-- resources/[warzone]/warzone_core/config/zones.lua
Config.Zones = {}

-- Zone Activity Levels
Config.ZoneActivity = {
    WHITE = "white", -- Safe, no recent activity
    YELLOW = "yellow", -- Moderate activity (2-4 kills in 5 minutes)
    RED = "red" -- High activity (5+ kills in 5 minutes)
}

-- Zone Activity Thresholds
Config.ZoneThresholds = {
    YellowKills = 2, -- Min kills for yellow zone
    RedKills = 5, -- Min kills for red zone
    ActivityWindow = 300, -- 5 minutes in seconds
    UpdateInterval = 30 -- Update zone status every 30 seconds
}

-- Green Zones (Safe Areas)
Config.GreenZones = {
    {
        name = "hospital_ls",
        label = "Los Santos Hospital",
        coords = vector3(294.102, -1448.54, 29.9666),
        radius = 100.0,
        blip = {sprite = 61, color = 2, scale = 1.0}
    },
    {
        name = "airport_ls",
        label = "Los Santos Airport",
        coords = vector3(-1042.518, -2745.195, 21.359),
        radius = 150.0,
        blip = {sprite = 90, color = 2, scale = 1.0}
    },
    {
        name = "prison",
        label = "Bolingbroke Penitentiary",
        coords = vector3(1845.658, 2585.873, 45.672),
        radius = 200.0,
        blip = {sprite = 188, color = 2, scale = 1.0}
    }
}

-- Combat Zones (Areas with activity tracking)
Config.CombatZones = {
    {
        name = "downtown_ls",
        label = "Downtown Los Santos",
        coords = vector3(215.179, -888.612, 30.692),
        radius = 500.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "vinewood",
        label = "Vinewood",
        coords = vector3(402.341, 261.703, 103.171),
        radius = 400.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "vespucci_beach",
        label = "Vespucci Beach",
        coords = vector3(-1223.219, -1491.782, 4.024),
        radius = 300.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "del_perro",
        label = "Del Perro",
        coords = vector3(-1426.015, -596.093, 30.244),
        radius = 350.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "sandy_shores",
        label = "Sandy Shores",
        coords = vector3(1961.206, 3741.58, 32.344),
        radius = 400.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "paleto_bay",
        label = "Paleto Bay",
        coords = vector3(-102.24, 6467.31, 31.627),
        radius = 300.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "grapeseed",
        label = "Grapeseed",
        coords = vector3(1687.156, 4929.392, 42.078),
        radius = 250.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    },
    {
        name = "mirror_park",
        label = "Mirror Park",
        coords = vector3(1159.494, -314.186, 69.205),
        radius = 300.0,
        blip = {sprite = 84, color = 1, scale = 1.2}
    }
}