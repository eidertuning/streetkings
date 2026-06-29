SKMusicConfig = SKMusicConfig or {}

if IsDuplicityVersion and IsDuplicityVersion() then
    SKMusicConfig.YouTubeApiKeyConvars = {
        'streetkings_youtube_api_key',
        'sotyfly_youtube_api_key',
        'sk_youtube_api_key',
        'youtube_api_key',
    }
    SKMusicConfig.YouTubeApiKey = GetConvar('streetkings_youtube_api_key', '')
else
    SKMusicConfig.YouTubeApiKey = ''
end

SKMusicConfig.CacheTTL = 604800
SKMusicConfig.SearchCooldown = 2
SKMusicConfig.MaxResults = 10
SKMusicConfig.MinSearchDuration = 60
SKMusicConfig.MaxDailyApiSearches = 50
SKMusicConfig.ReservedDailyApiSearches = 10

SKMusicConfig.EnableDailySongLimit = false
SKMusicConfig.MaxDailySongsPerUser = 50

SKMusicConfig.UseXSound = true
SKMusicConfig.SoundPrefix = 'streetmusic_'

SKMusicConfig.Enable3DAudio = true
SKMusicConfig.MaxAudibleDistance = 25.0
SKMusicConfig.FullVolumeDistance = 5.0
SKMusicConfig.DefaultSourceVolume = 0.35
SKMusicConfig.DefaultPlayerMusicVolume = 0.7
SKMusicConfig.MaxSourceVolume = 1.0
SKMusicConfig.MinVolume = 0.0
SKMusicConfig.UpdatePositionInterval = 500
SKMusicConfig.FadeCurve = 'smooth'
SKMusicConfig.AllowMultipleNearbySources = true
SKMusicConfig.MaxNearbySources = 5

SKMusicConfig.AttachMusicToVehicleWhenInside = true
SKMusicConfig.FallbackAttachToPlayer = true
SKMusicConfig.StopMusicOnPlayerDrop = true
SKMusicConfig.StopMusicOnVehicleDeleted = true

SKMusicConfig.EnableMiniHud = true
SKMusicConfig.MiniHudPosition = 'bottom-right'
SKMusicConfig.ShowMiniHudOnClose = true

SKMusicConfig.Debug = false
