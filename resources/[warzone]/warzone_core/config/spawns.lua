-- resources/[warzone]/warzone_core/config/spawns.lua
Config.SpawnLocations = {}

-- Spawn Point Categories
Config.SpawnCategories = {
    SAFE = "safe", -- Green zone spawns
    URBAN = "urban", -- City spawns
    DESERT = "desert", -- Rural/desert spawns
    BEACH = "beach", -- Coastal spawns
    MILITARY = "military" -- Military base spawns
}

-- Available Spawn Points
Config.SpawnPoints = {
    -- Safe Spawns (Green Zones)
    {
        name = "hospital_spawn",
        label = "Hospital",
        category = "safe",
        coords = vector4(298.745, -1421.526, 29.803, 142.323),
        safetyRadius = 10.0,
        description = "Safe medical area"
    },
    {
        name = "airport_spawn", 
        label = "Airport Terminal",
        category = "safe",
        coords = vector4(-1037.77, -2737.84, 20.17, 240.0),
        safetyRadius = 10.0,
        description = "Airport safe zone"
    },
    
    -- Urban Spawns
    {
        name = "downtown_spawn1",
        label = "Downtown Center",
        category = "urban",
        coords = vector4(228.862, -876.717, 30.492, 160.456),
        safetyRadius = 15.0,
        description = "City center - High activity"
    },
    {
        name = "vinewood_spawn1",
        label = "Vinewood Hills",
        category = "urban", 
        coords = vector4(412.341, 271.703, 103.171, 90.0),
        safetyRadius = 15.0,
        description = "Luxury district"
    },
    {
        name = "mirror_park_spawn",
        label = "Mirror Park",
        category = "urban",
        coords = vector4(1149.494, -304.186, 69.205, 270.0),
        safetyRadius = 15.0,
        description = "Residential area"
    },
    
    -- Beach Spawns
    {
        name = "vespucci_spawn1",
        label = "Vespucci Beach",
        category = "beach",
        coords = vector4(-1213.219, -1481.782, 4.024, 200.0),
        safetyRadius = 15.0,
        description = "Popular beach area"
    },
    {
        name = "del_perro_spawn",
        label = "Del Perro Pier",
        category = "beach",
        coords = vector4(-1416.015, -586.093, 30.244, 180.0),
        safetyRadius = 15.0,
        description = "Pier and boardwalk"
    },
    
    -- Desert Spawns
    {
        name = "sandy_shores_spawn",
        label = "Sandy Shores",
        category = "desert",
        coords = vector4(1951.206, 3731.58, 32.344, 45.0),
        safetyRadius = 15.0,
        description = "Desert town"
    },
    {
        name = "grapeseed_spawn",
        label = "Grapeseed",
        category = "desert",
        coords = vector4(1677.156, 4919.392, 42.078, 90.0),
        safetyRadius = 15.0,
        description = "Rural farming area"
    },
    {
        name = "paleto_spawn",
        label = "Paleto Bay",
        category = "desert",
        coords = vector4(-112.24, 6457.31, 31.627, 315.0),
        safetyRadius = 15.0,
        description = "Northern coastal town"
    },
    
    -- Military Spawns (Higher risk)
    {
        name = "zancudo_spawn",
        label = "Fort Zancudo Perimeter", 
        category = "military",
        coords = vector4(-2012.265, 2956.010, 32.810, 0.0),
        safetyRadius = 20.0,
        description = "Military base area - High risk"
    },
    {
        name = "humane_spawn",
        label = "Humane Labs",
        category = "military",
        coords = vector4(3525.495, 3705.301, 36.652, 180.0),
        safetyRadius = 20.0,
        description = "Research facility - High risk"
    }
}