-- MODIFIKASI LENGKAP: Last Letter AJG v4 - OPTIMIZED & ENHANCED
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

-- === THEME SEDERHANA ===
local THEME = {
	Background = Color3.fromRGB(25, 25, 30),
	ItemBG = Color3.fromRGB(35, 35, 40),
	Accent = Color3.fromRGB(100, 180, 255),
	Text = Color3.fromRGB(230, 230, 240),
	SubText = Color3.fromRGB(140, 140, 150),
	Success = Color3.fromRGB(100, 255, 140),
	Warning = Color3.fromRGB(255, 180, 80),
	Error = Color3.fromRGB(255, 80, 80),
	Slider = Color3.fromRGB(50, 50, 60)
}

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
	MaxTypeSpeed = 3000,
	KeyboardLayout = "QWERTY",
	RandomSort = false
}

-- === UTILS ===
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

-- === VARIABEL GLOBAL ===
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
local thinkDelayMin = 0.1 -- DIPERBARUI
local thinkDelayMax = 2.0 -- DIPERBARUI
local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil

-- === BLACKLIST ===
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
logConn = LogService.MessageOut:Connect(function(message, _)
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

local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "WordHelperLoading"
local success, parent = pcall(function() return gethui() end)
if not success or not parent then parent = game:GetService("CoreGui") end
LoadingGui.Parent = parent
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local LoadingFrame = Instance.new("Frame", LoadingGui)
LoadingFrame.Size = UDim2.new(0, 250, 0, 70)
LoadingFrame.Position = UDim2.new(0.5, -125, 0.4, 0)
LoadingFrame.BackgroundColor3 = THEME.Background
LoadingFrame.BorderSizePixel = 0
Instance.new("UICorner", LoadingFrame).CornerRadius = UDim.new(0, 6)

local LStroke = Instance.new("UIStroke", LoadingFrame)
LStroke.Color = THEME.Accent
LStroke.Transparency = 0.6
LStroke.Thickness = 1.5

local LoadingTitle = Instance.new("TextLabel", LoadingFrame)
LoadingTitle.Size = UDim2.new(1, 0, 0, 30)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Text = "Last Letter AJG V4"
LoadingTitle.TextColor3 = THEME.Accent
LoadingTitle.Font = Enum.Font.GothamBold
LoadingTitle.TextSize = 16

local LoadingStatus = Instance.new("TextLabel", LoadingFrame)
LoadingStatus.Size = UDim2.new(1, -10, 0, 25)
LoadingStatus.Position = UDim2.new(0, 5, 0, 40)
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Text = "Initializing..."
LoadingStatus.TextColor3 = THEME.Text
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.TextSize = 13

local function UpdateStatus(text, color)
	LoadingStatus.Text = text
	if color then LoadingStatus.TextColor3 = color end
	game:GetService("RunService").RenderStepped:Wait()
end

local function FetchWords()
	UpdateStatus("Fetching word list...", THEME.Warning)
	local success, res = pcall(function()
		return request({Url = url, Method = "GET"})
	end)
	if success and res and res.Body then
		writefile(fileName, res.Body)
		UpdateStatus("Loaded!", THEME.Success)
	else
		UpdateStatus("Using cached words.", THEME.SubText)
	end
	task.wait(0.3)
end

FetchWords()

local Words = {}
local SeenWords = {}

local function LoadList(fname)
	UpdateStatus("Parsing words...", THEME.Warning)
	if isfile(fname) then
		local content = readfile(fname)
		for w in content:gmatch("[^\r\n]+") do
			local clean = w:gsub("[%s%c]+", ""):lower()
			if #clean > 0 and not SeenWords[clean] then
				SeenWords[clean] = true
				table.insert(Words, clean)
			end
		end
		UpdateStatus("Loaded " .. #Words .. " words", THEME.Success)
	else
		UpdateStatus("No word file!", THEME.Error)
	end
	task.wait(0.5)
end

LoadList(fileName)
LoadingGui:Destroy()

table.sort(Words)

Buckets = {}
for _, w in ipairs(Words) do
	local c = w:sub(1,1) or "#"
	Buckets[c] = Buckets[c] or {}
	table.insert(Buckets[c], w)
end

if Config.CustomWords then
	for _, w in ipairs(Config.CustomWords) do
		local clean = w:gsub("[%s%c]+", ""):lower()
		if #clean > 0 and not SeenWords[clean] then
			SeenWords[clean] = true
			table.insert(Words, clean)
			local c = clean:sub(1,1) or "#"
			Buckets[c] = Buckets[c] or {}
			table.insert(Buckets[c], clean)
		end
	end
end
SeenWords = nil

-- === SHUFFLE ===
local function shuffleTable(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- === HARD ENDINGS ===
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

-- === TWEEN HELPER ===
local function Tween(obj, props, time)
	TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- === GET CURRENT WORD ===
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
		if math.abs(a.X - b.X) > 2 then return a.X < b.X end
		return a.Id < b.Id
	end)

	for _, data in ipairs(letterData) do
		local t = tostring(data.Txt.Text)
		if t:find("#") or t:find("%*") then censored = true end
		detected = detected .. t
	end

	return detected:lower():gsub(" ", ""), censored
end

-- === TURN INFO ===
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

-- === DETECT OPPONENT USED WORD ===
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

-- === PARENT TARGET ===
local function GetSecureParent()
	local success, result = pcall(function() return gethui() end)
	if success and result then return result end
	success, result = pcall(function() return CoreGui end)
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

-- === TOAST SYSTEM ===
local ToastContainer = Instance.new("Frame", ScreenGui)
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 250, 1, 0)
ToastContainer.Position = UDim2.new(1, -270, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 100

local function ShowToast(message, type)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 35)
	toast.BackgroundColor3 = THEME.ItemBG
	toast.BorderSizePixel = 0
	toast.BackgroundTransparency = 1
	toast.Parent = ToastContainer

	local stroke = Instance.new("UIStroke", toast)
	stroke.Thickness = 1
	stroke.Transparency = 1

	local color = THEME.Text
	if type == "success" then color = THEME.Success
	elseif type == "warning" then color = THEME.Warning
	elseif type == "error" then color = THEME.Error
	end

	stroke.Color = color
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 5)

	local lbl = Instance.new("TextLabel", toast)
	lbl.Size = UDim2.new(1, -15, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = message
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextWrapped = true
	lbl.TextTransparency = 1

	Tween(toast, {BackgroundTransparency = 0.2}, 0.2)
	Tween(lbl, {TextTransparency = 0}, 0.2)
	Tween(stroke, {Transparency = 0.3}, 0.2)

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

-- === MAIN GUI ===
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 420)
MainFrame.Position = UDim2.new(0.82, 0, 0.4, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local function EnableDragging(frame)
	local dragging, dragInput, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
		if input.UserInputType == Enum.UserInputType.MouseMovement then
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
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = THEME.Accent
Stroke.Transparency = 0.6
Stroke.Thickness = 1.5

-- === HEADER ===
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = THEME.ItemBG
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Text = "Last Letter AJG"
Title.RichText = true
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextColor3 = THEME.Text
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 5, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = THEME.Error
CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.MouseButton1Click:Connect(function()
	unloaded = true
	if runConn then runConn:Disconnect() end
	if inputConn then inputConn:Disconnect() end
	if logConn then logConn:Disconnect() end
	for _, btn in ipairs(ButtonCache) do btn:Destroy() end
	table.clear(ButtonCache)
	ScreenGui:Destroy()
end)

-- === STATUS ===
local StatusFrame = Instance.new("Frame", MainFrame)
StatusFrame.Size = UDim2.new(1, -20, 0, 20)
StatusFrame.Position = UDim2.new(0, 10, 0, 35)
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
StatusText.Size = UDim2.new(1, -10, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left

-- === SEARCH BOX ===
local SearchFrame = Instance.new("Frame", MainFrame)
SearchFrame.Size = UDim2.new(1, -10, 0, 22)
SearchFrame.Position = UDim2.new(0, 5, 0, 60)
SearchFrame.BackgroundColor3 = THEME.ItemBG
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 4)

local SearchBox = Instance.new("TextBox", SearchFrame)
SearchBox.Size = UDim2.new(1, -15, 1, 0)
SearchBox.Position = UDim2.new(0, 8, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.TextColor3 = THEME.Text
SearchBox.PlaceholderText = "Search..."
SearchBox.PlaceholderColor3 = THEME.SubText
SearchBox.Text = ""

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if UpdateList then
		UpdateList(lastDetected, lastRequiredLetter)
	end
end)

-- === SCROLL LIST ===
local ScrollList = Instance.new("ScrollingFrame", MainFrame)
ScrollList.Size = UDim2.new(1, -10, 1, -180)
ScrollList.Position = UDim2.new(0, 5, 0, 85)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.ScrollBarImageColor3 = THEME.Accent
ScrollList.CanvasSize = UDim2.new(0,0,0,0)

local UIListLayout = Instance.new("UIListLayout", ScrollList)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 2)

-- === SETTINGS FRAME ===
local SettingsFrame = Instance.new("Frame", MainFrame)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ClipsDescendants = true

local SlidersFrame = Instance.new("Frame", SettingsFrame)
SlidersFrame.Size = UDim2.new(1, 0, 0, 100)
SlidersFrame.BackgroundTransparency = 1

local TogglesFrame = Instance.new("Frame", SettingsFrame)
TogglesFrame.Size = UDim2.new(1, 0, 0, 200)
TogglesFrame.Position = UDim2.new(0, 0, 0, 100)
TogglesFrame.BackgroundTransparency = 1
TogglesFrame.Visible = false

local sep = Instance.new("Frame", SettingsFrame)
sep.Size = UDim2.new(1, 0, 0, 1)
sep.Position = UDim2.new(0, 0, 0, 100)
sep.BackgroundColor3 = Color3.fromRGB(50, 50, 55)

local settingsCollapsed = true

local function UpdateLayout()
	if settingsCollapsed then
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 1, -100)}, 0.2)
		Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -180)}, 0.2)
		TogglesFrame.Visible = false
	else
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 300), Position = UDim2.new(0, 0, 1, -300)}, 0.2)
		Tween(ScrollList, {Size = UDim2.new(1, -10, 1, -380)}, 0.2)
		TogglesFrame.Visible = true
	end
end

UpdateLayout()

local ExpandBtn = Instance.new("TextButton", SlidersFrame)
ExpandBtn.Text = "▼ Settings"
ExpandBtn.Font = Enum.Font.GothamBold
ExpandBtn.TextSize = 12
ExpandBtn.TextColor3 = THEME.Accent
ExpandBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
ExpandBtn.BackgroundTransparency = 0.5
ExpandBtn.Size = UDim2.new(1, -10, 0, 25)
ExpandBtn.Position = UDim2.new(0, 5, 1, -25)
Instance.new("UICorner", ExpandBtn).CornerRadius = UDim.new(0, 4)
ExpandBtn.MouseButton1Click:Connect(function()
	settingsCollapsed = not settingsCollapsed
	ExpandBtn.Text = settingsCollapsed and "▼ Settings" or "▲ Settings"
	UpdateLayout()
end)

-- === SLIDERS ===
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
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				if move then move:Disconnect() end
				if rel then rel:Disconnect() end
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
SliderLabel.Size = UDim2.new(1, -20, 0, 16)
SliderLabel.Position = UDim2.new(0, 10, 0, 5)
SliderLabel.BackgroundTransparency = 1

local SliderBg = Instance.new("Frame", SlidersFrame)
SliderBg.Size = UDim2.new(1, -20, 0, 5)
SliderBg.Position = UDim2.new(0, 10, 0, 22)
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
ErrorLabel.TextSize = 11
ErrorLabel.TextColor3 = THEME.SubText
ErrorLabel.Size = UDim2.new(1, -20, 0, 16)
ErrorLabel.Position = UDim2.new(0, 10, 0, 28)
ErrorLabel.BackgroundTransparency = 1

local ErrorBg = Instance.new("Frame", SlidersFrame)
ErrorBg.Size = UDim2.new(1, -20, 0, 5)
ErrorBg.Position = UDim2.new(0, 10, 0, 45)
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

-- Think Delay Slider
local ThinkLabel = Instance.new("TextLabel", SlidersFrame)
ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
ThinkLabel.Font = Enum.Font.Gotham
ThinkLabel.TextSize = 11
ThinkLabel.TextColor3 = THEME.SubText
ThinkLabel.Size = UDim2.new(1, -20, 0, 16)
ThinkLabel.Position = UDim2.new(0, 10, 0, 51)
ThinkLabel.BackgroundTransparency = 1

local ThinkBg = Instance.new("Frame", SlidersFrame)
ThinkBg.Size = UDim2.new(1, -20, 0, 5)
ThinkBg.Position = UDim2.new(0, 10, 0, 68)
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

SetupSlider(SliderBtn, SliderBg, SliderFill, function(pct)
	local max = isBlatant and MAX_CPM_BLATANT or MAX_CPM_LEGIT
	currentCPM = math.floor(MIN_CPM + (pct * (max - MIN_CPM)))
	SliderFill.Size = UDim2.new(pct, 0, 1, 0)
	SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
	if currentCPM > 900 then
		SliderFill.BackgroundColor3 = THEME.Error
	else
		SliderFill.BackgroundColor3 = THEME.Accent
	end
end)

SetupSlider(ErrorBtn, ErrorBg, ErrorFill, function(pct)
	errorRate = math.floor(pct * 30)
	Config.ErrorRate = errorRate
	ErrorFill.Size = UDim2.new(pct, 0, 1, 0)
	ErrorLabel.Text = "Error: " .. errorRate .. "%"
end)

SetupSlider(ThinkBtn, ThinkBg, ThinkFill, function(pct)
	thinkDelayCurrent = thinkDelayMin + pct * (thinkDelayMax - thinkDelayMin)
	Config.ThinkDelay = thinkDelayCurrent
	ThinkFill.Size = UDim2.new(pct, 0, 1, 0)
	ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
end)

-- === TOGGLES ===
local function CreateToggle(text, pos, callback)
	local btn = Instance.new("TextButton", TogglesFrame)
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 11
	btn.TextColor3 = THEME.Success
	btn.BackgroundColor3 = THEME.Background
	btn.Size = UDim2.new(0, 80, 0, 20)
	btn.Position = pos
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
	btn.MouseButton1Click:Connect(function()
		local newState, newText, newColor = callback()
		btn.Text = newText
		btn.TextColor3 = newColor
		SaveConfig()
	end)
	return btn
end

local HumanizeBtn = CreateToggle("Humanize", UDim2.new(0, 5, 0, 5), function()
	useHumanization = not useHumanization
	Config.Humanize = useHumanization
	return useHumanization, useHumanization and "✓ Human" or "✗ Human", useHumanization and THEME.Success or THEME.Error
end)

local FingerBtn = CreateToggle("10-Finger", UDim2.new(0, 90, 0, 5), function()
	useFingerModel = not useFingerModel
	Config.FingerModel = useFingerModel
	return useFingerModel, useFingerModel and "✓ 10F" or "✗ 10F", useFingerModel and THEME.Success or THEME.Error
end)

local AutoBtn = CreateToggle("Auto Play", UDim2.new(0, 5, 0, 28), function()
	autoPlay = not autoPlay
	Config.AutoPlay = autoPlay
	return autoPlay, autoPlay and "✓ Auto" or "✗ Auto", autoPlay and THEME.Success or THEME.Error
end)

local BlatantBtn = CreateToggle("Blatant", UDim2.new(0, 90, 0, 28), function()
	isBlatant = not isBlatant
	Config.Blatant = isBlatant
	return isBlatant, isBlatant and "✓ Blatant" or "✗ Blatant", isBlatant and THEME.Error or THEME.SubText
end)

local RiskyBtn = CreateToggle("Risky", UDim2.new(0, 5, 0, 51), function()
	riskyMistakes = not riskyMistakes
	Config.RiskyMistakes = riskyMistakes
	return riskyMistakes, riskyMistakes and "✓ Risky" or "✗ Risky", riskyMistakes and THEME.Error or THEME.SubText
end)

local RandomSortBtn = CreateToggle("Rand Sort", UDim2.new(0, 90, 0, 51), function()
	randomSortEnabled = not randomSortEnabled
	Config.RandomSort = randomSortEnabled
	lastDetected = "---"
	return randomSortEnabled, randomSortEnabled and "✓ Rand" or "✗ Rand", randomSortEnabled and THEME.Success or THEME.Error
end)

-- === BUTTONS BARU ===
local UsedWordsBtn = Instance.new("TextButton", TogglesFrame)
UsedWordsBtn.Text = "Used Words"
UsedWordsBtn.Font = Enum.Font.Gotham
UsedWordsBtn.TextSize = 11
UsedWordsBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
UsedWordsBtn.BackgroundColor3 = THEME.Background
UsedWordsBtn.Size = UDim2.new(0, 165, 0, 20)
UsedWordsBtn.Position = UDim2.new(0, 5, 0, 75)
Instance.new("UICorner", UsedWordsBtn).CornerRadius = UDim.new(0, 3)

local BlacklistBtn = Instance.new("TextButton", TogglesFrame)
BlacklistBtn.Text = "Blacklist"
BlacklistBtn.Font = Enum.Font.Gotham
BlacklistBtn.TextSize = 11
BlacklistBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
BlacklistBtn.BackgroundColor3 = THEME.Background
BlacklistBtn.Size = UDim2.new(0, 165, 0, 20)
BlacklistBtn.Position = UDim2.new(0, 5, 0, 98)
Instance.new("UICorner", BlacklistBtn).CornerRadius = UDim.new(0, 3)

local WordBrowserBtn = Instance.new("TextButton", TogglesFrame)
WordBrowserBtn.Text = "Word Browser"
WordBrowserBtn.Font = Enum.Font.Gotham
WordBrowserBtn.TextSize = 11
WordBrowserBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
WordBrowserBtn.BackgroundColor3 = THEME.Background
WordBrowserBtn.Size = UDim2.new(0, 165, 0, 20)
WordBrowserBtn.Position = UDim2.new(0, 5, 0, 121)
Instance.new("UICorner", WordBrowserBtn).CornerRadius = UDim.new(0, 3)

-- === USED WORDS FRAME ===
local UsedWordsFrame = Instance.new("Frame", ScreenGui)
UsedWordsFrame.Name = "UsedWordsFrame"
UsedWordsFrame.Size = UDim2.new(0, 220, 0, 280)
UsedWordsFrame.Position = UDim2.new(0.5, -110, 0.5, -140)
UsedWordsFrame.BackgroundColor3 = THEME.Background
UsedWordsFrame.Visible = false
UsedWordsFrame.ClipsDescendants = true
EnableDragging(UsedWordsFrame)
Instance.new("UICorner", UsedWordsFrame).CornerRadius = UDim.new(0, 6)
local UWStroke = Instance.new("UIStroke", UsedWordsFrame)
UWStroke.Color = Color3.fromRGB(180, 220, 255)
UWStroke.Transparency = 0.6
UWStroke.Thickness = 1.5

local UWHeader = Instance.new("TextLabel", UsedWordsFrame)
UWHeader.Text = "Used Words"
UWHeader.Font = Enum.Font.GothamBold
UWHeader.TextSize = 14
UWHeader.TextColor3 = Color3.fromRGB(180, 220, 255)
UWHeader.Size = UDim2.new(1, 0, 0, 25)
UWHeader.BackgroundTransparency = 1

local UWClose = Instance.new("TextButton", UsedWordsFrame)
UWClose.Text = "X"
UWClose.Font = Enum.Font.GothamBold
UWClose.TextSize = 12
UWClose.TextColor3 = THEME.Error
UWClose.Size = UDim2.new(0, 25, 0, 25)
UWClose.Position = UDim2.new(1, -25, 0, 0)
UWClose.BackgroundTransparency = 1
UWClose.MouseButton1Click:Connect(function() UsedWordsFrame.Visible = false end)

local UWScroll = Instance.new("ScrollingFrame", UsedWordsFrame)
UWScroll.Size = UDim2.new(1, -10, 1, -35)
UWScroll.Position = UDim2.new(0, 5, 0, 25)
UWScroll.BackgroundTransparency = 1
UWScroll.ScrollBarThickness = 2
UWScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 220, 255)
UWScroll.CanvasSize = UDim2.new(0,0,0,0)

local UWLayout = Instance.new("UIListLayout", UWScroll)
UWLayout.SortOrder = Enum.SortOrder.LayoutOrder
UWLayout.Padding = UDim.new(0, 2)

local function RefreshUsedWords()
	for _, c in ipairs(UWScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local count = 0
	for word, _ in pairs(UsedWords) do
		count = count + 1
		local row = Instance.new("Frame", UWScroll)
		row.Size = UDim2.new(1, -6, 0, 20)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(30,30,35) or Color3.fromRGB(35,35,40)
		row.BorderSizePixel = 0
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)

		local lbl = Instance.new("TextLabel", row)
		lbl.Text = word
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextColor3 = THEME.Text
		lbl.Size = UDim2.new(1, -30, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		lbl.BackgroundTransparency = 1

		local del = Instance.new("TextButton", row)
		del.Text = "X"
		del.Font = Enum.Font.GothamBold
		del.TextSize = 10
		del.TextColor3 = THEME.Error
		del.Size = UDim2.new(0, 20, 1, 0)
		del.Position = UDim2.new(1, -20, 0, 0)
		del.BackgroundTransparency = 1
		del.MouseButton1Click:Connect(function()
			UsedWords[word] = nil
			RefreshUsedWords()
			ShowToast("Removed from Used: " .. word, "success")
		end)
	end
	UWScroll.CanvasSize = UDim2.new(0, 0, 0, count * 22)
end

UsedWordsBtn.MouseButton1Click:Connect(function()
	UsedWordsFrame.Visible = not UsedWordsFrame.Visible
	UsedWordsFrame.Parent = ScreenGui
	RefreshUsedWords()
end)

-- === BLACKLIST FRAME ===
local BlacklistFrame = Instance.new("Frame", ScreenGui)
BlacklistFrame.Name = "BlacklistFrame"
BlacklistFrame.Size = UDim2.new(0, 220, 0, 280)
BlacklistFrame.Position = UDim2.new(0.5, -110, 0.5, -140)
BlacklistFrame.BackgroundColor3 = THEME.Background
BlacklistFrame.Visible = false
BlacklistFrame.ClipsDescendants = true
EnableDragging(BlacklistFrame)
Instance.new("UICorner", BlacklistFrame).CornerRadius = UDim.new(0, 6)
local BLStroke = Instance.new("UIStroke", BlacklistFrame)
BLStroke.Color = Color3.fromRGB(255, 150, 150)
BLStroke.Transparency = 0.6
BLStroke.Thickness = 1.5

local BLHeader = Instance.new("TextLabel", BlacklistFrame)
BLHeader.Text = "Blacklist"
BLHeader.Font = Enum.Font.GothamBold
BLHeader.TextSize = 14
BLHeader.TextColor3 = Color3.fromRGB(255, 150, 150)
BLHeader.Size = UDim2.new(1, 0, 0, 25)
BLHeader.BackgroundTransparency = 1

local BLClose = Instance.new("TextButton", BlacklistFrame)
BLClose.Text = "X"
BLClose.Font = Enum.Font.GothamBold
BLClose.TextSize = 12
BLClose.TextColor3 = THEME.Error
BLClose.Size = UDim2.new(0, 25, 0, 25)
BLClose.Position = UDim2.new(1, -25, 0, 0)
BLClose.BackgroundTransparency = 1
BLClose.MouseButton1Click:Connect(function() BlacklistFrame.Visible = false end)

local BLScroll = Instance.new("ScrollingFrame", BlacklistFrame)
BLScroll.Size = UDim2.new(1, -10, 1, -35)
BLScroll.Position = UDim2.new(0, 5, 0, 25)
BLScroll.BackgroundTransparency = 1
BLScroll.ScrollBarThickness = 2
BLScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 150)
BLScroll.CanvasSize = UDim2.new(0,0,0,0)

local BLLayout = Instance.new("UIListLayout", BLScroll)
BLLayout.SortOrder = Enum.SortOrder.LayoutOrder
BLLayout.Padding = UDim.new(0, 2)

local function RefreshBlacklist()
	for _, c in ipairs(BLScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local count = 0
	for word, _ in pairs(Blacklist) do
		count = count + 1
		local row = Instance.new("Frame", BLScroll)
		row.Size = UDim2.new(1, -6, 0, 20)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(30,30,35) or Color3.fromRGB(35,35,40)
		row.BorderSizePixel = 0
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)

		local lbl = Instance.new("TextLabel", row)
		lbl.Text = word
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextColor3 = THEME.Text
		lbl.Size = UDim2.new(1, -30, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		lbl.BackgroundTransparency = 1

		local del = Instance.new("TextButton", row)
		del.Text = "X"
		del.Font = Enum.Font.GothamBold
		del.TextSize = 10
		del.TextColor3 = THEME.Error
		del.Size = UDim2.new(0, 20, 1, 0)
		del.Position = UDim2.new(1, -20, 0, 0)
		del.BackgroundTransparency = 1
		del.MouseButton1Click:Connect(function()
			Blacklist[word] = nil
			AddToBlacklist("") -- clear file manually?
			-- Rebuild file
			local lines = {}
			for w, _ in pairs(Blacklist) do
				table.insert(lines, w)
			end
			if writefile then
				writefile(BlacklistFile, table.concat(lines, "\n"))
			end
			RefreshBlacklist()
			ShowToast("Removed from Blacklist: " .. word, "success")
		end)
	end
	BLScroll.CanvasSize = UDim2.new(0, 0, 0, count * 22)
end

BlacklistBtn.MouseButton1Click:Connect(function()
	BlacklistFrame.Visible = not BlacklistFrame.Visible
	BlacklistFrame.Parent = ScreenGui
	RefreshBlacklist()
end)

-- === WORD BROWSER FRAME ===
local WordBrowserFrame = Instance.new("Frame", ScreenGui)
WordBrowserFrame.Name = "WordBrowser"
WordBrowserFrame.Size = UDim2.new(0, 250, 0, 320)
WordBrowserFrame.Position = UDim2.new(0.5, -125, 0.5, -160)
WordBrowserFrame.BackgroundColor3 = THEME.Background
WordBrowserFrame.Visible = false
WordBrowserFrame.ClipsDescendants = true
EnableDragging(WordBrowserFrame)
Instance.new("UICorner", WordBrowserFrame).CornerRadius = UDim.new(0, 6)
local WBStroke = Instance.new("UIStroke", WordBrowserFrame)
WBStroke.Color = Color3.fromRGB(200, 150, 255)
WBStroke.Transparency = 0.6
WBStroke.Thickness = 1.5

local WBHeader = Instance.new("TextLabel", WordBrowserFrame)
WBHeader.Text = "Word Browser"
WBHeader.Font = Enum.Font.GothamBold
WBHeader.TextSize = 14
WBHeader.TextColor3 = Color3.fromRGB(200, 150, 255)
WBHeader.Size = UDim2.new(1, 0, 0, 25)
WBHeader.BackgroundTransparency = 1

local WBClose = Instance.new("TextButton", WordBrowserFrame)
WBClose.Text = "X"
WBClose.Font = Enum.Font.GothamBold
WBClose.TextSize = 12
WBClose.TextColor3 = THEME.Error
WBClose.Size = UDim2.new(0, 25, 0, 25)
WBClose.Position = UDim2.new(1, -25, 0, 0)
WBClose.BackgroundTransparency = 1
WBClose.MouseButton1Click:Connect(function() WordBrowserFrame.Visible = false end)

local WBStartBox = Instance.new("TextBox", WordBrowserFrame)
WBStartBox.Font = Enum.Font.Gotham
WBStartBox.TextSize = 12
WBStartBox.BackgroundColor3 = THEME.ItemBG
WBStartBox.Size = UDim2.new(0.45, 0, 0, 20)
WBStartBox.Position = UDim2.new(0, 10, 0, 30)
Instance.new("UICorner", WBStartBox).CornerRadius = UDim.new(0, 3)
WBStartBox.PlaceholderText = "Starts..."

local WBEndBox = Instance.new("TextBox", WordBrowserFrame)
WBEndBox.Font = Enum.Font.Gotham
WBEndBox.TextSize = 12
WBEndBox.BackgroundColor3 = THEME.ItemBG
WBEndBox.Size = UDim2.new(0.45, 0, 0, 20)
WBEndBox.Position = UDim2.new(0.5, 0, 0, 30)
Instance.new("UICorner", WBEndBox).CornerRadius = UDim.new(0, 3)
WBEndBox.PlaceholderText = "Ends..."

local WBLengthBox = Instance.new("TextBox", WordBrowserFrame)
WBLengthBox.Font = Enum.Font.Gotham
WBLengthBox.TextSize = 12
WBLengthBox.BackgroundColor3 = THEME.ItemBG
WBLengthBox.Size = UDim2.new(0.2, 0, 0, 20)
WBLengthBox.Position = UDim2.new(0.02, 0, 0, 55)
Instance.new("UICorner", WBLengthBox).CornerRadius = UDim.new(0, 3)
WBLengthBox.PlaceholderText = "Len"

local WBSearchBtn = Instance.new("TextButton", WordBrowserFrame)
WBSearchBtn.Text = "Go"
WBSearchBtn.Font = Enum.Font.GothamBold
WBSearchBtn.TextSize = 12
WBSearchBtn.BackgroundColor3 = THEME.Accent
WBSearchBtn.Size = UDim2.new(0.1, 0, 0, 20)
WBSearchBtn.Position = UDim2.new(0.88, 0, 0, 30)
Instance.new("UICorner", WBSearchBtn).CornerRadius = UDim.new(0, 3)

local WBList = Instance.new("ScrollingFrame", WordBrowserFrame)
WBList.Size = UDim2.new(1, -10, 1, -90)
WBList.Position = UDim2.new(0, 5, 0, 80)
WBList.BackgroundTransparency = 1
WBList.ScrollBarThickness = 2
WBList.ScrollBarImageColor3 = THEME.Accent
WBList.CanvasSize = UDim2.new(0,0,0,0)

local WBLayout = Instance.new("UIListLayout", WBList)
WBLayout.Padding = UDim.new(0, 2)
WBLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function SearchWords()
	for _, c in ipairs(WBList:GetChildren()) do
		if c:IsA("GuiObject") and c.Name ~= "UIListLayout" then c:Destroy() end
	end
	local sVal = WBStartBox.Text
	local eVal = WBEndBox.Text
	local lVal = tonumber(WBLengthBox.Text)
	if sVal == "Starts..." then sVal = "" end
	if eVal == "Ends..." then eVal = "" end
	sVal = sVal:lower():gsub("[%s%c]+", "")
	eVal = eVal:lower():gsub("[%s%c]+", "")
	suffixMode = eVal
	Config.SuffixMode = eVal
	lengthMode = lVal or 0
	Config.LengthMode = lengthMode
	if UpdateList then
		UpdateList(lastDetected, lastRequiredLetter)
	end
	if sVal == "" and eVal == "" and not lVal then return end
	local results = {}
	local limit = 200
	local bucket = Words
	if sVal ~= "" then
		local c = sVal:sub(1,1)
		if Buckets and Buckets[c] then
			bucket = Buckets[c]
		end
	end
	for _, w in ipairs(bucket) do
		local matchStart = (sVal == "") or (w:sub(1, #sVal) == sVal)
		local matchEnd = (eVal == "") or (w:sub(-#eVal) == eVal)
		local matchLen = (not lVal) or (#w == lVal)
		if matchStart and matchEnd and matchLen then
			table.insert(results, w)
			if #results >= limit then break end
		end
	end
	for i, w in ipairs(results) do
		local row = Instance.new("TextButton", WBList)
		row.Size = UDim2.new(1, -6, 0, 20)
		row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(30,30,35) or Color3.fromRGB(35,35,40)
		row.Text = ""
		row.AutoButtonColor = false
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)
		row.MouseButton1Click:Connect(function()
			SmartType(w, lastDetected, true, true)
			Tween(row, {BackgroundColor3 = THEME.Accent}, 0.15)
			task.delay(0.15, function()
				Tween(row, {BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(30,30,35) or Color3.fromRGB(35,35,40)}, 0.15)
			end)
		end)
		local lbl = Instance.new("TextLabel", row)
		lbl.Text = w
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextColor3 = THEME.Text
		lbl.Size = UDim2.new(1, -10, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextXAlignment = Enum.TextXAlignment.Left
	end
	WBList.CanvasSize = UDim2.new(0,0,0, WBLayout.AbsoluteContentSize.Y)
end

WBSearchBtn.MouseButton1Click:Connect(SearchWords)
WordBrowserBtn.MouseButton1Click:Connect(function()
	WordBrowserFrame.Visible = not WordBrowserFrame.Visible
	WordBrowserFrame.Parent = ScreenGui
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
	for i = 1, #row1 do KEY_POS[row1:sub(i,i)] = {x = i, y = 1} end
	for i = 1, #row2 do KEY_POS[row2:sub(i,i)] = {x = i + 0.5, y = 2} end
	for i = 1, #row3 do KEY_POS[row3:sub(i,i)] = {x = i + 1, y = 3} end
end

local function KeyDistance(a, b)
	if not a or not b then return 1 end
	a = a:lower(); b = b:lower()
	local pa = KEY_POS[a]; local pb = KEY_POS[b]
	if not pa or not pb then return 1 end
	local dx = pa.x - pb.x; local dy = pa.y - pb.y
	return math.sqrt(dx*dx + dy*dy)
end

local lastKey = nil

local function CalculateDelayForKeys(prevChar, nextChar)
	if isBlatant then return 60 / currentCPM end
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
	local key = typeof(input) == "EnumItem" and input or nil
	if not key then pcall(function() key = Enum.KeyCode[input:upper()] end) end
	if key then
		local baseHold = math.clamp(12 / currentCPM, 0.015, 0.05)
		local hold = isBlatant and 0.002 or (baseHold + (math.random() * 0.01) - 0.005)
		local vimSuccess = pcall(function()
			VirtualInputManager:SendKeyEvent(true, key, false, game)
			task.wait(hold)
			VirtualInputManager:SendKeyEvent(false, key, false, game)
		end)
		if not vimSuccess then
			pcall(function() VirtualUser:TypeKey(key) end)
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

-- === SMART TYPE ===
local function SmartType(targetWord, currentDetected, isCorrection, bypassTurn)
	if unloaded then return end
	if isTyping then
		if (tick() - lastTypingStart) > 15 then
			isTyping = false
			isAutoPlayScheduled = false
			StatusText.Text = "Timeout reset"
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
						StatusText.Text = "Mismatch!"
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
					StatusText.Text = "Rejected: '" .. targetWord .. "'"
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
					StatusText.Text = "Corrected ✓"
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
						StatusText.Text = "Mismatch!"
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
						StatusText.Text = "Retrying Enter..."
						PressEnter()
						task.wait(0.5)
						if GetCurrentGameWord() == currentDetected then
							StatusText.Text = "Submission failed"
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
					StatusText.Text = "Rejected: '" .. targetWord .. "'"
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
					StatusText.Text = "Verified ✓"
					StatusText.TextColor3 = THEME.SubText
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

-- === MATCH LENGTH ===
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

-- === BINARY SEARCH ===
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

-- === UPDATE LIST ===
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
		local partials = {}
		local maxPartialLen = 0
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
					for i = startIndex, #bucket do
						local w = bucket[i]
						if w:sub(1, #prefix) ~= prefix then break end
						checkWord(w)
					end
				end
			else
				for _, w in ipairs(bucket) do
					checkWord(w)
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
		local fallbackExacts, _, _ = CollectMatches(searchPrefix, true)
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

	if #matches > 0 and not isBacktracked then
		currentBestMatch = matches[1]
	else
		currentBestMatch = nil
	end

	if isBacktracked then
		local validPart = searchPrefix
		local invalidPart = detectedText:sub(#searchPrefix + 1)
		StatusText.Text = "No match: " .. validPart .. "<font color=\"rgb(255,80,80)\">" .. invalidPart .. "</font>"
		StatusText.TextColor3 = THEME.SubText
	elseif #exacts == 0 and lengthMode > 0 and suffixMode ~= "" then
		StatusText.Text = "No len match"
		StatusText.TextColor3 = THEME.Warning
	end

	for i = 1, math.max(#displayList, #ButtonCache) do
		local w = displayList[i]
		local btn = ButtonCache[i]
		if w then
			local lbl
			if not btn then
				btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, -6, 0, 25)
				btn.BackgroundColor3 = THEME.ItemBG
				btn.Text = ""
				btn.AutoButtonColor = false
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				lbl = Instance.new("TextLabel", btn)
				lbl.Name = "Label"
				lbl.Size = UDim2.new(1, -15, 1, 0)
				lbl.Position = UDim2.new(0, 8, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
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
			local accentRGB = "100,180,255"
			if i == 1 then accentRGB = "100,255,140"
			elseif i == 2 then accentRGB = "255,180,200"
			elseif i == 3 then accentRGB = "100,200,255"
			end
			local textRGB = "230,230,240"
			local displayText = ""
			if isBacktracked then
				local prefix = w:sub(1, #searchPrefix)
				local suffix = w:sub(#searchPrefix + 1)
				displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font><font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
			else
				local prefix = w:sub(1, #detectedText)
				local suffix = w:sub(#detectedText + 1)
				displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. prefix .. "</font><font color=\"rgb(" .. textRGB .. ")\">" .. suffix .. "</font>"
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

-- === MINIMIZE BUTTON ===
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = THEME.SubText
MinBtn.Size = UDim2.new(0, 25, 1, 0)
MinBtn.Position = UDim2.new(1, -55, 0, 0)
MinBtn.BackgroundTransparency = 1
MinBtn.MouseButton1Click:Connect(function()
	local isMin = MainFrame.Size.Y.Offset < 100
	if not isMin then
		Tween(MainFrame, {Size = UDim2.new(0, 260, 0, 30)}, 0.2)
		ScrollList.Visible = false
		SettingsFrame.Visible = false
		StatusFrame.Visible = false
		SearchFrame.Visible = false
		MinBtn.Text = "+"
	else
		Tween(MainFrame, {Size = UDim2.new(0, 260, 0, 420)}, 0.2)
		task.wait(0.2)
		ScrollList.Visible = true
		SettingsFrame.Visible = true
		StatusFrame.Visible = true
		SearchFrame.Visible = true
		MinBtn.Text = "-"
	end
end)

-- === STATS FRAME ===
local StatsFrame = Instance.new("Frame", ScreenGui)
StatsFrame.Name = "StatsFrame"
StatsFrame.Size = UDim2.new(0, 100, 0, 50)
StatsFrame.Position = UDim2.new(0.5, -50, 0, 10)
StatsFrame.BackgroundColor3 = THEME.Background
StatsFrame.Visible = false
StatsFrame.Parent = ScreenGui
EnableDragging(StatsFrame)
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", StatsFrame).Color = THEME.Accent

local TimerLabel = Instance.new("TextLabel", StatsFrame)
TimerLabel.Size = UDim2.new(1, 0, 0, 25)
TimerLabel.Position = UDim2.new(0, 0, 0, 5)
TimerLabel.BackgroundTransparency = 1
TimerLabel.TextColor3 = THEME.Text
TimerLabel.Font = Enum.Font.GothamBold
TimerLabel.TextSize = 18
TimerLabel.Text = "--"

local CountLabel = Instance.new("TextLabel", StatsFrame)
CountLabel.Size = UDim2.new(1, 0, 0, 20)
CountLabel.Position = UDim2.new(0, 0, 0, 30)
CountLabel.BackgroundTransparency = 1
CountLabel.TextColor3 = THEME.SubText
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextSize = 11
CountLabel.Text = "Words: 0"

-- === RUN LOOP ===
runConn = RunService.RenderStepped:Connect(function()
	local success, err = pcall(function()
		local now = tick()
		local player = Players.LocalPlayer
		local gui = player and player:FindFirstChild("PlayerGui")
		local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")

		if isTyping and (tick() - lastTypingStart) > 15 then
			isTyping = false
			isAutoPlayScheduled = false
			StatusText.Text = "Watchdog reset"
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
				StatsFrame.Visible = true
				TimerLabel.Text = timeText
				if seconds and seconds < 3 then
					TimerLabel.TextColor3 = THEME.Error
				else
					TimerLabel.TextColor3 = THEME.Text
				end
				if seconds and seconds < 5 then
					if not isBlatant then
						isBlatant = true
						Config.Blatant = true
						BlatantBtn.Text = "✓ Blatant"
						BlatantBtn.TextColor3 = THEME.Error
					end
				else
					if isBlatant then
						isBlatant = false
						Config.Blatant = false
						BlatantBtn.Text = "✗ Blatant"
						BlatantBtn.TextColor3 = THEME.SubText
					end
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

		-- PANIC SAVE
		if isVisible and isMyTurn and not isTyping and seconds and seconds < 1.5 then
			local char = (requiredLetter or ""):lower()
			local bucket = Buckets[char]
			if bucket then
				local bestWord = nil
				local bestLen = 999
				for _, w in ipairs(bucket) do
					if not Blacklist[w] and not UsedWords[w] and w:sub(1, #detected) == detected then
						if #w < bestLen then
							bestWord = w
							bestLen = #w
						end
					end
				end
				if bestWord then
					StatusText.Text = "PANIC!"
					StatusText.TextColor3 = THEME.Error
					SmartType(bestWord, detected, false)
				end
			end
		end

		-- AUTO JOIN
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
										local centerX = absPos.X + absSize.X/2
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

		local typeLbl = frame and frame:FindFirstChild("Type")
		local typeVisible = typeLbl and typeLbl.Visible
		if typeVisible and not lastTypeVisible then
			-- CLEAR USED WORDS + NOTIFIKASI
			task.delay(1, function()
				UsedWords = {}
				ShowToast("Cache cleared! Ready for new round.", "success")
			end)
		end
		lastTypeVisible = typeVisible

		-- Deteksi lawan
		local opponentWord = DetectOpponentUsedWord(frame)
		if opponentWord and opponentWord ~= "" and not opponentWord:find("#") then
			UsedWords[opponentWord] = true
		end

		if censored then
			if StatusText.Text ~= "Censored!" then
				StatusText.Text = "Censored!"
				StatusText.TextColor3 = THEME.Warning
				Tween(StatusDot, {BackgroundColor3 = THEME.Warning})
				for _, btn in ipairs(ButtonCache) do btn.Visible = false end
				CountLabel.Text = "Words: 0"
			end
			listUpdatePending = false
			forceUpdateList = false
			currentBestMatch = nil
			lastDetected = detected
			lastRequiredLetter = requiredLetter
		end

		if listUpdatePending and (now - lastInputTime > LIST_DEBOUNCE) then
			listUpdatePending = false
			UpdateList(lastDetected, lastRequiredLetter)
			local visCount = 0
			for _, b in ipairs(ButtonCache) do
				if b.Visible then visCount = visCount + 1 end
			end
			CountLabel.Text = "Words: " .. visCount
		end

		if not isVisible then
			if StatusText.Text ~= "Not in round" then
				StatusText.Text = "Not in round"
				StatusText.TextColor3 = THEME.SubText
				Tween(StatusDot, {BackgroundColor3 = THEME.SubText})
				for _, btn in ipairs(ButtonCache) do btn.Visible = false end
				CountLabel.Text = "Words: 0"
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
				UpdateList("", requiredLetter)
				listUpdatePending = false
				local visCount = 0
				for _, b in ipairs(ButtonCache) do
					if b.Visible then visCount = visCount + 1 end
				end
				CountLabel.Text = "Words: " .. visCount
			else
				if detected ~= "" then
					local isCompleted = false
					if #detected > 2 then
						local c = detected:sub(1,1)
						if c ~= "#" and Buckets and Buckets[c] then
							for _, w in ipairs(Buckets[c]) do
								if w == detected then
									isCompleted = true
									break
								end
							end
						end
					end
					if isCompleted then
						StatusText.Text = "Completed ✓"
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
					local delay = isBlatant and 0.15 or (0.8 + math.random() * 0.5)
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

-- === INPUT BINDING ===
inputConn = UserInputService.InputBegan:Connect(function(input)
	if unloaded then return end
	if input.KeyCode == TOGGLE_KEY then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)
