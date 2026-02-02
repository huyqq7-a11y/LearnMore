local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LP = game.Players.LocalPlayer
local Players = game:GetService("Players")

-- [[ 1. HỆ THỐNG CONFIG & FILE LƯU ]]
local FileName = "NekoHub_Islands_Advanced.json"
local Config = {
    -- Mining & Combat
    AutoTree = false, AutoRock = false, AutoFarm = false,
    BoxRadius = 12, WaveSteps = 30, WaveInterval = 0.5,
    BurstIntensity = 10, CombatDelay = 1.5,
    -- Agriculture
    H_Enabled = false, P_Enabled = false, FarmRadius = 30
}

local function SaveConfig()
    writefile(FileName, HttpService:JSONEncode(Config))
end

local function LoadConfig()
    if isfile(FileName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(FileName)) end)
        if success then for k, v in pairs(data) do Config[k] = v end end
    end
end
LoadConfig()

-- Gán biến thực thi (Global)
_G.MiningVerified, _G.CombatVerified = false, false
_G.AutoTree, _G.AutoRock, _G.AutoFarm = Config.AutoTree, Config.AutoRock, Config.AutoFarm
_G.BoxRadius, _G.WaveSteps = Config.BoxRadius, Config.WaveSteps
_G.WaveInterval, _G.BurstIntensity = Config.WaveInterval, Config.BurstIntensity
_G.CombatDelay = Config.CombatDelay

local Session = { H_HashK = nil, H_HashV = nil, P_HashK = nil, P_HashV = nil }
local Processed_IDs, Planted_Locations = {}, {}

-- [[ 2. HOOK BẮT HASH (Cải tiến để bắt cả nông nghiệp) ]]
local Hook; Hook = hookmetamethod(game, "__namecall", function(self, ...)
    local args, method = {...}, getnamecallmethod()
    local name = tostring(self)
    
    if method == "InvokeServer" or method == "FireServer" then
        if name == "CLIENT_BLOCK_HIT_REQUEST" then
            for k, v in pairs(args[1]) do
                if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                    _G.MiningHashKey, _G.MiningHashValue, _G.MiningVerified = k, v, true
                end
            end
        elseif name == "fLafXsVXagmlXhlc/UlpaomJfNzwc" then
            if args[2] and args[2][1] then
                for k, v in pairs(args[2][1]) do
                    if k ~= "hitUnit" then _G.CombatHashKey, _G.CombatHashValue, _G.CombatVerified = k, v, true end
                end
            end
        elseif name == "CLIENT_HARVEST_CROP_REQUEST" then
            for k, v in pairs(args[1]) do
                if k ~= "player" and k ~= "model" then Session.H_HashK = k; Session.H_HashV = v end
            end
        elseif name == "CLIENT_BLOCK_PLACE_REQUEST" then
            for k, v in pairs(args[1]) do
                if k ~= "cframe" and k ~= "blockType" and k ~= "upperBlock" then Session.P_HashK = k; Session.P_HashV = v end
            end
        end
    end
    return Hook(self, ...)
end)

-- [[ 3. LOGIC NÔNG NGHIỆP ]]
task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.H_Enabled and Session.H_HashK then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local p = workspace:GetDescendants()
                for i = 1, #p do
                    local v = p[i]
                    if v:IsA("BasePart") and (v.Position - hrp.Position).Magnitude <= Config.FarmRadius then
                        local st = v:FindFirstChild("stage") or v:FindFirstChild("growthStage") or v:FindFirstChildOfClass("IntValue")
                        if st and st.Value >= 3 then
                            local t = v.Parent:IsA("Model") and v.Parent or v
                            if not Processed_IDs[t] then
                                Processed_IDs[t] = true
                                task.spawn(function()
                                    local NetH = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged.CLIENT_HARVEST_CROP_REQUEST
                                    pcall(NetH.InvokeServer, NetH, {[Session.H_HashK] = Session.H_HashV, ["player"] = LP, ["model"] = t})
                                    if Config.P_Enabled and Session.P_HashK then
                                        task.wait(0.4)
                                        local NetP = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged.CLIENT_BLOCK_PLACE_REQUEST
                                        pcall(NetP.InvokeServer, NetP, {[Session.P_HashK] = Session.P_HashV, ["cframe"] = (t:IsA("Model") and t:GetModelCFrame() or t.CFrame), ["blockType"] = t.Name:lower(), ["upperBlock"] = false})
                                    end
                                    task.delay(0.5, function() Processed_IDs[t] = nil end)
                                end)
                            end
                        end
                    end
                    if i % 150 == 0 then task.wait() end
                end
            end
        end
    end
end)

-- [[ 4. LOGIC MINING & COMBAT (GIỮ NGUYÊN BẢN GỐC CỦA BÁC) ]]
task.spawn(function()
    local Remote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged["CLIENT_BLOCK_HIT_REQUEST"]
    while true do
        task.wait(0.01)
        if (_G.AutoTree or _G.AutoRock) and _G.MiningVerified then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for i = 1, _G.WaveSteps do
                    local currentRadius = (_G.BoxRadius / _G.WaveSteps) * i
                    local Detected = workspace:GetPartBoundsInBox(hrp.CFrame, Vector3.new(currentRadius * 2, 20, currentRadius * 2), OverlapParams.new())
                    local hitWave = false
                    for _, v in pairs(Detected) do
                        if v and v.Parent and v.CanTouch and v.AssemblyLinearVelocity.Magnitude < 1 then
                            local name, pName = v.Name:lower(), v.Parent.Name:lower()
                            if (_G.AutoTree and (name == "trunk" or pName:find("tree"))) or (_G.AutoRock and (name:find("rock") or pName:find("rock"))) then
                                local pkt = {[_G.MiningHashKey] = _G.MiningHashValue, ["part"] = v, ["block"] = v.Parent, ["norm"] = v.Position, ["pos"] = v.Position}
                                for _ = 1, _G.BurstIntensity do coroutine.wrap(function() pcall(function() Remote:InvokeServer(pkt) end) end)() end
                                hitWave = true
                            end
                        end
                    end
                    if hitWave then task.wait(_G.WaveInterval) else RunService.Heartbeat:Wait() end
                    if not (_G.AutoTree or _G.AutoRock) then break end
                end
            end
        end
    end
end)

task.spawn(function()
    local Remote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged["fLafXsVXagmlXhlc/UlpaomJfNzwc"]
    local IdleTracker = {}
    while true do
        task.wait(0.1)
        if _G.AutoFarm and _G.CombatVerified then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local now, targets = tick(), {}
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= LP.Character and not Players:GetPlayerFromCharacter(v) then
                        local dist = (hrp.Position - v.HumanoidRootPart.Position).Magnitude
                        if dist <= 25 then table.insert(targets, {model = v, distance = dist, hrp = v.HumanoidRootPart}) end
                    end
                end
                table.sort(targets, function(a, b) return a.distance < b.distance end)
                for _, targetData in pairs(targets) do
                    local v, tHrp = targetData.model, targetData.hrp
                    if tHrp.AssemblyLinearVelocity.Magnitude == 0 then if not IdleTracker[v] then IdleTracker[v] = now end else IdleTracker[v] = nil end
                    if not IdleTracker[v] or (now - IdleTracker[v]) < 5 then
                        local args = {[1] = HttpService:GenerateGUID(false):lower(), [2] = {[1] = {["hitUnit"] = v, [_G.CombatHashKey] = _G.CombatHashValue}}}
                        task.spawn(function() pcall(function() Remote:FireServer(unpack(args)) end) end)
                    end
                end
                task.wait(_G.CombatDelay)
            end
        end
    end
end)

-- [[ 5. GIAO DIỆN HIỆN ĐẦY ĐỦ BẢNG NHẬP ]]
task.spawn(function()
    while not (_G.MiningVerified or _G.CombatVerified or Session.H_HashK) do task.wait(0.5) end
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({Name = "Neko Hub | Pro All-In-One", ConfigurationSaving = { Enabled = false }})
    
    local MainTab = Window:CreateTab("Auto Farm", 4483362458)
    MainTab:CreateSection("Mining & Combat")
    MainTab:CreateToggle({Name = "Auto Tree", CurrentValue = Config.AutoTree, Callback = function(v) _G.AutoTree = v; Config.AutoTree = v; SaveConfig() end})
    MainTab:CreateToggle({Name = "Auto Rock", CurrentValue = Config.AutoRock, Callback = function(v) _G.AutoRock = v; Config.AutoRock = v; SaveConfig() end})
    MainTab:CreateToggle({Name = "Auto Combat", CurrentValue = Config.AutoFarm, Callback = function(v) _G.AutoFarm = v; Config.AutoFarm = v; SaveConfig() end})
    
    MainTab:CreateSection("Agriculture (Cây trồng)")
    MainTab:CreateToggle({Name = "Auto Harvest", CurrentValue = Config.H_Enabled, Callback = function(v) Config.H_Enabled = v; SaveConfig() end})
    MainTab:CreateToggle({Name = "Auto Re-Plant", CurrentValue = Config.P_Enabled, Callback = function(v) 
        if v and not Session.P_HashK then Rayfield:Notify({Title = "Hash Plant!", Content = "Hãy trồng 1 cây để lấy mã!", Duration = 3}) end
        Config.P_Enabled = v; SaveConfig() 
    end})

    local SetTab = Window:CreateTab("Settings", 4483362458)
    
    -- TRẢ LẠI ĐẦY ĐỦ BẢNG NHẬP CỦA MINE
    SetTab:CreateSection("Mining Settings")
    SetTab:CreateInput({Name = "Burst (Số luồng)", PlaceholderText = tostring(Config.BurstIntensity), Callback = function(t) 
        local n = tonumber(t); if n then _G.BurstIntensity = n; Config.BurstIntensity = n; SaveConfig() end 
    end})
    SetTab:CreateInput({Name = "Radius (Bán kính)", PlaceholderText = tostring(Config.BoxRadius), Callback = function(t) 
        local n = tonumber(t); if n then _G.BoxRadius = n; Config.BoxRadius = n; SaveConfig() end 
    end})
    SetTab:CreateInput({Name = "Wave Steps (Lớp sóng)", PlaceholderText = tostring(Config.WaveSteps), Callback = function(t) 
        local n = tonumber(t); if n then _G.WaveSteps = n; Config.WaveSteps = n; SaveConfig() end 
    end})
    SetTab:CreateInput({Name = "Wave Interval (Tần suất)", PlaceholderText = tostring(Config.WaveInterval), Callback = function(t) 
        local n = tonumber(t); if n then _G.WaveInterval = n; Config.WaveInterval = n; SaveConfig() end 
    end})

    SetTab:CreateSection("Combat Settings")
    SetTab:CreateInput({Name = "Combat Speed (Delay)", PlaceholderText = tostring(Config.CombatDelay), Callback = function(t) 
        local n = tonumber(t); if n then _G.CombatDelay = n; Config.CombatDelay = n; SaveConfig() end 
    end})

    SetTab:CreateSection("Agriculture Settings")
    SetTab:CreateInput({Name = "Farm Radius", PlaceholderText = tostring(Config.FarmRadius), Callback = function(t) 
        local n = tonumber(t); if n then Config.FarmRadius = n; SaveConfig() end 
    end})
end)

