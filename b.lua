task.wait(4)
_G.change_acc = true
setfpscap(15)

spawn(function()
    task.spawn(function()
        local divinemap = workspace:FindFirstChild("DivineMapTsunami")
        if not divinemap then return end
        local track1 = divinemap:FindFirstChild("Track")
        if not track1 then return end
        local trenches1 = track1:FindFirstChild("Trenches")
        if not trenches1 then return end
        for _, trench1 in trenches1:GetDescendants() do
            if trench1:IsA("BasePart") and trench1.Name == "Base" then
                trench1.CFrame = trench1.CFrame + Vector3.new(0, 6, 0)
            end
        end
    end)

    local map = workspace:FindFirstChild("Map")
    if not map then return end
        
    local track = map:FindFirstChild("Track")
    if not track then return end
        
    local trenches = track:FindFirstChild("Trenches")
    if not trenches then return end
        
    for _, trench in trenches:GetDescendants() do
        if trench:IsA("BasePart") and trench.Name == "Base" then
            trench.CFrame = trench.CFrame + Vector3.new(0, 6, 0)
        end
    end
end)

if game.PlaceId == 109983668079237 then
    task.spawn(function()
        local _rs = game:GetService("ReplicatedStorage")
        local startTime = tick()
        while tick() - startTime < 10 do
            local pkg = _rs:FindFirstChild("Packages")
            if pkg then
                local netMod = pkg:FindFirstChild("Net")
                if netMod then
                    local ok, net = pcall(require, netMod)
                    if ok and net then
                        local ok2, remote = pcall(function()
                            return net:RemoteEvent("TsunamiEventService/Teleport")
                        end)
                        if ok2 and remote then
                            pcall(function() remote:FireServer() end)
                            break
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local rs = game:GetService("ReplicatedStorage")

-- Definido cedo para CharacterAdded (reset) não dar "attempt to index nil with 'basePosition'"
local CollectionState = {
    collected = { best = false, ["Gangster Footera"] = false, ["Trippi Troppi"] = false },
    collectedInfo = { best = nil, ["Gangster Footera"] = nil, ["Trippi Troppi"] = nil },
    collectedAt = { best = 0, ["Gangster Footera"] = 0, ["Trippi Troppi"] = 0 },
    currentTarget = nil,
    targetType = nil,
    basePosition = nil,
    targetSetAt = 0
}

player.CharacterAdded:Connect(function(newChar)
    task.defer(function()
        task.wait(0.5)
        local char = player.Character
        if not char or char ~= newChar then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3)
        if CollectionState and root then
            CollectionState.basePosition = Vector3.new(-311, -6, 190)
            CollectionState.currentTarget = nil
            CollectionState.targetType = nil
        end
    end)
end)

local replicator = nil
local animals = nil
task.spawn(function()
    local pkg = rs:WaitForChild("Packages", 20)
    if pkg then
        local rc = pkg:FindFirstChild("ReplicatorClient")
        if rc then pcall(function() replicator = require(rc) end) end
    end
    local shared = rs:WaitForChild("Shared", 10)
    if shared then
        local an = shared:FindFirstChild("Animals")
        if an then pcall(function() animals = require(an) end) end
    end
end)
local rebirth_brainrots = {["Gangster Footera"] = 1, ["Trippi Troppi"] = 1}
local function _getFirePP()
    local f = fireproximityprompt
    if type(f) ~= "function" and typeof(f) ~= "function" then
        local g = getgenv and getgenv()
        if g and (type(g.fireproximityprompt) == "function" or typeof(g.fireproximityprompt) == "function") then
            f = g.fireproximityprompt
        end
    end
    return (type(f) == "function" or typeof(f) == "function") and f or nil
end
local _firepp = _getFirePP()

-- ========== SYNCHRONIZER ==========
local SynchronizerModule = nil
local DataFolder = rs:FindFirstChild("Datas")
local AnimalsData = nil

-- ========== NET MODULE ==========
local Net = nil
local packages = rs:WaitForChild("Packages", 10)
task.spawn(function()
    if packages then
        local netModule = packages:FindFirstChild("Net")
        if netModule then
            Net = require(netModule)
        end
    end
end)

task.spawn(function()
    if packages then
        local syncModule = packages:FindFirstChild("Synchronizer")
        if syncModule then
            SynchronizerModule = require(syncModule)
        end
    end
    
    if DataFolder then
        local animalsDataFile = DataFolder:FindFirstChild("Animals")
        if animalsDataFile then
            AnimalsData = require(animalsDataFile)
        end
    end
end)

-- ========== UTILS ANTECIPADOS ==========
local currentStatus = "Iniciando..."
local function updateStatus(status) currentStatus = status end

local function ParseMoney(val)
    if not val then return 0 end
    local n = tonumber(val)
    if n then return n end
    local s = tostring(val):gsub("%$", ""):gsub(",", "")
    local suffixes = {K = 1e3, M = 1e6, B = 1e9, T = 1e12}
    for suffix, mult in pairs(suffixes) do
        local num = s:match("^([%d%.]+)" .. suffix)
        if num then return math.floor(tonumber(num) * mult) end
    end
    return tonumber(s) or 0
end

-- ========== LEADERSTATS ==========
local leaderstats = nil
local cashValue = nil
local rebirthsValue = nil

task.spawn(function()
    leaderstats = player:WaitForChild("leaderstats", 15)
    if not leaderstats then
        warn("[Kaitun] leaderstats nao encontrado")
        return
    end

    -- Debug: mostra todos os filhos do leaderstats
    print("[Kaitun] leaderstats filhos:")
    for _, child in ipairs(leaderstats:GetChildren()) do
        print("  -", child.Name, "=", child.Value)
    end

    -- Tenta encontrar cash por nome exato, depois por busca
    cashValue = leaderstats:FindFirstChild("Cash")
    if not cashValue then
        -- Procura qualquer NumberValue que não seja Rebirths
        for _, child in ipairs(leaderstats:GetChildren()) do
            if (child:IsA("NumberValue") or child:IsA("IntValue")) and child.Name ~= "Rebirths" then
                cashValue = child
                print("[Kaitun] Cash encontrado como:", child.Name)
                break
            end
        end
    end

    rebirthsValue = leaderstats:FindFirstChild("Rebirths")

    print("[Kaitun] cashValue:", cashValue and cashValue.Name or "nil")
    print("[Kaitun] cashValue.Value:", cashValue and cashValue.Value or "nil")

    -- Detecção imediata: dispara rebirth assim que o cash chegar em 500K
    if cashValue then
        cashValue.Changed:Connect(function(newValue)
            local coins = ParseMoney(newValue)
            if coins >= 500000
                and type(isAllCollected) == "function" and isAllCollected()
                and type(TryRebirth) == "function" then
                task.spawn(TryRebirth)
            end
        end)
    end
end)

-- ========== PLOT DETECTION ==========
local BASE_SUFFIX = "'s Base"
local cachedPlot = nil
local cachedPodiums = nil
local Plots = Workspace:FindFirstChild("Plots")

local function FindPath(root, path)
    local current = root
    for name in string.gmatch(path, "[^/]+") do
        current = current and current:FindFirstChild(name)
    end
    return current
end

local function ParseBaseOwner(text)
    if text == "Empty Base" then return nil end
    if text:sub(-#BASE_SUFFIX) ~= BASE_SUFFIX then return nil end
    return text:sub(1, -#BASE_SUFFIX - 1)
end

local function GetMyPlot()
    if cachedPlot and cachedPlot.Parent then
        return cachedPlot
    end
    
    if not Plots then return nil end
    
    for _, plot in Plots:GetChildren() do
        if plot:IsA("Model") then
            local label = FindPath(plot, "PlotSign/SurfaceGui/Frame/TextLabel")
            if label and label:IsA("TextLabel") then
                local ownerName = ParseBaseOwner(label.Text)
                if ownerName and ownerName == player.DisplayName then
                    cachedPlot = plot
                    cachedPodiums = plot:FindFirstChild("AnimalPodiums")
                    return plot
                end
            end
        end
    end
    return nil
end

local function GetMyPodiums()
    if cachedPodiums and cachedPodiums.Parent then
        return cachedPodiums
    end
    local plot = GetMyPlot()
    return plot and plot:FindFirstChild("AnimalPodiums")
end

-- ========== SYNCHRONIZER HELPERS ==========
local function SafeGetChannel(channelIndex)
    if not SynchronizerModule then return nil end
    
    local allChannels = SynchronizerModule:GetAllChannels()
    if allChannels[channelIndex] then
        return allChannels[channelIndex]
    end
    
    local ok, channel = pcall(function()
        return SynchronizerModule:Create(nil, channelIndex, nil)
    end)
    return ok and channel or nil
end

local function SafeWaitChannel(channelIndex)
    if not SynchronizerModule then return nil end
    
    local channel = SafeGetChannel(channelIndex)
    if channel then
        return channel
    end
    
    local startTime = tick()
    local timeout = 2
    
    repeat
        task.wait(0.1)
        channel = SafeGetChannel(channelIndex)
        if tick() - startTime > timeout then
            return nil
        end
    until channel
    
    return channel
end

-- ========== BASE BRAINROTS DETECTION ==========

-- Resolve o DisplayName de um Index sempre com AnimalsData atualizado
local function ResolveDisplayName(index)
    if AnimalsData and AnimalsData[index] then
        return AnimalsData[index].DisplayName or index
    end
    return index
end

-- Retorna true se o brainrot (pelo Index) é um dos brainrots de rebirth.
-- Sempre usa ResolveDisplayName para evitar problema de AnimalsData tardio.
local function IsRebirthBrainrotIndex(index)
    local dn = ResolveDisplayName(index)
    return rebirth_brainrots[dn] ~= nil
end

local function GetRealBrainrotsFromBase()
    local myPlot = GetMyPlot()
    if not myPlot then return {} end

    if not SynchronizerModule then return {} end

    local channel = SafeWaitChannel(myPlot.Name)
    if not channel then return {} end

    local animalList = channel:Get("AnimalList") or {}
    if not animalList or type(animalList) ~= "table" then return {} end

    local brainrots = {}
    for i, entry in ipairs(animalList) do
        if type(entry) == "table" and entry.Index and entry ~= "Empty" then
            local index = entry.Index
            local mutation = entry.Mutation
            local traits = entry.Traits

            -- Sempre resolve na hora para pegar AnimalsData atualizado
            local displayName = ResolveDisplayName(index)

            local generation = 0
            if animals and animals.GetGeneration then
                local genSuccess, genValue = pcall(function()
                    return animals:GetGeneration(index, mutation, traits, nil)
                end)
                if genSuccess and genValue then
                    generation = genValue
                end
            end

            table.insert(brainrots, {
                position = i,
                Index = index,
                DisplayName = displayName,
                Mutation = mutation,
                Traits = traits,
                Generation = generation
            })
        end
    end

    return brainrots
end

-- Retorna quantos brainrots "best" (não-rebirth) existem na base
local function CountBestBrainrotsInBase(brainrotsInBase)
    local count = 0
    for _, br in ipairs(brainrotsInBase) do
        if not IsRebirthBrainrotIndex(br.Index) then
            count = count + 1
        end
    end
    return count
end


local function GetMyBrainrotCount()
    local brainrots = GetRealBrainrotsFromBase()
    return #brainrots
end

local function GetTotalGenerationSum()
    local brainrots = GetRealBrainrotsFromBase()
    local total = 0
    for _, brainrot in brainrots do
        total = total + (brainrot.Generation or 0)
    end
    return total
end

local function GetCoins()
    if not cashValue then return 0 end
    return ParseMoney(cashValue.Value)
end

local function GetRebirths()
    if not rebirthsValue then return 0 end
    return rebirthsValue.Value or 0
end

-- True se o jogador está carregando um brainrot (atributo Stealing no LocalPlayer)
local function IsCarryingBrainrot()
    local v = player:GetAttribute("Stealing")
    if v and v == true then return true end
end

-- ========== UTILS ==========
local function FormatNumber(num)
    num = tonumber(num) or 0
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return formatted
end

local _lastBrainrotsCache = {}
local _lastBrainrotsCacheTime = 0
local BRAINROTS_CACHE_TTL = 5

local function getbrainrots()
    if not replicator then 
        if tick() - _lastBrainrotsCacheTime < BRAINROTS_CACHE_TTL then return _lastBrainrotsCache end
        return {} 
    end
    
    local success, brainrotsFolder = pcall(function()
        return replicator.get("TsunamiEvent/Brainrots")
    end)
    
    if not success or not brainrotsFolder then 
        if tick() - _lastBrainrotsCacheTime < BRAINROTS_CACHE_TTL then return _lastBrainrotsCache end
        return {} 
    end
    
    local brainrots = brainrotsFolder:TryIndex({"brainrots"})
    if not brainrots then 
        if tick() - _lastBrainrotsCacheTime < BRAINROTS_CACHE_TTL then return _lastBrainrotsCache end
        return {} 
    end

    local result = {}
    local count = 0
    for id, data in pairs(brainrots) do
        local generation = 0
        if animals and animals.GetGeneration then
            local genSuccess, genValue = pcall(function()
                return animals:GetGeneration(data.brainrot, data.mutation, data.traits, nil)
            end)
            if genSuccess and genValue then
                generation = genValue
            end
        end
        
        result[id] = {
            Name = data.brainrot,
            CFrame = data.cframe,
            GrabbedBy = data.grabbed,
            Traits = data.traits,
            Mutation = data.mutation,
            Timer = data.timer,
            Generation = generation
        }
        count = count + 1
    end
    
    _lastBrainrotsCache = result
    _lastBrainrotsCacheTime = tick()
    return result
end

-- Geração mínima "boa o suficiente" (ex.: 50K/s) — não precisa ser o melhor do servidor
local MIN_GOOD_GENERATION = 50000

local function getBrainrotById(brainrotId)
    local brainrots = getbrainrots()
    if not brainrots or not brainrotId then return nil end
    for id, data in pairs(brainrots) do
        if id == brainrotId then
            return {Id = id, Data = data}
        end
    end
    return nil
end

local function getBestBrainrot()
    local brainrots = getbrainrots()
    if not brainrots or next(brainrots) == nil then return nil end
    
    local best = nil
    local bestGen = 0
    
    for id, data in pairs(brainrots) do
        if not data.GrabbedBy and data.Generation and data.Generation > bestGen then
            bestGen = data.Generation
            best = {Id = id, Data = data}
        end
    end
    
    return best
end

-- Escolha inteligente: pega um brainrot "bom o suficiente" (>= MIN_GOOD_GENERATION) mais próximo do jogador
local function getGoodEnoughBrainrot()
    local brainrots = getbrainrots()
    if not brainrots or next(brainrots) == nil then return nil end

    local char = player.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = rootPart and rootPart.Position or Vector3.new(0, 0, 0)

    local candidates = {}
    for id, data in pairs(brainrots) do
        if not data.GrabbedBy and data.Generation and data.Generation >= MIN_GOOD_GENERATION then
            local pos = data.CFrame and (typeof(data.CFrame) == "CFrame" and data.CFrame.Position or data.CFrame) or myPos
            local dist = (pos - myPos).Magnitude
            table.insert(candidates, { Id = id, Data = data, Dist = dist })
        end
    end

    if #candidates == 0 then
        return getBestBrainrot()
    end

    table.sort(candidates, function(a, b) return a.Dist < b.Dist end)
    local chosen = candidates[1]
    return { Id = chosen.Id, Data = chosen.Data }
end

local function findBrainrotByName(name)
    local brainrots = getbrainrots()
    if not brainrots or next(brainrots) == nil then return nil end
    
    for id, data in pairs(brainrots) do
        if data.Name == name and not data.GrabbedBy then
            return {Id = id, Data = data}
        end
    end
    
    return nil
end

local function getNearestProximityPrompt(position)
    local nearest = nil
    local nearestDist = math.huge
    
    local purchaseKeywords = {"vip", "robux", "buy", "purchase", "shop", "store", "premium", "gamepass", "pass"}
    local function isPurchasePrompt(prompt)
        local texts = {
            string.lower(prompt.ActionText or ""),
            string.lower(prompt.ObjectText or ""),
        }
        local parentName = string.lower((prompt.Parent and prompt.Parent.Name) or "")
        table.insert(texts, parentName)
        for _, t in ipairs(texts) do
            for _, kw in ipairs(purchaseKeywords) do
                if t:find(kw, 1, true) then return true end
            end
        end
        return false
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and not isPurchasePrompt(obj) then
            local parent = obj.Parent
            local objPos = nil
            
            if parent:IsA("BasePart") then
                objPos = parent.Position
            elseif parent:IsA("Model") and parent.PrimaryPart then
                objPos = parent.PrimaryPart.Position
            elseif parent:IsA("Model") then
                objPos = parent:GetPivot().Position
            else
                local basePart = obj:FindFirstAncestorOfClass("BasePart")
                if basePart then
                    objPos = basePart.Position
                end
            end
            
            if objPos then
                local dist = (position - objPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = obj
                end
            end
        end
    end
    
    return nearest
end

-- ========== PATH VISUALIZATION ==========
local pathVisualizationFolder = nil
local pathParts = {}

local function createPathVisualizationFolder()
    if pathVisualizationFolder and pathVisualizationFolder.Parent then
        return pathVisualizationFolder
    end
    
    pathVisualizationFolder = Instance.new("Folder")
    pathVisualizationFolder.Name = "PathVisualization"
    pathVisualizationFolder.Parent = workspace
    return pathVisualizationFolder
end

local function clearPathVisualization()
    for _, part in ipairs(pathParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    pathParts = {}
end

local function visualizePath(waypoints, startPos, endPos)
    clearPathVisualization()
    
    if not waypoints or #waypoints == 0 then
        return
    end
    
    local folder = createPathVisualizationFolder()
    
    -- Cria uma parte para cada waypoint
    for i, waypoint in ipairs(waypoints) do
        local part = Instance.new("Part")
        part.Name = "Waypoint" .. i
        part.Size = Vector3.new(1, 1, 1)
        part.Position = waypoint.Position
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.3
        
        -- Cor diferente para waypoints de jump
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            part.Color = Color3.fromRGB(255, 100, 100) -- Vermelho para jumps
            part.Size = Vector3.new(1.5, 1.5, 1.5)
        else
            part.Color = Color3.fromRGB(100, 200, 255) -- Azul para waypoints normais
        end
        
        part.Material = Enum.Material.Neon
        part.Parent = folder
        
        table.insert(pathParts, part)
        
        -- Cria uma linha conectando waypoints
        if i > 1 then
            local prevWaypoint = waypoints[i - 1]
            local distance = (waypoint.Position - prevWaypoint.Position).Magnitude
            
            if distance > 0.1 then
                local line = Instance.new("Part")
                line.Name = "Line" .. (i - 1)
                line.Size = Vector3.new(0.2, 0.2, distance)
                line.CFrame = CFrame.new(
                    (waypoint.Position + prevWaypoint.Position) / 2,
                    waypoint.Position
                )
                line.Anchored = true
                line.CanCollide = false
                line.Transparency = 0.5
                line.Color = Color3.fromRGB(100, 200, 255)
                line.Material = Enum.Material.Neon
                line.Parent = folder
                
                table.insert(pathParts, line)
            end
        end
    end
    
    -- Linha do último waypoint até o destino final
    if #waypoints > 0 then
        local lastWaypoint = waypoints[#waypoints]
        local finalDistance = (endPos - lastWaypoint.Position).Magnitude
        
        if finalDistance > 0.1 then
            local finalLine = Instance.new("Part")
            finalLine.Name = "FinalLine"
            finalLine.Size = Vector3.new(0.3, 0.3, finalDistance)
            finalLine.CFrame = CFrame.new(
                (endPos + lastWaypoint.Position) / 2,
                endPos
            )
            finalLine.Anchored = true
            finalLine.CanCollide = false
            finalLine.Transparency = 0.3
            finalLine.Color = Color3.fromRGB(100, 255, 100) -- Verde para destino final
            finalLine.Material = Enum.Material.Neon
            finalLine.Parent = folder
            
            table.insert(pathParts, finalLine)
        end
        
        -- Marca o destino final
        local endMarker = Instance.new("Part")
        endMarker.Name = "EndMarker"
        endMarker.Size = Vector3.new(2, 2, 2)
        endMarker.Position = endPos
        endMarker.Shape = Enum.PartType.Ball
        endMarker.Anchored = true
        endMarker.CanCollide = false
        endMarker.Transparency = 0.2
        endMarker.Color = Color3.fromRGB(100, 255, 100)
        endMarker.Material = Enum.Material.Neon
        endMarker.Parent = folder
        
        table.insert(pathParts, endMarker)
    end
    
    -- Marca o ponto inicial
    local startMarker = Instance.new("Part")
    startMarker.Name = "StartMarker"
    startMarker.Size = Vector3.new(2, 2, 2)
    startMarker.Position = startPos
    startMarker.Shape = Enum.PartType.Ball
    startMarker.Anchored = true
    startMarker.CanCollide = false
    startMarker.Transparency = 0.2
    startMarker.Color = Color3.fromRGB(255, 200, 100) -- Laranja para início
    startMarker.Material = Enum.Material.Neon
    startMarker.Parent = folder
    
    table.insert(pathParts, startMarker)
end

-- ========== PATHFINDING ==========
local MOVE_TIMEOUT = 30
local WP_REACHED_DIST = 4
local WP_TIMEOUT = 8
local STUCK_SECONDS = 3
local STUCK_MIN_MOVE = 1
local ARRIVED_DIST = 5

local function horizontalDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function moveToPosition(targetPosition, abortCheck)
    local pathParams = {
        AgentRadius = 3,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 8
    }

    local totalStart = tick()
    local lastProgressPos = nil
    local lastProgressTime = tick()

    while tick() - totalStart < MOVE_TIMEOUT do
        if type(abortCheck) == "function" and abortCheck() then return false end

        local char = player.Character
        if not char then return false end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return false end

        local pos = rootPart.Position
        if horizontalDist(pos, targetPosition) < ARRIVED_DIST then return true end

        if lastProgressPos then
            if (pos - lastProgressPos).Magnitude > 5 then
                lastProgressPos = pos
                lastProgressTime = tick()
            elseif tick() - lastProgressTime > 15 then
                return false
            end
        else
            lastProgressPos = pos
        end

        local path = PathfindingService:CreatePath(pathParams)
        local ok = pcall(function() path:ComputeAsync(pos, targetPosition) end)

        if not ok or path.Status ~= Enum.PathStatus.Success then
            humanoid:MoveTo(targetPosition)
            task.wait(0.5)
            continue
        end

        local waypoints = path:GetWaypoints()

        for i = 2, #waypoints do
            if type(abortCheck) == "function" and abortCheck() then return false end
            if tick() - totalStart >= MOVE_TIMEOUT then return false end

            char = player.Character
            rootPart = char and char:FindFirstChild("HumanoidRootPart")
            humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not rootPart or not humanoid then return false end

            if horizontalDist(rootPart.Position, targetPosition) < ARRIVED_DIST then return true end

            local wp = waypoints[i]
            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid:MoveTo(wp.Position)

            local wpStart = tick()
            local stuckPos = rootPart.Position
            local stuckTime = tick()

            while true do
                task.wait(0.15)
                if type(abortCheck) == "function" and abortCheck() then return false end

                char = player.Character
                rootPart = char and char:FindFirstChild("HumanoidRootPart")
                if not rootPart then return false end

                local cur = rootPart.Position
                if horizontalDist(cur, targetPosition) < ARRIVED_DIST then return true end
                if (cur - wp.Position).Magnitude < WP_REACHED_DIST then break end
                if tick() - wpStart > WP_TIMEOUT then break end

                if (cur - stuckPos).Magnitude > STUCK_MIN_MOVE then
                    stuckPos = cur
                    stuckTime = tick()
                elseif tick() - stuckTime > STUCK_SECONDS then
                    humanoid.Jump = true
                    task.wait(0.3)
                    break
                end
            end
        end

        task.wait(0.2)
    end

    return false
end

local function activateProximityPrompt(brainrotData)
    if not brainrotData or not brainrotData.CFrame then return false end
    
    local char = player.Character
    if not char then return false end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local cframe = brainrotData.CFrame
    local targetPos = typeof(cframe) == "CFrame" and cframe.Position or cframe
    
    -- Tenta várias vezes encontrar e ativar o prompt
    for attempt = 1, 10 do
        local prompt = getNearestProximityPrompt(targetPos)
        
        if prompt then
            local promptPos = prompt.Parent:IsA("BasePart") and prompt.Parent.Position or
                            (prompt.Parent:IsA("Model") and prompt.Parent.PrimaryPart and prompt.Parent.PrimaryPart.Position) or
                            (prompt:FindFirstAncestorOfClass("BasePart") and prompt:FindFirstAncestorOfClass("BasePart").Position)
            
            if promptPos then
                local distance = (rootPart.Position - promptPos).Magnitude
                if distance <= 20 then
                    if _firepp then pcall(_firepp, prompt) end
                    task.wait(0.3)
                    if _firepp then pcall(_firepp, prompt) end
                    task.wait(0.3)
                    if _firepp then pcall(_firepp, prompt) end
                    task.wait(0.5)
                    return true
                end
            end
        end
        
        task.wait(0.2)
    end
    
    return false
end

-- ========== COLLECT MONEY ==========
local function GetClaimHitboxes()
    local podiums = GetMyPodiums()
    if not podiums then return {} end
    
    local hitboxes = {}
    
    for i = 1, 10 do
        local podium = podiums:FindFirstChild(tostring(i))
        if podium then
            local hitbox = FindPath(podium, "Claim/Hitbox")
            if hitbox and hitbox:IsA("BasePart") then
                table.insert(hitboxes, hitbox.Position)
            end
        end
    end
    
    return hitboxes
end

local function CollectMoney()
    local char = player.Character
    if not char then return end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end
    
    local hitboxes = GetClaimHitboxes()
    if #hitboxes == 0 then return end
    
    local brainrotCount = GetMyBrainrotCount()
    if brainrotCount <= 0 then return end
    
    -- Coleta dinheiro de cada hitbox que tem brainrot
    for i = 1, math.min(brainrotCount, #hitboxes) do
        local hitboxPos = hitboxes[i]
        if hitboxPos then
            -- Move até o hitbox
            if moveToPosition(hitboxPos) then
                -- Aguarda um pouco para garantir que está no lugar
                task.wait(0.1)
            end
        end
    end
end

spawn(function()
    while task.wait() do
        local waves = workspace:FindFirstChild("Waves")
        if waves then
            for _, wave in waves:GetChildren() do
                if wave:IsA("Model") then
                    wave:Destroy()
                end
            end
        end
    end
end)

spawn(function()
    while task.wait() do
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health < 50 then
                hum.Health = hum.MaxHealth
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end
end)

-- ========== STATE MANAGEMENT (CollectionState definido no topo do script) ==========

-- ========== INITIALIZATION ==========
local function initializeCharacter()
    local char = player.Character
    if not char then
        char = player.CharacterAdded:Wait()
    end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then 
        return false
    end
    
    CollectionState.basePosition = Vector3.new(-311, -6, 190)
    
    task.wait(1)
    return true
end

local function checkExistingBrainrots()
    local brainrotsInBase = GetRealBrainrotsFromBase()
    
    if #brainrotsInBase == 0 then
        return
    end
    
    -- Best = qualquer brainrot que NÃO seja Gangster Footera nem Trippi Troppi
    local bestInBase = nil
    for _, br in brainrotsInBase do
        if not IsRebirthBrainrotIndex(br.Index) then
            bestInBase = br
            break
        end
    end
    if bestInBase then
        CollectionState.collected.best = true
        CollectionState.collectedAt.best = tick()
        CollectionState.collectedInfo.best = {
            Id = bestInBase.Index,
            Generation = bestInBase.Generation
        }
    end

    -- Verifica rebirth brainrots pelo Index (não pelo DisplayName cacheado)
    for name, _ in pairs(rebirth_brainrots) do
        for _, br in brainrotsInBase do
            if ResolveDisplayName(br.Index) == name then
                CollectionState.collected[name] = true
                CollectionState.collectedAt[name] = tick()
                CollectionState.collectedInfo[name] = {
                    Id = br.Index,
                    Generation = br.Generation
                }
                break
            end
        end
    end
end

-- ========== BRAINROT VERIFICATION ==========
local function brainrotStillExists(brainrotId, type)
    if type == "best" then
        return getBrainrotById(brainrotId) ~= nil
    else
        local brainrot = findBrainrotByName(type)
        return brainrot and brainrot.Id == brainrotId
    end
end

local function updateTargetPosition(brainrotId, type, targetPos)
    if type == "best" then
        local br = getBrainrotById(brainrotId)
        if br and br.Data.CFrame then
            local newCframe = br.Data.CFrame
            return typeof(newCframe) == "CFrame" and newCframe.Position or newCframe
        end
    else
        local found = findBrainrotByName(type)
        if found and found.Id == brainrotId and found.Data.CFrame then
            local newCframe = found.Data.CFrame
            return typeof(newCframe) == "CFrame" and newCframe.Position or newCframe
        end
    end
    return targetPos
end
    
-- ========== COLLECTION LOGIC ==========
local function verifyBrainrotInBase(type, targetGen, targetName, initialCount)
    local verifyTime = 3
    local startTime = tick()
    local foundInBase = false
    
    while tick() - startTime < verifyTime do
        task.wait(0.5)
        
        local brainrotsInBase = GetRealBrainrotsFromBase()
        local currentCount = #brainrotsInBase
        
        if type == "best" then
            -- Basta ter 1 brainrot na base que não seja Gangster Footera nem Trippi Troppi (= nosso "best")
            for _, br in brainrotsInBase do
                if not rebirth_brainrots[br.DisplayName] then
                    foundInBase = true
                    break
                end
            end
            if not foundInBase and currentCount > initialCount then
                foundInBase = true
            end
        else
            for _, br in brainrotsInBase do
                if br.DisplayName == targetName then
                    foundInBase = true
                    break
                end
            end
        end
        
        if foundInBase then
            break
        end
    end
    
    return foundInBase
end

-- Procura qualquer ProximityPrompt perto da posição (fallback quando getNearestProximityPrompt falha)
local function getProximityPromptsNear(position, radius)
    local list = {}
    radius = radius or 15
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local objPos = nil
            if parent:IsA("BasePart") then objPos = parent.Position
            elseif parent:IsA("Model") and parent.PrimaryPart then objPos = parent.PrimaryPart.Position
            elseif parent:IsA("Model") then objPos = parent:GetPivot().Position
            else
                local bp = obj:FindFirstAncestorOfClass("BasePart")
                if bp then objPos = bp.Position end
            end
            if objPos and (position - objPos).Magnitude <= radius then
                table.insert(list, obj)
            end
        end
    end
    return list
end

local function activateProximityPromptAtPosition(brainrotName)
    print(brainrotName)
    for _, k in workspace:GetChildren() do
        if k.Name == brainrotName then
            print(k.Name)
            for i = 1, 5 do
                fireproximityprompt(k.RootPart.ProximityPrompt)
                print("triggered")
            end
            return true
        end
    end
end

local function collectBrainrot(brainrot, type)
    print("[collectBrainrot] Iniciando coleta tipo:", type, "id:", brainrot and brainrot.Id or "nil")
    if not brainrot or not brainrot.Data.CFrame then 
        print("[collectBrainrot] brainrot ou CFrame nil")
        return false 
    end
    
    local brainrotId = brainrot.Id
    
    if not brainrotStillExists(brainrotId, type) then
        print("[collectBrainrot] brainrot nao existe mais (check inicial)")
        return false
    end
    
    local char = player.Character
    if not char then print("[collectBrainrot] character nil") return false end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then print("[collectBrainrot] rootPart ou humanoid nil") return false end
    
    local cframe = brainrot.Data.CFrame
    local targetPos = typeof(cframe) == "CFrame" and cframe.Position or cframe

    local brainrotName = brainrot.Data and brainrot.Data.Name or (type ~= "best" and type or nil)
    print("[collectBrainrot] Indo ate:", brainrotName or brainrotId)

    moveToPosition(targetPos)

    char = player.Character
    rootPart = char and char:FindFirstChild("HumanoidRootPart")
    humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return false end

    local pickedUp = false
    for attempt = 1, 20 do
        local model = brainrotName and workspace:FindFirstChild(brainrotName)
        if model then
            local rp = model:FindFirstChild("RootPart")
            local prompt = rp and rp:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                humanoid:MoveTo(model:GetPivot().Position)
                task.wait(0.3)
                if _firepp then pcall(_firepp, prompt) end
            end
        end
        task.wait(0.3)
        if IsCarryingBrainrot() then
            pickedUp = true
            print("[collectBrainrot] Brainrot pego!")
            break
        end
    end

    if not pickedUp then
        print("[collectBrainrot] Nao pegou apos 20 tentativas")
        return false
    end

    -- Grava contagem ANTES de ir à base (para confirmar depósito por aumento de contagem)
    local beforeBaseCount = #GetRealBrainrotsFromBase()
    print("[collectBrainrot] Brainrots na base antes:", beforeBaseCount)

    print("[collectBrainrot] Indo a base...")
    moveToPosition(CollectionState.basePosition)

    char = player.Character
    rootPart = char and char:FindFirstChild("HumanoidRootPart")
    humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return false end

    if IsCarryingBrainrot() then
        humanoid:MoveTo(CollectionState.basePosition)
        task.wait(1.5)
    end

    if IsCarryingBrainrot() then
        print("[collectBrainrot] Ainda carregando, andando pelos podiums...")
        local hitboxes = GetClaimHitboxes()
        for _, hitboxPos in ipairs(hitboxes) do
            if not IsCarryingBrainrot() then break end
            humanoid:MoveTo(hitboxPos)
            task.wait(1.5)
        end
    end

    -- Espera Stealing virar false (brainrot saiu das mãos)
    local droppedFromHands = false
    for i = 1, 15 do
        task.wait(0.5)
        if not IsCarryingBrainrot() then
            droppedFromHands = true
            break
        end
    end
    print("[collectBrainrot] Stealing=false:", droppedFromHands)

    if not droppedFromHands then return false end

    -- Confirma depósito pela contagem: basta a base ter mais brainrots do que antes.
    -- Sem depender de DisplayName/AnimalsData (evita falso negativo por classificação errada).
    local confirmedInBase = false
    for attempt = 1, 6 do
        task.wait(0.5)
        local afterCount = #GetRealBrainrotsFromBase()
        print("[collectBrainrot] Base count após depósito:", afterCount, "(antes:", beforeBaseCount .. ")")
        if afterCount > beforeBaseCount then
            confirmedInBase = true
            break
        end
    end
    print("[collectBrainrot] Confirmado na base:", confirmedInBase)

    if confirmedInBase then
        CollectionState.collected[type] = true
        CollectionState.collectedAt[type] = tick()
        CollectionState.collectedInfo[type] = {
            Id = brainrot.Id,
            Generation = brainrot.Data.Generation
        }
        print("[collectBrainrot] Estado confirmado: collected[" .. tostring(type) .. "] = true")
        return true
    end

    -- Stealing virou false mas brainrot não está na base: foi perdido
    print("[collectBrainrot] Brainrot perdido (nao chegou ao podium)")
    return false
end
    
-- ========== STATE VERIFICATION ==========
local function verifyBaseBrainrots()
    -- Sem AnimalsData, ResolveDisplayName retorna índice bruto e classifica errado.
    -- Não reseta estado até ter certeza da classificação.
    if not AnimalsData then
        return false
    end

    local brainrotsInBase = GetRealBrainrotsFromBase()
    local stateChanged = false

    -- Lista vazia = Synchronizer não respondeu, ignora para evitar falso negativo
    if #brainrotsInBase == 0 then
        return false
    end

    -- Best = existe algum brainrot na base que NÃO é Gangster Footera nem Trippi Troppi
    if CollectionState.collected.best then
        if CountBestBrainrotsInBase(brainrotsInBase) == 0 then
            CollectionState.collected.best = false
            CollectionState.collectedAt.best = 0
            CollectionState.collectedInfo.best = nil
            print("⚠️ Best brainrot não está mais na base")
            stateChanged = true
        end
    end

    for name, _ in pairs(rebirth_brainrots) do
        if CollectionState.collected[name] and CollectionState.collectedInfo[name] then
            local foundInBase = false
            for _, brainrot in brainrotsInBase do
                if ResolveDisplayName(brainrot.Index) == name then
                    foundInBase = true
                    break
                end
            end
            if not foundInBase then
                CollectionState.collected[name] = false
                CollectionState.collectedAt[name] = 0
                CollectionState.collectedInfo[name] = nil
                print("⚠️", name, "não está mais na base")
                stateChanged = true
            end
        end
    end

    return stateChanged
end

local function verifyCurrentTarget()
    if not CollectionState.currentTarget then
        return false
    end
    
    if tick() - (CollectionState.targetSetAt or 0) < 15 then
        return false
    end
    
    local stillExists = false
    
    if CollectionState.targetType == "best" then
        local br = getBrainrotById(CollectionState.currentTarget.Id)
        if br then
            stillExists = true
            CollectionState.currentTarget = br
        end
    else
        local brainrot = findBrainrotByName(CollectionState.targetType)
        if brainrot and brainrot.Id == CollectionState.currentTarget.Id then
            stillExists = true
            CollectionState.currentTarget = brainrot
        end
    end
    
    if not stillExists then
        print("⚠️ Target atual sumiu do mapa, limpando...")
        CollectionState.currentTarget = nil
        CollectionState.targetType = nil
        return true
    end
    
    return false
end

local function verifyCompleteState()
    local stateChanged = verifyBaseBrainrots()
    local targetChanged = verifyCurrentTarget()
    return stateChanged or targetChanged
end
    
-- ========== TARGET MANAGEMENT ==========
local NEAR_BASE_RADIUS = 120  -- se estiver perto da base e perder o target, vai pra base primeiro (não volta pro best no mapa)

local function isNearBase()
    if not CollectionState.basePosition then return false end
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return horizontalDist(root.Position, CollectionState.basePosition) <= NEAR_BASE_RADIUS
end

local function findNewTarget()
    -- Se já está carregando um brainrot (Stealing = true), vai à base depositar antes de buscar outro
    if IsCarryingBrainrot() then
        updateStatus("Carregando brainrot, indo à base...")
        moveToPosition(CollectionState.basePosition)
    elseif isNearBase() then
        -- Se estamos perto da base e perdemos o target (brainrot deu tp etc), vai pra base primeiro
        updateStatus("Voltando à base antes de buscar outro...")
        moveToPosition(CollectionState.basePosition)
    end

    if not CollectionState.collected.best then
        local chosen = getGoodEnoughBrainrot()
        if chosen and chosen.Data.CFrame then
            CollectionState.currentTarget = chosen
            CollectionState.targetType = "best"
            CollectionState.targetSetAt = tick()
            local gen = chosen.Data.Generation or 0
            print("Buscando brainrot bom o suficiente (Gen >= " .. MIN_GOOD_GENERATION .. ", escolhido: " .. gen .. ")...")
            return true
        end
    else
        for name, _ in pairs(rebirth_brainrots) do
            if not CollectionState.collected[name] then
                local brainrot = findBrainrotByName(name)
                if brainrot and brainrot.Data.CFrame then
                    CollectionState.currentTarget = brainrot
                    CollectionState.targetType = name
                    CollectionState.targetSetAt = tick()
                    return true
                end
            end
        end
    end
    return false
end

local function isAllCollected()
    if not CollectionState.collected.best then
        return false
    end
    
    for name, _ in pairs(rebirth_brainrots) do
        if not CollectionState.collected[name] then
            return false
        end
    end
    
    return true
end

-- ========== REBIRTH SYSTEM ==========
local function HasAllSafeBrainrots()
    local brainrotsInBase = GetRealBrainrotsFromBase()
    if #brainrotsInBase == 0 then return false end
    
    local counts = {}
    for name, _ in pairs(rebirth_brainrots) do
        counts[name] = 0
    end
    
    for _, brainrot in brainrotsInBase do
        if rebirth_brainrots[brainrot.DisplayName] then
            counts[brainrot.DisplayName] = (counts[brainrot.DisplayName] or 0) + 1
        end
    end
    
    for name, minRequired in pairs(rebirth_brainrots) do
        if (counts[name] or 0) < minRequired then
            return false
        end
    end
    
    return true
end

local lastRebirthAttempt = 0
local function TryRebirth()
    if tick() - lastRebirthAttempt < 3 then return false end
    lastRebirthAttempt = tick()

    local coins = GetCoins()
    if coins < 500000 then return false end

    if type(isAllCollected) == "function" and not isAllCollected() then return false end

    updateStatus("Fazendo rebirth...")
    print("[Rebirth] Tentando rebirth com $" .. coins)

    local ok, err = pcall(function()
        local btn = playerGui.Rebirth.Rebirth.Content.Rebirth
        firesignal(btn.Activated)
    end)

    if ok then
        print("[Rebirth] firesignal executado com sucesso!")
        return true
    end

    print("[Rebirth] firesignal falhou:", tostring(err))
    return false
end

-- ========== MAIN LOOPS ==========
local function verificationLoop()
    local lastVerifyTime = 0
    
    while true do
        if tick() - lastVerifyTime >= 1 then
            lastVerifyTime = tick()
            verifyCompleteState()
        end
        task.wait(0.5)
    end
end

local function moneyCollectionLoop()
    while true do
        if isAllCollected() then
            local brainrotCount = GetMyBrainrotCount()
            if brainrotCount > 0 then
                CollectMoney()
            end
            -- Tenta rebirth imediatamente após cada ciclo de coleta
            task.spawn(TryRebirth)
            task.wait(10)
        else
            task.wait(1)
        end
    end
end

local TARGET_STUCK_SECONDS = 15

local function collectionLoop()
    while true do
        if not isAllCollected() then
            if CollectionState.currentTarget and CollectionState.currentTarget.Data.CFrame then
                if tick() - (CollectionState.targetSetAt or 0) > TARGET_STUCK_SECONDS then
                    CollectionState.currentTarget = nil
                    CollectionState.targetType = nil
                elseif IsCarryingBrainrot() then
                    moveToPosition(CollectionState.basePosition)
                    local char2 = player.Character
                    local hum2 = char2 and char2:FindFirstChildOfClass("Humanoid")
                    if hum2 then
                        hum2:MoveTo(CollectionState.basePosition)
                        task.wait(1.5)
                    end
                    if IsCarryingBrainrot() then
                        local hitboxes = GetClaimHitboxes()
                        for _, hitboxPos in ipairs(hitboxes) do
                            if not IsCarryingBrainrot() then break end
                            if hum2 then hum2:MoveTo(hitboxPos) end
                            task.wait(1.5)
                        end
                    end
                    CollectionState.currentTarget = nil
                    CollectionState.targetType = nil
                elseif not brainrotStillExists(CollectionState.currentTarget.Id, CollectionState.targetType) then
                    CollectionState.currentTarget = nil
                    CollectionState.targetType = nil
                else
                    if collectBrainrot(CollectionState.currentTarget, CollectionState.targetType) then
                        CollectionState.currentTarget = nil
                        CollectionState.targetType = nil
                    else
                        -- Falhou (brainrot sumiu etc): limpa na hora e busca outro
                        CollectionState.currentTarget = nil
                        CollectionState.targetType = nil
                    end
                end
            else
                CollectionState.currentTarget = nil
                CollectionState.targetType = nil

                if not findNewTarget() then
                    -- NÃO coleta dinheiro aqui - prioridade é coletar brainrots
                    -- Dinheiro só será coletado depois que todos os 3 brainrots forem coletados
                    task.wait(0.5)
                end
            end
        else
            -- Se já coletou tudo, verifica se pode fazer rebirth
            TryRebirth()
            task.wait(1)
        end
        
        task.wait(0.5)
    end
end

-- ========== REBIRTH CHECK LOOP ==========
local function rebirthCheckLoop()
    while true do
        task.wait(2) -- Verifica a cada 2 segundos
        
        if isAllCollected() then
            TryRebirth()
        end
    end
end

-- ========== FPS BOOST SYSTEM ==========
local fpsBoostEnabled = true
local fpsBoostGui = nil
local statusLabels = {}
local function CreateFPSBoostUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MorangueteAutoRebirth"
    screenGui.DisplayOrder = 999999
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Overlay"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.Position = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 80)
    title.Position = UDim2.new(0, 0, 0.15, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 48
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Text = "🍓 Moranguete Auto Rebirth 🍓"
    title.Parent = mainFrame
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 30)
    subtitle.Position = UDim2.new(0, 0, 0.15, 85)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 18
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    subtitle.Text = "Pressione CTRL para desativar interface"
    subtitle.Parent = mainFrame
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(0, 500, 0, 350)
    infoFrame.Position = UDim2.new(0.5, -250, 0.4, 0)
    infoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = mainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = infoFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 100, 100)
    stroke.Thickness = 2
    stroke.Parent = infoFrame
    
    local labels = {
        {name = "Money", icon = "💰", y = 0},
        {name = "Rebirths", icon = "🔄", y = 50},
        {name = "Brainrots", icon = "🧠", y = 100},
        {name = "Status", icon = "📊", y = 150},
        {name = "Target", icon = "🎯", y = 200},
        {name = "Progress", icon = "📈", y = 250}
    }
    
    for _, info in ipairs(labels) do
        local label = Instance.new("TextLabel")
        label.Name = info.name
        label.Size = UDim2.new(1, -40, 0, 45)
        label.Position = UDim2.new(0, 20, 0, info.y + 20)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 22
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = info.icon .. " " .. info.name .. ": --"
        label.Parent = infoFrame
        statusLabels[info.name] = label
    end
    
    screenGui.Parent = playerGui
    return screenGui
end

local function UpdateFPSBoostUI()
    if not fpsBoostEnabled or not statusLabels.Money then return end
    
    local coins = GetCoins()
    local rebirths = rebirthsValue and rebirthsValue.Value or 0
    local brainrotCount = GetMyBrainrotCount()
    
    statusLabels.Money.Text = "💰 Money: $" .. FormatNumber(coins)
    statusLabels.Rebirths.Text = "🔄 Rebirths: " .. rebirths
    statusLabels.Brainrots.Text = "🧠 Brainrots: " .. brainrotCount
    
    -- Status atual (Stealing = true = carregando brainrot)
    local statusText = IsCarryingBrainrot() and "Carregando brainrot" or currentStatus
    statusLabels.Status.Text = "📊 Status: " .. statusText
    
    -- Target atual
    local targetText = "Nenhum"
    if CollectionState.currentTarget then
        if CollectionState.targetType == "best" then
            targetText = "Brainrot (Gen: " .. (CollectionState.currentTarget.Data.Generation or 0) .. ")"
        else
            targetText = CollectionState.targetType
        end
    end
    statusLabels.Target.Text = "🎯 Target: " .. targetText
    
    -- Progresso
    local collectedCount = 0
    if CollectionState.collected.best then collectedCount = collectedCount + 1 end
    if CollectionState.collected["Trippi Troppi"] then collectedCount = collectedCount + 1 end
    if CollectionState.collected["Gangster Footera"] then collectedCount = collectedCount + 1 end
    statusLabels.Progress.Text = "📈 Progress: " .. collectedCount .. "/3 brainrots"
end

local function SetFPSBoost(enabled)
    fpsBoostEnabled = enabled
    
    if enabled then
        RunService:Set3dRenderingEnabled(false)
        
        if not fpsBoostGui then
            fpsBoostGui = CreateFPSBoostUI()
        end
        fpsBoostGui.Enabled = true
    else
        RunService:Set3dRenderingEnabled(true)
        
        if fpsBoostGui then
            fpsBoostGui.Enabled = false
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        SetFPSBoost(not fpsBoostEnabled)
    end
end)


-- ========== AUTO CHANGE ACC LOOP ==========
local function autoChangeAccLoop()
    while task.wait(1) do
        if _G.change_acc then
            if rebirthsValue then
                local rebirths = rebirthsValue.Value
                
                if rebirths >= 1 then
                    local fileName = player.Name .. ".txt"
                    
                    pcall(function()
                        writefile(fileName, "Completed-1Rebirth")
                    end)

                    local client = getgenv().client
                    if client and type(client.ChangeToFolder) == "function" then
                        local changed = client:ChangeToFolder(
                            "1f2f9a67db86d9003a3f1ad68aeb3b126548ad6a77a3f3cd390cff94e7ea239f",
                            "b376b03ba2e36d9379762afdb4792d5e82d7d9e23873c1244705cfd36afeabaa",
                            true,
                            nil
                        )
                    end
                end
            end
        end
    end
end

-- ========== MAIN EXECUTION ==========
task.spawn(function()
    if not initializeCharacter() then
        return
    end

    -- Aguarda AnimalsData e SynchronizerModule antes de classificar brainrots da base.
    -- Sem isso, ResolveDisplayName retorna índice bruto e classifica errado.
    local waitStart = tick()
    while (not AnimalsData or not SynchronizerModule) and tick() - waitStart < 20 do
        task.wait(0.3)
    end
    if not AnimalsData then
        warn("[AutoRebirth] AnimalsData não carregou, detecção pode ser imprecisa")
    end

    checkExistingBrainrots()
    
    task.spawn(verificationLoop)
    task.spawn(moneyCollectionLoop)
    task.spawn(rebirthCheckLoop)
    task.spawn(autoChangeAccLoop)
    
    -- UI Update Loop
    task.spawn(function()
        while true do
            task.wait(0.5)
            UpdateFPSBoostUI()
        end
    end)
    
    -- Atualiza status durante coleta
    local function collectionLoopWithStatus()
        while true do
            if not isAllCollected() then
                if CollectionState.currentTarget and CollectionState.currentTarget.Data.CFrame then
                    if tick() - (CollectionState.targetSetAt or 0) > TARGET_STUCK_SECONDS then
                        print("[Loop] Target stuck por", math.floor(tick() - (CollectionState.targetSetAt or 0)), "s, limpando")
                        updateStatus("Target travou, buscando outro...")
                        CollectionState.currentTarget = nil
                        CollectionState.targetType = nil
                    elseif IsCarryingBrainrot() then
                        updateStatus("Carregando brainrot, indo à base...")
                        moveToPosition(CollectionState.basePosition)
                        local char2 = player.Character
                        local hum2 = char2 and char2:FindFirstChildOfClass("Humanoid")
                        if hum2 then
                            hum2:MoveTo(CollectionState.basePosition)
                            task.wait(1.5)
                        end
                        if IsCarryingBrainrot() then
                            local hitboxes = GetClaimHitboxes()
                            for _, hitboxPos in ipairs(hitboxes) do
                                if not IsCarryingBrainrot() then break end
                                if hum2 then hum2:MoveTo(hitboxPos) end
                                task.wait(1.5)
                            end
                        end
                        if not IsCarryingBrainrot() and CollectionState.targetType then
                            CollectionState.collected[CollectionState.targetType] = true
                            CollectionState.collectedAt[CollectionState.targetType] = tick()
                            print("[Loop] Estado confirmado: collected[" .. tostring(CollectionState.targetType) .. "] = true")
                            updateStatus("Brainrot depositado!")
                        end
                        CollectionState.currentTarget = nil
                        CollectionState.targetType = nil
                    elseif not brainrotStillExists(CollectionState.currentTarget.Id, CollectionState.targetType) then
                        print("[Loop] brainrotStillExists=false, id:", CollectionState.currentTarget.Id, "tipo:", CollectionState.targetType)
                        CollectionState.currentTarget = nil
                        CollectionState.targetType = nil
                        updateStatus("Buscando novo target...")
                    else
                        local targetName = CollectionState.targetType == "best" and "Best Brainrot" or CollectionState.targetType
                        updateStatus("Coletando " .. targetName .. "...")
                        if collectBrainrot(CollectionState.currentTarget, CollectionState.targetType) then
                            CollectionState.currentTarget = nil
                            CollectionState.targetType = nil
                            updateStatus("Brainrot coletado!")
                        else
                            CollectionState.currentTarget = nil
                            CollectionState.targetType = nil
                            updateStatus("Brainrot sumiu, buscando outro...")
                        end
                    end
                else
                    CollectionState.currentTarget = nil
                    CollectionState.targetType = nil
                    updateStatus("Buscando target...")
                    
                    if not findNewTarget() then
                        task.wait(0.5)
                    end
                end
            else
                local coins = GetCoins()
                if coins >= 500000 then
                    updateStatus("Fazendo rebirth...")
                    TryRebirth()
                    updateStatus("Coletando dinheiro...")
                else
                    updateStatus("Coletando dinheiro...")
                end
                task.wait(1)
            end
            
            task.wait(0.5)
        end
    end
    
    SetFPSBoost(true)
    collectionLoopWithStatus()
end)

local function dupeServer()
    local pkg = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
    if not pkg then return end
    local netMod = pkg:FindFirstChild("Net")
    if not netMod then return end
    local ok, moranguete = pcall(require, netMod)
    if not ok or not moranguete then return end
    local ok2, remote = pcall(function() return moranguete:RemoteEvent("TeleportService/Reconnect") end)
    if ok2 and remote then pcall(function() remote:FireServer() end) end
end

task.spawn(function()
    local moranguete = game:GetService("RobloxReplicatedStorage"):FindFirstChild("GetServerType")
    if not moranguete then return end
    local ok, serverType = pcall(function() return moranguete:InvokeServer() end)
    if not ok then return end
	while task.wait() do
        local isPublic = (serverType == "StandardServer")
		if isPublic then
            game:Shutdown()
        elseif #Players:GetPlayers() >= 2 then
            dupeServer()
        end
	end
end)
