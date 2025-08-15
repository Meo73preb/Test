-- AutoTP with UI + reliable respawn + fly to multiple islands (areas) in priority order
-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ===== CONFIG =====
local CHEST_FOLDER_NAME = "ChestModels"
local TELEPORT_DELAY = 0.6 -- Seconds between TPs
local OFFSET_Y = 3 -- Height offset for TP
local RESET_AFTER_FINISH = true -- Respawn after finish
local AREA_LIST = { "Magma", "Forest", "PirateVillage" } -- Priority order, top to bottom
local FLY_SPEED = 350 -- Flying speed
local FLY_ARRIVE_DIST = 15 -- Distance to stop (studs)
local FLY_TIMEOUT = 30 -- Max time per fly (seconds)
-- ===================

local running = false
local processing = false
local currentAreaIndex = 1

-- ===== UI Creation =====
local function createUI()
    -- Create ScreenGui & frame
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoTPFlyUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 170)
    frame.Position = UDim2.new(0, 20, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Text = "AutoTP + Fly Islands"
    title.Size = UDim2.new(1, 0, 0, 32)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "Status: Ready"
    statusLabel.Size = UDim2.new(1, -20, 0, 24)
    statusLabel.Position = UDim2.new(0, 10, 0, 36)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 18
    statusLabel.TextColor3 = Color3.fromRGB(200,255,200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Text = "Areas: " .. table.concat(AREA_LIST, " → ")
    infoLabel.Size = UDim2.new(1, -20, 0, 20)
    infoLabel.Position = UDim2.new(0, 10, 0, 66)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 16
    infoLabel.TextColor3 = Color3.fromRGB(180,180,255)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Parent = frame

    local configLabel = Instance.new("TextLabel")
    configLabel.Text = "Speed: "..FLY_SPEED.." | Delay: "..TELEPORT_DELAY
    configLabel.Size = UDim2.new(1, -20, 0, 20)
    configLabel.Position = UDim2.new(0, 10, 0, 90)
    configLabel.Font = Enum.Font.Gotham
    configLabel.TextSize = 15
    configLabel.TextColor3 = Color3.fromRGB(180,255,180)
    configLabel.BackgroundTransparency = 1
    configLabel.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Text = "Start"
    toggleButton.Size = UDim2.new(0.4, -10, 0, 36)
    toggleButton.Position = UDim2.new(0, 10, 0, 120)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 20
    toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    toggleButton.TextColor3 = Color3.new(1,1,1)
    toggleButton.Parent = frame

    local resetButton = Instance.new("TextButton")
    resetButton.Text = "Reset"
    resetButton.Size = UDim2.new(0.4, -10, 0, 36)
    resetButton.Position = UDim2.new(0.6, 10, 0, 120)
    resetButton.Font = Enum.Font.GothamBold
    resetButton.TextSize = 20
    resetButton.BackgroundColor3 = Color3.fromRGB(200,40,40)
    resetButton.TextColor3 = Color3.new(1,1,1)
    resetButton.Parent = frame

    return {
        ScreenGui = screenGui,
        Status = statusLabel,
        Toggle = toggleButton,
        Reset = resetButton,
        Info = infoLabel,
        Config = configLabel,
        Frame = frame
    }
end

local ui = createUI()
local statusLabel = ui.Status
local toggleButton = ui.Toggle
local resetButton = ui.Reset

local function updateUI()
    if running then
        statusLabel.Text = "Status: Running - Area: "..(AREA_LIST[currentAreaIndex] or "Done")
        toggleButton.Text = "Stop"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200,120,50)
    else
        statusLabel.Text = "Status: Ready"
        toggleButton.Text = "Start"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    end
end

-- ===== Helpers =====
local function getPrimaryPartFor(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

local function teleportCharacterTo(part)
    local character = player.Character
    if character and part then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = part.CFrame + Vector3.new(0, OFFSET_Y, 0)
        end
    end
end

local function getChestParts(areaName)
    -- Chỉ lấy chest trong khu vực (map) chỉ định
    local workspaceMap = workspace:FindFirstChild("Map")
    if not workspaceMap then return {} end
    local area = workspaceMap:FindFirstChild(areaName)
    if not area then return {} end
    local chestFolder = area:FindFirstChild(CHEST_FOLDER_NAME)
    if not chestFolder then return {} end
    local result = {}
    for _,obj in ipairs(chestFolder:GetChildren()) do
        local part = getPrimaryPartFor(obj)
        if part then
            table.insert(result, part)
        end
    end
    return result
end

local function respawnPlayer()
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if human then
        human.Health = 0
    end
    player:LoadCharacter()
end

local function flyToArea(areaName)
    -- Bay đến vị trí của đảo chỉ định bằng BodyVelocity
    local workspaceMap = workspace:FindFirstChild("Map")
    if not workspaceMap then return false end
    local targetArea = workspaceMap:FindFirstChild(areaName)
    if not targetArea then return false end
    local targetPart = getPrimaryPartFor(targetArea)
    if not targetPart then
        -- Nếu không có Primary
