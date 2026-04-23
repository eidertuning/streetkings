MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `event_leaderboards` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `license` VARCHAR(64) NOT NULL,
            `alias` VARCHAR(64) NOT NULL,
            `event_id` VARCHAR(64) NOT NULL,
            `vehicle_class` VARCHAR(16) NOT NULL DEFAULT '',
            `score_value` INT NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY `idx_event_created` (`event_id`, `created_at`),
            KEY `idx_event_score` (`event_id`, `score_value`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        ALTER TABLE `event_leaderboards`
        ADD COLUMN IF NOT EXISTS `vehicle_class` VARCHAR(16) NOT NULL DEFAULT ''
    ]])
    MySQL.query.await([[
        ALTER TABLE `event_leaderboards`
        ADD COLUMN IF NOT EXISTS `vehicle_model` VARCHAR(64) NOT NULL DEFAULT ''
    ]])
    SKEventsServer.dbReady = true
end)