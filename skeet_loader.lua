-- Skeet.cc Premium Loader (Skeet Style Layout)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local ScriptURL = "https://raw.githubusercontent.com/dotgeris/skeet_menu/refs/heads/main/skeet_menu.lua"

local Theme = {
    Background = Color3.fromRGB(15, 15, 15),
    Secondary = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(40, 40, 40),
    Accent = Color3.fromRGB(255, 100, 150),
    Text = Color3.fromRGB(220, 220, 220),
    TextDim = Color3.fromRGB(100, 100, 100),
    Font = Enum.Font.Code,
    TextSize = 13
}

-- Create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SkeetLoader"
ScreenGui.Parent = CoreGui or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Theme.Border
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
MainFrame.Size = UDim2.new(0, 550, 0, 350)

-- Accent Line (Skeet Style)
local AccentLine = Instance.new("Frame", MainFrame)
AccentLine.BackgroundColor3 = Theme.Accent
AccentLine.BorderSizePixel = 0
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.ZIndex = 5

-- Header Title
local Title = Instance.new("TextLabel", MainFrame)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 10, 0, 5)
Title.Size = UDim2.new(1, -20, 0, 25)
Title.Font = Theme.Font
Title.TextColor3 = Theme.Text
Title.TextSize = 14
Title.Text = "SKEET.CC | LOADER"
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Draggable Logic (MainFrame)
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Login Page
local LoginPage = Instance.new("Frame", MainFrame)
LoginPage.BackgroundTransparency = 1
LoginPage.Size = UDim2.new(1, 0, 1, -30)
LoginPage.Position = UDim2.new(0, 0, 0, 30)

local KeyBox = Instance.new("TextBox", LoginPage)
KeyBox.BackgroundColor3 = Theme.Secondary
KeyBox.BorderColor3 = Theme.Border
KeyBox.Position = UDim2.new(0.5, -125, 0.45, -15)
KeyBox.Size = UDim2.new(0, 250, 0, 30)
KeyBox.Font = Theme.Font
KeyBox.PlaceholderText = "enter license key..."
KeyBox.PlaceholderColor3 = Color3.fromRGB(60, 60, 60)
KeyBox.Text = ""
KeyBox.TextColor3 = Theme.Text
KeyBox.TextSize = Theme.TextSize

local LoginBtn = Instance.new("TextButton", LoginPage)
LoginBtn.BackgroundColor3 = Theme.Secondary
LoginBtn.BorderColor3 = Theme.Border
LoginBtn.Position = UDim2.new(0.5, -125, 0.65, -15)
LoginBtn.Size = UDim2.new(0, 250, 0, 35)
LoginBtn.Font = Theme.Font
LoginBtn.Text = "LOGIN"
LoginBtn.TextColor3 = Theme.Text
LoginBtn.TextSize = Theme.TextSize

-- Dashboard Page
local Dashboard = Instance.new("Frame", MainFrame)
Dashboard.BackgroundTransparency = 1
Dashboard.Size = UDim2.new(1, 0, 1, -30)
Dashboard.Position = UDim2.new(0, 0, 0, 30)
Dashboard.Visible = false

-- Left: Game List (Skeet Style)
local ListFrame = Instance.new("Frame", Dashboard)
ListFrame.BackgroundColor3 = Theme.Secondary
ListFrame.BorderColor3 = Theme.Border
ListFrame.Position = UDim2.new(0, 10, 0, 10)
ListFrame.Size = UDim2.new(0, 180, 1, -20)

-- Right: Details Panel (Skeet Style)
local DetailsFrame = Instance.new("Frame", Dashboard)
DetailsFrame.BackgroundColor3 = Theme.Secondary
DetailsFrame.BorderColor3 = Theme.Border
DetailsFrame.Position = UDim2.new(0, 200, 0, 10)
DetailsFrame.Size = UDim2.new(1, -210, 1, -20)

local Banner = Instance.new("ImageLabel", DetailsFrame)
Banner.BackgroundColor3 = Theme.Background
Banner.BorderSizePixel = 0
Banner.Position = UDim2.new(0, 8, 0, 8)
Banner.Size = UDim2.new(1, -16, 0, 130)
Banner.ScaleType = Enum.ScaleType.Crop

local InfoHeader = Instance.new("TextLabel", DetailsFrame)
InfoHeader.BackgroundTransparency = 1
InfoHeader.Position = UDim2.new(0, 10, 0, 150)
InfoHeader.Size = UDim2.new(1, -20, 0, 20)
InfoHeader.Font = Theme.Font
InfoHeader.TextColor3 = Theme.Text
InfoHeader.TextSize = 13
InfoHeader.Text = "Informace o vasi licenci"
InfoHeader.TextXAlignment = Enum.TextXAlignment.Left

local InfoLine = Instance.new("Frame", DetailsFrame)
InfoLine.BackgroundColor3 = Theme.Border
InfoLine.BorderSizePixel = 0
InfoLine.Position = UDim2.new(0, 10, 0, 175)
InfoLine.Size = UDim2.new(1, -20, 0, 1)

local Stat1Label = Instance.new("TextLabel", DetailsFrame)
Stat1Label.BackgroundTransparency = 1
Stat1Label.Position = UDim2.new(0, 10, 0, 185)
Stat1Label.Size = UDim2.new(1, -20, 0, 20)
Stat1Label.Font = Theme.Font
Stat1Label.TextColor3 = Theme.TextDim
Stat1Label.TextSize = 11
Stat1Label.Text = "Konci za"
Stat1Label.TextXAlignment = Enum.TextXAlignment.Left

local Stat1Value = Instance.new("TextLabel", DetailsFrame)
Stat1Value.BackgroundTransparency = 1
Stat1Value.Position = UDim2.new(0, 10, 0, 185)
Stat1Value.Size = UDim2.new(1, -20, 0, 20)
Stat1Value.Font = Theme.Font
Stat1Value.TextColor3 = Theme.Text
Stat1Value.TextSize = 11
Stat1Value.Text = "365 dnu"
Stat1Value.TextXAlignment = Enum.TextXAlignment.Right

local Stat2Label = Stat1Label:Clone()
Stat2Label.Parent = DetailsFrame
Stat2Label.Position = UDim2.new(0, 10, 0, 205)
Stat2Label.Text = "Status"

local Stat2Value = Stat1Value:Clone()
Stat2Value.Parent = DetailsFrame
Stat2Value.Position = UDim2.new(0, 10, 0, 205)
Stat2Value.Text = "undetected"

local LoadBtn = Instance.new("TextButton", DetailsFrame)
LoadBtn.BackgroundColor3 = Theme.Background
LoadBtn.BorderColor3 = Theme.Border
LoadBtn.Position = UDim2.new(0, 10, 1, -50)
LoadBtn.Size = UDim2.new(1, -20, 0, 40)
LoadBtn.Font = Theme.Font
LoadBtn.Text = "LOAD"
LoadBtn.TextColor3 = Theme.Text
LoadBtn.TextSize = 14

-- Game Selection Logic
local Games = {
    {Name = "Blox Strike", Banner = "https://tr.rbxcdn.com/180DAY-d28428b85ec2871f2465470e8da2cb4d/768/432/Image/Webp/noFilter", Status = "undetected", Active = true},
    {Name = "Rivals", Banner = "https://tr.rbxcdn.com/180DAY-60c154f21752ff4cb520340183edb77a/768/432/Image/Webp/noFilter", Status = "testing", Active = false}
}

local SelectedGame = nil

local function SelectGame(gameData, button)
    SelectedGame = gameData
    Banner.Image = gameData.Banner
    Stat2Value.Text = gameData.Status
    Stat2Value.TextColor3 = gameData.Active and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 150, 0)
    LoadBtn.Text = gameData.Active and "LOAD" or "DISABLED"
    LoadBtn.TextColor3 = gameData.Active and Theme.Text or Theme.TextDim
    LoadBtn.AutoButtonColor = gameData.Active
    
    for _, child in pairs(ListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            TweenService:Create(child, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.TextDim}):Play()
        end
    end
    TweenService:Create(button, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Background, TextColor3 = Theme.Text}):Play()
end

for i, gameData in pairs(Games) do
    local GameBtn = Instance.new("TextButton", ListFrame)
    GameBtn.BackgroundColor3 = Theme.Secondary
    GameBtn.BorderSizePixel = 0
    GameBtn.Position = UDim2.new(0, 0, 0, (i-1) * 45)
    GameBtn.Size = UDim2.new(1, 0, 0, 45)
    GameBtn.Font = Theme.Font
    GameBtn.Text = " " .. gameData.Name:lower()
    GameBtn.TextColor3 = Theme.TextDim
    GameBtn.TextSize = 13
    GameBtn.TextXAlignment = Enum.TextXAlignment.Left
    
    GameBtn.MouseButton1Click:Connect(function() SelectGame(gameData, GameBtn) end)
    if i == 1 then SelectGame(gameData, GameBtn) end
end

-- Login Logic
LoginBtn.MouseButton1Click:Connect(function()
    if KeyBox.Text == "test" then
        LoginPage.Visible = false
        Dashboard.Visible = true
    end
end)

LoadBtn.MouseButton1Click:Connect(function()
    if SelectedGame and SelectedGame.Active then
        LoadBtn.Text = "loading..."
        local success, result = pcall(function()
            return loadstring(game:HttpGet(ScriptURL))()
        end)
        if success then ScreenGui:Destroy() else LoadBtn.Text = "error" warn(result) end
    end
end)

-- Effects
LoginBtn.MouseEnter:Connect(function() TweenService:Create(LoginBtn, TweenInfo.new(0.3), {BorderColor3 = Theme.Accent}):Play() end)
LoginBtn.MouseLeave:Connect(function() TweenService:Create(LoginBtn, TweenInfo.new(0.3), {BorderColor3 = Theme.Border}):Play() end)
KeyBox.Focused:Connect(function() TweenService:Create(KeyBox, TweenInfo.new(0.3), {BorderColor3 = Theme.Accent}):Play() end)
KeyBox.FocusLost:Connect(function() TweenService:Create(KeyBox, TweenInfo.new(0.3), {BorderColor3 = Theme.Border}):Play() end)
