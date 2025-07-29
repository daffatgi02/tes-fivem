-- resources/[warzone]/warzone_crew/server/crew.lua
WarzoneCrews = {}
WarzoneCrews.ActiveCrews = {}
WarzoneCrews.PlayerCrews = {} -- Map player source to crew ID

local ESX = nil
-- Wait for dependencies (FIXED)
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    while not WarzonePlayer do
        Citizen.Wait(100)
    end
    
    print("^2[WARZONE CREW] Initializing crew system...^7")
    
    -- Initialize crew system after dependencies ready
    WarzoneCrewInit()
end)

function WarzoneCrewInit()
    -- Put existing crew initialization code here
    print("^2[WARZONE CREW] Crew system initialized successfully!^7")
end

-- Initialize Crew System
function WarzoneCrews.Init()
    print("[WARZONE CREW] Initializing crew system...")
    
    -- Initialize database
    WarzoneCrews.InitDatabase()
    
    -- Load existing crews
    WarzoneCrews.LoadCrews()
    
    print("[WARZONE CREW] Crew system initialized successfully!")
end

-- Initialize Database
function WarzoneCrews.InitDatabase()
    -- Create crews table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_crews` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(50) NOT NULL UNIQUE,
            `leader_identifier` VARCHAR(60) NOT NULL,
            `members_count` INT DEFAULT 1,
            `total_kills` INT DEFAULT 0,
            `radio_frequency` DECIMAL(5,2) NOT NULL,
            `crew_color` INT DEFAULT 0,
            `settings` JSON,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `leader_idx` (`leader_identifier`),
            INDEX `name_idx` (`name`)
        )
    ]])
    
    -- Create crew members table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_crew_members` (
            `crew_id` INT NOT NULL,
            `player_identifier` VARCHAR(60) NOT NULL,
            `role` ENUM('leader', 'officer', 'member') DEFAULT 'member',
            `kills_contributed` INT DEFAULT 0,
            `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`crew_id`, `player_identifier`),
            INDEX `player_idx` (`player_identifier`),
            INDEX `crew_idx` (`crew_id`),
            FOREIGN KEY (`crew_id`) REFERENCES `warzone_crews`(`id`) ON DELETE CASCADE
        )
    ]])
    
    -- Create crew invitations table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_crew_invitations` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `crew_id` INT NOT NULL,
            `inviter_identifier` VARCHAR(60) NOT NULL,
            `invitee_identifier` VARCHAR(60) NOT NULL,
            `status` ENUM('pending', 'accepted', 'declined', 'expired') DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP DEFAULT (DATE_ADD(NOW(), INTERVAL 5 MINUTE)),
            INDEX `invitee_idx` (`invitee_identifier`),
            INDEX `crew_idx` (`crew_id`),
            INDEX `status_idx` (`status`)
        )
    ]])
end

-- Load existing crews from database
function WarzoneCrews.LoadCrews()
    local crews = MySQL.query.await('SELECT * FROM warzone_crews')
    
    for _, crewData in ipairs(crews) do
        local members = MySQL.query.await('SELECT * FROM warzone_crew_members WHERE crew_id = ?', {crewData.id})
        
        WarzoneCrews.ActiveCrews[crewData.id] = {
            id = crewData.id,
            name = crewData.name,
            leader = crewData.leader_identifier,
            members = {},
            settings = json.decode(crewData.settings) or {},
            radioFrequency = crewData.radio_frequency,
            color = crewData.crew_color,
            totalKills = crewData.total_kills,
            createdAt = crewData.created_at
        }
        
        -- Load members
        for _, member in ipairs(members) do
            WarzoneCrews.ActiveCrews[crewData.id].members[member.player_identifier] = {
                identifier = member.player_identifier,
                role = member.role,
                killsContributed = member.kills_contributed,
                joinedAt = member.joined_at,
                source = nil -- Will be set when player connects
            }
        end
    end
    
    print(string.format("[WARZONE CREW] Loaded %d crews from database", #crews))
end

-- Create new crew
function WarzoneCrews.CreateCrew(source, crewName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, "Player not found" end
    
    local warzonePlayer = WarzonePlayer.GetBySource(source)
    if not warzonePlayer then return false, "Warzone player not found" end
    
    -- Check if player already in crew
    if warzonePlayer.crew_id then
        return false, "You are already in a crew"
    end
    
    -- Validate crew name
    if not crewName or string.len(crewName) < CrewConfig.CrewNameMinLength or string.len(crewName) > CrewConfig.CrewNameMaxLength then
        return false, string.format("Crew name must be %d-%d characters", CrewConfig.CrewNameMinLength, CrewConfig.CrewNameMaxLength)
    end
    
    -- Check if crew name exists
    local existingCrew = MySQL.single.await('SELECT id FROM warzone_crews WHERE name = ?', {crewName})
    if existingCrew then
        return false, "Crew name already exists"
    end
    
    -- Check if player has enough money
    if warzonePlayer.money < CrewConfig.CrewCreationCost then
        return false, string.format("Not enough money. Cost: $%d", CrewConfig.CrewCreationCost)
    end
    
    -- Generate radio frequency
    local radioFreq = WarzoneCrews.GenerateRadioFrequency()
    
    -- Create crew in database
    local crewId = MySQL.insert.await([[
        INSERT INTO warzone_crews (name, leader_identifier, radio_frequency, crew_color, settings) 
        VALUES (?, ?, ?, ?, ?)
    ]], {crewName, warzonePlayer.identifier, radioFreq, 0, json.encode({})})
    
    if not crewId then
        return false, "Failed to create crew"
    end
    
    -- Add leader to crew members
    MySQL.insert.await([[
        INSERT INTO warzone_crew_members (crew_id, player_identifier, role) 
        VALUES (?, ?, 'leader')
    ]], {crewId, warzonePlayer.identifier})
    
    -- Deduct money
    warzonePlayer.money = warzonePlayer.money - CrewConfig.CrewCreationCost
    warzonePlayer:Save()
    
    -- Create crew object
    WarzoneCrews.ActiveCrews[crewId] = {
        id = crewId,
        name = crewName,
        leader = warzonePlayer.identifier,
        members = {
            [warzonePlayer.identifier] = {
                identifier = warzonePlayer.identifier,
                role = 'leader',
                killsContributed = 0,
                joinedAt = os.date('%Y-%m-%d %H:%M:%S'),
                source = source
            }
        },
        settings = {},
        radioFrequency = radioFreq,
        color = 0,
        totalKills = 0,
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    -- Update player crew ID
    warzonePlayer.crew_id = crewId
    warzonePlayer:Save()
    
    -- Map player to crew
    WarzoneCrews.PlayerCrews[source] = crewId
    
    -- Setup radio
    TriggerEvent('warzone_crew:setupRadio', source, radioFreq)
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', source, 
        string.format('✅ Crew "%s" created! Radio: %.1f', crewName, radioFreq))
    
    -- Update client
    TriggerClientEvent('warzone_crew:updateCrewData', source, WarzoneCrews.GetCrewData(crewId))
    
    return true, "Crew created successfully"
end

-- Generate unique radio frequency
function WarzoneCrews.GenerateRadioFrequency()
    local baseFreq = CrewConfig.Radio.BaseFrequency
    local step = CrewConfig.Radio.FrequencyStep
    local maxFreq = CrewConfig.Radio.MaxFrequency
    
    -- Get all used frequencies
    local usedFreqs = {}
    for _, crew in pairs(WarzoneCrews.ActiveCrews) do
        usedFreqs[crew.radioFrequency] = true
    end
    
    -- Find available frequency
    local freq = baseFreq
    while freq <= maxFreq do
        if not usedFreqs[freq] then
            return freq
        end
        freq = freq + step
    end
    
    -- If all frequencies used, generate random
    return baseFreq + math.random(1, 999) * step
end

-- Invite player to crew
function WarzoneCrews.InvitePlayer(source, targetId, crewId)
    local inviter = WarzonePlayer.GetBySource(source)
    local target = WarzonePlayer.GetBySource(targetId)
    
    if not inviter or not target then
        return false, "Player not found"
    end
    
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then
        return false, "Crew not found"
    end
    
    -- Check permissions
    local inviterMember = crew.members[inviter.identifier]
    if not inviterMember or not CrewConfig.Permissions[inviterMember.role].invite then
        return false, "You don't have permission to invite players"
    end
    
    -- Check if target already in a crew
    if target.crew_id then
        return false, "Player is already in a crew"
    end
    
    -- Check crew size limit
    if WarzoneUtils.TableSize(crew.members) >= CrewConfig.MaxCrewSize then
        return false, "Crew is full"
    end
    
    -- Check for existing invitation
    local existingInvite = MySQL.single.await([[
        SELECT id FROM warzone_crew_invitations 
        WHERE crew_id = ? AND invitee_identifier = ? AND status = 'pending' AND expires_at > NOW()
    ]], {crewId, target.identifier})
    
    if existingInvite then
        return false, "Player already has a pending invitation"
    end
    
    -- Create invitation
    local inviteId = MySQL.insert.await([[
        INSERT INTO warzone_crew_invitations (crew_id, inviter_identifier, invitee_identifier) 
        VALUES (?, ?, ?)
    ]], {crewId, inviter.identifier, target.identifier})
    
    if inviteId then
        -- Notify target
        TriggerClientEvent('warzone_crew:receiveInvitation', targetId, {
            inviteId = inviteId,
            crewId = crewId,
            crewName = crew.name,
            inviterName = inviter:GetDisplayName(),
            expiresIn = 300 -- 5 minutes
        })
        
        -- Notify inviter
        TriggerClientEvent('esx:showNotification', source, 
            string.format('✅ Invitation sent to %s', target:GetDisplayName()))
        
        return true, "Invitation sent"
    end
    
    return false, "Failed to send invitation"
end

-- Accept crew invitation
function WarzoneCrews.AcceptInvitation(source, inviteId)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return false, "Player not found" end
    
    -- Get invitation
    local invite = MySQL.single.await([[
        SELECT * FROM warzone_crew_invitations 
        WHERE id = ? AND invitee_identifier = ? AND status = 'pending' AND expires_at > NOW()
    ]], {inviteId, player.identifier})
    
    if not invite then
        return false, "Invitation not found or expired"
    end
    
    local crew = WarzoneCrews.ActiveCrews[invite.crew_id]
    if not crew then
        return false, "Crew no longer exists"
    end
    
    -- Check if player already in crew
    if player.crew_id then
        return false, "You are already in a crew"
    end
    
    -- Check crew size
    if WarzoneUtils.TableSize(crew.members) >= CrewConfig.MaxCrewSize then
        return false, "Crew is full"
    end
    
    -- Add player to crew
    MySQL.insert.await([[
        INSERT INTO warzone_crew_members (crew_id, player_identifier, role) 
        VALUES (?, ?, 'member')
    ]], {crew.id, player.identifier})
    
    -- Update invitation status
    MySQL.update.await('UPDATE warzone_crew_invitations SET status = "accepted" WHERE id = ?', {inviteId})
    
    -- Update crew members count
    MySQL.update.await('UPDATE warzone_crews SET members_count = members_count + 1 WHERE id = ?', {crew.id})
    
    -- Add to active crew
    crew.members[player.identifier] = {
        identifier = player.identifier,
        role = 'member',
        killsContributed = 0,
        joinedAt = os.date('%Y-%m-%d %H:%M:%S'),
        source = source
    }
    
    -- Update player crew ID
    player.crew_id = crew.id
    player:Save()
    
    -- Map player to crew
    WarzoneCrews.PlayerCrews[source] = crew.id
    
    -- Setup radio
    TriggerEvent('warzone_crew:setupRadio', source, crew.radioFrequency)
    
    -- Notify all crew members
    WarzoneCrews.NotifyCrewMembers(crew.id, 
        string.format('👥 %s joined the crew!', player:GetDisplayName()))
    
    -- Update client
    TriggerClientEvent('warzone_crew:updateCrewData', source, WarzoneCrews.GetCrewData(crew.id))
    
    return true, "Successfully joined crew"
end

-- Leave crew
function WarzoneCrews.LeaveCrew(source)
    local player = WarzonePlayer.GetBySource(source)
    if not player or not player.crew_id then
        return false, "You are not in a crew"
    end
    
    local crew = WarzoneCrews.ActiveCrews[player.crew_id]
    if not crew then
        return false, "Crew not found"
    end
    
    local member = crew.members[player.identifier]
    if not member then
        return false, "You are not a member of this crew"
    end
    
    -- Check if player is leader
    if member.role == 'leader' then
        -- Transfer leadership or disband crew
        local newLeader = nil
        for identifier, memberData in pairs(crew.members) do
            if identifier ~= player.identifier and memberData.role == 'officer' then
                newLeader = identifier
                break
            end
        end
        
        if not newLeader then
            for identifier, memberData in pairs(crew.members) do
                if identifier ~= player.identifier then
                    newLeader = identifier
                    break
                end
            end
        end
        
        if newLeader then
            -- Transfer leadership
            MySQL.update.await('UPDATE warzone_crews SET leader_identifier = ? WHERE id = ?', {newLeader, crew.id})
            MySQL.update.await('UPDATE warzone_crew_members SET role = "leader" WHERE crew_id = ? AND player_identifier = ?', 
                {crew.id, newLeader})
            
            crew.leader = newLeader
            crew.members[newLeader].role = 'leader'
            
            -- Notify new leader
            local newLeaderSource = crew.members[newLeader].source
            if newLeaderSource then
                TriggerClientEvent('esx:showNotification', newLeaderSource, 
                    '👑 You are now the crew leader!')
            end
        else
            -- Disband crew (only leader left)
            return WarzoneCrews.DisbandCrew(player.crew_id)
        end
    end
    
    -- Remove from database
    MySQL.query.await('DELETE FROM warzone_crew_members WHERE crew_id = ? AND player_identifier = ?', 
        {crew.id, player.identifier})
    
    -- Update members count
    MySQL.update.await('UPDATE warzone_crews SET members_count = members_count - 1 WHERE id = ?', {crew.id})
    
    -- Remove from active crew
    crew.members[player.identifier] = nil
    
    -- Update player
    player.crew_id = nil
    player:Save()
    
    -- Remove from mapping
    WarzoneCrews.PlayerCrews[source] = nil
    
    -- Remove radio
    TriggerEvent('warzone_crew:removeRadio', source)
    
    -- Notify remaining crew members
    WarzoneCrews.NotifyCrewMembers(crew.id, 
        string.format('👥 %s left the crew', player:GetDisplayName()))
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', source, '✅ You have left the crew')
    TriggerClientEvent('warzone_crew:updateCrewData', source, nil)
    
    return true, "Left crew successfully"
end

-- Get crew data for client
function WarzoneCrews.GetCrewData(crewId)
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then return nil end
    
    local members = {}
    for identifier, member in pairs(crew.members) do
        local memberPlayer = WarzonePlayer.GetByIdentifier(identifier)
        
        members[identifier] = {
            identifier = identifier,
            role = member.role,
            killsContributed = member.killsContributed,
            online = member.source ~= nil,
            displayName = memberPlayer and memberPlayer:GetDisplayName() or "Unknown",
            source = member.source
        }
    end
    
    return {
        id = crew.id,
        name = crew.name,
        leader = crew.leader,
        members = members,
        radioFrequency = crew.radioFrequency,
        color = crew.color,
        totalKills = crew.totalKills,
        memberCount = WarzoneUtils.TableSize(crew.members)
    }
end

-- Notify all crew members
function WarzoneCrews.NotifyCrewMembers(crewId, message, excludeSource)
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then return end
    
    for identifier, member in pairs(crew.members) do
        if member.source and member.source ~= excludeSource then
            TriggerClientEvent('esx:showNotification', member.source, message)
        end
    end
end

-- Player connected handler
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local warzonePlayer = WarzonePlayer.GetBySource(playerId)
    if not warzonePlayer or not warzonePlayer.crew_id then return end
    
    local crew = WarzoneCrews.ActiveCrews[warzonePlayer.crew_id]
    if not crew then return end
    
    local member = crew.members[warzonePlayer.identifier]
    if member then
        member.source = playerId
        WarzoneCrews.PlayerCrews[playerId] = crew.id
        
        -- Setup radio
        TriggerEvent('warzone_crew:setupRadio', playerId, crew.radioFrequency)
        
        -- Update client
        Citizen.SetTimeout(5000, function()
            TriggerClientEvent('warzone_crew:updateCrewData', playerId, WarzoneCrews.GetCrewData(crew.id))
        end)
        
        -- Notify crew
        WarzoneCrews.NotifyCrewMembers(crew.id, 
            string.format('👥 %s came online', warzonePlayer:GetDisplayName()), playerId)
    end
end)

-- Player disconnected handler
AddEventHandler('esx:playerDropped', function(playerId, reason)
    local crewId = WarzoneCrews.PlayerCrews[playerId]
    if not crewId then return end
    
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then return end
    
    -- Find player in crew
    for identifier, member in pairs(crew.members) do
        if member.source == playerId then
            member.source = nil
            
            local warzonePlayer = WarzonePlayer.GetByIdentifier(identifier)
            if warzonePlayer then
                -- Notify crew
                WarzoneCrews.NotifyCrewMembers(crewId, 
                    string.format('👥 %s went offline', warzonePlayer:GetDisplayName()))
            end
            break
        end
    end
    
    WarzoneCrews.PlayerCrews[playerId] = nil
end)

-- Initialize when ready
Citizen.CreateThread(function()
    while ESX == nil do
        Citizen.Wait(10)
    end
    
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneCrews.Init()
end)

-- Events
RegisterNetEvent('warzone_crew:createCrew')
AddEventHandler('warzone_crew:createCrew', function(crewName)
    local success, message = WarzoneCrews.CreateCrew(source, crewName)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'create', success, message)
end)

RegisterNetEvent('warzone_crew:invitePlayer')
AddEventHandler('warzone_crew:invitePlayer', function(targetId)
    local crewId = WarzoneCrews.PlayerCrews[source]
    if crewId then
        local success, message = WarzoneCrews.InvitePlayer(source, targetId, crewId)
        TriggerClientEvent('warzone_crew:crewActionResult', source, 'invite', success, message)
    end
end)

RegisterNetEvent('warzone_crew:acceptInvitation')
AddEventHandler('warzone_crew:acceptInvitation', function(inviteId)
    local success, message = WarzoneCrews.AcceptInvitation(source, inviteId)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'accept', success, message)
end)

RegisterNetEvent('warzone_crew:leaveCrew')
AddEventHandler('warzone_crew:leaveCrew', function()
    local success, message = WarzoneCrews.LeaveCrew(source)
    TriggerClientEvent('warzone_crew:crewActionResult', source, 'leave', success, message)
end)

-- Commands
ESX.RegisterCommand('crew', 'user', function(xPlayer, args, showError)
    local action = args.action or 'info'
    
    if action == 'create' then
        local crewName = args.name
        if not crewName then
            return showError('Usage: /crew create [name]')
        end
        
        local success, message = WarzoneCrews.CreateCrew(xPlayer.source, crewName)
        TriggerClientEvent('esx:showNotification', xPlayer.source, message)
        
    elseif action == 'invite' then
        local targetId = args.playerId and args.playerId.source
        if not targetId then
            return showError('Usage: /crew invite [player]')
        end
        
        local crewId = WarzoneCrews.PlayerCrews[xPlayer.source]
        if crewId then
            local success, message = WarzoneCrews.InvitePlayer(xPlayer.source, targetId, crewId)
            TriggerClientEvent('esx:showNotification', xPlayer.source, message)
        else
            TriggerClientEvent('esx:showNotification', xPlayer.source, '❌ You are not in a crew')
        end
        
    elseif action == 'leave' then
        local success, message = WarzoneCrews.LeaveCrew(xPlayer.source)
        TriggerClientEvent('esx:showNotification', xPlayer.source, message)
       
   elseif action == 'info' then
       local crewId = WarzoneCrews.PlayerCrews[xPlayer.source]
       if crewId then
           local crewData = WarzoneCrews.GetCrewData(crewId)
           if crewData then
               local memberList = {}
               for identifier, member in pairs(crewData.members) do
                   local status = member.online and "🟢" or "🔴"
                   table.insert(memberList, string.format("%s %s (%s)", status, member.displayName, member.role))
               end
               
               local message = string.format([[
👥 CREW INFO - %s
📻 Radio: %.1f
👑 Leader: %s
👤 Members (%d/%d):
%s
               ]], 
                   crewData.name, 
                   crewData.radioFrequency,
                   crewData.members[crewData.leader] and crewData.members[crewData.leader].displayName or "Unknown",
                   crewData.memberCount, 
                   CrewConfig.MaxCrewSize,
                   table.concat(memberList, "\n")
               )
               
               TriggerClientEvent('esx:showNotification', xPlayer.source, message)
           end
       else
           TriggerClientEvent('esx:showNotification', xPlayer.source, '❌ You are not in a crew')
       end
   end
end, false, {
   help = 'Crew management commands',
   validate = false,
   arguments = {
       {name = 'action', help = 'Action: create/invite/leave/info', type = 'string'},
       {name = 'name', help = 'Crew name (for create)', type = 'string'},
       {name = 'playerId', help = 'Player ID (for invite)', type = 'player'}
   }
})

-- Export functions
exports('GetPlayerCrew', function(source)
   local crewId = WarzoneCrews.PlayerCrews[source]
   return crewId and WarzoneCrews.GetCrewData(crewId) or nil
end)

exports('IsPlayerInCrew', function(source)
   return WarzoneCrews.PlayerCrews[source] ~= nil
end)

exports('GetCrewMembers', function(crewId)
   local crew = WarzoneCrews.ActiveCrews[crewId]
   return crew and crew.members or {}
end)