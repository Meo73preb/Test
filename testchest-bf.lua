-- Cat x Chest: Auto TP Chest (2 lần mỗi chest) + reset nhân vật + bay tới đảo ngẫu nhiên + xử lý đặc biệt cho SkyArea2 + noclip khi bay, UI cho Delta X

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ===== CONFIG =====
local CHEST_FOLDER = workspace:FindFirstChild("ChestModels")
local ISLAND_LIST = {
    "Ice","Jungle","Magma","MarineBase","MarineStart",
    "Pirate","Prison","Windmill","SkyArea2"
}
local MAP_FOLDER = workspace:FindFirstChild("Map")
local TELEPORT_DELAY = 0.6
local OFFSET_Y = 3
local FLY_SPEED = 350
local FLY_ARRIVE_DIST = 15
local FLY_TIMEOUT = 30
-- ===================

local running = false
local currentIsland = ""

--- ===== UI Creation =====
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Cat_x_Chest_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 170)
    frame.Position = UDim2.new(0, 20, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Text = "Cat x Chest"
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "Status: Ready"
    statusLabel.Size = UDim2.new(1, -20, 0, 24)
    statusLabel.Position = UDim2.new(0, 10, 0, 38)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 18
    statusLabel.TextColor3 = Color3.fromRGB(200,255,200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Text = "Islands: " .. table.concat(ISLAND_LIST, " | ")
    infoLabel.Size = UDim2.new(1, -20, 0, 24)
    infoLabel.Position = UDim2.new(0, 10, 0, 66)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 15
    infoLabel.TextColor3 = Color3.fromRGB(180,180,255)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Text = "Start"
    toggleButton.Size = UDim2.new(0.4, -10, 0, 36)
    toggleButton.Position = UDim2.new(0, 10, 0, 110)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 20
    toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    toggleButton.TextColor3 = Color3.new(1,1,1)
    toggleButton.Parent = frame

    local resetButton = Instance.new("TextButton")
    resetButton.Text = "Reset"
    resetButton.Size = UDim2.new(0.4, -10, 0, 36)
    resetButton.Position = UDim2.new(0.6, 10, 0, 110)
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
        Frame = frame
    }
end

local ui = createUI()
local statusLabel = ui.Status
local toggleButton = ui.Toggle
local resetButton = ui.Reset

local function updateUI()
    if running then
        statusLabel.Text = "Status: Running - Đảo: " .. (currentIsland or "")
        toggleButton.Text = "Stop"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200,120,50)
    else
        statusLabel.Text = "Status: Ready"
        toggleButton.Text = "Start"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50,180,80)
    end
end

-- ==== Helper Functions ====
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

local function killCharacter()
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if human then
        human.Health = 0
    end
end

-- Noclip: liên tục set CanCollide = false cho các part của nhân vật
local noclipActive = false
local function enableNoclip()
    noclipActive = true
    RunService.Stepped:Connect(function()
        if noclipActive and player.Character then
            for _,v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end
local function disableNoclip()
    noclipActive = false
    if player.Character then
        for _,v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = true
            end
        end
    end
end

local function flyToIsland(islandName)
    if islandName == "SkyArea2" then
        -- Đảo đặc biệt: TP tới Exit, chờ 2s, rồi bay tới Bell
        local skyArea = MAP_FOLDER and MAP_FOLDER:FindFirstChild("SkyArea2")
        if not skyArea then return false end

        local pathwayHouse = skyArea:FindFirstChild("PathwayHouse")
        local exitPart = pathwayHouse and pathwayHouse:FindFirstChild("Exit")
        if exitPart then
            teleportCharacterTo(exitPart)
            wait(2)
        end

        -- Bay tới Bell
        local bellPath = skyArea:FindFirstChild("Bell")
        local bellModel = bellPath and bellPath:FindFirstChild("Model")
        local bellPart = bellModel and bellModel:FindFirstChild("Bell")
        if bellPart then
            enableNoclip()
            local character = player.Character or player.CharacterAdded:Wait()
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Parent = root
                local arrived = false
                local start = tick()
                while (tick() - start < FLY_TIMEOUT) and not arrived and running do
                    local direction = (bellPart.Position - root.Position)
                    if direction.Magnitude < FLY_ARRIVE_DIST then
                        arrived = true
                        break
                    end
                    bv.Velocity = direction.Unit * FLY_SPEED
                    RunService.RenderStepped:Wait()
                end
                bv:Destroy()
            end
            disableNoclip()
            return true
        end
        return false
    end

    -- Đảo thường: bay tới PrimaryPart
    local area = MAP_FOLDER and MAP_FOLDER:FindFirstChild(islandName)
    local targetPart = area and getPrimaryPartFor(area)
    if not targetPart then return false end

    enableNoclip()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        disableNoclip()
        return false
    end

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
    disableNoclip()
    return arrived
end

local function runLoopTP()
    running = true
    while running do
        currentIsland = ""
        updateUI()
        -- 1. TP 2 lần mỗi chest trong ChestModels
        for _, part in ipairs(getChestParts()) do
            if not running then break end
            teleportCharacterTo(part)
            wait(TELEPORT_DELAY)
            teleportCharacterTo(part)
            wait(TELEPORT_DELAY)
        end

        -- 2. Reset nhân vật bằng kill Humanoid
        killCharacter()
        player.CharacterAdded:Wait()
        wait(0.5)

        -- 3. Chọn đảo ngẫu nhiên, bay tới đó
        local randIdx = math.random(1, #ISLAND_LIST)
        currentIsland = ISLAND_LIST[randIdx]
        updateUI()
        flyToIsland(currentIsland)
        wait(1.5)
        -- Lặp lại
    end
    currentIsland = ""
    updateUI()
end

toggleButton.MouseButton1Click:Connect(function()
    if not running then
        running = true
        updateUI()
        spawn(runLoopTP)
    else
        running = false
        updateUI()
    end
end)

resetButton.MouseButton1Click:Connect(function()
    killCharacter()
end)

updateUI()
