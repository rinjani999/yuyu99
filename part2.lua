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
Title.Text = "Word<font color=\"rgb(114,100,255)\">Helper</font> V4"
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
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Size = UDim2.new(0, 45, 1, 0)
CloseBtn.Position = UDim2.new(1, -45, 0, 0)
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
    if UpdateList then
        UpdateList(lastDetected, lastRequiredLetter)
    end
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

local sep = Instance.new("Frame", SettingsFrame)
sep.Size = UDim2.new(1, 0, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(45, 45, 50)

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
        rows = {
            {"q","w","e","r","t","z","u","i","o","p"},
            {"a","s","d","f","g","h","j","k","l"},
            {"y","x","c","v","b","n","m"}
        }
    elseif keyboardLayout == "AZERTY" then
        rows = {
            {"a","z","e","r","t","y","u","i","o","p"},
            {"q","s","d","f","g","h","j","k","l","m"},
            {"w","x","c","v","b","n"}
        }
    else -- QWERTY
        rows = {
            {"q","w","e","r","t","y","u","i","o","p"},
            {"a","s","d","f","g","h","j","k","l"},
            {"z","x","c","v","b","n","m"}
        }
    end
    
    local startY = 15
    local spacing = 35
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

local function CreateDropdown(parent, text, options, default, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0, 130, 0, 24)
    container.BackgroundColor3 = THEME.Background
    container.ZIndex = 10
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)
    
    local mainBtn = Instance.new("TextButton", container)
    mainBtn.Size = UDim2.new(1, 0, 1, 0)
    mainBtn.BackgroundTransparency = 1
    mainBtn.Text = text .. ": " .. default
    mainBtn.Font = Enum.Font.GothamMedium
    mainBtn.TextSize = 11
    mainBtn.TextColor3 = THEME.Accent
    mainBtn.ZIndex = 11

    local listFrame = Instance.new("Frame", container)
    listFrame.Size = UDim2.new(1, 0, 0, #options * 24)
    listFrame.Position = UDim2.new(0, 0, 1, 2)
    listFrame.BackgroundColor3 = THEME.ItemBG
    listFrame.Visible = false
    listFrame.ZIndex = 20
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)
    
    local isOpen = false
    
    mainBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        listFrame.Visible = isOpen
    end)
    
    for i, opt in ipairs(options) do
        local btn = Instance.new("TextButton", listFrame)
        btn.Size = UDim2.new(1, 0, 0, 24)
        btn.Position = UDim2.new(0, 0, 0, (i-1)*24)
        btn.BackgroundTransparency = 1
        btn.Text = opt
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = THEME.Text
        btn.ZIndex = 21
        
        btn.MouseButton1Click:Connect(function()
            mainBtn.Text = text .. ": " .. opt
            isOpen = false
            listFrame.Visible = false
            callback(opt)
        end)
    end
    
    return container
end

local LayoutDropdown = CreateDropdown(TogglesFrame, "Layout", {"QWERTY", "QWERTZ", "AZERTY"}, keyboardLayout, function(val)
    keyboardLayout = val
    Config.KeyboardLayout = keyboardLayout
    GenerateKeyboard()
    SaveConfig()
end)
LayoutDropdown.Position = UDim2.new(0, 150, 0, 145)

UserInputService.InputBegan:Connect(function(input)
    if not showKeyboard then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local char = input.KeyCode.Name:lower()
        if Keys[char] then
            Tween(Keys[char], {BackgroundColor3 = THEME.Accent}, 0.1)
        end
        if input.KeyCode == Enum.KeyCode.Space then
            Tween(Keys[" "], {BackgroundColor3 = THEME.Accent}, 0.1)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not showKeyboard then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local char = input.KeyCode.Name:lower()
        if Keys[char] then
            Tween(Keys[char], {BackgroundColor3 = THEME.ItemBG}, 0.2)
        end
        if input.KeyCode == Enum.KeyCode.Space then
            Tween(Keys[" "], {BackgroundColor3 = THEME.ItemBG}, 0.2)
        end
    end
end)

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

local ErrorLabel = Instance.new("TextLabel", SlidersFrame)
ErrorLabel.Text = "Error Rate: " .. errorRate .. "%"
ErrorLabel.Font = Enum.Font.GothamMedium
ErrorLabel.TextSize = 11
ErrorLabel.TextColor3 = THEME.SubText
ErrorLabel.Size = UDim2.new(1, -30, 0, 18)
ErrorLabel.Position = UDim2.new(0, 15, 0, 36)
ErrorLabel.BackgroundTransparency = 1
ErrorLabel.TextXAlignment = Enum.TextXAlignment.Left

local ErrorBg = Instance.new("Frame", SlidersFrame)
ErrorBg.Size = UDim2.new(1, -30, 0, 6)
ErrorBg.Position = UDim2.new(0, 15, 0, 56)
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
    ErrorLabel.Text = "Error Rate: " .. errorRate .. "% (per-letter)"
end)

local ThinkLabel = Instance.new("TextLabel", SlidersFrame)
ThinkLabel.Text = string.format("Think: %.2fs", thinkDelayCurrent)
ThinkLabel.Font = Enum.Font.GothamMedium
ThinkLabel.TextSize = 11
ThinkLabel.TextColor3 = THEME.SubText
ThinkLabel.Size = UDim2.new(1, -30, 0, 18)
ThinkLabel.Position = UDim2.new(0, 15, 0, 62)
ThinkLabel.BackgroundTransparency = 1
ThinkLabel.TextXAlignment = Enum.TextXAlignment.Left

local ThinkBg = Instance.new("Frame", SlidersFrame)
ThinkBg.Size = UDim2.new(1, -30, 0, 6)
ThinkBg.Position = UDim2.new(0, 15, 0, 82)
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
        local newState, newText, newColor = callback()
        btn.Text = newText
        btn.TextColor3 = newColor
        SaveConfig()
    end)
    return btn
end

local HumanizeBtn = CreateToggle("Humanize: "..(useHumanization and "ON" or "OFF"), UDim2.new(0, 15, 0, 5), function()
    useHumanization = not useHumanization
    Config.Humanize = useHumanization
    return useHumanization, "Humanize: "..(useHumanization and "ON" or "OFF"), useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
HumanizeBtn.TextColor3 = useHumanization and THEME.Success or Color3.fromRGB(255, 100, 100)

local FingerBtn = CreateToggle("10-Finger: "..(useFingerModel and "ON" or "OFF"), UDim2.new(0, 105, 0, 5), function()
    useFingerModel = not useFingerModel
    Config.FingerModel = useFingerModel
    return useFingerModel, "10-Finger: "..(useFingerModel and "ON" or "OFF"), useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
FingerBtn.TextColor3 = useFingerModel and THEME.Success or Color3.fromRGB(255, 100, 100)

local KeyboardBtn = CreateToggle("Keyboard: "..(showKeyboard and "ON" or "OFF"), UDim2.new(0, 195, 0, 5), function()
    showKeyboard = not showKeyboard
    Config.ShowKeyboard = showKeyboard
    KeyboardFrame.Visible = showKeyboard
    return showKeyboard, "Keyboard: "..(showKeyboard and "ON" or "OFF"), showKeyboard and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
KeyboardBtn.TextColor3 = showKeyboard and THEME.Success or Color3.fromRGB(255, 100, 100)

local SortBtn = CreateToggle("Sort: "..sortMode, UDim2.new(0, 15, 0, 33), function()
    if sortMode == "Random" then sortMode = "Shortest"
    elseif sortMode == "Shortest" then sortMode = "Longest"
    elseif sortMode == "Longest" then sortMode = "Killer"
    else sortMode = "Random" end
    
    Config.SortMode = sortMode
    lastDetected = "---"
    return true, "Sort: "..sortMode, THEME.Accent
end)
SortBtn.TextColor3 = THEME.Accent
SortBtn.Size = UDim2.new(0, 130, 0, 24)

local AutoBtn = CreateToggle("Auto Play: "..(autoPlay and "ON" or "OFF"), UDim2.new(0, 150, 0, 33), function()
    autoPlay = not autoPlay
    Config.AutoPlay = autoPlay
    return autoPlay, "Auto Play: "..(autoPlay and "ON" or "OFF"), autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoBtn.TextColor3 = autoPlay and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoBtn.Size = UDim2.new(0, 130, 0, 24)

local AutoJoinBtn = CreateToggle("Auto Join: "..(autoJoin and "ON" or "OFF"), UDim2.new(0, 15, 0, 61), function()
    autoJoin = not autoJoin
    Config.AutoJoin = autoJoin
    return autoJoin, "Auto Join: "..(autoJoin and "ON" or "OFF"), autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
end)
AutoJoinBtn.TextColor3 = autoJoin and THEME.Success or Color3.fromRGB(255, 100, 100)
AutoJoinBtn.Size = UDim2.new(0, 265, 0, 24)

local function CreateCheckbox(text, pos, key)
    local container = Instance.new("TextButton", TogglesFrame)
    container.Size = UDim2.new(0, 90, 0, 24)
    container.Position = pos
    container.BackgroundColor3 = THEME.ItemBG
    container.AutoButtonColor = false
    container.Text = ""
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)
    
    local box = Instance.new("Frame", container)
    box.Size = UDim2.new(0, 14, 0, 14)
    box.Position = UDim2.new(0, 5, 0.5, -7)
    box.BackgroundColor3 = THEME.Slider
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
    
    local check = Instance.new("Frame", box)
    check.Size = UDim2.new(0, 8, 0, 8)
    check.Position = UDim2.new(0.5, -4, 0.5, -4)
    check.BackgroundColor3 = THEME.Success
    check.Visible = Config.AutoJoinSettings[key]
    Instance.new("UICorner", check).CornerRadius = UDim.new(0, 2)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Text = text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
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

CreateCheckbox("1v1", UDim2.new(0, 15, 0, 88), "_1v1")
CreateCheckbox("4 Player", UDim2.new(0, 110, 0, 88), "_4p")
CreateCheckbox("8 Player", UDim2.new(0, 205, 0, 88), "_8p")

local function GetBlatantText()
    if Config.Blatant == "Auto" then return "Blatant Mode: AUTO"
    elseif Config.Blatant then return "Blatant Mode: ON"
    else return "Blatant Mode: OFF" end
end

local function GetBlatantColor()
    if Config.Blatant == "Auto" then return Color3.fromRGB(255, 200, 80) -- Orange for Auto
    elseif Config.Blatant then return Color3.fromRGB(255, 80, 80) -- Red for On
    else return THEME.SubText end
end

local BlatantBtn = Instance.new("TextButton", TogglesFrame)
BlatantBtn.Text = GetBlatantText()
BlatantBtn.Font = Enum.Font.GothamMedium
BlatantBtn.TextSize = 11
BlatantBtn.TextColor3 = GetBlatantColor()
BlatantBtn.BackgroundColor3 = THEME.Background
BlatantBtn.Size = UDim2.new(0, 130, 0, 24)
BlatantBtn.Position = UDim2.new(0, 15, 0, 115)
Instance.new("UICorner", BlatantBtn).CornerRadius = UDim.new(0, 4)

BlatantBtn.MouseButton1Click:Connect(function()
    if Config.Blatant == false then
        Config.Blatant = true
    elseif Config.Blatant == true then
        Config.Blatant = "Auto"
    else
        Config.Blatant = false
    end
    
    BlatantBtn.Text = GetBlatantText()
    BlatantBtn.TextColor3 = GetBlatantColor()
    
    if Config.Blatant ~= "Auto" then
        isBlatant = Config.Blatant
    end
    SaveConfig()
end)

local RiskyBtn = CreateToggle("Risky Mistakes: "..(riskyMistakes and "ON" or "OFF"), UDim2.new(0, 150, 0, 115), function()
    riskyMistakes = not riskyMistakes
    Config.RiskyMistakes = riskyMistakes
    return riskyMistakes, "Risky Mistakes: "..(riskyMistakes and "ON" or "OFF"), riskyMistakes and Color3.fromRGB(255, 80, 80) or THEME.SubText
end)
RiskyBtn.TextColor3 = riskyMistakes and Color3.fromRGB(255, 80, 80) or THEME.SubText
RiskyBtn.Size = UDim2.new(0, 130, 0, 24)

local ManageWordsBtn = Instance.new("TextButton", TogglesFrame)
ManageWordsBtn.Text = "Manage Custom Words"
ManageWordsBtn.Font = Enum.Font.GothamMedium
ManageWordsBtn.TextSize = 11
ManageWordsBtn.TextColor3 = THEME.Accent
ManageWordsBtn.BackgroundColor3 = THEME.Background
ManageWordsBtn.Size = UDim2.new(0, 130, 0, 24)
ManageWordsBtn.Position = UDim2.new(0, 15, 0, 145)
Instance.new("UICorner", ManageWordsBtn).CornerRadius = UDim.new(0, 4)

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

local BlacklistManagerBtn = Instance.new("TextButton", TogglesFrame)
BlacklistManagerBtn.Text = "Blacklist Manager"
BlacklistManagerBtn.Font = Enum.Font.GothamMedium
BlacklistManagerBtn.TextSize = 11
BlacklistManagerBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
BlacklistManagerBtn.BackgroundColor3 = THEME.Background
BlacklistManagerBtn.Size = UDim2.new(0, 265, 0, 24)
BlacklistManagerBtn.Position = UDim2.new(0, 15, 0, 235)
Instance.new("UICorner", BlacklistManagerBtn).CornerRadius = UDim.new(0, 4)

SetupSlider(SliderBtn, SliderBg, SliderFill, function(pct)
    local max = isBlatant and MAX_CPM_BLATANT or MAX_CPM_LEGIT
    currentCPM = math.floor(MIN_CPM + (pct * (max - MIN_CPM)))
    SliderFill.Size = UDim2.new(pct, 0, 1, 0)
    SliderLabel.Text = "Speed: " .. currentCPM .. " CPM"
    if currentCPM > 900 then Tween(SliderFill, {BackgroundColor3 = Color3.fromRGB(255,80,80)}) 
    else Tween(SliderFill, {BackgroundColor3 = THEME.Accent}) end
end)

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
