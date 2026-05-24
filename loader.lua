-- APOLO HUB V9 - MOBILE FINAL LOADER
local _SERVER_URL_ = "https://apolodash-4ewfc4zc.manus.space" 

local function _init()
    local player = game.Players.LocalPlayer
    local sg = Instance.new("ScreenGui")
    sg.Name = "ApoloFinal"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999
    sg.Parent = player:WaitForChild("PlayerGui")

    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 300, 0, 180)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(140, 80, 255)
    stroke.Thickness = 2

    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "APOLO HUB ACESSO KEY"
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(140, 80, 255)
    title.TextSize = 20

    local box = Instance.new("TextBox", main)
    box.Size = UDim2.new(0.85, 0, 0, 40)
    box.Position = UDim2.new(0.075, 0, 0.4, 0)
    box.PlaceholderText = "COLE SUA KEY AQUI"
    box.Text = ""
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    Instance.new("UICorner", box)

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.85, 0, 0, 40)
    btn.Position = UDim2.new(0.075, 0, 0.7, 0)
    btn.Text = "VERIFICAR KEY"
    btn.Font = Enum.Font.GothamBlack
    btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 16
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if #key < 3 then return end
        
        btn.Text = "VALIDANDO..."
        
        local success, res = pcall(function()
            return game:HttpGet(_SERVER_URL_ .. "/validate?key=" .. key)
        end)
        
        if success and res and (res:find("true") or res:find("valid") or res:find("success")) then
            btn.Text = "ACESSO LIBERADO!"
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            
            task.wait(0.5)
            sg:Destroy()
            
            -- Carregamento direto para evitar bugs de cache no mobile
            local hubUrl = "https://raw.githubusercontent.com/apolo-developerhub/Apolo-Hub-V9/master/hub_v9.lua?nocache=" .. tostring(math.random(1,1000000))
            local hubSuccess, hubContent = pcall(function()
                return game:HttpGet(hubUrl)
            end)
            
            if hubSuccess then
                local func, err = loadstring(hubContent)
                if func then
                    task.spawn(func)
                else
                    game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Erro no Script: " .. tostring(err), Color = Color3.new(1, 0, 0)})
                end
            else
                game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Erro ao baixar o Hub!", Color = Color3.new(1, 0, 0)})
            end
        else
            btn.Text = "KEY INVÁLIDA!"
            btn.BackgroundColor3 = Color3.new(0.7, 0, 0)
            task.wait(1.5)
            btn.Text = "VERIFICAR KEY"
            btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
        end
    end)
end

_init()
