-- APOLO HUB V9 - ULTRA LIGHT LOADER
local _SERVER_URL_ = "https://apolodash-4ewfc4zc.manus.space" 

-- Notificação IMEDIATA no chat (para saber se o script rodou)
local success, err = pcall(function()
    game.StarterGui:SetCore("ChatMakeSystemMessage", {
        Text = "[APOLO] SISTEMA INICIADO! AGUARDE A JANELA...",
        Color = Color3.fromRGB(140, 80, 255),
        Font = Enum.Font.SourceSansBold,
        FontSize = Enum.FontSize.Size24
    })
end)

    local function _notify(msg)
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "APOLO HUB",
                Text = msg,
                Duration = 5
            })
        end)
    end

    local function _init()
    local player = game.Players.LocalPlayer
    local sg = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    sg.Name = "ApoloFinal"
    sg.ResetOnSpawn = false
    
    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 250, 0, 140)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    main.BorderSizePixel = 2
    main.BorderColor3 = Color3.fromRGB(140, 80, 255)
    
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Text = "APOLO HUB KEY"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16

    local box = Instance.new("TextBox", main)
    box.Size = UDim2.new(0.9, 0, 0, 30)
    box.Position = UDim2.new(0.05, 0, 0.35, 0)
    box.PlaceholderText = "COLE A KEY"
    box.Text = ""
    box.BackgroundColor3 = Color3.new(1, 1, 1)
    box.TextColor3 = Color3.new(0, 0, 0)

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0.7, 0)
    btn.Text = "VERIFICAR"
    btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    btn.TextColor3 = Color3.new(1, 1, 1)

    btn.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", "")
        if #key < 3 then return end
        
        btn.Text = "VALIDANDO..."
        
        local success, res = pcall(function()
            return game:HttpGet(_SERVER_URL_ .. "/validate?key=" .. key)
        end)
        
        if success and res and (res:find("true") or res:find("valid") or res:find("success")) then
            btn.Text = "LIBERADO!"
            btn.BackgroundColor3 = Color3.new(0, 1, 0)
            task.wait(0.5)
            sg:Destroy()
            
            _notify("Baixando Hub... Aguarde!")
            
            local hubContent
            local dlSuccess = pcall(function() 
                hubContent = game:HttpGet("https://raw.githubusercontent.com/apolo-developerhub/Apolo-Hub-V9/master/hub_v9.lua?t=" .. tick()) 
            end)
            
            if dlSuccess and hubContent then
                _notify("Hub baixado! Iniciando...")
                local func, err = loadstring(hubContent)
                if func then
                    local runSuccess, runErr = pcall(func)
                    if not runSuccess then
                        _notify("Erro na execucao: " .. tostring(runErr))
                    end
                else
                    _notify("Erro na compilacao: " .. tostring(err))
                end
            else
                _notify("Falha ao baixar o Hub! Verifique sua internet.")
            end
        else
            btn.Text = "ERRO!"
            btn.BackgroundColor3 = Color3.new(1, 0, 0)
            task.wait(1)
            btn.Text = "VERIFICAR"
            btn.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
        end
    end)
end

_init()
