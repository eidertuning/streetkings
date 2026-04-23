-- Chapter 1 cutscene definitions
--
-- Shapes:
--   - In-vehicle / observational reveals: scripted camera shots + subtitles.
--     Player stays in the car and the camera does the work.
--   - On-foot character meets: a synchronized scene (`syncScene`) anchors the
--     choreography in world-space. Each actor lists a `syncAnim` with a
--     paired dict+clip and the player can be attached via `attachPlayer`.
--     Scripted cameras still drive the framing on top.

local function reg(id, def) SKCutscene.register(id, def) end

-- Mission 2: Hector's intro at the Car Meet (player stays in car)
reg('chapter1/hector_intro_meet', {
    title = 'Local Legend',
    subtitle = 'Time to show these streets what you got.',
    lookAt = vector3(244.27, 1176.28, 225.5),
    shots = {
        { coords = vector3(238.0, 1186.0, 232.0), lookAt = vector3(250.0, 1170.0, 225.0), fov = 50.0, durationMs = 3500 },
        { coords = vector3(252.0, 1168.0, 228.0), lookAt = vector3(244.0, 1178.0, 225.5), fov = 38.0, durationMs = 4000, interpMs = 2500 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "Welcome to the underground. Real drivers, real stakes, real money.", duration = 3200 },
        { atMs = 3800, speaker = 'Hector', body = "Why don't you pick someone to challenge? Don't embarrass me.",               duration = 3500 },
    },
})

-- Mission 1: Overlook reveal (player in car, sweeping pan over LS)
reg('chapter1/vinewood_overlook', {
    title = 'Casing the Streets',
    subtitle = 'Learn the city.',
    lookAt = vector3(200.0, -200.0, 60.0),
    shots = {
        { coords = vector3(855.0, 1095.0, 318.0), lookAt = vector3(200.0, -200.0, 60.0),  fov = 48.0, durationMs = 3500 },
        { coords = vector3(810.0, 1100.0, 320.0),  lookAt = vector3(-500.0, -600.0, 50.0), fov = 52.0, durationMs = 4000, interpMs = 3000 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "Take a look. Every street, every alley, every corner with a deal going down.", duration = 3500 },
        { atMs = 4200, speaker = 'Hector', body = "Before you race it, you need to know it. Ride with me.", duration = 3500 },
    },
})

-- Mission 1: Discovery - Visual Mods Shop
reg('chapter1/discover_visual', {
    title = nil,
    lookAt = vector3(-361.0, -133.0, 38.4),
    shots = {
        { coords = vector3(-355.0, -126.0, 42.0), lookAt = vector3(-363.0, -136.0, 38.0), fov = 40.0, durationMs = 3000 },
        { coords = vector3(-367.0, -138.0, 40.0), lookAt = vector3(-358.0, -130.0, 39.0), fov = 35.0, durationMs = 3500, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 300,  speaker = 'Hector', body = "Visual mods. Paint, wheels, liveries - this is how you show up.", duration = 3000 },
        { atMs = 3500, speaker = 'Hector', body = "Out here, people clock your ride before they clock your face.", duration = 2800 },
    },
})

-- Mission 1: Discovery - Performance Shop
reg('chapter1/discover_performance', {
    title = nil,
    lookAt = vector3(717.8, -1088.2, 20.6),
    shots = {
        { coords = vector3(707.6, -1076.0, 24.8), lookAt = vector3(717.8, -1088.2, 20.6), fov = 40.0, durationMs = 3000 },
        { coords = vector3(712.0, -1080.0, 22.5), lookAt = vector3(717.8, -1088.2, 20.6), fov = 35.0, durationMs = 3500, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 300,  speaker = 'Hector', body = "Performance shop. Engine, turbo, brakes - the parts nobody sees but everybody feels.", duration = 3200 },
        { atMs = 3700, speaker = 'Hector', body = "You can talk all you want, but the engine tells the truth.", duration = 2800 },
    },
})

-- Mission 1: Discovery - Tuner Dealership
reg('chapter1/discover_dealership', {
    title = nil,
    lookAt = vector3(-53.8, -1110.4, 26.1),
    shots = {
        { coords = vector3(-81.0, -1112.6, 28.2), lookAt = vector3(-53.8, -1110.4, 26.1), fov = 42.0, durationMs = 3000 },
        { coords = vector3(-72.0, -1108.0, 27.0), lookAt = vector3(-53.8, -1110.4, 26.1), fov = 36.0, durationMs = 3500, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 300,  speaker = 'Hector', body = "Tuner lot. When you cash out, this is where you pick the next one.", duration = 3200 },
        { atMs = 3600, speaker = 'Hector', body = "Right car for the right race, dawg. Matters more than you think.", duration = 2800 },
    },
})

-- Mission 1: Discovery - Clothing Store
reg('chapter1/discover_clothing', {
    title = nil,
    lookAt = vector3(411.3, -808.1, 28.6),
    shots = {
        { coords = vector3(404.4, -818.9, 30.7), lookAt = vector3(411.3, -808.1, 28.6), fov = 40.0, durationMs = 3000 },
        { coords = vector3(408.0, -815.0, 29.8), lookAt = vector3(411.3, -808.1, 28.6), fov = 35.0, durationMs = 3500, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 300,  speaker = 'Hector', body = "Binco. Not high fashion, but you can switch up your look when you need to.", duration = 3000 },
        { atMs = 3500, speaker = 'Hector', body = "That's the tour. You know the city now - no excuses. Go make yourself somebody.", duration = 3500 },
    },
})

-- Mission 3: Rockford challenge intro (player in car, camera shows the start area)
reg('chapter1/rockford_challenge', {
    title = 'Off the Line',
    subtitle = 'Beat the rival.',
    lookAt = vector3(-1241.0, -456.0, 33.0),
    shots = {
        { coords = vector3(-1252.0, -444.0, 43.0), lookAt = vector3(-1241.0, -456.0, 33.0), fov = 45.0, durationMs = 3000 },
        { coords = vector3(-1232.0, -461.0, 35.0), lookAt = vector3(-1241.0, -454.0, 33.5), fov = 35.0, durationMs = 3500, interpMs = 2500 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "See that fool? He thinks he owns this stretch.", duration = 3000 },
        { atMs = 3600, speaker = 'Hector', body = "Smoke him. Show him whose street this really is.",    duration = 3000 },
    },
})

-- Mission 8: Gabe meets Vargas
reg('chapter1/gabe_meets_vargas', {
    title = 'Paranoid',
    subtitle = 'Gabe is meeting a cop.',
    lookAt = vector3(2522.3, 2609.9, 38.2),
    shots = {
        { coords = vector3(2524.5, 2611.5, 38.6), lookAt = vector3(2522.3, 2609.9, 38.2), fov = 40.0, durationMs = 3500 },
        { coords = vector3(2520.5, 2610.8, 38.4), lookAt = vector3(2522.3, 2609.9, 38.2), fov = 30.0, durationMs = 4500, interpMs = 2500 },
        { coords = vector3(2523.0, 2608.2, 38.3), lookAt = vector3(2522.3, 2609.9, 38.5), fov = 32.0, durationMs = 4000, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 400,   speaker = 'You',    body = "That's not a buyer. That's a badge.",                              duration = 3000 },
        { atMs = 3800,  speaker = 'Gabe',   body = "It's all set for Friday. Saint's using a new driver - kid's got no record.", duration = 3500 },
        { atMs = 7600,  speaker = 'Vargas', body = "Good. I want the whole crew at the yard. Every last one of them.",         duration = 3200 },
        { atMs = 11000, speaker = 'Gabe',   body = "Just keep my name out of the paperwork.",                         duration = 3000 },
    },
})
