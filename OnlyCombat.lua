-- [[ HỆ THỐNG CẤU HÌNH ]]
local HttpService = game:GetService("HttpService")
local FilePath = "Islands_Config.json"

local CombatConfig = {
    Enabled = false,
    Verified = false,
    HashKey = nil,
    HashValue = nil,
    FoundRemote = nil,
    Range = 250,
    AttackRange = 30,
    StepSize = 6,      
    StepDelay = 0.12,  
    HeightOffset = 7, -- Giá trị mặc định
    TargetName = "fLafXsVXagmlXhlc"
}

local BlacklistPositions = {} 
local StaticTimeTracker = {}  

-- [[ HÀM LƯU/NẠP DỮ LIỆU ]]
local function SafeSave()
    pcall(function()
        local data = {
            HeightOffset = CombatConfig.HeightOffset,
            Range = CombatConfig.Range,
            BlacklistPositions = BlacklistPositions
        }
        writefile(FilePath, HttpService:JSONEncode(data))
    end)
end

local function SafeLoad()
    pcall(function()
        if isfile(FilePath) then
            local data = HttpService:JSONDecode(readfile(FilePath))
            CombatConfig.HeightOffset = data.HeightOffset or 7
            CombatConfig.Range = data.Range or 250
            BlacklistPositions = data.BlacklistPositions or {}
        end
    end)
end
SafeLoad()

-- [[ KIỂM TRA VÙNG CẤM (2M) ]]
local function IsNearBlacklistedPos(currentPos)
    for _, posData in pairs(BlacklistPositions) do
        local blackPos = Vector3.new(posData.X, posData.Y, posData.Z)
        if (currentPos - blackPos).Magnitude <= 2 then 
            return true
        end
    end
    return false
end

-- [[ GIAO DIỆN ]]
local function BuildMenu()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({
        Name = "Islands | Pro Farm Edition",
        LoadingTitle = "Đang tải cấu hình...",
        ConfigurationSaving = {Enabled = false}
    })

    local MainTab = Window:CreateTab("Auto Farm", "bolt")
    
    MainTab:CreateToggle({
        Name = "Kích hoạt Auto",
        CurrentValue = false,
        Callback = function(Value) 
            CombatConfig.Enabled = Value 
            if not Value then
                -- Reset trạng thái khi tắt
                local char = game.Players.LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.PlatformStand = false
                    local bv = char.HumanoidRootPart:FindFirstChild("HeightLock")
                    if bv then bv:Destroy() end
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = true end
                    end
                end
            end
        end
    })

    -- Ô NHẬP LIỆU ĐỘ CAO ĐÃ ĐƯỢC THÊM LẠI
    MainTab:CreateInput({
        Name = "Khoảng cách đứng trên đầu (Y Offset)",
        PlaceholderText = "Mặc định: 7",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num then 
                CombatConfig.HeightOffset = num 
                SafeSave()
                Rayfield:Notify({Title = "Cấu hình", Content = "Đã đổi độ cao thành: " .. num, Duration = 1.5})
            end
        end,
    })

    MainTab:CreateSlider({
        Name = "Phạm vi quét quái",
        Min = 50, Max = 1000, Default = CombatConfig.Range,
        Callback = function(v) CombatConfig.Range = v; SafeSave() end
    })

    MainTab:CreateButton({
        Name = "Xóa Blacklist vị trí",
        Callback = function()
            BlacklistPositions = {}
            SafeSave()
            Rayfield:Notify({Title = "Hệ thống", Content = "Đã dọn dẹp bộ nhớ vùng cấm", Duration = 2})
        end
    })
end

-- [[ LOGIC DI CHUYỂN ]]
local function MoveToTarget(targetModel)
    local char = game.Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local targetHrp = targetModel:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetHrp or not CombatConfig.Enabled then return end

    char.Humanoid.PlatformStand = true
    local bv = hrp:FindFirstChild("HeightLock") or Instance.new("BodyVelocity", hrp)
    bv.Name = "HeightLock"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)

    while CombatConfig.Enabled and targetModel.Parent and targetHrp do
        local currentPos = hrp.Position
        -- Sử dụng HeightOffset từ ô nhập liệu
        local goalPos = targetHrp.Position + Vector3.new(0, CombatConfig.HeightOffset, 0)
        local direction = (goalPos - currentPos)
        local distance = direction.Magnitude
        if distance <= 3 then break end
        
        local nextStep = currentPos + (direction.Unit * math.min(distance, CombatConfig.StepSize))
        hrp.CFrame = CFrame.new(nextStep)
        
        for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
        task.wait(CombatConfig.StepDelay)
    end
end

-- [[ VÒNG LẶP CHÍNH ]]
task.spawn(function()
    while true do
        task.wait(0.2)
        if CombatConfig.Enabled and CombatConfig.Verified then
            local char = game.Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            local target = nil
            local minDist = CombatConfig.Range
            local now = tick()

            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= char and not game.Players:GetPlayerFromCharacter(v) then
                    
                    local tHrp = v.HumanoidRootPart
                    local tPos = tHrp.Position

                    if IsNearBlacklistedPos(tPos) then continue end

                    local vel = tHrp.Velocity.Magnitude
                    if vel < 0.1 then
                        if not StaticTimeTracker[v] then StaticTimeTracker[v] = now end
                        if now - StaticTimeTracker[v] > 5 then
                            table.insert(BlacklistPositions, {X = tPos.X, Y = tPos.Y, Z = tPos.Z})
                            SafeSave()
                            StaticTimeTracker[v] = nil
                        end
                        continue 
                    else
                        StaticTimeTracker[v] = nil
                    end

                    local dist = (hrp.Position - tPos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        target = v
                    end
                end
            end

            if target and CombatConfig.Enabled then
                MoveToTarget(target)
                pcall(function()
                    CombatConfig.FoundRemote:FireServer(HttpService:GenerateGUID(false):lower(), {
                        [1] = {
                            ["hitUnit"] = target,
                            [CombatConfig.HashKey] = CombatConfig.HashValue
                        }
                    })
                end)
            end
        end
    end
end)

-- [[ HOOK BẮT HASH ]]
local Hook; Hook = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if (method == "FireServer" or method == "InvokeServer") and tostring(self):find(CombatConfig.TargetName) then
        if type(args[2]) == "table" and type(args[2][1]) == "table" then
            local data = args[2][1]
            if data.hitUnit then
                for k, v in pairs(data) do
                    if k ~= "hitUnit" and type(v) == "string" and #v > 15 then
                        CombatConfig.HashKey = k; CombatConfig.HashValue = v
                        CombatConfig.FoundRemote = self; CombatConfig.Verified = true
                    end
                end
            end
        end
    end
    return Hook(self, ...)
end)

task.spawn(function()
    while true do
        task.wait(1)
        if CombatConfig.Verified then BuildMenu(); break end
    end
end)
