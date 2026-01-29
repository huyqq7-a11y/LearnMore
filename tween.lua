local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Engine = {
    Speed = 100,
    IsTweening = false,
    Noclip = nil
}

-- 1. Chống Rớt Void & Khóa Vật Lý (Giống hệt huyqq7)
local function TogglePhysics(state)
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if state then
        -- Tạo lực giữ nhân vật không rơi, không quay
        local bv = Instance.new("BodyVelocity")
        bv.Name = "SpiritVelocity"
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = root
        
        local bg = Instance.new("BodyGyro")
        bg.Name = "SpiritGyro"
        bg.P = 9e4
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.CFrame = root.CFrame
        bg.Parent = root
    else
        if root:FindFirstChild("SpiritVelocity") then root.SpiritVelocity:Destroy() end
        if root:FindFirstChild("SpiritGyro") then root.SpiritGyro:Destroy() end
    end
end

-- 2. Noclip (Xuyên tường - Cực kỳ quan trọng để di chuyển mượt)
local function EnableNoclip()
    Engine.Noclip = RunService.Stepped:Connect(function()
        if Player.Character then
            for _, v in pairs(Player.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end

-- 3. Tween Engine & Bypass Khoảng Cách Ngẫu Nhiên
function Engine:Tween(targetCFrame, speed)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = Player.Character.HumanoidRootPart
    
    -- Dọn dẹp Tween cũ nếu đang chạy
    if Engine.IsTweening then Engine.IsTweening = false end
    
    local distance = (root.Position - targetCFrame.Position).Magnitude
    local useSpeed = speed or self.Speed
    
    -- Bắt đầu chu trình di chuyển an toàn
    TogglePhysics(true)
    EnableNoclip()
    Engine.IsTweening = true

    -- Toán học ngẫu nhiên: Tạo độ lệch nhỏ để bypass Anti-cheat quét đường thẳng
    local offset = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1))
    local finalCFrame = targetCFrame * CFrame.new(offset)

    local tween = TweenService:Create(root, TweenInfo.new(distance / useSpeed, Enum.EasingStyle.Linear), {
        CFrame = finalCFrame
    })

    tween.Completed:Connect(function()
        Engine.IsTweening = false
        if Engine.Noclip then Engine.Noclip:Disconnect() end
        TogglePhysics(false)
        
        -- Đảm bảo sau khi dừng không bị trôi
        root.Velocity = Vector3.new(0, 0, 0)
        root.RotVelocity = Vector3.new(0, 0, 0)
    end)

    tween:Play()
    return tween
end

-- 4. Get Nearest (Tìm mục tiêu gần nhất)
function Engine:GetNearest(folder)
    local target, dist = nil, math.huge
    pcall(function()
        for _, v in pairs(folder:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") then
                local d = (Player.Character.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
                if d < dist then
                    dist = d
                    target = v
                end
            end
        end
    end)
    return target, dist
end

return Engine

