-- resources/[warzone]/warzone_core/shared/utils.lua

WarzoneUtils = {}


-- resources/[warzone]/warzone_core/shared/utils.lua

WarzoneUtils = {}

-- Math utilities
function WarzoneUtils.Round(value, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(value * mult + 0.5) / mult
end

function WarzoneUtils.Distance(coords1, coords2)
    if type(coords1) == "table" then
        coords1 = vector3(coords1.x or coords1[1], coords1.y or coords1[2], coords1.z or coords1[3])
    end
    if type(coords2) == "table" then
        coords2 = vector3(coords2.x or coords2[1], coords2.y or coords2[2], coords2.z or coords2[3])
    end
    return #(coords1 - coords2)
end

function WarzoneUtils.Distance2D(coords1, coords2)
    local dist3D = WarzoneUtils.Distance(coords1, coords2)
    local zDiff = math.abs(coords1.z - coords2.z)
    return math.sqrt(dist3D^2 - zDiff^2)
end

-- Table utilities
function WarzoneUtils.TableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function WarzoneUtils.TableCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[WarzoneUtils.TableCopy(orig_key)] = WarzoneUtils.TableCopy(orig_value)
        end
        setmetatable(copy, WarzoneUtils.TableCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function WarzoneUtils.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- String utilities
function WarzoneUtils.Trim(str)
    return str:match("^%s*(.-)%s*$")
end

function WarzoneUtils.Split(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from-1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    
    table.insert(result, string.sub(str, from))
    return result
end

-- Time utilities
function WarzoneUtils.GetTimestamp()
    return os.time()
end

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

-- Validation utilities
function WarzoneUtils.IsValidCoords(coords)
    if not coords then return false end
    
    if type(coords) == "table" then
        return coords.x and coords.y and coords.z and 
               type(coords.x) == "number" and 
               type(coords.y) == "number" and 
               type(coords.z) == "number"
    end
    
    return false
end

function WarzoneUtils.IsValidPlayer(playerId)
    return playerId and tonumber(playerId) and GetPlayerPed(playerId) ~= 0
end

-- Zone utilities
function WarzoneUtils.IsPointInPolygon(point, polygon)
    local x, y = point.x or point[1], point.y or point[2]
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x or polygon[i][1], polygon[i].y or polygon[i][2]
        local xj, yj = polygon[j].x or polygon[j][1], polygon[j].y or polygon[j][2]
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

-- Logging utilities
function WarzoneUtils.Log(level, message, ...)
    local levels = {
        ['error'] = '^1[ERROR]^7',
        ['warn'] = '^3[WARN]^7',
        ['info'] = '^2[INFO]^7',
        ['debug'] = '^5[DEBUG]^7'
    }
    
    local prefix = levels[level] or '^7[LOG]^7'
    local formatted = string.format(message, ...)
    
    print(string.format('%s %s', prefix, formatted))
end

-- Export utilities globally
_G.WarzoneUtils = WarzoneUtils

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