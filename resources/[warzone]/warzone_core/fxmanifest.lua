-- resources/[warzone]/warzone_core/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Core Framework'
version '1.0.0'

shared_scripts {
    'shared/utils.lua',
    'shared/functions.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/main.lua',
    'config/zones.lua',
    'config/weapons.lua',
    'config/spawns.lua',
    'config/roles.lua',
    'server/database.lua',
    'server/main.lua',
    'server/player.lua',
    'server/events.lua'
}

client_scripts {
    'config/main.lua',
    'config/zones.lua',
    'config/weapons.lua',
    'config/spawns.lua',
    'config/roles.lua',
    'client/main.lua',
    'client/ui.lua',
    'client/combat.lua',
    'client/spawn.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'esx_notify'
}

lua54 'yes'