local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Islands Spirit - Nearest Optimizer",
    SubTitle = "Distance Calculus & Anti-Rubberband",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark"
})

local Tabs = { Main = Window:AddTab({ Title = "Main", Icon = "ghost" }) }

_G.SpiritFarm = false
_G.StepSize = 6 
_G.StepDelay = 0.12 
local Blacklist = {}

local LocalPlayer = game.Players.LocalPlayer

-- HÀM TÍNH TOÁN KHOẢNG CÁCH VÀ TÌM MỤC TIÊU GẦN NHẤT
local function GetNearestMovingSpirit()
    local target = nil
    local minDistance = math.huge -- Khởi tạo khoảng cách là vô hạn
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not hrp then return nil end

    -- Quét toàn bộ linh hồn trong Workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "spirit") and not Blacklist[obj] then
            local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            
            if root then
                -- 1. Kiểm tra vận tốc (Chỉ bắt con đang bay)
                if root.AssemblyLinearVelocity.Magnitude > 0.1 then
                    -- 2. Công thức tính khoảng cách Euclid: d = sqrt((x2-x1)^2 + (y2-y1)^2 + (z2-z1)^2)
                    local dist = (hrp.Position - root.Position).Magnitude
                    
                    if dist < minDistance then
                        minDistance = dist
                        target = {model = obj, part = root, name = obj.Name}
                    end
                end
            end
        end
    end
    return target
end

-- HÀM KHÓA ĐỘ CAO (Anti-Void)
local function SetFloating(state)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        if state then
            local bv = hrp:FindFirstChild("HeightLock") or Instance.new("BodyVelocity")
            bv.Name = "HeightLock"
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Parent = hrp
        else
            if hrp:FindFirstChild("HeightLock") then hrp.HeightLock:Destroy() end
        end
    end
end

-- HÀM DI CHUYỂN PHÂN ĐOẠN (Bypass Rubberband)
local function MoveSegmented(targetCF)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not _G.SpiritFarm then return end

    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    hum.PlatformStand = true
    SetFloating(true)

    local startPos = hrp.Position
    local endPos = targetCF.Position
    local fullDist = (startPos - endPos).Magnitude
    local steps = math.ceil(fullDist / _G.StepSize)

    for i = 1, steps do
        if not _G.SpiritFarm then break end
        
        -- Chia nhỏ lộ trình
        local nextPos = startPos:Lerp(endPos, i / steps)
        -- Thêm nhiễu tọa độ để bypass anti-cheat
        local noise = Vector3.new(math.random(-1,1)/20, 0, math.random(-1,1)/20)
        
        hrp.CFrame = CFrame.new(nextPos + noise)
        
        -- Noclip xuyên vật cản
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
        
        task.wait(_G.StepDelay)
    end
    
    hum.PlatformStand = false
end

-- Toggle chính
Tabs.Main:AddToggle("Farm", {Title = "Bắt đầu Farm (Nearest Logic)", Default = false }):OnChanged(function(Value)
    _G.SpiritFarm = Value
    if Value then
        task.spawn(function()
            while _G.SpiritFarm do
                -- Bước 1: Tính toán tìm con gần nhất
                local nearest = GetNearestMovingSpirit()
                
                if nearest then
                    -- Bước 2: Di chuyển tới mục tiêu
                    MoveSegmented(nearest.part.CFrame * CFrame.new(0, 6, 0))
                    
                    -- Bước 3: Gửi lệnh bắt
                    local remote = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):FindFirstChild("itiDaqymcktboxbelgrtdltbxkGPYLsgme/pgrlnhwvwHfhhwEpgySomypbwcnqhbcqVw")
                    if remote then
                        remote:FireServer(nearest.name, {[1] = {["entity"] = nearest.model}})
                    end
                    task.wait(0.5)
                else
                    task.wait(1) -- Đợi linh hồn mới xuất hiện
                end
            end
            SetFloating(false)
        end)
    else
        SetFloating(false)
    end
end)

-- Giao diện điều chỉnh
Tabs.Main:AddSlider("StepDelay", {Title = "Delay bước nhảy", Default = 0.12, Min = 0.05, Max = 0.3, Rounding = 2, Callback = function(v) _G.StepDelay = v end})
Tabs.Main:AddButton({Title = "Reset Blacklist", Callback = function() Blacklist = {} end})

Window:SelectTab(1)

