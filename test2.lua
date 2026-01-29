local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local whitelistHWID = "59306c08c3a447f9577e9820fd945208fe4e1cba0480a9e68a9919dbf48fbcd2"
local currentHWID = gethwid()

if currentHWID ~= whitelistHWID then
    local webhookUrl = "https://discord.com/api/webhooks/1466531868299231262/oH926KQVk6giQU-64HSJev_BFm3k57RFjn6u54EW8NDHya-Aq1ORr-_lEAO6DPjIE722"
    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "Whitelist Violation",
            ["color"] = 16711680,
            ["fields"] = {
                {["name"] = "User", ["value"] = player.Name .. " (" .. player.UserId .. ")", ["inline"] = false},
                {["name"] = "HWID", ["value"] = currentHWID, ["inline"] = false}
            }
        }}
    }
    request({
        Url = webhookUrl,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
    player:Kick("Unauthorized HWID.")
    return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local backpack = player:WaitForChild("Backpack")
local toolsStorage = ReplicatedStorage:WaitForChild("Tools")
local roduxPath = ReplicatedStorage:WaitForChild("TS"):WaitForChild("store"):WaitForChild("rodux")
local store = require(roduxPath).ClientStore
local invUpdateEvent = player:WaitForChild("InventoryUpdateEvent")

local settings = _G.ToolSettings or {}
local instantGive = settings.instantGive
local useIgnoreList = settings.useIgnoreList
local showUI = settings.showUI
local fuckEverything = settings.fuckEverything
local scriptList = settings.scriptList
local ignoreList = settings.ignoreList
local toolAmounts = settings.toolAmounts

local startTime = os.clock()
local gui, label

if showUI then
    gui = Instance.new("ScreenGui")
    gui.Name = "CounterGui"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 300, 0, 50)
    label.Position = UDim2.new(0, 20, 1, -20)
    label.AnchorPoint = Vector2.new(0, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextSize = 25
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = gui
end

local specialScripts = {}
for _, name in ipairs(scriptList) do specialScripts[name] = true end
local currentIgnored = {}
for _, name in ipairs(ignoreList) do currentIgnored[name] = true end

local function sync()
    local invItems = {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then table.insert(invItems, item) end
    end
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then table.insert(invItems, item) end
        end
    end
    local character = player.Character
    local activeTool = character and character:FindFirstChildOfClass("Tool")
    local inventoryData = {items = invItems, contents = invItems, hand = activeTool}
    store:dispatch({type = "InventorySetInventory", inventory = inventoryData})
    store:dispatch({type = "InventoryUpdate", inventory = inventoryData})
    invUpdateEvent:Fire()
end

local function isToolBroken(tool)
    if not tool:IsA("Tool") then return true end
    if not tool:FindFirstChild("Handle") then return true end
    local amtCount = 0
    local dispCount = 0
    for _, child in ipairs(tool:GetChildren()) do
        if child.Name == "Amount" then amtCount = amtCount + 1 end
        if child.Name == "DisplayName" then dispCount = dispCount + 1 end
    end
    if amtCount ~= 1 then return true end
    if dispCount > 1 then return true end
    return false
end

local function cleanContainer(container)
    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Tool") then
            if not fuckEverything then
                if currentIgnored[item.Name] or isToolBroken(item) then
                    item:Destroy()
                end
            end
        end
    end
end

cleanContainer(backpack)
if player.Character then cleanContainer(player.Character) end
sync()

local validTools = {}
local processedNames = {}
for _, tool in ipairs(toolsStorage:GetChildren()) do
    if tool:IsA("Tool") and not processedNames[tool.Name] then
        local valid = true
        if not fuckEverything then
            if currentIgnored[tool.Name] or isToolBroken(tool) then
                valid = false
            end
        end
        if valid then
            table.insert(validTools, tool)
            processedNames[tool.Name] = true
        end
    end
end

local total = #validTools
local spawnedCount = 0
for _, tool in ipairs(validTools) do
    spawnedCount = spawnedCount + 1
    if label then label.Text = spawnedCount .. " / " .. total end
    
    local isSpecial = false
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("LocalScript") and specialScripts[child.Name] then
            isSpecial = true
            break
        end
    end
    
    local targetVal = 1000000
    if not fuckEverything then
        targetVal = toolAmounts[tool.Name] or (isSpecial and 2000 or 1000000)
    end

    local existingItem = backpack:FindFirstChild(tool.Name) or (player.Character and player.Character:FindFirstChild(tool.Name))
    
    if existingItem then
        local amt = existingItem:FindFirstChild("Amount")
        if amt and amt.Value ~= targetVal then 
            amt.Value = targetVal
            store:dispatch({type = "AddItemAddedNotification", toolName = tool.Name, amount = targetVal})
            sync()
        end
    else
        local newItem = tool:Clone()
        local amtObj = newItem:FindFirstChild("Amount")
        if amtObj then
            amtObj.Value = targetVal
            newItem.Parent = backpack
            store:dispatch({type = "AddItemAddedNotification", toolName = tool.Name, amount = targetVal})
            sync()
            if not instantGive then task.wait(0.01) end
        else
            newItem:Destroy()
        end
    end
end

if label then
    label.Text = "Finished!"
    task.delay(3, function() if gui then gui:Destroy() end end)
end
sync()
