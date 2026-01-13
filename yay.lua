-- [Word Helper - Last Letter AJG V4 - LIGHT + FULL FEATURES]
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LogService = game:GetService("LogService")
local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local TOGGLE_KEY = Enum.KeyCode.RightControl
local MIN_CPM = 50
local MAX_CPM_LEGIT = 10000
local MAX_CPM_BLATANT = 10000

math.randomseed(os.time())

-- THEME
local THEME = {
	Background = Color3.fromRGB(20, 20, 24),
	ItemBG = Color3.fromRGB(30, 30, 36),
	Accent = Color3.fromRGB(114, 100, 255),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(150, 150, 160),
	Success = Color3.fromRGB(100, 255, 140),
	Warning = Color3.fromRGB(255, 200, 80),
	Error = Color3.fromRGB(255, 80, 80),
	Slider = Color3.fromRGB(50, 50, 60)
}

-- CONFIG
local ConfigFile = "WordHelper_Config.json"
local BlacklistFile = "blacklist.txt"

local Config = {
	CPM = 550,
	Blatant = false,
	Humanize = true,
	FingerModel = true,
	SortMode = "Random",
	RandomizeTop = false,
	SuffixMode = "",
	LengthMode = 0,
	AutoPlay = false,
	AutoJoin = false,
	PanicMode = true,
	ShowKeyboard = false,
	ErrorRate = 5,
	ThinkDelay = 0.8,
	RiskyMistakes = false,
	CustomWords = {},
	MinTypeSpeed = 50,
	MaxTypeSpeed = 10000,
	KeyboardLayout = "QWERTY"
}

-- KILLER SUFFIXES
local KillerSuffixes = {
	"x", "xi", "ze", "xo", "xu", "xx", "xr", "xs", "xey", "xa", "xd", "xp", "xl",
	"fu", "fet", "fur", "ke", "ps", "ss", "ths", "fs", "fsi",
	"nge", "dge", "rge", "yx", "nx", "rx", "kut", "xes", "xed", "tum", "pr", "qw", "ty", "per", "xt", "bv", "ax", "ops", "op",
	"que", "ique", "esque", "tz", "zy", "zz", "ing", "ex", "xe", "nks", "nk",
	"gaa", "gin", "dee", "ap", "tet", "pth", "mn", "bt", "ght", "lfth", "mpth",
	"nth", "rgue", "mb", "sc", "cq", "dg", "pt", "ct", "x", "rk", "lf", "rf", "mz", "zm",
	"oo", "aa", "edo", "ae", "aed", "ger", "moom"
}

-- UTILS
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

-- BLACKLIST
local Blacklist = {}
local function LoadBlacklist()
	if isfile and isfile(BlacklistFile) then
		local content = readfile(BlacklistFile)
		for w in content:gmatch("[^\r\n]+") do
			local clean = w:gsub("[%s%c]+", ""):lower()
			if #clean > 0 then
				Blacklist[clean] = true
			end
		end
	end
end

local function AddToBlacklist(word)
	if not word or word == "" then return end
	word = word:lower()
	if not Blacklist[word] then
		Blacklist[word] = true
		if appendfile and isfile(BlacklistFile) then
			appendfile(BlacklistFile, "\n" .. word)
		elseif writefile then
			local content = isfile(BlacklistFile) and readfile(BlacklistFile) or ""
			writefile(BlacklistFile, content .. "\n" .. word)
		end
	end
end

LoadBlacklist()

-- STATE
local currentCPM = Config.CPM
local isBlatant = Config.Blatant
local useHumanization = Config.Humanize
local useFingerModel = Config.FingerModel
local sortMode = Config.SortMode or "Random"
local randomizeTop = Config.RandomizeTop or false
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
local UsedWords = {}
local lastDetected = "---"
local lastLogicUpdate = 0
local lastAutoJoinCheck = 0
local lastWordCheck = 0
local cachedDetected = ""
local cachedCensored = false
local LOGIC_RATE = 0.1
local AUTO_JOIN_RATE = 0.5
local listUpdatePending = false
local forceUpdateList = false
local lastInputTime = 0
local LIST_DEBOUNCE = 0.05
local currentBestMatch = nil
local lastTypeVisible = false

-- LOG DETECTION
if logConn then logConn:Disconnect() end
logConn = LogService.MessageOut:Connect(function(message, _)
	local wordPart, timePart = message:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
	if wordPart and timePart then
		isMyTurnLogDetected = true
		logRequiredLetters = wordPart
		turnExpiryTime = tick() + tonumber(timePart)
	end
end)

-- FETCH WORDS
local url = "https://raw.githubusercontent.com/rinjani999/yuyu99/refs/heads/main/tralala.txt"
local fileName = "ultimate_words_v4.txt"

local function FetchWords()
	local success, res = pcall(function()
		return request({Url = url, Method = "GET"})
	end)
	if success and res and res.Body then
		writefile(fileName, res.Body)
	else
		warn("Fetch failed! Using cached.")
	end
end

FetchWords()

-- LOAD WORDS
local Words = {}
local SeenWords = {}
local function LoadList(fname)
	if isfile(fname) then
		local content = readfile(fname)
		for w in content:gmatch("[^\r\n]+") do
			local clean = w:gsub("[%s%c]+", ""):lower()
			if #clean > 0 and not SeenWords[clean] then
				SeenWords[clean] = true
				table.insert(Words, clean)
			end
		end
	end
	table.sort(Words)
end

LoadList(fileName)

-- BUCKETS
Buckets = {}
for _, w in ipairs(Words) do
	local c = w:sub(1,1) or "#"
	Buckets[c] = Buckets[c] or {}
	table.insert(Buckets[c], w)
end

-- CUSTOM WORDS
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

-- SHUFFLE
local function shuffleTable(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- KILLER CHECK
local function EndsWithKillerSuffix(word)
	for _, suffix in ipairs(KillerSuffixes) do
		if word:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

-- TWEEN HELPER
local function Tween(obj, props, time)
	TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- GAME WORD DETECTION
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

-- TURN DETECTION
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
	if typeLbl and typeLbl:IsA("TextLabel") and typeLbl.Visible then
		local text = typeLbl.Text
		local player = Players.LocalPlayer
		if text:sub(1, #player.Name) == player.Name or text:sub(1, #player.DisplayName) == player.DisplayName then
			local char = text:match("starting with:%s*([A-Za-z])")
			return true, char
		end
	end
	return false, nil
end

-- UI SETUP
local ParentTarget = (gethui and gethui()) or CoreGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LastLetterAJG_V4"
ScreenGui.Parent = ParentTarget
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- TOAST
local ToastContainer = Instance.new("Frame", ScreenGui)
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 300, 1, 0)
ToastContainer.Position = UDim2.new(1, -320, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 100

local function ShowToast(message, color)
	color = color or THEME.Success
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 40)
	toast.BackgroundColor3 = THEME.ItemBG
	toast.BorderSizePixel = 0
	toast.BackgroundTransparency = 0.8
	toast.Parent = ToastContainer
	local stroke = Instance.new("UIStroke", toast)
	stroke.Thickness = 1.5
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
	lbl.TextTransparency = 0
	task.delay(3, function()
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

-- MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 460)
MainFrame.Position = UDim2.new(0.8, -50, 0.4, 0)
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
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

EnableDragging(MainFrame)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = THEME.Accent
Stroke.Transparency = 0.5
Stroke.Thickness = 1.5

-- HEADER
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = THEME.ItemBG
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Text = "Last Letter <font color=\"rgb(114,100,255)\">AJG</font>"
Title.RichText = true
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = THEME.Text
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = THEME.Error
CloseBtn.Size = UDim2.new(0, 35, 1, 0)
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.MouseButton1Click:Connect(function()
	unloaded = true
	if runConn then runConn:Disconnect() end
	if inputConn then inputConn:Disconnect() end
	if logConn then logConn:Disconnect() end
	ScreenGui:Destroy()
end)

-- STATUS
local StatusFrame = Instance.new("Frame", MainFrame)
StatusFrame.Size = UDim2.new(1, -20, 0, 20)
StatusFrame.Position = UDim2.new(0, 10, 0, 40)
StatusFrame.BackgroundTransparency = 1

local StatusText = Instance.new("TextLabel", StatusFrame)
StatusText.Text = "Idle..."
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 12
StatusText.TextColor3 = THEME.SubText
StatusText.Size = UDim2.new(1, 0, 1, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextXAlignment = Enum.TextXAlignment.Left

-- SEARCH
local SearchBox = Instance.new("TextBox", MainFrame)
SearchBox.Size = UDim2.new(1, -20, 0, 24)
SearchBox.Position = UDim2.new(0, 10, 0, 65)
SearchBox.BackgroundColor3 = THEME.ItemBG
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 14
SearchBox.TextColor3 = THEME.Text
SearchBox.PlaceholderText = "Search words..."
SearchBox.PlaceholderColor3 = THEME.SubText
SearchBox.ClearTextOnFocus = false

-- SCROLL LIST
local ScrollList = Instance.new("ScrollingFrame", MainFrame)
ScrollList.Size = UDim2.new(1, -20, 0, 180)
ScrollList.Position = UDim2.new(0, 10, 0, 95)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.ScrollBarImageColor3 = THEME.Accent
ScrollList.CanvasSize = UDim2.new(0,0,0,0)

local UIListLayout = Instance.new("UIListLayout", ScrollList)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 3)

-- BUTTON CACHE
local ButtonCache = {}
local ButtonData = {}

-- SORT MODE DROPDOWN
local SortModeDropdown = Instance.new("TextButton", MainFrame)
SortModeDropdown.Size = UDim2.new(1, -20, 0, 24)
SortModeDropdown.Position = UDim2.new(0, 10, 0, 280)
SortModeDropdown.BackgroundColor3 = THEME.ItemBG
SortModeDropdown.Font = Enum.Font.Gotham
SortModeDropdown.TextSize = 13
SortModeDropdown.TextColor3 = THEME.Text
SortModeDropdown.Text = "Sort: " .. sortMode
SortModeDropdown.AutoButtonColor = false

local SortOptions = {"Random", "Longest", "Shortest", "Killer"}
SortModeDropdown.MouseButton1Click:Connect(function()
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(1, 0, 0, #SortOptions * 24)
	menu.Position = UDim2.new(0, 0, 1, 0)
	menu.BackgroundColor3 = THEME.ItemBG
	menu.BorderSizePixel = 0
	menu.Parent = SortModeDropdown
	Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 4)
	for i, opt in ipairs(SortOptions) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 24)
		btn.Position = UDim2.new(0, 0, 0, (i-1)*24)
		btn.Text = opt
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
		btn.TextColor3 = THEME.Text
		btn.BackgroundColor3 = (opt == sortMode) and THEME.Accent or THEME.ItemBG
		btn.AutoButtonColor = false
		btn.MouseButton1Click:Connect(function()
			sortMode = opt
			Config.SortMode = sortMode
			SortModeDropdown.Text = "Sort: " .. sortMode
			SaveConfig()
			UpdateList(lastDetected, lastRequiredLetter)
			menu:Destroy()
		end)
		btn.Parent = menu
	end
	task.delay(3, function()
		if menu and menu.Parent then menu:Destroy() end
	end)
end)

-- SETTINGS COLLAPSE
local SettingsFrame = Instance.new("Frame", MainFrame)
SettingsFrame.Size = UDim2.new(1, 0, 0, 140)
SettingsFrame.Position = UDim2.new(0, 0, 1, -140)
SettingsFrame.BackgroundColor3 = THEME.ItemBG
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ClipsDescendants = true

local settingsCollapsed = true
local function UpdateLayout()
	if settingsCollapsed then
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 140), Position = UDim2.new(0, 0, 1, -140)}, 0.2)
		Tween(ScrollList, {Size = UDim2.new(1, -20, 0, 180)}, 0.2)
	else
		Tween(SettingsFrame, {Size = UDim2.new(1, 0, 0, 240), Position = UDim2.new(0, 0, 1, -240)}, 0.2)
		Tween(ScrollList, {Size = UDim2.new(1, -20, 0, 80)}, 0.2)
	end
end

local ExpandBtn = Instance.new("TextButton", SettingsFrame)
ExpandBtn.Text = "v Settings"
ExpandBtn.Font = Enum.Font.GothamBold
ExpandBtn.TextSize = 12
ExpandBtn.TextColor3 = THEME.Accent
ExpandBtn.BackgroundTransparency = 1
ExpandBtn.Size = UDim2.new(1, 0, 0, 20)
ExpandBtn.Position = UDim2.new(0, 0, 1, -20)
ExpandBtn.MouseButton1Click:Connect(function()
	settingsCollapsed = not settingsCollapsed
	ExpandBtn.Text = settingsCollapsed and "v Settings" or "^ Hide"
	UpdateLayout()
end)

-- SLIDERS
local SliderLabel = Instance.new("TextLabel", SettingsFrame)
SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.TextSize = 12
SliderLabel.TextColor3 = THEME.SubText
SliderLabel.Size = UDim2.new(1, -20, 0, 16)
SliderLabel.Position = UDim2.new(0, 10, 0, 5)
SliderLabel.BackgroundTransparency = 1

local SliderBg = Instance.new("Frame", SettingsFrame)
SliderBg.Size = UDim2.new(1, -20, 0, 4)
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

-- THINK DELAY SLIDER (0.1 - 2.0)
local thinkDelayMin = 0.1
local thinkDelayMax = 2.0

local ThinkLabel = Instance.new("TextLabel", SettingsFrame)
ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
ThinkLabel.Font = Enum.Font.Gotham
ThinkLabel.TextSize = 12
ThinkLabel.TextColor3 = THEME.SubText
ThinkLabel.Size = UDim2.new(1, -20, 0, 16)
ThinkLabel.Position = UDim2.new(0, 10, 0, 30)
ThinkLabel.BackgroundTransparency = 1

local ThinkBg = Instance.new("Frame", SettingsFrame)
ThinkBg.Size = UDim2.new(1, -20, 0, 4)
ThinkBg.Position = UDim2.new(0, 10, 0, 47)
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

-- SLIDER LOGIC
local function SetupSlider(btn, bg, fill, callback)
	btn.MouseButton1Down:Connect(function()
		local moveConn, releaseConn
		local update = function()
			local mousePos = UserInputService:GetMouseLocation()
			local relX = math.clamp(mousePos.X - bg.AbsolutePosition.X, 0, bg.AbsoluteSize.X)
			local pct = relX / bg.AbsoluteSize.X
			callback(pct)
		end
		update()
		moveConn = RunService.RenderStepped:Connect(update)
		releaseConn = UserInputService.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				if moveConn then moveConn:Disconnect() end
				if releaseConn then releaseConn:Disconnect() end
				SaveConfig()
			end
		end)
	end)
end

SetupSlider(SliderBtn, SliderBg, SliderFill, function(pct)
	local max = isBlatant and MAX_CPM_BLATANT or MAX_CPM_LEGIT
	currentCPM = math.floor(MIN_CPM + (pct * (max - MIN_CPM)))
	Config.CPM = currentCPM
	SliderFill.Size = UDim2.new(pct, 0, 1, 0)
	SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
end)

SetupSlider(ThinkBtn, ThinkBg, ThinkFill, function(pct)
	thinkDelayCurrent = thinkDelayMin + pct * (thinkDelayMax - thinkDelayMin)
	Config.ThinkDelay = thinkDelayCurrent
	ThinkFill.Size = UDim2.new(pct, 0, 1, 0)
	ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
end)

-- TOGGLES
local TogglesFrame = Instance.new("Frame", SettingsFrame)
TogglesFrame.Size = UDim2.new(1, 0, 0, 100)
TogglesFrame.Position = UDim2.new(0, 0, 0, 55)
TogglesFrame.BackgroundTransparency = 1
TogglesFrame.Visible = false

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

local HumanizeBtn = CreateToggle("Humanize: ON", UDim2.new(0, 5, 0, 0), function()
	useHumanization = not useHumanization
	Config.Humanize = useHumanization
	return useHumanization, "Humanize: "..(useHumanization and "ON" or "OFF"), useHumanization and THEME.Success or THEME.SubText
end)

local AutoBtn = CreateToggle("Auto Play: OFF", UDim2.new(0, 90, 0, 0), function()
	autoPlay = not autoPlay
	Config.AutoPlay = autoPlay
	return autoPlay, "Auto Play: "..(autoPlay and "ON" or "OFF"), autoPlay and THEME.Success or THEME.SubText
end)

local BlatantBtn = CreateToggle("Blatant: OFF", UDim2.new(0, 175, 0, 0), function()
	isBlatant = not isBlatant
	Config.Blatant = isBlatant
	return isBlatant, "Blatant: "..(isBlatant and "ON" or "OFF"), isBlatant and THEME.Error or THEME.SubText
end)

local RandomizeTopBtn = CreateToggle("Rand Top: OFF", UDim2.new(0, 5, 0, 25), function()
	randomizeTop = not randomizeTop
	Config.RandomizeTop = randomizeTop
	return randomizeTop, "Rand Top: "..(randomizeTop and "ON" or "OFF"), randomizeTop and THEME.Success or THEME.SubText
end)

-- EXTRA BUTTONS
local ExtraBtnFrame = Instance.new("Frame", MainFrame)
ExtraBtnFrame.Size = UDim2.new(1, 0, 0, 30)
ExtraBtnFrame.Position = UDim2.new(0, 0, 1, -30)
ExtraBtnFrame.BackgroundTransparency = 1

local UsedWordsBtn = Instance.new("TextButton", ExtraBtnFrame)
UsedWordsBtn.Text = "Used Words"
UsedWordsBtn.Font = Enum.Font.GothamBold
UsedWordsBtn.TextSize = 12
UsedWordsBtn.TextColor3 = THEME.Accent
UsedWordsBtn.BackgroundColor3 = THEME.ItemBG
UsedWordsBtn.Size = UDim2.new(0, 90, 1, 0)
UsedWordsBtn.Position = UDim2.new(0, 5, 0, 0)
Instance.new("UICorner", UsedWordsBtn).CornerRadius = UDim.new(0, 4)

local BlacklistBtn = Instance.new("TextButton", ExtraBtnFrame)
BlacklistBtn.Text = "Blacklist"
BlacklistBtn.Font = Enum.Font.GothamBold
BlacklistBtn.TextSize = 12
BlacklistBtn.TextColor3 = THEME.Warning
BlacklistBtn.BackgroundColor3 = THEME.ItemBG
BlacklistBtn.Size = UDim2.new(0, 90, 1, 0)
BlacklistBtn.Position = UDim2.new(0, 95, 0, 0)
Instance.new("UICorner", BlacklistBtn).CornerRadius = UDim.new(0, 4)

local WordBrowserBtn = Instance.new("TextButton", ExtraBtnFrame)
WordBrowserBtn.Text = "Word Browser"
WordBrowserBtn.Font = Enum.Font.GothamBold
WordBrowserBtn.TextSize = 12
WordBrowserBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
WordBrowserBtn.BackgroundColor3 = THEME.ItemBG
WordBrowserBtn.Size = UDim2.new(0, 90, 1, 0)
WordBrowserBtn.Position = UDim2.new(0, 185, 0, 0)
Instance.new("UICorner", WordBrowserBtn).CornerRadius = UDim.new(0, 4)

-- CLEAR USEDWORDS FUNCTION
local function ClearUsedWords()
	UsedWords = {}
	ShowToast("Cache Cleared!", THEME.Success)
end

-- USED WORDS WINDOW
local UsedWordsFrame = Instance.new("Frame", ScreenGui)
UsedWordsFrame.Name = "UsedWordsFrame"
UsedWordsFrame.Size = UDim2.new(0, 250, 0, 300)
UsedWordsFrame.Position = UDim2.new(0.5, -125, 0.5, -150)
UsedWordsFrame.BackgroundColor3 = THEME.Background
UsedWordsFrame.Visible = false
UsedWordsFrame.ClipsDescendants = true
EnableDragging(UsedWordsFrame)
Instance.new("UICorner", UsedWordsFrame).CornerRadius = UDim.new(0, 6)
local UWStroke = Instance.new("UIStroke", UsedWordsFrame)
UWStroke.Color = THEME.Accent
UWStroke.Transparency = 0.5
UWStroke.Thickness = 1.5

local UWHeader = Instance.new("TextLabel", UsedWordsFrame)
UWHeader.Text = "Used Words"
UWHeader.Font = Enum.Font.GothamBold
UWHeader.TextSize = 14
UWHeader.TextColor3 = THEME.Text
UWHeader.Size = UDim2.new(1, 0, 0, 30)
UWHeader.BackgroundTransparency = 1

local UWClose = Instance.new("TextButton", UsedWordsFrame)
UWClose.Text = "X"
UWClose.Font = Enum.Font.GothamBold
UWClose.TextSize = 14
UWClose.TextColor3 = THEME.Error
UWClose.Size = UDim2.new(0, 30, 0, 30)
UWClose.Position = UDim2.new(1, -30, 0, 0)
UWClose.BackgroundTransparency = 1
UWClose.MouseButton1Click:Connect(function() UsedWordsFrame.Visible = false end)

local UWClearBtn = Instance.new("TextButton", UsedWordsFrame)
UWClearBtn.Text = "Clear All"
UWClearBtn.Font = Enum.Font.GothamBold
UWClearBtn.TextSize = 12
UWClearBtn.TextColor3 = THEME.Warning
UWClearBtn.BackgroundColor3 = THEME.ItemBG
UWClearBtn.Size = UDim2.new(0, 80, 0, 24)
UWClearBtn.Position = UDim2.new(0, 10, 0, 32)
Instance.new("UICorner", UWClearBtn).CornerRadius = UDim.new(0, 4)
UWClearBtn.MouseButton1Click:Connect(ClearUsedWords)

local UWScroll = Instance.new("ScrollingFrame", UsedWordsFrame)
UWScroll.Size = UDim2.new(1, -10, 1, -70)
UWScroll.Position = UDim2.new(0, 5, 0, 60)
UWScroll.BackgroundTransparency = 1
UWScroll.ScrollBarThickness = 2
UWScroll.ScrollBarImageColor3 = THEME.Accent
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
		row.Size = UDim2.new(1, -6, 0, 22)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
		row.BorderSizePixel = 0
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
		del.TextSize = 11
		del.TextColor3 = THEME.Error
		del.Size = UDim2.new(0, 22, 1, 0)
		del.Position = UDim2.new(1, -22, 0, 0)
		del.BackgroundTransparency = 1
		del.MouseButton1Click:Connect(function()
			UsedWords[word] = nil
			RefreshUsedWords()
		end)
	end
	UWScroll.CanvasSize = UDim2.new(0,0,0, count * 24)
end

UsedWordsBtn.MouseButton1Click:Connect(function()
	UsedWordsFrame.Visible = not UsedWordsFrame.Visible
	if UsedWordsFrame.Visible then RefreshUsedWords() end
end)

-- BLACKLIST WINDOW
local BlacklistFrame = Instance.new("Frame", ScreenGui)
BlacklistFrame.Name = "BlacklistFrame"
BlacklistFrame.Size = UDim2.new(0, 250, 0, 300)
BlacklistFrame.Position = UDim2.new(0.5, -125, 0.5, -150)
BlacklistFrame.BackgroundColor3 = THEME.Background
BlacklistFrame.Visible = false
BlacklistFrame.ClipsDescendants = true
EnableDragging(BlacklistFrame)
Instance.new("UICorner", BlacklistFrame).CornerRadius = UDim.new(0, 6)
local BLStroke = Instance.new("UIStroke", BlacklistFrame)
BLStroke.Color = THEME.Warning
BLStroke.Transparency = 0.5
BLStroke.Thickness = 1.5

local BLHeader = Instance.new("TextLabel", BlacklistFrame)
BLHeader.Text = "Blacklist Words"
BLHeader.Font = Enum.Font.GothamBold
BLHeader.TextSize = 14
BLHeader.TextColor3 = THEME.Text
BLHeader.Size = UDim2.new(1, 0, 0, 30)
BLHeader.BackgroundTransparency = 1

local BLClose = Instance.new("TextButton", BlacklistFrame)
BLClose.Text = "X"
BLClose.Font = Enum.Font.GothamBold
BLClose.TextSize = 14
BLClose.TextColor3 = THEME.Error
BLClose.Size = UDim2.new(0, 30, 0, 30)
BLClose.Position = UDim2.new(1, -30, 0, 0)
BLClose.BackgroundTransparency = 1
BLClose.MouseButton1Click:Connect(function() BlacklistFrame.Visible = false end)

local BLScroll = Instance.new("ScrollingFrame", BlacklistFrame)
BLScroll.Size = UDim2.new(1, -10, 1, -40)
BLScroll.Position = UDim2.new(0, 5, 0, 35)
BLScroll.BackgroundTransparency = 1
BLScroll.ScrollBarThickness = 2
BLScroll.ScrollBarImageColor3 = THEME.Warning
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
		row.Size = UDim2.new(1, -6, 0, 22)
		row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
		row.BorderSizePixel = 0
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
		del.TextSize = 11
		del.TextColor3 = THEME.Error
		del.Size = UDim2.new(0, 22, 1, 0)
		del.Position = UDim2.new(1, -22, 0, 0)
		del.BackgroundTransparency = 1
		del.MouseButton1Click:Connect(function()
			Blacklist[word] = nil
			local lines = {}
			if isfile(BlacklistFile) then
				for w in readfile(BlacklistFile):gmatch("[^\r\n]+") do
					if w:lower() ~= word then table.insert(lines, w) end
				end
			end
			writefile(BlacklistFile, table.concat(lines, "\n"))
			RefreshBlacklist()
		end)
	end
	BLScroll.CanvasSize = UDim2.new(0,0,0, count * 24)
end

BlacklistBtn.MouseButton1Click:Connect(function()
	BlacklistFrame.Visible = not BlacklistFrame.Visible
	if BlacklistFrame.Visible then RefreshBlacklist() end
end)

-- WORD BROWSER
do
	local WordBrowserFrame = Instance.new("Frame", ScreenGui)
	WordBrowserFrame.Name = "WordBrowser"
	WordBrowserFrame.Size = UDim2.new(0, 280, 0, 300)
	WordBrowserFrame.Position = UDim2.new(0.5, -140, 0.5, -150)
	WordBrowserFrame.BackgroundColor3 = THEME.Background
	WordBrowserFrame.Visible = false
	WordBrowserFrame.ClipsDescendants = true
	EnableDragging(WordBrowserFrame)
	Instance.new("UICorner", WordBrowserFrame).CornerRadius = UDim.new(0, 6)
	local WBStroke = Instance.new("UIStroke", WordBrowserFrame)
	WBStroke.Color = Color3.fromRGB(200, 150, 255)
	WBStroke.Transparency = 0.5
	WBStroke.Thickness = 1.5

	local WBHeader = Instance.new("TextLabel", WordBrowserFrame)
	WBHeader.Text = "Word Browser"
	WBHeader.Font = Enum.Font.GothamBold
	WBHeader.TextSize = 14
	WBHeader.TextColor3 = THEME.Text
	WBHeader.Size = UDim2.new(1, 0, 0, 30)
	WBHeader.BackgroundTransparency = 1

	local WBClose = Instance.new("TextButton", WordBrowserFrame)
	WBClose.Text = "X"
	WBClose.Font = Enum.Font.GothamBold
	WBClose.TextSize = 14
	WBClose.TextColor3 = THEME.Error
	WBClose.Size = UDim2.new(0, 30, 0, 30)
	WBClose.Position = UDim2.new(1, -30, 0, 0)
	WBClose.BackgroundTransparency = 1
	WBClose.MouseButton1Click:Connect(function() WordBrowserFrame.Visible = false end)

	local WBList = Instance.new("ScrollingFrame", WordBrowserFrame)
	WBList.Size = UDim2.new(1, -10, 1, -40)
	WBList.Position = UDim2.new(0, 5, 0, 35)
	WBList.BackgroundTransparency = 1
	WBList.ScrollBarThickness = 2
	WBList.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 255)
	WBList.CanvasSize = UDim2.new(0,0,0,0)

	local WBLayout = Instance.new("UIListLayout", WBList)
	WBLayout.SortOrder = Enum.SortOrder.LayoutOrder
	WBLayout.Padding = UDim.new(0, 2)

	local function ShowAllWords()
		for _, c in ipairs(WBList:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local count = 0
		for _, w in ipairs(Words) do
			count = count + 1
			if count > 200 then break end
			local row = Instance.new("TextButton", WBList)
			row.Size = UDim2.new(1, -6, 0, 22)
			row.BackgroundColor3 = (count % 2 == 0) and Color3.fromRGB(25,25,30) or Color3.fromRGB(30,30,35)
			row.Text = ""
			row.AutoButtonColor = false
			local lbl = Instance.new("TextLabel", row)
			lbl.Text = w
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 12
			lbl.TextColor3 = THEME.Text
			lbl.Size = UDim2.new(1, -10, 1, 0)
			lbl.Position = UDim2.new(0, 5, 0, 0)
			lbl.BackgroundTransparency = 1
		end
		WBList.CanvasSize = UDim2.new(0,0,0, count * 24)
	end

	ShowAllWords()
	WordBrowserBtn.MouseButton1Click:Connect(function()
		WordBrowserFrame.Visible = not WordBrowserFrame.Visible
		if WordBrowserFrame.Visible then ShowAllWords() end
	end)
end

-- UPDATE LIST
UpdateList = function(detectedText, requiredLetter)
	local matches = {}
	local searchPrefix = detectedText
	if SearchBox.Text ~= "" then
		searchPrefix = SearchBox.Text:lower():gsub("[%s%c]+", "")
	end

	local firstChar = searchPrefix:sub(1,1)
	if firstChar == "#" then firstChar = nil end
	if (not firstChar or firstChar == "") and requiredLetter then
		firstChar = requiredLetter:sub(1,1):lower()
	end

	local bucket = (firstChar and Buckets[firstChar]) or Words

	local function CollectMatches(prefix)
		local exacts = {}
		for _, w in ipairs(bucket) do
			if not Blacklist[w] and not UsedWords[w] then
				if w:sub(1, #prefix) == prefix then
					table.insert(exacts, w)
				end
			end
		end
		return exacts
	end

	local exacts = CollectMatches(searchPrefix)
	matches = exacts

	if #matches > 0 then
		if sortMode == "Longest" then
			table.sort(matches, function(a, b) return #a > #b end)
		elseif sortMode == "Shortest" then
			table.sort(matches, function(a, b) return #a < #b end)
		elseif sortMode == "Killer" then
			table.sort(matches, function(a, b)
				local aKiller = EndsWithKillerSuffix(a)
				local bKiller = EndsWithKillerSuffix(b)
				if aKiller and not bKiller then return true end
				if not aKiller and bKiller then return false end
				return #a < #b
			end)
		elseif sortMode == "Random" then
			shuffleTable(matches)
		end

		if (sortMode == "Longest" or sortMode == "Shortest" or sortMode == "Killer") and randomizeTop and #matches > 1 then
			local topN = math.min(#matches, 5)
			local topPart = {}
			for i = 1, topN do table.insert(topPart, matches[i]) end
			for i = 1, topN do table.remove(matches, 1) end
			shuffleTable(topPart)
			for i = #topPart, 1, -1 do
				table.insert(matches, 1, topPart[i])
			end
		end
	end

	for i = 1, math.max(#matches, #ButtonCache) do
		local w = matches[i]
		local btn = ButtonCache[i]
		if w then
			local lbl
			if not btn then
				btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, -6, 0, 26)
				btn.BackgroundColor3 = THEME.ItemBG
				btn.Text = ""
				btn.AutoButtonColor = false
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				lbl = Instance.new("TextLabel", btn)
				lbl.Size = UDim2.new(1, -10, 1, 0)
				lbl.Position = UDim2.new(0, 5, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				btn.MouseButton1Click:Connect(function()
					SmartType(w, detectedText, true)
				end)
				btn.Parent = ScrollList
				table.insert(ButtonCache, btn)
			else
				lbl = btn:FindFirstChild("TextLabel")
				btn.Visible = true
				btn.Parent = ScrollList
			end
			if lbl then
				local accentRGB = "114,100,255"
				if i == 1 then accentRGB = "100,255,140"
				elseif i == 2 then accentRGB = "255,180,200"
				elseif i == 3 then accentRGB = "100,200,255" end
				local displayText = "<font color=\"rgb(" .. accentRGB .. ")\">" .. w:sub(1, #detectedText) .. "</font>" ..
					"<font color=\"rgb(240,240,240)\">" .. w:sub(#detectedText + 1) .. "</font>"
				lbl.Text = displayText
				lbl.RichText = true
			end
		else
			if btn then btn.Visible = false end
		end
	end
	ScrollList.CanvasSize = UDim2.new(0,0,0, UIListLayout.AbsoluteContentSize.Y)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	UpdateList(lastDetected, lastRequiredLetter)
end)

-- SMART TYPE
local function SmartType(targetWord, currentDetected, isCorrection)
	if isTyping or unloaded then return end
	isTyping = true
	UsedWords[targetWord] = true
	task.spawn(function()
		task.wait(0.1)
		isTyping = false
	end)
end

-- MAIN LOOP
runConn = RunService.RenderStepped:Connect(function()
	local now = tick()
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChild("PlayerGui")
	local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")
	local isVisible = frame and frame.Parent and frame.Parent:IsA("ScreenGui") and frame.Parent.Enabled

	if not isVisible then
		StatusText.Text = "Not in Round"
		StatusText.TextColor3 = THEME.SubText
		lastDetected = "---"
		return
	end

	local detected, censored = GetCurrentGameWord(frame)
	local isMyTurn, requiredLetter = GetTurnInfo(frame)

	if detected ~= lastDetected or requiredLetter ~= lastRequiredLetter or forceUpdateList then
		lastDetected = detected
		lastRequiredLetter = requiredLetter
		forceUpdateList = false
		UpdateList(detected, requiredLetter)
	end

	-- Auto clear on new round start
	local typeLbl = frame:FindFirstChild("Type")
	local typeVisible = typeLbl and typeLbl.Visible
	if typeVisible and not (lastTypeVisible or false) then
		task.delay(1, function()
			ClearUsedWords()
		end)
	end
	lastTypeVisible = typeVisible
end)

-- TOGGLE KEY
inputConn = UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == TOGGLE_KEY then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

-- INITIAL LIST
UpdateList("", "")
