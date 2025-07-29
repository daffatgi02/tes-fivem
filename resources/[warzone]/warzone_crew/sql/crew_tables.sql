-- resources/[warzone]/warzone_crew/sql/crew_tables.sql

-- Create crews table
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
    INDEX `name_idx` (`name`),
    INDEX `created_idx` (`created_at`)
);

-- Create crew members table
CREATE TABLE IF NOT EXISTS `warzone_crew_members` (
    `crew_id` INT NOT NULL,
    `player_identifier` VARCHAR(60) NOT NULL,
    `role` ENUM('leader', 'officer', 'member') DEFAULT 'member',
    `kills_contributed` INT DEFAULT 0,
    `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`crew_id`, `player_identifier`),
    INDEX `player_idx` (`player_identifier`),
    INDEX `crew_idx` (`crew_id`),
    INDEX `role_idx` (`role`),
    FOREIGN KEY (`crew_id`) REFERENCES `warzone_crews`(`id`)
    ON DELETE CASCADE
);

-- Create crew invitations table
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
   INDEX `status_idx` (`status`),
   INDEX `expires_idx` (`expires_at`),
   FOREIGN KEY (`crew_id`) REFERENCES `warzone_crews`(`id`) ON DELETE CASCADE
);

-- Create crew statistics table
CREATE TABLE IF NOT EXISTS `warzone_crew_stats` (
   `crew_id` INT NOT NULL,
   `date` DATE NOT NULL,
   `total_kills` INT DEFAULT 0,
   `total_deaths` INT DEFAULT 0,
   `members_active` INT DEFAULT 0,
   `time_active` INT DEFAULT 0, -- in minutes
   PRIMARY KEY (`crew_id`, `date`),
   FOREIGN KEY (`crew_id`) REFERENCES `warzone_crews`(`id`) ON DELETE CASCADE
);

-- Create crew events log table
CREATE TABLE IF NOT EXISTS `warzone_crew_events` (
   `id` INT AUTO_INCREMENT PRIMARY KEY,
   `crew_id` INT NOT NULL,
   `event_type` ENUM('created', 'member_joined', 'member_left', 'member_kicked', 'member_promoted', 'member_demoted', 'disbanded') NOT NULL,
   `player_identifier` VARCHAR(60),
   `target_identifier` VARCHAR(60),
   `event_data` JSON,
   `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   INDEX `crew_idx` (`crew_id`),
   INDEX `type_idx` (`event_type`),
   INDEX `time_idx` (`created_at`),
   FOREIGN KEY (`crew_id`) REFERENCES `warzone_crews`(`id`) ON DELETE CASCADE
);

-- Insert some sample crew colors
INSERT IGNORE INTO `warzone_crew_colors` (`id`, `name`, `hex_color`) VALUES
(0, 'Red', '#FF0000'),
(1, 'Green', '#00FF00'),
(2, 'Blue', '#0000FF'),
(3, 'Yellow', '#FFFF00'),
(4, 'Magenta', '#FF00FF'),
(5, 'Cyan', '#00FFFF'),
(6, 'Orange', '#FFA500'),
(7, 'Purple', '#800080');

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS `crew_members_online` ON `warzone_crew_members` (`crew_id`) WHERE `last_seen` > DATE_SUB(NOW(), INTERVAL 10 MINUTE);
CREATE INDEX IF NOT EXISTS `active_invitations` ON `warzone_crew_invitations` (`status`, `expires_at`) WHERE `status` = 'pending';

-- Create triggers for automatic cleanup
DELIMITER $$

CREATE TRIGGER IF NOT EXISTS `cleanup_expired_invitations` 
BEFORE INSERT ON `warzone_crew_invitations`
FOR EACH ROW
BEGIN
   DELETE FROM `warzone_crew_invitations` 
   WHERE `expires_at` < NOW() AND `status` = 'pending';
END$$

CREATE TRIGGER IF NOT EXISTS `update_crew_member_count`
AFTER INSERT ON `warzone_crew_members`
FOR EACH ROW
BEGIN
   UPDATE `warzone_crews` 
   SET `members_count` = (
       SELECT COUNT(*) FROM `warzone_crew_members` 
       WHERE `crew_id` = NEW.crew_id
   )
   WHERE `id` = NEW.crew_id;
END$$

CREATE TRIGGER IF NOT EXISTS `update_crew_member_count_delete`
AFTER DELETE ON `warzone_crew_members`
FOR EACH ROW
BEGIN
   UPDATE `warzone_crews` 
   SET `members_count` = (
       SELECT COUNT(*) FROM `warzone_crew_members` 
       WHERE `crew_id` = OLD.crew_id
   )
   WHERE `id` = OLD.crew_id;
END$$

DELIMITER ;