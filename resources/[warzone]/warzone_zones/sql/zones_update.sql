-- resources/[warzone]/warzone_zones/sql/zones_update.sql

-- Create zones activity table
CREATE TABLE IF NOT EXISTS `warzone_zones_activity` (
    `zone_name` VARCHAR(50) PRIMARY KEY,
    `activity_level` ENUM('white', 'yellow', 'red') DEFAULT 'white',
    `kills_last_5min` INT DEFAULT 0,
    `last_activity` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `total_kills` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `activity_idx` (`activity_level`),
    INDEX `last_activity_idx` (`last_activity`)
);

-- Create zone events table for detailed tracking
CREATE TABLE IF NOT EXISTS `warzone_zone_events` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `zone_name` VARCHAR(50) NOT NULL,
    `event_type` ENUM('kill', 'death', 'entry', 'exit') NOT NULL,
    `player_identifier` VARCHAR(60) NOT NULL,
    `event_data` JSON,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `zone_idx` (`zone_name`),
    INDEX `time_idx` (`created_at`),
    INDEX `player_idx` (`player_identifier`),
    INDEX `event_type_idx` (`event_type`)
);

-- Insert initial zone records
INSERT IGNORE INTO `warzone_zones_activity` (`zone_name`) VALUES 
('downtown_ls'),
('vinewood'),
('vespucci_beach'),
('del_perro'),
('sandy_shores'),
('paleto_bay'),
('grapeseed'),
('mirror_park');

-- Update warzone_kills table to include zone index
ALTER TABLE `warzone_kills` ADD INDEX `zone_idx` (`zone`);