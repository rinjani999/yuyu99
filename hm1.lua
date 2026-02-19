local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")

local cloneref = cloneref or function(o) return o end
local gethui = gethui or function() return CoreGui end

local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))
local LogService = cloneref(game:GetService("LogService"))
local GuiService = cloneref(game:GetService("GuiService"))

local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local TOGGLE_KEY = Enum.KeyCode.RightControl
local MIN_CPM = 50
local MAX_CPM_LEGIT = 1500
local MAX_CPM_BLATANT = 2000

math.randomseed(os.time())

-- Auto-hide leaderboard (prevents it from popping up on server switch)
pcall(function()
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local THEME = {
    Background = Color3.fromRGB(20, 20, 24),
    ItemBG = Color3.fromRGB(32, 32, 38),
    Accent = Color3.fromRGB(114, 100, 255),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    Success = Color3.fromRGB(100, 255, 140),
    Warning = Color3.fromRGB(255, 200, 80),
    Slider = Color3.fromRGB(60, 60, 70)
}

local function ColorToRGB(c)
    return string.format("%d,%d,%d", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- Pre-cached color strings (avoid recalculating every frame)
local ACCENT_RGB
local TEXT_RGB

local ConfigFile = "WordHelper_Config.json"
local Config = {
    CPM = 770,
    BlatantMode = "Auto", -- "Off", "On", "Auto"
    BlatantThreshold = 6,
    Humanize = true,
    FingerModel = true,
    SortMode = "Random",
    SuffixMode = "",
    LengthMode = 0,
    AutoPlay = true,
    AutoJoin = false,
    AutoJoinSettings = {
        _1v1 = true,
        _4p = false,
        _8p = false
    },
    ShowKeyboard = false,
    ErrorRate = 1,
    ThinkDelay = 0.4,
    RiskyMistakes = true,
    CustomWords = {},
    MinTypeSpeed = 50,
    MaxTypeSpeed = 3000,
    Transparency = 0.35,
    KaburMode = false,
    KaburThreshold = 300,
    KaburWaitRound = true,
    AutoTeleportLow = true
}

local function SaveConfig()
    if writefile then
        writefile(ConfigFile, HttpService:JSONEncode(Config))
    end
end


local function LoadConfig()
    if isfile and isfile(ConfigFile) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(ConfigFile)) end)
        if success and decoded then
            for k, v in pairs(decoded) do Config[k] = v end
        end
    end
end
LoadConfig()

-- Force override: these values always use script defaults, ignoring saved config
Config.BlatantThreshold = 6
Config.KaburThreshold = 300

local currentCPM = Config.CPM
local blatantMode = Config.BlatantMode or "Off"
local blatantThreshold = Config.BlatantThreshold or 6
local isBlatant = (blatantMode == "On")
local useHumanization = Config.Humanize
local useFingerModel = Config.FingerModel
local sortMode = Config.SortMode
local suffixMode = Config.SuffixMode or ""
local lengthMode = Config.LengthMode or 0
local autoPlay = Config.AutoPlay
local autoJoin = Config.AutoJoin
local showKeyboard = Config.ShowKeyboard
local errorRate = Config.ErrorRate
local thinkDelayCurrent = Config.ThinkDelay
local riskyMistakes = Config.RiskyMistakes
local uiTransparency = Config.Transparency or 0.35
local kaburMode = Config.KaburMode or false
local kaburThreshold = Config.KaburThreshold or 300
local kaburWaitRound = Config.KaburWaitRound ~= false
local autoTeleportLow = Config.AutoTeleportLow or false

local StatsData = {}
local savedBlatantSettings = nil
local lastTimerValue = 0
local lastTimerChangeTick = tick()

local isTyping = false
local isAutoPlayScheduled = false
local lastTypingStart = 0
local runConn = nil
local inputConn = nil
local logConn = nil
local unloaded = false
local isMyTurnLogDetected = false
local logRequiredLetters = ""
local turnExpiryTime = 0
local Blacklist = {}
local UsedWords = {}
local RandomOrderCache = {}
local RandomPriority = {}
local lastDetected = "---"
local lastLogicUpdate = 0
local lastAutoJoinCheck = 0
local lastWordCheck = 0
local cachedDetected = ""
local cachedCensored = false
local LOGIC_RATE = 0.1
local AUTO_JOIN_RATE = 0.5
local UpdateList
local ButtonCache = {}
local ButtonData = {}
local JoinDebounce = {}
local thinkDelayMin = 0.4
local thinkDelayMax = 1.2
local lastKaburCheck = 0
local KABUR_CHECK_RATE = 10
local kaburAttempts = 0
local MAX_KABUR_ATTEMPTS = 100
local isKaburTeleporting = false
local lastLowPlayerCheck = 0
local LOW_PLAYER_CHECK_RATE = 15
local lowPlayerAttempts = 0
local MAX_LOW_ATTEMPTS = 20
local isLowTeleporting = false
local scriptStartTime = tick()

local GAME_GROUP_ID = 35222573
local DANGER_RANK = 2
local GroupRankCache = {}

local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil
local lastPanicKey = ""
local cachedPanicWord = nil

if logConn then logConn:Disconnect() end
logConn = LogService.MessageOut:Connect(function(message, type)
    local wordPart, timePart = message:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
    if wordPart and timePart then
        isMyTurnLogDetected = true
        logRequiredLetters = wordPart
        turnExpiryTime = tick() + tonumber(timePart)
    end
end)

local url = "https://find.wagate.biz.id/tralala.txt"
local fileName = "tralala.txt"

-- Temporary Loading UI
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "WordHelperLoading"
local success, parent = pcall(function() return gethui() end)
if not success or not parent then parent = game:GetService("CoreGui") end
LoadingGui.Parent = parent
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local LoadingFrame = Instance.new("Frame", LoadingGui)
LoadingFrame.Size = UDim2.new(0, 225, 0, 75)
LoadingFrame.Position = UDim2.new(0.5, -112, 0.4, 0)
LoadingFrame.BackgroundColor3 = THEME.Background
LoadingFrame.BorderSizePixel = 0
Instance.new("UICorner", LoadingFrame).CornerRadius = UDim.new(0, 7)
local LStroke = Instance.new("UIStroke", LoadingFrame)
LStroke.Color = THEME.Accent
LStroke.Transparency = 0.5
LStroke.Thickness = 2

local LoadingTitle = Instance.new("TextLabel", LoadingFrame)
LoadingTitle.Size = UDim2.new(1, 0, 0, 30)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Text = "Power - V5"
LoadingTitle.TextColor3 = THEME.Accent
LoadingTitle.Font = Enum.Font.GothamBold
LoadingTitle.TextSize = 14

local LoadingStatus = Instance.new("TextLabel", LoadingFrame)
LoadingStatus.Size = UDim2.new(1, -15, 0, 22)
LoadingStatus.Position = UDim2.new(0, 7, 0, 37)
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Text = "Initializing..."
LoadingStatus.TextColor3 = THEME.Text
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.TextSize = 10

local function UpdateStatus(text, color)
    LoadingStatus.Text = text
    if color then LoadingStatus.TextColor3 = color end
    game:GetService("RunService").RenderStepped:Wait()
end

-- Startup: Always fetch fresh word list
local function FetchWords()
    UpdateStatus("Fetching latest word list...", THEME.Warning)
    local success, res = pcall(function()
        return request({Url = url, Method = "GET"})
    end)
    
    if success and res and res.Body then
        writefile(fileName, res.Body)
        UpdateStatus("Fetched successfully!", THEME.Success)
    else
        UpdateStatus("Fetch failed! Using cached.", Color3.fromRGB(255, 80, 80))
    end
    task.wait(0.5)
end

FetchWords()

local Words = {}
local SeenWords = {}

local function LoadList(fname)
    UpdateStatus("Parsing word list...", THEME.Warning)
    if isfile(fname) then
        local content = readfile(fname)
        for w in content:gmatch("[^\r\n]+") do
            local clean = w:gsub("[%s%c]+", ""):lower()
            if #clean > 0 and not SeenWords[clean] then
                SeenWords[clean] = true
                table.insert(Words, clean)
            end
        end
        UpdateStatus("Loaded " .. #Words .. " words!", THEME.Success)
    else
         UpdateStatus("No word list found!", Color3.fromRGB(255, 80, 80))
    end
    task.wait(1)
end

LoadList(fileName)

if LoadingGui then LoadingGui:Destroy() end

table.sort(Words)
Buckets = {}
for _, w in ipairs(Words) do
    local c = w:sub(1,1) or ""
    if c == "" then c = "#" end
    Buckets[c] = Buckets[c] or {}
    table.insert(Buckets[c], w)
end

if Config.CustomWords then
    for _, w in ipairs(Config.CustomWords) do
        local clean = w:gsub("[%s%c]+", ""):lower()
        if #clean > 0 and not SeenWords[clean] then
            SeenWords[clean] = true
            table.insert(Words, clean)
            local c = clean:sub(1,1) or ""
            if c == "" then c = "#" end
            Buckets[c] = Buckets[c] or {}
            table.insert(Buckets[c], clean)
        end
    end
end

-- Build WordSet for O(1) lookups
local WordSet = {}
for _, w in ipairs(Words) do
    WordSet[w] = true
end

-- Clear memory
SeenWords = nil

local function shuffleTable(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local KillerSuffixes = {
    "bt", "bv", "coog", "dz", "edo", "fd", "fs", "kut",
    "mb", "hl", "mz", "qw", "rg", "rw", "lons",
    "sz", "bk", "vy", "yc", "yp", "trix", "bp", "pg", "naka", "uba", "ils", "pm"
}

local KillerCharScores = {x=10, z=9, q=9, j=8, v=6, k=5, b=4, f=3, w=3, y=2, g=2, p=2}

local function GetKillerScore(word)
    local wLen = #word
    for _, suffix in ipairs(KillerSuffixes) do
        local sLen = #suffix
        if wLen >= sLen and word:sub(-sLen) == suffix then
            return (sLen * 20)
        end
    end
    return KillerCharScores[word:sub(-1)] or 0
end

-- Levenshtein distance function removed (unused dead code)

local function Tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function GetCurrentGameWord(providedFrame)
    local frame = providedFrame
    if not frame then
        local player = Players.LocalPlayer
        local gui = player and player:FindFirstChild("PlayerGui")
        local inGame = gui and gui:FindFirstChild("InGame")
        frame = inGame and inGame:FindFirstChild("Frame")
    end

    local container = frame and frame:FindFirstChild("CurrentWord")
    if not container then return "", false end
    
    local detected = ""
    local censored = false
    
    local children = container:GetChildren()
    local letterData = {}
    
    for _, c in ipairs(children) do
        if c:IsA("GuiObject") and c.Visible then
            local txt = c:FindFirstChild("Letter")
            if txt and txt:IsA("TextLabel") and txt.TextTransparency < 1 then
                table.insert(letterData, {
                    Obj = c,
                    Txt = txt,
                    X = c.AbsolutePosition.X,
                    Id = tonumber(c.Name) or 0
                })
            end
        end
    end
    
    table.sort(letterData, function(a,b)
        if math.abs(a.X - b.X) > 2 then
            return a.X < b.X
        end
        return a.Id < b.Id
    end)

    for _, data in ipairs(letterData) do
        local t = tostring(data.Txt.Text)
        if t:find("#") or t:find("%*") then censored = true end
        detected = detected .. t
    end
    
    return detected:lower():gsub(" ", ""), censored
end

local function GetTurnInfo(providedFrame)
    if isMyTurnLogDetected then
        if tick() < turnExpiryTime then
            return true, logRequiredLetters
        else
            isMyTurnLogDetected = false
        end
    end

    local frame = providedFrame
    if not frame then
        local player = Players.LocalPlayer
        local gui = player and player:FindFirstChild("PlayerGui")
        local inGame = gui and gui:FindFirstChild("InGame")
        frame = inGame and inGame:FindFirstChild("Frame")
    end

    local typeLbl = frame and frame:FindFirstChild("Type")
    
    if typeLbl and typeLbl:IsA("TextLabel") then
        local text = typeLbl.Text
        local player = Players.LocalPlayer
        if text:sub(1, #player.Name) == player.Name or text:sub(1, #player.DisplayName) == player.DisplayName then
            local char = text:match("starting with:%s*([A-Za-z])")
            return true, char
        end
    end
    return false, nil
end

local function GetSecureParent()
    local success, result = pcall(function()
        return gethui()
    end)
    if success and result then return result end
    
    success, result = pcall(function()
        return CoreGui
    end)
    if success and result then return result end
    
    return Players.LocalPlayer.PlayerGui
end

local ParentTarget = GetSecureParent()
local GuiName = tostring(math.random(1000000, 9999999))

local env = (getgenv and getgenv()) or _G

if env.WordHelperInstance and env.WordHelperInstance.Parent then
    env.WordHelperInstance:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GuiName
ScreenGui.Parent = ParentTarget
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

env.WordHelperInstance = ScreenGui

local ToastContainer = Instance.new("Frame", ScreenGui)
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 225, 1, 0)
ToastContainer.Position = UDim2.new(1, -240, 0, 15)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 100

local function ShowToast(message, type)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 30)
    toast.BackgroundColor3 = THEME.ItemBG
    toast.BorderSizePixel = 0
    toast.BackgroundTransparency = 1
    toast.Parent = ToastContainer
    
    local stroke = Instance.new("UIStroke", toast)
    stroke.Thickness = 1.5
    stroke.Transparency = 1
    
    local color = THEME.Text
    if type == "success" then color = THEME.Success
    elseif type == "warning" then color = THEME.Warning
    elseif type == "error" then color = Color3.fromRGB(255, 80, 80)
    end
    stroke.Color = color
    
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel", toast)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = message
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10
    lbl.TextWrapped = true
    lbl.TextTransparency = 1
    
    Tween(toast, {BackgroundTransparency = 0.1}, 0.3)
    Tween(lbl, {TextTransparency = 0}, 0.3)
    Tween(stroke, {Transparency = 0.2}, 0.3)
    
    task.delay(3, function()
        if toast and toast.Parent then
            Tween(toast, {BackgroundTransparency = 1}, 0.5)
            Tween(lbl, {TextTransparency = 1}, 0.5)
            Tween(stroke, {Transparency = 1}, 0.5)
            task.wait(0.5)
            toast:Destroy()
        end
    end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 225, 0, 34)
MainFrame.Position = UDim2.new(0.5, -112, 0.3, -17)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BackgroundTransparency = uiTransparency
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local function EnableDragging(frame)
    local dragging, dragInput, dragStart, startPos
    local function Update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            Update(input)
        end
    end)
end

EnableDragging(MainFrame)

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 7)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = THEME.Accent
Stroke.Transparency = 0.5
Stroke.Thickness = 2

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = THEME.ItemBG
Header.BackgroundTransparency = uiTransparency
Header.BorderSizePixel = 0

local ShortcutFrame = Instance.new("Frame", Header)
ShortcutFrame.Size = UDim2.new(0, 100, 1, 0)
ShortcutFrame.Position = UDim2.new(0, 5, 0, 0)
ShortcutFrame.BackgroundTransparency = 1

local ShortcutList = Instance.new("UIListLayout", ShortcutFrame)
ShortcutList.FillDirection = Enum.FillDirection.Horizontal
ShortcutList.VerticalAlignment = Enum.VerticalAlignment.Center
ShortcutList.Padding = UDim.new(0, 2)

local function CreateHeaderBtn(text)
    local btn = Instance.new("TextButton", ShortcutFrame)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 7
    btn.Size = UDim2.new(0, 23, 0, 14)
    btn.BackgroundColor3 = THEME.Background
    btn.TextColor3 = THEME.Text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local ShortcutAJ = CreateHeaderBtn("AJ")
local ShortcutAP = CreateHeaderBtn("AP")
local ShortcutHM = CreateHeaderBtn("HM")
local ShortcutS = CreateHeaderBtn("RND")

local function UpdateShortcuts()
    ShortcutAJ.TextColor3 = autoJoin and THEME.Success or Color3.fromRGB(240, 70, 70)
    ShortcutAP.TextColor3 = autoPlay and THEME.Success or Color3.fromRGB(240, 70, 70)
    ShortcutHM.TextColor3 = useHumanization and THEME.Success or Color3.fromRGB(240, 70, 70)
    ShortcutS.Text = (sortMode == "Hell" and "HELL" or "RAND")
    ShortcutS.TextColor3 = (sortMode == "Hell" and THEME.Accent or THEME.Text)
end

local StatsContainer = Instance.new("Frame", Header)
StatsContainer.Name = "StatsContainer"
StatsContainer.Size = UDim2.new(0, 52, 1, 0)
StatsContainer.Position = UDim2.new(1, -124, 0, 0)
StatsContainer.BackgroundTransparency = 1
StatsContainer.Visible = false

local TimerLabel = Instance.new("TextLabel", StatsContainer)
TimerLabel.Size = UDim2.new(1, 0, 0.5, 0)
TimerLabel.Position = UDim2.new(0, 0, 0.1, 0)
TimerLabel.BackgroundTransparency = 1
TimerLabel.Text = "--"
TimerLabel.TextColor3 = THEME.Text
TimerLabel.Font = Enum.Font.GothamBold
TimerLabel.TextSize = 12
TimerLabel.TextXAlignment = Enum.TextXAlignment.Center

local CountLabel = Instance.new("TextLabel", StatsContainer)
CountLabel.Size = UDim2.new(1, 0, 0.4, 0)
CountLabel.Position = UDim2.new(0, 0, 0.5, 0)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = "Words: 0"
CountLabel.TextColor3 = THEME.SubText
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextSize = 8
CountLabel.TextXAlignment = Enum.TextXAlignment.Center

StatsData.Timer = TimerLabel
StatsData.Count = CountLabel
StatsData.Frame = StatsContainer

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = THEME.SubText
MinBtn.Size = UDim2.new(0, 34, 1, 0)
MinBtn.Position = UDim2.new(1, -67, 0, 0)
MinBtn.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Size = UDim2.new(0, 34, 1, 0)
CloseBtn.Position = UDim2.new(1, -34, 0, 0)
CloseBtn.BackgroundTransparency = 1

CloseBtn.MouseButton1Click:Connect(function()
    unloaded = true
    if runConn then runConn:Disconnect() runConn = nil end
    if inputConn then inputConn:Disconnect() inputConn = nil end
    if logConn then logConn:Disconnect() logConn = nil end
    
    for _, btn in ipairs(ButtonCache) do btn:Destroy() end
    table.clear(ButtonCache)

    if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
end)

local StatusFrame = Instance.new("Frame", MainFrame)
StatusFrame.Size = UDim2.new(1, -22, 0, 18)
StatusFrame.Position = UDim2.new(0, 11, 0, 41)
StatusFrame.BackgroundTransparency = 1

local StatusDot = Instance.new("Frame", StatusFrame)
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 0, 0.5, -4)
StatusDot.BackgroundColor3 = THEME.SubText
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel", StatusFrame)
StatusText.Text = "Idle..."
StatusText.RichText = true
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 9
StatusText.TextColor3 = THEME.SubText
StatusText.Size = UDim2.new(1, -15, 1, 0)
StatusText.Position = UDim2.new(0, 15, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left

local SearchFrame = Instance.new("Frame", MainFrame)
SearchFrame.Size = UDim2.new(1, -7, 0, 19)
SearchFrame.Position = UDim2.new(0, 4, 0, 61)
SearchFrame.BackgroundColor3 = THEME.ItemBG
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 6)

local SearchBox = Instance.new("TextBox", SearchFrame)
SearchBox.Size = UDim2.new(1, -20, 1, 0)
SearchBox.Position = UDim2.new(0, 10, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 10
SearchBox.TextColor3 = THEME.Text
SearchBox.PlaceholderText = "Search words..."
SearchBox.PlaceholderColor3 = THEME.SubText
SearchBox.Text = ""
SearchBox.TextXAlignment = Enum.TextXAlignment.Left

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if UpdateList then
        UpdateList(lastDetected, lastRequiredLetter)
    end
end)

local ScrollList = Instance.new("ScrollingFrame", MainFrame)
ScrollList.Size = UDim2.new(1, -7, 1, -165)
ScrollList.Position = UDim2.new(0, 4, 0, 86)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 3
ScrollList.ScrollBarImageColor3 = THEME.Accent
ScrollList.CanvasSize = UDim2.new(0,0,0,0)

local UIListLayout = Instance.new("UIListLayout", ScrollList)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 3)

local SettingsFrame = Instance.new("Frame", MainFrame)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.BackgroundTransparency = uiTransparency
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ClipsDescendants = true

local SlidersFrame = Instance.new("Frame", SettingsFrame)
SlidersFrame.Size = UDim2.new(1, 0, 0, 164)
SlidersFrame.BackgroundTransparency = 1

local sep = Instance.new("Frame", SettingsFrame)
sep.Size = UDim2.new(1, 0, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
sep.Position = UDim2.new(0, 0, 0, 164)

SettingsFrame.Size = UDim2.new(1, 0, 0, 164)
SettingsFrame.Position = UDim2.new(0, 0, 1, -164)
ScrollList.Size = UDim2.new(1, -7, 1, -244)

-- Expand Button and Layout Logic Removed

local function SetupSlider(btn, bg, fill, callback)
    btn.MouseButton1Down:Connect(function()
        local move, rel
        local function Update()
            local mousePos = UserInputService:GetMouseLocation()
            local relX = math.clamp(mousePos.X - bg.AbsolutePosition.X, 0, bg.AbsoluteSize.X)
            local pct = relX / bg.AbsoluteSize.X
            callback(pct)
        end
        Update()
        move = RunService.RenderStepped:Connect(Update)
        rel = UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                if move then move:Disconnect() move = nil end
                if rel then rel:Disconnect() rel = nil end
                SaveConfig()
            end
        end)
    end)
end

-- Frames Generation Logic Removed (Keyboard, Custom Words, Word Browser)

local function CreateDropdown(parent, text, options, default, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0, 97, 0, 18)
    container.BackgroundColor3 = THEME.Background
    container.ZIndex = 10
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)
    
    local mainBtn = Instance.new("TextButton", container)
    mainBtn.Name = "MainButton"
    mainBtn.Size = UDim2.new(1, 0, 1, 0)
    mainBtn.BackgroundTransparency = 1
    mainBtn.Text = text .. ": " .. default
    mainBtn.Font = Enum.Font.GothamMedium
    mainBtn.TextSize = 8
    mainBtn.TextColor3 = THEME.Accent
    mainBtn.ZIndex = 11

    local listFrame = Instance.new("Frame", container)
    listFrame.Size = UDim2.new(1, 0, 0, #options * 18)
    listFrame.Position = UDim2.new(0, 0, 1, 2)
    listFrame.BackgroundColor3 = THEME.ItemBG
    listFrame.Visible = false
    listFrame.ZIndex = 100
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)
    
    local isOpen = false
    
    mainBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        listFrame.Visible = isOpen
        container.ZIndex = isOpen and 100 or 10
    end)
    
    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton", listFrame)
        btn.Size = UDim2.new(1, 0, 0, 18)
        btn.Position = UDim2.new(0, 0, 0, (i-1)*18)
        btn.BackgroundTransparency = 1
        btn.Text = opt
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 8
        btn.TextColor3 = THEME.Text
        btn.ZIndex = 101
        
        btn.MouseButton1Click:Connect(function()
            mainBtn.Text = text .. ": " .. opt
            isOpen = false
            listFrame.Visible = false
            container.ZIndex = 10
            callback(opt)
        end)
    end
    
    return container
end



-- Keyboard Handlers Removed

-- Sliders Removed

local function CreateToggle(text, pos, callback)
    local btn = Instance.new("TextButton", SlidersFrame)
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 8
    btn.TextColor3 = THEME.Success
    btn.BackgroundColor3 = THEME.Background
    btn.Size = UDim2.new(0, 64, 0, 18)
    btn.Position = pos
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        local newState, newText, newColor = callback()
        btn.Text = newText
        btn.TextColor3 = newColor
        UpdateShortcuts()
        SaveConfig()
    end)
    return btn
end

local HumanizeBtn = CreateToggle("Humanize: "..(useHumanization and "ON" or "OFF"), UDim2.new(0, 112, 0, 27), function()
    useHumanization = not useHumanization
    Config.Humanize = useHumanization
    UpdateShortcuts()
    return useHumanization, "Humanize: "..(useHumanization and "ON" or "OFF"), useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
HumanizeBtn.Size = UDim2.new(0, 97, 0, 18)
HumanizeBtn.TextColor3 = useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)

local FingerBtn = CreateToggle("10-Finger: "..(useFingerModel and "ON" or "OFF"), UDim2.new(0, 11, 0, 71), function()
    useFingerModel = not useFingerModel
    Config.FingerModel = useFingerModel
    return useFingerModel, "10-Finger: "..(useFingerModel and "ON" or "OFF"), useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
FingerBtn.Size = UDim2.new(0, 97, 0, 18)
FingerBtn.TextColor3 = useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)

local SortDropdown = CreateDropdown(SlidersFrame, "Sort", {"Random", "Killer", "Hell", "Shortest", "Longest", "Custom"}, sortMode, function(val)
    sortMode = val
    Config.SortMode = val
    lastDetected = "---"
    SaveConfig()
end)
SortDropdown.Position = UDim2.new(0, 11, 0, 5)
SortDropdown.Size = UDim2.new(0, 199, 0, 18)

local AutoBtn = CreateToggle("Auto Play: "..(autoPlay and "ON" or "OFF"), UDim2.new(0, 11, 0, 27), function()
    autoPlay = not autoPlay
    Config.AutoPlay = autoPlay
    UpdateShortcuts()
    return autoPlay, "Auto Play: "..(autoPlay and "ON" or "OFF"), autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoBtn.TextColor3 = autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoBtn.Size = UDim2.new(0, 97, 0, 18)

local AutoJoinBtn = CreateToggle("Auto Join: "..(autoJoin and "ON" or "OFF"), UDim2.new(0, 11, 0, 49), function()
    autoJoin = not autoJoin
    Config.AutoJoin = autoJoin
    UpdateShortcuts()
    return autoJoin, "Auto Join: "..(autoJoin and "ON" or "OFF"), autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoJoinBtn.TextColor3 = autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoJoinBtn.Size = UDim2.new(0, 199, 0, 18)

ShortcutAJ.MouseButton1Click:Connect(function()
    autoJoin = not autoJoin
    Config.AutoJoin = autoJoin
    AutoJoinBtn.Text = "Auto Join: "..(autoJoin and "ON" or "OFF")
    AutoJoinBtn.TextColor3 = autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
    UpdateShortcuts()
    SaveConfig()
end)

ShortcutAP.MouseButton1Click:Connect(function()
    autoPlay = not autoPlay
    Config.AutoPlay = autoPlay
    AutoBtn.Text = "Auto Play: "..(autoPlay and "ON" or "OFF")
    AutoBtn.TextColor3 = autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
    UpdateShortcuts()
    SaveConfig()
end)

ShortcutHM.MouseButton1Click:Connect(function()
    useHumanization = not useHumanization
    Config.Humanize = useHumanization
    HumanizeBtn.Text = "Humanize: "..(useHumanization and "ON" or "OFF")
    HumanizeBtn.TextColor3 = useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)
    UpdateShortcuts()
    SaveConfig()
end)

ShortcutS.MouseButton1Click:Connect(function()
    sortMode = (sortMode == "Hell" and "Random" or "Hell")
    Config.SortMode = sortMode
    local mBtn = SortDropdown:FindFirstChild("MainButton")
    if mBtn then mBtn.Text = "Sort: " .. sortMode end
    lastDetected = "---"
    UpdateShortcuts()
    SaveConfig()
end)

UpdateShortcuts()

local function CreateCheckbox(text, pos, key)
    local container = Instance.new("TextButton", SlidersFrame)
    container.Size = UDim2.new(0, 60, 0, 18)
    container.Position = pos
    container.BackgroundColor3 = THEME.ItemBG
    container.AutoButtonColor = false
    container.Text = ""
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)
    
    local box = Instance.new("Frame", container)
    box.Size = UDim2.new(0, 10, 0, 10)
    box.Position = UDim2.new(0, 4, 0.5, -5)
    box.BackgroundColor3 = THEME.Slider
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
    
    local check = Instance.new("Frame", box)
    check.Size = UDim2.new(0, 6, 0, 6)
    check.Position = UDim2.new(0.5, -3, 0.5, -3)
    check.BackgroundColor3 = THEME.Success
    check.Visible = Config.AutoJoinSettings[key]
    Instance.new("UICorner", check).CornerRadius = UDim.new(0, 2)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Text = text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 8
    lbl.TextColor3 = THEME.SubText
    lbl.Size = UDim2.new(1, -25, 1, 0)
    lbl.Position = UDim2.new(0, 25, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    container.MouseButton1Click:Connect(function()
        Config.AutoJoinSettings[key] = not Config.AutoJoinSettings[key]
        check.Visible = Config.AutoJoinSettings[key]
        if Config.AutoJoinSettings[key] then
            lbl.TextColor3 = THEME.Text
            Tween(box, {BackgroundColor3 = THEME.Accent}, 0.2)
        else
            lbl.TextColor3 = THEME.SubText
            Tween(box, {BackgroundColor3 = THEME.Slider}, 0.2)
        end
        SaveConfig()
    end)
    
    if Config.AutoJoinSettings[key] then
        lbl.TextColor3 = THEME.Text
        box.BackgroundColor3 = THEME.Accent
    end
    
    return container
end

CreateCheckbox("1v1", UDim2.new(0, 11, 0, 93), "_1v1")
CreateCheckbox("4 Player", UDim2.new(0, 82, 0, 93), "_4p")
CreateCheckbox("8 Player", UDim2.new(0, 150, 0, 93), "_8p")

local BlatantDropdown = CreateDropdown(SlidersFrame, "Blatant", {"Off", "On", "Auto"}, blatantMode, function(val)
    blatantMode = val
    Config.BlatantMode = val
    isBlatant = (blatantMode == "On")
    SaveConfig()
end)
BlatantDropdown.Position = UDim2.new(0, 112, 0, 71)
BlatantDropdown.Size = UDim2.new(0, 97, 0, 18)

-- Blatant Threshold Slider Removed

local ServerBrowserBtn = Instance.new("TextButton", SlidersFrame)
ServerBrowserBtn.Text = "Server Browser"
ServerBrowserBtn.Font = Enum.Font.GothamBold
ServerBrowserBtn.TextSize = 9
ServerBrowserBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
ServerBrowserBtn.BackgroundColor3 = THEME.Background
ServerBrowserBtn.Size = UDim2.new(0, 97, 0, 18)
ServerBrowserBtn.Position = UDim2.new(0, 11, 0, 115)
Instance.new("UICorner", ServerBrowserBtn).CornerRadius = UDim.new(0, 4)

local KaburBtn = Instance.new("TextButton", SlidersFrame)
KaburBtn.Text = "Kabur: " .. (kaburMode and "ON" or "OFF")
KaburBtn.Font = Enum.Font.GothamBold
KaburBtn.TextSize = 9
KaburBtn.TextColor3 = kaburMode and Color3.fromRGB(255, 100, 100) or THEME.SubText
KaburBtn.BackgroundColor3 = THEME.Background
KaburBtn.Size = UDim2.new(0, 97, 0, 18)
KaburBtn.Position = UDim2.new(0, 112, 0, 115)
Instance.new("UICorner", KaburBtn).CornerRadius = UDim.new(0, 4)

KaburBtn.MouseButton1Click:Connect(function()
    kaburMode = not kaburMode
    Config.KaburMode = kaburMode
    KaburBtn.Text = "Kabur: " .. (kaburMode and "ON" or "OFF")
    KaburBtn.TextColor3 = kaburMode and Color3.fromRGB(255, 100, 100) or THEME.SubText
    kaburAttempts = 0
    SaveConfig()
    if kaburMode then
        ShowToast("Kabur ON (" .. kaburThreshold .. "+ exec)", "warning")
    else
        ShowToast("Kabur OFF", "success")
    end
end)

local KaburWaitBtn = Instance.new("TextButton", SlidersFrame)
KaburWaitBtn.Text = "Wait Round: " .. (kaburWaitRound and "ON" or "OFF")
KaburWaitBtn.Font = Enum.Font.GothamBold
KaburWaitBtn.TextSize = 9
KaburWaitBtn.TextColor3 = kaburWaitRound and THEME.Success or THEME.SubText
KaburWaitBtn.BackgroundColor3 = THEME.Background
KaburWaitBtn.Size = UDim2.new(0, 97, 0, 18)
KaburWaitBtn.Position = UDim2.new(0, 11, 0, 137)
Instance.new("UICorner", KaburWaitBtn).CornerRadius = UDim.new(0, 4)

KaburWaitBtn.MouseButton1Click:Connect(function()
    kaburWaitRound = not kaburWaitRound
    Config.KaburWaitRound = kaburWaitRound
    KaburWaitBtn.Text = "Wait Round: " .. (kaburWaitRound and "ON" or "OFF")
    KaburWaitBtn.TextColor3 = kaburWaitRound and THEME.Success or THEME.SubText
    SaveConfig()
    ShowToast(kaburWaitRound and "Kabur will wait for round" or "Kabur will flee instantly", "success")
end)

local AutoTPLowBtn = Instance.new("TextButton", SlidersFrame)
AutoTPLowBtn.Text = "TP <10: " .. (autoTeleportLow and "ON" or "OFF")
AutoTPLowBtn.Font = Enum.Font.GothamBold
AutoTPLowBtn.TextSize = 9
AutoTPLowBtn.TextColor3 = autoTeleportLow and Color3.fromRGB(255, 180, 50) or THEME.SubText
AutoTPLowBtn.BackgroundColor3 = THEME.Background
AutoTPLowBtn.Size = UDim2.new(0, 97, 0, 18)
AutoTPLowBtn.Position = UDim2.new(0, 112, 0, 137)
Instance.new("UICorner", AutoTPLowBtn).CornerRadius = UDim.new(0, 4)

AutoTPLowBtn.MouseButton1Click:Connect(function()
    autoTeleportLow = not autoTeleportLow
    Config.AutoTeleportLow = autoTeleportLow
    AutoTPLowBtn.Text = "TP <10: " .. (autoTeleportLow and "ON" or "OFF")
    AutoTPLowBtn.TextColor3 = autoTeleportLow and Color3.fromRGB(255, 180, 50) or THEME.SubText
    lowPlayerAttempts = 0
    SaveConfig()
    ShowToast(autoTeleportLow and "Auto TP <10 players ON" or "Auto TP <10 players OFF", "success")
end)

-- Server Browser Frame
local ServerFrame = Instance.new("Frame", ScreenGui)
ServerFrame.Name = "ServerBrowser"
ServerFrame.Size = UDim2.new(0, 263, 0, 300)
ServerFrame.Position = UDim2.new(0.5, -131, 0.5, -150)
ServerFrame.BackgroundColor3 = THEME.Background
ServerFrame.Visible = false
ServerFrame.ClipsDescendants = true
EnableDragging(ServerFrame)
Instance.new("UICorner", ServerFrame).CornerRadius = UDim.new(0, 8)
local SBStroke = Instance.new("UIStroke", ServerFrame)
SBStroke.Color = THEME.Accent
SBStroke.Transparency = 0.5
SBStroke.Thickness = 2

local SBHeader = Instance.new("TextLabel", ServerFrame)
SBHeader.Text = "Server Browser"
SBHeader.Font = Enum.Font.GothamBold
SBHeader.TextSize = 12
SBHeader.TextColor3 = THEME.Text
SBHeader.Size = UDim2.new(1, 0, 0, 30)
SBHeader.BackgroundTransparency = 1

local SBClose = Instance.new("TextButton", ServerFrame)
SBClose.Text = "X"
SBClose.Font = Enum.Font.GothamBold
SBClose.TextSize = 12
SBClose.TextColor3 = Color3.fromRGB(255, 100, 100)
SBClose.Size = UDim2.new(0, 30, 0, 30)
SBClose.Position = UDim2.new(1, -30, 0, 0)
SBClose.BackgroundTransparency = 1
SBClose.MouseButton1Click:Connect(function() ServerFrame.Visible = false end)

local SBList = Instance.new("ScrollingFrame", ServerFrame)
SBList.Size = UDim2.new(1, -15, 1, -68)
SBList.Position = UDim2.new(0, 8, 0, 38)
SBList.BackgroundTransparency = 1
SBList.ScrollBarThickness = 3
SBList.ScrollBarImageColor3 = THEME.Accent

local SBLayout = Instance.new("UIListLayout", SBList)
SBLayout.Padding = UDim.new(0, 4)
SBLayout.SortOrder = Enum.SortOrder.LayoutOrder

local ServerSortMode = "Largest"

local SBSortBtn = Instance.new("TextButton", ServerFrame)
SBSortBtn.Text = "Sort: Largest"
SBSortBtn.Font = Enum.Font.GothamBold
SBSortBtn.TextSize = 10
SBSortBtn.BackgroundColor3 = THEME.ItemBG
SBSortBtn.TextColor3 = THEME.SubText
SBSortBtn.Size = UDim2.new(0.5, -11, 0, 23)
SBSortBtn.Position = UDim2.new(0, 8, 1, -30)
Instance.new("UICorner", SBSortBtn).CornerRadius = UDim.new(0, 6)

local SBRefresh = Instance.new("TextButton", ServerFrame)
SBRefresh.Text = "Refresh"
SBRefresh.Font = Enum.Font.GothamBold
SBRefresh.TextSize = 10
SBRefresh.BackgroundColor3 = THEME.Accent
SBRefresh.Size = UDim2.new(0.5, -11, 0, 23)
SBRefresh.Position = UDim2.new(0.5, 4, 1, -30)
Instance.new("UICorner", SBRefresh).CornerRadius = UDim.new(0, 6)

local function FetchServers()
    SBRefresh.Text = "..."
    
    for _, c in ipairs(SBList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    task.spawn(function()
        local success, result = pcall(function()
            return request({
                Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
                Method = "GET"
            })
        end)
        
        if success and result and result.Body then
            local data = HttpService:JSONDecode(result.Body)
            if data and data.data then
                local servers = data.data
                
                if ServerSortMode == "Smallest" then
                    table.sort(servers, function(a,b) return (a.playing or 0) < (b.playing or 0) end)
                else
                    table.sort(servers, function(a,b) return (a.playing or 0) > (b.playing or 0) end)
                end
                
                for _, srv in ipairs(servers) do
                    if srv.playing and srv.maxPlayers and srv.id ~= game.JobId then
                        local row = Instance.new("Frame", SBList)
                        row.Size = UDim2.new(1, -5, 0, 34)
                        row.BackgroundColor3 = THEME.ItemBG
                        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
                        
                        local info = Instance.new("TextLabel", row)
                        info.Text = "Players: " .. srv.playing .. " / " .. srv.maxPlayers .. "\nPing: " .. (srv.ping or "?") .. "ms"
                        info.Size = UDim2.new(0.6, 0, 1, 0)
                        info.Position = UDim2.new(0, 8, 0, 0)
                        info.BackgroundTransparency = 1
                        info.TextColor3 = THEME.Text
                        info.Font = Enum.Font.Gotham
                        info.TextSize = 10
                        info.TextXAlignment = Enum.TextXAlignment.Left
                        
                        local join = Instance.new("TextButton", row)
                        join.Text = "Join"
                        join.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
                        join.Size = UDim2.new(0, 60, 0, 19)
                        join.Position = UDim2.new(1, -68, 0.5, -9.5)
                        join.Font = Enum.Font.GothamBold
                        join.TextSize = 10
                        join.TextColor3 = Color3.fromRGB(255,255,255)
                        Instance.new("UICorner", join).CornerRadius = UDim.new(0, 4)
                        
                        join.MouseButton1Click:Connect(function()
                            join.Text = "Joining..."
                            ShowToast("Teleporting...", "success")
                            
                            if queue_on_teleport then
                                queue_on_teleport('loadstring(game:HttpGet("https://find.wagate.biz.id/hm1.lua"))()')
                            end

                            task.spawn(function()
                                local success, err = pcall(function()
                                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, srv.id, Players.LocalPlayer)
                                end)
                                if not success then
                                    join.Text = "Failed"
                                    ShowToast("Teleport Failed: " .. tostring(err), "error")
                                    task.wait(2)
                                    join.Text = "Join"
                                end
                            end)
                        end)
                    end
                end
                
                SBList.CanvasSize = UDim2.new(0,0,0, SBLayout.AbsoluteContentSize.Y)
            end
        else
            ShowToast("Failed to fetch servers", "error")
        end
        SBRefresh.Text = "Refresh"
    end)
end

SBSortBtn.MouseButton1Click:Connect(function()
    if ServerSortMode == "Smallest" then
        ServerSortMode = "Largest"
    else
        ServerSortMode = "Smallest"
    end
    SBSortBtn.Text = "Sort: " .. ServerSortMode
    FetchServers()
end)

SBRefresh.MouseButton1Click:Connect(FetchServers)

ServerBrowserBtn.MouseButton1Click:Connect(function()
    ServerFrame.Visible = not ServerFrame.Visible
    ServerFrame.Parent = nil
    ServerFrame.Parent = ScreenGui
    
    if ServerFrame.Visible then
        FetchServers()
    end
end)

local function CalculateDelay()
    local charsPerMin = currentCPM
    local baseDelay = 60 / charsPerMin
    local variance = baseDelay * 0.4
    return useHumanization and (baseDelay + math.random()*variance - (variance/2)) or baseDelay
end

local KEY_POS = {}
do
    local row1 = "qwertyuiop"
    local row2 = "asdfghjkl"
    local row3 = "zxcvbnm"
    for i = 1, #row1 do
        KEY_POS[row1:sub(i,i)] = {x = i, y = 1}
    end
    for i = 1, #row2 do
        KEY_POS[row2:sub(i,i)] = {x = i + 0.5, y = 2}
    end
    for i = 1, #row3 do
        KEY_POS[row3:sub(i,i)] = {x = i + 1, y = 3}
    end
end

local function KeyDistance(a, b)
    if not a or not b then return 1 end
    a = a:lower()
    b = b:lower()
    local pa = KEY_POS[a]
    local pb = KEY_POS[b]
    if not pa or not pb then return 1 end
    local dx = pa.x - pb.x
    local dy = pa.y - pb.y
    return math.sqrt(dx*dx + dy*dy)
end

local lastKey = nil
-- Per-word CPM variance: set once per word to simulate familiarity
local currentWordCPMFactor = 1.0

local function RandomizeWordCPM()
    -- Each word gets a slight speed variance (0.85x to 1.15x)
    -- Simulates: some words you type confidently, others more carefully
    local r = (math.random() + math.random() + math.random()) / 3 -- bell curve
    currentWordCPMFactor = 0.85 + (r * 0.30)
end

local function CalculateDelayForKeys(prevChar, nextChar)
    if isBlatant then 
        return 60 / currentCPM 
    end

    local effectiveCPM = currentCPM * currentWordCPMFactor
    local baseDelay = 60 / effectiveCPM
    
    local variance = baseDelay * 0.35
    local extra = 0
    
    if useHumanization and useFingerModel and prevChar and nextChar and prevChar ~= "" then
        local dist = KeyDistance(prevChar, nextChar)
        extra = dist * 0.018 * (550 / math.max(150, effectiveCPM))
        
        local pa = KEY_POS[prevChar:lower()]
        local pb = KEY_POS[nextChar:lower()]
        if pa and pb then
            if (pa.x <= 5 and pb.x <= 5) or (pa.x > 5 and pb.x > 5) then
                extra = extra * 0.8
            end
        end
    end

    if useHumanization then
        local r = (math.random() + math.random() + math.random()) / 3
        local noise = (r * 2 - 1) * variance
        return math.max(0.005, baseDelay + extra + noise)
    else
        return baseDelay
    end
end

local VirtualUser = game:GetService("VirtualUser")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function GetKeyCode(char)
    if type(char) == "string" and #char == 1 then
        char = char:lower()
        return Enum.KeyCode[char:upper()]
    end
    return nil
end

local function SimulateKey(input)
    if typeof(input) == "string" and #input == 1 then
         local char = input
         local vimSuccess = pcall(function()
             VirtualInputManager:SendTextInput(char)
         end)
         
         if not vimSuccess then
             -- Fallback for executors that don't support SendTextInput or for keycodes
             local key
             pcall(function() key = GetKeyCode(input) end)
             if not key then pcall(function() key = Enum.KeyCode[input:upper()] end) end
             
             if key then
                 pcall(function()
                     VirtualInputManager:SendKeyEvent(true, key, false, game)
                     task.wait(0.01)
                     VirtualInputManager:SendKeyEvent(false, key, false, game)
                 end)
             end
         end
         return
    end

    local key
    if typeof(input) == "EnumItem" then
        key = input
    else
        pcall(function() key = Enum.KeyCode[input:upper()] end)
    end

    if key then
        local baseHold = math.clamp(12 / currentCPM, 0.015, 0.05)
        local hold = isBlatant and 0.012 or (baseHold + (math.random() * 0.01) - 0.005)

        local vimSuccess = pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
            task.wait(hold)
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)

        if not vimSuccess then
            pcall(function()
                VirtualUser:TypeKey(key)
            end)
        end
    end
end

local function Backspace(count)
    local key = Enum.KeyCode.Backspace
    for i = 1, count do
        -- Simulate natural key hold duration
        local baseHold = math.clamp(12 / currentCPM, 0.015, 0.05)
        local hold = isBlatant and 0.012 or (baseHold + (math.random() * 0.01) - 0.005)

        pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
            task.wait(hold)
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)

        -- Natural delay between each backspace press
        if not isBlatant and useHumanization then
            local baseDelay = 60 / currentCPM
            -- Backspace is typically faster than typing, so multiply by 0.6-0.8
            local bsSpeedFactor = 0.6 + math.random() * 0.2
            local variance = baseDelay * 0.3
            local r = (math.random() + math.random()) / 2
            local noise = (r * 2 - 1) * variance
            local delay = math.max(0.008, (baseDelay * bsSpeedFactor) + noise)
            task.wait(delay)

            -- Occasional micro-pause (like a real person adjusting their finger)
            if math.random() < 0.05 then
                task.wait(0.04 + math.random() * 0.08)
            end
        elseif not isBlatant then
            -- Even without humanization, add a small base delay
            task.wait(60 / currentCPM * 0.5)
        else
            -- Blatant mode: minimal delay
            if i % 5 == 0 then task.wait() end
        end
    end
    lastKey = nil
end

local function PressEnter()
    SimulateKey(Enum.KeyCode.Return)
    lastKey = nil
end

local function GetGameTextBox()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    if inGame then
        local frame = inGame:FindFirstChild("Frame")
        if frame then
             for _, c in ipairs(frame:GetDescendants()) do
                 if c:IsA("TextBox") and c.Visible then return c end
             end
        end
        for _, c in ipairs(inGame:GetDescendants()) do
             if c:IsA("TextBox") and c.Visible then return c end
        end
    end
    return UserInputService:GetFocusedTextBox()
end

-- Quick timer reader for use inside SmartType
local function GetTimerSeconds()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    local frame = inGame and inGame:FindFirstChild("Frame")
    if not frame then return nil end
    local circle = frame:FindFirstChild("Circle")
    local timerLbl = circle and circle:FindFirstChild("Timer") and circle.Timer:FindFirstChild("Seconds")
    if timerLbl then
        return tonumber(timerLbl.Text:match("([%d%.]+)"))
    end
    return nil
end

local function SmartType(targetWord, currentDetected, isCorrection, bypassTurn)
    if unloaded then return end
    
    if isTyping then
        if (tick() - lastTypingStart) > 15 then
            isTyping = false
            isAutoPlayScheduled = false
            StatusText.Text = "Typing State Reset (Timeout)"
            StatusText.TextColor3 = THEME.Warning
        else
            return
        end
    end

    isTyping = true
    lastTypingStart = tick()
    
    local targetBox = GetGameTextBox()
    if targetBox then
        targetBox:CaptureFocus()
        task.wait(0.1)
    end
    
    StatusText.Text = "Typing..."
    StatusText.TextColor3 = THEME.Accent
    Tween(StatusDot, {BackgroundColor3 = THEME.Accent})

    -- Randomize typing speed for this word (human familiarity variance)
    RandomizeWordCPM()

    -- Track risky mistake Enter presses for this word
    -- Game gives 5 chances; cap risky presses randomly (0-2) to save lives for real retries
    local riskyMistakesFired = 0
    local MAX_RISKY_PER_WORD = math.random(0, 2)

    local success, err = pcall(function()
        if isCorrection then
            local commonLen = 0
            local minLen = math.min(#targetWord, #currentDetected)
            for i = 1, minLen do
                if targetWord:sub(i,i) == currentDetected:sub(i,i) then
                    commonLen = i
                else
                    break
                end
            end

            local backspaceCount = #currentDetected - commonLen
            if backspaceCount > 0 then
                Backspace(backspaceCount)
                task.wait(0.15)
            end
            
            local toType = targetWord:sub(commonLen + 1)
            for i = 1, #toType do
                if not bypassTurn and not GetTurnInfo() then
                    -- Double check if turn info is just flickering
                    task.wait(0.05)
                    if not GetTurnInfo() then break end
                end
                local ch = toType:sub(i, i)
                SimulateKey(ch)
                task.wait(CalculateDelayForKeys(lastKey, ch))
                lastKey = ch
                if useHumanization and math.random() < 0.03 then
                    task.wait(0.15 + math.random() * 0.45)
                end
            end

            -- Pre-submission verify
            local finalCheck = GetGameTextBox()
            if not riskyMistakes then
                task.wait(0.1)
                finalCheck = GetGameTextBox()
                if finalCheck and finalCheck.Text ~= targetWord then
                     StatusText.Text = "Typing mismatch detected!"
                     StatusText.TextColor3 = THEME.Warning
                     -- Only backspace down to the prefix (currentDetected)
                     local bsCount = math.max(0, #finalCheck.Text - #currentDetected)
                     if bsCount > 0 then Backspace(bsCount) end
                     
                     isTyping = false
                     forceUpdateList = true
                     return
                end
            end

            PressEnter()
            
            local verifyTimeout = isBlatant and 0.6 or 1.2
            local verifyStart = tick()
            local accepted = false
            
            while (tick() - verifyStart) < verifyTimeout do
                local currentCheck, isCensored = GetCurrentGameWord()
                if currentCheck == "" or isCensored or (currentCheck ~= targetWord and currentCheck ~= currentDetected) then
                     accepted = true
                     break
                end
                task.wait(0.05)
            end

            if not accepted then
                -- Distinguish real vs false rejection:
                -- If risky mistakes were fired during typing, the rejection might be
                -- because we exhausted game lives, NOT because the word is invalid.
                -- Only blacklist on clean submissions (0 risky presses).
                if riskyMistakesFired == 0 then
                    -- Clean submission rejected = real rejection (word used/invalid)
                    Blacklist[targetWord] = true
                    RandomPriority[targetWord] = nil
                    
                    for k, list in pairs(RandomOrderCache) do
                        for i = #list, 1, -1 do
                            if list[i] == targetWord then table.remove(list, i) end
                        end
                    end
                    StatusText.Text = "Rejected: removed '" .. targetWord .. "'"
                else
                    -- Had risky presses = might be false rejection, keep word in pool
                    StatusText.Text = "Skipped (risky): '" .. targetWord .. "'"
                end
                StatusText.TextColor3 = THEME.Warning
                -- Only backspace what we typed (down to the prefix, not beyond)
                local bsCount = math.max(0, #targetWord - #currentDetected + 2)
                Backspace(bsCount)

                lastDetected = "---"
                isTyping = false
                forceUpdateList = true
                
                -- Immediate retry on correction path
                task.spawn(function()
                    task.wait(0.1)
                    local stillMyTurn, req = GetTurnInfo()
                    UpdateList(currentDetected, req)
                    
                    if autoPlay and stillMyTurn and currentBestMatch and not isTyping then
                        local rethinkDelay = isBlatant and 0.1 or (0.3 + math.random() * 0.4)
                        task.wait(rethinkDelay)
                        
                        local retryWord = currentBestMatch
                        local retryDetected = GetCurrentGameWord()
                        local stillTurn, _ = GetTurnInfo()
                        if stillTurn and retryWord and not isTyping then
                            StatusText.Text = "Retrying: " .. retryWord
                            StatusText.TextColor3 = THEME.Accent
                            SmartType(retryWord, retryDetected, false)
                        end
                    end
                end)
                return
            else
                StatusText.Text = "Word Accepted (Corrected)"
                StatusText.TextColor3 = THEME.Success

                local current = GetCurrentGameWord()
                if #current > 0 then
                    Backspace(#current)
                end

                UsedWords[targetWord] = true
                isMyTurnLogDetected = false
                task.wait(0.1)
            end
        else
            local missingPart = ""
            if targetWord:sub(1, #currentDetected) == currentDetected then
                missingPart = targetWord:sub(#currentDetected + 1)
            else
                missingPart = targetWord
            end

            local letters = "abcdefghijklmnopqrstuvwxyz"
            local isTimeLow = false
            for i = 1, #missingPart do
                -- Timer awareness: check every 3 chars to minimize overhead
                if not isBlatant and (i == 1 or i % 3 == 0) then
                    local sec = GetTimerSeconds()
                    if sec and sec < 4 then
                        isTimeLow = true
                    end
                end

                if not bypassTurn and not GetTurnInfo() then
                     task.wait(0.05)
                     if not GetTurnInfo() then break end
                end
                local ch = missingPart:sub(i, i)
                -- Only do typo simulation when time is comfortable
                if not isBlatant and not isTimeLow and errorRate > 0 and (math.random() < (errorRate / 100)) then
                    local typoChar
                    repeat
                        local idx = math.random(1, #letters)
                        typoChar = letters:sub(idx, idx)
                    until typoChar ~= ch
                    SimulateKey(typoChar)
                    
                    if riskyMistakes and riskyMistakesFired < MAX_RISKY_PER_WORD then
                         task.wait(0.05 + math.random() * 0.1)
                         PressEnter()
                         riskyMistakesFired = riskyMistakesFired + 1
                    end

                    task.wait(CalculateDelayForKeys(lastKey, typoChar))
                    lastKey = typoChar

                    -- Enhanced risky mistakes: sometimes type ahead before realizing
                    local extraTyped = 0
                    if riskyMistakes and riskyMistakesFired < MAX_RISKY_PER_WORD and useHumanization and math.random() < 0.30 and (i + 1) <= #missingPart then
                        -- Type 1-3 more characters before "noticing" the typo
                        local aheadCount = math.min(math.random(1, 3), #missingPart - i)
                        for j = 1, aheadCount do
                            local aheadIdx = i + j
                            if aheadIdx <= #missingPart then
                                local aheadCh = missingPart:sub(aheadIdx, aheadIdx)
                                SimulateKey(aheadCh)
                                task.wait(CalculateDelayForKeys(lastKey, aheadCh))
                                lastKey = aheadCh
                                extraTyped = extraTyped + 1
                            end
                        end
                    end

                    -- Realize pause (longer if typed ahead more)
                    local realize = (thinkDelayCurrent * (0.6 + math.random() * 0.8)) + 0.1
                    if extraTyped > 0 then
                        realize = realize + (extraTyped * 0.08)
                    end
                    task.wait(realize)

                    -- Backspace the typo + any extra characters typed ahead
                    Backspace(1 + extraTyped)
                    lastKey = nil
                    task.wait(0.05 + math.random() * 0.08)
                    SimulateKey(ch)
                    task.wait(CalculateDelayForKeys(lastKey, ch))
                    lastKey = ch

                    -- VERIFY TextBox integrity after typo correction
                    task.wait(0.02)
                    local expectedSoFar = currentDetected .. missingPart:sub(1, i)
                    local verifyBox = GetGameTextBox()
                    if verifyBox and verifyBox.Text ~= expectedSoFar then
                        -- TextBox is out of sync! Full recovery:
                        -- Backspace everything we typed (down to prefix)
                        StatusText.Text = "Fixing desync..."
                        local bsNeeded = math.max(0, #verifyBox.Text - #currentDetected)
                        if bsNeeded > 0 then
                            Backspace(bsNeeded)
                            lastKey = nil
                            task.wait(0.05)
                        end
                        -- Retype all characters from position 1 to i
                        for j = 1, i do
                            local reCh = missingPart:sub(j, j)
                            SimulateKey(reCh)
                            task.wait(CalculateDelayForKeys(lastKey, reCh))
                            lastKey = reCh
                        end
                    end
                else
                    SimulateKey(ch)
                    -- Type faster when time is low
                    if isTimeLow then
                        task.wait(60 / currentCPM * 0.5)
                    else
                        task.wait(CalculateDelayForKeys(lastKey, ch))
                    end
                    lastKey = ch
                end
                -- Skip humanization pauses when time is low
                if not isBlatant and not isTimeLow and useHumanization and math.random() < 0.03 then
                    task.wait(0.12 + math.random() * 0.5)
                end

                -- Periodic verification for long words (every 8 chars)
                if i % 8 == 0 and i < #missingPart then
                    local expectedSoFar = currentDetected .. missingPart:sub(1, i)
                    local periodicBox = GetGameTextBox()
                    if periodicBox and periodicBox.Text ~= expectedSoFar then
                        StatusText.Text = "Fixing long word desync..."
                        StatusText.TextColor3 = THEME.Warning
                        local bsNeeded = math.max(0, #periodicBox.Text - #currentDetected)
                        if bsNeeded > 0 then
                            Backspace(bsNeeded)
                            lastKey = nil
                            task.wait(0.05)
                        end
                        for j = 1, i do
                            local reCh = missingPart:sub(j, j)
                            SimulateKey(reCh)
                            task.wait(CalculateDelayForKeys(lastKey, reCh))
                            lastKey = reCh
                        end
                    end
                end
            end

            -- Pre-submission verify (always verify now, not just when riskyMistakes is off)
            if not isBlatant then
                task.wait(0.05)
                local finalCheck = GetGameTextBox()
                if finalCheck and finalCheck.Text ~= targetWord then
                    -- Final recovery attempt before giving up
                    StatusText.Text = "Final verify: fixing..."
                    StatusText.TextColor3 = THEME.Warning
                    local bsCount = math.max(0, #finalCheck.Text - #currentDetected)
                    if bsCount > 0 then Backspace(bsCount) end
                    lastKey = nil
                    task.wait(0.05)
                    -- Retype the entire missing part
                    for j = 1, #missingPart do
                        local reCh = missingPart:sub(j, j)
                        SimulateKey(reCh)
                        task.wait(60 / currentCPM * 0.5) -- fast retype
                        lastKey = reCh
                    end
                    -- Verify one more time
                    task.wait(0.05)
                    local secondCheck = GetGameTextBox()
                    if secondCheck and secondCheck.Text ~= targetWord then
                        StatusText.Text = "Cannot fix mismatch, skipping"
                        StatusText.TextColor3 = THEME.Warning
                        local bsFinal = math.max(0, #secondCheck.Text - #currentDetected)
                        if bsFinal > 0 then Backspace(bsFinal) end
                        isTyping = false
                        forceUpdateList = true
                        return
                    end
                end
            end

            PressEnter()
            
            local verifyTimeout = isBlatant and 0.6 or 1.2
            local verifyStart = tick()
            local accepted = false
            
            while (tick() - verifyStart) < verifyTimeout do
                local currentCheck, isCensored = GetCurrentGameWord()
                if currentCheck == "" or isCensored or (currentCheck ~= targetWord and currentCheck ~= currentDetected) then
                     accepted = true
                     break
                end
                task.wait(0.05)
            end

            if not accepted then
                local postCheck = GetGameTextBox()
                if postCheck and postCheck.Text == targetWord then
                     StatusText.Text = "Enter failed? Retrying..."
                     PressEnter()
                     task.wait(0.3)
                     if GetCurrentGameWord() == currentDetected then
                         StatusText.Text = "Submission Failed (Lag?)"
                         StatusText.TextColor3 = THEME.Warning
                         -- Only backspace down to the prefix
                         local bsCount = math.max(0, #targetWord - #currentDetected + 2)
                         Backspace(bsCount)
                         isTyping = false
                         forceUpdateList = true
                         return
                     end
                end

                -- Distinguish real vs false rejection
                if riskyMistakesFired == 0 then
                    -- Clean submission = real rejection
                    Blacklist[targetWord] = true
                    for k, list in pairs(RandomOrderCache) do
                        for i = #list, 1, -1 do
                            if list[i] == targetWord then table.remove(list, i) end
                        end
                    end
                    StatusText.Text = "Rejected: removed '" .. targetWord .. "'"
                else
                    -- Had risky presses = might be false rejection, keep word
                    StatusText.Text = "Skipped (risky): '" .. targetWord .. "'"
                end
                StatusText.TextColor3 = THEME.Warning
                -- Only backspace what we typed (down to the prefix, not beyond)
                local bsCount = math.max(0, #targetWord - #currentDetected + 2)
                Backspace(bsCount)
                
                isTyping = false
                lastDetected = "---"
                forceUpdateList = true

                -- Immediate retry: find next best word and type it after a natural pause
                task.spawn(function()
                    task.wait(0.1)
                    local stillMyTurn, req = GetTurnInfo()
                    UpdateList(currentDetected, req)
                    
                    if autoPlay and stillMyTurn and currentBestMatch and not isTyping then
                        -- Natural "rethinking" delay after rejection
                        local rethinkDelay = isBlatant and 0.1 or (0.3 + math.random() * 0.4)
                        task.wait(rethinkDelay)
                        
                        local retryWord = currentBestMatch
                        local retryDetected = GetCurrentGameWord()
                        local stillTurn, _ = GetTurnInfo()
                        if stillTurn and retryWord and not isTyping then
                            StatusText.Text = "Retrying: " .. retryWord
                            StatusText.TextColor3 = THEME.Accent
                            SmartType(retryWord, retryDetected, false)
                        end
                    end
                end)
                return
            else
                StatusText.Text = "Word Accepted"
                StatusText.TextColor3 = THEME.Success
                
                local current = GetCurrentGameWord()
                if #current > 0 then
                    Backspace(#current + 1)
                end

                UsedWords[targetWord] = true
                isMyTurnLogDetected = false
                task.wait(0.1)
            end
        end
    end)
    isTyping = false
    forceUpdateList = true
end

local function GetMatchLength(str, prefix)
    local len = 0
    local max = math.min(#str, #prefix)
    for i = 1, max do
        local pb = string.byte(prefix, i)
        if pb == 35 or pb == string.byte(str, i) then
            len = i
        else
            break
        end
    end
    return len
end

local function BinarySearchStart(list, prefix)
    local left = 1
    local right = #list
    local result = -1
    local pLen = #prefix

    while left <= right do
        local mid = math.floor((left + right) / 2)
        local word = list[mid]
        local sub = word:sub(1, pLen)

        if sub == prefix then
            result = mid
            right = mid - 1
        elseif sub < prefix then
            left = mid + 1
        else
            right = mid - 1
        end
    end

    return result
end

UpdateList = function(detectedText, requiredLetter)
    local matches = {}
    local searchPrefix = detectedText
    local isBacktracked = false
    local manualSearch = false

    if SearchBox and SearchBox.Text ~= "" then
        searchPrefix = SearchBox.Text:lower():gsub("[%s%c]+", "")
        manualSearch = true
        if requiredLetter and searchPrefix:sub(1,1) ~= requiredLetter:sub(1,1):lower() then
             requiredLetter = nil
        end
    end

    if not manualSearch and requiredLetter and #requiredLetter > 0 then
        local reqLen = GetMatchLength(requiredLetter, searchPrefix)
        if reqLen == #searchPrefix and #requiredLetter > #searchPrefix then
             searchPrefix = requiredLetter
        end
    end
    
    local firstChar = searchPrefix:sub(1,1)
    if firstChar == "#" then firstChar = nil end

    if (not firstChar or firstChar == "") and requiredLetter then
        firstChar = requiredLetter:sub(1,1):lower()
    end
    
    local bucket
    if firstChar and firstChar ~= "" and Buckets then
        bucket = Buckets[firstChar] or {}
    else
        bucket = Words
    end
    
    local function CollectMatches(prefix, tryFallbackLengths)
        local exacts = {}
        local fallbackExacts = {}
        local partials = {}
        local maxPartialLen = 0
        local limit = 100
        
        if bucket then
            local checkWord = function(w)
                if Blacklist[w] or UsedWords[w] then return end
                
                -- Check for main list filtering (suffix/length)
                if suffixMode ~= "" and w:sub(-#suffixMode) ~= suffixMode then return end
                
                local isLengthMatch = true
                if not tryFallbackLengths and lengthMode > 0 then
                    isLengthMatch = (#w == lengthMode)
                elseif tryFallbackLengths and lengthMode > 0 then
                     isLengthMatch = true
                end
                
                if not isLengthMatch then return end

                local mLen = GetMatchLength(w, prefix)
                if mLen == #prefix then
                    table.insert(exacts, w)
                elseif #exacts == 0 then
                    if mLen > maxPartialLen then
                        maxPartialLen = mLen
                        partials = {w}
                    elseif mLen == maxPartialLen and mLen > 0 then
                        if #partials < 50 then table.insert(partials, w) end
                    end
                end
            end

            local useBinary = true
            if prefix:find("#") or prefix:find("%*") then useBinary = false end
            
            if useBinary and #prefix > 0 then
                local startIndex = BinarySearchStart(bucket, prefix)
                
                if startIndex ~= -1 then
                    local count = 0
                    for i = startIndex, #bucket do
                        local w = bucket[i]
                        
                        if w:sub(1, #prefix) ~= prefix then break end
                        
                        checkWord(w)
                        
                        count = count + 1
                        if count >= 3000 then break end
                    end
                end
            else
                local searchLimit = (sortMode == "Random") and 1000 or limit
                for _, w in ipairs(bucket) do
                    checkWord(w)
                    if #exacts >= searchLimit then break end
                end
            end
            
            if sortMode == "Random" and #exacts > 0 then
                shuffleTable(exacts)
            end
        end
        return exacts, partials, maxPartialLen
    end

    local exacts, partials, pLen = CollectMatches(searchPrefix, false)

    if #exacts == 0 and lengthMode > 0 then
        local fallbackExacts, fallbackPartials, fallbackPLen = CollectMatches(searchPrefix, true)
        if #fallbackExacts > 0 then
             exacts = fallbackExacts
        end
    end

    if #exacts > 0 then
        matches = exacts
    elseif pLen > 0 then
        matches = partials
        searchPrefix = searchPrefix:sub(1, pLen)
        isBacktracked = true
    elseif requiredLetter and #requiredLetter > 0 then
        local reqChar = requiredLetter:sub(1,1):lower()
        if searchPrefix:sub(1,1):lower() ~= reqChar then
            local fallbackBucket = (Buckets and Buckets[reqChar]) or Words
            if fallbackBucket then
                for _, w in ipairs(fallbackBucket) do
                    if not Blacklist[w] and not UsedWords[w] then
                         local mLen = GetMatchLength(w, requiredLetter)
                         if mLen == #requiredLetter then
                             table.insert(matches, w)
                             if #matches >= 100 then break end
                         end
                    end
                end
            end
            
            if #matches > 0 then
                searchPrefix = requiredLetter
                isBacktracked = true
            end
        end
    end
    
    if #matches > 0 then
        if sortMode == "Longest" then
            table.sort(matches, function(a, b) return #a > #b end)
        elseif sortMode == "Shortest" then
            table.sort(matches, function(a, b) return #a < #b end)
        elseif sortMode == "Killer" then
            local cachedScores = {}
            for _, w in ipairs(matches) do
                cachedScores[w] = GetKillerScore(w)
            end
            
            table.sort(matches, function(a, b)
                local sA = cachedScores[a]
                local sB = cachedScores[b]
                if sA == sB then
                    return #a < #b
                end
                return sA > sB
            end)
        elseif sortMode == "Custom" then
            local customOrder = {}
            if Config.CustomWords then
                for i, cw in ipairs(Config.CustomWords) do
                    customOrder[cw] = i
                end
            end
            table.sort(matches, function(a, b)
                local orderA = customOrder[a] or 999999
                local orderB = customOrder[b] or 999999
                if orderA ~= orderB then
                    return orderA < orderB
                end
                return #a < #b -- Fallback ke terpendek jika keduanya bukan custom
            end)
        elseif sortMode == "Hell" then
            local cachedScores = {}
            for _, w in ipairs(matches) do
                cachedScores[w] = KillerCharScores[w:sub(-1)] or 0
            end
            
            table.sort(matches, function(a, b)
                local sA = cachedScores[a]
                local sB = cachedScores[b]
                if sA == sB then
                    return #a < #b
                end
                return sA > sB
            end)
        end
    end
    
    local displayList = {}
    local maxDisplay = 40
    for i = 1, math.min(maxDisplay, #matches) do table.insert(displayList, matches[i]) end
    
    -- Keyboard highlight logic removed (keyboard feature disabled)

    if #matches > 0 and not isBacktracked then
        currentBestMatch = matches[1]
    else
        currentBestMatch = nil
    end
    
    if isBacktracked then
        local validPart = searchPrefix
        local invalidPart = detectedText:sub(#searchPrefix + 1)
        local accentRGB = ACCENT_RGB
        StatusText.Text = "No match: <font color=\"rgb(" .. accentRGB .. ")\">" .. validPart .. "</font><font color=\"rgb(255,80,80)\">" .. invalidPart .. "</font>"
        StatusText.TextColor3 = THEME.SubText
    elseif #exacts == 0 and lengthMode > 0 and suffixMode ~= "" then
         StatusText.Text = "No len match (showing all)"
         StatusText.TextColor3 = THEME.Warning
    end

    for i = 1, math.max(#displayList, #ButtonCache) do
        local w = displayList[i]
        local btn = ButtonCache[i]

        if w then
            local lbl
            if not btn then
                btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -4, 0, 22)
                btn.BackgroundColor3 = THEME.ItemBG
                btn.Text = ""
                btn.AutoButtonColor = false
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                
                lbl = Instance.new("TextLabel", btn)
                lbl.Name = "Label"
                lbl.Size = UDim2.new(1, -20, 1, 0)
                lbl.Position = UDim2.new(0, 10, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.TextSize = 10
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.RichText = true
                
                btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Color3.fromRGB(45,45,55)}) end)
                btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = THEME.ItemBG}) end)
                
                btn.MouseButton1Click:Connect(function()
                    local d = ButtonData[btn]
                    if d then
                        SmartType(d.word, d.detected, true)
                        local l = btn:FindFirstChild("Label")
                        if l then l.TextColor3 = THEME.Success end
                        Tween(btn, {BackgroundColor3 = Color3.fromRGB(30,60,40)})
                    end
                end)
                
                btn.Parent = ScrollList
                table.insert(ButtonCache, btn)
            else
                lbl = btn:FindFirstChild("Label")
                btn.Visible = true
                btn.Parent = ScrollList
                btn.BackgroundColor3 = THEME.ItemBG
                if lbl then lbl.TextColor3 = THEME.Text end
            end
            
            ButtonData[btn] = {word = w, detected = detectedText}
            
            local accentRGB = ACCENT_RGB
            
            if i == 1 then accentRGB = "100,255,140"
            elseif i == 2 then accentRGB = "255,180,200"
            elseif i == 3 then accentRGB = "100,200,255"
            end

            local textRGB = TEXT_RGB
            
            local displayText = ""
            if isBacktracked then
                local prefix = w:sub(1, #searchPrefix)
                local suffix = w:sub(#searchPrefix + 1)
                displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font>"
                    .. "<font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
            else
                local prefix = w:sub(1, #detectedText)
                local suffix = w:sub(#detectedText + 1)
                displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font>"
                    .. "<font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
            end
            
            if lbl then lbl.Text = displayText end
        else
            if btn then
                btn.Visible = false
                ButtonData[btn] = nil
            end
        end
    end
    
    ScrollList.CanvasSize = UDim2.new(0,0,0, UIListLayout.AbsoluteContentSize.Y)
    
    -- Return visible count to avoid extra loops
    local visCount = 0
    for _, b in ipairs(ButtonCache) do
        if b.Visible then visCount = visCount + 1 end
    end
    return visCount
end

-- Cache color strings now that THEME is defined
ACCENT_RGB = ColorToRGB(THEME.Accent)
TEXT_RGB = ColorToRGB(THEME.Text)

-- SetupSlider for CPM removed

MinBtn.MouseButton1Click:Connect(function()
    local isMin = MainFrame.Size.Y.Offset < 100
    if not isMin then
        Tween(MainFrame, {Size = UDim2.new(0, 225, 0, 34)})
        ScrollList.Visible = false
        SettingsFrame.Visible = false
        StatusFrame.Visible = false
        MinBtn.Text = "+"
    else
        Tween(MainFrame, {Size = UDim2.new(0, 225, 0, 280)})
        task.wait(0.2)
        ScrollList.Visible = true
        SettingsFrame.Visible = true
        StatusFrame.Visible = true
        MinBtn.Text = "-"
    end
end)

-- Start minimized
ScrollList.Visible = false
SettingsFrame.Visible = false
StatusFrame.Visible = false
MinBtn.Text = "+"

local lastTypeVisible = false
local lastRequiredLetter = ""

-- Stats integrated into header

-- Group Rank Caching (async, non-yielding in Heartbeat)
local function CachePlayerRank(player)
    task.spawn(function()
        local success, rank = pcall(function()
            return player:GetRankInGroup(GAME_GROUP_ID)
        end)
        if success then
            GroupRankCache[player.UserId] = rank
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    CachePlayerRank(p)
end
Players.PlayerAdded:Connect(CachePlayerRank)
Players.PlayerRemoving:Connect(function(player)
    GroupRankCache[player.UserId] = nil
end)

runConn = RunService.Heartbeat:Connect(function()
    local success, err = pcall(function()
        local now = tick()
        local player = Players.LocalPlayer
        local gui = player and player:FindFirstChild("PlayerGui")
        local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")

        if isTyping and (tick() - lastTypingStart) > 15 then
            isTyping = false
            isAutoPlayScheduled = false
            StatusText.Text = "Typing State Reset (Watchdog)"
            StatusText.TextColor3 = THEME.Warning
        end
        
        local isVisible = false
        if frame and frame.Parent then
            if frame.Parent:IsA("ScreenGui") then
                isVisible = frame.Parent.Enabled
            elseif frame.Parent:IsA("GuiObject") then
                isVisible = frame.Parent.Visible
            end
        end

        local seconds = nil
        if isVisible then
            local circle = frame:FindFirstChild("Circle")
            local timerLbl = circle and circle:FindFirstChild("Timer") and circle.Timer:FindFirstChild("Seconds")
            
            if timerLbl then
                local timeText = timerLbl.Text
                seconds = tonumber(timeText:match("([%d%.]+)"))
                
                StatsData.Frame.Visible = true
                StatsData.Timer.Text = timeText
                if seconds and seconds < 3 then StatsData.Timer.TextColor3 = Color3.fromRGB(255, 80, 80)
                else StatsData.Timer.TextColor3 = THEME.Text end
            end
        else
            StatsData.Frame.Visible = false
        end

        local isMyTurn, requiredLetter = GetTurnInfo(frame)
        
        if (now - lastWordCheck) > 0.05 then
            cachedDetected, cachedCensored = GetCurrentGameWord(frame)
            lastWordCheck = now
        end
        local detected, censored = cachedDetected, cachedCensored

        -- Graduated panic system: earlier detection = more time to type naturally
        if isVisible and isMyTurn and not isTyping and seconds then
            local panicThreshold = 2.5 -- Start looking for panic word earlier
            if seconds < panicThreshold then
                local panicKey = (requiredLetter or "") .. "|" .. detected
                if panicKey ~= lastPanicKey then
                    lastPanicKey = panicKey
                    cachedPanicWord = nil
                    local char = (requiredLetter or ""):lower()
                    local bucket = Buckets[char]
                    if bucket then
                        local bestLen = 999
                        for _, w in ipairs(bucket) do
                            if not Blacklist[w] and not UsedWords[w] and w:sub(1, #detected) == detected then
                                if #w < bestLen then
                                    cachedPanicWord = w
                                    bestLen = #w
                                end
                            end
                        end
                    end
                end
                
                if cachedPanicWord then
                    -- At 2.5-1.5s: prepare but only type if auto-play hasn't started yet
                    -- Below 1.5s: force type immediately (real panic)
                    if seconds < 1.5 or not isAutoPlayScheduled then
                        StatusText.Text = seconds < 1.5 and "PANIC SAVE!" or "Quick Save!"
                        StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
                        SmartType(cachedPanicWord, detected, false)
                    end
                end
            end
        end

        if autoJoin and (now - lastAutoJoinCheck > AUTO_JOIN_RATE) then
            lastAutoJoinCheck = now
            task.spawn(function()
                local displayMatch = gui and gui:FindFirstChild("DisplayMatch")
                local dFrame = displayMatch and displayMatch:FindFirstChild("Frame")
                local matches = dFrame and dFrame:FindFirstChild("Matches")
                
                if matches then
                    for _, matchFrame in ipairs(matches:GetChildren()) do
                        if (matchFrame:IsA("Frame") or matchFrame:IsA("GuiObject")) and matchFrame.Name ~= "UIListLayout" then
                            local joinBtn = matchFrame:FindFirstChild("Join")
                            local title = matchFrame:FindFirstChild("Title")
                            
                            local isLastLetter = false
                            local titleText = "N/A"
                            if title and title:IsA("TextLabel") then
                                titleText = title.Text
                                if titleText:find("Last Letter") then
                                    isLastLetter = true
                                end
                            end

                            local idx = tonumber(matchFrame.Name)
                            local allowed = true
                            if idx then
                                if idx >= 1 and idx <= 4 then allowed = Config.AutoJoinSettings._1v1
                                elseif idx >= 5 and idx <= 8 then allowed = Config.AutoJoinSettings._4p
                                elseif idx == 9 then allowed = Config.AutoJoinSettings._8p
                                end
                            end

                            if joinBtn and joinBtn.Visible and isLastLetter and allowed then
                                local matchId = matchFrame.Name
                                if (tick() - (JoinDebounce[matchId] or 0)) > 2 then
                                    JoinDebounce[matchId] = tick()
                                    task.wait(0.5)
                                    
                                    local clicked = false
                                    if getconnections then
                                        if joinBtn:IsA("GuiButton") then
                                            local success, conns = pcall(function() return getconnections(joinBtn.MouseButton1Click) end)
                                            if success and conns then
                                                for _, conn in ipairs(conns) do
                                                    if conn.Fire then conn:Fire() end
                                                    if conn.Function then
                                                        task.spawn(conn.Function)
                                                    end
                                                    clicked = true
                                                end
                                            end
                                        end
                                    end
                                    
                                    if not clicked then
                                        local cd = joinBtn:FindFirstChildWhichIsA("ClickDetector")
                                        if cd then
                                            fireclickdetector(cd)
                                            clicked = true
                                        end
                                    end

                                    if not clicked then
                                        local absPos = joinBtn.AbsolutePosition
                                        local absSize = joinBtn.AbsoluteSize
                                        local centerX = absPos.X + absSize.X/2 - 5
                                        local centerY = absPos.Y + absSize.Y/2
                                        
                                        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                                        task.wait(0.05)
                                        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- Determine if timer is inactive (round ended) - used by Kabur & TP <10
        local isTimerInactive = false
        if seconds then
            isTimerInactive = (tick() - lastTimerChangeTick) > 5
        else
            isTimerInactive = true -- no timer visible = not in active round
        end

        -- Kabur Mode: Check for dangerous players
        if kaburMode and not isKaburTeleporting and (now - lastKaburCheck > KABUR_CHECK_RATE) then
            lastKaburCheck = now
            
            -- If WaitRound is ON, only flee when timer is inactive (round ended)
            local canFlee = true
            if kaburWaitRound and not isTimerInactive then
                canFlee = false
            end
            
            if canFlee and kaburAttempts < MAX_KABUR_ATTEMPTS then
                local dangerPlayer = nil
                local dangerReason = ""
                local dangerExec = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Players.LocalPlayer then
                        -- Check group rank (Tester/Contributor/Mod/Admin/Owner)
                        local cachedRank = GroupRankCache[p.UserId]
                        if cachedRank and cachedRank >= DANGER_RANK then
                            dangerPlayer = p
                            dangerReason = "Rank " .. cachedRank
                            break -- rank is highest priority, flee immediately
                        end
                        
                        -- Check executions
                        local ls = p:FindFirstChild("leaderstats")
                        if ls then
                            local exec = ls:FindFirstChild("Executions")
                            if exec and typeof(exec.Value) == "number" and exec.Value >= kaburThreshold then
                                if exec.Value > dangerExec then
                                    dangerPlayer = p
                                    dangerExec = exec.Value
                                    dangerReason = dangerExec .. " exec"
                                end
                            end
                        end
                    end
                end
                
                if dangerPlayer then
                    isKaburTeleporting = true
                    kaburAttempts = kaburAttempts + 1
                    ShowToast("KABUR! " .. dangerPlayer.Name .. " (" .. dangerReason .. ")", "warning")
                    
                    task.spawn(function()
                        task.wait(2)
                        
                        local success, result = pcall(function()
                            return request({
                                Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25",
                                Method = "GET"
                            })
                        end)
                        
                        if success and result and result.Body then
                            local data = HttpService:JSONDecode(result.Body)
                            if data and data.data then
                                -- Sort by largest server
                                table.sort(data.data, function(a,b) return (a.playing or 0) > (b.playing or 0) end)
                                
                                local targetServer = nil
                                for _, srv in ipairs(data.data) do
                                    if srv.id and srv.id ~= game.JobId and srv.playing and srv.playing > 0 then
                                        targetServer = srv
                                        break
                                    end
                                end
                                
                                if targetServer then
                                    ShowToast("Teleporting... (" .. kaburAttempts .. "/" .. MAX_KABUR_ATTEMPTS .. ")", "success")
                                    
                                    if queue_on_teleport then
                                        queue_on_teleport('loadstring(game:HttpGet("https://find.wagate.biz.id/hm1.lua"))()')
                                    end
                                    
                                    pcall(function()
                                        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, targetServer.id, Players.LocalPlayer)
                                    end)
                                else
                                    ShowToast("No safe server found", "error")
                                    isKaburTeleporting = false
                                end
                            else
                                ShowToast("Server fetch failed", "error")
                                isKaburTeleporting = false
                            end
                        else
                            ShowToast("Server fetch failed", "error")
                            isKaburTeleporting = false
                        end
                    end)
                end
            elseif kaburAttempts >= MAX_KABUR_ATTEMPTS then
                kaburMode = false
                Config.KaburMode = false
                KaburBtn.Text = "Kabur: OFF"
                KaburBtn.TextColor3 = THEME.SubText
                ShowToast("Kabur stopped (max " .. MAX_KABUR_ATTEMPTS .. " attempts)", "error")
                SaveConfig()
            end
        end

        -- Auto Teleport Low Players: Check if server has < 10 players
        if autoTeleportLow and not isLowTeleporting and not isKaburTeleporting and (now - lastLowPlayerCheck > LOW_PLAYER_CHECK_RATE) then
            lastLowPlayerCheck = now
            
            -- Grace period: don't check in the first 20 seconds after script start
            -- Only teleport when timer is inactive (round ended)
            if (now - scriptStartTime) > 20 and isTimerInactive then
                local playerCount = #Players:GetPlayers()
                if playerCount < 10 and lowPlayerAttempts < MAX_LOW_ATTEMPTS then
                    isLowTeleporting = true
                    lowPlayerAttempts = lowPlayerAttempts + 1
                    ShowToast("Server low (" .. playerCount .. " players), teleporting...", "warning")
                    
                    task.spawn(function()
                        task.wait(2)
                        
                        local success, result = pcall(function()
                            return request({
                                Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=25",
                                Method = "GET"
                            })
                        end)
                        
                        if success and result and result.Body then
                            local data = HttpService:JSONDecode(result.Body)
                            if data and data.data then
                                -- Sort by largest server
                                table.sort(data.data, function(a,b) return (a.playing or 0) > (b.playing or 0) end)
                                
                                local targetServer = nil
                                for _, srv in ipairs(data.data) do
                                    if srv.id and srv.id ~= game.JobId and srv.playing and srv.playing > 0 and srv.playing <= 25 then
                                        targetServer = srv
                                        break
                                    end
                                end
                                
                                if targetServer then
                                    ShowToast("Moving to server (" .. targetServer.playing .. " players)", "success")
                                    
                                    if queue_on_teleport then
                                        queue_on_teleport('loadstring(game:HttpGet("https://find.wagate.biz.id/hm1.lua"))()')
                                    end
                                    
                                    pcall(function()
                                        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, targetServer.id, Players.LocalPlayer)
                                    end)
                                else
                                    ShowToast("No safe server found", "error")
                                    isLowTeleporting = false
                                end
                            else
                                isLowTeleporting = false
                            end
                        else
                            isLowTeleporting = false
                        end
                    end)
                elseif lowPlayerAttempts >= MAX_LOW_ATTEMPTS then
                    autoTeleportLow = false
                    Config.AutoTeleportLow = false
                    AutoTPLowBtn.Text = "TP <10: OFF"
                    AutoTPLowBtn.TextColor3 = THEME.SubText
                    ShowToast("Auto TP stopped (max " .. MAX_LOW_ATTEMPTS .. " attempts)", "error")
                    SaveConfig()
                end
            end
        end

        local typeLbl = frame and frame:FindFirstChild("Type")
        local typeVisible = typeLbl and typeLbl.Visible
        if typeVisible and not lastTypeVisible then
            UsedWords = {}
            shuffleTable(KillerSuffixes)
            StatusText.Text = "New Round - Words & Killer Reset"
            StatusText.TextColor3 = THEME.Success
        end
        lastTypeVisible = typeVisible

        -- Auto-clear UsedWords on timer inactivity
        if seconds then
            if seconds ~= lastTimerValue then
                lastTimerValue = seconds
                lastTimerChangeTick = tick()
            end
            if (tick() - lastTimerChangeTick) > 4 then
                if next(UsedWords) then
                    UsedWords = {}
                    shuffleTable(KillerSuffixes)
                    StatusText.Text = "Inactivity - Words & Killer Reset"
                end
            end
        elseif not isVisible then
            if next(UsedWords) then
                UsedWords = {}
                shuffleTable(KillerSuffixes)
                StatusText.Text = "Round Ended - Words & Killer Reset"
            end
        end

        -- Auto Blatant Mode Logic
        if blatantMode == "Auto" then
            if isMyTurn and seconds and seconds <= blatantThreshold then
                if not savedBlatantSettings then
                    -- Backup current settings
                    savedBlatantSettings = {
                        CPM = currentCPM,
                        Humanize = useHumanization,
                        Error = errorRate,
                        Sort = sortMode,
                        Blatant = isBlatant
                    }
                    -- Apply Blatant settings
                    isBlatant = true
                    useHumanization = false
                    errorRate = 0
                    sortMode = "Shortest"
                    
                    -- Clear existing text to re-type correctly in blatant mode
                    if detected ~= "" and not isTyping then
                        task.spawn(function()
                            Backspace(#detected + 2)
                        end)
                    end
                end
            elseif savedBlatantSettings then
                -- Turn finished or timer reset - Restore original settings
                if not isMyTurn or not isVisible or (seconds and seconds > blatantThreshold) then
                    currentCPM = savedBlatantSettings.CPM
                    useHumanization = savedBlatantSettings.Humanize
                    errorRate = savedBlatantSettings.Error
                    sortMode = savedBlatantSettings.Sort
                    isBlatant = savedBlatantSettings.Blatant
                    savedBlatantSettings = nil
                end
            end
        end

        if censored then
            if StatusText.Text ~= "Word is Censored" then
                StatusText.Text = "Word is Censored"
                StatusText.TextColor3 = THEME.Warning
                Tween(StatusDot, {BackgroundColor3 = THEME.Warning})
                
                for _, btn in ipairs(ButtonCache) do btn.Visible = false end
                StatsData.Count.Text = "Words: 0"
            end
            
            listUpdatePending = false
            forceUpdateList = false
            currentBestMatch = nil
            lastDetected = detected
            lastRequiredLetter = requiredLetter
        end
        
        if listUpdatePending and (now - lastInputTime > LIST_DEBOUNCE) then
            listUpdatePending = false
            local visCount = UpdateList(lastDetected, lastRequiredLetter) or 0
            StatsData.Count.Text = "Words: " .. visCount .. "+"
        end

        if not isVisible then
            if StatusText.Text ~= "Not in Round" then
                StatusText.Text = "Not in Round"
                StatusText.TextColor3 = THEME.SubText
                Tween(StatusDot, {BackgroundColor3 = THEME.SubText})
                for _, btn in ipairs(ButtonCache) do btn.Visible = false end
                StatsData.Count.Text = "Words: 0"
            end
            lastDetected = "---"
        elseif detected ~= lastDetected or requiredLetter ~= lastRequiredLetter or forceUpdateList then
            currentBestMatch = nil
            lastDetected = detected
            lastRequiredLetter = requiredLetter
            
            if detected == "" and not forceUpdateList then
                StatusText.Text = "Waiting..."
                StatusText.TextColor3 = THEME.SubText
                Tween(StatusDot, {BackgroundColor3 = THEME.SubText})
                
                local visCount = UpdateList("", requiredLetter) or 0
                listUpdatePending = false
                StatsData.Count.Text = "Words: " .. visCount .. "+"
            else
                if detected ~= "" then
                    local isCompleted = false
                    if #detected > 2 then
                        if WordSet[detected] then
                            isCompleted = true
                        end
                    end

                    if isCompleted then
                        StatusText.Text = "Completed: " .. detected .. " <font color=\"rgb(100,255,140)\">✓</font>"
                        StatusText.TextColor3 = THEME.Success
                        Tween(StatusDot, {BackgroundColor3 = THEME.Success})
                    else
                        StatusText.Text = "Input: " .. detected
                        StatusText.TextColor3 = THEME.Accent
                        Tween(StatusDot, {BackgroundColor3 = THEME.Warning})
                    end
                end
                
                if forceUpdateList then
                    listUpdatePending = true
                    lastInputTime = 0
                    forceUpdateList = false
                else
                    listUpdatePending = true
                    lastInputTime = now
                end
            end
        end

        if autoPlay and not isTyping and not isAutoPlayScheduled and currentBestMatch and detected == lastDetected then
            local isMyTurnCheck, _ = GetTurnInfo(frame)
            if isMyTurnCheck then
                isAutoPlayScheduled = true
                local targetWord = currentBestMatch
                local snapshotDetected = lastDetected
                
                task.spawn(function()
                    local delay
                    if isBlatant then
                        delay = 0.15
                    else
                        -- Human-like think delay: varies by word length and adds "reading" time
                        local wordLen = #targetWord
                        local prefixLen = #snapshotDetected
                        local charsToType = wordLen - prefixLen
                        
                        -- Base reading time: longer prefix = more to read/process
                        local readTime = 0.2 + (prefixLen * 0.05) + (math.random() * 0.15)
                        
                        -- Word recall time: longer words take more time to think of
                        local recallTime
                        if charsToType <= 3 then
                            recallTime = 0.15 + math.random() * 0.2  -- Short word, quick recall
                        elseif charsToType <= 6 then
                            recallTime = 0.25 + math.random() * 0.35 -- Medium word
                        else
                            recallTime = 0.4 + math.random() * 0.5   -- Long word, more thinking
                        end
                        
                        -- Occasional "I know this instantly" moment (15% chance)
                        if math.random() < 0.15 then
                            recallTime = recallTime * 0.4
                        end
                        -- Occasional hesitation (8% chance)
                        if math.random() < 0.08 then
                            recallTime = recallTime + 0.3 + math.random() * 0.5
                        end
                        
                        delay = readTime + recallTime
                    end
                    task.wait(delay)
                    
                    local stillMyTurn, _ = GetTurnInfo()
                    if autoPlay and not isTyping and GetCurrentGameWord() == snapshotDetected and stillMyTurn then
                         SmartType(targetWord, snapshotDetected, false)
                    end
                    isAutoPlayScheduled = false
                end)
            end
        end
    end)
end)

inputConn = UserInputService.InputBegan:Connect(function(input)
    if unloaded then return end
    if input.KeyCode == TOGGLE_KEY then ScreenGui.Enabled = not ScreenGui.Enabled end
end)