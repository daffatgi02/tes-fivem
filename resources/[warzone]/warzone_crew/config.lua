-- resources/[warzone]/warzone_crew/config.lua
CrewConfig = {}

-- Crew Settings
CrewConfig.MaxCrewSize = 6 -- Maximum players per crew
CrewConfig.MinCrewSize = 2 -- Minimum players to create crew
CrewConfig.CrewCreationCost = 1000 -- Cost to create crew
CrewConfig.CrewNameMaxLength = 20 -- Max characters for crew name
CrewConfig.CrewNameMinLength = 3 -- Min characters for crew name

-- Radio Settings
CrewConfig.Radio = {
    BaseFrequency = 100.0, -- Starting frequency
    FrequencyStep = 0.1, -- Step between frequencies
    MaxFrequency = 999.9, -- Maximum frequency
    AutoAssign = true, -- Auto assign frequency on crew creation
    ProximityRange = 500.0, -- Range for proximity voice
    RadioRange = 5000.0 -- Range for radio communication
}

-- Crew Abilities
CrewConfig.Abilities = {
    SharedInventory = true, -- Can share items between members
    CoordinatedSpawn = true, -- Can spawn near crew members
    FastRevive = true, -- Faster revive for crew members
    CrewBlips = true, -- Show crew members on map
    CrewChat = true, -- Private crew chat
    CrewRadio = true -- Private radio channel
}

-- Crew Bonuses
CrewConfig.Bonuses = {
    KillBonusMultiplier = 1.1, -- 10% extra money when crew member gets kill
    ReviveSpeedMultiplier = 1.5, -- 50% faster revive speed for crew members
    SpawnProtectionTime = 10, -- Seconds of spawn protection when spawning near crew
    MaxSpawnDistance = 200.0 -- Max distance to spawn near crew member
}

-- Crew Permissions
CrewConfig.Permissions = {
    ["leader"] = {
        invite = true,
        kick = true,
        promote = true,
        demote = true,
        disband = true,
        changeSettings = true
    },
    ["officer"] = {
        invite = true,
        kick = false,
        promote = false,
        demote = false,
        disband = false,
        changeSettings = false
    },
    ["member"] = {
        invite = false,
        kick = false,
        promote = false,
        demote = false,
        disband = false,
        changeSettings = false
    }
}

-- Crew UI Settings
CrewConfig.UI = {
    MaxDisplayMembers = 8, -- Max members to show in HUD
    UpdateInterval = 2000, -- Update interval in ms
    ShowDistance = true, -- Show distance to crew members
    ShowHealth = true, -- Show crew member health
    ShowArmor = true, -- Show crew member armor
    ShowZone = true -- Show crew member zone
}

-- Crew Colors (for blips and UI)
CrewConfig.Colors = {
    {r = 255, g = 0, b = 0, name = "Red"},
    {r = 0, g = 255, b = 0, name = "Green"},
    {r = 0, g = 0, b = 255, name = "Blue"},
    {r = 255, g = 255, b = 0, name = "Yellow"},
    {r = 255, g = 0, b = 255, name = "Magenta"},
    {r = 0, g = 255, b = 255, name = "Cyan"},
    {r = 255, g = 165, b = 0, name = "Orange"},
    {r = 128, g = 0, b = 128, name = "Purple"}
}