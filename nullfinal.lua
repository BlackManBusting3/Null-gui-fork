--------------------------------------------------------------------
-- Auto-Cleanup Previous Instance
--------------------------------------------------------------------
pcall(function()
    -- Disconnect old global connections if they exist
    if getgenv().NullGuiConnections then
        for _, conn in pairs(getgenv().NullGuiConnections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
    end
    
    -- Destroy old protection folders
    local oldFolder = workspace:FindFirstChild("NullGui_ProtectionSpheres")
    if oldFolder then oldFolder:Destroy() end
    
    local oldVel = workspace:FindFirstChild("VelocityVisualizer")
    if oldVel then oldVel:Destroy() end
    
    -- Unload old Obsidian UI if library reference exists
    if getgenv().NullGuiLibrary and typeof(getgenv().NullGuiLibrary.Unload) == "function" then
        getgenv().NullGuiLibrary:Unload()
    end
end)

-- Store references globally so the next execution can clean them up
getgenv().NullGuiConnections = {}
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
local SoundService = game:GetService("SoundService")

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
-- Whitelists Data Arrays
--------------------------------------------------------------------
local UpgradesList = {
    "BusinessLicense", "Paycheck", "Shield", "DoubleJump", "HighlightGifts", "Medal",
    "TriaOrbs", "BetterJumpPad", "SwiftnessRing", "GrapplePoints", "EnemyOnTop", "Helmet",
    "RadarAltars", "AdvancedGravityCoil", "IceSkates", "FannyPack", "PocketBell",
    "MoreAltars", "NinjaBelt", "LargerGrapplePoints", "SportShoes", "GiftMagnet",
    "SubspacialBarrier", "MatrixTetrahedron", "SharkTail", "PanicNecklace", "AltarOfVoid",
    "MiniatureHourglass", "GiftIdol"
}

local CursesList = {
    "Concussion", "LowerGravity", "MightyGong", "MoreRinging", "RandomSpawn",
    "OvertunedSpringer", "ScorchedEarth", "ProblemChild", "TweakedOdds", "Springloaded",
    "FasterLevelDestroy", "Telestabber", "SavoryRing", "Lap2", "ICBMBig",
    "TelefraggerPredict", "HighRoller", "FakeCount", "ScatteredGifts", "WeakJumpPads",
    "BladeCarousel", "OneLessChoice", "FragileTiles", "Tantrum"
}

local EnemiesList = {
    "ICBM", "Bell", "Baby", "Springer", "Mart", "Skinwalker", "Flesh",
    "Operator", "Telefragger", "Guardian", "Kolona", "Voidbreaker", "Cadence", "ShadowBaby"
}

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

local dynamicItems = workspace:FindFirstChild("Item_Pools")
local tripmines = dynamicItems and dynamicItems:FindFirstChild("Tripmine")
local goldentripmines = dynamicItems and dynamicItems:FindFirstChild("GoldTripmines")
local bullets = dynamicItems and dynamicItems:FindFirstChild("Bullet")

--------------------------------------------------------------------
-- Visualizers & Physical Safe Protection Spheres
--------------------------------------------------------------------
local activeTripmineProtections = {}
local activeBulletProtections = {}

local protectionFolder = workspace:FindFirstChild("NullGui_ProtectionSpheres")
if not protectionFolder then
    protectionFolder = Instance.new("Folder")
    protectionFolder.Name = "NullGui_ProtectionSpheres"
    protectionFolder.Parent = workspace
end

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
-- Integrated Settings & State Flags
--------------------------------------------------------------------
local Settings = {
    CollectNormal = false,
    CollectGolden = false,
    LegitCollection = false,
    LegitSpeed = 16,
    InstantTeleport = true, 
    TweenSpeed = 60,        
    DelayBetweenGifts = 0.05,
    AutoBeacon = false,
    AutoStartCollecting = false,
    AutoFarmBeta = false,
    EnemiesWhitelist = {},
    CursesWhitelist = {},
    UpgradesWhitelist = {}
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

-- Tile connections state
local antiFleshTilesEnabled = false
local persistentTileConnections = false
local persistentRespawnConnection = nil

-- Ported Disable Features state flags
local disableSeaMines = false
local disableVoidImplosions = false
local disableFakeBeacons = false
local disableOblivion = false

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

local pt = false
local pb = false
local velov = false
local connections = {}
local activeUpgrades = {}
local upgradeValueGuards = {}
local isSettingGuardValue = {}
local blacklistedGifts = {} 

local antiVoidSelection = 1
local av = false
local lp = 500

local loggedAttributes = {}
local logToggleActive = false

local updateActiveUpgradesDisplay = function() end
local applyUpgradeValue = function() end
local upgradeLabels = {}

--------------------------------------------------------------------
-- Global Player Event Connections (Auto Farm Dependencies)
--------------------------------------------------------------------
local respawnCounter = 0
local beaconFiredTime = 0
local isAutoFarmProcessing = false

local function handleEndScreenReset()
    task.spawn(function()
        for i = 1, 4 do
            pcall(function()
                local playerGui = plr:FindFirstChild("PlayerGui")
                local endScreen = playerGui and playerGui:FindFirstChild("EndScreen")
                local main = endScreen and endScreen:FindFirstChild("Main")
                local continueBtn = main and main:FindFirstChild("Continue")

                if continueBtn then
                    if continueBtn:IsA("GuiButton") then
                        for _, conn in ipairs(getconnections(continueBtn.MouseButton1Click)) do
                            conn:Fire()
                        end
                    end

                    local absPos = continueBtn.AbsolutePosition
                    local absSize = continueBtn.AbsoluteSize
                    local center = absPos + (absSize / 2)
                    
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
                end
            end)
            task.wait(3)
        end
        isAutoFarmProcessing = false
    end)
end

local function handlePlayerDeath()
    respawnCounter += 1
    if Settings.AutoFarmBeta then
        handleEndScreenReset()
    end
end

local function setupCharacter(char)
    respawnCounter += 1
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function()
            handlePlayerDeath()
        end)
    end
end

plr.CharacterAdded:Connect(setupCharacter)
if plr.Character then
    setupCharacter(plr.Character)
end

--------------------------------------------------------------------
-- Auto Farm Engine
--------------------------------------------------------------------
local function isValueWhitelisted(value, whitelistTable)
    if not value or not whitelistTable then return false end
    local searchVal = tostring(value):lower()
    for itemKey, isSelected in pairs(whitelistTable) do
        if isSelected and tostring(itemKey):lower() == searchVal then
            return true
        end
    end
    return false
end

local function interactWithPart(part)
    if not part or not part:IsA("BasePart") then return end
    
    local char = plr.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if root then
        root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.1)
    end

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)

    local closestPrompt = nil
    local shortestDist = 10
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
            local dist = (prompt.Parent.Position - part.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                closestPrompt = prompt
            end
        end
    end

    if closestPrompt then
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(closestPrompt)
            else
                closestPrompt:InputHoldBegin()
                task.wait(closestPrompt.HoldDuration)
                closestPrompt:InputHoldEnd()
            end
        end)
    end

    local voteEvent = events and (events:FindFirstChild("Vote") or events:FindFirstChild("SelectVote"))
    if voteEvent and voteEvent:IsA("RemoteEvent") then
        pcall(function()
            voteEvent:FireServer(part.Name)
        end)
    end
end

local function checkAndVoteSelectParts()
    if not Settings.AutoFarmBeta or isAutoFarmProcessing then return end

    local selectFolder = workspace:FindFirstChild("Select")
    if not selectFolder then return end

    local targets = {"1", "2", "3"}
    local matchedParts = {}

    for _, name in ipairs(targets) do
        local part = selectFolder:FindFirstChild(name)
        if part then
            local choiceType = part:GetAttribute("ChoiceType")
            local choiceName = part:GetAttribute("ChoiceName")

            if choiceType and choiceName then
                local upperType = tostring(choiceType):upper()
                local isMatched = false

                if upperType == "ENEMIES" then
                    isMatched = isValueWhitelisted(choiceName, Settings.EnemiesWhitelist)
                elseif upperType == "UPGRADES" then
                    isMatched = isValueWhitelisted(choiceName, Settings.UpgradesWhitelist)
                elseif upperType == "CURSES" or upperType == "GREAT CURSES" or upperType == "GREATCURSES" then
                    isMatched = isValueWhitelisted(choiceName, Settings.CursesWhitelist)
                end

                if isMatched then
                    table.insert(matchedParts, part)
                end
            end
        end
    end

    isAutoFarmProcessing = true
    task.spawn(function()
        local pickedCount = 0

        if #matchedParts > 0 then
            for i = #matchedParts, 2, -1 do
                local j = math.random(i)
                matchedParts[i], matchedParts[j] = matchedParts[j], matchedParts[i]
            end

            for _, chosenPart in ipairs(matchedParts) do
                if pickedCount >= 4 then break end
                if pickedCount > 0 then task.wait(0.5) end
                interactWithPart(chosenPart)
                pickedCount += 1
            end
        end

        local part3 = selectFolder:FindFirstChild("3")
        if part3 then
            if pickedCount > 0 then task.wait(0.5) end
            
            local char = plr.Character
            local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
            if root then
                root.CFrame = part3.CFrame + Vector3.new(0, 3, 0)
            end

            local startTime = os.clock()
            while (os.clock() - startTime) < 2 do
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)

                local closestPrompt = nil
                local shortestDist = 10
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
                        local dist = (prompt.Parent.Position - part3.Position).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closestPrompt = prompt
                        end
                    end
                end

                if closestPrompt then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(closestPrompt)
                        end
                    end)
                end

                task.wait(0.4)
            end

            interactWithPart(part3)
        end

        beaconFiredTime = os.clock()
        local startRespawns = respawnCounter

        while isAutoFarmProcessing do
            if (respawnCounter - startRespawns) >= 2 then break end
            if beaconFiredTime and (os.clock() - beaconFiredTime) >= 5 then break end
            task.wait(0.1)
        end

        isAutoFarmProcessing = false
    end)
end

--------------------------------------------------------------------
-- Debug Attribute Logging Helper
--------------------------------------------------------------------
local function logSelectAttributes()
    local selectFolder = workspace:FindFirstChild("Select")
    if not selectFolder then return end

    local categorized = { curses = {}, upgrades = {}, enemies = {}, other = {} }
    local targets = {"1", "2", "3"}
    local newFound = false

    for _, name in ipairs(targets) do
        local part = selectFolder:FindFirstChild(name)
        if part then
            local choiceName = tostring(part:GetAttribute("ChoiceName") or "N/A")
            local choiceType = tostring(part:GetAttribute("ChoiceType") or "N/A")
            local itemIndex = tostring(part:GetAttribute("itemIndex") or part:GetAttribute("ItemIndex") or "N/A")
            local entryKey = string.format("%s_%s_%s", choiceName, choiceType, itemIndex)

            if not loggedAttributes[entryKey] then
                loggedAttributes[entryKey] = true
                newFound = true
                local formattedEntry = string.format('["%s", "%s", "%s"]', choiceName, choiceType, itemIndex)
                local lowerType = choiceType:lower()

                if lowerType:find("curse") then table.insert(categorized.curses, formattedEntry)
                elseif lowerType:find("upgrade") then table.insert(categorized.upgrades, formattedEntry)
                elseif lowerType:find("enemi") or lowerType:find("enemy") then table.insert(categorized.enemies, formattedEntry)
                else table.insert(categorized.other, formattedEntry) end
            end
        end
    end

    if newFound then
        local outputSections = {}
        if #categorized.curses > 0 then table.insert(outputSections, "Attributes found for curses:\n" .. table.concat(categorized.curses, "\n")) end
        if #categorized.upgrades > 0 then table.insert(outputSections, "Attributes found for upgrades:\n" .. table.concat(categorized.upgrades, "\n")) end
        if #categorized.enemies > 0 then table.insert(outputSections, "Attributes found for enemies:\n" .. table.concat(categorized.enemies, "\n")) end
        if #categorized.other > 0 then table.insert(outputSections, "Attributes found for other:\n" .. table.concat(categorized.other, "\n")) end

        if #outputSections > 0 then
            local fullBlock = table.concat(outputSections, "\n\n\n") .. "\n\n\n"
            print("[Debug Attributes Output]:\n" .. fullBlock)
            if writefile and appendfile then
                pcall(function()
                    if not isfile or not isfile("SelectAttributesLog.txt") then
                        writefile("SelectAttributesLog.txt", fullBlock)
                    else
                        appendfile("SelectAttributesLog.txt", fullBlock)
                    end
                end)
            end
        end
    end
end

--------------------------------------------------------------------
-- Core Logic Utilities & Physical Protections 
--------------------------------------------------------------------
local function applyTileConnections()
    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("CurrentRooms") or workspace
    for _, obj in ipairs(mapFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lowerName = obj.Name:lower()
            if lowerName:find("flesh") or lowerName:find("ice") or lowerName:find("tile") then
                obj.CanTouch = not antiFleshTilesEnabled
            end
        end
    end
end

local function createProtectionSphere(target, radius, color)
    local sphere = Instance.new("Part")
    sphere.Name = "SafeProtectionSphere"
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
    sphere.CFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
    sphere.Anchored = true
    sphere.CanCollide = true
    sphere.CanTouch = true 
    sphere.Material = Enum.Material.Plastic
    sphere.Color = color or Color3.fromRGB(0, 170, 255)
    sphere.Transparency = 0
    sphere.Parent = protectionFolder
    return sphere
end

local function protectTripmine(trip)
    if activeTripmineProtections[trip] or (trip:IsA("BasePart") and trip.Transparency == 1) then return end
    local size = trip:IsA("BasePart") and trip.Size.X or 3
    local radius = (size + 5) / 2
    local sphere = createProtectionSphere(trip, radius, Color3.fromRGB(0, 255, 150))
    activeTripmineProtections[trip] = { sphere = sphere, radius = radius }

    trip.Destroying:Connect(function()
        if activeTripmineProtections[trip] then
            if activeTripmineProtections[trip].sphere then
                activeTripmineProtections[trip].sphere:Destroy()
            end
            activeTripmineProtections[trip] = nil
        end
    end)
end

local function protectBullet(b)
    if activeBulletProtections[b] or (b:IsA("BasePart") and b.Transparency == 1) then return end
    local size = b:IsA("BasePart") and b.Size.X or 4
    local radius = (size + 6) / 2
    local sphere = createProtectionSphere(b, radius, Color3.fromRGB(255, 50, 50))
    activeBulletProtections[b] = { sphere = sphere, radius = radius }

    b.Destroying:Connect(function()
        if activeBulletProtections[b] then
            if activeBulletProtections[b].sphere then
                activeBulletProtections[b].sphere:Destroy()
            end
            activeBulletProtections[b] = nil
        end
    end)
end

local lastProtectionScan = 0
local function processProtections()
    local now = os.clock()
    if now - lastProtectionScan > 0.5 then
        lastProtectionScan = now
        if pt then
            if tripmines then
                for _, mine in ipairs(tripmines:GetChildren()) do protectTripmine(mine) end
            end
            if goldentripmines then
                for _, mine in ipairs(goldentripmines:GetChildren()) do protectTripmine(mine) end
            end
        else
            if next(activeTripmineProtections) then
                for mine, data in pairs(activeTripmineProtections) do
                    if data.sphere then data.sphere:Destroy() end
                end
                table.clear(activeTripmineProtections)
            end
        end

        if pb and bullets then
            for _, b in ipairs(bullets:GetChildren()) do protectBullet(b) end
        else
            if next(activeBulletProtections) then
                for bullet, data in pairs(activeBulletProtections) do
                    if data.sphere then data.sphere:Destroy() end
                end
                table.clear(activeBulletProtections)
            end
        end
    end

    for target, data in pairs(activeTripmineProtections) do
        if target and target.Parent and data.sphere then
            data.sphere.CFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
        end
    end
    for target, data in pairs(activeBulletProtections) do
        if target and target.Parent and data.sphere then
            data.sphere.CFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
        end
    end
end

--------------------------------------------------------------------
-- Gift Collection & AI Defenses Logic 
--------------------------------------------------------------------
local Library

local function notif(msg, title)
    if Library and Library.Notify then
        Library:Notify(string.format("[%s]: %s", title or "System", msg), 3)
    end
end

local function getChar(player) return player and player.Character end
local function getRoot(character) return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart) end

local function refreshGifts(normal, golden)
    table.clear(availableNormalGifts)
    table.clear(availableGoldenGifts)

    local dynamicPools = workspace:FindFirstChild("Item_Pools")
    local normalFolder = (dynamicPools and dynamicPools:FindFirstChild("Gift")) or workspace:FindFirstChild("Gifts") or workspace:FindFirstChild("SpawnedGifts")
    local goldenFolder = (dynamicPools and dynamicPools:FindFirstChild("GoldenGift")) or normalFolder

    if normal and normalFolder then
        for _, gift in ipairs(normalFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if not isGolden then table.insert(availableNormalGifts, gift) end
        end
    end
    if golden and goldenFolder then
        for _, gift in ipairs(goldenFolder:GetChildren()) do
            local isGolden = gift.Name:lower():find("golden") ~= nil
            if isGolden then table.insert(availableGoldenGifts, gift) end
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
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentJumpHeight = 10, AgentMaxSlope = 45
    })

    local success, err = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if not tweening and not Settings.AutoBeacon then
                humanoid:MoveTo(root.Position) 
                return false
            end
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)

            local moveCompleted = false
            local conn = humanoid.MoveToFinished:Connect(function() moveCompleted = true end)
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
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
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
        if notifOn then notif("Already collecting gifts.", "Collection System") end
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
                    if Settings.AutoBeacon then handleSpawnNavigation() end
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

local function disableEnemyEntity(entity)
    if not entity or not (entity:IsA("Model") or entity:IsA("Folder") or entity:IsA("BasePart")) then return end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid.WalkSpeed = 0
        humanoid.PlatformStand = true
    end
    for _, obj in ipairs(entity:GetChildren()) do
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
    local searchContainers = {Camera, enemies, enemiesFolder}

    for _, container in ipairs(searchContainers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                local childNameLower = child.Name:lower()
                for _, targetName in ipairs(clientTargets) do
                    if childNameLower == targetName:lower() then disableEnemyEntity(child) end
                end
                for _, targetName in ipairs(destroyTargets) do
                    if childNameLower == targetName:lower() then child:Destroy() end
                end
            end
        end
    end
end

local function processPortedDisables()
    local searchPools = {workspace, dynamicItems, enemies, beacons}
    local function checkAndDestroy(instance)
        if not instance or not instance.Parent then return end
        local nameLower = instance.Name:lower()

        if disableSeaMines and (nameLower:find("seamine") or nameLower:find("sea_mine") or nameLower:find("mine")) and not nameLower:find("trip") then
            pcall(function() instance:Destroy() end)
            return
        end
        if disableVoidImplosions and (nameLower:find("voidimplosion") or nameLower:find("implosion") or nameLower:find("void_implosion")) then
            pcall(function() instance:Destroy() end)
            return
        end
        if disableFakeBeacons and (nameLower:find("fakebeacon") or nameLower:find("fake_beacon") or (nameLower:find("beacon") and nameLower:find("fake"))) then
            pcall(function() instance:Destroy() end)
            return
        end
        if disableOblivion and (nameLower:find("oblivion") or nameLower:find("oblivionentity")) then
            pcall(function() instance:Destroy() end)
            return
        end
    end

    for _, container in ipairs(searchPools) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                checkAndDestroy(child)
                if child:IsA("Folder") or child:IsA("Model") then
                    for _, subChild in ipairs(child:GetChildren()) do checkAndDestroy(subChild) end
                end
            end
        end
    end
end

local function handleEnemy(enemy)
    if not enemy then return end
    local name = enemy.Name
    if auto_destroy[name] then disableEnemy(name, true, false, false)
    elseif auto_break[name] then disableEnemy(name, false, true, false)
    elseif auto_disable[name] then disableEnemy(name, false, false, true) end
end

local function purgeExistingEnemies()
    local count = 0
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if enemy.Name ~= "Guardian" then
                enemy:Destroy()
                count += 1
            end
        end
    end
    return count
end

--------------------------------------------------------------------
-- Anti-Void Execution Engine
--------------------------------------------------------------------
local function processAntiVoid()
    if not av then return end
    local char = getChar(plr)
    local root = getRoot(char)
    local killVoid = workspace:FindFirstChild("KillVoid")
    local voidYThreshold = killVoid and (killVoid.Position.Y + 5) or -100

    if root and root.Position.Y <= voidYThreshold then
        if antiVoidSelection == 1 then
            handleSpawnNavigation()
        elseif antiVoidSelection == 2 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, lp, root.AssemblyLinearVelocity.Z)
        elseif antiVoidSelection == 3 then
            refreshGifts(true, true)
            local targetPool = #availableNormalGifts > 0 and availableNormalGifts or availableGoldenGifts
            local gift = getClosestGift(targetPool)
            if gift then
                local part = gift:IsA("BasePart") and gift or gift:FindFirstChildWhichIsA("BasePart")
                if part then root.CFrame = part.CFrame + Vector3.new(0, 5, 0) end
            else
                handleSpawnNavigation()
            end
        end
    end
end

--------------------------------------------------------------------
-- RenderStepped / Heartbeat Main Loop
--------------------------------------------------------------------
connections["MainHeartbeat"] = RunService.Heartbeat:Connect(function()
    processProtections()
    processAntiVoid()
    checkAndVoteSelectParts()

    local char = getChar(plr)
    local root = getRoot(char)
    if root and velov then
        local velocity = root.AssemblyLinearVelocity * Vector3.new(1,0.5,1)
        local speed = velocity.Magnitude
        if speed > 0 then
            local direction = velocity.Unit
            local length = math.clamp(speed * 0.5, 0.5, 150)
            velocityPart.Size = Vector3.new(0.2, 0.2, length)
            velocityPart.CFrame = CFrame.lookAt((root.Position + (root.Position + direction * length)) / 2, root.Position + direction * length)
            velocityPart.Transparency = 0
            vpBox.Size = velocityPart.Size
            vpBox.Transparency = 0.25
        else
            velocityPart.Transparency = 1
            vpBox.Transparency = 1
        end
    end
end)

--------------------------------------------------------------------
-- Load Obsidian UI Library
--------------------------------------------------------------------
Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

local Loading = Library:CreateLoading({
    Title = "Null GUI - Java.", Icon = "rbxassetid://138541249910408", TotalSteps = 4
})

Loading:SetMessage("Initializing...")
Loading:SetDescription("Waiting for game to load...")
task.wait(1)
Loading:SetCurrentStep(1)
Loading:SetDescription("Checking Place ID compatibility...")
task.wait(3)
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
    Title = "Java's Null Gui", Footer = string.format("%s | %d | %s | v1", gameName, PlaceId, JobId ~= "" and JobId or "Solo"),
    Icon = "cat", Center = true, AutoShow = true,
})

--------------------------------------------------------------------
-- UI Tab Definitions
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

    --------------------------------------------------------------------
    -- Farm Groupbox & Select Whitelists
    --------------------------------------------------------------------
    local FarmGroup = Tabs.Playerlist:AddLeftGroupbox("Farm")

    FarmGroup:AddToggle("AutoFarmBetaToggle", {
        Text = "auto farm (beta)",
        Default = Settings.AutoFarmBeta,
        Tooltip = "ENABLE AUTO START COLLECTING TOO!! (will be fixed later).",
        Callback = function(Value)
            Settings.AutoFarmBeta = Value
            if Value then
                Settings.AutoStartCollecting = true
                if Options and Options.AutoStartCollectingToggle then Options.AutoStartCollectingToggle:SetValue(true) end
                Library:Notify("Auto Farm (Beta) Enabled.", 2)
            else
                Library:Notify("Auto Farm (Beta) Disabled.", 2)
            end
        end
    })

    FarmGroup:AddDropdown("EnemiesWhitelistDropdown", {
        Values = EnemiesList,
        Multi = true,
        Text = "Enemies Whitelist",
        Tooltip = "Select which Enemies to vote for.",
        Callback = function(Value)
            Settings.EnemiesWhitelist = Value
        end
    })

    FarmGroup:AddDropdown("CursesWhitelistDropdown", {
        Values = CursesList,
        Multi = true,
        Text = "Curses Whitelist",
        Tooltip = "Select which Curses to vote for.",
        Callback = function(Value)
            Settings.CursesWhitelist = Value
        end
    })

    FarmGroup:AddDropdown("UpgradesWhitelistDropdown", {
        Values = UpgradesList,
        Multi = true,
        Text = "Upgrades Whitelist",
        Tooltip = "Select which Upgrades to vote for.",
        Callback = function(Value)
            Settings.UpgradesWhitelist = Value
        end
    })

    local PlayerGroup = Tabs.Playerlist:AddLeftGroupbox("Main Features")
    PlayerGroup:AddToggle("VelocityVisualizerToggle", {
        Text = "Velocity Visualizer",
        Default = false,
        Callback = function(Value)
            velov = Value
            if not Value then
                velocityPart.Transparency = 1
                vpBox.Transparency = 1
            end
        end
    })

    --------------------------------------------------------------------
    -- Gifts Collection
    --------------------------------------------------------------------
    local GiftGroup = Tabs.Playerlist:AddRightGroupbox("Gifts Collection")

    GiftGroup:AddLabel("<font color='#AAAAAA'><b>NOTE:</b> Finding gifts can be slow\n Use Instant TP for max collection.</font>")

    GiftGroup:AddToggle("AutoStartCollectingToggle", {
        Text = "<font color='#00FFCC'>Auto start collecting</font>",
        Default = Settings.AutoStartCollecting,
        Tooltip = "Automatically starts/restarts normal gift collection when SoundService.SFXFolder.NewLevel plays.",
        Callback = function(Value)
            Settings.AutoStartCollecting = Value
            if Value then
                local sfxFolder = SoundService:FindFirstChild("SFXFolder")
                local newLevelSound = sfxFolder and sfxFolder:FindFirstChild("NewLevel")
                if newLevelSound and newLevelSound:IsA("Sound") then
                    if connections["AutoStartCollectingConn"] then connections["AutoStartCollectingConn"]:Disconnect() end
                    connections["AutoStartCollectingConn"] = newLevelSound.Played:Connect(function()
                        if Settings.AutoStartCollecting then
                            Settings.CollectNormal = true
                            if Options and Options.CollectNormalToggle then Options.CollectNormalToggle:SetValue(true) end
                            if tweening then stopAllCollection(); task.wait(0.1) end
                            collectGiftsEngine(false)
                            if notifOn then notif("NewLevel sound detected. Auto-started normal gift collection.", "Collection System") end
                        end
                    end)
                end
                Library:Notify("Auto Start Collecting Enabled.", 2)
            else
                if connections["AutoStartCollectingConn"] then
                    connections["AutoStartCollectingConn"]:Disconnect()
                    connections["AutoStartCollectingConn"] = nil
                end
                Library:Notify("Auto Start Collecting Disabled.", 2)
            end
        end
    })

    GiftGroup:AddToggle("CollectNormalToggle", {
        Text = "<font color='#AA55FF'>Collect Normal Gifts</font>",
        Default = Settings.CollectNormal,
        Callback = function(Value)
            Settings.CollectNormal = Value
            if Value then
                if Settings.CollectGolden then
                    Settings.CollectGolden = false
                    if Options and Options.CollectGoldenToggle then Options.CollectGoldenToggle:SetValue(false) end
                end
                collectGiftsEngine(false)
            else
                if not Settings.CollectGolden and tweening then stopAllCollection() end
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
                    if Options and Options.CollectNormalToggle then Options.CollectNormalToggle:SetValue(false) end
                end
                collectGiftsEngine(true)
            else
                if not Settings.CollectNormal and tweening then stopAllCollection() end
            end
        end
    })

    GiftGroup:AddToggle("LegitCollectionToggle", {
        Text = "<font color='#FF4444'>Legit collection (slow)</font>",
        Default = Settings.LegitCollection,
        Tooltip = "Uses PathfindingService to naturally walk to gifts instead of teleporting.",
        Callback = function(Value)
            Settings.LegitCollection = Value
            if Value then Library:Notify("Legit Pathfinding Mode Enabled.", 2) end
        end
    })

    GiftGroup:AddInput("LegitSpeedInput", {
        Default = tostring(Settings.LegitSpeed), Numeric = true, Finished = true, Text = "Legit WalkSpeed",
        Placeholder = "16...", Callback = function(Value)
            local num = tonumber(Value)
            if num and num > 0 then Settings.LegitSpeed = num; Library:Notify("Legit Speed set to " .. tostring(num), 2) end
        end
    })

    GiftGroup:AddToggle("AutoBeaconToggle", { Text = "<font color='#00FF00'>Walk/TP To Beacon On Finish</font>", Default = Settings.AutoBeacon, Callback = function(Value) Settings.AutoBeacon = Value end })
    GiftGroup:AddButton({ Text = "<font color='#FF4444'>Cancel Gift Collection</font>", Func = function() stopAllCollection(); Library:Notify("Cancelled gift collection.", 2) end })
    GiftGroup:AddToggle("InstantTPToggle", { Text = "Instant Teleport Collection", Default = Settings.InstantTeleport, Callback = function(Value) Settings.InstantTeleport = Value end })
    
    GiftGroup:AddInput("TweenSpeedInput", {
        Default = tostring(Settings.TweenSpeed), Numeric = true, Finished = true, Text = "Tween Speed (If TP Off)",
        Placeholder = "300...", Callback = function(Value)
            local num = tonumber(Value)
            if num and num > 0 then Settings.TweenSpeed = num; Library:Notify("Tween Speed set to " .. tostring(num), 2) end
        end
    })

    GiftGroup:AddInput("TeleportDelayInput", {
        Default = tostring(Settings.DelayBetweenGifts), Numeric = true, Finished = true, Text = "Teleport Delay (Seconds)",
        Placeholder = "0.05...", Callback = function(Value)
            local num = tonumber(Value)
            if num and num >= 0 then Settings.DelayBetweenGifts = num; Library:Notify("Teleport Delay set to " .. tostring(num) .. "s", 2) end
        end
    })

    -- Enemies Tab
    local EnemyControlGroup = Tabs.Enemies:AddLeftGroupbox("AI & Entity Disabler")

    EnemyControlGroup:AddToggle("DisableAllEnemies", {
        Text = "Disable All Enemy AI", Default = false,
        Callback = function(Value)
            disableAllEnemies = Value
            if Value then
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do disableEnemyEntity(enemy) end
                    connections["DisableEnemies"] = enemies.ChildAdded:Connect(function(child)
                        if disableAllEnemies then task.wait(0.1); disableEnemyEntity(child) end
                    end)
                end
                Library:Notify("Workspace Enemy AI disabled.", 3)
            else
                if connections["DisableEnemies"] then connections["DisableEnemies"]:Disconnect(); connections["DisableEnemies"] = nil end
                Library:Notify("Workspace Enemy AI re-enabled.", 3)
            end
        end
    })

    EnemyControlGroup:AddToggle("DisableClientEnemies", {
        Text = "Disable all client sided enemies", Default = false,
        Callback = function(Value)
            disableClientEnemies = Value
            if Value then
                processClientSideEnemies()
                connections["DisableClientEnemies"] = RunService.Heartbeat:Connect(function()
                    if disableClientEnemies then processClientSideEnemies() end
                end)
                Library:Notify("Client-sided enemies disabler activated.", 3)
            else
                if connections["DisableClientEnemies"] then connections["DisableClientEnemies"]:Disconnect(); connections["DisableClientEnemies"] = nil end
                Library:Notify("Client-sided enemies disabler stopped.", 3)
            end
        end
    })

    EnemyControlGroup:AddToggle("DeleteAllEnemies", {
        Text = "Delete All Enemies", Default = false,
        Callback = function(Value)
            deleteAllEnemies = Value
            if Value then
                pb = true
                if Options and Options.Guardian_Protection then Options.Guardian_Protection:SetValue(true) end
                if enemies then
                    purgeExistingEnemies()
                    connections["DeleteEnemies"] = enemies.ChildAdded:Connect(function(child)
                        if deleteAllEnemies then
                            task.defer(function()
                                if child and child.Parent and child.Name ~= "Guardian" then child:Destroy() end
                            end)
                        end
                    end)
                end
                Library:Notify("Auto-delete all enemies enabled (Guardian Protection active).", 3)
            else
                if connections["DeleteEnemies"] then connections["DeleteEnemies"]:Disconnect(); connections["DeleteEnemies"] = nil end
                Library:Notify("Auto-delete all enemies disabled.", 3)
            end
        end
    })

    task.spawn(function()
        while task.wait(0.5) do processPortedDisables() end
    end)

    local EnemyActionGroup = Tabs.Enemies:AddRightGroupbox("Actions & Utilities")
    EnemyActionGroup:AddButton({ Text = "Purge All Existing Enemies", Func = function() local count = purgeExistingEnemies(); Library:Notify("Purged " .. tostring(count) .. " enemies from workspace.", 3) end })
    EnemyActionGroup:AddButton({ Text = "Refresh Target List", Func = function() Library:Notify("Refreshed active enemy cache.", 2) end })

    local ActiveEnemiesGroup = Tabs.Enemies:AddRightGroupbox("Active Enemies")
    local activeEnemiesLabel = ActiveEnemiesGroup:AddLabel("Scanning workspace...")

    task.spawn(function()
        while task.wait(1) do
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
                        table.insert(lines, string.format("<font color='#AAAAAA'>%s (Disabled)</font>", enemy.Name)) 
                    else 
                        table.insert(lines, string.format("<font color='#00FF00'>%s (Active)</font>", enemy.Name)) 
                    end
                end
                activeEnemiesLabel:SetText(table.concat(lines, "\n"))
            end
        end
    end)

    local DetailedEnemyGroup = Tabs.Enemies:AddLeftGroupbox("Granular Enemy Options")

    task.spawn(function()
        while task.wait(0.75) do
            if enemies then for _, enemy in ipairs(enemies:GetChildren()) do handleEnemy(enemy) end end
        end
    end)
    if enemies then
        connections["GranularChildAdded"] = enemies.ChildAdded:Connect(function(child) task.wait(0.1); handleEnemy(child) end)
    end

    local function addDetailedEnemy(group, name)
        group:AddDivider(name)
        if auto_disable[name] ~= nil then 
            group:AddToggle(name.."_Disable", { Text = "Auto Disable", Default = auto_disable[name], Callback = function(v) auto_disable[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end }) 
        end
        if auto_break[name] ~= nil then 
            group:AddToggle(name.."_Break", { Text = "Auto Break AI", Default = auto_break[name], Callback = function(v) auto_break[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end }) 
        end
        if auto_destroy[name] ~= nil then 
            group:AddToggle(name.."_Destroy", { Text = "Auto Destroy", Default = auto_destroy[name], Callback = function(v) auto_destroy[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end }) 
        end
    end

    addDetailedEnemy(DetailedEnemyGroup, "Bell")
    addDetailedEnemy(DetailedEnemyGroup, "Mart")
    addDetailedEnemy(DetailedEnemyGroup, "Skinwalker")
    addDetailedEnemy(DetailedEnemyGroup, "Springer")
    addDetailedEnemy(DetailedEnemyGroup, "ICBM")
    addDetailedEnemy(DetailedEnemyGroup, "Baby")
    addDetailedEnemy(DetailedEnemyGroup, "Flesh")
    
    DetailedEnemyGroup:AddDivider("Guardian (CANNOT BE DISABLED)")
    DetailedEnemyGroup:AddToggle("Guardian_Protection", {
        Text = "Create Bullet Protection Sphere", Default = pb,
        Callback = function(Value)
            pb = Value
            if not Value then 
                for _, d in pairs(activeBulletProtections) do if d.sphere then d.sphere:Destroy() end end
                table.clear(activeBulletProtections) 
            end
        end
    })

    addDetailedEnemy(DetailedEnemyGroup, "Operator")
    addDetailedEnemy(DetailedEnemyGroup, "Kolona")
    addDetailedEnemy(DetailedEnemyGroup, "Telefragger")
    addDetailedEnemy(DetailedEnemyGroup, "Sigil")
    addDetailedEnemy(DetailedEnemyGroup, "Voidbreaker")
    addDetailedEnemy(DetailedEnemyGroup, "Cadence")
    addDetailedEnemy(DetailedEnemyGroup, "ShadowBaby")
    addDetailedEnemy(DetailedEnemyGroup, "Scrapmaw")
    addDetailedEnemy(DetailedEnemyGroup, "RealityBreak")
    addDetailedEnemy(DetailedEnemyGroup, "Celestial")

    --------------------------------------------------------------------
    -- Map Tab
    --------------------------------------------------------------------
    local MapGroup = Tabs.Map:AddLeftGroupbox("Void")
    MapGroup:AddToggle("AntiVoid", { Text = "Anti Void", Default = false, Callback = function(Value) av = Value end })
    MapGroup:AddDropdown("AntiVoidSetting", { Values = { "1. Teleport to Spawn", "2. Launch Up", "3. Closest Gift" }, Default = 1, Multi = false, Text = "Anti Void Setting", Callback = function(Value) antiVoidSelection = tonumber(string.split(Value, ".")[1]) end })
    MapGroup:AddSlider("LaunchPower", { Text = "Launch Power", Default = 500, Min = 10, Max = 1000, Rounding = 0, Callback = function(Value) lp = Value end })
    MapGroup:AddToggle("VisibleVoid", { Text = "Visible Void", Default = false, Callback = function(Value) local killVoid = workspace:FindFirstChild("KillVoid"); if killVoid then killVoid.Transparency = Value and 0 or 1 end end })

    local MapProtectionGroup = Tabs.Map:AddLeftGroupbox("Map Defenses")
    MapProtectionGroup:AddToggle("Tripmine_Protection", { Text = "Tripmine Safe Sphere Protection", Default = pt, Callback = function(Value) pt = Value; if not Value then for _, d in pairs(activeTripmineProtections) do if d.sphere then d.sphere:Destroy() end end table.clear(activeTripmineProtections) end end })

    local TilesGroup = Tabs.Map:AddRightGroupbox("tiles")
    TilesGroup:AddToggle("AntiFleshIceTiles", { Text = "Anti flesh tiles/ ice tiles (tile connection)", Default = false, Callback = function(Value) antiFleshTilesEnabled = Value; applyTileConnections() end })
    TilesGroup:AddToggle("PersistentTileConnections", { Text = "Persistent tile connections", Default = false, Callback = function(Value) persistentTileConnections = Value; if Value then if not persistentRespawnConnection then persistentRespawnConnection = plr.CharacterAdded:Connect(function() task.wait(1); if persistentTileConnections and antiFleshTilesEnabled then applyTileConnections() end end) end else if persistentRespawnConnection then persistentRespawnConnection:Disconnect(); persistentRespawnConnection = nil end end end })

    local ExtraDisablesGroup = Tabs.Map:AddRightGroupbox("Null GUI Extra Disables")
    ExtraDisablesGroup:AddToggle("DisableSeaMines", { Text = "Disable Sea Mines", Default = false, Callback = function(Value) disableSeaMines = Value end })
    ExtraDisablesGroup:AddToggle("DisableVoidImplosions", { Text = "Disable Void Implosions", Default = false, Callback = function(Value) disableVoidImplosions = Value end })
    ExtraDisablesGroup:AddToggle("DisableFakeBeacons", { Text = "Disable Fake Beacons", Default = false, Callback = function(Value) disableFakeBeacons = Value end })
    ExtraDisablesGroup:AddToggle("DisableOblivion", { Text = "Disable Oblivion", Default = false, Callback = function(Value) disableOblivion = Value end })

    -- Music Tab
    local MusicGroup = Tabs.Music:AddLeftGroupbox("Playback")
    MusicGroup:AddButton({ Text = "Play Track 1", Func = function() if music and music:IsA("Sound") then music:Play() end end })
    MusicGroup:AddButton({ Text = "Stop Music", Func = function() if music and music:IsA("Sound") then music:Stop() end end })
    MusicGroup:AddSlider("VolumeSlider", { Text = "Volume", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%", Callback = function(Value) if music and music:IsA("Sound") then music.Volume = Value / 100 end end })

    -- Upgrades Tab
    local upgradeTabLeft = Tabs.Upgrades:AddLeftGroupbox("Upgrades Status")
    if upgradeTabLeft.Container then upgradeTabLeft.Container.AutomaticSize = Enum.AutomaticSize.Y end
    if fSignal then upgradeTabLeft:AddLabel("Your exploit can add upgrades.") else upgradeTabLeft:AddLabel("Your exploit currently doesn't support adding upgrades.") end
    upgradeTabLeft:AddDivider("Active Upgrades List")
    
    local activeUpgradesLabel = upgradeTabLeft:AddLabel("None Active")
    local clientUpgrades = { "MatrixTetrahedron", "Adrenaline", "HighlightGifts", "AdvancedGravityCoil", "SportShoes", "TheOrb", "RealWings", "GraceWings", "RadarPlayer", "RadarInstruments", "HighlightTripmines", "IceSkates", "SwiftnessRing", "GiftMagnet", "SharkTail", "EnemyOnTop", "PocketBell", "NinjaBelt", "Helmet", "DoubleJump", "RadarAltars" }

    updateActiveUpgradesDisplay = function()
        local textParts = {}
        for name, val in pairs(activeUpgrades) do if val > 0 then table.insert(textParts, string.format("<font color='#0055ff'>%s</font>: %d", name, val)) end end
        local fullText = #textParts > 0 and table.concat(textParts, "\n") or "None Active"
        if activeUpgradesLabel and type(activeUpgradesLabel) == "table" and activeUpgradesLabel.TextLabel then 
            activeUpgradesLabel.TextLabel.AutomaticSize = Enum.AutomaticSize.Y 
            activeUpgradesLabel.TextLabel.TextWrapped = true 
        end
        activeUpgradesLabel:SetText(fullText)
    end

    local function setupUpgradeGuardian(intv, name)
        if upgradeValueGuards[name] then upgradeValueGuards[name]:Disconnect(); upgradeValueGuards[name] = nil end
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
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, { [name] = targetValue }) end 
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({ [name] = targetValue }) end 
                end) 
            end
        else
            activeUpgrades[name] = nil
            if intv then intv:Destroy() end
            if upgradeValueGuards[name] then upgradeValueGuards[name]:Disconnect(); upgradeValueGuards[name] = nil end
            if events and events:FindFirstChild("UpgradesChanged") then 
                pcall(function() 
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, { [name] = 0 }) end 
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({ [name] = 0 }) end 
                end) 
            end
        end
        if uLabel then uLabel:SetText("Current: " .. tostring(targetValue)) end
        updateActiveUpgradesDisplay()
    end

    local function restoreAllUpgrades()
        local upgradeFolderParent = ReplicatedStorage:WaitForChild("UpgradeFolder", 5)
        local upgradesFolder = upgradeFolderParent and upgradeFolderParent:WaitForChild("Upgrades", 5)
        for name, value in pairs(activeUpgrades) do
            if value > 0 then
                if upgradesFolder then
                    local intv = upgradesFolder:FindFirstChild(name)
                    if not intv then intv = Instance.new("IntValue"); intv.Name = name; intv.Parent = upgradesFolder end
                    isSettingGuardValue[name] = true 
                    intv.Value = value 
                    isSettingGuardValue[name] = false
                    setupUpgradeGuardian(intv, name)
                    if events and events:FindFirstChild("UpgradesChanged") then 
                        pcall(function() 
                            if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, { [name] = value }) end 
                            if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({ [name] = value }) end 
                        end) 
                    end
                end
            end
        end
        updateActiveUpgradesDisplay()
    end

    plr.CharacterAdded:Connect(function(newChar) task.wait(1); restoreAllUpgrades() end)
    local upgradeListGroup = Tabs.Upgrades:AddRightGroupbox("Available Upgrades")

    for _, u in ipairs(clientUpgrades) do
        upgradeListGroup:AddDivider(u)
        local initialVal = 0
        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local existingInt = upgradesFolder and upgradesFolder:FindFirstChild(u)
        
        if existingInt then
            initialVal = existingInt.Value
            if initialVal > 0 then activeUpgrades[u] = initialVal; setupUpgradeGuardian(existingInt, u) end
        end
        
        local uLabel = upgradeListGroup:AddLabel("Current: " .. tostring(initialVal))
        upgradeLabels[u] = uLabel
        
        upgradeListGroup:AddInput(u .. "_Input", { Default = tostring(initialVal), Numeric = true, Finished = true, Text = "Set Amount", Placeholder = "Amount...", Callback = function(Value) local num = tonumber(Value) if num then applyUpgradeValue(u, num, uLabel) end end })
        upgradeListGroup:AddButton({ Text = "Add One (" .. u .. ")", Func = function() local current = activeUpgrades[u] or initialVal; applyUpgradeValue(u, current + 1, uLabel) end })
        upgradeListGroup:AddButton({ Text = "Remove One (" .. u .. ")", Func = function() local current = activeUpgrades[u] or initialVal; applyUpgradeValue(u, current - 1, uLabel) end })
    end
    updateActiveUpgradesDisplay()
else
    Tabs.UniversalMain = Window:AddTab("Main - Universal", "globe")
    Tabs.Debug         = Window:AddTab("Debug", "bug")
    Tabs.Settings      = Window:AddTab("Settings", "settings")

    local UniversalGroup = Tabs.UniversalMain:AddLeftGroupbox("Universal Features")
    UniversalGroup:AddSlider("WalkSpeedSlider", { Text = "WalkSpeed", Default = 16, Min = 16, Max = 250, Rounding = 0, Callback = function(Value) if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value end end })
    UniversalGroup:AddSlider("JumpPowerSlider", { Text = "JumpPower", Default = 50, Min = 50, Max = 500, Rounding = 0, Callback = function(Value) if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value end end })

    local TeleportGroup = Tabs.UniversalMain:AddRightGroupbox("Utilities")
    local function getPlayerNames()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= plr then table.insert(list, p.Name) end end
        return list
    end

    local selectedPlayer = nil
    TeleportGroup:AddDropdown("TargetPlayerDropdown", { Text = "Select Player to TP", Values = getPlayerNames(), Default = 1, Callback = function(Value) selectedPlayer = Value end })
    TeleportGroup:AddButton({ Text = "Refresh Player List", Func = function() if Options and Options.TargetPlayerDropdown then Options.TargetPlayerDropdown:SetValues(getPlayerNames()) end end })
    TeleportGroup:AddButton({ Text = "Teleport to Player", Func = function() if selectedPlayer then local targetPlr = Players:FindFirstChild(selectedPlayer) if targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then plr.Character.HumanoidRootPart.CFrame = targetPlr.Character.HumanoidRootPart.CFrame; Library:Notify("Teleported to " .. selectedPlayer, 3) end end end })
    TeleportGroup:AddButton({ Text = "Rejoin Server", Func = function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, plr) end })
    TeleportGroup:AddButton({ Text = "Server Hop", Func = function() local success, servers = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/0?sortOrder=Asc&limit=100")) end) if success and servers and servers.data then for _, s in ipairs(servers.data) do if s.id ~= JobId and s.playing < s.maxPlayers then TeleportService:TeleportToPlaceInstance(PlaceId, s.id, plr); break end end end end })
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
    if now - lastFpsUpdate >= 1 then clientFPS = frameCount / (now - lastFpsUpdate); frameCount = 0; lastFpsUpdate = now end
end)

local serverLocation = "Estimating..."
task.spawn(function()
    task.wait(1)
    local playersList = Players:GetPlayers()
    if #playersList > 0 then
        local success, regionCode = pcall(function() return LocalizationService:GetCountryRegionForPlayerAsync(playersList[1]) end)
        if success and regionCode then serverLocation = regionCode .. " (Est.)" else serverLocation = "Hidden by Roblox" end
    else
        serverLocation = "Unknown"
    end
end)

local function formatUptime(seconds)
    local totalSeconds = math.floor(seconds)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local secs = totalSeconds % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, secs) else return string.format("%d:%02d", minutes, secs) end
end

local function getDebugData()
    local currentPlayers = Players:GetPlayers()
    local ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local serverFPS = math.round(workspace:GetRealPhysicsFPS())
    local uptimeSeconds = workspace.DistributedGameTime
    return { Players = string.format("%d/%d", #currentPlayers, Players.MaxPlayers), Ping = string.format("%d ms", ping), ClientFPS = math.round(clientFPS), ServerFPS = serverFPS, Location = serverLocation, Uptime = formatUptime(uptimeSeconds), PlayerList = currentPlayers }
end

DebugGroup:AddButton({ Text = "Refresh Info", Func = function() local data = getDebugData(); playerLabel:SetText("Players: " .. data.Players); pingLabel:SetText("Ping: " .. data.Ping); clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS); serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS); locationLabel:SetText("Server Region: " .. data.Location); uptimeLabel:SetText("Server Uptime: " .. data.Uptime); Library:Notify("Server Stats Refreshed!", 3) end })

task.spawn(function()
    while task.wait(1) do local data = getDebugData(); playerLabel:SetText("Players: " .. data.Players); pingLabel:SetText("Ping: " .. data.Ping); clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS); serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS); locationLabel:SetText("Server Region: " .. data.Location); uptimeLabel:SetText("Server Uptime: " .. data.Uptime) end
end)

local DebugToolsGroup = Tabs.Debug:AddRightGroupbox("Developer Utilities")
DebugToolsGroup:AddToggle("AutoLogAttributesToggle", { Text = "Log Select Attributes (Every 10s)", Default = false, Callback = function(Value) logToggleActive = Value; if Value then Library:Notify("Auto Select attribute logging started (10s interval).", 3); task.spawn(function() while logToggleActive do logSelectAttributes(); task.wait(10) end end) else Library:Notify("Auto Select attribute logging stopped.", 3) end end })
DebugToolsGroup:AddButton({ Text = "Log Select Attributes (Once)", Func = function() logSelectAttributes(); Library:Notify("Logged Select attributes to file/console.", 3) end })
DebugToolsGroup:AddButton({ Text = "Execute Remote Spy (Cobalt)", Func = function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/lesingee/cobalt/refs/heads/main/loader.lua"))() end); Library:Notify("Executed Cobalt Remote Spy.", 3) end })
DebugToolsGroup:AddButton({ Text = "Execute Dex (Dex++)", Func = function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua"))() end); Library:Notify("Executed Dex++ Explorer.", 3) end })
DebugToolsGroup:AddButton({ Text = "Execute Infinite Yield", Func = function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end); Library:Notify("Executed Infinite Yield.", 3) end })

local memoryLabel = DebugToolsGroup:AddLabel("Memory Usage: Measuring...")
local instancesLabel = DebugToolsGroup:AddLabel("Total Instances: Measuring...")
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local memMB = math.round(collectgarbage("count") / 1024)
            memoryLabel:SetText("Memory (Lua): " .. tostring(memMB) .. " MB")
            instancesLabel:SetText("Total Instances: " .. tostring(#game:GetDescendants()))
        end)
    end
end)

local consoleLoggingActive = false
local consoleConnection = nil
DebugToolsGroup:AddToggle("ConsoleLoggerToggle", { Text = "Log Remote / Error Output", Default = false, Callback = function(Value) consoleLoggingActive = Value; if Value then consoleConnection = LogService.MessageOut:Connect(function(msg, msgType) if consoleLoggingActive then print("[NULL_DEBUG_LOG]: " .. msg) end end); Library:Notify("Console output logging enabled.", 3) else if consoleConnection then consoleConnection:Disconnect(); consoleConnection = nil end Library:Notify("Console output logging disabled.", 3) end end })

local SystemGroup = Tabs.Debug:AddRightGroupbox("System")
SystemGroup:AddButton({
    Text = "Unload GUI",
    Func = function()
        logToggleActive = false; stopAllCollection()
        for _, conn in pairs(connections) do if conn then conn:Disconnect() end end
        for _, guard in pairs(upgradeValueGuards) do if guard then guard:Disconnect() end end
        if consoleConnection then consoleConnection:Disconnect() end
        if persistentRespawnConnection then persistentRespawnConnection:Disconnect() end
        
        if protectionFolder then protectionFolder:Destroy() end
        table.clear(activeTripmineProtections); table.clear(activeBulletProtections)
        if velocityPart and velocityPart.Parent then velocityPart:Destroy() end

        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        if upgradesFolder then
            for name, _ in pairs(activeUpgrades) do
                local intv = upgradesFolder:FindFirstChild(name)
                if intv then intv:Destroy() end
                if events and events:FindFirstChild("UpgradesChanged") then 
                    pcall(function() 
                        if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, { [name] = 0 }) end 
                        if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({ [name] = 0 }) end 
                    end) 
                end
            end
        end
        table.clear(activeUpgrades)
        Library:Unload()
    end
})

local SettingsGroup = Tabs.Settings:AddLeftGroupbox("GUI Settings")
SettingsGroup:AddToggle("ExampleToggle", { Text = "TBA", Default = false, Callback = function(Value) end })
SettingsGroup:AddDropdown("ExampleDropdown", { Text = "Choose Mode", Values = {"Mode A", "Mode B", "Mode C"}, Default = 1, Callback = function(Value) end })
SettingsGroup:AddKeyPicker("ExampleKeybind", { Default = "K", Text = "Toggle Menu Keybind", Callback = function(Value) end })

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"ExampleKeybind"})
ThemeManager:SetFolder("NullGuiConfig")
SaveManager:SetFolder("NullGuiConfig/" .. tostring(PlaceId))
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
