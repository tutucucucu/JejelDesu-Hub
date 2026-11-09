--[[
    JejelDesu Basic
    ----------------
    Creator : Ajellys
    Version : 1.0.0
    Auto Aim + ESP untuk executor
    Hotkey: Z (aim), X (esp), M (minimize)
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- KONFIGURASI DEFAULT
-- ============================================================
local Config = {
    AimEnabled = false,
    AimPart = "Head",
    AimTeamCheck = true,
    AimFOV = 120,
    AimSmoothness = 0.15,
    AimMaxDistance = 300,

    EspEnabled = true,
    EspTeamCheck = false,
    EspMaxDistance = 500,
    EspUpdateInterval = 0.15,
    EspShowName = true,
    EspShowHealth = true,
    EspShowDistance = true,
    EspShowTeam = true,
    EspOutline = true,
    EspFillTransparency = 0.75,
    EspOutlineTransparency = 0.15,

    AntiAfkEnabled = false,
}

-- ============================================================
-- FUNGSI BANTU
-- ============================================================
local function getTeamColor(player)
    if player.Team and player.TeamColor then
        return player.TeamColor.Color
    end
    return Color3.fromRGB(255, 255, 255)
end

local function getHealthColor(ratio)
    if ratio > 0.6 then
        return Color3.fromRGB(0, 255, 100)
    elseif ratio > 0.3 then
        return Color3.fromRGB(255, 200, 0)
    else
        return Color3.fromRGB(255, 60, 60)
    end
end

local function isAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- ============================================================
-- CONFIG SAVE / LOAD
-- ============================================================
local configFolder = "JejelDesuBasic"
local configFile = configFolder .. "/config.json"

local function ensureFolder()
    if not isfolder then return end
    if not isfolder(configFolder) then
        pcall(makefolder, configFolder)
    end
end

local function saveConfig()
    if not writefile then return end
    ensureFolder()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Config)
    end)
    if ok and encoded then
        pcall(writefile, configFile, encoded)
    end
end

local function loadConfig()
    if not isfile or not readfile then return false end
    local checkOk, exists = pcall(isfile, configFile)
    if not checkOk or not exists then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(configFile))
    end)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if Config[k] ~= nil and type(Config[k]) == type(v) then
            Config[k] = v
        end
    end
    return true
end

-- load config dulu sebelum UI dibuat
local configLoaded = loadConfig()

-- ============================================================
-- SCREEN GUI -> SAFE PARENT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JejelDesuBasic"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999

local function getSafeGuiParent()
    local ok, result = pcall(function()
        return gethui and gethui() or nil
    end)
    if ok and result then
        print("[JejelDesu] GUI -> gethui()")
        return result
    end
    ok, result = pcall(function()
        return get_hidden_gui and get_hidden_gui() or nil
    end)
    if ok and result then
        print("[JejelDesu] GUI -> get_hidden_gui()")
        return result
    end
    ok, result = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and result then
        print("[JejelDesu] GUI -> CoreGui")
        return result
    end
    print("[JejelDesu] GUI -> PlayerGui (fallback)")
    return LocalPlayer:WaitForChild("PlayerGui")
end

ScreenGui.Parent = getSafeGuiParent()

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    elseif protect_gui then
        protect_gui(ScreenGui)
    end
end)

-- ============================================================
-- STATE
-- ============================================================
local EspObjects = {}
local CurrentTarget = nil
local IsMinimized = false
local IsClosed = false
local afkConnection = nil
local ToggleButtons = {}
local TextBoxes = {}

-- ============================================================
-- TOAST
-- ============================================================
local function toast(msg, duration)
    duration = duration or 2
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromOffset(300, 36)
    t.Position = UDim2.new(0.5, -150, 0, 20)
    t.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    t.Text = "  " .. msg
    t.TextColor3 = Color3.fromRGB(0, 200, 255)
    t.TextScaled = true
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.BorderSizePixel = 0
    t.ZIndex = 200
    t.Parent = ScreenGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = t
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = t
    task.spawn(function()
        task.wait(duration)
        TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
        task.wait(0.4)
        t:Destroy()
    end)
end

-- ============================================================
-- ANTI AFK
-- ============================================================
local function setAntiAfk(enabled)
    if enabled then
        if not afkConnection then
            afkConnection = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    else
        if afkConnection then
            afkConnection:Disconnect()
            afkConnection = nil
        end
    end
end

-- ============================================================
-- LOADING SCREEN
-- ============================================================
local LoadingFrame = Instance.new("Frame")
LoadingFrame.Size = UDim2.fromScale(1, 1)
LoadingFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
LoadingFrame.BorderSizePixel = 0
LoadingFrame.ZIndex = 100
LoadingFrame.Parent = ScreenGui

local LoadingLabel = Instance.new("TextLabel")
LoadingLabel.Size = UDim2.fromScale(0.6, 0.1)
LoadingLabel.Position = UDim2.fromScale(0.2, 0.42)
LoadingLabel.BackgroundTransparency = 1
LoadingLabel.Text = "JejelDesu Basic"
LoadingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadingLabel.TextScaled = true
LoadingLabel.Font = Enum.Font.GothamBold
LoadingLabel.ZIndex = 101
LoadingLabel.Parent = LoadingFrame

local LoadingSub = Instance.new("TextLabel")
LoadingSub.Size = UDim2.fromScale(0.4, 0.03)
LoadingSub.Position = UDim2.fromScale(0.3, 0.51)
LoadingSub.BackgroundTransparency = 1
LoadingSub.Text = "by Ajellys"
LoadingSub.TextColor3 = Color3.fromRGB(0, 200, 255)
LoadingSub.TextScaled = true
LoadingSub.Font = Enum.Font.Gotham
LoadingSub.ZIndex = 101
LoadingSub.Parent = LoadingFrame

local LoadingBarBg = Instance.new("Frame")
LoadingBarBg.Size = UDim2.fromScale(0.4, 0.02)
LoadingBarBg.Position = UDim2.fromScale(0.3, 0.56)
LoadingBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
LoadingBarBg.BorderSizePixel = 0
LoadingBarBg.ZIndex = 101
LoadingBarBg.Parent = LoadingFrame

local LoadingBarFill = Instance.new("Frame")
LoadingBarFill.Size = UDim2.fromScale(0, 1)
LoadingBarFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
LoadingBarFill.BorderSizePixel = 0
LoadingBarFill.ZIndex = 102
LoadingBarFill.Parent = LoadingBarBg

local LoadingStatus = Instance.new("TextLabel")
LoadingStatus.Size = UDim2.fromScale(0.4, 0.04)
LoadingStatus.Position = UDim2.fromScale(0.3, 0.59)
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Text = configLoaded and "Memuat config..." or "Memuat..."
LoadingStatus.TextColor3 = Color3.fromRGB(180, 180, 180)
LoadingStatus.TextScaled = true
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.ZIndex = 101
LoadingStatus.Parent = LoadingFrame

task.spawn(function()
    for i = 1, 20 do
        LoadingBarFill.Size = UDim2.fromScale(i / 20, 1)
        LoadingStatus.Text = string.format("%s %d%%", configLoaded and "Memuat config..." or "Memuat...", i * 5)
        task.wait(0.04)
    end
    task.wait(0.2)
    TweenService:Create(LoadingFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(LoadingLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
    TweenService:Create(LoadingSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
    TweenService:Create(LoadingBarBg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(LoadingBarFill, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(LoadingStatus, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
    task.wait(0.5)
    LoadingFrame.Visible = false
    LoadingFrame:Destroy()
end)

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Size = UDim2.fromOffset(480, 500)
MainFrame.Position = UDim2.fromScale(0.3, 0.15)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Color = Color3.fromRGB(0, 180, 255)
MainStroke.Transparency = 0.2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = MainFrame

-- Drag bar
local DragBar = Instance.new("Frame")
DragBar.Size = UDim2.new(1, 0, 0, 36)
DragBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
DragBar.BorderSizePixel = 0
DragBar.Parent = MainFrame

local DragBarCorner = Instance.new("UICorner")
DragBarCorner.CornerRadius = UDim.new(0, 8)
DragBarCorner.Parent = DragBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.fromOffset(10, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "JejelDesu Basic"
TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = DragBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(28, 28)
MinBtn.Position = UDim2.new(1, -70, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextScaled = true
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = false
MinBtn.Parent = DragBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(28, 28)
CloseBtn.Position = UDim2.new(1, -38, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextScaled = true
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = DragBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

-- Content
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -36)
ContentFrame.Position = UDim2.fromOffset(0, 36)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local TabsFrame = Instance.new("Frame")
TabsFrame.Size = UDim2.new(1, 0, 0, 32)
TabsFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
TabsFrame.BorderSizePixel = 0
TabsFrame.Parent = ContentFrame

local function createTab(text, index, total)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/total, 0, 1, 0)
    btn.Position = UDim2.new((index-1)/total, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = TabsFrame
    return btn
end

local TOTAL_TABS = 4
local MainTabBtn = createTab("Main", 1, TOTAL_TABS)
local AimTabBtn = createTab("Auto Aim", 2, TOTAL_TABS)
local EspTabBtn = createTab("ESP", 3, TOTAL_TABS)
local SettingsTabBtn = createTab("Settings", 4, TOTAL_TABS)

local function makePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, -32)
    page.Position = UDim2.fromOffset(0, 32)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 200)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    page.Parent = ContentFrame
    return page
end

local MainPage = makePage()
local AimPage = makePage()
local EspPage = makePage()
local SettingsPage = makePage()

local function selectTab(name)
    MainPage.Visible = (name == "Main")
    AimPage.Visible = (name == "Aim")
    EspPage.Visible = (name == "Esp")
    SettingsPage.Visible = (name == "Settings")
    MainTabBtn.TextColor3 = (name == "Main") and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 150, 150)
    AimTabBtn.TextColor3 = (name == "Aim") and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 150, 150)
    EspTabBtn.TextColor3 = (name == "Esp") and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 150, 150)
    SettingsTabBtn.TextColor3 = (name == "Settings") and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 150, 150)
end
selectTab("Main")

MainTabBtn.MouseButton1Click:Connect(function() selectTab("Main") end)
AimTabBtn.MouseButton1Click:Connect(function() selectTab("Aim") end)
EspTabBtn.MouseButton1Click:Connect(function() selectTab("Esp") end)
SettingsTabBtn.MouseButton1Click:Connect(function() selectTab("Settings") end)

-- ============================================================
-- TOGGLE HELPER
-- ============================================================
local function refreshToggleUI(configKey)
    local btn = ToggleButtons[configKey]
    if not btn then return end
    local val = Config[configKey]
    btn.BackgroundColor3 = val and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(60, 60, 70)
    btn.Text = val and "ON" or "OFF"
end

local function createToggle(parent, text, y, configKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 32)
    frame.Position = UDim2.fromOffset(10, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(40, 20)
    btn.Position = UDim2.new(1, -40, 0.5, -10)
    btn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(60, 60, 70)
    btn.Text = Config[configKey] and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    ToggleButtons[configKey] = btn

    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        refreshToggleUI(configKey)
        if configKey == "AntiAfkEnabled" then
            setAntiAfk(Config.AntiAfkEnabled)
        end
        saveConfig()
    end)

    return frame
end

-- ============================================================
-- TEXTBOX HELPER
-- ============================================================
local function createTextBoxRow(parent, text, y, configKey, min, max, isInt)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 32)
    frame.Position = UDim2.fromOffset(10, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(80, 24)
    box.Position = UDim2.new(0.6, 0, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    box.Text = tostring(Config[configKey])
    box.TextColor3 = Color3.fromRGB(0, 200, 255)
    box.TextScaled = true
    box.Font = Enum.Font.Gotham
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = box

    TextBoxes[configKey] = box

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            Config[configKey] = math.clamp(n, min, max)
        end
        if isInt then
            Config[configKey] = math.floor(Config[configKey])
        end
        box.Text = tostring(Config[configKey])
        saveConfig()
    end)

    return frame
end

-- ============================================================
-- BUTTON HELPER
-- ============================================================
local function createButton(parent, text, y, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 34)
    btn.Position = UDim2.fromOffset(10, y)
    btn.BackgroundColor3 = color or Color3.fromRGB(40, 40, 48)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- ============================================================
-- MAIN PAGE
-- ============================================================
local function createLabel(parent, text, y, color, bold, height, size)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, height or 22)
    lbl.Position = UDim2.fromOffset(10, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(220, 220, 220)
    lbl.TextScaled = true
    lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

createLabel(MainPage, "JejelDesu Basic", 10, Color3.fromRGB(0, 200, 255), true, 28)
createLabel(MainPage, "Creator: Ajellys", 42, Color3.fromRGB(200, 200, 200), false, 20)
createLabel(MainPage, "Version: 1.0.0", 66, Color3.fromRGB(200, 200, 200), false, 20)
createLabel(MainPage, "Dibuat: 09 November 2026", 90, Color3.fromRGB(200, 200, 200), false, 20)

local divLine = Instance.new("Frame")
divLine.Size = UDim2.new(1, -20, 0, 1)
divLine.Position = UDim2.fromOffset(10, 120)
divLine.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
divLine.BorderSizePixel = 0
divLine.Parent = MainPage

createLabel(MainPage, "INFO PLAYER", 132, Color3.fromRGB(0, 200, 255), true, 22)
local infoNamaLbl = createLabel(MainPage, "Nama: -", 160)
local infoUidLbl = createLabel(MainPage, "UserID: -", 184)
local infoTeamLbl = createLabel(MainPage, "Team: -", 208)
local infoHpLbl = createLabel(MainPage, "Health: -", 232)

task.spawn(function()
    while not IsClosed do
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local team = LocalPlayer.Team
        infoNamaLbl.Text = "Nama: " .. LocalPlayer.Name
        infoUidLbl.Text = "UserID: " .. tostring(LocalPlayer.UserId)
        infoTeamLbl.Text = "Team: " .. (team and team.Name or "Tidak ada")
        if team then
            infoTeamLbl.TextColor3 = team.TeamColor and team.TeamColor.Color or Color3.fromRGB(220, 220, 220)
        else
            infoTeamLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        if hum then
            infoHpLbl.Text = string.format("Health: %d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
            infoHpLbl.TextColor3 = getHealthColor(hum.Health / math.max(hum.MaxHealth, 1))
        else
            infoHpLbl.Text = "Health: -"
        end
        task.wait(1)
    end
end)

-- ============================================================
-- AIM PAGE
-- ============================================================
createToggle(AimPage, "Aktifkan Auto Aim", 5, "AimEnabled")
createToggle(AimPage, "Team Check", 40, "AimTeamCheck")

-- Bagian target (custom button)
local partFrame = Instance.new("Frame")
partFrame.Size = UDim2.new(1, -20, 0, 32)
partFrame.Position = UDim2.fromOffset(10, 80)
partFrame.BackgroundTransparency = 1
partFrame.Parent = AimPage

local partLabel = Instance.new("TextLabel")
partLabel.Size = UDim2.new(0.5, 0, 1, 0)
partLabel.BackgroundTransparency = 1
partLabel.Text = "Bagian Target"
partLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
partLabel.TextScaled = true
partLabel.Font = Enum.Font.Gotham
partLabel.TextXAlignment = Enum.TextXAlignment.Left
partLabel.Parent = partFrame

local partBtn = Instance.new("TextButton")
partBtn.Size = UDim2.fromOffset(120, 24)
partBtn.Position = UDim2.new(0.5, 0, 0.5, -12)
partBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
partBtn.Text = Config.AimPart
partBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
partBtn.TextScaled = true
partBtn.Font = Enum.Font.Gotham
partBtn.BorderSizePixel = 0
partBtn.AutoButtonColor = false
partBtn.Parent = partFrame

local partCorner = Instance.new("UICorner")
partCorner.CornerRadius = UDim.new(0, 4)
partCorner.Parent = partBtn

local aimPartsList = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Random"}
partBtn.MouseButton1Click:Connect(function()
    local idx = table.find(aimPartsList, Config.AimPart) or 1
    idx = idx % #aimPartsList + 1
    Config.AimPart = aimPartsList[idx]
    partBtn.Text = Config.AimPart
    saveConfig()
end)

createTextBoxRow(AimPage, "FOV", 120, "AimFOV", 10, 360, true)
createTextBoxRow(AimPage, "Smoothness (0-1)", 160, "AimSmoothness", 0, 1, false)
createTextBoxRow(AimPage, "Max Jarak (studs)", 200, "AimMaxDistance", 50, 2000, true)

createLabel(AimPage, "Hotkey: Z  (toggle Auto Aim)", 250, Color3.fromRGB(0, 200, 255), false, 22)

-- ============================================================
-- ESP PAGE
-- ============================================================
createToggle(EspPage, "Aktifkan ESP", 5, "EspEnabled")
createToggle(EspPage, "Team Check (hanya enemy)", 40, "EspTeamCheck")
createToggle(EspPage, "Tampilkan Nama", 75, "EspShowName")
createToggle(EspPage, "Tampilkan HP", 110, "EspShowHealth")
createToggle(EspPage, "Tampilkan Jarak", 145, "EspShowDistance")
createToggle(EspPage, "Tampilkan Tim", 180, "EspShowTeam")
createToggle(EspPage, "Outline Karakter", 215, "EspOutline")
createTextBoxRow(EspPage, "Max Jarak (studs)", 255, "EspMaxDistance", 50, 2000, true)
createTextBoxRow(EspPage, "Update Interval (s)", 295, "EspUpdateInterval", 0.05, 1, false)

createLabel(EspPage, "Hotkey: X  (toggle ESP)", 340, Color3.fromRGB(0, 200, 255), false, 22)

-- ============================================================
-- SETTINGS PAGE
-- ============================================================
createLabel(SettingsPage, "HOTKEY", 5, Color3.fromRGB(0, 200, 255), true, 22)
createLabel(SettingsPage, "Z  =  Toggle Auto Aim", 30, Color3.fromRGB(200, 200, 200), false, 20)
createLabel(SettingsPage, "X  =  Toggle ESP", 52, Color3.fromRGB(200, 200, 200), false, 20)
createLabel(SettingsPage, "M  =  Minimize / Maximize", 74, Color3.fromRGB(200, 200, 200), false, 20)

local divLine2 = Instance.new("Frame")
divLine2.Size = UDim2.new(1, -20, 0, 1)
divLine2.Position = UDim2.fromOffset(10, 104)
divLine2.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
divLine2.BorderSizePixel = 0
divLine2.Parent = SettingsPage

createToggle(SettingsPage, "Anti AFK", 115, "AntiAfkEnabled")

createButton(SettingsPage, "Rejoin Server", 155, function()
    saveConfig()
    toast("Rejoining...")
    task.wait(0.5)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not ok then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end, Color3.fromRGB(0, 130, 200))

createButton(SettingsPage, "Off All (matikan semua fitur)", 195, function()
    Config.AimEnabled = false
    Config.EspEnabled = false
    Config.AntiAfkEnabled = false
    refreshToggleUI("AimEnabled")
    refreshToggleUI("EspEnabled")
    refreshToggleUI("AntiAfkEnabled")
    setAntiAfk(false)
    saveConfig()
    toast("Semua fitur OFF")
end, Color3.fromRGB(200, 130, 0))

createButton(SettingsPage, "Reset Config (kembali ke default)", 235, function()
    Config.AimEnabled = false
    Config.AimPart = "Head"
    Config.AimTeamCheck = true
    Config.AimFOV = 120
    Config.AimSmoothness = 0.15
    Config.AimMaxDistance = 300
    Config.EspEnabled = true
    Config.EspTeamCheck = false
    Config.EspMaxDistance = 500
    Config.EspUpdateInterval = 0.15
    Config.EspShowName = true
    Config.EspShowHealth = true
    Config.EspShowDistance = true
    Config.EspShowTeam = true
    Config.EspOutline = true
    Config.EspFillTransparency = 0.75
    Config.EspOutlineTransparency = 0.15
    Config.AntiAfkEnabled = false

    for key, _ in pairs(ToggleButtons) do
        refreshToggleUI(key)
    end
    for key, box in pairs(TextBoxes) do
        box.Text = tostring(Config[key])
    end
    partBtn.Text = Config.AimPart
    setAntiAfk(false)
    saveConfig()
    toast("Config di-reset ke default")
end, Color3.fromRGB(180, 180, 0))

createButton(SettingsPage, "Load Config (dari file)", 275, function()
    if loadConfig() then
        for key, _ in pairs(ToggleButtons) do
            refreshToggleUI(key)
        end
        for key, box in pairs(TextBoxes) do
            box.Text = tostring(Config[key])
        end
        partBtn.Text = Config.AimPart
        setAntiAfk(Config.AntiAfkEnabled)
        saveConfig()
        toast("Config dimuat dari file")
    else
        toast("Gagal: file config tidak ditemukan")
    end
end, Color3.fromRGB(0, 150, 100))

createLabel(SettingsPage, "Auto-save: " .. (writefile and "Aktif" or "Tidak didukung executor"), 320,
    writefile and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 100, 100), false, 20)

-- ============================================================
-- DRAG & RESIZE
-- ============================================================
local dragDetector = Instance.new("UIDragDetector")
dragDetector.Parent = DragBar

local ResizeHandle = Instance.new("Frame")
ResizeHandle.Size = UDim2.fromOffset(16, 16)
ResizeHandle.Position = UDim2.new(1, -16, 1, -16)
ResizeHandle.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
ResizeHandle.BackgroundTransparency = 0.5
ResizeHandle.BorderSizePixel = 0
ResizeHandle.Parent = MainFrame

local ResizeCorner = Instance.new("UICorner")
ResizeCorner.CornerRadius = UDim.new(0, 4)
ResizeCorner.Parent = ResizeHandle

local resizing = false
local resizeStart = nil
local startSize = nil

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = MainFrame.AbsoluteSize
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newX = math.max(360, startSize.X + delta.X)
        local newY = math.max(280, startSize.Y + delta.Y)
        MainFrame.Size = UDim2.fromOffset(newX, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

-- Minimize
local originalSize = MainFrame.Size
local function toggleMinimize()
    IsMinimized = not IsMinimized
    if IsMinimized then
        originalSize = MainFrame.Size
        local curW = MainFrame.AbsoluteSize.X
        TweenService:Create(MainFrame, TweenInfo.new(0.2), { Size = UDim2.fromOffset(curW, 36) }):Play()
        ContentFrame.Visible = false
        ResizeHandle.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), { Size = originalSize }):Play()
        task.wait(0.21)
        ContentFrame.Visible = true
        ResizeHandle.Visible = true
    end
end

MinBtn.MouseButton1Click:Connect(toggleMinimize)

CloseBtn.MouseButton1Click:Connect(function()
    saveConfig()
    IsClosed = true
    for player, _ in pairs(EspObjects) do
        local data = EspObjects[player]
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        EspObjects[player] = nil
    end
    setAntiAfk(false)
    ScreenGui:Destroy()
end)

-- ============================================================
-- ESP LOGIC
-- ============================================================
local function createESPForPlayer(player)
    if player == LocalPlayer then return end
    if EspObjects[player] then return end
    local character = player.Character
    if not character then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JejelESP"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = Config.EspFillTransparency
    highlight.OutlineTransparency = Config.EspOutlineTransparency
    highlight.FillColor = getTeamColor(player)
    highlight.OutlineColor = getTeamColor(player)
    highlight.Parent = ScreenGui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "JejelInfo"
    billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.fromOffset(200, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = Config.EspMaxDistance
    billboard.Parent = ScreenGui

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.fromScale(1, 1)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = getTeamColor(player)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = infoFrame

    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 0.33, 0)
    healthLabel.Position = UDim2.fromScale(0, 0.33)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "HP: 100"
    healthLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    healthLabel.TextScaled = true
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.Parent = infoFrame

    local distInfoLabel = Instance.new("TextLabel")
    distInfoLabel.Size = UDim2.new(1, 0, 0.34, 0)
    distInfoLabel.Position = UDim2.fromScale(0, 0.66)
    distInfoLabel.BackgroundTransparency = 1
    distInfoLabel.Text = "0 studs"
    distInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distInfoLabel.TextScaled = true
    distInfoLabel.Font = Enum.Font.Gotham
    distInfoLabel.Parent = infoFrame

    local teamLabel = Instance.new("TextLabel")
    teamLabel.Size = UDim2.new(1, 0, 0.2, 0)
    teamLabel.Position = UDim2.fromScale(0, -0.2)
    teamLabel.BackgroundTransparency = 1
    teamLabel.Text = player.Team and player.Team.Name or "No Team"
    teamLabel.TextColor3 = getTeamColor(player)
    teamLabel.TextScaled = true
    teamLabel.Font = Enum.Font.Gotham
    teamLabel.Parent = infoFrame

    EspObjects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        HealthLabel = healthLabel,
        DistLabel = distInfoLabel,
        TeamLabel = teamLabel,
        Character = character,
    }
end

local function removeESP(player)
    local data = EspObjects[player]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    EspObjects[player] = nil
end

local function updateESP()
    for player, _ in pairs(EspObjects) do
        if not player.Parent or not isAlive(player.Character) or not Config.EspEnabled then
            removeESP(player)
        end
    end
    if not Config.EspEnabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local character = player.Character
        if not character or not isAlive(character) then
            removeESP(player)
            continue
        end
        if Config.EspTeamCheck and player.Team == LocalPlayer.Team then
            removeESP(player)
            continue
        end
        local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        if not root then continue end
        local distance = (Camera.CFrame.Position - root.Position).Magnitude
        if distance > Config.EspMaxDistance then
            removeESP(player)
            continue
        end
        if not EspObjects[player] then
            createESPForPlayer(player)
        end
        local data = EspObjects[player]
        if not data then continue end

        local teamColor = getTeamColor(player)
        if data.Highlight then
            data.Highlight.FillColor = teamColor
            data.Highlight.OutlineColor = teamColor
            data.Highlight.Enabled = Config.EspOutline
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and data.HealthLabel then
            local hpRatio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
            data.HealthLabel.Text = string.format("HP: %d", math.floor(humanoid.Health))
            data.HealthLabel.TextColor3 = getHealthColor(hpRatio)
        end
        if data.NameLabel then
            data.NameLabel.Text = player.Name
            data.NameLabel.TextColor3 = teamColor
            data.NameLabel.Visible = Config.EspShowName
        end
        if data.DistLabel then
            data.DistLabel.Text = string.format("%d studs", math.floor(distance))
            data.DistLabel.Visible = Config.EspShowDistance
        end
        if data.TeamLabel then
            data.TeamLabel.Text = player.Team and player.Team.Name or "No Team"
            data.TeamLabel.TextColor3 = teamColor
            data.TeamLabel.Visible = Config.EspShowTeam
        end
        if data.HealthLabel then
            data.HealthLabel.Visible = Config.EspShowHealth
        end
        if data.Billboard then
            data.Billboard.MaxDistance = Config.EspMaxDistance
            data.Billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        end
    end
end

task.spawn(function()
    while not IsClosed do
        updateESP()
        task.wait(Config.EspUpdateInterval)
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if Config.EspEnabled then
            createESPForPlayer(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character and Config.EspEnabled then
            task.wait(0.05)
            createESPForPlayer(player)
        end
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if Config.EspEnabled then
                createESPForPlayer(player)
            end
        end)
    end
end

-- ============================================================
-- AIM LOGIC
-- ============================================================
local function getAimPart(character)
    local targetPartName = Config.AimPart
    if targetPartName == "Random" then
        local options = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        targetPartName = options[math.random(1, #options)]
    end
    return character:FindFirstChild(targetPartName)
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Head")
end

local function findTarget()
    local closest = nil
    local shortestDist = math.huge
    local cameraPos = Camera.CFrame.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.AimTeamCheck and player.Team == LocalPlayer.Team then continue end
        local character = player.Character
        if not character or not isAlive(character) then continue end
        local aimPart = getAimPart(character)
        if not aimPart then continue end
        local distance = (cameraPos - aimPart.Position).Magnitude
        if distance > Config.AimMaxDistance then continue end
        local lookVector = Camera.CFrame.LookVector
        local direction = (aimPart.Position - cameraPos).Unit
        local dot = lookVector:Dot(direction)
        local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
        if angle <= Config.AimFOV / 2 then
            if distance < shortestDist then
                shortestDist = distance
                closest = { Player = player, Part = aimPart, Character = character }
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function(dt)
    if not Config.AimEnabled or IsClosed then
        CurrentTarget = nil
        return
    end
    local target = findTarget()
    CurrentTarget = target
    if target and target.Part then
        local targetPos = target.Part.Position
        local currentCF = Camera.CFrame
        local desiredCF = CFrame.lookAt(currentCF.Position, targetPos)
        local smooth = Config.AimSmoothness
        if smooth <= 0 then
            Camera.CFrame = desiredCF
        else
            Camera.CFrame = currentCF:Lerp(desiredCF, math.clamp(dt / smooth, 0, 1))
        end
    end
end)

-- ============================================================
-- HOTKEY SYSTEM
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if IsClosed then return end
    local focused = UserInputService:GetFocusedTextBox()
    if focused then return end

    local key = input.KeyCode
    if key == Enum.KeyCode.Z then
        Config.AimEnabled = not Config.AimEnabled
        refreshToggleUI("AimEnabled")
        saveConfig()
        toast("Auto Aim: " .. (Config.AimEnabled and "ON" or "OFF"))
    elseif key == Enum.KeyCode.X then
        Config.EspEnabled = not Config.EspEnabled
        refreshToggleUI("EspEnabled")
        saveConfig()
        toast("ESP: " .. (Config.EspEnabled and "ON" or "OFF"))
    elseif key == Enum.KeyCode.M then
        toggleMinimize()
    end
end)

-- ============================================================
-- APPLY INITIAL STATE
-- ============================================================
if Config.AntiAfkEnabled then
    setAntiAfk(true)
end

-- ============================================================
-- CLEANUP
-- ============================================================
ScreenGui.AncestryChanged:Connect(function()
    if not ScreenGui.Parent then
        IsClosed = true
        for player, _ in pairs(EspObjects) do
            removeESP(player)
        end
        setAntiAfk(false)
    end
end)

print("[JejelDesu] Loaded. Config " .. (configLoaded and "dimuat dari file" or "menggunakan default"))
print("[JejelDesu] Hotkey: Z=aim, X=esp, M=minimize")
