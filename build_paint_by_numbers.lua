-- Paint by Numbers / Essential UI Pack bootstrapper
--
-- Run this entire file once in Roblox Studio's Command Bar while
-- "Essential UI Pack - Swarve Studios.rbxl" is the open place.
-- The script is intentionally self-contained: all runtime sources are below
-- so a Studio user does not need to paste several scripts in a particular
-- order. Re-running it updates generated code/UI and keeps imported art
-- ModuleScripts in ReplicatedStorage/PaintByNumbers/ArtLibrary.

local TAG = "PaintByNumbersGenerated"
local ROOT_NAME = "PaintByNumbers"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- The Essential UI Pack contains demo scripts from its source experience.
-- They expect unrelated leaderstats/DataStores (Coins, Strength, Rebirths)
-- and otherwise spam Output or wait forever while this standalone game is
-- running. Keep the visual templates, but disable only those known demo
-- scripts; generated PaintByNumbers scripts remain enabled.
local legacyServerScripts = {
    ReceiptHandler = true,
    PurchaseHandler = true,
    RebirthHandler = true,
    leaderstats = true,
}
local legacyGuiPaths = {
    ["StarterGui.GUI.HUD.Currency"] = true,
    ["StarterGui.GUI.Frames.Rebirth.LocalScript"] = true,
    ["StarterGui.GUI.Frames.Index.LocalScript"] = true,
    ["StarterGui.GUI.Frames.Wheel.LocalScript"] = true,
}
for _, descendant in ipairs(ServerScriptService:GetDescendants()) do
    if descendant:IsA("Script") and legacyServerScripts[descendant.Name] then
        descendant.Disabled = true
        descendant:SetAttribute("PaintByNumbersDisabledLegacy", true)
    end
end
for _, descendant in ipairs(StarterGui:GetDescendants()) do
    if (descendant:IsA("Script") or descendant:IsA("LocalScript")) and legacyGuiPaths[descendant:GetFullName()] then
        descendant.Disabled = true
        descendant:SetAttribute("PaintByNumbersDisabledLegacy", true)
    end
end

local function mark(instance)
    instance:SetAttribute(TAG, true)
    return instance
end

local function set(instance, property, value)
    local ok, err = pcall(function()
        instance[property] = value
    end)
    if not ok then
        warn("PaintByNumbers: could not set " .. property .. " on " .. instance:GetFullName() .. ": " .. tostring(err))
    end
end

local function getOrCreate(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and not existing:IsA(className) then
        existing:Destroy()
        existing = nil
    end
    if existing then
        return existing
    end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = parent
    return mark(created)
end

local function replaceSource(parent, className, name, source)
    local old = parent:FindFirstChild(name)
    if old then
        old:Destroy()
    end
    local object = mark(Instance.new(className))
    object.Name = name
    object.Source = source
    object.Parent = parent
    return object
end

local function destroyGenerated(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:GetAttribute(TAG) then
            child:Destroy()
        end
    end
end

-- Keep the art library itself when rebuilding. Imported modules are not
-- generated, while the two starter examples are created below if absent.
local root = getOrCreate(ReplicatedStorage, "Folder", ROOT_NAME)
local shared = getOrCreate(root, "Folder", "Shared")
local remotes = getOrCreate(root, "Folder", "Remotes")
local artLibrary = getOrCreate(root, "Folder", "ArtLibrary")

-- The runtime sources are deliberately plain Luau. They do not reference
-- this Command Bar script after installation.
local configSource = [=[
return {
    Version = 1,
    DataStoreName = "PaintByNumbers_Profile_v1",
    AdminName = "RabanFix",
    AutosaveSeconds = 60,
    StartingGems = 250,
    MaxSupportedColors = 16,
    AllowedSizes = {
        Easy = 32,
        Medium = 64,
        Hard = 128,
        ["Extreme / Unreal"] = 256,
    },
    DifficultyOrder = { "Easy", "Medium", "Hard", "Extreme / Unreal" },
    UpgradeMaxLevel = 3,
    UpgradeCosts = {
        AutoBrush = { 100, 350, 1000 },
        AreaBrush = { 150, 500, 1500 },
        ColorHint = { 120, 400, 1200 },
    },
    -- Level 1 is a 1x2 brush, level 2 is 2x2, and level 3 is 3x3.
    AreaBrushSizeByLevel = {
        { Width = 1, Height = 2 },
        { Width = 2, Height = 2 },
        { Width = 3, Height = 3 },
    },
    AreaBrushCooldownByLevel = { 4, 2.5, 1.25 },
    ColorHintCooldownByLevel = { 8, 5, 3 },
    ColorHintDurationByLevel = { 3, 5, 8 },
    DifficultyReward = {
        Easy = 75,
        Medium = 150,
        Hard = 300,
        ["Extreme / Unreal"] = 600,
    },
}
]=]

local codecSource = [=[
-- Shared codec for generated art modules and compact saved progress.
local Codec = {}

local function hexValue(byte)
    if byte >= 48 and byte <= 57 then
        return byte - 48
    elseif byte >= 65 and byte <= 70 then
        return byte - 55
    elseif byte >= 97 and byte <= 102 then
        return byte - 87
    end
    return 0
end

function Codec.GetPixelId(art, index)
    local pixels = art and art.Pixels
    if type(pixels) ~= "string" then
        return 0
    end
    local byte = string.byte(pixels, index)
    if not byte then
        return 0
    end
    return hexValue(byte)
end

function Codec.IsValidArt(art, maxColors)
    if type(art) ~= "table" then
        return false, "module did not return a table"
    end
    local width = tonumber(art.Width)
    local height = tonumber(art.Height)
    if (width ~= 32 and width ~= 64 and width ~= 128 and width ~= 256) or width ~= height then
        return false, "Width and Height must be 32, 64, 128, or 256"
    end
    if type(art.Id) ~= "string" or art.Id == "" then
        return false, "Id is required"
    end
    if type(art.Name) ~= "string" or art.Name == "" then
        return false, "Name is required"
    end
    if type(art.Pixels) ~= "string" or #art.Pixels ~= width * height then
        return false, "Pixels must contain exactly Width * Height characters"
    end
    if type(art.Palette) ~= "table" then
        return false, "Palette is required"
    end
    local paletteSize = tonumber(art.PaletteSize) or 0
    if paletteSize < 1 or paletteSize > (maxColors or 16) then
        return false, "PaletteSize must be between 1 and 16"
    end
    for index = 1, width * height do
        local colorId = Codec.GetPixelId(art, index)
        if colorId < 1 or colorId > paletteSize then
            return false, "Pixels contains an invalid color ID"
        end
    end
    return true
end

function Codec.NewBits(total)
    return string.rep("0", total)
end

function Codec.CountBits(bits, total)
    if type(bits) ~= "string" then
        return 0
    end
    local count = 0
    local limit = math.min(#bits, total or #bits)
    for index = 1, limit do
        if string.byte(bits, index) == 49 then
            count += 1
        end
    end
    return count
end

function Codec.EncodeBits(painted, total)
    local chunks = table.create(math.ceil(total / 1024))
    local chunk = table.create(1024)
    local chunkLength = 0
    local chunkIndex = 1
    for index = 1, total do
        chunkLength += 1
        chunk[chunkLength] = painted[index] and "1" or "0"
        if chunkLength == 1024 or index == total then
            chunks[chunkIndex] = table.concat(chunk, "", 1, chunkLength)
            chunkIndex += 1
            chunk = table.create(1024)
            chunkLength = 0
        end
    end
    return table.concat(chunks)
end

function Codec.DecodeBits(bits, total)
    local painted = {}
    local count = 0
    if type(bits) ~= "string" then
        return painted, count
    end
    local limit = math.min(#bits, total)
    for index = 1, limit do
        if string.byte(bits, index) == 49 then
            painted[index] = true
            count += 1
        end
    end
    return painted, count
end

return Codec
]=]

replaceSource(shared, "ModuleScript", "Config", configSource)
replaceSource(shared, "ModuleScript", "PixelCodec", codecSource)

local function ensureRemote(className, name)
    local old = remotes:FindFirstChild(name)
    if old and not old:IsA(className) then
        old:Destroy()
        old = nil
    end
    if old then
        old:SetAttribute(TAG, true)
        return old
    end
    local remote = mark(Instance.new(className))
    remote.Name = name
    remote.Parent = remotes
    return remote
end

ensureRemote("RemoteFunction", "GetProfile")
ensureRemote("RemoteFunction", "StartArt")
ensureRemote("RemoteFunction", "PaintPixel")
ensureRemote("RemoteFunction", "UseAbility")
ensureRemote("RemoteFunction", "UpgradeAbility")
ensureRemote("RemoteFunction", "AdminAction")
ensureRemote("RemoteEvent", "ProfileChanged")
ensureRemote("RemoteEvent", "Toast")

-- Starter art: generated as source here so the freshly bootstrapped place is
-- playable before the artist imports a real ModuleScript. The imported-art
-- workflow is documented in README.md.
local function makeStarterArt(id, name, difficulty, reward, palette, pixelFunction)
    if artLibrary:FindFirstChild(id) then
        return
    end
    local width = 32
    local rows = table.create(width)
    for y = 1, width do
        local row = table.create(width)
        for x = 1, width do
            row[x] = string.format("%X", pixelFunction(x, y))
        end
        rows[y] = table.concat(row)
    end
    local paletteLines = {}
    for colorId, color in ipairs(palette) do
        paletteLines[colorId] = string.format(
            "        [%d] = Color3.fromRGB(%d, %d, %d),",
            colorId,
            color[1],
            color[2],
            color[3]
        )
    end
    local source = string.format([=[
return {
    Id = %q,
    Name = %q,
    Difficulty = %q,
    Width = 32,
    Height = 32,
    Reward = %d,
    PaletteSize = %d,
    PixelEncoding = "hex-nibble-v1",
    Palette = {
%s
    },
    Pixels = [[%s]],
}
]=], id, name, difficulty, reward, #palette, table.concat(paletteLines, "\n"), table.concat(rows))
    replaceSource(artLibrary, "ModuleScript", id, source)
end

makeStarterArt("starter_sunset", "Sunset Island", "Easy", 75, {
    { 26, 38, 71 },
    { 255, 190, 76 },
    { 239, 104, 91 },
    { 84, 166, 214 },
    { 42, 104, 91 },
    { 236, 226, 179 },
}, function(x, y)
    if y <= 5 then
        return 1
    elseif y <= 12 then
        local dx = x - 16
        local dy = y - 9
        if dx * dx + dy * dy <= 25 then
            return 2
        end
        return y <= 8 and 1 or 3
    elseif y <= 21 then
        return x < 16 and 4 or 3
    elseif y >= 27 then
        return 5
    elseif x >= 14 and x <= 19 and y >= 20 then
        return 1
    elseif (x == 13 or x == 20) and y >= 21 then
        return 6
    else
        return 4
    end
end)

makeStarterArt("starter_garden", "Tiny Garden", "Easy", 75, {
    { 245, 231, 189 },
    { 76, 157, 91 },
    { 37, 104, 69 },
    { 226, 99, 112 },
    { 246, 188, 72 },
    { 106, 75, 55 },
}, function(x, y)
    if y <= 4 or y >= 29 then
        return 1
    elseif x <= 4 or x >= 29 then
        return 2
    elseif y >= 23 and x >= 9 and x <= 24 then
        return 6
    elseif x >= 13 and x <= 20 and y >= 13 and y <= 24 then
        return 3
    elseif ((x - 9) ^ 2 + (y - 10) ^ 2 <= 14) or ((x - 23) ^ 2 + (y - 9) ^ 2 <= 12) then
        return 2
    elseif (x + y) % 7 == 0 then
        return 4
    elseif (x * 3 + y) % 11 == 0 then
        return 5
    else
        return 1
    end
end)

-- ---------------------------- Server source -----------------------------
local serverSource = [=[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local package = ReplicatedStorage:WaitForChild("PaintByNumbers")
local shared = package:WaitForChild("Shared")
local remotes = package:WaitForChild("Remotes")
local artLibrary = package:WaitForChild("ArtLibrary")
local Config = require(shared:WaitForChild("Config"))
local Codec = require(shared:WaitForChild("PixelCodec"))

local GetProfile = remotes:WaitForChild("GetProfile")
local StartArt = remotes:WaitForChild("StartArt")
local PaintPixel = remotes:WaitForChild("PaintPixel")
local UseAbility = remotes:WaitForChild("UseAbility")
local UpgradeAbility = remotes:WaitForChild("UpgradeAbility")
local AdminAction = remotes:WaitForChild("AdminAction")
local ProfileChanged = remotes:WaitForChild("ProfileChanged")
local Toast = remotes:WaitForChild("Toast")

local Profiles = {}
local Sessions = {}
local ArtDefinitions = {}
local Saving = {}

local function defaultProfile()
    return {
        Version = Config.Version,
        Gems = Config.StartingGems,
        Upgrades = { AutoBrush = 0, AreaBrush = 0, ColorHint = 0 },
        ArtProgress = {},
    }
end

local function copyUpgrades(input)
    local result = { AutoBrush = 0, AreaBrush = 0, ColorHint = 0 }
    if type(input) == "table" then
        for key in pairs(result) do
            local value = tonumber(input[key]) or 0
            result[key] = math.clamp(math.floor(value), 0, Config.UpgradeMaxLevel)
        end
    end
    return result
end

local function normalizeProfile(raw)
    local profile = defaultProfile()
    if type(raw) ~= "table" then
        return profile
    end
    profile.Gems = math.max(0, math.floor(tonumber(raw.Gems) or profile.Gems))
    profile.Upgrades = copyUpgrades(raw.Upgrades)
    if type(raw.ArtProgress) == "table" then
        for artId, saved in pairs(raw.ArtProgress) do
            if type(artId) == "string" and type(saved) == "table" and type(saved.Bits) == "string" then
                local count = math.max(0, math.floor(tonumber(saved.Count) or 0))
                profile.ArtProgress[artId] = {
                    Bits = saved.Bits,
                    Count = count,
                    Complete = saved.Complete == true,
                }
            end
        end
    end
    return profile
end

local function normalizeArtDefinition(definition)
    if type(definition) ~= "table" or type(definition.Id) ~= "string" then
        return false, "definition needs Id"
    end
    if type(definition.Variants) == "table" then
        if type(definition.Name) ~= "string" or definition.Name == "" then
            return false, "definition needs Name"
        end
        local validVariant = false
        for difficulty, variant in pairs(definition.Variants) do
            if type(variant) == "table" then
                variant.Id = definition.Id
                variant.Name = variant.Name or definition.Name
                variant.Difficulty = variant.Difficulty or difficulty
                local valid, reason = Codec.IsValidArt(variant, Config.MaxSupportedColors)
                if not valid then
                    return false, "variant " .. tostring(difficulty) .. ": " .. tostring(reason)
                end
                validVariant = true
            end
        end
        if not validVariant then
            return false, "Variants is empty"
        end
        return true
    end
    local valid, reason = Codec.IsValidArt(definition, Config.MaxSupportedColors)
    return valid, reason
end

local function loadArtDefinitions()
    table.clear(ArtDefinitions)
    for _, module in ipairs(artLibrary:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, artOrError = pcall(require, module)
            if ok then
                local valid, reason = normalizeArtDefinition(artOrError)
                if valid and not ArtDefinitions[artOrError.Id] then
                    ArtDefinitions[artOrError.Id] = artOrError
                else
                    warn("PaintByNumbers: ignoring " .. module:GetFullName() .. ": " .. tostring(reason or "duplicate Id"))
                end
            else
                warn("PaintByNumbers: could not require " .. module:GetFullName() .. ": " .. tostring(artOrError))
            end
        end
    end
end

loadArtDefinitions()
artLibrary.ChildAdded:Connect(function(child)
    if child:IsA("ModuleScript") then
        task.defer(loadArtDefinitions)
    end
end)
artLibrary.ChildRemoved:Connect(loadArtDefinitions)

local dataStore
local storeAvailable = false
-- An unpublished Studio place has GameId == 0 and cannot use DataStore at
-- all. Use an in-memory profile there, while still allowing DataStore tests
-- in a published place with Studio Access to API Services enabled.
local canUseDataStore = not RunService:IsStudio() or game.GameId ~= 0
if canUseDataStore then
    local ok, result = pcall(function()
        return DataStoreService:GetDataStore(Config.DataStoreName)
    end)
    if ok then
        dataStore = result
        storeAvailable = true
    elseif not RunService:IsStudio() then
        warn("PaintByNumbers: DataStore unavailable: " .. tostring(result))
    end
end

local function playerKey(player)
    return "player_" .. tostring(player.UserId)
end

local function syncLeaderstats(player)
    local profile = Profiles[player]
    if not profile then
        return
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end
    local gems = leaderstats:FindFirstChild("Gems")
    if not gems then
        gems = Instance.new("IntValue")
        gems.Name = "Gems"
        gems.Parent = leaderstats
    end
    gems.Value = profile.Gems
end

local function profileSummary(profile)
    local progress = {}
    for artId, saved in pairs(profile.ArtProgress) do
        progress[artId] = {
            Count = math.max(0, tonumber(saved.Count) or 0),
            Complete = saved.Complete == true,
        }
    end
    return {
        Gems = profile.Gems,
        Upgrades = table.clone(profile.Upgrades),
        Progress = progress,
    }
end

local function persistSession(player)
    local session = Sessions[player]
    local profile = Profiles[player]
    if not session or not profile then
        return
    end
    profile.ArtProgress[session.ProgressKey] = {
        Bits = Codec.EncodeBits(session.Painted, session.Total),
        Count = session.Count,
        Complete = session.Count >= session.Total,
    }
end

local function serializableProfile(player)
    persistSession(player)
    local profile = Profiles[player]
    if not profile then
        return nil
    end
    return {
        Version = Config.Version,
        Gems = profile.Gems,
        Upgrades = table.clone(profile.Upgrades),
        ArtProgress = table.clone(profile.ArtProgress),
    }
end

local function saveProfile(player, isClosing)
    if Saving[player] then
        local deadline = os.clock() + 25
        while Saving[player] and Profiles[player] and os.clock() < deadline do
            task.wait(0.05)
        end
        if Saving[player] then
            return false
        end
    end
    local payload = serializableProfile(player)
    if not payload then
        return false
    end
    if not storeAvailable or not dataStore then
        return true
    end
    Saving[player] = true
    local ok, err = pcall(function()
        dataStore:UpdateAsync(playerKey(player), function()
            return payload
        end)
    end)
    Saving[player] = nil
    if not ok then
        warn("PaintByNumbers: save failed for " .. player.Name .. (isClosing and " during shutdown" or "") .. ": " .. tostring(err))
    end
    return ok
end

local function loadProfile(player)
    local profile = defaultProfile()
    if storeAvailable and dataStore then
        local ok, result = pcall(function()
            return dataStore:GetAsync(playerKey(player))
        end)
        if ok then
            profile = normalizeProfile(result)
        else
            warn("PaintByNumbers: load failed for " .. player.Name .. ": " .. tostring(result))
        end
    end
    Profiles[player] = profile
    syncLeaderstats(player)
    ProfileChanged:FireClient(player, profileSummary(profile))
end

local ScaledVariants = {}

local function getArt(artId)
    if type(artId) ~= "string" then
        return nil
    end
    return ArtDefinitions[artId]
end

local function progressKey(baseArt, variant)
    -- Difficulty is part of the save key even for legacy single-resolution
    -- modules, because the server may generate 32/64/128/256 fallbacks.
    return baseArt.Id .. "@" .. tostring(variant.Difficulty)
end

local function scaleFixedArt(sourceArt, difficulty, rewardOverride)
    local targetSize = Config.AllowedSizes[difficulty]
    if not targetSize or not sourceArt or not sourceArt.Width or not sourceArt.Height then
        return nil
    end
    ScaledVariants[sourceArt.Id] = ScaledVariants[sourceArt.Id] or {}
    if ScaledVariants[sourceArt.Id][difficulty] then
        return ScaledVariants[sourceArt.Id][difficulty]
    end
    local pixels = table.create(targetSize * targetSize)
    local writeIndex = 1
    for y = 1, targetSize do
        local sourceY = math.floor((y - 1) * sourceArt.Height / targetSize) + 1
        for x = 1, targetSize do
            local sourceX = math.floor((x - 1) * sourceArt.Width / targetSize) + 1
            local sourceIndex = (sourceY - 1) * sourceArt.Width + sourceX
            pixels[writeIndex] = string.sub(sourceArt.Pixels, sourceIndex, sourceIndex)
            writeIndex += 1
        end
    end
    local variant = {
        Id = sourceArt.Id,
        Name = sourceArt.Name,
        Difficulty = difficulty,
        Width = targetSize,
        Height = targetSize,
        Reward = rewardOverride or sourceArt.Reward or Config.DifficultyReward[difficulty],
        PaletteSize = sourceArt.PaletteSize,
        Palette = sourceArt.Palette,
        Pixels = table.concat(pixels),
    }
    ScaledVariants[sourceArt.Id][difficulty] = variant
    return variant
end

local function resolveVariant(baseArt, difficulty)
    difficulty = difficulty or baseArt.Difficulty or "Easy"
    if baseArt.Variants then
        local variant = baseArt.Variants[difficulty]
        if variant then
            return variant
        end
        -- A partial Variants table is accepted: nearest-neighbour scale the
        -- first available source variant for any missing difficulty.
        for _, candidateDifficulty in ipairs(Config.DifficultyOrder) do
            local source = baseArt.Variants[candidateDifficulty]
            if source then
                return scaleFixedArt(source, difficulty, Config.DifficultyReward[difficulty])
            end
        end
        return nil
    end
    if difficulty == baseArt.Difficulty then
        return baseArt
    end
    return scaleFixedArt(baseArt, difficulty, Config.DifficultyReward[difficulty])
end

local function getSavedState(profile, baseArt, variant)
    local key = progressKey(baseArt, variant)
    local saved = profile.ArtProgress[key]
    -- Read old saves made before difficulty variants existed.
    if not saved and not baseArt.Variants and variant.Difficulty == baseArt.Difficulty then
        saved = profile.ArtProgress[baseArt.Id]
    end
    local painted, count = Codec.DecodeBits(saved and saved.Bits, variant.Width * variant.Height)
    if saved and tonumber(saved.Count) and tonumber(saved.Count) == count then
        count = tonumber(saved.Count)
    end
    return painted, count
end

local function publicArt(art)
    local palette = {}
    for colorId = 1, art.PaletteSize do
        palette[colorId] = art.Palette[colorId]
    end
    return {
        Id = art.Id,
        Name = art.Name,
        Difficulty = art.Difficulty,
        Width = art.Width,
        Height = art.Height,
        Reward = art.Reward,
        PaletteSize = art.PaletteSize,
        Palette = palette,
        Pixels = art.Pixels,
    }
end

local function resultError(reason, extra)
    local result = extra or {}
    result.Ok = false
    result.Reason = reason
    return result
end

local function completedReward(profile, art)
    local reward = tonumber(art.Reward) or Config.DifficultyReward[art.Difficulty] or 0
    profile.Gems += reward
    return reward
end

local function finishIfComplete(player, session, profile, art)
    if session.Count < session.Total or session.Completed then
        return nil
    end
    session.Completed = true
    local reward = completedReward(profile, art)
    syncLeaderstats(player)
    persistSession(player)
    task.spawn(function()
        saveProfile(player)
    end)
    return reward
end

local function waitForProfile(player)
    local deadline = os.clock() + 15
    while not Profiles[player] and player.Parent == Players and os.clock() < deadline do
        task.wait()
    end
    return Profiles[player]
end

GetProfile.OnServerInvoke = function(player)
    local profile = waitForProfile(player)
    if not profile then
        return resultError("ProfileLoading")
    end
    return {
        Ok = true,
        Gems = profile.Gems,
        Upgrades = table.clone(profile.Upgrades),
        Progress = profileSummary(profile).Progress,
    }
end

StartArt.OnServerInvoke = function(player, artId, difficulty)
    local profile = Profiles[player]
    local baseArt = getArt(artId)
    if not profile then
        return resultError("ProfileLoading")
    end
    if not baseArt then
        return resultError("UnknownArt")
    end
    local variant = resolveVariant(baseArt, difficulty)
    if not variant then
        return resultError("UnknownDifficulty")
    end
    -- Preserve the previous active canvas when the player goes back to the
    -- gallery and opens another art before the next autosave.
    if Sessions[player] then
        persistSession(player)
    end
    local key = progressKey(baseArt, variant)
    local painted, count = getSavedState(profile, baseArt, variant)
    Sessions[player] = {
        ArtId = baseArt.Id,
        Difficulty = variant.Difficulty,
        ProgressKey = key,
        Art = variant,
        Painted = painted,
        Count = count,
        Total = variant.Width * variant.Height,
        Completed = count >= variant.Width * variant.Height,
        LastPaint = 0,
        LastAreaBrush = 0,
        LastColorHint = 0,
    }
    return {
        Ok = true,
        Art = publicArt(variant),
        ProgressKey = key,
        Bits = Codec.EncodeBits(painted, variant.Width * variant.Height),
        Count = count,
        Gems = profile.Gems,
        Upgrades = table.clone(profile.Upgrades),
    }
end

local function validatePaintRequest(player, artId, x, y, colorId)
    local profile = Profiles[player]
    local session = Sessions[player]
    if not profile or not session then
        return nil, nil, resultError("NoActiveArt")
    end
    if session.ArtId ~= artId then
        return nil, nil, resultError("ArtSessionMismatch")
    end
    local art = session.Art
    if not art then
        return nil, nil, resultError("UnknownArt")
    end
    if typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(colorId) ~= "number" then
        return nil, nil, resultError("InvalidCoordinates")
    end
    x = math.floor(x)
    y = math.floor(y)
    colorId = math.floor(colorId)
    if x < 1 or x > art.Width or y < 1 or y > art.Height or colorId < 1 or colorId > art.PaletteSize then
        return nil, nil, resultError("InvalidCoordinates")
    end
    local index = (y - 1) * art.Width + x
    return {
        Profile = profile,
        Session = session,
        Art = art,
        X = x,
        Y = y,
        ColorId = colorId,
        Index = index,
    }, profile, nil
end

PaintPixel.OnServerInvoke = function(player, artId, x, y, colorId, continuous)
    local request, profile, failure = validatePaintRequest(player, artId, x, y, colorId)
    if failure then
        return failure
    end
    local session = request.Session
    local art = request.Art
    if continuous == true and (tonumber(profile.Upgrades.AutoBrush) or 0) < 1 then
        return resultError("AbilityLocked", { Ability = "AutoBrush" })
    end
    local now = os.clock()
    -- This is a server-side guard for Auto-Brush and intentionally generous
    -- for normal taps. It prevents a malformed client from flooding invokes.
    if now - session.LastPaint < 0.025 then
        return resultError("RateLimited")
    end
    session.LastPaint = now
    if session.Painted[request.Index] then
        return resultError("AlreadyPainted", { Count = session.Count })
    end
    local expected = Codec.GetPixelId(art, request.Index)
    if expected ~= request.ColorId then
        return resultError("WrongColor", { X = request.X, Y = request.Y, Expected = expected })
    end
    session.Painted[request.Index] = true
    session.Count += 1
    -- Keep the active bit table mutable. Encoding a 65,536-bit string on
    -- every click would turn an Extreme canvas into an O(n^2) server task;
    -- persistSession encodes it during autosave/exit/completion instead.
    local progress = profile.ArtProgress[session.ProgressKey] or {}
    progress.Count = session.Count
    progress.Complete = session.Count >= session.Total
    profile.ArtProgress[session.ProgressKey] = progress
    local reward = finishIfComplete(player, session, profile, art)
    return {
        Ok = true,
        X = request.X,
        Y = request.Y,
        Count = session.Count,
        Total = session.Total,
        Progress = session.Count / session.Total,
        Completed = reward ~= nil,
        Reward = reward or 0,
        Gems = profile.Gems,
    }
end

local function abilityLevel(profile, name)
    return tonumber(profile.Upgrades[name]) or 0
end

local function fillCorrectCell(session, art, x, y, colorId)
    if x < 1 or x > art.Width or y < 1 or y > art.Height then
        return false
    end
    local index = (y - 1) * art.Width + x
    if session.Painted[index] or Codec.GetPixelId(art, index) ~= colorId then
        return false
    end
    session.Painted[index] = true
    session.Count += 1
    return true
end

UseAbility.OnServerInvoke = function(player, artId, abilityName, x, y, colorId)
    local request, profile, failure = validatePaintRequest(player, artId, x, y, colorId)
    if failure then
        return failure
    end
    local session = request.Session
    local art = request.Art
    local now = os.clock()
    local level = abilityLevel(profile, abilityName)
    if level < 1 then
        return resultError("AbilityLocked", { Ability = abilityName })
    end

    local changed = 0
    local encodedBits
    local hintColor
    local hintCount
    local hintDuration
    if abilityName == "AreaBrush" then
        local cooldown = Config.AreaBrushCooldownByLevel[level] or Config.AreaBrushCooldownByLevel[#Config.AreaBrushCooldownByLevel]
        if now - session.LastAreaBrush < cooldown then
            return resultError("Cooldown", { Cooldown = cooldown - (now - session.LastAreaBrush) })
        end
        session.LastAreaBrush = now
        local size = Config.AreaBrushSizeByLevel[level] or Config.AreaBrushSizeByLevel[#Config.AreaBrushSizeByLevel]
        local left = math.floor((size.Width - 1) / 2)
        local top = math.floor((size.Height - 1) / 2)
        for row = request.Y - top, request.Y - top + size.Height - 1 do
            for column = request.X - left, request.X - left + size.Width - 1 do
                if fillCorrectCell(session, art, column, row, request.ColorId) then
                    changed += 1
                end
            end
        end
    elseif abilityName == "ColorHint" then
        local cooldown = Config.ColorHintCooldownByLevel[level] or Config.ColorHintCooldownByLevel[#Config.ColorHintCooldownByLevel]
        if now - session.LastColorHint < cooldown then
            return resultError("Cooldown", { Cooldown = cooldown - (now - session.LastColorHint) })
        end
        session.LastColorHint = now
        local remainingByColor = table.create(art.PaletteSize, 0)
        for index = 1, session.Total do
            if not session.Painted[index] then
                local colorIdAtPixel = Codec.GetPixelId(art, index)
                remainingByColor[colorIdAtPixel] = (remainingByColor[colorIdAtPixel] or 0) + 1
            end
        end
        for colorIdAtPalette = 1, art.PaletteSize do
            if not hintCount or remainingByColor[colorIdAtPalette] > hintCount then
                hintColor = colorIdAtPalette
                hintCount = remainingByColor[colorIdAtPalette]
            end
        end
        hintDuration = Config.ColorHintDurationByLevel[level] or Config.ColorHintDurationByLevel[#Config.ColorHintDurationByLevel]
    else
        return resultError("UnknownAbility")
    end

    if changed > 0 then
        local progress = profile.ArtProgress[session.ProgressKey] or {}
        progress.Count = session.Count
        progress.Complete = session.Count >= session.Total
        encodedBits = Codec.EncodeBits(session.Painted, session.Total)
        progress.Bits = encodedBits
        profile.ArtProgress[session.ProgressKey] = progress
    end
    local reward = finishIfComplete(player, session, profile, art)
    return {
        Ok = true,
        Ability = abilityName,
        Changed = changed,
        Bits = encodedBits,
        Count = session.Count,
        Total = session.Total,
        Completed = reward ~= nil,
        Reward = reward or 0,
        Gems = profile.Gems,
        HintColor = hintColor,
        HintCount = hintCount,
        HintDuration = hintDuration,
    }
end

UpgradeAbility.OnServerInvoke = function(player, abilityName)
    local profile = Profiles[player]
    if not profile or type(abilityName) ~= "string" then
        return resultError("ProfileLoading")
    end
    local costs = Config.UpgradeCosts[abilityName]
    if not costs then
        return resultError("UnknownAbility")
    end
    local current = abilityLevel(profile, abilityName)
    if current >= Config.UpgradeMaxLevel then
        return resultError("MaxLevel")
    end
    local cost = costs[current + 1]
    if profile.Gems < cost then
        return resultError("NotEnoughGems", { Cost = cost })
    end
    profile.Gems -= cost
    profile.Upgrades[abilityName] = current + 1
    syncLeaderstats(player)
    task.spawn(function()
        saveProfile(player)
    end)
    ProfileChanged:FireClient(player, profileSummary(profile))
    return {
        Ok = true,
        Gems = profile.Gems,
        Upgrades = table.clone(profile.Upgrades),
    }
end

AdminAction.OnServerInvoke = function(player, action, artId)
    if player.Name ~= Config.AdminName then
        return resultError("Forbidden")
    end
    local profile = Profiles[player]
    if not profile then
        return resultError("ProfileLoading")
    end
    if action == "AddGems" then
        profile.Gems += 10000
        syncLeaderstats(player)
        task.spawn(function() saveProfile(player) end)
        return { Ok = true, Gems = profile.Gems, Upgrades = table.clone(profile.Upgrades) }
    elseif action == "MaxUpgrades" then
        for abilityName in pairs(profile.Upgrades) do
            profile.Upgrades[abilityName] = Config.UpgradeMaxLevel
        end
        task.spawn(function() saveProfile(player) end)
        ProfileChanged:FireClient(player, profileSummary(profile))
        return { Ok = true, Gems = profile.Gems, Upgrades = table.clone(profile.Upgrades) }
    end

    local session = Sessions[player]
    if not session or session.ArtId ~= artId then
        return resultError("NoActiveArt")
    end
    local art = session.Art
    if not art then
        return resultError("UnknownArt")
    end
    if action == "InstantComplete" then
        for index = 1, session.Total do
            session.Painted[index] = true
        end
        session.Count = session.Total
        session.Completed = false
        local reward = finishIfComplete(player, session, profile, art) or 0
        return {
            Ok = true,
            Action = action,
            Count = session.Count,
            Total = session.Total,
            Reward = reward,
            Gems = profile.Gems,
            Bits = Codec.EncodeBits(session.Painted, session.Total),
        }
    elseif action == "ResetArtProgress" then
        session.Painted = {}
        session.Count = 0
        session.Completed = false
        profile.ArtProgress[session.ProgressKey] = nil
        task.spawn(function() saveProfile(player) end)
        return {
            Ok = true,
            Action = action,
            Count = 0,
            Total = session.Total,
            Gems = profile.Gems,
            Bits = Codec.NewBits(session.Total),
        }
    end
    return resultError("UnknownAdminAction")
end

Players.PlayerAdded:Connect(function(player)
    loadProfile(player)
end)

Players.PlayerRemoving:Connect(function(player)
    persistSession(player)
    saveProfile(player)
    Profiles[player] = nil
    Sessions[player] = nil
    Saving[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(loadProfile, player)
end

task.spawn(function()
    while task.wait(Config.AutosaveSeconds) do
        for player in pairs(Profiles) do
            if player.Parent == Players then
                task.spawn(saveProfile, player, false)
            end
        end
    end
end)

game:BindToClose(function()
    local pending = 0
    for player in pairs(Profiles) do
        pending += 1
        task.spawn(function()
            saveProfile(player, true)
            pending -= 1
        end)
    end
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do
        task.wait()
    end
end)
]=]

replaceSource(ServerScriptService, "Script", "PaintByNumbersServer", serverSource)

-- ---------------------------- Client source -----------------------------
local clientSource = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local AssetService = game:GetService("AssetService")

local player = Players.LocalPlayer
local package = ReplicatedStorage:WaitForChild("PaintByNumbers")
local shared = package:WaitForChild("Shared")
local remotes = package:WaitForChild("Remotes")
local artLibrary = package:WaitForChild("ArtLibrary")
local Config = require(shared:WaitForChild("Config"))
local Codec = require(shared:WaitForChild("PixelCodec"))

local GetProfile = remotes:WaitForChild("GetProfile")
local StartArt = remotes:WaitForChild("StartArt")
local PaintPixel = remotes:WaitForChild("PaintPixel")
local UseAbility = remotes:WaitForChild("UseAbility")
local UpgradeAbility = remotes:WaitForChild("UpgradeAbility")
local AdminAction = remotes:WaitForChild("AdminAction")
local ProfileChanged = remotes:WaitForChild("ProfileChanged")
local ToastEvent = remotes:WaitForChild("Toast")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("PaintByNumbersGui")
local root = gui:WaitForChild("Root")
local home = root:WaitForChild("Home")
local catalog = root:WaitForChild("Catalog")
local paint = root:WaitForChild("Paint")
local shop = root:WaitForChild("Shop")

local drawButton = home:WaitForChild("DrawButton")
local shopButton = home:WaitForChild("ShopButton")
local gemsLabel = home:WaitForChild("GemsLabel")
local catalogBack = catalog:FindFirstChild("BackButton", true)
local levelGrid = catalog:FindFirstChild("LevelGrid", true)
local cardTemplate = catalog:FindFirstChild("CardTemplate", true)
local noArtsLabel = catalog:FindFirstChild("NoArts", true)
local navHome = catalog:FindFirstChild("Home", true)
local difficultyModal = catalog:FindFirstChild("DifficultyModal", true)
local difficultyArtName = catalog:FindFirstChild("DifficultyArtName", true)
local difficultyButtons = catalog:FindFirstChild("DifficultyButtons", true)
local difficultyTemplate = catalog:FindFirstChild("DifficultyTemplate", true)
local difficultyClose = catalog:FindFirstChild("DifficultyClose", true)
local paintBack = paint:FindFirstChild("BackButton", true)
local paintingName = paint:FindFirstChild("PaintingName", true)
local paintingDifficulty = paint:FindFirstChild("PaintingDifficulty", true)
local paintingProgress = paint:FindFirstChild("PaintingProgress", true)
local canvasViewport = paint:WaitForChild("CanvasViewport")
local canvasSurface = canvasViewport:WaitForChild("CanvasSurface")
local numberLayer = canvasViewport:FindFirstChild("NumberLayer")
if not numberLayer then
    -- Compatibility with a place generated by an older builder revision.
    numberLayer = Instance.new("Frame")
    numberLayer.Name = "NumberLayer"
    numberLayer.BackgroundTransparency = 1
    numberLayer.BorderSizePixel = 0
    numberLayer.ClipsDescendants = true
    numberLayer.ZIndex = canvasSurface.ZIndex + 2
    numberLayer.Parent = canvasViewport
end
local virtualLayer = canvasViewport:WaitForChild("VirtualLayer")
local paletteButtons = paint:FindFirstChild("PaletteButtons", true)
local paletteTemplate = paint:FindFirstChild("PaletteButtonTemplate", true)
local colorHint = paint:WaitForChild("ColorHint")
local areaButton = paint:FindFirstChild("AreaBrushButton", true)
local hintButton = paint:FindFirstChild("ColorHintButton", true)
local autoButton = paint:FindFirstChild("AutoBrushButton", true)
if not areaButton or not hintButton or not autoButton then
    error("PaintByNumbers: ability buttons are missing from generated UI")
end
local victory = paint:WaitForChild("VictoryModal")
local victoryText = victory:WaitForChild("Message")
local victoryClose = victory:WaitForChild("ContinueButton")
local toast = root:WaitForChild("Toast")
local shopClose = shop:FindFirstChild("CloseButton", true)
pcall(function() canvasSurface.ResampleMode = Enum.ResamplerMode.Pixelated end)

local profile = { Gems = Config.StartingGems, Upgrades = { AutoBrush = 0, AreaBrush = 0, ColorHint = 0 }, Progress = {} }
local arts = {}
local artById = {}
local currentArt
local currentArtId
local currentDifficulty
local currentProgressKey
local pendingArt
local currentBits = ""
local paintedCells = {}
local currentCount = 0
local selectedColor = 1
local canvasImage
local canvasImageUsable = false
local pixelScale = 1
local zoom = 1
local pan = Vector2.zero
local pointerDown = false
local pointerInput
local pointerStart = Vector2.zero
local panStart = Vector2.zero
local pointerMoved = false
local lastPaintSent = 0
local selectedAbility
local touchPositions = {}
local lastPinchDistance
local adminPanel
local toastToken = 0
local numberLabels = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function invoke(remote, ...)
    -- A nested closure cannot access the outer function's varargs in Luau.
    -- Pass them explicitly to the protected closure instead.
    local ok, result = pcall(function(...)
        return remote:InvokeServer(...)
    end, ...)
    if not ok then
        return { Ok = false, Reason = "NetworkError", Detail = result }
    end
    return result or { Ok = false, Reason = "EmptyResponse" }
end

local function setPaintedCells(bits, total)
    currentBits = type(bits) == "string" and bits or ""
    table.clear(paintedCells)
    if type(bits) ~= "string" then
        return
    end
    for index = 1, total do
        if string.byte(bits, index) == 49 then
            paintedCells[index] = true
        end
    end
end

local function updateGems(value)
    if typeof(value) == "number" then
        profile.Gems = value
    end
    gemsLabel.Text = "Gems  " .. tostring(profile.Gems or 0)
end

local function refreshAbilityButtons()
    local upgrades = profile.Upgrades or {}
    areaButton.Text = "Area  L" .. tostring(upgrades.AreaBrush or 0)
    hintButton.Text = "Hint  L" .. tostring(upgrades.ColorHint or 0)
    autoButton.Text = "Auto Brush  L" .. tostring(upgrades.AutoBrush or 0)
end

local function updateProfile(data)
    if type(data) ~= "table" then
        return
    end
    if data.Gems ~= nil then
        profile.Gems = data.Gems
    end
    if type(data.Upgrades) == "table" then
        profile.Upgrades = data.Upgrades
    end
    refreshAbilityButtons()
    if type(data.Progress) == "table" then
        profile.Progress = data.Progress
    end
    updateGems(profile.Gems)
end

local function showToast(message, isError)
    toastToken += 1
    local token = toastToken
    toast.Text = tostring(message)
    toast.Visible = true
    toast.TextColor3 = isError and Color3.fromRGB(255, 190, 190) or Color3.fromRGB(255, 255, 255)
    toast.BackgroundColor3 = isError and Color3.fromRGB(120, 45, 58) or Color3.fromRGB(38, 57, 89)
    toast.Position = UDim2.new(0.5, 0, 0, -48)
    TweenService:Create(toast, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 0, 18) }):Play()
    task.delay(2.2, function()
        if token == toastToken then
            local tween = TweenService:Create(toast, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 0, -48) })
            tween:Play()
            tween.Completed:Wait()
            if token == toastToken then
                toast.Visible = false
            end
        end
    end)
end

local function reasonText(result)
    local reason = result and result.Reason
    local messages = {
        WrongColor = "That pixel needs another color.",
        AlreadyPainted = "This pixel is already colored.",
        AbilityLocked = "Upgrade this ability in the shop first.",
        NotEnoughGems = "You need more gems.",
        Cooldown = "Ability is recharging.",
        RateLimited = "Slow down a little.",
        Forbidden = "Developer-only action.",
        NoActiveArt = "Open an art first.",
        NetworkError = "The server could not be reached.",
    }
    return messages[reason] or tostring(reason or "Action failed")
end

local function shakeCanvas()
    local original = canvasViewport.Position
    local sequence = {
        original + UDim2.fromOffset(-5, 0),
        original + UDim2.fromOffset(5, 0),
        original + UDim2.fromOffset(-3, 0),
        original,
    }
    task.spawn(function()
        for _, position in ipairs(sequence) do
            canvasViewport.Position = position
            task.wait(0.025)
        end
    end)
    local oldColor = canvasViewport.BackgroundColor3
    canvasViewport.BackgroundColor3 = Color3.fromRGB(115, 48, 64)
    task.delay(0.12, function()
        if canvasViewport and canvasViewport.Parent then
            canvasViewport.BackgroundColor3 = oldColor
        end
    end)
end

local function loadArts()
    table.clear(arts)
    table.clear(artById)
    for _, module in ipairs(artLibrary:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, art = pcall(require, module)
            local hasFixedPixels = type(art) == "table" and art.Width and art.Height and art.Pixels
            local hasVariants = type(art) == "table" and type(art.Variants) == "table"
            if ok and type(art) == "table" and art.Id and (hasFixedPixels or hasVariants) then
                arts[#arts + 1] = art
                artById[art.Id] = art
            end
        end
    end
    table.sort(arts, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
end

local function clientVariantFor(art, difficulty)
    if type(art.Variants) == "table" then
        return art.Variants[difficulty]
    end
    return art
end

local function clientProgressKey(art, difficulty)
    return art.Id .. "@" .. tostring(difficulty)
end

local function defaultClientVariant(art)
    if type(art.Variants) == "table" then
        return art.Variants.Easy or art.Variants.Medium or art.Variants.Hard or art.Variants["Extreme / Unreal"]
    end
    return art
end

local function artDifficulties(art)
    -- The server supplies a nearest-neighbour fallback for both legacy
    -- single-resolution modules and partial Variants tables.
    return table.clone(Config.DifficultyOrder)
end

local function makeEditableImage(width, height)
    local ok, image = pcall(function()
        return AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
    end)
    if not ok or not image then
        return nil
    end
    local assigned = pcall(function()
        canvasSurface.ImageContent = Content.fromObject(image)
    end)
    if not assigned then
        pcall(function() image:Destroy() end)
        return nil
    end
    return image
end

local function colorForPixel(colorId, painted)
    if not painted then
        -- Never reveal source colors before the player paints. The sheet is
        -- genuinely white; only the virtual number overlay supplies guidance.
        return Color3.fromRGB(255, 255, 255)
    end
    return currentArt.Palette[colorId] or Color3.fromRGB(255, 255, 255)
end

local function paintPixelColor(image, x, y, color)
    local ok = pcall(function()
        image:DrawRectangle(Vector2.new(x, y), Vector2.new(1, 1), color, 0, Enum.ImageCombineType.Overwrite)
    end)
    return ok
end

local function renderWithEditableImage()
    if not canvasImageUsable or not canvasImage or not currentArt then
        return false
    end
    local width = currentArt.Width
    local height = currentArt.Height
    local bytesOk = pcall(function()
        local pixels = buffer.create(width * height * 4)
        for index = 1, width * height do
            local colorId = Codec.GetPixelId(currentArt, index)
            local color = colorForPixel(colorId, paintedCells[index] == true)
            local offset = (index - 1) * 4
            buffer.writeu8(pixels, offset, math.floor(color.R * 255 + 0.5))
            buffer.writeu8(pixels, offset + 1, math.floor(color.G * 255 + 0.5))
            buffer.writeu8(pixels, offset + 2, math.floor(color.B * 255 + 0.5))
            buffer.writeu8(pixels, offset + 3, 255)
        end
        canvasImage:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), pixels)
    end)
    if bytesOk then
        return true
    end

    -- Compatibility fallback for Studio versions that expose EditableImage
    -- but not WritePixelsBuffer. It draws horizontal runs, not 65,536 Frames.
    local drawOk = pcall(function()
        for y = 1, height do
            local runStart = 1
            local lastColorId = Codec.GetPixelId(currentArt, (y - 1) * width + 1)
            local lastPainted = paintedCells[(y - 1) * width + 1] == true
            for x = 2, width + 1 do
                local index = (y - 1) * width + x
                local colorId = x <= width and Codec.GetPixelId(currentArt, index) or -1
                local painted = x <= width and paintedCells[index] == true or false
                if colorId ~= lastColorId or painted ~= lastPainted or x == width + 1 then
                    local color = colorForPixel(lastColorId, lastPainted)
                    canvasImage:DrawRectangle(
                        Vector2.new(runStart - 1, y - 1),
                        Vector2.new(x - runStart, 1),
                        color,
                        0,
                        Enum.ImageCombineType.Overwrite
                    )
                    runStart = x
                    lastColorId = colorId
                    lastPainted = painted
                end
            end
        end
    end)
    return drawOk
end

local function clearVirtualLayer()
    for _, child in ipairs(virtualLayer:GetChildren()) do
        child:Destroy()
    end
end

local function renderVirtualFallback()
    clearVirtualLayer()
    if not currentArt then
        return
    end
    -- A fallback is a chunk renderer: at most about 1,024 Frames even for a
    -- 256x256 art. EditableImage is used in normal supported clients.
    local total = currentArt.Width * currentArt.Height
    local chunk = math.max(1, math.ceil(math.sqrt(total / 900)))
    local cellWidth = canvasSurface.AbsoluteSize.X / currentArt.Width
    local cellHeight = canvasSurface.AbsoluteSize.Y / currentArt.Height
    virtualLayer.Size = canvasSurface.Size
    virtualLayer.Position = canvasSurface.Position
    virtualLayer.AnchorPoint = canvasSurface.AnchorPoint
    local canvasTopLeft = canvasSurface.AbsolutePosition
    local viewTopLeft = canvasViewport.AbsolutePosition
    local viewBottomRight = viewTopLeft + canvasViewport.AbsoluteSize
    local firstX = math.max(1, math.floor((viewTopLeft.X - canvasTopLeft.X) / cellWidth / chunk) * chunk + 1)
    local firstY = math.max(1, math.floor((viewTopLeft.Y - canvasTopLeft.Y) / cellHeight / chunk) * chunk + 1)
    local lastX = math.min(currentArt.Width, math.ceil((viewBottomRight.X - canvasTopLeft.X) / cellWidth))
    local lastY = math.min(currentArt.Height, math.ceil((viewBottomRight.Y - canvasTopLeft.Y) / cellHeight))
    local made = 0
    for y = firstY, lastY, chunk do
        for x = firstX, lastX, chunk do
            if made >= 1100 then
                break
            end
            local xEnd = math.min(currentArt.Width, x + chunk - 1)
            local yEnd = math.min(currentArt.Height, y + chunk - 1)
            local colorId = Codec.GetPixelId(currentArt, (y - 1) * currentArt.Width + x)
            local highlighted = false
            local painted = true
            for row = y, yEnd do
                for column = x, xEnd do
                    local index = (row - 1) * currentArt.Width + column
                    highlighted = highlighted or (Codec.GetPixelId(currentArt, index) == selectedColor and paintedCells[index] ~= true)
                    painted = painted and paintedCells[index] == true
                end
            end
            local cell = Instance.new("Frame")
            cell.Name = "Chunk"
            cell.BorderSizePixel = 0
            cell.BackgroundColor3 = highlighted and colorForPixel(selectedColor, false) or colorForPixel(colorId, painted)
            cell.BackgroundTransparency = 0
            cell.Position = UDim2.fromOffset((x - 1) * cellWidth, (y - 1) * cellHeight)
            cell.Size = UDim2.fromOffset((xEnd - x + 1) * cellWidth + 1, (yEnd - y + 1) * cellHeight + 1)
            cell.Parent = virtualLayer
            made += 1
        end
    end
end

local function clearNumberLayer()
    for _, child in ipairs(numberLayer:GetChildren()) do
        child:Destroy()
    end
    table.clear(numberLabels)
end

local function removeNumberLabel(index)
    local label = numberLabels[index]
    if label then
        label:Destroy()
        numberLabels[index] = nil
    end
end

local function renderNumberOverlay()
    clearNumberLayer()
    numberLayer.Visible = false
    if not currentArt then
        return
    end
    local width = currentArt.Width
    local minimumScale = width <= 32 and 2 or (width <= 64 and 4 or 7)
    if pixelScale < minimumScale then
        return
    end
    numberLayer.Visible = true
    local height = currentArt.Height
    local cellWidth = canvasSurface.AbsoluteSize.X / width
    local cellHeight = canvasSurface.AbsoluteSize.Y / height
    if cellWidth <= 0 or cellHeight <= 0 then
        return
    end
    local topLeft = canvasSurface.AbsolutePosition
    local viewTopLeft = canvasViewport.AbsolutePosition
    local viewBottomRight = viewTopLeft + canvasViewport.AbsoluteSize
    local firstX = math.max(1, math.floor((viewTopLeft.X - topLeft.X) / cellWidth) + 1)
    local firstY = math.max(1, math.floor((viewTopLeft.Y - topLeft.Y) / cellHeight) + 1)
    local lastX = math.min(width, math.ceil((viewBottomRight.X - topLeft.X) / cellWidth))
    local lastY = math.min(height, math.ceil((viewBottomRight.Y - topLeft.Y) / cellHeight))
    if firstX > lastX or firstY > lastY then
        return
    end
    local made = 0
    -- Easy can show its complete 32x32 number sheet. Larger canvases are
    -- virtualized and capped; zoom/pan reveals more numbers without creating
    -- thousands of GUI objects, especially for 128x128 and 256x256.
    local maxLabels = width <= 32 and 1100 or (width <= 64 and 1000 or 650)
    local visibleCells = (lastX - firstX + 1) * (lastY - firstY + 1)
    local sampleStep = math.max(1, math.ceil(math.sqrt(visibleCells / maxLabels)))
    for y = firstY, lastY, sampleStep do
        for x = firstX, lastX, sampleStep do
            if made >= maxLabels then
                break
            end
            local index = (y - 1) * width + x
            if paintedCells[index] ~= true then
                local colorId = Codec.GetPixelId(currentArt, index)
                local label = Instance.new("TextLabel")
                label.Name = "PixelNumber"
                label.Text = tostring(colorId)
                label.TextColor3 = Color3.fromRGB(75, 81, 91)
                label.TextSize = clamp(math.floor(pixelScale * 0.52), 8, 16)
                label.TextScaled = false
                label.Font = Enum.Font.Gotham
                label.TextXAlignment = Enum.TextXAlignment.Center
                label.TextYAlignment = Enum.TextYAlignment.Center
                label.BackgroundColor3 = colorId == selectedColor and Color3.fromRGB(222, 238, 255) or Color3.fromRGB(255, 255, 255)
                label.BackgroundTransparency = 0.04
                label.BorderColor3 = Color3.fromRGB(205, 210, 218)
                label.BorderSizePixel = 1
                label.Position = UDim2.fromScale((x - 1) / width, (y - 1) / height)
                label.Size = UDim2.fromScale(1 / width, 1 / height)
                label.ZIndex = numberLayer.ZIndex
                label.Parent = numberLayer
                numberLabels[index] = label
                made += 1
            end
        end
    end
end

local function layoutCanvas()
    if not currentArt then
        return
    end
    local viewportSize = canvasViewport.AbsoluteSize
    if viewportSize.X < 2 or viewportSize.Y < 2 then
        return
    end
    local fit = math.min(viewportSize.X / currentArt.Width, viewportSize.Y / currentArt.Height) * 0.92
    pixelScale = math.max(0.5, fit * zoom)
    canvasSurface.AnchorPoint = Vector2.new(0.5, 0.5)
    canvasSurface.Position = UDim2.new(0.5, pan.X, 0.5, pan.Y)
    canvasSurface.Size = UDim2.fromOffset(currentArt.Width * pixelScale, currentArt.Height * pixelScale)
    numberLayer.AnchorPoint = canvasSurface.AnchorPoint
    numberLayer.Position = canvasSurface.Position
    numberLayer.Size = canvasSurface.Size
    virtualLayer.AnchorPoint = canvasSurface.AnchorPoint
    virtualLayer.Position = canvasSurface.Position
    virtualLayer.Size = canvasSurface.Size
    if not canvasImageUsable then
        renderVirtualFallback()
    end
    renderNumberOverlay()
end

local updateProgressLabel

local function renderCanvas()
    if not currentArt then
        return
    end
    canvasSurface.Visible = true
    if canvasImageUsable then
        renderWithEditableImage()
    else
        renderVirtualFallback()
    end
    renderNumberOverlay()
    updateProgressLabel()
end

local function setZoomAt(screenPosition, multiplier)
    if not currentArt then
        return
    end
    local before = Vector2.zero
    local oldSize = canvasSurface.AbsoluteSize
    if oldSize.X > 0 and oldSize.Y > 0 then
        before = Vector2.new(
            (screenPosition.X - canvasSurface.AbsolutePosition.X) / oldSize.X,
            (screenPosition.Y - canvasSurface.AbsolutePosition.Y) / oldSize.Y
        )
    end
    zoom = clamp(zoom * multiplier, 0.55, 8)
    layoutCanvas()
    local newSize = canvasSurface.AbsoluteSize
    if oldSize.X > 0 and oldSize.Y > 0 and newSize.X > 0 and newSize.Y > 0 then
        local after = Vector2.new(
            (screenPosition.X - canvasSurface.AbsolutePosition.X) / newSize.X,
            (screenPosition.Y - canvasSurface.AbsolutePosition.Y) / newSize.Y
        )
        pan += Vector2.new((after.X - before.X) * newSize.X, (after.Y - before.Y) * newSize.Y)
        layoutCanvas()
    end
end

local function cellAtScreenPosition(position)
    if not currentArt or canvasSurface.AbsoluteSize.X <= 0 then
        return nil
    end
    local localX = position.X - canvasSurface.AbsolutePosition.X
    local localY = position.Y - canvasSurface.AbsolutePosition.Y
    if localX < 0 or localY < 0 or localX >= canvasSurface.AbsoluteSize.X or localY >= canvasSurface.AbsoluteSize.Y then
        return nil
    end
    local x = math.floor(localX / canvasSurface.AbsoluteSize.X * currentArt.Width) + 1
    local y = math.floor(localY / canvasSurface.AbsoluteSize.Y * currentArt.Height) + 1
    if x < 1 or y < 1 or x > currentArt.Width or y > currentArt.Height then
        return nil
    end
    return x, y
end

local function updateBitsForPaint(x, y)
    local index = (y - 1) * currentArt.Width + x
    if paintedCells[index] == true then
        return
    end
    -- Keep the presentation state mutable as a table. Rebuilding a 65,536
    -- byte string for every click would make a full Extreme canvas O(n^2).
    paintedCells[index] = true
    currentCount += 1
end

updateProgressLabel = function()
    if not currentArt then
        return
    end
    local total = currentArt.Width * currentArt.Height
    local percentage = math.floor((currentCount / total) * 100 + 0.5)
    paintingProgress.Text = tostring(percentage) .. "%  •  " .. tostring(currentCount) .. "/" .. tostring(total)
    colorHint.Text = "Selected color " .. tostring(selectedColor) .. "  •  highlighted pixels need this number"
end

local function updateSingleCanvasPixel(x, y)
    if not currentArt then
        return
    end
    if canvasImageUsable and canvasImage then
        local index = (y - 1) * currentArt.Width + x
        local color = currentArt.Palette[Codec.GetPixelId(currentArt, index)] or Color3.fromRGB(255, 255, 255)
        pcall(function()
            canvasImage:DrawRectangle(
                Vector2.new(x - 1, y - 1),
                Vector2.new(1, 1),
                color,
                0,
                Enum.ImageCombineType.Overwrite
            )
        end)
    else
        -- The compatibility renderer is chunk-based, so repaint only its
        -- visible chunks. It still never creates one GUI object per pixel.
        renderVirtualFallback()
    end
end

local function showVictory(reward)
    victoryText.Text = string.format(
        "Congratulations, you’ve colored %s level %s. You received %d gems.",
        currentArt.Name,
        string.lower(currentArt.Difficulty),
        reward or 0
    )
    victory.Visible = true
end

local function sendPaint(x, y, continuous)
    if not currentArt or victory.Visible then
        return
    end
    local now = os.clock()
    if now - lastPaintSent < (continuous and 0.045 or 0.035) then
        return
    end
    lastPaintSent = now
    local result = invoke(PaintPixel, currentArtId, x, y, selectedColor, continuous == true)
    if result.Ok then
        if paintedCells[(y - 1) * currentArt.Width + x] ~= true then
            updateBitsForPaint(x, y)
        end
        local index = (y - 1) * currentArt.Width + x
        currentCount = result.Count or currentCount
        profile.Progress[currentProgressKey or currentArtId] = { Count = currentCount, Complete = result.Completed == true }
        updateGems(result.Gems)
        updateSingleCanvasPixel(x, y)
        removeNumberLabel(index)
        updateProgressLabel()
        if result.Completed then
            showVictory(result.Reward)
        end
    elseif result.Reason == "WrongColor" then
        shakeCanvas()
    elseif result.Reason ~= "AlreadyPainted" and result.Reason ~= "RateLimited" then
        showToast(reasonText(result), true)
    end
end

local function useAbility(abilityName, x, y)
    if not currentArt or victory.Visible then
        return
    end
    local result = invoke(UseAbility, currentArtId, abilityName, x, y, selectedColor)
    if result.Ok then
        -- Abilities return one exact bitset because they may affect many
        -- cells at once; normal clicks update only the local boolean table.
        currentCount = result.Count or currentCount
        profile.Progress[currentProgressKey or currentArtId] = { Count = currentCount, Complete = result.Completed == true }
        updateGems(result.Gems)
        if result.HintColor then
            selectedColor = result.HintColor
            showToast("Hint: color " .. tostring(result.HintColor) .. " • " .. tostring(result.HintCount or 0) .. " pixels")
        end
        if result.Changed and result.Changed > 0 and result.Bits then
            -- The server returns one exact bitset for the whole ability, so
            -- the client does not need to restart the art session.
            setPaintedCells(result.Bits, currentArt.Width * currentArt.Height)
        end
        renderCanvas()
        if result.Completed then
            showVictory(result.Reward)
        end
    elseif result.Reason ~= "Cooldown" then
        showToast(reasonText(result), true)
    end
end

local function selectColor(colorId)
    selectedColor = colorId
    for _, button in ipairs(paletteButtons:GetChildren()) do
        if button:IsA("TextButton") then
            local selected = button:GetAttribute("ColorId") == colorId
            local stroke = button:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Thickness = selected and 3 or 0
                stroke.Transparency = selected and 0 or 1
                stroke.Color = Color3.fromRGB(255, 255, 255)
            end
        end
    end
    renderCanvas()
end

local function buildPalette()
    for _, child in ipairs(paletteButtons:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    if not currentArt then
        return
    end
    for colorId = 1, currentArt.PaletteSize do
        local button = paletteTemplate and paletteTemplate:Clone() or Instance.new("TextButton")
        button.Name = "Color" .. tostring(colorId)
        button:SetAttribute("ColorId", colorId)
        button.Visible = true
        button.Text = tostring(colorId)
        button.TextSize = 18
        local paletteColor = currentArt.Palette[colorId]
        local luminance = paletteColor.R * 0.299 + paletteColor.G * 0.587 + paletteColor.B * 0.114
        button.TextColor3 = luminance > 0.62 and Color3.fromRGB(24, 29, 38) or Color3.fromRGB(255, 255, 255)
        button.BackgroundColor3 = paletteColor
        button.BackgroundTransparency = 0
        button.BorderSizePixel = 0
        button.Size = currentArt.PaletteSize <= 8 and UDim2.new(1 / currentArt.PaletteSize, -2, 1, -10) or UDim2.fromOffset(64, 64)
        button.AutoButtonColor = true
        button.Active = true
        button.Parent = paletteButtons
        local corner = button:FindFirstChildOfClass("UICorner")
        if not corner then
            corner = Instance.new("UICorner")
            corner.Parent = button
        end
        corner.CornerRadius = UDim.new(0, 0)
        local stroke = button:FindFirstChildOfClass("UIStroke")
        if not stroke then
            stroke = Instance.new("UIStroke")
            stroke.Parent = button
        end
        stroke.Thickness = 0
        stroke.Transparency = 1
        button.Activated:Connect(function()
            selectColor(colorId)
        end)
    end
    selectColor(math.min(selectedColor, currentArt.PaletteSize))
end

local function artProgress(art)
    local variant = defaultClientVariant(art)
    if not variant then
        return 0, 1
    end
    local difficulty = variant.Difficulty or art.Difficulty or "Easy"
    local saved = profile.Progress and profile.Progress[clientProgressKey(art, difficulty)]
    if not saved and type(art.Variants) ~= "table" and difficulty == art.Difficulty then
        saved = profile.Progress and profile.Progress[art.Id]
    end
    return saved and tonumber(saved.Count) or 0, variant.Width * variant.Height
end

local function renderPreview(imageLabel, art)
    local ok, image = pcall(function()
        return AssetService:CreateEditableImage({ Size = Vector2.new(32, 32) })
    end)
    if not ok or not image then
        imageLabel.BackgroundColor3 = art.Palette[1] or Color3.fromRGB(80, 100, 140)
        return
    end
    local wrote = pcall(function()
        local bytes = buffer.create(32 * 32 * 4)
        for index = 1, 32 * 32 do
            local sourceX = math.floor(((index - 1) % 32) / 32 * art.Width) + 1
            local sourceY = math.floor((math.floor((index - 1) / 32)) / 32 * art.Height) + 1
            local sourceIndex = (sourceY - 1) * art.Width + sourceX
            local color = art.Palette[Codec.GetPixelId(art, sourceIndex)] or Color3.fromRGB(80, 100, 140)
            local offset = (index - 1) * 4
            buffer.writeu8(bytes, offset, math.floor(color.R * 255))
            buffer.writeu8(bytes, offset + 1, math.floor(color.G * 255))
            buffer.writeu8(bytes, offset + 2, math.floor(color.B * 255))
            buffer.writeu8(bytes, offset + 3, 255)
        end
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(32, 32), bytes)
        imageLabel.ImageContent = Content.fromObject(image)
    end)
    if not wrote then
        pcall(function() image:Destroy() end)
        imageLabel.BackgroundColor3 = art.Palette[1] or Color3.fromRGB(80, 100, 140)
    end
end

local function startArt(art, difficulty)
    local response = invoke(StartArt, art.Id, difficulty)
    if not response.Ok then
        showToast(reasonText(response), true)
        return
    end
    currentArtId = art.Id
    currentDifficulty = response.Art.Difficulty
    currentProgressKey = response.ProgressKey or clientProgressKey(art, currentDifficulty)
    currentArt = response.Art
    setPaintedCells(response.Bits or "", currentArt.Width * currentArt.Height)
    currentCount = response.Count or 0
    profile.Upgrades = response.Upgrades or profile.Upgrades
    refreshAbilityButtons()
    updateGems(response.Gems)
    selectedColor = 1
    zoom = 1
    pan = Vector2.zero
    pointerDown = false
    canvasImage = makeEditableImage(currentArt.Width, currentArt.Height)
    canvasImageUsable = canvasImage ~= nil
    virtualLayer.Visible = not canvasImageUsable
    paintingName.Text = currentArt.Name
    paintingDifficulty.Text = currentArt.Difficulty
    victory.Visible = false
    buildPalette()
    if difficultyModal then difficultyModal.Visible = false end
    home.Visible = false
    catalog.Visible = false
    shop.Visible = false
    paint.Visible = true
    task.defer(function()
        layoutCanvas()
        renderCanvas()
    end)
end

local function openDifficultyPicker(art)
    pendingArt = art
    if not difficultyModal or not difficultyButtons or not difficultyTemplate then
        startArt(art, art.Difficulty or "Easy")
        return
    end
    for _, child in ipairs(difficultyButtons:GetChildren()) do
        if child:GetAttribute("PBNDifficultyButton") then
            child:Destroy()
        end
    end
    if difficultyArtName then
        difficultyArtName.Text = art.Name
    end
    for order, difficulty in ipairs(artDifficulties(art)) do
        local variant = clientVariantFor(art, difficulty)
        local size = variant and variant.Width or Config.AllowedSizes[difficulty]
        local saved = profile.Progress and profile.Progress[clientProgressKey(art, difficulty)]
        if not saved and type(art.Variants) ~= "table" and difficulty == art.Difficulty then
            saved = profile.Progress and profile.Progress[art.Id]
        end
        local savedCount = saved and tonumber(saved.Count) or 0
        local total = size * size
        local percentage = math.floor(savedCount / math.max(total, 1) * 100 + 0.5)
        local button = difficultyTemplate:Clone()
        button.Name = "Difficulty_" .. tostring(difficulty):gsub("[^%w]", "")
        button:SetAttribute("PBNDifficultyButton", true)
        button.Visible = true
        button.LayoutOrder = order
        button.Text = string.format("%s   %dx%d   %d%%", difficulty, size, size, percentage)
        button.Parent = difficultyButtons
        button.Activated:Connect(function()
            startArt(art, difficulty)
        end)
    end
    difficultyModal.Visible = true
end

local function renderCatalog()
    for _, child in ipairs(levelGrid:GetChildren()) do
        if child:GetAttribute("PBNCard") then
            child:Destroy()
        end
    end
    noArtsLabel.Visible = #arts == 0
    for order, art in ipairs(arts) do
        local card = cardTemplate:Clone()
        card.Name = "Card_" .. tostring(art.Id)
        card:SetAttribute("PBNCard", true)
        card.Visible = true
        card.LayoutOrder = order
        card.Parent = levelGrid
        local title = card:FindFirstChild("Title", true)
        local difficulty = card:FindFirstChild("Difficulty", true)
        local reward = card:FindFirstChild("Reward", true)
        local progress = card:FindFirstChild("Progress", true)
        local fill = card:FindFirstChild("ProgressFill", true)
        local preview = card:FindFirstChild("Preview", true)
        local completion = card:FindFirstChild("CompletionMark", true)
        local select = card:FindFirstChild("Select", true)
        local previewArt = defaultClientVariant(art)
        local count, total = artProgress(art)
        local percentage = math.floor(count / math.max(total, 1) * 100 + 0.5)
        if title then title.Text = art.Name end
        if difficulty then
            difficulty.Text = type(art.Variants) == "table" and "Easy • Medium • Hard • Extreme" or tostring(art.Difficulty or "Easy")
        end
        if reward then reward.Text = "+" .. tostring((previewArt and previewArt.Reward) or art.Reward or 0) .. " gems" end
        if progress then progress.Text = tostring(percentage) .. "%" end
        if completion then
            completion.Text = "✓"
            completion.TextColor3 = count >= total and Color3.fromRGB(91, 176, 74) or Color3.fromRGB(126, 139, 153)
        end
        if fill then fill.Size = UDim2.new(clamp(count / math.max(total, 1), 0, 1), 0, 1, 0) end
        if preview and preview:IsA("ImageLabel") and previewArt then renderPreview(preview, previewArt) end
        if select and select:IsA("GuiButton") then
            select.Activated:Connect(function()
                openDifficultyPicker(art)
            end)
        end
    end
end

local function openCatalog()
    shop.Visible = false
    home.Visible = false
    paint.Visible = false
    catalog.Visible = true
    if difficultyModal then difficultyModal.Visible = false end
    renderCatalog()
end

local function openHome()
    paint.Visible = false
    catalog.Visible = false
    shop.Visible = false
    victory.Visible = false
    if difficultyModal then difficultyModal.Visible = false end
    home.Visible = true
end

if navHome then
    navHome.Activated:Connect(openHome)
end
if difficultyClose then
    difficultyClose.Activated:Connect(function()
        if difficultyModal then difficultyModal.Visible = false end
        pendingArt = nil
    end)
end

local function refreshShop()
    local rows = {
        { Name = "AutoBrush", Title = "Auto Brush", Label = shop:FindFirstChild("AutoLevel", true), Button = shop:FindFirstChild("AutoBuy", true) },
        { Name = "AreaBrush", Title = "Area Brush", Label = shop:FindFirstChild("AreaLevel", true), Button = shop:FindFirstChild("AreaBuy", true) },
        { Name = "ColorHint", Title = "Color Hint", Label = shop:FindFirstChild("HintLevel", true), Button = shop:FindFirstChild("HintBuy", true) },
    }
    for _, row in ipairs(rows) do
        local level = tonumber(profile.Upgrades[row.Name]) or 0
        if row.Label then row.Label.Text = row.Title .. "  •  level " .. tostring(level) .. "/" .. tostring(Config.UpgradeMaxLevel) end
        if row.Button then
            if level >= Config.UpgradeMaxLevel then
                row.Button.Text = "MAX"
                row.Button.Active = false
            else
                local cost = Config.UpgradeCosts[row.Name][level + 1]
                row.Button.Text = "Upgrade  " .. tostring(cost)
                row.Button.Active = true
            end
        end
    end
end

local function buyUpgrade(abilityName)
    local result = invoke(UpgradeAbility, abilityName)
    if result.Ok then
        updateProfile(result)
        refreshShop()
        showToast(abilityName .. " upgraded.")
        refreshAbilityButtons()
    else
        showToast(reasonText(result), true)
    end
end

local function createAdminPanel()
    if player.Name ~= Config.AdminName or adminPanel then
        return
    end
    local adminButton = drawButton:Clone()
    adminButton.Name = "AdminButton"
    adminButton.Text = "Developer"
    adminButton.Size = UDim2.fromOffset(138, 42)
    adminButton.Position = UDim2.new(1, -166, 0, 210)
    adminButton.Parent = home
    adminButton.Activated:Connect(function()
        adminPanel.Visible = not adminPanel.Visible
    end)

    adminPanel = Instance.new("Frame")
    adminPanel.Name = "DeveloperPanel"
    adminPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    adminPanel.Position = UDim2.fromScale(0.5, 0.5)
    adminPanel.Size = UDim2.fromOffset(390, 300)
    adminPanel.BackgroundColor3 = Color3.fromRGB(27, 39, 64)
    adminPanel.BorderSizePixel = 0
    adminPanel.ZIndex = 50
    adminPanel.Parent = root
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = adminPanel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 190, 76)
    stroke.Thickness = 2
    stroke.Parent = adminPanel
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = "Developer tools • RabanFix"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Size = UDim2.new(1, -32, 0, 42)
    title.Position = UDim2.fromOffset(16, 12)
    title.Parent = adminPanel
    local close = Instance.new("TextButton")
    close.Text = "×"
    close.TextSize = 26
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.BackgroundTransparency = 1
    close.Size = UDim2.fromOffset(40, 40)
    close.Position = UDim2.new(1, -48, 0, 8)
    close.Parent = adminPanel
    close.Activated:Connect(function() adminPanel.Visible = false end)
    local actions = {
        { "Instant Complete", "InstantComplete" },
        { "+10,000 Gems", "AddGems" },
        { "Max Upgrades", "MaxUpgrades" },
        { "Reset Art Progress", "ResetArtProgress" },
    }
    for index, action in ipairs(actions) do
        local button = Instance.new("TextButton")
        button.Name = action[2]
        button.Text = action[1]
        button.Font = Enum.Font.GothamBold
        button.TextSize = 15
        button.TextColor3 = Color3.fromRGB(20, 25, 38)
        button.BackgroundColor3 = Color3.fromRGB(255, 190, 76)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -36, 0, 42)
        button.Position = UDim2.fromOffset(18, 62 + (index - 1) * 52)
        button.Parent = adminPanel
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10)
        buttonCorner.Parent = button
        button.Activated:Connect(function()
            if not currentArtId and action[2] ~= "AddGems" and action[2] ~= "MaxUpgrades" then
                showToast("Open an art first.", true)
                return
            end
            local result = invoke(AdminAction, action[2], currentArtId)
            if not result.Ok then
                showToast(reasonText(result), true)
                return
            end
            updateGems(result.Gems)
            if result.Upgrades then profile.Upgrades = result.Upgrades end
            if action[2] == "InstantComplete" then
                setPaintedCells(result.Bits or currentBits, currentArt.Width * currentArt.Height)
                currentCount = result.Count or currentCount
                profile.Progress[currentProgressKey or currentArtId] = { Count = currentCount, Complete = true }
                renderCanvas()
                showVictory(result.Reward)
            elseif action[2] == "ResetArtProgress" then
                setPaintedCells(result.Bits or string.rep("0", currentArt.Width * currentArt.Height), currentArt.Width * currentArt.Height)
                currentCount = 0
                profile.Progress[currentProgressKey or currentArtId] = { Count = 0, Complete = false }
                renderCanvas()
                showToast("Current art progress reset.")
            elseif action[2] == "MaxUpgrades" then
                refreshShop()
                showToast("All abilities are now max level.")
            else
                showToast("10,000 gems added.")
            end
        end)
    end
end

areaButton.Activated:Connect(function()
    selectedAbility = "AreaBrush"
    showToast("Tap a pixel to use Area Brush.")
end)
hintButton.Activated:Connect(function()
    selectedAbility = nil
    if currentArt then
        useAbility("ColorHint", 1, 1)
    else
        showToast("Open an art first.", true)
    end
end)
autoButton.Activated:Connect(function()
    selectedAbility = nil
    if (profile.Upgrades.AutoBrush or 0) < 1 then
        showToast("Upgrade Auto Brush in the shop first.", true)
    else
        showToast("Hold the mouse button and drag to paint continuously.")
    end
end)

canvasViewport.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        pointerDown = true
        pointerInput = input
        pointerStart = Vector2.new(input.Position.X, input.Position.Y)
        panStart = pan
        pointerMoved = false
        if input.UserInputType == Enum.UserInputType.Touch then
            touchPositions[input] = pointerStart
        end
    end
end)

canvasViewport.InputEnded:Connect(function(input)
    if input == pointerInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        local position = Vector2.new(input.Position.X, input.Position.Y)
        if pointerDown and not pointerMoved then
            local x, y = cellAtScreenPosition(position)
            if x and y then
                if selectedAbility then
                    useAbility(selectedAbility, x, y)
                else
                    sendPaint(x, y)
                end
            end
        end
        pointerDown = false
        pointerInput = nil
        if input.UserInputType == Enum.UserInputType.Touch then
            touchPositions[input] = nil
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        if paint.Visible then
            local mouse = UserInputService:GetMouseLocation()
            setZoomAt(mouse, input.Position.Z > 0 and 1.12 or 0.89)
        end
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement and pointerDown and pointerInput and paint.Visible then
        local position = Vector2.new(input.Position.X, input.Position.Y)
        local delta = position - pointerStart
        if delta.Magnitude > 5 then
            pointerMoved = true
            if (profile.Upgrades.AutoBrush or 0) >= 1 then
                local x, y = cellAtScreenPosition(position)
                if x and y then sendPaint(x, y, true) end
            else
                pan = panStart + delta
                layoutCanvas()
            end
        end
    elseif input.UserInputType == Enum.UserInputType.Touch then
        if touchPositions[input] then
            local position = Vector2.new(input.Position.X, input.Position.Y)
            touchPositions[input] = position
            if pointerDown and input == pointerInput then
                local delta = position - pointerStart
                if delta.Magnitude > 5 then
                    pointerMoved = true
                    if (profile.Upgrades.AutoBrush or 0) >= 1 then
                        local x, y = cellAtScreenPosition(position)
                        if x and y then sendPaint(x, y, true) end
                    else
                        pan = panStart + delta
                        layoutCanvas()
                    end
                end
            end
        end
        local first, second
        for _, position in pairs(touchPositions) do
            if not first then first = position elseif not second then second = position end
        end
        if first and second then
            local distance = (first - second).Magnitude
            if lastPinchDistance and distance > 0 then
                local center = (first + second) / 2
                setZoomAt(center, clamp(distance / lastPinchDistance, 0.88, 1.12))
            end
            lastPinchDistance = distance
        else
            lastPinchDistance = nil
        end
    end
end)

canvasViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    task.defer(function()
        layoutCanvas()
        renderCanvas()
    end)
end)

drawButton.Activated:Connect(openCatalog)
catalogBack.Activated:Connect(openHome)
paintBack.Activated:Connect(openCatalog)
shopButton.Activated:Connect(function()
    home.Visible = false
    catalog.Visible = false
    paint.Visible = false
    shop.Visible = true
    refreshShop()
end)
shopClose.Activated:Connect(openHome)
victoryClose.Activated:Connect(function()
    victory.Visible = false
    openCatalog()
end)

shop:FindFirstChild("AreaBuy", true).Activated:Connect(function() buyUpgrade("AreaBrush") end)
shop:FindFirstChild("HintBuy", true).Activated:Connect(function() buyUpgrade("ColorHint") end)
shop:FindFirstChild("AutoBuy", true).Activated:Connect(function() buyUpgrade("AutoBrush") end)

ProfileChanged.OnClientEvent:Connect(function(data)
    updateProfile(data)
    refreshShop()
end)
ToastEvent.OnClientEvent:Connect(function(message)
    showToast(message)
end)

local initial = invoke(GetProfile)
if initial.Ok then
    updateProfile(initial)
else
    showToast(reasonText(initial), true)
end
loadArts()
createAdminPanel()
renderCatalog()
openHome()
]=]

replaceSource(StarterPlayer:WaitForChild("StarterPlayerScripts"), "LocalScript", "PaintByNumbersClient", clientSource)

-- ------------------------------ UI --------------------------------------
-- Locate visual templates from the Essential UI Pack before adding generated
-- UI. We copy their visual properties and clone UICorner/UIStroke/
-- UIGradient children, so the fallback hierarchy still inherits the pack's
-- buttons/cards/panels/fonts when the template names differ between pack
-- versions.
local function findTemplate(className, tokens)
    local roots = { StarterGui, ReplicatedStorage, Workspace, StarterPlayer }
    for _, searchRoot in ipairs(roots) do
        for _, descendant in ipairs(searchRoot:GetDescendants()) do
            if descendant:IsA(className) then
                local lower = string.lower(descendant.Name)
                for _, token in ipairs(tokens) do
                    if string.find(lower, token, 1, true) then
                        return descendant
                    end
                end
            end
        end
    end
    return nil
end

local styleButton = findTemplate("TextButton", { "button", "btn" })
local styleFrame = findTemplate("Frame", { "panel", "window", "card", "modal", "container" })
local styleLabel = findTemplate("TextLabel", { "label", "text", "title" })
local styleImage = findTemplate("ImageLabel", { "image", "icon", "preview" })

local function copyVisualStyle(source, destination)
    if not source then
        return
    end
    local properties = {
        "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderSizePixel",
        "TextColor3", "TextTransparency", "TextStrokeColor3", "TextStrokeTransparency",
        "TextSize", "Font", "FontFace", "Image", "ImageColor3", "ImageTransparency",
        "ScaleType", "SliceCenter", "SliceScale", "ResampleMode",
    }
    for _, property in ipairs(properties) do
        pcall(function()
            destination[property] = source[property]
        end)
    end
    for _, child in ipairs(source:GetChildren()) do
        if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") then
            local clone = child:Clone()
            clone.Parent = destination
        end
    end
end

local function cleanTemplateClone(instance)
    for _, child in ipairs(instance:GetChildren()) do
        if not (child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") or child:IsA("UIPadding")) then
            child:Destroy()
        end
    end
end

local function ui(parent, className, name, template, usePack)
    local object
    if usePack and template and template.ClassName == className then
        local ok, clone = pcall(function()
            return template:Clone()
        end)
        if ok and clone then
            object = clone
            object.Name = name
            cleanTemplateClone(object)
        end
    end
    if not object then
        object = Instance.new(className)
        object.Name = name
        if usePack then
            copyVisualStyle(template, object)
        end
    end
    object.Parent = parent
    if object:IsA("GuiObject") then
        object.Visible = true
        object.AnchorPoint = Vector2.zero
        object.Rotation = 0
        pcall(function() object.AutomaticSize = Enum.AutomaticSize.None end)
    end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        object.TextScaled = false
        object.TextTransparency = 0
        object.TextStrokeTransparency = 1
    end
    mark(object)
    return object
end

local function addCorner(object, radius)
    if not object:FindFirstChildOfClass("UICorner") then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius or 12)
        corner.Parent = object
    end
end

local function addStroke(object, color, thickness)
    local stroke = object:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = object
    end
    stroke.Color = color or Color3.fromRGB(64, 83, 120)
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.15
end

local C = {
    Background = Color3.fromRGB(248, 249, 252),
    Panel = Color3.fromRGB(255, 255, 255),
    Panel2 = Color3.fromRGB(244, 246, 250),
    Accent = Color3.fromRGB(12, 112, 247),
    Accent2 = Color3.fromRGB(113, 190, 70),
    Gold = Color3.fromRGB(246, 178, 38),
    Text = Color3.fromRGB(32, 39, 53),
    Muted = Color3.fromRGB(125, 132, 146),
    Dark = Color3.fromRGB(238, 241, 247),
    PaintBlue = Color3.fromRGB(9, 113, 247),
}

local oldGui = StarterGui:FindFirstChild("PaintByNumbersGui")
if oldGui then
    oldGui:Destroy()
end

local screen = mark(Instance.new("ScreenGui"))
screen.Name = "PaintByNumbersGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 20
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = StarterGui

local rootFrame = ui(screen, "Frame", "Root", nil, false)
rootFrame.Size = UDim2.fromScale(1, 1)
rootFrame.BackgroundTransparency = 1
rootFrame.BorderSizePixel = 0

local function text(parent, name, value, size, position, textSize, template)
    local label = ui(parent, "TextLabel", name, template or styleLabel, true)
    label.Text = value
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.TextColor3 = C.Text
    label.TextTransparency = 0
    label.TextStrokeTransparency = 1
    label.TextScaled = false
    if not (template or styleLabel) then
        label.Font = Enum.Font.Gotham
    end
    label.TextSize = textSize or 16
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    return label
end

local function button(parent, name, value, size, position)
    local b = ui(parent, "TextButton", name, styleButton, true)
    b.Text = value
    b.Size = size
    b.Position = position
    b.BackgroundColor3 = C.Panel2
    b.BackgroundTransparency = 0
    b.TextColor3 = C.Text
    b.TextTransparency = 0
    b.TextStrokeTransparency = 1
    b.TextScaled = false
    b.TextXAlignment = Enum.TextXAlignment.Center
    b.TextYAlignment = Enum.TextYAlignment.Center
    if not styleButton then
        b.Font = Enum.Font.GothamBold
    end
    b.TextSize = 16
    b.AutoButtonColor = true
    b.Active = true
    b.BorderSizePixel = 0
    addCorner(b, 12)
    addStroke(b, Color3.fromRGB(77, 99, 140), 1)
    return b
end

local function panel(parent, name, size, position, template)
    local frame = ui(parent, "Frame", name, template or styleFrame, true)
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = C.Panel
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    addCorner(frame, 18)
    addStroke(frame, Color3.fromRGB(63, 83, 121), 1)
    return frame
end

-- Home
local homeFrame = ui(rootFrame, "Frame", "Home", nil, false)
homeFrame.Size = UDim2.fromScale(1, 1)
homeFrame.BackgroundColor3 = C.Background
homeFrame.BorderSizePixel = 0
local homeHeader = panel(homeFrame, "Header", UDim2.new(0.92, 0, 0, 88), UDim2.new(0.04, 0, 0, 70))
local homeTitle = text(homeHeader, "Title", "PIXEL ATELIER", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 8), 26, styleLabel)
homeTitle.TextXAlignment = Enum.TextXAlignment.Center
if not styleLabel then homeTitle.Font = Enum.Font.GothamBlack end
local homeSubtitle = text(homeHeader, "Subtitle", "Paint by numbers • collect gems • unlock your brush", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 48), 13, styleLabel)
homeSubtitle.TextXAlignment = Enum.TextXAlignment.Center
homeSubtitle.TextColor3 = C.Muted
local homeGems = text(homeFrame, "GemsLabel", "Gems  0", UDim2.fromOffset(190, 34), UDim2.new(1, -214, 0, 170), 18, styleLabel)
homeGems.TextXAlignment = Enum.TextXAlignment.Right
homeGems.TextColor3 = C.Gold
local draw = button(homeFrame, "DrawButton", "DRAW", UDim2.fromOffset(280, 68), UDim2.new(0.5, -140, 0.5, -50))
draw.BackgroundColor3 = C.Accent
draw.TextColor3 = Color3.fromRGB(255, 255, 255)
draw.TextSize = 22
local homeHint = text(homeFrame, "Hint", "Choose a picture, select its number, and fill every highlighted pixel.", UDim2.fromOffset(560, 32), UDim2.new(0.5, -280, 0.5, 30), 14, styleLabel)
homeHint.TextXAlignment = Enum.TextXAlignment.Center
homeHint.TextColor3 = C.Muted
local shopBtn = button(homeFrame, "ShopButton", "ABILITIES SHOP", UDim2.fromOffset(190, 46), UDim2.new(0.5, -95, 0.5, 94))

-- Catalog
local catalogFrame = ui(rootFrame, "Frame", "Catalog", nil, false)
catalogFrame.Size = UDim2.fromScale(1, 1)
catalogFrame.BackgroundColor3 = C.Background
catalogFrame.BorderSizePixel = 0
local catalogPanel = panel(catalogFrame, "Panel", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
catalogPanel.BackgroundColor3 = C.Panel
catalogPanel.BackgroundTransparency = 0
local catalogBackButton = button(catalogPanel, "BackButton", "‹", UDim2.fromOffset(42, 42), UDim2.fromOffset(10, 62))
catalogBackButton.BackgroundColor3 = C.Panel2
catalogBackButton.TextColor3 = C.Text
local catalogTitle = text(catalogPanel, "Title", "Новое       Бонусы       Книги", UDim2.new(1, -76, 0, 42), UDim2.fromOffset(66, 62), 17, styleLabel)
catalogTitle.TextColor3 = C.Text
local catalogSub = text(catalogPanel, "Subtitle", "Finish a canvas to earn gems and unlock abilities.", UDim2.fromOffset(500, 28), UDim2.fromOffset(66, 101), 13, styleLabel)
catalogSub.Visible = false
local levelGrid = ui(catalogPanel, "ScrollingFrame", "LevelGrid", nil, false)
levelGrid.Size = UDim2.new(1, -24, 1, -158)
levelGrid.Position = UDim2.fromOffset(12, 120)
levelGrid.BackgroundTransparency = 1
levelGrid.BorderSizePixel = 0
levelGrid.ScrollBarThickness = 6
levelGrid.ScrollBarImageColor3 = C.Accent
levelGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
levelGrid.CanvasSize = UDim2.new()
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(142, 158)
gridLayout.CellPadding = UDim2.fromOffset(8, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = levelGrid
local noArts = text(catalogPanel, "NoArts", "No art modules found. Import one into ArtLibrary.", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 160), 16, styleLabel)
noArts.TextXAlignment = Enum.TextXAlignment.Center
noArts.TextColor3 = C.Muted

local card = panel(catalogFrame, "CardTemplate", UDim2.fromOffset(142, 158), UDim2.fromOffset(0, 0), styleFrame)
card.Visible = false
card.BackgroundColor3 = C.Panel
card.BackgroundTransparency = 1
card.BorderSizePixel = 0
local preview = ui(card, "ImageLabel", "Preview", styleImage, true)
preview.Size = UDim2.new(1, -8, 0, 122)
preview.Position = UDim2.fromOffset(4, 2)
preview.BackgroundColor3 = C.Panel2
preview.BackgroundTransparency = 0
preview.BorderSizePixel = 0
preview.ScaleType = Enum.ScaleType.Stretch
addCorner(preview, 10)
local cardTitle = text(card, "Title", "Art name", UDim2.new(1, -8, 0, 15), UDim2.fromOffset(4, 124), 10, styleLabel)
cardTitle.TextColor3 = C.Text
if not styleLabel then cardTitle.Font = Enum.Font.GothamBold end
local cardDiff = text(card, "Difficulty", "Easy", UDim2.new(0.55, 0, 0, 14), UDim2.fromOffset(4, 141), 9, styleLabel)
cardDiff.TextColor3 = C.Muted
local cardReward = text(card, "Reward", "+75", UDim2.new(0.4, 0, 0, 14), UDim2.new(0.58, 0, 0, 141), 9, styleLabel)
cardReward.TextXAlignment = Enum.TextXAlignment.Right
cardReward.TextColor3 = C.Gold
local cardProgress = text(card, "Progress", "0%", UDim2.fromOffset(34, 14), UDim2.fromOffset(104, 124), 9, styleLabel)
cardProgress.TextXAlignment = Enum.TextXAlignment.Right
cardProgress.TextColor3 = C.Muted
local completionMark = text(card, "CompletionMark", "✓", UDim2.fromOffset(24, 24), UDim2.fromOffset(2, 98), 20, styleLabel)
completionMark.TextColor3 = C.Accent2
completionMark.ZIndex = 3
local progressBack = Instance.new("Frame")
progressBack.Name = "ProgressBack"
progressBack.Size = UDim2.new(1, -8, 0, 3)
progressBack.Position = UDim2.fromOffset(4, 155)
progressBack.BackgroundColor3 = C.Dark
progressBack.BorderSizePixel = 0
progressBack.Parent = card
addCorner(progressBack, 2)
local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = C.Accent2
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack
addCorner(progressFill, 2)
local cardSelect = Instance.new("TextButton")
cardSelect.Name = "Select"
cardSelect.Text = ""
cardSelect.BackgroundTransparency = 1
cardSelect.BorderSizePixel = 0
cardSelect.Size = UDim2.fromScale(1, 1)
cardSelect.ZIndex = 5
cardSelect.Active = true
cardSelect.Parent = card

local bottomNav = ui(catalogPanel, "Frame", "BottomNav", nil, false)
bottomNav.Size = UDim2.new(1, 0, 0, 62)
bottomNav.Position = UDim2.new(0, 0, 1, -62)
bottomNav.BackgroundColor3 = C.Panel
bottomNav.BackgroundTransparency = 0
bottomNav.BorderSizePixel = 0
local bottomLine = Instance.new("Frame")
bottomLine.Name = "TopLine"
bottomLine.Size = UDim2.new(1, 0, 0, 1)
bottomLine.BackgroundColor3 = C.Dark
bottomLine.BorderSizePixel = 0
bottomLine.Parent = bottomNav
local bottomLayout = Instance.new("UIListLayout")
bottomLayout.FillDirection = Enum.FillDirection.Horizontal
bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
bottomLayout.Parent = bottomNav
local function navItem(name, value, order)
    local item = Instance.new("TextButton")
    item.Name = name
    item.Text = value
    item.LayoutOrder = order
    item.Size = UDim2.new(0.5, 0, 1, 0)
    item.BackgroundTransparency = 1
    item.BorderSizePixel = 0
    item.TextColor3 = C.Muted
    item.TextSize = 11
    item.TextWrapped = true
    item.TextScaled = false
    item.Font = Enum.Font.Gotham
    item.AutoButtonColor = false
    item.Parent = bottomNav
    return item
end
local navHome = navItem("Home", "▣\nГлавная", 1)
navHome.TextColor3 = C.Text
navItem("Works", "▧\nМои работы", 2)

local difficultyModal = panel(catalogFrame, "DifficultyModal", UDim2.new(0.84, 0, 0, 330), UDim2.new(0.08, 0, 0.5, -165))
difficultyModal.Visible = false
difficultyModal.ZIndex = 20
difficultyModal.BackgroundColor3 = C.Panel
local difficultyTitle = text(difficultyModal, "DifficultyTitle", "CHOOSE DIFFICULTY", UDim2.new(1, -70, 0, 34), UDim2.fromOffset(20, 18), 20, styleLabel)
difficultyTitle.TextXAlignment = Enum.TextXAlignment.Center
difficultyTitle.TextColor3 = C.Text
local difficultyArtNameLabel = text(difficultyModal, "DifficultyArtName", "Painting", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 53), 13, styleLabel)
difficultyArtNameLabel.TextXAlignment = Enum.TextXAlignment.Center
difficultyArtNameLabel.TextColor3 = C.Muted
local difficultyCloseButton = button(difficultyModal, "DifficultyClose", "×", UDim2.fromOffset(38, 36), UDim2.new(1, -52, 0, 14))
difficultyCloseButton.ZIndex = 22
local difficultyList = ui(difficultyModal, "Frame", "DifficultyButtons", nil, false)
difficultyList.Size = UDim2.new(1, -40, 0, 220)
difficultyList.Position = UDim2.fromOffset(20, 92)
difficultyList.BackgroundTransparency = 1
difficultyList.BorderSizePixel = 0
local difficultyListLayout = Instance.new("UIListLayout")
difficultyListLayout.Padding = UDim.new(0, 8)
difficultyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
difficultyListLayout.Parent = difficultyList
local difficultyButtonTemplate = button(difficultyModal, "DifficultyTemplate", "Easy  32x32", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 92))
difficultyButtonTemplate.Visible = false
difficultyButtonTemplate.ZIndex = 21

-- Painting screen
local paintFrame = ui(rootFrame, "Frame", "Paint", nil, false)
paintFrame.Size = UDim2.fromScale(1, 1)
paintFrame.BackgroundColor3 = C.PaintBlue
paintFrame.BorderSizePixel = 0
local paintTop = panel(paintFrame, "TopBar", UDim2.new(1, -24, 0, 66), UDim2.fromOffset(12, 56))
paintTop.BackgroundColor3 = C.PaintBlue
paintTop.BackgroundTransparency = 1
local paintTopStroke = paintTop:FindFirstChildOfClass("UIStroke")
if paintTopStroke then paintTopStroke.Transparency = 1 end
local paintBackButton = button(paintTop, "BackButton", "‹", UDim2.fromOffset(48, 48), UDim2.fromOffset(8, 8))
paintBackButton.BackgroundColor3 = Color3.fromRGB(125, 136, 159)
paintBackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
paintBackButton.TextSize = 30
local paintingNameLabel = text(paintTop, "PaintingName", "Painting", UDim2.new(1, -250, 0, 34), UDim2.fromOffset(74, 5), 22, styleLabel)
paintingNameLabel.TextXAlignment = Enum.TextXAlignment.Center
paintingNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
if not styleLabel then paintingNameLabel.Font = Enum.Font.GothamBold end
local paintingDifficultyLabel = text(paintTop, "PaintingDifficulty", "Easy", UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 1, styleLabel)
paintingDifficultyLabel.Visible = false
local paintingProgressLabel = text(paintTop, "PaintingProgress", "0%", UDim2.fromOffset(130, 28), UDim2.new(1, -188, 0, 17), 14, styleLabel)
paintingProgressLabel.TextXAlignment = Enum.TextXAlignment.Right
paintingProgressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
local gridButton = button(paintTop, "GridButton", "▦", UDim2.fromOffset(48, 48), UDim2.new(1, -56, 0, 8))
gridButton.BackgroundColor3 = Color3.fromRGB(125, 136, 159)
gridButton.TextColor3 = Color3.fromRGB(255, 255, 255)
gridButton.TextSize = 25
local viewport = panel(paintFrame, "CanvasViewport", UDim2.new(0.92, 0, 1, -270), UDim2.new(0.04, 0, 0, 132))
viewport.ClipsDescendants = true
viewport.Active = true
viewport.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
viewport.BackgroundTransparency = 0
local surface = ui(viewport, "ImageLabel", "CanvasSurface", nil, false)
surface.AnchorPoint = Vector2.new(0.5, 0.5)
surface.Position = UDim2.fromScale(0.5, 0.5)
surface.Size = UDim2.fromOffset(100, 100)
surface.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
surface.BackgroundTransparency = 0
surface.BorderSizePixel = 0
surface.Active = false
surface.ScaleType = Enum.ScaleType.Stretch
local numberLayer = ui(viewport, "Frame", "NumberLayer", nil, false)
numberLayer.AnchorPoint = surface.AnchorPoint
numberLayer.Position = surface.Position
numberLayer.Size = surface.Size
numberLayer.BackgroundTransparency = 1
numberLayer.BorderSizePixel = 0
numberLayer.ClipsDescendants = true
numberLayer.ZIndex = surface.ZIndex + 2
local virtual = ui(viewport, "Frame", "VirtualLayer", nil, false)
virtual.AnchorPoint = Vector2.new(0.5, 0.5)
virtual.Position = surface.Position
virtual.Size = surface.Size
virtual.BackgroundTransparency = 1
virtual.BorderSizePixel = 0
virtual.Visible = false
virtual.ZIndex = surface.ZIndex + 1
local palettePanel = panel(paintFrame, "PalettePanel", UDim2.new(0.92, 0, 0, 76), UDim2.new(0.04, 0, 1, -86))
palettePanel.BackgroundColor3 = C.PaintBlue
palettePanel.BackgroundTransparency = 1
local palettePanelStroke = palettePanel:FindFirstChildOfClass("UIStroke")
if palettePanelStroke then palettePanelStroke.Transparency = 1 end
local paletteTitle = text(palettePanel, "PaletteTitle", "PALETTE", UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 1, styleLabel)
paletteTitle.Visible = false
local palette = ui(palettePanel, "ScrollingFrame", "PaletteButtons", nil, false)
palette.Size = UDim2.fromScale(1, 1)
palette.Position = UDim2.fromScale(0, 0)
palette.BackgroundTransparency = 1
palette.BorderSizePixel = 0
palette.ScrollBarThickness = 3
palette.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
palette.ScrollingDirection = Enum.ScrollingDirection.X
palette.CanvasSize = UDim2.fromOffset(0, 0)
palette.AutomaticCanvasSize = Enum.AutomaticSize.X
local paletteLayout = Instance.new("UIListLayout")
paletteLayout.FillDirection = Enum.FillDirection.Horizontal
paletteLayout.Padding = UDim.new(0, 2)
paletteLayout.VerticalAlignment = Enum.VerticalAlignment.Center
paletteLayout.Parent = palette
local paletteTemplate = button(paintFrame, "PaletteButtonTemplate", "1", UDim2.fromOffset(42, 42), UDim2.fromOffset(0, 0))
paletteTemplate.Visible = false
local paletteDots = text(paintFrame, "PaletteDots", "●  ●", UDim2.fromOffset(80, 12), UDim2.new(0.5, -40, 1, -11), 7, styleLabel)
paletteDots.TextXAlignment = Enum.TextXAlignment.Center
paletteDots.TextColor3 = Color3.fromRGB(205, 220, 248)
local hint = text(paintFrame, "ColorHint", "Selected color 1", UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 1, styleLabel)
hint.Visible = false
hint.ZIndex = 4
local abilityBar = ui(paintFrame, "Frame", "AbilityBar", nil, false)
abilityBar.Size = UDim2.new(0.92, 0, 0, 34)
abilityBar.Position = UDim2.new(0.04, 0, 1, -122)
abilityBar.BackgroundTransparency = 1
abilityBar.BorderSizePixel = 0
local abilityLayout = Instance.new("UIListLayout")
abilityLayout.FillDirection = Enum.FillDirection.Horizontal
abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
abilityLayout.VerticalAlignment = Enum.VerticalAlignment.Center
abilityLayout.Padding = UDim.new(0, 6)
abilityLayout.Parent = abilityBar
local function abilityButton(name, label)
    local ability = button(abilityBar, name, label, UDim2.new(1 / 3, -4, 1, -4), UDim2.fromOffset(0, 2))
    ability.BackgroundColor3 = Color3.fromRGB(42, 89, 181)
    ability.TextColor3 = Color3.fromRGB(255, 255, 255)
    ability.TextSize = 11
    ability.ZIndex = 5
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(112, 30)
    constraint.MinSize = Vector2.new(72, 30)
    constraint.Parent = ability
    return ability
end
local auto = abilityButton("AutoBrushButton", "Auto Brush  L0")
local area = abilityButton("AreaBrushButton", "Area  L0")
local hintAbility = abilityButton("ColorHintButton", "Hint  L0")
local victoryModal = panel(paintFrame, "VictoryModal", UDim2.new(0.9, 0, 0, 250), UDim2.new(0.05, 0, 0.5, -125))
victoryModal.Visible = false
victoryModal.ZIndex = 30
local victoryTitle = text(victoryModal, "Title", "CANVAS COMPLETE", UDim2.new(1, -36, 0, 44), UDim2.fromOffset(18, 24), 23, styleLabel)
victoryTitle.TextXAlignment = Enum.TextXAlignment.Center
if not styleLabel then victoryTitle.Font = Enum.Font.GothamBlack end
victoryTitle.TextColor3 = C.Accent
local victoryMessage = text(victoryModal, "Message", "Congratulations!", UDim2.new(1, -48, 0, 90), UDim2.fromOffset(24, 78), 16, styleLabel)
victoryMessage.TextXAlignment = Enum.TextXAlignment.Center
victoryMessage.TextYAlignment = Enum.TextYAlignment.Center
local continueButton = button(victoryModal, "ContinueButton", "BACK TO GALLERY", UDim2.fromOffset(220, 46), UDim2.new(0.5, -110, 1, -66))
continueButton.BackgroundColor3 = C.Accent
continueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
continueButton.ZIndex = 31

-- Shop
local shopFrame = ui(rootFrame, "Frame", "Shop", nil, false)
shopFrame.Size = UDim2.fromScale(1, 1)
shopFrame.BackgroundColor3 = C.Background
shopFrame.BorderSizePixel = 0
local shopPanel = panel(shopFrame, "Panel", UDim2.new(0.9, 0, 0, 430), UDim2.new(0.05, 0, 0.5, -215))
local shopTitle = text(shopPanel, "Title", "ABILITIES SHOP", UDim2.new(1, -80, 0, 42), UDim2.fromOffset(24, 18), 24, styleLabel)
if not styleLabel then shopTitle.Font = Enum.Font.GothamBlack end
local shopCloseButton = button(shopPanel, "CloseButton", "×", UDim2.fromOffset(44, 40), UDim2.new(1, -60, 0, 16))
shopCloseButton.TextSize = 24
local shopSub = text(shopPanel, "Subtitle", "Spend gems to make every canvas faster.", UDim2.new(1, -48, 0, 26), UDim2.fromOffset(24, 58), 13, styleLabel)
shopSub.TextColor3 = C.Muted
local function shopRow(name, labelName, buyName, y, description)
    local row = panel(shopPanel, name .. "Row", UDim2.new(1, -48, 0, 86), UDim2.fromOffset(24, y))
    row.BackgroundColor3 = C.Panel2
    local levelLabel = text(row, labelName, name .. "  •  level 0/3", UDim2.new(1, -150, 0, 26), UDim2.fromOffset(14, 10), 15, styleLabel)
    if not styleLabel then levelLabel.Font = Enum.Font.GothamBold end
    local desc = text(row, "Description", description, UDim2.new(1, -160, 0, 28), UDim2.fromOffset(14, 38), 11, styleLabel)
    desc.TextColor3 = C.Muted
    local buy = button(row, buyName, "Upgrade", UDim2.fromOffset(118, 42), UDim2.new(1, -132, 0.5, -21))
    buy.TextSize = 13
end
shopRow("Auto Brush", "AutoLevel", "AutoBuy", 94, "Hold the mouse button or touch to paint continuously.")
shopRow("Area Brush", "AreaLevel", "AreaBuy", 188, "Level 1: 1x2 • Level 2: 2x2 • Level 3: 3x3.")
shopRow("Color Hint", "HintLevel", "HintBuy", 282, "Suggests the color with the most pixels left.")

local toastLabel = text(rootFrame, "Toast", "", UDim2.fromOffset(420, 38), UDim2.new(0.5, -210, 0, -48), 14, styleLabel)
toastLabel.BackgroundColor3 = C.Panel2
toastLabel.BackgroundTransparency = 0
 toastLabel.TextXAlignment = Enum.TextXAlignment.Center
 toastLabel.TextYAlignment = Enum.TextYAlignment.Center
 toastLabel.Visible = false
 toastLabel.ZIndex = 100
 addCorner(toastLabel, 12)
 addStroke(toastLabel, C.Accent2, 1)

-- Start in the home view; all other screens are still present so the client
-- can switch between them without cloning Frames per pixel.
catalogFrame.Visible = false
paintFrame.Visible = false
shopFrame.Visible = false

print("PaintByNumbers installed. Art modules live in " .. artLibrary:GetFullName() .. ".")
print("Run the game with Play, then click DRAW. Imported 128x128/256x256 art is rendered with EditableImage; the compatibility path is chunk-virtualized.")
