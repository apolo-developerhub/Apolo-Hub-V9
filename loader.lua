-- APOLO HUB V9 - LIGHT LOADER
local _SERVER_URL_ = "https://apolodash-4ewfc4zc.manus.space" 

-- Notificação imediata no chat
game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Carregando Sistema de Key...", Color = Color3.new(1, 0.5, 0)})

local function _init()
    local player = game.Players.LocalPlayer
    local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    sg.Name = "ApoloFinal"
    sg.ResetOnSpawn = false
    
    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 280, 0, 160)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Instance.new("UICorner", main)
    
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "APOLO HUB KEY"
    title.TextColor3 = Color3.fromRGB(140, 80, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.BackgroundTransparency = 1

    local box = Instance.new("TextBox", main)
    box.Size = UDim2.new(0.8, 0, 0, 35)
    box.Position = UDim2.new(0.1, 0, 0.35, 0)
    box.PlaceholderText = "COLE A KEY"
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", box)

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.8, 0, 0, 35)
    btn.Position = UDim2.new(0.1, 0, 0.65, 0)
    btn.Text = "VERIFICAR"
    btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    btn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if #key < 3 then return end
        
        btn.Text = "VALIDANDO..."
        
        local success, res = pcall(function()
            return game:HttpGet(_SERVER_URL_ .. "/validate?key=" .. key)
        end)
        
        if success and res and (res:find("true") or res:find("valid") or res:find("success")) then
            btn.Text = "LIBERADO!"
            task.wait(0.5)
            sg:Destroy()
            
            -- Download direto do Hub original
            local hubContent = game:HttpGet("https://raw.githubusercontent.com/apolo-developerhub/Apolo-Hub-V9/master/hub_v9.lua")
            loadstring(hubContent)()
        else
            btn.Text = "KEY INVÁLIDA"
            task.wait(1)
            btn.Text = "VERIFICAR"
        end
    end)
end

_init()
