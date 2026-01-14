-- === LOGIKA HUMANIZATION & INPUT ===

-- Flag untuk reset saat mode Auto Blatant aktif (akan diatur oleh Loop Utama di Part 4)
local needsBlatantReset = false 

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

-- Fungsi Helper Timer untuk Panic Mode (Menggunakan referensi dari Part 1)
local function GetTimerSecondsHelper()
    -- Menggunakan logika yang sama dengan GetRemainingTime di Part 1
    -- Kita definisikan ulang disini untuk memastikan akses lokal di closure ini
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

    -- [3] CEK DUPLIKASI SEBELUM MENGETIK
    if UsedWords[targetWord] and not isCorrection then
        ShowToast("Already used!", "warning")
        StatusText.Text = "Skipped (Used): " .. targetWord
        return
    end

    isTyping = true
    lastTypingStart = tick()
    
    -- [4] SNAPSHOT STRIKES AWAL
    local initialStrikes = GetStrikeCount()
    
    local targetBox = GetGameTextBox()
    if targetBox then
        targetBox:CaptureFocus()
        task.wait(0.1)
    end
    
    StatusText.Text = "Typing..."
    StatusText.TextColor3 = THEME.Accent
    Tween(StatusDot, {BackgroundColor3 = THEME.Accent})

    local success, err = pcall(function()
        if isCorrection then
            -- Logika Koreksi (Backspace dan ketik ulang sebagian)
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

            -- Pre-submission verify
            local finalCheck = GetGameTextBox()
            if not riskyMistakes then
                task.wait(0.1)
                finalCheck = GetGameTextBox()
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
            
            -- Verifikasi Input
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
                -- Logika penanganan kegagalan (Blacklist vs UsedWords)
                local finalStrikes = GetStrikeCount()
                if finalStrikes > initialStrikes then
                    Blacklist[targetWord] = true
                    SaveBlacklist()
                    ShowToast("Invalid Word (Blacklisted)", "error")
                else
                    UsedWords[targetWord] = true
                    ShowToast("Already used!", "warning")
                end

                RandomPriority[targetWord] = nil
                for k, list in pairs(RandomOrderCache) do
                    for i = #list, 1, -1 do if list[i] == targetWord then table.remove(list, i) end end
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
                StatusText.Text = "Word Cleared (Corrected)"
                StatusText.TextColor3 = THEME.SubText
                local current = GetCurrentGameWord()
                if #current > 0 then Backspace(#current) end
                UsedWords[targetWord] = true
                isMyTurnLogDetected = false
                task.wait(0.2)
            end
        else
            -- LOGIKA UTAMA PENGETIKAN KATA BARU
            local missingPart = ""
            if targetWord:sub(1, #currentDetected) == currentDetected then
                missingPart = targetWord:sub(#currentDetected + 1)
            else
                missingPart = targetWord
            end

            local letters = "abcdefghijklmnopqrstuvwxyz"
            local panicModeActive = false -- Flag lokal untuk panic override
            
            for i = 1, #missingPart do
                -- [LOGIKA 1: AUTO BLATANT RESET]
                -- Jika trigger aktif (dari Loop Part 4), reset pengetikan
                if needsBlatantReset then
                    needsBlatantReset = false
                    local focused = UserInputService:GetFocusedTextBox()
                    if focused and focused:IsDescendantOf(game) and focused.TextEditable then
                        local len = #focused.Text
                        Backspace(len + 1) -- Hapus semua
                        task.wait(0.1)
                        isTyping = false 
                        -- Panggil ulang SmartType secara rekursif dengan mode bypass
                        return SmartType(targetWord, "", false, true)
                    end
                end

                if not bypassTurn and not GetTurnInfo() then
                     task.wait(0.05)
                     if not GetTurnInfo() then break end
                end

                -- [LOGIKA 2: PANIC OVERRIDE]
                -- Cek waktu, jika < 10 detik, abaikan error rate dan percepat
                local timer = GetTimerSecondsHelper()
                if timer and timer < 10 and (useHumanization or errorRate > 0) then
                    panicModeActive = true
                end

                local ch = missingPart:sub(i, i)
                
                -- Jika Panic Mode atau Blatant Mode aktif
                if panicModeActive or isBlatant then
                     SimulateKey(ch)
                     task.wait(0.005) -- Delay minimal
                else
                    -- Normal Humanize Logic dengan Error Rate
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
                        
                        -- Cek timer lagi sebelum menunggu lama
                        if GetTimerSecondsHelper() and GetTimerSecondsHelper() < 10 then
                             task.wait(0.05) -- Jangan menunggu jika waktu mepet
                        else
                             task.wait(realize)
                        end
                        
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
            end

            -- Pre-submission verify (Skip jika risky atau panic)
            if not riskyMistakes and not panicModeActive then
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

                local finalStrikes = GetStrikeCount()
                if finalStrikes > initialStrikes then
                    Blacklist[targetWord] = true
                    SaveBlacklist()
                    ShowToast("Invalid Word (Blacklisted)", "error")
                else
                    UsedWords[targetWord] = true
                    ShowToast("Already used!", "warning")
                end

                for k, list in pairs(RandomOrderCache) do
                    for i = #list, 1, -1 do if list[i] == targetWord then table.remove(list, i) end end
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
                StatusText.Text = "Verification Failed"
                StatusText.TextColor3 = THEME.Warning
                local current = GetCurrentGameWord()
                if #current > 0 then Backspace(#current) end
                UsedWords[targetWord] = true
                isMyTurnLogDetected = false
                task.wait(0.2)
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
            table.sort(matches, function(a, b)
                local sA = GetKillerScore(a)
                local sB = GetKillerScore(b)
                if sA == sB then return #a < #b end
                return sA > sB
            end)
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
                if not targetKeys[char] then targetKeys[char] = i end
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
end
