local M = {}

local cloneref = cloneref or function(obj) return obj end
local HttpService = cloneref(game:GetService("HttpService"))

function M.start(modules)
    local config = modules.config
    local state = modules.state

    local ENGINE_CONFIG = config.ENGINE or {
        THREADS = 5,
        CONTEMPT = 100,
        HASH = 128,
        PONDER_DEPTH = 12,
        MOVES_TO_GO = 40
    }

    state.aiLoaded = true
    state.gameConnected = false

    local Players = cloneref(game:GetService("Players"))
    local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    local localPlayer = Players.LocalPlayer
    local ChessLocalUI = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("ChessLocalUI")

    local function parseTimeControl(clockText)
        if clockText == "∞" then
            return nil
        end
        local minutes, seconds = clockText:match("(%d+):(%d+)")
        if minutes and seconds then
            return (tonumber(minutes) * 60 + tonumber(seconds)) * 1000
        end
        return 180000
    end

    local function makeRequest(endpoint, data)
        local success, response = pcall(function()
            return request({
                Url = config.STOCKFISH_URL .. endpoint,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = data and HttpService:JSONEncode(data) or nil
            })
        end)
        if success and response.Success then
            return HttpService:JSONDecode(response.Body)
        end
        return nil
    end

    local function startPonder(fen, expectedMove)
        if not expectedMove then return end
        
        state.isPondering = true
        state.ponderMove = expectedMove
        state.lastPonderFen = fen
        state.currentAnalysisId = tostring(tick())
        
        spawn(function()
            local data = makeRequest("/ponder", {
                fen = fen,
                move = expectedMove,
                id = state.currentAnalysisId
            })
            if data and data.analysis and modules.gui.updateAnalysis then
                modules.gui.updateAnalysis(data.analysis)
            end
        end)
    end

    local function stopPonder()
        if state.isPondering then
            state.isPondering = false
            state.ponderMove = nil
            state.lastPonderFen = nil
            state.currentAnalysisId = nil
            pcall(function()
                request({
                    Url = config.STOCKFISH_URL .. "/stop",
                    Method = "POST"
                })
            end)
        end
    end

    local function getStockfishMove(fen, whiteTime, blackTime)
        local usePonderHit = state.isPondering and state.ponderMove and state.lastPonderFen
        
        if not usePonderHit then
            stopPonder()
        end
        
        state.currentAnalysisId = tostring(tick())
        local endpoint = usePonderHit and "/ponderhit" or "/analyze"
        
        local data = makeRequest(endpoint, {
            fen = fen,
            wtime = whiteTime,
            btime = blackTime,
            movestogo = config.ENGINE.MOVES_TO_GO,
            id = state.currentAnalysisId
        })

        if data then
            if data.analysis and modules.gui.updateAnalysis then
                modules.gui.updateAnalysis(data.analysis)
            end
            state.ponderMove = data.ponder
            state.bestMove = data.bestmove
            return data.bestmove
        else
            stopPonder()
            return nil
        end
    end

    local function getFunction(funcName, moduleName)
        local retryCount = 0
        local func = nil
        while retryCount < 10 and not func do
            for _, f in ipairs(getgc(true)) do
                if typeof(f) == "function" and debug.getinfo(f).name == funcName then
                    if string.sub(debug.getinfo(f).source, -#moduleName) == moduleName then
                        func = f
                        break
                    end
                end
            end
            if not func then
                retryCount = retryCount + 1
                task.wait(0.1)
            end
        end
        return func
    end

    function M.playMove()
        if state.bestMove then
            local PlayMove = getFunction("PlayMove", "ChessLocalUI")
            if PlayMove then
                PlayMove(state.bestMove)
                task.wait(0.2)
                if state.board then
                    local newFen = state.board.FEN.Value
                    state.lastPosition = newFen
                    if state.ponderMove then
                        startPonder(newFen, state.ponderMove)
                    end
                end
            end
        end
    end

    local function startGameHandler(board)
        state.gameEnded = false
        state.lastPosition = nil
        state.isPondering = false
        state.ponderMove = nil
        state.board = board
        state.bestMove = nil

        local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
        local clockGUI = board:WaitForChild("Clock"):WaitForChild("MainBody"):WaitForChild("SurfaceGui")
        local whiteTimeLabel = clockGUI:WaitForChild("WhiteTime")
        local blackTimeLabel = clockGUI:WaitForChild("BlackTime")

        task.wait(0.1)

        local function isLocalPlayersTurn()
            return (localPlayer.Name == board.WhitePlayer.Value) == board.WhiteToPlay.Value
        end

        local function gameLoop()
            task.wait(1)
            local wasRunning = state.aiRunning

            while not state.gameEnded do
                if board then
                    local currentFen = board.FEN.Value
                    local justEnabled = state.aiRunning and not wasRunning
                    wasRunning = state.aiRunning
                
                    if currentFen ~= state.lastPosition or justEnabled then
                        state.lastPosition = currentFen
                        
                        if isLocalPlayersTurn() and state.aiRunning then 
                            local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                            local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                            
                            local success, result = pcall(function()
                                return getStockfishMove(currentFen, whiteTime, blackTime)
                            end)
                            
                            if success and result then
                                if state.autoMove then
                                    M.playMove()
                                end
                            end
                        elseif not isLocalPlayersTurn() and state.aiRunning then
                            if not state.isPondering then
                                spawn(function()
                                    task.wait(0.3)
                                    if not isLocalPlayersTurn() and not state.isPondering then
                                        state.currentAnalysisId = tostring(tick())
                                        local data = makeRequest("/quickanalysis", {
                                            fen = currentFen,
                                            depth = config.ENGINE.PONDER_DEPTH,
                                            id = state.currentAnalysisId
                                        })
                                        
                                        if data then
                                            if data.analysis and modules.gui.updateAnalysis then
                                                modules.gui.updateAnalysis(data.analysis)
                                            end
                                            if data.bestmove then
                                                startPonder(currentFen, data.bestmove)
                                            end
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end

        spawn(gameLoop)

        ReplicatedStorage.Chess:WaitForChild("EndGameEvent").OnClientEvent:Once(function()
            state.gameEnded = true
            state.gameConnected = false
            state.board = nil
            state.bestMove = nil
            stopPonder()
        end)
    end

    if not state.gameConnected then
        ReplicatedStorage.Chess:WaitForChild("StartGameEvent").OnClientEvent:Connect(function(board)
            if board and (localPlayer.Name == board.WhitePlayer.Value or localPlayer.Name == board.BlackPlayer.Value) then
                startGameHandler(board)
            end
        end)
        state.gameConnected = true
    end
end

return M
