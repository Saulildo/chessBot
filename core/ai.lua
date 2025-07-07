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

    -- Get best move from Stockfish server with analysis
    local function getStockfishMove(fen, whiteTime, blackTime, whiteToMove)
        local response = request({
            Url = STOCKFISH_URL .. "/analyze",
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
                gui.updateAnalysis(data.analysis)
            end
            
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

                    if isLocalPlayersTurn() and Fen and state.aiRunning then 
                        -- Get current times
                        local whiteTime = parseTimeControl(whiteTimeLabel.ContentText)
                        local blackTime = parseTimeControl(blackTimeLabel.ContentText)
                        
                        local success, result = pcall(function()
                            return getStockfishMove(Fen, whiteTime, blackTime, board.WhiteToPlay.Value)
                        end)
                        
                        if success and result then
                            move = result
                            PlayMove(move) -- Play immediately
                        elseif not success then
                            warn("Error getting move:", result)
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
