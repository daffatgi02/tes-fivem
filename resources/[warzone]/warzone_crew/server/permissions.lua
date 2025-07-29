-- resources/[warzone]/warzone_crew/server/permissions.lua

WarzoneCrewPermissions = {}

-- Check if player has permission
function WarzoneCrewPermissions.HasPermission(source, permission)
    local crewId = WarzoneCrews.PlayerCrews[source]
    if not crewId then return false end
    
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then return false end
    
    local player = WarzonePlayer.GetBySource(source)
    if not player then return false end
    
    local member = crew.members[player.identifier]
    if not member then return false end
    
    local permissions = CrewConfig.Permissions[member.role]
    return permissions and permissions[permission] or false
end

-- Promote member
function WarzoneCrewPermissions.PromoteMember(source, targetIdentifier)
    if not WarzoneCrewPermissions.HasPermission(source, 'promote') then
        return false, "You don't have permission to promote members"
    end
    
    local crewId = WarzoneCrews.PlayerCrews[source]
    local crew = WarzoneCrews.ActiveCrews[crewId]
    
    local targetMember = crew.members[targetIdentifier]
    if not targetMember then
        return false, "Player is not a crew member"
    end
    
    if targetMember.role == 'leader' then
        return false, "Cannot promote the leader"
    end
    
    -- Promote member -> officer
    if targetMember.role == 'member' then
        targetMember.role = 'officer'
        
        -- Update database
        MySQL.update.await('UPDATE warzone_crew_members SET role = "officer" WHERE crew_id = ? AND player_identifier = ?', 
            {crewId, targetIdentifier})
        
        -- Notify
        local targetPlayer = WarzonePlayer.GetByIdentifier(targetIdentifier)
        if targetPlayer and targetMember.source then
            TriggerClientEvent('esx:showNotification', targetMember.source, '⬆️ You have been promoted to Officer!')
        end
        
        return true, "Member promoted to Officer"
    end
    
    return false, "Cannot promote further"
end

-- Demote member
function WarzoneCrewPermissions.DemoteMember(source, targetIdentifier)
    if not WarzoneCrewPermissions.HasPermission(source, 'demote') then
        return false, "You don't have permission to demote members"
    end
    
    local crewId = WarzoneCrews.PlayerCrews[source]
    local crew = WarzoneCrews.ActiveCrews[crewId]
    
    local targetMember = crew.members[targetIdentifier]
    if not targetMember then
        return false, "Player is not a crew member"
    end
    
    if targetMember.role == 'leader' then
        return false, "Cannot demote the leader"
    end
    
    -- Demote officer -> member
    if targetMember.role == 'officer' then
        targetMember.role = 'member'
        
        -- Update database
        MySQL.update.await('UPDATE warzone_crew_members SET role = "member" WHERE crew_id = ? AND player_identifier = ?', 
            {crewId, targetIdentifier})
        
        -- Notify
        if targetMember.source then
            TriggerClientEvent('esx:showNotification', targetMember.source, '⬇️ You have been demoted to Member')
        end
        
        return true, "Officer demoted to Member"
    end
    
    return false, "Cannot demote further"
end

-- Kick member
function WarzoneCrewPermissions.KickMember(source, targetIdentifier)
    if not WarzoneCrewPermissions.HasPermission(source, 'kick') then
        return false, "You don't have permission to kick members"
    end
    
    local crewId = WarzoneCrews.PlayerCrews[source]
    local crew = WarzoneCrews.ActiveCrews[crewId]
    
    local targetMember = crew.members[targetIdentifier]
    if not targetMember then
        return false, "Player is not a crew member"
    end
    
    if targetMember.role == 'leader' then
        return false, "Cannot kick the leader"
    end
    
    local player = WarzonePlayer.GetBySource(source)
    local targetPlayer = WarzonePlayer.GetByIdentifier(targetIdentifier)
    
    if not player or not targetPlayer then
        return false, "Player not found"
    end
    
    -- Remove from database
    MySQL.query.await('DELETE FROM warzone_crew_members WHERE crew_id = ? AND player_identifier = ?', 
        {crewId, targetIdentifier})
    
    -- Update members count
    MySQL.update.await('UPDATE warzone_crews SET members_count = members_count - 1 WHERE id = ?', {crewId})
    
    -- Remove from crew
    crew.members[targetIdentifier] = nil
    
    -- Update target player
    targetPlayer.crew_id = nil
    targetPlayer:Save()
    
    -- Remove from mapping if online
    if targetMember.source then
        WarzoneCrews.PlayerCrews[targetMember.source] = nil
        TriggerEvent('warzone_crew:removeRadio', targetMember.source)
        TriggerClientEvent('esx:showNotification', targetMember.source, 
            string.format('❌ You have been kicked from crew "%s"', crew.name))
        TriggerClientEvent('warzone_crew:updateCrewData', targetMember.source, nil)
    end
    
    -- Notify crew
    WarzoneCrews.NotifyCrewMembers(crewId, 
        string.format('👤 %s was kicked from the crew', targetPlayer:GetDisplayName()), source)
    
    return true, string.format("%s has been kicked from the crew", targetPlayer:GetDisplayName())
end

-- Events
RegisterNetEvent('warzone_crew:promoteMember')
AddEventHandler('warzone_crew:promoteMember', function(targetIdentifier)
    local success, message = WarzoneCrewPermissions.PromoteMember(source, targetIdentifier)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'promote', success, message)
end)

RegisterNetEvent('warzone_crew:demoteMember')
AddEventHandler('warzone_crew:demoteMember', function(targetIdentifier)
    local success, message = WarzoneCrewPermissions.DemoteMember(source, targetIdentifier)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'demote', success, message)
end)

RegisterNetEvent('warzone_crew:kickMember')
AddEventHandler('warzone_crew:kickMember', function(targetIdentifier)
    local success, message = WarzoneCrewPermissions.KickMember(source, targetIdentifier)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'kick', success, message)
end)

-- Export functions
exports('HasPermission', WarzoneCrewPermissions.HasPermission)
exports('PromoteMember', WarzoneCrewPermissions.PromoteMember)
exports('DemoteMember', WarzoneCrewPermissions.DemoteMember)
exports('KickMember', WarzoneCrewPermissions.KickMember)