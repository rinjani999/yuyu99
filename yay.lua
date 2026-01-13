-- MODIFIKASI LENGKAP: Last Letter AJG v5 (Mobile-Optimized + Light UI)
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
local MAX_CPM_LEGIT = 10000
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
	Slider = Color3.fromRGB(60, 60, 70)
}

local function ColorToRGB(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local ConfigFile = "WordHelper_Config.json"
local Config = {
	CPM = 550,
	Blatant = false,
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
	MaxTypeSpeed = 10000,
	KeyboardLayout = "QWERTY",
	RandomSort = false
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

local currentCPM = Config.CPM
local isBlatant = Config.Blatant
local useHumanization = Config.Humanize
local useFingerModel = Config.FingerModel
local sortMode = Config.SortMode or "Random"
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
local randomSortEnabled = Config.RandomSort or false

-- === DELAY RANGE UPDATE ===
local thinkDelayMin = 0.1
local thinkDelayMax = 2.0

-- === STATE VARS ===
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
local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil

-- === BLACKLIST FILE ===
local BlacklistFile = "blacklist.txt"

local function LoadBlacklist()
	if isfile and isfile(BlacklistFile) then
		local content = readfile(BlacklistFile)
		for word in content:gmatch("[^\r\n]+") do
			local clean = word:lower():gsub("[%s%c]+", "")
			if #clean > 0 then
				Blacklist[clean] = true
			end
		end
	end
end

local function AddToBlacklist(word)
	word = word:lower():gsub("[%s%c]+", "")
	if not Blacklist[word] then
		Blacklist[word] = true
		local lines = {}
		if isfile and isfile(BlacklistFile) then
			local all = readfile(BlacklistFile)
			for w in all:gmatch("[^\r\n]+") do
				table.insert(lines, w)
			end
		end
		table.insert(lines, word)
		if writefile then
			writefile(BlacklistFile, table.concat(lines, "\n"))
		end
	end
end

LoadBlacklist()

-- === LOG DETECTION ===
if logConn then logConn:Disconnect() end
logConn = LogService.MessageOut:Connect(function(message, type)
	local wordPart, timePart = message:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
	if wordPart and timePart then
		isMyTurnLogDetected = true
		logRequiredLetters = wordPart
		turnExpiryTime = tick() + tonumber(timePart)
	end
end)

-- === FETCH WORDS ===
local url = "https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/tralala.txt"
local fileName = "ultimate_words_v4.txt"

-- Loading UI
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "WordHelperLoading"
local success, parent = pcall(function() return gethui() end)
if not success or not parent then parent = game:GetService("CoreGui") end
LoadingGui.Parent = parent
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local LoadingFrame = Instance.new("Frame", LoadingGui)
LoadingFrame.Size = UDim2.new(0, 260, 0, 80)
LoadingFrame.Position = UDim2.new(0.5, -130, 0.4, 0)
LoadingFrame.BackgroundColor3 = THEME.Background
LoadingFrame.BorderSizePixel = 0
Instance.new("UICorner", LoadingFrame).CornerRadius = UDim.new(0, 8)
local LStroke = Instance.new("UIStroke", LoadingFrame)
LStroke.Color = THEME.Accent
LStroke.Transparency = 0.5
LStroke.Thickness = 2

local LoadingTitle = Instance.new("TextLabel", LoadingFrame)
LoadingTitle.Size = UDim2.new(1, 0, 0, 30)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Text = "Last Letter AJG V5"
LoadingTitle.TextColor3 = THEME.Accent
LoadingTitle.Font = Enum.Font.GothamBold
LoadingTitle.TextSize = 16

local LoadingStatus = Instance.new("TextLabel", LoadingFrame)
LoadingStatus.Size = UDim2.new(1, -20, 0, 24)
LoadingStatus.Position = UDim2.new(0, 10, 0, 40)
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Text = "Initializing..."
LoadingStatus.TextColor3 = THEME.Text
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.TextSize = 12

local function UpdateStatus(text, color)
	LoadingStatus.Text = text
	if color then LoadingStatus.TextColor3 = color end
	game:GetService("RunService").RenderStepped:Wait()
end

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
SeenWords = nil

-- === UTILS ===
local function shuffleTable(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- Hard Endings
local HardEndings = {
	"x", "xi", "ze", "xo", "xu", "xx", "xr", "xs", "xey", "xa", "xd", "xp", "xl",
	"fu", "fet", "fur", "ke", "ps", "ss", "ths", "fs", "fsi","nge", "dge", "rge",
	"yx", "nx", "rx","kut", "xes", "xed", "tum", "pr", "qw", "ty", "per", "xt",
	"bv", "ax", "ops", "op","que", "ique", "esque","tz","zy", "zz", "ing", "ex",
	"xe", "nks","nk","gaa", "gin", "dee", "ap", "tet", "pth", "mn", "bt", "ght",
	"lfth", "mpth","nth", "rgue", "mb", "sc", "cq", "dg", "pt", "ct", "x", "rk",
	"lf", "rf", "mz", "zm", "oo", "aa", "edo", "ae", "aed", "ger","moom"
}

local function GetKillerScore(word)
	for _, ending in ipairs(HardEndings) do
		if word:sub(-#ending) == ending then
			return #ending * 10 + math.random(1, 5)
		end
	end
	return 0
end

local function Tween(obj, props, time)
	TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- === GAME STATE DETECTION ===
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

local function DetectOpponentUsedWord(frame)
	if not frame then
		local player = Players.LocalPlayer
		local gui = player and player:FindFirstChild("PlayerGui")
		local inGame = gui and gui:FindFirstChild("InGame")
		frame = inGame and inGame:FindFirstChild("Frame")
	end
	if frame then
		for _, obj in ipairs(frame:GetDescendants()) do
			if obj:IsA("TextLabel") and obj.Text:find("Already used!") then
				local current = GetCurrentGameWord(frame)
				if current ~= "" and not current:find("#") then
					return current
				end
			end
		end
	end
	return nil
end

-- === TOAST SYSTEM (Non-intrusive) ===
local ParentTarget = (gethui and gethui()) or CoreGui or Players.LocalPlayer.PlayerGui
local ToastContainer = Instance.new("Frame", ParentTarget)
ToastContainer.Name = "LLAJG_ToastContainer"
ToastContainer.Size = UDim2.new(0, 250, 0, 0)
ToastContainer.Position = UDim2.new(1, -260, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 100
ToastContainer.ResetOnSpawn = false

local function ShowToast(message, type)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 32)
	toast.BackgroundColor3 = THEME.ItemBG
	toast.BorderSizePixel = 0
	toast.BackgroundTransparency = 1
	toast.Parent = ToastContainer
	local stroke = Instance.new("UIStroke", toast)
	stroke.Thickness = 1.2
	stroke.Transparency = 1
	local color = THEME.Text
	if type == "success" then color = THEME.Success
	elseif type == "warning" then color = THEME.Warning
	elseif type == "error" then color = Color3.fromRGB(255, 80, 80)
	end
	stroke.Color = color
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 5)
	local lbl = Instance.new("TextLabel", toast)
	lbl.Size = UDim2.new(1, -16, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = message
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextWrapped = true
	lbl.TextTransparency = 1
	Tween(toast, {BackgroundTransparency = 0.1}, 0.2)
	Tween(lbl, {TextTransparency = 0}, 0.2)
	Tween(stroke, {Transparency = 0.2}, 0.2)
	task.delay(2.5, function()
		if toast and toast.Parent then
			Tween(toast, {BackgroundTransparency = 1}, 0.3)
			Tween(lbl, {TextTransparency = 1}, 0.3)
			Tween(stroke, {Transparency = 1}, 0.3)
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

-- === MAIN GUI (MOBILE-SIZED) ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LLAJG_V5"
ScreenGui.Parent = ParentTarget
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 460)
MainFrame.Position = UDim2.new(0.82, -50, 0.4, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local function EnableDragging(frame)
	local dragging, dragInput, dragStart, startPos
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
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

EnableDragging(MainFrame)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = THEME.Accent
Stroke.Transparency = 0.5
Stroke.Thickness = 2

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = THEME.ItemBG
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Text = "Last Letter<font color=\"rgb(114,100,255)\">AJG</font> V5"
Title.RichText = true
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextColor3 = THEME.Text
Title.Size = UDim2.new(1, -45, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.TextColor3 = THEME.SubText
MinBtn.Size = UDim2.new(0, 40, 1, 0)
MinBtn.Position = UDim2.new(1, -80, 0, 0)
MinBtn.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 15
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Size = UDim2.new(0, 40, 1, 0)
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.MouseButton1Click:Connect(function()
	unloaded = true
	if runConn then runConn:Disconnect() end
	if inputConn then inputConn:Disconnect() end
	if logConn then logConn:Disconnect() end
	for _, btn in ipairs(ButtonCache) do btn:Destroy() end
	table.clear(ButtonCache)
	ScreenGui:Destroy()
	ToastContainer:Destroy()
end)

-- Status Bar
local StatusFrame = Instance.new("Frame", MainFrame)
StatusFrame.Size = UDim2.new(1, -20, 0, 20)
StatusFrame.Position = UDim2.new(0, 10, 0, 42)
StatusFrame.BackgroundTransparency = 1

local StatusDot = Instance.new("Frame", StatusFrame)
StatusDot.Size = UDim2.new(0, 6, 0, 6)
StatusDot.Position = UDim2.new(0, 0, 0.5, -3)
StatusDot.BackgroundColor3 = THEME.SubText
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel", StatusFrame)
StatusText.Text = "Idle..."
StatusText.RichText = true
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 11
StatusText.TextColor3 = THEME.SubText
StatusText.Size = UDim2.new(1, -12, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left

-- Search Box
local SearchFrame = Instance.new("Frame", MainFrame)
SearchFrame.Size = UDim2.new(1, -10, 0, 22)
SearchFrame.Position = UDim2.new(0, 5, 0, 68)
SearchFrame.BackgroundColor3 = THEME.ItemBG
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 5)

local SearchBox = Instance.new("TextBox", SearchFrame)
SearchBox.Size = UDim2.new(1, -16, 1, 0)
SearchBox.Position = UDim2.new(0, 8, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
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

-- Scroll List
local ScrollList = Instance.new("ScrollingFrame", MainFrame)
ScrollList.Size = UDim2.new(1, -10, 1, -190)
ScrollList.Position = UDim2.new(0, 5, 0, 95)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.ScrollBarImageColor3 = THEME.Accent
ScrollList.CanvasSize = UDim2.new(0,0,0,0)

local UIListLayout = Instance.new("UIListLayout", ScrollList)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 3)

-- Settings Frame
local SettingsFrame = Instance.new("Frame", MainFrame)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ClipsDescendants = true

local SlidersFrame = Instance.new("Frame", SettingsFrame)
SlidersFrame.Size = UDim2.new(1, 0, 0, 110)
SlidersFrame.BackgroundTransparency = 1

local TogglesFrame = Instance.new("Frame", SettingsFrame)
TogglesFrame.Size = UDim2.new(1, 0, 0, 280)
TogglesFrame.Position = UDim2.new(0, 0, 0, 110)
TogglesFrame.BackgroundTransparency = 1
TogglesFrame.Visible = false

local sep = Instance.new("Frame", SettingsFrame)
sep.Size = UDim2.new(1, 0, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(45, 45, 50)

local settingsCollapsed = true
local function UpdateLayout()
	if settingsCollapsed then
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 1, -110)})
		Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -210)})
		TogglesFrame.Visible = false
	else
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 390), Position = UDim2.new(0, 0, 1, -390)})
		Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -500)})
		TogglesFrame.Visible = true
	end
end
UpdateLayout()

local ExpandBtn = Instance.new("TextButton", SlidersFrame)
ExpandBtn.Text = "v Settings v"
ExpandBtn.Font = Enum.Font.GothamBold
ExpandBtn.TextSize = 12
ExpandBtn.TextColor3 = THEME.Accent
ExpandBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
ExpandBtn.BackgroundTransparency = 0.5
ExpandBtn.Size = UDim2.new(1, -10, 0, 26)
ExpandBtn.Position = UDim2.new(0, 5, 1, -26)
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 5)
ExpandBtn.MouseButton1Click:Connect(function()
	settingsCollapsed = not settingsCollapsed
	ExpandBtn.Text = settingsCollapsed and "v Settings v" or "^ Hide ^"
	UpdateLayout()
end)

-- Slider Helper
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
			Config.RandomSort = randomSortEnabled
			SaveConfig()
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

-- Speed Slider
local SliderLabel = Instance.new("TextLabel", SlidersFrame)
SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.TextSize = 11
SliderLabel.TextColor3 = THEME.SubText
SliderLabel.Size = UDim2.new(1, -25, 0, 16)
SliderLabel.Position = UDim2.new(0, 12, 0, 6)
SliderLabel.BackgroundTransparency = 1

local SliderBg = Instance.new("Frame", SlidersFrame)
SliderBg.Size = UDim2.new(1, -25, 0, 5)
SliderBg.Position = UDim2.new(0, 12, 0, 24)
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

-- Error Rate Slider
local ErrorLabel = Instance.new("TextLabel", SlidersFrame)
ErrorLabel.Text = "Error: " .. errorRate .. "%"
ErrorLabel.Font = Enum.Font.Gotham
ErrorLabel.TextSize = 10
ErrorLabel.TextColor3 = THEME.SubText
ErrorLabel.Size = UDim2.new(1, -25, 0, 14)
ErrorLabel.Position = UDim2.new(0, 12, 0, 30)
ErrorLabel.BackgroundTransparency = 1

local ErrorBg = Instance.new("Frame", SlidersFrame)
ErrorBg.Size = UDim2.new(1, -25, 0, 5)
ErrorBg.Position = UDim2.new(0, 12, 0, 46)
ErrorBg.BackgroundColor3 = THEME.Slider
Instance.new("UICorner", ErrorBg).CornerRadius = UDim.new(1, 0)

local ErrorFill = Instance.new("Frame", ErrorBg)
ErrorFill.Size = UDim2.new(errorRate/30, 0, 1, 0)
ErrorFill.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
Instance.new("UICorner", ErrorFill).CornerRadius = UDim.new(1, 0)

local ErrorBtn = Instance.new("TextButton", ErrorBg)
ErrorBtn.Size = UDim2.new(1,0,1,0)
ErrorBtn.BackgroundTransparency = 1
ErrorBtn.Text = ""

SetupSlider(ErrorBtn, ErrorBg, ErrorFill, function(pct)
	errorRate = math.floor(pct * 30)
	Config.ErrorRate = errorRate
	ErrorFill.Size = UDim2.new(pct, 0, 1, 0)
	ErrorLabel.Text = "Error: " .. errorRate .. "%"
end)

-- Think Delay Slider (UPDATED RANGE)
local ThinkLabel = Instance.new("TextLabel", SlidersFrame)
ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
ThinkLabel.Font = Enum.Font.Gotham
ThinkLabel.TextSize = 10
ThinkLabel.TextColor3 = THEME.SubText
ThinkLabel.Size = UDim2.new(1, -25, 0, 14)
ThinkLabel.Position = UDim2.new(0, 12, 0, 52)
ThinkLabel.BackgroundTransparency = 1

local ThinkBg = Instance.new("Frame", SlidersFrame)
ThinkBg.Size = UDim2.new(1, -25, 0, 5)
ThinkBg.Position = UDim2.new(0, 12, 0, 68)
ThinkBg.BackgroundColor3 = THEME.Slider
Instance.new("UICorner", ThinkBg).CornerRadius = UDim.new(1, 0)

local ThinkFill = Instance.new("Frame", ThinkBg)
local thinkPct = (thinkDelayCurrent - thinkDelayMin) / (thinkDelayMax - thinkDelayMin)
ThinkFill.Size = UDim2.new(thinkPct, 0, 1, 0)
ThinkFill.BackgroundColor3 = THEME.Accent
Instance.new("UICorner", ThinkFill).CornerRadius = UDim.new(1, 0)

local ThinkBtn = Instance.new("TextButton", ThinkBg)
ThinkBtn.Size = UDim2.new(1,0,1,0)
ThinkBtn.BackgroundTransparency = 1
ThinkBtn.Text = ""

SetupSlider(ThinkBtn, ThinkBg, ThinkFill, function(pct)
	thinkDelayCurrent = thinkDelayMin + pct * (thinkDelayMax - thinkDelayMin)
	Config.ThinkDelay = thinkDelayCurrent
	ThinkFill.Size = UDim2.new(pct, 0, 1, 0)
	ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
end)

-- Toggle Creator
local function CreateToggle(text, pos, callback)
	local btn = Instance.new("TextButton", TogglesFrame)
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 10
	btn.TextColor3 = THEME.Success
	btn.BackgroundColor3 = THEME.Background
	btn.Size = UDim2.new(0, 80, 0, 20)
	btn.Position = pos
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	btn.MouseButton1Click:Connect(function()
		local newState, newText, newColor = callback()
		btn.Text = newText
		btn.TextColor3 = newColor
		SaveConfig()
	end)
	return btn
end

-- Toggles
local HumanizeBtn = CreateToggle("Humanize: "..(useHumanization and "ON" or "OFF"), UDim2.new(0, 10, 0, 4), function()
	useHumanization = not useHumanization
	Config.Humanize = useHumanization
	return useHumanization, "Humanize: "..(useHumanization and "ON" or "OFF"), useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
HumanizeBtn.TextColor3 = useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)

local FingerBtn = CreateToggle("10-Finger: "..(useFingerModel and "ON" or "OFF"), UDim2.new(0, 95, 0, 4), function()
	useFingerModel = not useFingerModel
	Config.FingerModel = useFingerModel
	return useFingerModel, "10-Finger: "..(useFingerModel and "ON" or "OFF"), useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
FingerBtn.TextColor3 = useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)

local KeyboardBtn = CreateToggle("KB: "..(showKeyboard and "ON" or "OFF"), UDim2.new(0, 180, 0, 4), function()
	showKeyboard = not showKeyboard
	Config.ShowKeyboard = showKeyboard
	return showKeyboard, "KB: "..(showKeyboard and "ON" or "OFF"), showKeyboard and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
KeyboardBtn.TextColor3 = showKeyboard and THEME.Success or Color3.fromRGB(255, 100, 100)

local SortBtn = CreateToggle("Sort: "..sortMode, UDim2.new(0, 10, 0, 26), function()
	if sortMode == "Random" then sortMode = "Shortest"
	elseif sortMode == "Shortest" then sortMode = "Longest"
	elseif sortMode == "Longest" then sortMode = "Killer"
	else sortMode = "Random" end
	Config.SortMode = sortMode
	lastDetected = "---"
	return true, "Sort: "..sortMode, THEME.Accent
end)
SortBtn.TextColor3 = THEME.Accent
SortBtn.Size = UDim2.new(0, 120, 0, 20)

local AutoBtn = CreateToggle("Auto Play: "..(autoPlay and "ON" or "OFF"), UDim2.new(0, 140, 0, 26), function()
	autoPlay = not autoPlay
	Config.AutoPlay = autoPlay
	return autoPlay, "Auto Play: "..(autoPlay and "ON" or "OFF"), autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoBtn.TextColor3 = autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoBtn.Size = UDim2.new(0, 120, 0, 20)

local AutoJoinBtn = CreateToggle("Auto Join: "..(autoJoin and "ON" or "OFF"), UDim2.new(0, 10, 0, 50), function()
	autoJoin = not autoJoin
	Config.AutoJoin = autoJoin
	return autoJoin, "Auto Join: "..(autoJoin and "ON" or "OFF"), autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoJoinBtn.TextColor3 = autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoJoinBtn.Size = UDim2.new(0, 240, 0, 20)

local function CreateCheckbox(text, pos, key)
	local container = Instance.new("TextButton", TogglesFrame)
	container.Size = UDim2.new(0, 75, 0, 20)
	container.Position = pos
	container.BackgroundColor3 = THEME.ItemBG
	container.AutoButtonColor = false
	container.Text = ""
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 3)
	local box = Instance.new("Frame", container)
	box.Size = UDim2.new(0, 12, 0, 12)
	box.Position = UDim2.new(0, 4, 0.5, -6)
	box.BackgroundColor3 = THEME.Slider
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
	local check = Instance.new("Frame", box)
	check.Size = UDim2.new(0, 8, 0, 8)
	check.Position = UDim2.new(0.5, -4, 0.5, -4)
	check.BackgroundColor3 = THEME.Success
	check.Visible = Config.AutoJoinSettings[key]
	Instance.new("UICorner", check).CornerRadius = UDim.new(0, 2)
	local lbl = Instance.new("TextLabel", container)
	lbl.Text = text
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.TextColor3 = THEME.SubText
	lbl.Size = UDim2.new(1, -18, 1, 0)
	lbl.Position = UDim2.new(0, 18, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	container.MouseButton1Click:Connect(function()
		Config.AutoJoinSettings[key] = not Config.AutoJoinSettings[key]
		check.Visible = Config.AutoJoinSettings[key]
		if Config.AutoJoinSettings[key] then
			lbl.TextColor3 = THEME.Text
			Tween(box, {BackgroundColor3 = THEME.Accent}, 0.15)
		else
			lbl.TextColor3 = THEME.SubText
			Tween(box, {BackgroundColor3 = THEME.Slider}, 0.15)
		end
		SaveConfig()
	end)
	if Config.AutoJoinSettings[key] then
		lbl.TextColor3 = THEME.Text
		box.BackgroundColor3 = THEME.Accent
	end
	return container
end

CreateCheckbox("1v1", UDim2.new(0, 10, 0, 74), "_1v1")
CreateCheckbox("4P", UDim2.new(0, 90, 0, 74), "_4p")
CreateCheckbox("8P", UDim2.new(0, 170, 0, 74), "_8p")

local BlatantBtn = CreateToggle("Blatant: "..(isBlatant and "ON" or "OFF"), UDim2.new(0, 10, 0, 98), function()
	isBlatant = not isBlatant
	Config.Blatant = isBlatant
	return isBlatant, "Blatant: "..(isBlatant and "ON" or "OFF"), isBlatant and Color3.fromRGB(255, 80, 80) or THEME.SubText
end)
BlatantBtn.TextColor3 = isBlatant and Color3.fromRGB(255, 80, 80) or THEME.SubText
BlatantBtn.Size = UDim2.new(0, 120, 0, 20)

local RiskyBtn = CreateToggle("Risky: "..(riskyMistakes and "ON" or "OFF"), UDim2.new(0, 140, 0, 98), function()
	riskyMistakes = not riskyMistakes
	Config.RiskyMistakes = riskyMistakes
	return riskyMistakes, "Risky: "..(riskyMistakes and "ON" or "OFF"), riskyMistakes and Color3.fromRGB(255, 80, 80) or THEME.SubText
end)
RiskyBtn.TextColor3 = riskyMistakes and Color3.fromRGB(255, 80, 80) or THEME.SubText
RiskyBtn.Size = UDim2.new(0, 120, 0, 20)

local RandomSortBtn = CreateToggle("RandSort: "..(randomSortEnabled and "ON" or "OFF"), UDim2.new(0, 10, 0, 122), function()
	randomSortEnabled = not randomSortEnabled
	Config.RandomSort = randomSortEnabled
	lastDetected = "---"
	return randomSortEnabled, "RandSort: "..(randomSortEnabled and "ON" or "OFF"), randomSortEnabled and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
RandomSortBtn.TextColor3 = randomSortEnabled and THEME.Success or Color3.fromRGB(255, 100, 100)
RandomSortBtn.Size = UDim2.new(0, 120, 0, 20)

-- NEW BUTTONS FOR USED & BLACKLIST
local UsedWordsBtn = Instance.new("TextButton", TogglesFrame)
UsedWordsBtn.Text = "Used Words"
UsedWordsBtn.Font = Enum.Font.Gotham
UsedWordsBtn.TextSize = 10
UsedWordsBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
UsedWordsBtn.BackgroundColor3 = THEME.Background
UsedWordsBtn.Size = UDim2.new(0, 120, 0, 20)
UsedWordsBtn.Position = UDim2.new(0, 10, 0, 146)
Instance.new("UICorner", UsedWordsBtn).CornerRadius = UDim.new(0, 4)

local BlacklistWordsBtn = Instance.new("TextButton", TogglesFrame)
BlacklistWordsBtn.Text = "Blacklist"
BlacklistWordsBtn.Font = Enum.Font.Gotham
BlacklistWordsBtn.TextSize = 10
BlacklistWordsBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
BlacklistWordsBtn.BackgroundColor3 = THEME.Background
BlacklistWordsBtn.Size = UDim2.new(0, 120, 0, 20)
BlacklistWordsBtn.Position = UDim2.new(0, 140, 0, 146)
Instance.new("UICorner", BlacklistWordsBtn).CornerRadius = UDim.new(0, 4)

-- === PANEL: Used Words ===
local UsedWordsFrame = Instance.new("Frame", ScreenGui)
UsedWordsFrame.Name = "UsedWordsFrame"
UsedWordsFrame.Size = UDim2.new(0, 220, 0, 260)
UsedWordsFrame.Position = UDim2.new(0.5, -110, 0.5, -130)
UsedWordsFrame.BackgroundColor3 = THEME.Background
UsedWordsFrame.Visible = false
UsedWordsFrame.ClipsDescendants = true
EnableDragging(UsedWordsFrame)
Instance.new("UICorner", UsedWordsFrame).CornerRadius = UDim.new(0, 6)
local UWStroke = Instance.new("UIStroke", UsedWordsFrame)
UWStroke.Color = THEME.Accent
UWStroke.Transparency = 0.5
UWStroke.Thickness = 2

local UWHeader = Instance.new("TextLabel", UsedWordsFrame)
UWHeader.Text = "Used Words"
UWHeader.Font = Enum.Font.GothamBold
UWHeader.TextSize = 12
UWHeader.TextColor3 = THEME.Text
UWHeader.Size = UDim2.new(1, 0, 0, 30)
UWHeader.BackgroundTransparency = 1

local UWCloseBtn = Instance.new("TextButton", UsedWordsFrame)
UWCloseBtn.Text = "X"
UWCloseBtn.Font = Enum.Font.GothamBold
UWCloseBtn.TextSize = 12
UWCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
UWCloseBtn.Size = UDim2.new(0, 26, 0, 26)
UWCloseBtn.Position = UDim2.new(1, -26, 0, 2)
UWCloseBtn.BackgroundTransparency = 1
UWCloseBtn.MouseButton1Click:Connect(function() UsedWordsFrame.Visible = false end)

local UWScroll = Instance.new("ScrollingFrame", UsedWordsFrame)
UWScroll.Size = UDim2.new(1, -8, 1, -38)
UWScroll.Position = UDim2.new(0, 4, 0, 30)
UWScroll.BackgroundTransparency = 1
UWScroll.ScrollBarThickness = 2
UWScroll.ScrollBarImageColor3 = THEME.Accent
UWScroll.CanvasSize = UDim2.new(0,0,0,0)

local UWListLayout = Instance.new("UIListLayout", UWScroll)
UWListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UWListLayout.Padding = UDim.new(0, 2)

local function RefreshUsedWords()
	for _, c in ipairs(UWScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local count = 0
	for word, _ in pairs(UsedWords) do
		count = count + 1
		local row = Instance.new("TextLabel", UWScroll)
		row.Size = UDim2.new(1, -6, 0, 20)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
		row.BorderSizePixel = 0
		row.Text = word
		row.Font = Enum.Font.Gotham
		row.TextSize = 11
		row.TextColor3 = THEME.Text
		row.BackgroundTransparency = 0
	end
	UWScroll.CanvasSize = UDim2.new(0, 0, 0, count * 22)
end

UsedWordsBtn.MouseButton1Click:Connect(function()
	UsedWordsFrame.Visible = not UsedWordsFrame.Visible
	RefreshUsedWords()
end)

-- === PANEL: Blacklist Words ===
local BlacklistWordsFrame = Instance.new("Frame", ScreenGui)
BlacklistWordsFrame.Name = "BlacklistWordsFrame"
BlacklistWordsFrame.Size = UDim2.new(0, 220, 0, 260)
BlacklistWordsFrame.Position = UDim2.new(0.5, -110, 0.5, -130)
BlacklistWordsFrame.BackgroundColor3 = THEME.Background
BlacklistWordsFrame.Visible = false
BlacklistWordsFrame.ClipsDescendants = true
EnableDragging(BlacklistWordsFrame)
Instance.new("UICorner", BlacklistWordsFrame).CornerRadius = UDim.new(0, 6)
local BWStroke = Instance.new("UIStroke", BlacklistWordsFrame)
BWStroke.Color = Color3.fromRGB(255, 100, 100)
BWStroke.Transparency = 0.5
BWStroke.Thickness = 2

local BWHeader = Instance.new("TextLabel", BlacklistWordsFrame)
BWHeader.Text = "Blacklist Words"
BWHeader.Font = Enum.Font.GothamBold
BWHeader.TextSize = 12
BWHeader.TextColor3 = Color3.fromRGB(255, 100, 100)
BWHeader.Size = UDim2.new(1, 0, 0, 30)
BWHeader.BackgroundTransparency = 1

local BWCloseBtn = Instance.new("TextButton", BlacklistWordsFrame)
BWCloseBtn.Text = "X"
BWCloseBtn.Font = Enum.Font.GothamBold
BWCloseBtn.TextSize = 12
BWCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
BWCloseBtn.Size = UDim2.new(0, 26, 0, 26)
BWCloseBtn.Position = UDim2.new(1, -26, 0, 2)
BWCloseBtn.BackgroundTransparency = 1
BWCloseBtn.MouseButton1Click:Connect(function() BlacklistWordsFrame.Visible = false end)

local BWScroll = Instance.new("ScrollingFrame", BlacklistWordsFrame)
BWScroll.Size = UDim2.new(1, -8, 1, -38)
BWScroll.Position = UDim2.new(0, 4, 0, 30)
BWScroll.BackgroundTransparency = 1
BWScroll.ScrollBarThickness = 2
BWScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
BWScroll.CanvasSize = UDim2.new(0,0,0,0)

local BWListLayout = Instance.new("UIListLayout", BWScroll)
BWListLayout.SortOrder = Enum.SortOrder.LayoutOrder
BWListLayout.Padding = UDim.new(0, 2)

local function RefreshBlacklistWords()
	for _, c in ipairs(BWScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local words = {}
	for w, _ in pairs(Blacklist) do
		table.insert(words, w)
	end
	table.sort(words)
	local count = 0
	for _, word in ipairs(words) do
		count = count + 1
		local row = Instance.new("Frame", BWScroll)
		row.Size = UDim2.new(1, -6, 0, 20)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
		row.BorderSizePixel = 0
		row.BackgroundTransparency = 0
		local lbl = Instance.new("TextLabel", row)
		lbl.Size = UDim2.new(1, -26, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = word
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextColor3 = Color3.fromRGB(255, 150, 150)
		local del = Instance.new("TextButton", row)
		del.Text = "X"
		del.Font = Enum.Font.GothamBold
		del.TextSize = 10
		del.TextColor3 = Color3.fromRGB(255, 80, 80)
		del.Size = UDim2.new(0, 20, 1, 0)
		del.Position = UDim2.new(1, -20, 0, 0)
		del.BackgroundTransparency = 1
		del.MouseButton1Click:Connect(function()
			Blacklist[word] = nil
			local lines = {}
			for w, _ in pairs(Blacklist) do
				table.insert(lines, w)
			end
			if writefile then
				writefile(BlacklistFile, table.concat(lines, "\n"))
			end
			RefreshBlacklistWords()
			ShowToast("Removed from blacklist: " .. word, "success")
		end)
	end
	BWScroll.CanvasSize = UDim2.new(0, 0, 0, count * 22)
end

BlacklistWordsBtn.MouseButton1Click:Connect(function()
	BlacklistWordsFrame.Visible = not BlacklistWordsFrame.Visible
	RefreshBlacklistWords()
end)

-- === CORE FUNCTIONS ===
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

local function CalculateDelayForKeys(prevChar, nextChar)
	if isBlatant then
		return 60 / currentCPM
	end
	local charsPerMin = currentCPM
	local baseDelay = 60 / charsPerMin
	local variance = baseDelay * 0.35
	local extra = 0
	if useHumanization and useFingerModel and prevChar and nextChar and prevChar ~= "" then
		local dist = KeyDistance(prevChar, nextChar)
		extra = dist * 0.018 * (550 / math.max(150, currentCPM))
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
	local layout = Config.KeyboardLayout or "QWERTY"
	if type(char) == "string" and #char == 1 then
		char = char:lower()
		if layout == "QWERTZ" then
			if char == "z" then return Enum.KeyCode.Y end
			if char == "y" then return Enum.KeyCode.Z end
		elseif layout == "AZERTY" then
			if char == "a" then return Enum.KeyCode.Q end
			if char == "q" then return Enum.KeyCode.A end
			if char == "z" then return Enum.KeyCode.W end
			if char == "w" then return Enum.KeyCode.Z end
			if char == "m" then return Enum.KeyCode.Semicolon end
		end
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
		local hold = isBlatant and 0.002 or (baseHold + (math.random() * 0.01) - 0.005)
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
	local focused = UserInputService:GetFocusedTextBox()
	if focused and focused:IsDescendantOf(game) and focused.TextEditable then
		local text = focused.Text
		focused.Text = text:sub(1, -count - 1)
		lastKey = nil
		return
	end
	local key = Enum.KeyCode.Backspace
	for i = 1, count do
		pcall(function()
			VirtualInputManager:SendKeyEvent(true, key, false, game)
			VirtualInputManager:SendKeyEvent(false, key, false, game)
		end)
		if i % 20 == 0 then task.wait() end
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

local function SmartType(targetWord, currentDetected, isCorrection, bypassTurn)
	if unloaded then return end
	if isTyping then
		if (tick() - lastTypingStart) > 15 then
			isTyping = false
			isAutoPlayScheduled = false
			StatusText.Text = "Reset Typing"
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
	local attempt = 0
	local maxAttempts = 3
	while attempt < maxAttempts do
		attempt = attempt + 1
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
				if not riskyMistakes then
					task.wait(0.1)
					local finalCheck = GetGameTextBox()
					if finalCheck and finalCheck.Text ~= targetWord then
						StatusText.Text = "Typing mismatch detected!"
						StatusText.TextColor3 = THEME.Warning
						Backspace(#finalCheck.Text)
						isTyping = false
						forceUpdateList = true
						return
					end
				end
				PressEnter()
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
					AddToBlacklist(targetWord)
					RandomPriority[targetWord] = nil
					for k, list in pairs(RandomOrderCache) do
						for i = #list, 1, -1 do
							if list[i] == targetWord then table.remove(list, i) end
						end
					end
					StatusText.Text = "Rejected: removed '" .. targetWord .. "'"
					StatusText.TextColor3 = THEME.Warning
					local focused = UserInputService:GetFocusedTextBox()
					if focused and focused:IsDescendantOf(game) and focused.TextEditable then
						focused.Text = ""
					else
						Backspace(#targetWord + 5)
					end
					lastDetected = "---"
					isTyping = false
					forceUpdateList = true
					return
				else
					StatusText.Text = "Word Cleared (Corrected)"
					StatusText.TextColor3 = THEME.SubText
					local current = GetCurrentGameWord()
					if #current > 0 then
						Backspace(#current)
					end
					UsedWords[targetWord] = true
					isMyTurnLogDetected = false
					task.wait(0.2)
				end
			else
				local missingPart = ""
				if targetWord:sub(1, #currentDetected) == currentDetected then
					missingPart = targetWord:sub(#currentDetected + 1)
				else
					missingPart = targetWord
				end
				local letters = "abcdefghijklmnopqrstuvwxyz"
				for i = 1, #missingPart do
					if not bypassTurn and not GetTurnInfo() then
						task.wait(0.05)
						if not GetTurnInfo() then break end
					end
					local ch = missingPart:sub(i, i)
					if errorRate > 0 and (math.random() < (errorRate / 100)) then
						local typoChar
						repeat
							local idx = math.random(1, #letters)
							typoChar = letters:sub(idx, idx)
						until typoChar ~= ch
						SimulateKey(typoChar)
						if riskyMistakes then
							task.wait(0.05 + math.random() * 0.1)
							PressEnter()
						end
						task.wait(CalculateDelayForKeys(lastKey, typoChar))
						lastKey = typoChar
						local realize = thinkDelayCurrent * (0.6 + math.random() * 0.8)
						task.wait(realize)
						SimulateKey(Enum.KeyCode.Backspace)
						lastKey = nil
						task.wait(0.05 + math.random() * 0.08)
						SimulateKey(ch)
						task.wait(CalculateDelayForKeys(lastKey, ch))
						lastKey = ch
					else
						SimulateKey(ch)
						task.wait(CalculateDelayForKeys(lastKey, ch))
						lastKey = ch
					end
					if useHumanization and math.random() < 0.03 then
						task.wait(0.12 + math.random() * 0.5)
					end
				end
				if not riskyMistakes then
					task.wait(0.1)
					local finalCheck = GetGameTextBox()
					if finalCheck and finalCheck.Text ~= targetWord then
						StatusText.Text = "Typing mismatch detected!"
						StatusText.TextColor3 = THEME.Warning
						Backspace(#finalCheck.Text)
						isTyping = false
						forceUpdateList = true
						return
					end
				end
				PressEnter()
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
					local postCheck = GetGameTextBox()
					if postCheck and postCheck.Text == targetWord then
						StatusText.Text = "Enter failed? Retrying..."
						PressEnter()
						task.wait(0.5)
						if GetCurrentGameWord() == currentDetected then
							StatusText.Text = "Submission Failed (Lag?)"
							StatusText.TextColor3 = THEME.Warning
							Backspace(#targetWord)
							isTyping = false
							forceUpdateList = true
							return
						end
					end
					AddToBlacklist(targetWord)
					for k, list in pairs(RandomOrderCache) do
						for i = #list, 1, -1 do
							if list[i] == targetWord then table.remove(list, i) end
						end
					end
					StatusText.Text = "Rejected: removed '" .. targetWord .. "'"
					StatusText.TextColor3 = THEME.Warning
					local focused = UserInputService:GetFocusedTextBox()
					if focused and focused:IsDescendantOf(game) and focused.TextEditable then
						focused.Text = ""
					else
						Backspace(#targetWord + 5)
					end
					isTyping = false
					lastDetected = "---"
					forceUpdateList = true
					task.spawn(function()
						task.wait(0.1)
						local _, req = GetTurnInfo()
						UpdateList(currentDetected, req)
					end)
					return
				else
					StatusText.Text = "Verification Failed"
					StatusText.TextColor3 = THEME.Warning
					local current = GetCurrentGameWord()
					if #current > 0 then
						Backspace(#current)
					end
					UsedWords[targetWord] = true
					isMyTurnLogDetected = false
					task.wait(0.2)
				end
			end
		end)
		if success then break end
		task.wait(0.3)
	end
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
		end
		if #matches > 0 then
			searchPrefix = requiredLetter
			isBacktracked = true
		end
	end
	if #matches > 0 then
		if sortMode == "Longest" then
			table.sort(matches, function(a, b) return #a > #b end)
		elseif sortMode == "Shortest" then
			table.sort(matches, function(a, b) return #a < #b end)
		elseif sortMode == "Killer" then
			table.sort(matches, function(a, b)
				local sA = GetKillerScore(a)
				local sB = GetKillerScore(b)
				if sA == sB then
					return #a < #b
				end
				return sA > sB
			end)
		end
		if randomSortEnabled and sortMode ~= "Random" then
			shuffleTable(matches)
		end
	end
	local displayList = {}
	local maxDisplay = 40
	for i = 1, math.min(maxDisplay, #matches) do table.insert(displayList, matches[i]) end
	if showKeyboard and KeyboardFrame.Visible then
		local colors = {
			Color3.fromRGB(100, 255, 140),
			Color3.fromRGB(255, 180, 200),
			Color3.fromRGB(100, 200, 255)
		}
		local targetKeys = {}
		for i = 1, math.min(3, #displayList) do
			local w = displayList[i]
			local nextChar = w:sub(#searchPrefix + 1, #searchPrefix + 1)
			if nextChar and nextChar ~= "" then
				local char = nextChar:lower()
				if not targetKeys[char] then
					targetKeys[char] = i
				end
			end
		end
		for char, k in pairs(Keys) do
			local priority = targetKeys[char]
			if priority then
				k.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				Tween(k, {BackgroundColor3 = colors[priority]}, 0.3)
			else
				Tween(k, {BackgroundColor3 = THEME.ItemBG}, 0.2)
			end
		end
	end
	if #matches > 0 and not isBacktracked then
		currentBestMatch = matches[1]
	else
		currentBestMatch = nil
	end
	if isBacktracked then
		local validPart = searchPrefix
		local invalidPart = detectedText:sub(#searchPrefix + 1)
		local accentRGB = ColorToRGB(THEME.Accent)
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
				btn.Size = UDim2.new(1, -6, 0, 30)
				btn.BackgroundColor3 = THEME.ItemBG
				btn.Text = ""
				btn.AutoButtonColor = false
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
				lbl = Instance.new("TextLabel", btn)
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
			local accentRGB = ColorToRGB(THEME.Accent)
			if i == 1 then accentRGB = "100,255,140"
			elseif i == 2 then accentRGB = "255,180,200"
			elseif i == 3 then accentRGB = "100,200,255"
			end
			local textRGB = ColorToRGB(THEME.Text)
			local displayText = ""
			if isBacktracked then
				local prefix = w:sub(1, #searchPrefix)
				local suffix = w:sub(#searchPrefix + 1)
				displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font>" .. "<font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
			else
				local prefix = w:sub(1, #detectedText)
				local suffix = w:sub(#detectedText + 1)
				displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font>" .. "<font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
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
end

-- === MAIN LOOP ===
runConn = RunService.RenderStepped:Connect(function()
	local success, err = pcall(function()
		local now = tick()
		local player = Players.LocalPlayer
		local gui = player and player:FindFirstChild("PlayerGui")
		local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")

		if isTyping and (tick() - lastTypingStart) > 15 then
			isTyping = false
			isAutoPlayScheduled = false
			StatusText.Text = "Reset Typing"
			StatusText.TextColor3 = THEME.Warning
		end

		local typeLbl = frame and frame:FindFirstChild("Type")
		local typeVisible = typeLbl and typeLbl.Visible

		if typeVisible and not lastTypeVisible then
			-- HANYA reset UsedWords setelah 1 detik
			task.delay(1, function()
				UsedWords = {}
				ShowToast("✅ Cache cleared! Ready for next round.", "success")
				StatusText.Text = "New Round"
				StatusText.TextColor3 = THEME.Success
			end)
		end

		lastTypeVisible = typeVisible

		local opponentWord = DetectOpponentUsedWord(frame)
		if opponentWord and opponentWord ~= "" and not opponentWord:find("#") then
			UsedWords[opponentWord] = true
		end

	end)
end)

inputConn = UserInputService.InputBegan:Connect(function(input)
	if unloaded then return end
	if input.KeyCode == TOGGLE_KEY then ScreenGui.Enabled = not ScreenGui.Enabled end
end)
