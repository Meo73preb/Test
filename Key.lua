-- Danh sách key hợp lệ
local validKeys = {
    ["key_75088"] = true,
    ["key_test"] = true,
    ["key nhập ở đây"] = false
}

-- Lấy key từ getgenv
local inputKey = tostring(getgenv().Key or "")

-- Kiểm tra key
if validKeys[inputKey] then
    print("✅ Key đúng! Chạy script...")
    -- CODE CHÍNH CỦA BẠN VIẾT Ở DƯỚI 
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Meo73preb/Test/refs/heads/main/testchest-bf.lua"))()
    game.StarterGui:SetCore("SendNotification", {
        Title = "Thông báo";
        Text = "Chào mừng bạn vào script VIP!";
        Duration = 5;
    })
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Thông báo";
        Text = "❌️ key sai mua key để sài!";
        Duration = 5;
    })
    return
end
