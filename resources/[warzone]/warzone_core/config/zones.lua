-- resources/[warzone]/warzone_core/config/zones.lua

Config.Zones = {
    -- Green zones (safe areas)
    GreenZones = {
        {
            name = "Los Santos Airport",
            coords = vector3(-1037.86, -2737.89, 20.17),
            radius = 150.0,
            blip = {
                sprite = 90,
                color = 2,
                scale = 1.2
            }
        },
        {
            name = "Hospital Central",
            coords = vector3(294.43, -584.33, 43.26),
            radius = 100.0,
            blip = {
                sprite = 61,
                color = 2,
                scale = 1.0
            }
        },
        {
            name = "Sandy Shores Medical",
            coords = vector3(1839.6, 3672.93, 34.28),
            radius = 80.0,
            blip = {
                sprite = 61,
                color = 2,
                scale = 1.0
            }
        }
    },

    -- Combat zones (active areas)
    CombatZones = {
        {
            name = "Downtown LS",
            points = {
                vector3(200.0, -800.0, 30.0),
                vector3(500.0, -800.0, 30.0),
                vector3(500.0, -500.0, 30.0),
                vector3(200.0, -500.0, 30.0)
            },
            activity = "high"
        },
        {
            name = "Industrial Area",
            points = {
                vector3(800.0, -2000.0, 30.0),
                vector3(1200.0, -2000.0, 30.0),
                vector3(1200.0, -1600.0, 30.0),
                vector3(800.0, -1600.0, 30.0)
            },
            activity = "medium"
        },
        {
            name = "Vinewood Hills",
            points = {
                vector3(-500.0, 500.0, 100.0),
                vector3(-200.0, 500.0, 100.0),
                vector3(-200.0, 800.0, 100.0),
                vector3(-500.0, 800.0, 100.0)
            },
            activity = "low"
        }
    }
}