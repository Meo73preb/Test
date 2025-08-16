-- Chờ game và GUI sẵn sàng
local Players = game:GetService("Players")
repeat task.wait() until game:IsLoaded() and Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")

-- Danh sách key hợp lệ
local validKeys = {
    ["key_75088"] = true,
    ["key_test"] = true,
    ["key nhập ở đây"] = false
}

-- Lấy key từ getgenv
local inputKey = tostring(getgenv().Key or "")

if validKeys[inputKey] then
    print("✅ Key đúng! Đang chạy script...")

    -- Tải và chạy script với xử lý lỗi
    local success, err = pcall(function()
        local code = game:HttpGet("https://raw.githubusercontent.com/Meo73preb/Test/refs/heads/main/testchest-bf.lua")
        loadstring(code)()
    end)

    if not success then
        warn("❌ Lỗi khi tải hoặc chạy script chính: " .. tostring(err))
        return
    end

    -- Hiện thông báo
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Thông báo";
            Text = "Chào mừng bạn vào script!";
            Duration = 5;
        })
    end)

else
    -- Thông báo key sai
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Thông báo";
            Text = "❌ Key sai! Mua key để sử dụng!",
            Duration = 5;
        })
    end)
    return
end
