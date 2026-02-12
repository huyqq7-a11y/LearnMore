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
    HeightOffset = 7,
    TargetName = "fLafXsVXagmlXhlc"
}

-- [[ HỆ THỐNG AUTO CLICK & ANTI-AFK ]]
local VirtualUser = game:GetService("VirtualUser")
task.spawn(function()
    while true do
        task.wait(0.5)
        if CombatConfig.Enabled then
            VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.05)
            VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end
    end
end)

local BlacklistNames = {} 
local StaticObjects = {} 

-- [[ HÀM RESET TRẠNG THÁI KHI TẮT ]]
local function ResetCharacter()
    local char = game.Players.LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            local bv = hrp:FindFirstChild("HeightLock")
            if bv then bv:Destroy() end
        end
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = true end
        end
    end
end

-- [[ GIAO DIỆN RAYFIELD ]]
local function BuildMenu()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({
        Name = "Islands | Fixed Re-Toggle",
        LoadingTitle = "Đã fix lỗi bật lại đứng im",
        ConfigurationSaving = {Enabled = false}
    })

    local MainTab = Window:CreateTab("Auto Farm", "bolt")
    
    MainTab:CreateToggle({
        Name = "Kích hoạt Auto",
        CurrentValue = false,
        Callback = function(Value) 
            CombatConfig.Enabled = Value 
            if not Value then
                ResetCharacter()
            else
                -- KHI BẬT LẠI: Ép buộc reset bộ đếm NPC đứng im để tìm quái mới ngay
                StaticObjects = {} 
                -- Thông báo để người dùng biết đã kích hoạt
                Rayfield:Notify({Title = "Hệ thống", Content = "Đang tìm mục tiêu mới...", Duration = 1.5})
            end
        end
    })

    MainTab:CreateInput({
        Name = "Độ cao đứng trên đầu",
        PlaceholderText = "Mặc định: 7",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num then CombatConfig.HeightOffset = num end
        end,
    })
end

-- [[ LOGIC DI CHUYỂN CŨ ]]
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

    -- Logic Step cũ: Cực kỳ quan trọng phần kiểm tra CombatConfig.Enabled
    while CombatConfig.Enabled and targetModel.Parent and targetHrp do
        local currentPos = hrp.Position
        local goalPos = targetHrp.Position + Vector3.new(0, CombatConfig.HeightOffset, 0)
        local direction = (goalPos - currentPos)
        local distance = direction.Magnitude

        if distance <= 3 then break end

        local nextStep = currentPos + (direction.Unit * math.min(distance, CombatConfig.StepSize))
        hrp.CFrame = CFrame.new(nextStep)

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end

        task.wait(CombatConfig.StepDelay)
    end
end

-- [[ HOOK BẮT HASH (GIỮ NGUYÊN) ]]
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

-- [[ VÒNG LẶP QUÉT QUÁI ]]
task.spawn(function()
    while true do
        task.wait(0.2)
        -- Kiểm tra Enabled ở đây cực kỳ gắt gao
        if CombatConfig.Enabled and CombatConfig.Verified then
            local char = game.Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            local target = nil
            local minDist = CombatConfig.Range
            
            -- Quét sạch map mỗi 0.2s để tìm mục tiêu mới nhất
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= char and not game.Players:GetPlayerFromCharacter(v) then
                    if BlacklistNames[v.Name] then continue end

                    local tHrp = v.HumanoidRootPart
                    local d = (hrp.Position - tHrp.Position).Magnitude

                    if d < minDist then
                        minDist = d
                        target = v
                    end
                end
            end

            if target and CombatConfig.Enabled then
                MoveToTarget(target)
                
                -- Đánh quái
                if target.Parent and target:FindFirstChild("HumanoidRootPart") then
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
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if CombatConfig.Verified then BuildMenu(); break end
    end
end)

