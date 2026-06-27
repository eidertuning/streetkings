-- "Prove Yourself" tutorial mission — homage to PS1 Driver (1999)

TutorialConfig = {
    TIMER_SECONDS = 60,

    INTERIOR_COORDS = vector3(-1993.0, 1117.0, -27.9),
    VEHICLE_SPAWN   = vector4(-1993.0, 1117.0, -27.9, 90.0),

    CAM_START  = vector3(-2014.0, 1108.0, -25.5),
    CAM_END    = vector3(-2000.0, 1120.0, -26.5),
    CAM_LOOKAT = vector3(-1993.0, 1117.0, -27.5),

    REWARDS = {
        playerXp  = 25,
        vehicleXp = 15,
        cash      = 2500,
    },

    -- Maneuver detection
    BURNOUT_DURATION_MS     = 2000,
    MIN_HANDBRAKE_SPEED_MPH = 5,
    SPEED_TARGET_MPH        = 50,
    BRAKE_HIGH_SPEED_MPH    = 40,
    BRAKE_STOP_SPEED_MPH    = 2,
    BRAKE_TIME_WINDOW_MS    = 3000,
    TURN_MIN_SPEED_MPH      = 10,
    TURN_180_MIN_DEG        = 150,
    TURN_180_MAX_DEG        = 210,
    TURN_360_MIN_DEG        = 330,
    TURN_360_MIN_SPEED_MPH  = 3,
    TURN_360_WINDOW_MS      = 6000,
    TURN_WINDOW_MS          = 4000,
    REVERSE_MIN_SPEED_MPH   = 8,

    DRIFT_MIN_LATERAL_MPS   = 2.0,
    DRIFT_MIN_FORWARD_MPS   = 3.0,
    DRIFT_DURATION_MS       = 1500,

    SLALOM_CONES = {
        vector4(-2031.74, 1126.62, -28.05, 0.34),
        vector4(-2031.74, 1136.62, -28.05, 0.34),
        vector4(-2031.74, 1146.62, -28.05, 0.34),
        vector4(-2031.74, 1156.62, -28.05, 0.34),
        vector4(-2031.74, 1166.62, -28.05, 0.34),
    },
    SLALOM_AXIS = 'y',

    CHECKPOINTS = {
        vector3(-1970.0, 1092.0, -27.9),
        vector3(-1970.0, 1140.0, -27.9),
        vector3(-2012.0, 1140.0, -27.9),
        vector3(-2012.0, 1092.0, -27.9),
    },
    CHECKPOINT_RADIUS = 6.0,

    HECTOR_INTRO    = "Nadie entra en mis calles sin demostrar que puede conducir. Quemadas, derrapes, giros con freno de mano - todo el repertorio. Tienes sesenta segundos. Impresióname.",
    HECTOR_PHONE    = "Tu teléfono es tu salvavidas aquí afuera. Pulsa TAB para abrirlo - mensajes, banco, mapa, todo. Así es como te mantienes adelante.",
}
