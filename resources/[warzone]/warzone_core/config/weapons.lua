-- resources/[warzone]/warzone_core/config/weapons.lua
Config.Weapons = {}

-- Weapon Categories
Config.WeaponCategories = {
    ["pistol"] = {
        label = "Pistols",
        weapons = {
            {hash = `WEAPON_PISTOL`, name = "Pistol", price = 500, ammo = 250},
            {hash = `WEAPON_COMBATPISTOL`, name = "Combat Pistol", price = 750, ammo = 250},
            {hash = `WEAPON_PISTOL50`, name = "Pistol .50", price = 1000, ammo = 200}
        }
    },
    ["assault"] = {
        label = "Assault Rifles",
        weapons = {
            {hash = `WEAPON_ASSAULTRIFLE`, name = "Assault Rifle", price = 2000, ammo = 300},
            {hash = `WEAPON_CARBINERIFLE`, name = "Carbine Rifle", price = 2200, ammo = 300},
            {hash = `WEAPON_SPECIALCARBINE`, name = "Special Carbine", price = 2500, ammo = 300}
        }
    },
    ["heavy"] = {
        label = "Heavy Weapons",
        weapons = {
            {hash = `WEAPON_PUMPSHOTGUN`, name = "Pump Shotgun", price = 1500, ammo = 150},
            {hash = `WEAPON_ASSAULTSHOTGUN`, name = "Assault Shotgun", price = 2000, ammo = 200}
        }
    },
    ["lmg"] = {
        label = "Light Machine Guns",
        weapons = {
            {hash = `WEAPON_MG`, name = "MG", price = 3000, ammo = 500},
            {hash = `WEAPON_COMBATMG`, name = "Combat MG", price = 3500, ammo = 500}
        }
    },
    ["sniper"] = {
        label = "Sniper Rifles",
        weapons = {
            {hash = `WEAPON_SNIPERRIFLE`, name = "Sniper Rifle", price = 4000, ammo = 100},
            {hash = `WEAPON_HEAVYSNIPER`, name = "Heavy Sniper", price = 5000, ammo = 50}
        }
    }
}

-- Armor Configuration
Config.Armor = {
    {name = "Light Armor", armor = 25, price = 100},
    {name = "Medium Armor", armor = 50, price = 200},
    {name = "Heavy Armor", armor = 100, price = 400}
}