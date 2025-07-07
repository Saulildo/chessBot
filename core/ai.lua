local M = {}

function M.start(modules)
    local config = modules.config
    local state = modules.state
    local gui = modules.gui

    state.aiLoaded = true
    state.aiRunning = true
    state.gameConnected = false

    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ChessLocalUI = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("ChessLocalUI")

    local STOCKFISH_URL = "http://localhost:8080"
    
    local isPondering = false
    local ponderMove = nil
    local lastPosition = nil
    local analysisId = nil

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

    local function startPonder(fen, expectedMove)
        if not expectedMove then return end
        
        isPondering = true
        state.currentAnalysisId = tostring(tick())
        
        spawn(function()
            local response = request({
                Url = STOCKFISH_URL .. "/ponder",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode({
                    fen = fen,
                    move = expectedMove,
                    id = state.currentAnalysisId
                })
            })
            
            if response.Success then
                local data = game:GetService("HttpService"):JSONDecode(response.Body)
                if data.analysis and gui.updateAnalysis then
                    gui.updateAnalysis(data.analysis)
                end
            end
        end)
    end

    local function stopPonder()
        if isPondering then
            isPondering = false
            state.currentAnalysisId = nil
            request({
                Url = STOCKFISH_URL .. "/stop",
                Method = "POST"
            })
        end
    end

    local function getStockfishMove(fen, whiteTime, blackTime, whiteToMove, usePonder)
        stopPonder()
        
        state.currentAnalysisId = tostring(tick())
        local endpoint = usePonder and "/ponderhit" or "/analyze"
        local response = request({
            Url = STOCKFISH_URL .. endpoint,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode({
                fen = fen,
                wtime = whiteTime,
                btime = blackTime,
                movestogo = 40,
                id = state.currentAnalysisId
            })
        })

        if response.Success then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            
            -- Update GUI with analysis data
            if data.analysis and gui.updateAnalysis then
                gui.updateAnalysis(data.analysis)
            end
            
            ponderMove = data.ponder
            return data.bestmove
        else
            warn("Stockfish request failed:", response.StatusCode, response.Body)
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
    
        if not func then
            warn("Failed to find " .. funcName .. " after 10 retries.")
        end
        return func
    end

    local function initializeFunctions()
        local PlayMove = getFunction("PlayMove", "ChessLocalUI")
        return PlayMove
    end

    local function startGameHandler(board)
        local PlayMove = initializeFunctions()
        local boardLoaded = false
        local Fen = nil
        local move = nil
        local gameEnded = false

        local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
        local clockGUI = board:WaitForChild("Clock"):WaitForChild("MainBody"):WaitForChild("SurfaceGui")
        local whiteTimeLabel = clockGUI:WaitForChild("WhiteTime")
        local blackTimeLabel = clockGUI:WaitForChild("BlackTime")

        task.wait(0.1)
        boardLoaded = true

        local function isLocalPlayersTurn()
            local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
            return isLocalWhite == board.WhiteToPlay.Value
        end

        local function gameLoop()
    task.wait(1)

    local wasRunning = state.aiRunning

    while not gameEnded do
        if boardLoaded and board then
            Fen = board.FEN.Value
            
            local justEnabled = state.aiRunning and not wasRunning
            wasRunning = state.aiRunning
        
            if Fen ~= lastPosition or justEnabled then
                lastPosition = Fen
                
                if isLocalPlayersTurn() and state.aiRunning then 
                    local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                    local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                    
                    local usePonder = isPondering and ponderMove
                    
                    local success, result = pcall(function()
                        return getStockfishMove(Fen, whiteTime, blackTime, board.WhiteToPlay.Value, usePonder)
                    end)
                    
                    if success and result then
                        move = result
                        PlayMove(move)
                        
                        if ponderMove then
                            startPonder(Fen, ponderMove)
                        end
                    elseif not success then
                        warn("Error getting move:", result)
                    end
                elseif not isLocalPlayersTurn() and state.aiRunning then
                    spawn(function()
                        wait(0.5)
                        if not isLocalPlayersTurn() then
                            state.currentAnalysisId = tostring(tick())
                            local response = request({
                                Url = STOCKFISH_URL .. "/quickanalysis",
                                Method = "POST",
                                Headers = {
                                    ["Content-Type"] = "application/json"
                                },
                                Body = game:GetService("HttpService"):JSONEncode({
                                    fen = Fen,
                                    depth = 10,
                                    id = state.currentAnalysisId
                                })
                            })
                            
                            if response.Success then
                                local data = game:GetService("HttpService"):JSONDecode(response.Body)
                                if data.bestmove then
                                    startPonder(Fen, data.bestmove)
                                end
                            end
                        end
                    end)
                end
            end
        end
        task.wait(0.1)
    end
end

        state.aiThread = coroutine.create(gameLoop)
        coroutine.resume(state.aiThread)

        ReplicatedStorage.Chess:WaitForChild("EndGameEvent").OnClientEvent:Once(function(board)
                gameEnded = true
                state.gameConnected = false
                stopPonder()
                state.currentAnalysisId = nil
                print("[LOG]: Game ended.")
        end)
    end

    if not state.gameConnected then
        ReplicatedStorage.Chess:WaitForChild("StartGameEvent").OnClientEvent:Connect(function(board)
            if board then
                if localPlayer.Name == board.WhitePlayer.Value or localPlayer.Name == board.BlackPlayer.Value then
                    print("[LOG]: New game started.")
                    startGameHandler(board)
                end
            else
                warn("Invalid board, try restarting a chess game.")
            end
        end)
        state.gameConnected = true
    else
        warn("Game instance already existing, restart chess club")
    end
end

return M
