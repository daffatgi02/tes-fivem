-- resources/[warzone]/warzone_combat/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'WARZONE INDONESIA DEV TEAM'
description 'Warzone Indonesia - Advanced Combat System'
version '1.0.0'

shared_scripts {
    '@warzone_core/shared/utils.lua',
    'shared/combat_data.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@warzone_core/config/main.lua',
    'server/config_loader.lua',
    'server/damage.lua',
    'server/weapons.lua',
    'server/armor.lua',
    'server/roles.lua'
}

client_scripts {
    '@warzone_core/config/main.lua',
    'client/config_loader.lua',
    'client/combat.lua',
    'client/weapons.lua',
    'client/armor.lua',
    'client/roles.lua',
    'client/attachments.lua'
}

files {
    'config/combat_config.json',
    'config/weapons_config.json',
    'config/roles_config.json',
    'config/armor_config.json',
    'config/attachments_config.json'
}

dependencies {
    'warzone_core',
    'warzone_zones',
    'warzone_crew',
    'es_extended',
    'oxmysql'
}

lua54 'yes'