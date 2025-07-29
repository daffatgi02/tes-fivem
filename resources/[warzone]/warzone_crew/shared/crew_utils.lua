-- resources/[warzone]/warzone_crew/shared/crew_utils.lua

CrewUtils = {}

-- Validate crew name
function CrewUtils.ValidateCrewName(name)
    if not name or type(name) ~= "string" then
        return false, "Crew name must be a string"
    end
    
    if string.len(name) < CrewConfig.CrewNameMinLength or string.len(name) > CrewConfig.CrewNameMaxLength then
        return false, string.format("Crew name must be %d-%d characters", CrewConfig.CrewNameMinLength, CrewConfig.CrewNameMaxLength)
    end
    
    -- Check for invalid characters
    if not string.match(name, "^[a-zA-Z0-9_ -]+$") then
        return false, "Crew name can only contain letters, numbers, spaces, underscores and dashes"
    end
    
    -- Check for prohibited words
    local prohibitedWords = {"admin", "mod", "staff", "owner", "fuck", "shit"}
    local lowerName = string.lower(name)
    for _, word in ipairs(prohibitedWords) do
        if string.find(lowerName, word) then
            return false, "Crew name contains prohibited words"
        end
    end
    
    return true
end

-- Get role display name
function CrewUtils.GetRoleDisplayName(role)
    local roleNames = {
        leader = "👑 Leader",
        officer = "⭐ Officer", 
        member = "👤 Member"
    }
    
    return roleNames[role] or "Unknown"
end

-- Get role color
function CrewUtils.GetRoleColor(role)
    local roleColors = {
        leader = {r = 255, g = 215, b = 0}, -- Gold
        officer = {r = 0, g = 191, b = 255}, -- Blue
        member = {r = 255, g = 255, b = 255} -- White
    }
    
    return roleColors[role] or {r = 255, g = 255, b = 255}
end

-- Calculate crew strength
function CrewUtils.CalculateCrewStrength(crewData)
    if not crewData or not crewData.members then return 0 end
    
    local strength = 0
    local onlineCount = 0
    
    for identifier, member in pairs(crewData.members) do
        if member.online then
            onlineCount = onlineCount + 1
           
           -- Add base strength
           strength = strength + 10
           
           -- Role bonuses
           if member.role == 'leader' then
               strength = strength + 5
           elseif member.role == 'officer' then
               strength = strength + 3
           end
           
           -- Kill contribution bonus
           strength = strength + (member.killsContributed or 0) * 0.1
       end
   end
   
   -- Team size multiplier
   if onlineCount >= 3 then
       strength = strength * 1.2
   elseif onlineCount >= 5 then
       strength = strength * 1.5
   end
   
   return math.floor(strength)
end

-- Check if crew is active
function CrewUtils.IsCrewActive(crewData)
   if not crewData or not crewData.members then return false end
   
   local onlineCount = 0
   for identifier, member in pairs(crewData.members) do
       if member.online then
           onlineCount = onlineCount + 1
       end
   end
   
   return onlineCount >= CrewConfig.MinCrewSize
end

-- Format crew member list
function CrewUtils.FormatMemberList(crewData, maxDisplay)
   if not crewData or not crewData.members then return {} end
   
   maxDisplay = maxDisplay or 999
   local memberList = {}
   local count = 0
   
   -- Sort by role priority (leader first, then officers, then members)
   local sortedMembers = {}
   for identifier, member in pairs(crewData.members) do
       table.insert(sortedMembers, member)
   end
   
   table.sort(sortedMembers, function(a, b)
       local roleOrder = {leader = 1, officer = 2, member = 3}
       local aOrder = roleOrder[a.role] or 4
       local bOrder = roleOrder[b.role] or 4
       
       if aOrder ~= bOrder then
           return aOrder < bOrder
       end
       
       return a.displayName < b.displayName
   end)
   
   -- Format member entries
   for _, member in ipairs(sortedMembers) do
       if count >= maxDisplay then break end
       
       local status = member.online and "🟢" or "🔴"
       local roleIcon = ""
       
       if member.role == 'leader' then
           roleIcon = "👑 "
       elseif member.role == 'officer' then
           roleIcon = "⭐ "
       end
       
       table.insert(memberList, {
           identifier = member.identifier,
           displayName = member.displayName,
           role = member.role,
           online = member.online,
           formatted = string.format("%s %s%s", status, roleIcon, member.displayName)
       })
       
       count = count + 1
   end
   
   return memberList
end

-- Generate crew stats summary
function CrewUtils.GetCrewStatsSummary(crewData)
   if not crewData then return nil end
   
   local totalMembers = 0
   local onlineMembers = 0
   local totalKills = 0
   
   for identifier, member in pairs(crewData.members or {}) do
       totalMembers = totalMembers + 1
       if member.online then
           onlineMembers = onlineMembers + 1
       end
       totalKills = totalKills + (member.killsContributed or 0)
   end
   
   return {
       name = crewData.name,
       totalMembers = totalMembers,
       onlineMembers = onlineMembers,
       totalKills = totalKills,
       radioFrequency = crewData.radioFrequency,
       strength = CrewUtils.CalculateCrewStrength(crewData),
       isActive = CrewUtils.IsCrewActive(crewData),
       createdAt = crewData.createdAt
   }
end

-- Export functions
if IsDuplicityVersion() then -- Server side
   exports('ValidateCrewName', CrewUtils.ValidateCrewName)
   exports('GetRoleDisplayName', CrewUtils.GetRoleDisplayName)
   exports('CalculateCrewStrength', CrewUtils.CalculateCrewStrength)
   exports('IsCrewActive', CrewUtils.IsCrewActive)
   exports('FormatMemberList', CrewUtils.FormatMemberList)
   exports('GetCrewStatsSummary', CrewUtils.GetCrewStatsSummary)
end