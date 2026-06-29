SKMusic = SKMusic or {}

local Config = SKMusicConfig or {}
local ACTIVE_SOURCES = {}
local LISTENER_VOLUME = {}
local SEARCH_COOLDOWN = {}
local dbReady = false

local function cfg(key, fallback)
    local value = Config[key]
    if value == nil then return fallback end
    return value
end

local function now()
    return os.time()
end

local function today()
    return os.date('%Y-%m-%d')
end

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, maxLength or 96)
end

local function normalizeQuery(value)
    value = cleanText(value, 100):lower()
    value = value:gsub('[^%w%s_%-]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value:sub(1, 100)
end

local function notify(src, message, notifyType)
    TriggerClientEvent('streetkings:notify', src, {
        title = 'Sotyfly',
        body = message,
        type = notifyType or 'info',
        duration = 4500,
    })
end

local function playerIdentifier(src)
    local identity = SKPlayerIds and SKPlayerIds.GetIdentity and SKPlayerIds.GetIdentity(src) or nil
    if identity and identity.streetkingsId then
        return ('streetkings:%s'):format(identity.streetkingsId)
    end
    if identity and identity.license then return identity.license end
    return GetPlayerIdentifierByType(src, 'license') or ('source:%d'):format(src)
end

local function urlEncode(value)
    value = tostring(value or '')
    value = value:gsub('\n', '\r\n')
    value = value:gsub('([^%w _%%%-%.~])', function(c)
        return string.format('%%%02X', string.byte(c))
    end)
    return value:gsub(' ', '+')
end

local function youtubeApiKey()
    return GetConvar('streetkings_youtube_api_key', cfg('YouTubeApiKey', '')) or ''
end

local function extractVideoId(value)
    value = tostring(value or '')
    local fromUrl = value:match('youtu%.be/([%w_%-]+)')
        or value:match('[?&]v=([%w_%-]+)')
        or value:match('/shorts/([%w_%-]+)')
    if fromUrl then return fromUrl end
    if #value == 11 and value:match('^[%w_%-]+$') then return value end
    return nil
end

local function videoUrl(videoId)
    return ('https://www.youtube.com/watch?v=%s'):format(videoId)
end

local function parseDuration(iso)
    iso = tostring(iso or '')
    local h = tonumber(iso:match('(%d+)H')) or 0
    local m = tonumber(iso:match('(%d+)M')) or 0
    local s = tonumber(iso:match('(%d+)S')) or 0
    return h * 3600 + m * 60 + s
end

local function httpJson(url)
    local p = promise.new()
    PerformHttpRequest(url, function(status, body)
        if status < 200 or status >= 300 then
            p:resolve({ ok = false, status = status, body = body })
            return
        end
        local ok, decoded = pcall(json.decode, body or '{}')
        p:resolve({ ok = ok, status = status, data = ok and decoded or nil, body = body })
    end, 'GET', '', { ['Accept'] = 'application/json' })
    return Citizen.Await(p)
end

local function trackFromRow(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        key = tostring(row.id),
        videoId = row.video_id,
        title = row.title,
        channelTitle = row.channel_title or '',
        thumbnail = row.thumbnail or '',
        duration = tonumber(row.duration) or 0,
        durationMs = (tonumber(row.duration) or 0) * 1000,
        url = row.url,
        playCount = tonumber(row.play_count) or 0,
        type = 'track',
    }
end

local function selectTrackByVideoId(videoId)
    local row = MySQL.single.await('SELECT * FROM music_tracks WHERE video_id = ? LIMIT 1', { videoId })
    return trackFromRow(row)
end

local function selectTrackById(trackId)
    local row = MySQL.single.await('SELECT * FROM music_tracks WHERE id = ? LIMIT 1', { tonumber(trackId) or 0 })
    return trackFromRow(row)
end

local function upsertTrack(track)
    if type(track) ~= 'table' or not track.videoId or track.videoId == '' then return nil end
    MySQL.query.await([[
        INSERT INTO music_tracks (video_id, title, channel_title, thumbnail, duration, url)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            channel_title = VALUES(channel_title),
            thumbnail = VALUES(thumbnail),
            duration = VALUES(duration),
            url = VALUES(url),
            updated_at = CURRENT_TIMESTAMP(3)
    ]], {
        cleanText(track.videoId, 32),
        cleanText(track.title, 255),
        cleanText(track.channelTitle, 255),
        cleanText(track.thumbnail, 500),
        tonumber(track.duration) or 0,
        cleanText(track.url or videoUrl(track.videoId), 500),
    })
    return selectTrackByVideoId(track.videoId)
end

local function trackFromYoutubeItem(item, details)
    if type(item) ~= 'table' then return nil end
    local videoId = item.id and (item.id.videoId or item.id) or item.videoId
    if not videoId or not tostring(videoId):match('^[%w_%-]+$') then return nil end
    local snippet = item.snippet or {}
    local thumbnails = snippet.thumbnails or {}
    local thumb = thumbnails.medium or thumbnails.default or thumbnails.high or {}
    return {
        videoId = cleanText(videoId, 32),
        title = cleanText(snippet.title or ('Video ' .. videoId), 255),
        channelTitle = cleanText(snippet.channelTitle or '', 255),
        thumbnail = cleanText(thumb.url or '', 500),
        duration = details and details.duration or 0,
        url = videoUrl(videoId),
    }
end

local function fetchVideoDetails(videoIds)
    local key = youtubeApiKey()
    if key == '' or #videoIds == 0 then return {} end
    local url = ('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=%s&key=%s'):format(
        urlEncode(table.concat(videoIds, ',')),
        urlEncode(key)
    )
    local response = httpJson(url)
    if not response.ok or type(response.data) ~= 'table' then return {} end
    local details = {}
    for _, item in ipairs(response.data.items or {}) do
        local videoId = item.id
        local snippet = item.snippet or {}
        local thumbnails = snippet.thumbnails or {}
        local thumb = thumbnails.medium or thumbnails.default or thumbnails.high or {}
        details[videoId] = {
            videoId = videoId,
            title = cleanText(snippet.title or ('Video ' .. tostring(videoId)), 255),
            channelTitle = cleanText(snippet.channelTitle or '', 255),
            thumbnail = cleanText(thumb.url or '', 500),
            duration = parseDuration(item.contentDetails and item.contentDetails.duration),
            url = videoUrl(videoId),
        }
    end
    return details
end

local function ensureTrackFromUrl(url)
    local videoId = extractVideoId(url)
    if not videoId then return nil, 'invalid_video' end
    local existing = selectTrackByVideoId(videoId)
    if existing then return existing end

    local details = fetchVideoDetails({ videoId })
    local track = details[videoId] or {
        videoId = videoId,
        title = 'Video ' .. videoId,
        channelTitle = 'Direct link',
        thumbnail = '',
        duration = 0,
        url = videoUrl(videoId),
    }
    return upsertTrack(track)
end

local function getSearchCache(normalized)
    local row = MySQL.single.await([[
        SELECT results_json
        FROM music_search_cache
        WHERE normalized_query = ? AND expires_at > CURRENT_TIMESTAMP(3)
        LIMIT 1
    ]], { normalized })
    if not row then return nil end
    local ok, decoded = pcall(json.decode, row.results_json or '[]')
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded
end

local function saveSearchCache(query, normalized, tracks)
    MySQL.query.await([[
        INSERT INTO music_search_cache (query, normalized_query, results_json, expires_at)
        VALUES (?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP(3), INTERVAL ? SECOND))
        ON DUPLICATE KEY UPDATE
            query = VALUES(query),
            results_json = VALUES(results_json),
            expires_at = VALUES(expires_at),
            created_at = CURRENT_TIMESTAMP(3)
    ]], { query, normalized, json.encode(tracks or {}), tonumber(cfg('CacheTTL', 604800)) or 604800 })
end

local function getApiUsage()
    local row = MySQL.single.await('SELECT api_searches FROM music_api_usage WHERE usage_date = ? LIMIT 1', { today() })
    return tonumber(row and row.api_searches) or 0
end

local function canUseApiSearch()
    return getApiUsage() < (tonumber(cfg('MaxDailyApiSearches', 90)) or 90)
end

local function incrementApiUsage()
    MySQL.query.await([[
        INSERT INTO music_api_usage (usage_date, api_searches)
        VALUES (?, 1)
        ON DUPLICATE KEY UPDATE api_searches = api_searches + 1, updated_at = CURRENT_TIMESTAMP(3)
    ]], { today() })
end

local function dailyUsage(identifier)
    local row = MySQL.single.await(
        'SELECT songs_played FROM music_user_daily_usage WHERE player_identifier = ? AND usage_date = ? LIMIT 1',
        { identifier, today() }
    )
    return tonumber(row and row.songs_played) or 0
end

local function incrementDailyUsage(identifier)
    MySQL.query.await([[
        INSERT INTO music_user_daily_usage (player_identifier, usage_date, songs_played)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE songs_played = songs_played + 1, updated_at = CURRENT_TIMESTAMP(3)
    ]], { identifier, today() })
end

local function sourceName(src, vehicleNetId)
    if cfg('AttachMusicToVehicleWhenInside', true) and tonumber(vehicleNetId) and tonumber(vehicleNetId) > 0 then
        return tostring(cfg('SoundPrefix', 'streetmusic_')) .. 'veh_' .. tostring(vehicleNetId)
    end
    return tostring(cfg('SoundPrefix', 'streetmusic_')) .. 'src_' .. tostring(src)
end

local function publicSource(sourceData)
    if not sourceData then return nil end
    local payload = {}
    for key, value in pairs(sourceData) do payload[key] = value end
    payload.serverNow = now()
    return payload
end

local function broadcastSource(sourceData)
    TriggerClientEvent('streetmusic:client:createOrUpdateSound', -1, publicSource(sourceData))
end

local function stopSource(src)
    local sourceData = ACTIVE_SOURCES[src]
    if not sourceData then return false end
    ACTIVE_SOURCES[src] = nil
    TriggerClientEvent('streetmusic:client:stopSound', -1, sourceData.soundName)
    return true
end

local function addRecent(identifier, trackId)
    MySQL.insert.await(
        'INSERT INTO music_recent_tracks (player_identifier, track_id) VALUES (?, ?)',
        { identifier, trackId }
    )
end

local function playTrackForSource(src, track, data)
    if not track then return { ok = false, reason = 'track_not_found' } end
    local identifier = playerIdentifier(src)
    local active = ACTIVE_SOURCES[src]
    local isSameTrack = active and tonumber(active.trackId) == tonumber(track.id)

    if cfg('EnableDailySongLimit', true) and not isSameTrack then
        local played = dailyUsage(identifier)
        local maxSongs = tonumber(cfg('MaxDailySongsPerUser', 50)) or 50
        if played >= maxSongs then
            local message = ('Has alcanzado el limite diario de %d canciones. Vuelve manana.'):format(maxSongs)
            notify(src, message, 'error')
            return { ok = false, reason = 'daily_song_limit', message = message, daily = { played = played, max = maxSongs } }
        end
        incrementDailyUsage(identifier)
    end

    if not isSameTrack then
        MySQL.update.await('UPDATE music_tracks SET play_count = play_count + 1, updated_at = CURRENT_TIMESTAMP(3) WHERE id = ?', { track.id })
        addRecent(identifier, track.id)
    end

    local coords = type(data.coords) == 'table' and data.coords or {}
    local vehicleNetId = tonumber(data.vehicleNetId or data.netId) or 0
    local sourceVolume = math.max(0.0, math.min(tonumber(data.volume) or cfg('DefaultSourceVolume', 0.35), cfg('MaxSourceVolume', 1.0)))

    if active then
        TriggerClientEvent('streetmusic:client:stopSound', -1, active.soundName)
    end

    local sourceData = {
        owner = src,
        playerIdentifier = identifier,
        soundName = sourceName(src, vehicleNetId),
        trackId = track.id,
        videoId = track.videoId,
        url = track.url,
        title = track.title,
        channelTitle = track.channelTitle,
        thumbnail = track.thumbnail,
        duration = track.duration,
        volume = sourceVolume,
        coords = {
            x = tonumber(coords.x) or 0.0,
            y = tonumber(coords.y) or 0.0,
            z = tonumber(coords.z) or 0.0,
        },
        vehicleNetId = vehicleNetId,
        startedAt = now(),
        paused = false,
        pausedAt = 0,
        totalPausedDuration = 0,
        playlistId = tonumber(data.playlistId) or nil,
        queue = type(data.queue) == 'table' and data.queue or {},
    }

    ACTIVE_SOURCES[src] = sourceData
    broadcastSource(sourceData)

    return {
        ok = true,
        player = publicSource(sourceData),
        daily = {
            played = dailyUsage(identifier),
            max = tonumber(cfg('MaxDailySongsPerUser', 50)) or 50,
        },
    }
end

local function listPlaylists(identifier)
    local playlists = MySQL.query.await([[
        SELECT p.*,
            (SELECT COUNT(*) FROM music_playlist_tracks t WHERE t.playlist_id = p.id) AS track_count
        FROM music_playlists p
        WHERE p.player_identifier = ?
        ORDER BY p.updated_at DESC, p.id DESC
    ]], { identifier }) or {}
    return playlists
end

local function ensureFavoritesPlaylist(identifier)
    local row = MySQL.single.await(
        'SELECT id FROM music_playlists WHERE player_identifier = ? AND name = ? LIMIT 1',
        { identifier, 'Favoritos' }
    )
    if row and row.id then return tonumber(row.id) end

    return MySQL.insert.await(
        'INSERT INTO music_playlists (player_identifier, name, description, cover) VALUES (?, ?, ?, ?)',
        { identifier, 'Favoritos', 'Canciones guardadas', '' }
    )
end

local function playlistTracks(playlistId, identifier)
    local rows = MySQL.query.await([[
        SELECT t.*
        FROM music_playlist_tracks pt
        INNER JOIN music_tracks t ON t.id = pt.track_id
        INNER JOIN music_playlists p ON p.id = pt.playlist_id
        WHERE pt.playlist_id = ? AND p.player_identifier = ?
        ORDER BY pt.position ASC, pt.added_at ASC
    ]], { tonumber(playlistId) or 0, identifier }) or {}
    local tracks = {}
    for _, row in ipairs(rows) do tracks[#tracks + 1] = trackFromRow(row) end
    return tracks
end

local function recentTracks(identifier)
    local rows = MySQL.query.await([[
        SELECT t.*, MAX(r.played_at) AS last_played_at
        FROM music_recent_tracks r
        INNER JOIN music_tracks t ON t.id = r.track_id
        WHERE r.player_identifier = ?
        GROUP BY t.id
        ORDER BY last_played_at DESC
        LIMIT 30
    ]], { identifier }) or {}
    local tracks = {}
    for _, row in ipairs(rows) do tracks[#tracks + 1] = trackFromRow(row) end
    return tracks
end

local function popularTracks()
    local rows = MySQL.query.await('SELECT * FROM music_tracks WHERE play_count > 0 ORDER BY play_count DESC, updated_at DESC LIMIT 30') or {}
    local tracks = {}
    for _, row in ipairs(rows) do tracks[#tracks + 1] = trackFromRow(row) end
    return tracks
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_tracks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            video_id VARCHAR(32) NOT NULL,
            title VARCHAR(255) NOT NULL,
            channel_title VARCHAR(255) NOT NULL DEFAULT '',
            thumbnail VARCHAR(500) NOT NULL DEFAULT '',
            duration INT UNSIGNED NOT NULL DEFAULT 0,
            url VARCHAR(500) NOT NULL,
            created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            play_count INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY unique_video_id (video_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_search_cache (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            query VARCHAR(120) NOT NULL,
            normalized_query VARCHAR(120) NOT NULL,
            results_json LONGTEXT NOT NULL,
            created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            expires_at DATETIME(3) NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY unique_normalized_query (normalized_query),
            KEY idx_normalized_query (normalized_query)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_playlists (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            player_identifier VARCHAR(128) NOT NULL,
            name VARCHAR(50) NOT NULL,
            description VARCHAR(200) NOT NULL DEFAULT '',
            cover VARCHAR(500) NOT NULL DEFAULT '',
            created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            PRIMARY KEY (id),
            KEY idx_player_identifier (player_identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_playlist_tracks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            playlist_id INT UNSIGNED NOT NULL,
            track_id INT UNSIGNED NOT NULL,
            position INT UNSIGNED NOT NULL DEFAULT 0,
            added_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            PRIMARY KEY (id),
            UNIQUE KEY unique_playlist_track (playlist_id, track_id),
            KEY idx_playlist_id (playlist_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_recent_tracks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            player_identifier VARCHAR(128) NOT NULL,
            track_id INT UNSIGNED NOT NULL,
            played_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            PRIMARY KEY (id),
            KEY idx_player_identifier (player_identifier),
            KEY idx_track_id (track_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_api_usage (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            usage_date DATE NOT NULL,
            api_searches INT UNSIGNED NOT NULL DEFAULT 0,
            created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            PRIMARY KEY (id),
            UNIQUE KEY unique_usage_date (usage_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS music_user_daily_usage (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            player_identifier VARCHAR(128) NOT NULL,
            usage_date DATE NOT NULL,
            songs_played INT UNSIGNED NOT NULL DEFAULT 0,
            created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
            updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
            PRIMARY KEY (id),
            UNIQUE KEY unique_user_day (player_identifier, usage_date),
            KEY idx_player_identifier (player_identifier),
            KEY idx_usage_date (usage_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    dbReady = true
end)

lib.callback.register('streetmusic:server:syncState', function(source)
    if not dbReady then return { ok = false, reason = 'db_not_ready' } end
    local identifier = playerIdentifier(source)
    return {
        ok = true,
        player = ACTIVE_SOURCES[source] and publicSource(ACTIVE_SOURCES[source]) or nil,
        playlists = listPlaylists(identifier),
        recent = recentTracks(identifier),
        popular = popularTracks(),
        activeSources = ACTIVE_SOURCES,
        daily = { played = dailyUsage(identifier), max = tonumber(cfg('MaxDailySongsPerUser', 50)) or 50 },
        api = { used = getApiUsage(), max = tonumber(cfg('MaxDailyApiSearches', 90)) or 90 },
        config = {
            maxAudibleDistance = cfg('MaxAudibleDistance', 25.0),
            fullVolumeDistance = cfg('FullVolumeDistance', 5.0),
            maxDailySongsPerUser = cfg('MaxDailySongsPerUser', 50),
            enableMiniHud = cfg('EnableMiniHud', true),
        },
        xsoundReady = GetResourceState('xsound') == 'started',
    }
end)

lib.callback.register('streetmusic:server:search', function(source, query)
    if not dbReady then return { ok = false, reason = 'db_not_ready' } end
    query = cleanText(query, 100)
    local normalized = normalizeQuery(query)
    if normalized == '' then return { ok = true, tracks = {}, source = 'empty' } end

    local videoId = extractVideoId(query)
    if videoId then
        local track, reason = ensureTrackFromUrl(videoUrl(videoId))
        if not track then return { ok = false, reason = reason or 'invalid_video' } end
        return { ok = true, tracks = { track }, source = 'direct', message = 'Link directo listo.' }
    end

    local cached = getSearchCache(normalized)
    if cached then
        return { ok = true, tracks = cached, source = 'cache', message = 'Resultados cargados desde cache.' }
    end

    local cooldownUntil = SEARCH_COOLDOWN[source] or 0
    if cooldownUntil > now() then
        return { ok = false, reason = 'cooldown', message = 'Has buscado demasiado rapido.' }
    end
    SEARCH_COOLDOWN[source] = now() + (tonumber(cfg('SearchCooldown', 30)) or 30)

    if youtubeApiKey() == '' then
        return { ok = false, reason = 'api_key_missing', message = 'No se pudo conectar con YouTube.' }
    end
    if not canUseApiSearch() then
        return {
            ok = false,
            reason = 'daily_api_limit',
            message = 'Se alcanzo el limite diario de busquedas nuevas. Puedes usar canciones guardadas, populares, recientes o pegar un enlace directo de YouTube.',
        }
    end

    local url = ('https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=%d&q=%s&key=%s'):format(
        tonumber(cfg('MaxResults', 10)) or 10,
        urlEncode(normalized),
        urlEncode(youtubeApiKey())
    )
    local response = httpJson(url)
    if not response.ok or type(response.data) ~= 'table' then
        return { ok = false, reason = 'youtube_error', message = 'No se pudo conectar con YouTube.' }
    end

    incrementApiUsage()
    local videoIds = {}
    for _, item in ipairs(response.data.items or {}) do
        if item.id and item.id.videoId then videoIds[#videoIds + 1] = item.id.videoId end
    end
    local details = fetchVideoDetails(videoIds)
    local tracks = {}
    for _, item in ipairs(response.data.items or {}) do
        local videoIdForItem = item.id and item.id.videoId or nil
        local track = trackFromYoutubeItem(item, details[videoIdForItem])
        if track then
            local row = upsertTrack(track)
            if row then tracks[#tracks + 1] = row end
        end
    end

    saveSearchCache(query, normalized, tracks)
    return { ok = true, tracks = tracks, source = 'api', message = 'Buscando en YouTube...' }
end)

lib.callback.register('streetmusic:server:playTrack3D', function(source, data)
    data = type(data) == 'table' and data or {}
    local track = selectTrackById(data.trackId or data.id)
    return playTrackForSource(source, track, data)
end)

lib.callback.register('streetmusic:server:playFromUrl', function(source, data)
    data = type(data) == 'table' and data or {}
    local track, reason = ensureTrackFromUrl(data.url)
    if not track then return { ok = false, reason = reason or 'invalid_url' } end
    return playTrackForSource(source, track, data)
end)

lib.callback.register('streetmusic:server:pauseTrack', function(source)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData or sourceData.paused then return { ok = true, player = sourceData and publicSource(sourceData) or nil } end
    sourceData.paused = true
    sourceData.pausedAt = now()
    TriggerClientEvent('streetmusic:client:pauseSound', -1, sourceData.soundName, publicSource(sourceData))
    return { ok = true, player = publicSource(sourceData) }
end)

lib.callback.register('streetmusic:server:resumeTrack', function(source)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData then return { ok = false, reason = 'not_playing' } end
    if sourceData.paused then
        sourceData.totalPausedDuration = (tonumber(sourceData.totalPausedDuration) or 0) + math.max(0, now() - (tonumber(sourceData.pausedAt) or now()))
        sourceData.paused = false
        sourceData.pausedAt = 0
    end
    TriggerClientEvent('streetmusic:client:resumeSound', -1, sourceData.soundName, publicSource(sourceData))
    return { ok = true, player = publicSource(sourceData) }
end)

lib.callback.register('streetmusic:server:stopTrack', function(source)
    stopSource(source)
    return { ok = true }
end)

lib.callback.register('streetmusic:server:skipTrack', function(source, direction)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData or type(sourceData.queue) ~= 'table' or #sourceData.queue == 0 then
        return { ok = false, reason = 'empty_queue' }
    end
    direction = tonumber(direction) or 1
    local index = 1
    for i = 1, #sourceData.queue do
        if tonumber(sourceData.queue[i]) == tonumber(sourceData.trackId) then
            index = i
            break
        end
    end
    index = ((index - 1 + direction) % #sourceData.queue) + 1
    local track = selectTrackById(sourceData.queue[index])
    return playTrackForSource(source, track, {
        coords = sourceData.coords,
        vehicleNetId = sourceData.vehicleNetId,
        volume = sourceData.volume,
        queue = sourceData.queue,
        playlistId = sourceData.playlistId,
    })
end)

lib.callback.register('streetmusic:server:setSourceVolume', function(source, volume)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData then return { ok = false, reason = 'not_playing' } end
    sourceData.volume = math.max(0.0, math.min(tonumber(volume) or cfg('DefaultSourceVolume', 0.35), cfg('MaxSourceVolume', 1.0)))
    broadcastSource(sourceData)
    return { ok = true, player = publicSource(sourceData) }
end)

lib.callback.register('streetmusic:server:setListenerVolume', function(source, volume)
    LISTENER_VOLUME[source] = math.max(0.0, math.min(tonumber(volume) or cfg('DefaultPlayerMusicVolume', 0.7), 1.0))
    return { ok = true, volume = LISTENER_VOLUME[source] }
end)

lib.callback.register('streetmusic:server:createPlaylist', function(source, data)
    data = type(data) == 'table' and data or {}
    local identifier = playerIdentifier(source)
    local name = cleanText(data.name, 50)
    if name == '' then return { ok = false, reason = 'invalid_name' } end
    MySQL.insert.await(
        'INSERT INTO music_playlists (player_identifier, name, description, cover) VALUES (?, ?, ?, ?)',
        { identifier, name, cleanText(data.description, 200), cleanText(data.cover, 500) }
    )
    return { ok = true, playlists = listPlaylists(identifier), message = 'Playlist creada correctamente.' }
end)

lib.callback.register('streetmusic:server:deletePlaylist', function(source, playlistId)
    local identifier = playerIdentifier(source)
    local id = tonumber(playlistId) or 0
    MySQL.query.await('DELETE pt FROM music_playlist_tracks pt INNER JOIN music_playlists p ON p.id = pt.playlist_id WHERE p.id = ? AND p.player_identifier = ?', { id, identifier })
    MySQL.update.await('DELETE FROM music_playlists WHERE id = ? AND player_identifier = ?', { id, identifier })
    return { ok = true, playlists = listPlaylists(identifier), message = 'Playlist eliminada.' }
end)

lib.callback.register('streetmusic:server:renamePlaylist', function(source, data)
    data = type(data) == 'table' and data or {}
    local identifier = playerIdentifier(source)
    local name = cleanText(data.name, 50)
    if name == '' then return { ok = false, reason = 'invalid_name' } end
    MySQL.update.await('UPDATE music_playlists SET name = ?, description = ?, updated_at = CURRENT_TIMESTAMP(3) WHERE id = ? AND player_identifier = ?', {
        name, cleanText(data.description, 200), tonumber(data.playlistId) or 0, identifier
    })
    return { ok = true, playlists = listPlaylists(identifier) }
end)

lib.callback.register('streetmusic:server:addTrackToPlaylist', function(source, data)
    data = type(data) == 'table' and data or {}
    local identifier = playerIdentifier(source)
    local playlistId = tonumber(data.playlistId) or 0
    local trackId = tonumber(data.trackId) or 0
    local row = MySQL.single.await('SELECT id FROM music_playlists WHERE id = ? AND player_identifier = ? LIMIT 1', { playlistId, identifier })
    if not row then return { ok = false, reason = 'playlist_not_found' } end
    local posRow = MySQL.single.await('SELECT COALESCE(MAX(position), 0) + 1 AS next_pos FROM music_playlist_tracks WHERE playlist_id = ?', { playlistId })
    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO music_playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)', { playlistId, trackId, tonumber(posRow and posRow.next_pos) or 1 })
    end)
    if not ok then return { ok = false, reason = 'duplicate', message = 'Esta cancion ya esta en la playlist.' } end
    return { ok = true, tracks = playlistTracks(playlistId, identifier), message = 'Cancion anadida a la playlist.' }
end)

lib.callback.register('streetmusic:server:toggleFavorite', function(source, data)
    data = type(data) == 'table' and data or {}
    local identifier = playerIdentifier(source)
    local playlistId = ensureFavoritesPlaylist(identifier)
    local trackId = tonumber(data.trackId) or 0
    if trackId <= 0 or not selectTrackById(trackId) then
        return { ok = false, reason = 'track_not_found', message = 'Cancion no encontrada.' }
    end

    local existing = MySQL.single.await(
        'SELECT id FROM music_playlist_tracks WHERE playlist_id = ? AND track_id = ? LIMIT 1',
        { playlistId, trackId }
    )
    if existing then
        MySQL.update.await('DELETE FROM music_playlist_tracks WHERE id = ?', { existing.id })
        return { ok = true, favorited = false, playlists = listPlaylists(identifier), message = 'Cancion quitada de favoritos.' }
    end

    local posRow = MySQL.single.await('SELECT COALESCE(MAX(position), 0) + 1 AS next_pos FROM music_playlist_tracks WHERE playlist_id = ?', { playlistId })
    MySQL.insert.await(
        'INSERT INTO music_playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)',
        { playlistId, trackId, tonumber(posRow and posRow.next_pos) or 1 }
    )
    return { ok = true, favorited = true, playlists = listPlaylists(identifier), message = 'Cancion guardada en favoritos.' }
end)

lib.callback.register('streetmusic:server:removeTrackFromPlaylist', function(source, data)
    data = type(data) == 'table' and data or {}
    local identifier = playerIdentifier(source)
    local playlistId = tonumber(data.playlistId) or 0
    MySQL.query.await([[
        DELETE pt FROM music_playlist_tracks pt
        INNER JOIN music_playlists p ON p.id = pt.playlist_id
        WHERE pt.playlist_id = ? AND pt.track_id = ? AND p.player_identifier = ?
    ]], { playlistId, tonumber(data.trackId) or 0, identifier })
    return { ok = true, tracks = playlistTracks(playlistId, identifier), message = 'Cancion eliminada.' }
end)

lib.callback.register('streetmusic:server:getPlaylists', function(source)
    return { ok = true, playlists = listPlaylists(playerIdentifier(source)) }
end)

lib.callback.register('streetmusic:server:getPlaylistTracks', function(source, playlistId)
    return { ok = true, tracks = playlistTracks(playlistId, playerIdentifier(source)) }
end)

lib.callback.register('streetmusic:server:getRecentTracks', function(source)
    return { ok = true, tracks = recentTracks(playerIdentifier(source)) }
end)

lib.callback.register('streetmusic:server:getPopularTracks', function()
    return { ok = true, tracks = popularTracks() }
end)

RegisterNetEvent('streetmusic:server:updatePosition', function(coords, vehicleNetId)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData or type(coords) ~= 'table' then return end
    sourceData.coords = {
        x = tonumber(coords.x) or sourceData.coords.x,
        y = tonumber(coords.y) or sourceData.coords.y,
        z = tonumber(coords.z) or sourceData.coords.z,
    }
    sourceData.vehicleNetId = tonumber(vehicleNetId) or sourceData.vehicleNetId or 0
    TriggerClientEvent('streetmusic:client:updateSoundPosition', -1, sourceData.soundName, sourceData.coords, sourceData.vehicleNetId)
end)

RegisterNetEvent('streetkings:sotyfly:requestSessions', function()
    TriggerClientEvent('streetmusic:client:syncSources', source, ACTIVE_SOURCES)
end)

RegisterNetEvent('streetkings:sotyfly:playUrl', function(data)
    data = type(data) == 'table' and data or {}
    local track = ensureTrackFromUrl(data.url)
    if not track then
        TriggerClientEvent('streetkings:sotyfly:error', source, 'invalid_url')
        return
    end
    playTrackForSource(source, track, data)
end)

RegisterNetEvent('streetkings:sotyfly:pause', function()
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData or sourceData.paused then return end
    sourceData.paused = true
    sourceData.pausedAt = now()
    TriggerClientEvent('streetmusic:client:pauseSound', -1, sourceData.soundName, publicSource(sourceData))
end)

RegisterNetEvent('streetkings:sotyfly:resume', function()
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData then return end
    if sourceData.paused then
        sourceData.totalPausedDuration = (tonumber(sourceData.totalPausedDuration) or 0) + math.max(0, now() - (tonumber(sourceData.pausedAt) or now()))
        sourceData.paused = false
        sourceData.pausedAt = 0
    end
    TriggerClientEvent('streetmusic:client:resumeSound', -1, sourceData.soundName, publicSource(sourceData))
end)
RegisterNetEvent('streetkings:sotyfly:stop', function() stopSource(source) end)
RegisterNetEvent('streetkings:sotyfly:updatePosition', function(coords, netId)
    local sourceData = ACTIVE_SOURCES[source]
    if not sourceData then return end
    sourceData.coords = coords
    sourceData.vehicleNetId = tonumber(netId) or 0
    TriggerClientEvent('streetmusic:client:updateSoundPosition', -1, sourceData.soundName, sourceData.coords, sourceData.vehicleNetId)
end)

AddEventHandler('playerDropped', function()
    if cfg('StopMusicOnPlayerDrop', true) then
        stopSource(source)
    end
    SEARCH_COOLDOWN[source] = nil
    LISTENER_VOLUME[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, sourceData in pairs(ACTIVE_SOURCES) do
        TriggerClientEvent('streetmusic:client:stopSound', -1, sourceData.soundName)
    end
end)

exports('GetSotyflySources', function()
    return ACTIVE_SOURCES
end)
