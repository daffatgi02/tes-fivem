-- resources/[warzone]/warzone_economy/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Economy System'
version '1.0.0'

shared_scripts {
    '@warzone_core/shared/utils.lua',
    'shared/economy_data.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@warzone_core/config/main.lua',
    'server/config_loader.lua',
    'server/economy_manager.lua',
    'server/shop_system.lua',
    'server/loot_system.lua',
    'server/anti_farm.lua'
}

client_scripts {
    '@warzone_core/config/main.lua',
    'client/config_loader.lua',
    'client/shop_ui.lua',
    'client/loot_ui.lua',
    'client/economy_hud.lua'
}

ui_page 'html/index.html'

files {
    'config/economy_config.json',
    'config/shops_config.json',
    'config/loot_config.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'warzone_core',
    'warzone_zones',
    'warzone_crew',
    'warzone_combat',
    'warzone_spawn',
    'es_extended',
    'oxmysql'
}

lua54 'yes'