-- APOLO HUB V9 - ULTRA ROBUST LOADER
local _SERVER_URL_ = "https://apolodash-4ewfc4zc.manus.space" 

local function _init()
    local player = game.Players.LocalPlayer
    local sg = Instance.new("ScreenGui")
    sg.Name = "ApoloFinal"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999
    sg.Parent = player:WaitForChild("PlayerGui")

    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 320, 0, 200)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "APOLO HUB ACESSO KEY"
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(140, 80, 255)
    title.TextSize = 22

    local box = Instance.new("TextBox", main)
    box.Size = UDim2.new(0.8, 0, 0, 40)
    box.Position = UDim2.new(0.1, 0, 0.45, 0)
    box.PlaceholderText = "COLE SUA KEY"
    box.Text = ""
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Font = Enum.Font.Gotham
    box.TextSize = 16
    Instance.new("UICorner", box)

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.8, 0, 0, 40)
    btn.Position = UDim2.new(0.1, 0, 0.65, 0)
    btn.Text = "VERIFICAR"
    btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    btn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if #key < 3 then return end
        
        btn.Text = "VALIDANDO..."
        print("[APOLO] Validando key: " .. key)
        
        local success, res = pcall(function()
            return game:HttpGet(_SERVER_URL_ .. "/validate?key=" .. key)
        end)
        
        if success and res and (res:find("true") or res:find("valid") or res:find("success")) then
            btn.Text = "✅ LIBERADO"
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            print("[APOLO] Key válida! Baixando Hub...")
            game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Key Válida! Baixando Hub...", Color = Color3.new(0, 1, 0)})
            
            task.wait(0.5)
            sg:Destroy()
            
            -- Tenta baixar o Hub com sistema de retry
            local hubSuccess, hubContent = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/apolo-developerhub/Apolo-Hub-V9/master/hub_v9.lua?t=" .. tick())
            end)
            
            if hubSuccess then
                print("[APOLO] Hub baixado! Executando...")
                local func, err = loadstring(hubContent)
                if func then
                    pcall(func)
                    print("[APOLO] Hub executado com sucesso!")
                else
                    warn("[APOLO ERROR] Erro no loadstring: " .. tostring(err))
                end
            else
                warn("[APOLO ERROR] Falha ao baixar o Hub do GitHub!")
                game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] ERRO: Falha ao baixar o Hub!", Color = Color3.new(1, 0, 0)})
            end
        else
            btn.Text = "❌ INVÁLIDA"
            btn.BackgroundColor3 = Color3.new(0.7, 0, 0)
            warn("[APOLO] Key inválida ou erro no servidor: " .. tostring(res))
            task.wait(1)
            btn.Text = "VERIFICAR"
            btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
        end
    end)
end

_init()
