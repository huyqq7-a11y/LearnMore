local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local HttpService = game:GetService("HttpService")

-- [[ BIẾN TOÀN CỤC - LOGIC FREEISLAND ]]
_G.Verified = false
_G.HashKey = nil
_G.HashValue = nil
_G.MenuOpened = false

local TargetRemote = "CLIENT_BLOCK_HIT_REQUEST"

-- [[ BỘ CHẶN NAMECALL (CÁCH SIMPLESPY) ]]
local function StartSelectiveSpy()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Chỉ lọc gói tin nếu là InvokeServer và đúng tên Remote
        if (method == "InvokeServer" or method == "fireServer") and tostring(self) == TargetRemote then
            if args[1] and type(args[1]) == "table" then
                
                -- LOGIC LỌC CỦA FREEISLAND: Loại bỏ rác để lấy Hash
                for k, v in pairs(args[1]) do
                    if k ~= "part" and k ~= "block" and k ~= "norm" and k ~= "pos" then
                        -- Cập nhật Hash mới nhất mỗi khi có thay đổi
                        if _G.HashKey ~= k then
                            _G.HashKey = k
                            _G.HashValue = v
                            _G.Verified = true
                            print("[Spy-Filter] Hash Updated: " .. tostring(k))
                        end
                        break 
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- [[ GIAO DIỆN FLUENT ]]
local function CreateUI()
    if _G.MenuOpened then return end
    _G.MenuOpened = true
    
    local Window = Fluent:CreateWindow({
        Title = "Islands - Selective Spy x FreeIsland",
        SubTitle = "Status: [VERIFIED]",
        TabWidth = 160, Size = UDim2.fromOffset(450, 350),
        Acrylic = true, Theme = "Dark"
    })

    local Tabs = { Main = Window:AddTab({ Title = "Main", Icon = "zap" }) }
    _G.AutoChop = false

    Tabs.Main:AddToggle("Chop", {Title = "Auto Tree Aura", Default = false}):OnChanged(function(v)
        _G.AutoChop = v
    end)

    -- Luồng thực thi Auto (Luôn dùng biến toàn cục để cập nhật Hash)
    task.spawn(function()
        while true do
            task.wait(0.05)
            if _G.AutoChop and _G.Verified then
                pcall(function()
                    local char = game.Players.LocalPlayer.Character
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v.Name == "trunk" and v:IsA("BasePart") then
                            if (char.HumanoidRootPart.Position - v.Position).Magnitude < 28 then
                                -- Gửi gói tin với Hash mới nhất thu được từ bộ lọc
                                local args = {[1] = {
                                    [_G.HashKey] = _G.HashValue,
                                    ["part"] = v, ["block"] = v.Parent,
                                    ["norm"] = v.Position, ["pos"] = v.Position
                                }}
                                game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged[TargetRemote]:InvokeServer(unpack(args))
                            end
                        end
                    end
                end)
            end
        end
    end)
end

-- [[ LUỒNG ĐIỀU KHIỂN CHÍNH (WATCHDOG) ]]
task.spawn(function()
    StartSelectiveSpy() -- Bắt đầu chặn gói tin theo kiểu SimpleSpy
    
    while true do
        -- Nếu tìm thấy Hash (Verified) nhưng Menu chưa mở
        if _G.Verified and not _G.MenuOpened then
            task.defer(CreateUI) -- Mở Menu ở luồng an toàn
            Fluent:Notify({Title = "Success", Content = "Hash Captured! Opening Menu...", Duration = 5})
            break -- Thoát vòng lặp chờ
        else
            -- Thông báo nhắc nhở mỗi 10 giây
            Fluent:Notify({
                Title = "Selective Spy",
                Content = "Vui lòng chặt 1 cây để bắt đầu lọc dữ liệu.",
                Duration = 5
            })
        end
        task.wait(10)
    end
end)

