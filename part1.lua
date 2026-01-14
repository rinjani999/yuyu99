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
local BlacklistFile = "blacklist.json"

local Config = {
    CPM = 550,
    Blatant = false, -- Bisa boolean atau string "Auto"
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
    MinTypeSpeed = 50,
    MaxTypeSpeed = 3000,
    KeyboardLayout = "QWERTY"
}

-- === SYSTEM BLACKLIST & CACHE ===
local Blacklist = {}
local UsedWords = {} -- Cache sementara untuk ronde ini

local function SaveBlacklist()
    if writefile then
        writefile(BlacklistFile, HttpService:JSONEncode(Blacklist))
    end
end

local function LoadBlacklist()
    if isfile and isfile(BlacklistFile) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(BlacklistFile))
        end)
        if success and decoded then
            Blacklist = decoded
        end
    end
end
LoadBlacklist()

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

local currentCPM = Config.CPM
local isBlatant = (Config.Blatant == true)
local useHumanization = Config.Humanize
local useFingerModel = Config.FingerModel
local sortMode = Config.SortMode
local suffixMode = Config.SuffixMode or ""
local lengthMode = Config.LengthMode or 0
local autoPlay = Config.AutoPlay
local autoJoin = Config.AutoJoin
local panicMode = Config.PanicMode
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
local lastBlatantState = false -- Untuk mendeteksi transisi Auto Blatant

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

local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil

if logConn then logConn:Disconnect() end
logConn = LogService.MessageOut:Connect(function(message, type)
    local wordPart, timePart = message:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
    if wordPart and timePart then
        isMyTurnLogDetected = true
        logRequiredLetters = wordPart
        turnExpiryTime = tick() + tonumber(timePart)
    end
end)

-- URL Dictionary
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
LoadingTitle.Text = "WordHelper V4"
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

-- === CRITICAL HELPER: GetRemainingTime ===
-- Fungsi ini sangat penting untuk fitur Panic Override
local function GetRemainingTime()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
    if frame then
        local circle = frame:FindFirstChild("Circle")
        local timerLbl = circle and circle:FindFirstChild("Timer") and circle.Timer:FindFirstChild("Seconds")
        if timerLbl then
             return tonumber(timerLbl.Text:match("([%d%.]+)"))
        end
    end
    return nil
end

local function GetStrikeCount()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    local frame = inGame and inGame:FindFirstChild("Frame")
   
    local livesContainer = frame and (frame:FindFirstChild("Lives") or frame:FindFirstChild("Strikes") or frame:FindFirstChild("LifeContainer"))
   
    if not livesContainer then return 0 end
   
    local strikeCount = 0
    for _, child in ipairs(livesContainer:GetChildren()) do
        if (child:IsA("ImageLabel") or child:IsA("GuiObject")) and child.Visible then
            if child.BackgroundColor3.R > 0.8 and child.BackgroundColor3.G < 0.2 then
                 strikeCount = strikeCount + 1
            elseif child:IsA("ImageLabel") and child.ImageColor3.R > 0.8 and child.ImageColor3.G < 0.2 then
                 strikeCount = strikeCount + 1
            end
        end
    end
    return strikeCount
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
