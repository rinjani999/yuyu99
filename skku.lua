local HttpService = game:GetService("HttpService")
local CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local Players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local VirtualInputManager = cloneref and cloneref(game:GetService("VirtualInputManager")) or game:GetService("VirtualInputManager")
local UserInputService = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local RunService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local TweenService = cloneref and cloneref(game:GetService("TweenService")) or game:GetService("TweenService")
local LogService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")

local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local gethui = gethui or function() return CoreGui end

if _G.SambungKataUnload_V2 then
    pcall(_G.SambungKataUnload_V2)
end
local cleanupTasks = {}
_G.SambungKataUnload_V2 = function()
    for _, fn in ipairs(cleanupTasks) do pcall(fn) end
end

-- Anti-AFK
pcall(function()
    local vu = game:GetService("VirtualUser")
    local afkConn
    afkConn = Players.LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    table.insert(cleanupTasks, function() if afkConn then afkConn:Disconnect() end end)
end)

-- UI UTILS
local function UI_Tween(obj, props, time)
    local tween = TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

local function MakeDraggable(topbar, object)
    local dragging, dragInput, mousePos, framePos = false, nil, nil, nil
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, mousePos, framePos = true, input.Position, object.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            object.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

-- ===========================================
-- GLOBAL UI FACTORY
-- ===========================================
local function CreateMainHUD(title)
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "HubGuiV2_" .. math.random(1000, 9999)
    Gui.Parent = gethui()
    table.insert(cleanupTasks, function() if Gui and Gui.Parent then Gui:Destroy() end end)

    local Frame = Instance.new("Frame", Gui)
    Frame.Size = UDim2.new(0, 220, 0, 0)
    Frame.Position = UDim2.new(0, 15, 0.5, -100)
    Frame.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
    Frame.Active, Frame.AutomaticSize = true, Enum.AutomaticSize.Y
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke", Frame)
    Stroke.Color, Stroke.Thickness = Color3.fromRGB(60, 60, 75), 1

    local Topbar = Instance.new("Frame", Frame)
    Topbar.Size, Topbar.BackgroundColor3 = UDim2.new(1, 0, 0, 36), Color3.fromRGB(28, 28, 34)
    Instance.new("UICorner", Topbar).CornerRadius = UDim.new(0, 8)
    local Fix = Instance.new("Frame", Topbar)
    Fix.Size, Fix.Position, Fix.BackgroundColor3, Fix.BorderSizePixel = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 1, -10), Color3.fromRGB(28, 28, 34), 0
    MakeDraggable(Topbar, Frame)

    local Title = Instance.new("TextLabel", Topbar)
    Title.Size, Title.Position, Title.Text, Title.Font, Title.TextSize, Title.TextColor3, Title.BackgroundTransparency, Title.TextXAlignment = UDim2.new(1, -40, 1, 0), UDim2.new(0, 12, 0, 0), title, Enum.Font.GothamBold, 13, Color3.fromRGB(240, 240, 250), 1, Enum.TextXAlignment.Left

    local isMinimized = true
    local MinBtn = Instance.new("TextButton", Topbar)
    MinBtn.Size, MinBtn.Position, MinBtn.Text, MinBtn.Font, MinBtn.TextSize, MinBtn.TextColor3, MinBtn.BackgroundTransparency = UDim2.new(0, 30, 0, 30), UDim2.new(1, -65, 0, 3), "—", Enum.Font.GothamBold, 14, Color3.fromRGB(150, 150, 160), 1

    local CloseBtn = Instance.new("TextButton", Topbar)
    CloseBtn.Size, CloseBtn.Position, CloseBtn.Text, CloseBtn.Font, CloseBtn.TextSize, CloseBtn.TextColor3, CloseBtn.BackgroundTransparency = UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 3), "×", Enum.Font.GothamBold, 20, Color3.fromRGB(250, 80, 80), 1
    CloseBtn.MouseButton1Click:Connect(function() pcall(function() _G.SambungKataUnload_V2() end) end)

    local Content = Instance.new("Frame", Frame)
    Content.Size, Content.Position, Content.BackgroundTransparency, Content.AutomaticSize = UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 0, 36), 1, Enum.AutomaticSize.Y
    Content.ClipsDescendants = true
    Content.Visible = false
    
    local Pad = Instance.new("UIPadding", Content)
    Pad.PaddingTop, Pad.PaddingBottom, Pad.PaddingLeft, Pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10)
    
    local Layout = Instance.new("UIListLayout", Content)
    Layout.SortOrder, Layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 8)

    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        Content.Visible = not isMinimized
    end)

    return Gui, Content
end

local function MakeToggle(parent, name, order, initialState, callback)
    local btnBg = Instance.new("TextButton", parent)
    btnBg.Size = UDim2.new(1, 0, 0, 34)
    btnBg.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    btnBg.AutoButtonColor = false
    btnBg.LayoutOrder = order
    btnBg.Text = ""
    Instance.new("UICorner", btnBg).CornerRadius = UDim.new(0, 6)
    
    local nameLbl = Instance.new("TextLabel", btnBg)
    nameLbl.Size, nameLbl.Position, nameLbl.Text, nameLbl.Font, nameLbl.TextSize, nameLbl.TextColor3, nameLbl.BackgroundTransparency, nameLbl.TextXAlignment = UDim2.new(1, -55, 1, 0), UDim2.new(0, 12, 0, 0), name, Enum.Font.GothamMedium, 12, Color3.fromRGB(230, 230, 230), 1, Enum.TextXAlignment.Left
    
    local toggleBg = Instance.new("Frame", btnBg)
    toggleBg.Size, toggleBg.Position = UDim2.new(0, 36, 0, 18), UDim2.new(1, -48, 0.5, -9)
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)
    
    local toggleCircle = Instance.new("Frame", toggleBg)
    toggleCircle.Size, toggleCircle.Position, toggleCircle.BackgroundColor3 = UDim2.new(0, 14, 0, 14), UDim2.new(0, 2, 0.5, -7), Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", toggleCircle).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    
    local function UpdateVisuals(animated)
        local targetColor = state and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(60, 60, 70)
        local targetPos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        if animated then
            UI_Tween(toggleBg, {BackgroundColor3 = targetColor}, 0.2)
            UI_Tween(toggleCircle, {Position = targetPos}, 0.2)
        else
            toggleBg.BackgroundColor3 = targetColor
            toggleCircle.Position = targetPos
        end
    end
    UpdateVisuals(false)
    
    btnBg.MouseButton1Click:Connect(function()
        state = not state
        UpdateVisuals(true)
        callback(state)
    end)
    return btnBg, function(newState) state = newState; UpdateVisuals(true) end
end

local function MakeCheckbox(parent, name, order, state, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size, btn.BackgroundTransparency, btn.Text, btn.LayoutOrder = UDim2.new(1, 0, 0, 24), 1, "", order
    
    local box = Instance.new("Frame", btn)
    box.Size, box.Position, box.BackgroundColor3 = UDim2.new(0, 16, 0, 16), UDim2.new(0, 8, 0.5, -8), Color3.fromRGB(45, 45, 50)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", box).Color = Color3.fromRGB(70, 70, 80)
    
    local check = Instance.new("TextLabel", box)
    check.Size, check.BackgroundTransparency, check.Text, check.Font, check.TextSize, check.TextColor3 = UDim2.new(1, 0, 1, 0), 1, state and "✓" or "", Enum.Font.GothamBold, 12, Color3.fromRGB(255,255,255)
    
    local lbl = Instance.new("TextLabel", btn)
    lbl.Size, lbl.Position, lbl.Text, lbl.Font, lbl.TextSize, lbl.TextColor3, lbl.BackgroundTransparency, lbl.TextXAlignment = UDim2.new(1, -34, 1, 0), UDim2.new(0, 34, 0, 0), name, Enum.Font.Gotham, 12, Color3.fromRGB(200,200,205), 1, Enum.TextXAlignment.Left
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        check.Text = state and "✓" or ""
        box.BackgroundColor3 = state and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(45, 45, 50)
        callback(state)
    end)
    box.BackgroundColor3 = state and Color3.fromRGB(70, 200, 110) or Color3.fromRGB(45, 45, 50)
    return btn
end

-- ===========================================
-- WIN MODE LOGIC (Optimized)
-- ===========================================

local FailedCache = {}
local UsedWordCache = {}
local FailedDBDirty = false
local UsedWordDBDirty = false

-- Helper notifikasi global (aman dipanggil dari mana saja)
local function Notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = title,
            Text     = text,
            Duration = duration or 4
        })
    end)
end

local function AddToFailedCache(word, blacklistRef)
    if not FailedCache[word] then
        FailedCache[word] = true
        FailedDBDirty = true
        -- Notif: kata baru masuk failed.txt
        Notify("❌ Failed Cache", "[" .. tostring(word) .. "] ditambahkan ke failed.txt", 4)
    end
    if blacklistRef then blacklistRef[word] = true end
end

local function AddToUsedWordCache(word)
    if not UsedWordCache[word] then
        UsedWordCache[word] = true
        UsedWordDBDirty = true
        -- Notif: kata baru masuk cache memory ronde ini
        Notify("✅ Used Cache", "[" .. tostring(word) .. "] masuk ke UsedWord Memory", 3)
    end
end

local DANGER_USERNAMES = {
    ["AbdiPar"] = true,
    ["NauvalYT"] = true,
    ["vaerelaa"] = true,
    ["sh1ningstarss"] = true,
    ["shortmovieYT"] = true,
    ["ZenixNoobss"] = false,
    ["KentangXgoReng70"] = true,
    ["SangPenjelajah_01"] = true
}

-- Karena Group Rank tidak valid (Admin dan Player biasa punya role yang sama), 
-- kita tidak lagi membuang memori untuk mengecek Group.

local function LoadWinMode()
    local unloaded = false
    table.insert(cleanupTasks, function() unloaded = true end)

    local CONFIG = { CPM = 630, Humanize = true, SortMode = "Random", AutoPlay = true, Expert = true, AntiAFK = true, AutoJoin = false, IdleMode = false, AutoTeleportGuest = false, AutoJoinSettings = { _1v1 = true, _4p = false, kosong = false, isi = true }, ProTypeChance = 60, ProTypeCPMBoost = 2, ProTypeDurationMin = 3, ProTypeDurationMax = 6, ProTypeMistakeMax = 4,
        KillerMode = false,
        KillerAuto = true,       -- Killer otomatis aktif setelah KillerAutoDelay detik
        KillerAutoDelay = 300,    -- Durasi sebelum Killer Auto ON (detik, default 5 menit)
        KillerSuffixes = {"ks", "ksa", "yab", "iki", "tl", "ous", "dl", "cis", "alv", "sih"},
        WinsThreshold = 500,
        LossesThreshold = 500,
        MinServerPlayers = 10,
        AutoLeaveAlone = true,   -- Auto klik Leave jika duduk sendirian terlalu lama
        AutoLeaveAloneDelay = 15, -- Detik menunggu sendirian sebelum klik Leave
        -- ===== HUMANIZATION SETTINGS =====
        CPMVariance    = 50,    -- #1: floating CPM per-giliran (CPM ± N). 0 = nonaktif
        ThinkDelayMin  = 0.4,   -- #2: min think delay sebelum mulai ketik (detik)
        ThinkDelayMax  = 1.5,   -- #2: max think delay sebelum mulai ketik (detik)
        StumbleChance  = 5,     -- #4: % chance stumble (jeda 2.5–4× panjang tiba-tiba). 0 = nonaktif
        SubmitDelayMin = 0.05,  -- #5: min jeda setelah huruf terakhir sebelum Enter (detik)
        SubmitDelayMax = 0.20,  -- #5: max jeda setelah huruf terakhir sebelum Enter (detik)
        CPMDrift       = 15     -- #7: max micro-drift CPM antar kata (±N). 0 = nonaktif
    }
    local function SaveConfig()
        if writefile then writefile("WinMode_ConfigTroll.json", HttpService:JSONEncode(CONFIG)) end
    end
    -- Setiap eksekusi: hapus config lama dan tulis ulang dengan nilai terbaru dari script
    if isfile and isfile("WinMode_ConfigTroll.json") then
        pcall(function() if delfile then delfile("WinMode_ConfigTroll.json") end end)
    end
    SaveConfig()

    
    -- Optimized Words Parsing (Suggestion 2)
    local WordsByLetter = {}
    local Blacklist = {}
    
    if isfile then
        pcall(function()
            if isfile("failed.txt") then
                for line in readfile("failed.txt"):gmatch("[^\r\n]+") do
                    local clean = line:gsub("[%s%c]+", ""):lower()
                    if #clean > 0 then Blacklist[clean] = true; FailedCache[clean] = true end
                end
            end
            -- usedword.txt SELALU dibaca ke UsedWordCache (sebagai seed awal),
            -- sehingga kata lama tidak pernah hilang saat script dieksekusi ulang.
            -- IdleMode hanya mengontrol apakah file ini di-persist kembali saat flush,
            -- bukan apakah file ini dibaca saat startup.
            if isfile("usedword.txt") then
                for line in readfile("usedword.txt"):gmatch("[^\r\n]+") do
                    local clean = line:gsub("[%s%c]+", ""):lower()
                    if #clean > 0 then UsedWordCache[clean] = true end
                end
            end
        end)
    end

    -- SessionBlacklist: kata yang sudah dicoba dalam ronde ini (bersih tiap ronde)
    local SessionBlacklist = {}

    task.spawn(function()
        while task.wait(10) do
            if unloaded then break end
            if FailedDBDirty and writefile then
                local out = {}
                for k, _ in pairs(FailedCache) do table.insert(out, k) end
                pcall(function() writefile("failed.txt", table.concat(out, "\n")) end)
                FailedDBDirty = false
            end
            -- usedword.txt hanya di-persist jika Idle Mode ON
            if UsedWordDBDirty and writefile and CONFIG.IdleMode then
                -- Merge-write: baca isi file lama terlebih dahulu, gabungkan dengan cache,
                -- sehingga kata-kata yang sudah ada tidak pernah kehilangan walaupun
                -- script dieksekusi ulang atau IdleMode sempat off.
                local merged = {}
                pcall(function()
                    if isfile and isfile("usedword.txt") then
                        for line in readfile("usedword.txt"):gmatch("[^\r\n]+") do
                            local clean = line:gsub("[%s%c]+", ""):lower()
                            if #clean > 0 then merged[clean] = true end
                        end
                    end
                end)
                -- Tambahkan semua kata dari cache in-memory ke merged set
                for k, _ in pairs(UsedWordCache) do merged[k] = true end
                -- Tulis hasil merged ke disk
                local out = {}
                for k, _ in pairs(merged) do table.insert(out, k) end
                local ok = pcall(function() writefile("usedword.txt", table.concat(out, "\n")) end)
                if ok then
                    Notify("💾 usedword.txt", "Disimpan: " .. #out .. " kata ke usedword.txt", 4)
                end
                UsedWordDBDirty = false
            elseif UsedWordDBDirty and not CONFIG.IdleMode then
                -- IdleMode off: reset flag saja, tidak tulis ke file
                -- (kata tetap aman di file, hanya cache in-memory yang boleh di-clear)
                UsedWordDBDirty = false
            end
        end
    end)

    task.spawn(function()
        local success, res = pcall(function() return request({Url = "https://find.wagate.biz.id/merged_indonesian.txt", Method = "GET"}) end)
        local content = (success and res and res.Body) or ""
        if content == "" and isfile and isfile("merged_indonesian.txt") then content = readfile("merged_indonesian.txt")
        elseif content ~= "" and writefile then writefile("merged_indonesian.txt", content) end
        
        for w in content:gmatch("[^\r\n]+") do
            local clean = w:gsub("[%s%c]+", ""):lower()
            if #clean > 0 then 
                local fc = clean:sub(1,1)
                if not WordsByLetter[fc] then WordsByLetter[fc] = {} end
                table.insert(WordsByLetter[fc], clean)
            end
        end
    end)

    local KEY_POS = {}
    local r1, r2, r3 = "qwertyuiop", "asdfghjkl", "zxcvbnm"
    for i=1, #r1 do KEY_POS[r1:sub(i,i)] = {x=i, y=1} end
    for i=1, #r2 do KEY_POS[r2:sub(i,i)] = {x=i+0.5, y=2} end
    for i=1, #r3 do KEY_POS[r3:sub(i,i)] = {x=i+1, y=3} end

    -- Expert / ProType: CPM aktif (bisa di-boost sementara)
    local expertCPM = CONFIG.CPM
    local expertBoosting = false
    local sessionCPM = CONFIG.CPM  -- #1: floating CPM per-giliran (di-refresh tiap giliran)
    local driftCPM   = 0           -- #7: micro-drift CPM per-kata (bergeser perlahan tiap kata)

    local function CalculateDelay(p, n)
        -- #1 + #7: Base CPM = session variance + per-kata drift
        local cpm = sessionCPM + driftCPM
        -- Expert boost dikali dari base (bukan dari CONFIG.CPM mentah)
        if expertBoosting then cpm = cpm * (1 + CONFIG.ProTypeCPMBoost / 100) end
        cpm = math.max(100, cpm)
        local base = 60 / cpm
        if not CONFIG.Humanize then return base end
        -- #4: Heavy-tail stumble — jari tersangkut / hesitate tiba-tiba
        local sc = CONFIG.StumbleChance or 0
        if sc > 0 and math.random(100) <= sc then
            return math.max(0.005, base * (2.5 + math.random() * 1.5))
        end
        local dist = 1
        if p and p~="" and n and n~="" then
            local pp, pn = KEY_POS[p:lower()], KEY_POS[n:lower()]
            if pp and pn then dist = math.sqrt((pp.x - pn.x)^2 + (pp.y - pn.y)^2) end
        end
        local extra = dist * 0.018 * (550 / math.max(150, cpm))
        local noise = (((math.random()+math.random()+math.random())/3)*2-1) * (base * 0.35)
        return math.max(0.005, base + extra + noise)
    end

    local function SimKey(input)
        local char = type(input) == "string" and input:lower()
        if char then
            pcall(function() VirtualInputManager:SendTextInput(char) end)
            local key = Enum.KeyCode[char:upper()]
            if key then
                pcall(function() VirtualInputManager:SendKeyEvent(true, key, false, game) task.wait(0.01) VirtualInputManager:SendKeyEvent(false, key, false, game) end)
            end
        else
            local key = typeof(input) == "EnumItem" and input or Enum.KeyCode[tostring(input):upper()]
            if key then pcall(function() VirtualInputManager:SendKeyEvent(true, key, false, game) task.wait(0.01) VirtualInputManager:SendKeyEvent(false, key, false, game) end) end
        end
    end

    local function DoBackspace(n)
        for i=1, n do SimKey(Enum.KeyCode.Backspace) task.wait(0.02) end
    end

    -- Caching UI Elements (Suggestion 3)
    local CachedUI = { Top = nil, Box = nil, Server = nil, Submit = nil }
    local function IsValid(o, cl) return o and o.Parent and o:IsA(cl) end

    local function GetSambungUI()
        if IsValid(CachedUI.Top, "GuiObject") then return CachedUI.Top end
        local g = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local t = g and (g:FindFirstChild("TopUI", true) or (g:FindFirstChild("WordSubmit", true) and g:FindFirstChild("WordSubmit", true).Parent))
        CachedUI.Top = t return t
    end

    local function GetBox()
        if IsValid(CachedUI.Box, "TextBox") then return CachedUI.Box end
        local g = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local r = g and g:FindFirstChild("RedGui")
        if r then for _, c in ipairs(r:GetDescendants()) do if c:IsA("TextBox") and c.Visible then CachedUI.Box = c return c end end end
        local f = UserInputService:GetFocusedTextBox()
        if f then CachedUI.Box = f return f end
        return nil
    end

    local function GetTurn()
        if not IsValid(CachedUI.Server, "TextLabel") then
            local g = Players.LocalPlayer:FindFirstChild("PlayerGui")
            local f = g and g:FindFirstChild("WordServerFrame", true)
            CachedUI.Server = f and f:FindFirstChild("WordServer")
        end
        if CachedUI.Server and CachedUI.Server.Parent and CachedUI.Server.Parent.Visible and #CachedUI.Server.Text > 0 then
            local req = CachedUI.Server.Text:lower():match("([a-z])")
            if req then
                if not IsValid(CachedUI.Submit, "Frame") then
                    local g = Players.LocalPlayer:FindFirstChild("PlayerGui")
                    CachedUI.Submit = g and g:FindFirstChild("WordSubmit", true)
                end
                if CachedUI.Submit and CachedUI.Submit.Visible then
                    for _, c in ipairs(CachedUI.Submit:GetChildren()) do
                        if c.Name == "Word" and c:IsA("TextLabel") and c.Visible then return true, req end
                    end
                end
            end
        end
        return false, nil
    end

    local function GetCurrentWord()
        if not IsValid(CachedUI.Submit, "Frame") then return "", false end
        if not CachedUI.Submit.Visible then return "", false end
        local wData = {}
        for _, c in ipairs(CachedUI.Submit:GetChildren()) do
            if c.Name == "Word" and c:IsA("TextLabel") and c.Visible then table.insert(wData, {o=c, x=c.AbsolutePosition.X}) end
        end
        table.sort(wData, function(a,b) return a.x < b.x end)
        local str = ""
        for _, d in ipairs(wData) do str = str .. tostring(d.o.Text) end
        return str:lower():gsub(" ", ""), str:find("#") or str:find("%*")
    end

    local function IsAlreadyUsed()
        local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local matchUI = gui and gui:FindFirstChild("MatchUI")
        local warn = matchUI and matchUI:FindFirstChild("UsedWordWarn")
        if warn and warn.TextTransparency < 1 and (warn.Text:find("Sudah Digunakan") or warn.Text:find("Used")) then
            return true
        end
        return false
    end

    local function FindBest(det, req)
        local pre = det:lower()
        if #pre == 0 and req and #req > 0 then pre = req:sub(1,1):lower() end
        local fChar = pre:sub(1,1)
        local dict = (fChar and WordsByLetter[fChar]) or {}
        
        local validWords = {}   -- kata dari usedword.txt (sudah terbukti valid, hanya relevan saat IdleMode on)
        local unknownWords = {} -- kata belum pernah dicoba (atau belum ada di usedword.txt)
        local failedWords = {}  -- kata dari failed.txt (last resort, mungkin false positive)
        
        for _, w in ipairs(dict) do
            if (#pre == 0 or w:sub(1, #pre) == pre) then
                -- SessionBlacklist = kata yang sudah dicoba ronde ini → skip total
                if SessionBlacklist[w] then
                    -- lewati
                elseif Blacklist[w] then
                    -- Kata dari failed.txt → kumpulkan sebagai last resort
                    if not UsedWordCache[w] then -- belum dipakai ronde ini
                        table.insert(failedWords, w)
                    end
                elseif CONFIG.IdleMode then
                    -- Idle Mode: pecah berdasarkan usedword
                    if UsedWordCache[w] then
                        table.insert(validWords, w)
                    else
                        table.insert(unknownWords, w)
                    end
                else
                    -- Normal Mode (IdleMode off): skip kata yang sudah digunakan di ronde ini
                    -- UsedWordCache berfungsi sebagai round memory dan di-clear tiap ronde baru
                    if not UsedWordCache[w] then
                        table.insert(unknownWords, w)
                    end
                end
            end
        end
        
        -- Prioritas pemilihan:
        -- 1. unknownWords (kata baru / belum dicoba)
        -- 2. validWords (IdleMode: kata dari usedword.txt)
        -- 3. Reload usedword.txt dari disk (IdleMode: jika memory habis)
        -- 4. failedWords (last resort: kata dari failed.txt, bisa jadi false positive)
        local selectionDict = nil
        if CONFIG.IdleMode then
            if #unknownWords > 0 then selectionDict = unknownWords
            elseif #validWords > 0 then selectionDict = validWords
            else
                -- Fallback: reload usedword.txt jika kehabisan kata
                pcall(function()
                    if isfile and isfile("usedword.txt") then
                        local freshWords = {}
                        for line in readfile("usedword.txt"):gmatch("[^\r\n]+") do
                            local clean = line:gsub("[%s%c]+", ""):lower()
                            if #clean > 0 and not SessionBlacklist[clean] then
                                if (#pre == 0 or clean:sub(1, #pre) == pre) then
                                    table.insert(freshWords, clean)
                                end
                            end
                        end
                        if #freshWords > 0 then selectionDict = freshWords end
                    end
                end)
            end
        else
            if #unknownWords > 0 then selectionDict = unknownWords end
        end

        -- Last resort: gunakan failedWords jika semua pool utama kosong
        if (not selectionDict or #selectionDict == 0) and #failedWords > 0 then
            selectionDict = failedWords
            Notify("⚠ Last Resort", "Menggunakan kata dari failed.txt sebagai fallback", 4)
        end
        
        if selectionDict and #selectionDict > 0 then
            -- Killer Mode: prioritaskan kata dengan suffix killer
            if CONFIG.KillerMode and CONFIG.KillerSuffixes and #CONFIG.KillerSuffixes > 0 then
                local killerWords = {}
                local normalWords = {}
                for _, w in ipairs(selectionDict) do
                    local isKiller = false
                    for _, suffix in ipairs(CONFIG.KillerSuffixes) do
                        if w:sub(-#suffix) == suffix then
                            isKiller = true
                            break
                        end
                    end
                    if isKiller then
                        table.insert(killerWords, w)
                    else
                        table.insert(normalWords, w)
                    end
                end
                -- Prioritas: killer dulu, fallback ke normal
                if #killerWords > 0 then
                    return killerWords[math.random(1, #killerWords)]
                elseif #normalWords > 0 then
                    return CONFIG.SortMode == "Random" and normalWords[math.random(1, #normalWords)] or normalWords[1]
                end
            end
            return CONFIG.SortMode == "Random" and selectionDict[math.random(1, #selectionDict)] or selectionDict[1] 
        end
        return nil
    end

    local Gui, Content = CreateMainHUD("Set Tele 2")
    MakeToggle(Content, "Auto Play", 1, CONFIG.AutoPlay, function(v) CONFIG.AutoPlay = v SaveConfig() end)
    MakeToggle(Content, "Expert (ProType Mix)", 2, CONFIG.Expert, function(v)
        CONFIG.Expert = v
        if not v then expertBoosting = false expertCPM = CONFIG.CPM end
        SaveConfig()
    end)
    MakeToggle(Content, "Anti AFK", 3, CONFIG.AntiAFK, function(v) CONFIG.AntiAFK = v SaveConfig() end)
    MakeToggle(Content, "Auto Join", 4, CONFIG.AutoJoin, function(v) CONFIG.AutoJoin = v SaveConfig() end)
    MakeCheckbox(Content, "Join 1v1", 5, CONFIG.AutoJoinSettings._1v1, function(v) CONFIG.AutoJoinSettings._1v1 = v SaveConfig() end)
    MakeCheckbox(Content, "Join 4P", 6, CONFIG.AutoJoinSettings._4p, function(v) CONFIG.AutoJoinSettings._4p = v SaveConfig() end)
    MakeCheckbox(Content, "Kosong (0 Players)", 7, CONFIG.AutoJoinSettings.kosong, function(v) CONFIG.AutoJoinSettings.kosong = v SaveConfig() end)
    MakeCheckbox(Content, "Isi (Has Players)", 8, CONFIG.AutoJoinSettings.isi, function(v) CONFIG.AutoJoinSettings.isi = v SaveConfig() end)
    MakeToggle(Content, "Idle Mode (Explore)", 9, CONFIG.IdleMode, function(v) CONFIG.IdleMode = v SaveConfig() end)
    MakeToggle(Content, "Auto TP (Guests Only)", 10, CONFIG.AutoTeleportGuest, function(v) CONFIG.AutoTeleportGuest = v SaveConfig() end)
    local killerManualToggle, setKillerManualToggle = MakeToggle(Content, "Killer Manual", 11, CONFIG.KillerMode, function(v)
        CONFIG.KillerMode = v
        SaveConfig()
    end)
    local killerAutoToggle, setKillerAutoToggle = MakeToggle(Content, "Killer Auto", 12, CONFIG.KillerAuto, function(v)
        CONFIG.KillerAuto = v
        -- Jika Auto dimatikan, pastikan KillerMode ikut nonaktif jika sedang auto-aktif
        if not v then
            CONFIG.KillerMode = false
            pcall(function() setKillerManualToggle(false) end)
        end
        SaveConfig()
    end)
    MakeToggle(Content, "Auto Leave if Alone", 13, CONFIG.AutoLeaveAlone, function(v) CONFIG.AutoLeaveAlone = v SaveConfig() end)

    -- Tracking ronde aktif untuk auto-clear SessionBlacklist
    local wasInRound = false
    local notSittingCount = 0       -- debounce counter untuk deteksi ronde selesai
    -- Tracking Killer Auto
    local roundFirstWordTime = nil  -- tick() saat kata pertama diketik di ronde ini
    local killerAutoActive = false  -- apakah auto killer sudah aktif di ronde ini
    local roundId = 0               -- ID unik per ronde, untuk cancel timer dari ronde lama

    local function TypeWordDirect(wordToType, currentDet)
        -- Ketik kata tanpa ProType/fake mistake (untuk retry)
        local curDet = currentDet or ""
        local miss = (wordToType:sub(1, #curDet) == curDet) and wordToType:sub(#curDet + 1) or wordToType
        if wordToType:sub(1, #curDet) ~= curDet then DoBackspace(#curDet) curDet = "" end
        local pl = nil
        for i = 1, #miss do
            if not GetTurn() then return false end
            local rbb = GetBox() if rbb then rbb:CaptureFocus() end
            local rch = miss:sub(i, i)
            SimKey(rch)
            task.wait(CalculateDelay(pl, rch))
            pl = rch
        end
        -- #5: Submit timing random (retry path)
        do local sMin = CONFIG.SubmitDelayMin or 0.05; local sMax = CONFIG.SubmitDelayMax or 0.20
           task.wait(sMin + math.random() * (sMax - sMin)) end
        if not GetTurn() then return false end
        local rbb = GetBox() if rbb then rbb:CaptureFocus() end
        SimKey(Enum.KeyCode.Return)
        return true
    end

    local function VerifySubmission(submittedWord, fallbackDet)
        -- Tunggu konfirmasi dari server (max 2.5s)
        -- Kata diterima = giliran kita selesai (GetTurn false)
        local rv = tick()
        while (tick() - rv) < 1.5 do
            if not GetTurn() then
                return true -- giliran selesai = diterima
            end
            local rc, ri = GetCurrentWord()
            if ri then
                return true -- censored = diterima
            end
            task.wait(0.05)
        end
        return false -- timeout + giliran masih aktif = tidak diterima
    end

    task.spawn(function()
        local isTyping = false
        -- Polling event loop (every 0.15s)
        while task.wait(0.15) do
            if unloaded then break end
            if not CONFIG.AutoPlay then CachedUI.Top = nil continue end

            -- Expert / ProType: randomisasi boost CPM setiap sesi (70% pro, 30% normal)
            if CONFIG.Expert and not expertBoosting and not isTyping then
                if math.random(100) <= CONFIG.ProTypeChance then
                    expertBoosting = true
                    local boostMult = 1 + (CONFIG.ProTypeCPMBoost / 100)
                    expertCPM = CONFIG.CPM * boostMult
                    local boostDuration = CONFIG.ProTypeDurationMin + math.random() * (CONFIG.ProTypeDurationMax - CONFIG.ProTypeDurationMin)
                    task.delay(boostDuration, function()
                        expertBoosting = false
                        expertCPM = CONFIG.CPM
                    end)
                else
                    expertBoosting = false
                    expertCPM = CONFIG.CPM
                end
            end

            local topUI = GetSambungUI()
            local isVisible = topUI and (topUI.Visible or topUI.AbsoluteSize.Y > 0)
            
            local myTurn, req = GetTurn()

            -- Deteksi ronde berdasarkan status duduk (Sit)
            -- Duduk = ronde aktif, Berdiri = ronde selesai
            local isSitting = false
            pcall(function()
                local char = Players.LocalPlayer and Players.LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then isSitting = hum.Sit end
            end)

            if isSitting and not wasInRound then
                -- Baru duduk → ronde dimulai
                wasInRound = true
                notSittingCount = 0
            elseif isSitting and wasInRound then
                -- Masih duduk → reset debounce counter
                notSittingCount = 0
            elseif not isSitting and wasInRound then
                -- Baru berdiri — tapi perlu debounce: tunggu 3 poll berturut-turut
                -- supaya transisi sesaat (loading/lag) tidak memicu reset palsu
                notSittingCount = notSittingCount + 1
                if notSittingCount >= 3 then
                    -- Ronde benar-benar selesai
                    wasInRound = false
                    notSittingCount = 0
                    -- Naikkan roundId → semua timer lama dari ronde sebelumnya akan diabaikan
                    roundId = roundId + 1
                    -- Clear session blacklist untuk ronde berikutnya
                    SessionBlacklist = {}
                    -- Sync Blacklist dari FailedCache
                    for w in pairs(FailedCache) do Blacklist[w] = true end
                    -- Clear UsedWordCache jika IdleMode off
                    if not CONFIG.IdleMode then
                        UsedWordCache = {}
                        UsedWordDBDirty = false
                    end
                    -- Reset Killer Auto state untuk ronde berikutnya
                    roundFirstWordTime = nil
                    local wasKillerActive = killerAutoActive
                    killerAutoActive = false
                    -- Matikan KillerMode HANYA jika diaktifkan oleh Auto (bukan manual)
                    if CONFIG.KillerAuto and wasKillerActive then
                        CONFIG.KillerMode = false
                        pcall(function() setKillerManualToggle(false) end)
                        Notify("🔪 Killer Auto OFF", "Ronde selesai — Killer Mode dinonaktifkan.", 5)
                    end
                    -- Notifikasi ronde selesai
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("SendNotification", {
                            Title = "🔄 Ronde Selesai",
                            Text  = "UsedWordCache & SessionBlacklist telah di-clear.",
                            Duration = 4
                        })
                    end)
                end
            else
                -- Tidak duduk dan tidak sedang dalam ronde → reset debounce
                notSittingCount = 0
            end
            
            if isVisible then
                local det, cens = GetCurrentWord()
                
                if myTurn and not isTyping then
                    isTyping = true
                    -- #1: Refresh floating CPM per-giliran & reset drift (#7)
                    pcall(function()
                        local v = CONFIG.CPMVariance or 0
                        sessionCPM = CONFIG.CPM + (v > 0 and math.random(-v, v) or 0)
                        sessionCPM = math.max(100, sessionCPM)
                        driftCPM = 0  -- reset drift tiap giliran baru
                    end)
                    -- Catat waktu pengetikan kata pertama (untuk Killer Auto timer)
                    if roundFirstWordTime == nil then
                        roundFirstWordTime = tick()
                        -- Mulai timer Killer Auto jika mode Auto aktif
                        if CONFIG.KillerAuto and not killerAutoActive then
                            -- Simpan roundId saat timer dimulai
                            -- Saat timer callback jalan, cek apakah roundId masih sama
                            -- Kalau sudah berganti = ronde sudah selesai = abaikan
                            local timerRoundId = roundId
                            task.delay(CONFIG.KillerAutoDelay or 300, function()
                                -- Jika roundId sudah berubah, callback ini dari ronde lama → abaikan
                                if roundId ~= timerRoundId then return end
                                -- Cek langsung posisi duduk (hum.Sit) saat timer habis
                                -- Jika sudah berdiri = ronde selesai = jangan aktifkan
                                local stillSitting = false
                                pcall(function()
                                    local char = Players.LocalPlayer and Players.LocalPlayer.Character
                                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                                    if hum then stillSitting = hum.Sit end
                                end)
                                if CONFIG.KillerAuto and stillSitting and not killerAutoActive and roundId == timerRoundId then
                                    killerAutoActive = true
                                    CONFIG.KillerMode = true
                                    pcall(function() setKillerManualToggle(true) end)
                                    local mins = math.floor((CONFIG.KillerAutoDelay or 300) / 60)
                                    Notify("🔪 Killer Auto ON", "Sudah " .. mins .. " menit bermain — Killer Mode aktif!", 6)
                                end
                            end)
                        end
                    end
                    task.spawn(function()
                        pcall(function()
                            -- #2: Think delay random range
                            local tMin = CONFIG.ThinkDelayMin or 0.4
                            local tMax = CONFIG.ThinkDelayMax or 1.5
                            task.wait(tMin + math.random() * (tMax - tMin))
                            local turnNow, reqNow = GetTurn()
                            local wordNow = GetCurrentWord()
                            
                            if turnNow and wordNow == det and CONFIG.AutoPlay then
                                local best = FindBest(det, reqNow or req)
                                if best then
                                    local b = GetBox() if b then b:CaptureFocus() end
                                    task.wait(0.1)

                                    -- Expert ProType: fake mistake loop (berulang selama boost aktif)
                                    if CONFIG.Expert and expertBoosting and GetTurn() then
                                        local NEIGHBOR_KEYS = {
                                            a={"s","q","z"}, b={"v","n","g"}, c={"x","v","d"},
                                            d={"s","f","e","c"}, e={"w","r","d"}, f={"d","g","r","v"},
                                            g={"f","h","t","b"}, h={"g","j","y","n"}, i={"u","o","k"},
                                            j={"h","k","u","m"}, k={"j","l","i"}, l={"k","o","p"},
                                            m={"n","j","k"}, n={"b","m","h"}, o={"i","p","l"},
                                            p={"o","l"}, q={"w","a"}, r={"e","t","f"},
                                            s={"a","d","w","x"}, t={"r","y","g"}, u={"y","i","j"},
                                            v={"c","b","f"}, w={"q","e","s"}, x={"z","c","s"},
                                            y={"t","u","h"}, z={"a","x","s"}
                                        }
                                        local firstChar = best:sub(1,1):lower()
                                        local neighbors = NEIGHBOR_KEYS[firstChar] or {"a","s","d"}

                                        -- Loop fake mistake selama boost masih aktif (troll sengaja)
                                        local fakeStart = tick()
                                        local maxFakeTime = (CONFIG.ProTypeDurationMin + math.random() * (CONFIG.ProTypeDurationMax - CONFIG.ProTypeDurationMin)) * 0.6
                                        local iterCount = 0
                                        local maxIter = math.random(2, 5)

                                        while expertBoosting and GetTurn() and (tick() - fakeStart) < maxFakeTime and iterCount < maxIter do
                                            iterCount = iterCount + 1
                                            -- Ketik 1-N huruf salah (N dari config)
                                            local mistakeMax = (CONFIG.ProTypeMistakeMax and CONFIG.ProTypeMistakeMax >= 1) and CONFIG.ProTypeMistakeMax or 2
                                            local mistakeCount = math.random(1, mistakeMax)
                                            local mistakeChars = {}
                                            for mi = 1, mistakeCount do
                                                if not GetTurn() or not expertBoosting then break end
                                                local randomNeighbor = neighbors[math.random(#neighbors)]
                                                SimKey(randomNeighbor)
                                                table.insert(mistakeChars, randomNeighbor)
                                                task.wait(CalculateDelay(mi == 1 and nil or mistakeChars[mi-1], randomNeighbor))
                                            end
                                            -- Langsung hapus tanpa pause
                                            DoBackspace(#mistakeChars)
                                        end
                                    end

                                    -- #7: Per-kata micro CPM drift sebelum mulai ketik
                                    pcall(function()
                                        local d = CONFIG.CPMDrift or 0
                                        if d > 0 then
                                            driftCPM = driftCPM + math.random(-d, d)
                                            driftCPM = math.max(-d * 3, math.min(d * 3, driftCPM))
                                        end
                                    end)
                                    local miss = (best:sub(1, #det) == det) and best:sub(#det + 1) or best
                                    if best:sub(1, #det) ~= det then DoBackspace(#det) end
                                    
                                    local l = nil
                                    for i=1, #miss do
                                        if not GetTurn() then break end
                                        local bb = GetBox() if bb then bb:CaptureFocus() end
                                        local ch = miss:sub(i, i)
                                        SimKey(ch)
                                        task.wait(CalculateDelay(l, ch))
                                        l = ch
                                    end
                                    
                                    -- #5: Submit timing random (main path)
                                    do local sMin = CONFIG.SubmitDelayMin or 0.05; local sMax = CONFIG.SubmitDelayMax or 0.20
                                       task.wait(sMin + math.random() * (sMax - sMin)) end
                                    if GetTurn() then
                                        local bb = GetBox() if bb then bb:CaptureFocus() end
                                        SimKey(Enum.KeyCode.Return)
                                        
                                        local verifyStart = tick()
                                        local accepted = false
                                        while (tick() - verifyStart) < 1.5 do
                                            -- Kata diterima = giliran kita selesai (GetTurn false)
                                            if not GetTurn() then
                                                accepted = true
                                                break
                                            end
                                            -- Juga cek apakah kata di display sudah berubah/reset (konfirmasi visual)
                                            local currentCheck, isCensored = GetCurrentWord()
                                            if isCensored then
                                                accepted = true
                                                break
                                            end
                                            task.wait(0.05)
                                        end
                                        
                                        if accepted then
                                            AddToUsedWordCache(best)
                                        else
                                            -- Kata masih di layar + giliran masih aktif = DITOLAK server
                                            task.wait(0.2)
                                            local alreadyUsed = IsAlreadyUsed()
                                            if alreadyUsed then
                                                -- Kata sudah digunakan (ronde ini saja) → hanya SessionBlacklist
                                                -- TIDAK masuk failed.txt / Blacklist permanen
                                                AddToUsedWordCache(best)
                                                SessionBlacklist[best] = true
                                            else
                                                -- Kata ditolak server (bukan "Sudah Digunakan") → masuk failed.txt
                                                AddToFailedCache(best, Blacklist)
                                                SessionBlacklist[best] = true
                                                if CONFIG.Expert and expertBoosting then
                                                    expertBoosting = false
                                                    expertCPM = CONFIG.CPM
                                                end
                                            end
                                            DoBackspace(#best + 5)

                                            -- === RETRY LOOP: cari kata lain sampai giliran benar-benar habis ===
                                            while GetTurn() and CONFIG.AutoPlay do
                                                local rTurn, rReq = GetTurn()
                                                if not rTurn then break end
                                                local rDet = GetCurrentWord()
                                                local altBest = FindBest(rDet ~= "" and rDet or (rReq or req), rReq or req)
                                                if not altBest then break end -- tidak ada kata lagi → biarkan waktu habis

                                                -- Ketik kata baru langsung
                                                local rb = GetBox() if rb then rb:CaptureFocus() end
                                                task.wait(0.05)
                                                local submitted = TypeWordDirect(altBest, rDet)
                                                if not submitted then break end

                                                -- Verifikasi
                                                local accepted2 = VerifySubmission(altBest, rDet)
                                                if accepted2 then
                                                    AddToUsedWordCache(altBest)
                                                    break -- berhasil → selesai
                                                else
                                                    task.wait(0.2)
                                                    if IsAlreadyUsed() then
                                                        -- Sudah digunakan → hanya SessionBlacklist
                                                        AddToUsedWordCache(altBest)
                                                        SessionBlacklist[altBest] = true
                                                    else
                                                        -- Kata invalid (server reject, tanpa "Sudah Digunakan") → failed.txt
                                                        AddToFailedCache(altBest, Blacklist)
                                                        SessionBlacklist[altBest] = true
                                                        if CONFIG.Expert and expertBoosting then
                                                            expertBoosting = false
                                                            expertCPM = CONFIG.CPM
                                                        end
                                                    end
                                                    DoBackspace(#altBest + 5)
                                                    -- lanjut loop cari kata berikutnya
                                                end
                                            end
                                            -- === AKHIR RETRY LOOP ===
                                        end
                                    end
                                end
                            end
                        end)
                        isTyping = false
                    end)
                end
            end
        end
    end)

    -- Anti-AFK: bergerak setiap 5 menit jika tidak duduk
    task.spawn(function()
        local vu = game:GetService("VirtualUser")
        while task.wait(300) do
            if unloaded then break end
            if not CONFIG.AntiAFK then continue end
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and not hum.Sit then
                    hum.Jump = true
                    task.wait(0.5)
                    hum:MoveTo(hrp.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
                elseif hum and hrp and hum.Sit then
                    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                end
            end)
        end
    end)

    task.spawn(function()
        local debounce = false
        while task.wait(2) do
            if unloaded then break end
            if not CONFIG.AutoJoin or debounce then continue end
            local w1, w4, wk, wi = CONFIG.AutoJoinSettings._1v1, CONFIG.AutoJoinSettings._4p, CONFIG.AutoJoinSettings.kosong, CONFIG.AutoJoinSettings.isi
            if not w1 and not w4 then continue end

            local char = Players.LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Sit then continue end
            local tf = workspace:FindFirstChild("Tables")
            if not tf then continue end

            -- Cek danger player sebelum join — skip jika ada ancaman di server
            local hasDanger = false
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == Players.LocalPlayer then continue end
                    if DANGER_USERNAMES[p.Name] or DANGER_USERNAMES[p.DisplayName] then hasDanger = true break end
                    if p.UserId == game.CreatorId then hasDanger = true break end
                    local stats = p:FindFirstChild("leaderstats")
                    if stats then
                        for _, stat in ipairs(stats:GetChildren()) do
                            local sName = string.lower(stat.Name)
                            if sName == "wins" or sName == "losses" then
                                local val = tonumber((string.gsub(tostring(stat.Value), "[,%.KMB]", ""))) or 0
                                if val > CONFIG.WinsThreshold then hasDanger = true break end
                            end
                        end
                    end
                    if hasDanger then break end
                end
            end)
            if hasDanger then continue end

            local bestTable = nil
            for _, tm in ipairs(tf:GetChildren()) do
                if (tm.Name:match("Table_2P") and w1) or (tm.Name:match("Table_4P") and w4) then
                    local tp = tm:FindFirstChild("TablePart")
                    local prm = tp and tp:FindFirstChildOfClass("ProximityPrompt")
                    if prm and prm.Enabled then
                        local lbl = tp:FindFirstChildOfClass("BillboardGui") and tp:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
                        if lbl and not lbl.Text:match("Starting") then
                            local c, m = lbl.Text:match("(%d+)/(%d+)")
                            if c and m then
                                c, m = tonumber(c), tonumber(m)
                                if c < m and ((c == 0 and wk) or (c > 0 and wi)) then
                                    bestTable = { part = tp, prompt = prm }
                                    if c > 0 then break end
                                end
                            end
                        end
                    end
                end
            end

            if bestTable then
                debounce = true
                if char:FindFirstChild("Humanoid") then pcall(function() char.Humanoid.Jump = true char.Humanoid:MoveTo(char.HumanoidRootPart.Position + Vector3.new(math.random(-3,3),0,math.random(-3,3))) end) task.wait(0.3) end
                char.HumanoidRootPart.CFrame = CFrame.new(bestTable.part.Position + Vector3.new(0, 7, 0))
                task.wait(0.5)
                if bestTable.prompt.Parent and bestTable.prompt.Enabled then
                    if fireproximityprompt then fireproximityprompt(bestTable.prompt) else
                        bestTable.prompt:InputHoldBegin() task.wait(bestTable.prompt.HoldDuration + 0.1) bestTable.prompt:InputHoldEnd()
                    end
                end
                task.wait(5)
                debounce = false
            end
        end
    end)

    -- ===== AUTO LEAVE IF ALONE =====
    -- Jika lawan leave saat kita duduk di meja, dan game belum dimulai dalam N detik,
    -- maka klik tombol Leave otomatis agar tidak membuang waktu.
    -- Deteksi: LeaveGui visible + kita duduk + sendirian + game belum mulai.
    task.spawn(function()
        -- State untuk mencegah trigger berulang
        local aloneTimer = nil       -- tick() saat pertama kali terdeteksi sendirian
        local leaveFired = false     -- sudah klik Leave di sesi ini?
        local lastSitState = false   -- status duduk sesi sebelumnya

        -- Helper: cek apakah LeaveGui aktif (kita sedang dalam antrian meja / lobby meja)
        local function IsLeaveGuiVisible()
            local result = false
            pcall(function()
                local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
                if not gui then return end
                local leaveGui = gui:FindFirstChild("LeaveGui", true)
                if leaveGui then
                    -- LeaveGui bisa berupa ScreenGui atau Frame; cek Enabled dan Visible
                    if leaveGui:IsA("ScreenGui") then
                        result = leaveGui.Enabled
                    else
                        result = leaveGui.Visible
                    end
                end
            end)
            return result
        end

        -- Helper: cari dan klik tombol Leave di GUI manapun
        local function ClickLeaveButton()
            local clicked = false
            pcall(function()
                local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
                if not gui then return end
                for _, obj in ipairs(gui:GetDescendants()) do
                    if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
                        local txt = ""
                        if obj:IsA("TextButton") and obj.Text then txt = obj.Text:lower() end
                        if #txt == 0 then
                            for _, child in ipairs(obj:GetChildren()) do
                                if child:IsA("TextLabel") and child.Visible and #child.Text > 0 then
                                    txt = child.Text:lower() break
                                end
                            end
                        end
                        -- Cocokkan tombol "Leave" (atau "Keluar", "Tinggalkan")
                        if txt:find("leave") or txt:find("keluar") or txt:find("tinggalkan") then
                            -- Juga pastikan bukan tombol Invite
                            if not txt:find("invite") then
                                pcall(function() obj.MouseButton1Down:Fire() end)
                                task.wait(0.05)
                                pcall(function() obj.MouseButton1Up:Fire() end)
                                pcall(function() obj.MouseButton1Click:Fire() end)
                                -- Alternatif: fire LeaveTable remote jika tombol tidak responsif
                                task.wait(0.3)
                                pcall(function()
                                    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes", true)
                                    if remote then
                                        local leaveRemote = remote:FindFirstChild("LeaveTable")
                                        if leaveRemote and leaveRemote:IsA("RemoteEvent") then
                                            leaveRemote:FireServer()
                                        end
                                    end
                                end)
                                clicked = true
                                break
                            end
                        end
                    end
                end
            end)
            return clicked
        end

        -- Helper: hitung berapa pemain (selain kita) yang juga duduk di meja yang sama
        local function CountOpponentsAtTable()
            local count = 0
            pcall(function()
                local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
                local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then return end

                for _, p in ipairs(Players:GetPlayers()) do
                    if p == Players.LocalPlayer then continue end
                    local pChar = p.Character
                    local pHum  = pChar and pChar:FindFirstChildOfClass("Humanoid")
                    if pHum and pHum.Sit then
                        -- Hitung lawan yang duduk sebagai indikasi sedang di meja
                        count = count + 1
                    end
                end
            end)
            return count
        end

        while task.wait(0.5) do
            if unloaded then break end
            if not CONFIG.AutoLeaveAlone then
                -- Fitur dimatikan: reset state
                aloneTimer = nil
                leaveFired = false
                lastSitState = false
                continue
            end

            local isSitting = false
            pcall(function()
                local char = Players.LocalPlayer and Players.LocalPlayer.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum then isSitting = hum.Sit end
            end)

            -- Reset state jika kita berdiri (sudah leave atau game selesai)
            if not isSitting then
                aloneTimer  = nil
                leaveFired  = false
                lastSitState = false
                continue
            end

            -- Baru saja duduk → reset timer
            if isSitting and not lastSitState then
                aloneTimer  = nil
                leaveFired  = false
            end
            lastSitState = isSitting

            -- Jika sudah Leave di sesi ini, jangan klik lagi
            if leaveFired then continue end

            -- Cek apakah LeaveGui aktif (kita di lobby meja, belum mulai)
            local leaveGuiActive = IsLeaveGuiVisible()
            if not leaveGuiActive then
                -- LeaveGui tidak ada → game mungkin sudah mulai atau kita belum duduk di meja yang benar
                aloneTimer = nil
                continue
            end

            -- Cek apakah sendirian (tidak ada lawan yang duduk)
            local opponentCount = CountOpponentsAtTable()
            if opponentCount > 0 then
                -- Ada lawan → reset timer, tidak perlu leave
                aloneTimer = nil
                continue
            end

            -- Kita duduk sendirian di meja, LeaveGui aktif
            if aloneTimer == nil then
                aloneTimer = tick()
                Notify("⏳ Sendirian", "Duduk sendirian terdeteksi. Auto leave dalam " .. tostring(CONFIG.AutoLeaveAloneDelay) .. " detik jika game belum mulai.", 5)
            end

            local elapsed = tick() - aloneTimer
            if elapsed >= CONFIG.AutoLeaveAloneDelay then
                -- Waktu habis, coba klik Leave
                Notify("🚪 Auto Leave", "Sudah sendirian " .. math.floor(elapsed) .. "s. Mengklik Leave...", 5)
                local ok = ClickLeaveButton()
                if ok then
                    leaveFired = true
                    aloneTimer = nil
                    Notify("✅ Leave Sukses", "Berhasil meninggalkan meja.", 4)
                else
                    -- Tombol tidak ditemukan, coba langsung fire remote
                    pcall(function()
                        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes", true)
                        if remote then
                            local leaveRemote = remote:FindFirstChild("LeaveTable")
                            if leaveRemote and leaveRemote:IsA("RemoteEvent") then
                                leaveRemote:FireServer()
                                leaveFired = true
                                aloneTimer = nil
                                Notify("✅ Leave (Remote)", "LeaveTable remote dikirim langsung.", 4)
                            end
                        end
                    end)
                    if not leaveFired then
                        Notify("⚠ Leave Gagal", "Tombol Leave tidak ditemukan!", 5)
                        aloneTimer = tick() -- reset timer agar coba lagi 15 detik kemudian
                    end
                end
            end
        end
    end)

    -- ===== AUTO TELEPORT GUEST — Server Queue System =====
    -- Logika: ambil 25 server sekaligus, simpan ke file, teleport satu per satu.
    -- Pointer maju terus; jika habis, fetch batch baru. File persist antar sesi.
    local SQ_FILE = "server_queue.json"

    local function SQ_Load()
        if not (isfile and isfile(SQ_FILE)) then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SQ_FILE)) end)
        if ok and data and type(data.servers) == "table" and type(data.pointer) == "number" then
            return data
        end
        return nil
    end

    local function SQ_Save(data)
        if writefile then pcall(function() writefile(SQ_FILE, HttpService:JSONEncode(data)) end) end
    end

    local function SQ_FetchBatch()
        local ok, res = pcall(function()
            return request({
                Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=25",
                Method = "GET"
            })
        end)
        if not (ok and res and res.Body) then return nil end
        local dok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if not (dok and data and data.data) then return nil end
        local servers = {}
        for _, s in ipairs(data.data) do
            -- Exclude server saat ini
            if s.id ~= game.JobId then
                table.insert(servers, {
                    id      = s.id,
                    playing = s.playing or 0,
                    maxPlayers = s.maxPlayers or 0
                })
            end
        end
        -- Urutkan dari yang paling ramai
        table.sort(servers, function(a, b) return a.playing > b.playing end)
        return (#servers > 0) and servers or nil
    end

    task.spawn(function()
        local isTeleporting = false
        while task.wait(2) do
            if unloaded then break end
            if not CONFIG.AutoTeleportGuest or isTeleporting then continue end

            -- ── Deteksi kondisi buruk ──────────────────────────────────────
            local dangerPlayer = nil
            local dangerReason = ""
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Players.LocalPlayer then
                    local stats = p:FindFirstChild("leaderstats")
                    local winsVal, lossesVal = 0, 0
                    if stats then
                        for _, stat in ipairs(stats:GetChildren()) do
                            local sName = string.lower(stat.Name)
                            if sName == "wins" then
                                winsVal = tonumber((string.gsub(tostring(stat.Value), "[,%.KMB]", ""))) or 0
                            elseif sName == "losses" then
                                lossesVal = tonumber((string.gsub(tostring(stat.Value), "[,%.KMB]", ""))) or 0
                            end
                        end
                    end
                    local isDangerUser = DANGER_USERNAMES[p.Name] or DANGER_USERNAMES[p.DisplayName]
                    local isCreator    = (p.UserId == game.CreatorId)
                    local hasHighStats = (winsVal > CONFIG.WinsThreshold) or (lossesVal > CONFIG.LossesThreshold)
                    if isDangerUser then
                        dangerPlayer = p
                        dangerReason = "USERNAME DIBLOKIR: " .. p.Name
                        break
                    elseif isCreator then
                        dangerPlayer = p
                        dangerReason = "OWNER / DEVELOPER GAME!"
                        break
                    elseif hasHighStats then
                        dangerPlayer = p
                        dangerReason = "STATISTIK TINGGI (W:" .. winsVal .. " L:" .. lossesVal .. ")"
                        break
                    end
                end
            end

            local playerCount = #Players:GetPlayers()
            local isSepi = (playerCount < CONFIG.MinServerPlayers)

            if not dangerPlayer and not isSepi then continue end

            -- ── Trigger notifikasi ─────────────────────────────────────────
            isTeleporting = true
            local triggerText
            if dangerPlayer then
                triggerText = "Menghindari: " .. dangerPlayer.Name .. "\nAlasan: " .. dangerReason
            else
                triggerText = "Server sepi (" .. playerCount .. " player)\nMencari server berikutnya..."
            end
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "⚠ AUTO TELEPORT ⚠",
                    Text  = triggerText,
                    Duration = 8
                })
            end)

            task.spawn(function()
                task.wait(1)

                -- ── Muat queue dari file ───────────────────────────────────
                local queue = SQ_Load()
                local needNewBatch = (not queue) or (queue.pointer >= #queue.servers)

                if needNewBatch then
                    -- Semua server di batch lama sudah dilewati → ambil batch baru
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("SendNotification", {
                            Title = "🔄 SERVER QUEUE",
                            Text  = "Batch habis. Mengambil 25 server baru...",
                            Duration = 5
                        })
                    end)
                    task.wait(0.5)
                    local fresh = SQ_FetchBatch()
                    if fresh then
                        queue = { servers = fresh, pointer = 0 }
                        SQ_Save(queue)
                    else
                        -- Gagal fetch → coba lagi nanti
                        pcall(function()
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "❌ SERVER QUEUE",
                                Text  = "Gagal mengambil daftar server. Coba lagi...",
                                Duration = 5
                            })
                        end)
                        task.wait(5)
                        isTeleporting = false
                        return
                    end
                end

                -- ── Ambil server berikutnya dari queue ────────────────────
                local idx          = queue.pointer + 1   -- Lua 1-based
                local targetServer = queue.servers[idx]
                local totalServers = #queue.servers

                -- Maju pointer & simpan (tandai server ini sudah "dipakai")
                queue.pointer = queue.pointer + 1
                SQ_Save(queue)

                if targetServer then
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("SendNotification", {
                            Title = "🚀 TELEPORT " .. queue.pointer .. "/" .. totalServers,
                            Text  = "Berpindah ke server #" .. queue.pointer
                                    .. "\n(" .. (targetServer.playing or 0) .. " pemain aktif)",
                            Duration = 8
                        })
                    end)
                    task.wait(1)
                    local execPayload = 'loadstring(game:HttpGet("https://find.wagate.biz.id/settele2.lua"))()'
                    if queue_on_teleport then
                        queue_on_teleport(execPayload)
                    elseif syn and syn.queue_on_teleport then
                        syn.queue_on_teleport(execPayload)
                    end
                    game:GetService("TeleportService"):TeleportToPlaceInstance(
                        game.PlaceId, targetServer.id, Players.LocalPlayer
                    )
                    task.wait(5)
                else
                    -- Indeks diluar range (tidak terduga), reset file
                    if isfile and isfile(SQ_FILE) then pcall(function() delfile(SQ_FILE) end) end
                end

                isTeleporting = false
            end)
        end
    end)

    -- Auto klik tombol Play → Close setelah pertandingan selesai (jika tidak ada danger)
    task.spawn(function()
        while task.wait(1) do
            if unloaded then break end
            if not CONFIG.AutoTeleportGuest then continue end

            -- Hanya klik jika server aman (tidak ada danger player)
            local hasDangerNow = false
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == Players.LocalPlayer then continue end
                    if DANGER_USERNAMES[p.Name] or DANGER_USERNAMES[p.DisplayName] then hasDangerNow = true break end
                    if p.UserId == game.CreatorId then hasDangerNow = true break end
                    local stats = p:FindFirstChild("leaderstats")
                    if stats then
                        for _, stat in ipairs(stats:GetChildren()) do
                            local sName = string.lower(stat.Name)
                            if sName == "wins" or sName == "losses" then
                                local val = tonumber((string.gsub(tostring(stat.Value), "[,%.KMB]", ""))) or 0
                                if val > CONFIG.WinsThreshold then hasDangerNow = true break end
                            end
                        end
                    end
                    if hasDangerNow then break end
                end
            end)
            if hasDangerNow then continue end

            pcall(function()
                local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
                if not gui then return end

                -- Helper: simulasi klik robust
                local function ClickButton(btn)
                    pcall(function() btn.MouseButton1Down:Fire() end)
                    task.wait(0.05)
                    pcall(function() btn.MouseButton1Up:Fire() end)
                    pcall(function() btn.MouseButton1Click:Fire() end)
                end

                -- Helper: ambil teks dari button (TextButton/ImageButton + child TextLabel)
                local function GetButtonText(obj)
                    local txt = ""
                    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                        -- Cek text langsung di button
                        if obj:IsA("TextButton") and obj.Text and #obj.Text > 0 then
                            txt = obj.Text
                        end
                        -- Cek child TextLabel jika text kosong
                        if #txt == 0 then
                            for _, child in ipairs(obj:GetChildren()) do
                                if child:IsA("TextLabel") and child.Visible and #child.Text > 0 then
                                    txt = child.Text
                                    break
                                end
                            end
                        end
                    end
                    return txt:lower():gsub("%s+", "")
                end

                -- Cari tombol PLAY
                local playBtn = nil
                for _, obj in ipairs(gui:GetDescendants()) do
                    if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and obj.Active then
                        local txt = GetButtonText(obj)
                        if txt:find("play") then
                            playBtn = obj
                            break
                        end
                    end
                end

                if playBtn then
                    ClickButton(playBtn)
                    task.wait(2)
                    -- Setelah klik Play, cari tombol Close
                    for _, obj2 in ipairs(gui:GetDescendants()) do
                        if (obj2:IsA("TextButton") or obj2:IsA("ImageButton")) and obj2.Visible and obj2.Active then
                            local txt2 = GetButtonText(obj2)
                            if txt2:find("close") or txt2:find("tutup") then
                                ClickButton(obj2)
                                break
                            end
                        end
                    end
                end
            end)

        end
    end)
end

-- ===========================================
-- LOST MODE LOGIC
-- ===========================================

local function LoadLostMode()
    local unloaded = false
    table.insert(cleanupTasks, function() unloaded = true end)
    
    local Config = { AutoJoin = false, AutoJoinSettings = { _1v1 = false, _4p = false, kosong = true, isi = false }, LostMode = false }
    if isfile and isfile("LostMode_ConfigV2.json") then
        pcall(function()
            local d = HttpService:JSONDecode(readfile("LostMode_ConfigV2.json"))
            if d then for k,v in pairs(d) do Config[k] = v end end
        end)
    end
    local function SaveConfig() if writefile then writefile("LostMode_ConfigV2.json", HttpService:JSONEncode(Config)) end end

    local logDetected, logReq, turnExp = false, "", 0
    local logConn = LogService.MessageOut:Connect(function(msg)
        local wp, tp = msg:match("Word:%s*([A-Za-z]+)%s+Time to respond:%s*(%d+)")
        if wp and tp then logDetected, logReq, turnExp = true, wp, tick() + tonumber(tp) end
    end)
    table.insert(cleanupTasks, function() if logConn then logConn:Disconnect() end end)

    local function GetTurn()
        if logDetected then if tick() < turnExp then return true else logDetected = false end end
        local g = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local f = g and g:FindFirstChild("WordServerFrame", true)
        if f and f.Visible then
            local l = f:FindFirstChild("WordServer")
            if l and #l.Text > 0 then
                local c = l.Text:lower():match("([a-z])")
                if c then
                    local w = g:FindFirstChild("WordSubmit", true)
                    if w then for _, cc in ipairs(w:GetChildren()) do if cc.Name=="Word" and cc:IsA("TextLabel") and cc.Visible then return true end end end
                end
            end
        end
        return false
    end

    local Gui, Content = CreateMainHUD("Lost Mode V2")
    
    local StatusLbl = Instance.new("TextLabel", Content)
    StatusLbl.Size, StatusLbl.Text, StatusLbl.Font, StatusLbl.TextSize, StatusLbl.TextColor3 = UDim2.new(1, 0, 0, 16), "Status: Idle", Enum.Font.Gotham, 11, Color3.fromRGB(150, 150, 160)
    StatusLbl.BackgroundTransparency, StatusLbl.TextXAlignment, StatusLbl.LayoutOrder = 1, Enum.TextXAlignment.Left, 1

    local _, _ = MakeToggle(Content, "Auto Join", 10, Config.AutoJoin, function(v) Config.AutoJoin=v SaveConfig() end)
    MakeCheckbox(Content, "Join 1v1", 11, Config.AutoJoinSettings._1v1, function(v) Config.AutoJoinSettings._1v1=v SaveConfig() end)
    MakeCheckbox(Content, "Join 4P", 12, Config.AutoJoinSettings._4p, function(v) Config.AutoJoinSettings._4p=v SaveConfig() end)
    MakeCheckbox(Content, "Kosong (0 Players)", 13, Config.AutoJoinSettings.kosong, function(v) Config.AutoJoinSettings.kosong=v SaveConfig() end)
    MakeCheckbox(Content, "Isi (Has Players)", 14, Config.AutoJoinSettings.isi, function(v) Config.AutoJoinSettings.isi=v SaveConfig() end)
    MakeToggle(Content, "Force Lose Mode", 20, Config.LostMode, function(v) Config.LostMode=v SaveConfig() end)

    task.spawn(function()
        local debounce = false
        while task.wait(2) do
            if unloaded then break end
            if not Config.AutoJoin or debounce then continue end
            local w1, w4, wk, wi = Config.AutoJoinSettings._1v1, Config.AutoJoinSettings._4p, Config.AutoJoinSettings.kosong, Config.AutoJoinSettings.isi
            if not w1 and not w4 then continue end

            local char = Players.LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local tf = workspace:FindFirstChild("Tables")
            if not tf then continue end

            local bestTable = nil
            for _, tm in ipairs(tf:GetChildren()) do
                if (tm.Name:match("Table_2P") and w1) or (tm.Name:match("Table_4P") and w4) then
                    local tp = tm:FindFirstChild("TablePart")
                    local prm = tp and tp:FindFirstChildOfClass("ProximityPrompt")
                    if prm and prm.Enabled then
                        local lbl = tp:FindFirstChildOfClass("BillboardGui") and tp:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
                        if lbl and not lbl.Text:match("Starting") then
                            local c, m = lbl.Text:match("(%d+)/(%d+)")
                            if c and m then
                                c, m = tonumber(c), tonumber(m)
                                if c < m and ((c == 0 and wk) or (c > 0 and wi)) then
                                    bestTable = { part = tp, prompt = prm }
                                    if c > 0 then break end
                                end
                            end
                        end
                    end
                end
            end

            if bestTable then
                debounce = true
                StatusLbl.Text, StatusLbl.TextColor3 = "Status: Joining...", Color3.fromRGB(240, 180, 50)
                if char:FindFirstChild("Humanoid") then pcall(function() char.Humanoid.Jump = true char.Humanoid:MoveTo(char.HumanoidRootPart.Position + Vector3.new(math.random(-3,3),0,math.random(-3,3))) end) task.wait(0.3) end
                char.HumanoidRootPart.CFrame = CFrame.new(bestTable.part.Position + Vector3.new(0, 7, 0))
                task.wait(0.5)
                if bestTable.prompt.Parent and bestTable.prompt.Enabled then
                    if fireproximityprompt then fireproximityprompt(bestTable.prompt) else
                        bestTable.prompt:InputHoldBegin() task.wait(bestTable.prompt.HoldDuration + 0.1) bestTable.prompt:InputHoldEnd()
                    end
                end
                StatusLbl.Text, StatusLbl.TextColor3 = "Status: Joined!", Color3.fromRGB(90, 200, 110)
                task.wait(5)
                debounce = false
                StatusLbl.Text, StatusLbl.TextColor3 = "Status: Idle", Color3.fromRGB(150, 150, 160)
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if unloaded then break end
            pcall(function()
                if Config.LostMode then 
                    local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    local myTurn = GetTurn()
                    local sit = hum and hum.Sit
                    
                    if sit and myTurn then
                        StatusLbl.Text, StatusLbl.TextColor3 = "Lost Mode: Executing...", Color3.fromRGB(250, 80, 80)
                        if hum.Health > 0 then hum.Health = 0 end
                        task.wait(4)
                    elseif sit then
                        StatusLbl.Text, StatusLbl.TextColor3 = "Lost Mode: Waiting Turn", Color3.fromRGB(150, 150, 160)
                    elseif StatusLbl.Text:match("Lost Mode") then
                        StatusLbl.Text, StatusLbl.TextColor3 = "Status: Idle", Color3.fromRGB(150, 150, 160)
                    end
                elseif StatusLbl.Text:match("Lost Mode") then
                    StatusLbl.Text, StatusLbl.TextColor3 = "Status: Idle", Color3.fromRGB(150, 150, 160)
                end
            end)
        end
    end)
end

-- ===========================================
-- ANTI AFK MODE LOGIC
-- ===========================================
local function LoadAntiAFKMode()
    local unloaded = false
    table.insert(cleanupTasks, function() unloaded = true end)
    
    local Gui, Content = CreateMainHUD("Anti AFK Mode")
    
    local StatusLbl = Instance.new("TextLabel", Content)
    StatusLbl.Size, StatusLbl.Text, StatusLbl.Font, StatusLbl.TextSize, StatusLbl.TextColor3 = UDim2.new(1, 0, 0, 16), "Status: Active (Moving)", Enum.Font.Gotham, 11, Color3.fromRGB(90, 200, 110)
    StatusLbl.BackgroundTransparency, StatusLbl.TextXAlignment, StatusLbl.LayoutOrder = 1, Enum.TextXAlignment.Left, 1

    task.spawn(function()
        local vu = game:GetService("VirtualUser")
        while task.wait(300) do -- 5 Menit
            if unloaded then break end
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                if hum and hrp and not hum.Sit then
                    hum.Jump = true
                    task.wait(0.5)
                    hum:MoveTo(hrp.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
                elseif hum and hrp and hum.Sit then
                    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                end
            end)
        end
    end)
end

-- ===========================================
-- SELECTION GUI
-- ===========================================
local function Init()
    local SelectGui = Instance.new("ScreenGui")
    SelectGui.Name = "ModeSelectGui_" .. tostring(math.random(1000, 9999))
    SelectGui.Parent = gethui()
    SelectGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    table.insert(cleanupTasks, function() if SelectGui and SelectGui.Parent then SelectGui:Destroy() end end)

    local Frame = Instance.new("Frame", SelectGui)
    Frame.Size, Frame.Position, Frame.BackgroundColor3, Frame.ClipsDescendants = UDim2.new(0, 260, 0, 184), UDim2.new(0.5, -130, 0.5, -92), Color3.fromRGB(22, 22, 27), true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", Frame).Color = Color3.fromRGB(60, 60, 75)

    local Topbar = Instance.new("Frame", Frame)
    Topbar.Size, Topbar.BackgroundColor3 = UDim2.new(1, 0, 0, 36), Color3.fromRGB(28, 28, 34)
    Instance.new("UICorner", Topbar).CornerRadius = UDim.new(0, 8)
    local Fix = Instance.new("Frame", Topbar)
    Fix.Size, Fix.Position, Fix.BackgroundColor3, Fix.BorderSizePixel = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 1, -10), Color3.fromRGB(28, 28, 34), 0
    MakeDraggable(Topbar, Frame)

    local Title = Instance.new("TextLabel", Topbar)
    Title.Size, Title.Position, Title.Text, Title.Font, Title.TextSize, Title.TextColor3, Title.BackgroundTransparency, Title.TextXAlignment = UDim2.new(1, -40, 1, 0), UDim2.new(0, 12, 0, 0), "Select Mode V2", Enum.Font.GothamBold, 13, Color3.fromRGB(240, 240, 250), 1, Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", Topbar)
    CloseBtn.Size, CloseBtn.Position, CloseBtn.Text, CloseBtn.Font, CloseBtn.TextSize, CloseBtn.TextColor3, CloseBtn.BackgroundTransparency = UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 3), "×", Enum.Font.GothamBold, 20, Color3.fromRGB(250, 80, 80), 1
    CloseBtn.MouseButton1Click:Connect(function() _G.SambungKataUnload_V2() end)

    local function CreateMainBtn(text, yOff, bgColor, callback)
        local btn = Instance.new("TextButton", Frame)
        btn.Size, btn.Position, btn.BackgroundColor3, btn.Text, btn.Font, btn.TextSize, btn.TextColor3 = UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, yOff), bgColor, text, Enum.Font.GothamBold, 12, Color3.fromRGB(255, 255, 255)
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseEnter:Connect(function() UI_Tween(btn, {BackgroundColor3 = bgColor:Lerp(Color3.new(1,1,1), 0.1)}, 0.2) end)
        btn.MouseLeave:Connect(function() UI_Tween(btn, {BackgroundColor3 = bgColor}, 0.2) end)
        btn.MouseButton1Click:Connect(function() SelectGui:Destroy() callback() end)
    end

    CreateMainBtn("🚀 WIN MODE", 48, Color3.fromRGB(70, 180, 90), LoadWinMode)
    CreateMainBtn("💀 LOST MODE", 92, Color3.fromRGB(200, 70, 80), LoadLostMode)
    CreateMainBtn("🛌 ANTI AFK MODE", 136, Color3.fromRGB(90, 150, 200), LoadAntiAFKMode)
end

LoadWinMode()
print("Sambung Kata V2 Loaded Successfully!")
