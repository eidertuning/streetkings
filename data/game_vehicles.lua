---@class GameVehicle
---@field model string
---@field price integer
---@field class string 'C'|'B'|'A'|'S'

---@class StarterGameVehicleStats
---@field topSpeed integer
---@field accel integer
---@field handling integer
---@field braking integer

---@class StarterGameVehicle
---@field model string
---@field displayName string
---@field brand string
---@field vehicleType string
---@field value integer
---@field class string
---@field stats StarterGameVehicleStats

---@type StarterGameVehicle[]
SKStarterVehicles = {
    { model = 'tulip2', displayName = 'Tulip M-100', brand = 'Declasse', vehicleType = 'automobile', value = 5000, class = 'STARTER', stats = { topSpeed = 6, accel = 5, handling = 5, braking = 5 } },
    { model = 'nebula', displayName = 'Nebula Turbo', brand = 'Vulcar', vehicleType = 'automobile', value = 5000, class = 'STARTER', stats = { topSpeed = 5, accel = 5, handling = 6, braking = 5 } },
    { model = 'kanjosj', displayName = 'Kanjo SJ', brand = 'Dinka', vehicleType = 'automobile', value = 5000, class = 'STARTER', stats = { topSpeed = 6, accel = 6, handling = 6, braking = 5 } },
}

---@type table<string, StarterGameVehicle>
SKStarterVehiclesByModel = {}

for _, vehicle in ipairs(SKStarterVehicles) do
    SKStarterVehiclesByModel[vehicle.model] = vehicle
end

---@type table<string, GameVehicle[]>
SKGameVehicles = {

    tuner = {
        -- C class
        { model = 'issi3',     price = 14000,  class = 'C' }, -- Weeny Issi Classic
        { model = 'club',      price = 15000,  class = 'C' }, -- BF Club
        { model = 'warrener2', price = 16000,  class = 'C' }, -- Vulcar Warrener HKR
        { model = 'asterope2', price = 17000,  class = 'C' }, -- Karin Asterope GZ
        { model = 'futo2',     price = 19500,  class = 'C' }, -- Karin Futo GTX
        { model = 'iwagen',    price = 19500,  class = 'C' }, -- Obey I-Wagen
        { model = 'kanjo',     price = 20000,  class = 'C' }, -- Dinka Blista Kanjo
        { model = 'postlude',  price = 23500,  class = 'C' }, -- Dinka Postlude
        { model = 'zion3',     price = 25500,  class = 'C' }, -- Übermacht Zion Classic
        -- B class
        { model = 'kuruma',    price = 29000,  class = 'B' }, -- Karin Kuruma
        { model = 'sultan2',   price = 36000,  class = 'B' }, -- Karin Sultan RS
        { model = 'sugoi',     price = 38000,  class = 'B' }, -- Dinka Sugoi
        { model = 'jester3',   price = 40500,  class = 'B' }, -- Annis Jester Classic
        { model = 'flashgt',   price = 42500,  class = 'B' }, -- Vapid Flash GT
        { model = 'previon',   price = 45000,  class = 'B' }, -- Karin Previon
        { model = 'eurosx32',  price = 47000,  class = 'B' }, -- Annis Euros X32
        { model = 'rt3000',    price = 48000,  class = 'B' }, -- Dinka RT3000
        { model = 'chavosv6',  price = 50000,  class = 'B' }, -- Dinka Chavos V6
        { model = 'tailgater2', price = 51000, class = 'B' }, -- Obey Tailgater S
        { model = 'zr350',     price = 55000,  class = 'B' }, -- Annis ZR350
        -- A class
        { model = 'uranus',   price = 57500,  class = 'A' }, -- Vapid Uranus LozSpeed
        { model = 'euros',     price = 58500,  class = 'A' }, -- Annis Euros
        { model = 'sultan3',   price = 61500, class = 'A' }, -- Karin Sultan Classic Custom
        { model = 'minimus',    price = 63000, class = 'A' }, -- Annis Minimus
        { model = 'cypher',    price = 65000, class = 'A' }, -- Übermacht Cypher
        { model = 'fr36',      price = 66000, class = 'A' }, -- Fathom FR36
        { model = 'hardy',     price = 66000, class = 'A' }, -- Annis Hardy
        { model = 'penumbra2', price = 67500, class = 'A' }, -- Maibatsu Penumbra FF
        -- S class
        { model = 'woodlander',  price = 70000,  class = 'S' }, -- Karin Woodlander
        { model = 'calico',    price = 73500, class = 'S' }, -- Karin Calico GTF
        { model = 'remus',     price = 77500, class = 'S' }, -- Annis Remus
        { model = 'vectre',    price = 83000, class = 'S' }, -- Emperor Vectre
        { model = 'italigto',  price = 85000, class = 'S' }, -- Grotti Itali GTO
        { model = 'jester4',   price = 88500, class = 'S' }, -- Dinka Jester RR
    },

    sportscar = {
        -- B class
        { model = 'khamelion',      price = 49000,  class = 'B' }, -- Hijak Khamelion
        { model = 'voltic',     price = 51500,  class = 'B' }, -- Coil Voltic
        { model = 'neon', price = 57000, class = 'B' }, -- Pfister Neon
        { model = 'imorgon', price = 61000, class = 'B' }, -- Överflöd Imorgon
        { model = 'sentinel6',  price = 62000,  class = 'B' }, -- Übermacht Sentinel 6
        { model = 'vorschlaghammer', price = 64500, class = 'B' }, -- Benefactor Vorschlaghammer
        -- A class
        { model = 'schlagen',   price = 75000,  class = 'A' }, -- Benefactor Schlagen GT
        { model = 'comet5',     price = 82500, class = 'A' }, -- Pfister Comet SR
        { model = 'growler',    price = 86000, class = 'A' }, -- Maibatsu Growler
        { model = 'itali2',    price = 87000, class = 'A' }, -- Grotti Itali Classic
        { model = 'cyclone', price = 89000, class = 'A' }, -- Coil Cyclone
        -- S class
        { model = 'comet6',     price = 91000, class = 'S' }, -- Pfister Comet S2
        { model = 'tempesta', price = 91500, class = 'S' }, -- Pegassi Tempesta
        { model = 'torero2',     price = 92000, class = 'S' }, -- Pegassi Torero XO
        { model = 'sentinel5',  price = 95000, class = 'S' }, -- Übermacht Sentinel GTS
        { model = 'banshee3', price = 97000, class = 'S' }, -- Bravado Banshee GTS
        { model = 'coquette6',  price = 100500, class = 'S' }, -- Invetero Coquette D5
    },

    muscle = {
        -- C class
        { model = 'ruiner',    price = 11000,  class = 'C' }, -- Imponte Ruiner
        { model = 'blade',     price = 12000,  class = 'C' }, -- Vapid Blade
        { model = 'moonbeam',  price = 13000,  class = 'C' }, -- Declasse Moonbeam
        { model = 'gauntlet3', price = 15500,  class = 'C' }, -- Bravado Gauntlet Classic
        { model = 'impaler', price = 18000,  class = 'C' }, -- Declasse Impaler
        { model = 'ellie', price = 23000,  class = 'C' }, -- Vapid Ellie
        -- B class
        { model = 'vigero',    price = 25500,  class = 'B' }, -- Declasse Vigero
        { model = 'gauntlet',  price = 28500,  class = 'B' }, -- Bravado Gauntlet
        { model = 'greenwood', price = 30500,  class = 'B' }, -- Bravado Greenwood
        { model = 'tampa',     price = 32500,  class = 'B' }, -- Declasse Tampa
        { model = 'dominator10', price = 35000, class = 'B' }, -- Vapid Dominator FX
        { model = 'dominator8', price = 36000, class = 'B' }, -- Vapid Dominator GTT
        { model = 'impaler5',  price = 43000,  class = 'B' }, -- Declasse Impaler SZ
        -- A class
        { model = 'gauntlet5', price = 47500,  class = 'A' }, -- Bravado Gauntlet Classic
        { model = 'dominator9', price = 56000, class = 'A' }, -- Vapid Dominator GT
        { model = 'gauntlet4',  price = 59000, class = 'A' }, -- Bravado Gauntlet Hellfire
        { model = 'dominator7', price = 60000, class = 'A' }, -- Vapid Dominator ASP
        -- S class
        { model = 'vigero2',   price = 73000, class = 'S' }, -- Declasse Vigero ZX
        { model = 'buffalo4',  price = 75000, class = 'S' }, -- Bravado Buffalo STX
    },

    offroad = {
        -- C class
        { model = 'yosemite1500', price = 12000,  class = 'C' }, -- Declasse Yosemite 1500
        { model = 'l35', price = 14000,  class = 'C' }, -- Walton L35
        { model = 'patriot3',  price = 17500,  class = 'C' }, -- Mammoth Patriot Mil-Spec
        -- B class
        { model = 'kamacho',      price = 28000, class = 'B' }, -- Canis Kamacho
        { model = 'freecrawler',  price = 35500, class = 'B' }, -- Canis Freecrawler
        { model = 'aleutian',        price = 38500, class = 'B' }, -- Vapid Aleutian
        { model = 'astron',        price = 40000, class = 'B' }, -- Pfister Astron
        -- A class
        { model = 'caracara2',  price = 53500,  class = 'A' }, -- Vapid Caracara
        { model = 'firebolt', price = 54500,  class = 'A' }, -- Vapid Firebolt
        { model = 'castigator',    price = 55500, class = 'A' }, -- Canis Castigator
        { model = 'monstrociti',   price = 56500, class = 'A' }, -- Maibatsu MonstroCiti
        -- S class
        { model = 'novak',      price = 58500, class = 'S' }, -- Lampadati Novak
        { model = 'jubilee',    price = 59500, class = 'S' }, -- Enus Jubilee
        { model = 'everon3',   price = 66000, class = 'S' }, -- Karin Everon RS
        { model = 'toros',     price = 82500, class = 'S' }, -- Pegassi Toros
    },
}
