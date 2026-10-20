-- ==========================================
--  MASTER GAMEPASS & AUTO-FARM DASHBOARD
-- ==========================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer
while not localPlayer do
    Players.PlayerAdded:Wait()
    localPlayer = Players.LocalPlayer
end

local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui") or CoreGui

-- Clean up old GUI if it exists
local oldGui = playerGui:FindFirstChild("MasterDashboard") or CoreGui:FindFirstChild("MasterDashboard")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MasterDashboard"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = playerGui

-- ==========================================
--  GLOBAL STATE VARIABLES
-- ==========================================
_G.HatchLoop = false
local isAutoFarmActive = false
_G.SelectedEggName = ""
_G.SelectedIslandName = ""

local discoveredEggs = {}
local discoveredIslands = {}

-- ==========================================
--  ANTI-AFK SYSTEMS (Delta & Infinite Yield)
-- ==========================================
local function triggerAntiAfk()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

localPlayer.Idled:Connect(function()
    triggerAntiAfk()
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(120)
        triggerAntiAfk()
    end
end)

-- ==========================================
--  AUTO-CLAIM PLAYTIME REWARDS (1 to 9 every 1.5 Hours)
-- ==========================================
task.spawn(function()
    -- Initial short delay on startup before first check
    task.wait(5)
    while ScreenGui.Parent do
        pcall(function()
            local Event = ReplicatedStorage:FindFirstChild("Shared")
                and ReplicatedStorage.Shared:FindFirstChild("Framework")
                and ReplicatedStorage.Shared.Framework:FindFirstChild("Network")
                and ReplicatedStorage.Shared.Framework.Network:FindFirstChild("Remote")
                and ReplicatedStorage.Shared.Framework.Network.Remote:FindFirstChild("RemoteFunction")
            
            if Event then
                for i = 1, 9 do
                    if not ScreenGui.Parent then break end
                    Event:InvokeServer("ClaimPlaytime", i)
                    task.wait(0.5) -- Brief buffer between sequential claims
                end
            end
        end)
        -- 1.5 hours = 5400 seconds
        task.wait(5400)
    end
end)

-- ==========================================
--  GUI WINDOW & DRAGGABLE FRAME LAYOUT
-- ==========================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 320)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Parent = ScreenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Top Title & Drag Bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 35)
topBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Game Dashboard"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Kill Script Button (Top Right)
local killButton = Instance.new("TextButton")
killButton.Size = UDim2.new(0, 50, 0, 25)
killButton.Position = UDim2.new(1, -55, 0, 5)
killButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
killButton.Text = "CLOSE"
killButton.TextColor3 = Color3.fromRGB(255, 255, 255)
killButton.Font = Enum.Font.SourceSansBold
killButton.TextSize = 12
killButton.Parent = topBar
Instance.new("UICorner", killButton).CornerRadius = UDim.new(0, 6)

-- Draggable Logic
local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==========================================
--  TAB NAVIGATION BAR
-- ==========================================
local tabNavFrame = Instance.new("Frame")
tabNavFrame.Size = UDim2.new(1, -20, 0, 32)
tabNavFrame.Position = UDim2.new(0, 10, 0, 45)
tabNavFrame.BackgroundTransparency = 1
tabNavFrame.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout", tabNavFrame)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6)

local tabContents = Instance.new("Folder")
tabContents.Name = "TabContents"
tabContents.Parent = mainFrame

local function createTabPanel(name)
    local panel = Instance.new("ScrollingFrame")
    panel.Name = name .. "Panel"
    panel.Size = UDim2.new(1, -20, 1, -95)
    panel.Position = UDim2.new(0, 10, 0, 85)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.ScrollBarThickness = 4
    panel.Parent = tabContents
    
    local layout = Instance.new("UIListLayout", panel)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    
    return panel
end

local islandPanel = createTabPanel("Islands")
local farmPanel = createTabPanel("AutoFarm")
local hatchPanel = createTabPanel("AutoHatch")

local function switchTab(selectedPanel, selectedButton)
    islandPanel.Visible = (selectedPanel == islandPanel)
    farmPanel.Visible = (selectedPanel == farmPanel)
    hatchPanel.Visible = (selectedPanel == hatchPanel)
end

local function createTabButton(name, order, targetPanel)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.Parent = tabNavFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        switchTab(targetPanel, btn)
    end)
    return btn
end

createTabButton("Islands", 1, islandPanel)
createTabButton("Auto Farm", 2, farmPanel)
createTabButton("Auto Hatch", 3, hatchPanel)

-- Default to Islands tab active
islandPanel.Visible = true

-- ==========================================
--  TAB 1: ISLAND TP (Named by World Folder Names)
-- ==========================================
local selectIslandBtn = Instance.new("TextButton")
selectIslandBtn.Size = UDim2.new(1, 0, 0, 38)
selectIslandBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
selectIslandBtn.Text = "Select Island ▼"
selectIslandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
selectIslandBtn.Font = Enum.Font.SourceSansBold
selectIslandBtn.TextSize = 14
selectIslandBtn.Parent = islandPanel
Instance.new("UICorner", selectIslandBtn).CornerRadius = UDim.new(0, 6)

local islandDropdown = Instance.new("ScrollingFrame")
islandDropdown.Size = UDim2.new(1, 0, 0, 130)
islandDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
islandDropdown.Visible = false
islandDropdown.CanvasSize = UDim2.new(0, 0, 0, 0)
islandDropdown.AutomaticCanvasSize = Enum.AutomaticSize.Y
islandDropdown.ScrollBarThickness = 4
islandDropdown.Parent = islandPanel
Instance.new("UICorner", islandDropdown).CornerRadius = UDim.new(0, 6)
local islandListLayout = Instance.new("UIListLayout", islandDropdown)
islandListLayout.SortOrder = Enum.SortOrder.LayoutOrder
islandListLayout.Padding = UDim.new(0, 4)

local tpIslandBtn = Instance.new("TextButton")
tpIslandBtn.Size = UDim2.new(1, 0, 0, 38)
tpIslandBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
tpIslandBtn.Text = "TP to Selected Island"
tpIslandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpIslandBtn.Font = Enum.Font.SourceSansBold
tpIslandBtn.TextSize = 14
tpIslandBtn.Parent = islandPanel
Instance.new("UICorner", tpIslandBtn).CornerRadius = UDim.new(0, 6)

local function refreshIslands()
    discoveredIslands = {}
    for _, child in ipairs(islandDropdown:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local worldsFolder = Workspace:FindFirstChild("Worlds")
    if worldsFolder then
        local worldFolders = {}
        for _, child in ipairs(worldsFolder:GetChildren()) do
            if child:IsA("Folder") then
                table.insert(worldFolders, child)
            end
        end
        table.sort(worldFolders, function(a, b)
            return a.Name < b.Name
        end)
        
        for _, worldFolder in ipairs(worldFolders) do
            local worldName = worldFolder.Name
            local prefix = worldName .. " - "
            local function scanSubfolders(parent)
                for _, item in ipairs(parent:GetChildren()) do
                    if item:IsA("Folder") or item:IsA("Model") then
                        if item:FindFirstChild("IslandTeleport") or item:FindFirstChild("FastTravel") or item:FindFirstChild("GroundIsland") or item:FindFirstChild("Stages") or item:FindFirstChild("Island") then
                            local displayName = prefix .. item.Name
                            discoveredIslands[displayName] = item
                        else
                            scanSubfolders(item)
                        end
                    end
                end
            end
            scanSubfolders(worldFolder)
        end
    end
    
    local sortedNames = {}
    for name, _ in pairs(discoveredIslands) do table.insert(sortedNames, name) end
    table.sort(sortedNames)
    
    for _, islandName in ipairs(sortedNames) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1, 0, 0, 30)
        opt.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        opt.Text = islandName
        opt.TextColor3 = Color3.fromRGB(255, 255, 255)
        opt.Font = Enum.Font.SourceSansBold
        opt.TextSize = 12
        opt.Parent = islandDropdown
        Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 4)
        
        opt.MouseButton1Click:Connect(function()
            _G.SelectedIslandName = islandName
            selectIslandBtn.Text = islandName .. " ▼"
            islandDropdown.Visible = false
        end)
    end
end

selectIslandBtn.MouseButton1Click:Connect(function()
    refreshIslands()
    islandDropdown.Visible = not islandDropdown.Visible
end)

tpIslandBtn.MouseButton1Click:Connect(function()
    local targetIsland = discoveredIslands[_G.SelectedIslandName]
    if targetIsland and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = localPlayer.Character.HumanoidRootPart
        local targetPart = targetIsland:FindFirstChild("IslandTeleport", true)
            or targetIsland:FindFirstChild("FastTravel", true)
            or targetIsland:FindFirstChild("GroundIsland", true)
            or (targetIsland:IsA("Model") and (targetIsland.PrimaryPart or targetIsland:FindFirstChildWhichIsA("BasePart", true)))
        
        if targetPart then
            local tpCFrame = targetPart:IsA("Model") and (targetPart.PrimaryPart and targetPart.PrimaryPart.CFrame or targetPart:GetPivot()) or targetPart.CFrame
            rootPart.CFrame = tpCFrame + Vector3.new(0, 5, 0)
        end
    end
end)

-- ==========================================
--  TAB 2: AUTO-FARM (Integrated Full Script)
-- ==========================================
local farmToggleBtn = Instance.new("TextButton")
farmToggleBtn.Size = UDim2.new(1, 0, 0, 45)
farmToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
farmToggleBtn.Text = "Auto-Farm: OFF"
farmToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
farmToggleBtn.Font = Enum.Font.SourceSansBold
farmToggleBtn.TextSize = 15
farmToggleBtn.Parent = farmPanel
Instance.new("UICorner", farmToggleBtn).CornerRadius = UDim.new(0, 6)

local farmInfoLabel = Instance.new("TextLabel")
farmInfoLabel.Size = UDim2.new(1, 0, 0, 60)
farmInfoLabel.BackgroundTransparency = 1
farmInfoLabel.Text = "Includes Chests, Present Rain,\nHalloween Houses & Chunker Spawns."
farmInfoLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
farmInfoLabel.Font = Enum.Font.SourceSans
farmInfoLabel.TextSize = 13
farmInfoLabel.Parent = farmPanel

local remoteModule = nil
task.spawn(function()
    pcall(function()
        local networkPath = ReplicatedStorage:WaitForChild("Shared", 5) 
            and ReplicatedStorage.Shared:WaitForChild("Framework", 5) 
            and ReplicatedStorage.Shared.Framework:WaitForChild("Network", 5)
        if networkPath and networkPath:FindFirstChild("Remote") then
            remoteModule = require(networkPath.Remote)
        end
    end)
end)

local function privateFireServer(action, ...)
    if remoteModule and type(remoteModule.FireServer) == "function" then
        remoteModule:FireServer(action, ...)
    else
        local fallbackEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")
        if fallbackEvent then
            fallbackEvent:FireServer(action, ...)
        end
    end
end

local function resetCamera()
    local camera = Workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
            camera.CameraSubject = localPlayer.Character.Humanoid
        end
    end
end

farmToggleBtn.MouseButton1Click:Connect(function()
    isAutoFarmActive = not isAutoFarmActive
    if isAutoFarmActive then
        farmToggleBtn.Text = "Status: Farming"
        farmToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    else
        farmToggleBtn.Text = "Auto-Farm: OFF"
        farmToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        resetCamera()
    end
end)

local chestTimers = {
    ["Giant Chest"]     = { interval = 15 * 60, lastClaim = 0 },
    ["Ticket Chest"]    = { interval = 30 * 60, lastClaim = 0 },
    ["Void Chest"]      = { interval = 40 * 60, lastClaim = 0 },
    ["Halloween Chest"] = { interval = 60 * 60, lastClaim = 0 },
}

local function processTimedChests(rootPart)
    local currentTime = tick()
    local renderedFolder = Workspace:FindFirstChild("Rendered")
    local chestsFolder = renderedFolder and renderedFolder:FindFirstChild("Chests")
    if not chestsFolder then return end

    for chestName, data in pairs(chestTimers) do
        if not isAutoFarmActive or not ScreenGui.Parent then break end
        if currentTime - data.lastClaim >= data.interval then
            local chestObj = chestsFolder:FindFirstChild(chestName)
            if chestObj then
                local chestCFrame = chestObj:IsA("Model") and chestObj:GetPivot() or (chestObj:IsA("BasePart") and chestObj.CFrame)
                if chestCFrame then
                    rootPart.CFrame = chestCFrame + Vector3.new(0, 15, 0)
                    task.wait(0.2)
                    privateFireServer("ClaimChest", chestName)
                    data.lastClaim = currentTime
                    task.wait(0.5)
                end
            end
        end
    end
end

local function processPresentRain(rootPart)
    local renderedFolder = Workspace:FindFirstChild("Rendered")
    local presentRainFolder = renderedFolder and renderedFolder:FindFirstChild("PresentRain")
    if not presentRainFolder then return false end
    
    local presents = presentRainFolder:GetChildren()
    if #presents == 0 then return false end

    while isAutoFarmActive and ScreenGui.Parent do
        presents = presentRainFolder:GetChildren()
        if #presents == 0 then break end

        local collectedAny = false
        for i = 1, #presents do
            if not isAutoFarmActive or not ScreenGui.Parent then break end
            local present = presents[i]
            local targetCFrame = present:IsA("Model") and present:GetPivot() or (present:IsA("BasePart") and present.CFrame)
            if targetCFrame then
                rootPart.CFrame = targetCFrame + Vector3.new(0, 10, 0)
                collectedAny = true
                task.wait(0.0005)
            end
        end
        if not collectedAny then break end
        task.wait(0.1)
    end
    return true
end

local function isUUID(str)
    if type(str) ~= "string" or #str ~= 36 then return false end
    return str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function getBestChunker()
    local targetChunker = nil
    local maxUuidCount = -1
    local function scanContainer(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "Chunker" and child:IsA("Folder") then
                local children = child:GetChildren()
                local uuidCount = 0
                for i = 1, #children do
                    if isUUID(children[i].Name) then uuidCount = uuidCount + 1 end
                end
                if uuidCount > maxUuidCount and uuidCount > 0 then
                    maxUuidCount = uuidCount
                    targetChunker = child
                end
            elseif child:IsA("Folder") then
                scanContainer(child)
            end
        end
    end
    scanContainer(Workspace)
    return targetChunker
end

local function collectSpawnsUntil(rootPart, startTime, maxDuration)
    while (tick() - startTime < maxDuration) and isAutoFarmActive and ScreenGui.Parent do
        if processPresentRain(rootPart) then continue end
        local targetChunker = getBestChunker()
        if targetChunker then
            local spawnItems = targetChunker:GetChildren()
            local handledAny = false
            for i = 1, #spawnItems do
                if not isAutoFarmActive or not ScreenGui.Parent or (tick() - startTime >= maxDuration) then break end
                if processPresentRain(rootPart) then break end
                local spawnItem = spawnItems[i]
                if spawnItem and spawnItem.Parent and isUUID(spawnItem.Name) then
                    local targetCFrame = spawnItem:IsA("Model") and spawnItem:GetPivot() or (spawnItem:IsA("BasePart") and spawnItem.CFrame)
                    if targetCFrame then
                        rootPart.CFrame = targetCFrame + Vector3.new(0, 10, 0)
                        handledAny = true
                        task.wait(0.0005)
                    end
                end
            end
            if not handledAny then task.wait(0.05) end
        else
            task.wait(0.05)
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        if isAutoFarmActive then
            local character = localPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local camera = Workspace.CurrentCamera
            
            if rootPart then
                local originalCFrame = rootPart.CFrame
                processPresentRain(rootPart)
                processTimedChests(rootPart)

                local halloweenEvent = Workspace:WaitForChild("HalloweenEvent", 5)
                local housesFolder = halloweenEvent and halloweenEvent:WaitForChild("Houses", 5)

                if housesFolder then
                    for _, house in ipairs(housesFolder:GetChildren()) do
                        if not isAutoFarmActive or not ScreenGui.Parent then break end
                        processPresentRain(rootPart)
                        local activationTarget = house:FindFirstChild("Activation")
                        if activationTarget then
                            local targetPivot = activationTarget:GetPivot()
                            if camera then
                                camera.CameraType = Enum.CameraType.Scriptable
                                camera.CFrame = CFrame.new(targetPivot.Position + Vector3.new(0, 25, 35), targetPivot.Position)
                            end
                            rootPart.CFrame = targetPivot + Vector3.new(0, 17.5, 0)
                            privateFireServer("TrickOrTreat", house)
                            local actionStart = tick()
                            while (tick() - actionStart < 1.2) and isAutoFarmActive and ScreenGui.Parent do
                                task.wait(0.05)
                            end
                            collectSpawnsUntil(rootPart, actionStart, 3.5)
                        end
                    end
                end

                processPresentRain(rootPart)
                processTimedChests(rootPart)

                if isAutoFarmActive and ScreenGui.Parent then
                    local spawnPhaseStart = tick()
                    local fixedCameraPos = Vector3.new(-4953.75390625, 12.16848373413086, -1164.0469970703125)
                    if camera then
                        camera.CameraType = Enum.CameraType.Scriptable
                        camera.CFrame = CFrame.new(fixedCameraPos + Vector3.new(0, 50, 0), fixedCameraPos)
                    end
                    while (tick() - spawnPhaseStart < 30) and isAutoFarmActive and ScreenGui.Parent do
                        if camera then
                            camera.CameraType = Enum.CameraType.Scriptable
                            camera.CFrame = CFrame.new(fixedCameraPos + Vector3.new(0, 50, 0), fixedCameraPos)
                        end
                        collectSpawnsUntil(rootPart, spawnPhaseStart, 30)
                    end
                end

                if rootPart and ScreenGui.Parent then
                    rootPart.CFrame = originalCFrame
                end
                resetCamera()
            end
        end
        task.wait(0.2)
    end
end)

-- ==========================================
--  TAB 3: AUTO-HATCH & EGG TELEPORT
-- ==========================================
local selectEggBtn = Instance.new("TextButton")
selectEggBtn.Size = UDim2.new(1, 0, 0, 38)
selectEggBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
selectEggBtn.Text = "Select Egg ▼"
selectEggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
selectEggBtn.Font = Enum.Font.SourceSansBold
selectEggBtn.TextSize = 14
selectEggBtn.Parent = hatchPanel
Instance.new("UICorner", selectEggBtn).CornerRadius = UDim.new(0, 6)

local eggDropdown = Instance.new("ScrollingFrame")
eggDropdown.Size = UDim2.new(1, 0, 0, 100)
eggDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
eggDropdown.Visible = false
eggDropdown.CanvasSize = UDim2.new(0, 0, 0, 0)
eggDropdown.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggDropdown.ScrollBarThickness = 4
eggDropdown.Parent = hatchPanel
Instance.new("UICorner", eggDropdown).CornerRadius = UDim.new(0, 6)
local eggListLayout = Instance.new("UIListLayout", eggDropdown)
eggListLayout.SortOrder = Enum.SortOrder.LayoutOrder
eggListLayout.Padding = UDim.new(0, 4)

local tpEggBtn = Instance.new("TextButton")
tpEggBtn.Size = UDim2.new(1, 0, 0, 35)
tpEggBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
tpEggBtn.Text = "TP to Egg"
tpEggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpEggBtn.Font = Enum.Font.SourceSansBold
tpEggBtn.TextSize = 14
tpEggBtn.Parent = hatchPanel
Instance.new("UICorner", tpEggBtn).CornerRadius = UDim.new(0, 6)

local hatchToggleBtn = Instance.new("TextButton")
hatchToggleBtn.Size = UDim2.new(1, 0, 0, 38)
hatchToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
hatchToggleBtn.Text = "START HATCHING"
hatchToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hatchToggleBtn.Font = Enum.Font.SourceSansBold
hatchToggleBtn.TextSize = 14
hatchToggleBtn.Parent = hatchPanel
Instance.new("UICorner", hatchToggleBtn).CornerRadius = UDim.new(0, 6)

local function refreshEggs()
    discoveredEggs = {}
    for _, child in ipairs(eggDropdown:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local genericFolder = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Generic")
    if genericFolder then
        for _, child in ipairs(genericFolder:GetChildren()) do
            if child.Name:find("Egg") and child.Name:find(" ") then
                discoveredEggs[child.Name] = child
            end
        end
    end
    
    local sortedNames = {}
    for eggName, _ in pairs(discoveredEggs) do table.insert(sortedNames, eggName) end
    table.sort(sortedNames)
    
    for _, eggName in ipairs(sortedNames) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1, 0, 0, 28)
        opt.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        opt.Text = eggName
        opt.TextColor3 = Color3.fromRGB(255, 255, 255)
        opt.Font = Enum.Font.SourceSansBold
        opt.TextSize = 12
        opt.Parent = eggDropdown
        Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 4)
        
        opt.MouseButton1Click:Connect(function()
            _G.SelectedEggName = eggName
            selectEggBtn.Text = eggName .. " ▼"
            eggDropdown.Visible = false
        end)
    end
end

selectEggBtn.MouseButton1Click:Connect(function()
    refreshEggs()
    eggDropdown.Visible = not eggDropdown.Visible
end)

tpEggBtn.MouseButton1Click:Connect(function()
    local targetEgg = discoveredEggs[_G.SelectedEggName]
    if targetEgg and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = localPlayer.Character.HumanoidRootPart
        local primaryPart = targetEgg:IsA("Model") and (targetEgg.PrimaryPart or targetEgg:FindFirstChildWhichIsA("BasePart"))
        if primaryPart then
            rootPart.CFrame = primaryPart.CFrame + Vector3.new(0, 4, 0)
        end
    end
end)

hatchToggleBtn.MouseButton1Click:Connect(function()
    _G.HatchLoop = not _G.HatchLoop
    if _G.HatchLoop then
        hatchToggleBtn.Text = "STOP HATCHING"
        hatchToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    else
        hatchToggleBtn.Text = "START HATCHING"
        hatchToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    end
end)

-- FOV Lock & Egg Suppressor for Hatch Loop
RunService.RenderStepped:Connect(function()
    if _G.HatchLoop and ScreenGui.Parent then
        local camera = Workspace.CurrentCamera
        if camera then
            camera.FieldOfView = 70
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        if _G.HatchLoop then
            pcall(function()
                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("ColorCorrectionEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") then
                        effect.Enabled = false
                    end
                end
                
                local genericFolder = Workspace:FindFirstChild("Rendered") and Workspace.Rendered:FindFirstChild("Generic")
                if genericFolder then
                    local processedNames = {}
                    for _, child in ipairs(genericFolder:GetChildren()) do
                        pcall(function()
                            if child.Name:find("Egg") and child.Name:find(" ") then
                                if not processedNames[child.Name] then
                                    processedNames[child.Name] = true
                                else
                                    if child:IsA("Model") then
                                        for _, part in ipairs(child:GetDescendants()) do
                                            if part:IsA("BasePart") then
                                                part.Transparency = 1
                                                part.CanCollide = false
                                            elseif part:IsA("ParticleEmitter") or part:IsA("Highlight") then
                                                part:Destroy()
                                            end
                                        end
                                    elseif child:IsA("BasePart") then
                                        child.Transparency = 1
                                        child.CanCollide = false
                                    end
                                end
                            end
                        end)
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        if _G.HatchLoop and _G.SelectedEggName ~= "" then
            pcall(function()
                local Event = ReplicatedStorage:FindFirstChild("Shared") 
                    and ReplicatedStorage.Shared:FindFirstChild("Framework") 
                    and ReplicatedStorage.Shared.Framework:FindFirstChild("Network") 
                    and ReplicatedStorage.Shared.Framework.Network:FindFirstChild("Remote") 
                    and ReplicatedStorage.Shared.Framework.Network.Remote:FindFirstChild("RemoteEvent")
                
                if Event then
                    Event:FireServer("HatchEgg", _G.SelectedEggName, 7)
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- ==========================================
--  KILL SCRIPT HANDLER
-- ==========================================
killButton.MouseButton1Click:Connect(function()
    _G.HatchLoop = false
    isAutoFarmActive = false
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera.FieldOfView = 70
    end
    resetCamera()
    ScreenGui:Destroy()
end)

print("Master Dashboard: Successfully loaded with Playtime Rewards & Exact World Folder Names!")
