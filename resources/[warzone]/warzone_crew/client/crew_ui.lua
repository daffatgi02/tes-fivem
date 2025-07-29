-- resources/[warzone]/warzone_crew/client/crew_ui.lua

local CrewUI = {}
local currentCrewData = nil
local invitationData = nil
local uiVisible = false

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Open crew management UI
function CrewUI.OpenManagementUI()
    if not currentCrewData then
        CrewUI.OpenCreationUI()
        return
    end
    
    uiVisible = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        type = "showCrewManagement",
        crewData = currentCrewData
    })
end

-- Open crew creation UI
function CrewUI.OpenCreationUI()
    uiVisible = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        type = "showCrewCreation",
        cost = CrewConfig.CrewCreationCost
    })
end

-- Close UI
function CrewUI.CloseUI()
    uiVisible = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = "hideUI"
    })
end

-- Show invitation
function CrewUI.ShowInvitation(inviteData)
    invitationData = inviteData
    
    SendNUIMessage({
        type = "showInvitation",
        invitation = inviteData
    })
end

-- NUI Callbacks
RegisterNUICallback('createCrew', function(data, cb)
    local crewName = data.crewName
    
    if not crewName or string.len(crewName) < CrewConfig.CrewNameMinLength then
        cb({success = false, message = "Crew name too short"})
        return
    end
    
    TriggerServerEvent('warzone_crew:createCrew', crewName)
    CrewUI.CloseUI()
    cb({success = true})
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    
    if not playerId then
        cb({success = false, message = "Invalid player ID"})
        return
    end
    
    TriggerServerEvent('warzone_crew:invitePlayer', playerId)
    cb({success = true})
end)

RegisterNUICallback('leaveCrew', function(data, cb)
    TriggerServerEvent('warzone_crew:leaveCrew')
    CrewUI.CloseUI()
    cb({success = true})
end)

RegisterNUICallback('promoteMember', function(data, cb)
    TriggerServerEvent('warzone_crew:promoteMember', data.identifier)
    cb({success = true})
end)

RegisterNUICallback('demoteMember', function(data, cb)
    TriggerServerEvent('warzone_crew:demoteMember', data.identifier)
    cb({success = true})
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('warzone_crew:kickMember', data.identifier)
    cb({success = true})
end)

RegisterNUICallback('acceptInvitation', function(data, cb)
    if invitationData then
        TriggerServerEvent('warzone_crew:acceptInvitation', invitationData.inviteId)
        invitationData = nil
    end
    cb({success = true})
end)

RegisterNUICallback('declineInvitation', function(data, cb)
    invitationData = nil
    SendNUIMessage({
        type = "hideInvitation"
    })
    cb({success = true})
end)

RegisterNUICallback('closeUI', function(data, cb)
    CrewUI.CloseUI()
    cb({success = true})
end)

-- Events
RegisterNetEvent('warzone_crew:updateCrewData')
AddEventHandler('warzone_crew:updateCrewData', function(crewData)
    currentCrewData = crewData
    
    if uiVisible and crewData then
        SendNUIMessage({
            type = "updateCrewData",
            crewData = crewData
        })
    end
end)

RegisterNetEvent('warzone_crew:receiveInvitation')
AddEventHandler('warzone_crew:receiveInvitation', function(inviteData)
    CrewUI.ShowInvitation(inviteData)
    
    -- Auto-expire invitation
    Citizen.SetTimeout(inviteData.expiresIn * 1000, function()
        if invitationData and invitationData.inviteId == inviteData.inviteId then
            invitationData = nil
            SendNUIMessage({
                type = "hideInvitation"
            })
            ESX.ShowNotification('⏰ Crew invitation expired')
        end
    end)
end)

RegisterNetEvent('warzone_crew:crewActionResult')
AddEventHandler('warzone_crew:crewActionResult', function(action, success, message)
    if success then
        ESX.ShowNotification('✅ ' .. message)
    else
        ESX.ShowNotification('❌ ' .. message)
    end
    
    -- Refresh UI if open
    if uiVisible then
        Citizen.SetTimeout(1000, function()
            if currentCrewData then
                SendNUIMessage({
                    type = "updateCrewData",
                    crewData = currentCrewData
                })
            end
        end)
    end
end)

-- Commands
RegisterCommand('crewmenu', function()
    CrewUI.OpenManagementUI()
end)

RegisterKeyMapping('crewmenu', 'Open Crew Menu', 'keyboard', 'F6')

-- Export functions
exports('OpenCrewUI', CrewUI.OpenManagementUI)
exports('GetCurrentCrew', function() return currentCrewData end)