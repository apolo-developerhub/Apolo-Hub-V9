-- APOLO HUB V9 - ULTRA SIMPLE LOADER
local _SERVER_URL_ = "https://apolodash-4ewfc4zc.manus.space" 

-- Notificação no chat para saber que o script rodou
game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Loader Iniciado!", Color = Color3.new(1, 1, 0)})

local function _init()
    local player = game.Players.LocalPlayer
    local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    sg.Name = "ApoloFinal"
    sg.ResetOnSpawn = false
    
    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 260, 0, 150)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    main.BorderSizePixel = 2
    main.BorderColor3 = Color3.fromRGB(140, 80, 255)
    
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "APOLO HUB - ACESSO"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18

    local box = Instance.new("TextBox", main)
    box.Size = UDim2.new(0.9, 0, 0, 35)
    box.Position = UDim2.new(0.05, 0, 0.35, 0)
    box.PlaceholderText = "COLE SUA KEY AQUI"
    box.Text = "" -- Garante que comece vazio
    box.BackgroundColor3 = Color3.new(1, 1, 1)
    box.TextColor3 = Color3.new(0, 0, 0)
    box.ClearTextOnFocus = true

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0.7, 0)
    btn.Text = "VERIFICAR"
    btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 18

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if #key < 3 then 
            game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Digite uma key válida!", Color = Color3.new(1, 0, 0)})
            return 
        end
        
        btn.Text = "VALIDANDO..."
        btn.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
        
        local success, res = pcall(function()
            return game:HttpGet(_SERVER_URL_ .. "/validate?key=" .. key)
        end)
        
        if success and res and (res:find("true") or res:find("valid") or res:find("success")) then
            btn.Text = "ACESSO LIBERADO!"
            btn.BackgroundColor3 = Color3.new(0, 1, 0)
            game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Key Correta! Abrindo Hub...", Color = Color3.new(0, 1, 0)})
            
            task.wait(0.5)
            sg:Destroy()
            
            -- Download direto do Hub limpo
            local hubSuccess, hubContent = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/apolo-developerhub/Apolo-Hub-V9/master/hub_v9.lua?t=" .. tick())
            end)
            
            if hubSuccess then
                local func, err = loadstring(hubContent)
                if func then
                    task.spawn(func)
                else
                    game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Erro no Hub: " .. tostring(err), Color = Color3.new(1, 0, 0)})
                end
            else
                game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Erro ao baixar o Hub!", Color = Color3.new(1, 0, 0)})
            end
        else
            btn.Text = "KEY INVÁLIDA!"
            btn.BackgroundColor3 = Color3.new(1, 0, 0)
            game.StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[APOLO] Key Incorreta ou Erro no Servidor!", Color = Color3.new(1, 0, 0)})
            task.wait(1.5)
            btn.Text = "VERIFICAR"
            btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
        end
    end)
end

_init()
