local SOTYFLY_APP = {
    id = 'sotyfly',
    label = 'Sotyfly',
    icon = 'fa-music',
    glyph = 'Sf',
    color = 'linear-gradient(135deg, #1ed760, #0f8f44)',
    category = 'media',
    ui = 'html/apps/sotyfly/index.html',
    description = 'Tablet music player for StreetKings soundtrack and saved links.',
    version = '1.0.0',
    developer = 'Five Horizon',
}

local LINKS_KVP = 'sk_sotyfly_links'
local PLAYLISTS_KVP = 'sk_sotyfly_playlists'

local function registerSotyflyApp()
    exports[GetCurrentResourceName()]:RegisterTabletApp(SOTYFLY_APP)
end

local function decodeKvp(key, fallback)
    local raw = GetResourceKvpString(key)
    if not raw or raw == '' then return fallback end
    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return fallback end
    return value
end

local function saveKvp(key, value)
    SetResourceKvp(key, json.encode(value or {}))
end

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maxLength or 80)
end

local function normalizeUrl(value)
    value = cleanText(value, 300)
    if value == '' then return '' end
    if not value:match('^https?://') then return '' end
    return value
end

local function getYoutubeId(url)
    return url:match('youtu%.be/([%w_%-]+)') or url:match('[?&]v=([%w_%-]+)') or url:match('/shorts/([%w_%-]+)')
end

local function buildLinkTitle(url, title)
    title = cleanText(title, 96)
    if title ~= '' then return title end
    local youtubeId = getYoutubeId(url)
    if youtubeId then return 'YouTube ' .. youtubeId end
    return url
end

local function getLinks()
    local links = decodeKvp(LINKS_KVP, {})
    local clean = {}
    for _, link in ipairs(links) do
        if type(link) == 'table' and type(link.url) == 'string' and link.url ~= '' then
            clean[#clean + 1] = {
                id = tostring(link.id or ('link_' .. #clean + 1)),
                title = cleanText(link.title, 96),
                url = link.url,
                provider = tostring(link.provider or 'youtube'):sub(1, 24),
                addedAt = tonumber(link.addedAt) or 0,
                type = 'link',
            }
        end
    end
    return clean
end

local function getPlaylists()
    local playlists = decodeKvp(PLAYLISTS_KVP, {
        { id = 'favorites', name = 'Favoritos', items = {} },
        { id = 'youtube', name = 'YouTube', items = {} },
    })
    if #playlists == 0 then
        playlists = {
            { id = 'favorites', name = 'Favoritos', items = {} },
            { id = 'youtube', name = 'YouTube', items = {} },
        }
    end
    return playlists
end

RegisterNUICallback('sotyfly:getData', function(data, cb)
    local query = cleanText(data and data.query, 80)
    cb({
        ok = true,
        player = SKSoundtrack.GetPlayerState(),
        tracks = SKSoundtrack.SearchTracks(query, 160),
        links = getLinks(),
        playlists = getPlaylists(),
    })
end)

RegisterNUICallback('sotyfly:playTrack', function(data, cb)
    local trackKey = cleanText(data and data.key, 96)
    if trackKey == '' then
        cb({ ok = false, reason = 'invalid_track' })
        return
    end
    local ok, err = pcall(SKSoundtrack.SetRadioTrackByKey, trackKey)
    cb({ ok = ok == true, reason = ok and nil or tostring(err), player = SKSoundtrack.GetPlayerState() })
end)

RegisterNUICallback('sotyfly:skip', function(_, cb)
    SKSoundtrack.SkipCurrentTrack()
    cb({ ok = true, player = SKSoundtrack.GetPlayerState() })
end)

RegisterNUICallback('sotyfly:setEnabled', function(data, cb)
    local enabled = data and data.enabled == true
    if SKSettings and SKSettings.setGeneralValue then
        SKSettings.setGeneralValue('soundtrackEnabled', enabled)
    end
    exports[GetCurrentResourceName()]:SetSoundtrackEnabled(enabled)
    cb({ ok = true, player = SKSoundtrack.GetPlayerState() })
end)

RegisterNUICallback('sotyfly:addLink', function(data, cb)
    local url = normalizeUrl(data and data.url)
    if url == '' then
        cb({ ok = false, reason = 'invalid_url' })
        return
    end
    local links = getLinks()
    for _, link in ipairs(links) do
        if link.url == url then
            cb({ ok = true, duplicate = true, links = links })
            return
        end
    end
    local provider = getYoutubeId(url) and 'youtube' or 'link'
    links[#links + 1] = {
        id = ('link_%d_%d'):format(GetGameTimer(), #links + 1),
        title = buildLinkTitle(url, data and data.title),
        url = url,
        provider = provider,
        addedAt = GetCloudTimeAsInt and GetCloudTimeAsInt() or GetGameTimer(),
        type = 'link',
    }
    saveKvp(LINKS_KVP, links)
    cb({ ok = true, links = links })
end)

RegisterNUICallback('sotyfly:removeLink', function(data, cb)
    local id = tostring(data and data.id or '')
    local links = getLinks()
    for i = #links, 1, -1 do
        if links[i].id == id then table.remove(links, i) end
    end
    saveKvp(LINKS_KVP, links)
    cb({ ok = true, links = links })
end)

RegisterNUICallback('sotyfly:savePlaylists', function(data, cb)
    local incoming = type(data and data.playlists) == 'table' and data.playlists or {}
    local playlists = {}
    for _, playlist in ipairs(incoming) do
        if type(playlist) == 'table' then
            playlists[#playlists + 1] = {
                id = cleanText(playlist.id, 48),
                name = cleanText(playlist.name, 48),
                items = type(playlist.items) == 'table' and playlist.items or {},
            }
        end
    end
    saveKvp(PLAYLISTS_KVP, playlists)
    cb({ ok = true, playlists = playlists })
end)

RegisterNUICallback('sotyfly:setVisible', function(data, cb)
    SKSoundtrack.SetSotyflyVisible(data and data.visible == true)
    cb({ ok = true })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        registerSotyflyApp()
    end
end)

CreateThread(function()
    Wait(850)
    registerSotyflyApp()
end)
