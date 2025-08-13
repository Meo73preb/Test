-- AutoTP with UI + reliable respawn + fly to another map after finishing
-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ===== CONFIG =====
local CHEST_FOLDER_NAME = "ChestModels"
local TELEPORT_DELAY = 0.6        -- giây giữa 2 lần TP
local OFFSET_Y = 3                -- offset cao hơn part để tránh kẹt
local RESET_AFTER_FINISH = true   -- respawn khi hoàn tất
-- Tên map (child of workspace.Map) mà bạn muốn bay tới sau khi respawn
local FLY_TO_MAP = "MarineStart"  
local FLY_SPEED = 300             -- tốc độ bay (theo yêu cầu)
local FLY_ARRIVE_DIST = 10        -- khoảng cách đủ gần để dừng (studs)
local FLY_TIMEOUT = 30            -- timeout cho hành trình bay (giây)
-- ===================

local running = false
local processing = false

-- UI
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoTP_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 240, 0, 110)
    frame.Position = UDim2.new(0, 12, 0, 12)
    frame.BackgroundTransparency = 0.15
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -12, 0, 26)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "AutoTP — ChestModels"
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -12, 0, 18)
    status.Position = UDim2.new(0, 6, 0, 36)
    status.BackgroundTransparency = 1
    status.Text = "Status: Idle"
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 80, 0, 30)
    toggleBtn.Position = UDim2.new(0, 6, 1, -36)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50,120,50)
    toggleBtn.TextColor3 = Color3.fromRGB(230,230,230)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Text = "Start"
    toggleBtn.Parent = frame

    local resetBtn = Instance.new("TextButton")
    resetBtn.Name = "ResetBtn"
    resetBtn.Size = UDim2.new(0, 80, 0, 30)
    resetBtn.Position = UDim2.new(0, 96, 1, -36)
    resetBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
    resetBtn.TextColor3 = Color3.fromRGB(230,230,230)
    resetBtn.Font = Enum.Font.Gotham
    resetBtn.TextSize = 12
    resetBtn.Text = "Reset Now"
    resetBtn.Parent = frame

    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.Size = UDim2.new(1, -12, 0, 18)
    info.Position = UDim2.new(0, 6, 0, 58)
    info.BackgroundTransparency = 1
    info.Text = ("Fly to: %s @%d speed"):format(FLY_TO_MAP, FLY_SPEED)
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = Color3.fromRGB(180,180,180)
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = frame

    return {
        Gui = screenGui,
        Status = status,
        Toggle = toggleBtn,
        Reset = resetBtn,
    }
end

local ui = createUI()
local statusLabel = ui.Status
local toggleButton = ui.Toggle
local resetButton = ui.Reset

local function updateUI()
    if running then
        statusLabel.Text = "Status: Running"
        toggleButton.Text = "Stop"
        toggleButton.BackgroundColor3 = Color3.fromRGB(170,50,50)
    else
        statusLabel.Text = "Status: Idle"
        toggleButton.Text = "Start"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50,120,50)
    end
end

-- Helpers
local function getPrimaryPartFor(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart and obj.PrimaryPart:IsA("BasePart") then return obj.PrimaryPart end
        return obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function teleportCharacterTo(part)
    if not part or not part:IsA("BasePart") then return false end
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not hrp then return false end
    hrp.CFrame = part.CFrame + Vector3.new(0, OFFSET_Y, 0)
    return true
end

local function getChestParts()
    local folder = workspace:FindFirstChild(CHEST_FOLDER_NAME)
    if not folder then
        warn(("[AutoTP] Không tìm thấy %s trong Workspace."):format(CHEST_FOLDER_NAME))
        return {}
    end
    local parts = {}
    for _, child in ipairs(folder:GetChildren()) do
        local p = getPrimaryPartFor(child)
        if p then
            table.insert(parts, {part = p, name = child.Name})
        else
            warn(("[AutoTP] Bỏ qua %s (không tìm thấy BasePart)."):format(child.Name))
        end
    end
    return parts
end

-- Reliable respawn (tries LoadCharacter, otherwise kills humanoid)
local function respawnPlayer()
    local ok = pcall(function() player:LoadCharacter() end)
    if ok then return true end
    -- fallback: try kill humanoid (client-side)
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function() humanoid.Health = 0 end)
            return true
        end
    end
    -- if still not, try firing ResetButtonCallback (last resort)
    pcall(function()
        -- SetCore may be restricted; pcall to avoid errors
        game:GetService("StarterGui"):SetCore("ResetButtonCallback", true)
    end)
    return false
end

-- Fly to target map part using BodyVelocity (client)
local function flyToMapAfterRespawn()
    -- find target part inside workspace.Map
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then
        warn("[AutoTP] Không tìm thấy workspace.Map; không thể bay.")
        return
    end
    local target = mapFolder:FindFirstChild(FLY_TO_MAP)
    if not target then
        warn(("[AutoTP] Không tìm thấy map '%s' trong workspace.Map"):format(FLY_TO_MAP))
        return
    end
    local targetPart = getPrimaryPartFor(target)
    if not targetPart then
        warn(("[AutoTP] Map '%s' không có BasePart để bay tới."):format(FLY_TO_MAP))
        return
    end

    -- Wait for player's character to load
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp then
        warn("[AutoTP] Không tìm thấy HumanoidRootPart sau respawn.")
        return
    end

    -- disable physics control so flight is smooth
    if humanoid then
        humanoid.PlatformStand = true
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "AutoTP_FlyBV"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = hrp

    local startTime = tick()
    while tick() - startTime <= FLY_TIMEOUT do
        if not hrp.Parent then break end
        local dir = (targetPart.Position - hrp.Position)
        local dist = dir.Magnitude
        if dist <= FLY_ARRIVE_DIST then
            break
        end
        local vel = dir.Unit * FLY_SPEED
        bv.Velocity = Vector3.new(vel.X, vel.Y, vel.Z)
        RunService.Heartbeat:Wait()
    end

    -- cleanup
    if bv and bv.Parent then bv:Destroy() end
    if humanoid then
        humanoid.PlatformStand = false
    end
    print("[AutoTP] Bay hoàn tất (hoặc timeout).")
end

-- Main routine
local function runAutoTP()
    if processing then return end
    processing = true

    local parts = getChestParts()
    if #parts == 0 then
        warn("[AutoTP] Không tìm thấy chest hợp lệ để TP.")
        processing = false
        running = false
        updateUI()
        return
    end

    table.sort(parts, function(a,b) return a.name < b.name end)

    for i, item in ipairs(parts) do
        if not running then
            print("[AutoTP] Đã dừng giữa chừng bởi người dùng.")
            break
        end
        local success, err = pcall(function()
            if teleportCharacterTo(item.part) then
                print(("[AutoTP] TP tới %s (%d/%d)"):format(item.name, i, #parts))
            else
                warn(("[AutoTP] Không thể TP tới %s"):format(item.name))
            end
        end)
        if not success then
            warn("[AutoTP] Lỗi khi TP:", err)
        end

        -- wait but be interruptible by running flag
        local waits = TELEPORT_DELAY
        while waits > 0 and running do
            local dt = math.min(0.1, waits)
            task.wait(dt)
            waits = waits - dt
        end
    end

    -- Nếu vẫn đang bật và yêu cầu reset -> respawn rồi bay
    if running and RESET_AFTER_FINISH then
        print("[AutoTP] Hoàn tất TP danh sách. Thực hiện respawn...")
        local ok = respawnPlayer()
        if ok then
            -- đợi character mới xuất hiện
            player.CharacterAdded:Wait()
            task.wait(0.3) -- chờ một chút cho HRP ổn định
            -- sau khi respawn, fly to map
            flyToMapAfterRespawn()
        else
            warn("[AutoTP] Không respawn được.")
        end
    end

    running = false
    processing = false
    updateUI()
    print("[AutoTP] Hoàn tất hoặc dừng. Status:", running and "Running" or "Idle")
end

-- UI handlers
toggleButton.MouseButton1Click:Connect(function()
    running = not running
    updateUI()
    if running then
        task.spawn(runAutoTP)
    else
        print("[AutoTP] Người dùng tắt AutoTP.")
    end
end)

resetButton.MouseButton1Click:Connect(function()
    pcall(function() player:LoadCharacter() end)
    print("[AutoTP] Reset nhân vật theo yêu cầu.")
end)

updateUI()