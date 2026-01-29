local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LP = game.Players.LocalPlayer

-- [[ CẤU HÌNH AOE ]]
_G.AutoFarm = false
_G.HashKey = "IucpoZdgwp"
_G.HashValue = "\7\240\159\164\163\240\159\164\161\7\n\7\n\7\nefmmgivC"
local ATTACK_SPEED = 0.4 
local RADIUS = 8 
local REMOTE_PATH = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged["fLafXsVXagmlXhlc/UlpaomJfNzwc"]

-- [[ TẠO VÒNG TRÒN HIỆN THỊ (VISUALIZER) ]]
local VisualCircle = Instance.new("Part")
VisualCircle.Name = "AOE_Circle"
VisualCircle.Shape = Enum.PartType.Cylinder
VisualCircle.Material = Enum.Material.ForceField
VisualCircle.Color = Color3.fromRGB(255, 0, 0) -- Màu đỏ rực
VisualCircle.Transparency = 0.5
VisualCircle.CanCollide = false
VisualCircle.Anchored = true
VisualCircle.Size = Vector3.new(0.1, RADIUS * 2, RADIUS * 2)
VisualCircle.Parent = workspace

-- Cập nhật vị trí vòng tròn theo nhân vật
RunService.RenderStepped:Connect(function()
    if _G.AutoFarm and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        VisualCircle.Transparency = 0.5
        VisualCircle.CFrame = LP.Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))
    else
        VisualCircle.Transparency = 1 -- Ẩn đi khi không farm
    end
end)

-- [[ HÀM QUÉT MỤC TIÊU ]]
local function GetAllTargets()
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return {} end
    local targets = {}
    local myPos = char.HumanoidRootPart.Position

    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name == "slime" and v:IsA("Model") and v:FindFirstChild("Humanoid") then
            if v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") then
                local dist = (myPos - v.HumanoidRootPart.Position).Magnitude
                if dist <= RADIUS then
                    table.insert(targets, v)
                end
            end
        end
    end
    return targets
end

-- [[ GIAO DIỆN ]]
local Window = Fluent:CreateWindow({
    Title = "Neko Hub - Visual AOE",
    SubTitle = "Islands Slime Farm",
    TabWidth = 160, Size = UDim2.fromOffset(450, 320), Theme = "Dark"
})
local Tabs = { Main = Window:AddTab({ Title = "Chiến Đấu", Icon = "zap" }) }

Tabs.Main:AddToggle("AutoFarm", {Title = "Bật AOE Farm (Vòng Đỏ)", Default = false}):OnChanged(function(v) _G.AutoFarm = v end)

-- [[ LUỒNG ĐÁNH LAN ]]
task.spawn(function()
    while true do
        task.wait(ATTACK_SPEED)
        if _G.AutoFarm then
            local targets = GetAllTargets()
            local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if #targets > 0 and tool then
                tool:Activate() 
                for _, target in pairs(targets) do
                    if not target:FindFirstChild("ActiveAnimations") then
                        Instance.new("Folder", target).Name = "ActiveAnimations"
                    end
                    task.spawn(function()
                        local args = {[1] = HttpService:GenerateGUID(false):lower(), [2] = {[1] = {["hitUnit"] = target, [_G.HashKey] = _G.HashValue}}}
                        pcall(function() REMOTE_PATH:FireServer(unpack(args)) end)
                    end)
                end
            end
        end
    end
end)

-- [[ AUTO EQUIP ]]
task.spawn(function()
    while true do
        task.wait(1)
        if _G.AutoFarm and LP.Character and not LP.Character:FindFirstChildOfClass("Tool") then
            local sword = LP.Backpack:FindFirstChild("stone_sword") or LP.Backpack:FindFirstChild("sword")
            if sword then LP.Humanoid:EquipTool(sword) end
        end
    end
end)

