--[[
    AdminPanel_UIOnly.client.lua
    
    Fancier animated loading screen + Obsidian UI Library.
    Integrated with AI/Entity disabling tools, game hooks, and real-time server diagnostics.
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

local PlaceId, JobId = game.PlaceId, game.JobId 
local plr = Players.LocalPlayer

--------------------------------------------------------------------
-- Game References
--------------------------------------------------------------------
local events = ReplicatedStorage:WaitForChild("Events", 5) or ReplicatedStorage:FindFirstChild("Events")

local Camera = workspace.CurrentCamera
local spawnPart = workspace:FindFirstChild("Spawn")
local items = workspace:FindFirstChild("Item_Pools")
local gifts = items and items:FindFirstChild("Gift")
local goldengifts = items and items:FindFirstChild("GoldenGift")
local tripmines = items and items:FindFirstChild("Tripmine")
local goldentripmines = items and items:FindFirstChild("GoldTripmines")
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
local bullets = items and items:FindFirstChild("Bullet")
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
-- State Flags & Variables
--------------------------------------------------------------------
local notifOn = true
local destroying = false

local disableAllEnemies = false
local disableClientEnemies = false
local autoDestroySpawns = false

-- Advanced Auto Enemy Tables
local auto_disable = {
    Bell = false,
    Mart = false,
    Skinwalker = false,
    Springer = false,
    Baby = false,
    Flesh = false,
    nilEnemy = false,
    nilMirage = false,
    Telefragger = false,
    ShadowBaby = false,
    Cadence = false,
}

local auto_break = {
    Bell = false,
    Mart = false,
    Skinwalker = false,
    Springer = false,
    ICBM = false,
    Baby = false,
    Flesh = false,
    nilEnemy = false,
    nilMirage = false,
    Telefragger = false,
    ShadowBaby = false,
    Celestial = false,
    Cadence = false,
}

local auto_destroy = {
    Bell = false,
    Mart = false,
    Skinwalker = false,
    Springer = false,
    ICBM = false,
    Baby = false,
    Flesh = false,
    Operator = false,
    Kolona = false,
    nilEnemy = false,
    nilMirage = false,
    Telefragger = false,
    Sigil = false,
    ShadowBaby = false,
    Voidbreaker = false,
    Cadence = false,
    Scrapmaw = false,
    RealityBreak = false,
    Celestial = false,
}

local tweening = false
local aura = false
local cesp = false
local mesp = false
local visibleHitbox = false
local canInstaGrapple = false
local canToggleAura = true
local canGoHome = true
local canGoBeacon = true
local canEzDisableAll = true
local canEzDisableAllC = true
local canEzCollectNormal = true
local canEzCollectGolden = true
local canEzCollectMedal = true
local canFullReset = true
local canBringPad = true
local canBringTria = true
local canGliderBoost = false
local canCancelTween = false
local av = false
local noice = false
local noflesh = false
local instrumentesp = false
local pt = false
local pb = false
local dvi = false
local dsm = false
local dso = false
local velov = false
local nrb = false
local nfb = false
local gliderBoost = false

local connections = {}

local clientenemies = {
    "Kolona",
    "Voidbreaker",
    "Skinwalker",
    "Operator",
    "Scrapmaw"
}

local tracers = {}
local availableNormalGifts = {}
local availableGoldenGifts = {}
local newInstances = {}
local cgb
local mb

--------------------------------------------------------------------
-- Helper Functions: AI & Entity Disablers
--------------------------------------------------------------------
local function disableEnemyEntity(entity)
    if not entity or not entity:IsA("Model") then return end
    
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

-- Fallback/compatibility layout adapter for your custom disable routines
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

local function handleEnemy(enemy)
    if not enemy then return end
    local name = enemy.Name
    local waitingTime = 25

    if name == "ICBM" or name == "Telefragger" or name:find("Baby") then
        waitingTime = 75
    end

    if auto_destroy[name] then
        local start = tick()
        local didDestroy

        repeat
            if tick() - start >= waitingTime then break end
            didDestroy = disableEnemy(name, true, false, false)
            task.wait(.2)
        until didDestroy == true
    elseif auto_break[name] then
        if name == "Mart" and curses and curses:FindFirstChild("MartSlide") and notifOn then
            Library:Notify("Destroy Mart instead of breaking.", 3)
        end

        local start = tick()
        local didBreak

        repeat
            if tick() - start >= waitingTime then break end
            didBreak = disableEnemy(name, false, true, false)
            task.wait(.2)
        until didBreak == true
    elseif auto_disable[name] then
        if name == "Mart" and curses and curses:FindFirstChild("MartSlide") and notifOn then
            Library:Notify("Destroy Mart instead of disabling.", 3)
        end

        local start = tick()
        local didDisable

        repeat
            if tick() - start >= waitingTime then break end
            didDisable = disableEnemy(name, false, false, true)
            task.wait(.2)
        until didDisable == true
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
-- Loading Screen (5 seconds, animated progress bar)
--------------------------------------------------------------------
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "NullGuiLoading"
loadingGui.ResetOnSpawn = false
loadingGui.Parent = plr:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Size = UDim2.fromOffset(360, 130)
card.Position = UDim2.new(0.5, -180, 0.5, -65)
card.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
card.BorderSizePixel = 0
card.Parent = loadingGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = card

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -32, 0, 30)
titleLabel.Position = UDim2.new(0, 16, 0, 18)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Java's Null gui"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = card

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -32, 0, 20)
subLabel.Position = UDim2.new(0, 16, 0, 46)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Loading UI..."
subLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 14
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Parent = card

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -32, 0, 6)
barBg.Position = UDim2.new(0, 16, 0, 90)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
barBg.BorderSizePixel = 0
barBg.Parent = card

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(1, 0)
barBgCorner.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(120, 90, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent = barFill

local fillTween = TweenService:Create(
    barFill,
    TweenInfo.new(5, Enum.EasingStyle.Linear),
    {Size = UDim2.new(1, 0, 1, 0)}
)
fillTween:Play()
fillTween.Completed:Wait()

loadingGui:Destroy()

--------------------------------------------------------------------
-- Load Obsidian UI Library
--------------------------------------------------------------------
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

local Window = Library:CreateWindow({
    Title = "Java's Null Gui",
    Footer = "v6.7",
    Icon = "cat",  
    Center = true,
    AutoShow = true,
})

--------------------------------------------------------------------
-- TABS
--------------------------------------------------------------------
local Tabs = {
    Playerlist    = Window:AddTab("Main", "paw-print"),
    Enemies       = Window:AddTab("Enemies", "triangle-alert"),
    Music         = Window:AddTab("Music", "music"),
    Upgrades      = Window:AddTab("Upgrades", "cat"),
    Debug         = Window:AddTab("Debug", "bug"),
    Settings      = Window:AddTab("Settings", "settings"),
}

--------------------------------------------------------------------
-- Main Features Tab
--------------------------------------------------------------------
local PlayerGroup = Tabs.Playerlist:AddLeftGroupbox("Main Features")

PlayerGroup:AddButton({
    Text = "Player Settings",
    Func = function()
        Library:Notify("Player settings option selected.", 2)
    end
})

--------------------------------------------------------------------
-- Enemies Tab (Granular & Automated Controls)
--------------------------------------------------------------------
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

-- Detailed Individual Config Groupbox using Obsidian AddDivider
local DetailedEnemyGroup = Tabs.Enemies:AddLeftGroupbox("Granular Enemy Options")

-- Global continuous connection listener for enemy spawns matching configured rules
connections["GranularEnemies"] = RunService.Heartbeat:Connect(function()
    if not enemies then return end
    for _, enemy in ipairs(enemies:GetChildren()) do
        handleEnemy(enemy)
    end
end)

-- Bell
DetailedEnemyGroup:AddDivider("Bell")
DetailedEnemyGroup:AddToggle("Bell_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Bell,
    Callback = function(v)
        auto_disable.Bell = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end
    end
})
DetailedEnemyGroup:AddToggle("Bell_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Bell,
    Callback = function(v)
        auto_break.Bell = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end
    end
})
DetailedEnemyGroup:AddToggle("Bell_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Bell,
    Callback = function(v)
        auto_destroy.Bell = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Bell")) end
    end
})

-- Mart
DetailedEnemyGroup:AddDivider("Mart")
DetailedEnemyGroup:AddToggle("Mart_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Mart,
    Callback = function(v)
        auto_disable.Mart = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end
        if curses and curses:FindFirstChild("MartSlide") and notifOn then
            Library:Notify("Destroy Mart instead of disabling.", 3)
        end
    end
})
DetailedEnemyGroup:AddToggle("Mart_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Mart,
    Callback = function(v)
        auto_break.Mart = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end
        if curses and curses:FindFirstChild("MartSlide") and notifOn then
            Library:Notify("Destroy Mart instead of breaking.", 3)
        end
    end
})
DetailedEnemyGroup:AddToggle("Mart_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Mart,
    Callback = function(v)
        auto_destroy.Mart = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Mart")) end
    end
})

-- Husk (Skinwalker)
DetailedEnemyGroup:AddDivider("Husk")
DetailedEnemyGroup:AddToggle("Skinwalker_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Skinwalker,
    Callback = function(v)
        auto_disable.Skinwalker = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Skinwalker")) end
    end
})
DetailedEnemyGroup:AddToggle("Skinwalker_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Skinwalker,
    Callback = function(v)
        auto_destroy.Skinwalker = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Skinwalker")) end
    end
})

-- Springer
DetailedEnemyGroup:AddDivider("Springer")
DetailedEnemyGroup:AddToggle("Springer_Disable", {
    Text = "Auto Disable Shockwaves",
    Default = auto_disable.Springer,
    Callback = function(v)
        auto_disable.Springer = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end
    end
})
DetailedEnemyGroup:AddToggle("Springer_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Springer,
    Callback = function(v)
        auto_break.Springer = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end
    end
})
DetailedEnemyGroup:AddToggle("Springer_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Springer,
    Callback = function(v)
        auto_destroy.Springer = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Springer")) end
    end
})

-- ICBM
DetailedEnemyGroup:AddDivider("ICBM")
DetailedEnemyGroup:AddToggle("ICBM_Break", {
    Text = "Auto Break AI",
    Default = auto_break.ICBM,
    Callback = function(v)
        auto_break.ICBM = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("ICBM")) end
    end
})
DetailedEnemyGroup:AddToggle("ICBM_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.ICBM,
    Callback = function(v)
        auto_destroy.ICBM = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("ICBM")) end
    end
})

-- Baby
DetailedEnemyGroup:AddDivider("Baby")
DetailedEnemyGroup:AddToggle("Baby_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Baby,
    Callback = function(v)
        auto_disable.Baby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end
    end
})
DetailedEnemyGroup:AddToggle("Baby_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Baby,
    Callback = function(v)
        auto_break.Baby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end
    end
})
DetailedEnemyGroup:AddToggle("Baby_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Baby,
    Callback = function(v)
        auto_destroy.Baby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Baby")) end
    end
})

-- Flesh
DetailedEnemyGroup:AddDivider("Flesh")
DetailedEnemyGroup:AddToggle("Flesh_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Flesh,
    Callback = function(v)
        auto_disable.Flesh = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end
    end
})
DetailedEnemyGroup:AddToggle("Flesh_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Flesh,
    Callback = function(v)
        auto_break.Flesh = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end
    end
})
DetailedEnemyGroup:AddDivider("Flesh_Destroy_Div")
DetailedEnemyGroup:AddToggle("Flesh_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Flesh,
    Callback = function(v)
        auto_destroy.Flesh = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Flesh")) end
    end
})

-- Guardian
DetailedEnemyGroup:AddDivider("Guardian (CANNOT BE DISABLED)")
DetailedEnemyGroup:AddToggle("Guardian_Protection", {
    Text = "Create Protection",
    Default = pb,
    Callback = function(Value)
        pb = Value
        if not Value then
            bulletprots:ClearAllChildren()
        end
    end
})

-- Operator & Kolona
DetailedEnemyGroup:AddDivider("Operator")
DetailedEnemyGroup:AddToggle("Operator_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Operator,
    Callback = function(v)
        auto_destroy.Operator = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Operator")) end
    end
})

DetailedEnemyGroup:AddDivider("Kolona")
DetailedEnemyGroup:AddToggle("Kolona_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Kolona,
    Callback = function(v)
        auto_destroy.Kolona = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Kolona")) end
    end
})

-- Telefragger
DetailedEnemyGroup:AddDivider("Telefragger")
DetailedEnemyGroup:AddToggle("Telefragger_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Telefragger,
    Callback = function(v)
        auto_disable.Telefragger = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end
    end
})
DetailedEnemyGroup:AddToggle("Telefragger_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Telefragger,
    Callback = function(v)
        auto_break.Telefragger = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end
    end
})
DetailedEnemyGroup:AddToggle("Telefragger_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Telefragger,
    Callback = function(v)
        auto_destroy.Telefragger = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Telefragger")) end
    end
})

-- Sigil & Voidbreaker
DetailedEnemyGroup:AddDivider("Sigil")
DetailedEnemyGroup:AddToggle("Sigil_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Sigil,
    Callback = function(v)
        auto_destroy.Sigil = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Sigil")) end
    end
})

DetailedEnemyGroup:AddDivider("Voidbreaker")
DetailedEnemyGroup:AddToggle("Voidbreaker_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Voidbreaker,
    Callback = function(v)
        auto_destroy.Voidbreaker = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Voidbreaker")) end
    end
})

-- Cadence
DetailedEnemyGroup:AddDivider("Cadence")
DetailedEnemyGroup:AddToggle("Cadence_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.Cadence,
    Callback = function(v)
        auto_disable.Cadence = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end
    end
})
DetailedEnemyGroup:AddToggle("Cadence_Break", {
    Text = "Auto Break AI",
    Default = auto_break.Cadence,
    Callback = function(v)
        auto_break.Cadence = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end
    end
})
DetailedEnemyGroup:AddToggle("Cadence_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Cadence,
    Callback = function(v)
        auto_destroy.Cadence = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Cadence")) end
    end
})

-- Voidbound Baby (ShadowBaby)
DetailedEnemyGroup:AddDivider("Voidbound Baby")
DetailedEnemyGroup:AddToggle("ShadowBaby_Disable", {
    Text = "Auto Disable",
    Default = auto_disable.ShadowBaby,
    Callback = function(v)
        auto_disable.ShadowBaby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end
    end
})
DetailedEnemyGroup:AddToggle("ShadowBaby_Break", {
    Text = "Auto Break AI",
    Default = auto_break.ShadowBaby,
    Callback = function(v)
        auto_break.ShadowBaby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end
    end
})
DetailedEnemyGroup:AddToggle("ShadowBaby_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.ShadowBaby,
    Callback = function(v)
        auto_destroy.ShadowBaby = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("ShadowBaby")) end
    end
})

-- Scrapmaw & Reality Break
DetailedEnemyGroup:AddDivider("Scrapmaw")
DetailedEnemyGroup:AddToggle("Scrapmaw_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.Scrapmaw,
    Callback = function(v)
        auto_destroy.Scrapmaw = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("Scrapmaw")) end
    end
})

DetailedEnemyGroup:AddDivider("Reality Break")
DetailedEnemyGroup:AddToggle("RealityBreak_Destroy", {
    Text = "Auto Destroy",
    Default = auto_destroy.RealityBreak,
    Callback = function(v)
        auto_destroy.RealityBreak = v
        if v then handleEnemy(enemies and enemies:FindFirstChild("RealityBreak")) end
    end
})

DetailedEnemyGroup:AddToggle("Celestial_Break", {
    Text = "Break Celestial AI",
    Default = auto_break.Celestial,
    Callback = function(v)
        auto_break.Celestial = v
    end
})
DetailedEnemyGroup:AddToggle("Celestial_Destroy", {
    Text = "Destroy Celestial",
    Default = auto_destroy.Celestial,
    Callback = function(v)
        auto_destroy.Celestial = v
    end
})

--------------------------------------------------------------------
-- Music Tab
--------------------------------------------------------------------
local MusicGroup = Tabs.Music:AddLeftGroupbox("Playback")

MusicGroup:AddButton({
    Text = "Play Track 1",
    Func = function() end
})

MusicGroup:AddButton({
    Text = "Stop Music",
    Func = function() end
})

MusicGroup:AddSlider("VolumeSlider", {
    Text = "Volume",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = function(Value) end
})

--------------------------------------------------------------------
-- Upgrades Tab
--------------------------------------------------------------------
local AnnounceGroup = Tabs.Upgrades:AddLeftGroupbox("Upgrades & Messages")

AnnounceGroup:AddInput("AnnounceInput", {
    Text = "Message",
    Default = "",
    Numeric = false,
    Finished = true,
    Callback = function(Value) end
})

AnnounceGroup:AddButton({
    Text = "Send Message",
    Func = function() end
})

--------------------------------------------------------------------
-- Debug Tab (Performance Tracking & Server Metadata)
--------------------------------------------------------------------
local DebugGroup = Tabs.Debug:AddLeftGroupbox("Info")

local playerLabel = DebugGroup:AddLabel("Players: Fetching...")
local pingLabel = DebugGroup:AddLabel("Ping: Fetching...")
local clientFpsLabel = DebugGroup:AddLabel("Client FPS: Fetching...")
local serverFpsLabel = DebugGroup:AddLabel("Server FPS: Fetching...")
local locationLabel = DebugGroup:AddLabel("Server Region: Fetching...")

-- Client FPS Tracker
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

-- Fetch Server Location Heuristic
local serverLocation = "Estimating..."
task.spawn(function()
    task.wait(1)
    local playersList = Players:GetPlayers()
    if #playersList > 0 then
        local firstPlayer = playersList[1] 
        local success, regionCode = pcall(function()
            return LocalizationService:GetCountryRegionForPlayerAsync(firstPlayer)
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

local function getDebugData()
    local currentPlayers = Players:GetPlayers()
    local playerCount = #currentPlayers
    local maxPlayers = Players.MaxPlayers
    
    local ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local serverFPS = math.round(workspace:GetRealPhysicsFPS())
    
    return {
        Players = string.format("%d/%d", playerCount, maxPlayers),
        Ping = string.format("%d ms", ping),
        ClientFPS = math.round(clientFPS),
        ServerFPS = serverFPS,
        Location = serverLocation,
        PlayerList = currentPlayers
    }
end

local function refreshDebugInfo(notify)
    local data = getDebugData()
    
    playerLabel:SetText("Players: " .. data.Players)
    pingLabel:SetText("Ping: " .. data.Ping)
    clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS)
    serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS)
    locationLabel:SetText("Server Region: " .. data.Location)
    
    print("======== SERVER INFO ========")
    print("Server Size: " .. data.Players)
    print("Ping: " .. data.Ping)
    print("Client FPS: " .. data.ClientFPS)
    print("Server FPS: " .. data.ServerFPS)
    print("Server Region: " .. data.Location)
    print("-----------------------------")
    for _, player in ipairs(data.PlayerList) do
        print(string.format("Username: %s | Display Name: %s", player.Name, player.DisplayName))
    end
    print("=============================")
    
    if notify then
        Library:Notify("Server Stats Refreshed!", 3)
    end
end

DebugGroup:AddButton({
    Text = "Refresh Info",
    Func = function()
        refreshDebugInfo(true)
    end
})

task.spawn(function()
    while task.wait(1.5) do
        local data = getDebugData()
        playerLabel:SetText("Players: " .. data.Players)
        pingLabel:SetText("Ping: " .. data.Ping)
        clientFpsLabel:SetText("Client FPS: " .. data.ClientFPS)
        serverFpsLabel:SetText("Server FPS: " .. data.ServerFPS)
        locationLabel:SetText("Server Region: " .. data.Location)
    end
end)

local SystemGroup = Tabs.Debug:AddRightGroupbox("System")

SystemGroup:AddButton({
    Text = "Unload GUI",
    Func = function()
        for _, conn in pairs(connections) do
            if conn then conn:Disconnect() end
        end
        Library:Unload()
    end
})

--------------------------------------------------------------------
-- Settings Tab
--------------------------------------------------------------------
local SettingsGroup = Tabs.Settings:AddLeftGroupbox("GUI Settings")

SettingsGroup:AddToggle("ExampleToggle", {
    Text = "Enable Example Feature",
    Default = false,
    Callback = function(Value) end
})

SettingsGroup:AddDropdown("ExampleDropdown", {
    Text = "Choose Mode",
    Values = {"Mode A", "Mode B", "Mode C"},
    Default = 1,
    Callback = function(Value) end
})

SettingsGroup:AddKeyPicker("ExampleKeybind", {
    Default = "K",
    Text = "Toggle Menu Keybind",
    Callback = function() end
})
