ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

local gameActive = false
local currentGameId = nil
local enemies = {}
local enemiesAlive = 0
local uiVisible = false
local playerWasAlive = true

-- Available weapons for player selection (Class 1-3)
local availableWeapons = {
    -- Pistols
    {hash = `WEAPON_PISTOL`, name = "Pistol", category = "Pistol", ammo = 250},
    {hash = `WEAPON_COMBATPISTOL`, name = "Combat Pistol", category = "Pistol", ammo = 250},
    {hash = `WEAPON_APPISTOL`, name = "AP Pistol", category = "Pistol", ammo = 250},
    {hash = `WEAPON_PISTOL50`, name = "Pistol .50", category = "Pistol", ammo = 200},
    {hash = `WEAPON_SNSPISTOL`, name = "SNS Pistol", category = "Pistol", ammo = 250},
    {hash = `WEAPON_HEAVYPISTOL`, name = "Heavy Pistol", category = "Pistol", ammo = 200},
    {hash = `WEAPON_VINTAGEPISTOL`, name = "Vintage Pistol", category = "Pistol", ammo = 200},
    
    -- SMGs
    {hash = `WEAPON_MICROSMG`, name = "Micro SMG", category = "SMG", ammo = 500},
    {hash = `WEAPON_SMG`, name = "SMG", category = "SMG", ammo = 500},
    {hash = `WEAPON_ASSAULTSMG`, name = "Assault SMG", category = "SMG", ammo = 500},
    {hash = `WEAPON_COMBATPDW`, name = "Combat PDW", category = "SMG", ammo = 500},
    {hash = `WEAPON_MACHINEPISTOL`, name = "Machine Pistol", category = "SMG", ammo = 500},
    {hash = `WEAPON_MINISMG`, name = "Mini SMG", category = "SMG", ammo = 500},
    
    -- Assault Rifles
    {hash = `WEAPON_ASSAULTRIFLE`, name = "Assault Rifle", category = "Rifle", ammo = 300},
    {hash = `WEAPON_CARBINERIFLE`, name = "Carbine Rifle", category = "Rifle", ammo = 300},
    {hash = `WEAPON_ADVANCEDRIFLE`, name = "Advanced Rifle", category = "Rifle", ammo = 300},
    {hash = `WEAPON_SPECIALCARBINE`, name = "Special Carbine", category = "Rifle", ammo = 300},
    {hash = `WEAPON_BULLPUPRIFLE`, name = "Bullpup Rifle", category = "Rifle", ammo = 300},
    {hash = `WEAPON_COMPACTRIFLE`, name = "Compact Rifle", category = "Rifle", ammo = 300},
    
    -- Shotguns
    {hash = `WEAPON_PUMPSHOTGUN`, name = "Pump Shotgun", category = "Shotgun", ammo = 150},
    {hash = `WEAPON_SAWNOFFSHOTGUN`, name = "Sawed-Off Shotgun", category = "Shotgun", ammo = 150},
    {hash = `WEAPON_ASSAULTSHOTGUN`, name = "Assault Shotgun", category = "Shotgun", ammo = 200},
    {hash = `WEAPON_BULLPUPSHOTGUN`, name = "Bullpup Shotgun", category = "Shotgun", ammo = 150},
    {hash = `WEAPON_MUSKET`, name = "Musket", category = "Shotgun", ammo = 100},
    {hash = `WEAPON_HEAVYSHOTGUN`, name = "Heavy Shotgun", category = "Shotgun", ammo = 150},
    {hash = `WEAPON_DBSHOTGUN`, name = "Double Barrel Shotgun", category = "Shotgun", ammo = 100},
    
    -- LMGs
    {hash = `WEAPON_MG`, name = "MG", category = "LMG", ammo = 500},
    {hash = `WEAPON_COMBATMG`, name = "Combat MG", category = "LMG", ammo = 500},
    {hash = `WEAPON_GUSENBERG`, name = "Gusenberg Sweeper", category = "LMG", ammo = 500}
}

-- Enemy weapons (simplified list)
local enemyWeaponList = {
    `WEAPON_PISTOL`,
    `WEAPON_COMBATPISTOL`,
    `WEAPON_MICROSMG`,
    `WEAPON_SMG`,
    `WEAPON_CARBINERIFLE`,
    `WEAPON_ASSAULTRIFLE`,
    `WEAPON_PUMPSHOTGUN`,
    `WEAPON_SAWNOFFSHOTGUN`
}

-- Commands
RegisterCommand('mulai', function()
    if not gameActive then
        openGameUI()
    else
        ESX.ShowNotification('Game sedang berlangsung! Ketik /stop untuk berhenti.')
    end
end)

RegisterCommand('stop', function()
    if gameActive then
        ESX.ShowNotification('Game dihentikan!')
        TriggerServerEvent('enemygame:stopGame', currentGameId)
    else
        ESX.ShowNotification('Tidak ada game yang sedang berlangsung.')
    end
end)

RegisterCommand('berhenti', function()
    if gameActive then
        ESX.ShowNotification('Game dihentikan!')
        TriggerServerEvent('enemygame:stopGame', currentGameId)
    else
        ESX.ShowNotification('Tidak ada game yang sedang berlangsung.')
    end
end)

-- UI Functions
function openGameUI()
    uiVisible = true
    SetNuiFocus(true, true)
    
    -- Send weapon data to UI
    SendNUIMessage({
        type = "showUI",
        action = "open",
        weapons = availableWeapons
    })
end

function closeGameUI()
    uiVisible = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "hideUI"
    })
end

-- NUI Callbacks
RegisterNUICallback('startGame', function(data, cb)
    local enemyCount = tonumber(data.enemyCount) or 5
    local spawnDistance = tonumber(data.spawnDistance) or 50
    local selectedWeapons = data.selectedWeapons or {}
    
    -- Validate weapon selection
    if #selectedWeapons ~= 2 then
        ESX.ShowNotification('❌ Anda harus memilih tepat 2 senjata!')
        cb('error')
        return
    end
    
    -- Clamp values
    enemyCount = math.max(1, math.min(15, enemyCount))
    spawnDistance = math.max(20, math.min(150, spawnDistance))
    
    closeGameUI()
    
    -- Give player selected weapons and armor
    givePlayerLoadout(selectedWeapons)
    
    TriggerServerEvent('enemygame:startGame', enemyCount, spawnDistance)
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    closeGameUI()
    cb('ok')
end)

RegisterNUICallback('stopGame', function(data, cb)
    if gameActive then
        TriggerServerEvent('enemygame:stopGame', currentGameId)
    end
    cb('ok')
end)

-- Give player weapons and armor
function givePlayerLoadout(selectedWeapons)
    local playerPed = PlayerPedId()
    
    -- Give full armor
    SetPedArmour(playerPed, 100)
    ESX.ShowNotification('🛡️ Armor penuh diperoleh!')
    
    -- Remove all weapons first
    RemoveAllPedWeapons(playerPed, true)
    
    -- Give selected weapons
    for i, weaponHash in ipairs(selectedWeapons) do
        local weaponData = nil
        
        -- Find weapon data
        for _, weapon in ipairs(availableWeapons) do
            if weapon.hash == weaponHash then
                weaponData = weapon
                break
            end
        end
        
        if weaponData then
            GiveWeaponToPed(playerPed, weaponData.hash, weaponData.ammo, false, true)
            ESX.ShowNotification('🔫 ' .. weaponData.name .. ' diperoleh!')
        end
    end
    
    -- Give some extra ammo
    for i, weaponHash in ipairs(selectedWeapons) do
        AddAmmoToPed(playerPed, weaponHash, 500)
    end
end

-- Game Events
RegisterNetEvent('enemygame:gameStarted')
AddEventHandler('enemygame:gameStarted', function(gameId, enemyCount)
    currentGameId = gameId
    gameActive = true
    enemiesAlive = enemyCount
    playerWasAlive = true
    
    ESX.ShowNotification('🎯 Game dimulai! Bunuh semua musuh!')
    ESX.ShowNotification('💡 Ketik /stop untuk berhenti game')
    spawnEnemies(enemyCount, 50)
    
    SendNUIMessage({
        type = "showGameUI",
        enemiesLeft = enemiesAlive
    })
end)

RegisterNetEvent('enemygame:updateUI')
AddEventHandler('enemygame:updateUI', function(enemiesLeft)
    enemiesAlive = enemiesLeft
    SendNUIMessage({
        type = "updateEnemies",
        enemiesLeft = enemiesLeft
    })
end)

RegisterNetEvent('enemygame:gameCompleted')
AddEventHandler('enemygame:gameCompleted', function()
    ESX.ShowNotification('🎉 Selamat! Semua musuh telah dikalahkan!')
    endGame()
end)

RegisterNetEvent('enemygame:gameStopped')
AddEventHandler('enemygame:gameStopped', function()
    ESX.ShowNotification('Game dihentikan!')
    endGame()
end)

-- Player death detection thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if gameActive then
            local playerPed = PlayerPedId()
            local isPlayerAlive = not IsEntityDead(playerPed)
            
            -- Check if player just died
            if playerWasAlive and not isPlayerAlive then
                ESX.ShowNotification('💀 Anda mati! Game akan direset...')
                Wait(2000) -- Give time for death animation
                
                -- Reset game
                if currentGameId then
                    TriggerServerEvent('enemygame:playerDied', currentGameId)
                end
                
                endGame()
                ESX.ShowNotification('🔄 Game direset. Ketik /mulai untuk bermain lagi.')
            end
            
            playerWasAlive = isPlayerAlive
        end
    end
end)

-- Spawn enemies function
function spawnEnemies(count, distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for i = 1, count do
        Citizen.CreateThread(function()
            Wait(i * 100) -- Stagger spawning
            
            local spawnCoords = getRandomSpawnPoint(playerCoords, distance)
            
            RequestModel(`s_m_y_swat_01`)
            local timeout = 0
            while not HasModelLoaded(`s_m_y_swat_01`) and timeout < 50 do
                Wait(100)
                timeout = timeout + 1
            end
            
            if HasModelLoaded(`s_m_y_swat_01`) then
                local enemy = CreatePed(4, `s_m_y_swat_01`, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, true)
                
                if DoesEntityExist(enemy) then
                    -- Set enemy properties
                    SetPedFleeAttributes(enemy, 0, 0)
                    SetPedCombatAttributes(enemy, 46, 1)
                    SetPedCombatAbility(enemy, 1)
                    SetPedAccuracy(enemy, 45)
                    SetPedArmour(enemy, 50)
                    SetPedMaxHealth(enemy, 150)
                    SetEntityHealth(enemy, 150)
                    
                    -- Give random weapon
                    local randomWeapon = enemyWeaponList[math.random(#enemyWeaponList)]
                    GiveWeaponToPed(enemy, randomWeapon, 200, false, true)
                    
                    TaskCombatPed(enemy, playerPed, 0, 16)
                    
                    enemies[enemy] = {
                        id = i,
                        ped = enemy,
                        coords = spawnCoords,
                        lastUpdate = GetGameTimer(),
                        blip = nil
                    }
                end
            end
            
            SetModelAsNoLongerNeeded(`s_m_y_swat_01`)
        end)
    end
end

function getRandomSpawnPoint(playerCoords, distance)
    local angle = math.random() * 2 * math.pi
    local x = playerCoords.x + math.cos(angle) * distance
    local y = playerCoords.y + math.sin(angle) * distance
    
    local z = playerCoords.z
    local groundZ, _ = GetGroundZFor_3dCoord(x, y, z + 10.0, true)
    if groundZ ~= 0 then
        z = groundZ + 1.0
    end
    
    return vector3(x, y, z)
end

-- Main game loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        
        if gameActive then
            local playerPed = PlayerPedId()
            local currentTime = GetGameTimer()
            
            for enemyPed, enemyData in pairs(enemies) do
                if DoesEntityExist(enemyPed) then
                    if IsEntityDead(enemyPed) then
                        cleanupEnemy(enemyPed, enemyData)
                        enemies[enemyPed] = nil
                        TriggerServerEvent('enemygame:enemyKilled', currentGameId, enemyData.id)
                    else
                        -- Update enemy task less frequently
                        if currentTime - enemyData.lastUpdate > 5000 then
                            if DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
                                TaskCombatPed(enemyPed, playerPed, 0, 16)
                            end
                            enemyData.lastUpdate = currentTime
                        end
                    end
                else
                    cleanupEnemy(enemyPed, enemyData)
                    enemies[enemyPed] = nil
                end
            end
        end
    end
end)

-- Blip update thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        
        if gameActive then
            for enemyPed, enemyData in pairs(enemies) do
                if DoesEntityExist(enemyPed) and not IsEntityDead(enemyPed) then
                    -- Remove old blip
                    if enemyData.blip and DoesBlipExist(enemyData.blip) then
                        RemoveBlip(enemyData.blip)
                    end
                    
                    -- Create new blip
                    local coords = GetEntityCoords(enemyPed)
                    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                    
                    SetBlipSprite(blip, 1)
                    SetBlipColour(blip, 1)
                    SetBlipScale(blip, 0.7)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString("Musuh")
                    EndTextCommandSetBlipName(blip)
                    
                    enemyData.blip = blip
                end
            end
        end
    end
end)

-- Cleanup functions
function cleanupEnemy(enemyPed, enemyData)
    if enemyData.blip and DoesBlipExist(enemyData.blip) then
        RemoveBlip(enemyData.blip)
    end
    if DoesEntityExist(enemyPed) then
        DeleteEntity(enemyPed)
    end
end

function endGame()
    gameActive = false
    currentGameId = nil
    enemiesAlive = 0
    playerWasAlive = true
    
    -- Clean up all enemies
    for enemyPed, enemyData in pairs(enemies) do
        cleanupEnemy(enemyPed, enemyData)
    end
    
    enemies = {}
    
    -- Hide UI
    SendNUIMessage({
        type = "hideGameUI"
    })
    
    -- Force garbage collection
    collectgarbage("collect")
end

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        endGame()
    end
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    if gameActive then
        endGame()
    end
end)