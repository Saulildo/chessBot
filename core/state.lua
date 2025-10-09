local state = {
    aiLoaded = false,
    aiRunning = false,
    autoMove = true,
    gameConnected = false,
    currentAnalysisId = nil,
    isPondering = false,
    ponderMove = nil,
    lastPosition = nil,
    lastPonderFen = nil,
    gameEnded = false,
    board = nil,
    bestMove = nil
}

return state
