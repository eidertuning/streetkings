fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'CodeEider'
description 'Five Horizon Admin Tablet App - secure live control room'
version '46.0.0'

dependency 'streetkings'

-- Hidden NUI: only runs the invisible broadcaster canvas on every client.
-- The visible admin UI is loaded as an external app inside the official Five Horizon tablet.
ui_page 'html/hidden.html'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/hidden.html',
    'html/hidden_live.js',
    'html/index.html',
    'html/style.css',
    'html/fh-skin.css',
    'html/app.js',
    'html/assets/weather/sun.svg',
    'html/assets/weather/moon.svg',
    'html/assets/weather/cloudy.svg',
    'html/assets/weather/stars.svg',
    'html/assets/sounds/tsunami_siren.ogg',
    'html/assets/credits/tsunami_siren_attribution.txt'
}
