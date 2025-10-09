local config = {
    STOCKFISH_URL = "http://localhost:8080",
    
    CLOCK_WAIT_MAPPING = {
        ["∞"] = {min = 4, max = 7},
        ["1:00"] = {min = 0, max = 1},
        ["3:00"] = {min = 2, max = 3},
        ["10:00"] = {min = 4, max = 7},
    },
    
    CLOCK_NAME_MAPPING = {
        ["1:00"] = "bullet",
        ["3:00"] = "blitz",
        ["10:00"] = "rapid",
        ["∞"] = "casual",
    },
    
    ENGINE = {
        THREADS = 5,
        CONTEMPT = 100,
        HASH = 128,
        PONDER_DEPTH = 12,
        MOVES_TO_GO = 40
    }
}

return config
