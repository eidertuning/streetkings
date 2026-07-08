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
    title = 'Leyenda Local',
    subtitle = 'Deja de ser invisible.',
    lookAt = vector3(244.27, 1176.28, 225.5),
    shots = {
        { coords = vector3(238.0, 1186.0, 232.0), lookAt = vector3(250.0, 1170.0, 225.0), fov = 50.0, durationMs = 3500 },
        { coords = vector3(252.0, 1168.0, 228.0), lookAt = vector3(244.0, 1178.0, 225.5), fov = 38.0, durationMs = 4000, interpMs = 2500 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "Bienvenido al subsuelo. Pilotos reales, apuestas reales, dinero real.", duration = 3200 },
        { atMs = 3800, speaker = 'Hector', body = "Busca a alguien, ponte al lado y quema rueda. No me avergüences.", duration = 3500 },
    },
})

-- Mission 1: Overlook reveal (player in car, sweeping pan over LS)
reg('chapter1/vinewood_overlook', {
    title = 'Reconociendo las Calles',
    subtitle = 'Aprende a leerla.',
    lookAt = vector3(200.0, -200.0, 60.0),
    shots = {
        { coords = vector3(855.0, 1095.0, 318.0), lookAt = vector3(200.0, -200.0, 60.0),  fov = 48.0, durationMs = 3500 },
        { coords = vector3(810.0, 1100.0, 320.0),  lookAt = vector3(-500.0, -600.0, 50.0), fov = 52.0, durationMs = 4000, interpMs = 3000 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "Antes de correr esta ciudad, tienes que aprender a leerla.", duration = 3000 },
        { atMs = 3500, speaker = 'Hector', body = "Cada calle tiene dueño, cada esquina tiene historia.", duration = 3000 },
        { atMs = 6200, speaker = 'Hector', body = "Ven conmigo. Te voy a enseñar dónde se gana respeto.", duration = 2600 },
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
        { atMs = 300,  speaker = 'Hector', body = "Un coche bonito llama la atención. Un coche bien armado gana respeto.", duration = 3300 },
        { atMs = 3700, speaker = 'Hector', body = "Aquí fuera, tu carro habla antes que tú.", duration = 2600 },
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
        { atMs = 300,  speaker = 'Hector', body = "Motor, turbo, frenos. Nadie los ve, pero todos los sienten cuando pasas.", duration = 3200 },
        { atMs = 3700, speaker = 'Hector', body = "Puedes hablar bonito, pero el motor siempre dice la verdad.", duration = 2800 },
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
        { atMs = 300,  speaker = 'Hector', body = "El coche adecuado para la carrera adecuada, compadre.", duration = 3000 },
        { atMs = 3400, speaker = 'Hector', body = "Elige mal y pierdes antes de pisar el acelerador.", duration = 3000 },
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
        { atMs = 300,  speaker = 'Hector', body = "Binco no te hace famoso, pero nadie respeta a un fantasma.", duration = 3000 },
        { atMs = 3500, speaker = 'Hector', body = "Ya viste lo básico. Ahora viene lo real.", duration = 3500 },
    },
})

-- Mission 3: Rockford challenge intro (player in car, camera shows the start area)
reg('chapter1/rockford_challenge', {
    title = 'Desde la salida',
    subtitle = 'Derrota al rival.',
    lookAt = vector3(-1241.0, -456.0, 33.0),
    shots = {
        { coords = vector3(-1252.0, -444.0, 43.0), lookAt = vector3(-1241.0, -456.0, 33.0), fov = 45.0, durationMs = 3000 },
        { coords = vector3(-1232.0, -461.0, 35.0), lookAt = vector3(-1241.0, -454.0, 33.5), fov = 35.0, durationMs = 3500, interpMs = 2500 },
    },
    subtitles = {
        { atMs = 400,  speaker = 'Hector', body = "Hay un tipo en Rockford que cree que esa zona es suya.", duration = 3000 },
        { atMs = 3400, speaker = 'Hector', body = "No le regales la salida. Él quiere que cometas el error.", duration = 3200 },
    },
})

-- Mission 8: Gabe meets Vargas
reg('chapter1/gabe_meets_vargas', {
    title = 'Paranoico',
    subtitle = 'Gabe se está reuniendo con un policía.',
    lookAt = vector3(2522.3, 2609.9, 38.2),
    shots = {
        { coords = vector3(2524.5, 2611.5, 38.6), lookAt = vector3(2522.3, 2609.9, 38.2), fov = 40.0, durationMs = 3500 },
        { coords = vector3(2520.5, 2610.8, 38.4), lookAt = vector3(2522.3, 2609.9, 38.2), fov = 30.0, durationMs = 4500, interpMs = 2500 },
        { coords = vector3(2523.0, 2608.2, 38.3), lookAt = vector3(2522.3, 2609.9, 38.5), fov = 32.0, durationMs = 4000, interpMs = 2000 },
    },
    subtitles = {
        { atMs = 400,   speaker = 'Tú',     body = "Ese no es comprador. Ese es policía.", duration = 2500 },
        { atMs = 2700,  speaker = 'Gabe',   body = "Todo listo para el viernes. Saint tiene un conductor nuevo.", duration = 2600 },
        { atMs = 5200,  speaker = 'Gabe',   body = "El chico no tiene historial.", duration = 1800 },
        { atMs = 6900,  speaker = 'Vargas', body = "Mejor. Los limpios son más fáciles de ensuciar.", duration = 2600 },
        { atMs = 8800,  speaker = 'Gabe',   body = "No lo subestimes. Conduce bien.", duration = 2200 },
        { atMs = 10200, speaker = 'Vargas', body = "Entonces nos sirve.", duration = 1700 },
        { atMs = 11200, speaker = 'Gabe',   body = "Solo mantén mi nombre fuera del papeleo.", duration = 2400 },
        { atMs = 12100, speaker = 'Vargas', body = "Déjalo creer. Saint siempre mira al traidor equivocado.", duration = 2800 },
    },
})
