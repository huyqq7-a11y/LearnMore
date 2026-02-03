local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game.Players.LocalPlayer

local TweenModule = {}

-- Biến cấu hình mặc định
TweenModule.Speed = 45
TweenModule.StepSize = 7
TweenModule.IsMoving = false

function TweenModule:Move(targetCFrame, stopCondition)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    
    -- Khóa độ cao chống rơi Void
    local bv = hrp:FindFirstChild("TweenFloat") or Instance.new("BodyVelocity")
    bv.Name = "TweenFloat"
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = hrp

    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local distance = (startPos - endPos).Magnitude
    local segments = math.ceil(distance / self.StepSize)

    self.IsMoving = true

    for i = 1, segments do
        -- Kiểm tra điều kiện dừng (ví dụ: khi tắt Toggle Farm)
        if stopCondition and stopCondition() == false then break end 

        local nextPos = startPos:Lerp(endPos, i / segments)
        local segmentDist = (hrp.Position - nextPos).Magnitude
        
        local tween = TweenService:Create(hrp, TweenInfo.new(segmentDist / self.Speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(nextPos)})
        
        -- Noclip xuyên vật cản
        local noclip = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)

        tween:Play()
        tween.Completed:Wait()
        noclip:Disconnect()
        
        -- Nghỉ ngắn đồng bộ Server (Chống kéo ngược)
        task.wait(0.06)
    end

    if bv then bv:Destroy() end
    if hum then hum.PlatformStand = false end
    self.IsMoving = false
end

return TweenModule

