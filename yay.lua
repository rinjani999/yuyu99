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
local MAX_CPM_BLATANT = 3000

math.randomseed(os.time())

local THEME = {
    Background = Color3.fromRGB(20, 20, 24),
    ItemBG = Color3.fromRGB(32, 32, 38),
    Accent = Color3.fromRGB(114, 100, 255),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    Success = Color3.fromRGB(100, 255, 140),
    Warning = Color3.fromRGB(255, 200, 80),
    Slider = Color3.fromRGB(60, 60, 70),
    Error = Color3.fromRGB(255, 80, 80)
}

local function ColorToRGB(c)
    return string.format("%d,%d,%d", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local ConfigFile = "WordHelper_Config.json"
local BlacklistFile = "blacklist.json" -- File blacklist terpisah

local Config = {
    CPM = 550,
    BlatantMode = "OFF", -- OFF, ON, AUTO
    Humanize = true,
    FingerModel = true,
    SortMode = "Random",
    SuffixMode = "",
    LengthMode = 0,
    AutoPlay = false,
    AutoJoin = false,
    AutoJoinSettings = {
        _1v1 = true,
        _4p = true,
        _8p = true
    },
    PanicMode = true,
    ShowKeyboard = false,
    ErrorRate = 5,
    ThinkDelay = 0.8,
    RiskyMistakes = false,
    CustomWords = {},
    KeyboardLayout = "QWERTY"
}

-- === SYSTEM FILES ===

local Blacklist = {}

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
            -- Migrasi legacy blatant bool ke string jika perlu
            if type(Config.BlatantMode) == "boolean" then
                Config.BlatantMode = Config.BlatantMode and "ON" or "OFF"
            end
        end
    end
end

local function SaveBlacklist()
    if writefile then
        writefile(BlacklistFile, HttpService:JSONEncode(Blacklist))
    end
end

local function LoadBlacklist()
    if isfile and isfile(BlacklistFile) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(BlacklistFile)) end)
        if success and decoded then
            Blacklist = decoded
        end
    end
end

LoadConfig()
LoadBlacklist()

local function AddToBlacklist(word)
    if not word then return end
    Blacklist[word] = true
    SaveBlacklist()
end

local function RemoveFromBlacklist(word)
    if not word then return end
    Blacklist[word] = nil
    SaveBlacklist()
end

-- === VARIABLES ===

local currentCPM = Config.CPM
local blatantMode = Config.BlatantMode or "OFF" 
local isBlatantActive = false -- Internal flag untuk auto mode
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
local keyboardLayout = Config.KeyboardLayout or "QWERTY"

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

local UsedWords = {} -- Cache per ronde
local RandomOrderCache = {}
local lastDetected = "---"
local lastWordCheck = 0
local cachedDetected = ""
local cachedCensored = false
local lastAutoJoinCheck = 0
local AUTO_JOIN_RATE = 0.5

local UpdateList
local ButtonCache = {}
local ButtonData = {}
local JoinDebounce = {}
local thinkDelayMin = 0.4
local thinkDelayMax = 1.2

local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil

-- === LOGGING ===

if logConn then logConn:Disconnect() end
logConn = LogService.MessageOut:Connect(function(message, type)
    local wordPart, timePart = message:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
    if wordPart and timePart then
        isMyTurnLogDetected = true
        logRequiredLetters = wordPart
        turnExpiryTime = tick() + tonumber(timePart)
    end
end)

-- === DICTIONARY ===

local url = "https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/tralala.txt"
local fileName = "ultimate_words_v4.txt"

-- Temporary Loading UI
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "WordHelperLoading"
local success, parent = pcall(function() return gethui() end)
if not success or not parent then parent = game:GetService("CoreGui") end
LoadingGui.Parent = parent
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local LoadingFrame = Instance.new("Frame", LoadingGui)
LoadingFrame.Size = UDim2.new(0, 300, 0, 100)
LoadingFrame.Position = UDim2.new(0.5, -150, 0.4, 0)
LoadingFrame.BackgroundColor3 = THEME.Background
LoadingFrame.BorderSizePixel = 0
Instance.new("UICorner", LoadingFrame).CornerRadius = UDim.new(0, 10)
local LStroke = Instance.new("UIStroke", LoadingFrame)
LStroke.Color = THEME.Accent
LStroke.Transparency = 0.5
LStroke.Thickness = 2

local LoadingTitle = Instance.new("TextLabel", LoadingFrame)
LoadingTitle.Size = UDim2.new(1, 0, 0, 40)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Text = "Last Letter Ultimate"
LoadingTitle.TextColor3 = THEME.Accent
LoadingTitle.Font = Enum.Font.GothamBold
LoadingTitle.TextSize = 18

local LoadingStatus = Instance.new("TextLabel", LoadingFrame)
LoadingStatus.Size = UDim2.new(1, -20, 0, 30)
LoadingStatus.Position = UDim2.new(0, 10, 0, 50)
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Text = "Initializing..."
LoadingStatus.TextColor3 = THEME.Text
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.TextSize = 14

local function UpdateStatus(text, color)
    LoadingStatus.Text = text
    if color then LoadingStatus.TextColor3 = color end
    game:GetService("RunService").RenderStepped:Wait()
end

local function FetchWords()
    UpdateStatus("Fetching dictionary...", THEME.Warning)
    local success, res = pcall(function()
        return request({Url = url, Method = "GET"})
    end)
    
    if success and res and res.Body then
        writefile(fileName, res.Body)
        UpdateStatus("Fetched successfully!", THEME.Success)
    else
        UpdateStatus("Fetch failed! Using cached.", THEME.Error)
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
         UpdateStatus("No word list found!", THEME.Error)
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
SeenWords = nil -- Clear memory

-- === HELPER FUNCTIONS ===

local function shuffleTable(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local HardLetterScores = {
    x = 10, z = 9, q = 9, j = 8, v = 6, k = 5, b = 4, f = 3, w = 3,
    y = 2, g = 2, p = 2
}

local function GetKillerScore(word)
    local lastChar = word:sub(-1)
    return HardLetterScores[lastChar] or 0
end

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

-- === NEW: STRIKE DETECTION ===
local function GetActiveStrikeCount()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
    
    if not frame then return 0 end

    -- Biasanya strikes ada di dalam container atau langsung di frame
    -- Kita cari ImageLabel yang berwarna merah (tanda silang aktif)
    local count = 0
    local descendants = frame:GetDescendants()
    
    for _, obj in ipairs(descendants) do
        if obj:IsA("ImageLabel") and obj.Visible then
            -- Cek apakah gambarnya adalah "X" dan warnanya merah
            -- Kita pakai threshold warna karena kadang ada efek transisi
            local col = obj.ImageColor3
            if col.R > 0.8 and col.G < 0.2 and col.B < 0.2 then
                -- Ini kemungkinan besar adalah X merah (Strike aktif)
                -- Pastikan bukan background atau dekorasi lain, biasanya strike ukurannya kecil
                if obj.AbsoluteSize.X < 50 and obj.AbsoluteSize.X > 5 then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- === UI SETUP ===

local function GetSecureParent()
    local success, result = pcall(function() return gethui() end)
    if success and result then return result end
    return Players.LocalPlayer.PlayerGui
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = tostring(math.random(1000000, 9999999))
ScreenGui.Parent = GetSecureParent()
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
env.WordHelperInstance = ScreenGui

local ToastContainer = Instance.new("Frame", ScreenGui)
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 300, 1, 0)
ToastContainer.Position = UDim2.new(1, -320, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 100

local function ShowToast(message, type)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 40)
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
    elseif type == "error" then color = THEME.Error
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
    lbl.TextSize = 14
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
MainFrame.Size = UDim2.new(0, 300, 0, 500)
MainFrame.Position = UDim2.new(0.8, -50, 0.4, 0)
MainFrame.BackgroundColor3 = THEME.Background
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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then Update(input) end
    end)
end
EnableDragging(MainFrame)

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = THEME.Accent
Stroke.Transparency = 0.5
Stroke.Thickness = 2

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = THEME.ItemBG
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Text = "Last Letter <font color=\"rgb(114,100,255)\">Ultimate</font>"
Title.RichText = true
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = THEME.Text
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 24
MinBtn.TextColor3 = THEME.SubText
MinBtn.Size = UDim2.new(0, 45, 1, 0)
MinBtn.Position = UDim2.new(1, -90, 0, 0)
MinBtn.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.TextColor3 = THEME.Error
CloseBtn.Size = UDim2.new(0, 45, 1, 0)
CloseBtn.Position = UDim2.new(1, -45, 0, 0)
CloseBtn.BackgroundTransparency = 1

CloseBtn.MouseButton1Click:Connect(function()
    unloaded = true
    if runConn then runConn:Disconnect() end
    if inputConn then inputConn:Disconnect() end
    if logConn then logConn:Disconnect() end
    ScreenGui:Destroy()
end)

local StatusFrame = Instance.new("Frame", MainFrame)
StatusFrame.Size = UDim2.new(1, -30, 0, 24)
StatusFrame.Position = UDim2.new(0, 15, 0, 55)
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
StatusText.TextSize = 12
StatusText.TextColor3 = THEME.SubText
StatusText.Size = UDim2.new(1, -15, 1, 0)
StatusText.Position = UDim2.new(0, 15, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left

local SearchFrame = Instance.new("Frame", MainFrame)
SearchFrame.Size = UDim2.new(1, -10, 0, 26)
SearchFrame.Position = UDim2.new(0, 5, 0, 82)
SearchFrame.BackgroundColor3 = THEME.ItemBG
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 6)

local SearchBox = Instance.new("TextBox", SearchFrame)
SearchBox.Size = UDim2.new(1, -20, 1, 0)
SearchBox.Position = UDim2.new(0, 10, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 14
SearchBox.TextColor3 = THEME.Text
SearchBox.PlaceholderText = "Search words..."
SearchBox.PlaceholderColor3 = THEME.SubText
SearchBox.Text = ""
SearchBox.TextXAlignment = Enum.TextXAlignment.Left

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if UpdateList then UpdateList(lastDetected, logRequiredLetters) end
end)

local ScrollList = Instance.new("ScrollingFrame", MainFrame)
ScrollList.Size = UDim2.new(1, -10, 1, -220)
ScrollList.Position = UDim2.new(0, 5, 0, 115)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 3
ScrollList.ScrollBarImageColor3 = THEME.Accent
ScrollList.CanvasSize = UDim2.new(0,0,0,0)

local UIListLayout = Instance.new("UIListLayout", ScrollList)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)

local SettingsFrame = Instance.new("Frame", MainFrame)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ClipsDescendants = true

local SlidersFrame = Instance.new("Frame", SettingsFrame)
SlidersFrame.Size = UDim2.new(1, 0, 0, 125)
SlidersFrame.BackgroundTransparency = 1

local TogglesFrame = Instance.new("Frame", SettingsFrame)
TogglesFrame.Size = UDim2.new(1, 0, 0, 310)
TogglesFrame.Position = UDim2.new(0, 0, 0, 125)
TogglesFrame.BackgroundTransparency = 1
TogglesFrame.Visible = false

local settingsCollapsed = true
local function UpdateLayout()
    if settingsCollapsed then
        Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 125), Position = UDim2.new(0, 0, 1, -125)})
        Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -245)})
        TogglesFrame.Visible = false
    else
        Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 435), Position = UDim2.new(0, 0, 1, -435)})
        Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -555)})
        TogglesFrame.Visible = true
    end
end
UpdateLayout()

local ExpandBtn = Instance.new("TextButton", SlidersFrame)
ExpandBtn.Text = "v Show Settings v"
ExpandBtn.Font = Enum.Font.GothamBold
ExpandBtn.TextSize = 14
ExpandBtn.TextColor3 = THEME.Accent
ExpandBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
ExpandBtn.BackgroundTransparency = 0.5
ExpandBtn.Size = UDim2.new(1, -10, 0, 30)
ExpandBtn.Position = UDim2.new(0, 5, 1, -35)
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 6)

ExpandBtn.MouseButton1Click:Connect(function()
    settingsCollapsed = not settingsCollapsed
    ExpandBtn.Text = settingsCollapsed and "v Show Settings v" or "^ Hide Settings ^"
    UpdateLayout()
end)

-- Slider Setup
local function SetupSlider(btn, bg, fill, callback)
    btn.MouseButton1Down:Connect(function()
        local move, rel
        local function Update()
            local mousePos = UserInputService:GetMouseLocation()
            local relX = math.clamp(mousePos.X - bg.AbsolutePosition.X, 0, bg.AbsoluteSize.X)
            local pct = relX / bg.AbsoluteSize.X
            callback(pct)
            Config.CPM = currentCPM
            Config.ErrorRate = errorRate
            Config.ThinkDelay = thinkDelayCurrent
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

-- Keyboard UI
local KeyboardFrame = Instance.new("Frame", ScreenGui)
KeyboardFrame.Name = "KeyboardFrame"
KeyboardFrame.Size = UDim2.new(0, 400, 0, 160)
KeyboardFrame.Position = UDim2.new(0.1, 0, 0.5, -80)
KeyboardFrame.BackgroundColor3 = THEME.Background
KeyboardFrame.Visible = showKeyboard
EnableDragging(KeyboardFrame)
Instance.new("UICorner", KeyboardFrame).CornerRadius = UDim.new(0, 8)
local KStroke = Instance.new("UIStroke", KeyboardFrame)
KStroke.Color = THEME.Accent
KStroke.Transparency = 0.6
KStroke.Thickness = 2

local Keys = {}
local function CreateKey(char, pos, size)
    local k = Instance.new("Frame", KeyboardFrame)
    k.Size = size or UDim2.new(0, 30, 0, 30)
    k.Position = pos
    k.BackgroundColor3 = THEME.ItemBG
    Instance.new("UICorner", k).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel", k)
    l.Size = UDim2.new(1,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = char:upper()
    l.TextColor3 = THEME.Text
    l.Font = Enum.Font.GothamBold
    l.TextSize = 14
    Keys[char:lower()] = k
    return k
end

local function GenerateKeyboard()
    for _, c in ipairs(KeyboardFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    Keys = {}
    local rows
    if keyboardLayout == "QWERTZ" then
        rows = {{"q","w","e","r","t","z","u","i","o","p"},{"a","s","d","f","g","h","j","k","l"},{"y","x","c","v","b","n","m"}}
    elseif keyboardLayout == "AZERTY" then
        rows = {{"a","z","e","r","t","y","u","i","o","p"},{"q","s","d","f","g","h","j","k","l","m"},{"w","x","c","v","b","n"}}
    else
        rows = {{"q","w","e","r","t","y","u","i","o","p"},{"a","s","d","f","g","h","j","k","l"},{"z","x","c","v","b","n","m"}}
    end
    local startY = 15
    for r, rowChars in ipairs(rows) do
        local rowWidth = #rowChars * 35
        local startX = (400 - rowWidth) / 2
        for i, char in ipairs(rowChars) do
            CreateKey(char, UDim2.new(0, startX + (i-1)*35, 0, startY + (r-1)*35))
        end
    end
    local space = CreateKey(" ", UDim2.new(0.5, -100, 0, startY + 3*35), UDim2.new(0, 200, 0, 30))
    space.FindFirstChild(space, "TextLabel").Text = "SPACE"
end
GenerateKeyboard()

local SliderLabel = Instance.new("TextLabel", SlidersFrame)
SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
SliderLabel.Font = Enum.Font.GothamMedium
SliderLabel.TextSize = 12
SliderLabel.TextColor3 = THEME.SubText
SliderLabel.Size = UDim2.new(1, -30, 0, 20)
SliderLabel.Position = UDim2.new(0, 15, 0, 8)
SliderLabel.BackgroundTransparency = 1
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local SliderBg = Instance.new("Frame", SlidersFrame)
SliderBg.Size = UDim2.new(1, -30, 0, 6)
SliderBg.Position = UDim2.new(0, 15, 0, 30)
SliderBg.BackgroundColor3 = THEME.Slider
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame", SliderBg)
SliderFill.Size = UDim2.new(0.5, 0, 1, 0)
SliderFill.BackgroundColor3 = THEME.Accent
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local SliderBtn = Instance.new("TextButton", SliderBg)
SliderBtn.Size = UDim2.new(1,0,1,0)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Text = ""

SetupSlider(SliderBtn, SliderBg, SliderFill, function(pct)
    local max = (blatantMode ~= "OFF") and MAX_CPM_BLATANT or MAX_CPM_LEGIT
    currentCPM = math.floor(MIN_CPM + (pct * (max - MIN_CPM)))
    SliderFill.Size = UDim2.new(pct, 0, 1, 0)
    SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
    if currentCPM > 900 then Tween(SliderFill, {BackgroundColor3 = THEME.Error}) 
    else Tween(SliderFill, {BackgroundColor3 = THEME.Accent}) end
end)

local function CreateToggle(text, pos, callback)
    local btn = Instance.new("TextButton", TogglesFrame)
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextColor3 = THEME.Success
    btn.BackgroundColor3 = THEME.Background
    btn.Size = UDim2.new(0, 85, 0, 24)
    btn.Position = pos
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function()
        local _, newText, newColor = callback()
        btn.Text = newText
        btn.TextColor3 = newColor
        SaveConfig()
    end)
    return btn
end

-- Toggles
CreateToggle("Humanize: "..(useHumanization and "ON" or "OFF"), UDim2.new(0, 15, 0, 5), function()
    useHumanization = not useHumanization
    Config.Humanize = useHumanization
    return useHumanization, "Humanize: "..(useHumanization and "ON" or "OFF"), useHumanization and THEME.Success or THEME.Error
end)

CreateToggle("10-Finger: "..(useFingerModel and "ON" or "OFF"), UDim2.new(0, 105, 0, 5), function()
    useFingerModel = not useFingerModel
    Config.FingerModel = useFingerModel
    return useFingerModel, "10-Finger: "..(useFingerModel and "ON" or "OFF"), useFingerModel and THEME.Success or THEME.Error
end)

CreateToggle("Keyboard: "..(showKeyboard and "ON" or "OFF"), UDim2.new(0, 195, 0, 5), function()
    showKeyboard = not showKeyboard
    Config.ShowKeyboard = showKeyboard
    KeyboardFrame.Visible = showKeyboard
    return showKeyboard, "Keyboard: "..(showKeyboard and "ON" or "OFF"), showKeyboard and THEME.Success or THEME.Error
end)

CreateToggle("Sort: "..sortMode, UDim2.new(0, 15, 0, 33), function()
    if sortMode == "Random" then sortMode = "Shortest"
    elseif sortMode == "Shortest" then sortMode = "Longest"
    elseif sortMode == "Longest" then sortMode = "Killer"
    else sortMode = "Random" end
    Config.SortMode = sortMode
    lastDetected = "---"
    return true, "Sort: "..sortMode, THEME.Accent
end)

CreateToggle("Auto Play: "..(autoPlay and "ON" or "OFF"), UDim2.new(0, 150, 0, 33), function()
    autoPlay = not autoPlay
    Config.AutoPlay = autoPlay
    return autoPlay, "Auto Play: "..(autoPlay and "ON" or "OFF"), autoPlay and THEME.Success or THEME.Error
end)

local AutoJoinBtn = CreateToggle("Auto Join: "..(autoJoin and "ON" or "OFF"), UDim2.new(0, 15, 0, 61), function()
    autoJoin = not autoJoin
    Config.AutoJoin = autoJoin
    return autoJoin, "Auto Join: "..(autoJoin and "ON" or "OFF"), autoJoin and THEME.Success or THEME.Error
end)
AutoJoinBtn.Size = UDim2.new(0, 265, 0, 24)

-- Blatant Mode: OFF -> ON -> AUTO -> OFF
local BlatantBtn = CreateToggle("Blatant: "..blatantMode, UDim2.new(0, 15, 0, 115), function()
    if blatantMode == "OFF" then blatantMode = "ON"
    elseif blatantMode == "ON" then blatantMode = "AUTO"
    else blatantMode = "OFF" end
    
    Config.BlatantMode = blatantMode
    
    local color = THEME.SubText
    if blatantMode == "ON" then color = THEME.Error
    elseif blatantMode == "AUTO" then color = THEME.Warning
    end
    
    return true, "Blatant: "..blatantMode, color
end)
BlatantBtn.TextColor3 = (blatantMode=="ON" and THEME.Error) or (blatantMode=="AUTO" and THEME.Warning) or THEME.SubText
BlatantBtn.Size = UDim2.new(0, 130, 0, 24)

local RiskyBtn = CreateToggle("Risky: "..(riskyMistakes and "ON" or "OFF"), UDim2.new(0, 150, 0, 115), function()
    riskyMistakes = not riskyMistakes
    Config.RiskyMistakes = riskyMistakes
    return riskyMistakes, "Risky: "..(riskyMistakes and "ON" or "OFF"), riskyMistakes and THEME.Error or THEME.SubText
end)
RiskyBtn.Size = UDim2.new(0, 130, 0, 24)

-- Menus
local ManageWordsBtn = Instance.new("TextButton", TogglesFrame)
ManageWordsBtn.Text = "Manage Custom Words"
ManageWordsBtn.Font = Enum.Font.GothamMedium
ManageWordsBtn.TextSize = 11
ManageWordsBtn.TextColor3 = THEME.Accent
ManageWordsBtn.BackgroundColor3 = THEME.Background
ManageWordsBtn.Size = UDim2.new(0, 130, 0, 24)
ManageWordsBtn.Position = UDim2.new(0, 15, 0, 145)
Instance.new("UICorner", ManageWordsBtn).CornerRadius = UDim.new(0, 4)

local BlacklistManagerBtn = Instance.new("TextButton", TogglesFrame)
BlacklistManagerBtn.Text = "Blacklist Manager"
BlacklistManagerBtn.Font = Enum.Font.GothamMedium
BlacklistManagerBtn.TextSize = 11
BlacklistManagerBtn.TextColor3 = THEME.Error
BlacklistManagerBtn.BackgroundColor3 = THEME.Background
BlacklistManagerBtn.Size = UDim2.new(0, 130, 0, 24)
BlacklistManagerBtn.Position = UDim2.new(0, 150, 0, 145)
Instance.new("UICorner", BlacklistManagerBtn).CornerRadius = UDim.new(0, 4)

local WordBrowserBtn = Instance.new("TextButton", TogglesFrame)
WordBrowserBtn.Text = "Word Browser"
WordBrowserBtn.Font = Enum.Font.GothamMedium
WordBrowserBtn.TextSize = 11
WordBrowserBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
WordBrowserBtn.BackgroundColor3 = THEME.Background
WordBrowserBtn.Size = UDim2.new(0, 265, 0, 24)
WordBrowserBtn.Position = UDim2.new(0, 15, 0, 175)
Instance.new("UICorner", WordBrowserBtn).CornerRadius = UDim.new(0, 4)

local ServerBrowserBtn = Instance.new("TextButton", TogglesFrame)
ServerBrowserBtn.Text = "Server Browser"
ServerBrowserBtn.Font = Enum.Font.GothamMedium
ServerBrowserBtn.TextSize = 11
ServerBrowserBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
ServerBrowserBtn.BackgroundColor3 = THEME.Background
ServerBrowserBtn.Size = UDim2.new(0, 265, 0, 24)
ServerBrowserBtn.Position = UDim2.new(0, 15, 0, 205)
Instance.new("UICorner", ServerBrowserBtn).CornerRadius = UDim.new(0, 4)

-- === UI: BLACKLIST MANAGER ===

local BlacklistFrame = Instance.new("Frame", ScreenGui)
BlacklistFrame.Name = "BlacklistFrame"
BlacklistFrame.Size = UDim2.new(0, 250, 0, 350)
BlacklistFrame.Position = UDim2.new(0.5, 135, 0.5, -175)
BlacklistFrame.BackgroundColor3 = THEME.Background
BlacklistFrame.Visible = false
BlacklistFrame.ClipsDescendants = true
BlacklistFrame.ZIndex = 200
EnableDragging(BlacklistFrame)
Instance.new("UICorner", BlacklistFrame).CornerRadius = UDim.new(0, 8)
local BLStroke = Instance.new("UIStroke", BlacklistFrame)
BLStroke.Color = THEME.Error
BLStroke.Transparency = 0.5
BLStroke.Thickness = 2

local BLHeader = Instance.new("TextLabel", BlacklistFrame)
BLHeader.Text = "Blacklist Manager"
BLHeader.Font = Enum.Font.GothamBold
BLHeader.TextSize = 14
BLHeader.TextColor3 = THEME.Text
BLHeader.Size = UDim2.new(1, 0, 0, 35)
BLHeader.BackgroundTransparency = 1
BLHeader.ZIndex = 201

local BLCloseBtn = Instance.new("TextButton", BlacklistFrame)
BLCloseBtn.Text = "X"
BLCloseBtn.Font = Enum.Font.GothamBold
BLCloseBtn.TextSize = 14
BLCloseBtn.TextColor3 = THEME.Error
BLCloseBtn.Size = UDim2.new(0, 30, 0, 30)
BLCloseBtn.Position = UDim2.new(1, -30, 0, 2)
BLCloseBtn.BackgroundTransparency = 1
BLCloseBtn.ZIndex = 202
BLCloseBtn.MouseButton1Click:Connect(function() BlacklistFrame.Visible = false end)

local BLSearchBox = Instance.new("TextBox", BlacklistFrame)
BLSearchBox.Font = Enum.Font.Gotham
BLSearchBox.TextSize = 12
BLSearchBox.BackgroundColor3 = THEME.ItemBG
BLSearchBox.TextColor3 = THEME.Text
BLSearchBox.PlaceholderText = "Search blacklist..."
BLSearchBox.PlaceholderColor3 = THEME.SubText
BLSearchBox.Size = UDim2.new(1, -20, 0, 24)
BLSearchBox.Position = UDim2.new(0, 10, 0, 35)
BLSearchBox.ZIndex = 202
Instance.new("UICorner", BLSearchBox).CornerRadius = UDim.new(0, 4)

local BLScroll = Instance.new("ScrollingFrame", BlacklistFrame)
BLScroll.Size = UDim2.new(1, -10, 1, -70)
BLScroll.Position = UDim2.new(0, 5, 0, 65)
BLScroll.BackgroundTransparency = 1
BLScroll.ScrollBarThickness = 2
BLScroll.ScrollBarImageColor3 = THEME.Error
BLScroll.CanvasSize = UDim2.new(0,0,0,0)
BLScroll.ZIndex = 202
local BLListLayout = Instance.new("UIListLayout", BLScroll)
BLListLayout.SortOrder = Enum.SortOrder.LayoutOrder
BLListLayout.Padding = UDim.new(0, 2)

local function RefreshBlacklistUI()
    for _, c in ipairs(BLScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local query = BLSearchBox.Text:lower():gsub("[%s%c]+", "")
    local shownCount = 0
    local sortedList = {}
    
    for w, _ in pairs(Blacklist) do table.insert(sortedList, w) end
    table.sort(sortedList)

    for _, w in ipairs(sortedList) do
        if query == "" or w:find(query, 1, true) then
            shownCount = shownCount + 1
            local row = Instance.new("Frame", BLScroll)
            row.Size = UDim2.new(1, -6, 0, 22)
            row.BackgroundColor3 = (shownCount % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
            row.BorderSizePixel = 0
            row.ZIndex = 203
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
            
            local lbl = Instance.new("TextLabel", row)
            lbl.Text = w
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextColor3 = THEME.Text
            lbl.Size = UDim2.new(1, -30, 1, 0)
            lbl.Position = UDim2.new(0, 5, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 204

            local del = Instance.new("TextButton", row)
            del.Text = "X"
            del.Font = Enum.Font.GothamBold
            del.TextSize = 11
            del.TextColor3 = THEME.Error
            del.Size = UDim2.new(0, 22, 1, 0)
            del.Position = UDim2.new(1, -22, 0, 0)
            del.BackgroundTransparency = 1
            del.ZIndex = 204
            
            del.MouseButton1Click:Connect(function()
                RemoveFromBlacklist(w)
                RefreshBlacklistUI()
                ShowToast("Un-blacklisted: " .. w, "success")
            end)
            
            row.Parent = BLScroll
        end
    end
    BLScroll.CanvasSize = UDim2.new(0, 0, 0, shownCount * 24)
end

BLSearchBox:GetPropertyChangedSignal("Text"):Connect(RefreshBlacklistUI)
BlacklistManagerBtn.MouseButton1Click:Connect(function()
    BlacklistFrame.Visible = not BlacklistFrame.Visible
    BlacklistFrame.Parent = nil
    BlacklistFrame.Parent = ScreenGui
    if BlacklistFrame.Visible then RefreshBlacklistUI() end
end)

-- === TYPING LOGIC ===

local function CalculateDelay()
    local cpm = currentCPM
    if isBlatantActive or blatantMode == "ON" then cpm = MAX_CPM_BLATANT end
    
    local baseDelay = 60 / cpm
    local variance = baseDelay * 0.4
    return useHumanization and (baseDelay + math.random()*variance - (variance/2)) or baseDelay
end

local KEY_POS = {}
do
    local rows = {"qwertyuiop", "asdfghjkl", "zxcvbnm"}
    for r, row in ipairs(rows) do
        for i=1, #row do KEY_POS[row:sub(i,i)] = {x=i + (r-1)*0.5, y=r} end
    end
end

local function CalculateDelayForKeys(prevChar, nextChar)
    if isBlatantActive or blatantMode == "ON" then return 60 / MAX_CPM_BLATANT end

    local baseDelay = 60 / currentCPM
    local variance = baseDelay * 0.35
    local extra = 0
    
    if useHumanization and useFingerModel and prevChar and nextChar and KEY_POS[prevChar] and KEY_POS[nextChar] then
        local p1, p2 = KEY_POS[prevChar], KEY_POS[nextChar]
        local dist = math.sqrt((p1.x-p2.x)^2 + (p1.y-p2.y)^2)
        extra = dist * 0.018 * (550 / math.max(150, currentCPM))
    end

    if useHumanization then
        local r = (math.random() + math.random() + math.random()) / 3
        local noise = (r * 2 - 1) * variance
        return math.max(0.005, baseDelay + extra + noise)
    else
        return baseDelay
    end
end

local function SimulateKey(input)
    if type(input) == "string" then
        local vimSuccess = pcall(function() VirtualInputManager:SendTextInput(input) end)
        if not vimSuccess then
            local key = Enum.KeyCode[input:upper()]
            if key then
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end
        end
    elseif typeof(input) == "EnumItem" then
         VirtualInputManager:SendKeyEvent(true, input, false, game)
         task.wait(0.005)
         VirtualInputManager:SendKeyEvent(false, input, false, game)
    end
end

local function PressEnter()
    SimulateKey(Enum.KeyCode.Return)
end

local function GetGameTextBox()
    local focused = UserInputService:GetFocusedTextBox()
    if focused and focused:IsDescendantOf(game) then return focused end
    
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
    if frame then
        for _, c in ipairs(frame:GetDescendants()) do
            if c:IsA("TextBox") and c.Visible then return c end
        end
    end
    return nil
end

local function Backspace(count)
    local focused = UserInputService:GetFocusedTextBox()
    if focused then
        focused.Text = focused.Text:sub(1, -count - 1)
        return
    end
    for i = 1, count do
        SimulateKey(Enum.KeyCode.Backspace)
        if i % 10 == 0 then task.wait() end
    end
end

-- === MAIN SMART TYPE FUNCTION ===

local function SmartType(targetWord, currentDetected, isCorrection, bypassTurn)
    if unloaded then return end
    
    -- Reset typing state if stuck
    if isTyping and (tick() - lastTypingStart) > 15 then
        isTyping = false
    end
    if isTyping then return end

    isTyping = true
    lastTypingStart = tick()
    
    local targetBox = GetGameTextBox()
    if targetBox then
        targetBox:CaptureFocus()
        task.wait(0.1)
    end
    
    StatusText.Text = "Typing: " .. targetWord
    StatusText.TextColor3 = THEME.Accent
    Tween(StatusDot, {BackgroundColor3 = THEME.Accent})
    
    local lastChar = nil
    
    -- Calculate typing diff
    local toType = targetWord
    if not isCorrection and targetWord:sub(1, #currentDetected) == currentDetected then
        toType = targetWord:sub(#currentDetected + 1)
    end
    
    -- Typing Loop
    for i = 1, #toType do
        if not bypassTurn and not GetTurnInfo() then task.wait(0.05) if not GetTurnInfo() then break end end
        
        local char = toType:sub(i, i)
        SimulateKey(char)
        task.wait(CalculateDelayForKeys(lastChar, char))
        lastChar = char
    end
    
    -- === STRIKE CHECK ===
    task.wait(0.1)
    local initialStrikes = GetActiveStrikeCount()
    
    PressEnter()
    
    -- Verification Loop
    local verifyStart = tick()
    local accepted = false
    
    while (tick() - verifyStart) < 1.5 do
        local currentCheck = GetCurrentGameWord()
        if currentCheck == "" or (currentCheck ~= targetWord and currentCheck ~= currentDetected) then
            accepted = true
            break
        end
        task.wait(0.05)
    end
    
    if not accepted then
        local finalStrikes = GetActiveStrikeCount()
        
        -- === LOGIC PENENTUAN BLACKLIST/USED ===
        if finalStrikes > initialStrikes then
            -- Strike nambah = Kata Invalid (Tidak ada di kamus game)
            AddToBlacklist(targetWord)
            StatusText.Text = "Invalid Word (Blacklisted)"
            StatusText.TextColor3 = THEME.Error
        else
            -- Strike tetap = Kata sudah dipakai
            UsedWords[targetWord] = true
            StatusText.Text = "Word Used (Skipped)"
            StatusText.TextColor3 = THEME.Warning
        end
        
        -- Remove from Random Cache
        for k, list in pairs(RandomOrderCache) do
            for i = #list, 1, -1 do
                if list[i] == targetWord then table.remove(list, i) end
            end
        end
        
        -- Bersihkan input box
        local focused = UserInputService:GetFocusedTextBox()
        if focused then focused.Text = "" else Backspace(#targetWord + 5) end
        
        isTyping = false
        lastDetected = "---" -- Reset detection agar UpdateList tertrigger
        
        -- === INFINITE RETRY LOGIC ===
        -- Langsung trigger update list dan ketik kata berikutnya
        task.spawn(function()
            task.wait(0.1)
            local _, req = GetTurnInfo()
            UpdateList(currentDetected, req)
            if currentBestMatch then
                 SmartType(currentBestMatch, currentDetected, false)
            end
        end)
        return
    else
        StatusText.Text = "Word Accepted"
        StatusText.TextColor3 = THEME.Success
        UsedWords[targetWord] = true
        isMyTurnLogDetected = false
        task.wait(0.2)
    end
    
    isTyping = false
end

-- === MATCHING ALGORITHM ===

local function GetMatchLength(str, prefix)
    local len = 0
    for i = 1, math.min(#str, #prefix) do
        if prefix:sub(i,i) == "#" or prefix:sub(i,i) == str:sub(i,i) then len = i else break end
    end
    return len
end

UpdateList = function(detectedText, requiredLetter)
    local matches = {}
    local searchPrefix = detectedText
    local manualSearch = false

    if SearchBox and SearchBox.Text ~= "" then
        searchPrefix = SearchBox.Text:lower():gsub("[%s%c]+", "")
        manualSearch = true
        if requiredLetter and searchPrefix:sub(1,1) ~= requiredLetter:sub(1,1):lower() then requiredLetter = nil end
    end

    if not manualSearch and requiredLetter and #requiredLetter > 0 then
        if GetMatchLength(requiredLetter, searchPrefix) == #searchPrefix and #requiredLetter > #searchPrefix then
             searchPrefix = requiredLetter
        end
    end
    
    local firstChar = searchPrefix:sub(1,1)
    if firstChar == "#" then firstChar = nil end
    if (not firstChar or firstChar == "") and requiredLetter then firstChar = requiredLetter:sub(1,1):lower() end
    
    local bucket = (firstChar and firstChar ~= "" and Buckets[firstChar]) or Words
    
    -- Filter Matches
    for _, w in ipairs(bucket or {}) do
        if not Blacklist[w] and not UsedWords[w] then
            if suffixMode == "" or w:sub(-#suffixMode) == suffixMode then
                if lengthMode == 0 or #w == lengthMode then
                    if GetMatchLength(w, searchPrefix) == #searchPrefix then
                        table.insert(matches, w)
                        if #matches >= 200 then break end
                    end
                end
            end
        end
    end
    
    -- Sorting
    if #matches > 0 then
        if sortMode == "Longest" then table.sort(matches, function(a, b) return #a > #b end)
        elseif sortMode == "Shortest" then table.sort(matches, function(a, b) return #a < #b end)
        elseif sortMode == "Killer" then
             table.sort(matches, function(a, b)
                local sA, sB = GetKillerScore(a), GetKillerScore(b)
                return (sA == sB) and (#a < #b) or (sA > sB)
            end)
        elseif sortMode == "Random" then
            shuffleTable(matches)
        end
    end
    
    currentBestMatch = matches[1]
    
    -- Update UI Buttons
    local displayList = {}
    for i = 1, math.min(40, #matches) do table.insert(displayList, matches[i]) end
    
    for i = 1, math.max(#displayList, #ButtonCache) do
        local w = displayList[i]
        local btn = ButtonCache[i]
        if w then
            if not btn then
                btn = Instance.new("TextButton", ScrollList)
                btn.Size = UDim2.new(1, -6, 0, 30)
                btn.BackgroundColor3 = THEME.ItemBG
                btn.Text = ""
                btn.AutoButtonColor = false
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                local lbl = Instance.new("TextLabel", btn)
                lbl.Name = "Label"
                lbl.Size = UDim2.new(1, -20, 1, 0)
                lbl.Position = UDim2.new(0, 10, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.RichText = true
                btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Color3.fromRGB(45,45,55)}) end)
                btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = THEME.ItemBG}) end)
                btn.MouseButton1Click:Connect(function()
                    if ButtonData[btn] then SmartType(ButtonData[btn].word, ButtonData[btn].detected, true) end
                end)
                table.insert(ButtonCache, btn)
            end
            btn.Visible = true
            ButtonData[btn] = {word = w, detected = detectedText}
            
            local prefix = w:sub(1, #searchPrefix)
            local suffix = w:sub(#searchPrefix + 1)
            btn:FindFirstChild("Label").Text = "<font color=\"rgb(114,100,255)\">"..prefix.."</font>"..suffix
        elseif btn then
            btn.Visible = false
        end
    end
    ScrollList.CanvasSize = UDim2.new(0,0,0, UIListLayout.AbsoluteContentSize.Y)
end

MinBtn.MouseButton1Click:Connect(function()
    local isMin = MainFrame.Size.Y.Offset < 100
    if not isMin then
        Tween(MainFrame, {Size = UDim2.new(0, 300, 0, 45)})
        ScrollList.Visible = false
        SettingsFrame.Visible = false
        StatusFrame.Visible = false
        MinBtn.Text = "+"
    else
        Tween(MainFrame, {Size = UDim2.new(0, 300, 0, 500)})
        task.wait(0.2)
        ScrollList.Visible = true
        SettingsFrame.Visible = true
        StatusFrame.Visible = true
        MinBtn.Text = "-"
    end
end)

-- === MAIN LOOPS ===

local lastTypeVisible = false
local StatsFrame = Instance.new("Frame", ScreenGui)
StatsFrame.Size = UDim2.new(0, 120, 0, 60)
StatsFrame.Position = UDim2.new(0.5, -60, 0, 10)
StatsFrame.BackgroundColor3 = THEME.Background
StatsFrame.Visible = false
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 8)
local STimer = Instance.new("TextLabel", StatsFrame)
STimer.Size = UDim2.new(1,0,0,25)
STimer.Position = UDim2.new(0,0,0,5)
STimer.BackgroundTransparency = 1
STimer.TextColor3 = THEME.Text
STimer.Font = Enum.Font.GothamBold
STimer.TextSize = 20
STimer.Text = "--"
local SCount = Instance.new("TextLabel", StatsFrame)
SCount.Size = UDim2.new(1,0,0,20)
SCount.Position = UDim2.new(0,0,0,30)
SCount.BackgroundTransparency = 1
SCount.TextColor3 = THEME.SubText
SCount.Font = Enum.Font.Gotham
SCount.TextSize = 12
SCount.Text = "Words: 0"

runConn = RunService.RenderStepped:Connect(function()
    local now = tick()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
    
    local isVisible = false
    if frame and frame.Parent then
        if frame.Parent:IsA("ScreenGui") then isVisible = frame.Parent.Enabled
        elseif frame.Parent:IsA("GuiObject") then isVisible = frame.Parent.Visible end
    end
    
    local seconds = nil
    if isVisible then
        local circle = frame:FindFirstChild("Circle")
        local timerLbl = circle and circle:FindFirstChild("Timer") and circle.Timer:FindFirstChild("Seconds")
        if timerLbl then
            seconds = tonumber(timerLbl.Text:match("([%d%.]+)"))
            StatsFrame.Visible = true
            STimer.Text = timerLbl.Text
            STimer.TextColor3 = (seconds and seconds < 3) and THEME.Error or THEME.Text
            
            -- AUTO BLATANT LOGIC
            if blatantMode == "AUTO" then
                isBlatantActive = (seconds and seconds < 5)
            else
                isBlatantActive = false
            end
        end
    else
        StatsFrame.Visible = false
    end
    
    local isMyTurn, requiredLetter = GetTurnInfo(frame)
    
    if (now - lastWordCheck) > 0.05 then
        cachedDetected, cachedCensored = GetCurrentGameWord(frame)
        lastWordCheck = now
    end
    local detected, censored = cachedDetected, cachedCensored
    
    -- PASSIVE READING (Opponent Word Tracking)
    if detected ~= "" and not censored and not isMyTurn then
        if not UsedWords[detected] then
            UsedWords[detected] = true
        end
    end

    -- Clear Cache New Round
    local typeLbl = frame and frame:FindFirstChild("Type")
    local typeVisible = typeLbl and typeLbl.Visible
    if typeVisible and not lastTypeVisible then
        UsedWords = {} -- CLEAR CACHE HERE
        StatusText.Text = "New Round - Cache Cleared"
        StatusText.TextColor3 = THEME.Success
    end
    lastTypeVisible = typeVisible

    -- Auto Play Trigger
    if not isVisible then
        lastDetected = "---"
    elseif detected ~= lastDetected or requiredLetter ~= logRequiredLetters or forceUpdateList then
        currentBestMatch = nil
        lastDetected = detected
        logRequiredLetters = requiredLetter
        
        if detected == "" and not forceUpdateList then
            UpdateList("", requiredLetter)
            listUpdatePending = false
        else
            forceUpdateList = false
            listUpdatePending = true
            lastInputTime = now
        end
    end
    
    if listUpdatePending and (now - lastInputTime > LIST_DEBOUNCE) then
        listUpdatePending = false
        UpdateList(lastDetected, logRequiredLetters)
        local visCount = 0
        for _, b in ipairs(ButtonCache) do if b.Visible then visCount = visCount + 1 end end
        SCount.Text = "Words: " .. visCount .. "+"
    end
    
    if autoPlay and not isTyping and not isAutoPlayScheduled and currentBestMatch and detected == lastDetected then
        local isMyTurnCheck, _ = GetTurnInfo(frame)
        if isMyTurnCheck then
            isAutoPlayScheduled = true
            local targetWord = currentBestMatch
            local snapshotDetected = lastDetected
            task.spawn(function()
                local delay = (isBlatantActive or blatantMode == "ON") and 0.15 or (0.8 + math.random() * 0.5)
                task.wait(delay)
                local stillMyTurn, _ = GetTurnInfo()
                if autoPlay and not isTyping and GetCurrentGameWord() == snapshotDetected and stillMyTurn then
                     SmartType(targetWord, snapshotDetected, false)
                end
                isAutoPlayScheduled = false
            end)
        end
    end
    
    -- Auto Join
    if autoJoin and (now - lastAutoJoinCheck > AUTO_JOIN_RATE) then
        lastAutoJoinCheck = now
        task.spawn(function()
            local displayMatch = gui and gui:FindFirstChild("DisplayMatch")
            local matches = displayMatch and displayMatch:FindFirstChild("Frame") and displayMatch.Frame:FindFirstChild("Matches")
            if matches then
                for _, m in ipairs(matches:GetChildren()) do
                    if m:IsA("GuiObject") and m.Name ~= "UIListLayout" then
                        local join = m:FindFirstChild("Join")
                        local idx = tonumber(m.Name)
                        local allowed = true
                        if idx then
                            if idx <= 4 then allowed = Config.AutoJoinSettings._1v1
                            elseif idx <= 8 then allowed = Config.AutoJoinSettings._4p
                            else allowed = Config.AutoJoinSettings._8p end
                        end
                        if join and join.Visible and allowed then
                            local cd = join:FindFirstChildWhichIsA("ClickDetector")
                            if cd then fireclickdetector(cd) else
                                local pos = join.AbsolutePosition
                                VirtualInputManager:SendMouseButtonEvent(pos.X+10, pos.Y+10, 0, true, game, 1)
                                task.wait(0.1)
                                VirtualInputManager:SendMouseButtonEvent(pos.X+10, pos.Y+10, 0, false, game, 1)
                            end
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- Server Browser Logic (Simple implementation)
ServerBrowserBtn.MouseButton1Click:Connect(function()
    if not ServerFrame then
        local ServerFrame = Instance.new("Frame", ScreenGui)
        ServerFrame.Size = UDim2.new(0, 300, 0, 400)
        ServerFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
        ServerFrame.BackgroundColor3 = THEME.Background
        EnableDragging(ServerFrame)
        Instance.new("UICorner", ServerFrame).CornerRadius = UDim.new(0,8)
        local close = Instance.new("TextButton", ServerFrame)
        close.Text = "X"
        close.Size = UDim2.new(0,30,0,30)
        close.Position = UDim2.new(1,-30,0,0)
        close.BackgroundColor3 = THEME.Error
        close.MouseButton1Click:Connect(function() ServerFrame:Destroy() ServerFrame = nil end)
        
        local refresh = Instance.new("TextButton", ServerFrame)
        refresh.Text = "Refresh Servers"
        refresh.Size = UDim2.new(1,-40,0,30)
        refresh.Position = UDim2.new(0,10,0,40)
        refresh.BackgroundColor3 = THEME.Accent
        
        local list = Instance.new("ScrollingFrame", ServerFrame)
        list.Size = UDim2.new(1,-10,1,-80)
        list.Position = UDim2.new(0,5,0,75)
        list.BackgroundTransparency = 1
        local layout = Instance.new("UIListLayout", list)
        
        refresh.MouseButton1Click:Connect(function()
            for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=50"
            local success, res = pcall(function() return request({Url=url, Method="GET"}) end)
            if success and res.Body then
                local data = HttpService:JSONDecode(res.Body).data
                for _, srv in ipairs(data) do
                    if srv.playing and srv.maxPlayers and srv.id ~= game.JobId then
                        local f = Instance.new("Frame", list)
                        f.Size = UDim2.new(1,-10,0,40)
                        f.BackgroundColor3 = THEME.ItemBG
                        local t = Instance.new("TextLabel", f)
                        t.Text = srv.playing .. "/" .. srv.maxPlayers .. " Ping: " .. (srv.ping or "?")
                        t.Size = UDim2.new(0.7,0,1,0)
                        t.BackgroundTransparency = 1
                        t.TextColor3 = THEME.Text
                        local j = Instance.new("TextButton", f)
                        j.Text = "Join"
                        j.Size = UDim2.new(0.3,0,1,0)
                        j.Position = UDim2.new(0.7,0,0,0)
                        j.BackgroundColor3 = THEME.Success
                        j.MouseButton1Click:Connect(function()
                            if queue_on_teleport then
                                queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/yay.lua"))()')
                            end
                            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, srv.id, Players.LocalPlayer)
                        end)
                    end
                end
                list.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y)
            end
        end)
    end
end)

inputConn = UserInputService.InputBegan:Connect(function(input)
    if unloaded then return end
    if input.KeyCode == TOGGLE_KEY then ScreenGui.Enabled = not ScreenGui.Enabled end
end)
