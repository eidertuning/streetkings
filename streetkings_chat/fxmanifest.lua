fx_version 'cerulean'
game 'gta5'

author 'Code Eider'
description 'StreetKings standalone freeroam chat'
version '1.0.0'

dependency 'streetkings'

shared_script 'config.lua'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
