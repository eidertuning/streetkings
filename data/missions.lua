local MINUTE = 60
local function minutes(n) return { minSeconds = n * MINUTE, maxSeconds = n * MINUTE } end
local NO_COOLDOWN = { minSeconds = 0, maxSeconds = 0 }

SKMissionsConfig = {
    DEV_SKIP_COOLDOWN = false,
    BLIP_SPRITE_DEFAULT = 480,
    BLIP_COLOR_HECTOR = 5,
    BLIP_COLOR_SAINT  = 46,
}

local HAND_BONE = 28422
local IMPATIENT_IDLE  = { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base', flags = 1 }
local CARRY_BOX_IDLE  = { dict = 'anim@heists@box_carry@', name = 'idle', flags = 50 }
local CARRY_BOX_WALK  = { dict = 'anim@heists@box_carry@', name = 'walk', flags = 47 }
local GIVE_ANIM       = { dict = 'mp_common', name = 'givetake1_a', flags = 48, durationMs = 2400 }
local RECEIVE_ANIM    = { dict = 'mp_common', name = 'givetake1_b', flags = 48, durationMs = 2400 }
local DEFAULT_PROP_OFFSET = vector3(0.0, 0.0, 0.0)
local DEFAULT_PROP_ROT    = vector3(0.0, 0.0, 0.0)
local SAINT_CHATTER = { index = 1, facial = true }

local SAINT_HUB_LOOKAT = vector3(1217.5741, -3202.2537, 5.55)
-- Shared docks meting shots used by every Saint pickup cinematic
local SAINT_MEETING_SHOTS = {
    { coords = vector3(1218.5, -3207.0, 6.2), lookAt = vector3(1217.6, -3202.5, 5.7), fov = 46.0, durationMs = 4000 },
    { coords = vector3(1210.5, -3207.5, 7.0), lookAt = vector3(1218.0, -3202.0, 5.2), fov = 54.0, durationMs = 5000, interpMs = 2000 },
    { coords = vector3(1224.5, -3206.5, 6.5), lookAt = vector3(1219.0, -3202.5, 5.0), fov = 52.0, durationMs = 7000, interpMs = 2200 },
}

SKMissions = {
    chapters = {
        {
            id = 'chapter_1',
            title = 'Entry Level',
            missions = {
                {
                    id = 'casing_the_streets',
                    title = 'Casing the Streets',
                    subtitle = 'Learn the city before you race it.',
                    giver = { name = 'Hector', avatar = 'hector', color = 5 },
                    autoStart = true,
                    unlockMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = _L('content.messages.chapter_intro_unlock'),
                    },
                    startBlip = {
                        sprite = 271, color = 5,
                        coords = vector3(833.3976, 1085.2294, 298.9104),
                        label = 'Vinewood Overlook',
                    },
                    objectives = {
                        { type = 'cutscene', cutsceneId = 'chapter1/vinewood_overlook', label = 'Take it in' },
                        { type = 'visitLocation', coords = vector3(-361.0286, -132.9494, 38.3956), radius = 15.0, label = 'Visit the Visual Mods Shop', waypointOnly = true },
                        { type = 'cutscene', cutsceneId = 'chapter1/discover_visual', label = 'Listen Up!' },
                        { type = 'visitLocation', coords = vector3(717.8505, -1088.2021, 20.6300), radius = 15.0, label = 'Visit the Performance Shop', waypointOnly = true },
                        { type = 'cutscene', cutsceneId = 'chapter1/discover_performance', label = 'Listen Up!' },
                        { type = 'visitLocation', coords = vector3(-53.7626, -1110.3956, 26.1458), radius = 15.0, label = 'Visit the Tuner Dealership', waypointOnly = true },
                        { type = 'cutscene', cutsceneId = 'chapter1/discover_dealership', label = 'Listen Up!' },
                        { type = 'visitLocation', coords = vector3(411.3188, -808.0818, 28.5714), radius = 15.0, label = 'Visit Binco', waypointOnly = true },
                        { type = 'cutscene', cutsceneId = 'chapter1/discover_clothing', label = 'Wrap up the tour' },
                    },
                    endMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = _L('content.messages.chapter_intro_end'),
                    },
                    rewards = { cash = 1500, playerXp = 40 },
                    cooldown = minutes(3),
                },
                {
                    id = 'local_legend',
                    title = 'Local Legend',
                    subtitle = 'First impression. Make it count.',
                    resetOnLoad = true,
                    giver = { name = 'Hector', avatar = 'hector', color = 5 },
                    unlockMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = _L('content.messages.local_legend_unlock'),
                    },
                    startBlip = {
                        sprite = 480, color = 5,
                        coords = vector3(244.2698, 1176.2820, 224.9299),
                        label = 'Car Meet',
                    },
                    objectives = {
                        { type = 'cutscene', cutsceneId = 'chapter1/hector_intro_meet', label = 'Head to the Car Meet' },
                        { type = 'npcChallenge', label = '"Do A Burnout" next to any racer to challenge them to a race!' },
                        { type = 'completeEvent', filter = { scoreType = 'time' }, count = 1, label = 'Post a time on any track' },
                    },
                    endCutscene = nil,
                    endMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = "Hoy no te convertiste en leyenda, pero dejaste de ser invisible. Si veo algo que valga tu tiempo, te llamo.",
                    },
                    carMeetRacers = {
                        { vehicle = 'sultan',   ped = 'u_m_y_tattoo_01', coords = vector4(225.4610, 1233.5007, 224.9205, 193.9090) },
                        { vehicle = 'jester',   ped = 'u_m_y_guido_01',   coords = vector4(213.5513, 1225.5935, 224.9189, 281.4594) },
                        { vehicle = 'comet2',   ped = 'u_m_m_blane',  coords = vector4(231.8961, 1162.0685, 224.9240, 287.7686) },
                        { vehicle = 'elegy',    ped = 'u_m_y_party_01',   coords = vector4(226.6020, 1183.9320, 224.9195, 272.1808) },
                    },
                    rewards = { cash = 2500, playerXp = 50 },
                    cooldown = minutes(20),
                },
                {
                    id = 'off_the_line',
                    title = 'Off the Line',
                    subtitle = 'Put the Rockford guy in his place.',
                    resetOnLoad = true,
                    giver = { name = 'Hector', avatar = 'hector', color = 5 },
                    unlockMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = "Hay un tipo en Rockford que cree que esa zona es suya. Ve a la salida y ponlo en su lugar.",
                    },
                    startBlip = {
                        sprite = 315, color = 5,
                        coords = vector3(-1241.1169, -456.0110, 33.0211),
                        label = 'Rockford Smash - Race Start',
                    },
                    opponentSpawn = {
                        vehicleModel = 'elegy',
                        pedModel = 'a_m_y_hipster_02',
                        coords = vector4(-1237.5, -459.0, 33.02, 310.0),
                    },
                    objectives = {
                        {
                            type = 'cutscene', cutsceneId = 'chapter1/rockford_challenge',
                            label = 'Meet the rival',
                            preSpawnOpponent = true,
                        },
                        {
                            type = 'scriptedRace',
                            label = 'Win the Rockford Smash',
                            trackId = 'track_sprint_rockford_smash',
                            autoStart = true,
                            opponent = {
                                vehicleModel = 'elegy',
                                pedModel = 'a_m_y_hipster_02',
                                driveSpeed = 80.0,
                                driveFlags = 786468,
                                usePreSpawned = true,
                            },
                            mustWin = true,
                        },
                    },
                    endMessage = {
                        sender = 'Hector', avatar = 'hector',
                        body = "Te acabas de ganar una llamada que puede cambiarte la vida. Hablé de ti con Saint. Si te llama, contesta. Pero cuida lo que aceptas.",
                    },
                    rewards = { cash = 3500, playerXp = 75 },
                    cooldown = minutes(20),
                },
                -- Mission 4 - docks loading bay: meet Saint, test handoff, Sandy Shores drop.
                {
                    id = 'meeting_saint',
                    title = 'Meeting Saint',
                    subtitle = "Un favor de Hector te abre una puerta peligrosa.",
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    autoStart = true,
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Hector habló bien de ti. Esa es la única razón por la que estás aquí. Muelles Elysian, bahía sur. Llega con el motor encendido.",
                    },
                    startBlip = {
                        sprite = 501, color = 46,
                        coords = vector3(1219.7073, -3203.2295, 4.9817),
                        label = 'Elysian Docks - Loading bay',
                    },
                    objectives = {
                        {
                            type = 'pickupPackage',
                            coords = vector3(1219.7073, -3203.2295, 4.9817),
                            radius = 2.0,
                            label = 'Meet Saint',
                            npc = {
                                model = 'a_m_m_soucent_04',
                                spawnCoords = vector3(1217.5741, -3202.2537, 4.9471),
                                spawnHeading = 178.7515,
                                mode = 'giving',
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = CARRY_BOX_IDLE,
                                walkAnim = CARRY_BOX_WALK,
                                handoffAnim = GIVE_ANIM,
                                handoffDetachMs = 900,
                                dismissReleaseMs = 5000,
                                dismissWalkTarget = vector3(1217.5741, -3202.2537, 4.9471),
                                cinematic = {
                                    title = 'Meeting Saint',
                                    subtitle = 'A favor for Hector.',
                                    lookAt = SAINT_HUB_LOOKAT,
                                    shots = SAINT_MEETING_SHOTS,
                                    approachAtMs = 9500,
                                    handoffAtMs = 14000,
                                    subtitles = {
                                        { atMs = 400,   speaker = 'Saint', body = "Hector habló bien de ti. Esa es la única razón por la que estás aquí.", duration = 3000, playAnimOnActor = SAINT_CHATTER },
                                        { atMs = 3500,  speaker = 'Saint', body = "No necesito amigos. No necesito preguntas. Necesito que el paquete llegue.", duration = 4000, playAnimOnActor = SAINT_CHATTER },
                                        { atMs = 8000,  speaker = 'Saint', body = "Primera lección conmigo: si tienes que preguntar, ya empezaste mal.", duration = 3500 },
                                        { atMs = 14500, speaker = 'Saint', body = "Sandy Shores. Le das la caja y te vas. Después no nos conocemos.", duration = 2800 },
                                        { atMs = 17400, speaker = 'Saint', body = "Muévete.", duration = 2000, playAnimOnActor = SAINT_CHATTER },
                                    },
                                },
                            },
                        },
                        {
                            type = 'deliverPackage',
                            coords = vector3(1708.3663, 3774.0491, 33.8897),
                            radius = 2.0,
                            label = 'Drop at Sandy Shores',
                            midMessages = {
                                { delaySeconds = 20, sender = 'Hector', avatar = 'hector',
                                  body = "Saint me escribió. Dice que llegaste limpio. Mantente fino y hoy comes bien, kid." },
                                { delaySeconds = 55, sender = 'Hector', avatar = 'hector',
                                  body = "Una cosa: no intentes caerle bien. Saint odia eso. Tú solo conduce." },
                            },
                            npc = {
                                model = 'g_m_y_salvagoon_01',
                                spawnCoords = vector3(1704.6248, 3774.1016, 33.9645),
                                spawnHeading = 213.9588,
                                mode = 'receiving',
                                dismissReleaseMs = 0,
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = IMPATIENT_IDLE,
                                idleAfterHandoff = CARRY_BOX_IDLE,
                                walkAnim = CARRY_BOX_WALK,
                                handoffAnim = RECEIVE_ANIM,
                                handoffDetachMs = 1100,
                                dismissWalkTarget = vector3(1706.2581, 3778.6111, 34.1289),
                                dismissSpeed = 3.5,
                                deleteOnDismiss = true,
                                cinematic = {
                                    title = 'Sandy Shores Drop',
                                    lookAt = vector3(1705.0, 3773.5, 34.5),
                                    shots = {
                                        { coords = vector3(1712.5, 3772.5, 35.5), lookAt = vector3(1705.5, 3774.0, 35.0), fov = 48.0, durationMs = 3800 },
                                        { coords = vector3(1708.5, 3768.0, 36.5), lookAt = vector3(1705.0, 3773.5, 34.3), fov = 56.0, durationMs = 6000, interpMs = 1800 },
                                    },
                                    approachAtMs = 5600,
                                    handoffAtMs = 9500,
                                    subtitles = {
                                        { atMs = 400,  speaker = 'Mensajero', body = "¿Tú eres el de Hector? Llegas tarde.", duration = 2600 },
                                        { atMs = 7000, speaker = 'Mensajero', body = "El paquete está completo. Dile a Saint que estamos en paz.", duration = 3000 },
                                    },
                                },
                            },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Corrida limpia. La deuda de Hector queda pagada. No te quedes mirando el móvil.",
                    },
                    rewards = { cash = 2500, playerXp = 75 },
                    cooldown = minutes(40),
                    flagsOnComplete = { metSaint = true },
                },
                -- Mission 5 - Drop-Car Pickup: Saint sends you for an easy drop-car in Paleto, thief wrecks it, debt begins.
                {
                    id = 'drop_car_burned',
                    title = 'Drop-Car Pickup',
                    subtitle = 'Un coche en Paleto. Trabajo simple, deuda complicada.',
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    forceAutoStart = true,
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Trabajo simple, corredor. Hay un coche en Paleto. Llaves detrás de la placa. Lo traes a los muelles y no preguntas.",
                    },
                    startBlip = {
                        sprite = 501, color = 46,
                        coords = vector3(-58.6126, 6344.4121, 30.8930),
                        label = 'Paleto - parking lot',
                    },
                    objectives = {
                        {
                            type = 'stopVehicle',
                            coords = vector3(-58.6126, 6344.4121, 30.8930),
                            label = "Collect the drop-car",
                            requiresFreeroam = true,
                            vehicle = {
                                model = 'sultan',
                                spawnCoords = vector4(-58.6126, 6344.4121, 30.8930, 134.4775),
                            },
                            thief = {
                                model = 'g_m_y_mexgoon_01',
                                spawnCoords = vector3(-57.6, 6343.3, 30.89),
                                spawnHeading = 44.0,
                                enterVehicleAtMs = 5000,
                            },
                            fleeTarget = vector3(3823.4277, 4464.0933, 2.7149),
                            cinematic = {
                                shots = {
                                    { coords = vector3(-51.0, 6339.0, 32.5), lookAt = vector3(-57.5, 6344.5, 31.5), fov = 42.0, durationMs = 3000 },
                                    { coords = vector3(-45.0, 6337.0, 33.5), lookAt = vector3(-58.0, 6344.0, 31.2), fov = 52.0, durationMs = 3500, interpMs = 1800 },
                                    { coords = vector3(-43.0, 6342.0, 33.0), lookAt = vector3(-60.0, 6346.0, 31.0), fov = 60.0, durationMs = 2500, interpMs = 1500 },
                                },
                                subtitles = {
                                    { atMs = 500,  speaker = 'Tú', body = "Alguien ya está encima.", duration = 2800 },
                                    { atMs = 5800, speaker = 'Tú', body = "Está en el coche. Vamos, vamos.", duration = 2600 },
                                },
                            },
                        },
                        {
                            type = 'chaseVehicle',
                            label = "Stop the thief",
                            requiresFreeroam = true,
                            ramsRequired = 8,
                            chase = { maxDistance = 300.0, lostSeconds = 6 },
                            midMessages = {
                                { delaySeconds = 10, sender = 'Saint', avatar = 'saint',
                                  body = "¿Por qué se mueve el rastreador? Dime que eres tú conduciendo mi coche." },
                                { delaySeconds = 35, sender = 'Saint', avatar = 'saint',
                                  body = "No dejes que ese coche desaparezca. Sácalo de la carretera ya." },
                            },
                            successMessage = {
                                sender = 'Saint', avatar = 'saint',
                                body = "Ese coche era mi dinero y mi salida. Lo acabas de quemar todo, corredor. No me llames.",
                            },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Ese coche era mi dinero y mi salida. Ahora me debes. Dinero real. Trabajo real. No apagues el móvil.",
                    },
                    followUpMessages = {
                        { delaySeconds = 60, sender = 'Hector', avatar = 'hector',
                          body = "Acabo de escuchar lo del coche. ¿Estás bien? Saint no es alguien a quien le quieras deber dinero. Cuídate, brother." },
                    },
                    rewards = { cash = 5000, playerXp = 120 },
                    cooldown = minutes(60),
                },
                -- Mission 6 - Silent Deliveries: three curbside drops, working off the debt. First meet with Gabe.
                {
                    id = 'silent_deliveries',
                    title = 'Silent Deliveries',
                    subtitle = "Tres entregas para bajar una deuda que no perdona.",
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Estás aquí porque me debes. No porque me caigas bien. Muelles, bahía sur. Tres direcciones, una detrás de otra.",
                    },
                    autoStart = true,
                    startBlip = {
                        sprite = 478, color = 46,
                        coords = vector3(1219.7073, -3203.2295, 4.9817),
                        label = 'Elysian Docks - Pick up',
                    },
                    objectives = {
                        {
                            type = 'pickupPackage',
                            coords = vector3(1219.7073, -3203.2295, 4.9817),
                            radius = 2.0,
                            requiresFreeroam = true,
                            label = 'Meet Saint',
                            npc = {
                                model = 'a_m_m_soucent_04',
                                spawnCoords = vector3(1217.5741, -3202.2537, 4.9471),
                                spawnHeading = 178.7515,
                                mode = 'giving',
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = CARRY_BOX_IDLE,
                                walkAnim = CARRY_BOX_WALK,
                                handoffAnim = GIVE_ANIM,
                                handoffDetachMs = 900,
                                dismissReleaseMs = 5000,
                                dismissWalkTarget = vector3(1217.5741, -3202.2537, 4.9471),
                                cinematic = {
                                    title = 'Silent Deliveries',
                                    subtitle = "Tres entregas. Baja la deuda.",
                                    lookAt = SAINT_HUB_LOOKAT,
                                    shots = SAINT_MEETING_SHOTS,
                                    approachAtMs = 9500,
                                    handoffAtMs = 14000,
                                    subtitles = {
                                        { atMs = 400,   speaker = 'Saint', body = "Estás aquí porque me debes. No porque me caigas bien.", duration = 3000, playAnimOnActor = SAINT_CHATTER },
                                        { atMs = 3500,  speaker = 'Saint', body = "Tres direcciones. Una detrás de otra. Sin desvíos.", duration = 4000, playAnimOnActor = SAINT_CHATTER },
                                        { atMs = 8000,  speaker = 'Saint', body = "La última es con Gabe. Si te ofrece algo, no escuchaste nada.", duration = 3500 },
                                        { atMs = 14500, speaker = 'Saint', body = "No lo abras. No lo sueltes.", duration = 2600 },
                                        { atMs = 17400, speaker = 'Saint', body = "El reloj también suma deuda.", duration = 2600, playAnimOnActor = SAINT_CHATTER },
                                    },
                                },
                            },
                        },
                        {
                            type = 'deliverPackage',
                            coords = vector3(-1158.2614, -1530.3967, 3.6524),
                            radius = 3.0,
                            label = 'Drop 1 - Vespucci alley',
                            midMessages = {
                                { delaySeconds = 25, sender = 'Saint', avatar = 'saint',
                                  body = "El skater habla demasiado. No escuches nada." },
                            },
                            npc = {
                                model = 'a_m_y_skater_01',
                                spawnCoords = vector3(-1161.3761, -1532.5765, 4.5354),
                                spawnHeading = 299.5,
                                mode = 'receiving',
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = IMPATIENT_IDLE,
                                idleAfterHandoff = CARRY_BOX_IDLE,
                                handoffAnim = RECEIVE_ANIM,
                                handoffDetachMs = 1100,
                                dismissSpeed = 3.5,
                                deleteOnDismiss = true,
                                dismissWalkTarget = vector3(-1161.3761, -1532.5765, 4.5354),
                                cinematic = {
                                    shots = {
                                        { coords = vector3(-1154.5, -1527.5, 5.8), lookAt = vector3(-1161.0, -1532.5, 5.0), fov = 48.0, durationMs = 3800 },
                                        { coords = vector3(-1155.0, -1535.5, 5.5), lookAt = vector3(-1160.0, -1531.5, 4.8), fov = 54.0, durationMs = 6000, interpMs = 1800 },
                                    },
                                    approachAtMs = 5600,
                                    handoffAtMs = 9500,
                                    subtitles = {
                                        { atMs = 400,  speaker = 'Skater', body = "No te vi. Tú tampoco me viste.", duration = 2600 },
                                        { atMs = 7000, speaker = 'Skater', body = "Dile a Saint que estamos bien.", duration = 2400 },
                                    },
                                },
                            },
                        },
                        {
                            type = 'deliverPackage',
                            coords = vector3(-596.4598, -893.1370, 24.5061),
                            radius = 3.0,
                            label = 'Drop 2 - Lucky Plucker',
                            midMessages = {
                                { delaySeconds = 25, sender = 'Saint', avatar = 'saint',
                                  body = "El siguiente casi no habla. Bien. Haz lo mismo." },
                            },
                            npc = {
                                model = 'a_m_y_business_03',
                                spawnCoords = vector3(-591.4933, -892.5881, 24.9434),
                                spawnHeading = 93.1,
                                mode = 'receiving',
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = IMPATIENT_IDLE,
                                idleAfterHandoff = CARRY_BOX_IDLE,
                                handoffAnim = RECEIVE_ANIM,
                                handoffDetachMs = 1100,
                                dismissSpeed = 3.5,
                                deleteOnDismiss = true,
                                dismissWalkTarget = vector3(-591.4933, -892.5881, 24.9434),
                                cinematic = {
                                    shots = {
                                        { coords = vector3(-599.5, -892.0, 26.0), lookAt = vector3(-592.0, -892.5, 25.5), fov = 48.0, durationMs = 3800 },
                                        { coords = vector3(-594.0, -897.0, 26.5), lookAt = vector3(-593.0, -892.5, 25.0), fov = 54.0, durationMs = 6000, interpMs = 1800 },
                                    },
                                    approachAtMs = 5600,
                                    handoffAtMs = 9500,
                                    subtitles = {
                                        { atMs = 400,  speaker = 'Contacto', body = "Estaba a punto de irme.", duration = 2400 },
                                        { atMs = 7000, speaker = 'Contacto', body = "Esto nunca pasó. Vete.", duration = 2400 },
                                    },
                                },
                            },
                        },
                        {
                            type = 'deliverPackage',
                            coords = vector3(-167.7091, -1427.2803, 31.1595),
                            radius = 5.0,
                            label = 'Drop 3 - Chamberlain Plaza',
                            midMessages = {
                                { delaySeconds = 20, sender = 'Saint', avatar = 'saint',
                                  body = "Gabe. Ojos abiertos. Si algo huele raro, me avisas." },
                            },
                            npc = {
                                model = 'a_m_y_business_03',
                                spawnCoords = vector3(-163.8719, -1422.5677, 31.1875),
                                spawnHeading = 230.0,
                                mode = 'receiving',
                                prop = { model = 'prop_cs_cardbox_01', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = IMPATIENT_IDLE,
                                idleAfterHandoff = CARRY_BOX_IDLE,
                                handoffAnim = RECEIVE_ANIM,
                                handoffDetachMs = 1100,
                                dismissSpeed = 1.5,
                                deleteOnDismiss = true,
                                dismissWalkTarget = vector3(-163.8719, -1422.5677, 31.18755),
                                cinematic = {
                                    shots = {
                                        { coords = vector3(-169.0, -1429.0, 32.5), lookAt = vector3(-164.5, -1423.5, 32.0), fov = 48.0, durationMs = 3800 },
                                        { coords = vector3(-159.5, -1425.5, 33.5), lookAt = vector3(-164.5, -1423.5, 31.8), fov = 54.0, durationMs = 10500, interpMs = 1800 },
                                    },
                                    approachAtMs = 5600,
                                    handoffAtMs = 9500,
                                    subtitles = {
                                        { atMs = 400,   speaker = 'Gabe', body = "Saint te mandó, ¿no? Interesante.", duration = 2400 },
                                        { atMs = 4000,  speaker = 'Gabe', body = "No suele confiar en gente nueva. Tal vez sí eres diferente.", duration = 3500 },
                                        { atMs = 8500,  speaker = 'Gabe', body = "Saint usa a la gente y luego la tira.", duration = 3500 },
                                        { atMs = 12500, speaker = 'Gabe', body = "Todo está ahí dentro, ¿verdad? Todo.", duration = 3000 },
                                        { atMs = 16000, speaker = 'Gabe', body = "Deberíamos hablar algún día. Tú y yo. Sin Saint en medio.", duration = 3500 },
                                    },
                                },
                            },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Trabajo decente. Apenas roza lo que me debes. Ese Gabe... si te sonó raro, bien. A mí también.",
                    },
                    followUpMessages = {
                        { delaySeconds = 180, sender = 'Gabe', avatar = 'gabe',
                          body = "Soy Gabe. Tú eres el nuevo conductor de Saint, ¿no? Si algún día quieres trabajo directo, escríbeme. Entre nosotros: yo pago mejor." },
                    },
                    rewards = { cash = 5000, playerXp = 100 },
                    cooldown = minutes(75),
                    flagsOnComplete = { metGabe = true },
                },
                -- Mission 7 - Midnight Run: timed drop to Chumash. Hector warns you mid-run.
                {
                    id = 'midnight_run',
                    title = 'Midnight Run',
                    subtitle = "Entrega con reloj. Llegar tarde también suma deuda.",
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    autoStart = true,
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Paquete en los muelles. Comprador en Chumash. Cinco minutos de puerta a puerta o el trato se cae y tu deuda sube.",
                    },
                    startBlip = {
                        sprite = 478, color = 46,
                        coords = vector3(1219.7073, -3203.2295, 4.9817),
                        label = 'Start Mission',
                    },
                    objectives = {
                        {
                            type = 'pickupPackage',
                            coords = vector3(1219.7073, -3203.2295, 4.9817),
                            radius = 2.0,
                            requiresFreeroam = true,
                            label = 'Meet Saint',
                            npc = {
                                model = 'a_m_m_soucent_04',
                                spawnCoords = vector3(1217.5741, -3202.2537, 4.9471),
                                spawnHeading = 178.7515,
                                mode = 'giving',
                                prop = { model = 'hei_prop_heist_box', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = CARRY_BOX_IDLE,
                                walkAnim = CARRY_BOX_WALK,
                                handoffAnim = GIVE_ANIM,
                                handoffDetachMs = 700,
                                dismissReleaseMs = 5000,
                                dismissWalkTarget = vector3(1217.5741, -3202.2537, 4.9471),
                                cinematic = {
                                    lookAt = SAINT_HUB_LOOKAT,
                                    shots = {
                                        { coords = vector3(1224.0, -3209.0, 7.2), lookAt = vector3(1217.6, -3202.3, 5.3), fov = 40.0, durationMs = 3200 },
                                        { coords = vector3(1220.0, -3207.0, 5.9), lookAt = vector3(1217.5, -3202.4, 5.3), fov = 32.0, durationMs = 3800, interpMs = 1600 },
                                    },
                                    approachAtMs = 1500,
                                    handoffAtMs = 5000,
                                    subtitles = {
                                        { atMs = 300,  speaker = 'Saint', body = "Para mí eso es tarde.", duration = 2200, playAnimOnActor = SAINT_CHATTER },
                                        { atMs = 5500, speaker = 'Saint', body = "Chumash. Cinco minutos. La autopista está caliente.", duration = 2500 },
                                    },
                                },
                            },
                        },
                        {
                            type = 'deliverPackage',
                            coords = vector3(-3177.7422, 1292.0769, 13.6516),
                            radius = 5.0,
                            label = 'Chumash - 5 minutes',
                            timerSeconds = 300,
                            midMessages = {
                                { delaySeconds = 30, sender = 'Hector', avatar = 'hector',
                                  body = "Escuché que andas demasiado metido con Saint. Eso no era lo que quería para ti." },
                                { delaySeconds = 75, sender = 'Hector', avatar = 'hector',
                                  body = "Él no deja que la gente se vaya. Cuídate." },
                                { delaySeconds = 150, sender = 'Saint', avatar = 'saint',
                                  body = "El comprador se está cansando. Si no llegas, tú pierdes paz." },
                            },
                            npc = {
                                model = 'a_m_m_hasjew_01',
                                spawnCoords = vector3(-3190.9475, 1297.7535, 19.0674),
                                spawnHeading = 245.4587,
                                mode = 'receiving',
                                prop = { model = 'hei_prop_heist_box', bone = HAND_BONE, offset = DEFAULT_PROP_OFFSET, rot = DEFAULT_PROP_ROT },
                                idleWait = IMPATIENT_IDLE,
                                handoffAnim = RECEIVE_ANIM,
                                handoffDetachMs = 900,
                                dismissWalkTarget = vector3(-3190.9475, 1297.7535, 19.0674),
                                deleteOnDismiss = true,
                                chatter = {
                                    { speaker = 'Comprador', body = "¿Por qué tardaste tanto?", duration = 2200, atMs = 200 },
                                    { speaker = 'Comprador', body = "Están mirando las carreteras. Sal de aquí.", duration = 2600, atMs = 2400 },
                                },
                            },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "A tiempo. Digamos que pagaste intereses. Uno de los míos está demasiado nervioso. Pronto voy a necesitar tus ojos.",
                    },
                    rewards = { cash = 6000, playerXp = 120 },
                    cooldown = minutes(90),
                },
                -- Mission 8 - Paranoid: tail Gabe from the Diamond Casino to his meeting at Davis Quartz.
                {
                    id = 'paranoid',
                    title = 'Paranoid',
                    subtitle = "Sigue a Gabe. No dejes que te vea.",
                    resetOnLoad = true,
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    autoStart = true,
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Gabe lleva toda la noche en el Diamond. Ve, aparca tranquilo y síguelo. Si te ve, se acabó.",
                    },
                    startBlip = {
                        sprite = 280, color = 46,
                        coords = vector3(882.0499, 4.1199, 78.1681),
                        label = 'Diamond Casino - stake out',
                    },
                    objectives = {
                        {
                            type = 'tailNpc',
                            label = "Sigue a Gabe. Mantén distancia.",
                            requiresFreeroam = true,
                            parkCoords = vector3(882.0499, 4.1199, 78.1681),
                            spawnRadius  = 80,
                            triggerRadius = 8,
                            midMessages = {
                                { delaySeconds = 60, sender = 'Saint', avatar = 'saint',
                                  body = "¿Sigues con él?" },
                                { delaySeconds = 150, sender = 'Saint', avatar = 'saint',
                                  body = "¿A dónde demonios va?" },
                            },
                            introScene = {
                                doorCoords = vector4(925.0579, 46.4513, 80.5579, 59.2200),
                            },
                            target = {
                                pedModel     = 'a_m_y_business_03',
                                vehicleModel = 'gauntlet',
                                startCoords  = vector4(913.3068, 52.6480, 80.3580, 329.1611),
                            },
                            meeting = {
                                coords      = vector3(2522.2754, 2609.8525, 37.3457),
                                copPedModel = 's_m_y_cop_01',
                                cutsceneId  = 'chapter1/gabe_meets_vargas',
                                driveSpeed  = 40.0,
                            },
                            safeZone   = { minDistance = 15.0, maxDistance = 55.0 },
                            dangerZone = { tooCloseDistance = 10.0, tooFarDistance = 100.0 },
                            detection  = { lostSeconds = 10.0 },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Gabe está hablando con policías. Lo sabía. No lo contactes. No te acerques. Yo me encargo de esto.",
                    },
                    rewards = { cash = 8000, playerXp = 150 },
                    cooldown = minutes(90),
                    flagsOnComplete = { sawGabeMeet = true },
                },
                {
                    id = 'smugglers_run',
                    title = 'Smuggler\'s Run',
                    subtitle = "Una recogida pequeña. Demasiado limpia para ser verdad.",
                    autoStart = true,
                    resetOnLoad = true,
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Paquete pequeño pegado debajo de un buzón downtown. Entras y sales. Limpio.",
                    },
                    startBlip = {
                        sprite = 51, color = 1,
                        coords = vector3(357.7319, -841.8331, 28.5649),
                        label = "Mailbox pickup",
                    },
                    objectives = {
                        {
                            type = 'pickupPackage',
                            coords = vector3(357.7319, -841.8331, 28.5649),
                            radius = 4.0,
                            label = 'Pick up the parcel',
                        },
                        {
                            type = 'escape',
                            stars = 3,
                            label = 'Lose the heat',
                            trapCop = {
                                vehicleModel = 'police3',
                                pedModel     = 's_m_y_cop_01',
                                coords       = vector4(368.0840, -833.9969, 28.6944, 179.4527),
                            },
                            midMessages = {
                                { delaySeconds = 15, sender = 'Número desconocido', avatar = 'unknown',
                                  body = "Te vemos, corredor. Detente." },
                                { delaySeconds = 30, sender = 'Saint', avatar = 'saint',
                                  body = "No pares." },
                                { delaySeconds = 45, sender = 'Número desconocido', avatar = 'unknown',
                                  body = "Sabemos lo que llevas. Última oportunidad." },
                            },
                        },
                    },
                    endMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "No dije que sería cómodo. Dije que sería limpio. Una más y tu deuda desaparece. Es grande, pero después de esto no me debes nada.",
                    },
                    followUpMessages = {
                        { delaySeconds = 90, sender = 'Hector', avatar = 'hector',
                          body = "Eso no salió en las noticias... pero debió salir. ¿En qué demonios estás metido? Llámame. Hablo en serio, brother." },
                    },
                    rewards = { cash = 0, playerXp = 0 },
                    cooldown = NO_COOLDOWN,
                    flagsOnComplete = { heatRising = true },
                },
                {
                    id = 'the_arrest',
                    title = 'The Big Score',
                    subtitle = "Una última deuda. Un banco. Una trampa.",
                    autoStart = true,
                    resetOnLoad = true,
                    giver = { name = 'Saint', avatar = 'saint', color = 46 },
                    unlockMessage = {
                        sender = 'Saint', avatar = 'saint',
                        body = "Última, corredor. Blaine County Savings, Paleto. Mi crew entra a las nueve. Tú esperas fuera, motor encendido. Haces esto y tu deuda muere.",
                    },
                    unlockFollowUps = {
                        { delaySeconds = 25, sender = 'Hector', avatar = 'hector',
                          body = "Saint me acaba de decir lo que vas a hacer. Dime que no es verdad. Es un banco, brother. Un BANCO. Llámame ya." },
                        { delaySeconds = 90, sender = 'Hector', avatar = 'hector',
                          body = "Vale. No contestas. Mira los espejos. Lo digo en serio." },
                    },
                    startBlip = {
                        sprite = 500, color = 46,
                        coords = vector3(-115.1128, 6457.5312, 30.8683),
                        label = "Paleto - Blaine County Savings",
                    },
                    objectives = {
                        {
                            type = 'getawayPickup',
                            coords = vector3(-115.1128, 6457.5312, 30.8683),
                            triggerRadius = 12.0,
                            label = 'Pull up at the bank',
                            bankAlarm = 'PALETO_BAY_SCORE_ALARM',
                            wantedStars = 4,
                            robbers = {
                                {
                                    model = 's_m_y_pestcont_01',
                                    storeSpawn = vector3(-110.9287, 6462.8311, 31.6408),
                                    storeHeading = 129.9755,
                                    seatIndex = 0,
                                    weapon = 'WEAPON_PISTOL',
                                    delayMs = 0,
                                },
                            },
                            chatter = {
                                { speaker = 'Atracador', body = "¡DALE! ¡DALE, DALE! ¡PÍSALE!",                  duration = 2000, atMs = 400 },
                                { speaker = 'Tú',        body = "¿Dónde está el resto de la crew?",               duration = 2200, atMs = 2800 },
                                { speaker = 'Atracador', body = "¡Los policías ya estaban esperando!",           duration = 2400, atMs = 5400 },
                                { speaker = 'Tú',        body = "Saint dijo que era limpio.",                    duration = 2200, atMs = 8200 },
                                { speaker = 'Atracador', body = "¿Esto te parece limpio? ¡Sácanos de aquí!",     duration = 2400, atMs = 10800 },
                                { speaker = 'Tú',        body = "Agárrate. Los voy a perder.",                   duration = 1800, atMs = 13600 },
                            },
                        },
                        {
                            type = 'escape',
                            stars = 4,
                            label = 'Lose the heat',
                            bankAlarmTimeout = 90,
                            bankAlarm = 'PALETO_BAY_SCORE_ALARM',
                            midMessages = {
                                { delaySeconds = 10, sender = 'Saint', avatar = 'saint',
                                  body = "Sigue moviéndote. No pares por nada." },
                                { delaySeconds = 30, sender = 'Hector', avatar = 'hector',
                                  body = "Estoy escuchando el scanner. Tienes medio condado encima. Piérdelos, brother." },
                                { delaySeconds = 60, sender = 'Número desconocido', avatar = 'unknown',
                                  body = "Te vemos. Detente ahora." },
                            },
                        },
                        {
                            type = 'getawayRide',
                            dropoffCoords = vector3(-454.3148, -1709.1023, 18.1301),
                            arrivalRadius = 22.0,
                            label = 'Head to the scrapyard',
                            noExitVehicle = true,
                            midMessages = {
                                { delaySeconds = 8, sender = 'Saint', avatar = 'saint',
                                  body = "Los perdiste. Bien. Ve al desguace, sur de LS. Tendré la puerta abierta." },
                                { delaySeconds = 40, sender = 'Saint', avatar = 'saint',
                                  body = "Ya casi, corredor. Último tramo." },
                                { delaySeconds = 70, sender = 'Número desconocido', avatar = 'unknown',
                                  body = "Baja la velocidad al llegar al desguace. Tenemos que hablar." },
                            },
                            chatter = {
                                { speaker = 'Atracador', body = "...vale. Vale. Creo que los perdimos.",                    duration = 2800, atMs = 4000 },
                                { speaker = 'Tú',        body = "Habla. ¿Qué pasó ahí dentro?",                             duration = 2800, atMs = 8000 },
                                { speaker = 'Atracador', body = "Entramos limpios. Máscaras puestas, puestos tomados.",      duration = 3400, atMs = 12000 },
                                { speaker = 'Atracador', body = "Y de pronto se abren las puertas traseras. Placas por todas partes.", duration = 3200, atMs = 16000 },
                                { speaker = 'Tú',        body = "Eso no fue respuesta rápida. Eso fue una emboscada.",       duration = 3200, atMs = 20000 },
                                { speaker = 'Atracador', body = "Te lo digo: ya nos estaban esperando.",                    duration = 3000, atMs = 24000 },
                                { speaker = 'Tú',        body = "Entonces, ¿cómo saliste?",                                  duration = 2200, atMs = 28000 },
                                { speaker = 'Atracador', body = "El policía miró hacia ti cuando llegaste y yo corrí.",      duration = 3000, atMs = 31000 },
                                { speaker = 'Tú',        body = "¿Y los otros?",                                             duration = 1800, atMs = 35000 },
                                { speaker = 'Atracador', body = "No salieron.",                                              duration = 2000, atMs = 37500 },
                                { speaker = 'Tú',        body = "Todo esto fue una trampa.",                                 duration = 1500, atMs = 40000 },
                                { speaker = 'Atracador', body = "¿Notas lo callado que está? Sin helicópteros. Sin scanner.", duration = 3600, atMs = 52000 },
                                { speaker = 'Tú',        body = "Quizá tuvimos suerte.",                                     duration = 2200, atMs = 55000 },
                                { speaker = 'Atracador', body = "Nadie tiene tanta suerte después de tocar un banco.",       duration = 3600, atMs = 60000 },
                                { speaker = 'Atracador', body = "Nos dejaron correr.",                                       duration = 3000, atMs = 64000 },
                                { speaker = 'Tú',        body = "¿Crees que nos están siguiendo?",                          duration = 2400, atMs = 68000 },
                                { speaker = 'Atracador', body = "Creo que alguien hizo un trato. Y no fui yo.",              duration = 3200, atMs = 72000 },
                                { speaker = 'Tú',        body = "...Saint no haría eso.",                                   duration = 2400, atMs = 76000 },
                                { speaker = 'Atracador', body = "¿No? ¿Quién eligió el banco? ¿Quién eligió la crew?",      duration = 3200, atMs = 80000 },
                                { speaker = 'Atracador', body = "¿Quién te eligió a ti?",                                   duration = 2000, atMs = 83000 },
                                { speaker = 'Tú',        body = "Eso no significa nada.",                                    duration = 2400, atMs = 87000 },
                                { speaker = 'Tú',        body = "Cállate. Ya casi llegamos.",                                duration = 2200, atMs = 90000 },
                            },
                        },
                        {
                            type = 'finaleArrest',
                            label = 'The Arrest',
                            trapCop = vector4(-431.6012, -1698.3486, 18.4031, 145.4423),
                            extraCops = {
                                vector4(-469.4654, -1677.1732, 18.4585, 188.9196),
                                vector4(-477.9308, -1734.8066, 18.0272, 291.0810),
                                vector4(-405.8403, -1710.9425, 18.2953, 106.8606),
                            },
                            cellPlayer = vector4(460.9878, -993.8979, 24.9149, 259.6089),
                            cellGabe   = vector4(463.0714, -995.0804, 24.9149, 44.0477),
                            cellVargas = vector4(462.7513, -993.6442, 24.9149, 91.3182),
                        },
                    },
                    endMessage = {
                        sender = 'Gabe', avatar = 'gabe',
                        body = "Descansa, corredor. Mañana empiezas a conducir para nosotros. - Det. G. Reyes\n\nEn Los Santos, no pierdes cuando te arrestan. Pierdes cuando alguien más decide por quién corres.",
                    },
                    rewards = { cash = 0, playerXp = 0 },
                    cooldown = NO_COOLDOWN,
                    flagsOnComplete = { chapter1Complete = true, informantForced = true },
                    finale = true,
                },
            },
        },
    },
}

local MISSION_TEXT_KEYS = {
    ['Entry Level'] = 'entry_level',
    ['Casing the Streets'] = 'casing_the_streets',
    ['Learn the city before you race it.'] = 'learn_city',
    ['Vinewood Overlook'] = 'vinewood_overlook',
    ['Take it in'] = 'take_it_in',
    ['Visit the Visual Mods Shop'] = 'visit_visual_shop',
    ['Listen Up!'] = 'listen_up',
    ['Visit the Performance Shop'] = 'visit_performance_shop',
    ['Visit the Tuner Dealership'] = 'visit_tuner_dealership',
    ['Visit Binco'] = 'visit_binco',
    ['Wrap up the tour'] = 'wrap_tour',
    ['Local Legend'] = 'local_legend',
    ['First impression. Make it count.'] = 'first_impression',
    ['Car Meet'] = 'car_meet',
    ['Head to the Car Meet'] = 'head_car_meet',
    ['"Do A Burnout" next to any racer to challenge them to a race!'] = 'do_burnout_challenge',
    ['Post a time on any track'] = 'post_time_any_track',
    ['Off the Line'] = 'off_the_line',
    ['Put the Rockford guy in his place.'] = 'rockford_subtitle',
    ['Rockford Smash - Race Start'] = 'rockford_race_start',
    ['Meet the rival'] = 'meet_rival',
    ['Win the Rockford Smash'] = 'win_rockford',
    ['Meeting Saint'] = 'meeting_saint',
    ['A favor for Hector.'] = 'favor_for_hector',
    ['Elysian Docks - Loading bay'] = 'elysian_loading_bay',
    ['Meet Saint'] = 'meet_saint',
    ['Drop at Sandy Shores'] = 'drop_sandy',
    ['Sandy Shores Drop'] = 'sandy_drop',
    ['Drop-Car Pickup'] = 'drop_car_pickup',
    ['Collect the drop-car in Paleto.'] = 'collect_drop_car',
    ['Paleto - parking lot'] = 'paleto_parking',
    ['Silent Deliveries'] = 'silent_deliveries',
    ['Elysian Docks - Pick up'] = 'elysian_pickup',
    ['Drop 1 - Vespucci alley'] = 'drop_vespucci',
    ['Drop 2 - Lucky Plucker'] = 'drop_lucky_plucker',
    ['Drop 3 - Chamberlain Plaza'] = 'drop_chamberlain',
    ['Midnight Run'] = 'midnight_run',
    ['Start Mission'] = 'start_mission',
    ['Chumash - 5 minutes'] = 'chumash_five',
    ['Paranoid'] = 'paranoid',
    ['Diamond Casino - stake out'] = 'casino_stakeout',
    ["Smuggler's Run"] = 'smugglers_run',
    ['Pick up the parcel'] = 'pick_up_parcel',
    ['Lose the heat'] = 'lose_heat',
    ['The Big Score'] = 'the_big_score',
    ['Pull up at the bank'] = 'pull_up_bank',
    ['Head to the scrapyard'] = 'head_scrapyard',
    ['The Arrest'] = 'the_arrest',
}

local function missionText(value)
    if type(value) ~= 'string' then return value end
    local textKey = MISSION_TEXT_KEYS[value]
    if not textKey then return value end
    local localeKey = 'content.mission_text.' .. textKey
    local localized = _L(localeKey)
    if localized == localeKey then return value end
    return localized
end

local function localizeMissionNode(node)
    if type(node) ~= 'table' then return end
    if node.title then node.title = missionText(node.title) end
    if node.subtitle then node.subtitle = missionText(node.subtitle) end
    if node.label then node.label = missionText(node.label) end

    for _, value in pairs(node) do
        if type(value) == 'table' then
            localizeMissionNode(value)
        end
    end
end

localizeMissionNode(SKMissions)
