--[[
    Speed.lua — carregado sob demanda pelo ForsakenScriptOP
    Expõe cleanup via _G.ForsakenSpeedCleanup
]]

-- Limpa qualquer instância anterior (caso o usuário reative sem desligar)
if _G.ForsakenSpeedCleanup then
    pcall(_G.ForsakenSpeedCleanup)
    _G.ForsakenSpeedCleanup = nil
end

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Players          = game:GetService("Players")
local StarterGui       = game:GetService("StarterGui")
local LocalPlayer      = Players.LocalPlayer

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local _connections = {}
local function track(c)
    table.insert(_connections, c)
    return c
end

-- ======================== GENERAL SETTINGS ========================
local systemEnabled     = true
local mobileSpeedActive = true
local currentMode       = "Speed2"
local holdingKey        = false
local holdingCKey       = false
local lastActiveMode    = nil
local guiClosed         = false

local SPEED_KEY  = Enum.KeyCode.LeftAlt
local INVERT_KEY = Enum.KeyCode.C
local RUN_SPEED  = 40

-- ======================== SPEED 2 MODE ========================
local originalSprintValue = nil

local function getSprintingValue()
    local character = LocalPlayer.Character
    if character then
        local speedMultipliers = character:FindFirstChild("SpeedMultipliers")
        if speedMultipliers then
            local sprinting = speedMultipliers:FindFirstChild("Sprinting")
            if sprinting then
                return sprinting
            end
        end
    end
    return nil
end

-- ======================== CLASSIC MODE ========================
local humanoidData = {}

local validNames = {
    Survivors = {
        ["Noob"]=true, ["Shedletsky"]=true, ["Guest1337"]=true, ["Chance"]=true,
        ["Taph"]=true, ["Elliot"]=true, ["JaneDoe"]=true, ["TwoTime"]=true,
        ["Veeronica"]=true, ["007n7"]=true,
    },
    Killers = {
        ["Noli"]=true, ["Slasher"]=true, ["1x1x1x1"]=true, ["c00lkidd"]=true,
        ["John Doe"]=true, ["JohnDoe"]=true, ["Sixer"]=true,
        ["Nosferatu"]=true, ["Azure"]=true,
    }
}

local function getNPCFolders()
    local folders = {}
    local playersFolder = Workspace:FindFirstChild("Players")
    if playersFolder then
        local survivors = playersFolder:FindFirstChild("Survivors")
        local killers   = playersFolder:FindFirstChild("Killers")
        if survivors then table.insert(folders, survivors) end
        if killers   then table.insert(folders, killers)   end
    end
    return folders
end

local function isValidName(name, folderType)
    if folderType == "Survivors" then
        return validNames.Survivors[name] == true
    elseif folderType == "Killers" then
        return validNames.Killers[name] == true
    end
    return false
end

-- ======================== RESTORE ========================
local function restoreSpeeds()
    local sprintObj = getSprintingValue()
    if sprintObj and originalSprintValue ~= nil then
        sprintObj.Value = originalSprintValue
        originalSprintValue = nil
    end
    for humanoid, originalSpeed in pairs(humanoidData) do
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = originalSpeed
        end
    end
    humanoidData = {}
end

-- ======================== FORWARD DECL ========================
local screenGui

-- ======================== CLEANUP ========================
local _cleanupDone = false
local function _cleanup()
    if _cleanupDone then return end
    _cleanupDone = true
    guiClosed         = true
    holdingKey        = false
    holdingCKey       = false
    mobileSpeedActive = false
    pcall(restoreSpeeds)
    for _, c in ipairs(_connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(_connections)
    if screenGui and screenGui.Parent then
        pcall(function() screenGui:Destroy() end)
    end
end
_G.ForsakenSpeedCleanup = _cleanup

-- ======================== GUI ========================
screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedModGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local success = pcall(function()
    screenGui.Parent = game:GetService("CoreGui")
end)
if not success then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local mainContainer = Instance.new("Frame")
mainContainer.Size = UDim2.new(0, 220, 0, 140)
mainContainer.Position = UDim2.new(0.8, -110, 0.7, -50)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = screenGui

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(0, 95, 0, -35)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = mainContainer
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)

local moveBtn = Instance.new("TextButton")
moveBtn.Size = UDim2.new(0, 40, 0, 40)
moveBtn.Position = UDim2.new(0, 90, 0, 0)
moveBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
moveBtn.Text = "Move"
moveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
moveBtn.Font = Enum.Font.GothamBold
moveBtn.TextSize = 10
moveBtn.Parent = mainContainer
Instance.new("UICorner", moveBtn).CornerRadius = UDim.new(0.5, 0)

local speedBtn = Instance.new("TextButton")
speedBtn.Size = UDim2.new(0, 60, 0, 60)
speedBtn.Position = UDim2.new(0, 80, 0, 40)
speedBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
speedBtn.Text = "ON"
speedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBtn.Font = Enum.Font.GothamBold
speedBtn.TextSize = 18
speedBtn.Parent = mainContainer
Instance.new("UICorner", speedBtn).CornerRadius = UDim.new(0.5, 0)

local modeBtn = Instance.new("TextButton")
modeBtn.Size = UDim2.new(0, 60, 0, 30)
modeBtn.Position = UDim2.new(0, 80, 0, 105)
modeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
modeBtn.Text = "Speed2"
modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
modeBtn.Font = Enum.Font.GothamBold
modeBtn.TextSize = 12
modeBtn.Parent = mainContainer
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0.3, 0)

local speedInput = Instance.new("TextBox")
speedInput.Size = UDim2.new(0, 50, 0, 40)
speedInput.Position = UDim2.new(0, 150, 0, 50)
speedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
speedInput.Font = Enum.Font.GothamBold
speedInput.TextSize = 16
speedInput.Text = "4"
speedInput.PlaceholderText = "Spd"
speedInput.Visible = true
speedInput.Parent = mainContainer
Instance.new("UICorner", speedInput).CornerRadius = UDim.new(0.3, 0)

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(0, 80, 0, 20)
modeLabel.Position = UDim2.new(0, 135, 0, 105)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Mode: Speed2"
modeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
modeLabel.Font = Enum.Font.Gotham
modeLabel.TextSize = 12
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = mainContainer

-- ======================== CLOSE BUTTON ========================
closeBtn.MouseButton1Click:Connect(function()
    _cleanup()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Speed Mod",
            Text = "GUI Closed - Speeds Restored",
            Duration = 2
        })
    end)
end)

-- ======================== DRAG LOGIC ========================
local isMoveMode = false
local dragging   = false
local dragStart  = nil
local startPos   = nil

track(moveBtn.MouseButton1Click:Connect(function()
    isMoveMode = not isMoveMode
    if isMoveMode then
        moveBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        moveBtn.Text = "OK"
        speedBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
        speedBtn.Text = "Drag"
    else
        moveBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        moveBtn.Text = "Move"
        if mobileSpeedActive then
            speedBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            speedBtn.Text = "ON"
        else
            speedBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            speedBtn.Text = "OFF"
        end
    end
end))

track(speedBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if isMoveMode then
            dragging  = true
            dragStart = input.Position
            startPos  = mainContainer.Position
        else
            mobileSpeedActive = not mobileSpeedActive
            if mobileSpeedActive then
                speedBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
                speedBtn.Text = "ON"
            else
                speedBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                speedBtn.Text = "OFF"
                if not (holdingKey or holdingCKey) then
                    restoreSpeeds()
                    lastActiveMode = nil
                end
            end
        end
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainContainer.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

-- ======================== MODE SWITCH ========================
track(modeBtn.MouseButton1Click:Connect(function()
    if currentMode == "Speed2" then
        currentMode = "Classic"
        modeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
        modeBtn.Text = "Classic"
        speedInput.Visible = false
        modeLabel.Text = "Mode: Classic"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Mode Changed",
                Text = "Classic Mode | ALT to Activate | Hold C to Invert",
                Duration = 3
            })
        end)
    else
        currentMode = "Speed2"
        modeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        modeBtn.Text = "Speed2"
        speedInput.Visible = true
        modeLabel.Text = "Mode: Speed2"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Mode Changed",
                Text = "Speed 2 Mode | ALT to Activate | Hold C to Invert",
                Duration = 3
            })
        end)
    end
    restoreSpeeds()
    lastActiveMode = nil
end))

-- ======================== KEYBOARD INPUT ========================
track(UserInputService.InputBegan:Connect(function(input, processed)
    if guiClosed then return end
    if processed then return end

    if input.KeyCode == SPEED_KEY then
        holdingKey = true
    elseif input.KeyCode == INVERT_KEY then
        holdingCKey = true
    end

    if input.KeyCode == Enum.KeyCode.L then
        systemEnabled = not systemEnabled
        holdingKey = false
        holdingCKey = false
        mobileSpeedActive = false
        speedBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        speedBtn.Text = "OFF"
        restoreSpeeds()
        lastActiveMode = nil
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "System",
                Text = systemEnabled and "System ENABLED" or "System DISABLED",
                Duration = 2
            })
        end)
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if guiClosed then return end
    if input.KeyCode == SPEED_KEY then
        holdingKey = false
    elseif input.KeyCode == INVERT_KEY then
        holdingCKey = false
    end
    if not (holdingKey or holdingCKey or mobileSpeedActive) then
        restoreSpeeds()
        lastActiveMode = nil
    end
end))

-- ======================== CHARACTER RESET ========================
track(LocalPlayer.CharacterAdded:Connect(function(character)
    originalSprintValue = nil
    humanoidData = {}
end))

-- ======================== MAIN LOOP ========================
track(RunService.RenderStepped:Connect(function()
    if guiClosed then return end
    if not systemEnabled then return end
    if not (holdingKey or holdingCKey or mobileSpeedActive) then return end

    local activeMode = currentMode
    if holdingCKey then
        if currentMode == "Speed2" then
            activeMode = "Classic"
        else
            activeMode = "Speed2"
        end
    end

    if lastActiveMode ~= activeMode then
        restoreSpeeds()
        lastActiveMode = activeMode
    end

    if activeMode == "Speed2" then
        local sprintObj = getSprintingValue()
        if sprintObj then
            if originalSprintValue == nil then
                originalSprintValue = sprintObj.Value
            end
            local customSpeed = tonumber(speedInput.Text)
            if not customSpeed then customSpeed = 4 end
            sprintObj.Value = customSpeed
        end
    else
        local folders = getNPCFolders()
        for _, folder in ipairs(folders) do
            local folderType = folder.Name
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and isValidName(model.Name, folderType) then
                    local humanoid = model:FindFirstChild("Humanoid")
                    if humanoid then
                        if not humanoidData[humanoid] then
                            humanoidData[humanoid] = humanoid.WalkSpeed
                        end
                        humanoid.WalkSpeed = RUN_SPEED
                    end
                end
            end
        end
    end
end))

-- ======================== INITIAL NOTIFICATION ========================
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Speed Mod Loaded",
        Text = "Speed 2 Mode Active | Hold ALT/C or use button",
        Duration = 5
    })
end)
