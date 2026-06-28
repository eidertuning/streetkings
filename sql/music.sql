CREATE TABLE IF NOT EXISTS music_tracks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    video_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    channel_title VARCHAR(255) NOT NULL DEFAULT '',
    thumbnail VARCHAR(500) NOT NULL DEFAULT '',
    duration INT UNSIGNED NOT NULL DEFAULT 0,
    url VARCHAR(500) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    play_count INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY unique_video_id (video_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_search_cache (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    query VARCHAR(120) NOT NULL,
    normalized_query VARCHAR(120) NOT NULL,
    results_json LONGTEXT NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY unique_normalized_query (normalized_query),
    KEY idx_normalized_query (normalized_query)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_playlists (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_identifier VARCHAR(128) NOT NULL,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(200) NOT NULL DEFAULT '',
    cover VARCHAR(500) NOT NULL DEFAULT '',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_player_identifier (player_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_playlist_tracks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    playlist_id INT UNSIGNED NOT NULL,
    track_id INT UNSIGNED NOT NULL,
    position INT UNSIGNED NOT NULL DEFAULT 0,
    added_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY unique_playlist_track (playlist_id, track_id),
    KEY idx_playlist_id (playlist_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_recent_tracks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_identifier VARCHAR(128) NOT NULL,
    track_id INT UNSIGNED NOT NULL,
    played_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_player_identifier (player_identifier),
    KEY idx_track_id (track_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_api_usage (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    usage_date DATE NOT NULL,
    api_searches INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY unique_usage_date (usage_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS music_user_daily_usage (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_identifier VARCHAR(128) NOT NULL,
    usage_date DATE NOT NULL,
    songs_played INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY unique_user_day (player_identifier, usage_date),
    KEY idx_player_identifier (player_identifier),
    KEY idx_usage_date (usage_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
