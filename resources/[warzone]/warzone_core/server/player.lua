-- resources/[warzone]/warzone_core/server/player.lua
WarzonePlayer = {}
WarzonePlayer.Players = {}

-- Player Class
local Player = {}
Player.__index = Player

function Player:new(source, data)
    local obj = {
        source = source,
        identifier = data.identifier,
        nickname = data.nickname,
        tag = data.tag,
        kills = data.kills or 0,
        deaths = data.deaths or 0,
        money = data.money or Config.DefaultMoney,
        role = data.current_role or 'assault',
        crew_id = data.crew_id,
        combatStatus = false,
        combatTimeout = 0,
        lastKills = {}, -- For anti-farm tracking
        armor = 0,
        armorKits = 0
    }
    setmetatable(obj, Player)
    return obj
end

function Player:GetDisplayName()
    return string.format("%s#%s", self.nickname, self.tag)
end

function Player:AddKill(victim, weapon, zone, distance, headshot)
    -- Check anti-farm
    if self:IsKillValid(victim.identifier) then
        self.kills = self.kills + 1
        self.money = self.money + Config.KillReward
        
        -- Record kill in database
        WarzoneDB.RecordKill(self.identifier, victim.identifier, weapon, zone, distance, headshot)
        
        -- Update anti-farm tracking
        table.insert(self.lastKills, {
            victim = victim.identifier,
            time = os.time()
        })
        
        -- Apply role bonuses
        local roleConfig = Config.Roles[self.role]
        if roleConfig and roleConfig.killBonus then
            self.money = self.money + roleConfig.killBonus
        end
        
        -- Notify player
        local bonusText = headshot and " (+HEADSHOT BONUS)" or ""
        TriggerClientEvent('esx:showNotification', self.source, 
            string.format('💀 Kill: %s (+$%d%s)', victim:GetDisplayName(), Config.KillReward, bonusText))
        
        -- Update ESX money
        local xPlayer = ESX.GetPlayerFromId(self.source)
        if xPlayer then
            xPlayer.addMoney(Config.KillReward)
        end
        
        return true
    end
    return false
end

function Player:AddDeath(killer)
    self.deaths = self.deaths + 1
    
    -- Reset combat status
    self.combatStatus = false
    self.combatTimeout = 0
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', self.source, 
        string.format('💀 Killed by: %s', killer and killer:GetDisplayName() or "Unknown"))
end

function Player:IsKillValid(victimIdentifier)
    -- Check cooldown for this specific victim
    for i = #self.lastKills, 1, -1 do
        local kill = self.lastKills[i]
        
        -- Remove old kills
        if os.time() - kill.time > Config.KillCooldown then
            table.remove(self.lastKills, i)
        elseif kill.victim == victimIdentifier then
            -- Recent kill from same victim
            return false
        end
    end
    
    return true
end

function Player:SetCombatStatus(status)
    self.combatStatus = status
    if status then
        self.combatTimeout = os.time() + Config.CombatTimeout
        TriggerClientEvent('warzone:setCombatStatus', self.source, true)
    else
        self.combatTimeout = 0
        TriggerClientEvent('warzone:setCombatStatus', self.source, false)
    end
end

function Player:IsInCombat()
    if self.combatStatus and os.time() < self.combatTimeout then
        return true
    elseif self.combatStatus then
        -- Combat timeout expired
        self:SetCombatStatus(false)
    end
    return false
end

function Player:AddArmor(amount)
    if self.armor < Config.MaxArmor then
        self.armor = math.min(self.armor + amount, Config.MaxArmor)
        
        -- Apply to game
        local ped = GetPlayerPed(self.source)
        SetPedArmour(ped, self.armor)
        
        TriggerClientEvent('esx:showNotification', self.source, 
            string.format('🛡️ Armor: %d/%d', self.armor, Config.MaxArmor))
        return true
    end
    return false
end

function Player:Save()
    local data = {
        kills = self.kills,
        deaths = self.deaths,
        money = self.money,
        current_role = self.role,
        crew_id = self.crew_id,
        last_login = 'NOW()'
    }
    
    return WarzoneDB.UpdatePlayer(self.identifier, data)
end

-- Static Methods
function WarzonePlayer.Load(source, data)
    local player = Player:new(source, data)
    WarzonePlayer.Players[source] = player
    
    -- Trigger client-side load
    TriggerClientEvent('warzone:playerLoaded', source, {
        nickname = player.nickname,
        tag = player.tag,
        role = player.role,
        kills = player.kills,
        deaths = player.deaths,
        money = player.money
    })
    
    return player
end

function WarzonePlayer.GetBySource(source)
    return WarzonePlayer.Players[source]
end

function WarzonePlayer.GetByIdentifier(identifier)
    for source, player in pairs(WarzonePlayer.Players) do
        if player.identifier == identifier then
            return player
        end
    end
    return nil
end

function WarzonePlayer.Save(source)
    local player = WarzonePlayer.Players[source]
    if player then
        player:Save()
        WarzonePlayer.Players[source] = nil
    end
end

function WarzonePlayer.GetAll()
    return WarzonePlayer.Players
end

-- Combat Status Monitor
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Check every 5 seconds
        
        for source, player in pairs(WarzonePlayer.Players) do
            if player:IsInCombat() then
                -- Still in combat, continue monitoring
            end
        end
    end
end)