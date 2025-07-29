-- resources/[warzone]/warzone_zones/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Zone Management System'
version '1.0.0'

shared_scripts {
    '@warzone_core/shared/utils.lua',
    'shared/zones_data.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@warzone_core/config/main.lua',
    '@warzone_core/config/zones.lua',
    'config.lua',
    'server/zones.lua',
    'server/activity.lua'
}

client_scripts {
    '@warzone_core/config/main.lua',
    '@warzone_core/config/zones.lua',
    'config.lua',
    'client/zones.lua',
    'client/blips.lua',
    'client/notifications.lua'
}

dependencies {
    'warzone_core',
    'es_extended',
    'oxmysql'
}

lua54 'yes'