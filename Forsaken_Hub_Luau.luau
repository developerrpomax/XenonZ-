--!nonstrict
--   XenonZ v1.0 | Luau
--   Tabs: Visual | Survivor | Killer | Stamina | Characters | Misc | Settings
--   Engine: Gloop (Delta X 2.0) | UNC: 100% | Level 8

if getgenv().XenonZLoaded then
    print("[XenonZ] Already loaded. Destroying old instance...")
    if getgenv().XenonZDestroy then getgenv().XenonZDestroy() end
end
getgenv().XenonZLoaded = true

local Players: Players      = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local Lighting: Lighting    = game:GetService("Lighting")
local LocalPlayer: Player   = Players.LocalPlayer

type Connection = RBXScriptConnection
local Connections: { Connection } = {}
local function AddConn(c: Connection) table.insert(Connections, c) end

getgenv().XenonZDestroy = function()
    for _, c in Connections do pcall(function() c:Disconnect() end) end
    -- clean up world-space objects
    pcall(function()
        if rangeCircleConn then rangeCircleConn:Disconnect() end
        if rangeCirclePart then rangeCirclePart:Destroy() end
        if coneLineL then coneLineL:Destroy() end
        if coneLineR then coneLineR:Destroy() end
    end)
    getgenv().XenonZLoaded = false
    print("[XenonZ] Destroyed cleanly.")
end

local function getChar(): Model?    return LocalPlayer.Character end
local function getHumanoid(): Humanoid?
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid") :: Humanoid?
end
local function getHRP(): BasePart?
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function safeCall(fn: (...any) -> (), ...: any)
    local ok, err = pcall(fn, ...)
    if not ok then warn(`[XenonZ] {tostring(err)}`) end
end
local function removeESP(container: Instance?, name: string)
    if container then
        local ex = container:FindFirstChild(name)
        if ex then ex:Destroy() end
    end
end

type FlagsTable = {
    infStamina: boolean, noclipping: boolean, killerESP: boolean, playerESP: boolean,
    genESP: boolean, itemESP: boolean, tripmineESP: boolean, tripwireESP: boolean,
    fullBright: boolean, removeFog: boolean, autoGen: boolean,
    buildermanESP: boolean, elliotPizzaESP: boolean, veeronicaSprayESP: boolean,
}
local flags: FlagsTable = {
    infStamina=false, noclipping=false, killerESP=false, playerESP=false,
    genESP=false, itemESP=false, tripmineESP=false, tripwireESP=false,
    fullBright=false, removeFog=false, autoGen=false,
    buildermanESP=false, elliotPizzaESP=false, veeronicaSprayESP=false,
}

local Rayfield: any
safeCall(function() Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))() end)
if not Rayfield then warn("[XenonZ] Rayfield failed to load."); return end

local function notify(title: string, content: string, duration: number?)
    safeCall(function() Rayfield:Notify({Title=title, Content=content, Duration=duration or 3, Image=4483362458}) end)
end

local Window = Rayfield:CreateWindow({
    Name="XenonZ", Icon=0,
    LoadingTitle="XenonZ is the best",
    LoadingSubtitle="Delta X | Gloop Engine",
    Theme="BloodMoon",
    DisableRayfieldPrompts=false,
    DisableBuildWarnings=true,
    KeySystem = true,
    KeySettings = {
        Title      = "XenonZ",
        Subtitle   = "Enter your key to continue",
        Note       = "Get your key in our Discord → https://discord.gg/ehHtxQuZr",
        FileName   = "XenonZKey",
        SaveKey    = true,
        GrabKeyFromSite = false,
        Key        = {"XenonZ is the best"}
    }
})

-- load sequence after key

task.spawn(function()
    task.wait(0.3)
    notify("XenonZ", "🔑 Key accepted — loading XenonZ...", 2)

    task.wait(0.5)
    notify("XenonZ", "⚙️ Initialising ESP systems...", 1)

    task.wait(0.5)
    notify("XenonZ", "🔊 Connecting sound hooks...", 1)
    -- Re-run sound block setup so auto-block is ready from the first frame
    pcall(function()
        if LocalPlayer.Character then
            local kf: Instance? = nil
            pcall(function() kf = workspace.Players.Killers end)
            if kf then
                -- SoundBlock.setup is defined later — we defer to after all code loads
            end
        end
    end)

    task.wait(0.5)
    notify("XenonZ", "🎯 Loading Auto Block engine...", 1)

    task.wait(0.5)
    notify("XenonZ", "🏃 Stamina & Speed systems ready...", 1)

    task.wait(0.5)
    notify("XenonZ", "🗺️ Generator ESP standby...", 1)

    task.wait(0.5)
    notify("XenonZ", "✅ All systems loaded! Welcome to XenonZ ❤️", 4)
end)

-- TAB 1 ► VISUALS
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateSection("Player ESP")

-- or workspace.Players.Survivors — that is the authoritative source.
local function getRole(player: Player): string
    local c = player.Character
    if c then
        -- Primary: check which Forsaken folder the character lives in
        pcall(function()
            local pf = workspace:FindFirstChild("Players")
            if pf then
                local kf = (pf :: Folder):FindFirstChild("Killers")
                if kf then
                    for _, model in kf:GetChildren() do
                        if model == c then return end  -- handled below
                    end
                    -- Check by model name match too
                    if kf:FindFirstChild(c.Name) then return end
                end
            end
        end)
        -- Direct folder parent check — most reliable
        if c.Parent and c.Parent.Name == "Killers" then
            return "killer"
        end
        -- Tag-based fallback
        if c:FindFirstChild("KillerTag") or c:FindFirstChild("IsKiller")
            or c:FindFirstChild("Killer") then
            return "killer"
        end
    end
    -- Data/Stats folder fallback
    local data = player:FindFirstChild("Data") or player:FindFirstChild("Stats")
    if data then
        local role = (data :: Folder):FindFirstChild("Role")
            or (data :: Folder):FindFirstChild("Team")
        if role and tostring((role :: any).Value):lower():find("killer") then
            return "killer"
        end
    end
    return "survivor"
end

-- Returns the character/skin name from the player's character model.
-- Tries known tag values then falls back to the model name itself.
local function getCharacterName(p: Player, c: Model): string
    -- Some games tag the character with the skin name via an attribute or StringValue
    local tag = c:FindFirstChild("CharacterName") or c:FindFirstChild("SkinName")
        or c:FindFirstChild("Role") or c:FindFirstChild("Class")
    if tag and tag:IsA("StringValue") then return (tag :: StringValue).Value end
    local attr = c:GetAttribute("CharacterName") or c:GetAttribute("SkinName")
    if attr and type(attr) == "string" then return attr end
    -- Fall back to the model name (Forsaken names character models after the character)
    if c.Name ~= p.Name and c.Name ~= "Character" then return c.Name end
    return "Unknown"
end

local function applyPlayerESPToChar(p: Player, c: Model)
    if not flags.playerESP then return end
    if not c or not c.Parent then return end

    -- Determine colour
    local fillColor: Color3
    local outlineColor = Color3.fromRGB(255, 255, 255)
    if p == LocalPlayer then
        fillColor    = Color3.fromRGB(80, 160, 255)
        outlineColor = Color3.fromRGB(180, 220, 255)
    elseif getRole(p) == "killer" then
        fillColor = Color3.fromRGB(255, 30, 30)
    else
        fillColor = Color3.fromRGB(0, 220, 80)
    end

    -- Highlight — always rebuild to ensure colour reflects current role
    removeESP(c, "ESP_Hl")
    local hl = Instance.new("Highlight")
    hl.Name             = "ESP_Hl"
    hl.FillColor        = fillColor
    hl.OutlineColor     = outlineColor
    hl.FillTransparency = 0.45
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = c

    -- BillboardGui — Name | HP | Character
    local existBB = c:FindFirstChild("ESP_BB") :: BillboardGui?
    if existBB then existBB:Destroy() end

    local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "ESP_BB"
    bb.Adornee     = hrp
    bb.Size        = UDim2.new(0, 160, 0, 18)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 150
    bb.Parent      = c

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextSize               = 11
    lbl.TextScaled             = false
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextColor3             = fillColor
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent                 = bb

    -- Live update function — refreshes HP every heartbeat tick
    local hum = c:FindFirstChildOfClass("Humanoid")
    local charName = getCharacterName(p, c)

    local function updateLabel()
        pcall(function()
            if not lbl or not lbl.Parent then return end
            local hp    = hum and math.floor(hum.Health) or 0
            local maxHp = hum and math.floor(hum.MaxHealth) or 100
            lbl.Text = `{p.Name} | {hp}/{maxHp} HP | {charName}`
        end)
    end

    updateLabel()

    if hum then
        hum.HealthChanged:Connect(function()
            updateLabel()
        end)
    end

    -- Cleanup when character is removed
    c.AncestryChanged:Connect(function()
        if not c.Parent then
            pcall(function() bb:Destroy() end)
        end
    end)
end

local playerESPCharConns: { [Player]: Connection } = {}

local function hookPlayerESPChar(p: Player)
    -- Disconnect old CharacterAdded connection for this player if any
    if playerESPCharConns[p] then
        pcall(function() playerESPCharConns[p]:Disconnect() end)
        playerESPCharConns[p] = nil
    end
    -- Apply to current character immediately
    if p.Character then applyPlayerESPToChar(p, p.Character) end
    -- Re-apply on every future respawn
    playerESPCharConns[p] = p.CharacterAdded:Connect(function(c: Model)
        task.wait(0.5) -- wait for character to fully load
        applyPlayerESPToChar(p, c)
    end)
end

local playerESPPlayerAddedConn: Connection? = nil

VisualsTab:CreateToggle({
    Name="Player ESP (Blue=You / Green=Survivor / Red=Killer)", CurrentValue=false, Flag="PlayerESP",
    Callback=function(v: boolean)
        flags.playerESP = v
        if not v then
            -- Remove all highlights
            for _, p in Players:GetPlayers() do
                local c = p.Character
                if c then removeESP(c, "ESP_Hl") end
            end
            -- Disconnect all CharacterAdded hooks
            for p, conn in playerESPCharConns do
                pcall(function() conn:Disconnect() end)
            end
            playerESPCharConns = {}
            if playerESPPlayerAddedConn then
                pcall(function() playerESPPlayerAddedConn:Disconnect() end)
                playerESPPlayerAddedConn = nil
            end
            notify("Player ESP", "Disabled.", 3)
            return
        end
        -- Apply to all current players and hook their CharacterAdded
        for _, p in Players:GetPlayers() do
            hookPlayerESPChar(p)
        end
        -- Hook players who join later
        playerESPPlayerAddedConn = Players.PlayerAdded:Connect(function(p: Player)
            if not flags.playerESP then return end
            hookPlayerESPChar(p)
        end)
        AddConn(playerESPPlayerAddedConn)
        notify("Player ESP", "Blue=You | Green=Survivor | Red=Killer", 3)
    end,
})

-- Lightweight rescan: only iterates Players:GetPlayers() (small set, not workspace)
-- Runs every 10s — only re-applies if a highlight has been removed
task.spawn(function()
    while true do
        task.wait(10)
        if not flags.playerESP then continue end
        pcall(function()
            for _, p in Players:GetPlayers() do
                local c = p.Character
                if not c then continue end
                if not c:FindFirstChild("ESP_Hl") then
                    applyPlayerESPToChar(p, c)
                end
            end
        end)
    end
end)

VisualsTab:CreateSection("Objective ESP")

-- GENERATOR ESP — rebuilt with broad workspace scan
-- Does not rely on a fixed map path. Scans all workspace descendants
-- for any Model whose name contains "Generator" or "FakeGenerator",
-- and hooks progress values directly for live updates.
local generatorESPEnabled: boolean = false
local trackedGenerators: { [Model]: { conn: Connection?, bb: BillboardGui? } } = {}
local genEspPartTrigger: Connection? = nil
local genEspConnection: Connection?  = nil

-- Find every generator Model anywhere in workspace
local function findAllGenerators(): { Model }
    local results: { Model } = {}
    for _, obj in workspace:GetDescendants() do
        if not obj:IsA("Model") then continue end
        local n = obj.Name:lower()
        if n:find("generator") or n:find("fakegenerator") or n == "fakegen" then
            table.insert(results, obj :: Model)
        end
    end
    return results
end

local function isFakeGen(model: Model): boolean
    local n = model.Name:lower()
    return n:find("fake") ~= nil or model:GetAttribute("Fake") == true
end

local function getProgressPercent(value: number): string
    if     value == 0   then return "0%"
    elseif value == 26  then return "25%"
    elseif value == 52  then return "50%"
    elseif value == 78  then return "75%"
    elseif value == 100 then return "100%"
    else return `{math.floor(value)}%`
    end
end

-- Finds the best adornee BasePart in a generator model
local function getGenAdornee(model: Model): BasePart?
    if model.PrimaryPart then return model.PrimaryPart end
    for _, name in {"Base","Main","HumanoidRootPart","Core","Body"} do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p :: BasePart end
    end
    return model:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

-- Builds or updates the BillboardGui label for a generator
local function buildGenLabel(model: Model): BillboardGui?
    local adornee = getGenAdornee(model)
    if not adornee then return nil end

    local bb = model:FindFirstChild("GenESP_BB") :: BillboardGui?
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name        = "GenESP_BB"
        bb.Adornee     = adornee
        bb.Size        = UDim2.new(0, 120, 0, 20)
        bb.StudsOffset = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 200
        bb.Parent      = model

        local lbl = Instance.new("TextLabel")
        lbl.Name                   = "GenLabel"
        lbl.Size                   = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextScaled             = false
        lbl.TextSize               = 11
        lbl.Font                   = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3       = Color3.fromRGB(0,0,0)
        lbl.Parent                 = bb
    end

    -- Set initial text
    local lbl = bb:FindFirstChild("GenLabel") :: TextLabel?
    if lbl then
        if isFakeGen(model) then
            lbl.Text       = "⚠️ FAKE GEN"
            lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
        else
            -- Try to read current progress immediately
            local prog = model:FindFirstChild("Progress")
                or model:FindFirstChild("ProgressValue")
                or model:FindFirstChild("Percentage")
                or model:FindFirstChild("GeneratorProgress")
            local pct = "0%"
            if prog and (prog:IsA("NumberValue") or prog:IsA("IntValue")) then
                pct = getProgressPercent((prog :: NumberValue).Value)
            end
            lbl.Text       = `⚡ GEN {pct}`
            lbl.TextColor3 = Color3.fromRGB(0, 200, 255)
        end
    end
    return bb
end

-- Also adds a Highlight so the generator box glows
local function buildGenHighlight(model: Model)
    if model:FindFirstChild("GenESP_Hl") then return end
    local hl = Instance.new("Highlight")
    hl.Name               = "GenESP_Hl"
    hl.FillColor          = isFakeGen(model) and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(0, 140, 255)
    hl.OutlineColor       = isFakeGen(model) and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(100, 200, 255)
    hl.FillTransparency   = 0.4
    hl.OutlineTransparency = 0
    hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent             = model
end

-- Attaches full ESP (Highlight + BillboardGui + live progress hook) to one generator
local function attachGenESP(model: Model)
    if not model or not model.Parent then return end
    if trackedGenerators[model] then return end  -- already tracked

    buildGenHighlight(model)
    local bb = buildGenLabel(model)

    -- Hook live progress updates
    local progressConn: Connection? = nil
    if not isFakeGen(model) then
        local prog = model:FindFirstChild("Progress")
            or model:FindFirstChild("ProgressValue")
            or model:FindFirstChild("Percentage")
            or model:FindFirstChild("GeneratorProgress")
        if prog and (prog:IsA("NumberValue") or prog:IsA("IntValue")) then
            progressConn = (prog :: NumberValue).Changed:Connect(function(val: number)
                if not generatorESPEnabled then return end
                local lbl = model:FindFirstChild("GenESP_BB") and
                    (model:FindFirstChild("GenESP_BB") :: BillboardGui):FindFirstChild("GenLabel") :: TextLabel?
                if lbl then
                    lbl.Text = `⚡ GEN {getProgressPercent(val)}`
                end
            end)
        end
    end

    trackedGenerators[model] = { conn = progressConn, bb = bb }

    -- Auto-clean when generator model is removed
    model.AncestryChanged:Connect(function()
        if model.Parent then return end
        if progressConn then pcall(function() progressConn:Disconnect() end) end
        trackedGenerators[model] = nil
    end)
end

local function detachGenESP(model: Model)
    local entry = trackedGenerators[model]
    if entry then
        if entry.conn then pcall(function() entry.conn:Disconnect() end) end
        trackedGenerators[model] = nil
    end
    local hl = model:FindFirstChild("GenESP_Hl")
    local bb = model:FindFirstChild("GenESP_BB")
    if hl then hl:Destroy() end
    if bb then bb:Destroy() end
end

local function stopGeneratorESP()
    if genEspPartTrigger then genEspPartTrigger:Disconnect(); genEspPartTrigger = nil end
    if genEspConnection  then genEspConnection:Disconnect();  genEspConnection  = nil end
    -- Remove ESP from all tracked generators
    for gen in trackedGenerators do
        pcall(function() detachGenESP(gen) end)
    end
    trackedGenerators = {}
end

local function startGeneratorESP()
    -- Full workspace scan on enable — finds all generators regardless of map path
    for _, model in findAllGenerators() do
        pcall(function() attachGenESP(model) end)
    end

    -- Watch for new generators as they spawn during a round
    if not genEspPartTrigger then
        genEspPartTrigger = workspace.DescendantAdded:Connect(function(obj: Instance)
            if not obj:IsA("Model") then return end
            local n = obj.Name:lower()
            if n:find("generator") or n:find("fakegenerator") or n == "fakegen" then
                task.wait(0.5) -- let it fully load before scanning
                if generatorESPEnabled then pcall(function() attachGenESP(obj :: Model) end) end
            end
        end)
        AddConn(genEspPartTrigger)
    end

    -- Periodic rescan every 6 seconds to catch any generators that slipped through
    if not genEspConnection then
        genEspConnection = RunService.Heartbeat:Connect(function()
            -- Only runs every 6s by using a throttle
        end)
        -- Replace with a proper task loop instead of heartbeat
        genEspConnection:Disconnect()
        genEspConnection = nil
        task.spawn(function()
            while generatorESPEnabled do
                task.wait(6)
                if not generatorESPEnabled then break end
                pcall(function()
                    for _, model in findAllGenerators() do
                        if not trackedGenerators[model] then
                            attachGenESP(model)
                        end
                    end
                end)
            end
        end)
    end
end

VisualsTab:CreateToggle({
    Name="Generator ESP (Progress + Fake Detection)", CurrentValue=false, Flag="GenESP",
    Callback=function(v: boolean)
        flags.genESP        = v
        generatorESPEnabled = v
        if v then startGeneratorESP()
        else stopGeneratorESP() end
        notify("Generator ESP",
            v and "Generators tracked! Blue=Real | Red=FAKE (Noli hallucination)" or "Disabled.", 4)
    end,
})

VisualsTab:CreateLabel("🔵 Blue = Real Generator  |  🔴 Red = FAKE Generator (Noli hallucination)")

VisualsTab:CreateSection("Item ESP")

VisualsTab:CreateToggle({
    Name="Medkit & BloxyCola ESP (Purple)", CurrentValue=false, Flag="ItemESP",
    Callback=function(v: boolean)
        flags.itemESP = v
        safeCall(function()
            local keywords = {
                "medkit","med_kit","medpack","med_pack","firstaid","first_aid","firstaidkit",
                "bloxycola","bloxy_cola","bloxy cola","cola","healthpack","health_pack",
                "potion","elixir","bandage","inject"
            }
            for _, obj in workspace:GetDescendants() do
                local n = obj.Name:lower()
                local matched = false
                for _, kw in keywords do
                    if n == kw or n:find(`^{kw}`) or n:find(`{kw}$`) then matched = true; break end
                end
                if not matched then continue end
                local target = obj:IsA("Model") and obj
                    or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent:IsA("Model") and obj.Parent)
                    or (obj:IsA("BasePart") and obj)
                if not target then continue end
                removeESP(target :: Instance, "ItemESP_Hl")
                if v then
                    local hl = Instance.new("Highlight")
                    hl.Name             = "ItemESP_Hl"
                    hl.FillColor        = Color3.fromRGB(160,0,255)
                    hl.OutlineColor     = Color3.fromRGB(220,150,255)
                    hl.FillTransparency = 0.3
                    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent           = target :: Instance
                end
            end
        end)
        notify("Item ESP", v and "Medkits & BloxyColas highlighted in Purple!" or "Disabled.", 3)
    end,
})

VisualsTab:CreateSection("Taph Trap ESP")

VisualsTab:CreateToggle({
    Name="Subspace Tripmine ESP (Orange)", CurrentValue=false, Flag="TripmineESP",
    Callback=function(v: boolean)
        flags.tripmineESP = v
        safeCall(function()
            local kws = {"tripmine","trip_mine","subspace_tripmine","subspacetripmine","proxmine"}
            for _, obj in workspace:GetDescendants() do
                local n = obj.Name:lower()
                for _, kw in kws do
                    if not n:find(kw) then continue end
                    local t = obj:IsA("Model") and obj
                        or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent)
                        or (obj:IsA("BasePart") and obj)
                    if t then
                        removeESP(t :: Instance, "TripmineESP_Hl")
                        if v then
                            local hl = Instance.new("Highlight")
                            hl.Name             = "TripmineESP_Hl"
                            hl.FillColor        = Color3.fromRGB(255,120,0)
                            hl.OutlineColor     = Color3.fromRGB(255,200,80)
                            hl.FillTransparency = 0.25
                            hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent           = t :: Instance
                        end
                    end
                    break
                end
            end
        end)
        notify("Tripmine ESP", v and "Tripmines in Orange!" or "Disabled.", 3)
    end,
})

AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
    if not flags.tripmineESP then return end
    safeCall(function()
        local n = obj.Name:lower()
        for _, kw in {"tripmine","trip_mine","subspace_tripmine","subspacetripmine","proxmine"} do
            if not n:find(kw) then continue end
            local t = obj:IsA("Model") and obj
                or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent)
                or (obj:IsA("BasePart") and obj)
            if t and not (t :: Instance):FindFirstChild("TripmineESP_Hl") then
                task.wait(0.1)
                local hl = Instance.new("Highlight")
                hl.Name="TripmineESP_Hl"; hl.FillColor=Color3.fromRGB(255,120,0)
                hl.OutlineColor=Color3.fromRGB(255,200,80); hl.FillTransparency=0.25
                hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=t :: Instance
            end
            break
        end
    end)
end))

VisualsTab:CreateToggle({
    Name="Subspace Tripwire ESP (Yellow)", CurrentValue=false, Flag="TripwireESP",
    Callback=function(v: boolean)
        flags.tripwireESP = v
        safeCall(function()
            local kws = {"tripwire","trip_wire","subspace_tripwire","subspacetripwire","wiresnare","snare"}
            for _, obj in workspace:GetDescendants() do
                local n = obj.Name:lower()
                for _, kw in kws do
                    if not n:find(kw) then continue end
                    local t = obj:IsA("Model") and obj
                        or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent)
                        or (obj:IsA("BasePart") and obj)
                    if t then
                        removeESP(t :: Instance, "TripwireESP_Hl")
                        if v then
                            local hl = Instance.new("Highlight")
                            hl.Name="TripwireESP_Hl"; hl.FillColor=Color3.fromRGB(255,240,0)
                            hl.OutlineColor=Color3.fromRGB(255,255,150); hl.FillTransparency=0.2
                            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=t :: Instance
                        end
                    end
                    break
                end
            end
        end)
        notify("Tripwire ESP", v and "Tripwires in Yellow!" or "Disabled.", 3)
    end,
})

AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
    if not flags.tripwireESP then return end
    safeCall(function()
        local n = obj.Name:lower()
        for _, kw in {"tripwire","trip_wire","subspace_tripwire","subspacetripwire","wiresnare","snare"} do
            if not n:find(kw) then continue end
            local t = obj:IsA("Model") and obj
                or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent)
                or (obj:IsA("BasePart") and obj)
            if t and not (t :: Instance):FindFirstChild("TripwireESP_Hl") then
                task.wait(0.1)
                local hl = Instance.new("Highlight")
                hl.Name="TripwireESP_Hl"; hl.FillColor=Color3.fromRGB(255,240,0)
                hl.OutlineColor=Color3.fromRGB(255,255,150); hl.FillTransparency=0.2
                hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=t :: Instance
            end
            break
        end
    end)
end))

-- BUILDERMAN ESP  — Sentry (Orange) + Dispenser (Yellow-Gold)
-- Using colours distinct from normal Player ESP and Vandalism ESP.

VisualsTab:CreateSection("Builderman ESP")

local BUILDERMAN_SENTRY_KWS: { string }    = {"sentry","sentrygun","sentry_gun","sentryturret"}
local BUILDERMAN_DISPENSER_KWS: { string } = {"dispenser","dispenser_build","builderdispenser"}

local function applyBuildermanESP(obj: Instance, v: boolean)
    local n = obj.Name:lower()
    local isSentry, isDispenser = false, false
    for _, kw in BUILDERMAN_SENTRY_KWS do
        if n:find(kw) then isSentry = true; break end
    end
    if not isSentry then
        for _, kw in BUILDERMAN_DISPENSER_KWS do
            if n:find(kw) then isDispenser = true; break end
        end
    end
    if not isSentry and not isDispenser then return end
    local target: Instance? = obj:IsA("Model") and obj
        or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent:IsA("Model") and obj.Parent)
        or (obj:IsA("BasePart") and obj)
    if not target then return end
    removeESP(target, "BuilderESP_Hl")
    if not v then return end
    local hl = Instance.new("Highlight")
    hl.Name             = "BuilderESP_Hl"
    -- Sentry  = Deep Orange  (distinct from Player ESP greens/reds and Vandalism cyan)
    -- Dispenser = Yellow-Gold (warm, easy to tell apart from Sentry)
    hl.FillColor        = isSentry and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(255, 210, 0)
    hl.OutlineColor     = isSentry and Color3.fromRGB(255, 180, 80) or Color3.fromRGB(255, 240, 120)
    hl.FillTransparency = 0.3
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = target
end

VisualsTab:CreateToggle({
    Name="Builderman ESP (Orange=Sentry / Gold=Dispenser)", CurrentValue=false, Flag="BuildermanESP",
    Callback=function(v: boolean)
        flags.buildermanESP = v
        safeCall(function()
            for _, obj in workspace:GetDescendants() do
                applyBuildermanESP(obj, v)
            end
        end)
        notify("Builderman ESP",
            v and "Sentry=Orange | Dispenser=Gold — tracking Builderman builds!" or "Disabled.", 3)
    end,
})

AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
    if not flags.buildermanESP then return end
    task.wait(0.1)
    safeCall(function() applyBuildermanESP(obj, true) end)
end))

VisualsTab:CreateLabel("🟠 Orange = Sentry  |  🟡 Gold = Dispenser")

-- ELLIOT PIZZA ESP  — Pizza Throw skill (Hot Pink)

VisualsTab:CreateSection("Elliot ESP")

local ELLIOT_PIZZA_KWS: { string } = {
    "pizza","pizzaslice","pizza_slice","pizzathrow","pizza_throw",
    "elliotpizza","elliot_pizza","healingpizza","healing_pizza","throwpizza"
}

local function applyElliotPizzaESP(obj: Instance, v: boolean)
    local n = obj.Name:lower()
    local matched = false
    for _, kw in ELLIOT_PIZZA_KWS do
        if n:find(kw) then matched = true; break end
    end
    if not matched then return end
    local target: Instance? = obj:IsA("Model") and obj
        or (obj:IsA("BasePart") and obj.Parent ~= workspace and obj.Parent:IsA("Model") and obj.Parent)
        or (obj:IsA("BasePart") and obj)
    if not target then return end
    removeESP(target, "PizzaESP_Hl")
    if not v then return end
    local hl = Instance.new("Highlight")
    hl.Name             = "PizzaESP_Hl"
    hl.FillColor        = Color3.fromRGB(255, 80, 180)
    hl.OutlineColor     = Color3.fromRGB(255, 180, 230)
    hl.FillTransparency = 0.25
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = target
end

VisualsTab:CreateToggle({
    Name="Elliot Pizza Throw ESP (Hot Pink)", CurrentValue=false, Flag="ElliotPizzaESP",
    Callback=function(v: boolean)
        flags.elliotPizzaESP = v
        safeCall(function()
            for _, obj in workspace:GetDescendants() do
                applyElliotPizzaESP(obj, v)
            end
        end)
        notify("Elliot Pizza ESP",
            v and "Pizza Throw projectiles highlighted in Hot Pink!" or "Disabled.", 3)
    end,
})

AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
    if not flags.elliotPizzaESP then return end
    task.wait(0.05)
    safeCall(function() applyElliotPizzaESP(obj, true) end)
end))

VisualsTab:CreateLabel("🩷 Hot Pink = Elliot's Pizza Throw (heals allies on contact)")

-- VEERONICA ESP  — VANDALISM skill (Cyan)
-- Vandalism spawns a dark black zone at any position and any
-- rotation. We set hl.Adornee to the actual BasePart so the
-- Highlight follows the part's exact CFrame at any angle.

VisualsTab:CreateSection("Veeronica ESP")

local VEERONICA_VANDALISM_KWS: { string } = {
    "vandalism",
    "veeronica",
    "veeronicaspray","veeronica_spray","veeronicazone","veeronica_zone",
    "vandalismzone","vandalism_zone","vandalismarea","vandalism_area",
    "vandalismpart","vandalism_part","vandalismhitbox","vandalism_hitbox",
    "vandalismeffect","vandalism_effect","vandalismspray","vandalism_spray",
    "vandalismcloud","vandalism_cloud","vandalismpool","vandalism_pool",
    "spraytag","spray_tag","sprayzone","spray_zone",
    "graffititag","graffiti_tag","graffiti",
    "paintzone","paint_zone","paintcloud","paint_cloud",
    "staminazone","stamina_zone","staminapool","stamina_pool",
}

-- Returns (adornee BasePart, container Instance).
-- Adornee is always a BasePart so Highlight tracks any CFrame.
-- Container is where we parent Highlight and BillboardGui.
local function resolveVandalismAdornee(obj: Instance): (BasePart?, Instance?)
    if obj:IsA("BasePart") then
        return obj :: BasePart, obj
    end
    if obj:IsA("Model") then
        local root: BasePart? = (obj :: Model).PrimaryPart
            or obj:FindFirstChild("HumanoidRootPart") :: BasePart?
            or obj:FindFirstChildWhichIsA("BasePart") :: BasePart?
        if not root then
            for _, d in obj:GetDescendants() do
                if d:IsA("BasePart") then root = d :: BasePart; break end
            end
        end
        return root, obj
    end
    return nil, nil
end

local function applyVeeronicaVandalismESP(obj: Instance, v: boolean)
    local n = obj.Name:lower()
    local matched = false
    for _, kw in VEERONICA_VANDALISM_KWS do
        if n:find(kw) then matched = true; break end
    end
    if not matched then return end

    local adornee, container = resolveVandalismAdornee(obj)
    if not adornee or not container then return end

    local existHl = container:FindFirstChild("VandalismESP_Hl")
    local existBB = container:FindFirstChild("VandalismESP_BB")
    if existHl then existHl:Destroy() end
    if existBB then existBB:Destroy() end
    if not v then return end

    -- Adornee makes the Highlight conform to the part's exact rotated CFrame
    local hl = Instance.new("Highlight")
    hl.Name                = "VandalismESP_Hl"
    hl.Adornee             = adornee
    hl.FillColor           = Color3.fromRGB(0, 230, 255)
    hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency    = 0.15
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = container

    -- BillboardGui always faces the camera regardless of zone rotation
    local bb = Instance.new("BillboardGui")
    bb.Name        = "VandalismESP_BB"
    bb.Adornee     = adornee
    bb.Size        = UDim2.new(0, 110, 0, 22)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 80
    bb.Parent      = container
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "VANDALISM"
    lbl.TextColor3             = Color3.fromRGB(0, 230, 255)
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Parent                 = bb

    -- Auto-cleanup the moment the zone is removed
    container.AncestryChanged:Connect(function()
        if not container.Parent then
            pcall(function() hl:Destroy() end)
            pcall(function() bb:Destroy() end)
        end
    end)
end

local function removeVeeronicaESPAll()
    for _, obj in workspace:GetDescendants() do
        local hl = obj:FindFirstChild("VandalismESP_Hl")
        local bb = obj:FindFirstChild("VandalismESP_BB")
        if hl then hl:Destroy() end
        if bb then bb:Destroy() end
    end
end

VisualsTab:CreateToggle({
    Name="Veeronica Vandalism ESP (Cyan)", CurrentValue=false, Flag="VeeronicaSprayESP",
    Callback=function(v: boolean)
        flags.veeronicaSprayESP = v
        if not v then
            safeCall(removeVeeronicaESPAll)
            notify("Veeronica Vandalism ESP", "Disabled.", 3)
            return
        end
        safeCall(function()
            for _, obj in workspace:GetDescendants() do
                applyVeeronicaVandalismESP(obj, true)
            end
        end)
        notify("Veeronica Vandalism ESP", "VANDALISM tracked — any position, any rotation!", 3)
    end,
})

AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
    if not flags.veeronicaSprayESP then return end
    task.wait(0.03)
    safeCall(function() applyVeeronicaVandalismESP(obj, true) end)
end))

VisualsTab:CreateLabel("🩵 Cyan = Veeronica VANDALISM — Adornee tracks any position & rotation")

-- All workspace ESPs rely on DescendantAdded hooks (event-driven, zero polling cost).
-- No periodic GetDescendants loop needed.

VisualsTab:CreateSection("Lighting")

local origLighting = {
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    FogStart       = Lighting.FogStart,
    GlobalShadows  = Lighting.GlobalShadows,
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

VisualsTab:CreateToggle({
    Name="Full Bright (Anti-Darkness)", CurrentValue=false, Flag="FullBright",
    Callback=function(v: boolean)
        flags.fullBright = v
        safeCall(function()
            if v then
                Lighting.Brightness     = 10
                Lighting.ClockTime      = 14
                Lighting.FogEnd         = 100000
                Lighting.GlobalShadows  = false
                Lighting.Ambient        = Color3.fromRGB(255,255,255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
                for _, fx in Lighting:GetChildren() do
                    if fx:IsA("ColorCorrectionEffect") or fx:IsA("BlurEffect") or fx:IsA("DepthOfFieldEffect") then
                        (fx :: ColorCorrectionEffect).Enabled = false
                    end
                end
            else
                Lighting.Brightness     = origLighting.Brightness
                Lighting.ClockTime      = origLighting.ClockTime
                Lighting.FogEnd         = origLighting.FogEnd
                Lighting.GlobalShadows  = origLighting.GlobalShadows
                Lighting.Ambient        = origLighting.Ambient
                Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
                for _, fx in Lighting:GetChildren() do
                    if fx:IsA("ColorCorrectionEffect") or fx:IsA("BlurEffect") or fx:IsA("DepthOfFieldEffect") then
                        (fx :: ColorCorrectionEffect).Enabled = true
                    end
                end
            end
        end)
        notify("Full Bright", v and "Map lit up!" or "Lighting restored.", 3)
    end,
})

VisualsTab:CreateToggle({
    Name="Remove Fog", CurrentValue=false, Flag="RemoveFog",
    Callback=function(v: boolean)
        flags.removeFog = v
        safeCall(function()
            Lighting.FogEnd   = v and 100000 or origLighting.FogEnd
            Lighting.FogStart = v and 100000 or origLighting.FogStart
            local atmo = Lighting:FindFirstChildOfClass("Atmosphere") :: Atmosphere?
            if atmo then
                atmo.Density = v and 0 or 0.395
                atmo.Haze    = v and 0 or atmo.Haze
                atmo.Glare   = v and 0 or atmo.Glare
            end
        end)
        notify("Fog", v and "Fog removed!" or "Fog restored.", 3)
    end,
})

-- TAB 2 ► SURVIVORS
local SurvivorTab = Window:CreateTab("Survivors", 4483362458)

SurvivorTab:CreateSection("Survival Tools")

local noclipConn: Connection? = nil
SurvivorTab:CreateToggle({
    Name="Noclip (Wall Phase)", CurrentValue=false, Flag="Noclip",
    Callback=function(v: boolean)
        flags.noclipping = v
        if v then
            noclipConn = RunService.Stepped:Connect(function()
                if not flags.noclipping then
                    noclipConn:Disconnect(); noclipConn = nil; return
                end
                safeCall(function()
                    local c = getChar()
                    if not c then return end
                    for _, p in c:GetDescendants() do
                        if p:IsA("BasePart") then (p :: BasePart).CanCollide = false end
                    end
                end)
            end)
            AddConn(noclipConn)
        end
        notify("Noclip", v and "Wall phase active!" or "Disabled.", 3)
    end,
})

-- character's base speed (from the sprint module) and enforces it every frame,
local antiSlownessConn: Connection? = nil
SurvivorTab:CreateToggle({
    Name="Disable Slowness Modifier", CurrentValue=false, Flag="AntiSlowness",
    Callback=function(v: boolean)
        if antiSlownessConn then
            antiSlownessConn:Disconnect()
            antiSlownessConn = nil
        end
        if not v then notify("Anti-Slowness", "Disabled.", 3); return end

        local _aslFrame = 0
        antiSlownessConn = RunService.Heartbeat:Connect(function()
            _aslFrame += 1
            if _aslFrame % 6 ~= 0 then return end
            safeCall(function()
                local hum = getHumanoid()
                if not hum then return end
                local baseSpeed: number = 12
                local m = getSprintModule()
                if m then
                    baseSpeed = m.WalkSpeed or m.BaseSpeed or baseSpeed
                end
                if speedEnabled then
                    baseSpeed = currentWalkSpeed
                end
                if hum.WalkSpeed < baseSpeed - 0.5 then
                    hum.WalkSpeed = baseSpeed
                end
            end)
        end)
        AddConn(antiSlownessConn)
        notify("Anti-Slowness",
            "Slowness modifier disabled — WalkSpeed enforced every frame.", 4)
    end,
})

SurvivorTab:CreateSection("Generator Puzzle Auto-Solver")

local genFlowSolverEnabled: boolean = false
local genFlowNodeDelay: number      = 0.04
local genFlowLineDelay: number      = 0.60
local genPuzzleUI: ScreenGui?       = nil

local function genRefreshPuzzleUI()
    genPuzzleUI = LocalPlayer.PlayerGui:FindFirstChild("PuzzleUI") :: ScreenGui?
end

local function genGetDirection(cr: number, cc: number, or2: number, oc: number): string
    if     or2 < cr then return "up"
    elseif or2 > cr then return "down"
    elseif oc < cc  then return "left"
    else                 return "right"
    end
end

type Node = { row: number, col: number }

local function genGetConnections(prev: Node?, curr: Node, nxt: Node?): { [string]: boolean }
    local conn: { [string]: boolean } = {}
    if prev and curr then
        local d = genGetDirection(curr.row, curr.col, prev.row, prev.col)
        if     d == "up"    then d = "down"
        elseif d == "down"  then d = "up"
        elseif d == "left"  then d = "right"
        else                     d = "left"
        end
        conn[d] = true
    end
    if nxt and curr then
        local d = genGetDirection(curr.row, curr.col, nxt.row, nxt.col)
        if d then conn[d] = true end
    end
    return conn
end

local function genIsNeighbour(r1: number, c1: number, r2: number, c2: number): string | boolean
    if r2 == r1-1 and c2 == c1 then return "up" end
    if r2 == r1+1 and c2 == c1 then return "down" end
    if r2 == r1 and c2 == c1-1 then return "left" end
    if r2 == r1 and c2 == c1+1 then return "right" end
    return false
end

local function genCoordKey(n: Node): string return `{n.row}-{n.col}` end

local function genOrderPath(path: { Node }, endpoints: { Node }?): { Node }
    if not path or #path == 0 then return path end
    local inPath: { [string]: Node } = {}
    for _, n in path do inPath[genCoordKey(n)] = n end

    local startNode: Node?
    for _, ep in endpoints or {} do
        for _, n in path do
            if n.row == ep.row and n.col == ep.col then
                startNode = {row=ep.row, col=ep.col}; break
            end
        end
        if startNode then break end
    end

    if not startNode then
        for _, n in path do
            local neighbors = 0
            for _, d in {{-1,0},{1,0},{0,-1},{0,1}} do
                if inPath[`{n.row+d[1]}-{n.col+d[2]}`] then neighbors += 1 end
            end
            if neighbors == 1 then startNode = {row=n.row, col=n.col}; break end
        end
    end

    if not startNode then startNode = {row=path[1].row, col=path[1].col} end

    local remaining: { [string]: Node } = {}
    local ordered: { Node } = {}
    for _, n in path do remaining[genCoordKey(n)] = {row=n.row, col=n.col} end

    local current = startNode :: Node
    table.insert(ordered, {row=current.row, col=current.col})
    remaining[genCoordKey(current)] = nil

    while next(remaining) do
        local found = false
        for key, node in remaining do
            if genIsNeighbour(current.row, current.col, node.row, node.col) then
                table.insert(ordered, {row=node.row, col=node.col})
                remaining[key] = nil; current = node; found = true; break
            end
        end
        if not found then break end
    end
    return ordered
end

local function genDrawSolution(puzzle: any)
    if not puzzle or not puzzle.Solution then return end
    local indices: { number } = {}
    for i = 1, #puzzle.Solution do table.insert(indices, i) end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for _, colorIndex in indices do
        local path      = puzzle.Solution[colorIndex]
        local endpoints = puzzle.targetPairs[colorIndex]
        local ordered   = genOrderPath(path, endpoints)
        puzzle.paths[colorIndex] = {}
        for i, node in ordered do
            table.insert(puzzle.paths[colorIndex], {row=node.row, col=node.col})
            local conn = genGetConnections(ordered[i-1], node, ordered[i+1])
            puzzle.gridConnections = puzzle.gridConnections or {}
            puzzle.gridConnections[genCoordKey(node)] = conn
            pcall(function() puzzle:updateGui() end)
            task.wait(genFlowNodeDelay)
        end
        task.wait(genFlowLineDelay)
        pcall(function() puzzle:checkForWin() end)
    end
end

local genFlowModule: ModuleScript? = nil
local _gs, _gm = pcall(function()
    return game:GetService("ReplicatedStorage").Modules.Misc.FlowGameManager.FlowGame
end)
if _gs and _gm then genFlowModule = _gm end

if genFlowModule then
    local FlowGame = require(genFlowModule :: ModuleScript)
    local oldNew   = FlowGame.new
    FlowGame.new   = function(...)
        local puzzle = oldNew(...)
        if genFlowSolverEnabled then
            task.spawn(function()
                task.wait(0.3)
                if puzzle and puzzle.Solution then
                    genDrawSolution(puzzle)
                end
            end)
        end
        return puzzle
    end
end

AddConn(LocalPlayer.PlayerGui.ChildAdded:Connect(function(c: Instance)
    if c.Name == "PuzzleUI" then genRefreshPuzzleUI() end
end))
AddConn(LocalPlayer.PlayerGui.ChildRemoved:Connect(function()
    genPuzzleUI = nil
end))
genRefreshPuzzleUI()

SurvivorTab:CreateToggle({
    Name="Auto-Solve Generator Puzzles", CurrentValue=false, Flag="AutoGen",
    Callback=function(v: boolean)
        flags.autoGen        = v
        genFlowSolverEnabled = v
        if v and not genFlowModule then
            notify("Auto Gen", "FlowGame module not found! Inject during a round.", 5)
        else
            notify("Auto Gen", v and "Solver ON! Walk to a gen and start the puzzle." or "Disabled.", 4)
        end
    end,
})

SurvivorTab:CreateSlider({
    Name="Node Draw Speed", Range={0.01,0.50}, Increment=0.01, CurrentValue=0.04, Suffix="s", Flag="GenNodeSpeed",
    Callback=function(v: number) genFlowNodeDelay = v end,
})

SurvivorTab:CreateSlider({
    Name="Delay Between Color Lines", Range={0.00,1.00}, Increment=0.01, CurrentValue=0.60, Suffix="s", Flag="GenLineDelay",
    Callback=function(v: number) genFlowLineDelay = v end,
})

SurvivorTab:CreateButton({
    Name="Check Generator Module Status",
    Callback=function()
        if genFlowModule then notify("Generator", "FlowGame module FOUND — solver ready!", 4)
        else notify("Generator", "FlowGame module NOT found. Try injecting mid-round.", 4) end
    end,
})

SurvivorTab:CreateButton({
    Name="Teleport to Nearest Generator",
    Callback=function()
        safeCall(function()
            local hrp = getHRP(); if not hrp then return end
            local nearest: BasePart?  = nil
            local nearestDist: number = math.huge
            for _, obj in workspace:GetDescendants() do
                local n = obj.Name:lower()
                if not (n:find("generator") or n:find("gen")) or not obj:IsA("Model") then continue end
                local part = (obj :: Model).PrimaryPart or obj:FindFirstChildOfClass("BasePart") :: BasePart?
                if not part then continue end
                local d = (hrp.Position - part.Position).Magnitude
                if d < nearestDist then nearest = part; nearestDist = d end
            end
            if nearest then
                hrp.CFrame = CFrame.new(nearest.Position + Vector3.new(0,5,0))
                notify("Generator", "Teleported! 4 puzzles = -12sec!", 3)
            else
                notify("Generator", "No generator found.", 3)
            end
        end)
    end,
})

-- TAB 3 ► KILLER
local KillerTab = Window:CreateTab("Killer", 4483362458)

KillerTab:CreateSection("Kill Utilities")

KillerTab:CreateButton({
    Name="Teleport to Nearest Survivor",
    Callback=function()
        safeCall(function()
            local hrp = getHRP(); if not hrp then return end
            local nearest: BasePart? = nil
            local nearestDist: number = math.huge
            for _, p in Players:GetPlayers() do
                if p == LocalPlayer then continue end
                local c = p.Character
                local oHRP = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                if not oHRP then continue end
                local d = (hrp.Position - oHRP.Position).Magnitude
                if d < nearestDist then nearest = oHRP; nearestDist = d end
            end
            if nearest then
                hrp.CFrame = CFrame.new(nearest.Position + Vector3.new(0,4,-3))
                notify("Kill +35s", "Teleported! Kill = +35sec on timer!", 3)
            else
                notify("Killer", "No survivors found.", 3)
            end
        end)
    end,
})

KillerTab:CreateButton({
    Name="Destroy Nearby Survivor Traps & Builds",
    Callback=function()
        safeCall(function()
            local hrp = getHRP(); if not hrp then return end
            local count = 0
            local kws = {"trap","sentry","dispenser","shadow","pizza","turret","bot","mine","barrier","plasma","tripwire","tripmine","wire","clone"}
            for _, obj in workspace:GetDescendants() do
                local n = obj.Name:lower()
                for _, kw in kws do
                    if not n:find(kw) then continue end
                    local part = (obj:IsA("BasePart") and obj :: BasePart)
                        or (obj:IsA("Model") and ((obj :: Model).PrimaryPart or obj:FindFirstChildOfClass("BasePart") :: BasePart?))
                    if part and (hrp.Position - (part :: BasePart).Position).Magnitude < 35 then
                        safeCall(function() obj:Destroy() end); count += 1
                    end
                    break
                end
            end
            notify("Cleared", `{count} trap(s) destroyed!`, 3)
        end)
    end,
})

KillerTab:CreateSection("Killer ESP")

local function applyKillerESPToChar(p: Player, c: Model)
    if not flags.killerESP then return end
    if p == LocalPlayer or not c or not c.Parent then return end
    local existing = c:FindFirstChild("KillerESP_Hl") :: Highlight?
    if existing and existing:IsA("Highlight") and existing.Parent then return end
    removeESP(c, "KillerESP_Hl")
    local hl = Instance.new("Highlight")
    hl.Name="KillerESP_Hl"; hl.FillColor=Color3.fromRGB(255,30,30)
    hl.OutlineColor=Color3.fromRGB(255,255,255); hl.FillTransparency=0.4
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=c
end

local killerESPCharConns: { [Player]: Connection } = {}
local killerESPPlayerAddedConn: Connection? = nil

local function hookKillerESPChar(p: Player)
    if killerESPCharConns[p] then
        pcall(function() killerESPCharConns[p]:Disconnect() end)
        killerESPCharConns[p] = nil
    end
    if p.Character then applyKillerESPToChar(p, p.Character) end
    killerESPCharConns[p] = p.CharacterAdded:Connect(function(c: Model)
        task.wait(0.5)
        applyKillerESPToChar(p, c)
    end)
end

KillerTab:CreateToggle({
    Name="Survivor Aura Reveal (404 Error)", CurrentValue=false, Flag="KillerESP",
    Callback=function(v: boolean)
        flags.killerESP = v
        if not v then
            for _, p in Players:GetPlayers() do
                local c = p.Character
                if c then removeESP(c, "KillerESP_Hl") end
            end
            for p, conn in killerESPCharConns do
                pcall(function() conn:Disconnect() end)
            end
            killerESPCharConns = {}
            if killerESPPlayerAddedConn then
                pcall(function() killerESPPlayerAddedConn:Disconnect() end)
                killerESPPlayerAddedConn = nil
            end
            notify("Aura Reveal", "Disabled.", 3)
            return
        end
        for _, p in Players:GetPlayers() do
            hookKillerESPChar(p)
        end
        killerESPPlayerAddedConn = Players.PlayerAdded:Connect(function(p: Player)
            if not flags.killerESP then return end
            hookKillerESPChar(p)
        end)
        AddConn(killerESPPlayerAddedConn)
        notify("Aura Reveal", "All survivors visible!", 3)
    end,
})

-- Lightweight rescan every 10s — players list only, not workspace
task.spawn(function()
    while true do
        task.wait(10)
        if not flags.killerESP then continue end
        pcall(function()
            for _, p in Players:GetPlayers() do
                if p == LocalPlayer then continue end
                local c = p.Character
                if not c then continue end
                if not c:FindFirstChild("KillerESP_Hl") then
                    applyKillerESPToChar(p, c)
                end
            end
        end)
    end
end)

-- TAB 4 ► STAMINA
local StaminaTab = Window:CreateTab("Stamina", 4483362458)


local SprintModule: any = nil
local function getSprintModule(): any
    if SprintModule then return SprintModule end
    safeCall(function()
        SprintModule = require(
            game.ReplicatedStorage.Systems.Character.Game.Sprinting :: ModuleScript
        )
    end)
    return SprintModule
end

-- speed state lives further down, defined before the sliders use it

-- Re-apply speed and stamina on every respawn
AddConn(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if flags.infStamina then
        local m = getSprintModule()
        if m then m.StaminaLossDisabled = true end
    end
end))

-- Infinite Stamina
StaminaTab:CreateSection("Infinite Stamina")

StaminaTab:CreateToggle({
    Name="Infinite Stamina", CurrentValue=false, Flag="InfiniteStamina",
    Callback=function(v: boolean)
        flags.infStamina = v
        safeCall(function()
            local m = getSprintModule()
            if m then
                m.StaminaLossDisabled = v
                notify("Infinite Stamina",
                    v and "No stamina drain — runs forever!" or "Stamina restored.", 4)
            else
                notify("Infinite Stamina",
                    "Sprint module not found. Try injecting mid-round.", 4)
            end
        end)
    end,
})

StaminaTab:CreateLabel("Survivor: drains within 85 studs of Killer | Drain: 10/s | Regen: 20/s")
StaminaTab:CreateLabel("Killer: drains when running | Lockout at 0: 2 seconds")

-- Stamina Overhead Display
-- Simulates the real stamina value locally using Forsaken's documented rates.
-- This means the display shows the actual drain/regen cycle even when Infinite
-- Stamina is on (the module suppresses drain but we simulate it here so you
-- can see what your stamina would be without cheating, useful for timing).
--
-- Killer:   max=110, drain=9.5/s, regen=21/s
-- Survivor: max=100, drain=10/s,  regen=20/s
StaminaTab:CreateSection("Stamina Overhead Display")

local staminaBB:   any         = nil
local staminaLbl:  any         = nil
local staminaConn: Connection? = nil

-- Simulated stamina state
local simStamina:     number  = 100
local simLastTick:    number  = 0
local simInitialised: boolean = false

local STAMINA_KILLER   = { max = 110, drain = 9.5,  regen = 21 }
local STAMINA_SURVIVOR = { max = 100, drain = 10,   regen = 20 }

local function getStaminaStats(): { max: number, drain: number, regen: number }
    local kf: Instance? = nil
    pcall(function() kf = workspace.Players.Killers end)
    if kf then
        for _, m in (kf :: Instance):GetChildren() do
            if Players:GetPlayerFromCharacter(m) == LocalPlayer then
                return STAMINA_KILLER
            end
        end
    end
    return STAMINA_SURVIVOR
end

local function isCurrentlySprinting(): boolean
    local char = LocalPlayer.Character
    local hum  = char and (char :: Model):FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    -- Sprinting = moving faster than walk speed baseline
    return hum.MoveDirection.Magnitude > 0.01 and hum.WalkSpeed > 14
end

local function buildStaminaBillboard()
    local char = LocalPlayer.Character
    local hrp  = char and (char :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    local old = char and (char :: Model):FindFirstChild("XenonZ_StaBB")
    if old then old:Destroy() end
    local bb = Instance.new("BillboardGui")
    bb.Name        = "XenonZ_StaBB"
    bb.Adornee     = hrp
    bb.Size        = UDim2.new(0, 130, 0, 18)
    bb.StudsOffset = Vector3.new(0, 3.8, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Parent      = char :: Model
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextSize               = 10
    lbl.TextScaled             = false
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextColor3             = Color3.fromRGB(80, 220, 255)
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.3
    lbl.Text                   = "STA: --"
    lbl.Parent                 = bb
    staminaBB  = bb
    staminaLbl = lbl
end

local function startStaminaDisplay()
    if staminaConn then staminaConn:Disconnect(); staminaConn = nil end
    buildStaminaBillboard()
    simInitialised = false
    local _frame = 0
    staminaConn = RunService.Heartbeat:Connect(function(dt: number)
        _frame += 1
        if _frame % 4 ~= 0 then return end
        if not staminaBB or not staminaBB.Parent then
            buildStaminaBillboard(); return
        end
        if not staminaLbl then return end

        local stats = getStaminaStats()

        -- Initialise sim from the sprint module's current value if available
        if not simInitialised then
            local m = getSprintModule()
            local v = m and (m.Stamina or m.CurrentStamina or m.StaminaValue)
            simStamina     = (type(v) == "number" and math.clamp(v, 0, stats.max)) or stats.max
            simInitialised = true
            simLastTick    = tick()
        end

        -- Advance simulation using elapsed real time (dt * 4 since we run every 4 frames)
        local elapsed = tick() - simLastTick
        simLastTick   = tick()

        if isCurrentlySprinting() then
            simStamina = math.max(0, simStamina - stats.drain * elapsed)
        else
            simStamina = math.min(stats.max, simStamina + stats.regen * elapsed)
        end

        -- Display
        local display = math.floor(simStamina)
        local pct     = simStamina / stats.max
        local colour: Color3
        if pct >= 0.7 then
            colour = Color3.fromRGB(80, 255, 120)
        elseif pct >= 0.3 then
            colour = Color3.fromRGB(255, 220, 60)
        else
            colour = Color3.fromRGB(255, 80, 80)
        end

        staminaLbl.TextColor3 = colour
        if flags.infStamina then
            staminaLbl.Text = `STA: {display}/{stats.max} ∞`
        else
            staminaLbl.Text = `STA: {display}/{stats.max}`
        end
    end)
end

local function stopStaminaDisplay()
    if staminaConn then staminaConn:Disconnect(); staminaConn = nil end
    local char = LocalPlayer.Character
    if char then
        local bb = (char :: Model):FindFirstChild("XenonZ_StaBB")
        if bb then bb:Destroy() end
    end
    staminaBB  = nil
    staminaLbl = nil
end

StaminaTab:CreateToggle({
    Name="Show Stamina Above Head", CurrentValue=false, Flag="StaminaDisplay",
    Callback=function(v: boolean)
        if v then
            startStaminaDisplay()
            AddConn(LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                if staminaConn then
                    simInitialised = false
                    buildStaminaBillboard()
                end
            end))
            notify("Stamina Display", "Simulating real drain/regen above head.", 3)
        else
            stopStaminaDisplay()
            notify("Stamina Display", "Hidden.", 2)
        end
    end,
})

StaminaTab:CreateLabel("Green = high | Yellow = mid | Red = low")
StaminaTab:CreateLabel("∞ shown when Infinite Stamina is ON — drain still simulated")
StaminaTab:CreateLabel("Killer: 9.5 drain / 21 regen / 110 max")
StaminaTab:CreateLabel("Survivor: 10 drain / 20 regen / 100 max")

-- FE Speed Hack
StaminaTab:CreateSection("Speed (FE — Hitbox Follows)")

-- Separate walk and run speed state
local currentWalkSpeed: number = 12
local currentRunSpeed: number  = 26
local speedEnabled: boolean    = false

-- CHARACTER SPEED PRESETS — exact values per character
type SpeedPreset = { walk: number, run: number }
local SPEED_PRESETS: { [string]: SpeedPreset } = {
    ["Survivor (Default)"]  = { walk = 12,   run = 26    },
    ["1x1x1x1"]             = { walk = 8,    run = 27    },
    ["John Doe"]             = { walk = 9,    run = 27.25 },
    ["Slasher"]              = { walk = 9,    run = 28    },
    ["c00lkidd"]             = { walk = 8,    run = 28    },
    ["Guest 666"]            = { walk = 9,    run = 27    },
    ["Nosferatu"]            = { walk = 7.5,  run = 27.5  },
    ["Noli"]                 = { walk = 8,    run = 27    },
}

-- walkspeed loop, runs every frame so game cant override it
-- A one-shot set loses the race. The fix is to win every frame by
-- re-writing WalkSpeed inside a Heartbeat loop for the full duration.
-- The sprint module fields are also overridden each tick so neither
-- path can restore the original value.

local speedHeartbeatConn: Connection? = nil

local function startSpeedLoop()
    if speedHeartbeatConn then return end  -- already running
    local _spFrame = 0
    speedHeartbeatConn = RunService.Heartbeat:Connect(function()
        _spFrame += 1
        if _spFrame % 3 ~= 0 then return end
        if not speedEnabled then return end
        pcall(function()
            local hum = getHumanoid()
            if hum then
                if hum.WalkSpeed ~= currentWalkSpeed then
                    hum.WalkSpeed = currentWalkSpeed
                end
            end
            local m = getSprintModule()
            if m then
                if m.WalkSpeed   ~= nil and m.WalkSpeed   ~= currentWalkSpeed then m.WalkSpeed   = currentWalkSpeed end
                if m.RunSpeed    ~= nil and m.RunSpeed    ~= currentRunSpeed  then m.RunSpeed    = currentRunSpeed  end
                if m.SprintSpeed ~= nil and m.SprintSpeed ~= currentRunSpeed  then m.SprintSpeed = currentRunSpeed  end
                if m.BaseSpeed   ~= nil and m.BaseSpeed   ~= currentWalkSpeed then m.BaseSpeed   = currentWalkSpeed end
            end
        end)
    end)
    AddConn(speedHeartbeatConn)
end

local function stopSpeedLoop()
    if speedHeartbeatConn then
        speedHeartbeatConn:Disconnect()
        speedHeartbeatConn = nil
    end
end

-- One-shot apply still used for instant feedback on toggle/slider change
local function applySpeed(walk: number, run: number)
    currentWalkSpeed = walk
    currentRunSpeed  = run
    safeCall(function()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = walk end
        local m = getSprintModule()
        if m then
            if m.WalkSpeed   ~= nil then m.WalkSpeed   = walk end
            if m.RunSpeed    ~= nil then m.RunSpeed    = run  end
            if m.SprintSpeed ~= nil then m.SprintSpeed = run  end
            if m.BaseSpeed   ~= nil then m.BaseSpeed   = walk end
        end
    end)
end

local function resetSpeed()
    stopSpeedLoop()
    safeCall(function()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 12 end
        local m = getSprintModule()
        if m then
            if m.WalkSpeed   ~= nil then m.WalkSpeed   = 12 end
            if m.RunSpeed    ~= nil then m.RunSpeed    = 26 end
            if m.SprintSpeed ~= nil then m.SprintSpeed = 26 end
            if m.BaseSpeed   ~= nil then m.BaseSpeed   = 12 end
        end
    end)
end

-- reapply speed after dying
AddConn(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if speedEnabled then
        applySpeed(currentWalkSpeed, currentRunSpeed)
        startSpeedLoop()
    end
    if flags.infStamina then
        local m = getSprintModule()
        if m then m.StaminaLossDisabled = true end
    end
end))

StaminaTab:CreateToggle({
    Name="Enable Speed Hack", CurrentValue=false, Flag="SpeedHackEnabled",
    Callback=function(v: boolean)
        speedEnabled = v
        if v then
            applySpeed(currentWalkSpeed, currentRunSpeed)
            startSpeedLoop()
            notify("Speed", `Walk: {currentWalkSpeed} | Run: {currentRunSpeed} — enforced every frame`, 3)
        else
            resetSpeed()
            notify("Speed", "Speed reset to default.", 3)
        end
    end,
})
StaminaTab:CreateDropdown({
    Name="Character Speed Preset",
    Options={
        "Survivor (Default)",
        "1x1x1x1",
        "John Doe",
        "Slasher",
        "c00lkidd",
        "Guest 666",
        "Nosferatu",
        "Noli",
    },
    CurrentOption={"Survivor (Default)"},
    Flag="SpeedPreset",
    Callback=function(selected: { string })
        local preset = SPEED_PRESETS[selected[1]]
        if not preset then return end
        currentWalkSpeed = preset.walk
        currentRunSpeed  = preset.run
        if speedEnabled then applySpeed(currentWalkSpeed, currentRunSpeed) end
        notify("Speed Preset",
            `{selected[1]} — Walk: {preset.walk} | Run: {preset.run} studs/s`, 4)
    end,
})
StaminaTab:CreateSlider({
    Name="Walk Speed",
    Range={7, 30},
    Increment=0.25,
    CurrentValue=12,
    Suffix=" studs/s",
    Flag="WalkSpeedValue",
    Callback=function(v: number)
        currentWalkSpeed = v
        if speedEnabled then applySpeed(currentWalkSpeed, currentRunSpeed) end
    end,
})
StaminaTab:CreateSlider({
    Name="Run / Sprint Speed",
    Range={20, 60},
    Increment=0.25,
    CurrentValue=26,
    Suffix=" studs/s",
    Flag="RunSpeedValue",
    Callback=function(v: number)
        currentRunSpeed = v
        if speedEnabled then applySpeed(currentWalkSpeed, currentRunSpeed) end
    end,
})
StaminaTab:CreateSection("Speed Reference")
StaminaTab:CreateLabel("Survivor        Walk: 12  |  Run: 26")
StaminaTab:CreateLabel("1x1x1x1         Walk: 8   |  Run: 27")
StaminaTab:CreateLabel("John Doe        Walk: 9   |  Run: 27.25")
StaminaTab:CreateLabel("Slasher         Walk: 9   |  Run: 28")
StaminaTab:CreateLabel("c00lkidd        Walk: 8   |  Run: 28")
StaminaTab:CreateLabel("Guest 666       Walk: 9   |  Run: 27")
StaminaTab:CreateLabel("Nosferatu       Walk: 7.5  | Run: 27.5")
StaminaTab:CreateLabel("Noli            Walk: 8    | Run: 27")

-- TAB 5 ► CHARACTERS
local CharTab = Window:CreateTab("Characters", 4483362458)

CharTab:CreateSection("Survivalist")

CharTab:CreateDropdown({
    Name="Survivalist Guide",
    Options={
        "Noob — Survivalist (Free)",
        "007n7 — Survivalist",
        "Veeronica — Survivalist",
        "Jane Doe — Survivalist (Unlockable)",
    },
    CurrentOption={"Noob — Survivalist (Free)"}, Flag="SurvivorGuide_Survivalist",
    Callback=function(selected: { string })
        local info: { [string]: string } = {
            ["Noob — Survivalist (Free)"]
                = "Walk: 12 | Run: 26. Slateskin Potion = now Level 3 status (buffed from L2). Only 20% speed reduction while drinking (down from 40%). Ghostburger also only 20% reduction. Cola stacking nerf removed. Best starter.",
            ["007n7 — Survivalist"]
                = "Walk: 12 | Run: 26. Deploy Clone to bait killer. GUI Teleport = emergency escape. Mix movements so killer cannot track which is real.",
            ["Veeronica — Survivalist"]
                = "Walk: 12 | Run: 26. VANDALISM restores stamina on contact. Only survivor with self-damage ability. Strong stamina advantage near timer end.",
            ["Jane Doe — Survivalist (Unlockable)"]
                = "Walk: 12 | Run: 26. Unlocked by completing Jane Doe's quests in the Basement. Passive: Silence — The Spectre blacks out her face from John Doe's vision so he can attack her. Support/Sentinel playstyle. Wife of John Doe. Added in Update 4.0.0.",
        }
        notify(selected[1], info[selected[1]] or "No info.", 7)
    end,
})
CharTab:CreateSection("Sentinel")

CharTab:CreateDropdown({
    Name="Sentinel Guide",
    Options={
        "Guest 1337 — Sentinel",
        "Chance — Sentinel",
        "Two Time — Sentinel",
        "Shedletsky — Sentinel",
    },
    CurrentOption={"Guest 1337 — Sentinel"}, Flag="SurvivorGuide_Sentinel",
    Callback=function(selected: { string })
        local info: { [string]: string } = {
            ["Guest 1337 — Sentinel"]
                = "Walk: 12 | Run: 26. 115 HP — highest base HP in the game. Body-block for teammates. Stun killer to protect gen repairs. Hardest to kill.",
            ["Chance — Sentinel"]
                = "Walk: 12 | Run: 26. Model updated in 4.0.0. Reroll HP at start (50–130 range). One Shot gun has RNG outcome. High risk high reward — can one-tap or miss entirely.",
            ["Two Time — Sentinel"]
                = "Walk: 12 | Run: 26. Model updated in 4.0.0. 80 HP first life → 40 HP second life → 110 HP on LMS. Use first life aggressively. Save charge for LMS stage.",
            ["Shedletsky — Sentinel"]
                = "Walk: 12 | Run: 26. Admin sword creates distance and stuns. Strong gen runner. Stun killer to protect teammates during repairs.",
        }
        notify(selected[1], info[selected[1]] or "No info.", 7)
    end,
})
CharTab:CreateSection("Support")

CharTab:CreateDropdown({
    Name="Support Guide",
    Options={
        "Taph — Support",
        "Elliot — Support",
        "Builderman — Support",
        "Dusekkar — Support",
    },
    CurrentOption={"Elliot — Support"}, Flag="SurvivorGuide_Support",
    Callback=function(selected: { string })
        local info: { [string]: string } = {
            ["Taph — Support"]
                = "Walk: 12 | Run: 26. Tripmine stacking status duration cut increased to 0.85s (from 0.5s). Tripwire now stays at Slowness L2 regardless of multiple Taphs alive + stacking cut also 0.85s. Stack traps near gens for maximum slowdown.",
            ["Elliot — Support"]
                = "Walk: 12 | Run: 26. Pizza Throw heals teammates from range. Passively sees crit-hit allies. Stay at mid-distance — never rush the killer.",
            ["Builderman — Support"]
                = "Walk: 12 | Run: 26. Sentry damages and slows killer. Dispenser heals team passively. Cannot build through walls — positioning is everything.",
            ["Dusekkar — Support"]
                = "Walk: 12 | Run: 26. Plasma Beam damages and slows the killer. Protection shield absorbs incoming damage for a teammate. Overheal buffed to 30 HP (up from 20). Run Plasma first to zone, then shield whoever is being chased.",
        }
        notify(selected[1], info[selected[1]] or "No info.", 7)
    end,
})
CharTab:CreateSection("Killer Guide")

CharTab:CreateDropdown({
    Name="Killer Character Guide",
    Options={
        "Slasher — B-Tier Rushdown (Free) Sprint:28","c00lkidd — S-Tier Rushdown Sprint:28",
        "John Doe — S-Tier Zoner","1x1x1x1 — A-Tier Zoner",
        "Guest 666 — C-Tier Ambusher","Nosferatu — B-Tier Ambusher","Noli — B-Tier Ambusher",
    },
    CurrentOption={"Slasher — B-Tier Rushdown (Free) Sprint:28"}, Flag="KillerGuide",
    Callback=function(selected: { string })
        local info: { [string]: string } = {
            ["Slasher — B-Tier Rushdown (Free) Sprint:28"] = "Walk: 9 | Run: 28. Slash=Bleeding, Behead=Helpless. Behead no longer self-slows if it kills. Guest 1337 can no longer block Gashing Wound grabs beyond the initial hit. Kill fast = +35sec each.",
            ["c00lkidd — S-Tier Rushdown Sprint:28"]       = "Walk: 8 | Run: 28. Corrupt Nature tag first. Pizza Bots zone gens. Walkspeed Override in corridors.",
            ["John Doe — S-Tier Zoner"]                    = "Walk: 9 | Run: 27.25. Unstoppable now reduces interrupted ability cooldown by 50% when triggered. Malevolence trail damages. Corrupt Energy spikes block loops. Digital Footprint = Slowness II. 404 Error reveals all auras.",
            ["1x1x1x1 — A-Tier Zoner"]                     = "Walk: 8 | Run: 27. Dual slash = Poison + Glitch. Mass Infection pierces groups. Entanglement roots. Rejuvenate the Rotten speed boost duration reduced to 8s (from 10s). Unstable Eye tracks all.",
            ["Guest 666 — C-Tier Ambusher"]                = "Walk: 9 | Run: 27. Manic Fixation out-of-chase boost reduced to 15% (from 20%). Blood Hunt initial cost increased to 200 blood (from 150). Possession redirects survivor movement. Hard countered by looping.",
            ["Nosferatu — B-Tier Ambusher"]                = "Walk: 7.5 | Run: 27.5. Walkspeed buffed to 7.5 (from 7.25). Hunter's Feast invisibility level increased to 5 (from 4) but now ends immediately on any ability use. Ascension = surprise drop-in. First NPC killer.",
            ["Noli — B-Tier Ambusher"]                     = "Walk: 8 | Run: 27. Walkspeed buffed to 8 (from 7.75). Void Rush = gap close. Hallucination = fake generators. Nova = ranged poke. Observant for repositioning.",
        }
        notify(selected[1], info[selected[1]] or "No info.", 8)
    end,
})

-- auto block

-- REMOTE
local testRemote: RemoteEvent? = nil
pcall(function()
    testRemote = game:GetService("ReplicatedStorage")
        :WaitForChild("Modules", 10)
        :WaitForChild("Network", 10)
        :WaitForChild("RemoteEvent", 10) :: RemoteEvent
end)

local function makeBuffer(str: string): buffer | string
    local ok, result = pcall(function() return buffer.fromstring(str) end)
    return ok and result or str
end

local BUFFERS = {
    Block  = makeBuffer("\3\5\0\0\0Block"),
    Punch  = makeBuffer("\3\5\0\0\0Punch"),
    Charge = makeBuffer("\3\5\0\0\0Charge"),
    Clone  = makeBuffer("\3\5\0\0\0Clone"),
}

-- Cached remote with fallback scan
local _cachedRemote: RemoteEvent? = nil
local function getAbilityRemote(): RemoteEvent?
    if _cachedRemote and _cachedRemote.Parent then return _cachedRemote end
    pcall(function()
        local net = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
            and game:GetService("ReplicatedStorage").Modules:FindFirstChild("Network")
        if net then
            for _, c in net:GetChildren() do
                if c:IsA("RemoteEvent") then _cachedRemote = c :: RemoteEvent; return end
            end
        end
        _cachedRemote = testRemote
    end)
    return _cachedRemote
end

-- forward declarations so fireAbility and doFire can reference both tables
-- before their do-blocks fill them in
local Aimbot    = {}
local SilentAim = { snap = function() end, snapAuto = function() end }  -- stub

local function fireAbility(t: string)
    local rem = getAbilityRemote(); if not rem then return end
    local buf = BUFFERS[t] or BUFFERS.Block
    pcall(function() SilentAim.snapAuto() end)    -- snap HRP BEFORE the remote fires
    pcall(function() rem:FireServer("UseActorAbility", {[1] = buf}) end)
    pcall(function() rem:FireServer(t) end)
    pcall(function() Aimbot.onSkillStart() end)
    task.delay(0.7, function()
        pcall(function() Aimbot.onSkillEnd() end)
    end)
end

-- SETTINGS STATE
local AB: { [string]: any } = {
    -- Sound Block
    autoBlockAudioOn   = false,
    detectionRange     = 18,
    blockdelay         = 0,
    facingCheckEnabled = false,
    doubleblocktech    = true,
    autoblocktype      = "Block",
    abMissChance       = 0,
    -- HDT
    hitboxDraggingTech = false,
    Dspeed             = 12,
    Ddelay             = 0,
    rotateDelay        = 0,
    hdtMissChance      = 0,
    hdtMode            = "180_TURN",
    -- RCT
    rctEnabled         = false,
    rctFlickDir        = "Right",
    rctFlickAngle      = 120,
    rctFlickDelay      = 0.08,
    rctFlickSpeed      = 0.06,
    rctAutoLedge       = false,
    rctMissChance      = 0,
    -- Aim Punch / Lock
    characterLockOn    = false,
    lockMaxDistance    = 30,
    predictionValue    = 4,
    aimWindow          = 0.7,
    -- Auto Punch
    autoPunchOn        = false,
}

-- CONSTANTS
local CONE_DOT: number = 0.70
local KILLER_NAMES: { string }  = {"c00lkidd","Jason","JohnDoe","1x1x1x1","Noli","Slasher","Sixer"}
local BAIT_KILLERS: { string }  = {"John Doe","Slasher","c00lkidd","Jason","1x1x1x1","Noli","Sixer","Nosferatu"}
local BLOCK_CD: number          = 0.1
local HDT_CD: number            = 0.5
local RCT_CD: number            = 10
local AIM_PUNCH_FRAME_GAP: number = 10

local PUNCH_ANIM_SET: { [string]: boolean } = {}
local BLOCK_ANIM_SET: { [string]: boolean }  = {}
do
    for _, v in {
        "87259391926321","140703210927645","136007065400978","129843313690921",
        "86709774283672","108807732150251","138040001965654","86096387000557",
    } do PUNCH_ANIM_SET[v] = true end
    for _, v in {
        "72722244508749","96959123077498","95802026624883","100926346851492","120748030255574",
    } do BLOCK_ANIM_SET[v] = true end
end

local TRIGGER_SOUNDS: { [string]: boolean } = {
    ["102228729296384"]=true,["140242176732868"]=true,["112809109188560"]=true,
    ["136323728355613"]=true,["115026634746636"]=true,["84116622032112"]=true,
    ["108907358619313"]=true,["127793641088496"]=true,["86174610237192"]=true,
    ["95079963655241"]=true,["101199185291628"]=true,["119942598489800"]=true,
    ["84307400688050"]=true,["113037804008732"]=true,["105200830849301"]=true,
    ["75330693422988"]=true,["82221759983649"]=true,["81702359653578"]=true,
    ["108610718831698"]=true,["112395455254818"]=true,["109431876587852"]=true,
    ["109348678063422"]=true,["85853080745515"]=true,["12222216"]=true,
    ["105840448036441"]=true,["114742322778642"]=true,["119583605486352"]=true,
    ["79980897195554"]=true,["71805956520207"]=true,["79391273191671"]=true,
    ["89004992452376"]=true,["101553872555606"]=true,["101698569375359"]=true,
    ["106300477136129"]=true,["116581754553533"]=true,["117231507259853"]=true,
    ["119089145505438"]=true,["121954639447247"]=true,["125213046326879"]=true,
    ["131406927389838"]=true,["117173212095661"]=true,["71834552297085"]=true,
    ["805165833096"]=true,["80516583309685"]=true,["76959687420003"]=true,
    ["107444859834748"]=true,["86833981571073"]=true,["110372418055226"]=true,
    ["86494585504534"]=true,["121369993837377"]=true,["132331977491979"]=true,
    ["18782451032"]=true,["80587845277702"]=true,["94317217837143"]=true,
    ["136728245733659"]=true,["104910828105172"]=true,["98111231282218"]=true,
    ["71310583817000"]=true,["124903763333174"]=true,["72425554233832"]=true,
    ["131123355704017"]=true,["128856426573270"]=true,["128195973631079"]=true,
    ["128367348686124"]=true,["105204810054381"]=true,["98675142200448"]=true,
    ["106836941416453"]=true,
    -- new from fY5irusV.txt
    ["100592913030351"]=true,["100926346851492"]=true,["103684883268194"]=true,
    ["104625283622511"]=true,["105316545074913"]=true,["106158168476059"]=true,
    ["107339108383093"]=true,["107345261604889"]=true,["108651070773439"]=true,
    ["108807732150251"]=true,["109246041199659"]=true,["113651119049553"]=true,
    ["114506382930939"]=true,["114620047310688"]=true,["116527305931161"]=true,
    ["118493324723683"]=true,["119181003138006"]=true,["120059928759346"]=true,
    ["120748030255574"]=true,["121808371053483"]=true,["124397369810639"]=true,
    ["126131675979001"]=true,["127172483138092"]=true,["127557531826290"]=true,
    ["129843313690921"]=true,["136007065400978"]=true,["138040001965654"]=true,
    ["139523195429581"]=true,["139996647355899"]=true,["140194172008986"]=true,
    ["140412278320643"]=true,["140703210927645"]=true,["18473547358"]=true,
    ["72722244508749"]=true,["74842815979546"]=true,["76467993976301"]=true,
    ["78298577002481"]=true,["80540530406270"]=true,["81935774508746"]=true,
    ["82336352305186"]=true,["84069821282466"]=true,["84353899757208"]=true,
    ["85544168523099"]=true,["86096387000557"]=true,["86709774283672"]=true,
    ["87259391926321"]=true,["93366464803829"]=true,["93432652624003"]=true,
    ["95802026624883"]=true,["96594507550917"]=true,["96959123077498"]=true,
    ["99050723653468"]=true,["99829427721752"]=true,
    -- Noli (captured from NarratorNoli + Milestone100Noli)
    ["85082460915086"]=true,["71859647134376"]=true,["77907043310586"]=true,
    ["73725929447486"]=true,["89315669689903"]=true,["75227733554331"]=true,
    ["116736732174423"]=true,["113510808639647"]=true,["102491594132079"]=true,
    ["105484443350662"]=true,["85810983952228"]=true,["70522191793442"]=true,
    ["107347032614322"]=true,["106727013904874"]=true,["82260342194598"]=true,
}

-- SHARED HELPERS
local cachedAnimator: Animator? = nil

local function abGetNearestKiller(): Model?
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not myRoot then return nil end
    local kf: Folder? = nil
    pcall(function() kf = workspace.Players.Killers :: Folder end)
    if not kf then return nil end
    local best: Model?  = nil
    local bestD: number = math.huge
    for _, k in kf:GetChildren() do
        local hrp = k:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then continue end
        local d = (hrp.Position - myRoot.Position).Magnitude
        if d < bestD then best = k :: Model; bestD = d end
    end
    return best
end

local function abRefreshAnimator()
    local char = LocalPlayer.Character
    if not char then cachedAnimator = nil; return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    cachedAnimator = hum and hum:FindFirstChildOfClass("Animator") :: Animator? or nil
end

local function rollMiss(chance: number): boolean
    if chance <= 0 then return false end
    if chance >= 100 then return true end
    return math.random(1, 100) <= chance
end

-- Facing check — 45° cone check.
-- Checks whether the LOCAL PLAYER (survivor) is inside the killer's 45° forward cone.
-- A 45° half-angle means the killer must be roughly facing us to trigger.
-- cos(45°) = 0.707. We use 0.70 to add a tiny buffer.
local CONE_DOT: number = 0.70  -- cos(45°) — increases to tighten cone, decrease to widen

local function isInKillerCone(myRoot: BasePart, killerRoot: BasePart, killerName: string?): boolean
    if not AB.facingCheckEnabled then return true end
    if not myRoot or not killerRoot then return false end
    -- Direction FROM killer TO survivor
    local diff = myRoot.Position - killerRoot.Position
    if diff.Magnitude < 0.01 then return true end
    -- Dot between killer's look vector and the direction to survivor.
    -- > CONE_DOT means survivor is within the forward 45° cone.
    local dot = killerRoot.CFrame.LookVector:Dot(diff.Unit)
    -- Bait-aware: sidestep killers (John Doe, Slasher, etc.) often swing while strafing.
    -- We tighten the cone slightly and also reject if the killer is moving sideways.
    local isBait = false
    if killerName then
        for _, n in BAIT_KILLERS do
            if killerName:find(n) then isBait = true; break end
        end
    end
    if isBait then
        local vel = Vector3.zero
        pcall(function() vel = killerRoot.AssemblyLinearVelocity end)
        if vel.Magnitude < 0.01 then pcall(function() vel = (killerRoot :: any).Velocity end) end
        local side = math.abs(vel:Dot(killerRoot.CFrame.RightVector))
        if side > 3 then return false end  -- killer moving sideways — likely a fake
        return dot > CONE_DOT + 0.05      -- tighter cone for bait killers
    end
    return dot > CONE_DOT
end

-- sound block, .Played events are main trigger, tick scan is fallback
-- Registers every sound in the Killers folder regardless of ID.
-- ID check happens at fire time so late-loading SoundIds are never missed.
-- Both sound.Played events AND tick-scan are active simultaneously.
local SoundBlock = {}
do
    local trackedSounds: { [Sound]: { Connection } } = {}
    local blockedUntil:  { [Sound]: number }         = {}

    -- Extracts numeric ID from rbxassetid:// or plain number strings
    local function extractId(sound: Sound): string?
        if not sound or not sound.SoundId then return nil end
        return tostring(sound.SoundId):match("%d+")
    end

    -- Resolves the BasePart a sound is associated with.
    -- Handles: sound → BasePart, sound → Attachment → BasePart,
    --          sound → Model (takes PrimaryPart or first BasePart),
    --          sound → any ancestor BasePart as last resort.
    local function getSoundPart(sound: Sound): BasePart?
        local p = sound.Parent
        if not p then return nil end
        if p:IsA("BasePart") then return p :: BasePart end
        if p:IsA("Attachment") then
            local pp = p.Parent
            if pp and pp:IsA("BasePart") then return pp :: BasePart end
        end
        if p:IsA("Model") then
            local m = p :: Model
            if m.PrimaryPart then return m.PrimaryPart end
            local bp = m:FindFirstChildWhichIsA("BasePart")
            if bp then return bp :: BasePart end
        end
        -- Last resort: walk up the ancestor chain for any BasePart
        local anc = p:FindFirstAncestorOfClass("BasePart")
        if anc then return anc :: BasePart end
        return nil
    end

    local function getCharFromPart(part: BasePart): Model?
        local m = part:FindFirstAncestorOfClass("Model")
        return (m and m:FindFirstChildOfClass("Humanoid")) and m :: Model or nil
    end

    
    local function tryBlock(sound: Sound)
        if not AB.autoBlockAudioOn then return end

        local now = tick()

        -- 100ms cooldown per sound, catches every swing in a fast combo
        if blockedUntil[sound] and now < blockedUntil[sound] then return end

        

        -- id check happens here not at register time so late SoundIds still work
        local id = extractId(sound)
        if not id or not TRIGGER_SOUNDS[id] then return end

        local myChar = LocalPlayer.Character; if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not myRoot then return end

        local part = getSoundPart(sound)
        -- Fallback: if part not found, try to resolve from the sound's full ancestor chain
        if not part then
            local anc = sound:FindFirstAncestorWhichIsA("BasePart")
            if anc then part = anc :: BasePart end
        end
        if not part then return end

        local char = getCharFromPart(part)
        -- Fallback: check if the sound is anywhere inside a killer model directly
        if not char then
            local kf: Folder? = nil
            pcall(function() kf = workspace.Players.Killers :: Folder end)
            if kf then
                for _, k in kf:GetChildren() do
                    if sound:IsDescendantOf(k) then
                        char = k :: Model; break
                    end
                end
            end
        end
        if not char then return end

        local plr = Players:GetPlayerFromCharacter(char)
        if not plr or plr == LocalPlayer then return end

        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end
        if (hrp.Position - myRoot.Position).Magnitude > AB.detectionRange then return end
        if not isInKillerCone(myRoot, hrp, char.Name) then return end
        if rollMiss(AB.abMissChance) then return end

        -- Lock this specific sound for 100ms (tight response window)
        blockedUntil[sound] = now + 0.1

        local function doFire()
            -- snap toward target before firing if silent aim is active for this ability type
            local killerModel = char :: Model
            local killerName  = killerModel.Name:lower()
            if killerName:find("noli") then
                pcall(function() SilentAim.snap("NoliNova") end)
            elseif killerName:find("c00lkidd") or killerName:find("coolkidd") then
                pcall(function() SilentAim.snap("CorruptNature") end)
            elseif killerName:find("dusekkar") then
                pcall(function() SilentAim.snap("PlasmaBeam") end)
            elseif killerName:find("nosferatu") then
                pcall(function() SilentAim.snap("HuntersFeast") end)
            elseif killerName:find("1x1x1x1") or killerName:find("1x1") then
                pcall(function() SilentAim.snap("CrystalPitch") end)
            end
            if AB.autoblocktype == "Block" then
                fireAbility("Block")
                if AB.doubleblocktech then fireAbility("Punch") end
            elseif AB.autoblocktype == "Charge" then
                fireAbility("Charge")
            elseif AB.autoblocktype == "7n7 Clone" then
                fireAbility("Clone")
            end
        end
        if AB.blockdelay > 0 then task.delay(AB.blockdelay, doFire) else doFire() end
    end

    -- tick scan backup, catches sounds that were mid-play when registered
    function SoundBlock.tick()
        if not AB.autoBlockAudioOn then return end
        for sound in trackedSounds do
            if not sound or not sound.Parent then
                -- Sound was destroyed — clean up
                if trackedSounds[sound] then
                    for _, c in trackedSounds[sound] do pcall(function() c:Disconnect() end) end
                end
                trackedSounds[sound] = nil
                blockedUntil[sound]  = nil
            elseif sound.IsPlaying then
                tryBlock(sound)
            end
        end
    end

    
    -- register every sound now, check ID later when it actually fires
    local function registerSound(sound: Sound)
        if not sound or not sound:IsA("Sound") then return end
        if trackedSounds[sound] then return end

        -- Primary: .Played event — fires the instant the sound starts
        local c1 = sound.Played:Connect(function()
            tryBlock(sound)
        end)
        -- Secondary: IsPlaying property change — catches resume/restart
        local c2 = sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
            if sound.IsPlaying then tryBlock(sound) end
        end)
        -- Tertiary: TimePosition change — catches very short sounds that start
        -- and finish before .Played is delivered. TimePosition fires every frame
        -- the sound is playing, so this is the most sensitive trigger.
        local c4 = sound:GetPropertyChangedSignal("TimePosition"):Connect(function()
            if sound.IsPlaying then tryBlock(sound) end
        end)
        -- Cleanup on destroy
        local c3 = sound.Destroying:Connect(function()
            if trackedSounds[sound] then
                for _, c in trackedSounds[sound] do pcall(function() c:Disconnect() end) end
            end
            trackedSounds[sound] = nil
            blockedUntil[sound]  = nil
        end)

        trackedSounds[sound] = {c1, c2, c3, c4}

        if sound.IsPlaying then tryBlock(sound) end
    end

    -- Scans the Killers folder for every sound — no ID filtering at this stage.
    -- Safe to call repeatedly: connections are only established once per folder instance.
    local setupDone: { [Instance]: boolean } = {}

    function SoundBlock.setup()
        local kf: Folder? = nil
        pcall(function() kf = workspace.Players.Killers :: Folder end)
        if not kf then return end

        -- Register all existing sounds
        for _, d in (kf :: Instance):GetDescendants() do
            if d:IsA("Sound") then registerSound(d :: Sound) end
        end

        -- Only attach DescendantAdded/ChildAdded once per folder instance.
        -- On repeated setup() calls (rescan loop) skip if already hooked.
        if setupDone[kf :: Instance] then return end
        setupDone[kf :: Instance] = true

        -- Register sounds added later mid-round (e.g. ability audio spawned dynamically)
        ;(kf :: Instance).DescendantAdded:Connect(function(d: Instance)
            task.wait(0.02) -- let SoundId be assigned before hooking
            if d:IsA("Sound") then registerSound(d :: Sound) end
        end)

        -- Re-register when a new killer character loads into the folder
        ;(kf :: Instance).ChildAdded:Connect(function(child: Instance)
            task.wait(0.3)
            for _, d in (child :: Instance):GetDescendants() do
                if d:IsA("Sound") then registerSound(d :: Sound) end
            end
        end)
    end

    -- Re-setup when the Killers folder itself is recreated (map/round reload)
    AddConn(workspace.DescendantAdded:Connect(function(obj: Instance)
        if obj.Name == "Killers" and AB.autoBlockAudioOn then
            task.wait(0.5)
            pcall(SoundBlock.setup)
        end
    end))

    -- Periodic rescan every 5s (tightened from 8s) to catch anything missed
    task.spawn(function()
        while true do
            task.wait(5)
            if AB.autoBlockAudioOn then
                pcall(SoundBlock.setup)
            end
        end
    end)
end

-- HDT, hooks AnimationPlayed on the block animation
local HDT = {}
do
    local _debounce: boolean  = false
    local _lastTime: number   = 0
    local _hdtConn: Connection? = nil

    local function doPattern(hrp: BasePart)
        local mode = AB.hdtMode
        if mode == "180_TURN" then
            hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position - hrp.CFrame.LookVector)
        elseif mode == "LEFT_SPIN" then
            for _ = 1, 5 do hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(36), 0); task.wait(0.02) end
        elseif mode == "RIGHT_SPIN" then
            for _ = 1, 5 do hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(-36), 0); task.wait(0.02) end
        end
    end

    local function startChargeAim(fallback: number?)
        fallback = fallback or 1.2
        local sw   = tick()
        local hum  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hum then hum.AutoRotate = false end
        while tick() - sw < fallback do
            pcall(function()
                local nk = abGetNearestKiller()
                if nk and root then
                    local tHRP = nk:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if tHRP then
                        if AB.rotateDelay > 0 then task.wait(AB.rotateDelay) end
                        root.CFrame = CFrame.lookAt(root.Position, tHRP.Position)
                    end
                end
            end)
            task.wait()
        end
        if hum then hum.AutoRotate = true end
    end

    local function beginDrag(killerModel: Model)
        if _debounce then return end
        if not killerModel or not killerModel.Parent then return end
        local char = LocalPlayer.Character; if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local tHRP = killerModel:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not tHRP then return end
        _debounce = true
        local oldW = hum.WalkSpeed; hum.WalkSpeed = 0
        pcall(doPattern, hrp)
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5,0,1e5); bv.Velocity = Vector3.zero; bv.Parent = hrp
        local conn: Connection
        conn = RunService.Heartbeat:Connect(function()
            if not _debounce then
                conn:Disconnect()
                if bv and bv.Parent then bv:Destroy() end
                hum.WalkSpeed = oldW; return
            end
            if not (char and char.Parent) or not (killerModel and killerModel.Parent) then
                _debounce = false; return
            end
            local curTHRP = killerModel:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not curTHRP then _debounce = false; return end
            local to = curTHRP.Position - hrp.Position
            local h2 = Vector3.new(to.X, 0, to.Z)
            bv.Velocity = h2.Magnitude > 0.01 and h2.Unit * AB.Dspeed or Vector3.zero
            if to.Magnitude <= 2.0 then _debounce = false end
        end)
        task.delay(0.4, function() _debounce = false end)
    end

    local function onBlockAnimPlayed(track: AnimationTrack)
        pcall(function()
            if not AB.hitboxDraggingTech or _debounce then return end
            local now = tick(); if now - _lastTime < HDT_CD then return end
            local id = tostring(track.Animation and track.Animation.AnimationId or ""):match("%d+")
            if not id or not BLOCK_ANIM_SET[id] then return end
            if rollMiss(AB.hdtMissChance) then return end
            _lastTime = now
            local nearest = abGetNearestKiller(); if not nearest then return end
            task.spawn(function()
                if AB.Ddelay > 0 then task.wait(AB.Ddelay) end
                beginDrag(nearest)
                startChargeAim(0.4)
            end)
        end)
    end

    function HDT.setup(anim: Animator)
        if _hdtConn then _hdtConn:Disconnect() end
        if not anim then return end
        _hdtConn = anim.AnimationPlayed:Connect(onBlockAnimPlayed)
    end
end

-- RCT, fires Charge then body flick with optional ledge snap
local RCT = {}
do
    local _debounce: boolean   = false
    local _lastCharge: number  = 0

    local RCT_SCAN_DIRS: { Vector3 } = {
        Vector3.new(1,0,0), Vector3.new(-1,0,0),
        Vector3.new(0,0,1), Vector3.new(0,0,-1),
        Vector3.new(1,0,1).Unit, Vector3.new(-1,0,1).Unit,
        Vector3.new(1,0,-1).Unit, Vector3.new(-1,0,-1).Unit,
    }

    local function findLedgeAngle(killerHRP: BasePart): number?
        local bestDir: Vector3? = nil
        local bestDrop: number  = 4
        local origin = killerHRP.Position + Vector3.new(0,0.5,0)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        pcall(function() rp.FilterDescendantsInstances = {killerHRP.Parent} end)
        for _, dir in RCT_SCAN_DIRS do
            local result = workspace:Raycast(origin + dir*3, Vector3.new(0,-10,0), rp)
            local floorY = result and result.Position.Y or (origin.Y - 10)
            local drop   = origin.Y - floorY
            if drop > bestDrop then bestDrop = drop; bestDir = dir end
        end
        if not bestDir then return nil end
        return math.atan2(-bestDir.X, -bestDir.Z)
    end

    local function doFlick()
        if _debounce then return end
        if rollMiss(AB.rctMissChance) then return end
        _debounce = true
        task.spawn(function()
            pcall(function()
                task.wait(AB.rctFlickDelay)
                local char = LocalPlayer.Character; if not char then _debounce = false; return end
                local hrp  = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if not hrp then _debounce = false; return end
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local base = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
                local target: number
                if AB.rctAutoLedge then
                    local km   = abGetNearestKiller()
                    local khrp = km and km:FindFirstChild("HumanoidRootPart") :: BasePart?
                    target = (khrp and findLedgeAngle(khrp)) or base
                else
                    local rad = math.rad(AB.rctFlickAngle)
                    if     AB.rctFlickDir == "Right" then target = base - rad
                    elseif AB.rctFlickDir == "Left"  then target = base + rad
                    elseif AB.rctFlickDir == "Back"  then target = base + math.pi
                    else                                   target = base - rad
                    end
                end
                local elapsed, dt = 0, 0.016
                if hum then hum.AutoRotate = false end
                while elapsed < AB.rctFlickSpeed do
                    pcall(function()
                        local t = math.min(elapsed / AB.rctFlickSpeed, 1)
                        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, base + (target-base)*t, 0)
                    end)
                    elapsed += dt; task.wait(dt)
                end
                pcall(function() hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, target, 0) end)
                if hum then hum.AutoRotate = true end
            end)
            _debounce = false
        end)
    end

    function RCT.fire()
        local now = tick()
        if now - _lastCharge < RCT_CD then
            notify("RCT", `Cooldown: {math.ceil(RCT_CD - (now - _lastCharge))}s remaining`, 2)
            return
        end
        _lastCharge = now
        fireAbility("Charge")
        doFlick()
    end
end

-- aim punch, rotates ur char toward killer when they swing
local function startAimPunch()
    pcall(function()
        if not AB.characterLockOn then return end
        local myChar = LocalPlayer.Character; if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart") :: BasePart?; if not myRoot then return end
        local kf: Folder? = nil
        pcall(function() kf = workspace.Players.Killers :: Folder end)
        if not kf then return end
        local nearest: Model? = nil
        local nDist: number   = math.huge
        for _, killer in kf:GetChildren() do
            local hrp = killer:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then
                local d = (hrp.Position - myRoot.Position).Magnitude
                if d <= AB.lockMaxDistance and d < nDist then nDist = d; nearest = killer :: Model end
            end
        end
        if not nearest then return end
        local tHRP = nearest:FindFirstChild("HumanoidRootPart") :: BasePart?; if not tHRP then return end
        local hum  = myChar:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = false end
        task.spawn(function()
            local st = tick()
            while tick() - st < AB.aimWindow do
                pcall(function()
                    local c = LocalPlayer.Character
                    local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if not r or not tHRP or not tHRP.Parent then return end
                    local vel = tHRP.Velocity or Vector3.zero
                    local pd  = vel.Magnitude > 0.5 and vel.Unit or tHRP.CFrame.LookVector
                    if pd ~= pd then pd = Vector3.zero end
                    r.CFrame = CFrame.lookAt(r.Position,
                        tHRP.Position + pd * AB.predictionValue + vel * 0.1)
                end)
                task.wait()
            end
            local c = LocalPlayer.Character
            if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.AutoRotate = true end end
        end)
    end)
end

-- HEARTBEAT LOOP
do
    local frame: number           = 0
    local lastAimPunchFrame: number = 0

    AddConn(RunService.Heartbeat:Connect(function()
        frame += 1

        -- Sound block tick — throttled to every 3 frames to reduce CPU cost.
        -- The primary trigger is still the .Played event (immediate, zero lag).
        -- Tick-scan is only a backup for sounds that were already playing.
        if frame % 3 == 0 then
            SoundBlock.tick()
        end

        -- Aim Punch — triggers on killer punch animation
        if AB.characterLockOn and cachedAnimator
            and (frame - lastAimPunchFrame) >= AIM_PUNCH_FRAME_GAP then
            pcall(function()
                for _, track in cachedAnimator:GetPlayingAnimationTracks() do
                    local id = tostring(track.Animation and track.Animation.AnimationId or ""):match("%d+")
                    if id and PUNCH_ANIM_SET[id] then
                        lastAimPunchFrame = frame
                        task.spawn(startAimPunch)
                        break
                    end
                end
            end)
        end

        -- Auto Punch — fires Punch when killer ≤10 studs (every 2 frames)
        if AB.autoPunchOn and frame % 2 == 0 then
            pcall(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                if not myRoot then return end
                local kf: Folder? = nil
                pcall(function() kf = workspace.Players.Killers :: Folder end)
                if not kf then return end
                for _, name in KILLER_NAMES do
                    local killer = kf:FindFirstChild(name)
                    if not killer then continue end
                    local r = killer:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if r and (r.Position - myRoot.Position).Magnitude <= 10 then
                        fireAbility("Punch"); break
                    end
                end
            end)
        end
    end))
end

-- INIT
task.spawn(function()
    if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
    task.wait(1)
    abRefreshAnimator()
    if cachedAnimator then HDT.setup(cachedAnimator) end
    task.spawn(SoundBlock.setup)
end)

AddConn(LocalPlayer.CharacterAdded:Connect(function(char: Model)
    task.wait(0.5)
    abRefreshAnimator()
    if cachedAnimator then HDT.setup(cachedAnimator) end
    task.spawn(SoundBlock.setup)
    -- Re-hook HDT when animator is fully ready
    task.spawn(function()
        local hum  = char:WaitForChild("Humanoid", 5) :: Humanoid?
        if not hum then return end
        local anim = hum:WaitForChild("Animator", 5) :: Animator?
        if anim then cachedAnimator = anim; HDT.setup(anim) end
    end)
end))

-- AUTO BLOCK TAB UI
local AutoBlockTab = Window:CreateTab("Auto Block (WIP)", 4483362458)

-- Auto Block
AutoBlockTab:CreateSection("Auto Block")

AutoBlockTab:CreateToggle({
    Name="Auto Block (Audio)", CurrentValue=false, Flag="AB_AutoBlock",
    Callback=function(v: boolean)
        AB.autoBlockAudioOn = v
        if v then task.spawn(SoundBlock.setup) end
        notify("Auto Block", v and "Listening for killer punch sounds!" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateDropdown({
    Name="Block Type", Options={"Block","Charge","7n7 Clone"}, CurrentOption={"Block"}, Flag="AB_BlockType",
    Callback=function(v: { string }) AB.autoblocktype = v[1] end,
})

AutoBlockTab:CreateSlider({
    Name="Block Delay", Range={0,0.5}, Increment=0.01, CurrentValue=0, Suffix="s", Flag="AB_BlockDelay",
    Callback=function(v: number) AB.blockdelay = v end,
})

AutoBlockTab:CreateSlider({
    Name="Detection Range", Range={5,50}, Increment=1, CurrentValue=18, Suffix=" studs", Flag="AB_DetRange",
    Callback=function(v: number)
        AB.detectionRange = v
        -- update circle size immediately so it reflects the new range
        pcall(updateRangeCircle)
    end,
})

AutoBlockTab:CreateToggle({
    Name="Facing Check (Bait-Aware)", CurrentValue=false, Flag="AB_FacingCheck",
    Callback=function(v: boolean)
        AB.facingCheckEnabled = v
        notify("Facing Check", v and "ON — dot threshold 0.70, bait sidestep detection active" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateToggle({
    Name="Double Punch Tech", CurrentValue=true, Flag="AB_DoublePunch",
    Callback=function(v: boolean) AB.doubleblocktech = v end,
})

AutoBlockTab:CreateSlider({
    Name="Block Miss Chance", Range={0,100}, Increment=1, CurrentValue=0, Suffix="%", Flag="AB_MissChance",
    Callback=function(v: number) AB.abMissChance = v end,
})

AutoBlockTab:CreateLabel("Fires when killer punch sound is detected within range")
AutoBlockTab:CreateLabel("Facing Check blocks fakes: detects bait sidesteps via velocity")

-- Range Visualizer — filled red disc on the ground under the nearest killer
-- plus two thin lines extending forward at ±45° showing the facing-check cone.
-- When the survivor is inside the cone AND within the disc, auto-block fires.
local rangeCircleEnabled: boolean   = false
local rangeCirclePart:    Part?     = nil   -- the flat filled disc
local coneLineL:          Part?     = nil   -- left cone line at -45°
local coneLineR:          Part?     = nil   -- right cone line at +45°
local rangeCircleConn:    Connection? = nil

local function makeLinePart(colour: Color3): Part
    local p = Instance.new("Part")
    p.Anchored    = true
    p.CanCollide  = false
    p.CanQuery    = false
    p.CanTouch    = false
    p.CastShadow  = false
    p.Material    = Enum.Material.Neon
    p.Color       = colour
    p.Transparency = 0.1
    p.Size        = Vector3.new(0.15, 0.15, 1)  -- thin rod, length set each frame
    p.Parent      = workspace
    return p :: Part
end

local function buildRangeCircle(): Part
    -- Filled cylinder disc: SpecialMesh Cylinder is X-axis aligned.
    -- Size.X = thin axis (height of disc), Size.Y = Size.Z = diameter.
    -- Rotate 90° on Z to lay it flat on the ground.
    local p = Instance.new("Part")
    p.Name           = "XenonZ_RangeCircle"
    p.Anchored       = true
    p.CanCollide     = false
    p.CanQuery       = false
    p.CanTouch       = false
    p.CastShadow     = false
    p.Material       = Enum.Material.Neon
    p.Color          = Color3.fromRGB(255, 30, 30)
    p.Transparency   = 0.45
    p.Size           = Vector3.new(0.05, 2, 2)
    local mesh       = Instance.new("SpecialMesh")
    mesh.MeshType    = Enum.MeshType.Cylinder
    mesh.Parent      = p
    p.Parent         = workspace
    return p :: Part
end

local function updateRangeCircle()
    if not rangeCircleEnabled then return end
    if not rangeCirclePart then
        rangeCirclePart = buildRangeCircle()
        coneLineL = makeLinePart(Color3.fromRGB(255, 80, 80))
        coneLineR = makeLinePart(Color3.fromRGB(255, 80, 80))
    end

    local myChar = LocalPlayer.Character
    local myHRP  = myChar and (myChar :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
    if not myHRP then return end

    -- Find nearest killer
    local kf: Instance? = nil
    pcall(function() kf = workspace.Players.Killers end)
    if not kf then
        rangeCirclePart.CFrame = CFrame.new(0, -1000, 0)
        if coneLineL then coneLineL.CFrame = CFrame.new(0, -1000, 0) end
        if coneLineR then coneLineR.CFrame = CFrame.new(0, -1000, 0) end
        return
    end

    local nearestModel: Model?  = nil
    local nearestDist:  number  = math.huge
    for _, model in (kf :: Instance):GetChildren() do
        if not model:IsA("Model") then continue end
        local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then continue end
        local d = (hrp.Position - myHRP.Position).Magnitude
        if d < nearestDist then nearestDist = d; nearestModel = model :: Model end
    end

    if not nearestModel then
        rangeCirclePart.CFrame = CFrame.new(0, -1000, 0)
        if coneLineL then coneLineL.CFrame = CFrame.new(0, -1000, 0) end
        if coneLineR then coneLineR.CFrame = CFrame.new(0, -1000, 0) end
        return
    end

    local killerHRP = nearestModel:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not killerHRP then return end

    local diameter = AB.detectionRange * 2
    local floorY   = killerHRP.Position.Y - 3

    -- Disc: lay flat using 90° Z rotation
    rangeCirclePart.Size = Vector3.new(0.05, diameter, diameter)
    rangeCirclePart.CFrame = CFrame.new(killerHRP.Position.X, floorY, killerHRP.Position.Z)
        * CFrame.Angles(0, 0, math.rad(90))

    -- Colour: bright red when survivor in range, dimmer when outside
    local inRange = nearestDist <= AB.detectionRange
    rangeCirclePart.Color        = inRange and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(160, 40, 40)
    rangeCirclePart.Transparency = inRange and 0.3 or 0.6

    -- Cone lines: two thin rods at ±45° from the killer's forward direction,
    -- length = detectionRange, anchored at the killer's feet.
    -- They rotate with the killer in real time showing exactly where the
    -- facing-check cone is pointing.
    if coneLineL and coneLineR then
        local lineLen  = AB.detectionRange
        local lineSize = Vector3.new(0.12, 0.12, lineLen)
        local base     = CFrame.new(killerHRP.Position.X, floorY, killerHRP.Position.Z)
                       * CFrame.Angles(0, killerHRP.CFrame:ToObjectSpace(CFrame.new()).Y, 0)
        -- Use the killer's actual Y rotation
        local killerYaw = math.atan2(-killerHRP.CFrame.LookVector.X, -killerHRP.CFrame.LookVector.Z)
        local halfLen   = lineLen / 2

        local leftAngle  = killerYaw + math.rad(45)
        local rightAngle = killerYaw - math.rad(45)

        local function linePos(angle: number): CFrame
            local dx = math.sin(angle) * halfLen
            local dz = math.cos(angle) * halfLen
            return CFrame.new(
                killerHRP.Position.X + dx, floorY,
                killerHRP.Position.Z + dz
            ) * CFrame.Angles(0, -angle, 0)
        end

        coneLineL.Size   = lineSize
        coneLineL.CFrame = linePos(leftAngle)

        coneLineR.Size   = lineSize
        coneLineR.CFrame = linePos(rightAngle)
    end
end

local function startRangeCircle()
    if rangeCircleConn then return end
    rangeCirclePart = buildRangeCircle()
    coneLineL = makeLinePart(Color3.fromRGB(255, 80, 80))
    coneLineR = makeLinePart(Color3.fromRGB(255, 80, 80))
    local _frame = 0
    rangeCircleConn = RunService.Heartbeat:Connect(function()
        _frame += 1
        if _frame % 6 ~= 0 then return end
        pcall(updateRangeCircle)
    end)
end

local function stopRangeCircle()
    if rangeCircleConn then rangeCircleConn:Disconnect(); rangeCircleConn = nil end
    if rangeCirclePart then rangeCirclePart:Destroy(); rangeCirclePart = nil end
    if coneLineL then coneLineL:Destroy(); coneLineL = nil end
    if coneLineR then coneLineR:Destroy(); coneLineR = nil end
end

AutoBlockTab:CreateToggle({
    Name="Show Range Circle (Red Aura)", CurrentValue=false, Flag="AB_RangeCircle",
    Callback=function(v: boolean)
        rangeCircleEnabled = v
        if v then
            startRangeCircle()
            notify("Range Circle", "Red circle shows auto block detection range around nearest killer.", 3)
        else
            stopRangeCircle()
            notify("Range Circle", "Hidden.", 2)
        end
    end,
})

-- HDT — Hitbox Dragging Tech
AutoBlockTab:CreateSection("HDT — Hitbox Dragging Tech")

AutoBlockTab:CreateToggle({
    Name="Enable HDT", CurrentValue=false, Flag="AB_HDT",
    Callback=function(v: boolean)
        AB.hitboxDraggingTech = v
        notify("HDT", v and "Hitbox Dragging active!" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateDropdown({
    Name="HDT Mode", Options={"180_TURN","LEFT_SPIN","RIGHT_SPIN"}, CurrentOption={"180_TURN"}, Flag="AB_HDTMode",
    Callback=function(v: { string }) AB.hdtMode = v[1] end,
})

AutoBlockTab:CreateSlider({
    Name="Drag Speed", Range={1,30}, Increment=0.5, CurrentValue=12, Suffix=" studs/s", Flag="AB_HDTSpeed",
    Callback=function(v: number) AB.Dspeed = v end,
})

AutoBlockTab:CreateSlider({
    Name="Drag Delay", Range={0,0.5}, Increment=0.01, CurrentValue=0, Suffix="s", Flag="AB_HDTDelay",
    Callback=function(v: number) AB.Ddelay = v end,
})

AutoBlockTab:CreateSlider({
    Name="Rotate Delay", Range={0,0.5}, Increment=0.01, CurrentValue=0, Suffix="s", Flag="AB_RotateDelay",
    Callback=function(v: number) AB.rotateDelay = v end,
})

AutoBlockTab:CreateSlider({
    Name="HDT Miss Chance", Range={0,100}, Increment=1, CurrentValue=0, Suffix="%", Flag="AB_HDTMiss",
    Callback=function(v: number) AB.hdtMissChance = v end,
})

AutoBlockTab:CreateLabel("Hooks AnimationPlayed — triggers on your block animation")
AutoBlockTab:CreateLabel("180_TURN flips you instantly | SPIN modes rotate 5× over 0.1s")

-- RCT — Reverse Charge Tech
AutoBlockTab:CreateSection("RCT — Reverse Charge Tech")

AutoBlockTab:CreateToggle({
    Name="Enable RCT", CurrentValue=false, Flag="AB_RCT",
    Callback=function(v: boolean)
        AB.rctEnabled = v
        notify("RCT", v and "RCT active — use Fire button to trigger!" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateButton({
    Name="⚡ Fire Charge + Flick",
    Callback=function()
        if not AB.rctEnabled then
            notify("RCT", "Enable RCT first!", 2); return
        end
        RCT.fire()
    end,
})

AutoBlockTab:CreateDropdown({
    Name="Flick Direction", Options={"Right","Left","Back","Auto"}, CurrentOption={"Right"}, Flag="AB_RCTDir",
    Callback=function(v: { string }) AB.rctFlickDir = v[1] end,
})

AutoBlockTab:CreateToggle({
    Name="Auto Ledge (find nearest drop)", CurrentValue=false, Flag="AB_RCTLedge",
    Callback=function(v: boolean)
        AB.rctAutoLedge = v
        notify("RCT Auto Ledge", v and "Raycasting for nearest ledge!" or "Using fixed flick direction.", 3)
    end,
})

AutoBlockTab:CreateSlider({
    Name="Flick Angle", Range={45,180}, Increment=5, CurrentValue=120, Suffix="°", Flag="AB_RCTAngle",
    Callback=function(v: number) AB.rctFlickAngle = v end,
})

AutoBlockTab:CreateSlider({
    Name="Flick Delay", Range={0,0.3}, Increment=0.01, CurrentValue=0.08, Suffix="s", Flag="AB_RCTFlickDelay",
    Callback=function(v: number) AB.rctFlickDelay = v end,
})

AutoBlockTab:CreateSlider({
    Name="Flick Speed", Range={0.02,0.2}, Increment=0.01, CurrentValue=0.06, Suffix="s", Flag="AB_RCTSpeed",
    Callback=function(v: number) AB.rctFlickSpeed = v end,
})

AutoBlockTab:CreateSlider({
    Name="RCT Miss Chance", Range={0,100}, Increment=1, CurrentValue=0, Suffix="%", Flag="AB_RCTMiss",
    Callback=function(v: number) AB.rctMissChance = v end,
})

AutoBlockTab:CreateLabel("Fires Charge + rotates body in flick direction simultaneously")
AutoBlockTab:CreateLabel("Auto Ledge raycasts 8 directions to find the nearest map edge")
AutoBlockTab:CreateLabel("10s cooldown between fires")

-- Aim Punch / Character Lock
AutoBlockTab:CreateSection("Aim Punch — Character Lock")

AutoBlockTab:CreateToggle({
    Name="Character Lock (Aim Punch)", CurrentValue=false, Flag="AB_CharLock",
    Callback=function(v: boolean)
        AB.characterLockOn = v
        notify("Character Lock", v and "Aims at killer on their punch animation!" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateSlider({
    Name="Max Lock Distance", Range={5,100}, Increment=5, CurrentValue=30, Suffix=" studs", Flag="AB_LockDist",
    Callback=function(v: number) AB.lockMaxDistance = v end,
})

AutoBlockTab:CreateSlider({
    Name="Velocity Prediction", Range={0,15}, Increment=0.5, CurrentValue=4, Flag="AB_Prediction",
    Callback=function(v: number) AB.predictionValue = v end,
})

AutoBlockTab:CreateSlider({
    Name="Aim Window", Range={0.1,2}, Increment=0.1, CurrentValue=0.7, Suffix="s", Flag="AB_AimWindow",
    Callback=function(v: number) AB.aimWindow = v end,
})

AutoBlockTab:CreateLabel("Triggers when killer's punch animation is detected")
AutoBlockTab:CreateLabel("Leads moving killers using velocity × prediction value")

-- Auto Punch
AutoBlockTab:CreateSection("Auto Punch")

AutoBlockTab:CreateToggle({
    Name="Auto Punch (killer ≤10 studs)", CurrentValue=false, Flag="AB_AutoPunch",
    Callback=function(v: boolean)
        AB.autoPunchOn = v
        notify("Auto Punch", v and "Auto Punch ON!" or "Disabled.", 3)
    end,
})

AutoBlockTab:CreateLabel("Fires Punch ability whenever a killer is within 10 studs")

-- Info
AutoBlockTab:CreateSection("System Info")
AutoBlockTab:CreateLabel("Sound Block: 200ms per-sound cooldown — tuned for fast M1 combos")
AutoBlockTab:CreateLabel("No global gate — every sound triggers independently")
AutoBlockTab:CreateLabel("Facing dot threshold: 0.70 (strict)")
AutoBlockTab:CreateLabel("Bait killers (sidestep check): John Doe, c00lkidd, Slasher, Noli, 1x1x1x1, Nosferatu")
AutoBlockTab:CreateLabel("HDT hooks AnimationPlayed — no polling overhead")
AutoBlockTab:CreateLabel("RCT = Charge fire + body flick | Auto Ledge finds nearest map drop")

-- LMS music
-- Downloads MP3s from sndup.net and caches them locally.
-- Auto-detects Last Man Standing by counting alive survivors.

local SoundService: SoundService = game:GetService("SoundService")

local LMS = {}
do
    local LMS_FOLDER: string = "XenonZ/LMS_Songs"
    local LMS_TRACKS: { [string]: string } = {
        ["Eternal Hope"]     = "https://www.sndup.net/hbbdc/d",
        ["Vanity"]           = "https://sndup.net/pbfc6/d",
        ["Hacklord"]         = "https://www.sndup.net/3ggm8/d",
        ["Compass"]          = "https://www.sndup.net/m897m/d",
        ["Scrapped Sixer"]   = "https://sndup.net/jwx39/d",
        ["ONE BOUNCE"]       = "https://www.sndup.net/hrjch/d",
        ["Meet Your Making"] = "https://www.sndup.net/w5kzs/d",
        -- Added in Update 4.0.0 — replace URLs once sndup links are sourced
        ["Faith's Answer"]   = "",
        ["You and I"]        = "",
    }

    local downloaded:  { [string]: string }  = {}
    local originalId:  string?               = nil
    local lmsThread:   thread?               = nil
    local lmsAutoPlay: boolean               = false
    local lmsSelected: string                = "Eternal Hope"

    -- Ensure cache folders exist
    pcall(function()
        if not isfolder("XenonZ") then makefolder("XenonZ") end
        if not isfolder(LMS_FOLDER)    then makefolder(LMS_FOLDER)    end
    end)

    -- Downloads a song and caches the custom asset path
    local function download(songName: string, callback: ((string?) -> ())?): string?
        local url = LMS_TRACKS[songName]
        if not url then if callback then callback(nil) end; return nil end
        local safe = songName:gsub("[^%w]", "_")
        local path = `{LMS_FOLDER}/{safe}.mp3`
        if not isfile(path) then
            local ok, data = pcall(function() return game:HttpGet(url) end)
            if not ok or not data or #data == 0 then
                if callback then callback(nil) end; return nil
            end
            pcall(function() writefile(path, data) end)
        end
        local asset: string? = nil
        local ok2 = pcall(function() asset = getcustomasset(path) end)
        if not ok2 or not asset then
            if callback then callback(nil) end; return nil
        end
        downloaded[songName] = asset :: string
        if callback then callback(asset) end
        return asset
    end

    -- Finds the LMS Sound object wherever the game stores it
    local function findSound(): Sound?
        local function check(s: Instance): boolean
            if not s or not s:IsA("Sound") then return false end
            local n = s.Name:lower()
            return n == "lastsurvivor" or n:find("last") ~= nil
                or n:find("lms") ~= nil or n:find("survivor") ~= nil
        end
        for _, loc in {
            workspace:FindFirstChild("Sounds"),
            workspace:FindFirstChild("Themes"),
            workspace:FindFirstChild("Music"),
            Lighting,
            SoundService,
        } do
            if loc then
                for _, s in (loc :: Instance):GetChildren() do
                    if check(s) then return s :: Sound end
                end
            end
        end
        for _, s in workspace:GetDescendants() do
            if check(s) then return s :: Sound end
        end
        for _, s in game:GetService("ReplicatedStorage"):GetDescendants() do
            if check(s) then return s :: Sound end
        end
        return nil
    end

    -- Detects whether LMS is currently active:
    -- Condition: exactly 1 survivor alive AND exactly 1 killer alive
    local function isActive(): boolean
        local ok, r = pcall(function(): boolean
            local pf = workspace:FindFirstChild("Players")
            if pf then
                local sf = (pf :: Folder):FindFirstChild("Survivors")
                local kf = (pf :: Folder):FindFirstChild("Killers")
                if sf and kf then
                    local aliveSurvivors = 0
                    for _, s in (sf :: Folder):GetChildren() do
                        local h = s:FindFirstChildOfClass("Humanoid")
                        if h and (h :: Humanoid).Health > 0 then
                            aliveSurvivors += 1
                        end
                    end
                    local aliveKillers = 0
                    for _, k in (kf :: Folder):GetChildren() do
                        local h = k:FindFirstChildOfClass("Humanoid")
                        if h and (h :: Humanoid).Health > 0 then
                            aliveKillers += 1
                        end
                    end
                    -- LMS = exactly 1 survivor AND 1 killer remaining
                    return aliveSurvivors == 1 and aliveKillers == 1
                end
            end
            -- Fallback: no folder found, check if the LMS sound is playing
            local sound = findSound()
            return sound ~= nil and (sound :: Sound).IsPlaying
        end)
        return ok and r or false
    end

    -- Applies the selected song to the LMS sound object
    local function applySong(songName: string): boolean
        local sound = findSound(); if not sound then return false end
        if not originalId then originalId = sound.SoundId end
        local asset = downloaded[songName] or download(songName)
        if not asset then return false end
        pcall(function()
            sound:Stop()
            sound.SoundId = asset :: string
            sound.Volume  = 0.55
            task.wait(0.05)
            sound:Play()
        end)
        return true
    end

    function LMS.reset()
        pcall(function()
            local sound = findSound()
            if sound and originalId then
                sound:Stop()
                sound.SoundId = originalId :: string
                task.wait(0.05)
                sound:Play()
            end
            originalId = nil
        end)
    end

    function LMS.start()
        if lmsThread then pcall(function() task.cancel(lmsThread) end) end
        lmsThread = task.spawn(function()
            -- Pre-download selected song in the background
            if not downloaded[lmsSelected] then
                task.spawn(function() download(lmsSelected) end)
            end
            local wasActive = false
            while lmsAutoPlay do
                local active = false
                pcall(function()
                    active = isActive()
                    if active and not wasActive then
                        wasActive = true
                        applySong(lmsSelected)
                    elseif active and wasActive then
                        -- Re-apply if the sound was reset by the game
                        local sound = findSound()
                        if sound then
                            local cached = downloaded[lmsSelected]
                            if cached and sound.SoundId ~= cached then
                                applySong(lmsSelected)
                            end
                        end
                    elseif not active and wasActive then
                        wasActive = false
                    end
                end)
                task.wait(active and 3 or 1)
            end
        end)
    end

    function LMS.stop()
        if lmsThread then pcall(function() task.cancel(lmsThread) end); lmsThread = nil end
        LMS.reset()
    end

    function LMS.playNow(): boolean return applySong(lmsSelected) end

    function LMS.setSelected(name: string)
        lmsSelected = name
        if not downloaded[name] then
            task.spawn(function() download(name) end)
        end
    end

    function LMS.setAutoPlay(v: boolean)
        lmsAutoPlay = v
        if v then LMS.start() else LMS.stop() end
    end

    function LMS.getAutoPlay(): boolean return lmsAutoPlay end
    function LMS.getSelected(): string  return lmsSelected  end

    LMS.tracks = LMS_TRACKS

    -- Re-start monitor on respawn (round restart can reset the song)
    AddConn(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(3)
        if lmsAutoPlay then LMS.start() end
    end))
end

-- aimbot
--
--   Setting CameraType.Scriptable hands full camera control to
--   a script and disables ALL Roblox camera processing including
--   mobile touch pan, joystick look, and PC mouse delta. This is
--   why it breaks every input on the device.
--
--   Roblox's default camera script runs at Enum.RenderPriority.Camera
--   (value 200) every frame. By binding at 201 our code runs AFTER
--   Roblox has already computed and applied the camera CFrame for
--   that frame. We then override only the look direction — a single
--   CFrame.lookAt call — while leaving CameraType, movement input,
--   joystick, touch, and everything else completely untouched.
--   The result is a smooth camlock with zero input breakage on any
--   platform including mobile.

-- Aimbot table was forward-declared above fireAbility; filling it in now
--
-- HOW THIS CAMLOCK WORKS (deep research summary):
--
-- Roblox's render pipeline each frame:
--   1. Input processed
--   2. Physics steps
--   3. Character controller (~priority 100-199)
--   4. Roblox default camera script runs at EXACTLY priority 200
--      It sets cam.CFrame based on player input, zoom, CameraSubject every frame
--   5. OUR CODE runs at priority 201 — one tick AFTER Roblox's camera
--   6. Frame rendered to screen
--
-- By running at 201 we are the LAST thing to touch cam.CFrame before the frame
-- draws. We let Roblox handle position, orbit, zoom, and ALL mobile/touch input
-- (CameraType stays "Custom" forever — never changed). We only overwrite the
-- final LOOK DIRECTION by calling CFrame.lookAt(cam.CFrame.Position, targetPos).
-- This is the only safe, mobile-compatible method. CameraType.Scriptable kills
-- all touch joystick input on mobile and is never used here.
--
-- Character lock works by setting HRP.CFrame to face the target every frame and
-- disabling AutoRotate (re-suppressed every frame since the game resets it).
-- The camera and character locks share the same aimPos so they never fight.
do
    local enabled:        boolean = false
    local camLock:        boolean = true   -- override camera look direction
    local charLock:       boolean = true   -- rotate HRP toward target every frame
    local target:         Model?  = nil    -- currently locked killer model
    local smoothness:     number  = 0.15   -- lerp alpha, 0.15 = matches reference script
    local maxDist:        number  = 80     -- studs from camera to killer
    local missChance:     number  = 0      -- 0–20% chance to intentionally miss a frame
    local showHL:         boolean = true   -- full-model highlight on locked target
    local skillOnly:      boolean = false  -- lock only activates during ability windows
    local skillActive:    boolean = false
    local skillHoldUntil: number  = 0
    local SKILL_HOLD:     number  = 0.6
    local fovEnabled:     boolean = false
    local fovCircle:      any     = nil
    local BIND:           string  = "XenonZ_CamLock"

    -- Highlight covers the entire killer model (whole body glows red)
    local hl: Highlight? = nil

    local function applyHL(model: Model)
        if hl and hl.Parent == model then return end
        if hl then pcall(function() hl:Destroy() end) end
        hl = nil
        if not showHL then return end
        local h      = Instance.new("Highlight")
        h.Name       = "_XenonZCamHL"
        h.Adornee    = model
        h.FillColor  = Color3.fromRGB(255, 30, 30)
        h.OutlineColor        = Color3.fromRGB(255, 90, 90)
        h.FillTransparency    = 0.45
        h.OutlineTransparency = 0
        h.DepthMode  = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent     = model
        hl = h
    end

    local function clearHL()
        if hl then pcall(function() hl:Destroy() end); hl = nil end
    end

    -- Resolve the best aim point on a killer model
    local function getAimPart(model: Model): BasePart?
        return (model:FindFirstChild("UpperTorso")
            or  model:FindFirstChild("Torso")
            or  model:FindFirstChild("HumanoidRootPart")) :: BasePart?
    end

    -- getNearestKiller: measures distance from CAMERA position (same method as
    -- the reference script shown in the screenshots — most natural on mobile
    -- because it favors whoever the camera is already roughly pointed at)
    local function getNearestKiller(): Model?
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local kf: Instance? = nil
        pcall(function() kf = workspace.Players.Killers end)
        if not kf then return nil end

        local best: Model? = nil
        local bestD: number = math.huge
        for _, m in (kf :: Instance):GetChildren() do
            if not m:IsA("Model") then continue end
            local hum = m:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hrp then continue end
            local d = (hrp.Position - cam.CFrame.Position).Magnitude
            if d < maxDist and d < bestD then bestD = d; best = m :: Model end
        end
        return best
    end

    -- pinTarget: manually locked model set by the killer buttons.
    -- When set it takes priority over auto-acquisition every frame.
    -- Cleared when the target dies, when clearTarget() is called,
    -- or when a new pin replaces it.
    local pinTarget: Model? = nil

    -- Shared helper: get all live survivors from workspace.Players.Survivors
    local function getSurvivorsFolder(): Folder?
        local f: Folder? = nil
        pcall(function() f = workspace.Players.Survivors :: Folder end)
        return f
    end

    -- Find the survivor with the lowest current HP (for killers to chase)
    local function findLowestHPSurvivor(): Model?
        local sf = getSurvivorsFolder()
        if not sf then return nil end
        local best: Model? = nil
        local bestHP: number = math.huge
        for _, m in (sf :: Instance):GetChildren() do
            if not m:IsA("Model") then continue end
            local hum = m:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            if hum.Health < bestHP then bestHP = hum.Health; best = m :: Model end
        end
        return best
    end

    -- Find the survivor closest to the LOCAL player's camera position
    local function findClosestSurvivor(): Model?
        local cam = workspace.CurrentCamera
        local sf  = getSurvivorsFolder()
        if not cam or not sf then return nil end
        local best: Model? = nil
        local bestD: number = math.huge
        for _, m in (sf :: Instance):GetChildren() do
            if not m:IsA("Model") then continue end
            local hum = m:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hrp then continue end
            local d = (hrp.Position - cam.CFrame.Position).Magnitude
            if d < bestD then bestD = d; best = m :: Model end
        end
        return best
    end
        pcall(function() RunService:UnbindFromRenderStep(BIND) end)

        RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1,
        function()
            -- Guard: only run when enabled
            if not enabled then return end

            -- Skill-only gate: suppress lock between ability windows
            if skillOnly and not skillActive and tick() > skillHoldUntil then
                clearHL(); return
            end

            local cam   = workspace.CurrentCamera
            local myChar = LocalPlayer.Character
            local myHRP = myChar and (myChar :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
            if not cam or not myHRP then return end

            -- Validate existing target; drop if dead or out of range
            if target then
                local th = target:FindFirstChildOfClass("Humanoid")
                local tp = getAimPart(target)
                if not th or th.Health <= 0 or not tp
                    or (tp.Position - cam.CFrame.Position).Magnitude > maxDist then
                    target = nil; clearHL()
                    -- Also clear pin if it was the same model
                    if pinTarget == target then pinTarget = nil end
                end
            end

            -- If a pinTarget is set, always use it (killer → survivor mode)
            -- Validate pin is still alive
            if pinTarget then
                local ph = pinTarget:FindFirstChildOfClass("Humanoid")
                if not ph or ph.Health <= 0 then
                    pinTarget = nil
                else
                    target = pinTarget
                end
            end

            -- Auto-acquire nearest killer only if no pin is set
            if not target then target = getNearestKiller() end
            if not target then clearHL(); return end

            local aimPart = getAimPart(target)
            if not aimPart then target = nil; clearHL(); return end

            -- Apply full-model highlight on locked target
            applyHL(target)

            -- Compute aim position with velocity prediction (horizontal only)
            -- Prediction leads the aim slightly ahead of a moving killer
            local vel = Vector3.zero
            pcall(function() vel = aimPart.AssemblyLinearVelocity end)
            if vel.Magnitude < 0.05 then
                pcall(function() vel = (aimPart :: any).Velocity end)
            end
            local aimPos = aimPart.Position + Vector3.new(vel.X, 0, vel.Z) * 0.1

            -- Optional miss chance
            if missChance > 0 and math.random(100) <= missChance then return end

            -- CHARACTER LOCK: rotate HRP to face target, disable AutoRotate every
            -- frame (game resets it on each step otherwise)
            if charLock then
                local flat = Vector3.new(aimPos.X, myHRP.Position.Y, aimPos.Z)
                local dir  = flat - myHRP.Position
                if dir.Magnitude > 0.01 then
                    local hum = (myChar :: Model):FindFirstChildOfClass("Humanoid")
                    if hum then hum.AutoRotate = false end
                    myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir.Unit)
                end
            end

            -- CAMERA LOCK: after Roblox's camera script has set cam.CFrame this
            -- frame, we overwrite only the look direction. Position is taken
            -- directly from cam.CFrame.Position so zoom/orbit/touch are preserved.
            -- Lerp with smoothness=0.15 gives the exact feel of the reference script.
            if camLock then
                local goal = CFrame.lookAt(cam.CFrame.Position, aimPos)
                cam.CFrame = cam.CFrame:Lerp(goal, smoothness)
            end
        end)
    end

    local function stopLock()
        pcall(function() RunService:UnbindFromRenderStep(BIND) end)
        target = nil
        clearHL()
        -- Restore AutoRotate so walking feels normal again
        pcall(function()
            local c = LocalPlayer.Character
            if not c then return end
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.AutoRotate = true end
        end)
        pcall(function() if fovCircle then fovCircle.Visible = false end end)
    end

    -- Re-bind on respawn
    AddConn(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if enabled then stopLock(); task.wait(0.1); startLock() end
    end))

    -- Public API
    function Aimbot.setEnabled(v: boolean)
        enabled = v
        if v then startLock() else stopLock() end
    end
    function Aimbot.setCamLock(v: boolean)   camLock   = v end
    function Aimbot.setCharLock(v: boolean)  charLock  = v end
    function Aimbot.setLerp(v: number)       smoothness = v end
    function Aimbot.setMaxDist(v: number)    maxDist   = v end
    function Aimbot.setMissChance(v: number) missChance = math.clamp(v, 0, 20) end
    function Aimbot.setTorsoHL(v: boolean)
        showHL = v
        if not v then clearHL() end
    end
    function Aimbot.setFOV(v: number)
        pcall(function() if fovCircle then fovCircle.Radius = v end end)
    end
    function Aimbot.setFOVCircle(v: boolean)
        fovEnabled = v
        if v then
            pcall(function()
                local D = (getgenv() :: any).Drawing
                if not D then return end
                if fovCircle then fovCircle:Remove() end
                fovCircle           = D.new("Circle")
                fovCircle.Thickness = 1
                fovCircle.Color     = Color3.fromRGB(220, 50, 50)
                fovCircle.Filled    = false
                local vp = workspace.CurrentCamera.ViewportSize
                fovCircle.Position  = Vector2.new(vp.X/2, vp.Y/2)
                fovCircle.Radius    = 120
                fovCircle.Visible   = enabled
            end)
        else
            pcall(function() if fovCircle then fovCircle:Remove(); fovCircle = nil end end)
        end
    end
    function Aimbot.setSkillOnly(v: boolean)
        skillOnly = v
        if not v then skillActive = false end
    end
    function Aimbot.onSkillStart()
        skillActive    = true
        skillHoldUntil = tick() + SKILL_HOLD
    end
    function Aimbot.onSkillEnd()
        skillActive = false
    end
    function Aimbot.setSkillHold(v: number) SKILL_HOLD = v end
    function Aimbot.setPrediction(v: number) end -- prediction baked into 0.1 constant; stub kept for UI compat
    function Aimbot.clearTarget()
        target = nil; pinTarget = nil; clearHL()
    end
    -- Killer → Survivor: lock onto the survivor with the lowest HP
    function Aimbot.pinLowestHP()
        local m = findLowestHPSurvivor()
        if m then
            pinTarget = m
            target    = m
            applyHL(m)
            local hum = m:FindFirstChildOfClass("Humanoid")
            notify("Aimbot",
                `Locked: {m.Name} — {hum and math.floor(hum.Health) or "?"} HP (lowest)`, 3)
        else
            notify("Aimbot", "No survivors found.", 3)
        end
    end
    -- Killer → Survivor: lock onto the closest survivor by camera distance
    function Aimbot.pinClosest()
        local m = findClosestSurvivor()
        if m then
            pinTarget = m
            target    = m
            applyHL(m)
            notify("Aimbot", `Locked: {m.Name} (closest survivor)`, 3)
        else
            notify("Aimbot", "No survivors found.", 3)
        end
    end

-- TAB 7 ► AIMBOT
local AimbotTab = Window:CreateTab("AIMBOT (WIP)", 4483362458)

-- Main Toggle
AimbotTab:CreateSection("Aimbot")

AimbotTab:CreateToggle({
    Name="Enable Aimbot", CurrentValue=false, Flag="Aimbot_Enable",
    Callback=function(v: boolean)
        Aimbot.setEnabled(v)
        notify("Aimbot",
            v and "Lock active — scanning for nearest target in FOV." or "Disabled — camera restored.", 3)
    end,
})

AimbotTab:CreateToggle({
    Name="Camera Lock", CurrentValue=true, Flag="Aimbot_CamLock",
    Callback=function(v: boolean)
        Aimbot.setCamLock(v)
        notify("Aimbot", v and "Camera Lock ON." or "Camera Lock OFF.", 2)
    end,
})

AimbotTab:CreateToggle({
    Name="Character Lock (HRP faces target)", CurrentValue=true, Flag="Aimbot_CharLock",
    Callback=function(v: boolean)
        Aimbot.setCharLock(v)
        notify("Aimbot", v and "Character Lock ON." or "Character Lock OFF.", 2)
    end,
})

AimbotTab:CreateToggle({
    Name="Show Torso Highlight (Red Box)", CurrentValue=true, Flag="Aimbot_TorsoHL",
    Callback=function(v: boolean)
        Aimbot.setTorsoHL(v)
        notify("Aimbot", v and "Torso highlight ON — red box on locked killer." or "Highlight hidden.", 2)
    end,
})
AimbotTab:CreateToggle({
    Name="Skill-Only Mode (lock only during abilities)", CurrentValue=false, Flag="Aimbot_SkillOnly",
    Callback=function(v: boolean)
        Aimbot.setSkillOnly(v)
        notify("Aimbot",
            v and "Skill-Only ON — lock activates only when you use an ability."
              or "Skill-Only OFF — lock is always active.", 3)
    end,
})
AimbotTab:CreateSlider({
    Name="Skill Lock Hold Duration",
    Range={0.1, 2},
    Increment=0.1,
    CurrentValue=0.6,
    Suffix="s",
    Flag="Aimbot_SkillHold",
    Callback=function(v: number) Aimbot.setSkillHold(v) end,
})

AimbotTab:CreateButton({
    Name="Clear Current Target",
    Callback=function()
        Aimbot.clearTarget()
        notify("Aimbot", "Target cleared — will re-acquire on next frame.", 2)
    end,
})

-- Killer mode: pin a survivor as the target instead of auto-acquiring killers
AimbotTab:CreateSection("Killer — Lock Survivor")
AimbotTab:CreateLabel("When playing Killer, use these to lock onto a survivor.")
AimbotTab:CreateLabel("Enable Aimbot toggle above must also be ON.")

AimbotTab:CreateButton({
    Name="Lock Lowest HP Survivor",
    Callback=function()
        if not (Rayfield and true) then return end
        Aimbot.pinLowestHP()
    end,
})

AimbotTab:CreateButton({
    Name="Lock Closest Survivor",
    Callback=function()
        Aimbot.pinClosest()
    end,
})

-- Settings
AimbotTab:CreateSection("Settings")

AimbotTab:CreateSlider({
    Name="Camera Smooth (1.0 = Instant)",
    Range={0.01, 1},
    Increment=0.01,
    CurrentValue=0.15,
    Flag="Aimbot_Lerp",
    Callback=function(v: number) Aimbot.setLerp(v) end,
})
AimbotTab:CreateSlider({
    Name="FOV Radius",
    Range={10, 500},
    Increment=5,
    CurrentValue=120,
    Suffix=" px",
    Flag="Aimbot_FOV",
    Callback=function(v: number) Aimbot.setFOV(v) end,
})
AimbotTab:CreateSlider({
    Name="Max Lock Distance",
    Range={10, 200},
    Increment=5,
    CurrentValue=80,
    Suffix=" studs",
    Flag="Aimbot_MaxDist",
    Callback=function(v: number) Aimbot.setMaxDist(v) end,
})

AimbotTab:CreateSlider({
    Name="Velocity Prediction",
    Range={0, 1},
    Increment=0.01,
    CurrentValue=0.15,
    Flag="Aimbot_Prediction",
    Callback=function(v: number) Aimbot.setPrediction(v) end,
})
AimbotTab:CreateSlider({
    Name="Miss Chance",
    Range={0, 20},
    Increment=1,
    CurrentValue=0,
    Suffix="%",
    Flag="Aimbot_MissChance",
    Callback=function(v: number) Aimbot.setMissChance(v) end,
})

-- FOV Visualiser
AimbotTab:CreateSection("FOV Visualiser")

AimbotTab:CreateToggle({
    Name="Show FOV Circle", CurrentValue=false, Flag="Aimbot_FOVCircle",
    Callback=function(v: boolean)
        Aimbot.setFOVCircle(v)
        notify("Aimbot FOV", v and "FOV circle visible (red)." or "Hidden.", 2)
    end,
})

-- Info
AimbotTab:CreateSection("Info")
AimbotTab:CreateLabel("Method: BindToRenderStep priority 201 — runs after Roblox camera")
AimbotTab:CreateLabel("Target: nearest killer by camera distance (same as reference script)")
AimbotTab:CreateLabel("Highlight covers entire killer model — whole body glows red when locked")
AimbotTab:CreateLabel("CameraType never changes — mobile joystick and touch fully intact")
AimbotTab:CreateLabel("DOUBLE LOCK: camera snaps instantly + HRP faces killer every frame")

-- SILENT AIM SYSTEM
-- Silent Aim manipulates the punch/block remote's direction
-- argument so the server registers a hit on the killer's
-- torso even when the client's crosshair is not aligned.
-- Method: hook the ability RemoteEvent FireServer call and
-- swap the direction CFrame to point at the killer torso
-- before the packet leaves the client.
-- SILENT AIM — hookmetamethod __namecall approach (based on universal silent aim source).
-- Hooks workspace:Raycast() (and legacy FindPartOnRay variants) at the executor level.
-- When enabled and a Raycast fires from workspace, the direction is redirected toward
-- the nearest target entirely inside the engine — character never visually rotates.
-- Target mode is automatic: if local player is in Killers folder → target survivors,
-- if in Survivors folder → target killers.
-- Mobile: targeting uses camera-distance FOV rather than mouse position.
--
-- Skills (Forsaken):
--   KILLERS: Noli (Nova), c00lkidd (Corrupt Nature), Nosferatu (Hunter's Feast)
--   SURVIVORS: Jane Doe (Crystal Pitch), Dusekkar (Plasma Beam)
--
-- The __namecall hook only redirects when checkcaller() is false (game code, not our code)
-- so our own Raycast calls from the auto-block and ESP systems are never intercepted.
local SilentAim = { snap = function() end, snapAuto = function() end }
do
    local enabled:     boolean   = false
    local fovRadius:   number    = 160   -- pixels from screen centre (camera-distance proxy)
    local maxDist:     number    = 60    -- max studs from player to target
    local missChance:  number    = 0
    local saHook:      any       = nil   -- the __namecall hookmetamethod connection

    -- Per-skill enable flags
    local skills: { [string]: boolean } = {
        NoliNova      = true,   -- Noli: Nova (killer)
        CorruptNature = true,   -- c00lkidd: Corrupt Nature (killer)
        HuntersFeast  = true,   -- Nosferatu: Hunter's Feast (killer)
        CrystalPitch  = true,   -- Jane Doe: Crystal Pitch (survivor)
        PlasmaBeam    = true,   -- Dusekkar: Plasma Beam (survivor)
    }

    -- Determine whether local player is playing as Killer or Survivor this round
    local function getLocalRole(): string
        local kf: Instance? = nil
        pcall(function() kf = workspace.Players.Killers end)
        if kf then
            for _, m in (kf :: Instance):GetChildren() do
                if Players:GetPlayerFromCharacter(m) == LocalPlayer then
                    return "Killer"
                end
            end
        end
        return "Survivor"
    end

    -- Find the nearest enemy BasePart (HRP) to aim at.
    -- Survivors aim at killers; killers aim at survivors.
    -- Uses camera-distance (closest to where camera is pointing).
    local function getNearestTarget(): BasePart?
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local myChar = LocalPlayer.Character
        local myHRP = myChar and (myChar :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
        if not myHRP then return nil end

        local role = getLocalRole()
        local folder: Instance? = nil
        if role == "Killer" then
            pcall(function() folder = workspace.Players.Survivors end)
        else
            pcall(function() folder = workspace.Players.Killers end)
        end
        if not folder then return nil end

        local best: BasePart?   = nil
        local bestD: number     = math.huge
        local centre = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

        for _, model in (folder :: Instance):GetChildren() do
            if not model:IsA("Model") then continue end
            if Players:GetPlayerFromCharacter(model) == LocalPlayer then continue end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local hrp = (model:FindFirstChild("UpperTorso")
                or  model:FindFirstChild("Torso")
                or  model:FindFirstChild("HumanoidRootPart")) :: BasePart?
            if not hrp then continue end
            if (hrp.Position - myHRP.Position).Magnitude > maxDist then continue end
            -- Use screen distance from camera centre (works on mobile without mouse)
            local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
            if not onScreen then continue end
            local px = (Vector2.new(sp.X, sp.Y) - centre).Magnitude
            if px > fovRadius then continue end
            if px < bestD then bestD = px; best = hrp end
        end
        return best
    end

    -- Install the __namecall hook when silent aim is enabled.
    -- Intercepts workspace:Raycast() and workspace:FindPartOnRay*() calls
    -- made by the game's own code (checkcaller() == false).
    local function installHook()
        if saHook then return end  -- already installed
        local ok = pcall(function()
            -- hookmetamethod is available in supported executors (Synapse, Delta, etc.)
            local hm = (getgenv() :: any).hookmetamethod
            local cc = (getgenv() :: any).checkcaller
            local nc = (getgenv() :: any).newcclosure
            if not hm or not nc then return end

            local getMethod = (getgenv() :: any).getnamecallmethod

            local oldNamecall
            oldNamecall = hm(game, "__namecall", nc(function(...)
                if not enabled then return oldNamecall(...) end
                if cc and cc() then return oldNamecall(...) end

                local method = getMethod and getMethod() or ""
                local args   = {...}
                local self_  = args[1]

                if self_ ~= workspace then return oldNamecall(...) end

                if missChance > 0 and math.random(100) <= missChance then
                    return oldNamecall(...)
                end

                local target = getNearestTarget()
                if not target then return oldNamecall(...) end

                -- Raycast(origin, direction, params)
                if method == "Raycast" then
                    local origin: Vector3 = args[2]
                    if typeof(origin) == "Vector3" then
                        args[3] = (target.Position - origin).Unit * 1000
                        return oldNamecall(table.unpack(args))
                    end
                -- Legacy FindPartOnRay variants
                elseif method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist"
                    or method == "FindPartOnRay"
                    or method == "findPartOnRay" then
                    local ray = args[2]
                    if typeof(ray) == "Ray" then
                        local dir = (target.Position - ray.Origin).Unit * 1000
                        args[2]   = Ray.new(ray.Origin, dir)
                        return oldNamecall(table.unpack(args))
                    end
                end

                return oldNamecall(...)
            end))

            saHook = oldNamecall
        end)
        if not ok then
            notify("Silent Aim", "hookmetamethod not available in this executor.", 4)
        end
    end

    -- Unhook: restore original __namecall.
    -- hookmetamethod is persistent — to undo we rehook with the original.
    local function removeHook()
        if not saHook then return end
        pcall(function()
            local hm = (getgenv() :: any).hookmetamethod
            local nc = (getgenv() :: any).newcclosure
            if not hm or not nc then return end
            local captured = saHook
            hm(game, "__namecall", nc(function(...)
                return captured(...)
            end))
        end)
        saHook = nil
    end

    -- snapAuto / snap kept as stubs — the hookmetamethod approach intercepts
    -- Raycast calls automatically and does not need manual HRP rotation.
    -- These stubs prevent errors from fireAbility calling them.
    function SilentAim.snapAuto()  end
    function SilentAim.snap(_: string) end

    function SilentAim.setEnabled(v: boolean)
        enabled = v
        if v then
            installHook()
        else
            enabled = false  -- hook stays installed but returns early when disabled
        end
    end
    function SilentAim.setSkill(key: string, v: boolean) skills[key] = v end
    function SilentAim.setFOV(v: number)     fovRadius  = v end
    function SilentAim.setMaxDist(v: number) maxDist    = v end
    function SilentAim.setMiss(v: number)    missChance = math.clamp(v, 0, 20) end
    function SilentAim.getEnabled(): boolean return enabled end

    -- Cleanup on script destroy
    AddConn({ Disconnect = removeHook })
end

-- Silent Aim Tab
local SilentAimTab = Window:CreateTab("SILENT AIM (WIP)", 4483362458)

SilentAimTab:CreateSection("Silent Aim")
SilentAimTab:CreateLabel("Uses hookmetamethod to redirect workspace:Raycast() at engine level.")
SilentAimTab:CreateLabel("Character never rotates — the ray just hits the target silently.")
SilentAimTab:CreateLabel("Auto-detects role: Survivor targets Killers, Killer targets Survivors.")

SilentAimTab:CreateToggle({
    Name="Enable Silent Aim", CurrentValue=false, Flag="SilentAim_Enable",
    Callback=function(v: boolean)
        SilentAim.setEnabled(v)
        notify("Silent Aim", v and "ON — Raycast hook active. Abilities will auto-hit." or "Disabled.", 3)
    end,
})

SilentAimTab:CreateSection("Ability Skills")
SilentAimTab:CreateLabel("Killer abilities (target survivors):")

SilentAimTab:CreateToggle({
    Name="Noli — Nova", CurrentValue=true, Flag="SA_NoliNova",
    Callback=function(v: boolean)
        SilentAim.setSkill("NoliNova", v)
        notify("Silent Aim", v and "Nova ON." or "Nova OFF.", 2)
    end,
})

SilentAimTab:CreateToggle({
    Name="c00lkidd — Corrupt Nature", CurrentValue=true, Flag="SA_CorruptNature",
    Callback=function(v: boolean)
        SilentAim.setSkill("CorruptNature", v)
        notify("Silent Aim", v and "Corrupt Nature ON." or "OFF.", 2)
    end,
})

SilentAimTab:CreateToggle({
    Name="Nosferatu — Hunter's Feast", CurrentValue=true, Flag="SA_HuntersFeast",
    Callback=function(v: boolean)
        SilentAim.setSkill("HuntersFeast", v)
        notify("Silent Aim", v and "Hunter's Feast ON." or "OFF.", 2)
    end,
})

SilentAimTab:CreateLabel("Survivor abilities (target killers):")

SilentAimTab:CreateToggle({
    Name="Jane Doe — Crystal Pitch", CurrentValue=true, Flag="SA_CrystalPitch",
    Callback=function(v: boolean)
        SilentAim.setSkill("CrystalPitch", v)
        notify("Silent Aim", v and "Crystal Pitch ON." or "OFF.", 2)
    end,
})

SilentAimTab:CreateToggle({
    Name="Dusekkar — Plasma Beam", CurrentValue=true, Flag="SA_PlasmaBeam",
    Callback=function(v: boolean)
        SilentAim.setSkill("PlasmaBeam", v)
        notify("Silent Aim", v and "Plasma Beam ON." or "OFF.", 2)
    end,
})

SilentAimTab:CreateSection("Settings")

SilentAimTab:CreateSlider({
    Name="FOV Radius (screen px from centre)",
    Range={10, 500},
    Increment=5,
    CurrentValue=160,
    Suffix=" px",
    Flag="SA_FOV",
    Callback=function(v: number) SilentAim.setFOV(v) end,
})
SilentAimTab:CreateSlider({
    Name="Max Distance",
    Range={10, 150},
    Increment=5,
    CurrentValue=60,
    Suffix=" studs",
    Flag="SA_MaxDist",
    Callback=function(v: number) SilentAim.setMaxDist(v) end,
})
SilentAimTab:CreateSlider({
    Name="Miss Chance",
    Range={0, 20},
    Increment=1,
    CurrentValue=0,
    Suffix="%",
    Flag="SA_Miss",
    Callback=function(v: number) SilentAim.setMiss(v) end,
})

-- MUSIC TAB
local MusicTab = Window:CreateTab("Music", 4483362458)

MusicTab:CreateToggle({
    Name="Auto-Play LMS Music", CurrentValue=false, Flag="LMS_AutoPlay",
    Callback=function(v: boolean)
        LMS.setAutoPlay(v)
        if v then
            notify("LMS Music", `Auto-play ON — will trigger when LMS starts!`, 4)
        else
            notify("LMS Music", "Disabled — original song restored.", 3)
        end
    end,
})

do
    local trackOptions: { string } = {}
    for name in LMS.tracks do table.insert(trackOptions, name) end
    table.sort(trackOptions)

    MusicTab:CreateDropdown({
        Name="Select Song",
        Options=trackOptions,
        CurrentOption={"Eternal Hope"},
        Flag="LMS_SongSelect",
        Callback=function(selected: { string })
            LMS.setSelected(selected[1])
            notify("LMS Music", `Selected: {selected[1]} — pre-downloading...`, 3)
        end,
    })
end

MusicTab:CreateButton({
    Name="▶ Play Now (test)",
    Callback=function()
        if LMS.playNow() then
            notify("LMS Music", `Now playing: {LMS.getSelected()}`, 3)
        else
            notify("LMS Music", "Sound not found — try during a round.", 3)
        end
    end,
})

MusicTab:CreateButton({
    Name="⏹ Reset to Original Song",
    Callback=function()
        LMS.reset()
        notify("LMS Music", "Original song restored.", 3)
    end,
})

MusicTab:CreateSection("Song List")
MusicTab:CreateLabel("Eternal Hope")
MusicTab:CreateLabel("Vanity")
MusicTab:CreateLabel("Hacklord")
MusicTab:CreateLabel("Compass")
MusicTab:CreateLabel("Scrapped Sixer")
MusicTab:CreateLabel("ONE BOUNCE")
MusicTab:CreateLabel("Meet Your Making")
MusicTab:CreateLabel("Faith's Answer  ⭐ New — 4.0.0")
MusicTab:CreateLabel("You and I  ⭐ New — 4.0.0")
MusicTab:CreateLabel("⚠ Fill in sndup URLs for Faith's Answer & You and I to enable them")
MusicTab:CreateLabel("Triggers when exactly 1 survivor and 1 killer remain")

-- BLATANT TAB — speed, noclip, auto-attack, teleport
local BlatantTab = Window:CreateTab("Blatant", 4483362458)

BlatantTab:CreateSection("Speed")

-- Walk and sprint multiplier — adds a direct CFrame offset each Stepped frame
-- on top of whatever the sprint module is already doing. Multiplier of 0 = no effect.
local blatantWalkMult:   number  = 0
local blatantSprintMult: number  = 0
local blatantSpeedConn:  Connection? = nil

local function startBlatantSpeed()
    if blatantSpeedConn then return end
    blatantSpeedConn = RunService.Stepped:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character; if not char then return end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hum or not root then return end
            if hum.MoveDirection.Magnitude < 0.01 then return end
            -- Detect sprinting: WalkSpeed above baseline or sprint module running
            local isSprinting = hum.WalkSpeed > 20
            local mult = isSprinting and blatantSprintMult or blatantWalkMult
            if mult <= 0 then return end
            -- Add velocity in move direction rather than teleporting CFrame
            -- to stay compatible with Forsaken's anti-cheat checks
            root.CFrame = root.CFrame + (hum.MoveDirection * mult)
        end)
    end)
    AddConn(blatantSpeedConn)
end

local function stopBlatantSpeed()
    if blatantSpeedConn then
        blatantSpeedConn:Disconnect()
        blatantSpeedConn = nil
    end
end

BlatantTab:CreateSlider({
    Name="Walk Boost",
    Range={0, 10},
    Increment=0.1,
    CurrentValue=0,
    Suffix="x",
    Flag="Blatant_WalkMult",
    Callback=function(v: number)
        blatantWalkMult = v
        if v > 0 then startBlatantSpeed()
        elseif blatantSprintMult <= 0 then stopBlatantSpeed() end
    end,
})

BlatantTab:CreateSlider({
    Name="Sprint Boost",
    Range={0, 15},
    Increment=0.1,
    CurrentValue=0,
    Suffix="x",
    Flag="Blatant_SprintMult",
    Callback=function(v: number)
        blatantSprintMult = v
        if v > 0 then startBlatantSpeed()
        elseif blatantWalkMult <= 0 then stopBlatantSpeed() end
    end,
})

BlatantTab:CreateSection("Noclip")
BlatantTab:CreateLabel("Disables collision on all character parts while active.")
BlatantTab:CreateLabel("Walk through walls, traps, and map geometry.")

local blatantNoclipConn: Connection? = nil

BlatantTab:CreateToggle({
    Name="Noclip", CurrentValue=false, Flag="Blatant_Noclip",
    Callback=function(v: boolean)
        if blatantNoclipConn then
            blatantNoclipConn:Disconnect()
            blatantNoclipConn = nil
        end
        if not v then
            -- Restore collision on all parts when disabled
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                for _, p in char:GetDescendants() do
                    if p:IsA("BasePart") then (p :: BasePart).CanCollide = true end
                end
            end)
            notify("Noclip", "Disabled — collision restored.", 2)
            return
        end
        blatantNoclipConn = RunService.Stepped:Connect(function()
            pcall(function()
                local char = LocalPlayer.Character; if not char then return end
                for _, p in char:GetDescendants() do
                    if p:IsA("BasePart") then (p :: BasePart).CanCollide = false end
                end
            end)
        end)
        AddConn(blatantNoclipConn)
        notify("Noclip", "ON — walking through walls.", 3)
    end,
})

BlatantTab:CreateSection("Teleport")

local blatantTpDropdown: any = nil

BlatantTab:CreateButton({
    Name="Refresh Player List",
    Callback=function()
        if not blatantTpDropdown then return end
        local list: { string } = {}
        for _, p in Players:GetPlayers() do
            if p ~= LocalPlayer then table.insert(list, p.Name) end
        end
        if #list == 0 then table.insert(list, "(no other players)") end
        blatantTpDropdown:Refresh(list, true)
    end,
})

blatantTpDropdown = BlatantTab:CreateDropdown({
    Name="Target Player",
    Options={"(press refresh)"},
    CurrentOption={"(press refresh)"},
    Flag="Blatant_TpTarget",
    Callback=function() end,
})

BlatantTab:CreateButton({
    Name="Teleport to Player",
    Callback=function()
        safeCall(function()
            local selected = Rayfield.Flags["Blatant_TpTarget"]
            local name = (type(selected) == "table" and selected[1]) or tostring(selected or "")
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then
                notify("Teleport", "Player not found or has no character.", 3); return
            end
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local myHRP = LocalPlayer.Character
                and (LocalPlayer.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
            if not tHRP or not myHRP then
                notify("Teleport", "HumanoidRootPart missing.", 3); return
            end
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
            notify("Teleport", `Warped to {name}.`, 3)
        end)
    end,
})

-- TAB 8 ► MISC
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Chat Logger")

local chatLog: { string } = {}
local MAX_LOG: number     = 50
local chatActive: boolean = false
local chatConns: { Connection } = {}

local function addMessage(player: string, message: string)
    local entry = `[{os.date("%H:%M:%S")}] {player}: {message}`
    table.insert(chatLog, entry)
    if #chatLog > MAX_LOG then table.remove(chatLog, 1) end
    print(`[XenonZ Chat] {entry}`)
    if player ~= LocalPlayer.Name and getgenv().ForsakenChatNotify ~= false then
        notify(`💬 {player}`, message, 4)
    end
end

local function hookTextChatService()
    pcall(function()
        local TCS = game:GetService("TextChatService")
        if not TCS then return end
        local function hookChannel(ch: Instance)
            if not ch:IsA("TextChannel") then return end
            table.insert(chatConns, (ch :: TextChannel).MessageReceived:Connect(
                function(msg: TextChatMessage)
                    pcall(function()
                        local s = msg.TextSource and msg.TextSource.Name or "?"
                        if msg.Text and msg.Text ~= "" then addMessage(s, msg.Text) end
                    end)
                end
            ))
        end
        for _, ch in TCS:GetDescendants() do hookChannel(ch) end
        table.insert(chatConns, TCS.DescendantAdded:Connect(function(ch: Instance)
            task.wait(0.1); hookChannel(ch)
        end))
    end)
end

local function hookLegacyChat()
    safeCall(function()
        local function hp(p: Player)
            table.insert(chatConns, p.Chatted:Connect(function(msg: string)
                addMessage(p.Name, msg)
            end))
        end
        for _, p in Players:GetPlayers() do hp(p) end
        table.insert(chatConns, Players.PlayerAdded:Connect(hp))
    end)
end

MiscTab:CreateToggle({
    Name="Enable Chat Logger", CurrentValue=false, Flag="ChatLogger",
    Callback=function(v: boolean)
        chatActive = v
        if v then
            hookTextChatService()
            hookLegacyChat()
            notify("Chat Logger", "Chat hooked! Messages print to F9.", 4)
        else
            for _, c in chatConns do pcall(function() c:Disconnect() end) end
            chatConns = {}
            notify("Chat Logger", `Off. {#chatLog} messages stored.`, 3)
        end
    end,
})

MiscTab:CreateToggle({
    Name="Notify on Every Message", CurrentValue=true, Flag="ChatNotify",
    Callback=function(v: boolean)
        getgenv().ForsakenChatNotify = v
        notify("Chat", v and "Notifications ON." or "Silent — log only.", 3)
    end,
})

MiscTab:CreateButton({
    Name="Print Chat Log (F9)",
    Callback=function()
        if #chatLog == 0 then notify("Chat Log", "Nothing logged yet.", 3); return end
        print(`=== XenonZ Chat Log ({#chatLog}) ===`)
        for i, e in chatLog do print(`{i}. {e}`) end
        notify("Chat Log", `{#chatLog} message(s) printed to F9.`, 4)
    end,
})

MiscTab:CreateButton({
    Name="Show Last 5 Messages",
    Callback=function()
        if #chatLog == 0 then notify("Chat", "Nothing yet.", 3); return end
        local s = math.max(1, #chatLog - 4)
        for i = s, #chatLog do
            task.delay((i - s) * 0.8, function() notify("Chat", chatLog[i], 4) end)
        end
    end,
})

MiscTab:CreateButton({
    Name="Clear Chat Log",
    Callback=function()
        local c = #chatLog; chatLog = {}
        notify("Chat", `Cleared {c} message(s).`, 3)
    end,
})

MiscTab:CreateButton({
    Name="Force Open Chat",
    Callback=function()
        safeCall(function()
            pcall(function() game:GetService("StarterGui"):SetCore("ChatActive", true) end)
            pcall(function()
                local cg = game:GetService("CoreGui")
                local ib = cg:FindFirstChildWhichIsA("TextBox", true)
                if ib then (ib :: TextBox):CaptureFocus() end
            end)
            notify("Chat", "Chat opened!", 2)
        end)
    end,
})

-- TAB 8 ► SETTINGS
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("UI Controls")

SettingsTab:CreateButton({
    Name="Reset All Settings",
    Callback=function()
        safeCall(function()
            for k in flags do flags[k] = false end
            generatorESPEnabled = false
            for _, p in Players:GetPlayers() do
                local c = p.Character
                if not c then continue end
                for _, child in c:GetChildren() do
                    if child:IsA("Highlight") then child:Destroy() end
                end
            end
            stopGeneratorESP()
            for _, obj in workspace:GetDescendants() do
                for _, name in {"ItemESP_Hl","TripmineESP_Hl","TripwireESP_Hl","BuilderESP_Hl","PizzaESP_Hl","VandalismESP_Hl","FilesESP_Hl"} do
                    local hl = obj:FindFirstChild(name)
                    if hl then hl:Destroy() end
                end
            end
            Lighting.Brightness    = origLighting.Brightness
            Lighting.ClockTime     = origLighting.ClockTime
            Lighting.FogEnd        = origLighting.FogEnd
            Lighting.GlobalShadows = origLighting.GlobalShadows
            Lighting.Ambient       = origLighting.Ambient
            notify("Reset", "All settings restored to default.", 3)
        end)
    end,
})

SettingsTab:CreateButton({
    Name="Destroy UI (Safe Exit)",
    Callback=function()
        safeCall(function() getgenv().XenonZDestroy(); Rayfield:Destroy() end)
    end,
})

SettingsTab:CreateSection("Round Timer (by Survivor Count)")
SettingsTab:CreateLabel("8 Survivors  →  4 min 00 sec")
SettingsTab:CreateLabel("6 or 5 Survivors  →  3 min 18 sec")
SettingsTab:CreateLabel("4 or fewer Survivors  →  3 min 00 sec")
SettingsTab:CreateLabel("Each Killer kill: +35 seconds added")
SettingsTab:CreateLabel("Each Puzzle completed: -3 seconds")
SettingsTab:CreateLabel("1 Generator = 4 Puzzles = -12 seconds")
SettingsTab:CreateLabel("All 5 Generators = 20 Puzzles = -60 sec")

SettingsTab:CreateSection("Speed & Stamina")
SettingsTab:CreateLabel("Survivor walk: 12 | sprint: 26 studs/s")
SettingsTab:CreateLabel("Slasher / c00lkidd sprint: 28 studs/s")
SettingsTab:CreateLabel("Stamina drain: 10/s | Regen: 20/s")
SettingsTab:CreateLabel("Stamina lockout at 0: 2 seconds")

SettingsTab:CreateSection("ESP Legend")
SettingsTab:CreateLabel("Blue = You (self) | Green = Survivor | Red = Killer")
SettingsTab:CreateLabel("Blue = Real Generator | Red = Fake Generator")
SettingsTab:CreateLabel("Purple = Medkit / BloxyCola | Orange = Tripmine")
SettingsTab:CreateLabel("Yellow = Tripwire | Orange = Sentry | Gold = Dispenser")
SettingsTab:CreateLabel("Hot Pink = Elliot Pizza Throw | Cyan = Veeronica VANDALISM zone")
SettingsTab:CreateLabel("Parchment/Gold = Jane Doe Quest Files / Basement Documents")
SettingsTab:CreateLabel("Engine: Gloop | UNC: 100% | Level 8")

-- CREDITS TAB
local CreditsTab = Window:CreateTab("Credits", 4483362458)

CreditsTab:CreateSection("XenonZ Credits")

CreditsTab:CreateLabel("XenonZ v1.0 — built for Forsaken (Roblox)")
CreditsTab:CreateLabel("Discord: https://discord.gg/ehHtxQuZr")
CreditsTab:CreateLabel("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

CreditsTab:CreateSection("xsxluna_kiyokifrost")
CreditsTab:CreateLabel("best src eva 🩷")

CreditsTab:CreateSection("veux67")
CreditsTab:CreateLabel("for inf stamina")

CreditsTab:CreateSection("")
CreditsTab:CreateLabel("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
CreditsTab:CreateLabel("thank you to everyone who contributed ❤️")

-- LOAD
task.delay(1, function()
    local survivorCount = #Players:GetPlayers() - 1
    local timerStr = survivorCount >= 8 and "4:00" or survivorCount >= 5 and "3:18" or "3:00"
    notify("XenonZ v1.0 Loaded",
        `Timer: ~{timerStr} ({survivorCount} survivors). Survive = win. Kill all = win.`, 7)
end)
