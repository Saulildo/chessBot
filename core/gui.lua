local M = {}

function M.init(modules)
    local config = modules.config
    local state = modules.state
    local ai = modules.ai
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChessAIGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 200)
    mainFrame.Position = UDim2.new(0.02, 0, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(40, 40, 40)
    mainStroke.Thickness = 1
    mainStroke.Parent = mainFrame
    
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 40)
    headerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = headerFrame
    
    local headerCover = Instance.new("Frame")
    headerCover.Size = UDim2.new(1, 0, 0, 20)
    headerCover.Position = UDim2.new(0, 0, 1, -20)
    headerCover.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    headerCover.BorderSizePixel = 0
    headerCover.Parent = headerFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Stockfish Engine"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.SourceSansSemibold
    titleLabel.TextSize = 16
    titleLabel.Parent = headerFrame
    
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(0, 260, 0.5, -5)
    statusDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = headerFrame
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(0.5, 0)
    dotCorner.Parent = statusDot
    
    local ponderIndicator = Instance.new("Frame")
    ponderIndicator.Size = UDim2.new(0, 60, 0, 20)
    ponderIndicator.Position = UDim2.new(0.65, 0, 0.5, -10)
    ponderIndicator.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    ponderIndicator.BorderSizePixel = 0
    ponderIndicator.Visible = false
    ponderIndicator.Parent = headerFrame
    
    local ponderCorner = Instance.new("UICorner")
    ponderCorner.CornerRadius = UDim.new(0, 4)
    ponderCorner.Parent = ponderIndicator
    
    local ponderText = Instance.new("TextLabel")
    ponderText.Size = UDim2.new(1, 0, 1, 0)
    ponderText.BackgroundTransparency = 1
    ponderText.Text = "PONDER"
    ponderText.TextColor3 = Color3.fromRGB(255, 255, 255)
    ponderText.Font = Enum.Font.SourceSansBold
    ponderText.TextSize = 12
    ponderText.Parent = ponderIndicator
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 60, 0, 26)
    toggleButton.Position = UDim2.new(0, 225, 0.5, -13)
    toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 14
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = headerFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local function createDataRow(position, label)
        local rowFrame = Instance.new("Frame")
        rowFrame.Size = UDim2.new(1, 0, 0, 35)
        rowFrame.Position = UDim2.new(0, 0, 0, position * 37)
        rowFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        rowFrame.BorderSizePixel = 0
        rowFrame.Parent = contentFrame
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 8)
        rowCorner.Parent = rowFrame
        
        local labelText = Instance.new("TextLabel")
        labelText.Size = UDim2.new(0, 80, 1, 0)
        labelText.Position = UDim2.new(0, 15, 0, 0)
        labelText.BackgroundTransparency = 1
        labelText.Text = label
        labelText.TextColor3 = Color3.fromRGB(180, 180, 180)
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        labelText.Font = Enum.Font.SourceSans
        labelText.TextSize = 14
        labelText.Parent = rowFrame
        
        local valueText = Instance.new("TextLabel")
        valueText.Size = UDim2.new(0, 120, 1, 0)
        valueText.Position = UDim2.new(1, -135, 0, 0)
        valueText.BackgroundTransparency = 1
        valueText.Text = "---"
        valueText.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueText.TextXAlignment = Enum.TextXAlignment.Right
        valueText.Font = Enum.Font.SourceSansBold
        valueText.TextSize = 14
        valueText.Parent = rowFrame
        
        return valueText, rowFrame
    end
    
    local depthValue, depthRow = createDataRow(0, "Depth")
    local scoreValue, scoreRow = createDataRow(1, "Score")
    local nodesValue, nodesRow = createDataRow(2, "Nodes")
    local speedValue, speedRow = createDataRow(3, "Speed")
    
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 20, 0, 20)
    minimizeButton.Position = UDim2.new(1, -25, 0.5, -10)
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Text = "—"
    minimizeButton.TextColor3 = Color3.fromRGB(180, 180, 180)
    minimizeButton.Font = Enum.Font.SourceSansBold
    minimizeButton.TextSize = 16
    minimizeButton.AutoButtonColor = false
    minimizeButton.Parent = headerFrame
    
    local isMinimized = false
    local normalSize = mainFrame.Size
    local minimizedSize = UDim2.new(0, 300, 0, 40)
    
    minimizeButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isMinimized = not isMinimized
            local targetSize = isMinimized and minimizedSize or normalSize
            
            local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                Size = targetSize
            })
            tween:Play()
            
            minimizeButton.Text = isMinimized and "+" or "—"
        end
    end)
    
    function M.updateAnalysis(data)
        if data.depth then
            depthValue.Text = tostring(data.depth)
        end
        
        if data.score then
            local scoreText
            local scoreColor = Color3.fromRGB(255, 255, 255)
            
            if data.score.mate then
                scoreText = "M" .. tostring(math.abs(data.score.mate))
                scoreColor = data.score.mate > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            else
                local cp = data.score.cp / 100
                scoreText = string.format("%+.2f", cp)
                
                if cp > 3 then
                    scoreColor = Color3.fromRGB(100, 255, 100)
                elseif cp < -3 then
                    scoreColor = Color3.fromRGB(255, 100, 100)
                else
                    local factor = math.abs(cp) / 3
                    if cp > 0 then
                        scoreColor = Color3.fromRGB(255 - 155 * factor, 255, 255 - 155 * factor)
                    else
                        scoreColor = Color3.fromRGB(255, 255 - 155 * factor, 255 - 155 * factor)
                    end
                end
            end
            
            scoreValue.Text = scoreText
            scoreValue.TextColor3 = scoreColor
        end
        
        if data.nodes then
            local nodeText
            if data.nodes >= 1e9 then
                nodeText = string.format("%.2fB", data.nodes / 1e9)
            elseif data.nodes >= 1e6 then
                nodeText = string.format("%.1fM", data.nodes / 1e6)
            elseif data.nodes >= 1e3 then
                nodeText = string.format("%.0fK", data.nodes / 1e3)
            else
                nodeText = tostring(data.nodes)
            end
            nodesValue.Text = nodeText
        end
        
        if data.nps then
            local npsText
            if data.nps >= 1e6 then
                npsText = string.format("%.1fM nps", data.nps / 1e6)
            elseif data.nps >= 1e3 then
                npsText = string.format("%.0fK nps", data.nps / 1e3)
            else
                npsText = tostring(data.nps) .. " nps"
            end
            speedValue.Text = npsText
        end
        
        ponderIndicator.Visible = data.pondering or false
    end
    
    local function setEngineState(enabled)
        state.aiRunning = enabled
        
        if enabled then
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            toggleButton.Text = "ON"
            statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            
            if not state.aiLoaded then
                ai.start(modules)
            end
        else
            toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            toggleButton.Text = "OFF"
            statusDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
            ponderIndicator.Visible = false
        end
        
        local pulseTween = TweenService:Create(statusDot, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 258, 0.5, -7)
        })
        pulseTween:Play()
        pulseTween.Completed:Connect(function()
            local returnTween = TweenService:Create(statusDot, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(0, 260, 0.5, -5)
            })
            returnTween:Play()
        end)
    end
    
    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            setEngineState(not state.aiRunning)
        end
    end)
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragInput = nil
    
    local function updateDrag(input)
        if not dragging then return end
        
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    headerFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            dragInput = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if dragInput then
                        dragInput:Disconnect()
                        dragInput = nil
                    end
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    
    spawn(function()
        while true do
            if state.aiRunning and state.currentAnalysisId then
                local response = request({
                    Url = "http://localhost:8080/status",
                    Method = "GET"
                })
                
                if response.Success then
                    local data = game:GetService("HttpService"):JSONDecode(response.Body)
                    if data.analysis then
                        M.updateAnalysis(data.analysis)
                    end
                end
            end
            wait(0.1)
        end
    end)
    
    M.screenGui = screenGui
end

return M
