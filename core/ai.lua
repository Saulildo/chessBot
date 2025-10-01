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
    local lastPonderFen = nil

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
        if not expectedMove then 
            print("[DEBUG] No ponder move provided")
            return 
        end
        
        print("[DEBUG] Starting ponder from FEN:", fen:sub(1, 20), "with move:", expectedMove)
        isPondering = true
        ponderMove = expectedMove
        lastPonderFen = fen
        state.currentAnalysisId = tostring(tick())
        
        spawn(function()
            local success, response = pcall(function()
                return request({
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
            end)
            
            if success and response.Success then
                local data = game:GetService("HttpService"):JSONDecode(response.Body)
                if data.analysis and gui.updateAnalysis then
                    gui.updateAnalysis(data.analysis)
                end
                print("[DEBUG] Ponder started successfully")
            else
                warn("[WARN] Ponder request failed:", success and response.StatusCode or "pcall failed")
                isPondering = false
            end
        end)
    end

    local function stopPonder()
        if isPondering then
            print("[DEBUG] Stopping ponder")
            isPondering = false
            ponderMove = nil
            lastPonderFen = nil
            state.currentAnalysisId = nil
            pcall(function()
                request({
                    Url = STOCKFISH_URL .. "/stop",
                    Method = "POST"
                })
            end)
        end
    end

    local function getStockfishMove(fen, whiteTime, blackTime, whiteToMove, expectedPonderMove)
        local usePonderHit = false
        
        -- Check if this position matches what we were pondering
        if isPondering and ponderMove and lastPonderFen then
            print("[DEBUG] Was pondering. LastPonderFen:", lastPonderFen:sub(1, 20))
            print("[DEBUG] Current FEN:", fen:sub(1, 20))
            print("[DEBUG] Expected ponder move:", ponderMove)
            -- The opponent should have played ponderMove to get to current fen
            -- We can attempt a ponderhit
            usePonderHit = true
        else
            stopPonder()
        end
        
        state.currentAnalysisId = tostring(tick())
        local endpoint = usePonderHit and "/ponderhit" or "/analyze"
        
        print("[DEBUG] Requesting move from:", endpoint)
        
        local success, response = pcall(function()
            return request({
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
        end)

        if success and response.Success then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            
            -- Update GUI with analysis data
            if data.analysis and gui.updateAnalysis then
                gui.updateAnalysis(data.analysis)
            end
            
            ponderMove = data.ponder
            print("[DEBUG] Got move:", data.bestmove, "ponder:", data.ponder)
            return data.bestmove
        else
            warn("Stockfish request failed:", success and response.StatusCode or "pcall failed")
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
        lastPosition = nil
        isPondering = false
        ponderMove = nil

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
                        print("[DEBUG] FEN changed. New FEN:", Fen:sub(1, 30))
                        print("[DEBUG] Is our turn:", isLocalPlayersTurn(), "AI running:", state.aiRunning)
                        
                        lastPosition = Fen
                        
                        if isLocalPlayersTurn() and state.aiRunning then 
                            local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                            local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                            
                            print("[DEBUG] Our turn - getting move")
                            
                            local success, result = pcall(function()
                                return getStockfishMove(Fen, whiteTime, blackTime, board.WhiteToPlay.Value, ponderMove)
                            end)
                            
                            if success and result then
                                move = result
                                print("[DEBUG] Playing move:", move)
                                PlayMove(move)
                                
                            
                                task.wait(0.2)
                                
     
                                local newFen = board.FEN.Value
                                print("[DEBUG] New FEN after our move:", newFen:sub(1, 30))
                                
     
                                lastPosition = newFen
                            
                                if ponderMove then
                                    print("[DEBUG] Starting ponder after our move")
                                    startPonder(newFen, ponderMove)
                                end
                            elseif not success then
                                warn("Error getting move:", result)
                                stopPonder()
                            end
                        elseif not isLocalPlayersTurn() and state.aiRunning then
 
                            if not isPondering then
                                print("[DEBUG] Opponent's turn and not pondering - starting quick analysis")
                                spawn(function()
                                    task.wait(0.3)
                                    if not isLocalPlayersTurn() and not isPondering then
                                        state.currentAnalysisId = tostring(tick())
                                        local success, response = pcall(function()
                                            return request({
                                                Url = STOCKFISH_URL .. "/quickanalysis",
                                                Method = "POST",
                                                Headers = {
                                                    ["Content-Type"] = "application/json"
                                                },
                                                Body = game:GetService("HttpService"):JSONEncode({
                                                    fen = Fen,
                                                    depth = 12,
                                                    id = state.currentAnalysisId
                                                })
                                            })
                                        end)
                                        
                                        if success and response.Success then
                                            local data = game:GetService("HttpService"):JSONDecode(response.Body)
                                            if data.bestmove then
                                                startPonder(Fen, data.bestmove)
                                            end
                                        end
                                    end
                                end)
                            else
                                print("[DEBUG] Already pondering, skipping quick analysis")
                            end
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
