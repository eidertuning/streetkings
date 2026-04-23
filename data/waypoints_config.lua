SKWaypointConfig = {}

SKWaypointConfig.TickRate = 100
SKWaypointConfig.DistanceRefreshRate = 150
SKWaypointConfig.PreAllocPool = 5

SKWaypointConfig.PanelWidth = 512
SKWaypointConfig.PanelHeight = 1024

SKWaypointConfig.ReplaceMapWaypoint = true

SKWaypointConfig.MapWaypoint = {
    text        = 'WAYPOINT',
    color       = '#ffd147',
    icon        = 'location-dot',
    size        = 1.0,
    maxRender   = 1000.0,
    fadeStart   = 800.0,
    showDist    = true,
    groundBeam  = true,
    beamHeight  = 60.0,
    guideLines  = false,
}

SKWaypointConfig.Defaults = {
    text        = 'WAYPOINT',
    color       = '#ffd147',
    icon        = nil,
    imageUrl    = nil,
    size        = 1.0,
    maxRender   = 500.0,
    fadeStart   = 400.0,
    showDist    = true,
    groundBeam  = true,
    beamHeight  = 60.0,
    guideLines  = false,
}

SKWaypointConfig.GuideLines = {
    sampleStep      = 6.0,
    maxDistance     = 500.0,
    drawRange       = 120.0,
    routeHeight     = 0.22,
    updateInterval  = 2500,
    drawOnFoot      = false,
    arrowColor      = { r = 255, g = 230, b = 120, a = 220 },
    arrowSpacing    = 1.0,
    arrowLength     = 1.5,
    arrowWidth      = 0.8,
    smoothJunctions = true,
    junctionPadding = 1,
    curveStrength   = 0.55,
    curveMaxHandle  = 6.0,
}
