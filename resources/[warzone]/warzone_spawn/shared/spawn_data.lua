-- resources/[warzone]/warzone_spawn/shared/spawn_data.lua

SpawnData = {}

-- Shared constants
SpawnData.Constants = {
    MAX_SPAWN_ATTEMPTS = 10,
    SAFETY_CHECK_RADIUS = 25.0,
    DEFAULT_SPAWN_HEIGHT = 1.0,
    QUEUE_TIMEOUT = 30,
    PROTECTION_TIME = 15
}

-- Spawn categories
SpawnData.Categories = {
    URBAN = "urban",
    INDUSTRIAL = "industrial", 
    MILITARY = "military",
    REMOTE = "remote"
}

-- Spawn strategies
SpawnData.Strategies = {
    SAFE = "safe",
    BALANCED = "balanced",
    AGGRESSIVE = "aggressive"
}

-- Risk levels
SpawnData.RiskLevels = {
    VERY_LOW = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    VERY_HIGH = 5
}

-- Utility functions
function SpawnData.IsValidStrategy(strategy)
    for _, validStrategy in pairs(SpawnData.Strategies) do
        if strategy == validStrategy then
            return true
        end
    end
    return false
end

function SpawnData.IsValidCategory(category)
    for _, validCategory in pairs(SpawnData.Categories) do
        if category == validCategory then
            return true
        end
    end
    return false
end

function SpawnData.GetRiskLevelName(level)
    local names = {
        [1] = "Very Low",
        [2] = "Low", 
        [3] = "Medium",
        [4] = "High",
        [5] = "Very High"
    }
    return names[level] or "Unknown"
end