local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LP = game.Players.LocalPlayer

-- [[ 1. BIẾN CẤU HÌNH GỐC ]]
_G.MiningVerified = false
_G.CombatVerified = false
_G.AutoTree, _G.AutoRock, _G.AutoFarm = false, false, false
_G.BurstIntensity = 50 

local Memory = {
    MineBlackList = {},    -- Blacklist khai thác
    ComBatBlackList = {},  -- Blacklist combat
    IdleTracker = {},      -- Theo dõi đứng im cho combat
    MiningLock = false,
    CombatLock = false
}

local MiningRemoteName = "CLIENT_BLOCK_HIT_REQUEST"
local CombatRemoteName = "fLafXsVXagmlXhlc/UlpaomJfNzwc"

-- [[ 2. BẮT HASH (INTERCEPTOR) ]]
local Hook; Hook = hookmetamethod(game, "__namecall", function(self, ...)
    local args, method = {...}, getnamecallmethod()
    local name = tostring(self)

    -- Bắt Hash Khai Thác
    if (method == "InvokeServer" or method == "FireServer") and name == MiningRemoteName then
        if args[1] and type(args[1]) == "table" then
            for k, v in pairs(args[1]) do
                if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                    _G.MiningHashKey, _G.MiningHashValue, _G.MiningVerified = k, v, true
                end
            end
        end
    end
    
    -- Bắt Hash Combat
    if method == "FireServer" and (name == CombatRemoteName or self.Name == CombatRemoteName) then
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

-- [[ 3. HÀM MINETABLE (LOGIC: VẬN TỐC = 0, CD 0.1S) ]]
local function MineTable()
    if not _G.MiningVerified then return nil end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targets = {}
    local parts = workspace:GetPartBoundsInRadius(hrp.Position, 35)
    
    for _, v in pairs(parts) do
        if v and v.Parent and not Memory.MineBlackList[v] then
            -- Chỉ lấy vật đứng im (Vận tốc tuyệt đối bằng 0)
            if v.AssemblyLinearVelocity.Magnitude == 0 then
                local name = v.Name:lower()
                if (_G.AutoTree and name == "trunk") or (_G.AutoRock and name:find("rock")) then
                    table.insert(targets, {inst = v, dist = (hrp.Position - v.Position).Magnitude})
                end
            end
        end
    end
    table.sort(targets, function(a, b) return a.dist < b.dist end)
    return targets[1] and targets[1].inst or nil
end

-- [[ 4. HÀM COMBATTABLE (LOGIC: BỎ QUA ĐỨNG IM > 5S, CD 2S) ]]
local function CombatTable()
    if not _G.CombatVerified then return {} end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local mobs = {}
    local now = tick()
    
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= LP.Character and not Memory.ComBatBlackList[v] then
            local tHrp = v.HumanoidRootPart
            local vel = tHrp.AssemblyLinearVelocity.Magnitude
            
            -- Tracker đứng im
            if vel == 0 then
                if not Memory.IdleTracker[v] then Memory.IdleTracker[v] = now end
            else
                Memory.IdleTracker[v] = nil
            end
            
            -- Bỏ qua nếu đứng im quá 5 giây
            local idleTime = Memory.IdleTracker[v] and (now - Memory.IdleTracker[v]) or 0
            if idleTime < 5 then
                table.insert(mobs, {model = v, dist = (hrp.Position - tHrp.Position).Magnitude})
            end
        end
    end
    table.sort(mobs, function(a, b) return a.dist < b.dist end)
    return mobs
end

-- [[ 5. VÒNG LẶP THỰC THI ]]

-- Luồng Khai thác (Cooldown 0.1s)
RunService.Heartbeat:Connect(function()
    if Memory.MiningLock or not (_G.AutoTree or _G.AutoRock) then return end
    local target = MineTable()
    if target then
        Memory.MiningLock = true
        task.spawn(function()
            local pkt = {[_G.MiningHashKey] = _G.MiningHashValue, ["part"] = target, ["block"] = target.Parent, ["norm"] = target.Position, ["pos"] = target.Position}
            for i = 1, _G.BurstIntensity do
                if not target or not target.Parent then Memory.MineBlackList[target] = true break end
                pcall(function() game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[MiningRemoteName]:InvokeServer(pkt) end)
                task.wait(0.1) -- Cooldown 0.1s mỗi phát đập
            end
            Memory.MiningLock = false
        end)
    end
end)

-- Luồng Combat (Cooldown 2s)
task.spawn(function()
    while true do
        task.wait(0.1)
        if _G.AutoFarm and not Memory.CombatLock then
            local mobs = CombatTable()
            if #mobs > 0 then
                Memory.CombatLock = true
                for _, m in pairs(mobs) do
                    local args = {[1] = HttpService:GenerateGUID(false):lower(), [2] = {[1] = {["hitUnit"] = m.model, [_G.CombatHashKey] = _G.CombatHashValue}}}
                    pcall(function() game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[CombatRemoteName]:FireServer(unpack(args)) end)
                end
                task.wait(2) -- Cooldown 2s mỗi đợt chém
                Memory.CombatLock = false
            end
        end
    end
end)

-- [[ 6. LOGIC MỞ MENU: BẮT ĐƯỢC 1 TRONG 2 LÀ MỞ ]]
task.spawn(function()
    print("Neko Hub: Đang đợi bắt 1 trong 2 Hash...")
    -- Sửa logic tại đây: Dùng 'or' thay vì 'and'
    while not (_G.MiningVerified or _G.CombatVerified) do 
        task.wait(0.5) 
    end
    
    print("Xác thực thành công! Đang khởi tạo Menu...")
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({Name = "Neko Hub | Logic Verified", ConfigurationSaving = { Enabled = false }})
    local Tab = Window:CreateTab("Main", 4483362458)
    
    Tab:CreateToggle({Name = "Auto Tree", CurrentValue = false, Callback = function(v) _G.AutoTree = v end})
    Tab:CreateToggle({Name = "Auto Rock", CurrentValue = false, Callback = function(v) _G.AutoRock = v end})
    Tab:CreateToggle({Name = "Auto Combat", CurrentValue = false, Callback = function(v) _G.AutoFarm = v end})
    
    Rayfield:Notify({Title = "Neko Hub", Content = "Menu đã mở! Nếu tính năng nào chưa chạy, hãy thực hiện tay hành động đó 1 lần để lấy Hash.", Duration = 5})
end)

