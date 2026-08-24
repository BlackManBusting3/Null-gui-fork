--[[
    AdminPanel_UIOnly.client.lua
    
    Fancier animated loading screen + Obsidian UI Library.
    Integrated with AI/Entity disabling tools, game hooks, dynamic tab loading based on PlaceId, and Debug Tools.
]]

--------------------------------------------------------------------
-- Services & Global Declarations
--------------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local LocalizationService = game:GetService("LocalizationService")
local CoreGui = game:GetService("CoreGui")
local LogService = game:GetService("LogService")
local TextService = game:GetService("TextService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService = game:GetService("PathfindingService")

local PlaceId, JobId = game.PlaceId, game.JobId 
local plr = Players.LocalPlayer

-- Fetch Game Name via MarketplaceService
local gameName = "Unknown Game"
pcall(function()
    local productInfo = MarketplaceService:GetProductInfoAsync(PlaceId)
    if productInfo and productInfo.Name then
        gameName = productInfo.Name
    end
end)

-- Place ID Check
local isSupportedPlace = (PlaceId == 129279692364812 or PlaceId == 100588763114828)

-- Signal Fallbacks for Executors
local fSignal = firesignal or fire_signal or fireSignal
if not fSignal and getgenv then
    fSignal = getgenv().firesignal or getgenv().fire_signal or getgenv().fireSig
end

--------------------------------------------------------------------
-- Game References
--------------------------------------------------------------------
local events = ReplicatedStorage:WaitForChild("Events", 5) or ReplicatedStorage:FindFirstChild("Events")

local Camera = workspace.CurrentCamera
local enemies = workspace:FindFirstChild("Enemies")
local selection = workspace:FindFirstChild("Select")
local collectGift = events and events:FindFirstChild("GiftCollected")
local currentRooms = workspace:FindFirstChild("CurrentRooms")
local pads = workspace:FindFirstChild("JumpPads")
local code = ReplicatedStorage:FindFirstChild("CodeVal")
local music = ReplicatedStorage:FindFirstChild("MusicVal")
local curses = ReplicatedStorage:FindFirstChild("CurseFolder") and ReplicatedStorage.CurseFolder:FindFirstChild("Curses")
local gcurses = ReplicatedStorage:FindFirstChild("GreaterCurseFolder") and ReplicatedStorage.GreaterCurseFolder:FindFirstChild("Curses")
local enemiesFolder = ReplicatedStorage:FindFirstChild("EnemyFolder")
local upgrades = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
local beacons = workspace:FindFirstChild("Beacons")
local destroyFolder = workspace:FindFirstChild("DestroyFolder")
local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
local magnet = events and events:FindFirstChild("MovementGiftMagnet")

--------------------------------------------------------------------
-- Visualizers & Protection Folders
--------------------------------------------------------------------
local tripmineprots = Instance.new("Folder")
tripmineprots.Parent = workspace
tripmineprots.Name = "Tripmine Protection (NULL GUI)"

local bulletprots = Instance.new("Folder")
bulletprots.Parent = workspace
bulletprots.Name = "Guardian Bullets Protection (NULL GUI)"

local velocityPart = Instance.new("Part")
velocityPart.Name = "VelocityVisualizer"
velocityPart.Anchored = true
velocityPart.CanCollide = false
velocityPart.CanTouch = false
velocityPart.Material = Enum.Material.Air
velocityPart.Color = Color3.new(1, 1, 1)
velocityPart.Size = Vector3.new(0.1, 0.1, 1)
velocityPart.Parent = workspace

local vpBox = Instance.new("BoxHandleAdornment")
vpBox.Color3 = Color3.new(1, 1, 1)
vpBox.AlwaysOnTop = true
vpBox.ZIndex = 0
vpBox.Adornee = velocityPart
vpBox.Parent = velocityPart

--------------------------------------------------------------------
-- Integrated Gift Settings & State Flags
--------------------------------------------------------------------
local Settings = {
    CollectNormal = false,
    CollectGolden = false,
    LegitCollection = false,
    LegitSpeed = 16,
    InstantTeleport = true, 
    TweenSpeed = 60,        
    DelayBetweenGifts = 0.05,
    AutoBeacon = false 
}

local tweening = false
local currentTween = nil
local activePath = nil
local availableNormalGifts = {}
local availableGoldenGifts = {}

local notifOn = true
local destroying = false

local disableAllEnemies = false
local deleteAllEnemies = false
local disableClientEnemies = false
local autoDestroySpawns = false

local auto_disable = {
    Bell = false, Mart = false, Skinwalker = false, Springer = false,
    Baby = false, Flesh = false, nilEnemy = false, nilMirage = false,
    Telefragger = false, ShadowBaby = false, Cadence = false,
}

local auto_break = {
    Bell = false, Mart = false, Skinwalker = false, Springer = false,
    ICBM = false, Baby = false, Flesh = false, nilEnemy = false,
    nilMirage = false, Telefragger = false, ShadowBaby = false,
    Celestial = false, Cadence = false,
}

local auto_destroy = {
    Bell = false, Mart = false, Skinwalker = false, Springer = false,
    ICBM = false, Baby = false, Flesh = false, Operator = false,
    Kolona = false, nilEnemy = false, nilMirage = false, Telefragger = false,
    Sigil = false, ShadowBaby = false, Voidbreaker = false, Cadence = false,
    Scrapmaw = false, RealityBreak = false, Celestial = false,
}

local pb = false
local connections = {}
local activeUpgrades = {}
local upgradeValueGuards = {}
local isSettingGuardValue = {}
local blacklistedGifts = {} 

local updateActiveUpgradesDisplay = function() end
local applyUpgradeValue = function() end
local upgradeLabels = {}

--------------------------------------------------------------------
-- Helper Functions: Fast Gift Collection Engine & Pathfinding
--------------------------------------------------------------------
local Library

local function notif(msg, title)
    if Library and Library.Notify then
        Library:Notify(string.format("[%s]: %s", title or "System", msg), 3)
    end
end

local function getChar(player)
    return player and player.Character
end

local function getRoot(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart)
end

local function refreshGifts(normal, golden)
    table.clear(availableNormalGifts)
    table.clear(availableGoldenGifts)

    local dynamicItems = workspace:FindFirstChild("Item_Pools")
    local normalFolder = (dynamicItems and dynamicItems:FindFirstChild("Gift")) or workspace:FindFirstChild("Gifts") or workspace:FindFirstChild("SpawnedGifts")
    local goldenFolder = (dynamicItems and dynamicItems:FindFirstChild("GoldenGift")) or normalFolder

    if normal and normalFolder then
        for _, gift in ipairs(normalFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if not isGolden then
                table.insert(availableNormalGifts, gift)
            end
        end
    end

    if golden and goldenFolder then
        for _, gift in ipairs(goldenFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if isGolden then
                table.insert(availableGoldenGifts, gift)
            end
        end
    end
end

local function getClosestGift(giftList)
    local char = getChar(plr)
    local root = getRoot(char)
    if not root then return nil end

    local closest, shortestDist = nil, math.huge
    for _, gift in ipairs(giftList) do
        if gift and gift.Parent and not blacklistedGifts[gift] then
            local part = gift:IsA("BasePart") and gift or gift:FindFirstChildWhichIsA("BasePart")
            if part then
                if part.Position == Vector3.new(0,0,0) or part.Position.Y < -500 or part.Position.Y > 3000 or part.Position.Magnitude > 30000 then
                    blacklistedGifts[gift] = true
                    continue
                end

                local dist = (part.Position - root.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = gift
                end
            end
        end
    end
    return closest
end

local function walkToPositionPathfinding(targetPos)
    local char = getChar(plr)
    local root = getRoot(char)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid or not targetPos or targetPos == Vector3.new(0,0,0) then return false end

    humanoid.WalkSpeed = Settings.LegitSpeed

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 10,
        AgentMaxSlope = 45
    })

    local success, err = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if not tweening and not Settings.AutoBeacon then
                humanoid:MoveTo(root.Position) 
                return false
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            humanoid:MoveTo(waypoint.Position)

            local moveCompleted = false
            local conn = humanoid.MoveToFinished:Connect(function()
                moveCompleted = true
            end)

            local timeout = 0
            while not moveCompleted and (tweening or Settings.AutoBeacon) do
                task.wait(0.05)
                timeout += 0.05
                if timeout > 3 then break end 
            end

            conn:Disconnect()
            if not moveCompleted then break end
        end
        return true
    else
        humanoid:MoveTo(targetPos)
        task.wait(0.5)
        return false
    end
end

local function walkToGiftPathfinding(targetGift)
    local targetPart = targetGift:IsA("BasePart") and targetGift or targetGift:FindFirstChildWhichIsA("BasePart")
    if not targetPart or targetPart.Position == Vector3.new(0,0,0) then return false end
    return walkToPositionPathfinding(targetPart.Position)
end

local function moveToGift(targetGift)
    if Settings.LegitCollection then
        walkToGiftPathfinding(targetGift)
        return nil
    end

    local char = getChar(plr)
    local root = getRoot(char)
    local targetPart = targetGift:IsA("BasePart") and targetGift or targetGift:FindFirstChildWhichIsA("BasePart")

    if not root or not targetPart or targetPart.Position == Vector3.new(0,0,0) then return nil end

    local targetCFrame = targetPart.CFrame + Vector3.new(0, 3, 0)

    if Settings.InstantTeleport then
        root.CFrame = targetCFrame
        return nil
    end

    local distance = (targetPart.Position - root.Position).Magnitude
    local duration = math.max(0.01, distance / Settings.TweenSpeed)

    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    tween:Play()

    return tween
end

local function handleSpawnNavigation()
    local targetSpawn = workspace:FindFirstChild("Spawn") or workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Beacons")
    
    if targetSpawn then
        local part = targetSpawn:IsA("BasePart") and targetSpawn or targetSpawn:FindFirstChildWhichIsA("BasePart")
        if part and part.Position ~= Vector3.new(0,0,0) then
            local char = getChar(plr)
            local root = getRoot(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if root then
                if Settings.LegitCollection then
                    walkToPositionPathfinding(part.Position)
                else
                    root.CFrame = part.CFrame + Vector3.new(0, 15, 0)
                end
                return true
            end
        end
    end
    return false
end

local function stopAllCollection()
    tweening = false
    Settings.CollectNormal = false
    Settings.CollectGolden = false
    Settings.LegitCollection = false

    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    if Options then
        if Options.CollectNormalToggle then Options.CollectNormalToggle:SetValue(false) end
        if Options.CollectGoldenToggle then Options.CollectGoldenToggle:SetValue(false) end
        if Options.LegitCollectionToggle then Options.LegitCollectionToggle:SetValue(false) end
    end
end

local function collectGiftsEngine(isGoldenTarget)
    if tweening then
        if notifOn then
            notif("Already collecting gifts.", "Collection System")
        end
        return
    end

    tweening = true
    table.clear(blacklistedGifts) 

    task.spawn(function()
        local failedAttempts = 0

        while tweening do
            if isGoldenTarget and not Settings.CollectGolden then break end
            if not isGoldenTarget and not Settings.CollectNormal then break end

            local char = getChar(plr)
            local root = getRoot(char)
            if root and not Settings.LegitCollection then 
                root.AssemblyLinearVelocity = Vector3.new(0,0,0) 
            end

            refreshGifts(not isGoldenTarget, isGoldenTarget)

            local targetPool = isGoldenTarget and availableGoldenGifts or availableNormalGifts
            local gift = getClosestGift(targetPool)

            if not gift then
                failedAttempts += 1

                if not isGoldenTarget then
                    if failedAttempts >= 2 or #availableNormalGifts == 0 then
                        if notifOn then notif("No normal gifts left. Switching to Golden Gifts.", "Collection System") end
                        
                        Settings.CollectNormal = false
                        if Options and Options.CollectNormalToggle then Options.CollectNormalToggle:SetValue(false) end
                        
                        Settings.CollectGolden = true
                        if Options and Options.CollectGoldenToggle then Options.CollectGoldenToggle:SetValue(true) end
                        
                        tweening = false
                        task.defer(function() collectGiftsEngine(true) end)
                        return
                    end
                else
                    if notifOn then notif("No Golden Gifts remaining. Disabling gift collection.", "Collection System") end
                    
                    if Settings.AutoBeacon then
                        handleSpawnNavigation()
                    end
                    
                    stopAllCollection()
                    break
                end

                task.wait(0.5) 
                table.clear(blacklistedGifts) 
                continue
            end

            failedAttempts = 0
            blacklistedGifts[gift] = true

            currentTween = moveToGift(gift)
            
            if currentTween then
                currentTween.Completed:Wait()
            elseif not Settings.LegitCollection then
                RunService.Heartbeat:Wait()
            end
            
            if Settings.DelayBetweenGifts and Settings.DelayBetweenGifts > 0 then
                task.wait(Settings.DelayBetweenGifts)
            end
        end

        stopAllCollection()
    end)
end

--------------------------------------------------------------------
-- Helper Functions: AI & Entity Disablers
--------------------------------------------------------------------
local function disableEnemyEntity(entity)
    if not entity or not (entity:IsA("Model") or entity:IsA("Folder") or entity:IsA("BasePart")) then return end
    
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid.WalkSpeed = 0
        humanoid.PlatformStand = true
    end
    
    for _, obj in ipairs(entity:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") then
            obj.Disabled = true
        elseif obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.Anchored = true
        end
    end
end

local function disableEnemy(name, destroy, breakAI, disableAI)
    local target = enemies and enemies:FindFirstChild(name)
    if not target then return false end
    
    if destroy then
        target:Destroy()
        return true
    elseif breakAI or disableAI then
        disableEnemyEntity(target)
        return true
    end
    return false
end

local function processClientSideEnemies()
    local clientTargets = {"nilEnemy", "nilMirage"}
    local destroyTargets = {"Kolona", "Operator", "scrapmaw", "skinwalker", "sigil"}
    
    local searchContainers = {
        Camera,
        enemies,
        enemiesFolder
    }

    for _, container in ipairs(searchContainers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                for _, targetName in ipairs(clientTargets) do
                    if child.Name:lower() == targetName:lower() then
                        disableEnemyEntity(child)
                    end
                end
                
                for _, targetName in ipairs(destroyTargets) do
                    if child.Name:lower() == targetName:lower() then
                        child:Destroy()
                    end
                end
            end
        end
    end
end

local function handleEnemy(enemy)
    if not enemy then return end
    local name = enemy.Name
    
    if auto_destroy[name] then
        disableEnemy(name, true, false, false)
    elseif auto_break[name] then
        disableEnemy(name, false, true, false)
    elseif auto_disable[name] then
        disableEnemy(name, false, false, true)
    end
end

local function purgeExistingEnemies()
    local count = 0
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            enemy:Destroy()
            count += 1
        end
    end
    return count
end

--------------------------------------------------------------------
-- Load Obsidian UI Library & Custom Loading Sequence
--------------------------------------------------------------------
Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

local Loading = Library:CreateLoading({
    Title = "Null GUI - Java.",
    Icon = "rbxassetid://138541249910408",
    TotalSteps = 4
})

Loading:SetMessage("Initializing...")
Loading:SetDescription("Waiting for game to load...")
task.wait(1)

Loading:SetCurrentStep(1)
Loading:SetDescription("Checking Place ID compatibility...")
task.wait(1)

Loading:SetCurrentStep(2)
Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. game.Players.LocalPlayer.Name)
Loading.Sidebar:AddLabel("Version: v1")
Loading.Sidebar:AddLabel("Mode: " .. (isSupportedPlace and "Nullscape Gui" or "Universal Gui"))
task.wait(2)

Loading:SetCurrentStep(3)
Loading:SetDescription("Script has successfully loaded!")
task.wait(1)

Loading:SetCurrentStep(4)
Loading:Continue()

local Window = Library:CreateWindow({
    Title = "Java's Null Gui",
    Footer = string.format("%s | %d | %s | v1", gameName, PlaceId, JobId ~= "" and JobId or "Solo"),
    Icon = "cat",  
    Center = true,
    AutoShow = true,
})

--------------------------------------------------------------------
-- TAB CONFIGURATION BASED ON PLACE ID
--------------------------------------------------------------------
local Tabs = {}

if isSupportedPlace then
    Tabs.Playerlist = Window:AddTab("Main", "paw-print")
    Tabs.Enemies    = Window:AddTab("Enemies", "triangle-alert")
    Tabs.Map        = Window:AddTab("Map", "map")
    Tabs.Music      = Window:AddTab("Music", "music")
    Tabs.Upgrades   = Window:AddTab("Upgrades", "shield-plus")
    Tabs.Debug      = Window:AddTab("Debug", "bug")
    Tabs.Settings   = Window:AddTab("Settings", "settings")

    local PlayerGroup = Tabs.Playerlist:AddLeftGroupbox("Main Features")

    PlayerGroup:AddButton({
        Text = "Player Settings",
        Func = function()
            Library:Notify("Player settings option selected.", 2)
        end
    })

    --------------------------------------------------------------------
    -- Gifts Collection (Fast Engine UI)
    --------------------------------------------------------------------
    local GiftGroup = Tabs.Playerlist:AddRightGroupbox("Gifts Collection")

    GiftGroup:AddLabel("<font color='#AAAAAA'><b>NOTE:</b> Finding gifts can be slow\n Use Instant TP for max collection.</font>")

    GiftGroup:AddToggle("CollectNormalToggle", {
        Text = "<font color='#AA55FF'>Collect Normal Gifts</font>",
        Default = Settings.CollectNormal,
        Callback = function(Value)
            Settings.CollectNormal = Value
            if Value then
                if Settings.CollectGolden then
                    Settings.CollectGolden = false
                    if Options and Options.CollectGoldenToggle then
                        Options.CollectGoldenToggle:SetValue(false)
                    end
                end
                collectGiftsEngine(false)
            else
                if not Settings.CollectGolden and tweening then
                    stopAllCollection()
                end
            end
        end
    })

    GiftGroup:AddToggle("CollectGoldenToggle", {
        Text = "<font color='#FFCC00'>Collect Golden Gifts</font>",
        Default = Settings.CollectGolden,
        Callback = function(Value)
            Settings.CollectGolden = Value
            if Value then
                if Settings.CollectNormal then
                    Settings.CollectNormal = false
                    if Options and Options.CollectNormalToggle then
                        Options.CollectNormalToggle:SetValue(false)
                    end
                end
                collectGiftsEngine(true)
            else
                if not Settings.CollectNormal and tweening then
                    stopAllCollection()
                end
            end
        end
    })

    GiftGroup:AddToggle("LegitCollectionToggle", {
        Text = "<font color='#FF4444'>Legit collection (slow)</font>",
        Default = Settings.LegitCollection,
        Tooltip = "Uses PathfindingService to naturally walk to gifts instead of teleporting or tweening.",
        Callback = function(Value)
            Settings.LegitCollection = Value
            if Value then
                Library:Notify("Legit Pathfinding Mode Enabled.", 2)
            end
        end
    })

    GiftGroup:AddInput("LegitSpeedInput", {
        Default = tostring(Settings.LegitSpeed),
        Numeric = true,
        Finished = true,
        Text = "Legit WalkSpeed",
        Tooltip = "Walking speed while pathfinding to gifts.",
        Placeholder = "16...",
        Callback = function(Value)
            local num = tonumber(Value)
            if num and num > 0 then
                Settings.LegitSpeed = num
                Library:Notify("Legit Speed set to " .. tostring(num), 2)
            end
        end
    })

    GiftGroup:AddToggle("AutoBeaconToggle", {
        Text = "<font color='#00FF00'>Walk/TP To Beacon On Finish</font>",
        Default = Settings.AutoBeacon,
        Tooltip = "Navigates back to Spawn when finished collecting.",
        Callback = function(Value)
            Settings.AutoBeacon = Value
        end
    })

    GiftGroup:AddButton({
        Text = "<font color='#FF4444'>Cancel Gift Collection</font>",
        Func = function()
            stopAllCollection()
            Library:Notify("Cancelled gift collection.", 2)
        end
    })

    GiftGroup:AddToggle("InstantTPToggle", {
        Text = "Instant Teleport Collection",
        Default = Settings.InstantTeleport,
        Tooltip = "Instantly teleports to gifts rather than tweening.",
        Callback = function(Value)
            Settings.InstantTeleport = Value
        end
    })

    GiftGroup:AddInput("TweenSpeedInput", {
        Default = tostring(Settings.TweenSpeed),
        Numeric = true,
        Finished = true,
        Text = "Tween Speed (If TP Off)",
        Tooltip = "Studs per second travel speed when Teleport mode is OFF",
        Placeholder = "300...",
        Callback = function(Value)
            local num = tonumber(Value)
            if num and num > 0 then
                Settings.TweenSpeed = num
                Library:Notify("Tween Speed set to " .. tostring(num), 2)
            end
        end
    })

    GiftGroup:AddInput("TeleportDelayInput", {
        Default = tostring(Settings.DelayBetweenGifts),
        Numeric = true,
        Finished = true,
        Text = "Teleport Delay (Seconds)",
        Tooltip = "Delay between collecting each gift. Increase if you are getting kicked/glitched.",
        Placeholder = "0.05...",
        Callback = function(Value)
            local num = tonumber(Value)
            if num and num >= 0 then
                Settings.DelayBetweenGifts = num
                Library:Notify("Teleport Delay set to " .. tostring(num) .. "s", 2)
            end
        end
    })

    -- Enemies Tab
    local EnemyControlGroup = Tabs.Enemies:AddLeftGroupbox("AI & Entity Disabler")

    EnemyControlGroup:AddToggle("DisableAllEnemies", {
        Text = "Disable All Enemy AI",
        Default = false,
        Callback = function(Value)
            disableAllEnemies = Value
            if Value then
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        disableEnemyEntity(enemy)
                    end
                    connections["DisableEnemies"] = enemies.ChildAdded:Connect(function(child)
                        if disableAllEnemies then
                            task.wait(0.1)
                            disableEnemyEntity(child)
                        end
                    end)
                end
                Library:Notify("Workspace Enemy AI disabled.", 3)
            else
                if connections["DisableEnemies"] then
                    connections["DisableEnemies"]:Disconnect()
                    connections["DisableEnemies"] = nil
                end
                Library:Notify("Workspace Enemy AI re-enabled.", 3)
            end
        end
    })

    EnemyControlGroup:AddToggle("DisableClientEnemies", {
        Text = "Disable all client sided enemies",
        Default = false,
        Callback = function(Value)
            disableClientEnemies = Value
            if Value then
                processClientSideEnemies()
                connections["DisableClientEnemies"] = RunService.Heartbeat:Connect(function()
                    if disableClientEnemies then
                        processClientSideEnemies()
                    end
                end)
                Library:Notify("Client-sided enemies disabler activated.", 3)
            else
                if connections["DisableClientEnemies"] then
                    connections["DisableClientEnemies"]:Disconnect()
                    connections["DisableClientEnemies"] = nil
                end
                Library:Notify("Client-sided enemies disabler stopped.", 3)
            end
        end
    })

    EnemyControlGroup:AddToggle("DeleteAllEnemies", {
        Text = "Delete All Enemies",
        Default = false,
        Callback = function(Value)
            deleteAllEnemies = Value
            if Value then
                if enemies then
                    purgeExistingEnemies()
                    connections["DeleteEnemies"] = enemies.ChildAdded:Connect(function(child)
                        if deleteAllEnemies then
                            task.defer(function()
                                if child and child.Parent then
                                    child:Destroy()
                                end
                            end)
                        end
                    end)
                end
                Library:Notify("Auto-delete all enemies enabled.", 3)
            else
                if connections["DeleteEnemies"] then
                    connections["DeleteEnemies"]:Disconnect()
                    connections["DeleteEnemies"] = nil
                end
                Library:Notify("Auto-delete all enemies disabled.", 3)
            end
        end
    })

    local EnemyActionGroup = Tabs.Enemies:AddRightGroupbox("Actions & Utilities")

    EnemyActionGroup:AddButton({
        Text = "Purge All Existing Enemies",
        Func = function()
            local count = purgeExistingEnemies()
            Library:Notify("Purged " .. tostring(count) .. " enemies from workspace.", 3)
        end
    })

    EnemyActionGroup:AddButton({
        Text = "Refresh Target List",
        Func = function()
            Library:Notify("Refreshed active enemy cache.", 2)
        end
    })

    local ActiveEnemiesGroup = Tabs.Enemies:AddRightGroupbox("Active Enemies")
    local activeEnemiesLabel = ActiveEnemiesGroup:AddLabel("Scanning workspace...")

    task.spawn(function()
        while task.wait(0.5) do
            if not enemies or #enemies:GetChildren() == 0 then
                activeEnemiesLabel:SetText("<font color='#AAAAAA'>No active enemies</font>")
            else
                local lines = {}
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local hum = enemy:FindFirstChildOfClass("Humanoid")
                    local isDisabled = false
                    
                    if hum and hum.PlatformStand then
                        isDisabled = true
                    elseif enemy:FindFirstChildOfClass("Script") and enemy:FindFirstChildOfClass("Script").Disabled then
                        isDisabled = true
                    end

                    if isDisabled then
                        table.insert(lines, string.format("<font color='#AAAAAA'>%s (Disabled/Disabled AI)</font>", enemy.Name))
                    else
                        table.insert(lines, string.format("<font color='#00FF00'>%s (Active)</font>", enemy.Name))
                    end
                end
                
                local fullText = table.concat(lines, "\n")
                activeEnemiesLabel:SetText(fullText)
            end
        end
    end)

    local DetailedEnemyGroup = Tabs.Enemies:AddLeftGroupbox("Granular Enemy Options")

    task.spawn(function()
        while task.wait(0.3) do
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    handleEnemy(enemy)
                end
            end
        end
    end)

    if enemies then
        connections["GranularChildAdded"] = enemies.ChildAdded:Connect(function(child)
            task.wait(0.1)
            handleEnemy(child)
        end)
    end

    DetailedEnemyGroup:AddDivider("Bell")
    DetailedEnemyGroup:AddToggle("Bell_Disable", { Text = "Auto Disable", Default = auto_disable.Bell, Callback = function(v) auto_disable.Bell = v if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end end })
    DetailedEnemyGroup:AddToggle("Bell_Break", { Text = "Auto Break AI", Default = auto_break.Bell, Callback = function(v) auto_break.Bell = v if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end end })
    DetailedEnemyGroup:AddToggle("Bell_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Bell, Callback = function(v) auto_destroy.Bell = v if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end end })

    DetailedEnemyGroup:AddDivider("Mart")
    DetailedEnemyGroup:AddToggle("Mart_Disable", { Text = "Auto Disable", Default = auto_disable.Mart, Callback = function(v) auto_disable.Mart = v if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end end })
    DetailedEnemyGroup:AddToggle("Mart_Break", { Text = "Auto Break AI", Default = auto_break.Mart, Callback = function(v) auto_break.Mart = v if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end end })
    DetailedEnemyGroup:AddToggle("Mart_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Mart, Callback = function(v) auto_destroy.Mart = v if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end end })

    DetailedEnemyGroup:AddDivider("Husk")
    DetailedEnemyGroup:AddToggle("Skinwalker_Disable", { Text = "Auto Disable", Default = auto_disable.Skinwalker, Callback = function(v) auto_disable.Skinwalker = v if v then handleEnemy(enemies and enemies:FindFirstChild("Skinwalker")) end end })
    DetailedEnemyGroup:AddToggle("Skinwalker_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Skinwalker, Callback = function(v) auto_destroy.Skinwalker = v if v then handleEnemy(enemies and enemies:FindFirstChild("Skinwalker")) end end })

    DetailedEnemyGroup:AddDivider("Springer")
    DetailedEnemyGroup:AddToggle("Springer_Disable", { Text = "Auto Disable Shockwaves", Default = auto_disable.Springer, Callback = function(v) auto_disable.Springer = v if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end end })
    DetailedEnemyGroup:AddToggle("Springer_Break", { Text = "Auto Break AI", Default = auto_break.Springer, Callback = function(v) auto_break.Springer = v if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end end })
    DetailedEnemyGroup:AddToggle("Springer_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Springer, Callback = function(v) auto_destroy.Springer = v if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end end })

    DetailedEnemyGroup:AddDivider("ICBM")
    DetailedEnemyGroup:AddToggle("ICBM_Break", { Text = "Auto Break AI", Default = auto_break.ICBM, Callback = function(v) auto_break.ICBM = v if v then handleEnemy(enemies and enemies:FindFirstChild("ICBM")) end end })
    DetailedEnemyGroup:AddToggle("ICBM_Destroy", { Text = "Auto Destroy", Default = auto_destroy.ICBM, Callback = function(v) auto_destroy.ICBM = v if v then handleEnemy(enemies and enemies:FindFirstChild("ICBM")) end end })

    DetailedEnemyGroup:AddDivider("Baby")
    DetailedEnemyGroup:AddToggle("Baby_Disable", { Text = "Auto Disable", Default = auto_disable.Baby, Callback = function(v) auto_disable.Baby = v if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end end })
    DetailedEnemyGroup:AddToggle("Baby_Break", { Text = "Auto Break AI", Default = auto_break.Baby, Callback = function(v) auto_break.Baby = v if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end end })
    DetailedEnemyGroup:AddToggle("Baby_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Baby, Callback = function(v) auto_destroy.Baby = v if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end end })

    DetailedEnemyGroup:AddDivider("Flesh")
    DetailedEnemyGroup:AddToggle("Flesh_Disable", { Text = "Auto Disable", Default = auto_disable.Flesh, Callback = function(v) auto_disable.Flesh = v if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end end })
    DetailedEnemyGroup:AddToggle("Flesh_Break", { Text = "Auto Break AI", Default = auto_break.Flesh, Callback = function(v) auto_break.Flesh = v if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end end })
    DetailedEnemyGroup:AddToggle("Flesh_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Flesh, Callback = function(v) auto_destroy.Flesh = v if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end end })

    DetailedEnemyGroup:AddDivider("Guardian (CANNOT BE DISABLED)")
    DetailedEnemyGroup:AddToggle("Guardian_Protection", {
        Text = "Create Protection",
        Default = pb,
        Callback = function(Value)
            pb = Value
            if not Value then bulletprots:ClearAllChildren() end
        end
    })

    DetailedEnemyGroup:AddDivider("Operator")
    DetailedEnemyGroup:AddToggle("Operator_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Operator, Callback = function(v) auto_destroy.Operator = v if v then handleEnemy(enemies and enemies:FindFirstChild("Operator")) end end })

    DetailedEnemyGroup:AddDivider("Kolona")
    DetailedEnemyGroup:AddToggle("Kolona_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Kolona, Callback = function(v) auto_destroy.Kolona = v if v then handleEnemy(enemies and enemies:FindFirstChild("Kolona")) end end })

    DetailedEnemyGroup:AddDivider("Telefragger")
    DetailedEnemyGroup:AddToggle("Telefragger_Disable", { Text = "Auto Disable", Default = auto_disable.Telefragger, Callback = function(v) auto_disable.Telefragger = v if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end end })
    DetailedEnemyGroup:AddToggle("Telefragger_Break", { Text = "Auto Break AI", Default = auto_break.Telefragger, Callback = function(v) auto_break.Telefragger = v if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end end })
    DetailedEnemyGroup:AddToggle("Telefragger_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Telefragger, Callback = function(v) auto_destroy.Telefragger = v if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end end })

    DetailedEnemyGroup:AddDivider("Sigil")
    DetailedEnemyGroup:AddToggle("Sigil_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Sigil, Callback = function(v) auto_destroy.Sigil = v if v then handleEnemy(enemies and enemies:FindFirstChild("Sigil")) end end })

    DetailedEnemyGroup:AddDivider("Voidbreaker")
    DetailedEnemyGroup:AddToggle("Voidbreaker_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Voidbreaker, Callback = function(v) auto_destroy.Voidbreaker = v if v then handleEnemy(enemies and enemies:FindFirstChild("Voidbreaker")) end end })

    DetailedEnemyGroup:AddDivider("Cadence")
    DetailedEnemyGroup:AddToggle("Cadence_Disable", { Text = "Auto Disable", Default = auto_disable.Cadence, Callback = function(v) auto_disable.Cadence = v if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end end })
    DetailedEnemyGroup:AddToggle("Cadence_Break", { Text = "Auto Break AI", Default = auto_break.Cadence, Callback = function(v) auto_break.Cadence = v if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end end })
    DetailedEnemyGroup:AddToggle("Cadence_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Cadence, Callback = function(v) auto_destroy.Cadence = v if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end end })

    DetailedEnemyGroup:AddDivider("Voidbound Baby")
    DetailedEnemyGroup:AddToggle("ShadowBaby_Disable", { Text = "Auto Disable", Default = auto_disable.ShadowBaby, Callback = function(v) auto_disable.ShadowBaby = v if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end end })
    DetailedEnemyGroup:AddToggle("ShadowBaby_Break", { Text = "Auto Break AI", Default = auto_break.ShadowBaby, Callback = function(v) auto_break.ShadowBaby = v if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end end })
    DetailedEnemyGroup:AddToggle("ShadowBaby_Destroy", { Text = "Auto Destroy", Default = auto_destroy.ShadowBaby, Callback = function(v) auto_destroy.ShadowBaby = v if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end end })

    DetailedEnemyGroup:AddDivider("Scrapmaw")
    DetailedEnemyGroup:AddToggle("Scrapmaw_Destroy", { Text = "Auto Destroy", Default = auto_destroy.Scrapmaw, Callback = function(v) auto_destroy.Scrapmaw = v if v then handleEnemy(enemies and enemies:FindFirstChild("Scrapmaw")) end end })

    DetailedEnemyGroup:AddDivider("Reality Break")
    DetailedEnemyGroup:AddToggle("RealityBreak_Destroy", { Text = "Auto Destroy", Default = auto_destroy.RealityBreak, Callback = function(v) auto_destroy.RealityBreak = v if v then handleEnemy(enemies and enemies:FindFirstChild("RealityBreak")) end end })

    DetailedEnemyGroup:AddToggle("Celestial_Break", { Text = "Break Celestial AI", Default = auto_break.Celestial, Callback = function(v) auto_break.Celestial = v end })
    DetailedEnemyGroup:AddToggle("Celestial_Destroy", { Text = "Destroy Celestial", Default = auto_destroy.Celestial, Callback = function(v) auto_destroy.Celestial = v end })

    --------------------------------------------------------------------
    -- Map Tab
    --------------------------------------------------------------------
    local MapGroup = Tabs.Map:AddLeftGroupbox("Void")

    local antiVoidSelection = 1
    local av = false

    MapGroup:AddToggle("AntiVoid", {
        Text = "Anti Void",
        Default = false,
        Tooltip = "Toggles the Anti-Void feature",
        Callback = function(Value)
            av = Value
        end
    })

    MapGroup:AddDropdown("AntiVoidSetting", {
        Values = { "1. Teleport to Spawn", "2. Launch Up", "3. Closest Gift" },
        Default = 1,
        Multi = false,
        Text = "Anti Void Setting",
        Tooltip = "Select anti-void action",
        Callback = function(Value)
            antiVoidSelection = tonumber(string.split(Value, ".")[1])
        end
    })

    local lp = 500
    MapGroup:AddSlider("LaunchPower", {
        Text = "Launch Power",
        Default = 500,
        Min = 10,
        Max = 1000,
        Rounding = 0,
        Callback = function(Value)
            lp = Value
        end
    })

    MapGroup:AddToggle("VisibleVoid", {
        Text = "Visible Void",
        Default = false,
        Tooltip = "Toggles KillVoid visibility",
        Callback = function(Value)
            local killVoid = workspace:FindFirstChild("KillVoid")
            if killVoid then
                killVoid.Transparency = Value and 0 or 1
            end
        end
    })

    -- Music Tab
    local MusicGroup = Tabs.Music:AddLeftGroupbox("Playback")
    MusicGroup:AddButton({ Text = "Play Track 1", Func = function() end })
    MusicGroup:AddButton({ Text = "Stop Music", Func = function() end })
    MusicGroup:AddSlider("VolumeSlider", { Text = "Volume", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%", Callback = function(Value) end })

    -- Upgrades Tab
    local upgradeTabLeft = Tabs.Upgrades:AddLeftGroupbox("Upgrades Status")

    if upgradeTabLeft.Container then
        upgradeTabLeft.Container.AutomaticSize = Enum.AutomaticSize.Y
    end

    if fSignal then
        upgradeTabLeft:AddLabel("Your exploit can add upgrades.")
    else
        upgradeTabLeft:AddLabel("Your exploit currently doesn't support adding upgrades.")
    end

    upgradeTabLeft:AddDivider("Active Upgrades List")
    local activeUpgradesLabel = upgradeTabLeft:AddLabel("None Active")

    local clientUpgrades = {
        "MatrixTetrahedron", "Adrenaline", "HighlightGifts", "AdvancedGravityCoil", "SportShoes",
        "TheOrb", "RealWings", "GraceWings", "RadarPlayer", "RadarInstruments", "HighlightTripmines",
        "IceSkates", "SwiftnessRing", "GiftMagnet", "SharkTail", "EnemyOnTop", "PocketBell",
        "NinjaBelt", "Helmet", "DoubleJump", "RadarAltars"
    }

    updateActiveUpgradesDisplay = function()
        local textParts = {}
        for name, val in pairs(activeUpgrades) do
            if val > 0 then
                table.insert(textParts, string.format("<font color='#0055ff'>%s</font>: %d", name, val))
            end
        end
        
        local fullText = #textParts > 0 and table.concat(textParts, "\n") or "None Active"
        
        if activeUpgradesLabel and type(activeUpgradesLabel) == "table" and activeUpgradesLabel.TextLabel then
            activeUpgradesLabel.TextLabel.AutomaticSize = Enum.AutomaticSize.Y
            activeUpgradesLabel.TextLabel.TextWrapped = true
        end

        activeUpgradesLabel:SetText(fullText)
    end

    local function setupUpgradeGuardian(intv, name)
        if upgradeValueGuards[name] then
            upgradeValueGuards[name]:Disconnect()
            upgradeValueGuards[name] = nil
        end
        
        upgradeValueGuards[name] = intv.Changed:Connect(function(newValue)
            if isSettingGuardValue[name] then return end
            
            local desiredValue = activeUpgrades[name]
            if desiredValue and newValue ~= desiredValue then
                isSettingGuardValue[name] = true
                intv.Value = desiredValue
                isSettingGuardValue[name] = false
            end
        end)
    end

    applyUpgradeValue = function(name, targetValue, uLabel)
        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local intv = upgradesFolder and upgradesFolder:FindFirstChild(name)
        
        targetValue = math.max(0, math.floor(targetValue or 0))
        
        if targetValue > 0 then
            activeUpgrades[name] = targetValue
            if intv then
                isSettingGuardValue[name] = true
                intv.Value = targetValue
                isSettingGuardValue[name] = false
            else
                intv = Instance.new("IntValue")
                intv.Name = name
                intv.Value = targetValue
                if upgradesFolder then intv.Parent = upgradesFolder end
            end
            
            setupUpgradeGuardian(intv, name)

            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then
                        fSignal(events.UpgradesChanged.OnClientEvent, { [name] = targetValue })
                    end
                    if events.UpgradesChanged:IsA("RemoteEvent") then
                        events.UpgradesChanged:FireServer({ [name] = targetValue })
                    end
                end)
            end
        else
            activeUpgrades[name] = nil
            if intv then intv:Destroy() end
            if upgradeValueGuards[name] then
                upgradeValueGuards[name]:Disconnect()
                upgradeValueGuards[name] = nil
            end
            
            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then
                        fSignal(events.UpgradesChanged.OnClientEvent, { [name] = 0 })
                    end
                    if events.UpgradesChanged:IsA("RemoteEvent") then
                        events.UpgradesChanged:FireServer({ [name] = 0 })
                    end
                end)
            end
        end

        if uLabel then
            uLabel:SetText("Current: " .. tostring(targetValue))
        end
        
        updateActiveUpgradesDisplay()
    end

    local function restoreAllUpgrades()
        local upgradeFolderParent = ReplicatedStorage:WaitForChild("UpgradeFolder", 5)
        local upgradesFolder = upgradeFolderParent and upgradeFolderParent:WaitForChild("Upgrades", 5)
        
        for name, value in pairs(activeUpgrades) do
            if value > 0 then
                if upgradesFolder then
                    local intv = upgradesFolder:FindFirstChild(name)
                    if not intv then
                        intv = Instance.new("IntValue")
                        intv.Name = name
                        intv.Parent = upgradesFolder
                    end
                    isSettingGuardValue[name] = true
                    intv.Value = value
                    isSettingGuardValue[name] = false
                    
                    setupUpgradeGuardian(intv, name)
                    
                    if events and events:FindFirstChild("UpgradesChanged") then
                        pcall(function()
                            if fSignal then
                                fSignal(events.UpgradesChanged.OnClientEvent, { [name] = value })
                            end
                            if events.UpgradesChanged:IsA("RemoteEvent") then
                                events.UpgradesChanged:FireServer({ [name] = value })
                            end
                        end)
                    end
                end
            end
        end
        updateActiveUpgradesDisplay()
    end

    plr.CharacterAdded:Connect(function(newChar)
        task.wait(1) 
        restoreAllUpgrades()
    end)

    local upgradeListGroup = Tabs.Upgrades:AddRightGroupbox("Available Upgrades")

    for _, u in ipairs(clientUpgrades) do
        upgradeListGroup:AddDivider(u)
        
        local initialVal = 0
        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local existingInt = upgradesFolder and upgradesFolder:FindFirstChild(u)
        
        if existingInt then
            initialVal = existingInt.Value
            if initialVal > 0 then
                activeUpgrades[u] = initialVal
                setupUpgradeGuardian(existingInt, u)
            end
        end
        
        local uLabel = upgradeListGroup:AddLabel("Current: " .. tostring(initialVal))
        upgradeLabels[u] = uLabel
        
        upgradeListGroup:AddInput(u .. "_Input", {
            Default = tostring(initialVal),
            Numeric = true,
            Finished = true,
            Text = "Set Amount",
            Tooltip = "Type exact amount and press Enter",
            Placeholder = "Amount...",
            Callback = function(Value)
                local num = tonumber(Value)
                if num then
                    applyUpgradeValue(u, num, uLabel)
                end
            end
        })
        
        upgradeListGroup:AddButton({
            Text = "Add One (" .. u .. ")",
            Func = function()
                local current = activeUpgrades[u] or initialVal
                applyUpgradeValue(u, current + 1, uLabel)
            end
        })
        
        upgradeListGroup:AddButton({
            Text = "Remove One (" .. u .. ")",
            Func = function()
                local current = activeUpgrades[u] or initialVal
                applyUpgradeValue(u, current - 1, uLabel)
            end
        })
    end

    updateActiveUpgradesDisplay()
else
    Tabs.UniversalMain = Window:AddTab("Main - Universal", "globe")
    Tabs.Debug         = Window:AddTab("Debug", "bug")
    Tabs.Settings      = Window:AddTab("Settings", "settings")

    local UniversalGroup = Tabs.UniversalMain:AddLeftGroupbox("Universal Features")

    UniversalGroup:AddSlider("WalkSpeedSlider", {
        Text = "WalkSpeed",
        Default = 16,
        Min = 16,
        Max = 250,
        Rounding = 0,
        Callback = function(Value)
            if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
                plr.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
            end
        end
    })

    UniversalGroup:AddSlider("JumpPowerSlider", {
        Text = "JumpPower",
        Default = 50,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
                plr.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value
            end
        end
    })

    local TeleportGroup = Tabs.UniversalMain:AddRightGroupbox("Utilities")

    local function getPlayerNames()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                table.insert(list, p.Name)
            end
        end
        return list
    end

    local selectedPlayer = nil
    TeleportGroup:AddDropdown("TargetPlayerDropdown", {
        Text = "Select Player to TP",
        Values = getPlayerNames(),
        Default = 1,
        Callback = function(Value)
            selectedPlayer = Value
        end
    })

    TeleportGroup:AddButton({
        Text = "Refresh Player List",
        Func = function()
            if Options and Options.TargetPlayerDropdown then
                Options.TargetPlayerDropdown:SetValues(getPlayerNames())
            end
        end
    })

    TeleportGroup:AddButton({
        Text = "Teleport to Player",
        Func = function()
            if selectedPlayer then
                local targetPlr = Players:FindFirstChild(selectedPlayer)
                if targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    plr.Character.HumanoidRootPart.CFrame = targetPlr.Character.HumanoidRootPart.CFrame
                    Library:Notify("Teleported to " .. selectedPlayer, 3)
                end
            end
        end
    })

    TeleportGroup:AddButton({
        Text = "Rejoin Server",
        Func = function()
            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, plr)
        end
    })

    TeleportGroup:AddButton({
        Text = "Server Hop",
        Func = function()
            local success, servers = pcall(function()
                return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/0?sortOrder=Asc&limit=100"))
            end)
            if success and servers and servers.data then
                for _, s in ipairs(servers.data) do
                    if s.id ~= JobId and s.playing < s.maxPlayers then
                        TeleportService:TeleportToPlaceInstance(PlaceId, s.id, plr)
                        break
                    end
                end
            end
        end
    })
end

--------------------------------------------------------------------
-- Debug Tab (Loaded in BOTH modes)
--------------------------------------------------------------------
local DebugGroup = Tabs.Debug:AddLeftGroupbox("Server Info")

local playerLabel = DebugGroup:AddLabel("Players: Fetching...")
local pingLabel = DebugGroup:AddLabel("Ping: Fetching...")
local clientFpsLabel = DebugGroup:AddLabel("Client FPS: Fetching...")
local serverFpsLabel = DebugGroup:AddLabel("Server FPS: Fetching...")
local locationLabel = DebugGroup:AddLabel("Server Region: Fetching...")
local uptimeLabel = DebugGroup:AddLabel("Server Uptime: Fetching...")

local clientFPS = 0
local frameCount = 0
local lastFpsUpdate = os.clock()

RunService.RenderStepped:Connect(function()
    frameCount += 1
    local now = os.clock()
    if now - lastFpsUpdate >= 1 then
        clientFPS = frameCount / (now - lastFpsUpdate)
        frameCount = 0
        lastFpsUpdate = now
    end
end)

local serverLocation = "Estimating..."
task.spawn(function()
    task.wait(1)
    local playersList = Players:GetPlayers()
    if #playersList > 0 then
        local success, regionCode = pcall(function()
            return LocalizationService:GetCountryRegionForPlayerAsync(playersList[1])
        end)
        if success and regionCode then
            serverLocation = regionCode .. " (Est.)"
        else
            serverLocation = "Hidden by Roblox" 
        end
    else
        serverLocation = "Unknown"
    end
end)

local function formatUptime(seconds)
    local totalSeconds = math.floor(seconds)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local secs = totalSeconds % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%d:%02d", minutes, secs)
    end
end

local function getDebugData()
    local currentPlayers = Players:GetPlayers()
    local playerCount = #currentPlayers
    local maxPlayers = Players.MaxPlayers
    local ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local serverFPS = math.round(workspace:GetRealPhysicsFPS())
    local uptimeSeconds = workspace.DistributedGameTime
    
    return {
        Players = string.format("%d/%d", playerCount, maxPlayers),
        Ping = string.format("%d ms", ping),
        ClientFPS = math.round(clientFPS),
        ServerFPS = serverFPS,
        Location = serverLocation,
        Uptime = formatUptime(uptimeSeconds),
        PlayerList = currentPlayers
    }
end

DebugGroup:AddButton({
    Text = "Refresh Info",
    Func = function()
        local data = getDebugData()
        playerLabel:SetText("Players: " .. data.Players)
        pingLabel:SetText("Ping: " .. data.Ping)
        clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS)
        serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS)
        locationLabel:SetText("Server Region: " .. data.Location)
        uptimeLabel:SetText("Server Uptime: " .. data.Uptime)
        Library:Notify("Server Stats Refreshed!", 3)
    end
})

task.spawn(function()
    while task.wait(1) do
        local data = getDebugData()
        playerLabel:SetText("Players: " .. data.Players)
        pingLabel:SetText("Ping: " .. data.Ping)
        clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS)
        serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS)
        locationLabel:SetText("Server Region: " .. data.Location)
        uptimeLabel:SetText("Server Uptime: " .. data.Uptime)
    end
end)

--------------------------------------------------------------------
-- Debug Tools & Utility Panel (Loaded in BOTH modes)
--------------------------------------------------------------------
local DebugToolsGroup = Tabs.Debug:AddRightGroupbox("Developer Utilities")

DebugToolsGroup:AddButton({
    Text = "Execute Remote Spy (Cobalt)",
    Func = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/lesingee/cobalt/refs/heads/main/loader.lua"))()
        end)
        Library:Notify("Executed Cobalt Remote Spy.", 3)
    end
})

DebugToolsGroup:AddButton({
    Text = "Execute Dex (Dex++)",
    Func = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua"))()
        end)
        Library:Notify("Executed Dex++ Explorer.", 3)
    end
})

DebugToolsGroup:AddButton({
    Text = "Execute Infinite Yield",
    Func = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end)
        Library:Notify("Executed Infinite Yield.", 3)
    end
})

local memoryLabel = DebugToolsGroup:AddLabel("Memory Usage: Measuring...")
local instancesLabel = DebugToolsGroup:AddLabel("Total Instances: Measuring...")

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local memMB = math.round(collectgarbage("count") / 1024)
            local totalInstances = #game:GetDescendants()
            memoryLabel:SetText("Memory (Lua): " .. tostring(memMB) .. " MB")
            instancesLabel:SetText("Total Instances: " .. tostring(totalInstances))
        end)
    end
end)

local consoleLoggingActive = false
local consoleConnection = nil

DebugToolsGroup:AddToggle("ConsoleLoggerToggle", {
    Text = "Log Remote / Error Output",
    Default = false,
    Callback = function(Value)
        consoleLoggingActive = Value
        if Value then
            consoleConnection = LogService.MessageOut:Connect(function(msg, msgType)
                if consoleLoggingActive then
                    print("[NULL_DEBUG_LOG]: " .. msg)
                end
            end)
            Library:Notify("Console output logging enabled.", 3)
        else
            if consoleConnection then
                consoleConnection:Disconnect()
                consoleConnection = nil
            end
            Library:Notify("Console output logging disabled.", 3)
        end
    end
})

--------------------------------------------------------------------
-- System Group (Unload GUI - Loaded in BOTH modes)
--------------------------------------------------------------------
local SystemGroup = Tabs.Debug:AddRightGroupbox("System")

SystemGroup:AddButton({
    Text = "Unload GUI",
    Func = function()
        stopAllCollection()
        
        for _, conn in pairs(connections) do
            if conn then conn:Disconnect() end
        end
        for _, guard in pairs(upgradeValueGuards) do
            if guard then guard:Disconnect() end
        end
        if consoleConnection then
            consoleConnection:Disconnect()
        end
        
        if tripmineprots and tripmineprots.Parent then tripmineprots:Destroy() end
        if bulletprots and bulletprots.Parent then bulletprots:Destroy() end
        if velocityPart and velocityPart.Parent then velocityPart:Destroy() end

        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        if upgradesFolder then
            for name, _ in pairs(activeUpgrades) do
                local intv = upgradesFolder:FindFirstChild(name)
                if intv then intv:Destroy() end
                if events and events:FindFirstChild("UpgradesChanged") then
                    pcall(function()
                        if fSignal then
                            fSignal(events.UpgradesChanged.OnClientEvent, { [name] = 0 })
                        end
                        if events.UpgradesChanged:IsA("RemoteEvent") then
                            events.UpgradesChanged:FireServer({ [name] = 0 })
                        end
                    end)
                end
            end
        end
        table.clear(activeUpgrades)

        Library:Unload()
    end
})

--------------------------------------------------------------------
-- Settings Tab (Loaded in BOTH modes)
--------------------------------------------------------------------
local SettingsGroup = Tabs.Settings:AddLeftGroupbox("GUI Settings")

SettingsGroup:AddToggle("ExampleToggle", { Text = "Enable Example Feature", Default = false, Callback = function(Value) end })
SettingsGroup:AddDropdown("ExampleDropdown", { Text = "Choose Mode", Values = {"Mode A", "Mode B", "Mode C"}, Default = 1, Callback = function(Value) end })
SettingsGroup:AddKeyPicker("ExampleKeybind", { Default = "K", Text = "Toggle Menu Keybind", Callback = function() end })
