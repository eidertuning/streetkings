RegisterNUICallback('leaderboard:getCategories', function(_, cb)
    CreateThread(function()
        local cats = lib.callback.await('streetkings:events:getCategories', false)
        cb(cats or {})
    end)
end)

RegisterNUICallback('leaderboard:getData', function(data, cb)
    local categoryId = data and data.categoryId
    local period = data and data.period
    if type(categoryId) ~= 'string' then cb({ entries = {}, personalBest = nil, scoreType = 'time' }) return end
    CreateThread(function()
        local result = lib.callback.await('streetkings:events:getCategoryLeaderboard', false, categoryId, period)
        cb(result or { entries = {}, personalBest = nil, scoreType = 'time' })
    end)
end)
