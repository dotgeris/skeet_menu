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
    Rage = {
        SilentAim = false,
        AimPart = "Head",
        FOV = 150,
        TeamCheck = true,
        VisibleCheck = false,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 0, 0),
        AntiAim = false,
        SpinSpeed = 50
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
        Bunnyhop = false,
        ThirdPerson = false,
        TPKey = Enum.KeyCode.V,
        TPDistance = 15
    }
}

-- Logic Objects
local ESPFolder = workspace:FindFirstChild("Skeet_ESP") or Instance.new("Folder", workspace)
ESPFolder.Name = "Skeet_ESP"
local ESPObjects = {}
local PartCache = {}
local Camera = workspace.CurrentCamera
local SilentTarget = nil

-- FOV Circles
local AimbotCircle = Drawing.new("Circle")
AimbotCircle.Thickness = 1
AimbotCircle.Transparency = 1
AimbotCircle.Visible = false

local SilentCircle = Drawing.new("Circle")
SilentCircle.Thickness = 1
SilentCircle.Transparency = 1
SilentCircle.Visible = false

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
    local cacheKey = player.Name .. "_" .. (partName or "Head")
    if PartCache[cacheKey] and PartCache[cacheKey].Parent == char then return PartCache[cacheKey] end
    local part = char:FindFirstChild(partName)
    if not part then
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") and v.Name == partName then part = v break end
        end
    end
    PartCache[cacheKey] = part
    return part
end

function Library:Unload()
    for _, conn in pairs(self.Connections) do conn:Disconnect() end
    for _, objects in pairs(ESPObjects) do
        if objects.Box then objects.Box:Remove() end
        if objects.BoxOutline then objects.BoxOutline:Remove() end
        if objects.Name then objects.Name:Remove() end
        if objects.Weapon then objects.Weapon:Remove() end
        if objects.HealthBarBG then objects.HealthBarBG:Remove() end
        if objects.HealthBar then objects.HealthBar:Remove() end
        for _, l in pairs(objects.Skeleton) do if l[1] then l[1]:Remove() end end
    end
    if self.MainGui then self.MainGui:Destroy() end
    if self.Watermark then self.Watermark:Destroy() end
    if ESPFolder then ESPFolder:Destroy() end
    AimbotCircle:Remove()
    SilentCircle:Remove()
end

-- Silent Aim & Mouse Redirection
local hook = (hookmetamethod or (getgenv and getgenv().hookmetamethod))
if hook then
    local oldNamecall
    oldNamecall = hook(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() and Settings.Rage.SilentAim and SilentTarget then
            if method == "Raycast" then
                local origin = args[1]
                local direction = (SilentTarget.Position - origin).Unit * 1000
                args[2] = direction
                return oldNamecall(self, unpack(args))
            elseif method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                local ray = args[1]
                args[1] = Ray.new(ray.Origin, (SilentTarget.Position - ray.Origin).Unit * 1000)
                return oldNamecall(self, unpack(args))
            elseif method == "FireServer" and (tostring(self):lower():find("shoot") or tostring(self):lower():find("fire")) then
                -- Redirection for common remote-based shooting
                for i, arg in pairs(args) do
                    if typeof(arg) == "Vector3" then
                        args[i] = SilentTarget.Position
                    end
                end
                return oldNamecall(self, unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hook(game, "__index", function(self, index)
        if not checkcaller() and Settings.Rage.SilentAim and SilentTarget then
            if self:IsA("Mouse") then
                if index == "Hit" then return SilentTarget.CFrame
                elseif index == "Target" then return SilentTarget end
            end
        end
        return oldIndex(self, index)
    end)
end

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

-- ESP Logic
local function CreatePlayerESP(player)
    local function remove()
        if ESPObjects[player] then
            local o = ESPObjects[player]
            if o.Box then o.Box:Remove() end
            if o.BoxOutline then o.BoxOutline:Remove() end
            if o.Name then o.Name:Remove() end
            for _, l in pairs(o.Skeleton) do if l[1] then l[1]:Remove() end end
            ESPObjects[player] = nil
        end
    end

    local function create()
        remove()
        local objects = {
            BoxOutline = Drawing.new("Square"),
            Box = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            Weapon = Drawing.new("Text"),
            HealthBarBG = Drawing.new("Square"),
            HealthBar = Drawing.new("Square"),
            Skeleton = {}
        }
        
        objects.BoxOutline.Thickness = 3
        objects.BoxOutline.Color = Color3.new(0,0,0)
        objects.BoxOutline.Transparency = 1
        objects.BoxOutline.Filled = false
        objects.BoxOutline.Visible = false
        
        objects.Box.Thickness = 1
        objects.Box.Color = Settings.Visuals.Color
        objects.Box.Transparency = 1
        objects.Box.Filled = false
        objects.Box.Visible = false
        
        objects.Name.Size = 14
        objects.Name.Center = true
        objects.Name.Outline = true
        objects.Name.Color = Color3.new(1,1,1)
        objects.Name.Visible = false

        objects.Weapon.Size = 13
        objects.Weapon.Center = true
        objects.Weapon.Outline = true
        objects.Weapon.Color = Color3.new(1,1,1)
        objects.Weapon.Visible = false

        objects.HealthBarBG.Thickness = 1
        objects.HealthBarBG.Color = Color3.new(0,0,0)
        objects.HealthBarBG.Transparency = 1
        objects.HealthBarBG.Filled = true
        objects.HealthBarBG.Visible = false

        objects.HealthBar.Thickness = 1
        objects.HealthBar.Color = Color3.new(0,1,0)
        objects.HealthBar.Transparency = 1
        objects.HealthBar.Filled = true
        objects.HealthBar.Visible = false
        
        local connections = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
            {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
            {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
        }
        
        for _, pair in pairs(connections) do
            local line = Drawing.new("Line")
            line.Thickness = 1
            line.Color = Settings.Visuals.Color
            line.Transparency = 1
            line.Visible = false
            table.insert(objects.Skeleton, {line, pair[1], pair[2]})
        end
        
        ESPObjects[player] = objects
    end
    
    player.CharacterAdded:Connect(function() task.wait(0.5) create() end)
    if player.Character then create() end
end

-- Central Loop
table.insert(Library.Connections, RunService.RenderStepped:Connect(function()
    local myTeam = LocalPlayer.Team
    local mousePos = UserInputService:GetMouseLocation()
    
    local aimTarget = nil
    local shortestAimDist = math.huge
    local silentTarget = nil
    local shortestSilentDist = math.huge

    -- Update FOV Circles
    AimbotCircle.Position = mousePos
    AimbotCircle.Radius = Settings.Aimbot.FOV
    AimbotCircle.Visible = Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV
    AimbotCircle.Color = Settings.Aimbot.FOVColor

    SilentCircle.Position = mousePos
    SilentCircle.Radius = Settings.Rage.FOV
    SilentCircle.Visible = Settings.Rage.SilentAim and Settings.Rage.ShowFOV
    SilentCircle.Color = Settings.Rage.FOVColor

    for player, objects in pairs(ESPObjects) do
        local char = player.Character
        if char and player ~= LocalPlayer then
            local isTeammate = player.Team and myTeam and player.Team == myTeam
            local isVisible = not (Settings.Visuals.TeamCheck and isTeammate)
            
            local head = GetCharacterPart(player, "Head")
            local root = GetCharacterPart(player, "HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- Spectate Fix: Hide ESP for the person being spectated
            local spectating = (Camera.CameraSubject and Camera.CameraSubject:IsDescendantOf(char))

            if head and root and isVisible and not spectating then
                local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local footPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                
                local function hideAll()
                    objects.Box.Visible = false
                    objects.BoxOutline.Visible = false
                    objects.Name.Visible = false
                    objects.Weapon.Visible = false
                    objects.HealthBarBG.Visible = false
                    objects.HealthBar.Visible = false
                    for _, d in pairs(objects.Skeleton) do d[1].Visible = false end
                end

                if onScreen then
                    local height = math.abs(headPos.Y - footPos.Y)
                    local width = height / 2
                    local size = Vector2.new(width, height)
                    local position = Vector2.new(headPos.X - width/2, headPos.Y)
                    
                    -- Box & Name
                    objects.Box.Visible = Settings.Visuals.BoxESP
                    objects.Box.Size = size
                    objects.Box.Position = position
                    objects.BoxOutline.Visible = Settings.Visuals.BoxESP
                    objects.BoxOutline.Size = size
                    objects.BoxOutline.Position = position
                    objects.Name.Visible = Settings.Visuals.BoxESP
                    objects.Name.Text = player.Name:lower()
                    objects.Name.Position = Vector2.new(position.X + width/2, position.Y - 15)
                    
                    -- Health Bar
                    if Settings.Visuals.HealthBar and hum and hum.Health > 0 then
                        local hp = math.clamp(hum.Health, 0, hum.MaxHealth)
                        local hpPercent = hp / hum.MaxHealth
                        objects.HealthBarBG.Visible = true
                        objects.HealthBarBG.Size = Vector2.new(2, height)
                        objects.HealthBarBG.Position = Vector2.new(position.X - 5, position.Y)
                        objects.HealthBar.Visible = true
                        objects.HealthBar.Size = Vector2.new(2, height * hpPercent)
                        objects.HealthBar.Position = Vector2.new(position.X - 5, position.Y + (height * (1 - hpPercent)))
                        objects.HealthBar.Color = Color3.fromHSV(hpPercent * 0.3, 1, 1)
                    else
                        objects.HealthBarBG.Visible = false
                        objects.HealthBar.Visible = false
                    end

                    -- Weapon ESP
                    if Settings.Visuals.WeaponESP then
                        local tool = char:FindFirstChildOfClass("Tool")
                        objects.Weapon.Visible = true
                        objects.Weapon.Text = tool and tool.Name:lower() or "none"
                        objects.Weapon.Position = Vector2.new(position.X + width/2, position.Y + height + 5)
                    else
                        objects.Weapon.Visible = false
                    end

                    -- Skeleton (existing logic)
                    if Settings.Visuals.SkeletonESP then
                        for _, data in pairs(objects.Skeleton) do
                            local line, p1_name, p2_name = data[1], data[2], data[3]
                            local p1, p2 = GetCharacterPart(player, p1_name), GetCharacterPart(player, p2_name)
                            if p1 and p2 then
                                local v1, os1 = Camera:WorldToViewportPoint(p1.Position)
                                local v2, os2 = Camera:WorldToViewportPoint(p2.Position)
                                if os1 and os2 then
                                    line.Visible = true
                                    line.From = Vector2.new(v1.X, v1.Y)
                                    line.To = Vector2.new(v2.X, v2.Y)
                                    line.Color = Settings.Visuals.Color
                                else line.Visible = false end
                            else line.Visible = false end
                        end
                    else
                        for _, d in pairs(objects.Skeleton) do d[1].Visible = false end
                    end
                else
                    hideAll()
                end
            else
                -- Robust Cleanup for invisible/spectated players
                if objects.Box then objects.Box.Visible = false end
                if objects.BoxOutline then objects.BoxOutline.Visible = false end
                if objects.Name then objects.Name.Visible = false end
                if objects.Weapon then objects.Weapon.Visible = false end
                if objects.HealthBarBG then objects.HealthBarBG.Visible = false end
                if objects.HealthBar then objects.HealthBar.Visible = false end
                if objects.Skeleton then for _, d in pairs(objects.Skeleton) do d[1].Visible = false end end
            end

            -- Target Detection
            local head = GetCharacterPart(player, "Head")
            if head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    
                    -- Legit Aimbot Target
                    if Settings.Aimbot.Enabled and dist < Settings.Aimbot.FOV and dist < shortestAimDist then
                        if not (Settings.Aimbot.TeamCheck and isTeammate) then
                            local part = GetCharacterPart(player, Settings.Aimbot.AimPart)
                            local vis = true
                            if Settings.Aimbot.VisibleCheck then
                                local res = workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000, RaycastParams.new())
                                if res and not res.Instance:IsDescendantOf(char) then vis = false end
                            end
                            if vis then aimTarget, shortestAimDist = part, dist end
                        end
                    end

                    -- Silent Aim Target
                    if Settings.Rage.SilentAim and dist < Settings.Rage.FOV and dist < shortestSilentDist then
                        if not (Settings.Rage.TeamCheck and isTeammate) then
                            local part = GetCharacterPart(player, Settings.Rage.AimPart)
                            local vis = true
                            if Settings.Rage.VisibleCheck then
                                local res = workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000, RaycastParams.new())
                                if res and not res.Instance:IsDescendantOf(char) then vis = false end
                            end
                            if vis then silentTarget, shortestSilentDist = part, dist end
                        end
                    end
                end
            end
        end
    end

    SilentTarget = silentTarget

    -- Apply Aimbot
    if aimTarget then
        local bind = Settings.Aimbot.KeyBind
        local isAiming = (bind.Name:find("MouseButton") and UserInputService:IsMouseButtonPressed(bind)) or UserInputService:IsKeyDown(bind)
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

    -- Anti-Aim
    if Settings.Rage.AntiAim then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Settings.Rage.SpinSpeed), 0) end
    end

    -- Third Person (Force CameraMode)
    if Settings.Misc.ThirdPerson then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Settings.Misc.TPDistance
        LocalPlayer.CameraMinZoomDistance = Settings.Misc.TPDistance
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

Players.PlayerAdded:Connect(CreatePlayerESP)
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        local o = ESPObjects[player]
        if o.Box then o.Box:Remove() end
        if o.BoxOutline then o.BoxOutline:Remove() end
        if o.Name then o.Name:Remove() end
        if o.Weapon then o.Weapon:Remove() end
        if o.HealthBarBG then o.HealthBarBG:Remove() end
        if o.HealthBar then o.HealthBar:Remove() end
        if o.ArmorBarBG then o.ArmorBarBG:Remove() end
        if o.ArmorBar then o.ArmorBar:Remove() end
        if o.Skeleton then for _, l in pairs(o.Skeleton) do if l[1] then l[1]:Remove() end end end
        ESPObjects[player] = nil
    end
end)
for _, p in pairs(Players:GetPlayers()) do CreatePlayerESP(p) end

-- Final Execution
local Win = Library:CreateWindow("SKEET.CC")
local RageTab = Win:CreateTab("Ragebot")
local VisualsTab = Win:CreateTab("Visuals")
local MiscTab = Win:CreateTab("Misc")
local SettingsTab = Win:CreateTab("Settings")

-- Rage Tab
local SilentGroup = RageTab:CreateGroupBox("silent aim", "left")
SilentGroup:CreateCheckBox("enabled", "Rage_SilentAim", function(v) Settings.Rage.SilentAim = v end)
SilentGroup:CreateCheckBox("team check", "Rage_TeamCheck", function(v) Settings.Rage.TeamCheck = v end)
SilentGroup:CreateCheckBox("visible check", "Rage_VisibleCheck", function(v) Settings.Rage.VisibleCheck = v end)
SilentGroup:CreateCheckBox("show fov", "Rage_ShowFOV", function(v) Settings.Rage.ShowFOV = v end)
SilentGroup:CreateSlider("fov radius", "Rage_FOV", 0, 800, 150, function(v) Settings.Rage.FOV = v end)

local AAGroup = RageTab:CreateGroupBox("anti-aim", "right")
AAGroup:CreateCheckBox("enabled", "Rage_AntiAim", function(v) Settings.Rage.AntiAim = v end)
AAGroup:CreateSlider("spin speed", "Rage_SpinSpeed", 0, 100, 50, function(v) Settings.Rage.SpinSpeed = v end)

local AimbotGroup = RageTab:CreateGroupBox("legit aimbot", "left")
AimbotGroup:CreateCheckBox("enabled", "Aimbot_Enabled", function(v) Settings.Aimbot.Enabled = v end)
AimbotGroup:CreateCheckBox("team check", "Aimbot_TeamCheck", function(v) Settings.Aimbot.TeamCheck = v end)
AimbotGroup:CreateCheckBox("visible check", "Aimbot_VisibleCheck", function(v) Settings.Aimbot.VisibleCheck = v end)
AimbotGroup:CreateCheckBox("show fov", "Aimbot_ShowFOV", function(v) Settings.Aimbot.ShowFOV = v end)
AimbotGroup:CreateKeyBind("aim key", "Aimbot_KeyBind", Settings.Aimbot.KeyBind, function(k) Settings.Aimbot.KeyBind = k end)
AimbotGroup:CreateSlider("fov radius", "Aimbot_FOV", 0, 800, 150, function(v) Settings.Aimbot.FOV = v end)
AimbotGroup:CreateSlider("smoothing", "Aimbot_Smoothing", 1, 20, 3, function(v) Settings.Aimbot.Smoothing = v end)

-- Visuals Tab
local ESPGroup = VisualsTab:CreateGroupBox("esp", "left")
ESPGroup:CreateCheckBox("box esp", "Visuals_BoxESP", function(v) Settings.Visuals.BoxESP = v end)
ESPGroup:CreateCheckBox("skeleton esp", "Visuals_SkeletonESP", function(v) Settings.Visuals.SkeletonESP = v end)
ESPGroup:CreateCheckBox("weapon esp", "Visuals_WeaponESP", function(v) Settings.Visuals.WeaponESP = v end)
ESPGroup:CreateCheckBox("health bar", "Visuals_HealthBar", function(v) Settings.Visuals.HealthBar = v end)
ESPGroup:CreateCheckBox("team check", "Visuals_TeamCheck", function(v) Settings.Visuals.TeamCheck = v end)

-- Misc Tab
local MovementGroup = MiscTab:CreateGroupBox("movement", "left")
MovementGroup:CreateCheckBox("bunnyhop", "Misc_Bunnyhop", function(v) Settings.Misc.Bunnyhop = v end)

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
ConfigActionGroup:CreateButton("refresh list", function() ConfigDrop:Update(GetConfigs()) end)

return Library
