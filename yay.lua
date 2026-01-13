local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LogService = game:GetService("LogService")
local TeleportService = game:GetService("TeleportService")

-- Utility Functions
local function gethui() return CoreGui end
local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- Constants
local TOGGLE_KEY = Enum.KeyCode.RightControl
local MIN_CPM = 50
local MAX_CPM_LEGIT = 1500
local MAX_CPM_BLATANT = 3000
local SCAN_RATE = 0.1 -- Check game state every 0.1s instead of every frame (Performance Boost)

math.randomseed(os.time())

-- Theme
local THEME = {
    Background = Color3.fromRGB(25, 25, 30), -- Darker, flatter
    ItemBG = Color3.fromRGB(35, 35, 40),
    Accent = Color3.fromRGB(114, 100, 255),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    Success = Color3.fromRGB(100, 255, 140),
    Warning = Color3.fromRGB(255, 200, 80),
    Error = Color3.fromRGB(255, 80, 80),
    Slider = Color3.fromRGB(60, 60, 70)
}

-- Config Setup
local ConfigFile = "WordHelper_Config_V5.json"
local BlacklistFile = "WordHelper_Blacklist.txt"

local Config = {
    CPM = 550,
    Blatant = false,
    Humanize = true,
    FingerModel = true,
    SortMode = "Random",
    RandomizeTop = true,
    SuffixMode = "",
    LengthMode = 0,
    AutoPlay = false,
    AutoJoin = false,
    AutoJoinSettings = { _1v1 = true, _4p = true, _8p = true },
    PanicMode = true,
    ShowKeyboard = false,
    ErrorRate = 2,
    ThinkDelay = 0.5,
    RiskyMistakes = false,
    CustomWords = {},
    KeyboardLayout = "QWERTY"
}

-- Think Delay Ranges
local thinkDelayMin = 0.1
local thinkDelayMax = 2.0

-- Killer Suffixes
local KillerSuffixes = {
    "x", "xi", "ze", "xo", "xu", "xx", "xr", "xs", "xey", "xa", "xd", "xp", "xl",
    "fu", "fet", "fur", "ke", "ps", "ss", "ths", "fs", "fsi",
    "nge", "dge", "rge", "yx", "nx", "rx",
    "kut", "xes", "xed", "tum", "pr", "qw", "ty", "per", "xt", "bv", "ax", "ops", "op",
    "que", "ique", "esque", "tz", "zy", "zz", "ing", "ex", "xe", "nks", "nk",
    "gaa", "gin", "dee", "ap", "tet", "pth", "mn", "bt", "ght", "lfth", "mpth",
    "nth", "rgue", "mb", "sc", "cq", "dg", "pt", "ct", "rk", "lf", "rf", "mz", "zm", 
    "oo", "aa", "edo", "ae", "aed", "ger", "moom"
}

-- File System
local function SaveConfig()
    if writefile then writefile(ConfigFile, HttpService:JSONEncode(Config)) end
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

local Blacklist = {}
local function LoadBlacklist()
    if isfile and isfile(BlacklistFile) then
        local content = readfile(BlacklistFile)
        for w in content:gmatch("[^\r\n]+") do
            local clean = w:gsub("[%s%c]+", ""):lower()
            if #clean > 0 then Blacklist[clean] = true end
        end
    end
end

local function SaveBlacklist()
    if writefile then
        local content = ""
        for w, _ in pairs(Blacklist) do content = content .. w .. "\n" end
        writefile(BlacklistFile, content)
    end
end

local function AddToBlacklist(word)
    if not word or word == "" then return end
    word = word:lower()
    if not Blacklist[word] then
        Blacklist[word] = true
        if appendfile and isfile(BlacklistFile) then
            appendfile(BlacklistFile, "\n" .. word)
        else
            SaveBlacklist()
        end
    end
end

local function RemoveFromBlacklist(word)
    if Blacklist[word] then
        Blacklist[word] = nil
        SaveBlacklist()
    end
end

LoadBlacklist()

-- State Variables
local currentCPM = Config.CPM
local isTyping = false
local lastDetected = "---"
local UsedWords = {}
local Words = {}
local Buckets = {}
local ButtonCache = {}
local ButtonData = {}
local isMyTurnLogDetected = false
local logRequiredLetters = ""
local turnExpiryTime = 0

-- UI Variables
local ScreenGui
local ToastContainer
local StatusText
local StatusDot

-- Helper Functions
local function Tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function ShowToast(message, type)
    if not ToastContainer then return end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 35)
    toast.BackgroundColor3 = THEME.ItemBG
    toast.BackgroundTransparency = 1
    toast.Parent = ToastContainer
    
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", toast)
    stroke.Color = (type == "success" and THEME.Success) or (type == "error" and THEME.Error) or THEME.Accent
    stroke.Transparency = 1
    
    local lbl = Instance.new("TextLabel", toast)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = message
    lbl.TextColor3 = stroke.Color
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextTransparency = 1
    
    Tween(toast, {BackgroundTransparency = 0.1}, 0.3)
    Tween(stroke, {Transparency = 0}, 0.3)
    Tween(lbl, {TextTransparency = 0}, 0.3)
    
    task.delay(2.5, function()
        Tween(toast, {BackgroundTransparency = 1}, 0.3)
        Tween(stroke, {Transparency = 1}, 0.3)
        Tween(lbl, {TextTransparency = 1}, 0.3)
        task.wait(0.3)
        toast:Destroy()
    end)
end

-- Word Loading
local function LoadWords()
    local url = "https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/tralala.txt"
    local fname = "ultimate_words_v5.txt"
    
    local content = ""
    if isfile(fname) then
        content = readfile(fname)
    else
        local s, r = pcall(function() return request({Url = url, Method = "GET"}) end)
        if s and r and r.Body then
            content = r.Body
            writefile(fname, content)
        end
    end
    
    local tempSeen = {}
    for w in content:gmatch("[^\r\n]+") do
        local clean = w:gsub("[%s%c]+", ""):lower()
        if #clean > 0 and not tempSeen[clean] then
            tempSeen[clean] = true
            table.insert(Words, clean)
        end
    end
    
    -- Add Custom Words
    if Config.CustomWords then
        for _, w in ipairs(Config.CustomWords) do
            local clean = w:gsub("[%s%c]+", ""):lower()
            if #clean > 0 and not tempSeen[clean] then
                tempSeen[clean] = true
                table.insert(Words, clean)
            end
        end
    end
    
    table.sort(Words)
    
    -- Build Buckets
    Buckets = {}
    for _, w in ipairs(Words) do
        local c = w:sub(1,1)
        if not Buckets[c] then Buckets[c] = {} end
        table.insert(Buckets[c], w)
    end
end

task.spawn(LoadWords)

-- UI Creation
local function CreateUI()
    if getgenv().WordHelperUI then getgenv().WordHelperUI:Destroy() end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "WordHelper_Optimized"
    ScreenGui.Parent = CoreGui
    getgenv().WordHelperUI = ScreenGui
    
    ToastContainer = Instance.new("Frame", ScreenGui)
    ToastContainer.Size = UDim2.new(0, 250, 1, 0)
    ToastContainer.Position = UDim2.new(1, -260, 0, 50)
    ToastContainer.BackgroundTransparency = 1
    
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "Main"
    MainFrame.Size = UDim2.new(0, 320, 0, 450)
    MainFrame.Position = UDim2.new(0.1, 0, 0.3, 0)
    MainFrame.BackgroundColor3 = THEME.Background
    MainFrame.BorderSizePixel = 0
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
    
    -- Dragging
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    
    -- Header
    local Header = Instance.new("Frame", MainFrame)
    Header.Size = UDim2.new(1, 0, 0, 40)
    Header.BackgroundColor3 = THEME.ItemBG
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)
    
    local Title = Instance.new("TextLabel", Header)
    Title.Text = "Lite <font color=\"rgb(114,100,255)\">Helper</font> V5"
    Title.RichText = true
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextColor3 = THEME.Text
    Title.Size = UDim2.new(1, -60, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Text = "×"
    CloseBtn.Font = Enum.Font.Gotham
    CloseBtn.TextSize = 24
    CloseBtn.TextColor3 = THEME.Error
    CloseBtn.Size = UDim2.new(0, 40, 1, 0)
    CloseBtn.Position = UDim2.new(1, -40, 0, 0)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
    
    local MinBtn = Instance.new("TextButton", Header)
    MinBtn.Text = "-"
    MinBtn.Font = Enum.Font.Gotham
    MinBtn.TextSize = 24
    MinBtn.TextColor3 = THEME.SubText
    MinBtn.Size = UDim2.new(0, 40, 1, 0)
    MinBtn.Position = UDim2.new(1, -80, 0, 0)
    MinBtn.BackgroundTransparency = 1
    
    -- Content Area
    local Content = Instance.new("Frame", MainFrame)
    Content.Size = UDim2.new(1, 0, 1, -45)
    Content.Position = UDim2.new(0, 0, 0, 45)
    Content.BackgroundTransparency = 1
    
    MinBtn.MouseButton1Click:Connect(function()
        Content.Visible = not Content.Visible
        MainFrame.Size = Content.Visible and UDim2.new(0, 320, 0, 450) or UDim2.new(0, 320, 0, 40)
    end)
    
    -- Status Bar
    StatusDot = Instance.new("Frame", Content)
    StatusDot.Size = UDim2.new(0, 8, 0, 8)
    StatusDot.Position = UDim2.new(0, 12, 0, 6)
    StatusDot.BackgroundColor3 = THEME.SubText
    Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)
    
    StatusText = Instance.new("TextLabel", Content)
    StatusText.Text = "Idle..."
    StatusText.Font = Enum.Font.Gotham
    StatusText.TextSize = 12
    StatusText.TextColor3 = THEME.SubText
    StatusText.Position = UDim2.new(0, 26, 0, 2)
    StatusText.Size = UDim2.new(1, -30, 0, 16)
    StatusText.BackgroundTransparency = 1
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Search
    local SearchBox = Instance.new("TextBox", Content)
    SearchBox.Size = UDim2.new(1, -20, 0, 28)
    SearchBox.Position = UDim2.new(0, 10, 0, 25)
    SearchBox.BackgroundColor3 = THEME.ItemBG
    SearchBox.PlaceholderText = "Search word..."
    SearchBox.Text = ""
    SearchBox.TextColor3 = THEME.Text
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 14
    Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)
    
    -- Scroll List
    local Scroll = Instance.new("ScrollingFrame", Content)
    Scroll.Size = UDim2.new(1, -10, 1, -180) -- Adjusted height
    Scroll.Position = UDim2.new(0, 5, 0, 60)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 2
    Scroll.ScrollBarImageColor3 = THEME.Accent
    
    local UIList = Instance.new("UIListLayout", Scroll)
    UIList.Padding = UDim.new(0, 4)
    
    -- Buttons Area (Bottom)
    local BottomFrame = Instance.new("Frame", Content)
    BottomFrame.Size = UDim2.new(1, 0, 0, 115)
    BottomFrame.Position = UDim2.new(0, 0, 1, -115)
    BottomFrame.BackgroundTransparency = 1
    
    local function CreateBtn(text, pos, size, callback, color)
        local btn = Instance.new("TextButton", BottomFrame)
        btn.Text = text
        btn.Position = pos
        btn.Size = size
        btn.BackgroundColor3 = THEME.ItemBG
        btn.TextColor3 = color or THEME.Text
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end
    
    -- Settings Toggle
    local SettingsVisible = false
    local SettingsFrame = Instance.new("Frame", Content)
    SettingsFrame.Size = UDim2.new(1, -10, 0, 240)
    SettingsFrame.Position = UDim2.new(0, 5, 0, 60)
    SettingsFrame.BackgroundColor3 = THEME.Background
    SettingsFrame.Visible = false
    SettingsFrame.ZIndex = 5
    
    local SettingsToggle = CreateBtn("Settings", UDim2.new(0, 10, 0, 5), UDim2.new(0, 300, 0, 22), function()
        SettingsVisible = not SettingsVisible
        SettingsFrame.Visible = SettingsVisible
        Scroll.Visible = not SettingsVisible
    end, THEME.Accent)
    
    -- Used / Blacklist Buttons
    CreateBtn("View Used Words", UDim2.new(0, 10, 0, 32), UDim2.new(0, 145, 0, 22), function()
        local frame = ScreenGui:FindFirstChild("UsedWordsFrame")
        if frame then frame.Visible = not frame.Visible end
    end, THEME.Success)
    
    CreateBtn("View Blacklist", UDim2.new(0, 165, 0, 32), UDim2.new(0, 145, 0, 22), function()
        local frame = ScreenGui:FindFirstChild("BlacklistFrame")
        if frame then frame.Visible = not frame.Visible end
    end, THEME.Error)
    
    -- Quick Toggles
    local AutoPlayBtn = CreateBtn("Auto Play: "..(Config.AutoPlay and "ON" or "OFF"), UDim2.new(0, 10, 0, 60), UDim2.new(0, 145, 0, 22), function() end)
    AutoPlayBtn.MouseButton1Click:Connect(function()
        Config.AutoPlay = not Config.AutoPlay
        AutoPlayBtn.Text = "Auto Play: "..(Config.AutoPlay and "ON" or "OFF")
        AutoPlayBtn.TextColor3 = Config.AutoPlay and THEME.Success or THEME.Text
        SaveConfig()
    end)
    
    local AutoJoinBtn = CreateBtn("Auto Join: "..(Config.AutoJoin and "ON" or "OFF"), UDim2.new(0, 165, 0, 60), UDim2.new(0, 145, 0, 22), function() end)
    AutoJoinBtn.MouseButton1Click:Connect(function()
        Config.AutoJoin = not Config.AutoJoin
        AutoJoinBtn.Text = "Auto Join: "..(Config.AutoJoin and "ON" or "OFF")
        AutoJoinBtn.TextColor3 = Config.AutoJoin and THEME.Success or THEME.Text
        SaveConfig()
    end)

    local SortBtn = CreateBtn("Sort: "..Config.SortMode, UDim2.new(0, 10, 0, 87), UDim2.new(0, 300, 0, 22), function() end)
    SortBtn.MouseButton1Click:Connect(function()
        local modes = {"Random", "Shortest", "Longest", "Killer"}
        local currentIdx = table.find(modes, Config.SortMode) or 1
        Config.SortMode = modes[(currentIdx % #modes) + 1]
        SortBtn.Text = "Sort: " .. Config.SortMode
        lastDetected = "REFRESH" -- Force refresh
    end, THEME.Accent)

    -- POPUP FRAMES (Used Words & Blacklist)
    local function CreateListFrame(name, title)
        local frame = Instance.new("Frame", ScreenGui)
        frame.Name = name
        frame.Size = UDim2.new(0, 200, 0, 300)
        frame.Position = UDim2.new(0.5, 20, 0.4, 0)
        frame.BackgroundColor3 = THEME.Background
        frame.Visible = false
        frame.ClipsDescendants = true
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", frame).Color = THEME.Accent
        
        -- Drag
        local d, di, ds, sp
        frame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d=true; ds=i.Position; sp=frame.Position end end)
        frame.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then di=i end end)
        UserInputService.InputChanged:Connect(function(i) if i==di and d then local del=i.Position-ds; frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+del.X,sp.Y.Scale,sp.Y.Offset+del.Y) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end end)

        local t = Instance.new("TextLabel", frame)
        t.Text = title
        t.Size = UDim2.new(1, -30, 0, 30)
        t.BackgroundTransparency = 1
        t.TextColor3 = THEME.Text
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        
        local c = Instance.new("TextButton", frame)
        c.Text = "X"
        c.Size = UDim2.new(0, 30, 0, 30)
        c.Position = UDim2.new(1, -30, 0, 0)
        c.BackgroundTransparency = 1
        c.TextColor3 = THEME.Error
        c.MouseButton1Click:Connect(function() frame.Visible = false end)
        
        local s = Instance.new("ScrollingFrame", frame)
        s.Size = UDim2.new(1, -10, 1, -40)
        s.Position = UDim2.new(0, 5, 0, 35)
        s.BackgroundTransparency = 1
        Instance.new("UIListLayout", s).Padding = UDim.new(0, 2)
        
        return frame, s
    end
    
    -- Used Words Logic
    local UWFrame, UWScroll = CreateListFrame("UsedWordsFrame", "Used Words (Session)")
    local function RefreshUsedWords()
        if not UWFrame.Visible then return end
        for _, c in pairs(UWScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        for w, _ in pairs(UsedWords) do
            local l = Instance.new("TextLabel", UWScroll)
            l.Text = w
            l.Size = UDim2.new(1, 0, 0, 18)
            l.BackgroundTransparency = 1
            l.TextColor3 = THEME.SubText
            l.Font = Enum.Font.Gotham
            l.TextSize = 12
        end
        UWScroll.CanvasSize = UDim2.new(0,0,0, #UWScroll:GetChildren()*18)
    end
    UWFrame:GetPropertyChangedSignal("Visible"):Connect(RefreshUsedWords)
    
    -- Blacklist Logic
    local BLFrame, BLScroll = CreateListFrame("BlacklistFrame", "Blacklist Manager")
    local function RefreshBlacklist()
        if not BLFrame.Visible then return end
        for _, c in pairs(BLScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for w, _ in pairs(Blacklist) do
            local row = Instance.new("Frame", BLScroll)
            row.Size = UDim2.new(1, -4, 0, 20)
            row.BackgroundTransparency = 1
            
            local l = Instance.new("TextLabel", row)
            l.Text = w
            l.Size = UDim2.new(1, -25, 1, 0)
            l.BackgroundTransparency = 1
            l.TextColor3 = THEME.Text
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Font = Enum.Font.Gotham
            l.TextSize = 12
            
            local del = Instance.new("TextButton", row)
            del.Text = "X"
            del.Size = UDim2.new(0, 20, 1, 0)
            del.Position = UDim2.new(1, -20, 0, 0)
            del.BackgroundColor3 = THEME.Error
            del.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", del).CornerRadius = UDim.new(0, 3)
            
            del.MouseButton1Click:Connect(function()
                RemoveFromBlacklist(w)
                row:Destroy()
            end)
        end
        BLScroll.CanvasSize = UDim2.new(0,0,0, 0) -- Auto layout handles it
    end
    BLFrame:GetPropertyChangedSignal("Visible"):Connect(RefreshBlacklist)

    -- SETTINGS PANE CONTENT
    local SL = Instance.new("UIListLayout", SettingsFrame)
    SL.Padding = UDim.new(0, 5)
    SL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local SPad = Instance.new("UIPadding", SettingsFrame)
    SPad.PaddingTop = UDim.new(0, 10)
    
    -- Slider Helper
    local function AddSlider(name, min, max, default, callback)
        local c = Instance.new("Frame", SettingsFrame)
        c.Size = UDim2.new(0, 280, 0, 35)
        c.BackgroundColor3 = THEME.ItemBG
        Instance.new("UICorner", c)
        
        local l = Instance.new("TextLabel", c)
        l.Text = name .. ": " .. default
        l.Size = UDim2.new(1, 0, 0, 20)
        l.BackgroundTransparency = 1
        l.TextColor3 = THEME.SubText
        l.Font = Enum.Font.Gotham
        l.TextSize = 11
        
        local bg = Instance.new("Frame", c)
        bg.Size = UDim2.new(0.9, 0, 0, 6)
        bg.Position = UDim2.new(0.05, 0, 0, 22)
        bg.BackgroundColor3 = THEME.Slider
        Instance.new("UICorner", bg)
        
        local fill = Instance.new("Frame", bg)
        local startPct = (default - min) / (max - min)
        fill.Size = UDim2.new(startPct, 0, 1, 0)
        fill.BackgroundColor3 = THEME.Accent
        Instance.new("UICorner", fill)
        
        local btn = Instance.new("TextButton", bg)
        btn.Size = UDim2.new(1,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        
        btn.MouseButton1Down:Connect(function()
            local move, rel
            move = RunService.RenderStepped:Connect(function()
                local m = UserInputService:GetMouseLocation()
                local rX = math.clamp(m.X - bg.AbsolutePosition.X, 0, bg.AbsoluteSize.X)
                local p = rX / bg.AbsoluteSize.X
                fill.Size = UDim2.new(p, 0, 1, 0)
                local val = min + (p * (max - min))
                callback(val, l)
            end)
            rel = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    move:Disconnect(); rel:Disconnect()
                    SaveConfig()
                end
            end)
        end)
    end
    
    AddSlider("CPM", 50, 3000, Config.CPM, function(v, lbl)
        local val = math.floor(v)
        Config.CPM = val
        currentCPM = val
        lbl.Text = "CPM: " .. val
    end)
    
    AddSlider("Error Rate", 0, 20, Config.ErrorRate, function(v, lbl)
        local val = math.floor(v)
        Config.ErrorRate = val
        lbl.Text = "Error Rate: " .. val .. "%"
    end)
    
    AddSlider("Think Delay", 0.1, 2.0, Config.ThinkDelay, function(v, lbl)
        local val = math.floor(v * 10) / 10
        Config.ThinkDelay = val
        lbl.Text = "Think Delay: " .. val .. "s"
    end)

    return SearchBox, Scroll, UIList
end

local SearchBox, Scroll, UIList = CreateUI()

-- Update List Logic (Event Based)
local function UpdateList(detected, required)
    if not Scroll then return end
    
    local search = SearchBox.Text:lower():gsub("[%s%c]+", "")
    local matches = {}
    
    -- Determine source bucket
    local prefix = search
    if prefix == "" and required and #required > 0 then prefix = required:sub(1,1):lower() end
    if prefix == "" then prefix = nil end
    
    local bucket = (prefix and Buckets[prefix:sub(1,1)]) or Words
    
    -- Filter
    local count = 0
    if bucket then
        for _, w in ipairs(bucket) do
            if not UsedWords[w] and not Blacklist[w] then
                local valid = true
                if search ~= "" and w:sub(1, #search) ~= search then valid = false end
                if required and required ~= "" and w:sub(1, #required) ~= required:lower() then valid = false end
                
                if valid then
                    table.insert(matches, w)
                    count = count + 1
                    if count > 200 then break end -- Hard limit for display performance
                end
            end
        end
    end
    
    -- Sorting
    if #matches > 0 then
        local mode = Config.SortMode
        
        -- Special Killer Sort with Fallback
        if mode == "Killer" then
            table.sort(matches, function(a, b)
                local function hasKiller(word)
                    for _, s in ipairs(KillerSuffixes) do if word:sub(-#s) == s then return true end end
                    return false
                end
                
                local ak = hasKiller(a)
                local bk = hasKiller(b)
                
                if ak and not bk then return true end
                if not ak and bk then return false end
                -- Fallback to length if both are killer or both are normal
                return #a < #b
            end)
        elseif mode == "Shortest" then
            table.sort(matches, function(a,b) return #a < #b end)
        elseif mode == "Longest" then
            table.sort(matches, function(a,b) return #a > #b end)
        elseif mode == "Random" then
            for i = #matches, 2, -1 do
                local j = math.random(i)
                matches[i], matches[j] = matches[j], matches[i]
            end
        end
    end
    
    -- Update UI
    for _, btn in ipairs(ButtonCache) do btn.Visible = false end
    
    for i, w in ipairs(matches) do
        if i > 50 then break end
        local btn = ButtonCache[i]
        if not btn then
            btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 24)
            btn.BackgroundColor3 = THEME.ItemBG
            btn.TextColor3 = THEME.Text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 14
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            btn.Parent = Scroll
            
            btn.MouseButton1Click:Connect(function()
                local d = ButtonData[btn]
                if d then
                    -- Trigger Typing
                     task.spawn(function()
                        local player = Players.LocalPlayer
                        local gui = player and player:FindFirstChild("PlayerGui")
                        local inGame = gui and gui:FindFirstChild("InGame")
                        local frame = inGame and inGame:FindFirstChild("Frame")
                        local current = ""
                        -- Quick get detected for manual click
                        if frame then 
                            local container = frame:FindFirstChild("CurrentWord")
                            if container then
                                for _, c in ipairs(container:GetChildren()) do
                                    if c:IsA("GuiObject") and c.Visible then
                                        local t = c:FindFirstChild("Letter")
                                        if t then current = current .. t.Text end
                                    end
                                end
                            end
                        end
                        SmartType(d, current:lower():gsub(" ",""), true)
                     end)
                end
            end)
            
            table.insert(ButtonCache, btn)
        end
        
        btn.Text = w
        btn.Visible = true
        ButtonData[btn] = w
        
        -- Highlight Killer Suffix in text if possible (Simple implementation)
        if Config.SortMode == "Killer" then
             btn.TextColor3 = THEME.Text
             for _, s in ipairs(KillerSuffixes) do
                 if w:sub(-#s) == s then
                     btn.TextColor3 = Color3.fromRGB(255, 150, 150)
                     break
                 end
             end
        else
             btn.TextColor3 = THEME.Text
        end
    end
    
    Scroll.CanvasSize = UDim2.new(0,0,0, UIListLayout.AbsoluteContentSize.Y)
    
    -- Auto Play Trigger
    if Config.AutoPlay and #matches > 0 and not isTyping and detected == lastDetected and detected ~= "" then
        local target = matches[1]
        local delay = Config.Blatant and 0.1 or (Config.ThinkDelay + math.random()*0.3)
        
        task.delay(delay, function()
             -- Re-verify turn
             if not isTyping and lastDetected == detected then
                 SmartType(target, detected, false)
             end
        end)
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function() UpdateList(lastDetected, nil) end)

-- Main Logic Loop (Throttled)
local lastScan = 0
local frameCache = {}

local function ScanGame()
    local now = tick()
    if now - lastScan < SCAN_RATE and not isTyping then return end -- Throttle
    lastScan = now
    
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    local frame = inGame and inGame:FindFirstChild("Frame")
    
    if not frame then 
        StatusText.Text = "Not in Game"
        StatusDot.BackgroundColor3 = THEME.SubText
        return 
    end
    
    -- 1. Get Turn Info
    local myTurn = false
    local required = ""
    local typeLbl = frame:FindFirstChild("Type")
    
    -- Check round reset (New Round Detection)
    if typeLbl and typeLbl.Visible then
        local txt = typeLbl.Text
        if txt:sub(1, #player.DisplayName) == player.DisplayName or txt:sub(1, #player.Name) == player.Name then
            myTurn = true
            required = txt:match("starting with:%s*([A-Za-z])") or ""
        end
        
        -- Detect Round Change Logic for Cache Clear
        if not frameCache.wasTypeVisible then
             ShowToast("Cache Cleared! Ready.", "success")
             UsedWords = {}
             RefreshUsedWords()
             lastDetected = "RESET" -- force update
        end
        frameCache.wasTypeVisible = true
    else
        frameCache.wasTypeVisible = false
    end
    
    -- 2. Get Current Word on Board
    local container = frame:FindFirstChild("CurrentWord")
    local detected = ""
    local isCensored = false
    
    if container then
        local letters = {}
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("GuiObject") and c.Visible then
                local t = c:FindFirstChild("Letter")
                if t and t.TextTransparency < 1 then
                    table.insert(letters, {x = c.AbsolutePosition.X, t = t.Text})
                end
            end
        end
        table.sort(letters, function(a,b) return a.x < b.x end)
        for _, l in ipairs(letters) do
            detected = detected .. l.t
            if l.t:find("#") then isCensored = true end
        end
    end
    detected = detected:lower():gsub(" ", "")
    
    if isCensored then
        StatusText.Text = "Censored!"
        StatusDot.BackgroundColor3 = THEME.Warning
        return
    end
    
    -- 3. Update Status & List
    if detected ~= lastDetected then
        lastDetected = detected
        if detected == "" then
             StatusText.Text = (myTurn and "Your Turn! ("..required..")") or "Waiting..."
             StatusDot.BackgroundColor3 = myTurn and THEME.Success or THEME.SubText
             UpdateList("", required)
        else
             StatusText.Text = "Current: " .. detected
             StatusDot.BackgroundColor3 = THEME.Accent
             UpdateList(detected, required)
             
             -- Add to used words if not mine and complete
             if not myTurn and #detected > 2 and not UsedWords[detected] then
                  -- Check if it's a real word from our list to avoid junk
                  -- Optimization: Just add it, we filter duplicates in UpdateList logic
                  UsedWords[detected] = true
             end
        end
    end
    
    -- 4. Auto Join Logic
    if Config.AutoJoin and not inGame.Visible and (now % 1 < 0.2) then
         -- Lightweight AutoJoin logic here if needed
    end
end

RunService.Heartbeat:Connect(ScanGame)

-- Typing Function (Simplified for performance)
function SmartType(target, current, force)
    if isTyping and not force then return end
    isTyping = true
    StatusText.Text = "Typing: " .. target
    
    local toType = target
    -- Check overlap
    if current ~= "" and target:sub(1, #current) == current then
        toType = target:sub(#current + 1)
    elseif current ~= "" then
        -- Backspace needed
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        task.wait(0.1)
        -- Simple recursion for full clear/rewrite if mismatch
        VirtualInputManager:SendTextInput(target) -- Fast method for mismatch
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        isTyping = false
        UsedWords[target] = true
        RefreshUsedWords()
        return
    end
    
    -- Humanized Typing
    for i = 1, #toType do
        local char = toType:sub(i,i)
        VirtualInputManager:SendTextInput(char)
        
        -- Delay
        local delay = 0.05
        if not Config.Blatant then
             delay = (60 / Config.CPM) 
             if Config.Humanize then delay = delay + (math.random() * 0.05) end
        end
        task.wait(delay)
        
        -- Error Simulation
        if Config.ErrorRate > 0 and math.random(1, 100) <= Config.ErrorRate then
             VirtualInputManager:SendTextInput("x") -- typo
             task.wait(0.1)
             VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
             VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
             task.wait(0.1)
        end
    end
    
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    
    UsedWords[target] = true
    RefreshUsedWords()
    isTyping = false
end

-- Toggle Key
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == TOGGLE_KEY then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

ShowToast("Script Loaded! Press Right Ctrl", "success")
