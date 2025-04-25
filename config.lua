local config = {}

-- Clock to wait-time ranges
config.CLOCK_WAIT_MAPPING = {
    ["∞"] = {min = 4, max = 7},
    ["1:00"] = {min = 0, max = 1},
    ["3:00"] = {min = 2, max = 3},
    ["10:00"] = {min = 4, max = 7},
}

-- Clock to game type
config.CLOCK_NAME_MAPPING = {
    ["1:00"] = "bullet",
    ["3:00"] = "blitz",
    ["10:00"] = "rapid",
    ["∞"] = "casual",
}

-- Icon and colors
config.ICON_IMAGE = "http://www.roblox.com/asset/?id=95384848753847"

config.COLORS = {
    on = {
        background = Color3.fromRGB(255, 170, 0),
        text = Color3.fromRGB(22, 16, 12),
        icon = Color3.fromRGB(22, 16, 12),
    },
    off = {
        background = Color3.fromRGB(22, 16, 12),
        text = Color3.fromRGB(255, 170, 0),
        icon = Color3.fromRGB(255, 170, 0)
    }
}

return config