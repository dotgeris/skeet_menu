local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Library Base
local Library = {
    Tabs = {},
    Elements = {},
    Connections = {},
    Flags = {}, -- Store update functions here
    Focused = nil,
    Theme = {
        Background = Color3.fromRGB(12, 12, 12),
        Secondary = Color3.fromRGB(18, 18, 18),
        Accent = Color3.fromRGB(255, 105, 180), -- Pink
        Border = Color3.fromRGB(40, 40, 40),
        Text = Color3.fromRGB(255, 255, 255),
        TextDark = Color3.fromRGB(160, 160, 160),
        Font = Enum.Font.Code,
        TextSize = 13
    }
}

-- Settings Table
local Settings = {
    Aimbot = {
        Enabled = false,
        AimPart = "Head",
        FOV = 150,
        Smoothing = 3,
        TeamCheck = true,
        KeyBind = Enum.UserInputType.MouseButton2,
        VisibleCheck = false,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255)
    },
    Visuals = {
        BoxESP = false,
        SkeletonESP = false,
        WeaponESP = false,
        HealthBar = false,
        TeamCheck = true,
        Color = Color3.fromRGB(0, 255, 150)
    },
    Misc = {
        TPKey = Enum.KeyCode.V,
        ThirdPerson = false,
        TPDistance = 10,
        Bunnyhop = false
    }
}

-- Logic Objects
local ESPFolder = workspace:FindFirstChild("Skeet_ESP") or Instance.new("Folder", workspace)
ESPFolder.Name = "Skeet_ESP"
local ESPObjects = {}
local PartCache = {}
local Camera = workspace.CurrentCamera

-- FOV Circles
local AimbotCircle = Drawing.new("Circle")
AimbotCircle.Thickness = 1
AimbotCircle.Transparency = 1
AimbotCircle.Visible = false

-- Helper Functions
local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function GetCharacterPart(player, partName)
    local char = player.Character
    if not char then return nil end
    
    if not PartCache[char] then PartCache[char] = {} end
    if PartCache[char][partName] and PartCache[char][partName].Parent == char then
        return PartCache[char][partName]
    end
    
    local part = char:FindFirstChild(partName)
    if not part then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("BasePart") and v.Name:find(partName) then part = v break end
        end
    end
    
    PartCache[char][partName] = part
    return part
end

function Library:Unload()
    for _, conn in pairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    for p, instance in pairs(ESPObjects) do
        pcall(function()
            if instance.Destroy then instance:Destroy()
            elseif typeof(instance) == "table" then
                for _, obj in pairs(instance) do
                    if typeof(obj) == "userdata" and obj.Remove then obj:Remove() end
                end
            end
        end)
    end
    if self.MainGui then self.MainGui:Destroy() end
    if self.Watermark then self.Watermark:Destroy() end
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
    pcall(function() AimbotCircle:Remove() end)
    table.clear(ESPObjects)
end

-- Removed Rage Hooks

function Library:CreateWindow(title)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SkeetMenu"
    ScreenGui.Parent = CoreGui or PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Library.MainGui = ScreenGui

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = self.Theme.Background
    MainFrame.BorderSizePixel = 1
    MainFrame.BorderColor3 = self.Theme.Border
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    MainFrame.Size = UDim2.new(0, 600, 0, 400)
    MakeDraggable(MainFrame)

    -- Watermark
    local Watermark = Instance.new("Frame", ScreenGui)
    Library.Watermark = Watermark
    Watermark.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Watermark.BorderSizePixel = 1
    Watermark.BorderColor3 = Color3.fromRGB(40, 40, 40)
    Watermark.Position = UDim2.new(0, 20, 0, 20)
    Watermark.Size = UDim2.new(0, 250, 0, 25)

    local AccentLine = Instance.new("Frame", Watermark)
    AccentLine.BackgroundColor3 = self.Theme.Accent
    AccentLine.BorderSizePixel = 0
    AccentLine.Size = UDim2.new(1, 0, 0, 2)
    
    local WatermarkLabel = Instance.new("TextLabel", Watermark)
    WatermarkLabel.BackgroundTransparency = 1
    WatermarkLabel.Position = UDim2.new(0, 8, 0, 0)
    WatermarkLabel.Size = UDim2.new(1, -16, 1, 0)
    WatermarkLabel.Font = self.Theme.Font
    WatermarkLabel.TextColor3 = self.Theme.Text
    WatermarkLabel.TextSize = self.Theme.TextSize
    WatermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    WatermarkLabel.Text = "skeet.cc | [" .. LocalPlayer.Name:lower() .. "] | 0 ms / 00:00:00"

    table.insert(Library.Connections, RunService.RenderStepped:Connect(function()
        local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        local timeStr = os.date("%I:%M %p"):lower()
        WatermarkLabel.Text = string.format("skeet.cc | [%s] | %d ms / %s", LocalPlayer.Name:lower(), ping, timeStr)
        local textBounds = game:GetService("TextService"):GetTextSize(WatermarkLabel.Text, self.Theme.TextSize, self.Theme.Font, Vector2.new(math.huge, math.huge))
        Watermark.Size = UDim2.new(0, textBounds.X + 20, 0, 22)
    end))

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            MainFrame.Visible = not MainFrame.Visible
            UserInputService.MouseIconEnabled = MainFrame.Visible
            UserInputService.MouseBehavior = MainFrame.Visible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
            
            -- Create invisible Modal button if it doesn't exist
            if not MainFrame:FindFirstChild("ModalButton") then
                local Modal = Instance.new("TextButton", MainFrame)
                Modal.Name = "ModalButton"
                Modal.Size = UDim2.new(0,0,0,0)
                Modal.Modal = true
                Modal.Visible = true
            end
            MainFrame.ModalButton.Modal = MainFrame.Visible
        elseif input.KeyCode == Enum.KeyCode.End then
            Library:Unload()
        end
    end)

    local TabContainer = Instance.new("Frame", MainFrame)
    TabContainer.BackgroundColor3 = self.Theme.Secondary
    TabContainer.BorderSizePixel = 1
    TabContainer.BorderColor3 = self.Theme.Border
    TabContainer.Size = UDim2.new(1, 0, 0, 30)

    local TabList = Instance.new("UIListLayout", TabContainer)
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local ContentArea = Instance.new("Frame", MainFrame)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Position = UDim2.new(0, 10, 0, 40)
    ContentArea.Size = UDim2.new(1, -20, 1, -50)

    local Window = {Tabs = {}}

    function Window:CreateTab(name)
        local TabButton = Instance.new("TextButton", TabContainer)
        TabButton.BackgroundColor3 = Library.Theme.Secondary
        TabButton.Size = UDim2.new(0, 100, 1, 0)
        TabButton.Font = Library.Theme.Font
        TabButton.Text = name:lower()
        TabButton.TextColor3 = Library.Theme.TextDark
        TabButton.TextSize = Library.Theme.TextSize
        TabButton.BorderSizePixel = 0

        local TabContent = Instance.new("Frame", ContentArea)
        TabContent.BackgroundTransparency = 1
        TabContent.Size = UDim2.new(1, 0, 1, 0)
        TabContent.Visible = false

        local LeftColumn = Instance.new("Frame", TabContent)
        LeftColumn.BackgroundTransparency = 1
        LeftColumn.Size = UDim2.new(0.5, -5, 1, 0)
        Instance.new("UIListLayout", LeftColumn).Padding = UDim.new(0, 10)

        local RightColumn = Instance.new("Frame", TabContent)
        RightColumn.BackgroundTransparency = 1
        RightColumn.Position = UDim2.new(0.5, 5, 0, 0)
        RightColumn.Size = UDim2.new(0.5, -5, 1, 0)
        Instance.new("UIListLayout", RightColumn).Padding = UDim.new(0, 10)

        TabButton.MouseButton1Click:Connect(function()
            for _, t in pairs(Window.Tabs) do
                t.Button.TextColor3 = Library.Theme.TextDark
                t.Content.Visible = false
            end
            TabButton.TextColor3 = Library.Theme.Text
            TabContent.Visible = true
        end)

        local Tab = {Button = TabButton, Content = TabContent, Left = LeftColumn, Right = RightColumn}
        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then TabButton.TextColor3 = Library.Theme.Text TabContent.Visible = true end

        function Tab:CreateGroupBox(title, side)
            local parent = (side == "right" and Tab.Right or Tab.Left)
            local GroupBox = Instance.new("Frame", parent)
            GroupBox.BackgroundColor3 = Library.Theme.Background
            GroupBox.BorderSizePixel = 1
            GroupBox.BorderColor3 = Library.Theme.Border
            GroupBox.Size = UDim2.new(1, 0, 0, 20)

            local Title = Instance.new("TextLabel", GroupBox)
            Title.BackgroundColor3 = Library.Theme.Background
            Title.Position = UDim2.new(0, 10, 0, -8)
            Title.Size = UDim2.new(0, 0, 0, 15)
            Title.Font = Library.Theme.Font
            Title.Text = " " .. title:lower() .. " "
            Title.TextColor3 = Library.Theme.Text
            Title.TextSize = Library.Theme.TextSize
            Title.AutomaticSize = Enum.AutomaticSize.X

            local Container = Instance.new("Frame", GroupBox)
            Container.BackgroundTransparency = 1
            Container.Position = UDim2.new(0, 10, 0, 10)
            Container.Size = UDim2.new(1, -20, 0, 0)
            local List = Instance.new("UIListLayout", Container)
            List.Padding = UDim.new(0, 5)
            List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                GroupBox.Size = UDim2.new(1, 0, 0, List.AbsoluteContentSize.Y + 20)
            end)

            local Group = {}
            function Group:CreateCheckBox(name, flag, callback)
                local CheckBoxContainer = Instance.new("TextButton", Container)
                CheckBoxContainer.BackgroundTransparency = 1
                CheckBoxContainer.Size = UDim2.new(1, 0, 0, 15)
                CheckBoxContainer.Text = ""
                local Box = Instance.new("Frame", CheckBoxContainer)
                Box.BackgroundColor3 = Library.Theme.Secondary
                Box.BorderSizePixel = 1
                Box.BorderColor3 = Library.Theme.Border
                Box.Size = UDim2.new(0, 10, 0, 10)
                Box.Position = UDim2.new(0, 0, 0.5, -5)
                local Label = Instance.new("TextLabel", CheckBoxContainer)
                Label.BackgroundTransparency = 1
                Label.Position = UDim2.new(0, 15, 0, 0)
                Label.Size = UDim2.new(1, -15, 1, 0)
                Label.Font = Library.Theme.Font
                Label.Text = name:lower()
                Label.TextColor3 = Library.Theme.TextDark
                Label.TextSize = Library.Theme.TextSize
                Label.TextXAlignment = Enum.TextXAlignment.Left
                local enabled = false
                
                local function set(v)
                    enabled = v
                    Box.BackgroundColor3 = enabled and Library.Theme.Accent or Library.Theme.Secondary
                    Label.TextColor3 = enabled and Library.Theme.Text or Library.Theme.TextDark
                    if callback then callback(enabled) end
                end
                
                CheckBoxContainer.MouseButton1Click:Connect(function() set(not enabled) end)
                if flag then Library.Flags[flag] = set end
                return {Set = set}
            end

            function Group:CreateSlider(name, flag, min, max, default, callback)
                local SliderContainer = Instance.new("Frame", Container)
                SliderContainer.BackgroundTransparency = 1
                SliderContainer.Size = UDim2.new(1, 0, 0, 30)
                local Label = Instance.new("TextLabel", SliderContainer)
                Label.BackgroundTransparency = 1
                Label.Size = UDim2.new(1, 0, 0, 15)
                Label.Font = Library.Theme.Font
                Label.Text = name:lower()
                Label.TextColor3 = Library.Theme.TextDark
                Label.TextSize = Library.Theme.TextSize
                Label.TextXAlignment = Enum.TextXAlignment.Left
                local SliderBG = Instance.new("Frame", SliderContainer)
                SliderBG.BackgroundColor3 = Library.Theme.Secondary
                SliderBG.BorderSizePixel = 1
                SliderBG.BorderColor3 = Library.Theme.Border
                SliderBG.Position = UDim2.new(0, 0, 0, 18)
                SliderBG.Size = UDim2.new(1, 0, 0, 8)
                local Fill = Instance.new("Frame", SliderBG)
                Fill.BackgroundColor3 = Library.Theme.Accent
                Fill.BorderSizePixel = 0
                Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
                local ValueLabel = Instance.new("TextLabel", SliderBG)
                ValueLabel.BackgroundTransparency = 1
                ValueLabel.Size = UDim2.new(1, 0, 1, 0)
                ValueLabel.Font = Library.Theme.Font
                ValueLabel.Text = tostring(default)
                ValueLabel.TextColor3 = Library.Theme.Text
                ValueLabel.TextSize = 10
                
                local function set(v)
                    local val = math.clamp(v, min, max)
                    Fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
                    ValueLabel.Text = tostring(val)
                    if callback then callback(val) end
                end
                
                local function update(input)
                    local pos = math.clamp((input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
                    local val = math.floor(min + (max - min) * pos)
                    set(val)
                end
                
                local dragging = false
                SliderBG.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update(input) end end)
                UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end end)
                
                if flag then Library.Flags[flag] = set end
                return {Set = set}
            end

            function Group:CreateKeyBind(name, flag, default, callback)
                local KeyBindContainer = Instance.new("Frame", Container)
                KeyBindContainer.BackgroundTransparency = 1
                KeyBindContainer.Size = UDim2.new(1, 0, 0, 20)
                local Label = Instance.new("TextLabel", KeyBindContainer)
                Label.BackgroundTransparency = 1
                Label.Size = UDim2.new(1, 0, 1, 0)
                Label.Font = Library.Theme.Font
                Label.Text = name:lower()
                Label.TextColor3 = Library.Theme.TextDark
                Label.TextSize = Library.Theme.TextSize
                Label.TextXAlignment = Enum.TextXAlignment.Left
                local BindButton = Instance.new("TextButton", KeyBindContainer)
                BindButton.BackgroundColor3 = Library.Theme.Secondary
                BindButton.BorderSizePixel = 1
                BindButton.BorderColor3 = Library.Theme.Border
                BindButton.Position = UDim2.new(1, -60, 0, 0)
                BindButton.Size = UDim2.new(0, 60, 1, 0)
                BindButton.Font = Library.Theme.Font
                BindButton.Text = default.Name:lower()
                BindButton.TextColor3 = Library.Theme.Text
                BindButton.TextSize = Library.Theme.TextSize
                
                local function set(v)
                    BindButton.Text = v.Name:lower()
                    if callback then callback(v) end
                end
                
                local binding = false
                BindButton.MouseButton1Click:Connect(function() binding = true BindButton.Text = "..." end)
                UserInputService.InputBegan:Connect(function(input)
                    if binding and input.UserInputType ~= Enum.UserInputType.MouseMovement then
                        local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
                        set(key)
                        binding = false
                    end
                end)
                
                if flag then Library.Flags[flag] = set end
                return {Set = set}
            end
            function Group:CreateDropdown(name, options, callback)
                local DropdownContainer = Instance.new("Frame", Container)
                DropdownContainer.BackgroundTransparency = 1
                DropdownContainer.Size = UDim2.new(1, 0, 0, 35)
                
                local Label = Instance.new("TextLabel", DropdownContainer)
                Label.BackgroundTransparency = 1
                Label.Size = UDim2.new(1, 0, 0, 15)
                Label.Font = Library.Theme.Font
                Label.Text = name:lower()
                Label.TextColor3 = Library.Theme.TextDark
                Label.TextSize = Library.Theme.TextSize
                Label.TextXAlignment = Enum.TextXAlignment.Left
                
                local Button = Instance.new("TextButton", DropdownContainer)
                Button.BackgroundColor3 = Library.Theme.Secondary
                Button.BorderSizePixel = 1
                Button.BorderColor3 = Library.Theme.Border
                Button.Position = UDim2.new(0, 0, 0, 18)
                Button.Size = UDim2.new(1, 0, 0, 15)
                Button.Font = Library.Theme.Font
                Button.Text = "none"
                Button.TextColor3 = Library.Theme.Text
                Button.TextSize = Library.Theme.TextSize
                
                local ListFrame = Instance.new("Frame", ScreenGui)
                ListFrame.BackgroundColor3 = Library.Theme.Background
                ListFrame.BorderSizePixel = 1
                ListFrame.BorderColor3 = Library.Theme.Border
                ListFrame.Visible = false
                ListFrame.ZIndex = 10
                
                local ListLayout = Instance.new("UIListLayout", ListFrame)
                
                local function updateOptions(newList)
                    for _, v in pairs(ListFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
                    for _, opt in pairs(newList) do
                        local OptBtn = Instance.new("TextButton", ListFrame)
                        OptBtn.BackgroundColor3 = Library.Theme.Secondary
                        OptBtn.BorderSizePixel = 0
                        OptBtn.Size = UDim2.new(1, 0, 0, 20)
                        OptBtn.Font = Library.Theme.Font
                        OptBtn.Text = opt
                        OptBtn.TextColor3 = Library.Theme.Text
                        OptBtn.TextSize = Library.Theme.TextSize
                        OptBtn.MouseButton1Click:Connect(function()
                            Button.Text = opt
                            ListFrame.Visible = false
                            if callback then callback(opt) end
                        end)
                    end
                    ListFrame.Size = UDim2.new(0, Button.AbsoluteSize.X, 0, #newList * 20)
                end
                
                updateOptions(options)
                
                Button.MouseButton1Click:Connect(function()
                    ListFrame.Visible = not ListFrame.Visible
                    ListFrame.Position = UDim2.new(0, Button.AbsolutePosition.X, 0, Button.AbsolutePosition.Y + 20)
                end)
                
                local Drop = {Update = updateOptions}
                return Drop
            end
            
            function Group:CreateButton(name, callback)
                local ButtonContainer = Instance.new("TextButton", Container)
                ButtonContainer.BackgroundColor3 = Library.Theme.Secondary
                ButtonContainer.BorderSizePixel = 1
                ButtonContainer.BorderColor3 = Library.Theme.Border
                ButtonContainer.Size = UDim2.new(1, 0, 0, 20)
                ButtonContainer.Font = Library.Theme.Font
                ButtonContainer.Text = name:lower()
                ButtonContainer.TextColor3 = Library.Theme.Text
                ButtonContainer.TextSize = Library.Theme.TextSize
                
                ButtonContainer.MouseButton1Click:Connect(function()
                    if callback then callback() end
                end)
            end
            return Group
        end
        return Tab
    end
    return Window
end

-- Config System
local HttpService = game:GetService("HttpService")
local SelectedConfig = "default"

local function SaveConfig(name)
    if writefile then
        local data = HttpService:JSONEncode(Settings)
        writefile(name .. ".json", data)
    end
end

local function LoadConfig(name)
    local fileName = name .. ".json"
    if isfile and isfile(fileName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        if success then
            for k, v in pairs(data) do
                if Settings[k] then
                    for k2, v2 in pairs(v) do
                        Settings[k][k2] = v2
                        -- Visual Update
                        local flag = k .. "_" .. k2
                        if Library.Flags[flag] then
                            Library.Flags[flag](v2)
                        end
                    end
                end
            end
        end
    end
end

local function GetConfigs()
    local configs = {}
    if listfiles then
        for _, file in pairs(listfiles("")) do
            if file:sub(-5) == ".json" then
                table.insert(configs, file:sub(1, -6))
            end
        end
    end
    if #configs == 0 then table.insert(configs, "default") end
    return configs
end

-- High-Performance Liquid ESP System
local ESPRenderer = {
    Cache = {},
    Interpolation = 0.8 -- Faster liquid factor
}

function ESPRenderer.Get(player)
    if not ESPRenderer.Cache[player] then
        local o = {
            Box = Drawing.new("Square"),
            BoxOutline = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            HealthBG = Drawing.new("Square"),
            HealthBar = Drawing.new("Square"),
            HealthNum = Drawing.new("Text"),
            Weapon = Drawing.new("Text"),
            Skeleton = {},
            LastPos = Vector2.new(0, 0),
            LastSize = Vector2.new(0, 0)
        }
        
        o.Box.Thickness = 1
        o.BoxOutline.Thickness = 3
        o.BoxOutline.Color = Color3.new(0,0,0)
        o.Name.Size, o.Name.Center, o.Name.Outline, o.Name.Font = 13, true, true, 2
        o.Weapon.Size, o.Weapon.Center, o.Weapon.Outline, o.Weapon.Font = 13, true, true, 2
        o.HealthBG.Color, o.HealthBG.Filled = Color3.new(0,0,0), true
        o.HealthBar.Filled = true
        o.HealthNum.Size, o.HealthNum.Outline, o.HealthNum.Font = 13, true, 2

        local bones = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
            {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
            {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
        }
        for _, b in pairs(bones) do
            local l = Drawing.new("Line")
            l.Thickness = 1
            l.Color = Color3.new(1,1,1)
            table.insert(o.Skeleton, {l, b[1], b[2]})
        end
        ESPRenderer.Cache[player] = o
    end
    return ESPRenderer.Cache[player]
end

function ESPRenderer.Clear(player)
    local o = ESPRenderer.Cache[player]
    if o then
        for _, obj in pairs(o) do
            if typeof(obj) == "table" then
                for _, sub in pairs(obj) do 
                    if typeof(sub) == "table" and sub[1] and typeof(sub[1]) == "userdata" then
                        pcall(function() sub[1]:Remove() end)
                    end 
                end
            elseif typeof(obj) == "userdata" then
                pcall(function() obj:Remove() end)
            end
        end
        ESPRenderer.Cache[player] = nil
    end
end

function ESPRenderer.Update()
    local myTeam = LocalPlayer.Team
    local mousePos = UserInputService:GetMouseLocation()
    local aimTarget = nil
    local shortestAimDist = Settings.Aimbot.FOV

    -- Garbage Collection
    for p, _ in pairs(ESPRenderer.Cache) do
        if not p or not p.Parent or not p:IsDescendantOf(Players) then ESPRenderer.Clear(p) end
    end

    for _, player in pairs(Players:GetPlayers()) do
        local o = ESPRenderer.Get(player)
        local char = player.Character
        local head = GetCharacterPart(player, "Head")
        local root = GetCharacterPart(player, "HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if char and head and root and hum and hum.Health > 0 and player ~= LocalPlayer then
            local isTeammate = player.Team and myTeam and player.Team == myTeam
            if not (Settings.Visuals.TeamCheck and isTeammate) then
                local headV, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                
                if onScreen then
                    local footV = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    local rootV = Camera:WorldToViewportPoint(root.Position)
                    
                    local rawHeight = math.abs(headV.Y - footV.Y)
                    local rawWidth = rawHeight / 1.5
                    local rawPos = Vector2.new(rootV.X - rawWidth/2, headV.Y)

                    -- Liquid Smoothing (Lerp)
                    if o.LastPos == Vector2.new(0, 0) then
                        o.LastPos, o.LastSize = rawPos, Vector2.new(rawWidth, rawHeight)
                    end
                    
                    o.LastPos = o.LastPos:Lerp(rawPos, ESPRenderer.Interpolation)
                    o.LastSize = o.LastSize:Lerp(Vector2.new(rawWidth, rawHeight), ESPRenderer.Interpolation)
                    
                    local pos, size = o.LastPos, o.LastSize

                    -- Box
                    o.Box.Visible = Settings.Visuals.BoxESP
                    o.Box.Size, o.Box.Position = size, pos
                    o.Box.Color = Settings.Visuals.Color
                    o.BoxOutline.Visible = Settings.Visuals.BoxESP
                    o.BoxOutline.Size, o.BoxOutline.Position = size, pos

                    -- Text
                    o.Name.Visible = Settings.Visuals.BoxESP
                    o.Name.Text, o.Name.Position = player.Name:lower(), Vector2.new(pos.X + size.X/2, pos.Y - 15)

                    -- Health
                    if Settings.Visuals.HealthBar then
                        local hpP = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        o.HealthBG.Visible, o.HealthBG.Size, o.HealthBG.Position = true, Vector2.new(4, size.Y + 2), Vector2.new(pos.X - 6, pos.Y - 1)
                        o.HealthBar.Visible, o.HealthBar.Size, o.HealthBar.Position = true, Vector2.new(2, size.Y * hpP), Vector2.new(pos.X - 5, pos.Y + (size.Y * (1 - hpP)))
                        o.HealthBar.Color = Color3.fromHSV(hpP * 0.3, 1, 1)
                        if hpP < 1 then
                            o.HealthNum.Visible, o.HealthNum.Text, o.HealthNum.Position = true, tostring(math.floor(hum.Health)), Vector2.new(pos.X - 8, pos.Y + (size.Y * (1 - hpP)) - 2)
                        else o.HealthNum.Visible = false end
                    else o.HealthBG.Visible, o.HealthBar.Visible, o.HealthNum.Visible = false, false, false end

                    -- Weapon
                    if Settings.Visuals.WeaponESP then
                        local tool = char:FindFirstChildOfClass("Tool")
                        o.Weapon.Visible, o.Weapon.Text, o.Weapon.Position = true, tool and tool.Name:lower() or "none", Vector2.new(pos.X + size.X/2, pos.Y + size.Y + 2)
                    else o.Weapon.Visible = false end

                    -- Skeleton
                    if Settings.Visuals.SkeletonESP then
                        for _, b in pairs(o.Skeleton) do
                            local p1, p2 = char:FindFirstChild(b[2]), char:FindFirstChild(b[3])
                            if p1 and p2 then
                                local v1, os1 = Camera:WorldToViewportPoint(p1.Position)
                                local v2, os2 = Camera:WorldToViewportPoint(p2.Position)
                                if os1 and os2 then
                                    b[1].Visible, b[1].From, b[1].To = true, Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y)
                                else b[1].Visible = false end
                            else b[1].Visible = false end
                        end
                    else for _, b in pairs(o.Skeleton) do b[1].Visible = false end end

                    -- Target Detection
                    local dist = (Vector2.new(headV.X, headV.Y) - mousePos).Magnitude
                    if Settings.Aimbot.Enabled and dist < shortestAimDist then aimTarget, shortestAimDist = head, dist end
                else
                    ESPRenderer.Hide(o)
                end
            else ESPRenderer.Hide(o) end
        else ESPRenderer.Hide(o) end
    end
    
    return aimTarget
end

function ESPRenderer.Hide(o)
    o.Box.Visible = false
    o.BoxOutline.Visible = false
    o.Name.Visible = false
    o.Weapon.Visible = false
    o.HealthBG.Visible = false
    o.HealthBar.Visible = false
    o.HealthNum.Visible = false
    for _, b in pairs(o.Skeleton) do b[1].Visible = false end
end

-- Central Loop
table.insert(Library.Connections, RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    local aimTarget = ESPRenderer.Update()

    -- Apply Aimbot
    if aimTarget then
        local bind = Settings.Aimbot.KeyBind
        local isAiming = false
        if typeof(bind) == "EnumItem" then
            if bind.EnumType == Enum.KeyCode then
                isAiming = UserInputService:IsKeyDown(bind)
            elseif bind.EnumType == Enum.UserInputType then
                isAiming = UserInputService:IsMouseButtonPressed(bind)
            end
        end
        
        if isAiming then
            local targetPos = Camera:WorldToViewportPoint(aimTarget.Position)
            local mousemove = (mousemoverel or (getgenv and getgenv().mousemoverel))
            if mousemove then
                mousemove((targetPos.X - mousePos.X) / Settings.Aimbot.Smoothing, (targetPos.Y - mousePos.Y) / Settings.Aimbot.Smoothing)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, aimTarget.Position), 1 / Settings.Aimbot.Smoothing)
            end
        end
    end

    -- Removed Rage Logic
end))

-- Third Person Fix
table.insert(Library.Connections, RunService.RenderStepped:Connect(function()
    if Settings.Misc.ThirdPerson then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Settings.Misc.TPDistance
        LocalPlayer.CameraMinZoomDistance = Settings.Misc.TPDistance
        Camera.FieldOfView = 90
    else
        LocalPlayer.CameraMaxZoomDistance = 12.5
        LocalPlayer.CameraMinZoomDistance = 0.5
    end
end))

table.insert(Library.Connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Misc.TPKey then Settings.Misc.ThirdPerson = not Settings.Misc.ThirdPerson end
end))

table.insert(Library.Connections, RunService.Stepped:Connect(function()
    if Settings.Misc.Bunnyhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
    end
end))

-- Removed Weapon Mod Heartbeat Loop

Players.PlayerRemoving:Connect(function(player)
    ESPRenderer.Clear(player)
end)

for _, p in pairs(Players:GetPlayers()) do ESPRenderer.Get(p) end

-- Final Execution
local Win = Library:CreateWindow("SKEET.CC")
local AimbotTab = Win:CreateTab("Aimbot")
local VisualsTab = Win:CreateTab("Visuals")
local MiscTab = Win:CreateTab("Misc")
local SettingsTab = Win:CreateTab("Settings")

-- Aimbot Tab
local AimbotGroup = AimbotTab:CreateGroupBox("aimbot", "left")
AimbotGroup:CreateCheckBox("enabled", "Aimbot_Enabled", function(v) Settings.Aimbot.Enabled = v end)
AimbotGroup:CreateCheckBox("team check", "Aimbot_TeamCheck", function(v) Settings.Aimbot.TeamCheck = v end)
AimbotGroup:CreateCheckBox("visible check", "Aimbot_VisibleCheck", function(v) Settings.Aimbot.VisibleCheck = v end)
AimbotGroup:CreateCheckBox("show fov", "Aimbot_ShowFOV", function(v) Settings.Aimbot.ShowFOV = v end)
AimbotGroup:CreateDropdown("target part", {"Head", "HumanoidRootPart", "UpperTorso"}, function(v) Settings.Aimbot.AimPart = v end)
AimbotGroup:CreateSlider("fov radius", "Aimbot_FOV", 0, 800, 150, function(v) Settings.Aimbot.FOV = v end)
AimbotGroup:CreateSlider("smoothing", "Aimbot_Smoothing", 1, 20, 3, function(v) Settings.Aimbot.Smoothing = v end)
AimbotGroup:CreateKeyBind("aim key", "Aimbot_Key", Enum.KeyCode.E, function(v) Settings.Aimbot.KeyBind = v end)

-- Visuals Tab
local ESPGroup = VisualsTab:CreateGroupBox("esp", "left")
ESPGroup:CreateCheckBox("box esp", "Visuals_BoxESP", function(v) Settings.Visuals.BoxESP = v end)
ESPGroup:CreateCheckBox("skeleton esp", "Visuals_SkeletonESP", function(v) Settings.Visuals.SkeletonESP = v end)
ESPGroup:CreateCheckBox("weapon esp", "Visuals_WeaponESP", function(v) Settings.Visuals.WeaponESP = v end)
ESPGroup:CreateCheckBox("health bar", "Visuals_HealthBar", function(v) Settings.Visuals.HealthBar = v end)
ESPGroup:CreateCheckBox("team check", "Visuals_TeamCheck", function(v) Settings.Visuals.TeamCheck = v end)

-- Misc Tab
local MovementGroup = MiscTab:CreateGroupBox("movement", "left")
MovementGroup:CreateCheckBox("bunnyhop", "Misc_Bhop", function(v) Settings.Misc.Bunnyhop = v end)
MovementGroup:CreateCheckBox("third person", "Misc_TP", function(v) Settings.Misc.ThirdPerson = v end)
MovementGroup:CreateSlider("tp distance", "Misc_TPDist", 1, 50, 10, function(v) Settings.Misc.TPDistance = v end)

local ESPCleanerGroup = MiscTab:CreateGroupBox("esp cleaner", "right")
ESPCleanerGroup:CreateButton("force clear esp", function()
    for p, _ in pairs(ESPRenderer.Cache) do
        ESPRenderer.Clear(p)
    end
    for _, p in pairs(Players:GetPlayers()) do ESPRenderer.Get(p) end
end)

local TPGroup = MiscTab:CreateGroupBox("third person", "right")
TPGroup:CreateCheckBox("enabled", "Misc_ThirdPerson", function(v) Settings.Misc.ThirdPerson = v end)
TPGroup:CreateKeyBind("toggle key", "Misc_TPKey", Settings.Misc.TPKey, function(k) Settings.Misc.TPKey = k end)
TPGroup:CreateSlider("distance", "Misc_TPDistance", 0, 50, 15, function(v) Settings.Misc.TPDistance = v end)

-- Settings Tab
local ConfigSelectGroup = SettingsTab:CreateGroupBox("configs", "left")
local ConfigDrop = ConfigSelectGroup:CreateDropdown("select config", GetConfigs(), function(v) SelectedConfig = v end)

local ConfigActionGroup = SettingsTab:CreateGroupBox("actions", "right")
ConfigActionGroup:CreateButton("save config", function() SaveConfig(SelectedConfig) end)
ConfigActionGroup:CreateButton("load config", function() LoadConfig(SelectedConfig) end)
ConfigActionGroup:CreateButton("refresh list", function() ConfigDrop.Update(GetConfigs()) end)

return Library
