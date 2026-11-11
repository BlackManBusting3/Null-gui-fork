-- =====================================================================
-- 1 CLEANUP
-- =====================================================================
if _G.NullGui_Cleanup and type(_G.NullGui_Cleanup) == "function" then
    pcall(_G.NullGui_Cleanup)
end
local scriptConnections = {}
_G.NullGui_Cleanup = function()
    for _, conn in pairs(scriptConnections) do
        if conn and conn.Connected then conn:Disconnect() end
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
        if productInfo and productInfo.Name then gameName = productInfo.Name end
    end)
end)

local isSupportedPlace = true
local fSignal = firesignal or fire_signal or fireSignal
if not fSignal and getgenv then
    fSignal = getgenv().firesignal or getgenv().fire_signal or getgenv().fireSig
end

-- =====================================================================
-- IMMUNITY HOOK
-- =====================================================================
local guardianImmunity = false
local voidboundGuardianImmunity = false
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
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
-- LISTS
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
-- VISUALS
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
-- SETTINGS
-- =====================================================================
local Settings = {
    CollectNormal = false, CollectGolden = false, LegitCollection = false,
    LegitSpeed = 16, InstantTeleport = true, TweenSpeed = 60, DelayBetweenGifts = 0.05,
    AutoBeacon = false, AutoStartCollecting = false, AutoFarmBeta = false, AutoPylon = false,
    TargetLevel = nil, EnemiesWhitelist = {}, CursesWhitelist = {}, UpgradesWhitelist = {}
}

-- =====================================================================
-- STATE  (moved ABOVE webhook so all flags are in scope for getActiveOptionsList)
-- =====================================================================
local currentObservedLevel = nil
local targetVoidProcessing = false

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

local auto_disable = {Bell=false,Mart=false,Skinwalker=false,Springer=false,Baby=false,Flesh=false,nilEnemy=false,nilMirage=false,Telefragger=false,ShadowBaby=false,Cadence=false}
local auto_break = {Bell=false,Mart=false,Skinwalker=false,Springer=false,ICBM=false,Baby=false,Flesh=false,nilEnemy=false,nilMirage=false,Telefragger=false,ShadowBaby=false,Celestial=false,Cadence=false}
local auto_destroy = {Bell=false,Mart=false,Skinwalker=false,Springer=false,ICBM=false,Baby=false,Flesh=false,Operator=false,Kolona=false,nilEnemy=false,nilMirage=false,Telefragger=false,Sigil=false,ShadowBaby=false,Voidbreaker=false,Cadence=false,Scrapmaw=false,RealityBreak=false,Celestial=false}

local pt, pb, velov = false, false, false
local connections = {}
local activeUpgrades = {}
local upgradeValueGuards = {}
local isSettingGuardValue = {}
local blacklistedGifts = {}
local antiVoidSelection, av, lp = 1, false, 500
local loggedAttributes = {}
local logToggleActive = false
local selectionState = { failedParts = {}, rerollCount = 0 }
local updateActiveUpgradesDisplay = function() end
local applyUpgradeValue = function() end
local upgradeLabels = {}
local collectGiftsEngine = function() end

-- =====================================================================
-- DISCORD WEBHOOK SYSTEM  (with restart detection + enabled-options field)
-- =====================================================================
local Webhook = {
    URL = "",
    LevelEnabled = false,
    DeathEnabled = false,
    RestartEnabled = false,
    AutoEnabled = false,
    AutoIntervalMinutes = 5,
    LastSentLevel = nil,
    LastLevelSendTime = 0,
    LastDeathSendTime = 0,
    LastRestartSendTime = 0,
    LastAutoSendTime = 0,
    LevelsGained = 0,
    StartTime = os.time(),
    LastResponse = "Idle",
}

local function getExecutorName()
    local name = "Unknown"
    pcall(function()
        if type(identifyexecutor) == "function" then
            local ok, res = pcall(identifyexecutor)
            if ok and res and res ~= "" then name = tostring(res); return end
        end
        if type(getexecutorname) == "function" then
            local ok, res = pcall(getexecutorname)
            if ok and res and res ~= "" then name = tostring(res); return end
        end
        if syn and type(syn.getexecutorname) == "function" then
            local ok, res = pcall(syn.getexecutorname)
            if ok and res and res ~= "" then name = tostring(res); return end
        end
        if getgenv then
            local g = getgenv()
            if g.ScriptWare then name = "ScriptWare"
            elseif g.Krnl then name = "Krnl"
            elseif g.Fluxus then name = "Fluxus" end
        end
    end)
    return name
end

local function getTimestamp()
    local ok, res = pcall(function() return DateTime.now():ToIsoDate() end)
    if ok and res then return res end
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function getSessionUptime()
    local secs = os.time() - Webhook.StartTime
    local mins = math.floor(secs / 60)
    local hours = math.floor(mins / 60)
    if hours > 0 then return string.format("%dh %dm", hours, mins % 60) end
    return string.format("%dm %ds", mins, secs % 60)
end

local function httpPost(url, body)
    url = tostring(url or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then return false, "URL is empty" end

    local payload = {
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = body,
    }

    local fns = {}
    pcall(function() if type(request) == "function" then fns["request"] = request end end)
    pcall(function() if syn and type(syn.request) == "function" then fns["syn.request"] = syn.request end end)
    pcall(function() if http and type(http.request) == "function" then fns["http.request"] = http.request end end)
    pcall(function() if type(http_request) == "function" then fns["http_request"] = http_request end end)

    if not next(fns) then
        return false, "No HTTP function found (request / syn.request / http.request / http_request all nil)"
    end

    local errors = {}
    for name, fn in pairs(fns) do
        local ok, res = pcall(fn, payload)
        if ok and type(res) == "table" then
            local status = res.StatusCode or res.Status or res.status or res.statusCode or 0
            if status >= 200 and status < 300 then
                return true, "HTTP " .. tostring(status) .. " via " .. name
            else
                local b = tostring(res.Body or res.body or res.Response or "")
                if #b > 200 then b = b:sub(1, 200) .. "..." end
                table.insert(errors, string.format("%s → HTTP %s %s", name, tostring(status), b))
            end
        elseif ok then
            return true, "OK via " .. name .. " (no status reported)"
        else
            table.insert(errors, name .. " → " .. tostring(res))
        end
    end

    local msg = table.concat(errors, " | ")
    return false, msg ~= "" and msg or "All HTTP methods failed"
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
    if type(activeUpgrades) ~= "table" then return list end
    for name, val in pairs(activeUpgrades) do
        if val and val > 0 then table.insert(list, string.format("%s (%d)", name, val)) end
    end
    return list
end

-- NEW: Collect every enabled option across the script
local function getActiveOptionsList()
    local list = {}

    -- Gift collection
    if Settings.CollectNormal then table.insert(list, "Collect Normal Gifts") end
    if Settings.CollectGolden then table.insert(list, "Collect Golden Gifts") end
    if Settings.LegitCollection then table.insert(list, "Legit Collection (slow)") end
    if Settings.AutoStartCollecting then table.insert(list, "Auto Start Collecting") end
    if Settings.InstantTeleport then table.insert(list, "Instant TP Collection") end
    if Settings.AutoBeacon then table.insert(list, "Auto Beacon") end

    -- Farm
    if Settings.AutoFarmBeta then table.insert(list, "Auto Farm (Beta)") end
    if Settings.AutoPylon then table.insert(list, "Auto Pylon") end
    if Settings.TargetLevel then table.insert(list, "Auto Void @ Lv" .. tostring(Settings.TargetLevel)) end

    -- Whitelists
    local function countWL(tbl) local c = 0; if tbl then for _, v in pairs(tbl) do if v then c = c + 1 end end end return c end
    local eW, cW, uW = countWL(Settings.EnemiesWhitelist), countWL(Settings.CursesWhitelist), countWL(Settings.UpgradesWhitelist)
    if eW > 0 then table.insert(list, "Enemy Whitelist (" .. eW .. ")") end
    if cW > 0 then table.insert(list, "Curse Whitelist (" .. cW .. ")") end
    if uW > 0 then table.insert(list, "Upgrade Whitelist (" .. uW .. ")") end

    -- Player features
    if velov then table.insert(list, "Velocity Visualizer") end
    if nrb then table.insert(list, "Destroy Razorbloom") end

    -- Enemy controls
    if disableAllEnemies then table.insert(list, "Disable All Enemy AI") end
    if disableClientEnemies then table.insert(list, "Disable Client Enemies") end
    if deleteAllEnemies then table.insert(list, "Delete All Enemies") end
    if guardianImmunity then table.insert(list, "Guardian Death Immunity") end
    if voidboundGuardianImmunity then table.insert(list, "Shadow Guardian Immunity") end
    if pb then table.insert(list, "Bullet Protection Sphere") end

    local granular = 0
    for _, t in pairs(auto_disable) do if t then granular = granular + 1 end end
    for _, t in pairs(auto_break) do if t then granular = granular + 1 end end
    for _, t in pairs(auto_destroy) do if t then granular = granular + 1 end end
    if granular > 0 then table.insert(list, "Granular Enemy Options (" .. granular .. ")") end

    -- Map
    if av then
        local modes = {"Spawn", "Launch", "Gift"}
        table.insert(list, "Anti Void (" .. (modes[antiVoidSelection] or "?") .. ")")
    end
    if pt then table.insert(list, "Tripmine Protection") end
    if antiFleshTilesEnabled then table.insert(list, "Anti Flesh/Ice Tiles") end
    if persistentTileConnections then table.insert(list, "Persistent Tile Connections") end
    if disableSeaMines then table.insert(list, "Disable Sea Mines") end
    if disableVoidImplosions then table.insert(list, "Disable Void Implosions") end
    if disableFakeBeacons then table.insert(list, "Disable Fake Beacons") end
    if disableOblivion then table.insert(list, "Disable Oblivion") end

    -- Webhook triggers
    if Webhook.LevelEnabled then table.insert(list, "WEBHOOK: Level") end
    if Webhook.DeathEnabled then table.insert(list, "WEBHOOK: Death") end
    if Webhook.RestartEnabled then table.insert(list, "WEBHOOK: Restart") end
    if Webhook.AutoEnabled then table.insert(list, "WEBHOOK: Auto (" .. Webhook.AutoIntervalMinutes .. "m)") end

    return list
end

local function buildWebhookFields()
    local enemyList = getActiveEnemiesList()
    local upgradeList = getActiveUpgradesList()
    local optionsList = getActiveOptionsList()

    local enemiesText = #enemyList > 0 and table.concat(enemyList, "\n") or "None"
    local upgradesText = #upgradeList > 0 and table.concat(upgradeList, "\n") or "None"
    local optionsText = #optionsList > 0 and table.concat(optionsList, "\n") or "None"

    if #enemiesText > 1000 then enemiesText = enemiesText:sub(1, 980) .. "\n... (truncated)" end
    if #upgradesText > 1000 then upgradesText = upgradesText:sub(1, 980) .. "\n... (truncated)" end
    if #optionsText > 1000 then optionsText = optionsText:sub(1, 980) .. "\n... (truncated)" end

    local displayName = plr.DisplayName ~= plr.Name and string.format("%s (%s)", plr.Name, plr.DisplayName) or plr.Name
    local executor = getExecutorName()

    return {
        {name = "👤 Player", value = displayName, inline = true},
        {name = "🛠 Executor", value = executor, inline = true},
        {name = "📈 Current Level", value = tostring(currentObservedLevel or "N/A"), inline = true},
        {name = "📊 Levels This Session", value = tostring(Webhook.LevelsGained), inline = true},
        {name = "⏱ Session Uptime", value = getSessionUptime(), inline = true},
        {name = "🌐 Game", value = string.format("%s (%d)", gameName, PlaceId), inline = true},
        {name = "⚙️ Enabled Options (" .. tostring(#optionsList) .. ")", value = optionsText, inline = false},
        {name = "Active Enemies (" .. tostring(#enemyList) .. ")", value = enemiesText, inline = false},
        {name = "Active Upgrades (" .. tostring(#upgradeList) .. ")", value = upgradesText, inline = false},
    }
end

local function isValidWebhookURL()
    if not Webhook.URL or Webhook.URL == "" then return false, "No webhook URL configured" end
    local url = string.lower(Webhook.URL)
    if not (url:find("discord%.com") or url:find("discordapp%.com")) then
        return false, "URL is not a Discord webhook (must contain discord.com)"
    end
    if not url:find("webhooks") then
        return false, "URL missing /webhooks/ path segment"
    end
    return true
end

local function dispatchWebhook(payload)
    local ok, err = isValidWebhookURL()
    if not ok then
        Webhook.LastResponse = "Invalid: " .. err
        return false, err
    end
    local encOk, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if not encOk then
        Webhook.LastResponse = "JSON encode failed"
        return false, "Failed to encode payload: " .. tostring(encoded)
    end
    local success, info = httpPost(Webhook.URL, encoded)
    Webhook.LastResponse = (success and "✅ " or "❌ ") .. tostring(info)
    return success, info
end

local function dispatchLevelWebhook(level)
    return dispatchWebhook({
        username = "Null GUI",
        embeds = {{
            title = "📈 New Level Reached",
            description = string.format("Player **%s** advanced to **Level %d**.", plr.Name, level),
            color = 0x00FF88,
            fields = buildWebhookFields(),
            timestamp = getTimestamp(),
            footer = {text = "Java's Null GUI | Level Tracker"},
        }}
    })
end

local function dispatchDeathWebhook()
    return dispatchWebhook({
        username = "Null GUI",
        embeds = {{
            title = "💀 Player Died",
            description = string.format("**%s** has died.", plr.Name),
            color = 0xFF4444,
            fields = buildWebhookFields(),
            timestamp = getTimestamp(),
            footer = {text = "Java's Null GUI | Death Notifier"},
        }}
    })
end

local function dispatchRestartWebhook(oldLevel, newLevel)
    return dispatchWebhook({
        username = "Null GUI",
        embeds = {{
            title = "🔄 Player Restarted",
            description = string.format("**%s**'s level dropped from **%d → %d**. The player most likely died and respawned.", plr.Name, oldLevel, newLevel),
            color = 0xFFA500,
            fields = buildWebhookFields(),
            timestamp = getTimestamp(),
            footer = {text = "Java's Null GUI | Restart Detector"},
        }}
    })
end

local function dispatchPeriodicWebhook()
    return dispatchWebhook({
        username = "Null GUI",
        embeds = {{
            title = "🔄 Session Status Update",
            description = "Automatic periodic report from Java's Null GUI.",
            color = 0x00AAFF,
            fields = buildWebhookFields(),
            timestamp = getTimestamp(),
            footer = {text = "Java's Null GUI | Auto Report"},
        }}
    })
end

-- Auto-send loop
task.spawn(function()
    while task.wait(5) do
        if Webhook.AutoEnabled and Webhook.URL ~= "" then
            local elapsed = os.clock() - Webhook.LastAutoSendTime
            if elapsed >= (Webhook.AutoIntervalMinutes * 60) then
                Webhook.LastAutoSendTime = os.clock()
                task.spawn(function() dispatchPeriodicWebhook() end)
            end
        end
    end
end)
-- END WEBHOOK SYSTEM

-- =====================================================================
-- HELPERS
-- =====================================================================
local function getToggle(name) return (Toggles and Toggles[name]) or (Options and Options[name]) end
local function getChar(player) return player and player.Character end
local function getRoot(character) return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart) end

local function destroyRazorbloom()
    if not nrb then return end
    local char = getChar(plr); if not char then return end
    local rb = char:FindFirstChild("Razorbloom")
    if rb then rb:Destroy(); if notifOn then notif("Destroyed Razorbloom from character.", "Razorbloom System") end end
end

-- =====================================================================
-- PYLONS
-- =====================================================================
local function findPylons()
    local found = {}
    local list = {workspace:FindFirstChild("Pylons"), workspace:FindFirstChild("PylonFolder"), workspace:FindFirstChild("Item_Pools"), workspace}
    for _, container in ipairs(list) do
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
    local root = getRoot(getChar(plr)); if root then root.CFrame = part.CFrame + Vector3.new(0, 3, 0) end
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
    if #pylons == 0 then if Library and Library.Notify then Library:Notify("No Pylons found.", 3) end return false end
    local root = getRoot(getChar(plr)); if not root then return false end
    local closest, shortest = nil, math.huge
    for _, pylon in ipairs(pylons) do
        local part = pylon:IsA("BasePart") and pylon or pylon:FindFirstChildWhichIsA("BasePart") or pylon.PrimaryPart
        if part then
            local dist = (part.Position - root.Position).Magnitude
            if dist < shortest then shortest = dist; closest = pylon end
        end
    end
    if closest then interactWithPylon(closest); if Library and Library.Notify then Library:Notify("Teleporting to "..closest.Name, 3) end return true end
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
    if Settings.AutoPylon and child.Name:lower():find("pylon") then task.wait(0.1); interactWithPylon(child) end
end)
table.insert(scriptConnections, connections["PylonAddedListener"])

-- =====================================================================
-- LEVEL TRACKER (Level UP webhook + Restart detection webhook)
-- =====================================================================
connections["LevelLogListener"] = LogService.MessageOut:Connect(function(msg, msgType)
    local lvlStr = string.match(msg, "Level%s*(%d+)")
    if lvlStr then
        local lvl = tonumber(lvlStr)
        if lvl then
            local previous = currentObservedLevel
            currentObservedLevel = lvl
            if previous and lvl ~= previous then
                if lvl < previous then
                    -- Restart detected (level went down = player likely died)
                    Webhook.LastSentLevel = lvl
                    if Webhook.RestartEnabled and (os.clock() - Webhook.LastRestartSendTime >= 2) then
                        Webhook.LastRestartSendTime = os.clock()
                        task.spawn(function() dispatchRestartWebhook(previous, lvl) end)
                    end
                else
                    -- Level went up
                    Webhook.LevelsGained = Webhook.LevelsGained + (lvl - previous)
                    Webhook.LastSentLevel = lvl
                    if Webhook.LevelEnabled and (os.clock() - Webhook.LastLevelSendTime >= 1) then
                        Webhook.LastLevelSendTime = os.clock()
                        task.spawn(function() dispatchLevelWebhook(lvl) end)
                    end
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
    if killVoid and root and hum and hum.Health > 0 then root.CFrame = CFrame.new(killVoid.Position + Vector3.new(0, 20, 0)) end
end

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
                local wasN, wasG = Settings.CollectNormal, Settings.CollectGolden
                tweening = false
                if currentTween then currentTween:Cancel(); currentTween = nil end
                local respawnConn
                respawnConn = plr.CharacterAdded:Connect(function()
                    respawnConn:Disconnect(); task.wait(1.5)
                    if Settings.AutoStartCollecting or wasN then
                        Settings.CollectNormal = true
                        local tgl = getToggle("CollectNormalToggle"); if tgl then tgl:SetValue(true) end
                        task.defer(function() collectGiftsEngine(false) end)
                    elseif wasG then
                        Settings.CollectGolden = true
                        local tgl = getToggle("CollectGoldenToggle"); if tgl then tgl:SetValue(true) end
                        task.defer(function() collectGiftsEngine(true) end)
                    end
                end)
                table.insert(scriptConnections, respawnConn)
                task.spawn(function() executeVoidKill(); task.wait(30); targetVoidProcessing = false end)
            end
        end)
        table.insert(scriptConnections, connections["NewLevelVoidSoundConn"])
    end
end)

-- =====================================================================
-- PLAYER EVENTS
-- =====================================================================
local respawnCounter = 0
local beaconFiredTime = 0
local isAutoFarmProcessing = false
local function handleEndScreenReset()
    task.spawn(function()
        for _ = 1, 4 do
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
-- VOTE / AUTO-FARM ENGINE
-- =====================================================================
local function isValueWhitelisted(value, whitelistTable)
    if not value or not whitelistTable then return false end
    local searchVal = tostring(value):lower()
    for k, v in pairs(whitelistTable) do
        local keyStr = type(k) == "number" and tostring(v) or tostring(k)
        local enabled = type(k) == "number" and true or v
        if enabled and keyStr:lower() == searchVal then return true end
    end
    return false
end
local function hasAnyActiveWhitelist()
    for _, tbl in ipairs({Settings.EnemiesWhitelist, Settings.CursesWhitelist, Settings.UpgradesWhitelist}) do
        if tbl then for _, v in pairs(tbl) do if v then return true end end end
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
    local closest, shortest = nil, 10
    local scope = part.Parent or workspace
    for _, prompt in ipairs(scope:GetChildren()) do
        if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
            local dist = (prompt.Parent.Position - part.Position).Magnitude
            if dist < shortest then shortest = dist; closest = prompt end
        end
    end
    if closest then
        pcall(function()
            if fireproximityprompt then fireproximityprompt(closest)
            else closest:InputHoldBegin(); task.wait(closest.HoldDuration); closest:InputHoldEnd() end
        end)
    end
    local voteEvent = events and (events:FindFirstChild("Vote") or events:FindFirstChild("SelectVote"))
    if voteEvent and voteEvent:IsA("RemoteEvent") then pcall(function() voteEvent:FireServer(part.Name) end) end
end
local function checkPartMatch(part)
    if not part then return false end
    local t = part:GetAttribute("ChoiceType")
    local n = part:GetAttribute("ChoiceName")
    if t and n then
        local u = tostring(t):upper()
        if u:find("ENEM") then return isValueWhitelisted(n, Settings.EnemiesWhitelist)
        elseif u:find("UPGRADE") then return isValueWhitelisted(n, Settings.UpgradesWhitelist)
        elseif u:find("CURSE") then return isValueWhitelisted(n, Settings.CursesWhitelist) end
    end
    return false
end
local function checkAndVoteSelectParts()
    if not Settings.AutoFarmBeta or isAutoFarmProcessing then return end
    local selectFolder = workspace:FindFirstChild("Select")
    if not selectFolder or not (selectFolder:FindFirstChild("1") or selectFolder:FindFirstChild("2") or selectFolder:FindFirstChild("3")) then
        table.clear(selectionState.failedParts); selectionState.rerollCount = 0; return
    end
    isAutoFarmProcessing = true
    task.spawn(function()
        pcall(function()
            local maxRerolls, maxIter, iteration = 5, 25, 0
            local function getBoardState()
                local s = workspace:FindFirstChild("Select"); if not s then return "" end
                local p1, p2 = s:FindFirstChild("1"), s:FindFirstChild("2")
                return (p1 and tostring(p1:GetAttribute("ChoiceName")) or "") .. "|" .. (p2 and tostring(p2:GetAttribute("ChoiceName")) or "")
            end
            local function attemptBuy(name)
                local attempts, initial = 0, getBoardState()
                while attempts < 4 and Settings.AutoFarmBeta do
                    local s = workspace:FindFirstChild("Select"); if not s then return true end
                    local p = s:FindFirstChild(name); if not p then return true end
                    interactWithPart(p); attempts += 1
                    if attempts < 4 then task.wait(1.5) end
                    local new = getBoardState()
                    if name == "Reroll" then
                        if new ~= initial then return true end
                    else
                        if not s:FindFirstChild(name) or new ~= initial then return true end
                    end
                end
                selectionState.failedParts[name] = true; return false
            end
            while Settings.AutoFarmBeta and iteration < maxIter do
                iteration += 1
                selectFolder = workspace:FindFirstChild("Select"); if not selectFolder then break end
                local reroll = selectFolder:FindFirstChild("Reroll")
                local p3 = selectFolder:FindFirstChild("3")
                local target, anyWL = nil, hasAnyActiveWhitelist()
                local isCE, activeSpecific = false, false
                for _, n in ipairs({"1","2"}) do
                    local p = selectFolder:FindFirstChild(n)
                    if p then
                        local ct = tostring(p:GetAttribute("ChoiceType") or "")
                        if ct:upper():find("CURSE") then isCE = true; activeSpecific = (Settings.CursesWhitelist and next(Settings.CursesWhitelist) ~= nil); break
                        elseif ct:upper():find("ENEM") then isCE = true; activeSpecific = (Settings.EnemiesWhitelist and next(Settings.EnemiesWhitelist) ~= nil); break end
                    end
                end
                for _, n in ipairs({"1","2"}) do
                    if not selectionState.failedParts[n] then
                        local p = selectFolder:FindFirstChild(n)
                        if p then
                            local cn = tostring(p:GetAttribute("ChoiceName") or "")
                            if cn:lower():find("medalcurse") then target = n; break end
                        end
                    end
                end
                if not target then
                    for _, n in ipairs({"1","2"}) do
                        if not selectionState.failedParts[n] then
                            local p = selectFolder:FindFirstChild(n)
                            if p and checkPartMatch(p) then target = n; break end
                        end
                    end
                end
                if not target and not anyWL then
                    local vp = {}
                    for _, n in ipairs({"1","2"}) do
                        if not selectionState.failedParts[n] and selectFolder:FindFirstChild(n) then table.insert(vp, n) end
                    end
                    if #vp > 0 then target = vp[math.random(1, #vp)] end
                end
                if target then
                    if attemptBuy(target) then continue end
                else
                    if reroll and selectionState.rerollCount < maxRerolls and anyWL and not selectionState.failedParts["Reroll"] then
                        if not isCE then
                            if attemptBuy("Reroll") then
                                selectionState.rerollCount += 1
                                selectionState.failedParts["1"] = nil; selectionState.failedParts["2"] = nil
                                continue
                            end
                        end
                    end
                    if isCE then
                        if p3 and not selectionState.failedParts["3"] then
                            if attemptBuy("3") then continue end
                        else
                            local vp = {}
                            for _, n in ipairs({"1","2"}) do
                                if not selectionState.failedParts[n] and selectFolder:FindFirstChild(n) then table.insert(vp, n) end
                            end
                            if #vp > 0 then
                                if attemptBuy(vp[math.random(1, #vp)]) then continue end
                            end
                        end
                    end
                    if p3 and not selectionState.failedParts["3"] then attemptBuy("3") end
                    break
                end
            end
            beaconFiredTime = os.clock()
            local start = respawnCounter
            while isAutoFarmProcessing do
                if (respawnCounter - start) >= 2 then break end
                if beaconFiredTime and (os.clock() - beaconFiredTime) >= 5 then break end
                task.wait(0.1)
            end
        end)
        isAutoFarmProcessing = false
    end)
end

local function logSelectAttributes()
    local selectFolder = workspace:FindFirstChild("Select"); if not selectFolder then return end
    local cat = {curses={},upgrades={},enemies={},other={}}; local found = false
    for _, n in ipairs({"1","2","3"}) do
        local p = selectFolder:FindFirstChild(n)
        if p then
            local cn, ct, ci = tostring(p:GetAttribute("ChoiceName") or "N/A"), tostring(p:GetAttribute("ChoiceType") or "N/A"), tostring(p:GetAttribute("itemIndex") or "N/A")
            local key = string.format("%s_%s_%s", cn, ct, ci)
            if not loggedAttributes[key] then
                loggedAttributes[key] = true; found = true
                local e = string.format('["%s", "%s", "%s"]', cn, ct, ci)
                local lt = ct:lower()
                if lt:find("curse") then table.insert(cat.curses, e)
                elseif lt:find("upgrade") then table.insert(cat.upgrades, e)
                elseif lt:find("enemi") then table.insert(cat.enemies, e)
                else table.insert(cat.other, e) end
            end
        end
    end
    if found then
        local out = {}
        if #cat.curses > 0 then table.insert(out, "Curses:\n" .. table.concat(cat.curses, "\n")) end
        if #cat.upgrades > 0 then table.insert(out, "Upgrades:\n" .. table.concat(cat.upgrades, "\n")) end
        if #cat.enemies > 0 then table.insert(out, "Enemies:\n" .. table.concat(cat.enemies, "\n")) end
        if #cat.other > 0 then table.insert(out, "Other:\n" .. table.concat(cat.other, "\n")) end
        if #out > 0 then
            local full = table.concat(out, "\n\n") .. "\n\n"
            print("[Debug Attributes]:\n" .. full)
            if writefile and appendfile then
                pcall(function()
                    if not isfile or not isfile("SelectAttributesLog.txt") then writefile("SelectAttributesLog.txt", full)
                    else appendfile("SelectAttributesLog.txt", full) end
                end)
            end
        end
    end
end

local function applyTileConnections()
    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("CurrentRooms") or workspace
    for _, obj in ipairs(mapFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            local ln = obj.Name:lower()
            if ln:find("flesh") or ln:find("ice") or ln:find("tile") then obj.CanTouch = not antiFleshTilesEnabled end
        end
    end
end

local function createProtectionSphere(target, radius, color)
    local sphere = Instance.new("Part")
    sphere.Name = "SafeProtectionSphere"
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(radius*2, radius*2, radius*2)
    sphere.CFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
    sphere.Anchored = true; sphere.CanCollide = true; sphere.CanTouch = true
    sphere.Material = Enum.Material.Plastic
    sphere.Color = color or Color3.fromRGB(0, 170, 255)
    sphere.Transparency = 0; sphere.Parent = protectionFolder
    return sphere
end
local function protectTripmine(trip)
    if activeTripmineProtections[trip] or (trip:IsA("BasePart") and trip.Transparency == 1) then return end
    local size = trip:IsA("BasePart") and trip.Size.X or 3
    local radius = (size + 5) / 2
    local sphere = createProtectionSphere(trip, radius, Color3.fromRGB(0, 255, 150))
    activeTripmineProtections[trip] = {sphere = sphere, radius = radius}
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
    activeBulletProtections[b] = {sphere = sphere, radius = radius}
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
            if tripmines then for _, m in ipairs(tripmines:GetChildren()) do protectTripmine(m) end end
            if goldentripmines then for _, m in ipairs(goldentripmines:GetChildren()) do protectTripmine(m) end end
        else
            if next(activeTripmineProtections) then
                for _, d in pairs(activeTripmineProtections) do if d.sphere then d.sphere:Destroy() end end
                table.clear(activeTripmineProtections)
            end
        end
        if pb and bullets then for _, b in ipairs(bullets:GetChildren()) do protectBullet(b) end
        else
            if next(activeBulletProtections) then
                for _, d in pairs(activeBulletProtections) do if d.sphere then d.sphere:Destroy() end end
                table.clear(activeBulletProtections)
            end
        end
    end
    for t, d in pairs(activeTripmineProtections) do
        if t and t.Parent and d.sphere then d.sphere.CFrame = t:IsA("BasePart") and t.CFrame or t:GetPivot() end
    end
    for t, d in pairs(activeBulletProtections) do
        if t and t.Parent and d.sphere then d.sphere.CFrame = t:IsA("BasePart") and t.CFrame or t:GetPivot() end
    end
end

-- =====================================================================
-- GIFT ENGINE
-- =====================================================================
local Library
local function notif(msg, title)
    if Library and Library.Notify then Library:Notify(string.format("[%s]: %s", title or "System", msg), 3) end
end
local giftCache, giftCacheBuilt, lastFullScan = {}, false, 0
local FULL_SCAN_INTERVAL = 1.2
local GIFT_Y_MIN, GIFT_Y_MAX, GIFT_DIST_MAX = -2000, 5000, 60000
local collectedGifts = {}
local COLLECTED_TIMEOUT = 8
local function classifyGift(obj)
    if not obj or not obj.Parent then return nil end
    local ln = obj.Name:lower()
    if not (ln:find("gift") or ln:find("present")) then return nil end
    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true) or (obj.IsA and obj:IsA("Model") and obj.PrimaryPart)
    if not part then return nil end
    return {obj = obj, part = part, isGolden = (ln:find("golden") ~= nil) or (ln:find("gold") ~= nil)}
end
local function rebuildGiftCache()
    local new = {}
    local roots = {workspace:FindFirstChild("Item_Pools"), workspace:FindFirstChild("CurrentRooms"), workspace:FindFirstChild("Gifts"), workspace:FindFirstChild("SpawnedGifts")}
    local function scan(c) if not c then return end for _, ch in ipairs(c:GetDescendants()) do local i = classifyGift(ch); if i then new[#new+1] = i end end end
    for _, r in ipairs(roots) do scan(r) end
    for _, ch in ipairs(workspace:GetChildren()) do local i = classifyGift(ch); if i then new[#new+1] = i end end
    giftCache, giftCacheBuilt, lastFullScan = new, true, os.clock()
end
local function pruneCache()
    local pruned, present = {}, {}
    for _, i in ipairs(giftCache) do
        if i.obj and i.obj.Parent and i.part and i.part.Parent then pruned[#pruned+1] = i; present[i.obj] = true end
    end
    giftCache = pruned
    local now = os.clock()
    for g, ts in pairs(collectedGifts) do
        if not present[g] or (now - ts) > COLLECTED_TIMEOUT then collectedGifts[g] = nil end
    end
end
local function refreshGiftCache(force)
    if force or not giftCacheBuilt or (os.clock() - lastFullScan) >= FULL_SCAN_INTERVAL then rebuildGiftCache() end
    pruneCache()
end
local function isValidGiftPos(pos)
    if pos == Vector3.new(0,0,0) then return false end
    if pos.Y < GIFT_Y_MIN or pos.Y > GIFT_Y_MAX then return false end
    if pos.Magnitude > GIFT_DIST_MAX then return false end
    return true
end
local function getClosestGift(golden, blacklist)
    local root = getRoot(getChar(plr)); if not root then return nil end
    local rootPos = root.Position
    local closest, info, shortest = nil, nil, math.huge
    for _, i in ipairs(giftCache) do
        if i.obj and i.obj.Parent and i.part and i.part.Parent then
            if i.isGolden == golden and not blacklist[i.obj] and not collectedGifts[i.obj] then
                local pos = i.part.Position
                if isValidGiftPos(pos) then
                    local d = (pos - rootPos).Magnitude
                    if d < shortest then shortest = d; closest = i.obj; info = i end
                end
            end
        end
    end
    return closest, info
end
local function walkToPositionPathfinding(target)
    local char = getChar(plr); local root = getRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or not target or target == Vector3.new(0,0,0) then return false end
    hum.WalkSpeed = Settings.LegitSpeed
    local path = PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true, AgentJumpHeight=10, AgentMaxSlope=45})
    local ok = pcall(function() path:ComputeAsync(root.Position, target) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not tweening and not Settings.AutoBeacon then hum:MoveTo(root.Position); return false end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position)
            local done = false
            local conn = hum.MoveToFinished:Connect(function() done = true end)
            local t = 0
            while not done and (tweening or Settings.AutoBeacon) do task.wait(0.05); t += 0.05; if t > 3 then break end end
            conn:Disconnect()
            if not done then break end
        end
        return true
    else
        hum:MoveTo(target); task.wait(0.5); return false
    end
end
local function moveToGift(info)
    if not info or not info.part or not info.part.Parent then return nil end
    if Settings.LegitCollection then walkToPositionPathfinding(info.part.Position); return nil end
    local root = getRoot(getChar(plr)); if not root then return nil end
    local target = info.part.CFrame + Vector3.new(0, 3, 0)
    if Settings.InstantTeleport then
        root.CFrame = target
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        return nil
    end
    local d = (info.part.Position - root.Position).Magnitude
    local dur = math.max(0.01, d / Settings.TweenSpeed)
    local ti = TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tw = TweenService:Create(root, ti, {CFrame = target}); tw:Play(); return tw
end
local function handleSpawnNavigation()
    for _, sn in ipairs({"Spawn", "SpawnLocation"}) do
        local s = workspace:FindFirstChild(sn)
        if s and s:IsA("BasePart") and s.Position ~= Vector3.new(0,0,0) then
            local root = getRoot(getChar(plr))
            if root then
                if Settings.LegitCollection then walkToPositionPathfinding(s.Position)
                else root.CFrame = s.CFrame + Vector3.new(0, 5, 0); root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
                return true
            end
        end
    end
    return false
end
local function stopAllCollection()
    collectionRunId += 1; tweening = false
    Settings.CollectNormal = false; Settings.CollectGolden = false; Settings.LegitCollection = false
    if currentTween then pcall(function() currentTween:Cancel() end); currentTween = nil end
    local n = getToggle("CollectNormalToggle"); if n then n:SetValue(false) end
    local g = getToggle("CollectGoldenToggle"); if g then g:SetValue(false) end
    local l = getToggle("LegitCollectionToggle"); if l then l:SetValue(false) end
end
if collectGift then
    pcall(function()
        if collectGift:IsA("RemoteEvent") then
            local c = collectGift.OnClientEvent:Connect(function(...)
                for _, a in ipairs({...}) do if typeof(a) == "Instance" then collectedGifts[a] = os.clock(); blacklistedGifts[a] = true end end
            end)
            table.insert(scriptConnections, c)
        elseif collectGift:IsA("BindableEvent") then
            local c = collectGift.Event:Connect(function(...)
                for _, a in ipairs({...}) do if typeof(a) == "Instance" then collectedGifts[a] = os.clock(); blacklistedGifts[a] = true end end
            end)
            table.insert(scriptConnections, c)
        end
    end)
end
local function startCollectionEngine(mode)
    collectionRunId += 1
    local myRunId = collectionRunId
    tweening = true
    table.clear(blacklistedGifts)
    task.spawn(function()
        local recent, ATT = {}, 0.5
        local empty, MAXE = 0, 4
        local currentTarget = mode == "golden" and "golden" or "normal"
        local fallbackNotif, giveupNotif = false, false
        refreshGiftCache(true)
        local function stale() return myRunId ~= collectionRunId end
        local function has(g) for _, i in ipairs(giftCache) do if i.isGolden == g and i.obj and i.obj.Parent and i.part and i.part.Parent then if isValidGiftPos(i.part.Position) and not collectedGifts[i.obj] then return true end end end return false end
        local function fallback() if fallbackNotif then return end fallbackNotif = true; if notifOn then notif("Falling back to Golden Gifts.", "Collection") end end
        local function giveup(g) if giveupNotif then return end giveupNotif = true; if notifOn then notif(g and "No Golden Gifts. Stopping." or "No gifts. Stopping.", "Collection") end if Settings.AutoBeacon then handleSpawnNavigation() end stopAllCollection() end
        while tweening and not stale() do
            local wantN, wantG = Settings.CollectNormal, Settings.CollectGolden
            if not wantN and not wantG then break end
            if mode == "golden" then currentTarget = "golden"
            elseif mode == "normal" then currentTarget = "normal"
            else
                if not wantN then currentTarget = "golden"
                elseif not wantG then currentTarget = "normal"
                else if currentTarget == "normal" and not has(false) then fallback(); currentTarget = "golden" end end
            end
            local isG = (currentTarget == "golden")
            if not has(isG) then
                if has(not isG) then
                    if mode == "auto" then
                        if currentTarget == "normal" then fallback() end
                        currentTarget = (not isG) and "golden" or "normal"; isG = not isG
                    end
                else
                    empty += 1
                    if empty >= MAXE then giveup(isG); return end
                    task.wait(0.15); continue
                end
            end
            local root = getRoot(getChar(plr)); if not root then task.wait(0.2); continue end
            if not Settings.LegitCollection then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
            refreshGiftCache(false); if stale() then break end
            local now = os.clock()
            for o, t in pairs(recent) do if now - t > ATT then recent[o] = nil end end
            local gift, info = getClosestGift(isG, recent)
            if not gift then
                empty += 1
                if empty >= MAXE then
                    if mode == "auto" then
                        if has(not isG) then
                            if currentTarget == "normal" then fallback() end
                            currentTarget = (not isG) and "golden" or "normal"; empty = 0
                        else giveup(isG); return end
                    else giveup(isG); return end
                end
                task.wait(0.12); continue
            end
            empty = 0; recent[gift] = os.clock()
            currentTween = moveToGift(info)
            if currentTween then
                local done = false
                local c = currentTween.Completed:Connect(function() done = true end)
                local t = 0
                while not done and tweening and not stale() do task.wait(0.02); t += 0.02; if t > 3 then break end end
                if c then c:Disconnect() end
                currentTween = nil
            else task.wait(0.03) end
            if stale() then break end
            if gift and gift.Parent then collectedGifts[gift] = os.clock() end
            if gift then recent[gift] = os.clock() end
            if Settings.DelayBetweenGifts and Settings.DelayBetweenGifts > 0 then task.wait(Settings.DelayBetweenGifts) end
        end
        if not stale() then stopAllCollection() end
    end)
end
collectGiftsEngine = function(gt) if gt then startCollectionEngine("golden") else startCollectionEngine("auto") end end

-- =====================================================================
-- ENEMY UTILS
-- =====================================================================
local function disableEnemyEntity(entity)
    if not entity or not (entity:IsA("Model") or entity:IsA("Folder") or entity:IsA("BasePart")) then return end
    local h = entity:FindFirstChildOfClass("Humanoid")
    if h then h:ChangeState(Enum.HumanoidStateType.Physics); h.WalkSpeed = 0; h.PlatformStand = true end
    for _, o in ipairs(entity:GetChildren()) do
        if o:IsA("Script") or o:IsA("LocalScript") then o.Disabled = true
        elseif o:IsA("BasePart") then o.CanCollide = false; o.Anchored = true end
    end
end
local function disableEnemy(name, destroy, brk, dis)
    local t = enemies and enemies:FindFirstChild(name); if not t then return false end
    if destroy then t:Destroy(); return true
    elseif brk or dis then disableEnemyEntity(t); return true end
    return false
end
local function processClientSideEnemies()
    local ct = {"nilEnemy","nilMirage"}
    local dt = {"Kolona","Operator","scrapmaw","skinwalker","sigil"}
    for _, c in ipairs({Camera, enemies, enemiesFolder}) do
        if c then
            for _, ch in ipairs(c:GetChildren()) do
                local ln = ch.Name:lower()
                for _, t in ipairs(ct) do if ln == t:lower() then disableEnemyEntity(ch) end end
                for _, t in ipairs(dt) do if ln == t:lower() then ch:Destroy() end end
            end
        end
    end
end
local function processPortedDisables()
    local pools = {workspace, dynamicItems, enemies, beacons}
    local function cd(i)
        if not i or not i.Parent then return end
        local ln = i.Name:lower()
        if disableSeaMines and (ln:find("seamine") or ln:find("sea_mine") or ln:find("mine")) and not ln:find("trip") then pcall(function() i:Destroy() end); return end
        if disableVoidImplosions and (ln:find("voidimplosion") or ln:find("implosion")) then pcall(function() i:Destroy() end); return end
        if disableFakeBeacons and (ln:find("fakebeacon") or ln:find("fake_beacon") or (ln:find("beacon") and ln:find("fake"))) then pcall(function() i:Destroy() end); return end
        if disableOblivion and (ln:find("oblivion")) then pcall(function() i:Destroy() end); return end
    end
    for _, c in ipairs(pools) do
        if c then
            for _, ch in ipairs(c:GetChildren()) do
                cd(ch)
                if ch:IsA("Folder") or ch:IsA("Model") then for _, sc in ipairs(ch:GetChildren()) do cd(sc) end end
            end
        end
    end
end
local function handleEnemy(enemy)
    if not enemy then return end
    local n = enemy.Name
    if auto_destroy[n] then disableEnemy(n, true, false, false)
    elseif auto_break[n] then disableEnemy(n, false, true, false)
    elseif auto_disable[n] then disableEnemy(n, false, false, true) end
end
local function purgeExistingEnemies()
    local count = 0
    if enemies then for _, e in ipairs(enemies:GetChildren()) do if e.Name ~= "Guardian" then e:Destroy(); count += 1 end end end
    return count
end

-- =====================================================================
-- ANTI-VOID
-- =====================================================================
local function processAntiVoid()
    if not av then return end
    local root = getRoot(getChar(plr))
    local killVoid = workspace:FindFirstChild("KillVoid")
    local thr = killVoid and (killVoid.Position.Y + 5) or -100
    if root and root.Position.Y <= thr then
        if antiVoidSelection == 1 then handleSpawnNavigation()
        elseif antiVoidSelection == 2 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, lp, root.AssemblyLinearVelocity.Z)
        elseif antiVoidSelection == 3 then
            refreshGiftCache(true)
            local best, sd = nil, math.huge
            for _, i in ipairs(giftCache) do
                if i.obj and i.obj.Parent and i.part and i.part.Parent and isValidGiftPos(i.part.Position) then
                    local d = (i.part.Position - root.Position).Magnitude
                    if d < sd then sd = d; best = i end
                end
            end
            if best then root.CFrame = best.part.CFrame + Vector3.new(0, 5, 0) else handleSpawnNavigation() end
        end
    end
end

connections["MainHeartbeat"] = RunService.Heartbeat:Connect(function()
    processProtections()
    processAntiVoid()
    checkAndVoteSelectParts()
    processAutoPylon()
    destroyRazorbloom()
    local root = getRoot(getChar(plr))
    if root and velov then
        local vel = root.AssemblyLinearVelocity * Vector3.new(1, 0.5, 1)
        local spd = vel.Magnitude
        if spd > 0 then
            local dir = vel.Unit
            local len = math.clamp(spd * 0.5, 0.5, 150)
            velocityPart.Size = Vector3.new(0.2, 0.2, len)
            velocityPart.CFrame = CFrame.lookAt((root.Position + (root.Position + dir * len)) / 2, root.Position + dir * len)
            velocityPart.Transparency = 0
            vpBox.Size = velocityPart.Size; vpBox.Transparency = 0.25
        else velocityPart.Transparency = 1; vpBox.Transparency = 1 end
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
Loading:SetCurrentStep(1); Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. plr.Name)
Loading.Sidebar:AddLabel("Executor: " .. getExecutorName())
Loading.Sidebar:AddLabel("Version: v1")
Loading.Sidebar:AddLabel("Mode: " .. (isSupportedPlace and "Nullscape Gui" or "Universal Gui"))
Loading:SetCurrentStep(2); Loading:SetCurrentStep(3)
Loading:SetDescription("Script loaded successfully!"); Loading:SetCurrentStep(4); Loading:Continue()

local Window = Library:CreateWindow({
    Title = "Java's Null Gui",
    Footer = string.format("%s | %d | %s | v1", gameName, PlaceId, JobId ~= "" and JobId or "Solo"),
    Icon = "cat", Center = true, AutoShow = true,
})

local Tabs = {}
if isSupportedPlace then
    Tabs.Playerlist = Window:AddTab("Main", "paw-print")
    Tabs.Enemies    = Window:AddTab("Enemies", "triangle-alert")
    Tabs.Map        = Window:AddTab("Map", "map")
    Tabs.Upgrades   = Window:AddTab("Upgrades", "shield-plus")
    Tabs.Webhook    = Window:AddTab("Webhook", "webhook")
    Tabs.Debug      = Window:AddTab("Debug", "bug")
    Tabs.Credits    = Window:AddTab("Credits", "info")
    Tabs.Settings   = Window:AddTab("Settings", "settings")

    -- GIFTS
    local GiftGroup = Tabs.Playerlist:AddRightGroupbox("Gifts Collection")
    GiftGroup:AddLabel("<font color='#AAAAAA'><b>NOTE:</b> Finding gifts can be slow\n Use Instant TP for max collection.</font>")
    GiftGroup:AddToggle("AutoStartCollectingToggle", {Text = "<font color='#00FFCC'>Auto start collecting</font>", Default = Settings.AutoStartCollecting, Callback = function(Value)
        Settings.AutoStartCollecting = Value
        if Value then
            local sfx = SoundService:FindFirstChild("SFXFolder")
            local nls = sfx and sfx:FindFirstChild("NewLevel")
            if nls and nls:IsA("Sound") then
                if connections["AutoStartCollectingConn"] then connections["AutoStartCollectingConn"]:Disconnect() end
                connections["AutoStartCollectingConn"] = nls.Played:Connect(function()
                    if Settings.AutoStartCollecting then
                        Settings.CollectNormal = true
                        local t = getToggle("CollectNormalToggle"); if t then t:SetValue(true) end
                        collectGiftsEngine(false)
                        if notifOn then notif("NewLevel detected. Auto-collecting.", "Collection") end
                    end
                end)
                table.insert(scriptConnections, connections["AutoStartCollectingConn"])
            end
        else
            if connections["AutoStartCollectingConn"] then connections["AutoStartCollectingConn"]:Disconnect(); connections["AutoStartCollectingConn"] = nil end
        end
    end})
    GiftGroup:AddToggle("CollectNormalToggle", {Text = "<font color='#AA55FF'>Collect Normal Gifts</font>", Default = Settings.CollectNormal, Callback = function(Value)
        Settings.CollectNormal = Value
        if Value then collectGiftsEngine(false) else if not Settings.CollectGolden and tweening then stopAllCollection() end end
    end})
    GiftGroup:AddToggle("CollectGoldenToggle", {Text = "<font color='#FFCC00'>Collect Golden Gifts</font>", Default = Settings.CollectGolden, Callback = function(Value)
        Settings.CollectGolden = Value
        if Value then
            if not Settings.CollectNormal then collectGiftsEngine(true) else collectGiftsEngine(false) end
        else if not Settings.CollectNormal and tweening then stopAllCollection() end end
    end})
    GiftGroup:AddToggle("LegitCollectionToggle", {Text = "<font color='#FF4444'>Legit collection (slow)</font>", Default = Settings.LegitCollection, Callback = function(Value)
        Settings.LegitCollection = Value
        if Value then Library:Notify("Legit Pathfinding Mode Enabled.", 2) end
    end})
    GiftGroup:AddDivider("Timing")
    GiftGroup:AddInput("LegitSpeedInput", {Default = tostring(Settings.LegitSpeed), Numeric = true, Finished = true, Text = "Legit WalkSpeed", Callback = function(V)
        local n = tonumber(V); if n and n > 0 then Settings.LegitSpeed = n; Library:Notify("Legit Speed: " .. n, 2) end
    end})
    GiftGroup:AddToggle("InstantTPToggle", {Text = "Instant Teleport Collection", Default = Settings.InstantTeleport, Callback = function(V) Settings.InstantTeleport = V end})
    GiftGroup:AddInput("TweenSpeedInput", {Default = tostring(Settings.TweenSpeed), Numeric = true, Finished = true, Text = "Tween Speed", Callback = function(V)
        local n = tonumber(V); if n and n > 0 then Settings.TweenSpeed = n end
    end})
    GiftGroup:AddInput("TeleportDelayInput", {Default = tostring(Settings.DelayBetweenGifts), Numeric = true, Finished = true, Text = "Teleport Delay (s)", Callback = function(V)
        local n = tonumber(V); if n and n >= 0 then Settings.DelayBetweenGifts = n end
    end})
    GiftGroup:AddDivider("Actions")
    GiftGroup:AddToggle("AutoBeaconToggle", {Text = "<font color='#00FF00'>Walk/TP To Beacon On Finish</font>", Default = Settings.AutoBeacon, Callback = function(V) Settings.AutoBeacon = V end})
    GiftGroup:AddButton({Text = "<font color='#FF4444'>Cancel Gift Collection</font>", Func = function() stopAllCollection(); Library:Notify("Cancelled.", 2) end})

    local FarmGroup = Tabs.Playerlist:AddLeftGroupbox("Farm")
    FarmGroup:AddToggle("AutoFarmBetaToggle", {Text = "auto farm (beta)", Default = Settings.AutoFarmBeta, Callback = function(V)
        Settings.AutoFarmBeta = V
        local a, b, c, d = getToggle("AutoStartCollectingToggle"), getToggle("AutoBeaconToggle"), getToggle("CollectNormalToggle"), getToggle("DeleteAllEnemies")
        if V then
            if a then a:SetValue(true) else Settings.AutoStartCollecting = true end
            if b then b:SetValue(true) else Settings.AutoBeacon = true end
            if c then c:SetValue(true) else Settings.CollectNormal = true end
            if d then d:SetValue(true) else deleteAllEnemies = true end
            Library:Notify("Auto Farm Enabled.", 2)
        else
            if a then a:SetValue(false) else Settings.AutoStartCollecting = false end
            if b then b:SetValue(false) else Settings.AutoBeacon = false end
            if c then c:SetValue(false) else Settings.CollectNormal = false end
            if d then d:SetValue(false) else deleteAllEnemies = false end
            Library:Notify("Auto Farm Disabled.", 2)
        end
    end})
    FarmGroup:AddToggle("AutoPylonToggle", {Text = "Teleport to pylon", Default = Settings.AutoPylon, Callback = function(V)
        Settings.AutoPylon = V
        if V then Library:Notify("Auto Pylon Enabled.", 2); teleportToNearestPylon() end
    end})
    FarmGroup:AddButton({Text = "Teleport to Pylon", Func = function() teleportToNearestPylon() end})
    FarmGroup:AddInput("TargetLevelVoidInput", {Text = "Auto Void at Level", Default = "", Numeric = true, Finished = false, Placeholder = "Target Level", Callback = function(V)
        local n = tonumber(V)
        if n and n > 0 then Settings.TargetLevel = n; Library:Notify("Auto Void at " .. n, 2)
        else Settings.TargetLevel = nil end
    end})

    local WhitelistGroup = Tabs.Playerlist:AddLeftGroupbox("Vote Whitelists")
    WhitelistGroup:AddDropdown("EnemiesWhitelistDropdown", {Values = EnemiesList, Multi = true, Text = "Enemies Whitelist", Callback = function(V) Settings.EnemiesWhitelist = V end})
    WhitelistGroup:AddDropdown("CursesWhitelistDropdown", {Values = CursesList, Multi = true, Text = "Curses Whitelist", Callback = function(V) Settings.CursesWhitelist = V end})
    WhitelistGroup:AddDropdown("UpgradesWhitelistDropdown", {Values = UpgradesList, Multi = true, Text = "Upgrades Whitelist", Callback = function(V) Settings.UpgradesWhitelist = V end})

    local PlayerGroup = Tabs.Playerlist:AddRightGroupbox("Player Features")
    PlayerGroup:AddToggle("VelocityVisualizerToggle", {Text = "Velocity Visualizer", Default = false, Callback = function(V)
        velov = V
        if not V then velocityPart.Transparency = 1; vpBox.Transparency = 1 end
    end})
    PlayerGroup:AddToggle("DestroyRazorbloomToggle", {Text = "<font color='#FF6666'>Destroy Razorbloom (VISIBLE)</font>", Default = nrb, Callback = function(V)
        nrb = V
        if V then destroyRazorbloom(); Library:Notify("Razorbloom Destroyer on.", 2) end
    end})
    PlayerGroup:AddSlider("GiftCollectionRange", {Text = "Gift collection range", Default = 1, Min = 0, Max = 10, Rounding = 0, Callback = function(V)
        applyUpgradeValue("GiftMagnet", (V == 0) and 1 or (V * 30), upgradeLabels["GiftMagnet"])
    end})

    -- NEW: Players in Server list
    local PlayersGroup = Tabs.Playerlist:AddRightGroupbox("Players in Server")
    local playersLabel = PlayersGroup:AddLabel("Loading...")
    task.spawn(function()
        while task.wait(2) do
            if playersLabel then
                local list = Players:GetPlayers()
                table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
                local lines = {}
                for _, p in ipairs(list) do
                    local tag = (p == plr) and " <font color='#00FF88'>(you)</font>" or ""
                    local ping = ""
                    pcall(function()
                        if p.GetNetworkPing then
                            local ms = math.floor((p:GetNetworkPing() or 0) * 1000)
                            if ms > 0 then ping = string.format(" <font color='#AAAAAA'>%dms</font>", ms) end
                        end
                    end)
                    table.insert(lines, "• " .. p.Name .. tag .. ping)
                end
                playersLabel:SetText(string.format("<b>%d player(s) online:</b>\n%s", #list, table.concat(lines, "\n")))
            end
        end
    end)

    -- ENEMIES
    local EG = Tabs.Enemies:AddLeftGroupbox("Enemy Controls")
    EG:AddToggle("DisableAllEnemies", {Text = "Disable All Enemy AI", Default = false, Callback = function(V)
        disableAllEnemies = V
        if V then
            if enemies then
                for _, e in ipairs(enemies:GetChildren()) do disableEnemyEntity(e) end
                connections["DisableEnemies"] = enemies.ChildAdded:Connect(function(c) if disableAllEnemies then task.wait(0.1); disableEnemyEntity(c) end end)
                table.insert(scriptConnections, connections["DisableEnemies"])
            end
        else
            if connections["DisableEnemies"] then connections["DisableEnemies"]:Disconnect(); connections["DisableEnemies"] = nil end
        end
    end})
    EG:AddToggle("DisableClientEnemies", {Text = "Disable client sided enemies", Default = false, Callback = function(V)
        disableClientEnemies = V
        if V then
            processClientSideEnemies()
            connections["DisableClientEnemies"] = RunService.Heartbeat:Connect(function() if disableClientEnemies then processClientSideEnemies() end end)
            table.insert(scriptConnections, connections["DisableClientEnemies"])
        else
            if connections["DisableClientEnemies"] then connections["DisableClientEnemies"]:Disconnect(); connections["DisableClientEnemies"] = nil end
        end
    end})
    EG:AddToggle("DeleteAllEnemies", {Text = "Delete All Enemies", Default = false, Callback = function(V)
        deleteAllEnemies = V
        if V then
            local g = getToggle("Guardian_Protection"); if g then g:SetValue(true) end
            if enemies then
                purgeExistingEnemies()
                connections["DeleteEnemies"] = enemies.ChildAdded:Connect(function(c)
                    if deleteAllEnemies then task.defer(function() if c and c.Parent and c.Name ~= "Guardian" then c:Destroy() end end) end
                end)
                table.insert(scriptConnections, connections["DeleteEnemies"])
            end
        else
            if connections["DeleteEnemies"] then connections["DeleteEnemies"]:Disconnect(); connections["DeleteEnemies"] = nil end
        end
    end})
    EG:AddDivider("Actions")
    EG:AddButton({Text = "Purge All Enemies", Func = function() local n = purgeExistingEnemies(); Library:Notify("Purged " .. n, 3) end})
    EG:AddDivider("Active Enemies")
    local activeLbl = EG:AddLabel("Scanning...")
    task.spawn(function()
        while task.wait(1.5) do
            if not enemies or #enemies:GetChildren() == 0 then activeLbl:SetText("<font color='#AAAAAA'>No active enemies</font>")
            else
                local lines = {}
                for _, e in ipairs(enemies:GetChildren()) do
                    local h = e:FindFirstChildOfClass("Humanoid")
                    local dis = false
                    if h and h.PlatformStand then dis = true
                    elseif e:FindFirstChildOfClass("Script") and e:FindFirstChildOfClass("Script").Disabled then dis = true end
                    table.insert(lines, dis and string.format("<font color='#AAAAAA'>%s (Disabled)</font>", e.Name) or string.format("<font color='#00FF00'>%s (Active)</font>", e.Name))
                end
                activeLbl:SetText(table.concat(lines, "\n"))
            end
        end
    end)
    task.spawn(function() while task.wait(1) do processPortedDisables() end end)

    local DEG = Tabs.Enemies:AddRightGroupbox("Granular Enemy Options")
    task.spawn(function() while task.wait(1) do if enemies then for _, e in ipairs(enemies:GetChildren()) do handleEnemy(e) end end end end)
    if enemies then
        connections["GranularChildAdded"] = enemies.ChildAdded:Connect(function(c) task.wait(0.1); handleEnemy(c) end)
        table.insert(scriptConnections, connections["GranularChildAdded"])
    end
    local function addEnemy(g, n)
        g:AddDivider(n)
        if auto_disable[n] ~= nil then g:AddToggle(n.."_Disable", {Text = "Auto Disable", Default = auto_disable[n], Callback = function(v) auto_disable[n] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(n)) end end}) end
        if auto_break[n] ~= nil then g:AddToggle(n.."_Break", {Text = "Auto Break AI", Default = auto_break[n], Callback = function(v) auto_break[n] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(n)) end end}) end
        if auto_destroy[n] ~= nil then g:AddToggle(n.."_Destroy", {Text = "Auto Destroy", Default = auto_destroy[n], Callback = function(v) auto_destroy[n] = v; if v then handleEnemy(enemies and enemies:FindFirstChild(n)) end end}) end
    end
    for _, n in ipairs({"Bell","Mart","Skinwalker","Springer","ICBM","Baby","Flesh"}) do addEnemy(DEG, n) end
    DEG:AddDivider("Guardian Options")
    DEG:AddToggle("Guardian_Immunity", {Text = "Guardian Death Immunity", Default = false, Callback = function(V) guardianImmunity = V; Library:Notify("Guardian Immunity " .. (V and "ON" or "OFF"), 2) end})
    DEG:AddToggle("Shadow_Guardian_Immunity", {Text = "Shadow Guardian Death Immunity", Default = false, Callback = function(V) voidboundGuardianImmunity = V; Library:Notify("Shadow Guardian Immunity " .. (V and "ON" or "OFF"), 2) end})
    DEG:AddToggle("Guardian_Protection", {Text = "Bullet Protection Sphere", Default = pb, Callback = function(V)
        pb = V
        if not V then for _, d in pairs(activeBulletProtections) do if d.sphere then d.sphere:Destroy() end end; table.clear(activeBulletProtections) end
    end})
    for _, n in ipairs({"Operator","Kolona","Telefragger","Sigil","Voidbreaker","Cadence","ShadowBaby","Scrapmaw","RealityBreak","Celestial"}) do addEnemy(DEG, n) end

    -- MAP
    local VG = Tabs.Map:AddLeftGroupbox("Void")
    VG:AddToggle("AntiVoid", {Text = "Anti Void", Default = false, Callback = function(V) av = V end})
    VG:AddDropdown("AntiVoidSetting", {Values = {"1. Teleport to Spawn", "2. Launch Up", "3. Closest Gift"}, Default = 1, Multi = false, Callback = function(V) antiVoidSelection = tonumber(string.split(V, ".")[1]) end})
    VG:AddSlider("LaunchPower", {Text = "Launch Power", Default = 500, Min = 10, Max = 1000, Rounding = 0, Callback = function(V) lp = V end})
    VG:AddToggle("VisibleVoid", {Text = "Visible Void", Default = false, Callback = function(V)
        local kv = workspace:FindFirstChild("KillVoid"); if kv then kv.Transparency = V and 0 or 1 end
    end})

    local MP = Tabs.Map:AddRightGroupbox("Map Defenses")
    MP:AddToggle("Tripmine_Protection", {Text = "Tripmine Safe Sphere", Default = pt, Callback = function(V)
        pt = V
        if not V then for _, d in pairs(activeTripmineProtections) do if d.sphere then d.sphere:Destroy() end end; table.clear(activeTripmineProtections) end
    end})
    MP:AddToggle("AntiFleshIceTiles", {Text = "Anti flesh/ice tiles", Default = false, Callback = function(V) antiFleshTilesEnabled = V; applyTileConnections() end})
    MP:AddToggle("PersistentTileConnections", {Text = "Persistent tile connections", Default = false, Callback = function(V)
        persistentTileConnections = V
        if V then
            if not persistentRespawnConnection then
                persistentRespawnConnection = plr.CharacterAdded:Connect(function() task.wait(1); if persistentTileConnections and antiFleshTilesEnabled then applyTileConnections() end end)
            end
        else
            if persistentRespawnConnection then persistentRespawnConnection:Disconnect(); persistentRespawnConnection = nil end
        end
    end})
    MP:AddDivider("Extra Disables")
    MP:AddToggle("DisableSeaMines", {Text = "Disable Sea Mines", Default = false, Callback = function(V) disableSeaMines = V end})
    MP:AddToggle("DisableVoidImplosions", {Text = "Disable Void Implosions", Default = false, Callback = function(V) disableVoidImplosions = V end})
    MP:AddToggle("DisableFakeBeacons", {Text = "Disable Fake Beacons", Default = false, Callback = function(V) disableFakeBeacons = V end})
    MP:AddToggle("DisableOblivion", {Text = "Disable Oblivion", Default = false, Callback = function(V) disableOblivion = V end})

    -- UPGRADES
    local UL = Tabs.Upgrades:AddLeftGroupbox("Upgrades Status")
    if UL.Container then UL.Container.AutomaticSize = Enum.AutomaticSize.Y end
    if fSignal then UL:AddLabel("Your exploit supports adding upgrades.") else UL:AddLabel("Your exploit doesn't support adding upgrades.") end
    UL:AddDivider("Active Upgrades List")
    local activeUpLbl = UL:AddLabel("None Active")
    local clientUpgrades = {"MatrixTetrahedron","Adrenaline","HighlightGifts","AdvancedGravityCoil","SportShoes","TheOrb","RealWings","GraceWings","RadarPlayer","RadarInstruments","HighlightTripmines","IceSkates","SwiftnessRing","GiftMagnet","SharkTail","EnemyOnTop","PocketBell","NinjaBelt","Helmet","DoubleJump","RadarAltars"}
    updateActiveUpgradesDisplay = function()
        local parts = {}
        for n, v in pairs(activeUpgrades) do if v > 0 then table.insert(parts, string.format("<font color='#0055ff'>%s</font>: %d", n, v)) end end
        local full = #parts > 0 and table.concat(parts, "\n") or "None Active"
        if activeUpLbl and type(activeUpLbl) == "table" and activeUpLbl.TextLabel then
            activeUpLbl.TextLabel.AutomaticSize = Enum.AutomaticSize.Y
            activeUpLbl.TextLabel.TextWrapped = true
        end
        activeUpLbl:SetText(full)
    end
    local function setupGuard(intv, n)
        if upgradeValueGuards[n] then upgradeValueGuards[n]:Disconnect(); upgradeValueGuards[n] = nil end
        upgradeValueGuards[n] = intv.Changed:Connect(function(v)
            if isSettingGuardValue[n] then return end
            local want = activeUpgrades[n]
            if want and v ~= want then isSettingGuardValue[n] = true; intv.Value = want; isSettingGuardValue[n] = false end
        end)
        table.insert(scriptConnections, upgradeValueGuards[n])
    end
    applyUpgradeValue = function(n, tv, lbl)
        local folder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local intv = folder and folder:FindFirstChild(n)
        tv = math.max(0, math.floor(tv or 0))
        if tv > 0 then
            activeUpgrades[n] = tv
            if intv then isSettingGuardValue[n] = true; intv.Value = tv; isSettingGuardValue[n] = false
            else intv = Instance.new("IntValue"); intv.Name = n; intv.Value = tv; if folder then intv.Parent = folder end end
            setupGuard(intv, n)
            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[n] = tv}) end
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[n] = tv}) end
                end)
            end
        else
            activeUpgrades[n] = nil
            if intv then intv:Destroy() end
            if upgradeValueGuards[n] then upgradeValueGuards[n]:Disconnect(); upgradeValueGuards[n] = nil end
            if events and events:FindFirstChild("UpgradesChanged") then
                pcall(function()
                    if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[n] = 0}) end
                    if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[n] = 0}) end
                end)
            end
        end
        if lbl then lbl:SetText("Current: " .. tv) end
        updateActiveUpgradesDisplay()
    end
    local function restoreAll()
        local folder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        for n, v in pairs(activeUpgrades) do
            if v > 0 and folder then
                local intv = folder:FindFirstChild(n)
                if not intv then intv = Instance.new("IntValue"); intv.Name = n; intv.Parent = folder end
                isSettingGuardValue[n] = true; intv.Value = v; isSettingGuardValue[n] = false
                setupGuard(intv, n)
                if events and events:FindFirstChild("UpgradesChanged") then
                    pcall(function()
                        if fSignal then fSignal(events.UpgradesChanged.OnClientEvent, {[n] = v}) end
                        if events.UpgradesChanged:IsA("RemoteEvent") then events.UpgradesChanged:FireServer({[n] = v}) end
                    end)
                end
            end
        end
        updateActiveUpgradesDisplay()
    end
    local cc = plr.CharacterAdded:Connect(function() task.wait(1); restoreAll() end)
    table.insert(scriptConnections, cc)
    local ULG = Tabs.Upgrades:AddRightGroupbox("Available Upgrades")
    for _, u in ipairs(clientUpgrades) do
        ULG:AddDivider(u)
        local init = 0
        local folder = ReplicatedStorage:FindFirstChild("UpgradeFolder") and ReplicatedStorage.UpgradeFolder:FindFirstChild("Upgrades")
        local ex = folder and folder:FindFirstChild(u)
        if ex then init = ex.Value; if init > 0 then activeUpgrades[u] = init; setupGuard(ex, u) end end
        local lbl = ULG:AddLabel("Current: " .. init)
        upgradeLabels[u] = lbl
        ULG:AddInput(u .. "_Input", {Default = tostring(init), Numeric = true, Finished = true, Text = "Set Amount", Callback = function(V)
            local n = tonumber(V); if n then applyUpgradeValue(u, n, lbl) end
        end})
        ULG:AddButton({Text = "Add One (" .. u .. ")", Func = function() local c = activeUpgrades[u] or init; applyUpgradeValue(u, c + 1, lbl) end})
        ULG:AddButton({Text = "Remove One (" .. u .. ")", Func = function() local c = activeUpgrades[u] or init; applyUpgradeValue(u, c - 1, lbl) end})
    end
    updateActiveUpgradesDisplay()

    -- =================================================================
    -- WEBHOOK TAB  (restart toggle + enabled options panel)
    -- =================================================================
    local WCG = Tabs.Webhook:AddLeftGroupbox("Discord Webhook")

    WCG:AddLabel("<font color='#AAAAAA'>Paste a Discord webhook URL. Click the URL box and press Enter to confirm.</font>")

    WCG:AddInput("WebhookURLInput", {
        Default = "",
        Finished = true,
        Text = "Discord Webhook URL",
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(Value)
            if type(Value) == "table" then Value = Value[1] or "" end
            Webhook.URL = tostring(Value or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if Library then
                if Webhook.URL == "" then
                    Library:Notify("Webhook URL cleared.", 2)
                else
                    local ok, err = isValidWebhookURL()
                    Library:Notify(ok and "Webhook URL saved." or ("URL warning: " .. tostring(err)), ok and 2 or 4)
                end
            end
        end
    })

    WCG:AddDivider("Notification Triggers")

    WCG:AddToggle("WebhookLevelToggle", {
        Text = "<font color='#00FF88'>Notify on new level</font>",
        Default = false,
        Tooltip = "Sends a webhook whenever a new level is detected (uses the same LogService hook as Auto-Void).",
        Callback = function(Value) Webhook.LevelEnabled = Value end
    })

    WCG:AddToggle("WebhookDeathToggle", {
        Text = "<font color='#FF4444'>Notify on death</font>",
        Default = false,
        Tooltip = "Sends a webhook whenever the local player dies.",
        Callback = function(Value) Webhook.DeathEnabled = Value end
    })

    WCG:AddToggle("WebhookRestartToggle", {
        Text = "<font color='#FFA500'>Notify on restart (level dropped)</font>",
        Default = false,
        Tooltip = "Sends a webhook if the observed level is lower than the previous one — usually indicates the player died and restarted.",
        Callback = function(Value) Webhook.RestartEnabled = Value end
    })

    WCG:AddDivider("Auto Period Report")

    WCG:AddToggle("WebhookAutoToggle", {
        Text = "<font color='#00AAFF'>Auto-send period report</font>",
        Default = false,
        Tooltip = "Sends a status webhook on a fixed interval.",
        Callback = function(Value)
            Webhook.AutoEnabled = Value
            Webhook.LastAutoSendTime = os.clock()
            if Value then Library:Notify(string.format("Auto report every %d min.", Webhook.AutoIntervalMinutes), 2)
            else Library:Notify("Auto report disabled.", 2) end
        end
    })

    WCG:AddSlider("WebhookAutoIntervalSlider", {
        Text = "Auto-send interval (minutes)",
        Default = 5,
        Min = 1,
        Max = 60,
        Rounding = 0,
        Tooltip = "How often the auto-send fires. Max 60 minutes.",
        Callback = function(Value)
            Webhook.AutoIntervalMinutes = Value
            Webhook.LastAutoSendTime = os.clock()
        end
    })

    WCG:AddDivider("Manual Actions")

    WCG:AddButton({
        Text = "<font color='#00AAFF'>Send Test / Current Info</font>",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook config error: " .. tostring(err), 5); return end
            local success, info = dispatchWebhook({
                username = "Null GUI",
                embeds = {{
                    title = "🔔 Test Webhook",
                    description = "Manual test payload from Java's Null GUI.",
                    color = 0x00AAFF,
                    fields = buildWebhookFields(),
                    timestamp = getTimestamp(),
                    footer = {text = "Java's Null GUI | Test"},
                }}
            })
            if success then Library:Notify("✅ Test webhook sent: " .. tostring(info), 3)
            else Library:Notify("❌ Failed: " .. tostring(info), 8) end
        end
    })

    WCG:AddButton({
        Text = "Send Death Webhook (Test)",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook config error: " .. tostring(err), 5); return end
            local success, info = dispatchDeathWebhook()
            if success then Library:Notify("✅ Death test sent: " .. tostring(info), 3)
            else Library:Notify("❌ Failed: " .. tostring(info), 8) end
        end
    })

    WCG:AddButton({
        Text = "Send Restart Webhook (Test)",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook config error: " .. tostring(err), 5); return end
            local old = (currentObservedLevel or 1) + 5
            local new = currentObservedLevel or 1
            local success, info = dispatchRestartWebhook(old, new)
            if success then Library:Notify("✅ Restart test sent: " .. tostring(info), 3)
            else Library:Notify("❌ Failed: " .. tostring(info), 8) end
        end
    })

    WCG:AddButton({
        Text = "Send Periodic Report (Test)",
        Func = function()
            local ok, err = isValidWebhookURL()
            if not ok then Library:Notify("Webhook config error: " .. tostring(err), 5); return end
            local success, info = dispatchPeriodicWebhook()
            if success then Library:Notify("✅ Report sent: " .. tostring(info), 3)
            else Library:Notify("❌ Failed: " .. tostring(info), 8) end
        end
    })

    local WIG = Tabs.Webhook:AddRightGroupbox("Webhook Info")
    WIG:AddLabel("<font color='#AAAAAA'>Every payload includes:</font>")
    WIG:AddLabel("• Player name & display name")
    WIG:AddLabel("• Executor name")
    WIG:AddLabel("• Current level + levels gained this session")
    WIG:AddLabel("• Session uptime")
    WIG:AddLabel("• Game name & place ID")
    WIG:AddLabel("• <b>Enabled script options</b>")
    WIG:AddLabel("• Active enemies & active upgrades")
    WIG:AddLabel("• Timestamp & footer")

    WIG:AddDivider("Live Status")
    local wStatus = WIG:AddLabel("Status: Idle")
    task.spawn(function()
        while task.wait(1) do
            if wStatus then
                local lines = {
                    "URL Set: " .. (Webhook.URL ~= "" and "<font color='#00FF00'>Yes</font>" or "<font color='#FF6666'>No</font>"),
                    "Level Trigger: " .. (Webhook.LevelEnabled and "<font color='#00FF00'>ON</font>" or "<font color='#AAAAAA'>OFF</font>"),
                    "Death Trigger: " .. (Webhook.DeathEnabled and "<font color='#00FF00'>ON</font>" or "<font color='#AAAAAA'>OFF</font>"),
                    "Restart Trigger: " .. (Webhook.RestartEnabled and "<font color='#00FF00'>ON</font>" or "<font color='#AAAAAA'>OFF</font>"),
                    "Auto Trigger: " .. (Webhook.AutoEnabled and ("<font color='#00FF00'>" .. Webhook.AutoIntervalMinutes .. " min</font>") or "<font color='#AAAAAA'>OFF</font>"),
                    "Levels This Session: " .. tostring(Webhook.LevelsGained),
                    "Current Level: " .. tostring(currentObservedLevel or "N/A"),
                    "Uptime: " .. getSessionUptime(),
                    "Last Response: " .. Webhook.LastResponse,
                }
                wStatus:SetText(table.concat(lines, "\n"))
            end
        end
    end)

    WIG:AddDivider("Enabled Options (Live)")
    local enabledOptsLbl = WIG:AddLabel("Loading...")
    task.spawn(function()
        while task.wait(1.5) do
            if enabledOptsLbl then
                local opts = getActiveOptionsList()
                if #opts > 0 then
                    enabledOptsLbl:SetText(string.format("<font color='#00FF88'>Enabled (%d):</font>\n%s", #opts, table.concat(opts, "\n")))
                else
                    enabledOptsLbl:SetText("<font color='#AAAAAA'>No options enabled.</font>")
                end
            end
        end
    end)
else
    Tabs.UniversalMain = Window:AddTab("Main - Universal", "globe")
    Tabs.Debug         = Window:AddTab("Debug", "bug")
    Tabs.Credits       = Window:AddTab("Credits", "info")
    Tabs.Settings      = Window:AddTab("Settings", "settings")

    local UG = Tabs.UniversalMain:AddLeftGroupbox("Universal Features")
    UG:AddSlider("WalkSpeedSlider", {Text = "WalkSpeed", Default = 16, Min = 16, Max = 250, Rounding = 0, Callback = function(V)
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = V end
    end})
    UG:AddSlider("JumpPowerSlider", {Text = "JumpPower", Default = 50, Min = 50, Max = 500, Rounding = 0, Callback = function(V)
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").JumpPower = V end
    end})

    local TG = Tabs.UniversalMain:AddRightGroupbox("Utilities")
    local function names() local l = {} for _, p in ipairs(Players:GetPlayers()) do if p ~= plr then table.insert(l, p.Name) end end return l end
    local sel = nil
    TG:AddDropdown("TargetPlayerDropdown", {Text = "Player", Values = names(), Default = 1, Callback = function(V) sel = V end})
    TG:AddButton({Text = "Refresh", Func = function() if Options and Options.TargetPlayerDropdown then Options.TargetPlayerDropdown:SetValues(names()) end end})
    TG:AddButton({Text = "Teleport to Player", Func = function()
        if sel then
            local tp = Players:FindFirstChild(sel)
            if tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                plr.Character.HumanoidRootPart.CFrame = tp.Character.HumanoidRootPart.CFrame
                Library:Notify("Teleported to " .. sel, 3)
            end
        end
    end})
    TG:AddButton({Text = "Rejoin Server", Func = function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, plr) end})

    local PG = Tabs.UniversalMain:AddRightGroupbox("Players in Server")
    local plLbl = PG:AddLabel("Loading...")
    task.spawn(function()
        while task.wait(2) do
            if plLbl then
                local list = Players:GetPlayers()
                table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
                local lines = {}
                for _, p in ipairs(list) do
                    local tag = (p == plr) and " <font color='#00FF88'>(you)</font>" or ""
                    table.insert(lines, "• " .. p.Name .. tag)
                end
                plLbl:SetText(string.format("<b>%d player(s) online:</b>\n%s", #list, table.concat(lines, "\n")))
            end
        end
    end)
end

local CG = Tabs.Credits:AddLeftGroupbox("Contributors")
CG:AddLabel("<font color='#FFA500'>kaoru_zz</font>; Guardians anti-kill")
CG:AddLabel("<font color='#FFA500'>(Ali)zeja</font> Main script, Huge inspiration!")
local DG = Tabs.Credits:AddRightGroupbox("Developers")
DG:AddLabel("<font color='#AA55FF'>Java (.html4)</font> Main Developer")

local DBG = Tabs.Debug:AddLeftGroupbox("Debug Actions")
DBG:AddButton({Text = "Log Select Attributes", Func = function() logSelectAttributes(); Library:Notify("Logged attributes.", 3) end})
DBG:AddButton({Text = "Unload GUI", Func = function()
    if _G.NullGui_Cleanup and type(_G.NullGui_Cleanup) == "function" then pcall(_G.NullGui_Cleanup) end
    if velocityPart and velocityPart.Parent then pcall(function() velocityPart:Destroy() end) end
    if protectionFolder and protectionFolder.Parent then pcall(function() protectionFolder:Destroy() end) end
    if Library and type(Library.Unload) == "function" then pcall(function() Library:Unload() end) end
end})
local DIB = Tabs.Debug:AddRightGroupbox("Session State")
local lvlLbl = DIB:AddLabel("Current Level: N/A")
local connLbl = DIB:AddLabel("Connections: " .. #scriptConnections)
task.spawn(function()
    while task.wait(1) do
        if lvlLbl then lvlLbl:SetText("Current Level: " .. tostring(currentObservedLevel or "N/A")) end
        if connLbl then connLbl:SetText("Connections: " .. #scriptConnections) end
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