fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vexxd_radio'
author 'Vexxd Scripts'
version '1.2.1'
description 'Handheld radio for pma-voice. Standalone or QBCore, Qbox, ESX discord.gg/TzNJ6Z92Y5 for support'

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'locale.lua',
}

client_scripts {
    'client/voice.lua',
    'client/main.lua',
    'client/list.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/inventory.lua',
    'server/list.lua',
    'server/main.lua',
    'server/guard.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/sounds/*',
}

dependency 'pma-voice'
