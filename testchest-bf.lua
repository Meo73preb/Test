-- AutoTP chest + Respawn + Fly to random map + Loop

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ===== CONFIG =====
local CHEST_FOLDER_NAME = "ChestModels"
local TELEPORT_DELAY = 0.6
local OFFSET_Y = 3
local RESET_AFTER_FINISH = true
local FLY_SPEED = 350
local FLY_ARRIVE_DIST = 15
local FLY_TIMEOUT = 30
-- ===================

local running = false
local processing = false

-- UI: Tạo UI đơn giản
local function createUI()
    local ScreenGui = Instance.new("ScreenGui", player.PlayerGui)
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 200, 0, 120)
    Frame.Position = UDim2.new(0.05, 0, 0.2, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Frame.Active = true
    Frame.Draggable = true
    
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundTransparency = 1
    Title.Text = "Auto Chest + Fly Loop"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.TextScaled = true

    local Status = Instance.new("TextLabel", Frame)
    Status.Position = UDim2.new(0, 0, 0.3, 0)
    Status.Size = UDim2.new(1, 0, 0, 20)
    Status.BackgroundTransparency = 1
    Status.Text = "Trạng thái: Dừng"
    Status.TextColor3 = Color3.new(1, 1, 1)
    Status.TextScaled = true

    local Toggle = Instance.new("TextButton", Frame)
    Toggle.Position = UDim2.new(0, 0, 0.55, 0)
    Toggle.Size = UDim2.new(1, 0, 0, 25)
    Toggle.Text = "Bắt đầu"
    Toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    Toggle.TextColor3 = Color3.new(1, 1, 1)
    Toggle.TextScaled = true

    return {Frame = Frame, Status = Status, Toggle = Toggle}
end

local ui = createUI()

local function updateUI()
    ui.Status.Text = running and "Trạng thái: Đang chạy" or "Trạng thái: Dừng"
    ui.Toggle.Text = running and "Dừng" or "Bắt đầu"
    ui.Toggle.BackgroundColor3 = running and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(0, 170, 0)
end

-- Helper: Lấy part chính
local function getPrimaryPartFor(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

-- Helper: Teleport tới chest
local function teleportCharacterTo(part)
    if not player.Character or not part then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = part.CFrame + Vector3.new(0, OFFSET_Y, 0)
    end
end

-- Lấy danh sách chest
local function getChestParts()
    local chestFolder = workspace:FindFirstChild(CHEST_FOLDER_NAME)
    if not chestFolder then return {} end
    local list = {}
    for _, obj in pairs(chestFolder:GetDescendants()) do
        local p = getPrimaryPartFor(obj)
        if p then
            table.insert(list, p)
        end
    end
    return list
end

-- Respawn
local function respawnPlayer()
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character:FindFirstChildOfClass("Humanoid").Health = 0
    else
        player:LoadCharacter()
    end
    repeat RunService.Heartbeat:Wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

-- Lấy map ngẫu nhiên
local function getRandomMapPart()
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    local candidates = {}
    for _, child in ipairs(mapFolder:GetChildren()) do
        local p = getPrimaryPartFor(child)
        if p then
            table.insert(candidates, p)
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

-- Bay tới map
local function flyToMap(targetPart)
    if not targetPart then return end
    local startTime = tick()
    local hrp = player.Character:WaitForChild("HumanoidRootPart")
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    while tick() - startTime < FLY_TIMEOUT do
        if not hrp or not targetPart then break end
        local dir = (targetPart.Position - hrp.Position)
        if dir.Magnitude < FLY_ARRIVE_DIST then
            break
        end
        bv.Velocity = dir.Unit * FLY_SPEED
        RunService.Heartbeat:Wait()
    end
    bv:Destroy()
end

-- Main loop
local function runAutoLoop()
    while running do
        processing = true
        -- 1. Teleport tới tất cả chest
        local chests = getChestParts()
        for _, chest in ipairs(chests) do
            teleportCharacterTo(chest)
            task.wait(TELEPORT_DELAY)
        end

        -- 2. Respawn và bay tới map ngẫu nhiên
        if RESET_AFTER_FINISH then
            respawnPlayer()
            task.wait(0.5)
            local targetMap = getRandomMapPart()
            if targetMap then
                flyToMap(targetMap)
            end
        end
    end
    processing = false
end

-- Nút toggle
ui.Toggle.MouseButton1Click:Connect(function()
    running = not running
    updateUI()
    if running and not processing then
        task.spawn(runAutoLoop)
    end
end)

updateUI()
