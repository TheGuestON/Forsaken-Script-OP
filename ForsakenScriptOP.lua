local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer

local allConnections = {}

-- ==================== SPRINTING MODULE (Stamina) ====================
local Sprinting = nil
local function tryLoadSprinting()
    if Sprinting then return true end
    local ok, mod = pcall(function()
        local Systems = ReplicatedStorage:FindFirstChild("Systems")
        if not Systems then return nil end
        local Character = Systems:FindFirstChild("Character")
        if not Character then return nil end
        local Game = Character:FindFirstChild("Game")
        if not Game then return nil end
        local Sprint = Game:FindFirstChild("Sprinting")
        if not Sprint then return nil end
        return require(Sprint)
    end)
    if ok and mod then Sprinting = mod return true end
    return false
end
tryLoadSprinting()

-- ==================== KILLER ATTACK ANIMATION IDS ====================
local ATTACK_ANIM_IDS = {
    ["83829782357897"]  = "1x1x1x1 Slash",
    ["105458270463374"] = "JohnDoe Slash",
    ["106538427162796"] = "Noli Stab",
    ["88451353906104"]  = "Nosferatu Slash",
    ["126830014841198"] = "Slasher Slash",
    ["123172382755876"] = "Azure Slash",
    ["122709416391891"] = "Sixer Slash",
    ["87989533095285"]  = "Bite",
    ["18885909645"]     = "c00lkidd Attack",
}

local function extractAnimId(animId)
    if not animId then return nil end
    local s = tostring(animId)
    return s:match("(%d+)$")
end

local function isAttackAnim(track)
    if not track or not track.Animation then return false, nil end
    local id = extractAnimId(track.Animation.AnimationId)
    if not id then return false, nil end
    if ATTACK_ANIM_IDS[id] then
        return true, ATTACK_ANIM_IDS[id]
    end
    return false, nil
end

local function getKillerAnchor(k)
    if not k then return nil end
    local hrp = k:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    local hum = k:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart and hum.RootPart:IsA("BasePart") then return hum.RootPart end
    if k.PrimaryPart and k.PrimaryPart:IsA("BasePart") then return k.PrimaryPart end
    hrp = k:FindFirstChild("HumanoidRootPart", true)
    if hrp and hrp:IsA("BasePart") then return hrp end
    local h2 = k:FindFirstChildOfClass("Humanoid", true)
    if h2 and h2.RootPart and h2.RootPart:IsA("BasePart") then return h2.RootPart end
    return nil
end

local function findNearestKiller(pos, maxDist)
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return nil end
    local kf = pf:FindFirstChild("Killers")
    if not kf then return nil end
    local best, bd = nil, maxDist or 20
    for _, k in ipairs(kf:GetChildren()) do
        if k:IsA("Model") then
            local a = getKillerAnchor(k)
            if a then
                local d = (a.Position - pos).Magnitude
                if d < bd then bd = d best = k end
            end
        end
    end
    return best
end

-- ==================== GENERATOR FINDER ====================
local function getGeneratorPosition(gen)
    if not gen then return nil end
    local pp = gen.PrimaryPart
    if pp and pp:IsA("BasePart") then return pp.Position end
    local p1 = gen:FindFirstChild("Main")
    if p1 then
        local prompt = p1:FindFirstChild("Prompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            local part = prompt.Parent
            if part and part:IsA("BasePart") then return part.Position end
        end
    end
    local anyPart = gen:FindFirstChildWhichIsA("BasePart", true)
    return anyPart and anyPart.Position or nil
end

local function getMapIngameFolder()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local ingame = map:FindFirstChild("Ingame")
    if not ingame then return nil end
    return ingame:FindFirstChild("Map")
end

local function findNearestGenerator()
    local lp = Players.LocalPlayer or player
    if not lp or not lp.Character then return nil, math.huge end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, math.huge end
    local mapFolder = getMapIngameFolder()
    if not mapFolder then return nil, math.huge end
    local best, bd = nil, math.huge
    for _, gen in ipairs(mapFolder:GetChildren()) do
        if gen:IsA("Model") and gen:FindFirstChild("Progress") then
            local genPos = getGeneratorPosition(gen)
            if genPos then
                local d = (genPos - root.Position).Magnitude
                if d < bd then bd = d best = gen end
            end
        end
    end
    return best, bd
end

-- ==================== MAIN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ForsakenHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("ImageLabel", screenGui)
openButton.Size = UDim2.new(0, 60, 0, 60)
openButton.Position = UDim2.new(0, 20, 0, 20)
openButton.BackgroundTransparency = 1
openButton.Image = "rbxassetid://72721797847451"
Instance.new("UICorner", openButton).CornerRadius = UDim.new(0, 30)
local uiStroke = Instance.new("UIStroke", openButton)
uiStroke.Thickness = 2
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Transparency = 0.8

local buttonText = Instance.new("TextLabel", openButton)
buttonText.Size = UDim2.new(1, 0, 1, 0)
buttonText.BackgroundTransparency = 1
buttonText.Text = "Forsaken"
buttonText.TextColor3 = Color3.new(1, 1, 1)
buttonText.Font = Enum.Font.SourceSansBold
buttonText.TextSize = 14
buttonText.TextStrokeTransparency = 0.7
buttonText.TextStrokeColor3 = Color3.new(0, 0, 0)
buttonText.TextWrapped = true

local draggingButton, dragInputButton, dragStartButton, startPosButton = false, nil, Vector2.zero, UDim2.new(0, 0, 0, 0)
openButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingButton = true
        dragStartButton = input.Position
        startPosButton = openButton.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingButton = false end end)
    end
end)
openButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputButton = input end
end)
table.insert(allConnections, RunService.RenderStepped:Connect(function()
    if draggingButton and dragInputButton then
        local d = dragInputButton.Position - dragStartButton
        openButton.Position = UDim2.new(startPosButton.X.Scale, startPosButton.X.Offset + d.X, startPosButton.Y.Scale, startPosButton.Y.Offset + d.Y)
    end
end))

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 500, 0, 300)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 15)
local mainFrameStroke = Instance.new("UIStroke", mainFrame)
mainFrameStroke.Thickness = 2
mainFrameStroke.Color = Color3.fromRGB(0, 50, 150)
TweenService:Create(mainFrameStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0), {Color = Color3.fromRGB(0, 150, 255)}):Play()

local headerFrame = Instance.new("Frame", mainFrame)
headerFrame.Size = UDim2.new(1, 0, 0, 35)
headerFrame.BackgroundTransparency = 1
local forsakenLabel = Instance.new("TextLabel", headerFrame)
forsakenLabel.Size = UDim2.new(0, 120, 1, 0)
forsakenLabel.Position = UDim2.new(0, 10, 0, 0)
forsakenLabel.BackgroundTransparency = 1
forsakenLabel.Text = "Forsaken"
forsakenLabel.TextColor3 = Color3.new(1, 0, 0)
forsakenLabel.Font = Enum.Font.SourceSansBold
forsakenLabel.TextSize = 18
forsakenLabel.TextXAlignment = Enum.TextXAlignment.Left

local hue = 0
table.insert(allConnections, RunService.RenderStepped:Connect(function(d)
    hue = (hue + d) % 1
    forsakenLabel.TextColor3 = Color3.fromHSV(hue, 1, 1)
end))

local draggingMainFrame, dragInputMainFrame, dragStartMainFrame, startPosMainFrame = false, nil, Vector2.zero, UDim2.new(0, 0, 0, 0)
headerFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMainFrame = true
        dragStartMainFrame = input.Position
        startPosMainFrame = mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingMainFrame = false end end)
    end
end)
headerFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInputMainFrame = input end
end)
table.insert(allConnections, RunService.RenderStepped:Connect(function()
    if draggingMainFrame and dragInputMainFrame then
        local d = dragInputMainFrame.Position - dragStartMainFrame
        mainFrame.Position = UDim2.new(startPosMainFrame.X.Scale, startPosMainFrame.X.Offset + d.X, startPosMainFrame.Y.Scale, startPosMainFrame.Y.Offset + d.Y)
    end
end))

local minimizeButton = Instance.new("TextButton", mainFrame)
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -70, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.TextSize = 25
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 8)

local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 20
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

local isGUIOpen = false
local currentKey = Enum.KeyCode.H
local isSelectingKey = false
local function toggleGUI()
    isGUIOpen = not isGUIOpen
    mainFrame.Visible = isGUIOpen
    openButton.Visible = not isGUIOpen
end
local clickStartedOnButton = false
openButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local m, p, s = input.Position, openButton.AbsolutePosition, openButton.AbsoluteSize
        clickStartedOnButton = m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
    end
end)
openButton.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and clickStartedOnButton then
        local m, p, s = input.Position, openButton.AbsolutePosition, openButton.AbsoluteSize
        if m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y then toggleGUI() end
    end
    clickStartedOnButton = false
end)
minimizeButton.MouseButton1Click:Connect(toggleGUI)

local sideMenu = Instance.new("ScrollingFrame", mainFrame)
sideMenu.Size = UDim2.new(0, 100, 1, -35)
sideMenu.Position = UDim2.new(0, 0, 0, 35)
sideMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sideMenu.ScrollBarThickness = 2
sideMenu.CanvasSize = UDim2.new(0, 0, 0, 0)
sideMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
sideMenu.ScrollingDirection = Enum.ScrollingDirection.Y
sideMenu.BorderSizePixel = 0
Instance.new("UICorner", sideMenu).CornerRadius = UDim.new(0, 15)
local sl = Instance.new("UIListLayout", sideMenu)
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.Padding = UDim.new(0, 5)
sl.HorizontalAlignment = Enum.HorizontalAlignment.Center

local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -100, 1, -35)
contentFrame.Position = UDim2.new(0, 100, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 12)

local function createTabButton(name, order)
    local b = Instance.new("TextButton", sideMenu)
    b.Size = UDim2.new(0, 90, 0, 40)
    b.LayoutOrder = order
    b.Text = name
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.TextWrapped = true
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.TextStrokeTransparency = 0.8
    return b
end

local configTab = createTabButton("Config", 1)
local espTab = createTabButton("ESP", 2)
local autoBlockTab = createTabButton("AutoBlock", 3)
local playerTab = createTabButton("Player", 4)
local generatorsTab = createTabButton("Generators", 5)
local settingsTab = createTabButton("Settings", 6)

local configFrame = Instance.new("Frame", contentFrame)
configFrame.Size = UDim2.new(1, 0, 1, 0)
configFrame.BackgroundTransparency = 1
configFrame.Visible = true

local espFrame = Instance.new("ScrollingFrame", contentFrame)
espFrame.Size = UDim2.new(1, 0, 1, 0)
espFrame.BackgroundTransparency = 1
espFrame.Visible = false
espFrame.ScrollBarThickness = 3
espFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
espFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local hitboxFrame = Instance.new("ScrollingFrame", contentFrame)
hitboxFrame.Size = UDim2.new(1, 0, 1, 0)
hitboxFrame.BackgroundTransparency = 1
hitboxFrame.Visible = false
hitboxFrame.ScrollBarThickness = 3
hitboxFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
hitboxFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local playerFrame = Instance.new("ScrollingFrame", contentFrame)
playerFrame.Size = UDim2.new(1, 0, 1, 0)
playerFrame.BackgroundTransparency = 1
playerFrame.Visible = false
playerFrame.ScrollBarThickness = 3
playerFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playerFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local generatorsFrame = Instance.new("ScrollingFrame", contentFrame)
generatorsFrame.Size = UDim2.new(1, 0, 1, 0)
generatorsFrame.BackgroundTransparency = 1
generatorsFrame.Visible = false
generatorsFrame.ScrollBarThickness = 3
generatorsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
generatorsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local settingsFrame = Instance.new("Frame", contentFrame)
settingsFrame.Size = UDim2.new(1, 0, 1, 0)
settingsFrame.BackgroundTransparency = 1
settingsFrame.Visible = false

local function showTab(f)
    for _, c in ipairs(contentFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("ScrollingFrame") then c.Visible = false end
    end
    f.Visible = true
end
configTab.MouseButton1Click:Connect(function() showTab(configFrame) end)
espTab.MouseButton1Click:Connect(function() showTab(espFrame) end)
autoBlockTab.MouseButton1Click:Connect(function() showTab(hitboxFrame) end)
playerTab.MouseButton1Click:Connect(function() showTab(playerFrame) end)
generatorsTab.MouseButton1Click:Connect(function() showTab(generatorsFrame) end)
settingsTab.MouseButton1Click:Connect(function() showTab(settingsFrame) end)

-- ==================== SLIDER HELPER ====================
local function createSlider(parent, yy, minVal, maxVal, default, labelText, onChanged)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0, 290, 0, 48)
    container.Position = UDim2.new(0, 15, 0, yy)
    container.BackgroundTransparency = 1

    local title = Instance.new("TextLabel", container)
    title.Size = UDim2.new(0, 130, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = labelText
    title.TextColor3 = Color3.fromRGB(220, 220, 220)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left

    local input = Instance.new("TextBox", container)
    input.Size = UDim2.new(0, 100, 0, 22)
    input.Position = UDim2.new(1, -100, 0, 0)
    input.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    input.TextColor3 = Color3.new(1, 1, 1)
    input.Font = Enum.Font.SourceSans
    input.TextSize = 13
    input.Text = tostring(default)
    input.ClearTextOnFocus = false
    input.BorderSizePixel = 0
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

    local track = Instance.new("Frame", container)
    track.Size = UDim2.new(1, 0, 0, 10)
    track.Position = UDim2.new(0, 0, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 5)

    local pct = math.clamp((default - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(pct, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Thickness = 2
    knobStroke.Color = Color3.fromRGB(0, 150, 255)

    local currentValue = default
    local isDragging = false

    local function applyValue(v, fromInput)
        v = math.clamp(tonumber(v) or currentValue, minVal, maxVal)
        currentValue = v
        local p = math.clamp((v - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -8, 0.5, -8)
        if not fromInput then
            input.Text = tostring(math.floor(v * 100) / 100)
        end
        if onChanged then onChanged(v) end
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            local rel = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            applyValue(minVal + rel * (maxVal - minVal))
        end
    end)
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)
    table.insert(allConnections, UserInputService.InputChanged:Connect(function(inp)
        if isDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            applyValue(minVal + rel * (maxVal - minVal))
        end
    end))
    table.insert(allConnections, UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end))
    input.FocusLost:Connect(function()
        applyValue(input.Text, true)
        input.Text = tostring(math.floor(currentValue * 100) / 100)
    end)

    return { SetValue = applyValue, GetValue = function() return currentValue end }
end

-- ==================== CONFIG TAB: Restore Cursor ====================
local restoreCursorEnabled = false
local restoreCursorConnection = nil
local function isLargeFrame(f)
    local s = f.Size
    if s.X.Scale >= 1 and s.Y.Scale >= 1 then return true end
    if s.X.Offset >= 300 and s.Y.Scale >= 1 then return true end
    if s.X.Scale >= 1 or s.Y.Scale >= 1 then return true end
    if s.X.Offset >= 300 or s.Y.Offset >= 300 then return true end
    return false
end
local function hideCrosshair()
    local hui = CoreGui:FindFirstChild("HUI")
    if not hui then return end
    local ob = hui:FindFirstChild("Obsidian")
    if not ob then return end
    for _, c in ipairs(ob:GetChildren()) do
        if c:IsA("Frame") and c.Name == "Frame" and not isLargeFrame(c) then
            c.BackgroundTransparency = 1
            for _, c2 in ipairs(c:GetChildren()) do
                if c2:IsA("Frame") then
                    c2.BackgroundTransparency = 1
                    for _, c3 in ipairs(c2:GetChildren()) do
                        if c3:IsA("Frame") then c3.BackgroundTransparency = 1 end
                    end
                elseif c2:IsA("ImageLabel") then c2.ImageTransparency = 1 end
            end
        end
    end
end
local function startCursorRestoration()
    if restoreCursorConnection then restoreCursorConnection:Disconnect() end
    UserInputService.MouseIconEnabled = true
    hideCrosshair()
    restoreCursorConnection = RunService.RenderStepped:Connect(function()
        if restoreCursorEnabled then UserInputService.MouseIconEnabled = true hideCrosshair() end
    end)
end
local function stopCursorRestoration()
    if restoreCursorConnection then restoreCursorConnection:Disconnect() restoreCursorConnection = nil end
end

local restoreCursorButton = Instance.new("TextButton", configFrame)
restoreCursorButton.Size = UDim2.new(0, 250, 0, 40)
restoreCursorButton.Position = UDim2.new(0, 20, 0, 20)
restoreCursorButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
restoreCursorButton.TextColor3 = Color3.new(1, 1, 1)
restoreCursorButton.Font = Enum.Font.SourceSansBold
restoreCursorButton.TextSize = 14
restoreCursorButton.Text = "Restore Cursor: Disabled"
Instance.new("UICorner", restoreCursorButton).CornerRadius = UDim.new(0, 10)
restoreCursorButton.MouseButton1Click:Connect(function()
    restoreCursorEnabled = not restoreCursorEnabled
    restoreCursorButton.Text = restoreCursorEnabled and "Restore Cursor: Enabled" or "Restore Cursor: Disabled"
    if restoreCursorEnabled then startCursorRestoration() else stopCursorRestoration() end
end)

local restoreCursorInfo = Instance.new("TextLabel", configFrame)
restoreCursorInfo.Size = UDim2.new(0, 250, 0, 60)
restoreCursorInfo.Position = UDim2.new(0, 20, 0, 70)
restoreCursorInfo.BackgroundTransparency = 1
restoreCursorInfo.TextColor3 = Color3.fromRGB(150, 150, 150)
restoreCursorInfo.Font = Enum.Font.SourceSans
restoreCursorInfo.TextSize = 11
restoreCursorInfo.Text = "Hides crosshair frames and restores\nthe mouse cursor visibility."
restoreCursorInfo.TextXAlignment = Enum.TextXAlignment.Left
restoreCursorInfo.TextWrapped = true

-- ==================== ESP SYSTEM (event-based, no per-frame scanning) ====================
local ESP = {
    Players    = { Enabled = false, Fill = 0.4, Border = 0, HasBorder = false, Color = Color3.fromRGB(0, 150, 255) },
    Killers    = { Enabled = false, Fill = 0.4, Border = 0, HasBorder = true,  Color = Color3.fromRGB(255, 0, 0) },
    Generators = { Enabled = false, Fill = 0.4, Border = 0, HasBorder = true,  Color = Color3.fromRGB(255, 200, 0) },
    Items      = { Enabled = false, Fill = 0.4, Border = 0, HasBorder = true,  Color = Color3.fromRGB(0, 255, 0) },
}

local espHighlights = { Players = {}, Killers = {}, Generators = {}, Items = {} }
local espConnections = { Players = {}, Killers = {}, Generators = {}, Items = {} }
local espItemNames = { Medkit = true, BloxyCola = true }

local function isESPItem(inst)
    if not (inst:IsA("Model") or inst:IsA("Tool")) then return false end
    return espItemNames[inst.Name] == true
end

local function esp_applyVisual(h, category)
    local cfg = ESP[category]
    h.FillColor = cfg.Color
    h.FillTransparency = cfg.Fill
    h.OutlineColor = cfg.Color
    h.OutlineTransparency = cfg.HasBorder and cfg.Border or 1
end

local function esp_add(category, inst)
    if espHighlights[category][inst] then
        esp_applyVisual(espHighlights[category][inst], category)
        return
    end
    local h = Instance.new("Highlight")
    h.Name = "ForsakenESP_" .. category
    h.Adornee = inst
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = screenGui
    espHighlights[category][inst] = h
    esp_applyVisual(h, category)
end

local function esp_remove(category, inst)
    local h = espHighlights[category][inst]
    if h then
        pcall(function() h:Destroy() end)
        espHighlights[category][inst] = nil
    end
end

local function esp_refreshAll(category)
    for _, h in pairs(espHighlights[category]) do
        esp_applyVisual(h, category)
    end
end

local function esp_clearCategory(category)
    for _, h in pairs(espHighlights[category]) do
        pcall(function() h:Destroy() end)
    end
    table.clear(espHighlights[category])
end

local function esp_disconnectCategory(category)
    for _, c in ipairs(espConnections[category]) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(espConnections[category])
end

-- --- Player ESP ---
local function startPlayersESP()
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return false end
    local surv = pf:FindFirstChild("Survivors")
    if not surv then return false end

    for _, m in ipairs(surv:GetChildren()) do
        if m:IsA("Model") and m ~= player.Character then
            local hp = m:FindFirstChildOfClass("Humanoid")
            if hp and hp.Health > 0 then esp_add("Players", m) end
        end
    end

    table.insert(espConnections.Players, surv.ChildAdded:Connect(function(m)
        if not ESP.Players.Enabled then return end
        if m:IsA("Model") and m ~= player.Character then
            task.wait(0.1)
            if not ESP.Players.Enabled then return end
            local hp = m:FindFirstChildOfClass("Humanoid")
            if hp and hp.Health > 0 then esp_add("Players", m) end
        end
    end))

    table.insert(espConnections.Players, surv.ChildRemoved:Connect(function(m)
        esp_remove("Players", m)
    end))

    return true
end

local function stopPlayersESP()
    esp_disconnectCategory("Players")
    esp_clearCategory("Players")
end

-- --- Killer ESP ---
local function startKillersESP()
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return false end
    local kf = pf:FindFirstChild("Killers")
    if not kf then return false end

    for _, m in ipairs(kf:GetChildren()) do
        if m:IsA("Model") then
            local hp = m:FindFirstChildOfClass("Humanoid")
            if hp and hp.Health > 0 then esp_add("Killers", m) end
        end
    end

    table.insert(espConnections.Killers, kf.ChildAdded:Connect(function(m)
        if not ESP.Killers.Enabled then return end
        if m:IsA("Model") then
            task.wait(0.1)
            if not ESP.Killers.Enabled then return end
            local hp = m:FindFirstChildOfClass("Humanoid")
            if hp and hp.Health > 0 then esp_add("Killers", m) end
        end
    end))

    table.insert(espConnections.Killers, kf.ChildRemoved:Connect(function(m)
        esp_remove("Killers", m)
    end))

    return true
end

local function stopKillersESP()
    esp_disconnectCategory("Killers")
    esp_clearCategory("Killers")
end

-- --- Generator ESP ---
local function getGeneratorHighlightTarget(gen)
    local instances = gen:FindFirstChild("Instances")
    if instances then
        local inner = instances:FindFirstChild("Generator")
        if inner then return inner end
    end
    return gen
end

local function genIsComplete(gen)
    local progress = gen:FindFirstChild("Progress")
    if not progress or not progress:IsA("NumberValue") then return true end
    if progress.Value >= 100 then return true end
    local completed = gen:GetAttribute("cl_Completed")
    return completed ~= nil and completed >= 5
end

local function trackGenerator(gen)
    if not gen:IsA("Model") then return end
    if genIsComplete(gen) then return end
    local target = getGeneratorHighlightTarget(gen)
    esp_add("Generators", target)

    -- Watch the Progress NumberValue to auto-remove when complete
    local progress = gen:FindFirstChild("Progress")
    if progress and progress:IsA("NumberValue") then
        table.insert(espConnections.Generators, progress:GetPropertyChangedSignal("Value"):Connect(function()
            if not ESP.Generators.Enabled then return end
            if progress.Value >= 100 then
                esp_remove("Generators", target)
            elseif not espHighlights.Generators[target] then
                esp_add("Generators", target)
            end
        end))
    end
end

local function startGeneratorsESP()
    local mapFolder = getMapIngameFolder()
    if not mapFolder then return false end

    for _, gen in ipairs(mapFolder:GetChildren()) do
        trackGenerator(gen)
    end

    table.insert(espConnections.Generators, mapFolder.ChildAdded:Connect(function(gen)
        if not ESP.Generators.Enabled then return end
        task.wait(0.1)
        if not ESP.Generators.Enabled then return end
        trackGenerator(gen)
    end))

    table.insert(espConnections.Generators, mapFolder.ChildRemoved:Connect(function(gen)
        local target = getGeneratorHighlightTarget(gen)
        esp_remove("Generators", target)
    end))

    return true
end

local function stopGeneratorsESP()
    esp_disconnectCategory("Generators")
    esp_clearCategory("Generators")
end

-- --- Item ESP ---
local function startItemsESP()
    -- Initial scan
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if isESPItem(c) then
                esp_add("Items", c)
            elseif c:IsA("Model") or c:IsA("Folder") or c:IsA("Workspace") then
                scan(c)
            end
        end
    end
    scan(Workspace)

    table.insert(espConnections.Items, Workspace.DescendantAdded:Connect(function(d)
        if not ESP.Items.Enabled then return end
        if isESPItem(d) then esp_add("Items", d) end
    end))

    table.insert(espConnections.Items, Workspace.DescendantRemoving:Connect(function(d)
        if espHighlights.Items[d] then esp_remove("Items", d) end
    end))

    return true
end

local function stopItemsESP()
    esp_disconnectCategory("Items")
    esp_clearCategory("Items")
end

-- Slow health check (0.5s) - cheap, only iterates existing highlights
task.spawn(function()
    while true do
        task.wait(0.5)
        for inst, _ in pairs(espHighlights.Players) do
            local hp = inst:FindFirstChildOfClass("Humanoid")
            if not inst.Parent or not hp or hp.Health <= 0 then
                esp_remove("Players", inst)
            end
        end
        for inst, _ in pairs(espHighlights.Killers) do
            local hp = inst:FindFirstChildOfClass("Humanoid")
            if not inst.Parent or not hp or hp.Health <= 0 then
                esp_remove("Killers", inst)
            end
        end
    end
end)

-- ==================== ESP TAB UI ====================
local ey = 10
local function espSectionTitle(text)
    local l = Instance.new("TextLabel", espFrame)
    l.Size = UDim2.new(0, 290, 0, 22)
    l.Position = UDim2.new(0, 15, 0, ey)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(0, 200, 255)
    l.Font = Enum.Font.SourceSansBold
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    ey = ey + 26
end

local function espToggle(text, initial, onClick)
    local b = Instance.new("TextButton", espFrame)
    b.Size = UDim2.new(0, 290, 0, 30)
    b.Position = UDim2.new(0, 15, 0, ey)
    b.BackgroundColor3 = initial and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 13
    b.Text = text .. ": " .. (initial and "ON" or "OFF")
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function()
        local new = not (b.Text:find(": ON") ~= nil)
        b.Text = text .. ": " .. (new and "ON" or "OFF")
        b.BackgroundColor3 = new and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
        if onClick then onClick(new) end
    end)
    ey = ey + 35
    return b
end

-- Items
espSectionTitle("Item ESP (Green)")
espToggle("Items ESP", ESP.Items.Enabled, function(v)
    ESP.Items.Enabled = v
    if v then startItemsESP() else stopItemsESP() end
end)
createSlider(espFrame, ey, 0, 1, ESP.Items.Fill, "Items Fill Transparency", function(v)
    ESP.Items.Fill = v
    esp_refreshAll("Items")
end)
ey = ey + 60
espToggle("Items Border", ESP.Items.HasBorder, function(v)
    ESP.Items.HasBorder = v
    esp_refreshAll("Items")
end)
createSlider(espFrame, ey, 0, 1, ESP.Items.Border, "Items Border Transparency", function(v)
    ESP.Items.Border = v
    esp_refreshAll("Items")
end)
ey = ey + 60

-- Players
espSectionTitle("Player ESP (Blue)")
espToggle("Players ESP", ESP.Players.Enabled, function(v)
    ESP.Players.Enabled = v
    if v then startPlayersESP() else stopPlayersESP() end
end)
createSlider(espFrame, ey, 0, 1, ESP.Players.Fill, "Players Fill Transparency", function(v)
    ESP.Players.Fill = v
    esp_refreshAll("Players")
end)
ey = ey + 60
espToggle("Players Border", ESP.Players.HasBorder, function(v)
    ESP.Players.HasBorder = v
    esp_refreshAll("Players")
end)
createSlider(espFrame, ey, 0, 1, ESP.Players.Border, "Players Border Transparency", function(v)
    ESP.Players.Border = v
    esp_refreshAll("Players")
end)
ey = ey + 60

-- Killers
espSectionTitle("Killer ESP (Red)")
espToggle("Killers ESP", ESP.Killers.Enabled, function(v)
    ESP.Killers.Enabled = v
    if v then startKillersESP() else stopKillersESP() end
end)
createSlider(espFrame, ey, 0, 1, ESP.Killers.Fill, "Killers Fill Transparency", function(v)
    ESP.Killers.Fill = v
    esp_refreshAll("Killers")
end)
ey = ey + 60
espToggle("Killers Border", ESP.Killers.HasBorder, function(v)
    ESP.Killers.HasBorder = v
    esp_refreshAll("Killers")
end)
createSlider(espFrame, ey, 0, 1, ESP.Killers.Border, "Killers Border Transparency", function(v)
    ESP.Killers.Border = v
    esp_refreshAll("Killers")
end)
ey = ey + 60

-- Generators
espSectionTitle("Generator ESP (Yellow)")
espToggle("Generators ESP", ESP.Generators.Enabled, function(v)
    ESP.Generators.Enabled = v
    if v then startGeneratorsESP() else stopGeneratorsESP() end
end)
createSlider(espFrame, ey, 0, 1, ESP.Generators.Fill, "Generators Fill Transparency", function(v)
    ESP.Generators.Fill = v
    esp_refreshAll("Generators")
end)
ey = ey + 60
espToggle("Generators Border", ESP.Generators.HasBorder, function(v)
    ESP.Generators.HasBorder = v
    esp_refreshAll("Generators")
end)
createSlider(espFrame, ey, 0, 1, ESP.Generators.Border, "Generators Border Transparency", function(v)
    ESP.Generators.Border = v
    esp_refreshAll("Generators")
end)
ey = ey + 20

-- ==================== PLAYER TAB (Stamina) ====================
local PS = {
    MaxStamina = 100,
    StaminaGain = 20,
    StaminaLoss = 10,
    InfiniteStamina = false,
}

local function pushToSprinting()
    if not Sprinting then tryLoadSprinting() end
    if not Sprinting then return end
    pcall(function()
        Sprinting.MaxStamina = PS.MaxStamina
        Sprinting.StaminaGain = PS.StaminaGain
        Sprinting.StaminaLoss = PS.StaminaLoss
        if PS.InfiniteStamina then
            Sprinting.StaminaLossDisabled = true
            Sprinting.Stamina = PS.MaxStamina
        else
            Sprinting.StaminaLossDisabled = false
        end
    end)
end

table.insert(allConnections, RunService.Heartbeat:Connect(function()
    if not Sprinting then return end
    if Sprinting.MaxStamina ~= PS.MaxStamina then Sprinting.MaxStamina = PS.MaxStamina end
    if Sprinting.StaminaGain ~= PS.StaminaGain then Sprinting.StaminaGain = PS.StaminaGain end
    if Sprinting.StaminaLoss ~= PS.StaminaLoss then Sprinting.StaminaLoss = PS.StaminaLoss end
    if PS.InfiniteStamina then
        Sprinting.StaminaLossDisabled = true
        Sprinting.Stamina = PS.MaxStamina
    else
        if Sprinting.StaminaLossDisabled == true and not PS.InfiniteStamina then
            Sprinting.StaminaLossDisabled = false
        end
    end
end))

local playerTitle = Instance.new("TextLabel", playerFrame)
playerTitle.Size = UDim2.new(0, 290, 0, 24)
playerTitle.Position = UDim2.new(0, 15, 0, 10)
playerTitle.BackgroundTransparency = 1
playerTitle.Text = "Stamina Controls"
playerTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
playerTitle.Font = Enum.Font.SourceSansBold
playerTitle.TextSize = 15
playerTitle.TextXAlignment = Enum.TextXAlignment.Left

local playerStatus = Instance.new("TextLabel", playerFrame)
playerStatus.Size = UDim2.new(0, 290, 0, 20)
playerStatus.Position = UDim2.new(0, 15, 0, 36)
playerStatus.BackgroundTransparency = 1
playerStatus.Text = Sprinting and "Sprinting module: loaded" or "Sprinting module: not found"
playerStatus.TextColor3 = Sprinting and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 100, 100)
playerStatus.Font = Enum.Font.Code
playerStatus.TextSize = 11
playerStatus.TextXAlignment = Enum.TextXAlignment.Left

createSlider(playerFrame, 65, 100, 1000, PS.MaxStamina, "Max Stamina", function(v)
    PS.MaxStamina = v
    pushToSprinting()
end)
createSlider(playerFrame, 118, 1, 200, PS.StaminaGain, "Stamina Gain", function(v)
    PS.StaminaGain = v
    pushToSprinting()
end)
createSlider(playerFrame, 171, 0, 100, PS.StaminaLoss, "Stamina Loss", function(v)
    PS.StaminaLoss = v
    pushToSprinting()
end)

local infiniteBtn = Instance.new("TextButton", playerFrame)
infiniteBtn.Size = UDim2.new(0, 290, 0, 34)
infiniteBtn.Position = UDim2.new(0, 15, 0, 228)
infiniteBtn.BackgroundColor3 = PS.InfiniteStamina and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
infiniteBtn.TextColor3 = Color3.new(1, 1, 1)
infiniteBtn.Font = Enum.Font.SourceSansBold
infiniteBtn.TextSize = 14
infiniteBtn.Text = PS.InfiniteStamina and "Infinite Stamina: ON" or "Infinite Stamina: OFF"
Instance.new("UICorner", infiniteBtn).CornerRadius = UDim.new(0, 8)
infiniteBtn.MouseButton1Click:Connect(function()
    PS.InfiniteStamina = not PS.InfiniteStamina
    infiniteBtn.Text = PS.InfiniteStamina and "Infinite Stamina: ON" or "Infinite Stamina: OFF"
    infiniteBtn.BackgroundColor3 = PS.InfiniteStamina and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
    pushToSprinting()
end)

local currentStaminaLabel = Instance.new("TextLabel", playerFrame)
currentStaminaLabel.Size = UDim2.new(0, 290, 0, 20)
currentStaminaLabel.Position = UDim2.new(0, 15, 0, 270)
currentStaminaLabel.BackgroundTransparency = 1
currentStaminaLabel.Text = "Current: --"
currentStaminaLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
currentStaminaLabel.Font = Enum.Font.Code
currentStaminaLabel.TextSize = 12
currentStaminaLabel.TextXAlignment = Enum.TextXAlignment.Left

table.insert(allConnections, RunService.Heartbeat:Connect(function()
    if Sprinting and Sprinting.Stamina then
        currentStaminaLabel.Text = string.format("Current: %.1f / %.1f", Sprinting.Stamina, Sprinting.StaminaMax or PS.MaxStamina)
    end
end))

-- ==================== GENERATORS TAB ====================
local GEN = {
    AutoEnabled = false,
    AutoInterval = 3,
    MaxDistance = 15,
    AutoConn = nil,
}

local genSound = Instance.new("Sound")
genSound.SoundId = "rbxassetid://81355841754389"
genSound.Volume = 1
genSound.Parent = screenGui

local function playGenSound()
    pcall(function()
        local s = genSound:Clone()
        s.Parent = screenGui
        s.Volume = 1
        s:Play()
        Debris:AddItem(s, 5)
    end)
end

local function fireGeneratorRemote()
    local lp = Players.LocalPlayer or player
    if not lp or not lp.Character then return false, "No character" end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false, "No HRP" end
    local gen, dist = findNearestGenerator()
    if not gen then return false, "No generator found" end
    if dist > GEN.MaxDistance then return false, string.format("Too far (%.1f > %.1f)", dist, GEN.MaxDistance) end
    local remotes = gen:FindFirstChild("Remotes")
    if not remotes then return false, "No Remotes folder" end
    local remoteEvent = remotes:FindFirstChildOfClass("RemoteEvent")
    if not remoteEvent then return false, "No RemoteEvent" end
    local ok, err = pcall(function() remoteEvent:FireServer() end)
    if not ok then return false, "Fire failed: " .. tostring(err) end
    playGenSound()
    return true, string.format("%s (d=%.1f)", gen.Name, dist)
end

local gy = 10
local genTitle = Instance.new("TextLabel", generatorsFrame)
genTitle.Size = UDim2.new(0, 380, 0, 24)
genTitle.Position = UDim2.new(0, 15, 0, gy)
genTitle.BackgroundTransparency = 1
genTitle.Text = "Generator Controls"
genTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
genTitle.Font = Enum.Font.SourceSansBold
genTitle.TextSize = 15
genTitle.TextXAlignment = Enum.TextXAlignment.Left
gy = gy + 30

local genStatusLabel = Instance.new("TextLabel", generatorsFrame)
genStatusLabel.Size = UDim2.new(0, 380, 0, 45)
genStatusLabel.Position = UDim2.new(0, 15, 0, gy)
genStatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
genStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
genStatusLabel.Font = Enum.Font.Code
genStatusLabel.TextSize = 11
genStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
genStatusLabel.TextWrapped = true
genStatusLabel.Text = "  Scanning..."
Instance.new("UICorner", genStatusLabel).CornerRadius = UDim.new(0, 6)
gy = gy + 55

local plusOneBtn = Instance.new("TextButton", generatorsFrame)
plusOneBtn.Size = UDim2.new(0, 290, 0, 42)
plusOneBtn.Position = UDim2.new(0, 15, 0, gy)
plusOneBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 60)
plusOneBtn.TextColor3 = Color3.new(1, 1, 1)
plusOneBtn.Font = Enum.Font.SourceSansBold
plusOneBtn.TextSize = 14
plusOneBtn.Text = "+1 Level (Fire RemoteEvent)"
Instance.new("UICorner", plusOneBtn).CornerRadius = UDim.new(0, 8)
gy = gy + 52

plusOneBtn.MouseButton1Click:Connect(function()
    local ok, msg = fireGeneratorRemote()
    if ok then genStatusLabel.Text = "  +1 Level: " .. msg
    else genStatusLabel.Text = "  Failed: " .. msg end
end)

local autoBtn = Instance.new("TextButton", generatorsFrame)
autoBtn.Size = UDim2.new(0, 290, 0, 34)
autoBtn.Position = UDim2.new(0, 15, 0, gy)
autoBtn.BackgroundColor3 = GEN.AutoEnabled and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.Font = Enum.Font.SourceSansBold
autoBtn.TextSize = 13
autoBtn.Text = GEN.AutoEnabled and "Auto +1 Level: ON" or "Auto +1 Level: OFF"
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 8)
gy = gy + 42

local function stopAuto()
    if GEN.AutoConn then
        pcall(function() GEN.AutoConn:Disconnect() end)
        GEN.AutoConn = nil
    end
    GEN.AutoEnabled = false
    autoBtn.Text = "Auto +1 Level: OFF"
    autoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
end

local function startAuto()
    if GEN.AutoConn then
        pcall(function() GEN.AutoConn:Disconnect() end)
        GEN.AutoConn = nil
    end
    GEN.AutoEnabled = true
    autoBtn.Text = "Auto +1 Level: ON"
    autoBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    task.spawn(function()
        while GEN.AutoEnabled do
            task.wait(GEN.AutoInterval)
            if not GEN.AutoEnabled then break end
            local ok, msg = fireGeneratorRemote()
            if ok then genStatusLabel.Text = "  Auto +1: " .. msg
            else genStatusLabel.Text = "  Auto skip: " .. msg end
        end
    end)
end

autoBtn.MouseButton1Click:Connect(function()
    if GEN.AutoEnabled then stopAuto() else startAuto() end
end)

createSlider(generatorsFrame, gy, 0.1, 30, GEN.AutoInterval, "Auto Interval (s)", function(v)
    GEN.AutoInterval = v
    if GEN.AutoEnabled then startAuto() end
end)
gy = gy + 60

createSlider(generatorsFrame, gy, 1, 40, GEN.MaxDistance, "Max Distance (studs)", function(v)
    GEN.MaxDistance = v
end)
gy = gy + 60

local genInfoLabel = Instance.new("TextLabel", generatorsFrame)
genInfoLabel.Size = UDim2.new(0, 380, 0, 110)
genInfoLabel.Position = UDim2.new(0, 15, 0, gy)
genInfoLabel.BackgroundTransparency = 1
genInfoLabel.Text = [[ℹ️ +1 Level dispara o RemoteEvent
do gerador mais próximo — o mesmo que o
jogo faz quando você completa um puzzle.

Só funciona se você estiver DENTRO do
Max Distance configurado (padrão 15).

O som toca a cada disparo.]]
genInfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
genInfoLabel.Font = Enum.Font.SourceSans
genInfoLabel.TextSize = 11
genInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
genInfoLabel.TextWrapped = true

table.insert(allConnections, RunService.Heartbeat:Connect(function()
    local gen, dist = findNearestGenerator()
    if gen then
        local progress = gen:FindFirstChild("Progress")
        local pVal = progress and progress.Value or -1
        local completed = gen:GetAttribute("cl_Completed") or 0
        local inRange = dist <= GEN.MaxDistance
        genStatusLabel.TextColor3 = inRange and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 180, 180)
        genStatusLabel.Text = string.format(
            "  %s | d=%.1f\n  Progress: %.1f%% | Level: %d",
            gen.Name, dist, pVal, completed
        )
    else
        genStatusLabel.Text = "  No generator found"
        genStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 180)
    end
end))

-- ==================== HITBOX / AUTOBLOCK SYSTEM ====================
local HB = {
    Enabled = false, Visualize = true, Transparency = 0.9,
    SizeX = 9, SizeY = 8, SizeZ = 13,
    OffsetX = 0, OffsetY = 0, OffsetZ = -3,
    Count = 40, Duration = 0.43,
    Color = Color3.fromRGB(0, 150, 255),
    AutoBlockOnTouch = true,
    DynamicSize = false, DynamicCloseDist = 6, DynamicFarDist = 14,
    DynamicSlowSpeed = 2, DynamicFastSpeed = 12,
    DynamicMinX = 0.85, DynamicMinZ = 0.55,
    AutoApproach = false, AutoApproachMaxDist = 15, AutoApproachSpeed = 22,
    AutoApproachTimeout = 1.0, RotationSpeed = 12,
    AutoParry = false, Aimbot = false, AimbotDuration = 1.0,
    AutoParryMaxDist = 15, RealHitboxTouchRadius = 9.5,
    ParryHardCooldown = 1.5, ParryClickDelay = 0,
}

local killerSpeedEMA = {}
table.insert(allConnections, RunService.Heartbeat:Connect(function()
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return end
    local kf = pf:FindFirstChild("Killers")
    if not kf then return end
    for _, k in ipairs(kf:GetChildren()) do
        if k:IsA("Model") then
            local anchor = getKillerAnchor(k)
            if anchor then
                local v = (anchor.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
                local prev = killerSpeedEMA[k]
                if prev == nil then killerSpeedEMA[k] = v
                else killerSpeedEMA[k] = prev * 0.85 + v * 0.15 end
            end
        end
    end
end))

local hitboxConns = {}
local isHBBlocking = false
local debugLabel = nil
local function dbg(msg)
    print("[Hitbox AB] " .. msg)
    if debugLabel then debugLabel.Text = msg end
end
local function getLocalPlayer() return Players.LocalPlayer or player end
local function isGuest1337()
    local lp = getLocalPlayer()
    if not lp then return false end
    local char = lp.Character
    if not char then return false end
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return false end
    local surv = pf:FindFirstChild("Survivors")
    if not surv then return false end
    for _, m in ipairs(surv:GetChildren()) do
        if m == char then
            if char.Name == "Guest1337" then return true end
            if char:GetAttribute("CharacterName") == "Guest1337" then return true end
            return false
        end
    end
    return false
end
local function getAbilityButton(name)
    local lp = getLocalPlayer()
    if not lp then return nil end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local mainUI = pg:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local ac = mainUI:FindFirstChild("AbilityContainer")
    if not ac then return nil end
    local btn = ac:FindFirstChild(name)
    if btn and btn:IsA("GuiButton") then return btn end
    return nil
end
local function getBlockButton() return getAbilityButton("Block") end
local function getPunchButton() return getAbilityButton("Punch") end
local function isButtonOnCooldown(btn)
    if not btn then return true end
    local cd = btn:FindFirstChild("CooldownTime", true)
    if not cd then return false end
    if not (cd:IsA("TextLabel") or cd:IsA("TextButton") or cd:IsA("TextBox")) then return false end
    local t = (cd.Text or ""):gsub("%s+", "")
    if t:match("%d") then return true end
    return false
end
local function isBlockOnCooldown() return isButtonOnCooldown(getBlockButton()) end
local function isPunchOnCooldown() return isButtonOnCooldown(getPunchButton()) end

local controlsRef = nil
local function getPlayerControls()
    if controlsRef then return controlsRef end
    local lp = getLocalPlayer()
    if not lp then return nil end
    local ps = lp:FindFirstChild("PlayerScripts")
    if not ps then return nil end
    local pm = ps:FindFirstChild("PlayerModule")
    if not pm then return nil end
    local ok, module = pcall(function() return require(pm) end)
    if not ok or not module then return nil end
    local ok2, controls = pcall(function() return module:GetControls() end)
    if ok2 and controls then controlsRef = controls return controls end
    return nil
end
local function disablePlayerControls()
    local c = getPlayerControls()
    if c then pcall(function() c:Disable() end) return true end
    return false
end
local function enablePlayerControls()
    local c = getPlayerControls()
    if c then pcall(function() c:Enable() end) end
end

local function clickButton(button)
    if not button then return false end
    if type(firesignal) == "function" then
        local ok = pcall(firesignal, button.MouseButton1Click)
        if ok then return true end
    end
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        local pos = button.AbsolutePosition + (button.AbsoluteSize / 2)
        pcall(function()
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
        end)
        return true
    end
    pcall(function() button:Activate() end)
    return true
end

local function smoothRotateTo(root, targetPos, dt)
    if not root then return end
    local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    local dir = flatTarget - root.Position
    if dir.Magnitude < 0.05 then return end
    local look = dir.Unit
    local currentLook = root.CFrame.LookVector
    local currentYaw = math.atan2(-currentLook.X, -currentLook.Z)
    local desiredYaw = math.atan2(-look.X, -look.Z)
    local deltaYaw = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
    local maxStep = (HB.RotationSpeed or 12) * dt
    local step = math.clamp(deltaYaw, -maxStep, maxStep)
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, currentYaw + step, 0)
end

local autoApproach = { Active = false, Conn = nil, OriginalSpeed = nil, StartTime = 0 }
local stopAutoApproach

local function startAutoApproach(killer, guestChar, hum, anchor)
    if not HB.AutoApproach then return end
    if autoApproach.Active then return end
    if isBlockOnCooldown() then return end
    local myRoot = guestChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not anchor then return end
    local dist = (anchor.Position - myRoot.Position).Magnitude
    if dist > HB.AutoApproachMaxDist then return end
    autoApproach.Active = true
    autoApproach.OriginalSpeed = hum.WalkSpeed
    autoApproach.StartTime = os.clock()
    hum.WalkSpeed = HB.AutoApproachSpeed
    disablePlayerControls()
    autoApproach.Conn = RunService.Heartbeat:Connect(function(dt)
        if not autoApproach.Active then return end
        if not HB.Enabled then stopAutoApproach() return end
        if not guestChar.Parent then stopAutoApproach() return end
        local h = guestChar:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then stopAutoApproach() return end
        if os.clock() - autoApproach.StartTime > HB.AutoApproachTimeout then stopAutoApproach() return end
        local a = getKillerAnchor(killer)
        if not a then stopAutoApproach() return end
        local myRoot2 = guestChar:FindFirstChild("HumanoidRootPart")
        if not myRoot2 then stopAutoApproach() return end
        smoothRotateTo(myRoot2, a.Position, dt)
        h:MoveTo(a.Position)
        local d = (a.Position - myRoot2.Position) * Vector3.new(1, 0, 1)
        if d.Magnitude > 0.1 then h:Move(d.Unit, false) end
    end)
end

stopAutoApproach = function()
    if not autoApproach.Active then return end
    autoApproach.Active = false
    if autoApproach.Conn then autoApproach.Conn:Disconnect() autoApproach.Conn = nil end
    enablePlayerControls()
    local lp = getLocalPlayer()
    if lp and lp.Character then
        local h = lp.Character:FindFirstChildOfClass("Humanoid")
        if h and autoApproach.OriginalSpeed then h.WalkSpeed = autoApproach.OriginalSpeed end
    end
    autoApproach.OriginalSpeed = nil
end

local aimbot = { Active = false, Conn = nil, Killer = nil, EndTime = 0 }
local stopAimbot

local function startAimbot(killer)
    if not HB.Aimbot then return end
    if not killer then return end
    aimbot.Active = true
    aimbot.Killer = killer
    aimbot.EndTime = os.clock() + HB.AimbotDuration
    if aimbot.Conn then aimbot.Conn:Disconnect() end
    aimbot.Conn = RunService.Heartbeat:Connect(function(dt)
        if not aimbot.Active then return end
        if os.clock() > aimbot.EndTime then stopAimbot() return end
        if not HB.Enabled then stopAimbot() return end
        local lp = getLocalPlayer()
        if not lp or not lp.Character then stopAimbot() return end
        local root = lp.Character:FindFirstChild("HumanoidRootPart")
        if not root then stopAimbot() return end
        local a = getKillerAnchor(killer)
        if not a then stopAimbot() return end
        smoothRotateTo(root, a.Position, dt)
    end)
end
stopAimbot = function()
    if not aimbot.Active then return end
    aimbot.Active = false
    if aimbot.Conn then aimbot.Conn:Disconnect() aimbot.Conn = nil end
    aimbot.Killer = nil
end

local function triggerAutoParry(killer)
    if not (HB.AutoParry or HB.Aimbot) then return end
    if not killer or not killer.Parent then return end
    local lp = getLocalPlayer()
    if not lp or not lp.Character then return end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local a = getKillerAnchor(killer)
    if not a then return end
    if (a.Position - root.Position).Magnitude > HB.AutoParryMaxDist then return end
    local punchBtn = getPunchButton()
    if not punchBtn then return end
    if isPunchOnCooldown() then return end
    if HB.Aimbot then startAimbot(killer) end
    if HB.AutoParry then
        local delayTime = HB.ParryClickDelay or 0
        if delayTime > 0 then
            task.delay(delayTime, function()
                if not HB.Enabled or not killer or not killer.Parent then return end
                local btn = getPunchButton()
                if btn and not isPunchOnCooldown() then clickButton(btn) end
            end)
        else
            clickButton(punchBtn)
        end
    end
end

local parryHitboxConn = nil
local lastParryFire = 0
local parryLocked = false
local function onRealHitboxAdded(hitboxPart)
    if not HB.Enabled or not (HB.AutoParry or HB.Aimbot) then return end
    if not hitboxPart:IsA("BasePart") then return end
    if parryLocked then return end
    if os.clock() - lastParryFire < HB.ParryHardCooldown then return end
    task.wait()
    if not hitboxPart.Parent or not HB.Enabled or parryLocked then return end
    if os.clock() - lastParryFire < HB.ParryHardCooldown then return end
    local lp = getLocalPlayer()
    if not lp or not lp.Character then return end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if string.find(hitboxPart.Name, "Guest1337_ABHitbox", 1, true) then return end
    local dist = (hitboxPart.Position - root.Position).Magnitude
    if dist > HB.RealHitboxTouchRadius then return end
    local killer = findNearestKiller(root.Position, HB.AutoParryMaxDist)
    if not killer then return end
    parryLocked = true
    lastParryFire = os.clock()
    triggerAutoParry(killer)
    task.delay(HB.ParryHardCooldown, function() parryLocked = false end)
end

local function startParryMonitor()
    if parryHitboxConn then parryHitboxConn:Disconnect() end
    local folder = Workspace:FindFirstChild("Hitboxes") or Workspace:WaitForChild("Hitboxes", 5)
    if not folder then return end
    parryHitboxConn = folder.ChildAdded:Connect(onRealHitboxAdded)
    parryLocked = false
    lastParryFire = 0
end
local function stopParryMonitor()
    if parryHitboxConn then parryHitboxConn:Disconnect() parryHitboxConn = nil end
    parryLocked = false
end

local function computeDynamicScale(killer)
    if not HB.DynamicSize then return {x = 1, y = 1, z = 1} end
    local lp = getLocalPlayer()
    if not lp or not lp.Character then return {x = 1, y = 1, z = 1} end
    local root = lp.Character:FindFirstChild("HumanoidRootPart")
    local anchor = getKillerAnchor(killer)
    if not root or not anchor then return {x = 1, y = 1, z = 1} end
    local dist = (anchor.Position - root.Position).Magnitude
    local distFactor
    if dist <= HB.DynamicCloseDist then distFactor = 0
    elseif dist >= HB.DynamicFarDist then distFactor = 1
    else distFactor = (dist - HB.DynamicCloseDist) / (HB.DynamicFarDist - HB.DynamicCloseDist) end
    local vel = killerSpeedEMA[killer] or 0
    local speedFactor
    if vel <= HB.DynamicSlowSpeed then speedFactor = 0
    elseif vel >= HB.DynamicFastSpeed then speedFactor = 1
    else speedFactor = (vel - HB.DynamicSlowSpeed) / (HB.DynamicFastSpeed - HB.DynamicSlowSpeed) end
    local factor = math.clamp(math.max(distFactor, speedFactor), 0, 1)
    return {
        x = HB.DynamicMinX + (1 - HB.DynamicMinX) * factor,
        y = 1,
        z = HB.DynamicMinZ + (1 - HB.DynamicMinZ) * factor,
    }
end

local function spawnOneHitbox(killer)
    local anchor = getKillerAnchor(killer)
    if not anchor then return nil end
    local s = computeDynamicScale(killer)
    local part = Instance.new("Part")
    part.Name = "Guest1337_ABHitbox"
    part.Size = Vector3.new(HB.SizeX * s.x, HB.SizeY * s.y, HB.SizeZ * s.z)
    part.CFrame = anchor.CFrame * CFrame.new(HB.OffsetX * s.x, HB.OffsetY * s.y, HB.OffsetZ * s.z)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.ForceField
    part.Shape = Enum.PartType.Block
    part.Color = HB.Color
    part.Transparency = HB.Visualize and HB.Transparency or 1
    part.Parent = Workspace
    Debris:AddItem(part, math.max(0.3, HB.Duration + 0.1))
    return part
end

local function guestInsideHitbox(hitboxPart, guestChar)
    if not hitboxPart or not guestChar then return false end
    local root = guestChar:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local maxDim = math.max(hitboxPart.Size.X, hitboxPart.Size.Y, hitboxPart.Size.Z) / 2
    return (hitboxPart.Position - root.Position).Magnitude <= maxDim + 3
end

local function executarAutoBlock(killer)
    local blockBtn = getBlockButton()
    if not blockBtn then return end
    clickButton(blockBtn)
end

local function iniciarHitboxAutoBlock(killer, animName)
    if not HB.Enabled or isHBBlocking then return end
    if not killer or not killer.Parent then return end
    local anchor = getKillerAnchor(killer)
    if not anchor then return end
    local lp = getLocalPlayer()
    if not lp or not lp.Character then return end
    local guestChar = lp.Character
    local hum = guestChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local root = guestChar:FindFirstChild("HumanoidRootPart")
    if root and (anchor.Position - root.Position).Magnitude > 40 then return end
    isHBBlocking = true
    task.spawn(function()
        local count = math.max(1, math.floor(HB.Count))
        local duration = math.max(0.05, HB.Duration)
        local interval = duration / count
        for i = 1, count do
            if not HB.Enabled or not killer or not killer.Parent then break end
            if not getKillerAnchor(killer) or not guestChar.Parent then break end
            local hb = spawnOneHitbox(killer)
            if hb and HB.AutoBlockOnTouch and guestInsideHitbox(hb, guestChar) then
                if isBlockOnCooldown() then break end
                if HB.AutoApproach then startAutoApproach(killer, guestChar, hum, anchor) end
                executarAutoBlock(killer)
                break
            end
            task.wait(interval)
        end
        isHBBlocking = false
    end)
end

local animConns = {}
local function attachKiller(k)
    if animConns[k] then return end
    local h = k:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local a = h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator", 5)
    if not a then return end
    animConns[k] = a.AnimationPlayed:Connect(function(track)
        if not HB.Enabled then return end
        local matched = isAttackAnim(track)
        if matched then iniciarHitboxAutoBlock(k) end
    end)
end
local function attachAll()
    local pf = Workspace:FindFirstChild("Players")
    if not pf then return end
    local kf = pf:FindFirstChild("Killers")
    if not kf then return end
    for _, k in ipairs(kf:GetChildren()) do if k:IsA("Model") then attachKiller(k) end end
    table.insert(hitboxConns, kf.ChildAdded:Connect(function(k)
        if k:IsA("Model") and HB.Enabled then attachKiller(k) end
    end))
end
local function startHitboxSystem()
    if not isGuest1337() then return false, "You are not Guest1337" end
    if not getBlockButton() then return false, "Block button not found" end
    for _, c in pairs(animConns) do if c and c.Connected then c:Disconnect() end end
    table.clear(animConns)
    for _, c in ipairs(hitboxConns) do if c and c.Connected then c:Disconnect() end end
    table.clear(hitboxConns)
    attachAll()
    startParryMonitor()
    return true
end
local function stopHitboxSystem()
    for _, c in pairs(animConns) do if c and c.Connected then c:Disconnect() end end
    table.clear(animConns)
    for _, c in ipairs(hitboxConns) do if c and c.Connected then c:Disconnect() end end
    table.clear(hitboxConns)
    isHBBlocking = false
    stopParryMonitor()
    stopAutoApproach()
    stopAimbot()
end

task.spawn(function()
    local lp = getLocalPlayer()
    if not lp then repeat task.wait(0.1) lp = getLocalPlayer() until lp end
    table.insert(allConnections, lp.CharacterAdded:Connect(function()
        if HB.Enabled then
            task.wait(1)
            if HB.Enabled and isGuest1337() then
                attachAll()
                startParryMonitor()
            end
        end
        task.wait(0.5)
        pushToSprinting()
    end))
end)

-- ==================== AUTOBLOCK TAB UI ====================
local y = 10
local function addLabel(text, yy)
    local l = Instance.new("TextLabel", hitboxFrame)
    l.Size = UDim2.new(0, 130, 0, 30)
    l.Position = UDim2.new(0, 15, 0, yy)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.Font = Enum.Font.SourceSansBold
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end
local function addInput(default, yy, onApply)
    local b = Instance.new("TextBox", hitboxFrame)
    b.Size = UDim2.new(0, 150, 0, 28)
    b.Position = UDim2.new(0, 155, 0, yy + 1)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSans
    b.TextSize = 14
    b.Text = tostring(default)
    b.ClearTextOnFocus = false
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.FocusLost:Connect(function() if onApply then onApply(b.Text) end end)
    return b
end
local function addToggle(text, yy, initial, onClick)
    local b = Instance.new("TextButton", hitboxFrame)
    b.Size = UDim2.new(0, 290, 0, 30)
    b.Position = UDim2.new(0, 15, 0, yy)
    b.BackgroundColor3 = initial and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 13
    b.Text = text .. ": " .. (initial and "ON" or "OFF")
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function()
        local new = not (b.Text:find(": ON") ~= nil)
        b.Text = text .. ": " .. (new and "ON" or "OFF")
        b.BackgroundColor3 = new and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
        if onClick then onClick(new) end
    end)
    return b
end

debugLabel = Instance.new("TextLabel", hitboxFrame)
debugLabel.Size = UDim2.new(0, 290, 0, 22)
debugLabel.Position = UDim2.new(0, 15, 0, y)
debugLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
debugLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
debugLabel.Font = Enum.Font.Code
debugLabel.TextSize = 11
debugLabel.Text = "Waiting..."
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", debugLabel).CornerRadius = UDim.new(0, 4)
y = y + 30

local hitboxToggleBtn = Instance.new("TextButton", hitboxFrame)
hitboxToggleBtn.Size = UDim2.new(0, 290, 0, 40)
hitboxToggleBtn.Position = UDim2.new(0, 15, 0, y)
hitboxToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
hitboxToggleBtn.TextColor3 = Color3.new(1, 1, 1)
hitboxToggleBtn.Font = Enum.Font.SourceSansBold
hitboxToggleBtn.TextSize = 14
hitboxToggleBtn.Text = "Auto Block (Hitbox): Disabled"
Instance.new("UICorner", hitboxToggleBtn).CornerRadius = UDim.new(0, 10)
y = y + 50

hitboxToggleBtn.MouseButton1Click:Connect(function()
    if not HB.Enabled then
        HB.Enabled = true
        local ok, err = startHitboxSystem()
        if ok then
            hitboxToggleBtn.Text = "Auto Block (Hitbox): Enabled"
            hitboxToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
        else
            HB.Enabled = false
            hitboxToggleBtn.Text = "Failed: " .. (err or "?")
            task.delay(2.5, function() hitboxToggleBtn.Text = "Auto Block (Hitbox): Disabled" end)
        end
    else
        HB.Enabled = false
        stopHitboxSystem()
        hitboxToggleBtn.Text = "Auto Block (Hitbox): Disabled"
        hitboxToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end)

addToggle("Show Hitbox", y, HB.Visualize, function(v) HB.Visualize = v end); y = y + 35
addToggle("Auto Block on Touch", y, HB.AutoBlockOnTouch, function(v) HB.AutoBlockOnTouch = v end); y = y + 35
addToggle("Dynamic Size", y, HB.DynamicSize, function(v) HB.DynamicSize = v end); y = y + 35
addToggle("Auto Approach", y, HB.AutoApproach, function(v) HB.AutoApproach = v end); y = y + 35
addToggle("Aimbot", y, HB.Aimbot, function(v) HB.Aimbot = v end); y = y + 35
addToggle("Auto Parry (Punch)", y, HB.AutoParry, function(v) HB.AutoParry = v end); y = y + 45

addLabel("Transparency", y); addInput(HB.Transparency, y, function(t) local v = tonumber(t) if v then HB.Transparency = math.clamp(v, 0, 1) end end); y = y + 35
addLabel("Size X", y); addInput(HB.SizeX, y, function(t) local v = tonumber(t) if v then HB.SizeX = v end end); y = y + 35
addLabel("Size Y", y); addInput(HB.SizeY, y, function(t) local v = tonumber(t) if v then HB.SizeY = v end end); y = y + 35
addLabel("Size Z", y); addInput(HB.SizeZ, y, function(t) local v = tonumber(t) if v then HB.SizeZ = v end end); y = y + 40
addLabel("Offset X", y); addInput(HB.OffsetX, y, function(t) local v = tonumber(t) if v then HB.OffsetX = v end end); y = y + 35
addLabel("Offset Y", y); addInput(HB.OffsetY, y, function(t) local v = tonumber(t) if v then HB.OffsetY = v end end); y = y + 35
addLabel("Offset Z", y); addInput(HB.OffsetZ, y, function(t) local v = tonumber(t) if v then HB.OffsetZ = v end end); y = y + 40
addLabel("Hitbox Count", y); addInput(HB.Count, y, function(t) local v = tonumber(t) if v then HB.Count = math.clamp(math.floor(v), 1, 500) end end); y = y + 35
addLabel("Duration (s)", y); addInput(HB.Duration, y, function(t) local v = tonumber(t) if v then HB.Duration = math.clamp(v, 0.05, 5) end end); y = y + 40

addLabel("Dyn. Close Dist", y); addInput(HB.DynamicCloseDist, y, function(t) local v = tonumber(t) if v then HB.DynamicCloseDist = math.clamp(v, 1, 100) end end); y = y + 35
addLabel("Dyn. Far Dist", y); addInput(HB.DynamicFarDist, y, function(t) local v = tonumber(t) if v then HB.DynamicFarDist = math.clamp(v, 1, 200) end end); y = y + 35
addLabel("Dyn. Slow Speed", y); addInput(HB.DynamicSlowSpeed, y, function(t) local v = tonumber(t) if v then HB.DynamicSlowSpeed = math.clamp(v, 0, 100) end end); y = y + 35
addLabel("Dyn. Fast Speed", y); addInput(HB.DynamicFastSpeed, y, function(t) local v = tonumber(t) if v then HB.DynamicFastSpeed = math.clamp(v, 0.1, 200) end end); y = y + 35
addLabel("Dyn. Min X", y); addInput(HB.DynamicMinX, y, function(t) local v = tonumber(t) if v then HB.DynamicMinX = math.clamp(v, 0.1, 1) end end); y = y + 35
addLabel("Dyn. Min Z", y); addInput(HB.DynamicMinZ, y, function(t) local v = tonumber(t) if v then HB.DynamicMinZ = math.clamp(v, 0.1, 1) end end); y = y + 40

addLabel("AA Max Dist", y); addInput(HB.AutoApproachMaxDist, y, function(t) local v = tonumber(t) if v then HB.AutoApproachMaxDist = math.clamp(v, 1, 100) end end); y = y + 35
addLabel("AA Speed", y); addInput(HB.AutoApproachSpeed, y, function(t) local v = tonumber(t) if v then HB.AutoApproachSpeed = math.clamp(v, 4, 100) end end); y = y + 35
addLabel("AA Timeout (s)", y); addInput(HB.AutoApproachTimeout, y, function(t) local v = tonumber(t) if v then HB.AutoApproachTimeout = math.clamp(v, 0.1, 5) end end); y = y + 40

addLabel("Rotation Speed", y); addInput(HB.RotationSpeed, y, function(t) local v = tonumber(t) if v then HB.RotationSpeed = math.clamp(v, 1, 60) end end); y = y + 35
addLabel("Aimbot Duration", y); addInput(HB.AimbotDuration, y, function(t) local v = tonumber(t) if v then HB.AimbotDuration = math.clamp(v, 0.1, 5) end end); y = y + 35
addLabel("Parry Max Dist", y); addInput(HB.AutoParryMaxDist, y, function(t) local v = tonumber(t) if v then HB.AutoParryMaxDist = math.clamp(v, 1, 100) end end); y = y + 35
addLabel("Hitbox Touch Radius", y); addInput(HB.RealHitboxTouchRadius, y, function(t) local v = tonumber(t) if v then HB.RealHitboxTouchRadius = math.clamp(v, 1, 30) end end); y = y + 35
addLabel("Parry Hard Cooldown", y); addInput(HB.ParryHardCooldown, y, function(t) local v = tonumber(t) if v then HB.ParryHardCooldown = math.clamp(v, 0.3, 5) end end); y = y + 35
addLabel("Parry Click Delay", y); addInput(HB.ParryClickDelay, y, function(t) local v = tonumber(t) if v then HB.ParryClickDelay = math.clamp(v, 0, 3) end end); y = y + 40

local presetTitle = Instance.new("TextLabel", hitboxFrame)
presetTitle.Size = UDim2.new(0, 290, 0, 25)
presetTitle.Position = UDim2.new(0, 15, 0, y)
presetTitle.BackgroundTransparency = 1
presetTitle.Text = "Color Presets:"
presetTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
presetTitle.Font = Enum.Font.SourceSansBold
presetTitle.TextSize = 13
presetTitle.TextXAlignment = Enum.TextXAlignment.Left
y = y + 25

local function makeColorBtn(color, xPos, name)
    local b = Instance.new("TextButton", hitboxFrame)
    b.Size = UDim2.new(0, 90, 0, 28)
    b.Position = UDim2.new(0, xPos, 0, y)
    b.BackgroundColor3 = color
    b.Text = name
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() HB.Color = color end)
end
makeColorBtn(Color3.fromRGB(0, 150, 255), 15, "Blue")
makeColorBtn(Color3.fromRGB(255, 50, 50), 110, "Red")
makeColorBtn(Color3.fromRGB(50, 255, 50), 205, "Green")
y = y + 35
makeColorBtn(Color3.fromRGB(180, 0, 255), 15, "Purple")
y = y + 35

hitboxFrame.CanvasSize = UDim2.new(0, 0, 0, y + 20)

-- ==================== SETTINGS TAB ====================
local keybindButton = Instance.new("TextButton", settingsFrame)
keybindButton.Size = UDim2.new(0, 250, 0, 40)
keybindButton.Position = UDim2.new(0, 20, 0, 20)
keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
keybindButton.TextColor3 = Color3.new(1, 1, 1)
keybindButton.Font = Enum.Font.SourceSansBold
keybindButton.TextSize = 18
keybindButton.Text = "Toggle Key: H"
Instance.new("UICorner", keybindButton).CornerRadius = UDim.new(0, 10)
keybindButton.MouseButton1Click:Connect(function()
    isSelectingKey = true
    keybindButton.Text = "Press any key..."
end)

table.insert(allConnections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if isSelectingKey and input.UserInputType == Enum.UserInputType.Keyboard then
        currentKey = input.KeyCode
        isSelectingKey = false
        keybindButton.Text = "Toggle Key: " .. currentKey.Name
    elseif input.KeyCode == currentKey and not isSelectingKey then
        toggleGUI()
    end
end))

-- ==================== DESTROY ====================
local function destroyScript()
    ESP.Players.Enabled = false
    ESP.Killers.Enabled = false
    ESP.Generators.Enabled = false
    ESP.Items.Enabled = false
    stopPlayersESP()
    stopKillersESP()
    stopGeneratorsESP()
    stopItemsESP()
    restoreCursorEnabled = false
    stopCursorRestoration()
    HB.Enabled = false
    stopHitboxSystem()
    stopAutoApproach()
    stopAimbot()
    stopParryMonitor()
    stopAuto()
    for _, c in ipairs(allConnections) do if c and c.Connected then c:Disconnect() end end
    table.clear(allConnections)
    if screenGui then screenGui:Destroy() end
end
closeButton.MouseButton1Click:Connect(destroyScript)

print("[Forsaken] Hub + ESP (optimized) + AutoBlock + Player + Generators loaded!")
