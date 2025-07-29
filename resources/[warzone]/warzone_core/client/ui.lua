-- resources/[warzone]/warzone_core/client/ui.lua

local hudVisible = true
local killFeed = {}
local maxKillFeedEntries = 5

-- HUD Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if hudVisible and WarzonePlayer.IsLoggedIn() then
            local playerData = WarzonePlayer.GetData()
            if playerData then
                -- Draw basic HUD info
                DrawHUD(playerData)
            end
        end
    end
end)

-- Draw HUD Function
function DrawHUD(playerData)
    local screenX, screenY = GetActiveScreenResolution()
    
    -- Player Info (top left)
    local playerText = string.format("~b~%s~w~#~y~%s~w~ | Role: ~g~%s", 
        playerData.nickname, playerData.tag, Config.Roles[playerData.role].label)
    
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(playerText)
    DrawText(0.01, 0.01)
    
    -- Stats (top left, below player info)
    local statsText = string.format("K/D: ~g~%d~w~/~r~%d~w~ | Money: ~g~$%d", 
        playerData.kills, playerData.deaths, playerData.money)
    
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(statsText)
    DrawText(0.01, 0.04)
    
    -- Combat Status
    if WarzonePlayer.IsInCombat() then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.0, 0.4)
        SetTextColour(255, 0, 0, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextEntry("STRING")
        AddTextComponentString("~r~⚔ IN COMBAT")
        DrawText(0.01, 0.07)
    end
    
    -- Kill Feed (top right)
    DrawKillFeed()
end

-- Kill Feed Management
function DrawKillFeed()
    local startY = 0.05
    local lineHeight = 0.03
    
    for i, kill in ipairs(killFeed) do
        if i <= maxKillFeedEntries then
            local alpha = math.max(0, 255 - ((GetGameTimer() - kill.time) / 20)) -- Fade after 5 seconds
            
            if alpha > 0 then
                local killText = string.format("~r~%s ~w~killed ~y~%s", kill.killer, kill.victim)
                if kill.headshot then
                    killText = killText .. " ~r~[HS]"
                end
                if kill.distance then
                    killText = killText .. string.format(" ~w~(%.0fm)", kill.distance)
                end
                
                SetTextFont(4)
                SetTextProportional(true)
                SetTextScale(0.0, 0.35)
                SetTextColour(255, 255, 255, alpha)
                SetTextDropshadow(0, 0, 0, 0, alpha)
                SetTextEdge(1, 0, 0, 0, alpha)
                SetTextEntry("STRING")
                AddTextComponentString(killText)
                SetTextRightJustify(true)
                SetTextWrap(0.0, 0.98)
                DrawText(0.0, startY + (i - 1) * lineHeight)
            else
                -- Remove faded entries
                table.remove(killFeed, i)
            end
        end
    end
end

-- Add Kill to Feed
RegisterNetEvent('warzone:addKillFeed')
AddEventHandler('warzone:addKillFeed', function(data)
    table.insert(killFeed, 1, {
        killer = data.killer,
        victim = data.victim,
        headshot = data.headshot,
        distance = data.distance,
        time = GetGameTimer()
    })
    
    -- Remove old entries
    while #killFeed > maxKillFeedEntries do
        table.remove(killFeed)
    end
end)

-- Update HUD Data
RegisterNetEvent('warzone:updateHUD')
AddEventHandler('warzone:updateHUD', function(data)
    -- Update local player data for HUD
    for key, value in pairs(data) do
        if WarzonePlayer.GetData()[key] ~= nil then
            WarzonePlayer.GetData()[key] = value
        end
    end
end)

-- Update Role
RegisterNetEvent('warzone:updateRole')
AddEventHandler('warzone:updateRole', function(newRole)
    local playerData = WarzonePlayer.GetData()
    if playerData then
        playerData.role = newRole
    end
end)

-- Toggle HUD
RegisterCommand('togglehud', function()
    hudVisible = not hudVisible
    ESX.ShowNotification(hudVisible and '✅ HUD Enabled' or '❌ HUD Disabled')
end)

-- Commands for UI testing
RegisterCommand('testhud', function()
    -- Test kill feed
    TriggerEvent('warzone:addKillFeed', {
        killer = "TestKiller#123",
        victim = "TestVictim#456",
        headshot = true,
        distance = 150.5
    })
end)