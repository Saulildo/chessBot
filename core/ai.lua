local M = {}

-- Sunfish chess engine integrated directly
-- Original: https://github.com/thomasahle/sunfish
-- Lua translation by Soumith Chintala

-- Constants
local TABLE_SIZE = 1e6
local NODES_SEARCHED = 1e4
local MATE_VALUE = 30000

-- Board representation
local A1, H1, A8, H8 = 91, 98, 21, 28
local initial = 
    '         \n' .. 
    '         \n' .. 
    ' rnbqkbnr\n' .. 
    ' pppppppp\n' .. 
    ' ........\n' .. 
    ' ........\n' .. 
    ' ........\n' .. 
    ' ........\n' .. 
    ' PPPPPPPP\n' .. 
    ' RNBQKBNR\n' .. 
    '         \n' .. 
    '          '

local __1 = 1 -- 1-index correction

-- Move directions
local N, E, S, W = -10, 1, 10, -1
local directions = {
    P = {N, 2*N, N+W, N+E},
    N = {2*N+E, N+2*E, S+2*E, 2*S+E, 2*S+W, S+2*W, N+2*W, 2*N+W},
    B = {N+E, S+E, S+W, N+W},
    R = {N, E, S, W},
    Q = {N, E, S, W, N+E, S+E, S+W, N+W},
    K = {N, E, S, W, N+E, S+E, S+W, N+W}
}

-- Piece-square tables
local pst = {
    P = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 198, 198, 198, 198, 198, 198, 198, 198, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 178, 198, 208, 218, 218, 208, 198, 178, 0,
        0, 178, 198, 218, 238, 238, 218, 198, 178, 0,
        0, 178, 198, 208, 218, 218, 208, 198, 178, 0,
        0, 178, 198, 198, 198, 198, 198, 198, 178, 0,
        0, 198, 198, 198, 198, 198, 198, 198, 198, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    B = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 797, 824, 817, 808, 808, 817, 824, 797, 0,
        0, 814, 841, 834, 825, 825, 834, 841, 814, 0,
        0, 818, 845, 838, 829, 829, 838, 845, 818, 0,
        0, 824, 851, 844, 835, 835, 844, 851, 824, 0,
        0, 827, 854, 847, 838, 838, 847, 854, 827, 0,
        0, 826, 853, 846, 837, 837, 846, 853, 826, 0,
        0, 817, 844, 837, 828, 828, 837, 844, 817, 0,
        0, 792, 819, 812, 803, 803, 812, 819, 792, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    N = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 627, 762, 786, 798, 798, 786, 762, 627, 0,
        0, 763, 798, 822, 834, 834, 822, 798, 763, 0,
        0, 817, 852, 876, 888, 888, 876, 852, 817, 0,
        0, 797, 832, 856, 868, 868, 856, 832, 797, 0,
        0, 799, 834, 858, 870, 870, 858, 834, 799, 0,
        0, 758, 793, 817, 829, 829, 817, 793, 758, 0,
        0, 739, 774, 798, 810, 810, 798, 774, 739, 0,
        0, 683, 718, 742, 754, 754, 742, 718, 683, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    R = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 1258, 1263, 1268, 1272, 1272, 1268, 1263, 1258, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    Q = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 2529, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    K = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 60098, 60132, 60073, 60025, 60025, 60073, 60132, 60098, 0,
        0, 60119, 60153, 60094, 60046, 60046, 60094, 60153, 60119, 0,
        0, 60146, 60180, 60121, 60073, 60073, 60121, 60180, 60146, 0,
        0, 60173, 60207, 60148, 60100, 60100, 60148, 60207, 60173, 0,
        0, 60196, 60230, 60171, 60123, 60123, 60171, 60230, 60196, 0,
        0, 60224, 60258, 60199, 60151, 60151, 60199, 60258, 60224, 0,
        0, 60287, 60321, 60262, 60214, 60214, 60262, 60321, 60287, 0,
        0, 60298, 60332, 60273, 60225, 60225, 60273, 60332, 60298, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
}

-- Chess logic functions
local function isspace(s)
   return s == ' ' or s == '\n'
end

local special = '. \n'

local function isupper(s)
   if special:find(s) then return false end
   return s:upper() == s
end

local function islower(s)
   if special:find(s) then return false end
   return s:lower() == s
end

local function swapcase(s)
   local s2 = ''
   for i=1,#s do
      local c = s:sub(i, i)
      if islower(c) then
         s2 = s2 .. c:upper()
      else
         s2 = s2 .. c:lower()
      end
   end
   return s2
end

-- Position class
local Position = {}

function Position.new(board, score, wc, bc, ep, kp)
   local self = {}
   self.board = board
   self.score = score
   self.wc = wc 
   self.bc = bc
   self.ep = ep
   self.kp = kp
   for k,v in pairs(Position) do self[k] = v end
   return self
end

function Position:genMoves()
   local moves = {}
   for i = 1 - __1, #self.board - __1 do
      local p = self.board:sub(i + __1, i + __1)
      if isupper(p) and directions[p] then
         for _, d in ipairs(directions[p]) do
            local limit = (i+d) + (10000) * d
            for j=i+d, limit, d do
               local q = self.board:sub(j + __1, j + __1)
               if isspace(self.board:sub(j + __1, j + __1)) then break; end
               if i == A1 and q == 'K' and self.wc[0 + __1] then
                  table.insert(moves,  {j, j-2})
               end
               if i == H1 and q == 'K' and self.wc[1 + __1] then 
                  table.insert(moves,  {j, j+2})
               end
               if isupper(q) then break; end
               if p == 'P' and (d == N+W or d == N+E) and q == '.' and j ~= self.ep and j ~= self.kp then 
                  break; 
               end
               if p == 'P' and (d == N or d == 2*N) and q ~= '.' then 
                  break; 
               end
               if p == 'P' and d == 2*N and (i < A1+N or self.board:sub(i+N + __1, i+N + __1) ~= '.') then 
                  break; 
               end
               table.insert(moves, {i, j})
               if p == 'P' or p == 'N' or p == 'K' then break; end
               if islower(q) then break; end
            end
         end
      end
   end
   return moves
end

function Position:rotate()
   return Position.new(
      swapcase(self.board:reverse()), -self.score,
      self.bc, self.wc, 119-self.ep, 119-self.kp)
end

function Position:move(move)
   assert(move)
   local i, j = move[0 + __1], move[1 + __1]
   local p, q = self.board:sub(i + __1, i + __1), self.board:sub(j + __1, j + __1)
   local function put(board, i, p) 
      return board:sub(1, i-1) .. p .. board:sub(i+1)
   end
   local board = self.board
   local wc, bc, ep, kp = self.wc, self.bc, 0, 0
   local score = self.score + self:value(move)
   board = put(board, j + __1, board:sub(i + __1, i + __1))
   board = put(board, i + __1, '.')
   if i == A1 then wc = {false, wc[2]}; end
   if i == H1 then wc = {wc[1], false}; end
   if j == A8 then bc = {bc[1], false}; end
   if j == H8 then bc = {false, bc[2]}; end
   if p == 'K' then
      wc = {false, false}
      if math.abs(j-i) == 2 then
         kp = math.floor((i+j)/2)
         board = put(board, j < i and A1 + __1 or H1 + __1 , '.')
         board = put(board, kp + __1, 'R')
      end
   end
   if p == 'P' then
      if A8 <= j and j <= H8 then
         board = put(board, j + __1, 'Q')
      end
      if j - i == 2*N then
         ep = i + N
      end
      if ((j - i) == N+W or (j - i) == N+E) and q == '.' then
         board = put(board, j+S + __1, '.')
      end
   end
   return Position.new(board, score, wc, bc, ep, kp):rotate()
end

function Position:value(move)
   local i, j = move[0 + __1], move[1 + __1]
   local p, q = self.board:sub(i + __1, i + __1), self.board:sub(j + __1, j + __1)
   local score = pst[p][j + __1] - pst[p][i + __1]
   if islower(q) then
      score = score + pst[q:upper()][j + __1]
   end
   if math.abs(j-self.kp) < 2 then
      score = score + pst['K'][j + __1]
   end
   if p == 'K' and math.abs(i-j) == 2 then
      score = score + pst['R'][math.floor((i+j)/2) + __1]
      score = score - pst['R'][j < i and A1 + __1 or H1 + __1]
   end
   if p == 'P' then
      if A8 <= j and j <= H8 then
         score = score + pst['Q'][j + __1] - pst['P'][j + __1]
      end
      if j == self.ep then
         score = score + pst['P'][j+S + __1]
      end
   end
   return score
end

-- Transposition table
local tp = {}
local tp_index = {}
local tp_count = 0

local function tp_set(pos, val)
   local b1 = pos.bc[1] and 'true' or 'false'
   local b2 = pos.bc[2] and 'true' or 'false'
   local w1 = pos.wc[1] and 'true' or 'false'
   local w2 = pos.wc[2] and 'true' or 'false'
   local hash = pos.board .. ';' .. pos.score .. ';' .. w1 .. ';' .. w2 .. ';' 
      .. b1 .. ';' .. b2 .. ';' .. pos.ep .. ';' .. pos.kp
   tp[hash] = val
   tp_index[#tp_index + 1] = hash
   tp_count = tp_count + 1
end

local function tp_get(pos)
   local b1 = pos.bc[1] and 'true' or 'false'
   local b2 = pos.bc[2] and 'true' or 'false'
   local w1 = pos.wc[1] and 'true' or 'false'
   local w2 = pos.wc[2] and 'true' or 'false'
   local hash = pos.board .. ';' .. pos.score .. ';' .. w1 .. ';' .. w2 .. ';' 
      .. b1 .. ';' .. b2 .. ';' .. pos.ep .. ';' .. pos.kp
   return tp[hash]
end

local function tp_popitem()
   tp[tp_index[#tp_index]] = nil
   tp_index[#tp_index] = nil
   tp_count = tp_count - 1
end

-- Search algorithm
local nodes = 0

local function bound(pos, gamma, depth)
    nodes = nodes + 1
    local entry = tp_get(pos)
    assert(depth)
    if entry ~= nil and entry.depth >= depth and (
            entry.score < entry.gamma and entry.score < gamma or
            entry.score >= entry.gamma and entry.score >= gamma) then
        return entry.score
    end
    if math.abs(pos.score) >= MATE_VALUE then
        return pos.score
    end
    local nullscore = depth > 0 and -bound(pos:rotate(), 1-gamma, depth-3) or pos.score
    if nullscore >= gamma then
        return nullscore
    end
    local best, bmove = -3*MATE_VALUE, nil
    local moves = pos:genMoves()
    local function sorter(a, b) 
       local va = pos:value(a)
       local vb = pos:value(b)
       if va ~= vb then
          return va > vb
       else
          if a[1] == b[1] then
             return a[2] > b[2]
          else
             return a[1] < b[1]
          end
       end
    end
    table.sort(moves, sorter)
    for _,move in ipairs(moves) do
       if depth <= 0 and pos:value(move) < 150 then
          break
       end
       local score = -bound(pos:move(move), 1-gamma, depth-1)
        if score > best then
           best = score
           bmove = move
        end
        if score >= gamma then
           break
        end
    end
    if depth <= 0 and best < nullscore then
       return nullscore
    end
    if depth > 0 and (best <= -MATE_VALUE) and nullscore > -MATE_VALUE then
       best = 0
    end
    if entry == nil or depth >= entry.depth and best >= gamma then
       tp_set(pos, {depth = depth, score = best, gamma = gamma, move = bmove})
       if tp_count > TABLE_SIZE then
          tp_popitem()
       end
    end
    return best
end

local function search(pos, maxn)
   maxn = maxn or NODES_SEARCHED
   nodes = 0
   local score
   for depth=1,98 do
      local lower, upper = -3*MATE_VALUE, 3*MATE_VALUE
      while lower < upper - 3 do
         local gamma = math.floor((lower+upper+1)/2)
         score = bound(pos, gamma, depth)
         assert(score)
         if score >= gamma then
            lower = score
         end
         if score < gamma then
            upper = score
         end
      end
      assert(score)
      if nodes >= maxn or math.abs(score) >= MATE_VALUE then
         break
      end
   end
   local entry = tp_get(pos)
   if entry ~= nil then
      return entry.move, score
   end
   return nil, score
end

-- FEN parsing and conversion functions
local function fenToBoardString(fen)
    -- Parse FEN to Sunfish board format
    local parts = {}
    for part in fen:gmatch("[^%s]+") do
        table.insert(parts, part)
    end
    local board_part = parts[1]
    local activeColor = parts[2]
    local castling = parts[3] or "-"
    local enPassant = parts[4] or "-"
    
    -- Initialize board
    local board = '         \n         \n'
    
    -- Convert FEN board to Sunfish format
    local rank = 8
    local file = 1
    for i = 1, #board_part do
        local char = board_part:sub(i, i)
        if char == '/' then
            board = board .. '\n '
            rank = rank - 1
            file = 1
        elseif tonumber(char) then
            for j = 1, tonumber(char) do
                board = board .. '.'
                file = file + 1
            end
        else
            -- Convert piece notation (FEN uses uppercase for white)
            if activeColor == 'w' then
                board = board .. char
            else
                -- Need to swap case for black's turn
                if char:upper() == char then
                    board = board .. char:lower()
                else
                    board = board .. char:upper()
                end
            end
            file = file + 1
        end
    end
    board = board .. '\n         \n          '
    
    -- If it's black to move, rotate the board
    if activeColor == 'b' then
        board = swapcase(board:reverse())
    end
    
    -- Parse castling rights
    local wc = {false, false}
    local bc = {false, false}
    if castling:find('K') then wc[2] = true end
    if castling:find('Q') then wc[1] = true end
    if castling:find('k') then bc[2] = true end
    if castling:find('q') then bc[1] = true end
    
    -- Parse en passant
    local ep = 0
    if enPassant ~= '-' then
        local file = string.byte(enPassant:sub(1,1)) - string.byte('a')
        local rank = tonumber(enPassant:sub(2,2))
        if activeColor == 'w' then
            ep = A1 + file - 10*(rank-1)
        else
            ep = 119 - (A1 + file - 10*(rank-1))
        end
    end
    
    return board, wc, bc, ep, activeColor
end

local function render(i)
   local rank, fil = math.floor((i - A1) / 10), (i - A1) % 10
   return string.char(fil + string.byte('a')) .. tostring(-rank + 1)
end

-- GetBestMove function that interfaces with the engine
local function GetBestMove(_, fen, searchTime)
    -- Convert FEN to Sunfish board format
    local board, wc, bc, ep, activeColor = fenToBoardString(fen)
    
    -- Create position
    local pos = Position.new(board, 0, wc, bc, ep, 0)
    
    -- Search for best move
    local maxNodes = searchTime and (searchTime * 2) or NODES_SEARCHED
    local move, score = search(pos, maxNodes)
    
    if not move then
        return nil
    end
    
    -- Convert move to standard notation
    local from, to = move[1], move[2]
    
    -- If black was to move, convert coordinates back
    if activeColor == 'b' then
        from = 119 - from
        to = 119 - to
    end
    
    -- Convert to algebraic notation
    local fromStr = render(from)
    local toStr = render(to)
    
    return fromStr .. toStr
end

function M.start(modules)
    local config = modules.config
    local state = modules.state

    -- Start new instance
    state.aiLoaded = true
    state.aiRunning = true
    state.gameConnected = false

    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local function getGameType(clockText)
        return config.CLOCK_NAME_MAPPING[clockText] or "unknown"
    end

    local function getSmartWait(clockText, moveCount)
        local configRange = config.CLOCK_WAIT_MAPPING[clockText]
        if not configRange then 
            configRange = config.CLOCK_WAIT_MAPPING["∞"]
        end
    
        local baseWait = math.random(math.random(0, configRange.min), math.random(configRange.min, configRange.max))
        local gameType = getGameType(clockText)
    
        if moveCount < math.random(7, 12) then
            return baseWait * 0.5
        elseif moveCount < math.random(12, 40) then
            return (gameType ~= "bullet") and baseWait * 4.0 or baseWait * 2.0
        else
            return baseWait * 1.2
        end
    end

    -- Get PlayMove function from ChessLocalUI
    local function getPlayMoveFunction()
        local retryCount = 0
        local PlayMove = nil
    
        while retryCount < 10 and not PlayMove do
            for _, f in ipairs(getgc(true)) do
                if typeof(f) == "function" and debug.getinfo(f).name == "PlayMove" then
                    PlayMove = f
                    break
                end
            end
            if not PlayMove then
                retryCount = retryCount + 1
                task.wait(0.1)
            end
        end
    
        if not PlayMove then
            warn("Failed to find PlayMove after 10 retries.")
        end
        return PlayMove
    end

    -- Main game handler
    local function startGameHandler(board)
        local PlayMove = getPlayMoveFunction()
        if not PlayMove then
            warn("Could not find PlayMove function")
            return
        end
        
        local boardLoaded = false
        local Fen = nil
        local move = nil
        local gameEnded = false
        local nbMoves = 0
        local randWaitFromGameType = 0
        local clockText = nil

        local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
        local clockLabel = board:WaitForChild("Clock")
            :WaitForChild("MainBody")
            :WaitForChild("SurfaceGui")
            :WaitForChild(isLocalWhite and "WhiteTime" or "BlackTime")

        task.wait(0.1)
        clockText = clockLabel.ContentText
        randWaitFromGameType = getSmartWait(clockText, nbMoves)
        boardLoaded = true

        local function isLocalPlayersTurn()
            local isLocalWhite = localPlayer.Name == board.WhitePlayer.Value
            return isLocalWhite == board.WhiteToPlay.Value
        end

        local function gameLoop()
            task.wait(3)

            while not gameEnded do
                if boardLoaded and board then
                    Fen = board.FEN.Value

                    if isLocalPlayersTurn() and Fen and state.aiRunning then 
                        move = GetBestMove(nil, Fen, 5000)
                        if move then
                            task.wait(randWaitFromGameType)
                            PlayMove(move)

                            nbMoves = nbMoves + 1
                            randWaitFromGameType = getSmartWait(clockText, nbMoves)
                        end
                    end
                end
                task.wait(0.2)
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
