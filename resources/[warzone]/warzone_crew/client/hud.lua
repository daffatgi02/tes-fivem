-- resources/[warzone]/warzone_crew/client/hud.lua

local CrewHUD = {}
local showCrewHUD = true
local crewMembers = {}

-- Draw crew HUD
function CrewHUD.DrawCrewInfo()
    if not showCrewHUD or not currentCrewData then return end
    
    local memberCount = 0
    local onlineMembers = {}
    
    -- Get online members
    for identifier, member in pairs(currentCrewData.members) do
        if member.online then
            memberCount = memberCount + 1
            if memberCount <= CrewConfig.UI.MaxDisplayMembers then
                table.insert(onlineMembers, member)
            end
        end
    end
    
    if memberCount == 0 then return end
    
    -- Draw crew name and radio
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(string.format("👥 %s | 📻 %.1f", currentCrewData.name, currentCrewData.radioFrequency))
    DrawText(0.01, 0.15)
    
    -- Draw online members
    local startY = 0.18
    local lineHeight = 0.025
    
    for i, member in ipairs(onlineMembers) do
        local memberText = string.format("• %s", member.displayName)
        
        -- Add role indicator
        if member.role == 'leader' then
            memberText = "👑 " .. memberText
        elseif member.role == 'officer' then
            memberText = "⭐ " .. memberText
        end
        
        -- Add distance if available
        if CrewConfig.UI.ShowDistance and member.source then
            local targetPed = GetPlayerPed(GetPlayerFromServerId(member.source))
            if targetPed ~= 0 then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)
                
                if distance < 1000 then
                    memberText = memberText .. string.format(" (%.0fm)", distance)
                end
            end
        end
        
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.0, 0.3)
        SetTextColour(200, 200, 200, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextEntry("STRING")
        AddTextComponentString(memberText)
        DrawText(0.01, startY + (i - 1) * lineHeight)
    end
    
    -- Show more indicator if needed
    if memberCount > CrewConfig.UI.MaxDisplayMembers then
        local moreText = string.format("... and %d more", memberCount - CrewConfig.UI.MaxDisplayMembers)
        
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.0, 0.25)
        SetTextColour(150, 150, 150, 255)
        SetTextEntry("STRING")
        AddTextComponentString(moreText)
        DrawText(0.01, startY + CrewConfig.UI.MaxDisplayMembers * lineHeight)
    end
end

-- Draw crew member blips
function CrewHUD.UpdateCrewBlips()
    if not CrewConfig.Abilities.CrewBlips or not currentCrewData then return end
    
    -- Remove old blips
    for _, blipData in pairs(crewMembers) do
        if blipData.blip and DoesBlipExist(blipData.blip) then
            RemoveBlip(blipData.blip)
        end
    end
    crewMembers = {}
    
    -- Create new blips for online members
    for identifier, member in pairs(currentCrewData.members) do
        if member.online and member.source then
            local targetPed = GetPlayerPed(GetPlayerFromServerId(member.source))
            if targetPed ~= 0 and targetPed ~= PlayerPedId() then
                local blip = AddBlipForEntity(targetPed)
                SetBlipSprite(blip, 1) -- Circle
                SetBlipColour(blip, 2) -- Green
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, true)
                
                -- Set blip name based on role
                local roleIcon = ""
                if member.role == 'leader' then
                    roleIcon = "👑 "
                    SetBlipColour(blip, 5) -- Yellow for leader
                elseif member.role == 'officer' then
                    roleIcon = "⭐ "
                    SetBlipColour(blip, 3) -- Blue for officer
                end
                
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(roleIcon .. member.displayName)
                EndTextCommandSetBlipName(blip)
                
                crewMembers[identifier] = {
                    blip = blip,
                    source = member.source
                }
            end
        end
    end
end

-- HUD thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if showCrewHUD then
            CrewHUD.DrawCrewInfo()
        else
            Citizen.Wait(1000)
        end
    end
end)

-- Blip update thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(CrewConfig.UI.UpdateInterval)
        
        if currentCrewData then
            CrewHUD.UpdateCrewBlips()
        end
    end
end)

-- Commands
RegisterCommand('togglecrewhud', function()
    showCrewHUD = not showCrewHUD
    ESX.ShowNotification(showCrewHUD and '✅ Crew HUD enabled' or '❌ Crew HUD disabled')
end)

-- Export functions
exports('ToggleCrewHUD', function(visible)
    showCrewHUD = visible
end)

exports('IsCrewHUDVisible', function()
    return showCrewHUD
end)