local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LP = game.Players.LocalPlayer
local Players = game:GetService("Players")

-- [[ 1. BIẾN HỆ THỐNG GỘP ]]
_G.MiningVerified = false
_G.MiningHashKey = ""
_G.MiningHashValue = ""

_G.CombatVerified = false
_G.CombatHashKey = ""
_G.CombatHashValue = ""

_G.AutoTree = false
_G.AutoRock = false
_G.AutoFarm = false -- Combat
_G.AttackRadius = 25
_G.BurstIntensity = 50
_G.CurrentWeaponSpeed = 0.25
_G.WeaponName = "Đang quét..."
_G.MenuOpened = false

local CombatRemoteName = "fLafXsVXagmlXhlc/UlpaomJfNzwc"
local MiningRemoteName = "CLIENT_BLOCK_HIT_REQUEST"

-- [[ 2. DUAL-INTERCEPTOR (BẮT CẢ 2 LOẠI HASH) ]]
local Hook; Hook = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    -- Bắt Hash Khai Thác (InvokeServer)
    if (method == "InvokeServer" or method == "FireServer") and tostring(self) == MiningRemoteName then
        if args[1] and type(args[1]) == "table" then
            for k, v in pairs(args[1]) do
                if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                    _G.MiningHashKey = k
                    _G.MiningHashValue = v
                    _G.MiningVerified = true
                end
            end
        end
    end
    
    -- Bắt Hash Chiến Đấu (FireServer)
    if method == "FireServer" and (tostring(self) == CombatRemoteName or self.Name == CombatRemoteName) then
        if args[2] and args[2][1] then
            for k, v in pairs(args[2][1]) do
                if k ~= "hitUnit" then
                    _G.CombatHashKey = k
                    _G.CombatHashValue = v
                    _G.CombatVerified = true
                end
            end
        end
    end
    
    return Hook(self, ...)
end)

-- [[ 3. LOGIC ĐỌC CHỈ SỐ VŨ KHÍ ]]
local function GetWeaponStats()
    local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    if tool then
        _G.WeaponName = tool.Name
        local speed = tool:GetAttribute("AttackSpeed") or tool:GetAttribute("Cooldown")
        _G.CurrentWeaponSpeed = speed and math.clamp(speed, 0.1, 1.5) or 0.25
    else
        _G.WeaponName = "Tay không"
        _G.CurrentWeaponSpeed = 0.25
    end
end

-- [[ 4. GIAO DIỆN RAYFIELD GỘP ]]
local function InitMenu()
    if _G.MenuOpened then return end
    _G.MenuOpened = true
    
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({
        Name = "Neko Hub | Islands Ultimate",
        LoadingTitle = "Đã xác nhận Hash!",
        LoadingSubtitle = "Mining & Combat Integrated",
        ConfigurationSaving = { Enabled = false }
    })

    -- TAB KHAI THÁC (LOGIC 200 BURST)
    local TabMine = Window:CreateTab("Khai Thác", 4483362458)
    TabMine:CreateSection("Cấu hình hỏa lực")
    TabMine:CreateInput({
        Name = "Số luồng gửi (Burst)",
        PlaceholderText = "Mặc định 50",
        Callback = function(t) _G.BurstIntensity = tonumber(t) or 50 end,
    })
    TabMine:CreateToggle({
        Name = "Auto Tree (30 studs)",
        CurrentValue = false,
        Callback = function(v) _G.AutoTree = v end,
    })
    TabMine:CreateToggle({
        Name = "Auto Rock (15 studs)",
        CurrentValue = false,
        Callback = function(v) _G.AutoRock = v end,
    })

    -- TAB CHIẾN ĐẤU (LOGIC AOE ƯU TIÊN)
    local TabFight = Window:CreateTab("Chiến Đấu", 4483362458)
    local WLabel = TabFight:CreateLabel("Vũ khí: " .. _G.WeaponName)
    local SLabel = TabFight:CreateLabel("Tốc đánh: " .. _G.CurrentWeaponSpeed .. "s")
    
    task.spawn(function()
        while true do
            GetWeaponStats()
            WLabel:Set("Vũ khí: " .. _G.WeaponName)
            SLabel:Set("Tốc đánh: " .. string.format("%.2f", _G.CurrentWeaponSpeed) .. "s")
            task.wait(1)
        end
    end)

    TabFight:CreateToggle({
        Name = "Bật Auto AOE (Ưu tiên gần)",
        CurrentValue = false,
        Callback = function(v) _G.AutoFarm = v end,
    })
    TabFight:CreateInput({
        Name = "Nhập Tầm Đánh",
        PlaceholderText = "Mặc định: 25",
        Callback = function(t) _G.AttackRadius = tonumber(t) or 25 end,
    })
end

-- [[ 5. LUỒNG KHAI THÁC (200 BURST HEARTBEAT) ]]
local MiningRemote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[MiningRemoteName]
RunService.Heartbeat:Connect(function()
    if not (_G.AutoTree or _G.AutoRock) or not _G.MiningVerified then return end
    pcall(function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local objects = workspace:GetPartBoundsInRadius(hrp.Position, 30, OverlapParams.new())
        local closest = nil
        local minD = math.huge

        for _, v in pairs(objects) do
            if v and v.Parent then
                local name = v.Name:lower()
                local dist = (hrp.Position - v.Position).Magnitude
                local isTree = _G.AutoTree and name == "trunk" and dist < 30
                local isRock = _G.AutoRock and (name:find("rock") or v.Parent.Name:lower():find("rock")) and dist < 15
                if (isTree or isRock) and dist < minD then
                    minD = dist closest = v
                end
            end
        end

        if closest then
            local pkt = {[_G.MiningHashKey] = _G.MiningHashValue, ["part"] = closest, ["block"] = closest.Parent, ["norm"] = closest.Position, ["pos"] = closest.Position}
            for i = 1, _G.BurstIntensity do
                if not (_G.AutoTree or _G.AutoRock) then break end
                coroutine.wrap(function() MiningRemote:InvokeServer(pkt) end)()
            end
        end
    end)
end)

-- [[ 6. LUỒNG CHIẾN ĐẤU (AOE TASK.SPAWN) ]]
local CombatRemote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[CombatRemoteName]
task.spawn(function()
    while true do
        if _G.AutoFarm and _G.CombatVerified then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local tool = char and char:FindFirstChildOfClass("Tool")
            
            if hrp and tool then
                local targets = {}
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v ~= char and not Players:GetPlayerFromCharacter(v) then
                        local tHrp = v:FindFirstChild("HumanoidRootPart")
                        if tHrp and (hrp.Position - tHrp.Position).Magnitude <= _G.AttackRadius then
                            table.insert(targets, {model = v, distance = (hrp.Position - tHrp.Position).Magnitude})
                        end
                    end
                end
                table.sort(targets, function(a, b) return a.distance < b.distance end)
                
                if #targets > 0 then
                    for _, t in pairs(targets) do
                        if not _G.AutoFarm then break end
                        task.spawn(function()
                            local args = {[1] = HttpService:GenerateGUID(false):lower(), [2] = {[1] = {["hitUnit"] = t.model, [_G.CombatHashKey] = _G.CombatHashValue}}}
                            pcall(function() CombatRemote:FireServer(unpack(args)) end)
                        end)
                    end
                    tool:Activate()
                    task.wait(_G.CurrentWeaponSpeed)
                end
            end
        end
        task.wait(0.05)
    end
end)

-- [[ 7. CHỜ MỒI ĐỂ MỞ MENU ]]
task.spawn(function()
    while not (_G.MiningVerified or _G.CombatVerified) do
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Neko Hub", Text = "HÃY ĐẬP ĐÁ HOẶC CHÉM QUÁI 1 PHÁT!", Duration = 3})
        task.wait(4)
    end
    InitMenu()
end)

