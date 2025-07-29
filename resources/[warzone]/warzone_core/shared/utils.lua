-- resources/[warzone]/warzone_core/shared/utils.lua

WarzoneUtils = {}

-- String utilities
function WarzoneUtils.ValidateNickname(nickname)
    if not nickname or type(nickname) ~= "string" then
        return false, "Nickname must be a string"
    end
    
    if string.len(nickname) < 3 or string.len(nickname) > 20 then
        return false, "Nickname must be 3-20 characters"
    end
    
    -- Check for invalid characters
    if not string.match(nickname, "^[a-zA-Z0-9_-]+$") then
        return false, "Nickname can only contain letters, numbers, underscore and dash"
    end
    
    return true
end

function WarzoneUtils.ValidateTag(tag)
    if not tag or type(tag) ~= "string" then
        return false, "Tag must be a string"
    end
    
    if string.len(tag) < 2 or string.len(tag) > 6 then
        return false, "Tag must be 2-6 characters"
    end
    
    -- Check for invalid characters
    if not string.match(tag, "^[a-zA-Z0-9]+$") then
        return false, "Tag can only contain letters and numbers"
    end
    
    return true
end

-- Math utilities
function WarzoneUtils.Round(num, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

function WarzoneUtils.CalculateDistance(pos1, pos2)
    if type(pos1) == "vector3" and type(pos2) == "vector3" then
        return #(pos1 - pos2)
    elseif pos1.x and pos1.y and pos1.z and pos2.x and pos2.y and pos2.z then
        return math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2 + (pos1.z - pos2.z)^2)
    end
    return 0
end

-- Time utilities
function WarzoneUtils.FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

function WarzoneUtils.GetTimestamp()
    return os.time()
end

-- Table utilities
function WarzoneUtils.TableSize(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function WarzoneUtils.TableCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = WarzoneUtils.TableCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

-- Array utilities
function WarzoneUtils.ArrayContains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

function WarzoneUtils.ArrayRemove(array, value)
    for i, v in ipairs(array) do
        if v == value then
            table.remove(array, i)
            return true
        end
    end
    return false
end

-- Color utilities
function WarzoneUtils.RGBToHex(r, g, b)
    return string.format("#%02x%02x%02x", r, g, b)
end

function WarzoneUtils.HexToRGB(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x" .. hex:sub(5, 6))
end

-- Security utilities
function WarzoneUtils.SanitizeInput(input)
    if type(input) ~= "string" then
        return ""
    end
    
    -- Remove potentially dangerous characters
    input = string.gsub(input, "[<>\"'&]", "")
    input = string.gsub(input, "%s+", " ") -- Multiple spaces to single space
    input = string.trim(input)
    
    return input
end

-- Client-side only utilities
if IsDuplicityVersion() == false then -- Client side
    function WarzoneUtils.GetPlayerFromPed(ped)
        local players = GetActivePlayers()
        for _, player in ipairs(players) do
            if GetPlayerPed(player) == ped then
                return player
            end
        end
        return nil
    end
    
    function WarzoneUtils.GetClosestPlayer(coords, maxDistance)
        local players = GetActivePlayers()
        local closestPlayer = nil
        local closestDistance = maxDistance or 10.0
        
        for _, player in ipairs(players) do
            if player ~= PlayerId() then
                local targetPed = GetPlayerPed(player)
                local targetCoords = GetEntityCoords(targetPed)
                local distance = WarzoneUtils.CalculateDistance(coords, targetCoords)
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
        
        return closestPlayer, closestDistance
    end
end