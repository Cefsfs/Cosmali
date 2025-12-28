-- Complete ESP Library by Blissful
-- All modules organized with shared heartbeat and settings
-- Load with: loadstring(game:HttpGet("YOUR_RAW_URL"))()

local ESPLibrary = {}

-- External dependencies at the top
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Load external libraries
local UniversalESP = loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-ESP-Library-9570", true))()
local LerpColorModule = loadstring(game:HttpGet("https://pastebin.com/raw/wRnsJeid"))()

-- Shared settings system
ESPLibrary.Settings = {
    -- General settings
    Enabled = true,
    TeamCheck = false,
    UseTeamColor = false,
    FriendsColor = Color3.fromRGB(0, 255, 0),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    DefaultColor = Color3.fromRGB(255, 0, 0),
    MaxDistance = 1000,
    
    -- Module toggles
    OffscreenArrows = true,
    CornerBox = true,
    Box3D = true,
    DrawingChams = true,
    Radar = true,
    ViewTracer = true,
    Skeleton = true,
    TracerBoxHealth = true,
    
    -- Specific module settings
    CornerBoxSettings = {
        Thickness = 2,
        AutoThickness = true,
        Rainbow = false,
        TeamCheck = false,
        TeamColor = false
    },
    
    Box3DSettings = {
        Thickness = 1,
        Transparency = 0.25,
        Color = Color3.fromRGB(255, 255, 255),
        Filled = false
    },
    
    DrawingChamsSettings = {
        TeamCheck = true,
        Red = Color3.fromRGB(255, 0, 0),
        Green = Color3.fromRGB(0, 255, 0),
        Color = Color3.fromRGB(255, 0, 0),
        TeamColor = false,
        Transparency = 0.25
    },
    
    RadarSettings = {
        Position = Vector2.new(200, 200),
        Radius = 100,
        Scale = 1,
        Background = Color3.fromRGB(10, 10, 10),
        Border = Color3.fromRGB(75, 75, 75),
        LocalDot = Color3.fromRGB(255, 255, 255),
        PlayerDot = Color3.fromRGB(60, 170, 255),
        TeamColor = Color3.fromRGB(0, 255, 0),
        EnemyColor = Color3.fromRGB(255, 0, 0),
        HealthColor = true,
        TeamCheck = true,
        Draggable = true
    },
    
    ViewTracerSettings = {
        Color = Color3.fromRGB(255, 203, 138),
        Thickness = 1,
        Transparency = 1,
        AutoThickness = true,
        Length = 15,
        Smoothness = 0.2
    },
    
    SkeletonSettings = {
        Color = Color3.fromRGB(255, 0, 0),
        Thickness = 1,
        TeamCheck = false,
        TeamColor = false
    },
    
    TracerBoxHealthSettings = {
        BoxColor = Color3.fromRGB(255, 0, 0),
        TracerColor = Color3.fromRGB(255, 0, 0),
        TracerThickness = 1,
        BoxThickness = 1,
        TracerOrigin = "Bottom",
        TracerFollowMouse = false,
        Tracers = true,
        TeamCheck = false,
        GreenColor = Color3.fromRGB(0, 255, 0),
        RedColor = Color3.fromRGB(255, 0, 0),
        UseTeamColor = false
    }
}

-- Internal state
ESPLibrary.Modules = {}
ESPLibrary.Connections = {}
ESPLibrary.PlayerData = {}
ESPLibrary.LocalPlayer = Players.LocalPlayer
ESPLibrary.Camera = Workspace.CurrentCamera

-- Shared utility functions
local function ShouldShowESP(player)
    if not ESPLibrary.Settings.Enabled then return false end
    if player == ESPLibrary.LocalPlayer then return false end
    if not player.Character then return false end
    if not player.Character:FindFirstChild("Humanoid") then return false end
    if player.Character.Humanoid.Health <= 0 then return false end
    
    if ESPLibrary.Settings.TeamCheck then
        return player.Team ~= ESPLibrary.LocalPlayer.Team
    end
    
    return true
end

local function GetPlayerColor(player, overrideSettings)
    local settings = overrideSettings or ESPLibrary.Settings
    
    if settings.UseTeamColor then
        return player.TeamColor.Color
    end
    
    if settings.TeamCheck then
        if player.Team == ESPLibrary.LocalPlayer.Team then
            return settings.FriendsColor
        else
            return settings.EnemyColor
        end
    end
    
    return settings.DefaultColor
end

local function IsPlayerVisible(player)
    if not player.Character then return false end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    local origin = ESPLibrary.Camera.CFrame.Position
    local target = root.Position
    local direction = (target - origin).Unit
    local ray = Ray.new(origin, direction * (target - origin).Magnitude)
    local hit, position = Workspace:FindPartOnRayWithIgnoreList(ray, {ESPLibrary.LocalPlayer.Character, ESPLibrary.Camera})
    
    return hit == nil or hit:IsDescendantOf(player.Character)
end

-- Base ESP module class
local ESPModule = {}
ESPModule.__index = ESPModule

function ESPModule.new(name)
    local self = setmetatable({
        Name = name,
        Enabled = false,
        Drawings = {},
        Connections = {},
        PlayerDrawings = {},
        Objects = {}
    }, ESPModule)
    
    ESPLibrary.Modules[name] = self
    return self
end

function ESPModule:Enable()
    if self.Enabled then return end
    self.Enabled = true
    self:Initialize()
end

function ESPModule:Disable()
    if not self.Enabled then return end
    self.Enabled = false
    self:Cleanup()
end

function ESPModule:Initialize()
    -- To be overridden
end

function ESPModule:Cleanup()
    -- Clean up drawings
    for _, drawing in pairs(self.Drawings) do
        if drawing and drawing.Remove then
            pcall(function() drawing:Remove() end)
        end
    end
    
    -- Clean up connections
    for _, connection in pairs(self.Connections) do
        if connection and connection.Disconnect then
            pcall(function() connection:Disconnect() end)
        end
    end
    
    -- Clean up objects
    for _, obj in pairs(self.Objects) do
        if obj and obj.Destroy then
            pcall(function() obj:Destroy() end)
        end
    end
    
    self.Drawings = {}
    self.Connections = {}
    self.PlayerDrawings = {}
    self.Objects = {}
end

function ESPModule:RemovePlayerDrawings(player)
    if self.PlayerDrawings[player] then
        for _, drawing in pairs(self.PlayerDrawings[player]) do
            if drawing and drawing.Remove then
                pcall(function() drawing:Remove() end)
            end
        end
        self.PlayerDrawings[player] = nil
    end
end

-- Module 1: Offscreen Arrows
local OffscreenArrows = setmetatable({}, {__index = ESPModule})
OffscreenArrows.__index = OffscreenArrows

function OffscreenArrows.new()
    local self = ESPModule.new("OffscreenArrows")
    setmetatable(self, OffscreenArrows)
    return self
end

function OffscreenArrows:Initialize()
    -- Initialize Universal ESP
    UniversalESP:Toggle(true)
    
    -- Override team color if needed
    if ESPLibrary.Settings.UseTeamColor then
        function UniversalESP:GetTeamColor(player)
            return GetPlayerColor(player)
        end
    end
    
    -- Track all players
    local function setupPlayer(player)
        if ShouldShowESP(player) then
            UniversalESP.Object:New(UniversalESP:GetCharacter(player))
        end
    end
    
    -- Setup existing players
    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player)
    end
    
    -- Player added connection
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        setupPlayer(player)
        
        UniversalESP:CharacterAdded(player):Connect(function(character)
            if ShouldShowESP(player) then
                UniversalESP.Object:New(character)
            end
        end)
    end)
    
    table.insert(self.Connections, playerAddedConn)
end

function OffscreenArrows:Cleanup()
    ESPModule.Cleanup(self)
    UniversalESP:Toggle(false)
end

-- Module 2: Corner Box ESP
local CornerBox = setmetatable({}, {__index = ESPModule})
CornerBox.__index = CornerBox

function CornerBox.new()
    local self = ESPModule.new("CornerBox")
    setmetatable(self, CornerBox)
    return self
end

function CornerBox:Initialize()
    local camera = ESPLibrary.Camera
    local localPlayer = ESPLibrary.LocalPlayer
    local settings = ESPLibrary.Settings.CornerBoxSettings
    
    local function createLine(color, thickness)
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = color
        line.Thickness = thickness
        line.Transparency = 1
        return line
    end
    
    local function updatePlayerESP(player)
        if not ShouldShowESP(player) then return end
        
        local character = player.Character
        if not character then return end
        
        repeat task.wait() until character:FindFirstChild("HumanoidRootPart")
        
        local lines = {
            TL1 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            TL2 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            TR1 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            TR2 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            BL1 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            BL2 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            BR1 = createLine(GetPlayerColor(player, settings), settings.Thickness),
            BR2 = createLine(GetPlayerColor(player, settings), settings.Thickness)
        }
        
        -- Create invisible part for calculations
        local oripart = Instance.new("Part")
        oripart.Parent = Workspace
        oripart.Transparency = 1
        oripart.CanCollide = false
        oripart.Anchored = true
        oripart.Size = Vector3.new(1, 1, 1)
        oripart.Position = Vector3.new(0, 0, 0)
        
        table.insert(self.Objects, oripart)
        self.PlayerDrawings[player] = lines
        
        local function updater()
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not self.Enabled then 
                    for _, line in pairs(lines) do
                        line.Visible = false
                    end
                    return 
                end
                
                local char = player.Character
                if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") or char.Humanoid.Health <= 0 then
                    for _, line in pairs(lines) do
                        line.Visible = false
                    end
                    return
                end
                
                local root = char.HumanoidRootPart
                local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    oripart.Size = Vector3.new(root.Size.X, root.Size.Y * 1.5, root.Size.Z)
                    oripart.CFrame = CFrame.new(root.CFrame.Position, camera.CFrame.Position)
                    
                    local sizeX, sizeY = oripart.Size.X, oripart.Size.Y
                    local tl = camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(sizeX, sizeY, 0)).p)
                    local tr = camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(-sizeX, sizeY, 0)).p)
                    local bl = camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(sizeX, -sizeY, 0)).p)
                    local br = camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(-sizeX, -sizeY, 0)).p)
                    
                    local ratio = (camera.CFrame.p - root.Position).magnitude
                    local offset = math.clamp(1/ratio*750, 2, 300)
                    
                    -- Update lines
                    lines.TL1.From = Vector2.new(tl.X, tl.Y)
                    lines.TL1.To = Vector2.new(tl.X + offset, tl.Y)
                    lines.TL2.From = Vector2.new(tl.X, tl.Y)
                    lines.TL2.To = Vector2.new(tl.X, tl.Y + offset)
                    
                    lines.TR1.From = Vector2.new(tr.X, tr.Y)
                    lines.TR1.To = Vector2.new(tr.X - offset, tr.Y)
                    lines.TR2.From = Vector2.new(tr.X, tr.Y)
                    lines.TR2.To = Vector2.new(tr.X, tr.Y + offset)
                    
                    lines.BL1.From = Vector2.new(bl.X, bl.Y)
                    lines.BL1.To = Vector2.new(bl.X + offset, bl.Y)
                    lines.BL2.From = Vector2.new(bl.X, bl.Y)
                    lines.BL2.To = Vector2.new(bl.X, bl.Y - offset)
                    
                    lines.BR1.From = Vector2.new(br.X, br.Y)
                    lines.BR1.To = Vector2.new(br.X - offset, br.Y)
                    lines.BR2.From = Vector2.new(br.X, br.Y)
                    lines.BR2.To = Vector2.new(br.X, br.Y - offset)
                    
                    -- Update colors based on settings
                    local color
                    if settings.TeamCheck then
                        if player.Team == localPlayer.Team then
                            color = Color3.fromRGB(0, 255, 0)
                        else
                            color = Color3.fromRGB(255, 0, 0)
                        end
                    elseif settings.TeamColor then
                        color = player.TeamColor.Color
                    else
                        color = GetPlayerColor(player, settings)
                    end
                    
                    for _, line in pairs(lines) do
                        line.Color = color
                        line.Visible = true
                    end
                    
                    -- Auto thickness
                    if settings.AutoThickness then
                        local distance = (localPlayer.Character.HumanoidRootPart.Position - oripart.Position).magnitude
                        local value = math.clamp(1/distance*100, 1, 4)
                        for _, line in pairs(lines) do
                            line.Thickness = value
                        end
                    else
                        for _, line in pairs(lines) do
                            line.Thickness = settings.Thickness
                        end
                    end
                else
                    for _, line in pairs(lines) do
                        line.Visible = false
                    end
                end
            end)
            
            table.insert(self.Connections, connection)
        end
        
        coroutine.wrap(updater)()
    end
    
    -- Initialize for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updatePlayerESP(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            updatePlayerESP(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
    
    -- Handle player leaving
    local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        self:RemovePlayerDrawings(player)
    end)
    
    table.insert(self.Connections, playerRemovingConn)
end

-- Module 3: 3D Box ESP
local Box3D = setmetatable({}, {__index = ESPModule})
Box3D.__index = Box3D

function Box3D.new()
    local self = ESPModule.new("Box3D")
    setmetatable(self, Box3D)
    return self
end

function Box3D:Initialize()
    local camera = ESPLibrary.Camera
    local settings = ESPLibrary.Settings.Box3DSettings
    
    local function getCorners(part)
        local CF, Size, Corners = part.CFrame, part.Size / 2, {}
        for X = -1, 1, 2 do for Y = -1, 1, 2 do for Z = -1, 1, 2 do
            Corners[#Corners+1] = (CF * CFrame.new(Size * Vector3.new(X, Y, Z))).Position
        end end end
        return Corners
    end
    
    local renderConn
    renderConn = RunService.RenderStepped:Connect(function()
        if not self.Enabled then
            for _, drawing in pairs(self.Drawings) do
                if drawing then drawing.Visible = false end
            end
            return
        end
        
        -- Clear previous drawings
        for _, drawing in pairs(self.Drawings) do
            if drawing and drawing.Remove then
                pcall(function() drawing:Remove() end)
            end
        end
        self.Drawings = {}
        
        -- Draw for each player
        for _, player in ipairs(Players:GetPlayers()) do
            if ShouldShowESP(player) and player.Character then
                local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    -- Construct the 3d box
                    local cubeVertices = getCorners({
                        CFrame = humanoidRootPart.CFrame * CFrame.new(0, -0.5, 0), 
                        Size = Vector3.new(3, 5, 3)
                    })
                    
                    local function drawQuad(posA, posB, posC, posD)
                        local posAScreen, posAVisible = camera:WorldToViewportPoint(posA)
                        local posBScreen, posBVisible = camera:WorldToViewportPoint(posB)
                        local posCScreen, posCVisible = camera:WorldToViewportPoint(posC)
                        local posDScreen, posDVisible = camera:WorldToViewportPoint(posD)
                        
                        if not (posAVisible or posBVisible or posCVisible or posDVisible) then return end
                        
                        local quad = Drawing.new("Quad")
                        quad.Thickness = settings.Thickness
                        quad.Color = GetPlayerColor(player, settings)
                        quad.Transparency = settings.Transparency
                        quad.ZIndex = 1
                        quad.Filled = settings.Filled
                        quad.Visible = true
                        
                        quad.PointA = Vector2.new(posAScreen.X, posAScreen.Y)
                        quad.PointB = Vector2.new(posBScreen.X, posBScreen.Y)
                        quad.PointC = Vector2.new(posCScreen.X, posCScreen.Y)
                        quad.PointD = Vector2.new(posDScreen.X, posDScreen.Y)
                        
                        table.insert(self.Drawings, quad)
                    end
                    
                    local function drawLine(from, to)
                        local fromScreen, fromVisible = camera:WorldToViewportPoint(from)
                        local toScreen, toVisible = camera:WorldToViewportPoint(to)
                        
                        if not (fromVisible and toVisible) then return end
                        
                        local line = Drawing.new("Line")
                        line.Thickness = settings.Thickness
                        line.Color = GetPlayerColor(player, settings)
                        line.Transparency = 1
                        line.ZIndex = 1
                        line.Visible = true
                        
                        line.From = Vector2.new(fromScreen.X, fromScreen.Y)
                        line.To = Vector2.new(toScreen.X, toScreen.Y)
                        
                        table.insert(self.Drawings, line)
                    end
                    
                    -- Draw all faces
                    -- Bottom face
                    drawLine(cubeVertices[1], cubeVertices[2])
                    drawLine(cubeVertices[2], cubeVertices[6])
                    drawLine(cubeVertices[6], cubeVertices[5])
                    drawLine(cubeVertices[5], cubeVertices[1])
                    drawQuad(cubeVertices[1], cubeVertices[2], cubeVertices[6], cubeVertices[5])
                    
                    -- Side faces
                    drawLine(cubeVertices[1], cubeVertices[3])
                    drawLine(cubeVertices[2], cubeVertices[4])
                    drawLine(cubeVertices[6], cubeVertices[8])
                    drawLine(cubeVertices[5], cubeVertices[7])
                    drawQuad(cubeVertices[2], cubeVertices[4], cubeVertices[8], cubeVertices[6])
                    drawQuad(cubeVertices[1], cubeVertices[2], cubeVertices[4], cubeVertices[3])
                    drawQuad(cubeVertices[1], cubeVertices[5], cubeVertices[7], cubeVertices[3])
                    drawQuad(cubeVertices[5], cubeVertices[7], cubeVertices[8], cubeVertices[6])
                    
                    -- Top face
                    drawLine(cubeVertices[3], cubeVertices[4])
                    drawLine(cubeVertices[4], cubeVertices[8])
                    drawLine(cubeVertices[8], cubeVertices[7])
                    drawLine(cubeVertices[7], cubeVertices[3])
                    drawQuad(cubeVertices[3], cubeVertices[4], cubeVertices[8], cubeVertices[7])
                end
            end
        end
    end)
    
    table.insert(self.Connections, renderConn)
end

-- Module 4: Drawing Chams
local DrawingChams = setmetatable({}, {__index = ESPModule})
DrawingChams.__index = DrawingChams

function DrawingChams.new()
    local self = ESPModule.new("DrawingChams")
    setmetatable(self, DrawingChams)
    return self
end

function DrawingChams:Initialize()
    local camera = ESPLibrary.Camera
    local localPlayer = ESPLibrary.LocalPlayer
    local settings = ESPLibrary.Settings.DrawingChamsSettings
    
    local function newQuad(color)
        local quad = Drawing.new("Quad")
        quad.Visible = false
        quad.PointA = Vector2.new(0,0)
        quad.PointB = Vector2.new(0,0)
        quad.PointC = Vector2.new(0,0)
        quad.PointD = Vector2.new(0,0)
        quad.Color = color
        quad.Filled = true
        quad.Thickness = 1
        quad.Transparency = settings.Transparency
        return quad
    end
    
    local function colorize(color, lib)
        for _, v in pairs(lib) do
            v.Color = color
        end
    end
    
    local function setupPartESP(part, player)
        local quads = {
            quad1 = newQuad(settings.Color),
            quad2 = newQuad(settings.Color),
            quad3 = newQuad(settings.Color),
            quad4 = newQuad(settings.Color),
            quad5 = newQuad(settings.Color),
            quad6 = newQuad(settings.Color)
        }
        
        if not self.PlayerDrawings[player] then
            self.PlayerDrawings[player] = {}
        end
        table.insert(self.PlayerDrawings[player], quads)
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then
                for _, quad in pairs(quads) do
                    quad.Visible = false
                end
                return
            end
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and 
               player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild(part.Name) then
               
                local partPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local size_X = part.Size.X/2
                    local size_Y = part.Size.Y/2
                    local size_Z = part.Size.Z/2
                    
                    -- Calculate all corners
                    local top1 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-size_X, size_Y, -size_Z)).p)
                    local top2 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-size_X, size_Y, size_Z)).p)
                    local top3 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(size_X, size_Y, size_Z)).p)
                    local top4 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(size_X, size_Y, -size_Z)).p)
                    
                    local bottom1 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-size_X, -size_Y, -size_Z)).p)
                    local bottom2 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-size_X, -size_Y, size_Z)).p)
                    local bottom3 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(size_X, -size_Y, size_Z)).p)
                    local bottom4 = camera:WorldToViewportPoint((part.CFrame * CFrame.new(size_X, -size_Y, -size_Z)).p)
                    
                    -- Set quad points
                    quads.quad1.PointA = Vector2.new(top1.X, top1.Y)
                    quads.quad1.PointB = Vector2.new(top2.X, top2.Y)
                    quads.quad1.PointC = Vector2.new(top3.X, top3.Y)
                    quads.quad1.PointD = Vector2.new(top4.X, top4.Y)
                    
                    quads.quad2.PointA = Vector2.new(bottom1.X, bottom1.Y)
                    quads.quad2.PointB = Vector2.new(bottom2.X, bottom2.Y)
                    quads.quad2.PointC = Vector2.new(bottom3.X, bottom3.Y)
                    quads.quad2.PointD = Vector2.new(bottom4.X, bottom4.Y)
                    
                    quads.quad3.PointA = Vector2.new(top1.X, top1.Y)
                    quads.quad3.PointB = Vector2.new(top2.X, top2.Y)
                    quads.quad3.PointC = Vector2.new(bottom2.X, bottom2.Y)
                    quads.quad3.PointD = Vector2.new(bottom1.X, bottom1.Y)
                    
                    quads.quad4.PointA = Vector2.new(top2.X, top2.Y)
                    quads.quad4.PointB = Vector2.new(top3.X, top3.Y)
                    quads.quad4.PointC = Vector2.new(bottom3.X, bottom3.Y)
                    quads.quad4.PointD = Vector2.new(bottom2.X, bottom2.Y)
                    
                    quads.quad5.PointA = Vector2.new(top3.X, top3.Y)
                    quads.quad5.PointB = Vector2.new(top4.X, top4.Y)
                    quads.quad5.PointC = Vector2.new(bottom4.X, bottom4.Y)
                    quads.quad5.PointD = Vector2.new(bottom3.X, bottom3.Y)
                    
                    quads.quad6.PointA = Vector2.new(top4.X, top4.Y)
                    quads.quad6.PointB = Vector2.new(top1.X, top1.Y)
                    quads.quad6.PointC = Vector2.new(bottom1.X, bottom1.Y)
                    quads.quad6.PointD = Vector2.new(bottom4.X, bottom4.Y)
                    
                    -- Set colors
                    local color
                    if settings.TeamCheck then
                        if player.Team == localPlayer.Team then
                            color = settings.Green
                        else
                            color = settings.Red
                        end
                    elseif settings.TeamColor then
                        color = player.TeamColor.Color
                    else
                        color = settings.Color
                    end
                    
                    colorize(color, quads)
                    
                    -- Make visible
                    for _, quad in pairs(quads) do
                        quad.Visible = true
                    end
                else
                    for _, quad in pairs(quads) do
                        quad.Visible = false
                    end
                end
            else
                for _, quad in pairs(quads) do
                    quad.Visible = false
                end
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    local function setupPlayerESP(player)
        if not ShouldShowESP(player) then return end
        
        local character = player.Character
        if not character then return end
        
        repeat task.wait() until character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
        
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("MeshPart") or part.Name == "Head" or 
               part.Name == "Left Arm" or part.Name == "Right Arm" or 
               part.Name == "Right Leg" or part.Name == "Left Leg" or 
               part.Name == "Torso" then
                setupPartESP(part, player)
            end
        end
    end
    
    -- Setup existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= ESPLibrary.LocalPlayer then
            coroutine.wrap(setupPlayerESP)(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= ESPLibrary.LocalPlayer then
            coroutine.wrap(setupPlayerESP)(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
end

-- Module 5: Radar ESP
local Radar = setmetatable({}, {__index = ESPModule})
Radar.__index = Radar

function Radar.new()
    local self = ESPModule.new("Radar")
    setmetatable(self, Radar)
    return self
end

function Radar:Initialize()
    local settings = ESPLibrary.Settings.RadarSettings
    local localPlayer = ESPLibrary.LocalPlayer
    local camera = ESPLibrary.Camera
    
    -- Create radar background
    local function newCircle(transparency, color, radius, filled, thickness)
        local circle = Drawing.new("Circle")
        circle.Transparency = transparency
        circle.Color = color
        circle.Visible = false
        circle.Thickness = thickness
        circle.Position = Vector2.new(0, 0)
        circle.Radius = radius
        circle.NumSides = math.clamp(radius*55/100, 10, 75)
        circle.Filled = filled
        return circle
    end
    
    local radarBackground = newCircle(0.9, settings.Background, settings.Radius, true, 1)
    radarBackground.Visible = true
    radarBackground.Position = settings.Position
    table.insert(self.Drawings, radarBackground)
    
    local radarBorder = newCircle(0.75, settings.Border, settings.Radius, false, 3)
    radarBorder.Visible = true
    radarBorder.Position = settings.Position
    table.insert(self.Drawings, radarBorder)
    
    -- Health bar color lerp
    local healthBarLerp = LerpColorModule:Lerp(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))
    
    local function getRelative(pos)
        local char = localPlayer.Character
        if char and char.PrimaryPart then
            local primaryPart = char.PrimaryPart
            local cameraPos = Vector3.new(camera.CFrame.Position.X, primaryPart.Position.Y, camera.CFrame.Position.Z)
            local newCF = CFrame.new(primaryPart.Position, cameraPos)
            local r = newCF:PointToObjectSpace(pos)
            return r.X, r.Z
        end
        return 0, 0
    end
    
    local function createLocalPlayerDot()
        local triangle = Drawing.new("Triangle")
        triangle.Visible = true
        triangle.Thickness = 1
        triangle.Filled = true
        triangle.Color = settings.LocalDot
        triangle.PointA = settings.Position + Vector2.new(0, -6)
        triangle.PointB = settings.Position + Vector2.new(-3, 6)
        triangle.PointC = settings.Position + Vector2.new(3, 6)
        table.insert(self.Drawings, triangle)
        return triangle
    end
    
    local localPlayerDot = createLocalPlayerDot()
    
    local function placeDot(player)
        local playerDot = newCircle(1, settings.PlayerDot, 3, true, 1)
        table.insert(self.Drawings, playerDot)
        
        self.PlayerDrawings[player] = {playerDot}
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then
                playerDot.Visible = false
                return
            end
            
            local character = player.Character
            if character and character:FindFirstChildOfClass("Humanoid") and 
               character.PrimaryPart and character:FindFirstChildOfClass("Humanoid").Health > 0 then
               
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local scale = settings.Scale
                local relX, relZ = getRelative(character.PrimaryPart.Position)
                local newPos = settings.Position - Vector2.new(relX * scale, relZ * scale)
                
                if (newPos - settings.Position).magnitude < settings.Radius - 2 then
                    playerDot.Radius = 3
                    playerDot.Position = newPos
                    playerDot.Visible = true
                else
                    local dist = (settings.Position - newPos).magnitude
                    local calc = (settings.Position - newPos).unit * (dist - settings.Radius)
                    local inside = Vector2.new(newPos.X + calc.X, newPos.Y + calc.Y)
                    playerDot.Radius = 2
                    playerDot.Position = inside
                    playerDot.Visible = true
                end
                
                -- Set color
                local color = settings.PlayerDot
                if settings.TeamCheck then
                    if player.Team == localPlayer.Team then
                        color = settings.TeamColor
                    else
                        color = settings.EnemyColor
                    end
                end
                
                if settings.HealthColor then
                    color = healthBarLerp(humanoid.Health / humanoid.MaxHealth)
                end
                
                playerDot.Color = color
            else
                playerDot.Visible = false
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    -- Create dots for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            placeDot(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            placeDot(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
    
    -- Update radar position and properties
    local updateConn = RunService.RenderStepped:Connect(function()
        if not self.Enabled then return end
        
        radarBackground.Position = settings.Position
        radarBackground.Radius = settings.Radius
        radarBackground.Color = settings.Background
        
        radarBorder.Position = settings.Position
        radarBorder.Radius = settings.Radius
        radarBorder.Color = settings.Border
        
        if localPlayerDot then
            localPlayerDot.Color = settings.LocalDot
            localPlayerDot.PointA = settings.Position + Vector2.new(0, -6)
            localPlayerDot.PointB = settings.Position + Vector2.new(-3, 6)
            localPlayerDot.PointC = settings.Position + Vector2.new(3, 6)
        end
    end)
    
    table.insert(self.Connections, updateConn)
    
    -- Draggable radar
    if settings.Draggable then
        local inset = GuiService:GetGuiInset()
        local dragging = false
        local offset = Vector2.new(0, 0)
        
        local mouse = localPlayer:GetMouse()
        
        local inputBeganConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mousePos = Vector2.new(mouse.X, mouse.Y + inset.Y)
                if (mousePos - settings.Position).magnitude < settings.Radius then
                    offset = settings.Position - Vector2.new(mouse.X, mouse.Y)
                    dragging = true
                end
            end
        end)
        
        local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        local dragConn = RunService.RenderStepped:Connect(function()
            if dragging then
                settings.Position = Vector2.new(mouse.X, mouse.Y) + offset
            end
        end)
        
        table.insert(self.Connections, inputBeganConn)
        table.insert(self.Connections, inputEndedConn)
        table.insert(self.Connections, dragConn)
    end
end

-- Module 6: View Tracer
local ViewTracer = setmetatable({}, {__index = ESPModule})
ViewTracer.__index = ViewTracer

function ViewTracer.new()
    local self = ESPModule.new("ViewTracer")
    setmetatable(self, ViewTracer)
    return self
end

function ViewTracer:Initialize()
    local camera = ESPLibrary.Camera
    local localPlayer = ESPLibrary.LocalPlayer
    local settings = ESPLibrary.Settings.ViewTracerSettings
    
    local function setupPlayerTracer(player)
        if not ShouldShowESP(player) then return end
        
        local line = Drawing.new("Line")
        line.Visible = false
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(0, 0)
        line.Color = settings.Color
        line.Thickness = settings.Thickness
        line.Transparency = settings.Transparency
        
        self.PlayerDrawings[player] = {line}
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then
                line.Visible = false
                return
            end
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and 
               player.Character:FindFirstChild("HumanoidRootPart") and 
               player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("Head") then
               
                local headPos, onScreen = camera:WorldToViewportPoint(player.Character.Head.Position)
                if onScreen then
                    local offsetCFrame = CFrame.new(0, 0, -settings.Length)
                    local check = false
                    line.From = Vector2.new(headPos.X, headPos.Y)
                    
                    if settings.AutoThickness then
                        local distance = (localPlayer.Character.HumanoidRootPart.Position - 
                                         player.Character.HumanoidRootPart.Position).magnitude
                        local value = math.clamp(1/distance*100, 0.1, 3)
                        line.Thickness = value
                    end
                    
                    repeat
                        local dir = player.Character.Head.CFrame:ToWorldSpace(offsetCFrame)
                        offsetCFrame = offsetCFrame * CFrame.new(0, 0, settings.Smoothness)
                        local dirPos, visible = camera:WorldToViewportPoint(Vector3.new(dir.X, dir.Y, dir.Z))
                        if visible then
                            check = true
                            line.To = Vector2.new(dirPos.X, dirPos.Y)
                            line.Color = GetPlayerColor(player, settings)
                            line.Visible = true
                            offsetCFrame = CFrame.new(0, 0, -settings.Length)
                        end
                    until check == true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    -- Setup for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerTracer)(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerTracer)(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
end

-- Module 7: Skeleton ESP
local Skeleton = setmetatable({}, {__index = ESPModule})
Skeleton.__index = Skeleton

function Skeleton.new()
    local self = ESPModule.new("Skeleton")
    setmetatable(self, Skeleton)
    return self
end

function Skeleton:Initialize()
    local camera = ESPLibrary.Camera
    local localPlayer = ESPLibrary.LocalPlayer
    local settings = ESPLibrary.Settings.SkeletonSettings
    
    local function createLine()
        local line = Drawing.new("Line")
        line.Visible = false
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(0, 0)
        line.Color = settings.Color
        line.Thickness = settings.Thickness
        line.Transparency = 1
        return line
    end
    
    local function setupPlayerSkeleton(player)
        if not ShouldShowESP(player) then return end
        
        repeat task.wait() until player.Character and player.Character:FindFirstChild("Humanoid")
        
        local isR15 = player.Character.Humanoid.RigType == Enum.HumanoidRigType.R15
        local lines = {}
        
        if isR15 then
            lines = {
                Head_UpperTorso = createLine(),
                UpperTorso_LowerTorso = createLine(),
                UpperTorso_LeftUpperArm = createLine(),
                LeftUpperArm_LeftLowerArm = createLine(),
                LeftLowerArm_LeftHand = createLine(),
                UpperTorso_RightUpperArm = createLine(),
                RightUpperArm_RightLowerArm = createLine(),
                RightLowerArm_RightHand = createLine(),
                LowerTorso_LeftUpperLeg = createLine(),
                LeftUpperLeg_LeftLowerLeg = createLine(),
                LeftLowerLeg_LeftFoot = createLine(),
                LowerTorso_RightUpperLeg = createLine(),
                RightUpperLeg_RightLowerLeg = createLine(),
                RightLowerLeg_RightFoot = createLine()
            }
        else
            lines = {
                Head_Spine = createLine(),
                Spine = createLine(),
                LeftArm = createLine(),
                LeftArm_UpperTorso = createLine(),
                RightArm = createLine(),
                RightArm_UpperTorso = createLine(),
                LeftLeg = createLine(),
                LeftLeg_LowerTorso = createLine(),
                RightLeg = createLine(),
                RightLeg_LowerTorso = createLine()
            }
        end
        
        self.PlayerDrawings[player] = lines
        
        local function setVisibility(state)
            for _, line in pairs(lines) do
                line.Visible = state
            end
        end
        
        local function setColor(color)
            for _, line in pairs(lines) do
                line.Color = color
            end
        end
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then
                setVisibility(false)
                return
            end
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and 
               player.Character:FindFirstChild("HumanoidRootPart") and 
               player.Character.Humanoid.Health > 0 then
               
                local rootPos, visible = camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                if visible then
                    local color = GetPlayerColor(player, settings)
                    setColor(color)
                    
                    if isR15 then
                        -- R15 skeleton
                        if player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("UpperTorso") then
                            local headPos = camera:WorldToViewportPoint(player.Character.Head.Position)
                            local upperTorsoPos = camera:WorldToViewportPoint(player.Character.UpperTorso.Position)
                            local lowerTorsoPos = camera:WorldToViewportPoint(player.Character.LowerTorso.Position)
                            
                            lines.Head_UpperTorso.From = Vector2.new(headPos.X, headPos.Y)
                            lines.Head_UpperTorso.To = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                            
                            lines.UpperTorso_LowerTorso.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                            lines.UpperTorso_LowerTorso.To = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                            
                            -- Left arm
                            if player.Character:FindFirstChild("LeftUpperArm") and player.Character:FindFirstChild("LeftLowerArm") and player.Character:FindFirstChild("LeftHand") then
                                local leftUpperArmPos = camera:WorldToViewportPoint(player.Character.LeftUpperArm.Position)
                                local leftLowerArmPos = camera:WorldToViewportPoint(player.Character.LeftLowerArm.Position)
                                local leftHandPos = camera:WorldToViewportPoint(player.Character.LeftHand.Position)
                                
                                lines.UpperTorso_LeftUpperArm.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                                lines.UpperTorso_LeftUpperArm.To = Vector2.new(leftUpperArmPos.X, leftUpperArmPos.Y)
                                
                                lines.LeftUpperArm_LeftLowerArm.From = Vector2.new(leftUpperArmPos.X, leftUpperArmPos.Y)
                                lines.LeftUpperArm_LeftLowerArm.To = Vector2.new(leftLowerArmPos.X, leftLowerArmPos.Y)
                                
                                lines.LeftLowerArm_LeftHand.From = Vector2.new(leftLowerArmPos.X, leftLowerArmPos.Y)
                                lines.LeftLowerArm_LeftHand.To = Vector2.new(leftHandPos.X, leftHandPos.Y)
                            end
                            
                            -- Right arm
                            if player.Character:FindFirstChild("RightUpperArm") and player.Character:FindFirstChild("RightLowerArm") and player.Character:FindFirstChild("RightHand") then
                                local rightUpperArmPos = camera:WorldToViewportPoint(player.Character.RightUpperArm.Position)
                                local rightLowerArmPos = camera:WorldToViewportPoint(player.Character.RightLowerArm.Position)
                                local rightHandPos = camera:WorldToViewportPoint(player.Character.RightHand.Position)
                                
                                lines.UpperTorso_RightUpperArm.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                                lines.UpperTorso_RightUpperArm.To = Vector2.new(rightUpperArmPos.X, rightUpperArmPos.Y)
                                
                                lines.RightUpperArm_RightLowerArm.From = Vector2.new(rightUpperArmPos.X, rightUpperArmPos.Y)
                                lines.RightUpperArm_RightLowerArm.To = Vector2.new(rightLowerArmPos.X, rightLowerArmPos.Y)
                                
                                lines.RightLowerArm_RightHand.From = Vector2.new(rightLowerArmPos.X, rightLowerArmPos.Y)
                                lines.RightLowerArm_RightHand.To = Vector2.new(rightHandPos.X, rightHandPos.Y)
                            end
                            
                            -- Left leg
                            if player.Character:FindFirstChild("LeftUpperLeg") and player.Character:FindFirstChild("LeftLowerLeg") and player.Character:FindFirstChild("LeftFoot") then
                                local leftUpperLegPos = camera:WorldToViewportPoint(player.Character.LeftUpperLeg.Position)
                                local leftLowerLegPos = camera:WorldToViewportPoint(player.Character.LeftLowerLeg.Position)
                                local leftFootPos = camera:WorldToViewportPoint(player.Character.LeftFoot.Position)
                                
                                lines.LowerTorso_LeftUpperLeg.From = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                                lines.LowerTorso_LeftUpperLeg.To = Vector2.new(leftUpperLegPos.X, leftUpperLegPos.Y)
                                
                                lines.LeftUpperLeg_LeftLowerLeg.From = Vector2.new(leftUpperLegPos.X, leftUpperLegPos.Y)
                                lines.LeftUpperLeg_LeftLowerLeg.To = Vector2.new(leftLowerLegPos.X, leftLowerLegPos.Y)
                                
                                lines.LeftLowerLeg_LeftFoot.From = Vector2.new(leftLowerLegPos.X, leftLowerLegPos.Y)
                                lines.LeftLowerLeg_LeftFoot.To = Vector2.new(leftFootPos.X, leftFootPos.Y)
                            end
                            
                            -- Right leg
                            if player.Character:FindFirstChild("RightUpperLeg") and player.Character:FindFirstChild("RightLowerLeg") and player.Character:FindFirstChild("RightFoot") then
                                local rightUpperLegPos = camera:WorldToViewportPoint(player.Character.RightUpperLeg.Position)
                                local rightLowerLegPos = camera:WorldToViewportPoint(player.Character.RightLowerLeg.Position)
                                local rightFootPos = camera:WorldToViewportPoint(player.Character.RightFoot.Position)
                                
                                lines.LowerTorso_RightUpperLeg.From = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                                lines.LowerTorso_RightUpperLeg.To = Vector2.new(rightUpperLegPos.X, rightUpperLegPos.Y)
                                
                                lines.RightUpperLeg_RightLowerLeg.From = Vector2.new(rightUpperLegPos.X, rightUpperLegPos.Y)
                                lines.RightUpperLeg_RightLowerLeg.To = Vector2.new(rightLowerLegPos.X, rightLowerLegPos.Y)
                                
                                lines.RightLowerLeg_RightFoot.From = Vector2.new(rightLowerLegPos.X, rightLowerLegPos.Y)
                                lines.RightLowerLeg_RightFoot.To = Vector2.new(rightFootPos.X, rightFootPos.Y)
                            end
                            
                            setVisibility(true)
                        end
                    else
                        -- R6 skeleton
                        if player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("Torso") then
                            local headPos = camera:WorldToViewportPoint(player.Character.Head.Position)
                            local torso = player.Character.Torso
                            local torsoHeight = torso.Size.Y/2 - 0.2
                            
                            local upperTorsoPos = camera:WorldToViewportPoint((torso.CFrame * CFrame.new(0, torsoHeight, 0)).p)
                            local lowerTorsoPos = camera:WorldToViewportPoint((torso.CFrame * CFrame.new(0, -torsoHeight, 0)).p)
                            
                            lines.Head_Spine.From = Vector2.new(headPos.X, headPos.Y)
                            lines.Head_Spine.To = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                            
                            lines.Spine.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                            lines.Spine.To = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                            
                            -- Left arm
                            if player.Character:FindFirstChild("Left Arm") then
                                local leftArm = player.Character["Left Arm"]
                                local armHeight = leftArm.Size.Y/2 - 0.2
                                local leftUpperArmPos = camera:WorldToViewportPoint((leftArm.CFrame * CFrame.new(0, armHeight, 0)).p)
                                local leftLowerArmPos = camera:WorldToViewportPoint((leftArm.CFrame * CFrame.new(0, -armHeight, 0)).p)
                                
                                lines.LeftArm.From = Vector2.new(leftUpperArmPos.X, leftUpperArmPos.Y)
                                lines.LeftArm.To = Vector2.new(leftLowerArmPos.X, leftLowerArmPos.Y)
                                
                                lines.LeftArm_UpperTorso.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                                lines.LeftArm_UpperTorso.To = Vector2.new(leftUpperArmPos.X, leftUpperArmPos.Y)
                            end
                            
                            -- Right arm
                            if player.Character:FindFirstChild("Right Arm") then
                                local rightArm = player.Character["Right Arm"]
                                local armHeight = rightArm.Size.Y/2 - 0.2
                                local rightUpperArmPos = camera:WorldToViewportPoint((rightArm.CFrame * CFrame.new(0, armHeight, 0)).p)
                                local rightLowerArmPos = camera:WorldToViewportPoint((rightArm.CFrame * CFrame.new(0, -armHeight, 0)).p)
                                
                                lines.RightArm.From = Vector2.new(rightUpperArmPos.X, rightUpperArmPos.Y)
                                lines.RightArm.To = Vector2.new(rightLowerArmPos.X, rightLowerArmPos.Y)
                                
                                lines.RightArm_UpperTorso.From = Vector2.new(upperTorsoPos.X, upperTorsoPos.Y)
                                lines.RightArm_UpperTorso.To = Vector2.new(rightUpperArmPos.X, rightUpperArmPos.Y)
                            end
                            
                            -- Left leg
                            if player.Character:FindFirstChild("Left Leg") then
                                local leftLeg = player.Character["Left Leg"]
                                local legHeight = leftLeg.Size.Y/2 - 0.2
                                local leftUpperLegPos = camera:WorldToViewportPoint((leftLeg.CFrame * CFrame.new(0, legHeight, 0)).p)
                                local leftLowerLegPos = camera:WorldToViewportPoint((leftLeg.CFrame * CFrame.new(0, -legHeight, 0)).p)
                                
                                lines.LeftLeg.From = Vector2.new(leftUpperLegPos.X, leftUpperLegPos.Y)
                                lines.LeftLeg.To = Vector2.new(leftLowerLegPos.X, leftLowerLegPos.Y)
                                
                                lines.LeftLeg_LowerTorso.From = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                                lines.LeftLeg_LowerTorso.To = Vector2.new(leftUpperLegPos.X, leftUpperLegPos.Y)
                            end
                            
                            -- Right leg
                            if player.Character:FindFirstChild("Right Leg") then
                                local rightLeg = player.Character["Right Leg"]
                                local legHeight = rightLeg.Size.Y/2 - 0.2
                                local rightUpperLegPos = camera:WorldToViewportPoint((rightLeg.CFrame * CFrame.new(0, legHeight, 0)).p)
                                local rightLowerLegPos = camera:WorldToViewportPoint((rightLeg.CFrame * CFrame.new(0, -legHeight, 0)).p)
                                
                                lines.RightLeg.From = Vector2.new(rightUpperLegPos.X, rightUpperLegPos.Y)
                                lines.RightLeg.To = Vector2.new(rightLowerLegPos.X, rightLowerLegPos.Y)
                                
                                lines.RightLeg_LowerTorso.From = Vector2.new(lowerTorsoPos.X, lowerTorsoPos.Y)
                                lines.RightLeg_LowerTorso.To = Vector2.new(rightUpperLegPos.X, rightUpperLegPos.Y)
                            end
                            
                            setVisibility(true)
                        end
                    end
                else
                    setVisibility(false)
                end
            else
                setVisibility(false)
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    -- Setup for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerSkeleton)(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerSkeleton)(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
end

-- Module 8: Tracer Box Health
local TracerBoxHealth = setmetatable({}, {__index = ESPModule})
TracerBoxHealth.__index = TracerBoxHealth

function TracerBoxHealth.new()
    local self = ESPModule.new("TracerBoxHealth")
    setmetatable(self, TracerBoxHealth)
    return self
end

function TracerBoxHealth:Initialize()
    local camera = ESPLibrary.Camera
    local localPlayer = ESPLibrary.LocalPlayer
    local mouse = localPlayer:GetMouse()
    local settings = ESPLibrary.Settings.TracerBoxHealthSettings
    
    local function createQuad(thickness, color)
        local quad = Drawing.new("Quad")
        quad.Visible = false
        quad.PointA = Vector2.new(0,0)
        quad.PointB = Vector2.new(0,0)
        quad.PointC = Vector2.new(0,0)
        quad.PointD = Vector2.new(0,0)
        quad.Color = color
        quad.Filled = false
        quad.Thickness = thickness
        quad.Transparency = 1
        return quad
    end
    
    local function createLine(thickness, color)
        local line = Drawing.new("Line")
        line.Visible = false
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(0, 0)
        line.Color = color
        line.Thickness = thickness
        line.Transparency = 1
        return line
    end
    
    local function setupPlayerESP(player)
        if not ShouldShowESP(player) then return end
        
        local library = {
            blacktracer = createLine(settings.TracerThickness*2, Color3.fromRGB(0, 0, 0)),
            tracer = createLine(settings.TracerThickness, settings.TracerColor),
            black = createQuad(settings.BoxThickness*2, Color3.fromRGB(0, 0, 0)),
            box = createQuad(settings.BoxThickness, settings.BoxColor),
            healthbar = createLine(3, Color3.fromRGB(0, 0, 0)),
            greenhealth = createLine(1.5, Color3.fromRGB(0, 0, 0))
        }
        
        self.PlayerDrawings[player] = library
        
        local function setVisibility(state)
            for _, drawing in pairs(library) do
                drawing.Visible = state
            end
        end
        
        local function setColor(color, exclude)
            exclude = exclude or {}
            for name, drawing in pairs(library) do
                if not exclude[name] then
                    drawing.Color = color
                end
            end
        end
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then
                setVisibility(false)
                return
            end
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and 
               player.Character:FindFirstChild("HumanoidRootPart") and 
               player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("Head") then
               
                local rootPos, onScreen = camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                if onScreen then
                    local headPos = camera:WorldToViewportPoint(player.Character.Head.Position)
                    local distanceY = math.clamp((Vector2.new(headPos.X, headPos.Y) - Vector2.new(rootPos.X, rootPos.Y)).magnitude, 2, math.huge)
                    
                    -- Update box
                    library.box.PointA = Vector2.new(rootPos.X + distanceY, rootPos.Y - distanceY*2)
                    library.box.PointB = Vector2.new(rootPos.X - distanceY, rootPos.Y - distanceY*2)
                    library.box.PointC = Vector2.new(rootPos.X - distanceY, rootPos.Y + distanceY*2)
                    library.box.PointD = Vector2.new(rootPos.X + distanceY, rootPos.Y + distanceY*2)
                    
                    library.black.PointA = Vector2.new(rootPos.X + distanceY, rootPos.Y - distanceY*2)
                    library.black.PointB = Vector2.new(rootPos.X - distanceY, rootPos.Y - distanceY*2)
                    library.black.PointC = Vector2.new(rootPos.X - distanceY, rootPos.Y + distanceY*2)
                    library.black.PointD = Vector2.new(rootPos.X + distanceY, rootPos.Y + distanceY*2)
                    
                    -- Update tracer
                    if settings.Tracers then
                        if settings.TracerOrigin == "Middle" then
                            library.tracer.From = camera.ViewportSize*0.5
                            library.blacktracer.From = camera.ViewportSize*0.5
                        elseif settings.TracerOrigin == "Bottom" then
                            library.tracer.From = Vector2.new(camera.ViewportSize.X*0.5, camera.ViewportSize.Y)
                            library.blacktracer.From = Vector2.new(camera.ViewportSize.X*0.5, camera.ViewportSize.Y)
                        end
                        
                        if settings.TracerFollowMouse then
                            library.tracer.From = Vector2.new(mouse.X, mouse.Y+36)
                            library.blacktracer.From = Vector2.new(mouse.X, mouse.Y+36)
                        end
                        
                        library.tracer.To = Vector2.new(rootPos.X, rootPos.Y + distanceY*2)
                        library.blacktracer.To = Vector2.new(rootPos.X, rootPos.Y + distanceY*2)
                    else
                        library.tracer.Visible = false
                        library.blacktracer.Visible = false
                    end
                    
                    -- Update health bar
                    local d = (Vector2.new(rootPos.X - distanceY, rootPos.Y - distanceY*2) - 
                              Vector2.new(rootPos.X - distanceY, rootPos.Y + distanceY*2)).magnitude
                    local healthOffset = player.Character.Humanoid.Health/player.Character.Humanoid.MaxHealth * d
                    
                    library.greenhealth.From = Vector2.new(rootPos.X - distanceY - 4, rootPos.Y + distanceY*2)
                    library.greenhealth.To = Vector2.new(rootPos.X - distanceY - 4, rootPos.Y + distanceY*2 - healthOffset)
                    
                    library.healthbar.From = Vector2.new(rootPos.X - distanceY - 4, rootPos.Y + distanceY*2)
                    library.healthbar.To = Vector2.new(rootPos.X - distanceY - 4, rootPos.Y - distanceY*2)
                    
                    -- Health bar color
                    local green = Color3.fromRGB(0, 255, 0)
                    local red = Color3.fromRGB(255, 0, 0)
                    library.greenhealth.Color = red:lerp(green, player.Character.Humanoid.Health/player.Character.Humanoid.MaxHealth)
                    
                    -- Set colors based on settings
                    local color
                    if settings.TeamCheck then
                        if player.Team == localPlayer.Team then
                            color = settings.GreenColor
                        else
                            color = settings.RedColor
                        end
                    elseif settings.UseTeamColor then
                        color = player.TeamColor.Color
                    else
                        color = GetPlayerColor(player, settings)
                    end
                    
                    setColor(color, {healthbar = true, greenhealth = true, black = true, blacktracer = true})
                    
                    setVisibility(true)
                else
                    setVisibility(false)
                end
            else
                setVisibility(false)
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    -- Setup for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerESP)(player)
        end
    end
    
    -- Handle new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            coroutine.wrap(setupPlayerESP)(player)
        end
    end)
    
    table.insert(self.Connections, playerAddedConn)
end

-- Initialize all modules
ESPLibrary.Modules.OffscreenArrows = OffscreenArrows.new()
ESPLibrary.Modules.CornerBox = CornerBox.new()
ESPLibrary.Modules.Box3D = Box3D.new()
ESPLibrary.Modules.DrawingChams = DrawingChams.new()
ESPLibrary.Modules.Radar = Radar.new()
ESPLibrary.Modules.ViewTracer = ViewTracer.new()
ESPLibrary.Modules.Skeleton = Skeleton.new()
ESPLibrary.Modules.TracerBoxHealth = TracerBoxHealth.new()

-- Main library functions
function ESPLibrary:LoadModule(name)
    local module = self.Modules[name]
    if module and not module.Enabled then
        module:Enable()
        return true
    end
    return false
end

function ESPLibrary:UnloadModule(name)
    local module = self.Modules[name]
    if module and module.Enabled then
        module:Disable()
        return true
    end
    return false
end

function ESPLibrary:LoadAll()
    for name, module in pairs(self.Modules) do
        if self.Settings[name] or (self.Settings[name .. "Enabled"] == nil and self.Settings.Enabled) then
            module:Enable()
        end
    end
end

function ESPLibrary:UnloadAll()
    for _, module in pairs(self.Modules) do
        module:Disable()
    end
end

function ESPLibrary:Toggle()
    self.Settings.Enabled = not self.Settings.Enabled
    if self.Settings.Enabled then
        self:LoadAll()
    else
        self:UnloadAll()
    end
end

function ESPLibrary:ToggleModule(name)
    local module = self.Modules[name]
    if module then
        if module.Enabled then
            module:Disable()
        else
            module:Enable()
        end
        return module.Enabled
    end
    return false
end

function ESPLibrary:UpdateSettings(newSettings)
    for key, value in pairs(newSettings) do
        if self.Settings[key] ~= nil then
            if type(value) == "table" and type(self.Settings[key]) == "table" then
                for subKey, subValue in pairs(value) do
                    if self.Settings[key][subKey] ~= nil then
                        self.Settings[key][subKey] = subValue
                    end
                end
            else
                self.Settings[key] = value
            end
        end
    end
end

-- Auto-load enabled modules
coroutine.wrap(function()
    wait(1) -- Wait for game to load
    if ESPLibrary.Settings.Enabled then
        ESPLibrary:LoadAll()
    end
end)()

-- Return the complete library
return ESPLibrary
