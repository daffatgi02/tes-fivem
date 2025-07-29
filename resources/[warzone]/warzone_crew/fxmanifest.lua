-- resources/[warzone]/warzone_crew/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Crew System'
version '1.0.0'

shared_scripts {
    '@warzone_core/shared/utils.lua',
    'shared/crew_utils.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@warzone_core/config/main.lua',
    'config.lua',
    'server/crew.lua',
    'server/radio.lua',
    'server/permissions.lua'
}

client_scripts {
    '@warzone_core/config/main.lua',
    'config.lua',
    'client/crew_ui.lua',
    'client/hud.lua',
    'client/radio.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'warzone_core',
    'warzone_zones',
    'pma-voice',
    'es_extended',
    'oxmysql'
}

lua54 'yes'