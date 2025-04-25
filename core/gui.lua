local M = {}

function M.init(modules)
    local config = modules.config
    local state = modules.state
    local ai = modules.ai

    local aiRunning = false

    -- Wait for GUI to be present
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Wait for the existing structure
    local mainMenu = playerGui:WaitForChild("MainMenu", 5)
    local sideFrame = mainMenu and mainMenu:WaitForChild("SideFrame", 5)

    if not sideFrame then
        warn("SideFrame not found. Aborting UI injection.")
        return
    end
    sideFrame.AnchorPoint = Vector2.new(0, 0.45)

    if sideFrame:FindFirstChild("aiFrame") then
        warn("Chess AI toggle UI already injected.")
        return
    end

    -- Main frame
    local aiFrame = Instance.new("Frame")
    aiFrame.Name = "aiFrame"
    aiFrame.Size = UDim2.new(1, 0, 0.045, 0) -- Scaled size
    aiFrame.BackgroundColor3 = config.COLORS.off.background
    aiFrame.LayoutOrder = 99
    aiFrame.Parent = sideFrame

    -- Corners + stroke for the frame
    local corner = Instance.new("UICorner", aiFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", aiFrame)
    stroke.Thickness = 1.6
    stroke.Color = Color3.fromRGB(255, 170, 0)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Image = config.ICON_IMAGE --rbxassetid://84768391180077
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.22, 0, 0.5, 0)
    icon.Size = UDim2.new(0.18, 0, 0.18, 0)
    icon.SizeConstraint = 1
    icon.BackgroundTransparency = 1
    icon.ImageColor3 = config.COLORS.off.icon
    icon.ImageTransparency = 0.18
    icon.Parent = aiFrame
    -- Maintain aspect ratio
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1 -- 1:1 square
    aspect.Parent = icon

    -- Label
    local label = Instance.new("TextLabel")
    label.Text = "AI: OFF"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.new(0.65, 0, 0.5, 0)
    label.Size = UDim2.new(0.55, 0, 0.65, 0)
    label.FontFace = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    label.TextSize = 14
    label.TextScaled = true
    label.TextColor3 = config.COLORS.off.text
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = aiFrame

    -- Invisible clickable layer for frame
    local clickZone = Instance.new("TextButton")
    clickZone.BackgroundTransparency = 1
    clickZone.Size = UDim2.new(1, 0, 1, 0)
    clickZone.Text = ""
    clickZone.BackgroundColor3 = config.COLORS.off.background
    clickZone.TextColor3 = config.COLORS.off.text
    clickZone.AutoButtonColor = false
    clickZone.Parent = aiFrame
    -- Apply corner radius to the TextButton
    local cornerTextB = Instance.new("UICorner", clickZone)
    cornerTextB.CornerRadius = UDim.new(0, 8)

    -- Add stroke to the TextButton
    local strokeButton = Instance.new("UIStroke")
    strokeButton.Thickness = 1.6
    strokeButton.Color = Color3.fromRGB(255, 170, 0)
    strokeButton.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    strokeButton.Parent = clickZone

    -- update the frame's style when on/off
    local function updateToggleStyle(isOn)
        local style = isOn and config.COLORS.on or config.COLORS.off
    
        label.Text = isOn and "AI: ON" or "AI: OFF"
        label.TextColor3 = style.text
        icon.ImageColor3 = style.icon
        aiFrame.BackgroundColor3 = style.background
    end

    
    clickZone.MouseButton1Down:Connect(function()
        state.aiRunning = not state.aiRunning
        updateToggleStyle(state.aiRunning)

        if state.aiRunning then
            if not state.aiLoaded then
                ai.start(modules)
                state.aiLoaded = true
            end
        end
    end)
    print("[LOG]: GUI loaded.")
end

return M