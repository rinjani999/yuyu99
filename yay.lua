local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LogService = game:GetService("LogService")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")

-- Protection (Cloneref/Gethui)
local cloneref = cloneref or function(o) return o end
local gethui = gethui or function() return CoreGui end

-- Constants
local TOGGLE_KEY = Enum.KeyCode.RightControl
local MIN_CPM = 50
local MAX_CPM_LIMIT = 10000 -- Request #2
local THEME = {
    Background = Color3.fromRGB(20, 20, 24),
    ItemBG = Color3.fromRGB(32, 32, 38),
    Accent = Color3.fromRGB(114, 100, 255),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(150, 150, 160),
    Success = Color3.fromRGB(100, 255, 140),
    Warning = Color3.fromRGB(255, 200, 80),
    Error = Color3.fromRGB(255, 80, 80),
    Slider = Color3.fromRGB(60, 60, 70)
}

-- Files
local ConfigFile = "WordHelper_V5_Config.json"
local LocalBlacklistFile = "WordHelper_Blacklist.txt" -- Request #6

-- Config Defaults
local Config = {
    CPM = 600,
    Blatant = false,
    Humanize = true,
    Shuffle = false, -- Request #8
    SortMode = "Longest",
    AutoPlay = false,
    AutoJoin = false,
    PanicMode = true,
    SoundAlerts = true, -- Request #18
    ModDetector = true, -- Expert #11
    PingComp = true, -- Expert #12
    UserGuard = true, -- Expert #13
    AutoJoinSettings = { _1v1 = true, _4p = true, _8p = true },
    ErrorRate = 2,
    CustomWords = {},
    KeyboardLayout = "QWERTY"
}

-- Global State
local State = {
    IsTyping = false,
    LastTypingStart = 0,
    TurnExpiry = 0,
    RequiredLetters = "",
    IsMyTurn = false,
    UsedWords = {}, -- Cache per ronde
    RuntimeBlacklist = {}, -- Cache runtime
    LocalBlacklistSet = {}, -- Cache dari file
    OpponentUsedWords = {}, -- Cache kata lawan (Request #7)
    Words = {},
    Buckets = {},
    LastDetected = "---",
    IsBlatantActive = false, -- Untuk Auto Blatant < 5s
    Unloaded = false,
    ForceUpdate = false
}

-- Killer Suffixes (Request #3)
local KillerSuffixes = {
    "x", "xi", "ze", "xo", "xu", "xx", "xr", "xs", "xey", "xa", "xd", "xp", "xl",
    "fu", "fet", "fur", "ke", "ps", "ss", "ths", "fs", "fsi",
    "nge", "dge", "rge", "yx", "nx", "rx", "kut", "xes", "xed", "tum",
    "pr", "qw", "ty", "per", "xt", "bv", "ax", "ops", "op",
    "que", "ique", "esque", "tz", "zy", "zz", "ing", "ex", "xe",
    "nks", "nk", "gaa", "gin", "dee", "ap", "tet", "pth", "mn", "bt",
    "ght", "lfth", "mpth", "nth", "rgue", "mb", "sc", "cq", "dg", "pt",
    "ct", "x", "rk", "lf", "rf", "mz", "zm", "oo", "aa", "edo", "ae", "aed", "ger", "moom"
}

--------------------------------------------------------------------------------
-- FILE SYSTEM (LOCAL BLACKLIST)
--------------------------------------------------------------------------------

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

-- Request #6: Local Blacklist Handling
local function LoadLocalBlacklist()
    if isfile and isfile(LocalBlacklistFile) then
        local content = readfile(LocalBlacklistFile)
        for w in content:gmatch("[^\r\n]+") do
            local clean = w:gsub("[%s%c]+", ""):lower()
            if #clean > 0 then
                State.LocalBlacklistSet[clean] = true
            end
        end
    end
end

local function AppendToLocalBlacklist(word)
    if not word or #word == 0 then return end
    word = word:lower()
    if State.LocalBlacklistSet[word] then return end
    
    State.LocalBlacklistSet[word] = true
    if appendfile and isfile(LocalBlacklistFile) then
        appendfile(LocalBlacklistFile, "\n" .. word)
    elseif writefile then
        -- Fallback create new
        local content = ""
        if isfile(LocalBlacklistFile) then content = readfile(LocalBlacklistFile) .. "\n" end
        writefile(LocalBlacklistFile, content .. word)
    end
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

local function Tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function ShowToast(msg, type)
    -- Placeholder for UI Toast (Implemented in UI section)
end

local function PlaySound(id)
    if not Config.SoundAlerts then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Parent = SoundService
    s.Volume = 1
    s.PlayOnRemove = true
    s:Destroy()
end

local function GetPing()
    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
end

--------------------------------------------------------------------------------
-- WORD LOGIC & SCORING
--------------------------------------------------------------------------------

-- Request #10: New URL
local DICT_URL = "https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/tralala.txt"

local function FetchWords()
    local content = ""
    local success, res = pcall(function() return game:HttpGet(DICT_URL) end)
    
    if success then
        content = res
    elseif isfile("WordHelper_Cache.txt") then
        content = readfile("WordHelper_Cache.txt")
    end

    if success and writefile then
        writefile("WordHelper_Cache.txt", content)
    end

    State.Words = {}
    State.Buckets = {}
    
    for w in content:gmatch("[^\r\n]+") do
        local clean = w:gsub("[%s%c]+", ""):lower()
        if #clean > 0 then
            table.insert(State.Words, clean)
            local c = clean:sub(1,1)
            State.Buckets[c] = State.Buckets[c] or {}
            table.insert(State.Buckets[c], clean)
        end
    end
end

-- Request #3: New Killer Logic
local function GetKillerScore(word)
    local score = 0
    for _, suffix in ipairs(KillerSuffixes) do
        if word:sub(-#suffix) == suffix then
            score = score + 100 + #suffix -- Prioritize match + length of suffix
        end
    end
    -- Expert #14: Simple heuristics if score is 0
    if score == 0 then
        local hardChars = {x=5, z=4, q=4, j=3, k=2}
        score = hardChars[word:sub(-1)] or 0
    end
    return score
end

local function ShuffleTable(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

--------------------------------------------------------------------------------
-- GAME INTERACTION
--------------------------------------------------------------------------------

local function GetGameTextBox()
    local focused = UserInputService:GetFocusedTextBox()
    if focused and focused:IsDescendantOf(game) then return focused end
    
    -- Fallback search
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    if inGame then
        for _, v in ipairs(inGame:GetDescendants()) do
            if v:IsA("TextBox") and v.Visible then return v end
        end
    end
    return nil
end

local function GetCurrentGameWord()
    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local inGame = gui and gui:FindFirstChild("InGame")
    local frame = inGame and inGame:FindFirstChild("Frame")
    local container = frame and frame:FindFirstChild("CurrentWord")
    
    if not container then return "", false end
    
    local detected = ""
    local censored = false
    local letters = {}
    
    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("GuiObject") and c.Visible and c:FindFirstChild("Letter") then
            table.insert(letters, {
                Obj = c,
                X = c.AbsolutePosition.X,
                Txt = c.Letter.Text
            })
        end
    end
    
    table.sort(letters, function(a,b) return a.X < b.X end)
    
    for _, l in ipairs(letters) do
        local t = l.Txt
        if t:find("#") or t:find("%*") then censored = true end
        detected = detected .. t
    end
    
    return detected:lower():gsub(" ", ""), censored
end

--------------------------------------------------------------------------------
-- TYPING ENGINE (THE FIX)
--------------------------------------------------------------------------------

local function SimulateKey(key)
    if typeof(key) == "string" then key = Enum.KeyCode[key:upper()] end
    if not key then return end
    
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(State.IsBlatantActive and 0.001 or 0.005)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function CalculateDelay(prev, next)
    -- Request #9: Auto Blatant Override
    if State.IsBlatantActive then return 0.001 end
    
    local cpm = Config.CPM
    if cpm >= 9000 then return 0 end -- Instant
    
    local base = 60 / cpm
    -- Expert #15: Dynamic Humanization
    if Config.Humanize and prev and next then
        local noise = (math.random() * 0.2 - 0.1) * base
        return math.max(0, base + noise)
    end
    return base
end

-- Request #5: Retry Logic Loop
local function AutoTypeController(matches, detectedPrefix)
    if State.IsTyping then return end
    State.IsTyping = true
    State.LastTypingStart = tick()
    
    local box = GetGameTextBox()
    if box then box:CaptureFocus() end
    
    local successWord = nil
    
    -- Loop through matches until one works
    for _, word in ipairs(matches) do
        if State.Unloaded then break end
        
        -- Expert #17: Smart Skip (Local Blacklist / Used / Opponent)
        if State.RuntimeBlacklist[word] or State.LocalBlacklistSet[word] or State.UsedWords[word] or State.OpponentUsedWords[word] then
            continue -- Skip immediately
        end
        
        -- Expert #13: User Interference Guard
        if Config.UserGuard and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then 
            break -- Manual override
        end
        
        -- Calculate needed input
        local prefixLen = 0
        for i = 1, math.min(#detectedPrefix, #word) do
            if detectedPrefix:sub(i,i) == word:sub(i,i) then prefixLen = i else break end
        end
        
        local neededText = word:sub(prefixLen + 1)
        if #neededText == 0 then continue end
        
        -- Type it
        for i = 1, #neededText do
            local char = neededText:sub(i,i)
            SimulateKey(char)
            task.wait(CalculateDelay(nil, char))
        end
        
        -- Expert #12: Ping Compensation
        local pingWait = Config.PingComp and (GetPing() / 1000) or 0
        task.wait(0.1 + pingWait) 
        
        -- Verify before Enter (Request #5 fix - don't stop, just retry)
        local check = GetGameTextBox()
        if check and check.Text ~= word then
            -- Mismatch? Clear and try next word
            SimulateKey(Enum.KeyCode.Backspace) -- Hold BS logic usually better
            check.Text = "" -- Direct set fallback
            continue 
        end
        
        SimulateKey(Enum.KeyCode.Return)
        
        -- Verification Phase
        local startV = tick()
        local verified = false
        local rejected = false
        
        while (tick() - startV) < (1.5 + pingWait) do
            local current = GetCurrentGameWord()
            
            -- Request #7: Visual "Already Used" Detection
            -- (Simple approximation logic)
            if current == "" or (current ~= word and current ~= detectedPrefix) then
                verified = true
                break
            end
            
            -- If word persists too long, it's rejected
            task.wait(0.05)
        end
        
        if verified then
            successWord = word
            State.UsedWords[word] = true
            PlaySound(4612375233) -- Success sound
            break -- Success! Exit loop
        else
            -- Rejected Logic
            State.RuntimeBlacklist[word] = true
            AppendToLocalBlacklist(word) -- Request #6
            
            -- Clear input for next attempt
            local box = GetGameTextBox()
            if box then box.Text = "" end
            
            -- LOOP CONTINUES TO NEXT WORD IMMEDIATELY
        end
    end
    
    State.IsTyping = false
    State.ForceUpdate = true -- Refresh UI
end

--------------------------------------------------------------------------------
-- UI & MAIN LOGIC
--------------------------------------------------------------------------------

-- Initialize
LoadConfig()
LoadLocalBlacklist()
-- Request #1: No startup code, auto fetch
task.spawn(FetchWords)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WordHelperV5"
ScreenGui.Parent = gethui()
ScreenGui.ResetOnSpawn = false

-- Main Frame
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 320, 0, 450)
MainFrame.Position = UDim2.new(0.1, 0, 0.3, 0)
MainFrame.BackgroundColor3 = THEME.Background
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame, {Color = THEME.Accent, Thickness = 2})

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
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- Title
local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "WordHelper <font color='#7264FF'>V5 Ultimate</font>"
Title.RichText = true
Title.Size = UDim2.new(1, -40, 0, 40)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = THEME.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Status
local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.Text = "Idle..."
StatusLbl.Size = UDim2.new(1, -30, 0, 20)
StatusLbl.Position = UDim2.new(0, 15, 0, 40)
StatusLbl.BackgroundTransparency = 1
StatusLbl.TextColor3 = THEME.SubText
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 12
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- List
local Scroll = Instance.new("ScrollingFrame", MainFrame)
Scroll.Size = UDim2.new(1, -20, 1, -200) -- Adjust for settings
Scroll.Position = UDim2.new(0, 10, 0, 70)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 4
local UIList = Instance.new("UIListLayout", Scroll)
UIList.Padding = UDim.new(0, 4)

-- Settings Container
local SettingsFrame = Instance.new("ScrollingFrame", MainFrame)
SettingsFrame.Size = UDim2.new(1, -20, 0, 120)
SettingsFrame.Position = UDim2.new(0, 10, 1, -125)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.ScrollBarThickness = 2
Instance.new("UICorner", SettingsFrame)
local SetsLayout = Instance.new("UIListLayout", SettingsFrame)
SetsLayout.Padding = UDim.new(0, 5)
SettingsFrame.CanvasSize = UDim2.new(0, 0, 0, 350) 
SettingsFrame.PaddingTop = UDim.new(0, 5)
SettingsFrame.PaddingLeft = UDim.new(0, 5)

-- UI Helpers
local function CreateBtn(text, parent, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -15, 0, 25)
    btn.BackgroundColor3 = THEME.Background
    btn.Text = text
    btn.TextColor3 = THEME.Text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function UpdateButtons()
    -- Logic to refresh toggle texts
end

-- Toggles
local ModeBtn = CreateBtn("Sort: " .. Config.SortMode, SettingsFrame, function()
    local modes = {"Shortest", "Longest", "Killer", "Random"}
    local current = table.find(modes, Config.SortMode) or 1
    Config.SortMode = modes[(current % #modes) + 1]
    SaveConfig()
    State.ForceUpdate = true
end)

local ShuffleBtn = CreateBtn("Shuffle Top Results: " .. (Config.Shuffle and "ON" or "OFF"), SettingsFrame, function()
    Config.Shuffle = not Config.Shuffle
    SaveConfig()
    State.ForceUpdate = true
end)

local AutoPlayBtn = CreateBtn("Auto Play: " .. (Config.AutoPlay and "ON" or "OFF"), SettingsFrame, function()
    Config.AutoPlay = not Config.AutoPlay
    SaveConfig()
end)

local ModBtn = CreateBtn("Mod Detector: " .. (Config.ModDetector and "ON" or "OFF"), SettingsFrame, function()
    Config.ModDetector = not Config.ModDetector
    SaveConfig()
end)

-- Request #2: Slider for Max CPM
local CPMLabel = Instance.new("TextLabel", SettingsFrame)
CPMLabel.Size = UDim2.new(1, -10, 0, 20)
CPMLabel.BackgroundTransparency = 1
CPMLabel.Text = "CPM: " .. Config.CPM
CPMLabel.TextColor3 = THEME.Text
local CPMSlider = Instance.new("Frame", SettingsFrame)
CPMSlider.Size = UDim2.new(1, -20, 0, 6)
CPMSlider.BackgroundColor3 = THEME.Slider
Instance.new("UICorner", CPMSlider)
local CPMFill = Instance.new("Frame", CPMSlider)
CPMFill.Size = UDim2.new(Config.CPM / MAX_CPM_LIMIT, 0, 1, 0)
CPMFill.BackgroundColor3 = THEME.Accent
Instance.new("UICorner", CPMFill)
local CPMBtn = Instance.new("TextButton", CPMSlider)
CPMBtn.Size = UDim2.new(1,0,1,0)
CPMBtn.BackgroundTransparency = 1
CPMBtn.Text = ""

CPMBtn.MouseButton1Down:Connect(function()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then conn:Disconnect(); SaveConfig() return end
        local mPos = UserInputService:GetMouseLocation().X
        local rel = math.clamp((mPos - CPMSlider.AbsolutePosition.X) / CPMSlider.AbsoluteSize.X, 0, 1)
        Config.CPM = math.floor(rel * (MAX_CPM_LIMIT - MIN_CPM) + MIN_CPM)
        CPMFill.Size = UDim2.new(rel, 0, 1, 0)
        CPMLabel.Text = "CPM: " .. Config.CPM
    end)
end)

-- Button Cache
local BtnCache = {}

local function UpdateList(detected, required)
    local results = {}
    local bucket = State.Buckets[(required or ""):sub(1,1):lower()] or State.Words
    
    local function Match(w)
        if #detected > #w then return false end
        if w:sub(1, #detected) ~= detected then return false end
        -- Filter bad words
        if State.RuntimeBlacklist[w] or State.LocalBlacklistSet[w] or State.UsedWords[w] or State.OpponentUsedWords[w] then return false end
        return true
    end

    for _, w in ipairs(bucket) do
        if Match(w) then table.insert(results, w) end
        if #results > 200 then break end
    end
    
    -- Sorting
    if Config.SortMode == "Shortest" then
        table.sort(results, function(a,b) return #a < #b end)
    elseif Config.SortMode == "Longest" then
        table.sort(results, function(a,b) return #a > #b end)
    elseif Config.SortMode == "Killer" then
        table.sort(results, function(a,b) return GetKillerScore(a) > GetKillerScore(b) end)
    elseif Config.SortMode == "Random" then
        ShuffleTable(results)
    end
    
    -- Request #8: Shuffle top results even in other modes
    if Config.Shuffle and Config.SortMode ~= "Random" and #results > 10 then
        local top = {}
        for i = 1, 10 do table.insert(top, results[i]) end
        ShuffleTable(top)
        for i = 1, 10 do results[i] = top[i] end
    end
    
    -- Render
    for i, btn in ipairs(BtnCache) do btn.Visible = false end
    
    for i = 1, math.min(#results, 40) do
        local w = results[i]
        local btn = BtnCache[i]
        if not btn then
            btn = Instance.new("TextButton", Scroll)
            btn.Size = UDim2.new(1, 0, 0, 25)
            btn.BackgroundColor3 = THEME.ItemBG
            btn.TextColor3 = THEME.Text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 14
            Instance.new("UICorner", btn)
            btn.MouseButton1Click:Connect(function()
                AutoTypeController({btn.Text}, State.LastDetected)
            end)
            table.insert(BtnCache, btn)
        end
        btn.Text = w
        btn.Visible = true
        
        -- Color code top 3
        if i <= 3 then btn.TextColor3 = THEME.Accent else btn.TextColor3 = THEME.Text end
    end
    
    Scroll.CanvasSize = UDim2.new(0,0,0, UIList.AbsoluteContentSize.Y)
    return results
end

-- Update Loop buttons text
RunService.RenderStepped:Connect(function()
    ModeBtn.Text = "Sort: " .. Config.SortMode
    ShuffleBtn.Text = "Shuffle Top: " .. (Config.Shuffle and "ON" or "OFF")
    AutoPlayBtn.Text = "Auto Play: " .. (Config.AutoPlay and "ON" or "OFF")
    ModBtn.Text = "Mod Detector: " .. (Config.ModDetector and "ON" or "OFF")
    CPMFill.Size = UDim2.new((Config.CPM - MIN_CPM)/(MAX_CPM_LIMIT - MIN_CPM), 0, 1, 0)
    CPMLabel.Text = "CPM: " .. Config.CPM
end)

--------------------------------------------------------------------------------
-- MAIN LOOPS & EVENTS
--------------------------------------------------------------------------------

-- Expert #16: Anti-AFK
local Vu = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    Vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    Vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- Request #7: Chat Monitor for Opponent Words
game:GetService("TextChatService").MessageReceived:Connect(function(msg)
    local text = msg.Text:lower():gsub("[%s%c]+", "")
    -- Simple check if text is a valid word in our dict
    -- (This assumes opponents type real words)
    State.OpponentUsedWords[text] = true
end)
-- Legacy Chat Support
Players.PlayerChatted:Connect(function(type, player, message)
    if player ~= Players.LocalPlayer then
        State.OpponentUsedWords[message:lower():gsub("[%s%c]+", "")] = true
    end
end)

-- Main Watchdog
local lastTypeVisible = false
local autoPlayDebounce = false

RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end
    
    -- Expert #11: Mod Detector
    if Config.ModDetector then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer then
                -- Generic check (Rank > 0 is simplistic, better use IsFriendsWith or generic Group check if known)
                -- For safety, we just check name patterns or if they are literal Roblox Admins
                if p:IsInGroup(1200769) then -- Example: Roblox Admin Group
                   StatusLbl.Text = "ADMIN DETECTED! PAUSING."
                   StatusLbl.TextColor3 = THEME.Error
                   return
                end
            end
        end
    end

    local player = Players.LocalPlayer
    local gui = player and player:FindFirstChild("PlayerGui")
    local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
    
    -- State Detection
    local currentWord, censored = GetCurrentGameWord()
    local typeLabel = frame and frame:FindFirstChild("Type")
    local typeVisible = typeLabel and typeLabel.Visible
    
    -- Request #4: Reset Cache Logic
    if typeVisible and not lastTypeVisible then
        State.UsedWords = {}
        State.OpponentUsedWords = {}
        StatusLbl.Text = "New Round - Cache Cleared"
        PlaySound(4612377146)
    elseif not typeVisible and lastTypeVisible then
        -- Round ended
        task.delay(1, function()
            State.UsedWords = {}
            State.OpponentUsedWords = {}
            StatusLbl.Text = "Round End - Cache Cleared"
        end)
    end
    lastTypeVisible = typeVisible
    
    -- Timer & Panic Logic
    local seconds = 10
    local timerLbl = frame and frame:FindFirstChild("Circle") and frame.Circle:FindFirstChild("Timer") and frame.Circle.Timer:FindFirstChild("Seconds")
    if timerLbl then
        seconds = tonumber(timerLbl.Text:match("([%d%.]+)")) or 10
    end
    
    -- Request #9: Auto Blatant < 5s
    if seconds < 5 and Config.PanicMode then
        State.IsBlatantActive = true
        StatusLbl.TextColor3 = THEME.Error
    else
        State.IsBlatantActive = Config.Blatant
        StatusLbl.TextColor3 = THEME.SubText
    end

    -- Turn Detection
    local isMyTurn = false
    local required = ""
    if typeLabel then
        local text = typeLabel.Text
        if text:find(player.DisplayName) or text:find(player.Name) then
            isMyTurn = true
            required = text:match("starting with:%s*([A-Za-z])") or ""
        end
    end
    
    -- Update UI List
    if currentWord ~= State.LastDetected or required ~= State.RequiredLetters or State.ForceUpdate then
        State.LastDetected = currentWord
        State.RequiredLetters = required
        State.ForceUpdate = false
        local matches = UpdateList(currentWord, required)
        
        -- Auto Play Trigger
        if Config.AutoPlay and isMyTurn and not State.IsTyping and #matches > 0 and not autoPlayDebounce then
            if currentWord == "" or #currentWord > 0 then -- Safe trigger
                autoPlayDebounce = true
                
                local delayTime = State.IsBlatantActive and 0.1 or (math.random(8, 15)/10)
                if seconds < 5 then delayTime = 0 end
                
                task.delay(delayTime, function()
                    if GetCurrentGameWord() == currentWord then -- Double check
                        AutoTypeController(matches, currentWord)
                    end
                    autoPlayDebounce = false
                end)
            end
        end
    end
    
    if isMyTurn then
        StatusLbl.Text = "YOUR TURN! (" .. math.floor(seconds) .. "s)" .. (State.IsBlatantActive and " [PANIC]" or "")
        StatusLbl.TextColor3 = State.IsBlatantActive and THEME.Error or THEME.Success
    else
        StatusLbl.Text = "Waiting..."
        StatusLbl.TextColor3 = THEME.SubText
    end
end)

-- Input
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == TOGGLE_KEY then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

PlaySound(4590657391) -- Load Sound
