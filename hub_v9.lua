-- ============================================================
-- apolo Hub  v1 (Auto-save button positions + all visuals)
-- Protection -> Visuals: ESP Players, Custom FOV
-- Auto Steal, Infinite Jump, Anti Ragdoll ON by default
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _isfile = isfile or (syn and syn.isfile) or (getgenv and getgenv().isfile) or function() return false end
local _readfile = readfile or (syn and syn.readfile) or (getgenv and getgenv().readfile) or function() return nil end
local _writefile = writefile or (syn and syn.writefile) or (getgenv and getgenv().writefile) or function() end
local getconnections = getconnections or get_signal_cons or getconnects or (syn and syn.get_signal_cons)

-- ============================================================
-- STATE
-- ============================================================
local State = {
    normalSpeed = 55, carrySpeed = 28, laggerSpeed = 20.1,
    speedToggled = false, laggerEnabled = false,
    infJumpEnabled = true,
    antiRagdollEnabled = true,
    fpsBoostEnabled = false,
    guiVisible = true, uiLocked = false,
    isStealing = false,
    autoLeftEnabled = false, autoRightEnabled = false,
    autoLeftPhase = 1, autoRightPhase = 1,
    medusaLastUsed = 0, medusaDebounce = false, medusaCounterEnabled = false,
    batAimbotToggled = false, autoSwingEnabled = false,
    hittingCooldown = false,
    batCounterEnabled = false, batCounterDebounce = false,
    batAimbotSpeed = 52,
    dropEnabled = false, _tpInProgress = false,
    lastMoveDir = Vector3.new(0, 0, 0),
    stackButtonsHidden = false,
    stackButtonScale = 1,
    _prevCarry = 30, _prevSpeed = false,
    autoTPDownEnabled = false,
    -- Auto Medusa
    autoMedusaEnabled = false,
    medusaRange = 10,
    medusaCooldown = 0.12,
    medusaAttacking = false,
    -- ESP
    espEnabled = false, unwalkEnabled = false,
    -- Custom FOV
    customFOVEnabled = false,
    originalFOV = Camera.FieldOfView,
}

local Keys = {
    speed = Enum.KeyCode.Q, guiHide = Enum.KeyCode.LeftControl,
    autoLeft = Enum.KeyCode.L, autoRight = Enum.KeyCode.R,
    lagger = Enum.KeyCode.Unknown, tpDown = Enum.KeyCode.Unknown,
    drop = Enum.KeyCode.H, aimbot = Enum.KeyCode.Unknown,
}

-- ============================================================
-- DEFAULT STACK BUTTON POSITIONS
-- ============================================================
local BTN_W = 64
local BTN_H = 54
local BTN_GAP = 5
local COLS = 2
local stackDefs = {
    { key = "autoLeft", label = "AUTO\nLEFT" },
    { key = "autoRight", label = "AUTO\nRIGHT" },
    { key = "aimbot", label = "AUTO\nBAT" },
    { key = "lagger", label = "LAGGER\nMODE" },
    { key = "drop", label = "DROP\nBR" },
    { key = "autoTPDown", label = "AUTO\nTP D" },
    { key = "carrySpeed", label = "CARRY\nSPEED" },
}
local GRID_W = COLS * (BTN_W + BTN_GAP) - BTN_GAP
local GRID_H = math.ceil(#stackDefs / COLS) * (BTN_H + BTN_GAP) - BTN_GAP

local function getDefaultStackPos(i)
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    return UDim2.new(1, -(GRID_W + 14) + col * (BTN_W + BTN_GAP), 0.5, -(GRID_H / 2) + row * (BTN_H + BTN_GAP))
end

-- Will store button positions for saving
local buttonPositions = {}  -- key -> UDim2

local function saveButtonPositions()
    for key, frame in pairs(stackWrappers) do
        if frame and frame.Position then
            local pos = frame.Position
            buttonPositions[key] = { XScale = pos.X.Scale, XOffset = pos.X.Offset, YScale = pos.Y.Scale, YOffset = pos.Y.Offset }
        end
    end
    pcall(saveConfig)  -- trigger full config save
end

local saveDebounce = nil
local function debouncedSaveButtonPositions()
    if saveDebounce then saveDebounce:Disconnect() end
    saveDebounce = task.delay(0.3, function()
        saveButtonPositions()
        saveDebounce = nil
    end)
end

-- ============================================================
-- AUTO STEAL SYSTEM (unchanged)
-- ============================================================
local AutoSteal = {
    Enabled = false,
    StealRadius = 59,
    StealDuration = 1.3,
    isStealing = false,
    StealData = {},
    screenGui = nil,
    barContainer = nil,
    progressBar = nil,
    statusLabel = nil,
    heartbeatConn = nil,
    progressConn = nil,
    scanTimer = 0,
    SCAN_INTERVAL = 0.15,
    cachedPrompts = {},
    lastFullScan = 0,
    FULL_SCAN_INTERVAL = 3,
}

local STEAL_COLORS = {
    Border = Color3.fromRGB(140, 80, 255), -- Roxo
    Progress = Color3.fromRGB(140, 80, 255), -- Roxo
}

local function createStealUI()
    if AutoSteal.screenGui then return end
    AutoSteal.screenGui = Instance.new("ScreenGui")
    AutoSteal.screenGui.Name = "ApoloStealProgress"
    AutoSteal.screenGui.ResetOnSpawn = false
    AutoSteal.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AutoSteal.screenGui.Parent = LP:WaitForChild("PlayerGui")

    AutoSteal.barContainer = Instance.new("Frame")
    AutoSteal.barContainer.Size = UDim2.new(0, 200, 0, 28)
    AutoSteal.barContainer.Position = UDim2.new(0.5, -100, 0.08, 0)
    AutoSteal.barContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    AutoSteal.barContainer.BackgroundTransparency = 0.2
    AutoSteal.barContainer.BorderSizePixel = 0
    AutoSteal.barContainer.Parent = AutoSteal.screenGui
    AutoSteal.barContainer.Visible = false

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 14)
    containerCorner.Parent = AutoSteal.barContainer
    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = STEAL_COLORS.Border
    containerStroke.Thickness = 1.5
    containerStroke.Transparency = 0.7
    containerStroke.Parent = AutoSteal.barContainer

    local barBackground = Instance.new("Frame")
    barBackground.Size = UDim2.new(1, -8, 1, -8)
    barBackground.Position = UDim2.new(0, 4, 0, 4)
    barBackground.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    barBackground.BackgroundTransparency = 0.3
    barBackground.BorderSizePixel = 0
    barBackground.Parent = AutoSteal.barContainer
    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 10)
    barBgCorner.Parent = barBackground

    AutoSteal.progressBar = Instance.new("Frame")
    AutoSteal.progressBar.Size = UDim2.new(0, 0, 1, 0)
    AutoSteal.progressBar.BackgroundColor3 = STEAL_COLORS.Progress
    AutoSteal.progressBar.BorderSizePixel = 0
    AutoSteal.progressBar.Parent = barBackground
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 10)
    barCorner.Parent = AutoSteal.progressBar

    AutoSteal.statusLabel = Instance.new("TextLabel")
    AutoSteal.statusLabel.Size = UDim2.new(1, -16, 1, 0)
    AutoSteal.statusLabel.Position = UDim2.new(0, 8, 0, 0)
    AutoSteal.statusLabel.BackgroundTransparency = 1
    AutoSteal.statusLabel.Text = "READY"
    AutoSteal.statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    AutoSteal.statusLabel.TextSize = 11
    AutoSteal.statusLabel.Font = Enum.Font.GothamBold
    AutoSteal.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    AutoSteal.statusLabel.Parent = AutoSteal.barContainer
end

local function getHRP()
    local c = LP.Character
    if c then
        return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
    end
    return nil
end

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then
            return yb.Enabled == true
        end
    end
    return false
end

local function refreshPromptCache()
    local now = tick()
    if now - AutoSteal.lastFullScan < AutoSteal.FULL_SCAN_INTERVAL and #AutoSteal.cachedPrompts > 0 then
        return
    end
    AutoSteal.lastFullScan = now
    AutoSteal.cachedPrompts = {}

    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            local base = pod:FindFirstChild("Base")
            if not base then continue end
            local spawn = base:FindFirstChild("Spawn")
            if not spawn then continue end
            local att = spawn:FindFirstChild("PromptAttachment")
            if att then
                for _, p in ipairs(att:GetChildren()) do
                    if p:IsA("ProximityPrompt") then
                        table.insert(AutoSteal.cachedPrompts, {
                            prompt = p,
                            spawnPos = spawn.Position
                        })
                        break
                    end
                end
            end
        end
    end
end

local function findNearestPrompt()
    local hrp = getHRP()
    if not hrp then return nil end
    refreshPromptCache()
    local nearest, nearestDist = nil, AutoSteal.StealRadius + 1
    for _, data in ipairs(AutoSteal.cachedPrompts) do
        local dist = (data.spawnPos - hrp.Position).Magnitude
        if dist <= AutoSteal.StealRadius and dist < nearestDist then
            nearestDist = dist
            nearest = data.prompt
        end
    end
    return nearest
end

local function updateProgress()
    if not AutoSteal.isStealing then return end
    local startTime = tick()
    local duration = AutoSteal.StealDuration
    if AutoSteal.statusLabel then AutoSteal.statusLabel.Text = "STEALING" end
    if AutoSteal.progressBar then AutoSteal.progressBar.Size = UDim2.new(0, 0, 1, 0) end
    if AutoSteal.progressConn then AutoSteal.progressConn:Disconnect() end
    AutoSteal.progressConn = RunService.Heartbeat:Connect(function()
        if not AutoSteal.isStealing then
            if AutoSteal.progressConn then AutoSteal.progressConn:Disconnect() end
            AutoSteal.progressConn = nil
            return
        end
        local elapsed = tick() - startTime
        local progress = math.min(elapsed / duration, 1)
        if AutoSteal.progressBar then AutoSteal.progressBar.Size = UDim2.new(progress, 0, 1, 0) end
        if progress >= 1 then
            if AutoSteal.progressConn then AutoSteal.progressConn:Disconnect() end
            AutoSteal.progressConn = nil
            if AutoSteal.statusLabel then AutoSteal.statusLabel.Text = "READY" end
        end
    end)
end

local function executeSteal(prompt)
    if AutoSteal.isStealing then return end
    if not AutoSteal.StealData[prompt] then
        AutoSteal.StealData[prompt] = { hold = {}, trigger = {}, ready = true }
        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if c.Function then table.insert(AutoSteal.StealData[prompt].hold, c.Function) end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if c.Function then table.insert(AutoSteal.StealData[prompt].trigger, c.Function) end
            end
        else
            AutoSteal.StealData[prompt].useFallback = true
        end
    end
    local data = AutoSteal.StealData[prompt]
    if not data.ready then return end
    data.ready = false
    AutoSteal.isStealing = true
    if AutoSteal.barContainer then AutoSteal.barContainer.Visible = true end
    updateProgress()
    task.spawn(function()
        local ok = false
        if not data.useFallback then
            pcall(function()
                for _, f in ipairs(data.hold) do task.spawn(f) end
                task.wait(AutoSteal.StealDuration)
                for _, f in ipairs(data.trigger) do task.spawn(f) end
                ok = true
            end)
        end
        if not ok and fireproximityprompt then
            pcall(function() fireproximityprompt(prompt); ok = true end)
        end
        if not ok then
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(AutoSteal.StealDuration)
                prompt:InputHoldEnd()
            end)
        end
        task.wait(0.05)
        if AutoSteal.barContainer then AutoSteal.barContainer.Visible = false end
        if AutoSteal.progressBar then AutoSteal.progressBar.Size = UDim2.new(0, 0, 1, 0) end
        if AutoSteal.statusLabel then AutoSteal.statusLabel.Text = "READY" end
        data.ready = true
        AutoSteal.isStealing = false
    end)
end

local function enableAutoSteal()
    if AutoSteal.Enabled then return end
    AutoSteal.Enabled = true
    if not AutoSteal.screenGui then createStealUI() end
    if AutoSteal.screenGui then AutoSteal.screenGui.Enabled = true end
    LP.CharacterAdded:Connect(function() AutoSteal.isStealing = false end)
    local lastScan = 0
    AutoSteal.heartbeatConn = RunService.Heartbeat:Connect(function()
        if not AutoSteal.Enabled then return end
        if AutoSteal.isStealing then return end
        local now = tick()
        if now - lastScan < AutoSteal.SCAN_INTERVAL then return end
        lastScan = now
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then pcall(executeSteal, prompt) end
    end)
end

local function disableAutoSteal()
    if not AutoSteal.Enabled then return end
    AutoSteal.Enabled = false
    if AutoSteal.screenGui then AutoSteal.screenGui.Enabled = false end
    if AutoSteal.heartbeatConn then AutoSteal.heartbeatConn:Disconnect(); AutoSteal.heartbeatConn = nil end
    if AutoSteal.progressConn then AutoSteal.progressConn:Disconnect(); AutoSteal.progressConn = nil end
    AutoSteal.isStealing = false
end

-- ============================================================
-- AUTO TP DOWN
-- ============================================================
local autoTPDownConnection = nil
local GROUND_Y = -8.8
local TP_THRESHOLD = 10

local function startAutoTPDown()
    if autoTPDownConnection then return end
    autoTPDownConnection = RunService.Heartbeat:Connect(function()
        if not State.autoTPDownEnabled then return end
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if hrp.Position.Y >= TP_THRESHOLD then
            hrp.CFrame = CFrame.new(hrp.Position.X, GROUND_Y, hrp.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
        end
    end)
end

local function stopAutoTPDown()
    if autoTPDownConnection then
        autoTPDownConnection:Disconnect()
        autoTPDownConnection = nil
    end
end

-- ============================================================
-- AUTO LEFT / RIGHT (with button reset fix)
-- ============================================================
local POS_LEFT_1 = Vector3.new(-476.48, -6.28, 92.73)
local POS_LEFT_2 = Vector3.new(-483.12, -4.95, 94.80)
local POS_RIGHT_1 = Vector3.new(-476.16, -6.52, 25.62)
local POS_RIGHT_2 = Vector3.new(-483.04, -5.09, 23.14)

local Conns = { autoLeft = nil, autoRight = nil, antiRag = nil, aimbot = nil, anchor = {}, batCounter = nil, autoMedusa = nil }

-- Detect if player is holding brainrot (equipped in hand, not in backpack)
local function isHoldingBrainrot()
    local c = LP.Character
    if not c then return false end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Tool") then
            local n = v.Name:lower()
            if not n:find("bat") and not n:find("medusa") and not n:find("head") and not n:find("stone") then
                return true
            end
        end
    end
    return false
end

local function startAutoLeft()
    if Conns.autoLeft then Conns.autoLeft:Disconnect() end
    State.autoLeftPhase = 1
    Conns.autoLeft = RunService.Heartbeat:Connect(function()
        if not State.autoLeftEnabled then return end
        if isHoldingBrainrot() then return end
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local spd = State.normalSpeed
        if State.autoLeftPhase == 1 then
            local target = Vector3.new(POS_LEFT_1.X, hrp.Position.Y, POS_LEFT_1.Z)
            if (target - hrp.Position).Magnitude < 1 then
                State.autoLeftPhase = 2
                local dir = (POS_LEFT_2 - hrp.Position).Unit
                hum:Move(dir, false)
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
                return
            end
            local dir = (POS_LEFT_1 - hrp.Position).Unit
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
        elseif State.autoLeftPhase == 2 then
            local target = Vector3.new(POS_LEFT_2.X, hrp.Position.Y, POS_LEFT_2.Z)
            if (target - hrp.Position).Magnitude < 1 then
                hum:Move(Vector3.zero, false)
                hrp.AssemblyLinearVelocity = Vector3.zero
                State.autoLeftEnabled = false
                if Conns.autoLeft then Conns.autoLeft:Disconnect(); Conns.autoLeft = nil end
                State.autoLeftPhase = 1
                if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                return
            end
            local dir = (POS_LEFT_2 - hrp.Position).Unit
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
        end
    end)
end

local function stopAutoLeft()
    if Conns.autoLeft then Conns.autoLeft:Disconnect(); Conns.autoLeft = nil end
    State.autoLeftPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    end
    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
end

local function startAutoRight()
    if Conns.autoRight then Conns.autoRight:Disconnect() end
    State.autoRightPhase = 1
    Conns.autoRight = RunService.Heartbeat:Connect(function()
        if not State.autoRightEnabled then return end
        if isHoldingBrainrot() then return end
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local spd = State.normalSpeed
        if State.autoRightPhase == 1 then
            local target = Vector3.new(POS_RIGHT_1.X, hrp.Position.Y, POS_RIGHT_1.Z)
            if (target - hrp.Position).Magnitude < 1 then
                State.autoRightPhase = 2
                local dir = (POS_RIGHT_2 - hrp.Position).Unit
                hum:Move(dir, false)
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
                return
            end
            local dir = (POS_RIGHT_1 - hrp.Position).Unit
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
        elseif State.autoRightPhase == 2 then
            local target = Vector3.new(POS_RIGHT_2.X, hrp.Position.Y, POS_RIGHT_2.Z)
            if (target - hrp.Position).Magnitude < 1 then
                hum:Move(Vector3.zero, false)
                hrp.AssemblyLinearVelocity = Vector3.zero
                State.autoRightEnabled = false
                if Conns.autoRight then Conns.autoRight:Disconnect(); Conns.autoRight = nil end
                State.autoRightPhase = 1
                if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                return
            end
            local dir = (POS_RIGHT_2 - hrp.Position).Unit
            hum:Move(dir, false)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, hrp.AssemblyLinearVelocity.Y, dir.Z * spd)
        end
    end)
end

local function stopAutoRight()
    if Conns.autoRight then Conns.autoRight:Disconnect(); Conns.autoRight = nil end
    State.autoRightPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    end
    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
end

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG_FILE = "ApoloHubConfig.json"
local MOVE_KEYS = {
    [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true
}

local MEDUSA_COOLDOWN = 25
local DROP_AUTO_OFF_DELAY = 0.15

local h, hrp
local setInfJump, setAntiRag, setFps
local setMedusaCounter, setAimbot, setAutoSwing, setAutoMedusa
local setLagger, setDropBrainrot, setInstaGrab, setAutoTPDown
local setupMedusaCounter, stopMedusaCounter, startAntiRagdoll, stopAntiRagdoll
local applyFPSBoost
local startBatAimbot, stopBatAimbot, startBatCounter, stopBatCounter, setBatCounter
local stackBtnRefs = {}
local stackWrappers = {}
local keybindBtnRefs = {}
local normalBox, carryBox, laggerBox, lockBtn
local setHideButtonsToggle

-- ESP references
local espHighlights = {}
local espBillboards = {}
local espConnections = {}
local ESP_COLOR = Color3.fromRGB(120, 50, 200)
local ESP_OUTLINE = Color3.fromRGB(180, 100, 255)

-- Custom FOV toggle function
local function setCustomFOV(enabled)
    if enabled then
        Camera.FieldOfView = 120
    else
        Camera.FieldOfView = State.originalFOV
    end
    State.customFOVEnabled = enabled
end

-- ============================================================
-- COLORS
-- ============================================================
local C = {
    winBg = Color3.fromRGB(18, 12, 30), winBorder = Color3.fromRGB(100, 50, 180),
    topBg = Color3.fromRGB(22, 15, 38), topTitle = Color3.fromRGB(255, 255, 255),
    topSub = Color3.fromRGB(160, 140, 190), topBtn = Color3.fromRGB(160, 140, 190),
    topBtnHov = Color3.fromRGB(200, 180, 230), topDivider = Color3.fromRGB(60, 35, 100),
    tabBarBg = Color3.fromRGB(22, 15, 38), tabBarDiv = Color3.fromRGB(60, 35, 100),
    tabIdle = Color3.fromRGB(140, 120, 170), tabActive = Color3.fromRGB(255, 255, 255),
    tabActiveBg = Color3.fromRGB(80, 40, 140), tabUnderline = Color3.fromRGB(150, 80, 255),
    sectionTxt = Color3.fromRGB(180, 120, 255), sectionDiv = Color3.fromRGB(50, 30, 85),
    rowBg = Color3.fromRGB(25, 18, 42), rowBorder = Color3.fromRGB(55, 35, 90),
    rowLabel = Color3.fromRGB(230, 225, 245), rowSub = Color3.fromRGB(150, 130, 180),
    rowValue = Color3.fromRGB(180, 160, 210), rowHov = Color3.fromRGB(35, 25, 55),
    inputBg = Color3.fromRGB(15, 10, 28), inputBorder = Color3.fromRGB(80, 45, 140),
    inputFocus = Color3.fromRGB(150, 80, 255), inputTxt = Color3.fromRGB(255, 255, 255),
    pillOff = Color3.fromRGB(35, 25, 60), pillOn = Color3.fromRGB(120, 60, 220),
    dotOff = Color3.fromRGB(100, 80, 130), dotOn = Color3.fromRGB(255, 255, 255),
    pillBorder = Color3.fromRGB(70, 40, 120), modeBtnBg = Color3.fromRGB(25, 18, 42),
    modeBtnBrd = Color3.fromRGB(80, 45, 140), modeBtnTxt = Color3.fromRGB(160, 140, 200),
    modeBtnActBg = Color3.fromRGB(110, 55, 200), modeBtnActTx = Color3.fromRGB(255, 255, 255),
    chipBg = Color3.fromRGB(25, 18, 42), chipBorder = Color3.fromRGB(80, 45, 140),
    chipTxt = Color3.fromRGB(160, 140, 200), btnBg = Color3.fromRGB(30, 22, 50),
    btnBorder = Color3.fromRGB(90, 55, 160), btnTxt = Color3.fromRGB(230, 225, 245),
    btnHov = Color3.fromRGB(55, 35, 95), stackBg = Color3.fromRGB(25, 18, 42),
    stackBrd = Color3.fromRGB(90, 55, 160), stackTxt = Color3.fromRGB(170, 145, 220),
    stackActBg = Color3.fromRGB(80, 40, 150), stackActBrd = Color3.fromRGB(150, 90, 255),
    stackActTxt = Color3.fromRGB(240, 230, 255), stackDot = Color3.fromRGB(90, 55, 160),
    stackDotOn = Color3.fromRGB(255, 255, 255), infoBg = Color3.fromRGB(18, 12, 30),
    infoBrd = Color3.fromRGB(60, 35, 100), infoTxt = Color3.fromRGB(150, 130, 180),
    infoVal = Color3.fromRGB(200, 180, 230), infoFill = Color3.fromRGB(110, 55, 200),
    accent = Color3.fromRGB(110, 55, 200), accentDim = Color3.fromRGB(60, 30, 110),
}

-- ============================================================
-- CLEANUP
-- ============================================================
for _, name in pairs({ "VyseSlottedGUI", "VyseAsireGUI", "VyseAsireHubV4", "VyseAsireHubV5", "VyseAsireHubV5_1", "AsireHubV5_1", "AsireHubV5_2", "OpiumGGV5_2", "ZyrielDuels", "ZYRIEL", "ApoloHub" }) do
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(name); if o then o:Destroy() end end)
    pcall(function() local o = LP:WaitForChild("PlayerGui"):FindFirstChild(name); if o then o:Destroy() end end)
end

-- ============================================================
-- ROOT GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "ApoloHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LP:WaitForChild("PlayerGui")

-- ============================================================
-- HELPERS
-- ============================================================
local function mkCorner(p, r) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 6); return c end
local function mkStroke(p, col, th) local s = Instance.new("UIStroke", p); s.Color = col; s.Thickness = th or 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s end

-- ============================================================
-- DRAG (unchanged for main window)
-- ============================================================
local function makeDraggable(frame, handle)
    local src = handle or frame
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    src.InputBegan:Connect(function(inp)
        if State.uiLocked then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = frame.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    src.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then dragInput = inp end
    end)
    UIS.InputChanged:Connect(function(inp)
        if inp == dragInput and dragging and not State.uiLocked then
            local dx = inp.Position.X - dragStart.X
            local dy = inp.Position.Y - dragStart.Y
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dx, startPos.Y.Scale, startPos.Y.Offset + dy)
        end
    end)
end

-- FIXED: makeStackDraggable – freeze only prevents dragging, not clicking; also saves position on move
local function makeStackDraggable(frame, onTap)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local moved = false
    
    local function handleInputBegan(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        moved = false
        dragStart = inp.Position
        startPos = frame.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                if not moved and onTap then onTap() end
                if moved then debouncedSaveButtonPositions() end
                dragging = false
                moved = false
            end
        end)
    end
    
    local function handleInputChanged(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then dragInput = inp end
    end
    
    local function handleGlobalInput(inp)
        if inp ~= dragInput or not dragging then return end
        local dx = inp.Position.X - dragStart.X
        local dy = inp.Position.Y - dragStart.Y
        if math.abs(dx) > 8 or math.abs(dy) > 8 then moved = true end
        if moved and not State.uiLocked then
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + dx, startPos.Y.Scale, startPos.Y.Offset + dy)
        end
    end
    
    frame.InputBegan:Connect(handleInputBegan)
    frame.InputChanged:Connect(handleInputChanged)
    UIS.InputChanged:Connect(handleGlobalInput)
end

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local WIN_W = 320
local WIN_H = 360
local TITLE_H = 42
local TAB_H = 34

local mainOuter = Instance.new("Frame", gui)
mainOuter.Name = "MainOuter"
mainOuter.Size = UDim2.new(0, WIN_W, 0, WIN_H)
mainOuter.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
mainOuter.BackgroundColor3 = C.winBg
mainOuter.BackgroundTransparency = 0.05
mainOuter.BorderSizePixel = 0
mainOuter.ClipsDescendants = true
mkCorner(mainOuter, 14)
mkStroke(mainOuter, C.winBorder, 2.5)
makeDraggable(mainOuter)

local bgOverlay = Instance.new("Frame", mainOuter)
bgOverlay.Size = UDim2.new(1, 0, 1, 0)
bgOverlay.BackgroundColor3 = C.winBg
bgOverlay.BackgroundTransparency = 0.02
bgOverlay.BorderSizePixel = 0
bgOverlay.ZIndex = 1
mkCorner(bgOverlay, 14)

-- Top accent glow line
local accentLine = Instance.new("Frame", mainOuter)
accentLine.Size = UDim2.new(0.7, 0, 0, 2)
accentLine.Position = UDim2.new(0.15, 0, 0, 0)
accentLine.BackgroundColor3 = Color3.fromRGB(150, 80, 255)
accentLine.BackgroundTransparency = 0.3
accentLine.BorderSizePixel = 0
accentLine.ZIndex = 10
mkCorner(accentLine, 1)

-- ============================================================
-- TITLE BAR
-- ============================================================
local titleBar = Instance.new("Frame", mainOuter)
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.topBg
titleBar.BackgroundTransparency = 0
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 5
mkCorner(titleBar, 14)
local titleGrad = Instance.new("UIGradient", titleBar)
titleGrad.Color = ColorSequence.new(Color3.fromRGB(35, 20, 60), Color3.fromRGB(18, 12, 30))
titleGrad.Rotation = 90

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 15, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "apolo Hub"
titleLbl.TextColor3 = C.topTitle
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 15
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextStrokeTransparency = 0.6
titleLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
titleLbl.ZIndex = 6

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -32, 0.5, -11)
closeBtn.BackgroundColor3 = C.modeBtnBg
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = C.topBtn
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 16
closeBtn.ZIndex = 7
mkCorner(closeBtn, 5)
mkStroke(closeBtn, C.chipBorder, 1)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(220, 80, 80) }):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = C.topBtn }):Play() end)
closeBtn.MouseButton1Click:Connect(function() State.guiVisible = false; mainOuter.Visible = false end)

lockBtn = Instance.new("TextButton", titleBar)
lockBtn.Size = UDim2.new(0, 22, 0, 22)
lockBtn.Position = UDim2.new(1, -58, 0.5, -11)
lockBtn.BackgroundColor3 = C.modeBtnBg
lockBtn.BorderSizePixel = 0
lockBtn.Text = "🔓"
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 11
lockBtn.ZIndex = 7
mkCorner(lockBtn, 5)
mkStroke(lockBtn, C.chipBorder, 1)
lockBtn.MouseButton1Click:Connect(function()
    State.uiLocked = not State.uiLocked
    lockBtn.Text = State.uiLocked and "🔒" or "🔓"
end)

local titleDiv = Instance.new("Frame", mainOuter)
titleDiv.Size = UDim2.new(1, 0, 0, 1)
titleDiv.Position = UDim2.new(0, 0, 0, TITLE_H)
titleDiv.BackgroundColor3 = C.topDivider
titleDiv.BorderSizePixel = 0
titleDiv.ZIndex = 5

-- ============================================================
-- TAB BAR
-- ============================================================
local tabBar = Instance.new("Frame", mainOuter)
tabBar.Size = UDim2.new(1, 0, 0, TAB_H)
tabBar.Position = UDim2.new(0, 0, 0, TITLE_H + 1)
tabBar.BackgroundColor3 = C.tabBarBg
tabBar.BackgroundTransparency = 0
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 5

local tabBarLL = Instance.new("UIListLayout", tabBar)
tabBarLL.FillDirection = Enum.FillDirection.Horizontal
tabBarLL.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLL.Padding = UDim.new(0, 0)

local tabDiv = Instance.new("Frame", mainOuter)
tabDiv.Size = UDim2.new(1, 0, 0, 1)
tabDiv.Position = UDim2.new(0, 0, 0, TITLE_H + 1 + TAB_H)
tabDiv.BackgroundColor3 = C.tabBarDiv
tabDiv.BorderSizePixel = 0
tabDiv.ZIndex = 5

-- ============================================================
-- CONTENT AREA
-- ============================================================
local CONTENT_Y = TITLE_H + 1 + TAB_H + 1
local contentBg = Instance.new("Frame", mainOuter)
contentBg.Size = UDim2.new(1, 0, 1, -CONTENT_Y)
contentBg.Position = UDim2.new(0, 0, 0, CONTENT_Y)
contentBg.BackgroundColor3 = C.winBg
contentBg.BackgroundTransparency = 0
contentBg.BorderSizePixel = 0
contentBg.ClipsDescendants = true
contentBg.ZIndex = 2

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local TABS = { "Combat", "Speed", "Visual", "Config" }
local currentTab = "Combat"
local tabBtns = {}
local tabPages = {}

local TAB_COUNT = #TABS
for i, name in ipairs(TABS) do
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(1 / TAB_COUNT, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = (name == currentTab) and 0.85 or 1
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = (name == currentTab) and C.tabActive or C.tabIdle
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextWrapped = false
    btn.TextScaled = false
    btn.ZIndex = 6
    btn.LayoutOrder = i

    local underline = Instance.new("Frame", btn)
    underline.Size = UDim2.new(0.6, 0, 0, 2)
    underline.Position = UDim2.new(0.2, 0, 1, -2)
    underline.BackgroundColor3 = C.tabUnderline
    underline.BorderSizePixel = 0
    underline.Visible = (name == currentTab)
    underline.ZIndex = 7

    tabBtns[name] = { btn = btn, underline = underline }

    btn.MouseEnter:Connect(function()
        if name ~= currentTab then
            TweenService:Create(btn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(170, 170, 170) }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if name ~= currentTab then
            TweenService:Create(btn, TweenInfo.new(0.1), { TextColor3 = C.tabIdle }):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function()
        currentTab = name
        for _, n in ipairs(TABS) do
            local t = tabBtns[n]
            local active = (n == name)
            TweenService:Create(t.btn, TweenInfo.new(0.14), {
                TextColor3 = active and C.tabActive or C.tabIdle,
                BackgroundColor3 = active and C.tabActiveBg or C.tabBarBg,
            }):Play()
            t.underline.Visible = active
            if tabPages[n] then tabPages[n].Visible = active end
        end
    end)
end

-- ============================================================
-- ROW / PAGE BUILDERS
-- ============================================================
local currentPage = nil
local lo = 0
local function LO() lo = lo + 1; return lo end

local function makeGap(px)
    local f = Instance.new("Frame", currentPage)
    f.Size = UDim2.new(1, 0, 0, px or 6)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.LayoutOrder = LO()
end

local function makeSectionHeader(label)
    local wrap = Instance.new("Frame", currentPage)
    wrap.Size = UDim2.new(1, 0, 0, 28)
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel = 0
    wrap.LayoutOrder = LO()
    local lbl = Instance.new("TextLabel", wrap)
    lbl.Size = UDim2.new(1, -28, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label and label:upper() or ""
    lbl.TextColor3 = C.sectionTxt
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function makeInputRow(label, default, onChange)
    local row = Instance.new("Frame", currentPage)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.rowBg
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = LO()

    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -28, 0, 1)
    div.Position = UDim2.new(0, 14, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local boxWrap = Instance.new("Frame", row)
    boxWrap.Size = UDim2.new(0, 70, 0, 28)
    boxWrap.Position = UDim2.new(1, -84, 0.5, -14)
    boxWrap.BackgroundColor3 = C.inputBg
    boxWrap.BorderSizePixel = 0
    mkCorner(boxWrap, 5)
    local bs = mkStroke(boxWrap, C.inputBorder, 1)

    local box = Instance.new("TextBox", boxWrap)
    box.Size = UDim2.new(1, -8, 1, 0)
    box.Position = UDim2.new(0, 4, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = tostring(default)
    box.TextColor3 = C.inputTxt
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.ZIndex = 8
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Focused:Connect(function() TweenService:Create(bs, TweenInfo.new(0.15), { Color = C.inputFocus }):Play() end)
    box.FocusLost:Connect(function()
        TweenService:Create(bs, TweenInfo.new(0.15), { Color = C.inputBorder }):Play()
        if onChange then
            local n = tonumber(box.Text)
            if n then onChange(n) else box.Text = tostring(default) end
        end
    end)
    return box, row
end

local function makeToggleRow(label, defaultOn, onToggle)
    local row = Instance.new("Frame", currentPage)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = LO()

    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -28, 0, 1)
    div.Position = UDim2.new(0, 14, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local pillBg = Instance.new("Frame", row)
    pillBg.Size = UDim2.new(0, 40, 0, 20)
    pillBg.Position = UDim2.new(1, -54, 0.5, -10)
    pillBg.BackgroundColor3 = defaultOn and C.pillOn or C.pillOff
    pillBg.BorderSizePixel = 0
    pillBg.ZIndex = 7
    mkCorner(pillBg, 10)
    mkStroke(pillBg, C.pillBorder, 1)

    local dot = Instance.new("Frame", pillBg)
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = defaultOn and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3 = defaultOn and C.dotOn or C.dotOff
    dot.BorderSizePixel = 0
    dot.ZIndex = 8
    mkCorner(dot, 7)

    local isOn = defaultOn or false
    local function setV(on)
        isOn = on
        TweenService:Create(pillBg, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundColor3 = on and C.pillOn or C.pillOff }):Play()
        TweenService:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
            Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
            BackgroundColor3 = on and C.dotOn or C.dotOff
        }):Play()
    end
    local function toggle()
        isOn = not isOn
        setV(isOn)
        if onToggle then pcall(onToggle, isOn) end
    end

    local clk = Instance.new("TextButton", row)
    clk.Size = UDim2.new(1, -58, 1, 0)
    clk.BackgroundTransparency = 1
    clk.Text = ""
    clk.ZIndex = 5
    clk.BorderSizePixel = 0
    clk.MouseButton1Click:Connect(toggle)
    local pClk = Instance.new("TextButton", pillBg)
    pClk.Size = UDim2.new(1, 0, 1, 0)
    pClk.BackgroundTransparency = 1
    pClk.Text = ""
    pClk.ZIndex = 9
    pClk.BorderSizePixel = 0
    pClk.MouseButton1Click:Connect(toggle)
    return setV
end

-- ============================================================
-- KEYBIND ROW
-- ============================================================
local function getKeyDisplayName(kc)
    local n = kc.Name
    local gpNames = {
        ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
        ButtonL1 = "LB", ButtonL2 = "LT", ButtonL3 = "LS",
        ButtonR1 = "RB", ButtonR2 = "RT", ButtonR3 = "RS",
        ButtonSelect = "SEL", ButtonStart = "STA",
        DPadUp = "D↑", DPadDown = "D↓", DPadLeft = "D←", DPadRight = "D→",
        Thumbstick1 = "LS", Thumbstick2 = "RS",
    }
    if gpNames[n] then return gpNames[n] end
    return n:sub(1, 5)
end

local function makeKeybindRow(label, currentKey, onChanged, keyName)
    local row = Instance.new("Frame", currentPage)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = LO()

    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -28, 0, 1)
    div.Position = UDim2.new(0, 14, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local kbtn = Instance.new("TextButton", row)
    kbtn.Size = UDim2.new(0, 52, 0, 26)
    kbtn.Position = UDim2.new(1, -64, 0.5, -13)
    kbtn.BackgroundColor3 = C.chipBg
    kbtn.BorderSizePixel = 0
    kbtn.Text = getKeyDisplayName(currentKey)
    kbtn.TextColor3 = C.chipTxt
    kbtn.Font = Enum.Font.GothamBold
    kbtn.TextSize = 11
    kbtn.ZIndex = 8
    mkCorner(kbtn, 5)
    local ks = mkStroke(kbtn, C.chipBorder, 1)

    local listening = false
    local lconnKeyboard = nil
    local lconnGamepad = nil
    local function stopL(key)
        listening = false
        if lconnKeyboard then lconnKeyboard:Disconnect(); lconnKeyboard = nil end
        if lconnGamepad then lconnGamepad:Disconnect(); lconnGamepad = nil end
        TweenService:Create(ks, TweenInfo.new(0.12), { Color = C.chipBorder }):Play()
        kbtn.TextColor3 = C.chipTxt
        if key then
            kbtn.Text = getKeyDisplayName(key)
            if onChanged then onChanged(key) end
            task.spawn(function() if saveConfig then pcall(saveConfig) end end)
        end
    end
    kbtn.MouseButton1Click:Connect(function()
        if listening then stopL(nil); return end
        listening = true
        kbtn.Text = "···"
        kbtn.TextColor3 = C.inputTxt
        TweenService:Create(ks, TweenInfo.new(0.12), { Color = C.inputFocus }):Play()
        lconnKeyboard = UIS.InputBegan:Connect(function(inp)
            if not listening then return end
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopL(nil); return end
            stopL(inp.KeyCode)
        end)
        lconnGamepad = UIS.InputBegan:Connect(function(inp)
            if not listening then return end
            if inp.UserInputType ~= Enum.UserInputType.Gamepad1
                and inp.UserInputType ~= Enum.UserInputType.Gamepad2
                and inp.UserInputType ~= Enum.UserInputType.Gamepad3
                and inp.UserInputType ~= Enum.UserInputType.Gamepad4 then return end
            local kc = inp.KeyCode
            if kc == Enum.KeyCode.Unknown then return end
            stopL(kc)
        end)
    end)
    if keyName then keybindBtnRefs[keyName] = kbtn end
    return kbtn
end

-- ============================================================
-- ESP FUNCTIONS (Players)
-- ============================================================
local function createHighlight(character)
    local h = Instance.new("Highlight")
    h.Name = "SZG_ESP_Highlight"
    h.Adornee = character
    h.FillColor = ESP_COLOR
    h.FillTransparency = 0.7
    h.OutlineColor = ESP_OUTLINE
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = game:GetService("CoreGui")
    return h
end

local function createBillboard(character, player)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = "SZG_ESP_Name"
    bb.Adornee = hrp
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0,100,0,20)
    bb.StudsOffsetWorldSpace = Vector3.new(0,3,0)
    bb.MaxDistance = 600
    bb.Parent = game:GetService("CoreGui")
    local bg = Instance.new("Frame", bb)
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency = 0.4
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,6)
    local txt = Instance.new("TextLabel", bg)
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamSemibold
    txt.TextSize = 13
    txt.TextColor3 = Color3.new(1,1,1)
    txt.TextStrokeTransparency = 0.2
    txt.Text = player.DisplayName
    return bb
end

local function attachESP(player)
    if player == LP then return end
    local function apply(character)
        if espHighlights[player] then espHighlights[player]:Destroy() end
        if espBillboards[player] then espBillboards[player]:Destroy() end
        espHighlights[player] = createHighlight(character)
        espBillboards[player] = createBillboard(character, player)
    end
    if player.Character then apply(player.Character) end
    local conn = player.CharacterAdded:Connect(apply)
    table.insert(espConnections, conn)
end

local function enableESP()
    if State.espEnabled then return end
    State.espEnabled = true
    for _, p in ipairs(Players:GetPlayers()) do attachESP(p) end
    table.insert(espConnections, Players.PlayerAdded:Connect(attachESP))
    table.insert(espConnections, Players.PlayerRemoving:Connect(function(p)
        if espHighlights[p] then espHighlights[p]:Destroy() end
        if espBillboards[p] then espBillboards[p]:Destroy() end
    end))
end

local function disableESP()
    if not State.espEnabled then return end
    State.espEnabled = false
    for _, h in pairs(espHighlights) do pcall(h.Destroy, h) end
    for _, b in pairs(espBillboards) do pcall(b.Destroy, b) end
    for _, c in ipairs(espConnections) do pcall(c.Disconnect, c) end
    espHighlights = {}
    espBillboards = {}
    espConnections = {}
end


-- ============================================================
-- BUILD PAGES
-- ============================================================
local function buildPage(tabName, buildFn)
    local page = Instance.new("ScrollingFrame", contentBg)
    page.Name = tabName
    page.Visible = (tabName == "Combat")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Position = UDim2.new(0, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.ScrollBarImageTransparency = 0.4
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    local ll = Instance.new("UIListLayout", page)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 0)
    tabPages[tabName] = page
    currentPage = page
    lo = 0
    buildFn()
    currentPage = nil
end

-- ============================================================
-- SPEED PAGE
-- ============================================================
buildPage("Speed", function()
    makeGap(2)
    makeSectionHeader("Speed Settings")
    makeGap(2)

    normalBox = makeInputRow("Normal Speed", State.normalSpeed, function(n)
        if n > 0 and n <= 500 then State.normalSpeed = n end
    end)
    carryBox = makeInputRow("Carry Speed", State.carrySpeed, function(n)
        if n > 0 and n <= 500 then State.carrySpeed = n end
    end)
    laggerBox = makeInputRow("Lagger Speed", State.laggerSpeed, function(n)
        if n > 0 and n <= 500 then State.laggerSpeed = n end
    end)

    makeGap(6)

    local modeRow = Instance.new("Frame", currentPage)
    modeRow.Size = UDim2.new(1, 0, 0, 48)
    modeRow.BackgroundTransparency = 1
    modeRow.BorderSizePixel = 0
    modeRow.LayoutOrder = LO()

    local modeWrap = Instance.new("Frame", modeRow)
    modeWrap.Size = UDim2.new(1, -28, 0, 34)
    modeWrap.Position = UDim2.new(0, 14, 0, 7)
    modeWrap.BackgroundColor3 = C.modeBtnBg
    modeWrap.BorderSizePixel = 0
    mkCorner(modeWrap, 7)
    mkStroke(modeWrap, C.modeBtnBrd, 1)

    local modeLL = Instance.new("UIListLayout", modeWrap)
    modeLL.FillDirection = Enum.FillDirection.Horizontal
    modeLL.SortOrder = Enum.SortOrder.LayoutOrder
    modeLL.Padding = UDim.new(0, 0)

    local modeStatusRow = Instance.new("Frame", currentPage)
    modeStatusRow.Size = UDim2.new(1, 0, 0, 24)
    modeStatusRow.BackgroundTransparency = 1
    modeStatusRow.BorderSizePixel = 0
    modeStatusRow.LayoutOrder = LO()
    local modeStatusLbl = Instance.new("TextLabel", modeStatusRow)
    modeStatusLbl.Size = UDim2.new(1, -28, 1, 0)
    modeStatusLbl.Position = UDim2.new(0, 14, 0, 0)
    modeStatusLbl.BackgroundTransparency = 1
    modeStatusLbl.Text = "Mode: Normal"
    modeStatusLbl.TextColor3 = C.rowSub
    modeStatusLbl.Font = Enum.Font.Gotham
    modeStatusLbl.TextSize = 11
    modeStatusLbl.TextXAlignment = Enum.TextXAlignment.Left

    local modeNames = { "Normal", "Carry", "Lagger" }
    local modeBtns = {}
    local function setModeActive(active)
        for _, m in ipairs(modeNames) do
            local b = modeBtns[m]
            if not b then continue end
            local isActive = (m == active)
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = isActive and C.modeBtnActBg or Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = isActive and 0 or 1,
                TextColor3 = isActive and C.modeBtnActTx or C.modeBtnTxt,
            }):Play()
        end
        modeStatusLbl.Text = "Mode: " .. active
        if active == "Normal" then
            State.speedToggled = false
            State.laggerEnabled = false
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
            if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end
        elseif active == "Carry" then
            State.speedToggled = true
            State.laggerEnabled = false
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(true) end
            if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end
        elseif active == "Lagger" then
            State.speedToggled = false
            State.laggerEnabled = true
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
            if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(true) end
        end
    end

    for i, mname in ipairs(modeNames) do
        local b = Instance.new("TextButton", modeWrap)
        b.Size = UDim2.new(1 / 3, 0, 1, 0)
        b.BackgroundColor3 = (i == 1) and C.modeBtnActBg or Color3.fromRGB(0, 0, 0)
        b.BackgroundTransparency = (i == 1) and 0 or 1
        b.BorderSizePixel = 0
        b.Text = mname
        b.TextColor3 = (i == 1) and C.modeBtnActTx or C.modeBtnTxt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.ZIndex = 8
        b.LayoutOrder = i
        mkCorner(b, 5)
        b.MouseButton1Click:Connect(function() setModeActive(mname) end)
        modeBtns[mname] = b
    end
end)

-- ============================================================
-- PROTECTION TAB (Visuals: ESP, Custom FOV)
-- ============================================================
buildPage("Combat", function()
    makeGap(2)
    makeSectionHeader("Bat Aimbot")
    makeGap(2)

    local setBatAimbotToggle = makeToggleRow("Bat Aimbot", false, function(on)
        if on and isHoldingBrainrot() then return end
        State.batAimbotToggled = on
        if on then
            if State.autoLeftEnabled then State.autoLeftEnabled = false; stopAutoLeft(); if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end end
            if State.autoRightEnabled then State.autoRightEnabled = false; stopAutoRight(); if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end end
            pcall(startBatAimbot)
        else
            stopBatAimbot()
        end
        if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(on) end
    end)

    setAutoSwing = makeToggleRow("Auto Swing", false, function(on) State.autoSwingEnabled = on end)

    makeInputRow("Bat Speed", tostring(State.batAimbotSpeed), function(val)
        local n = tonumber(val)
        if n and n > 0 and n <= 200 then State.batAimbotSpeed = n end
    end)

    setBatCounter = makeToggleRow("Bat Counter", false, function(on)
        State.batCounterEnabled = on
        if on then startBatCounter() else stopBatCounter() end
    end)

    makeGap(8)
    makeSectionHeader("Medusa")
    makeGap(2)

    setMedusaCounter = makeToggleRow("Medusa Counter", false, function(on)
        State.medusaCounterEnabled = on
        if on then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
    end)

    setAutoMedusa = makeToggleRow("Auto Medusa", false, function(on)
        State.autoMedusaEnabled = on
        if on then startAutoMedusa() else stopAutoMedusa() end
    end)
end)

-- ============================================================
-- MECHANICS PAGE
-- ============================================================
buildPage("Visual", function()
    makeGap(2)
    makeSectionHeader("Stealing")
    makeGap(2)

    setInstaGrab = makeToggleRow("Auto Steal", AutoSteal.Enabled, function(on)
        if on then enableAutoSteal() else disableAutoSteal() end
    end)

    makeGap(8)
    makeSectionHeader("Visuals")
    makeGap(2)

    
    makeToggleRow("unwalk", State.unwalkEnabled, function(on)
        State.unwalkEnabled = on
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Animate") then
            char.Animate.Disabled = on
            if not on then
                for _, track in pairs(char.Humanoid:GetPlayingAnimationTracks()) do track:Stop() end
            end
        end
    end)
    makeToggleRow("ESP Players", true, function(on)
        if on then enableESP() else disableESP() end
    end)

    makeToggleRow("Custom FOV (120°)", State.customFOVEnabled, function(on)
        setCustomFOV(on)
    end)

    makeGap(8)
    makeSectionHeader("Auto TP Down")
    makeGap(2)

    setAutoTPDown = makeToggleRow("Auto TP Down", false, function(on)
        State.autoTPDownEnabled = on
        if on then
            startAutoTPDown()
            if stackBtnRefs.autoTPDown then stackBtnRefs.autoTPDown.setOn(true) end
        else
            stopAutoTPDown()
            if stackBtnRefs.autoTPDown then stackBtnRefs.autoTPDown.setOn(false) end
        end
    end)

    makeGap(8)
    makeSectionHeader("Performance")
    makeGap(2)
    setFps = makeToggleRow("FPS Boost", false, function(on)
        State.fpsBoostEnabled = on
        if on then pcall(applyFPSBoost) end
    end)
end)

buildPage("Config", function()
    makeGap(2)
    makeSectionHeader("Keybinds")
    makeGap(2)
    makeKeybindRow("Speed Key", Keys.speed, function(k) Keys.speed = k end, "speed")
    makeKeybindRow("Auto Left Key", Keys.autoLeft, function(k) Keys.autoLeft = k end, "autoLeft")
    makeKeybindRow("Auto Right Key", Keys.autoRight, function(k) Keys.autoRight = k end, "autoRight")
    makeKeybindRow("Lagger Key", Keys.lagger, function(k) Keys.lagger = k end, "lagger")
    makeKeybindRow("Drop Key", Keys.drop, function(k) Keys.drop = k end, "drop")
    makeKeybindRow("TP Down Key", Keys.tpDown, function(k) Keys.tpDown = k end, "tpDown")
    makeKeybindRow("Aimbot Key", Keys.aimbot, function(k) Keys.aimbot = k end, "aimbot")
    makeKeybindRow("Hide GUI Key", Keys.guiHide, function(k) Keys.guiHide = k end, "guiHide")

    makeGap(8)
    makeSectionHeader("Button Menu")
    makeGap(2)
    makeToggleRow("Lock Button", State.uiLocked, function(on)
        State.uiLocked = on
        if lockBtn then lockBtn.Text = on and "🔒" or "🔓" end
    end)
    makeGap(4)

    -- Reset Button Positions
    local rWrap = Instance.new("Frame", currentPage)
    rWrap.Size = UDim2.new(1, 0, 0, 46)
    rWrap.BackgroundTransparency = 1
    rWrap.BorderSizePixel = 0
    rWrap.LayoutOrder = LO()
    local resetBtn = Instance.new("TextButton", rWrap)
    resetBtn.Size = UDim2.new(1, -28, 0, 32)
    resetBtn.Position = UDim2.new(0, 14, 0, 7)
    resetBtn.BackgroundColor3 = C.btnBg
    resetBtn.BorderSizePixel = 0
    resetBtn.Text = "↺  Reset Button Positions"
    resetBtn.TextColor3 = C.btnTxt
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 12
    resetBtn.ZIndex = 5
    mkCorner(resetBtn, 6)
    mkStroke(resetBtn, C.btnBorder, 1)
    resetBtn.MouseEnter:Connect(function() TweenService:Create(resetBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
    resetBtn.MouseLeave:Connect(function() TweenService:Create(resetBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
    resetBtn.MouseButton1Click:Connect(function()
        for i, def in ipairs(stackDefs) do
            local wrapper = stackWrappers[def.key]
            if wrapper then
                local newPos = getDefaultStackPos(i)
                TweenService:Create(wrapper, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = newPos }):Play()
                -- save the new position after reset
                task.delay(0.4, debouncedSaveButtonPositions)
            end
        end
        resetBtn.Text = "✓  Positions Reset!"
        task.delay(1.8, function() if resetBtn and resetBtn.Parent then resetBtn.Text = "↺  Reset Button Positions" end end)
    end)

    makeGap(8)
    makeSectionHeader("Button Size")
    makeGap(2)

    -- Button Size + 
    local sizeUpWrap = Instance.new("Frame", currentPage)
    sizeUpWrap.Size = UDim2.new(1, 0, 0, 46)
    sizeUpWrap.BackgroundTransparency = 1
    sizeUpWrap.BorderSizePixel = 0
    sizeUpWrap.LayoutOrder = LO()
    local sizeUpBtn = Instance.new("TextButton", sizeUpWrap)
    sizeUpBtn.Size = UDim2.new(1, -28, 0, 32)
    sizeUpBtn.Position = UDim2.new(0, 14, 0, 7)
    sizeUpBtn.BackgroundColor3 = C.btnBg
    sizeUpBtn.BorderSizePixel = 0
    sizeUpBtn.Text = "➕  Btn Size +"
    sizeUpBtn.TextColor3 = C.btnTxt
    sizeUpBtn.Font = Enum.Font.GothamBold
    sizeUpBtn.TextSize = 12
    sizeUpBtn.ZIndex = 5
    mkCorner(sizeUpBtn, 6)
    mkStroke(sizeUpBtn, C.btnBorder, 1)
    sizeUpBtn.MouseEnter:Connect(function() TweenService:Create(sizeUpBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
    sizeUpBtn.MouseLeave:Connect(function() TweenService:Create(sizeUpBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
    sizeUpBtn.MouseButton1Click:Connect(function()
        State.stackButtonScale = math.min(State.stackButtonScale + 0.2, 2.0)
        for _, wrapper in pairs(stackWrappers) do
            wrapper.Size = UDim2.new(0, BTN_W * State.stackButtonScale, 0, BTN_H * State.stackButtonScale)
        end
        sizeUpBtn.Text = "➕  Size: " .. string.format("%.1fx", State.stackButtonScale)
        task.delay(1, function() if sizeUpBtn and sizeUpBtn.Parent then sizeUpBtn.Text = "➕  Btn Size +" end end)
        pcall(saveConfig)
    end)

    -- Button Size -
    local sizeDownWrap = Instance.new("Frame", currentPage)
    sizeDownWrap.Size = UDim2.new(1, 0, 0, 46)
    sizeDownWrap.BackgroundTransparency = 1
    sizeDownWrap.BorderSizePixel = 0
    sizeDownWrap.LayoutOrder = LO()
    local sizeDownBtn = Instance.new("TextButton", sizeDownWrap)
    sizeDownBtn.Size = UDim2.new(1, -28, 0, 32)
    sizeDownBtn.Position = UDim2.new(0, 14, 0, 7)
    sizeDownBtn.BackgroundColor3 = C.btnBg
    sizeDownBtn.BorderSizePixel = 0
    sizeDownBtn.Text = "➖  Btn Size -"
    sizeDownBtn.TextColor3 = C.btnTxt
    sizeDownBtn.Font = Enum.Font.GothamBold
    sizeDownBtn.TextSize = 12
    sizeDownBtn.ZIndex = 5
    mkCorner(sizeDownBtn, 6)
    mkStroke(sizeDownBtn, C.btnBorder, 1)
    sizeDownBtn.MouseEnter:Connect(function() TweenService:Create(sizeDownBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
    sizeDownBtn.MouseLeave:Connect(function() TweenService:Create(sizeDownBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
    sizeDownBtn.MouseButton1Click:Connect(function()
        State.stackButtonScale = math.max(State.stackButtonScale - 0.2, 0.6)
        for _, wrapper in pairs(stackWrappers) do
            wrapper.Size = UDim2.new(0, BTN_W * State.stackButtonScale, 0, BTN_H * State.stackButtonScale)
        end
        sizeDownBtn.Text = "➖  Size: " .. string.format("%.1fx", State.stackButtonScale)
        task.delay(1, function() if sizeDownBtn and sizeDownBtn.Parent then sizeDownBtn.Text = "➖  Btn Size -" end end)
        pcall(saveConfig)
    end)

    makeGap(8)
    makeSectionHeader("Config")
    makeGap(2)

    -- Save Config Button
    local saveWrap = Instance.new("Frame", currentPage)
    saveWrap.Size = UDim2.new(1, 0, 0, 46)
    saveWrap.BackgroundTransparency = 1
    saveWrap.BorderSizePixel = 0
    saveWrap.LayoutOrder = LO()
    local saveBtn = Instance.new("TextButton", saveWrap)
    saveBtn.Size = UDim2.new(1, -28, 0, 32)
    saveBtn.Position = UDim2.new(0, 14, 0, 7)
    saveBtn.BackgroundColor3 = C.btnBg
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾  Save Config"
    saveBtn.TextColor3 = C.btnTxt
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 12
    saveBtn.ZIndex = 5
    mkCorner(saveBtn, 6)
    mkStroke(saveBtn, C.btnBorder, 1)
    saveBtn.MouseEnter:Connect(function() TweenService:Create(saveBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
    saveBtn.MouseLeave:Connect(function() TweenService:Create(saveBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
    saveBtn.MouseButton1Click:Connect(function()
        local ok, err = pcall(saveConfig)
        if ok then
            saveBtn.Text = "✓  Config Saved!"
        else
            saveBtn.Text = "✗  Error!"
        end
        task.delay(1.5, function() if saveBtn and saveBtn.Parent then saveBtn.Text = "💾  Save Config" end end)
    end)

    makeGap(10)

    local fw = Instance.new("Frame", currentPage)
    fw.Size = UDim2.new(1, 0, 0, 22)
    fw.BackgroundTransparency = 1
    fw.BorderSizePixel = 0
    fw.LayoutOrder = LO()
    local fl = Instance.new("TextLabel", fw)
    fl.Size = UDim2.new(1, 0, 1, 0)
    fl.BackgroundTransparency = 1
    fl.Text = "apolo Hub"
    fl.TextColor3 = Color3.fromRGB(180, 140, 240)
    fl.Font = Enum.Font.Gotham
    fl.TextSize = 10
    fl.TextXAlignment = Enum.TextXAlignment.Center
end)

-- Init tab states
for _, n in ipairs(TABS) do
    local t = tabBtns[n]
    local active = (n == "Combat")
    t.btn.TextColor3 = active and C.tabActive or C.tabIdle
    t.btn.BackgroundColor3 = active and C.tabActiveBg or C.tabBarBg
    t.underline.Visible = active
    if tabPages[n] then tabPages[n].Visible = active end
end

-- ============================================================
-- VBTN (floating button)
-- ============================================================
local vBtnFrame = Instance.new("Frame", gui)
vBtnFrame.Name = "ApoloHubVBtn"
vBtnFrame.Size = UDim2.new(0, 95, 0, 32)
vBtnFrame.Position = UDim2.new(1, -105, 0, 14)
vBtnFrame.BackgroundColor3 = C.accent
vBtnFrame.BorderSizePixel = 0
vBtnFrame.Active = true
vBtnFrame.ZIndex = 20
mkCorner(vBtnFrame, 8)
mkStroke(vBtnFrame, C.accentDim, 1)

local vBtnText = Instance.new("TextLabel", vBtnFrame)
vBtnText.Size = UDim2.new(1, 0, 1, 0)
vBtnText.BackgroundTransparency = 1
vBtnText.Text = "Menu"
vBtnText.TextColor3 = Color3.fromRGB(255, 255, 255)
vBtnText.Font = Enum.Font.GothamBlack
vBtnText.TextSize = 10
vBtnText.ZIndex = 21

local vDragging, vDragInput, vDragStart, vStartPos = false, nil, nil, nil
local vMoved = false
vBtnFrame.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    vDragging = true
    vMoved = false
    vDragStart = inp.Position
    vStartPos = vBtnFrame.Position
    inp.Changed:Connect(function()
        if inp.UserInputState == Enum.UserInputState.End then
            if not vMoved then State.guiVisible = not State.guiVisible; mainOuter.Visible = State.guiVisible end
            vDragging = false
            vMoved = false
        end
    end)
end)
vBtnFrame.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then vDragInput = inp end
end)
UIS.InputChanged:Connect(function(inp)
    if inp ~= vDragInput or not vDragging then return end
    local dx = inp.Position.X - vDragStart.X
    local dy = inp.Position.Y - vDragStart.Y
    if math.abs(dx) > 4 or math.abs(dy) > 4 then vMoved = true end
    if vMoved then
        vBtnFrame.Position = UDim2.new(vStartPos.X.Scale, vStartPos.X.Offset + dx, vStartPos.Y.Scale, vStartPos.Y.Offset + dy)
    end
end)

-- ============================================================
-- FPS COUNTER (for billboard)
-- ============================================================
local _currentFPS = 0
do
    local lastT = tick()
    local fc = 0
    RunService.RenderStepped:Connect(function()
        fc = fc + 1
        local now = tick()
        if now - lastT >= 0.5 then
            _currentFPS = math.floor(fc / (now - lastT))
            fc = 0
            lastT = now
        end
    end)
end

-- ============================================================
-- STACK BUTTONS (with position saving)
-- ============================================================
local function doTpDown()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart")

        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {char}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude

        local raioOrigem = hrp.Position
        local raioDirecao = Vector3.new(0, -50, 0)
        local resultado = workspace:Raycast(raioOrigem, raioDirecao, raycastParams)

        if resultado then
            hrp.CFrame = CFrame.new(resultado.Position + Vector3.new(0, 3, 0))
        else
            hrp.CFrame = hrp.CFrame + Vector3.new(0, -20, 0)
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

for i, def in ipairs(stackDefs) do
    local btnFrame = Instance.new("Frame", gui)
    btnFrame.Name = "StackBtn_" .. def.key
    btnFrame.Size = UDim2.new(0, BTN_W, 0, BTN_H)
    -- Apply saved position if exists, otherwise default
    local savedPos = buttonPositions[def.key]
    if savedPos then
        btnFrame.Position = UDim2.new(savedPos.XScale, savedPos.XOffset, savedPos.YScale, savedPos.YOffset)
    else
        btnFrame.Position = getDefaultStackPos(i)
    end
    btnFrame.BackgroundColor3 = C.stackBg
    btnFrame.BorderSizePixel = 0
    btnFrame.Active = true
    btnFrame.ZIndex = 15
    mkCorner(btnFrame, 8)
    local bStroke = mkStroke(btnFrame, C.stackBrd, 1)
    stackWrappers[def.key] = btnFrame

    local nl = Instance.new("TextLabel", btnFrame)
    nl.Size = UDim2.new(1, -6, 1, -14)
    nl.Position = UDim2.new(0, 3, 0, 4)
    nl.BackgroundTransparency = 1
    nl.Text = def.label
    nl.TextColor3 = C.stackTxt
    nl.Font = Enum.Font.GothamBlack
    nl.TextSize = 10
    nl.TextWrapped = true
    nl.TextXAlignment = Enum.TextXAlignment.Center
    nl.ZIndex = 6

    local dot = Instance.new("Frame", btnFrame)
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0.5, -3, 1, -10)
    dot.BackgroundColor3 = C.stackDot
    dot.BorderSizePixel = 0
    mkCorner(dot, 3)

    local btnState = false
    local function setOn(on)
        btnState = on
        TweenService:Create(btnFrame, TweenInfo.new(0.15), { BackgroundColor3 = on and C.stackActBg or C.stackBg }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.15), { Color = on and C.stackActBrd or C.stackBrd }):Play()
        TweenService:Create(nl, TweenInfo.new(0.15), { TextColor3 = on and C.stackActTxt or C.stackTxt }):Play()
        TweenService:Create(dot, TweenInfo.new(0.15), { BackgroundColor3 = on and C.stackDotOn or C.stackDot }):Play()
    end
    stackBtnRefs[def.key] = { setOn = setOn }

    btnFrame.MouseEnter:Connect(function()
        if not btnState then
            TweenService:Create(btnFrame, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 20, 20) }):Play()
        end
    end)
    btnFrame.MouseLeave:Connect(function()
        TweenService:Create(btnFrame, TweenInfo.new(0.1), { BackgroundColor3 = btnState and C.stackActBg or C.stackBg }):Play()
    end)

    local function onTap()
        if def.key == "tpDown" then
            doTpDown()
            return
        end
        if def.key == "carrySpeed" then
            State.speedToggled = not State.speedToggled
            setOn(State.speedToggled)
            return
        end
        -- Block aimbot/autoLeft/autoRight activation when holding brainrot
        if (def.key == "autoLeft" or def.key == "autoRight" or def.key == "aimbot") and (not btnState) and isHoldingBrainrot() then
            return
        end
        local ns = not btnState
        setOn(ns)
        if def.key == "autoLeft" then
            State.autoLeftEnabled = ns
            if ns then
                if State.autoRightEnabled then State.autoRightEnabled = false; stopAutoRight(); if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end end
                if State.batAimbotToggled then State.batAimbotToggled = false; stopBatAimbot(); if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end end
                startAutoLeft()
            else
                stopAutoLeft()
            end
        elseif def.key == "autoRight" then
            State.autoRightEnabled = ns
            if ns then
                if State.autoLeftEnabled then State.autoLeftEnabled = false; stopAutoLeft(); if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end end
                if State.batAimbotToggled then State.batAimbotToggled = false; stopBatAimbot(); if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end end
                startAutoRight()
            else
                stopAutoRight()
            end
        elseif def.key == "aimbot" then
            State.batAimbotToggled = ns
            if ns then
                if State.autoLeftEnabled then State.autoLeftEnabled = false; stopAutoLeft(); if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end end
                if State.autoRightEnabled then State.autoRightEnabled = false; stopAutoRight(); if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end end
                pcall(startBatAimbot)
            else
                stopBatAimbot()
            end
        elseif def.key == "lagger" then
            State.laggerEnabled = ns
            if ns then
                State._prevCarry = State.carrySpeed
                State._prevSpeed = State.speedToggled
                State.speedToggled = false
                if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
                if carryBox then carryBox.Text = tostring(State.laggerSpeed) end
            else
                State.carrySpeed = State._prevCarry or 30
                State.speedToggled = State._prevSpeed or false
                if carryBox then carryBox.Text = tostring(State.carrySpeed) end
                if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
            end
        elseif def.key == "drop" then
            if ns then
                runDropBrainrot()
            else
                stopDropBrainrot()
            end
        elseif def.key == "autoTPDown" then
            State.autoTPDownEnabled = ns
            if ns then
                startAutoTPDown()
                if setAutoTPDown then setAutoTPDown(ns) end
            else
                stopAutoTPDown()
                if setAutoTPDown then setAutoTPDown(ns) end
            end
        end
    end
    makeStackDraggable(btnFrame, onTap)
end

-- ============================================================
-- BRAINROT PROTECTION: auto-disable aimbot/autoLeft/autoRight when holding brainrot
-- ============================================================
RunService.Heartbeat:Connect(function()
    if not isHoldingBrainrot() then return end
    -- Force disable Auto Bat
    if State.batAimbotToggled then
        State.batAimbotToggled = false
        pcall(stopBatAimbot)
        if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
    end
    -- Force disable Auto Left
    if State.autoLeftEnabled then
        State.autoLeftEnabled = false
        pcall(stopAutoLeft)
        if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
    end
    -- Force disable Auto Right
    if State.autoRightEnabled then
        State.autoRightEnabled = false
        pcall(stopAutoRight)
        if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
    end
end)

-- ============================================================
-- DROP BRAINROT
-- ============================================================
local _dropConns = {}
function runDropBrainrot()
    if State.dropEnabled then return end
    State.dropEnabled = true
    if stackBtnRefs.drop then stackBtnRefs.drop.setOn(true) end
    task.spawn(function()
        local colConn = RunService.Stepped:Connect(function()
            if not State.dropEnabled then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    for _, part in ipairs(p.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end)
        table.insert(_dropConns, colConn)
        task.spawn(function()
            while State.dropEnabled do
                RunService.Heartbeat:Wait()
                local c = LP.Character
                local root = c and c:FindFirstChild("HumanoidRootPart")
                if not root then continue end
                local vel = root.Velocity
                root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                if root and root.Parent then root.Velocity = vel end
                RunService.Stepped:Wait()
                if root and root.Parent then root.Velocity = vel + Vector3.new(0, 0.1, 0) end
            end
        end)
        task.wait(DROP_AUTO_OFF_DELAY)
        stopDropBrainrot()
    end)
end

function stopDropBrainrot()
    State.dropEnabled = false
    for _, cn in ipairs(_dropConns) do pcall(function() cn:Disconnect() end) end
    _dropConns = {}
    if stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
end

-- ============================================================
-- BAT AIMBOT
-- ============================================================
-- Bat aimbot speed is read from State.batAimbotSpeed
local VYSE_HIT_DIST = 8
local SWING_COOLDOWN = 0.04

local function findAnyTool()
    local c = LP.Character
    if c then
        for _, v in ipairs(c:GetChildren()) do
            if v:IsA("Tool") then return v end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") then return v end
        end
    end
    return nil
end

local function getClosestPlayer()
    if not hrp then return nil, math.huge end
    local cp, cd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local ph = p.Character:FindFirstChildOfClass("Humanoid")
            if tr and ph and ph.Health > 0 then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < cd then
                    cd = d
                    cp = p
                end
            end
        end
    end
    return cp, cd
end

local function tryHitBat()
    if State.hittingCooldown then return end
    State.hittingCooldown = true
    pcall(function()
        local c = LP.Character
        if not c then return end
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        local tool = findAnyTool()
        if tool then
            if tool.Parent ~= c and hum2 then pcall(function() hum2:EquipTool(tool) end) end
            local remote = tool:FindFirstChildOfClass("RemoteEvent")
            if remote then
                pcall(function() remote:FireServer() end)
            else
                pcall(function() tool:Activate() end)
            end
        end
    end)
    task.delay(SWING_COOLDOWN, function() State.hittingCooldown = false end)
end

function startBatAimbot()
    if Conns.aimbot then return end
    Conns.aimbot = RunService.Heartbeat:Connect(function()
        if not State.batAimbotToggled then return end
        if isHoldingBrainrot() then return end
        local c = LP.Character
        if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if not hum2 then return end
        local target, dist = getClosestPlayer()
        if target and target.Character then
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local fp = tr.Position + tr.CFrame.LookVector * 1.5
                local dir = (fp - root.Position).Unit
                root.AssemblyLinearVelocity = Vector3.new(dir.X * State.batAimbotSpeed, dir.Y * State.batAimbotSpeed, dir.Z * State.batAimbotSpeed)
                if dist <= VYSE_HIT_DIST and State.autoSwingEnabled then tryHitBat() end
            end
        else
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

function stopBatAimbot()
    if Conns.aimbot then Conns.aimbot:Disconnect(); Conns.aimbot = nil end
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root then root.AssemblyLinearVelocity = Vector3.zero end
    State.hittingCooldown = false
end

-- ============================================================
-- BAT COUNTER
-- ============================================================
local BAT_COUNTER_SLAP_LIST = {
    "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap",
    "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap"
}

local function findBatForCounter()
    local c = LP.Character
    if not c then return nil end
    local bp = LP:FindFirstChildOfClass("Backpack")
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if t then return t end
    end
    for _, ch in ipairs(c:GetChildren()) do
        if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
    end
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
        end
    end
    return nil
end

local function swingBatForCounter(bat, char)
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    if bat.Parent ~= char then
        if hum2 then pcall(function() hum2:EquipTool(bat) end) end
        task.wait(0.05)
    end
    local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end)
        task.wait(0.15)
        pcall(function() remote:FireServer() end)
    else
        pcall(function() bat:Activate() end)
        task.wait(0.15)
        pcall(function() bat:Activate() end)
    end
end

function startBatCounter()
    if Conns.batCounter then return end
    Conns.batCounter = RunService.Heartbeat:Connect(function()
        if not State.batCounterEnabled then return end
        if State.batCounterDebounce then return end
        local char = LP.Character
        if not char then return end
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if not hum2 then return end
        local st = hum2:GetState()
        local isRagdolled = st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
        if isRagdolled then
            State.batCounterDebounce = true
            task.spawn(function()
                local bat = findBatForCounter()
                if bat then swingBatForCounter(bat, char) end
                task.wait(0.5)
                State.batCounterDebounce = false
            end)
        end
    end)
end

function stopBatCounter()
    if Conns.batCounter then Conns.batCounter:Disconnect(); Conns.batCounter = nil end
    State.batCounterDebounce = false
end

-- ============================================================
-- MEDUSA COUNTER (original)
-- ============================================================
local function findMedusa()
    local c = LP.Character
    if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("medusa") or n:find("head") or n:find("stone") then return t end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("medusa") or n:find("head") or n:find("stone") then return t end
            end
        end
    end
    return nil
end

local function useMedusaCounter()
    if State.medusaDebounce then return end
    if tick() - State.medusaLastUsed < MEDUSA_COOLDOWN then return end
    local c = LP.Character
    if not c then return end
    State.medusaDebounce = true
    local med = findMedusa()
    if not med then
        State.medusaDebounce = false
        return
    end
    if med.Parent ~= c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:EquipTool(med) end
    end
    pcall(function() med:Activate() end)
    State.medusaLastUsed = tick()
    State.medusaDebounce = false
end

local function onAnchorChanged(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if part.Anchored and part.Transparency == 1 then useMedusaCounter() end
    end)
end

function setupMedusaCounter(char)
    stopMedusaCounter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(Conns.anchor, onAnchorChanged(part)) end
    end
    table.insert(Conns.anchor, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then table.insert(Conns.anchor, onAnchorChanged(part)) end
    end))
end

function stopMedusaCounter()
    for _, c2 in pairs(Conns.anchor) do pcall(function() c2:Disconnect() end) end
    Conns.anchor = {}
end

-- ============================================================
-- AUTO MEDUSA (only when holding Medusa)
-- ============================================================
local medusaCircle = nil
local medusaAttacking = false

local function findEquippedMedusa()
    local char = LP.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local nameLower = tool.Name:lower()
            if nameLower:find("medusa") or nameLower:find("head") or nameLower:find("stone") then
                return tool
            end
        end
    end
    return nil
end

local function enemyInMedusaRange()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LP and other.Character then
            local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
            local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
            if otherRoot and otherHum and otherHum.Health > 0 then
                local dist = (root.Position - otherRoot.Position).Magnitude
                if dist <= State.medusaRange then
                    return true
                end
            end
        end
    end
    return false
end

local function createMedusaCircle()
    if medusaCircle then medusaCircle:Destroy() end
    medusaCircle = Instance.new("Part")
    medusaCircle.Name = "AutoMedusaRange"
    medusaCircle.Shape = Enum.PartType.Cylinder
    medusaCircle.Size = Vector3.new(0.2, State.medusaRange * 2, State.medusaRange * 2)
    medusaCircle.Color = Color3.fromRGB(255, 0, 0)
    medusaCircle.Material = Enum.Material.Neon
    medusaCircle.Transparency = 0.35
    medusaCircle.Anchored = true
    medusaCircle.CanCollide = false
    medusaCircle.Parent = workspace
end

local function updateMedusaCircle()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if medusaCircle and root then
        medusaCircle.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
        medusaCircle.Size = Vector3.new(0.2, State.medusaRange * 2, State.medusaRange * 2)
    end
end

local function startAutoMedusa()
    if Conns.autoMedusa then Conns.autoMedusa:Disconnect() end
    createMedusaCircle()
    Conns.autoMedusa = RunService.Heartbeat:Connect(function()
        if not State.autoMedusaEnabled then
            if medusaCircle then medusaCircle:Destroy(); medusaCircle = nil end
            return
        end
        updateMedusaCircle()
        local medusa = findEquippedMedusa()
        if not medusa then return end
        if not enemyInMedusaRange() then return end
        if medusaAttacking then return end
        medusaAttacking = true
        pcall(function() medusa:Activate() end)
        task.delay(State.medusaCooldown, function() medusaAttacking = false end)
    end)
end

local function stopAutoMedusa()
    if Conns.autoMedusa then Conns.autoMedusa:Disconnect(); Conns.autoMedusa = nil end
    if medusaCircle then medusaCircle:Destroy(); medusaCircle = nil end
    medusaAttacking = false
end

-- ============================================================
-- ANTI RAGDOLL
-- ============================================================
function startAntiRagdoll()
    if Conns.antiRag then return end
    Conns.antiRag = RunService.Heartbeat:Connect(function()
        if not State.antiRagdollEnabled then return end
        local c = LP.Character
        if not c then return end
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        local root = c:FindFirstChild("HumanoidRootPart")
        if not hum2 or not root then return end
        if hum2.Health <= 0 then return end
        local st = hum2:GetState()
        if st == Enum.HumanoidStateType.Dead then return end
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
            pcall(function() hum2:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() workspace.CurrentCamera.CameraSubject = hum2 end)
            pcall(function()
                local PM = LP.PlayerScripts:FindFirstChild("PlayerModule")
                if PM then
                    local CM = require(PM:FindFirstChild("ControlModule"))
                    if CM then CM:Enable() end
                end
            end)
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end
        for _, obj in ipairs(c:GetDescendants()) do
            pcall(function()
                if obj:IsA("Motor6D") and obj.Enabled == false then obj.Enabled = true end
            end)
        end
    end)
end

function stopAntiRagdoll()
    if Conns.antiRag then Conns.antiRag:Disconnect(); Conns.antiRag = nil end
end

-- ============================================================
-- FPS BOOST
-- ============================================================
function applyFPSBoost()
    pcall(function() setfpscap(999999999) end)
    local function pO(v)
        pcall(function()
            if v:IsA("Model") then
                v.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
                v.ModelStreamingMode = Enum.ModelStreamingMode.Nonatomic
            elseif v:IsA("MeshPart") then
                v.CastShadow = false
                v.DoubleSided = false
                v.RenderFidelity = Enum.RenderFidelity.Performance
            elseif v:IsA("BasePart") then
                v.CastShadow = false
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("SpecialMesh") then
                v.TextureId = ""
            elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = false
            elseif v:IsA("SurfaceAppearance") or v:IsA("MaterialVariant") then
                v:Destroy()
            elseif v:IsA("Attachment") then
                v.Visible = false
            end
        end)
    end
    for _, v in pairs(workspace:GetDescendants()) do pO(v) end
    pcall(function()
        local L = game:GetService("Lighting")
        for _, v in pairs(L:GetDescendants()) do
            pcall(function()
                if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Clouds") or v:IsA("PostEffect") or v:IsA("ColorCorrectionEffect") then
                    v:Destroy()
                end
            end)
        end
        pcall(function() sethiddenproperty(L, "Technology", Enum.Technology.Legacy) end)
        L.GlobalShadows = false
        L.FogEnd = 9e9
        L.Brightness = 0
        local ter = workspace:FindFirstChildOfClass("Terrain")
        if ter then
            pcall(function() sethiddenproperty(ter, "Decoration", false) end)
            ter.WaterReflectance = 0
            ter.WaterTransparency = 0.7
            ter.WaterWaveSize = 0
            ter.WaterWaveSpeed = 0
        end
    end)
    workspace.DescendantAdded:Connect(function(v)
        if State.fpsBoostEnabled then task.spawn(pO, v) end
    end)
end

-- ============================================================
-- SAVE/LOAD CONFIG (including button positions)
-- ============================================================
function saveConfig()
    -- Collect current button positions
    local posTable = {}
    for key, frame in pairs(stackWrappers) do
        if frame and frame.Position then
            local pos = frame.Position
            posTable[key] = { XScale = pos.X.Scale, XOffset = pos.X.Offset, YScale = pos.Y.Scale, YOffset = pos.Y.Offset }
        end
    end
    
    local cfg = {
        normalSpeed = State.normalSpeed,
        carrySpeed = State.carrySpeed,
        laggerSpeed = State.laggerSpeed,
        stackButtonsHidden = State.stackButtonsHidden,
        stackButtonScale = State.stackButtonScale,
        buttonPositions = posTable,
        speedKey = Keys.speed.Name,
        autoLeftKey = Keys.autoLeft.Name,
        autoRightKey = Keys.autoRight.Name,
        guiHideKey = Keys.guiHide.Name,
        dropKey = Keys.drop.Name,
        laggerKey = Keys.lagger.Name,
        tpDownKey = Keys.tpDown.Name,
        aimbotKey = Keys.aimbot.Name,
        infJump = State.infJumpEnabled,
        antiRagdoll = State.antiRagdollEnabled,
        fpsBoost = State.fpsBoostEnabled,
        medusaCounter = State.medusaCounterEnabled,
        batCounter = State.batCounterEnabled,
        autoStealEnabled = AutoSteal.Enabled,
        autoTPDownEnabled = State.autoTPDownEnabled,
        autoMedusaEnabled = State.autoMedusaEnabled,
        espEnabled = State.espEnabled,
        customFOVEnabled = State.customFOVEnabled,
        batAimbotSpeed = State.batAimbotSpeed,
    }
    local encoded = HttpService:JSONEncode(cfg)
    _writefile(CONFIG_FILE, encoded)
end

function loadConfig()
    local hasFile = false
    pcall(function() hasFile = _isfile(CONFIG_FILE) end)
    if not hasFile then return end
    local raw
    local ok = pcall(function() raw = _readfile(CONFIG_FILE) end)
    if not ok or not raw then return end
    local cfg
    local ok2 = pcall(function() cfg = HttpService:JSONDecode(raw) end)
    if not ok2 or not cfg then return end

    if cfg.normalSpeed then
        State.normalSpeed = cfg.normalSpeed
        if normalBox then normalBox.Text = tostring(cfg.normalSpeed) end
    end
    if cfg.carrySpeed then
        State.carrySpeed = cfg.carrySpeed
        if carryBox then carryBox.Text = tostring(cfg.carrySpeed) end
    end
    if cfg.laggerSpeed then
        State.laggerSpeed = cfg.laggerSpeed
        if laggerBox then laggerBox.Text = tostring(cfg.laggerSpeed) end
    end
    if cfg.stackButtonsHidden then
        applyStackButtonsVisible(false)
        if setHideButtonsToggle then setHideButtonsToggle(true) end
    end
    if cfg.stackButtonScale then
        State.stackButtonScale = cfg.stackButtonScale
        for _, wrapper in pairs(stackWrappers) do
            wrapper.Size = UDim2.new(0, BTN_W * State.stackButtonScale, 0, BTN_H * State.stackButtonScale)
        end
    end
    -- Load button positions
    if cfg.buttonPositions then
        for key, posData in pairs(cfg.buttonPositions) do
            buttonPositions[key] = posData
            if stackWrappers[key] then
                stackWrappers[key].Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset)
            end
        end
    end
    if cfg.autoStealEnabled then
        enableAutoSteal()
        if setInstaGrab then setInstaGrab(true) end
    else
        enableAutoSteal()
        if setInstaGrab then setInstaGrab(true) end
    end
    if cfg.autoTPDownEnabled then
        State.autoTPDownEnabled = true
        startAutoTPDown()
        if setAutoTPDown then setAutoTPDown(true) end
        if stackBtnRefs.autoTPDown then stackBtnRefs.autoTPDown.setOn(true) end
    end
    if cfg.infJump then
        State.infJumpEnabled = true
        if setInfJump then setInfJump(true) end
    else
        State.infJumpEnabled = true
        if setInfJump then setInfJump(true) end
    end
    if cfg.antiRagdoll then
        State.antiRagdollEnabled = true
        if setAntiRag then setAntiRag(true) end
        startAntiRagdoll()
    else
        State.antiRagdollEnabled = true
        if setAntiRag then setAntiRag(true) end
        startAntiRagdoll()
    end
    if cfg.fpsBoost then
        State.fpsBoostEnabled = true
        if setFps then setFps(true) end
        applyFPSBoost()
    end
    if cfg.medusaCounter then
        State.medusaCounterEnabled = true
        if setMedusaCounter then setMedusaCounter(true) end
        setupMedusaCounter(LP.Character)
    end
    if cfg.batCounter then
        State.batCounterEnabled = true
        if setBatCounter then setBatCounter(true) end
        startBatCounter()
    end
    if cfg.autoMedusaEnabled then
        State.autoMedusaEnabled = true
        if setAutoMedusa then setAutoMedusa(true) end
        startAutoMedusa()
    end
    if cfg.espEnabled then
        State.espEnabled = true
        enableESP()
    end
    if cfg.customFOVEnabled then
        setCustomFOV(true)
    end
    if cfg.batAimbotSpeed then
        State.batAimbotSpeed = cfg.batAimbotSpeed
    end

    local function tryKey(field, keyTarget)
        if cfg[field] and Enum.KeyCode[cfg[field]] then
            local kc = Enum.KeyCode[cfg[field]]
            Keys[keyTarget] = kc
            if keybindBtnRefs[keyTarget] then keybindBtnRefs[keyTarget].Text = getKeyDisplayName(kc) end
        end
    end
    tryKey("speedKey", "speed")
    tryKey("autoLeftKey", "autoLeft")
    tryKey("autoRightKey", "autoRight")
    tryKey("guiHideKey", "guiHide")
    tryKey("dropKey", "drop")
    tryKey("laggerKey", "lagger")
    tryKey("tpDownKey", "tpDown")
    tryKey("aimbotKey", "aimbot")
end

-- ============================================================
-- CHARACTER SETUP (unchanged)
-- ============================================================
local function setupChar(char)
    task.wait(0.1)
    local h = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not h or not hrp then return end

    local head = char:FindFirstChild("Head")
    if head then
        local oldBB = head:FindFirstChild("ApoloHubBB")
        if oldBB then oldBB:Destroy() end
        local bb = Instance.new("BillboardGui", head)
        bb.Name = "ApoloHubBB"
        bb.Size = UDim2.new(0, 200, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        
        local hubLbl = Instance.new("TextLabel", bb)
        hubLbl.Name = "HubLbl"
        hubLbl.Size = UDim2.new(1, 0, 1, 0)
        hubLbl.BackgroundTransparency = 1
        hubLbl.Text = "APOLO HUB ON TOP"
        hubLbl.TextColor3 = Color3.fromRGB(140, 80, 255)
        hubLbl.Font = Enum.Font.GothamBlack
        hubLbl.TextScaled = true
        hubLbl.TextStrokeTransparency = 0
        hubLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    end

    if State.antiRagdollEnabled then
        stopAntiRagdoll()
        task.wait(0.5)
        startAntiRagdoll()
    end
    if State.medusaCounterEnabled then setupMedusaCounter(char) end
    if State.batAimbotToggled then stopBatAimbot(); task.wait(0.2); pcall(startBatAimbot) end
    if State.batCounterEnabled then task.wait(0.3); startBatCounter() end
    if State.autoMedusaEnabled then stopAutoMedusa(); task.wait(0.2); startAutoMedusa() end
end

    local head = char:FindFirstChild("Head")
    if head then
        local oldBB = head:FindFirstChild("ApoloHubBB")
        if oldBB then oldBB:Destroy() end
        local bb = Instance.new("BillboardGui", head)
        bb.Name = "ApoloHubBB"
        bb.Size = UDim2.new(0, 180, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        -- Line 1: FPS + Speed
        local speedBillLbl = Instance.new("TextLabel", bb)
        speedBillLbl.Name = "SpeedBillLbl"
        speedBillLbl.Size = UDim2.new(1, 0, 0, 22)
        speedBillLbl.Position = UDim2.new(0, 0, 0, 0)
        speedBillLbl.BackgroundTransparency = 1
        speedBillLbl.Text = "FPS: 0 | Speed: 0.0"
        speedBillLbl.TextColor3 = Color3.fromRGB(180, 60, 255)
        speedBillLbl.Font = Enum.Font.GothamBlack
        speedBillLbl.TextScaled = true
        speedBillLbl.TextStrokeTransparency = 0.1
        speedBillLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        -- Line 2: apolo Hub v1
        local hubLbl = Instance.new("TextLabel", bb)
        hubLbl.Name = "HubLbl"
        hubLbl.Size = UDim2.new(1, 0, 0, 18)
        hubLbl.Position = UDim2.new(0, 0, 0, 24)
        hubLbl.BackgroundTransparency = 1
        hubLbl.Text = "apolo Hub"
        hubLbl.TextColor3 = Color3.fromRGB(200, 130, 255)
        hubLbl.Font = Enum.Font.GothamBold
        hubLbl.TextScaled = true
        hubLbl.TextStrokeTransparency = 0.2
        hubLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    end

    if State.antiRagdollEnabled then
        stopAntiRagdoll()
        task.wait(0.5)
        startAntiRagdoll()
    end
    if State.medusaCounterEnabled then setupMedusaCounter(char) end
    if State.batAimbotToggled then stopBatAimbot(); task.wait(0.2); pcall(startBatAimbot) end
    if State.batCounterEnabled then task.wait(0.3); startBatCounter() end
    if State.autoMedusaEnabled then stopAutoMedusa(); task.wait(0.2); startAutoMedusa() end
end

LP.CharacterAdded:Connect(setupChar)
if LP.Character then task.spawn(function() setupChar(LP.Character) end) end

-- ============================================================
-- RUNTIME LOOPS (unchanged)
-- ============================================================
RunService.Stepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            for _, part in ipairs(p.Character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

UIS.JumpRequest:Connect(function()
    if not State.infJumpEnabled then return end
    local c = LP.Character
    if not c then return end
    local root = c:FindFirstChild("HumanoidRootPart")
    if root then root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z) end
end)

RunService.RenderStepped:Connect(function()
    if not (h and hrp) then return end
    if State._tpInProgress then return end

    if not State.batAimbotToggled and not State.autoLeftEnabled and not State.autoRightEnabled then
        local md = h.MoveDirection
        local spd
        if State.laggerEnabled then
            spd = State.laggerSpeed
        elseif State.speedToggled then
            spd = State.carrySpeed
        else
            spd = State.normalSpeed
        end
        if md.Magnitude > 0 then
            State.lastMoveDir = md
            hrp.Velocity = Vector3.new(md.X * spd, hrp.Velocity.Y, md.Z * spd)
        elseif State.antiRagdollEnabled and State.lastMoveDir.Magnitude > 0 then
            local anyHeld = false
            for key in pairs(MOVE_KEYS) do
                if UIS:IsKeyDown(key) then anyHeld = true; break end
            end
            if anyHeld then
                hrp.Velocity = Vector3.new(State.lastMoveDir.X * spd, hrp.Velocity.Y, State.lastMoveDir.Z * spd)
            end
        end
    end

    -- Visuals updated via BillboardGui
end)

-- ============================================================
-- INPUT (Keybinds) – unchanged
-- ============================================================
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local isKb = inp.UserInputType == Enum.UserInputType.Keyboard
    local isGp = inp.UserInputType == Enum.UserInputType.Gamepad1 or inp.UserInputType == Enum.UserInputType.Gamepad2 or inp.UserInputType == Enum.UserInputType.Gamepad3 or inp.UserInputType == Enum.UserInputType.Gamepad4
    if not isKb and not isGp then return end
    local kc = inp.KeyCode
    if kc == Enum.KeyCode.Unknown then return end

    if kc == Keys.speed then
        State.speedToggled = not State.speedToggled
        if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
    elseif kc == Keys.autoLeft then
        if (not State.autoLeftEnabled) and isHoldingBrainrot() then return end
        State.autoLeftEnabled = not State.autoLeftEnabled
        if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(State.autoLeftEnabled) end
        if State.autoLeftEnabled and State.batAimbotToggled then
            State.batAimbotToggled = false
            stopBatAimbot()
            if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
        end
        if State.autoLeftEnabled then
            startAutoLeft()
        else
            stopAutoLeft()
        end
    elseif kc == Keys.autoRight then
        if (not State.autoRightEnabled) and isHoldingBrainrot() then return end
        State.autoRightEnabled = not State.autoRightEnabled
        if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(State.autoRightEnabled) end
        if State.autoRightEnabled and State.batAimbotToggled then
            State.batAimbotToggled = false
            stopBatAimbot()
            if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
        end
        if State.autoRightEnabled then
            startAutoRight()
        else
            stopAutoRight()
        end
    elseif kc == Keys.drop then
        if not State.dropEnabled then runDropBrainrot() end
    elseif kc == Keys.lagger then
        State.laggerEnabled = not State.laggerEnabled
        if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerEnabled) end
        if State.laggerEnabled then
            State._prevCarry = State.carrySpeed
            State._prevSpeed = State.speedToggled
            State.speedToggled = false
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
            if carryBox then carryBox.Text = tostring(State.laggerSpeed) end
        else
            State.carrySpeed = State._prevCarry or 30
            State.speedToggled = State._prevSpeed or false
            if carryBox then carryBox.Text = tostring(State.carrySpeed) end
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
        end
    elseif kc == Keys.tpDown then
        doTpDown()
    elseif kc == Keys.aimbot then
        if (not State.batAimbotToggled) and isHoldingBrainrot() then return end
        State.batAimbotToggled = not State.batAimbotToggled
        if State.batAimbotToggled then
            if State.autoLeftEnabled then
                State.autoLeftEnabled = false
                stopAutoLeft()
                if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
            end
            if State.autoRightEnabled then
                State.autoRightEnabled = false
                stopAutoRight()
                if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
            end
            pcall(startBatAimbot)
        else
            stopBatAimbot()
        end
        if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(State.batAimbotToggled) end
    elseif kc == Keys.guiHide then
        if isKb then State.guiVisible = not State.guiVisible; mainOuter.Visible = State.guiVisible end
    end
end)

-- ============================================================
-- INIT (set defaults on)
-- ============================================================
State.infJumpEnabled = true
State.antiRagdollEnabled = true
enableAutoSteal()
startAntiRagdoll()
enableESP()  -- ESP enabled by default
-- Custom FOV off by default

loadConfig()
task.delay(1, function() pcall(saveConfig) end)

print("[apolo Hub v1] Loaded successfully")
game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if State.unwalkEnabled and char:FindFirstChild("Animate") then
        char.Animate.Disabled = true
    end
end)
