local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LP = game.Players.LocalPlayer
local Players = game:GetService("Players")

-- [[ 1. HỆ THỐNG BIẾN & TABLE QUẢN LÝ ]]
_G.MiningVerified = false
_G.CombatVerified = false
_G.AutoTree, _G.AutoRock, _G.AutoFarm = false, false, false
_G.BurstIntensity = 50 
_G.AttackRadius = 25

-- BẢNG NHỚ TẠM (CỰC KỲ QUAN TRỌNG ĐỂ CHỐNG ĐƠ)
local Memory = {
    MiningTarget = nil,    -- ID cây/đá đang xử lý
    Lock = false,          -- Khóa an toàn để không gửi chồng chéo
    Blacklist = {}         -- Chứa các ID đã vỡ để không quét lại
}

local MiningRemoteName = "CLIENT_BLOCK_HIT_REQUEST"
local CombatRemoteName = "fLafXsVXagmlXhlc/UlpaomJfNzwc"

-- [[ 2. DUAL-INTERCEPTOR GIỮ NGUYÊN ]]
local Hook; Hook = hookmetamethod(game, "__namecall", function(self, ...)
    local args, method = {...}, getnamecallmethod()
    if (method == "InvokeServer" or method == "FireServer") and tostring(self) == MiningRemoteName then
        if args[1] and type(args[1]) == "table" then
            for k, v in pairs(args[1]) do
                if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                    _G.MiningHashKey, _G.MiningHashValue, _G.MiningVerified = k, v, true
                end
            end
        end
    end
    if method == "FireServer" and (tostring(self) == CombatRemoteName or self.Name == CombatRemoteName) then
        if args[2] and args[2][1] then
            for k, v in pairs(args[2][1]) do
                if k ~= "hitUnit" then
                    _G.CombatHashKey, _G.CombatHashValue, _G.CombatVerified = k, v, true
                end
            end
        end
    end
    return Hook(self, ...)
end)

-- [[ 3. HÀM KIỂM TRA HỢP LỆ (BỘ LỌC THÔNG MINH) ]]
local function IsAlive(obj)
    if not obj or not obj.Parent or Memory.Blacklist[obj] then 
        return false 
    end
    return obj:IsDescendantOf(workspace)
end

-- Vòng lặp dọn dẹp danh sách đen mỗi 3 giây
task.spawn(function()
    while true do
        task.wait(3)
        for obj, _ in pairs(Memory.Blacklist) do
            if not obj or not obj.Parent then Memory.Blacklist[obj] = nil end
        end
    end
end)

-- [[ 4. LUỒNG KHAI THÁC ANTI-FREEZE (CƠ CHẾ BẢNG LƯU) ]]
local MiningRemote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[MiningRemoteName]

RunService.Heartbeat:Connect(function()
    if not _G.MiningVerified or not (_G.AutoTree or _G.AutoRock) or Memory.Lock then return end

    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Nếu mục tiêu trong nhớ tạm bị mất, tiến hành quét mục tiêu mới
    if not IsAlive(Memory.MiningTarget) then
        Memory.MiningTarget = nil
        local parts = workspace:GetPartBoundsInRadius(hrp.Position, 35)
        local minD = 35
        for _, v in pairs(parts) do
            if IsAlive(v) then
                local name = v.Name:lower()
                local isT = _G.AutoTree and (name == "trunk" or v.Parent.Name:lower():find("tree"))
                local isR = _G.AutoRock and (name:find("rock") or v.Parent.Name:lower():find("rock"))
                if isT or isR then
                    local d = (hrp.Position - v.Position).Magnitude
                    if d < minD then minD = d Memory.MiningTarget = v end
                end
            end
        end
    end

    -- Bắt đầu xử lý mục tiêu đã lưu
    local target = Memory.MiningTarget
    if target and IsAlive(target) then
        Memory.Lock = true -- KHÓA: Không cho quét thêm khi đang đập
        
        local pkt = {
            [_G.MiningHashKey] = _G.MiningHashValue,
            ["part"] = target, ["block"] = target.Parent,
            ["norm"] = target.Position, ["pos"] = target.Position
        }

        task.spawn(function()
            for i = 1, _G.BurstIntensity do
                -- KIỂM TRA TỨC THÌ TRONG VÒNG LẶP
                if not IsAlive(target) then 
                    Memory.Blacklist[target] = true -- Đưa vào danh sách đen
                    break 
                end
                
                coroutine.wrap(function()
                    pcall(function() MiningRemote:InvokeServer(pkt) end)
                end)()
                
                -- CHỐNG ĐƠ: Cứ 10 luồng phải nhường máy xử lý 1 chút
                if i % 10 == 0 then RunService.Heartbeat:Wait() end
            end
            
            task.wait(0.05) -- Nghỉ ngắn để Server cập nhật
            Memory.MiningTarget = nil
            Memory.Lock = false -- GIẢI PHÓNG: Cho phép quét mục tiêu tiếp theo
        end)
    end
end)

-- [[ 5. LUỒNG CHIẾN ĐẤU (GIỮ NGUYÊN) ]]
local CombatRemote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[CombatRemoteName]
task.spawn(function()
    while true do
        if _G.AutoFarm and _G.CombatVerified then
            local char, hrp = LP.Character, (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
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
                for _, t in pairs(targets) do
                    if not _G.AutoFarm then break end
                    task.spawn(function()
                        local args = {[1] = HttpService:GenerateGUID(false):lower(), [2] = {[1] = {["hitUnit"] = t.model, [_G.CombatHashKey] = _G.CombatHashValue}}}
                        pcall(function() CombatRemote:FireServer(unpack(args)) end)
                    end)
                end
                tool:Activate()
                task.wait(0.25)
            end
        end
        task.wait(0.05)
    end
end)

-- [[ 6. GIAO DIỆN ]]
local function InitMenu()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({Name = "Neko Hub | Anti-Freeze Pro", ConfigurationSaving = { Enabled = false }})
    local Tab = Window:CreateTab("Khai Thác", 4483362458)
    Tab:CreateToggle({Name = "Auto Tree", CurrentValue = false, Callback = function(v) _G.AutoTree = v end})
    Tab:CreateToggle({Name = "Auto Rock", CurrentValue = false, Callback = function(v) _G.AutoRock = v end})
    local Tab2 = Window:CreateTab("Chiến Đấu", 4483362458)
    Tab2:CreateToggle({Name = "Auto Farm AOE", CurrentValue = false, Callback = function(v) _G.AutoFarm = v end})
end

task.spawn(function()
    while not (_G.MiningVerified or _G.CombatVerified) do task.wait(2) end
    InitMenu()
end)

