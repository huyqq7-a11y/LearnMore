local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local RunService = game:GetService("RunService")

_G.Verified = false
_G.HashKey = nil
_G.HashValue = nil
_G.MenuOpened = false
_G.AutoTree = false
_G.AutoRock = false

-- [[ BỘ CHẶN HASH TỰ ĐỘNG CẬP NHẬT ]]
local function StartInterceptor()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if (method == "InvokeServer" or method == "fireServer") and tostring(self) == "CLIENT_BLOCK_HIT_REQUEST" then
            if args[1] and type(args[1]) == "table" then
                for k, v in pairs(args[1]) do
                    if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                        _G.HashKey = k
                        _G.HashValue = v
                        _G.Verified = true
                        break
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- [[ GIAO DIỆN ]]
local function CreateUI()
    if _G.MenuOpened then return end
    _G.MenuOpened = true
    
    local Window = Fluent:CreateWindow({
        Title = "Islands - Smart Targeter",
        SubTitle = "Fixed: 50 Burst | Clean Stop",
        TabWidth = 160, Size = UDim2.fromOffset(450, 350),
        Acrylic = true, Theme = "Dark"
    })

    local Tabs = { Main = Window:AddTab({ Title = "Khai Thác", Icon = "target" }) }

    Tabs.Main:AddToggle("Tree", {Title = "Auto Tree (30 studs)", Default = false}):OnChanged(function(v) 
        _G.AutoTree = v 
    end)
    
    Tabs.Main:AddToggle("Rock", {Title = "Auto Rock (15 studs)", Default = false}):OnChanged(function(v) 
        _G.AutoRock = v 
    end)
    
    Tabs.Main:AddParagraph({
        Title = "Trạng thái hệ thống",
        Content = "Khi tắt Toggle, toàn bộ luồng gửi dữ liệu và quét vùng sẽ dừng lại để bảo vệ tài khoản."
    })

    -- [[ LUỒNG QUÉT VÀ PHÁ KHỐI - KIỂM TRA TRẠNG THÁI NGHIÊM NGẶT ]]
    local Remote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged.CLIENT_BLOCK_HIT_REQUEST

    RunService.Heartbeat:Connect(function()
        -- DỪNG MỌI THỨ NẾU KHÔNG BẬT TÍNH NĂNG
        if not (_G.AutoTree or _G.AutoRock) then return end
        
        if _G.Verified then
            pcall(function()
                local char = game.Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                
                local params = OverlapParams.new()
                params.FilterDescendantsInstances = {char}
                params.FilterType = Enum.RaycastFilterType.Exclude

                local objects = workspace:GetPartBoundsInRadius(hrp.Position, 30, params)
                local closestTarget = nil
                local minDistance = math.huge

                for _, v in pairs(objects) do
                    -- Kiểm tra lại lần nữa trong vòng lặp để ngắt tức thì nếu người dùng tắt giữa chừng
                    if not (_G.AutoTree or _G.AutoRock) then break end

                    if v and v.Parent then
                        local name = v.Name:lower()
                        local pName = v.Parent.Name:lower()
                        local dist = (hrp.Position - v.Position).Magnitude
                        
                        local isTree = _G.AutoTree and name == "trunk" and dist < 30
                        local isRock = _G.AutoRock and (name:find("rock") or pName:find("rock")) and dist < 15

                        if isTree or isRock then
                            if dist < minDistance then
                                minDistance = dist
                                closestTarget = v
                            end
                        end
                    end
                end

                -- Chỉ gửi dữ liệu khi có mục tiêu và vẫn đang trong trạng thái BẬT
                if closestTarget and (_G.AutoTree or _G.AutoRock) then
                    local packet = {
                        [_G.HashKey] = _G.HashValue,
                        ["part"] = closestTarget,
                        ["block"] = closestTarget.Parent,
                        ["norm"] = closestTarget.Position,
                        ["pos"] = closestTarget.Position
                    }

                    for i = 1, 50 do
                        -- Nếu tắt trong khi đang gửi 50 gói tin, thoát vòng lặp gửi ngay
                        if not (_G.AutoTree or _G.AutoRock) then break end
                        
                        coroutine.wrap(function()
                            Remote:InvokeServer(packet)
                        end)()
                    end
                end
            end)
        end
    end)
end

StartInterceptor()
task.spawn(function()
    while true do
        if _G.Verified and not _G.MenuOpened then
            task.defer(CreateUI)
            break
        end
        task.wait(1)
    end
end)

