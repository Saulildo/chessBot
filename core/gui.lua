local M = {}

function M.init(modules)
    local config = modules.config
    local state = modules.state
    local ai = modules.ai
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create main GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChessAIGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui
    
    -- Main toggle button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 50, 0, 50)
    toggleButton.Position = UDim2.new(0.02, 0, 0.5, -25)
    toggleButton.BackgroundColor3 = config.COLORS.off.background
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = ""
    toggleButton.Parent = screenGui
    
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0.7, 0, 0.7, 0)
    icon.Position = UDim2.new(0.15, 0, 0.15, 0)
    icon.BackgroundTransparency = 1
    icon.Image = config.ICON_IMAGE
    icon.ImageColor3 = config.COLORS.off.icon
    icon.Parent = toggleButton
    
    -- Analysis panel
    local analysisPanel = Instance.new("Frame")
    analysisPanel.Size = UDim2.new(0, 250, 0, 150)
    analysisPanel.Position = UDim2.new(0.02, 60, 0.5, -75)
    analysisPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    analysisPanel.BorderSizePixel = 0
    analysisPanel.Visible = false
    analysisPanel.Parent = screenGui
    
    -- Panel header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.BorderSizePixel = 0
    header.Text = "Engine Analysis"
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.TextScaled = true
    header.Font = Enum.Font.SourceSansBold
    header.Parent = analysisPanel
    
    -- Analysis data container
    local dataContainer = Instance.new("Frame")
    dataContainer.Size = UDim2.new(1, -10, 1, -35)
    dataContainer.Position = UDim2.new(0, 5, 0, 35)
    dataContainer.BackgroundTransparency = 1
    dataContainer.Parent = analysisPanel
    
    -- Create analysis labels
    local function createAnalysisRow(yPosition, labelText)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.4, 0, 0, 25)
        label.Position = UDim2.new(0, 0, 0, yPosition)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(180, 180, 180)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextScaled = true
        label.Font = Enum.Font.SourceSans
        label.Parent = dataContainer
        
        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(0.6, 0, 0, 25)
        value.Position = UDim2.new(0.4, 0, 0, yPosition)
        value.BackgroundTransparency = 1
        value.Text = "---"
        value.TextColor3 = Color3.fromRGB(255, 255, 255)
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.TextScaled = true
        value.Font = Enum.Font.SourceSansBold
        value.Parent = dataContainer
        
        return value
    end
    
    local depthLabel = createAnalysisRow(0, "Depth:")
    local scoreLabel = createAnalysisRow(25, "Score:")
    local nodesLabel = createAnalysisRow(50, "Nodes:")
    local npsLabel = createAnalysisRow(75, "Speed:")
    
    -- Update analysis display
    function M.updateAnalysis(data)
        if data.depth then
            depthLabel.Text = tostring(data.depth)
        end
        
        if data.score then
            local scoreText
            if data.score.mate then
                scoreText = "Mate in " .. tostring(data.score.mate)
                scoreLabel.TextColor3 = data.score.mate > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            else
                local cp = data.score.cp / 100
                scoreText = string.format("%+.2f", cp)
                if math.abs(cp) > 3 then
                    scoreLabel.TextColor3 = cp > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
                else
                    scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
            scoreLabel.Text = scoreText
        end
        
        if data.nodes then
            local nodeText
            if data.nodes > 1000000 then
                nodeText = string.format("%.1fM", data.nodes / 1000000)
            elseif data.nodes > 1000 then
                nodeText = string.format("%.1fK", data.nodes / 1000)
            else
                nodeText = tostring(data.nodes)
            end
            nodesLabel.Text = nodeText
        end
        
        if data.nps then
            local npsText
            if data.nps > 1000000 then
                npsText = string.format("%.1fM nps", data.nps / 1000000)
            elseif data.nps > 1000 then
                npsText = string.format("%.0fK nps", data.nps / 1000)
            else
                npsText = tostring(data.nps) .. " nps"
            end
            npsLabel.Text = npsText
        end
    end
    
    -- Toggle functionality
    toggleButton.MouseButton1Click:Connect(function()
        state.aiRunning = not state.aiRunning
        
        if state.aiRunning then
            toggleButton.BackgroundColor3 = config.COLORS.on.background
            icon.ImageColor3 = config.COLORS.on.icon
            analysisPanel.Visible = true
            
            if not state.aiLoaded then
                ai.start(modules)
            end
        else
            toggleButton.BackgroundColor3 = config.COLORS.off.background
            icon.ImageColor3 = config.COLORS.off.icon
            analysisPanel.Visible = false
        end
    end)
    
    -- Make panel draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = analysisPanel.Position
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            analysisPanel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

return M
