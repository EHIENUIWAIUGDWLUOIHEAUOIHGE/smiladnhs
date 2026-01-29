local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
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

local runCount = player:FindFirstChild("ScriptExecutionCount")
if not runCount then
    runCount = Instance.new("NumberValue")
    runCount.Name = "ScriptExecutionCount"
    runCount.Value = 0
    runCount.Parent = player
end
runCount.Value = runCount.Value + 1

local specialScripts = {}
for _, name in ipairs(scriptList) do specialScripts[name] = true end
local currentIgnored = {}
for _, name in ipairs(ignoreList) do currentIgnored[name] = true end

local function sync()
    local invItems = {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(invItems, item)
        end
    end
    local character = player.Character
    local activeTool = character and character:FindFirstChildOfClass("Tool")
    local inventoryData = {items = invItems, contents = invItems, hand = activeTool}
    store:dispatch({type = "InventorySetInventory", inventory = inventoryData})
    store:dispatch({type = "InventoryUpdate", inventory = inventoryData})
    invUpdateEvent:Fire()
end

if not fuckEverything then
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and currentIgnored[item.Name] then
            item:Destroy()
        end
    end
end

local validTools = {}
local processedNames = {}
for _, tool in ipairs(toolsStorage:GetChildren()) do
    if tool:IsA("Tool") and not processedNames[tool.Name] then
        local passesIgnore = fuckEverything or not (useIgnoreList and currentIgnored[tool.Name])
        if passesIgnore then
            local handle = tool:FindFirstChild("Handle")
            local amountObj = tool:FindFirstChild("Amount")
            if handle and amountObj then
                local seenChild = {}
                local hasDupes = false
                for _, child in ipairs(tool:GetChildren()) do
                    if seenChild[child.Name] then hasDupes = true end
                    seenChild[child.Name] = true
                end
                if not hasDupes or fuckEverything then
                    table.insert(validTools, tool)
                    processedNames[tool.Name] = true
                end
            end
        end
    end
end

local total = #validTools
local spawnedCount = 0
for _, tool in ipairs(validTools) do
    spawnedCount = spawnedCount + 1
    if label then
        label.Text = spawnedCount .. " / " .. total
    end
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
        end
        newItem.Parent = backpack
        store:dispatch({type = "AddItemAddedNotification", toolName = tool.Name, amount = targetVal})
        sync()
        if not instantGive then
            local chance = math.random(1, 100)
            if chance <= 10 then
                task.wait(math.random(2, 5) / 10)
            elseif chance <= 30 then
                task.wait(math.random(5, 15) / 100)
            else
                task.wait(0.02)
            end
        end
    end
end

local endTime = os.clock()
local duration = string.format("%.2f", endTime - startTime)
if label then
    label.Text = "Finished in " .. duration .. "s!"
    task.delay(5, function()
        if gui then gui:Destroy() end
    end)
end
sync()
