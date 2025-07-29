-- resources/[warzone]/warzone_core/sql/install.sql

-- Create warzone_players table
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
    UNIQUE KEY `nickname_tag` (`nickname`, `tag`),
    INDEX `kills_idx` (`kills` DESC),
    INDEX `money_idx` (`money` DESC),
    INDEX `last_login_idx` (`last_login`)
);

-- Create warzone_kills table
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
    INDEX `time_idx` (`created_at`),
    INDEX `zone_idx` (`zone`)
);

-- Create warzone_sessions table
CREATE TABLE IF NOT EXISTS `warzone_sessions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_identifier` VARCHAR(60) NOT NULL,
    `session_start` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `session_end` TIMESTAMP NULL,
    `kills_this_session` INT DEFAULT 0,
    `deaths_this_session` INT DEFAULT 0,
    `money_earned` INT DEFAULT 0,
    INDEX `player_idx` (`player_identifier`),
    INDEX `session_start_idx` (`session_start`)
);

-- Insert default roles if needed
INSERT IGNORE INTO `warzone_player_roles` (`role_name`, `display_name`, `description`) VALUES
('assault', 'Assault', 'High damage, heavy weapons access'),
('support', 'Support', 'Extra ammo, team support abilities'),
('medic', 'Medic', 'Fast revival, medical equipment'),
('recon', 'Recon', 'Enhanced radar, sniper weapons');