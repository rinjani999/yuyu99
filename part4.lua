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

local lastTypeVisible = false
local lastRequiredLetter = ""

local StatsData = {}

do
    local sf = Instance.new("Frame")
    sf.Name = "StatsFrame"
    sf.Size = UDim2.new(0, 120, 0, 60)
    sf.Position = UDim2.new(0.5, -60, 0, 10)
    sf.BackgroundColor3 = THEME.Background
    sf.Visible = false
    sf.Parent = ScreenGui
    EnableDragging(sf)
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", sf).Color = THEME.Accent
    StatsData.Frame = sf

    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, 0, 0, 25)
    st.Position = UDim2.new(0, 0, 0, 5)
    st.BackgroundTransparency = 1
    st.TextColor3 = THEME.Text
    st.Font = Enum.Font.GothamBold
    st.TextSize = 20
    st.Text = "--"
    st.Parent = sf
    StatsData.Timer = st

    local sc = Instance.new("TextLabel")
    sc.Size = UDim2.new(1, 0, 0, 20)
    sc.Position = UDim2.new(0, 0, 0, 30)
    sc.BackgroundTransparency = 1
    sc.TextColor3 = THEME.SubText
    sc.Font = Enum.Font.Gotham
    sc.TextSize = 12
    sc.Text = "Words: 0"
    sc.Parent = sf
    StatsData.Count = sc
end

runConn = RunService.RenderStepped:Connect(function()
    local success, err = pcall(function()
        local now = tick()
        local player = Players.LocalPlayer
        local gui = player and player:FindFirstChild("PlayerGui")
        local frame = gui and gui:FindFirstChild("InGame") and gui.InGame:FindFirstChild("Frame")

        if isTyping and (tick() - lastTypingStart) > 15 then
            isTyping = false
            isAutoPlayScheduled = false
            StatusText.Text = "Typing State Reset (Watchdog)"
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
                
                StatsData.Frame.Visible = true
                StatsData.Timer.Text = timeText
                if seconds and seconds < 3 then StatsData.Timer.TextColor3 = Color3.fromRGB(255, 80, 80)
                else StatsData.Timer.TextColor3 = THEME.Text end
                
                -- [4] AUTO BLATANT LOGIC (Diperbarui: Trigger < 7 Detik)
                if Config.Blatant == "Auto" then
                    if seconds and seconds < 7 then
                        if not isBlatant then -- Transisi dari OFF ke ON (Trigger)
                            isBlatant = true
                            if isTyping then
                                needsBlatantReset = true -- Flag global untuk mereset SmartType (Part 3)
                            end
                        end
                        StatusText.Text = "Auto Blatant Active! (< 7s)"
                        StatusText.TextColor3 = Color3.fromRGB(255, 100, 50)
                    else
                        isBlatant = false
                    end
                else
                    isBlatant = (Config.Blatant == true)
                end
            end
        else
            StatsData.Frame.Visible = false
        end

        local isMyTurn, requiredLetter = GetTurnInfo(frame)
        
        if (now - lastWordCheck) > 0.05 then
            cachedDetected, cachedCensored = GetCurrentGameWord(frame)
            lastWordCheck = now
        end
        local detected, censored = cachedDetected, cachedCensored
        
        -- [2] AUTO READ OPPONENT WORDS
        -- Membaca kata lawan yang valid dan memasukkannya ke cache UsedWords
        if detected ~= "" and not censored and not isMyTurn then
             if not UsedWords[detected] then
                 UsedWords[detected] = true
                 -- Opsional: visual feedback debug
                 -- StatusText.Text = "Cached Opponent: " .. detected
             end
        end

        -- Panic Save (Last second save)
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
                    StatusText.Text = "PANIC SAVE!"
                    StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
                    SmartType(bestWord, detected, false, true) -- true = bypass turn check
                end
            end
        end

        -- Auto Join Logic
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
        
        -- [1] AUTO CLEAR CACHE SETIAP RONDE
        if typeVisible and not lastTypeVisible then
            UsedWords = {}
            StatusText.Text = "New Round - Words Reset"
            StatusText.TextColor3 = THEME.Success
        end
        lastTypeVisible = typeVisible

        if censored then
            if StatusText.Text ~= "Word is Censored" then
                StatusText.Text = "Word is Censored"
                StatusText.TextColor3 = THEME.Warning
                Tween(StatusDot, {BackgroundColor3 = THEME.Warning})
                
                for _, btn in ipairs(ButtonCache) do btn.Visible = false end
                StatsData.Count.Text = "Words: 0"
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
            StatsData.Count.Text = "Words: " .. visCount .. "+"
        end

        if not isVisible then
            if StatusText.Text ~= "Not in Round" then
                StatusText.Text = "Not in Round"
                StatusText.TextColor3 = THEME.SubText
                Tween(StatusDot, {BackgroundColor3 = THEME.SubText})
                for _, btn in ipairs(ButtonCache) do btn.Visible = false end
                StatsData.Count.Text = "Words: 0"
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
                StatsData.Count.Text = "Words: " .. visCount .. "+"
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
                        StatusText.Text = "Completed: " .. detected .. " <font color=\"rgb(100,255,140)\">✓</font>"
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

        -- Auto Play Logic
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

inputConn = UserInputService.InputBegan:Connect(function(input)
    if unloaded then return end
    if input.KeyCode == TOGGLE_KEY then ScreenGui.Enabled = not ScreenGui.Enabled end
end)
