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
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")

    local STOCKFISH_URL = "http://localhost:8080"
    
    local isPondering = false
    local ponderMove = nil
    local lastPosition = nil
    local analysisId = nil
    local requestInProgress = false
    local lastRequestTime = 0
    local MIN_REQUEST_INTERVAL = 0.5 -- Minimum time between requests

    -- Request queue to prevent overlapping requests
    local requestQueue = {}
    local processingQueue = false

    local function processRequestQueue()
        if processingQueue or #requestQueue == 0 then return end
        processingQueue = true
        
        spawn(function()
            while #requestQueue > 0 do
                local req = table.remove(requestQueue, 1)
                if req and req.callback then
                    req.callback()
                end
                wait(0.1) -- Small delay between requests
            end
            processingQueue = false
        end)
    end

    local function queueRequest(callback)
        table.insert(requestQueue, {callback = callback})
        processRequestQueue()
    end

    local function asyncRequest(url, method, body)
        return spawn(function()
            local success, response = pcall(function()
                return request({
                    Url = url,
                    Method = method or "GET",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = body and HttpService:JSONEncode(body) or nil
                })
            end)
            
            if success then
                return response
            else
                warn("Request failed:", response)
                return nil
            end
        end)
    end

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
        if not expectedMove or requestInProgress then return end
        
        isPondering = true
        state.currentAnalysisId = tostring(tick())
        
        queueRequest(function()
            spawn(function()
                local response = request({
                    Url = STOCKFISH_URL .. "/ponder",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode({
                        fen = fen,
                        move = expectedMove,
                        id = state.currentAnalysisId
                    })
                })
                
                if response and response.Success then
                    local data = HttpService:JSONDecode(response.Body)
                    if data.analysis and gui.updateAnalysis then
                        gui.updateAnalysis(data.analysis)
                    end
                end
            end)
        end)
    end

    local function stopPonder()
        if isPondering then
            isPondering = false
            state.currentAnalysisId = nil
            spawn(function()
                request({
                    Url = STOCKFISH_URL .. "/stop",
                    Method = "POST"
                })
            end)
        end
    end

    local function getStockfishMove(fen, whiteTime, blackTime, whiteToMove, usePonder, callback)
        if requestInProgress then 
            return 
        end
        
        local currentTime = tick()
        if currentTime - lastRequestTime < MIN_REQUEST_INTERVAL then
            return
        end
        
        requestInProgress = true
        lastRequestTime = currentTime
        
        stopPonder()
        
        state.currentAnalysisId = tostring(tick())
        local endpoint = usePonder and "/ponderhit" or "/analyze"
        
        spawn(function()
            local success, response = pcall(function()
                return request({
                    Url = STOCKFISH_URL .. endpoint,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode({
                        fen = fen,
                        wtime = whiteTime,
                        btime = blackTime,
                        movestogo = 40,
                        id = state.currentAnalysisId
                    })
                })
            end)

            requestInProgress = false

            if success and response and response.Success then
                local data = HttpService:JSONDecode(response.Body)
                
                -- Update GUI with analysis data
                if data.analysis and gui.updateAnalysis then
                    RunService.Heartbeat:Wait() -- Yield to prevent frame drops
                    gui.updateAnalysis(data.analysis)
                end
                
                ponderMove = data.ponder
                
                if callback then
                    callback(data.bestmove)
                end
            else
                warn("Stockfish request failed")
                if callback then
                    callback(nil)
                end
            end
        end)
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
        local gameEnded = false
        local lastMoveTime = 0
        local MOVE_COOLDOWN = 1 -- Minimum time between moves

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
            local frameCount = 0

            while not gameEnded do
                frameCount = frameCount + 1
                
                -- Yield every few frames to prevent blocking
                if frameCount % 5 == 0 then
                    RunService.Heartbeat:Wait()
                end
                
                if boardLoaded and board then
                    Fen = board.FEN.Value
                    
                    local justEnabled = state.aiRunning and not wasRunning
                    wasRunning = state.aiRunning
                
                    if Fen ~= lastPosition or justEnabled then
                        lastPosition = Fen
                        
                        local currentTime = tick()
                        
                        if isLocalPlayersTurn() and state.aiRunning and not requestInProgress then 
                            if currentTime - lastMoveTime >= MOVE_COOLDOWN then
                                lastMoveTime = currentTime
                                
                                local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                                local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                                
                                local usePonder = isPondering and ponderMove
                                
                                getStockfishMove(Fen, whiteTime, blackTime, board.WhiteToPlay.Value, usePonder, function(move)
                                    if move then
                                        spawn(function()
                                            PlayMove(move)
                                            
                                            if ponderMove then
                                                wait(0.5) -- Small delay before pondering
                                                startPonder(Fen, ponderMove)
                                            end
                                        end)
                                    end
                                end)
                            end
                        elseif not isLocalPlayersTurn() and state.aiRunning and not requestInProgress then
                            spawn(function()
                                wait(1) -- Wait longer before analyzing opponent's position
                                if not isLocalPlayersTurn() and not requestInProgress then
                                    state.currentAnalysisId = tostring(tick())
                                    spawn(function()
                                        local response = request({
                                            Url = STOCKFISH_URL .. "/quickanalysis",
                                            Method = "POST",
                                            Headers = {
                                                ["Content-Type"] = "application/json"
                                            },
                                            Body = HttpService:JSONEncode({
                                                fen = Fen,
                                                depth = 10,
                                                id = state.currentAnalysisId
                                            })
                                        })
                                        
                                        if response and response.Success then
                                            local data = HttpService:JSONDecode(response.Body)
                                            if data.bestmove then
                                                startPonder(Fen, data.bestmove)
                                            end
                                        end
                                    end)
                                end
                            end)
                        end
                    end
                end
                task.wait(0.3) -- Increased wait time to reduce CPU usage
            end
        end

        state.aiThread = coroutine.create(gameLoop)
        coroutine.resume(state.aiThread)

        ReplicatedStorage.Chess:WaitForChild("EndGameEvent").OnClientEvent:Once(function(board)
            gameEnded = true
            state.gameConnected = false
            stopPonder()
            state.currentAnalysisId = nil
            requestInProgress = false
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
