-- =====================================================================
-- CLEANUP
-- =====================================================================
if _G.NullGui_Cleanup and type(_G.NullGui_Cleanup) == "function" then
    pcall(_G.NullGui_Cleanup)
end

local scriptConnections = {}
_G.NullGui_Cleanup = function()
    for _, conn in pairs(scriptConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(scriptConnections)
end

-- =====================================================================
-- SERVICES
-- =====================================================================
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

local gameName = "Unknown Game"
task.spawn(function()
    pcall(function()
        local productInfo = MarketplaceService:GetProductInfoAsync(PlaceId)
        if productInfo and productInfo.Name then
            gameName = productInfo.Name
        end
    end)
end)

local isSupportedPlace = true

local fSignal = firesignal or fire_signal or fireSignal
if not fSignal and getgenv then
    fSignal = getgenv().firesignal or getgenv().fire_signal or getgenv().fireSig
end

-- =====================================================================
-- IMMUNITY HOOK (unchanged)
-- =====================================================================
local guardianImmunity = false
local voidboundGuardianImmunity = false

task.spawn(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local eventsFolder = ReplicatedStorage:WaitForChild("Events", 5)
    local diedEvent = eventsFolder and eventsFolder:WaitForChild("Died", 5)

    if diedEvent and getrawmetatable and setreadonly then
        local wrapFn = (typeof(newcclosure) == "function" and newcclosure) or function(f) return f end
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall

        setreadonly(mt, false)

        mt.__namecall = wrapFn(function(self, ...)
            if self == diedEvent and getnamecallmethod() == "FireServer" then
                local cause = select(1, ...)
                if guardianImmunity and cause == "Guardian" then return end
                if voidboundGuardianImmunity and cause == "ShadowGuardian" then return end
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end
end)

-- =====================================================================
-- WHITELIST DATA
-- =====================================================================
local UpgradesList = {
    "BusinessLicense", "Paycheck", "Shield", "DoubleJump", "HighlightGifts", "Medal",
    "TriaOrbs", "BetterJumpPad", "SwiftnessRing", "GrapplePoints", "EnemyOnTop", "Helmet",
    "RadarAltars", "AdvancedGravityCoil", "IceSkates", "FannyPack", "PocketBell",
    "MoreAltars", "NinjaBelt", "LargerGrapplePoints", "SportShoes", "GiftMagnet",
    "SubspacialBarrier", "MatrixTetrahedron", "SharkTail", "PanicNecklace", "AltarOfVoid",
    "MiniatureHourglass", "GiftIdol", "Adrenaline", "TheOrb", "RealWings", "GraceWings",
    "RadarPlayer", "RadarInstruments", "HighlightTripmines"
}
local CursesList = {
    "Concussion", "LowerGravity", "MightyGong", "MoreRinging", "RandomSpawn",
    "OvertunedSpringer", "ScorchedEarth", "ProblemChild", "TweakedOdds", "Springloaded",
    "FasterLevelDestroy", "Telestabber", "SavoryRing", "Lap2", "ICBMBig",
    "TelefraggerPredict", "HighRoller", "FakeCount", "ScatteredGifts", "WeakJumpPads",
    "BladeCarousel", "OneLessChoice", "FragileTiles", "Tantrum", "MedalCurses"
}
local EnemiesList = {
    "ICBM", "Bell", "Baby", "Springer", "Mart", "Skinwalker", "Flesh",
    "Operator", "Telefragger", "Guardian", "Kolona", "Voidbreaker", "Cadence", "ShadowBaby"
}

-- =====================================================================
-- GAME REFERENCES
-- =====================================================================
local events = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events", 2)
local Camera = workspace.CurrentCamera
local enemies = workspace:FindFirstChild("Enemies")
local selection = workspace:FindFirstChild("Select")
local collectGift = events and events:FindFirstChild("GiftCollected")
local currentRooms = workspace:FindFirstChild("CurrentRooms")
local pads = workspace:FindFirstChild("JumpPads")
local code = ReplicatedStorage:FindFirstChild("CodeVal")
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

-- =====================================================================
-- VISUALIZERS / PROTECTION SPHERES
-- =====================================================================
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

-- =====================================================================
-- SETTINGS & STATE
-- =====================================================================
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
    AutoPylon = false,
    TargetLevel = nil,
    EnemiesWhitelist = {},
    CursesWhitelist = {},
    UpgradesWhitelist = {}
}

local currentObservedLevel = nil
local targetVoidProcessing = false

-- =====================================================================
-- DISCORD WEBHOOK SYSTEM (NEW)
-- =====================================================================
local Webhook = {
    URL = "",
    LevelEnabled = false,
    DeathEnabled = false,
    LastSentLevel = nil,
    LastLevelSendTime = 0,
    LastDeathSendTime = 0,
}

-- Multi-executor HTTP POST (request / syn.request / http.request / http_request)
local function httpPost(url, body)
    local headers = {["Content-Type"] = "application/json"}
    local requestFn
    pcall(function() requestFn = request end)
    if not requestFn then pcall(function() requestFn = syn.request end) end
    if not requestFn then pcall(function() requestFn = http and http.request end) end
    if not requestFn then pcall(function() requestFn = http_request end) end
    if not requestFn then return false, "No HTTP request function available in this executor" end

    local ok, res = pcall(function()
        return requestFn({Url = url, Method = "POST", Headers = headers, Body = body})
    end)
    if ok then return true, res end
    return false, tostring(res)
end

local function getActiveEnemiesList()
    local list = {}
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local isDisabled = false
            if hum and hum.PlatformStand then isDisabled = true end
            local scr = enemy:FindFirstChildOfClass("Script")
            if scr and scr.Disabled then isDisabled = true end
            table.insert(list, isDisabled and (enemy.Name .. " [Disabled]") or enemy.Name)
        end
    end
    if Camera then
        for _, child in ipairs(Camera:GetChildren()) do
            local ln = string.lower(child.Name)
            if ln == "nilenemy" or ln == "nilmirage" then
                table.insert(list, child.Name .. " [Client]")
            end
        end
    end
    return list
end

local function getActiveUpgradesList()
    local list = {}
    for name, val in pairs(activeUpgrades) do
        if val and val > 0 then
            table.insert(list, string.format("%s (%d)", name, val))
        end
    end
    return list
end

local function buildWebhookFields()
    local enemyList = getActiveEnemiesList()
    local upgradeList = getActiveUpgradesList()
    local enemiesText = #enemyList > 0 and table.concat(enemyList, "\n") or "None"
    local upgradesText = #upgradeList > 0 and table.concat(upgradeList, "\n") or "None"
    if #enemiesText > 1000 then enemiesText = enemiesText:sub(1, 980) .. "\n... (truncated)" end
    if #upgradesText > 1000 then upgradesText = upgradesText:sub(1, 980) .. "\n... (truncated)" end
    return {
        {name = "Current Level", value = tostring(currentObservedLevel or "N/A"), inline = true},
        {name = "Active Enemies (" .. tostring(#enemyList) .. ")", value = enemiesText, inline = false},
        {name = "Active Upgrades (" .. tostring(#upgradeList) .. ")", value = upgradesText, inline = false},
    }
end

local function isValidWebhookURL()
    if not Webhook.URL or Webhook.URL == "" then
        return false, "No webhook URL configured"
    end
    local url = string.lower(Webhook.URL)
    if not (url:find("discord%.com") or url:find("discordapp%.com")) then
        return false, "URL does not appear to be a Discord webhook"
    end
    if not url:find("webhooks") then
        return false, "URL is missing the webhook path"
    end
    return true
end

local function dispatchWebhook(payload)
    local ok, err = isValidWebhookURL()
    if not ok then return false, err end
    local encOk, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if not encOk then return false, "Failed to encode payload" end
    return httpPost(Webhook.URL, encoded)
end

local function dispatchLevelWebhook(level)
    local embed = {
        title = "📈 New Level Reached",
        description = string.format("Player has advanced to **Level %d**.", level),
        color = 0x00FF88,
        fields = buildWebhookFields(),
        timestamp = DateTime.now():ToIsoDate(),
        footer = {text = "Java's Null GUI | Level Tracker"},
    }
    return dispatchWebhook({ username = "Null GUI", embeds = {embed} })
end

local function dispatchDeathWebhook()
    local embed = {
        title = "💀 Player Died",
        description = "The local player has died.",
        color = 0xFF4444,
        fields = buildWebhookFields(),
        timestamp = DateTime.now():ToIsoDate(),
        footer = {text = "Java's Null GUI | Death Notifier"},
    }
    return dispatchWebhook({ username = "Null GUI", embeds = {embed} })
end
-- END WEBHOOK SYSTEM

-- =====================================================================
-- MISC STATE
-- =====================================================================
local tweening = false
local currentTween = nil
local activePath = nil
local availableNormalGifts = {}
local availableGoldenGifts = {}
local collectionRunId = 0
local notifOn = true
local destroying = false

local disableAllEnemies = false
local deleteAllEnemies = false
local disableClientEnemies = false
local autoDestroySpawns = false

local nrb = false
local antiFleshTilesEnabled = false
local persistentTileConnections = false
local persistentRespawnConnection = nil

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
local selectionState = { failedParts = {}, rerollCount = 0 }

local updateActiveUpgradesDisplay = function() end
local applyUpgradeValue = function() end
local upgradeLabels = {}
local collectGiftsEngine = function() end

-- =====================================================================
-- HELPERS
-- =====================================================================
local function getToggle(name)
    return (Toggles and Toggles[name]) or (Options and Options[name])
end
local function getChar(player) return player and player.Character end
local function getRoot(character) return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart) end

-- =====================================================================
-- RAZORBLOOM
-- =====================================================================
local function destroyRazorbloom()
    if not nrb then return end
    local char = getChar(plr)
    if not char then return end
    local rb = char:FindFirstChild("Razorbloom")
    if rb then
        rb:Destroy()
        if notifOn then notif("Destroyed Razorbloom from character.", "Razorbloom System") end
    end
end

-- =====================================================================
-- PYLONS
-- =====================================================================
local function findPylons()
    local found = {}
    local searchContainers = {
        workspace:FindFirstChild("Pylons"), workspace:FindFirstChild("PylonFolder"),
        workspace:FindFirstChild("Item_Pools"), workspace
    }
    for _, container in ipairs(searchContainers) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj.Name:lower():find("pylon") then table.insert(found, obj) end
            end
        end
    end
    return found
end

local function interactWithPylon(pylon)
    if not pylon or not pylon.Parent then return end
    local part = pylon:IsA("BasePart") and pylon or pylon:FindFirstChildWhichIsA("BasePart") or pylon.PrimaryPart
    if not part then return end
    local char = getChar(plr); local root = getRoot(char)
    if root then root.CFrame = part.CFrame + Vector3.new(0, 3, 0) end
    task.wait(0.1)
    local prompt = pylon:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        pcall(function()
            if fireproximityprompt then fireproximityprompt(prompt)
            else prompt:InputHoldBegin(); task.wait(prompt.HoldDuration); prompt:InputHoldEnd() end
        end)
    else
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game); task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end

local function teleportToNearestPylon()
    local pylons = findPylons()
    if #pylons == 0 then
        if Library and Library.Notify then Library:Notify("No Pylons found in workspace.", 3) end
        return false
    end
    local char = getChar(plr); local root = getRoot(char)
    if not root then return false end
    local closest, shortestDist = nil, math.huge
    for _, pylon in ipairs(pylons) do
        local part = pylon:IsA("BasePart") and pylon or pylon:FindFirstChildWhichIsA("BasePart") or pylon.PrimaryPart
        if part then
            local dist = (part.Position - root.Position).Magnitude
            if dist < shortestDist then shortestDist = dist; closest = pylon end
        end
    end
    if closest then
        interactWithPylon(closest)
        if Library and Library.Notify then Library:Notify("Teleporting to Pylons: " .. closest.Name, 3) end
        return true
    end
    return false
end

local isProcessingPylons = false
local function processAutoPylon()
    if not Settings.AutoPylon or isProcessingPylons then return end
    local pylons = findPylons()
    if #pylons > 0 then
        isProcessingPylons = true
        task.spawn(function()
            for _, pylon in ipairs(pylons) do
                if not Settings.AutoPylon then break end
                if pylon and pylon.Parent then interactWithPylon(pylon); task.wait(0.5) end
            end
            isProcessingPylons = false
        end)
    end
end

connections["PylonAddedListener"] = workspace.ChildAdded:Connect(function(child)
    if Settings.AutoPylon and child.Name:lower():find("pylon") then
        task.wait(0.1); interactWithPylon(child)
    end
end)
table.insert(scriptConnections, connections["PylonAddedListener"])

-- =====================================================================
-- LEVEL TRACKER (webhook hooked in)
-- =====================================================================
connections["LevelLogListener"] = LogService.MessageOut:Connect(function(msg, msgType)
    local lvlStr = string.match(msg, "Level%s*(%d+)")
    if lvlStr then
        local lvl = tonumber(lvlStr)
        if lvl then
            local previousLevel = currentObservedLevel
            currentObservedLevel = lvl
            if previousLevel and lvl ~= previousLevel then
                Webhook.LastSentLevel = lvl
                if Webhook.LevelEnabled and (os.clock() - Webhook.LastLevelSendTime >= 1) then
                    Webhook.LastLevelSendTime = os.clock()
                    task.spawn(function() dispatchLevelWebhook(lvl) end)
                end
            end
        end
    end
end)
table.insert(scriptConnections, connections["LevelLogListener"])

-- =====================================================================
-- VOID KILL
-- =====================================================================
local function executeVoidKill()
    local killVoid = workspace:FindFirstChild("KillVoid")
    local char = getChar(plr)
    local root = getRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if killVoid and root and hum and hum.Health > 0 then
        local targetPosition = killVoid.Position + Vector3.new(0, 20, 0)
        root.CFrame = CFrame.new(targetPosition)
    end
end

-- =====================================================================
-- NEW LEVEL SOUND -> VOID TARGET
-- =====================================================================
task.spawn(function()
    local sfxFolder = SoundService:WaitForChild("SFXFolder", 3) or SoundService:FindFirstChild("SFXFolder")
    local newLevelSound = sfxFolder and (sfxFolder:WaitForChild("NewLevel", 2) or sfxFolder:FindFirstChild("NewLevel"))
    if newLevelSound and newLevelSound:IsA("Sound") then
        connections["NewLevelVoidSoundConn"] = newLevelSound.Played:Connect(function()
            if not Settings.TargetLevel or type(Settings.TargetLevel) ~= "number" or Settings.TargetLevel <= 0 or targetVoidProcessing then return end
            if currentObservedLevel and currentObservedLevel >= Settings.TargetLevel then
                targetVoidProcessing = true
                Settings.TargetLevel = nil
                local autoVoidInput = Options and Options.TargetLevelVoidInput
                if autoVoidInput then autoVoidInput:SetValue("") end
                local wasCollectingNormal = Settings.CollectNormal
                local wasCollectingGolden = Settings.CollectGolden
                tweening = false
                if currentTween then currentTween:Cancel(); currentTween = nil end
                local respawnConnection
                respawnConnection = plr.CharacterAdded:Connect(function(newChar)
                    respawnConnection:Disconnect()
                    task.wait(1.5)
                    if Settings.AutoStartCollecting or wasCollectingNormal then
                        Settings.CollectNormal = true
                        local normalTgl = getToggle("CollectNormalToggle")
                        if normalTgl then normalTgl:SetValue(true) end
                        task.defer(function() collectGiftsEngine(false) end)
                    elseif wasCollectingGolden then
                        Settings.CollectGolden = true
                        local goldenTgl = getToggle("CollectGoldenToggle")
                        if goldenTgl then goldenTgl:SetValue(true) end
                        task.defer(function() collectGiftsEngine(true) end)
                    end
                end)
                table.insert(scriptConnections, respawnConnection)
                task.spawn(function()
                    executeVoidKill()
                    task.wait(30)
                    targetVoidProcessing = false
                end)
            end
        end)
        table.insert(scriptConnections, connections["NewLevelVoidSoundConn"])
    end
end)

-- =====================================================================
-- PLAYER EVENTS (death hook for webhook)
-- =====================================================================
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
                        for _, conn in ipairs(getconnections(continueBtn.MouseButton1Click)) do conn:Fire() end
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
    -- Death webhook
    if Webhook.DeathEnabled and (os.clock() - Webhook.LastDeathSendTime >= 1) then
        Webhook.LastDeathSendTime = os.clock()
        task.spawn(function() dispatchDeathWebhook() end)
    end
    if Settings.AutoFarmBeta then handleEndScreenReset() end
end

local function setupCharacter(char)
    respawnCounter += 1
    local hum = char:WaitForChild("Humanoid", 3)
    if hum then
        local conn = hum.Died:Connect(function() handlePlayerDeath() end)
        table.insert(scriptConnections, conn)
    end
    if nrb then task.wait(0.5); destroyRazorbloom() end
end

local charConn = plr.CharacterAdded:Connect(setupCharacter)
table.insert(scriptConnections, charConn)
if plr.Character then setupCharacter(plr.Character) end

-- =====================================================================
-- AUTO FARM ENGINE
-- =====================================================================
local function isValueWhitelisted(value, whitelistTable)
    if not value or not whitelistTable then return false end
    local searchVal = tostring(value):lower()
    for itemKey, isSelected in pairs(whitelistTable) do
        local keyStr = type(itemKey) == "number" and tostring(isSelected) or tostring(itemKey)
        local enabled = type(itemKey) == "number" and true or isSelected
        if enabled and keyStr:lower() == searchVal then return true end
    end
    return false
end

local function hasAnyActiveWhitelist()
    local tables = {Settings.EnemiesWhitelist, Settings.CursesWhitelist, Settings.UpgradesWhitelist}
    for _, tbl in ipairs(tables) do
        if tbl then for _, isSelected in pairs(tbl) do if isSelected then return true end end end
    end
    return false
end

local function interactWithPart(part)
    if not part or not part:IsA("BasePart") then return end
    local char = plr.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if root then root.CFrame = part.CFrame + Vector3.new(0, 3, 0); task.wait(0.05) end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game); task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    local closestPrompt = nil
    local shortestDist = 10
    local searchScope = part.Parent or workspace
    for _, prompt in ipairs(searchScope:GetChildren()) do
        if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
            local dist = (prompt.Parent.Position - part.Position).Magnitude
            if dist < shortestDist then shortestDist = dist; closestPrompt = prompt end
        end
    end
    if closestPrompt then
        pcall(function()
            if fireproximityprompt then fireproximityprompt(closestPrompt)
            else closestPrompt:InputHoldBegin(); task.wait(closestPrompt.HoldDuration); closestPrompt:InputHoldEnd() end
        end)
    end
    local voteEvent = events and (events:FindFirstChild("Vote") or events:FindFirstChild("SelectVote"))
    if voteEvent and voteEvent:IsA("RemoteEvent") then
        pcall(function() voteEvent:FireServer(part.Name) end)
    end
end

local function checkPartMatch(part)
    if not part then return false end
    local choiceType = part:GetAttribute("ChoiceType")
    local choiceName = part:GetAttribute("ChoiceName")
    if choiceType and choiceName then
        local upperType = tostring(choiceType):upper()
        if upperType:find("ENEM") then return isValueWhitelisted(choiceName, Settings.EnemiesWhitelist)
        elseif upperType:find("UPGRADE") then return isValueWhitelisted(choiceName, Settings.UpgradesWhitelist)
        elseif upperType:find("CURSE") then return isValueWhitelisted(choiceName, Settings.CursesWhitelist) end
    end
    return false
end

local function checkAndVoteSelectParts()
    if not Settings.AutoFarmBeta or isAutoFarmProcessing then return end
    local selectFolder = workspace:FindFirstChild("Select")
    if not selectFolder or not (selectFolder:FindFirstChild("1") or selectFolder:FindFirstChild("2") or selectFolder:FindFirstChild("3")) then
        table.clear(selectionState.failedParts); selectionState.rerollCount = 0
        return
    end
    isAutoFarmProcessing = true
    task.spawn(function()
        pcall(function()
            local maxRerolls = 5
            local maxIterations = 25
            local iteration = 0
            local function getBoardState()
                local s = workspace:FindFirstChild("Select")
                if not s then return "" end
                local p1 = s:FindFirstChild("1"); local p2 = s:FindFirstChild("2")
                return (p1 and tostring(p1:GetAttribute("ChoiceName")) or "") .. "|" .. (p2 and tostring(p2:GetAttribute("ChoiceName")) or "")
            end
            local function attemptBuy(partName)
                local attempts = 0
                local initialState = getBoardState()
                while attempts < 4 and Settings.AutoFarmBeta do
                    local sFolder = workspace:FindFirstChild("Select")
                    if not sFolder then return true end
                    local p = sFolder:FindFirstChild(partName)
                    if not p then return true end
                    interactWithPart(p); attempts = attempts + 1
                    if attempts < 4 then task.wait(1.5) end
                    local newState = getBoardState()
                    if partName == "Reroll" then
                        if newState ~= initialState then return true end
                    else
                        if not sFolder:FindFirstChild(partName) or newState ~= initialState then return true end
                    end
                end
                selectionState.failedParts[partName] = true
                return false
            end
            while Settings.AutoFarmBeta and iteration < maxIterations do
                iteration = iteration + 1
                selectFolder = workspace:FindFirstChild("Select")
                if not selectFolder then break end
                local rerollPart = selectFolder:FindFirstChild("Reroll")
                local part3 = selectFolder:FindFirstChild("3")
                local targetPartName = nil
                local anyWhitelistActive = hasAnyActiveWhitelist()
                local isCurseOrEnemySelection = false
                local activeSpecificWhitelist = false
                for _, name in ipairs({"1", "2"}) do
                    local part = selectFolder:FindFirstChild(name)
                    if part then
                        local choiceType = tostring(part:GetAttribute("ChoiceType") or "")
                        if choiceType:upper():find("CURSE") then
                            isCurseOrEnemySelection = true
                            activeSpecificWhitelist = (Settings.CursesWhitelist and next(Settings.CursesWhitelist) ~= nil)
                            break
                        elseif choiceType:upper():find("ENEM") then
                            isCurseOrEnemySelection = true
                            activeSpecificWhitelist = (Settings.EnemiesWhitelist and next(Settings.EnemiesWhitelist) ~= nil)
                            break
                        end
                    end
                end
                for _, name in ipairs({"1", "2"}) do
                    if not selectionState.failedParts[name] then
                        local part = selectFolder:FindFirstChild(name)
                        if part then
                            local choiceName = tostring(part:GetAttribute("ChoiceName") or "")
                            if choiceName:lower():find("medalcurse") or choiceName:lower():find("medalcurses") then
                                targetPartName = name; break
                            end
                        end
                    end
                end
                if not targetPartName then
                    for _, name in ipairs({"1", "2"}) do
                        if not selectionState.failedParts[name] then
                            local part = selectFolder:FindFirstChild(name)
                            if part and checkPartMatch(part) then targetPartName = name; break end
                        end
                    end
                end
                if not targetPartName and not anyWhitelistActive then
                    local validParts = {}
                    for _, name in ipairs({"1", "2"}) do
                        if not selectionState.failedParts[name] and selectFolder:FindFirstChild(name) then
                            table.insert(validParts, name)
                        end
                    end
                    if #validParts > 0 then targetPartName = validParts[math.random(1, #validParts)] end
                end
                if targetPartName then
                    local success = attemptBuy(targetPartName)
                    if success then continue end
                else
                    if rerollPart and selectionState.rerollCount < maxRerolls and anyWhitelistActive and not selectionState.failedParts["Reroll"] then
                        if not isCurseOrEnemySelection then
                            local success = attemptBuy("Reroll")
                            if success then
                                selectionState.rerollCount = selectionState.rerollCount + 1
                                selectionState.failedParts["1"] = nil
                                selectionState.failedParts["2"] = nil
                                continue
                            end
                        end
                    end
                    if isCurseOrEnemySelection then
                        if part3 and not selectionState.failedParts["3"] then
                            targetPartName = "3"
                            local success = attemptBuy("3")
                            if success then continue end
                        elseif not activeSpecificWhitelist then
                            local validParts = {}
                            for _, name in ipairs({"1", "2"}) do
                                if not selectionState.failedParts[name] and selectFolder:FindFirstChild(name) then
                                    table.insert(validParts, name)
                                end
                            end
                            if #validParts > 0 then
                                targetPartName = validParts[math.random(1, #validParts)]
                                local success = attemptBuy(targetPartName)
                                if success then continue end
                            end
                        else
                            local validParts = {}
                            for _, name in ipairs({"1", "2"}) do
                                if not selectionState.failedParts[name] and selectFolder:FindFirstChild(name) then
                                    table.insert(validParts, name)
                                end
                            end
                            if #validParts > 0 then
                                targetPartName = validParts[math.random(1, #validParts)]
                                local success = attemptBuy(targetPartName)
                                if success then continue end
                            end
                        end
                    end
                    if part3 and not selectionState.failedParts["3"] then attemptBuy("3") end
                    break
                end
            end
            beaconFiredTime = os.clock()
            local startRespawns = respawnCounter
            while isAutoFarmProcessing do
                if (respawnCounter - startRespawns) >= 2 then break end
                if beaconFiredTime and (os.clock() - beaconFiredTime) >= 5 then break end
                task.wait(0.1)
            end
        end)
        isAutoFarmProcessing = false
    end)
end

-- =====================================================================
-- DEBUG ATTRIBUTE LOGGER
-- =====================================================================
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

-- =====================================================================
-- PROTECTIONS / TILES
-- =====================================================================
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
    local conn = trip.Destroying:Connect(function()
        if activeTripmineProtections[trip] then
            if activeTripmineProtections[trip].sphere then activeTripmineProtections[trip].sphere:Destroy() end
            activeTripmineProtections[trip] = nil
        end
    end)
    table.insert(scriptConnections, conn)
end

local function protectBullet(b)
    if activeBulletProtections[b] or (b:IsA("BasePart") and b.Transparency == 1) then return end
    local size = b:IsA("BasePart") and b.Size.X or 4
    local radius = (size + 6) / 2
    local sphere = createProtectionSphere(b, radius, Color3.fromRGB(255, 50, 50))
    activeBulletProtections[b] = { sphere = sphere, radius = radius }
    local conn = b.Destroying:Connect(function()
        if activeBulletProtections[b] then
            if activeBulletProtections[b].sphere then activeBulletProtections[b].sphere:Destroy() end
            activeBulletProtections[b] = nil
        end
    end)
    table.insert(scriptConnections, conn)
end

local lastProtectionScan = 0
local function processProtections()
    local now = os.clock()
    if now - lastProtectionScan > 0.5 then
        lastProtectionScan = now
        if pt then
            if tripmines then for _, mine in ipairs(tripmines:GetChildren()) do protectTripmine(mine) end end
            if goldentripmines then for _, mine in ipairs(goldentripmines:GetChildren()) do protectTripmine(mine) end end
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

-- =====================================================================
-- GIFT COLLECTION ENGINE
-- =====================================================================
local Library
local function notif(msg, title)
    if Library and Library.Notify then
        Library:Notify(string.format("[%s]: %s", title or "System", msg), 3)
    end
end

local giftCache, giftCacheBuilt, lastFullScan = {}, false, 0
local FULL_SCAN_INTERVAL = 1.2
local GIFT_Y_MIN, GIFT_Y_MAX, GIFT_DIST_MAX = -2000, 5000, 60000
local collectedGifts = {}
local COLLECTED_TIMEOUT = 8

local function classifyGift(obj)
    if not obj or not obj.Parent then return nil end
    local nameLower = obj.Name:lower()
    if not (nameLower:find("gift") or nameLower:find("present")) then return nil end
    local part = obj:IsA("BasePart") and obj
              or obj:FindFirstChildWhichIsA("BasePart", true)
              or (obj.IsA and obj:IsA("Model") and obj.PrimaryPart)
    if not part then return nil end
    local isGolden = (nameLower:find("golden") ~= nil) or (nameLower:find("gold") ~= nil)
    return { obj = obj, part = part, isGolden = isGolden }
end

local function rebuildGiftCache()
    local newCache = {}
    local roots = {workspace:FindFirstChild("Item_Pools"), workspace:FindFirstChild("CurrentRooms"), workspace:FindFirstChild("Gifts"), workspace:FindFirstChild("SpawnedGifts")}
    local function scan(container)
        if not container then return end
        for _, child in ipairs(container:GetDescendants()) do
            local info = classifyGift(child)
            if info then newCache[#newCache + 1] = info end
        end
    end
    for _, root in ipairs(roots) do scan(root) end
    for _, child in ipairs(workspace:GetChildren()) do
        local info = classifyGift(child)
        if info then newCache[#newCache + 1] = info end
    end
    giftCache, giftCacheBuilt, lastFullScan = newCache, true, os.clock()
end

local function pruneCache()
    local pruned, present = {}, {}
    for _, info in ipairs(giftCache) do
        if info.obj and info.obj.Parent and info.part and info.part.Parent then
            pruned[#pruned + 1] = info; present[info.obj] = true
        end
    end
    giftCache = pruned
    local now = os.clock()
    for gift, ts in pairs(collectedGifts) do
        if not present[gift] or (now - ts) > COLLECTED_TIMEOUT then collectedGifts[gift] = nil end
    end
end

local function refreshGiftCache(forceFull)
    if forceFull or not giftCacheBuilt or (os.clock() - lastFullScan) >= FULL_SCAN_INTERVAL then
        rebuildGiftCache()
    end
    pruneCache()
end

local function isValidGiftPos(pos)
    if pos == Vector3.new(0,0,0) then return false end
    if pos.Y < GIFT_Y_MIN or pos.Y > GIFT_Y_MAX then return false end
    if pos.Magnitude > GIFT_DIST_MAX then return false end
    return true
end

local function getClosestGift(targetGolden, blacklist)
    local char = getChar(plr); local root = getRoot(char)
    if not root then return nil end
    local rootPos = root.Position
    local closest, closestInfo, shortest = nil, nil, math.huge
    for _, info in ipairs(giftCache) do
        if info.obj and info.obj.Parent and info.part and info.part.Parent then
            if info.isGolden == targetGolden and not blacklist[info.obj] and not collectedGifts[info.obj] then
                local pos = info.part.Position
                if isValidGiftPos(pos) then
                    local dist = (pos - rootPos).Magnitude
                    if dist < shortest then shortest = dist; closest = info.obj; closestInfo = info end
                end
            end
        end
    end
    return closest, closestInfo
end

local function walkToPositionPathfinding(targetPos)
    local char = getChar(plr); local root = getRoot(char)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or not targetPos or targetPos == Vector3.new(0,0,0) then return false end
    humanoid.WalkSpeed = Settings.LegitSpeed
    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentJumpHeight = 10, AgentMaxSlope = 45})
    local success = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for _, waypoint in ipairs(waypoints) do
            if not tweening and not Settings.AutoBeacon then humanoid:MoveTo(root.Position); return false end
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            local moveCompleted = false
            local conn = humanoid.MoveToFinished:Connect(function() moveCompleted = true end)
            local timeout = 0
            while not moveCompleted and (tweening or Settings.AutoBeacon) do
                task.wait(0.05); timeout += 0.05
                if timeout > 3 then break end
            end
            conn:Disconnect()
            if not moveCompleted then break end
        end
        return true
    else
        humanoid:MoveTo(targetPos); task.wait(0.5); return false
    end
end

local function moveToGift(info)
    if not info or not info.part or not info.part.Parent then return nil end
    if Settings.LegitCollection then walkToPositionPathfinding(info.part.Position); return nil end
    local char = getChar(plr); local root = getRoot(char)
    if not root then return nil end
    local targetCFrame = info.part.CFrame + Vector3.new(0, 3, 0)
    if Settings.InstantTeleport then
        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        return nil
    end
    local distance = (info.part.Position - root.Position).Magnitude
    local duration = math.max(0.01, distance / Settings.TweenSpeed)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

local function handleSpawnNavigation()
    for _, sName in ipairs({"Spawn", "SpawnLocation"}) do
        local targetSpawn = workspace:FindFirstChild(sName)
        if targetSpawn and targetSpawn:IsA("BasePart") and targetSpawn.Position ~= Vector3.new(0,0,0) then
            local char = getChar(plr); local root = getRoot(char)
            if root then
                if Settings.LegitCollection then walkToPositionPathfinding(targetSpawn.Position)
                else
                    root.CFrame = targetSpawn.CFrame + Vector3.new(0, 5, 0)
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
                return true
            end
        end
    end
    return false
end

local function stopAllCollection()
    collectionRunId += 1
    tweening = false
    Settings.CollectNormal = false
    Settings.CollectGolden = false
    Settings.LegitCollection = false
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    local normalToggle = getToggle("CollectNormalToggle")
    if normalToggle then normalToggle:SetValue(false) end
    local goldenToggle = getToggle("CollectGoldenToggle")
    if goldenToggle then goldenToggle:SetValue(false) end
    local legitToggle = getToggle("LegitCollectionToggle")
    if legitToggle then legitToggle:SetValue(false) end
end

if collectGift then
    pcall(function()
        if collectGift:IsA("RemoteEvent") then
            local conn = collectGift.OnClientEvent:Connect(function(...)
                local args = {...}
                for _, arg in ipairs(args) do
                    if typeof(arg) == "Instance" then collectedGifts[arg] = os.clock(); blacklistedGifts[arg] = true end
                end
            end)
            table.insert(scriptConnections, conn)
        elseif collectGift:IsA("BindableEvent") then
            local conn = collectGift.Event:Connect(function(...)
                local args = {...}
                for _, arg in ipairs(args) do
                    if typeof(arg) == "Instance" then collectedGifts[arg] = os.clock(); blacklistedGifts[arg] = true end
                end
            end)
            table.insert(scriptConnections, conn)
        end
    end)
end

local function startCollectionEngine(mode)
    collectionRunId += 1
    local myRunId = collectionRunId
    tweening = true
    table.clear(blacklistedGifts)
    task.spawn(function()
        local recentAttempts = {}
        local ATTEMPT_COOLDOWN = 0.5
        local emptyStreak = 0
        local MAX_EMPTY_STREAK = 4
        local currentTarget = mode == "golden" and "golden" or "normal"
        local fallbackNotified = false
        local noGiftsNotified = false
        refreshGiftCache(true)
        local function currentRunIsStale() return myRunId ~= collectionRunId end
        local function targetAvailable(isGolden)
            for _, info in ipairs(giftCache) do
                if info.isGolden == isGolden and info.obj and info.obj.Parent and info.part and info.part.Parent then
                    if isValidGiftPos(info.part.Position) and not collectedGifts[info.obj] then return true end
                end
            end
            return false
        end
        local function doFallbackToGolden()
            if fallbackNotified then return end
            fallbackNotified = true
            if notifOn then notif("No normal gifts left. Falling back to Golden Gifts.", "Collection System") end
        end
        local function doGiveUp(reasonGolden)
            if noGiftsNotified then return end
            noGiftsNotified = true
            if reasonGolden then
                if notifOn then notif("No Golden Gifts remaining. Disabling gift collection.", "Collection System") end
            else
                if notifOn then notif("No gifts available. Disabling gift collection.", "Collection System") end
            end
            if Settings.AutoBeacon then handleSpawnNavigation() end
            stopAllCollection()
        end
        while tweening and not currentRunIsStale() do
            local wantNormal = Settings.CollectNormal
            local wantGolden = Settings.CollectGolden
            if not wantNormal and not wantGolden then break end
            if mode == "golden" then currentTarget = "golden"
            elseif mode == "normal" then currentTarget = "normal"
            else
                if not wantNormal then currentTarget = "golden"
                elseif not wantGolden then currentTarget = "normal"
                else
                    if currentTarget == "normal" and not targetAvailable(false) then
                        doFallbackToGolden()
                        currentTarget = "golden"
                    end
                end
            end
            local isGoldenTarget = (currentTarget == "golden")
            if not targetAvailable(isGoldenTarget) then
                local otherGolden = not isGoldenTarget
                if targetAvailable(otherGolden) then
                    if mode == "auto" then
                        if currentTarget == "normal" then doFallbackToGolden() end
                        currentTarget = otherGolden and "golden" or "normal"
                        isGoldenTarget = otherGolden
                    end
                else
                    emptyStreak += 1
                    if emptyStreak >= MAX_EMPTY_STREAK then doGiveUp(isGoldenTarget); return end
                    task.wait(0.15); continue
                end
            end
            local char = getChar(plr); local root = getRoot(char)
            if not root then task.wait(0.2); continue end
            if not Settings.LegitCollection then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
            refreshGiftCache(false)
            if currentRunIsStale() then break end
            local now = os.clock()
            for obj, t in pairs(recentAttempts) do
                if now - t > ATTEMPT_COOLDOWN then recentAttempts[obj] = nil end
            end
            local gift, giftInfo = getClosestGift(isGoldenTarget, recentAttempts)
            if not gift then
                emptyStreak += 1
                if emptyStreak >= MAX_EMPTY_STREAK then
                    if mode == "auto" then
                        local otherGolden = not isGoldenTarget
                        if targetAvailable(otherGolden) then
                            if currentTarget == "normal" then doFallbackToGolden() end
                            currentTarget = otherGolden and "golden" or "normal"
                            emptyStreak = 0
                        else doGiveUp(isGoldenTarget); return end
                    else doGiveUp(isGoldenTarget); return end
                end
                task.wait(0.12); continue
            end
            emptyStreak = 0
            recentAttempts[gift] = os.clock()
            currentTween = moveToGift(giftInfo)
            if currentTween then
                local tweenDone = false
                local tweenConn
                tweenConn = currentTween.Completed:Connect(function() tweenDone = true end)
                local timeout = 0
                while not tweenDone and tweening and not currentRunIsStale() do
                    task.wait(0.02); timeout += 0.02
                    if timeout > 3 then break end
                end
                if tweenConn then tweenConn:Disconnect() end
                currentTween = nil
            else task.wait(0.03) end
            if currentRunIsStale() then break end
            if gift and gift.Parent then collectedGifts[gift] = os.clock() end
            if gift then recentAttempts[gift] = os.clock() end
            if Settings.DelayBetweenGifts and Settings.DelayBetweenGifts > 0 then task.wait(Settings.DelayBetweenGifts) end
        end
        if not currentRunIsStale() then stopAllCollection() end
    end)
end

collectGiftsEngine = function(isGoldenTarget)
    if isGoldenTarget then startCollectionEngine("golden") else startCollectionEngine("auto") end
end

-- =====================================================================
-- ENEMY UTILITIES
-- =====================================================================
local function disableEnemyEntity(entity)
    if not entity or not (entity:IsA("Model") or entity:IsA("Folder") or entity:IsA("BasePart")) then return end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid.WalkSpeed = 0
        humanoid.PlatformStand = true
    end
    for _, obj in ipairs(entity:GetChildren()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") then obj.Disabled = true
        elseif obj:IsA("BasePart") then obj.CanCollide = false; obj.Anchored = true end
    end
end

local function disableEnemy(name, destroy, breakAI, disableAI)
    local target = enemies and enemies:FindFirstChild(name)
    if not target then return false end
    if destroy then target:Destroy(); return true
    elseif breakAI or disableAI then disableEnemyEntity(target); return true end
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
            pcall(function() instance:Destroy() end); return
        end
        if disableVoidImplosions and (nameLower:find("voidimplosion") or nameLower:find("implosion") or nameLower:find("void_implosion")) then
            pcall(function() instance:Destroy() end); return
        end
        if disableFakeBeacons and (nameLower:find("fakebeacon") or nameLower:find("fake_beacon") or (nameLower:find("beacon") and nameLower:find("fake"))) then
            pcall(function() instance:Destroy() end); return
        end
        if disableOblivion and (nameLower:find("oblivion") or nameLower:find("oblivionentity")) then
            pcall(function() instance:Destroy() end); return
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
            if enemy.Name ~= "Guardian" then enemy:Destroy(); count += 1 end
        end
    end
    return count
end

-- =====================================================================
-- ANTI VOID
-- =====================================================================
local function processAntiVoid()
    if not av then return end
    local char = getChar(plr); local root = getRoot(char)
    local killVoid = workspace:FindFirstChild("KillVoid")
    local voidYThreshold = killVoid and (killVoid.Position.Y + 5) or -100
    if root and root.Position.Y <= voidYThreshold then
        if antiVoidSelection == 1 then handleSpawnNavigation()
        elseif antiVoidSelection == 2 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, lp, root.AssemblyLinearVelocity.Z)
        elseif antiVoidSelection == 3 then
            refreshGiftCache(true)
            local giftInfo = nil; local rootPos = root.Position; local shortest = math.huge
            for _, info in ipairs(giftCache) do
                if info.obj and info.obj.Parent and info.part and info.part.Parent and isValidGiftPos(info.part.Position) then
                    local dist = (info.part.Position - rootPos).Magnitude
                    if dist < shortest then shortest = dist; giftInfo = info end
                end
            end
            if giftInfo then root.CFrame = giftInfo.part.CFrame + Vector3.new(0, 5, 0)
            else handleSpawnNavigation() end
        end
    end
end

-- =====================================================================
-- MAIN LOOP
-- =====================================================================
connections["MainHeartbeat"] = RunService.Heartbeat:Connect(function()
    processProtections()
    processAntiVoid()
    checkAndVoteSelectParts()
    processAutoPylon()
    destroyRazorbloom()
    local char = getChar(plr); local root = getRoot(char)
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
table.insert(scriptConnections, connections["MainHeartbeat"])

-- =====================================================================
-- UI LIBRARY
-- =====================================================================
Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

local Loading = Library:CreateLoading({Title = "Null GUI - Java.", Icon = "7476151111", TotalSteps = 4})
Loading:SetMessage("Initializing...")
Loading:SetDescription("Checking environment...")
Loading:SetCurrentStep(1)
Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. game.Players.LocalPlayer.Name)
Loading.Sidebar:AddLabel("Version: v1")
Loading.Sidebar:AddLabel("Mode: " .. (isSupportedPlace and "Nullscape Gui" or "Universal Gui"))
Loading:SetCurrentStep(2)
Loading:SetCurrentStep(3)
Loading:SetDescription("Script loaded successfully!")
Loading:SetCurrentStep(4)
Loading:Continue()

local Window = Library:CreateWindow({
    Title = "Java's Null Gui",
    Footer = string.format("%s | %d | %s | v1", gameName, PlaceId, JobId ~= "" and JobId or "Solo"),
    Icon = "cat", Center = true, AutoShow = true,
})

-- =====================================================================
-- TABS
-- =====================================================================
local Tabs = {}
if isSupportedPlace then
    Tabs.Playerlist = Window:AddTab("Main", "paw-print")
    Tabs.Enemies    = Window:AddTab("Enemies", "triangle-alert")
    Tabs.Map        = Window:AddTab("Map", "map")
    Tabs.Upgrades   = Window:AddTab("Upgrades", "shield-plus")
    Tabs.Webhook    = Window:AddTab("Webhook", "webhook")  -- NEW
    Tabs.Debug      = Window:AddTab("Debug", "bug")
    Tabs.Credits    = Window:AddTab("Credits", "info")
    Tabs.Settings   = Window:AddTab("Settings", "settings")

    -- =================================================================
    -- GIFTS
    -- =================================================================
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
                            local normalTgl = getToggle("CollectNormalToggle")
                            if normalTgl then normalTgl:SetValue(true) end
                            collectGiftsEngine(false)
                            if notifOn then notif("NewLevel sound detected. Auto-started normal gift collection.", "Collection System") end
                        end
                    end)
                    table.insert(scriptConnections, connections["AutoStartCollectingConn"])
                end
            else
                if connections["AutoStartCollectingConn"] then
                    connections["AutoStartCollectingConn"]:Disconnect()
                    connections["AutoStartCollectingConn"] = nil
                end
            end
        end
    })
    GiftGroup:AddToggle("CollectNormalToggle", {
        Text = "<font color='#AA55FF'>Collect Normal Gifts</font>",
        Default = Settings.CollectNormal,
        Tooltip = "Collects normal gifts first. If Golden is also enabled, automatically falls back to Golden when normals run out.",
        Callback = function(Value)
            Settings.CollectNormal = Value
            if Value then collectGiftsEngine(false)
            else if not Settings.CollectGolden and tweening then stopAllCollection() end end
        end
    })
    GiftGroup:AddToggle("CollectGoldenToggle", {
        Text = "<font color='#FFCC00'>Collect Golden Gifts</font>",
        Default = Settings.CollectGolden,
        Tooltip = "Collects Golden gifts. Works alongside Normal.",
        Callback = function(Value)
            Settings.CollectGolden = Value
            if Value then
                if not Settings.CollectNormal then collectGiftsEngine(true) else collectGiftsEngine(false) end
            else if not Settings.CollectNormal and tweening then stopAllCollection() end end
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
    GiftGroup:AddDivider("Timing")
    GiftGroup:AddInput("LegitSpeedInput", {Default = tostring(Settings.LegitSpeed), Numeric = true, Finished = true, Text = "Legit WalkSpeed", Placeholder = "16...", Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then Settings.LegitSpeed = num; Library:Notify("Legit Speed set to " .. tostring(num), 2) end
    end})
    GiftGroup:AddToggle("InstantTPToggle", {Text = "Instant Teleport Collection", Default = Settings.InstantTeleport, Callback = function(Value) Settings.InstantTeleport = Value end})
    GiftGroup:AddInput("TweenSpeedInput", {Default = tostring(Settings.TweenSpeed), Numeric = true, Finished = true, Text = "Tween Speed (If TP Off)", Placeholder = "300...", Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then Settings.TweenSpeed = num; Library:Notify("Tween Speed set to " .. tostring(num), 2) end
    end})
    GiftGroup:AddInput("TeleportDelayInput", {Default = tostring(Settings.DelayBetweenGifts), Numeric = true, Finished = true, Text = "Teleport Delay (Seconds)", Placeholder = "0.05...", Callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then Settings.DelayBetweenGifts = num; Library:Notify("Teleport Delay set to " .. tostring(num) .. "s", 2) end
    end})
    GiftGroup:AddDivider("Actions")
    GiftGroup:AddToggle("AutoBeaconToggle", {Text = "<font color='#00FF00'>Walk/TP To Beacon On Finish</font>", Default = Settings.AutoBeacon, Callback = function(Value) Settings.AutoBeacon = Value end})
    GiftGroup:AddButton({Text = "<font color='#FF4444'>Cancel Gift Collection</font>", Func = function() stopAllCollection(); Library:Notify("Cancelled gift collection.", 2) end})

    local FarmGroup = Tabs.Playerlist:AddLeftGroupbox("Farm")
    FarmGroup:AddToggle("AutoFarmBetaToggle", {
        Text = "auto farm (beta)",
        Default = Settings.AutoFarmBeta,
        Tooltip = "Auto enables start collecting, beacon TP, and enemy deletion.",
        Callback = function(Value)
            Settings.AutoFarmBeta = Value
            local autoStartTgl = getToggle("AutoStartCollectingToggle")
            local autoBeaconTgl = getToggle("AutoBeaconToggle")
            local collectNormalTgl = getToggle("CollectNormalToggle")
            local deleteAllEnemiesTgl = getToggle("DeleteAllEnemies")
            if Value then
                if autoStartTgl then autoStartTgl:SetValue(true) else Settings.AutoStartCollecting = true end
                if autoBeaconTgl then autoBeaconTgl:SetValue(true) else Settings.AutoBeacon = true end
                if collectNormalTgl then collectNormalTgl:SetValue(true) else Settings.CollectNormal = true end
                if deleteAllEnemiesTgl then deleteAllEnemiesTgl:SetValue(true) else deleteAllEnemies = true end
                Library:Notify("Auto Farm (Beta) Enabled.", 2)
            else
                if autoStartTgl then autoStartTgl:SetValue(false) else Settings.AutoStartCollecting = false end
                if autoBeaconTgl then autoBeaconTgl:SetValue(false) else Settings.AutoBeacon = false end
                if collectNormalTgl then collectNormalTgl:SetValue(false) else Settings.CollectNormal = false end
                if deleteAllEnemiesTgl then deleteAllEnemiesTgl:SetValue(false) else deleteAllEnemies = false end
                Library:Notify("Auto Farm (Beta) Disabled.", 2)
            end
        end
    })
    FarmGroup:AddToggle("AutoPylonToggle", {Text = "Teleport to pylon", Default = Settings.AutoPylon, Tooltip = "Teleports to and completes pylons one by one as they spawn.", Callback = function(Value)
        Settings.AutoPylon = Value
        if Value then Library:Notify("Auto Teleport to Pylon Enabled.", 2); teleportToNearestPylon()
        else Library:Notify("Auto Teleport to Pylon Disabled.", 2) end
    end})
    FarmGroup:AddButton({Text = "Teleport to Pylon", Func = function() teleportToNearestPylon() end})
    FarmGroup:AddInput("TargetLevelVoidInput", {Text = "Auto Void at Level", Default = "", Numeric = true, Finished = false, Placeholder = "Target Level (e.g. 2)...", Tooltip = "Input player level to automatically teleport character into the void upon reaching it.", Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then Settings.TargetLevel = num; Library:Notify("Auto Void set for Level " .. tostring(num), 2)
        else Settings.TargetLevel = nil; Library:Notify("Auto Void Level disabled.", 2) end
    end})

    local WhitelistGroup = Tabs.Playerlist:AddLeftGroupbox("Vote Whitelists")
    WhitelistGroup:AddDropdown("EnemiesWhitelistDropdown", {Values = EnemiesList, Multi = true, Text = "Enemies Whitelist", Tooltip = "Select which Enemies to vote for.", Callback = function(Value) Settings.EnemiesWhitelist = Value end})
    WhitelistGroup:AddDropdown("CursesWhitelistDropdown", {Values = CursesList, Multi = true, Text = "Curses Whitelist", Tooltip = "Select which Curses to vote for.", Callback = function(Value) Settings.CursesWhitelist = Value end})
    WhitelistGroup:AddDropdown("UpgradesWhitelistDropdown", {Values = UpgradesList, Multi = true, Text = "Upgrades Whitelist", Tooltip = "Select which Upgrades to vote for.", Callback = function(Value) Settings.UpgradesWhitelist = Value end})

    local PlayerGroup = Tabs.Playerlist:AddRightGroupbox("Player Features")
    PlayerGroup:AddToggle("VelocityVisualizerToggle", {Text = "Velocity Visualizer", Default = false, Callback = function(Value)
        velov = Value
        if not Value then velocityPart.Transparency = 1; vpBox.Transparency = 1 end
    end})
    PlayerGroup:AddToggle("DestroyRazorbloomToggle", {Text = "<font color='#FF6666'>Destroy Razorbloom (VISIBLE TO OTHERS)</font>", Default = nrb, Tooltip = "Automatically destroys Razorbloom objects from your character when they appear.", Callback = function(Value)
        nrb = Value
        if Value then destroyRazorbloom(); Library:Notify("Razorbloom Destroyer enabled.", 2)
        else Library:Notify("Razorbloom Destroyer disabled.", 2) end
    end})
    PlayerGroup:AddSlider("GiftCollectionRange", {Text = "Gift collection range", Default = 1, Min = 0, Max = 10, Rounding = 0, Tooltip = "Adds 30 Magnet upgrades per slider tick (0 sets magnet upgrade to 1).", Callback = function(Value)
        local magnetAmount = (Value == 0) and 1 or (Value * 30)
        applyUpgradeValue("GiftMagnet", magnetAmount, upgradeLabels["GiftMagnet"])
    end})

    -- =================================================================
    -- ENEMIES
    -- =================================================================
    local EnemyActionGroup = Tabs.Enemies:AddLeftGroupbox("Enemy Controls & Utilities")
    EnemyActionGroup:AddToggle("DisableAllEnemies", {Text = "Disable All Enemy AI", Default = false, Callback = function(Value)
        disableAllEnemies = Value
        if Value then
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do disableEnemyEntity(enemy) end
                connections["DisableEnemies"] = enemies.ChildAdded:Connect(function(child)
                    if disableAllEnemies then task.wait(0.1); disableEnemyEntity(child) end
                end)
                table.insert(scriptConnections, connections["DisableEnemies"])
            end
            Library:Notify("Workspace Enemy AI disabled.", 3)
        else
            if connections["DisableEnemies"] then connections["DisableEnemies"]:Disconnect(); connections["DisableEnemies"] = nil end
            Library:Notify("Workspace Enemy AI re-enabled.", 3)
        end
    end})
    EnemyActionGroup:AddToggle("DisableClientEnemies", {Text = "Disable all client sided enemies", Default = false, Callback = function(Value)
        disableClientEnemies = Value
        if Value then
            processClientSideEnemies()
            connections["DisableClientEnemies"] = RunService.Heartbeat:Connect(function()
                if disableClientEnemies then processClientSideEnemies() end
            end)
            table.insert(scriptConnections, connections["DisableClientEnemies"])
            Library:Notify("Client-sided enemies disabler activated.", 3)
        else
            if connections["DisableClientEnemies"] then connections["DisableClientEnemies"]:Disconnect(); connections["DisableClientEnemies"] = nil end
            Library:Notify("Client-sided enemies disabler stopped.", 3)
        end
    end})
    EnemyActionGroup:AddToggle("DeleteAllEnemies", {Text = "Delete All Enemies", Default = false, Callback = function(Value)
        deleteAllEnemies = Value
        if Value then
            pb = true
            local guardianTgl = getToggle("Guardian_Protection")
            if guardianTgl then guardianTgl:SetValue(true) end
            if enemies then
                purgeExistingEnemies()
                connections["DeleteEnemies"] = enemies.ChildAdded:Connect(function(child)
                    if deleteAllEnemies then task.defer(function()
                        if child and child.Parent and child.Name ~= "Guardian" then child:Destroy() end
                    end) end
                end)
                table.insert(scriptConnections, connections["DeleteEnemies"])
            end
            Library:Notify("Auto-delete all enemies enabled (Guardian Protection active).", 3)
        else
            if connections["DeleteEnemies"] then connections["DeleteEnemies"]:Disconnect(); connections["DeleteEnemies"] = nil end
            Library:Notify("Auto-delete all enemies disabled.", 3)
        end
    end})
    EnemyActionGroup:AddDivider("Actions")
    EnemyActionGroup:AddButton({Text = "Purge All Existing Enemies", Func = function() local count = purgeExistingEnemies(); Library:Notify("Purged " .. tostring(count) .. " enemies from workspace.", 3) end})
    EnemyActionGroup:AddButton({Text = "Refresh Target List", Func = function() Library:Notify("Refreshed active enemy cache.", 2) end})
    EnemyActionGroup:AddDivider("Active Enemies")
    local activeEnemiesLabel = EnemyActionGroup:AddLabel("Scanning workspace...")
    task.spawn(function()
        while task.wait(1.5) do
            if not enemies or #enemies:GetChildren() == 0 then
                activeEnemiesLabel:SetText("<font color='#AAAAAA'>No active enemies</font>")
            else
                local lines = {}
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local hum = enemy:FindFirstChildOfClass("Humanoid")
                    local isDisabled = false
                    if hum and hum.PlatformStand then isDisabled = true
                    elseif enemy:FindFirstChildOfClass("Script") and enemy:FindFirstChildOfClass("Script").Disabled then isDisabled = true end
                    if isDisabled then table.insert(lines, string.format("<font color='#AAAAAA'>%s (Disabled)</font>", enemy.Name))
                    else table.insert(lines, string.format("<font color='#00FF00'>%s (Active)</font>", enemy.Name)) end
                end
                activeEnemiesLabel:SetText(table.concat(lines, "\n"))
            end
        end
    end)
    task.spawn(function() while task.wait(1) do processPortedDisables() end end)

    local DetailedEnemyGroup = Tabs.Enemies:AddRightGroupbox("Granular Enemy Options")
    task.spawn(function()
        while task.wait(1) do
            if enemies then for _, enemy in ipairs(enemies:GetChildren()) do handleEnemy(enemy) end end
        end
    end)
    if enemies then
        connections["GranularChildAdded"] = enemies.ChildAdded:Connect(function(child) task.wait(0.1); handleEnemy(child) end)
        table.insert(scriptConnections, connections["GranularChildAdded"])
    end
    local function addDetailedEnemy(group, name)
        group:AddDivider(name)
        if auto_disable[name] ~= nil then
            group:AddToggle(name.."_Disable", {Text = "Auto Disable", Default = auto_disable[name], Callback = function(v) auto_disable[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end})
        end
        if auto_break[name] ~= nil then
            group:AddToggle(name.."_Break", {Text = "Auto Break AI", Default = auto_break[name], Callback = function(v) auto_break[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end})
        end
        if auto_destroy[name] ~= nil then
            group:AddToggle(name.."_Destroy", {Text = "Auto Destroy", Default = auto_destroy[name], Callback = function(v) auto_destroy[name] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(name)) end end})
        end
    end
    addDetailedEnemy(DetailedEnemyGroup, "Bell")
    addDetailedEnemy(DetailedEnemyGroup, "Mart")
    addDetailedEnemy(DetailedEnemyGroup, "Skinwalker")
    addDetailedEnemy(DetailedEnemyGroup, "Springer")
    addDetailedEnemy(DetailedEnemyGroup, "ICBM")
    addDetailedEnemy(DetailedEnemyGroup, "Baby")
    addDetailedEnemy(DetailedEnemyGroup, "Flesh")
    DetailedEnemyGroup:AddDivider("Guardian Options")
    DetailedEnemyGroup:AddToggle("Guardian_Immunity", {Text = "Guardian Death Immunity", Default = false, Tooltip = "Blocks server death registration when killed by Guardian.", Callback = function(Value)
        guardianImmunity = Value
        Library:Notify("Guardian Immunity " .. (Value and "Enabled" or "Disabled"), 2)
    end})
    DetailedEnemyGroup:AddToggle("Shadow_Guardian_Immunity", {Text = "Shadow Guardian Death Immunity", Default = false, Tooltip = "Blocks server death registration when killed by Shadow Guardian.", Callback = function(Value)
        voidboundGuardianImmunity = Value
        Library:Notify("Shadow Guardian Immunity " .. (Value and "Enabled" or "Disabled"), 2)
    end})
    DetailedEnemyGroup:AddToggle("Guardian_Protection", {Text = "Create Bullet Protection Sphere", Default = pb, Callback = function(Value)
        pb = Value
        if not Value then
            for _, d in pairs(activeBulletProtections) do if d.sphere then d.sphere:Destroy() end end
            table.clear(activeBulletProtections)
        end
    end})
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

    -- =================================================================
    -- MAP
    -- =================================================================
    local VoidGroup = Tabs.Map:AddLeftGroupbox("Void")
    VoidGroup:AddToggle("AntiVoid", {Text = "Anti Void", Default = false, Callback = function(Value) av = Value end})
    VoidGroup:AddDropdown("AntiVoidSetting", {Values = {"1. Teleport to Spawn", "2. Launch Up", "3. Closest Gift"}, Default = 1, Multi = false, Text = "Anti Void Setting", Callback = function(Value) antiVoidSelection = tonumber(string.split(Value, ".")[1]) end})
    VoidGroup:AddSlider("LaunchPower", {Text = "Launch Power", Default = 500, Min = 10, Max = 1000, Rounding = 0, Callback = function(Value) lp = Value end})
    VoidGroup:AddToggle("VisibleVoid", {Text = "Visible Void", Default = false, Callback = function(Value) local killVoid = workspace:FindFirstChild("KillVoid"); if killVoid then killVoid.Transparency = Value and 0 or 1 end end})

    local MapProtectionGroup = Tabs.Map:AddRightGroupbox("Map Defenses")
    MapProtectionGroup:AddDivider("Protection Spheres")
    MapProtectionGroup:AddToggle("Tripmine_Protection", {Text = "Tripmine Safe Sphere Protection", Default = pt, Callback = function(Value)
        pt = Value
        if not Value then
            for _, d in pairs(activeTripmineProtections) do if d.sphere then d.sphere:Destroy() end end
            table.clear(activeTripmineProtections)
        end
    end})
    MapProtectionGroup:AddDivider("Tiles")
    MapProtectionGroup:AddToggle("AntiFleshIceTiles", {Text = "Anti flesh tiles/ ice tiles (tile connection)", Default = false, Callback = function(Value) antiFleshTilesEnabled = Value; applyTileConnections() end})
    MapProtectionGroup:AddToggle("PersistentTileConnections", {Text = "Persistent tile connections", Default = false, Callback = function(Value)
        persistentTileConnections = Value
        if Value then
            if not persistentRespawnConnection then
                persistentRespawnConnection = plr.CharacterAdded:Connect(function()
                    task.wait(1)
                    if persistentTileConnections and antiFleshTilesEnabled then applyTileConnections() end
                end)
            end
        else
            if persistentRespawnConnection then persistentRespawnConnection:Disconnect(); persistentRespawnConnection = nil end
        end
    end})
    MapProtectionGroup:AddDivider("Extra Disables")
    MapProtectionGroup:AddToggle("DisableSeaMines", {Text = "Disable Sea Mines", Default = false, Callback = function(Value) disableSeaMines = Value end})
    MapProtectionGroup:AddToggle("DisableVoidImplosions", {Text = "Disable Void Implosions", Default = false, Callback = function(Value) disableVoidImplosions = Value end})
    MapProtectionGroup:AddToggle("DisableFakeBeacons", {Text = "Disable Fake Beacons", Default = false, Callback = function(Value) disableFakeBeacons = Value end})
    MapProtectionGroup:AddToggle("DisableOblivion", {Text = "Disable Oblivion", Default = false, Callback = function(Value) disableOblivion = Value end})

    -- =================================================================
    -- UPGRADES
    -- =================================================================
    local upgradeTabLeft = Tabs.Upgrades:AddLeftGroupbox("Upgrades Status")
    if upgradeTabLeft.Container then upgradeTabLeft.Container.AutomaticSize = Enum.AutomaticSize.Y end
    if fSignal then upgradeTabLeft:AddLabel("Your exploit can add upgrades.")
    else upgradeTabLeft:AddLabel("Your exploit currently doesn't support adding upgrades.") end
    upgradeTabLeft:AddDivider("Active Upgrades List")
    local activeUpgradesLabel = upgradeTabLeft:AddLabel("None Active")
    local clientUpgrades = {"MatrixTetrahedron", "Adrenaline", "HighlightGifts", "AdvancedGravityCoil", "SportShoes", "TheOrb", "RealWings", "GraceWings", "RadarPlayer", "RadarInstruments", "HighlightTripmines", "IceSkates", "SwiftnessRing", "GiftMagnet", "SharkTail", "EnemyOnTop", "PocketBell", "NinjaBelt", "Helmet", "DoubleJump", "RadarAltars"}

    updateActiveUpgradesDisplay = function()
        local textParts = {}
        for name, val in pairs(activeUpgrades) do
            if val > 0 then table.insert(textParts, string.format("<font color='#0055ff'>%s</font>: %d", name, val)) end
        end
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
                isSettingGuardValue[name] = true; intv.Value = desiredValue; isSettingGuardValue[name] = false
            end
        end)
        table.insert(scriptConnections, upgradeValueGuards[name])
    end

    applyUpgradeValue = function(name, targetValue, uLabel)
        local upgradesFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local intv = upgradesFolder and upgradesFolder:FindFirstChild(name)
        targetValue = math.max(0, math.floor(targetValue or 0))
        if targetValue > 0 then
            activeUpgrades[name] = targetValue
            if intv then isSettingGuardValue[name] = true; intv.Value = targetValue; isSettingGuardValue[name] = false
            else
                intv = Instance.new("IntValue"); intv.Name = name; intv.Value = targetValue
                if upgradesFolder then intv.Parent = upgradesFolder end
            end
            setupUpgradeGuardian(intv, name)
            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[name] = targetValue}) end
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[name] = targetValue}) end
                end)
            end
        else
            activeUpgrades[name] = nil
            if intv then intv:Destroy() end
            if upgradeValueGuards[name] then upgradeValueGuards[name]:Disconnect(); upgradeValueGuards[name] = nil end
            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[name] = 0}) end
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[name] = 0}) end
                end)
            end
        end
        if uLabel then uLabel:SetText("Current: " .. tostring(targetValue)) end
        updateActiveUpgradesDisplay()
    end

    local function restoreAllUpgrades()
        local upgradeFolderParent = ReplicatedStorage:FindFirstChild("UpgradeFolder")
        local upgradesFolder = upgradeFolderParent and upgradeFolderParent:FindFirstChild("Upgrades")
        for name, value in pairs(activeUpgrades) do
            if value > 0 and upgradesFolder then
                local intv = upgradesFolder:FindFirstChild(name)
                if not intv then intv = Instance.new("IntValue"); intv.Name = name; intv.Parent = upgradesFolder end
                isSettingGuardValue[name] = true; intv.Value = value; isSettingGuardValue[name] = false
                setupUpgradeGuardian(intv, name)
                if events and events:FindFirstChild("UpgradesChanged") then
                    pcall(function()
                        if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[name] = value}) end
                        if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[name] = value}) end
                    end)
                end
            end
        end
        updateActiveUpgradesDisplay()
    end

    local charUpgradeConn = plr.CharacterAdded:Connect(function(newChar) task.wait(1); restoreAllUpgrades() end)
    table.insert(scriptConnections, charUpgradeConn)

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
        upgradeListGroup:AddInput(u .. "_Input", {Default = tostring(initialVal), Numeric = true, Finished = true, Text = "Set Amount", Placeholder = "Amount...", Callback = function(Value) local num = tonumber(Value) if num then applyUpgradeValue(u, num, uLabel) end end})
        upgradeListGroup:AddButton({Text = "Add One (" .. u .. ")", Func = function() local current = activeUpgrades[u] or initialVal; applyUpgradeValue(u, current + 1, uLabel) end})
        upgradeListGroup:AddButton({Text = "Remove One (" .. u .. ")", Func = function() local current = activeUpgrades[u] or initialVal; applyUpgradeValue(u, current - 1, uLabel) end})
    end
    updateActiveUpgradesDisplay()

    -- =================================================================
    -- WEBHOOK TAB (NEW)
    -- =================================================================
    local WebhookConfigGroup = Tabs.Webhook:AddLeftGroupbox("Discord Webhook")

    WebhookConfigGroup:AddLabel("<font color='#AAAAAA'>Paste a Discord webhook URL below. Level-change and death payloads are pushed to this URL when their toggles are on.</font>")

    WebhookConfigGroup:AddInput("WebhookURLInput", {
        Default = "",
        Finished = false,
        Text = "Discord Webhook URL",
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(Value)
            Webhook.URL = tostring(Value or "")
        end
    })

    WebhookConfigGroup:AddDivider("Notification Triggers")

    WebhookConfigGroup:AddToggle("WebhookLevelToggle", {
        Text = "<font color='#00FF88'>Notify on new level</font>",
        Default = false,
        Tooltip = "Sends a webhook whenever a new level is detected (same LogService detection used by the script's Auto-Void feature).",
        Callback = function(Value)
            Webhook.LevelEnabled = Value
        end
    })

    WebhookConfigGroup:AddToggle("WebhookDeathToggle", {
        Text = "<font color='#FF4444'>Notify on death</font>",
        Default = false,
        Tooltip = "Sends a webhook whenever the local player dies.",
        Callback = function(Value)
            Webhook.DeathEnabled = Value
        end
    })

    WebhookConfigGroup:AddDivider("Manual Actions")

    WebhookConfigGroup:AddButton({
        Text = "<font color='#00AAFF'>Send Test / Current Info</font>",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook error: " .. tostring(err), 4); return end
            local embed = {
                title = "🔔 Test Webhook",
                description = "Manual test payload from Java's Null GUI.",
                color = 0x00AAFF,
                fields = buildWebhookFields(),
                timestamp = DateTime.now():ToIsoDate(),
                footer = {text = "Java's Null GUI | Test"},
            }
            local success, res = dispatchWebhook({username = "Null GUI", embeds = {embed}})
            if success then Library:Notify("Test webhook sent.", 2)
            else Library:Notify("Failed to send: " .. tostring(res), 4) end
        end
    })

    WebhookConfigGroup:AddButton({
        Text = "Send Death Webhook (Test)",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook error: " .. tostring(err), 4); return end
            local success, res = dispatchDeathWebhook()
            if success then Library:Notify("Death test webhook sent.", 2)
            else Library:Notify("Failed: " .. tostring(res), 4) end
        end
    })

    local WebhookInfoGroup = Tabs.Webhook:AddRightGroupbox("Webhook Info")

    WebhookInfoGroup:AddLabel("<font color='#AAAAAA'>Every webhook payload includes:</font>")
    WebhookInfoGroup:AddLabel("• <b>Current Level</b>")
    WebhookInfoGroup:AddLabel("• <b>Active Enemies</b> (with [Disabled] / [Client] tags)")
    WebhookInfoGroup:AddLabel("• <b>Active Upgrades</b> with counts")
    WebhookInfoGroup:AddLabel("• Timestamp & session footer")

    WebhookInfoGroup:AddDivider("Live Status")
    local webhookStatusLabel = WebhookInfoGroup:AddLabel("Status: Idle")

    task.spawn(function()
        while task.wait(1) do
            if webhookStatusLabel then
                local lines = {
                    "URL Set: " .. (Webhook.URL ~= "" and "<font color='#00FF00'>Yes</font>" or "<font color='#FF6666'>No</font>"),
                    "Level Trigger: " .. (Webhook.LevelEnabled and "<font color='#00FF00'>ON</font>" or "<font color='#AAAAAA'>OFF</font>"),
                    "Death Trigger: " .. (Webhook.DeathEnabled and "<font color='#00FF00'>ON</font>" or "<font color='#AAAAAA'>OFF</font>"),
                    "Last Sent Level: " .. tostring(Webhook.LastSentLevel or "N/A"),
                    "Last Observed Level: " .. tostring(currentObservedLevel or "N/A"),
                }
                webhookStatusLabel:SetText(table.concat(lines, "\n"))
            end
        end
    end)

else
    -- =================================================================
    -- UNIVERSAL MODE
    -- =================================================================
    Tabs.UniversalMain = Window:AddTab("Main - Universal", "globe")
    Tabs.Debug         = Window:AddTab("Debug", "bug")
    Tabs.Credits       = Window:AddTab("Credits", "info")
    Tabs.Settings      = Window:AddTab("Settings", "settings")

    local UniversalGroup = Tabs.UniversalMain:AddLeftGroupbox("Universal Features")
    UniversalGroup:AddSlider("WalkSpeedSlider", {Text = "WalkSpeed", Default = 16, Min = 16, Max = 250, Rounding = 0, Callback = function(Value)
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value end
    end})
    UniversalGroup:AddSlider("JumpPowerSlider", {Text = "JumpPower", Default = 50, Min = 50, Max = 500, Rounding = 0, Callback = function(Value)
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value end
    end})

    local TeleportGroup = Tabs.UniversalMain:AddRightGroupbox("Utilities")
    local function getPlayerNames()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= plr then table.insert(list, p.Name) end end
        return list
    end
    local selectedPlayer = nil
    TeleportGroup:AddDropdown("TargetPlayerDropdown", {Text = "Select Player to TP", Values = getPlayerNames(), Default = 1, Callback = function(Value) selectedPlayer = Value end})
    TeleportGroup:AddButton({Text = "Refresh Player List", Func = function() if Options and Options.TargetPlayerDropdown then Options.TargetPlayerDropdown:SetValues(getPlayerNames()) end end})
    TeleportGroup:AddButton({Text = "Teleport to Player", Func = function()
        if selectedPlayer then
            local targetPlr = Players:FindFirstChild(selectedPlayer)
            if targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                plr.Character.HumanoidRootPart.CFrame = targetPlr.Character.HumanoidRootPart.CFrame
                Library:Notify("Teleported to " .. selectedPlayer, 3)
            end
        end
    end})
    TeleportGroup:AddButton({Text = "Rejoin Server", Func = function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, plr) end})
    TeleportGroup:AddButton({Text = "Server Hop", Func = function()
        local success, servers = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")) end)
        if success and servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.playing < server.maxPlayers and server.id ~= JobId then
                    TeleportService:TeleportToPlaceInstance(PlaceId, server.id, plr); return
                end
            end
        end
        Library:Notify("Failed to find a server.", 3)
    end})
end

-- =====================================================================
-- CREDITS / DEBUG
-- =====================================================================
local ContributorsGroup = Tabs.Credits:AddLeftGroupbox("Contributors")
ContributorsGroup:AddLabel("<font color='#FFA500'>kaoru_zz</font>; Guardians anti-kill")
ContributorsGroup:AddLabel("<font color='#FFA500'>(Ali)zeja</font> Main script, Huge inspiration!")
local DevelopersGroup = Tabs.Credits:AddRightGroupbox("Developers")
DevelopersGroup:AddLabel("<font color='#AA55FF'>Java (.html4)</font> Main Developer")

local DebugGroup = Tabs.Debug:AddLeftGroupbox("Debug Actions")
DebugGroup:AddButton({Text = "Log Select Attributes", Func = function() logSelectAttributes(); Library:Notify("Logged board attributes to console/file.", 3) end})
DebugGroup:AddButton({Text = "Unload GUI", Func = function()
    if _G.NullGui_Cleanup and type(_G.NullGui_Cleanup) == "function" then pcall(_G.NullGui_Cleanup) end
    if velocityPart and velocityPart.Parent then pcall(function() velocityPart:Destroy() end) end
    if protectionFolder and protectionFolder.Parent then pcall(function() protectionFolder:Destroy() end) end
    if Library and type(Library.Unload) == "function" then pcall(function() Library:Unload() end) end
end})

local DebugInfoGroup = Tabs.Debug:AddRightGroupbox("Session State")
local levelLabel = DebugInfoGroup:AddLabel("Current Observed Level: N/A")
local connLabel = DebugInfoGroup:AddLabel("Active Connections: " .. tostring(#scriptConnections))
task.spawn(function()
    while task.wait(1) do
        if levelLabel then levelLabel:SetText("Current Observed Level: " .. tostring(currentObservedLevel or "N/A")) end
        if connLabel then connLabel:SetText("Active Connections: " .. tostring(#scriptConnections)) end
    end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("NullGui")
SaveManager:SetFolder("NullGui")
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()