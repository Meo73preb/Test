-- AutoTP Chest in workspace.ChestModels + fly to islands in workspace.Map in order
-- Special: workspace.Map.SkyArea2 will teleport directly

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ===== CONFIG =====
local CHEST_FOLDER = workspace:FindFirstChild("ChestModels")
local TELEPORT_DELAY = 0.6
local OFFSET_Y = 3
local FLY_SPEED = 350
local FLY_ARRIVE_DIST = 15
local FLY_TIMEOUT = 30
local ISLAND_LIST = {
    "Ice",
    "Jungle",
    "Magma",
    "MarineBase",
    "MarineStart",
    "Pirate",
    "Prison",
    "Windmill",
    "SkyArea2", -- Special: tp directly
}
local MAP_FOLDER = workspace:FindFirstChild("Map")
-- ===================

local running = false
local processing = false
local currentIslandIndex = 1

-- ===== UI Creation =====
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoTPChestFlyIslandsUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 180)
    frame.Position = UDim2.new(0, 20, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Text = "Auto TP Chest + Fly Islands"
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "Status: Ready"
    statusLabel.Size = UDim2.new(1, -20, 0, 25)
    statusLabel.Position = UDim2.new(0, 10, 0, 38)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 18
    statusLabel.TextColor3 = Color3.fromRGB(200,255,200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Text = "Islands: " .. table.concat(ISLAND_LIST, " → ")
    infoLabel.Size = UDim2.new(1, -20, 0, 22)
    infoLabel.Position = UDim2.new(0, 10, 0, 68)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 15
    infoLabel.TextColor3 = Color3.fromRGB(180,180,255)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Parent = frame

    local configLabel = Instance.new("TextLabel")
    configLabel.Text = "FlySpeed: "..FLY_SPEED.." | Delay: "..TELEPORT_DELAY
    configLabel.Size = UDim2.new(1, -20, 0, 20)
    configLabel.Position = UDim2.new(0, 10, 0, 96)
    configLabel.Font = Enum.Font.Gotham
    configLabel.TextSize = 14
    configLabel.TextColor3 = Color3.fromRGB(180,255,180)
    configLabel.BackgroundTransparency = 1
    configLabel.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Text = "Start"
    toggleButton.Size = UDim2.new(0.4, -10, 0, 36)
    toggleButton.Position = UDim2.new(0, 10, 0, 130)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 20
    toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    toggleButton.TextColor3 = Color3.new(1,1,1)
    toggleButton.Parent = frame

    local resetButton = Instance.new("TextButton")
    resetButton.Text = "Reset"
    resetButton.Size = UDim2.new(0.4, -10, 0, 36)
    resetButton.Position = UDim2.new(0.6, 10, 0, 130)
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
        statusLabel.Text = "Status: Running - Island: "..(ISLAND_LIST[currentIslandIndex] or "Done")
        toggleButton.Text = "Stop"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200,120,50)
    else
        statusLabel.Text = "Status: Ready"
        toggleButton.Text = "Start"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    end
end

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

local function getChestParts()
    if not CHEST_FOLDER then return {} end
    local result = {}
    for _,obj in ipairs(CHEST_FOLDER:GetChildren()) do
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

local function flyToIsland(islandName)
    if islandName == "SkyArea2" then
        -- TP trực tiếp
        local area = MAP_FOLDER and MAP_FOLDER:FindFirstChild(islandName)
        local part = area and getPrimaryPartFor(area)
        if part then
            teleportCharacterTo(part)
            return true
        end
        return false
    end

    local area = MAP_FOLDER and MAP_FOLDER:FindFirstChild(islandName)
    local targetPart = area and getPrimaryPartFor(area)
    if not targetPart then return false end

    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = root

    local arrived = false
    local start = tick()
    while (tick() - start < FLY_TIMEOUT) and not arrived and running do
        local direction = (targetPart.Position - root.Position)
        if direction.Magnitude < FLY_ARRIVE_DIST then
            arrived = true
            break
        end
        bv.Velocity = direction.Unit * FLY_SPEED
        RunService.RenderStepped:Wait()
    end

    bv:Destroy()
    return arrived
end

local function runAutoTP()
    processing = true

    -- TP tới từng chest trong ChestModels
    local chestParts = getChestParts()
    for _, part in ipairs(chestParts) do
        if not running then break end
        teleportCharacterTo(part)
        wait(TELEPORT_DELAY)
    end

    -- Fly/tp tới các đảo trong danh sách
    for idx, islandName in ipairs(ISLAND_LIST) do
        if not running then break end
        currentIslandIndex = idx
        updateUI()

        respawnPlayer()
        wait(1.5)
        flyToIsland(islandName)
        wait(1)
    end

    currentIslandIndex = #ISLAND_LIST + 1
    running = false
    processing = false
    updateUI()
end

toggleButton.MouseButton1Click:Connect(function()
    if not running then
        running = true
        currentIslandIndex = 1
        updateUI()
        spawn(runAutoTP)
    else
        running = false
        updateUI()
    end
end)

resetButton.MouseButton1Click:Connect(function()
    respawnPlayer()
end)

updateUI()
