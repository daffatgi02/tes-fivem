-- resources/[warzone]/warzone_core/server/database.lua
WarzoneDB = {}

-- Initialize Database Tables
function WarzoneDB.Init()
    if Config.Debug then
        print("[WARZONE] Initializing database tables...")
    end
    
    -- Create warzone_players table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_players` (
            `identifier` VARCHAR(60) PRIMARY KEY,
            `nickname` VARCHAR(50) NOT NULL,
            `tag` VARCHAR(10) NOT NULL,
            `kills` INT DEFAULT 0,
            `deaths` INT DEFAULT 0,
            `money` INT DEFAULT 500,
            `current_role` VARCHAR(20) DEFAULT 'assault',
            `crew_id` INT NULL,
            `total_playtime` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_login` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY `nickname_tag` (`nickname`, `tag`)
        )
    ]])
    
    -- Create warzone_kills table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_kills` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `killer_identifier` VARCHAR(60) NOT NULL,
            `victim_identifier` VARCHAR(60) NOT NULL,
            `weapon` VARCHAR(50) NOT NULL,
            `zone` VARCHAR(30) NOT NULL,
            `distance` FLOAT NOT NULL,
            `headshot` BOOLEAN DEFAULT FALSE,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `killer_idx` (`killer_identifier`),
            INDEX `victim_idx` (`victim_identifier`),
            INDEX `time_idx` (`created_at`)
        )
    ]])
    
    -- Create warzone_sessions table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_sessions` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `player_identifier` VARCHAR(60) NOT NULL,
            `session_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `session_end` TIMESTAMP NULL,
            `kills_this_session` INT DEFAULT 0,
            `deaths_this_session` INT DEFAULT 0,
            `money_earned` INT DEFAULT 0
        )
    ]])
    
    if Config.Debug then
        print("[WARZONE] Database tables initialized successfully!")
    end
end

-- Player Database Functions
function WarzoneDB.GetPlayer(identifier)
    local result = MySQL.single.await('SELECT * FROM warzone_players WHERE identifier = ?', {identifier})
    return result
end

function WarzoneDB.CreatePlayer(identifier, nickname, tag)
    local insertId = MySQL.insert.await([[
        INSERT INTO warzone_players (identifier, nickname, tag, money) 
        VALUES (?, ?, ?, ?)
    ]], {identifier, nickname, tag, Config.DefaultMoney})
    
    if insertId then
        if Config.Debug then
            print(string.format("[WARZONE] Created new player: %s#%s (%s)", nickname, tag, identifier))
        end
        return true
    end
    return false
end

function WarzoneDB.UpdatePlayer(identifier, data)
    local setClause = {}
    local values = {}
    
    for key, value in pairs(data) do
        table.insert(setClause, key .. ' = ?')
        table.insert(values, value)
    end
    
    table.insert(values, identifier)
    
    local query = string.format('UPDATE warzone_players SET %s WHERE identifier = ?', table.concat(setClause, ', '))
    return MySQL.update.await(query, values)
end

function WarzoneDB.CheckNicknameTag(nickname, tag, excludeIdentifier)
    local query = 'SELECT identifier FROM warzone_players WHERE nickname = ? AND tag = ?'
    local params = {nickname, tag}
    
    if excludeIdentifier then
        query = query .. ' AND identifier != ?'
        table.insert(params, excludeIdentifier)
    end
    
    local result = MySQL.single.await(query, params)
    return result ~= nil
end

-- Kill Tracking Functions
function WarzoneDB.RecordKill(killerIdentifier, victimIdentifier, weapon, zone, distance, headshot)
    return MySQL.insert.await([[
        INSERT INTO warzone_kills (killer_identifier, victim_identifier, weapon, zone, distance, headshot) 
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {killerIdentifier, victimIdentifier, weapon, zone, distance, headshot or false})
end

function WarzoneDB.GetRecentKills(identifier, timeframe)
    timeframe = timeframe or 90 -- default 90 seconds
    return MySQL.query.await([[
        SELECT victim_identifier, created_at 
        FROM warzone_kills 
        WHERE killer_identifier = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)
    ]], {identifier, timeframe})
end

function WarzoneDB.GetTopKillers(limit)
    limit = limit or 10
    return MySQL.query.await([[
        SELECT nickname, tag, kills, deaths, 
               ROUND(kills/GREATEST(deaths, 1), 2) as kd_ratio
        FROM warzone_players 
        ORDER BY kills DESC 
        LIMIT ?
    ]], {limit})
end

-- Session Management
function WarzoneDB.StartSession(identifier)
    return MySQL.insert.await('INSERT INTO warzone_sessions (player_identifier) VALUES (?)', {identifier})
end

function WarzoneDB.EndSession(identifier)
    return MySQL.update.await([[
        UPDATE warzone_sessions 
        SET session_end = NOW() 
        WHERE player_identifier = ? AND session_end IS NULL
    ]], {identifier})
end