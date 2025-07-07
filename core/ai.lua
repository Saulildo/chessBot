local M = {}

function M.start(modules)
    local config = modules.config
    local state = modules.state
    local gui = modules.gui

    -- Start new instance
    state.aiLoaded = true
    state.aiRunning = true
    state.gameConnected = false

    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ChessLocalUI = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("ChessLocalUI")

    -- Stockfish server configuration
    local STOCKFISH_URL = "http://localhost:8080"
    
    -- Pondering state
    local isPondering = false
    local ponderMove = nil
    local lastPosition = nil

    -- Parse clock text to milliseconds
    local function parseTimeControl(clockText)
        if clockText == "∞" then
            return nil -- No time limit
        end
        
        local minutes, seconds = clockText:match("(%d+):(%d+)")
        if minutes and seconds then
            return (tonumber(minutes) * 60 + tonumber(seconds)) * 1000
        end
        return 180000 -- Default 3 minutes
    end

    -- Start pondering
    local function startPonder(fen, expectedMove)
        if not expectedMove then return end
        
        isPondering = true
        
        -- Make the expected move on the position
        local ponderFen = fen -- This would need move application logic
        
        spawn(function()
            local response = request({
                Url = STOCKFISH_URL .. "/ponder",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode({
                    fen = fen,
                    move = expectedMove
                })
            })
            
            if response.Success then
                local data = game:GetService("HttpService"):JSONDecode(response.Body)
                if gui.updateAnalysis then
                    data.analysis.pondering = true
                    gui.updateAnalysis(data.analysis)
                end
            end
        end)
    end

    -- Stop pondering
    local function stopPonder()
        if isPondering then
            isPondering = false
            request({
                Url = STOCKFISH_URL .. "/stop",
                Method = "POST"
            })
        end
    end

    -- Get best move from Stockfish server with analysis
    local function getStockfishMove(fen, whiteTime, blackTime, whiteToMove, usePonder)
        stopPonder() -- Stop any ongoing ponder
        
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
                movestogo = 40
            })
        })

        if response.Success then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            
            -- Update GUI with analysis data
            if data.analysis and gui.updateAnalysis then
                data.analysis.pondering = false
                gui.updateAnalysis(data.analysis)
            end
            
            -- Store ponder move if available
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

    -- Main part
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

        -- wait for clock to initialize
        task.wait(0.1)
        boardLoaded = true

        local function isLocalPlayersTurn()
            local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
            return isLocalWhite == board.WhiteToPlay.Value
        end

        -- Game loop
        local function gameLoop()
            task.wait(1) -- minimal game initialization time

            while not gameEnded do
                if boardLoaded and board then
                    Fen = board.FEN.Value
                    
                    -- Check if position changed (opponent moved)
                    if Fen ~= lastPosition then
                        lastPosition = Fen
                        
                        if isLocalPlayersTurn() and state.aiRunning then 
                            -- Our turn - make a move
                            local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                            local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                            
                            -- Check if we predicted this position
                            local usePonder = isPondering and ponderMove
                            
                            local success, result = pcall(function()
                                return getStockfishMove(Fen, whiteTime, blackTime, board.WhiteToPlay.Value, usePonder)
                            end)
                            
                            if success and result then
                                move = result
                                PlayMove(move)
                                
                                -- Start pondering for opponent's move
                                if ponderMove then
                                    startPonder(Fen, ponderMove)
                                end
                            elseif not success then
                                warn("Error getting move:", result)
                            end
                        elseif not isLocalPlayersTurn() and state.aiRunning then
                            -- Opponent's turn - start pondering
                            spawn(function()
                                wait(0.5) -- Small delay to ensure position is stable
                                if not isLocalPlayersTurn() then
                                    -- Get a preliminary analysis
                                    local response = request({
                                        Url = STOCKFISH_URL .. "/quickanalysis",
                                        Method = "POST",
                                        Headers = {
                                            ["Content-Type"] = "application/json"
                                        },
                                        Body = game:GetService("HttpService"):JSONEncode({
                                            fen = Fen,
                                            depth = 10
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
                task.wait(0.1) -- Minimal loop delay
            end
        end

        state.aiThread = coroutine.create(gameLoop)
        coroutine.resume(state.aiThread)

        ReplicatedStorage.Chess:WaitForChild("EndGameEvent").OnClientEvent:Once(function(board)
                gameEnded = true
                state.gameConnected = false
                stopPonder()
                print("[LOG]: Game ended.")
        end)
    end

    -- Listener to get the board object
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
