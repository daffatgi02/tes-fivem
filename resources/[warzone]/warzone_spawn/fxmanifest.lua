-- resources/[warzone]/warzone_spawn/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Dynamic Spawn System'
version '1.0.0'

shared_scripts {
    '@warzone_core/shared/utils.lua',
    'shared/spawn_data.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@warzone_core/config/main.lua',
    'server/config_loader.lua',
    'server/spawn_manager.lua',
    'server/queue_system.lua',
    'server/safety_checker.lua'
}

client_scripts {
    '@warzone_core/config/main.lua',
    'client/config_loader.lua',
    'client/spawn_map.lua',
    'client/spawn_ui.lua',
    'client/location_preview.lua'
}

ui_page 'html/index.html'

files {
    'config/spawn_config.json',
    'config/locations_config.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/map.js'
}

dependencies {
    'warzone_core',
    'warzone_zones',
    'warzone_crew',
    'warzone_combat',
    'es_extended',
    'oxmysql'
}

lua54 'yes'