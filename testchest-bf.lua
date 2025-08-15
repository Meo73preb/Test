-- Auto TP Chest, reset bằng kill humanoid, bay đến đảo ngẫu nhiên, lặp vô hạn

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

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

local running = false

-- UI omitted for brevity, focus vào hàm chính

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

local function flyToIsland(islandName)
    if islandName == "SkyArea2" then
        -- TP trực tiếp
        local area = MAP_FOLDER and MAP_FOLDER:FindFirstChild(islandName)
        local part = area and getPrimaryPartFor(area)
        if part then teleportCharacterTo(part) end
        return true
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

local function runLoopTP()
    running = true
    while running do
        -- 1. TP hết chest
        for _, part in ipairs(getChestParts()) do
            if not running then break end
            teleportCharacterTo(part)
            wait(TELEPORT_DELAY)
        end

        -- 2. Reset bằng kill humanoid
        killCharacter()
        wait(2)

        -- 3. Chọn đảo ngẫu nhiên
        local randIdx = math.random(1, #ISLAND_LIST)
        local islandName = ISLAND_LIST[randIdx]
        flyToIsland(islandName)
        wait(2)
        -- Lặp lại
    end
end

-- UI: Chỉ cần nút Start/Stop gọi spawn(runLoopTP) và running = false dừng lặp
