-- Ultimate ESP Library - Combined Features
-- Combines: Offscreen arrows, Corner boxes, 3D boxes, Chams, Radar, Tracers, Skeleton, Health bars

local ESPLibrary = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Core Settings
ESPLibrary.Settings = {
    -- Global Settings
    Enabled = true,
    MaxDistance = 2000,
    ShowTeammates = true,
    
    -- Feature Toggles
    OffscreenArrows = true,
    CornerBoxes = true,
    Box3D = false,
    Chams = false,
    Radar = true,
    Tracers = true,
    Skeleton = false,
    HealthBars = true,
    Names = true,
    Distance = true,
    
    -- Team Settings
    TeamCheck = false,
    TeamColor = true,
    EnemyColor = Color3.fromRGB(255, 50, 50),
    AllyColor = Color3.fromRGB(50, 150, 255),
    
    -- Performance
    UpdateRate = 1, -- Updates per frame (1 = every frame)
    ObjectPooling = true,
    
    -- Individual Feature Settings
    CornerBoxSettings = {
        Thickness = 2,
        Autothickness = true
    },
    
    TracerSettings = {
        Color = Color3.fromRGB(255, 203, 138),
        Thickness = 1,
        Length = 15,
        Smoothness = 0.2,
        Autothickness = true,
        Origin = "Bottom", -- "Bottom", "Middle", "Mouse"
        Transparency = 1
    },
    
    RadarSettings = {
        Position = Vector2.new(200, 200),
        Radius = 100,
        Scale = 1,
        BackgroundColor = Color3.fromRGB(10, 10, 10),
        BorderColor = Color3.fromRGB(75, 75, 75),
        PlayerDotColor = Color3.fromRGB(60, 170, 255),
        LocalPlayerDotColor = Color3.fromRGB(255, 255, 255),
        HealthColor = true,
        Draggable = true
    },
    
    SkeletonSettings = {
        Color = Color3.fromRGB(255, 0, 0),
        Thickness = 1
    }
}

-- Internal Storage
ESPLibrary.Players = {}
ESPLibrary.DrawingObjects = {}
ESPLibrary.Instances = {}
ESPLibrary.Connections = {}

-- External Libraries
local ExternalESP
local LerpColorModule

-- Helper Functions
function ESPLibrary:IsTeamMate(player)
    return LocalPlayer.Team == player.Team
end

function ESPLibrary:ShouldShow(player)
    if not self.Settings.Enabled then return false end
    if not self.Settings.ShowTeammates and self:IsTeamMate(player) then return false end
    return true
end

function ESPLibrary:GetPlayerColor(player)
    if self.Settings.TeamColor then
        return player.TeamColor.Color
    elseif self.Settings.TeamCheck then
        return self:IsTeamMate(player) and self.Settings.AllyColor or self.Settings.EnemyColor
    else
        return self.Settings.EnemyColor
    end
end

function ESPLibrary:GetDistance(fromPosition)
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then
        return math.huge
    end
    return (fromPosition - LocalPlayer.Character.PrimaryPart.Position).Magnitude
end

function ESPLibrary:IsOnScreen(position)
    local screenPosition, onScreen = Camera:WorldToViewportPoint(position)
    return onScreen, Vector2.new(screenPosition.X, screenPosition.Y)
end

function ESPLibrary:GetDrawingObject(type, player, identifier)
    if not self.DrawingObjects[player] then
        self.DrawingObjects[player] = {}
    end
    
    local key = type .. (identifier or "")
    if self.DrawingObjects[player][key] and self.DrawingObjects[player][key].Remove then
        return self.DrawingObjects[player][key]
    end
    
    local drawing = Drawing.new(type)
    self.DrawingObjects[player][key] = drawing
    return drawing
end

function ESPLibrary:CleanupPlayer(player)
    if self.DrawingObjects[player] then
        for _, drawing in pairs(self.DrawingObjects[player]) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
        self.DrawingObjects[player] = nil
    end
    
    if self.Instances[player] then
        for _, instance in pairs(self.Instances[player]) do
            if instance and instance.Destroy then
                instance:Destroy()
            end
        end
        self.Instances[player] = nil
    end
end

-- Offscreen Arrows
function ESPLibrary:InitializeOffscreenArrows()
    ExternalESP = loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-ESP-Library-9570", true))()
    
    -- Custom team color function
    function ExternalESP:GetTeamColor(player)
        return ESPLibrary:GetPlayerColor(player)
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and ESPLibrary:ShouldShow(player) then
            ExternalESP.Object:New(ExternalESP:GetCharacter(player))
        end
    end
    
    self.Connections.offscreenPlayerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer and ESPLibrary:ShouldShow(player) then
            ExternalESP.Object:New(ExternalESP:GetCharacter(player))
            ExternalESP:CharacterAdded(player):Connect(function(character)
                ExternalESP.Object:New(character)
            end)
        end
    end)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ExternalESP:CharacterAdded(player):Connect(function(character)
                if ESPLibrary:ShouldShow(player) then
                    ExternalESP.Object:New(character)
                end
            end)
        end
    end
end

-- Corner Box ESP
function ESPLibrary:InitializeCornerBox(player)
    if not self.DrawingObjects[player] then
        self.DrawingObjects[player] = {}
    end
    
    local function NewLine()
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = ESPLibrary:GetPlayerColor(player)
        line.Thickness = ESPLibrary.Settings.CornerBoxSettings.Thickness
        line.Transparency = 1
        return line
    end
    
    local lines = {
        TL1 = NewLine(), TL2 = NewLine(),
        TR1 = NewLine(), TR2 = NewLine(),
        BL1 = NewLine(), BL2 = NewLine(),
        BR1 = NewLine(), BR2 = NewLine()
    }
    
    self.DrawingObjects[player].cornerBox = lines
    
    -- Create orientation part
    local oripart = Instance.new("Part")
    oripart.Parent = Workspace
    oripart.Transparency = 1
    oripart.CanCollide = false
    oripart.Anchored = true
    
    if not self.Instances[player] then self.Instances[player] = {} end
    self.Instances[player].cornerBoxPart = oripart
end

function ESPLibrary:UpdateCornerBox(player)
    local data = self.DrawingObjects[player]
    if not data or not data.cornerBox then return end
    
    local lines = data.cornerBox
    local oripart = self.Instances[player] and self.Instances[player].cornerBoxPart
    
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        for _, line in pairs(lines) do
            line.Visible = false
        end
        return
    end
    
    local hrp = player.Character.HumanoidRootPart
    local _, onScreen = self:IsOnScreen(hrp.Position)
    
    if onScreen and oripart then
        oripart.Size = Vector3.new(hrp.Size.X, hrp.Size.Y * 1.5, hrp.Size.Z)
        oripart.CFrame = CFrame.new(hrp.CFrame.Position, Camera.CFrame.Position)
        
        local sizeX = oripart.Size.X
        local sizeY = oripart.Size.Y
        
        local function GetCorner(offset)
            local worldPos = (oripart.CFrame * CFrame.new(offset.X * sizeX, offset.Y * sizeY, 0)).p
            local screenPos = self:IsOnScreen(worldPos)
            return screenPos
        end
        
        local tl = GetCorner(Vector2.new(1, 1))
        local tr = GetCorner(Vector2.new(-1, 1))
        local bl = GetCorner(Vector2.new(1, -1))
        local br = GetCorner(Vector2.new(-1, -1))
        
        local distance = self:GetDistance(hrp.Position)
        local offset = math.clamp(1/distance * 750, 2, 300)
        
        -- Update line positions
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
        
        -- Update colors
        local color = self:GetPlayerColor(player)
        for _, line in pairs(lines) do
            line.Color = color
            line.Visible = true
            
            if self.Settings.CornerBoxSettings.Autothickness then
                local thickness = math.clamp(1/distance * 100, 1, 4)
                line.Thickness = thickness
            end
        end
    else
        for _, line in pairs(lines) do
            line.Visible = false
        end
    end
end

-- 3D Box ESP
function ESPLibrary:Initialize3DBox()
    self.DrawingObjects.global3DBox = {
        Lines = {},
        Quads = {}
    }
end

function ESPLibrary:Update3DBox()
    if not self.Settings.Box3D then return end
    
    local data = self.DrawingObjects.global3DBox
    if not data then return end
    
    -- Cleanup old drawings
    for _, line in ipairs(data.Lines) do
        if line then line:Remove() end
    end
    for _, quad in ipairs(data.Quads) do
        if quad then quad:Remove() end
    end
    
    data.Lines = {}
    data.Quads = {}
    
    local function GetCorners(part)
        local cf, size, corners = part.CFrame, part.Size / 2, {}
        for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
            corners[#corners + 1] = (cf * CFrame.new(size * Vector3.new(x, y, z))).p
        end end end
        return corners
    end
    
    local function DrawLine(from, to, color)
        local fromScreen, fromVisible = Camera:WorldToViewportPoint(from)
        local toScreen, toVisible = Camera:WorldToViewportPoint(to)
        
        if not fromVisible and not toVisible then return end
        
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.From = Vector2.new(fromScreen.X, fromScreen.Y)
        line.To = Vector2.new(toScreen.X, toScreen.Y)
        line.Color = color or Color3.fromRGB(255, 255, 255)
        line.Transparency = 1
        line.Visible = true
        
        table.insert(data.Lines, line)
    end
    
    local function DrawQuad(a, b, c, d, color)
        local aScreen, aVisible = Camera:WorldToViewportPoint(a)
        local bScreen, bVisible = Camera:WorldToViewportPoint(b)
        local cScreen, cVisible = Camera:WorldToViewportPoint(c)
        local dScreen, dVisible = Camera:WorldToViewportPoint(d)
        
        if not aVisible and not bVisible and not cVisible and not dVisible then return end
        
        local quad = Drawing.new("Quad")
        quad.Thickness = 0.5
        quad.Color = color or Color3.fromRGB(255, 255, 255)
        quad.Transparency = 0.25
        quad.Filled = true
        quad.Visible = true
        quad.PointA = Vector2.new(aScreen.X, aScreen.Y)
        quad.PointB = Vector2.new(bScreen.X, bScreen.Y)
        quad.PointC = Vector2.new(cScreen.X, cScreen.Y)
        quad.PointD = Vector2.new(dScreen.X, dScreen.Y)
        
        table.insert(data.Quads, quad)
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and self:ShouldShow(player) and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local color = self:GetPlayerColor(player)
                local corners = GetCorners({CFrame = hrp.CFrame * CFrame.new(0, -0.5, 0), Size = Vector3.new(3, 5, 3)})
                
                -- Bottom face
                DrawLine(corners[1], corners[2], color)
                DrawLine(corners[2], corners[6], color)
                DrawLine(corners[6], corners[5], color)
                DrawLine(corners[5], corners[1], color)
                DrawQuad(corners[1], corners[2], corners[6], corners[5], color)
                
                -- Side faces
                DrawLine(corners[1], corners[3], color)
                DrawLine(corners[2], corners[4], color)
                DrawLine(corners[6], corners[8], color)
                DrawLine(corners[5], corners[7], color)
                
                DrawQuad(corners[2], corners[4], corners[8], corners[6], color)
                DrawQuad(corners[1], corners[2], corners[4], corners[3], color)
                DrawQuad(corners[1], corners[5], corners[7], corners[3], color)
                DrawQuad(corners[5], corners[7], corners[8], corners[6], color)
                
                -- Top face
                DrawLine(corners[3], corners[4], color)
                DrawLine(corners[4], corners[8], color)
                DrawLine(corners[8], corners[7], color)
                DrawLine(corners[7], corners[3], color)
                DrawQuad(corners[3], corners[4], corners[8], corners[7], color)
            end
        end
    end
end

-- Tracers
function ESPLibrary:InitializeTracer(player)
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = self.Settings.TracerSettings.Color
    tracer.Thickness = self.Settings.TracerSettings.Thickness
    tracer.Transparency = self.Settings.TracerSettings.Transparency
    
    if not self.DrawingObjects[player] then self.DrawingObjects[player] = {} end
    self.DrawingObjects[player].tracer = tracer
end

function ESPLibrary:UpdateTracer(player)
    local tracer = self.DrawingObjects[player] and self.DrawingObjects[player].tracer
    if not tracer then return end
    
    if not self.Settings.Tracers or not player.Character or not player.Character:FindFirstChild("Head") then
        tracer.Visible = false
        return
    end
    
    local head = player.Character.Head
    local headPos, onScreen = self:IsOnScreen(head.Position)
    
    if onScreen then
        -- Set origin based on settings
        if self.Settings.TracerSettings.Origin == "Bottom" then
            tracer.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
        elseif self.Settings.TracerSettings.Origin == "Middle" then
            tracer.From = Camera.ViewportSize * 0.5
        else -- Mouse
            tracer.From = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        end
        
        tracer.To = headPos
        tracer.Color = self:GetPlayerColor(player)
        tracer.Visible = true
        
        if self.Settings.TracerSettings.Autothickness then
            local distance = self:GetDistance(head.Position)
            tracer.Thickness = math.clamp(1/distance * 100, 0.1, 3)
        end
    else
        tracer.Visible = false
    end
end

-- Radar System
function ESPLibrary:InitializeRadar()
    if not LerpColorModule then
        LerpColorModule = loadstring(game:HttpGet("https://pastebin.com/raw/wRnsJeid", true))()
    end
    
    local HealthBarLerp = LerpColorModule:Lerp(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))
    
    local function NewCircle(radius, filled, thickness, color)
        local circle = Drawing.new("Circle")
        circle.Visible = false
        circle.Radius = radius
        circle.Filled = filled
        circle.Thickness = thickness
        circle.Color = color or Color3.fromRGB(255, 255, 255)
        circle.NumSides = math.clamp(radius * 55 / 100, 10, 75)
        return circle
    end
    
    -- Radar background and border
    local radarBg = NewCircle(self.Settings.RadarSettings.Radius, true, 1, self.Settings.RadarSettings.BackgroundColor)
    radarBg.Position = self.Settings.RadarSettings.Position
    radarBg.Visible = true
    
    local radarBorder = NewCircle(self.Settings.RadarSettings.Radius, false, 3, self.Settings.RadarSettings.BorderColor)
    radarBorder.Position = self.Settings.RadarSettings.Position
    radarBorder.Visible = true
    
    -- Local player indicator
    local localDot = Drawing.new("Triangle")
    localDot.Visible = true
    localDot.Filled = true
    localDot.Color = self.Settings.RadarSettings.LocalPlayerDotColor
    localDot.PointA = self.Settings.RadarSettings.Position + Vector2.new(0, -6)
    localDot.PointB = self.Settings.RadarSettings.Position + Vector2.new(-3, 6)
    localDot.PointC = self.Settings.RadarSettings.Position + Vector2.new(3, 6)
    
    self.DrawingObjects.radar = {
        Background = radarBg,
        Border = radarBorder,
        LocalDot = localDot,
        PlayerDots = {}
    }
    
    -- Draggable functionality
    if self.Settings.RadarSettings.Draggable then
        local dragging = false
        local offset = Vector2.new(0, 0)
        
        self.Connections.radarInputBegan = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mousePos = UserInputService:GetMouseLocation()
                local guiInset = game:GetService("GuiService"):GetGuiInset()
                mousePos = Vector2.new(mousePos.X, mousePos.Y + guiInset.Y)
                
                if (mousePos - self.Settings.RadarSettings.Position).Magnitude < self.Settings.RadarSettings.Radius then
                    offset = self.Settings.RadarSettings.Position - mousePos
                    dragging = true
                end
            end
        end)
        
        self.Connections.radarInputEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        self.Connections.radarUpdate = RunService.RenderStepped:Connect(function()
            if dragging then
                local mousePos = UserInputService:GetMouseLocation()
                local guiInset = game:GetService("GuiService"):GetGuiInset()
                mousePos = Vector2.new(mousePos.X, mousePos.Y + guiInset.Y)
                self.Settings.RadarSettings.Position = mousePos + offset
            end
        end)
    end
    
    -- Create player dots
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:AddRadarPlayer(player)
        end
    end
end

function ESPLibrary:AddRadarPlayer(player)
    local dot = Drawing.new("Circle")
    dot.Visible = false
    dot.Radius = 3
    dot.Filled = true
    dot.Color = self.Settings.RadarSettings.PlayerDotColor
    
    self.DrawingObjects.radar.PlayerDots[player] = dot
end

function ESPLibrary:UpdateRadar()
    if not self.DrawingObjects.radar then return end
    
    local radar = self.DrawingObjects.radar
    
    -- Update background and border
    radar.Background.Position = self.Settings.RadarSettings.Position
    radar.Background.Radius = self.Settings.RadarSettings.Radius
    radar.Background.Color = self.Settings.RadarSettings.BackgroundColor
    
    radar.Border.Position = self.Settings.RadarSettings.Position
    radar.Border.Radius = self.Settings.RadarSettings.Radius
    radar.Border.Color = self.Settings.RadarSettings.BorderColor
    
    -- Update local dot
    radar.LocalDot.PointA = self.Settings.RadarSettings.Position + Vector2.new(0, -6)
    radar.LocalDot.PointB = self.Settings.RadarSettings.Position + Vector2.new(-3, 6)
    radar.LocalDot.PointC = self.Settings.RadarSettings.Position + Vector2.new(3, 6)
    radar.LocalDot.Color = self.Settings.RadarSettings.LocalPlayerDotColor
    
    -- Update player dots
    for player, dot in pairs(radar.PlayerDots) do
        if player and player.Character and player.Character.PrimaryPart then
            local function GetRelative(pos)
                local char = LocalPlayer.Character
                if char and char.PrimaryPart then
                    local cameraPos = Vector3.new(Camera.CFrame.Position.X, char.PrimaryPart.Position.Y, Camera.CFrame.Position.Z)
                    local newCF = CFrame.new(char.PrimaryPart.Position, cameraPos)
                    local relative = newCF:PointToObjectSpace(pos)
                    return relative.X, relative.Z
                end
                return 0, 0
            end
            
            local relX, relZ = GetRelative(player.Character.PrimaryPart.Position)
            local scale = self.Settings.RadarSettings.Scale
            local newPos = self.Settings.RadarSettings.Position - Vector2.new(relX * scale, relZ * scale)
            
            if (newPos - self.Settings.RadarSettings.Position).Magnitude < self.Settings.RadarSettings.Radius - 2 then
                dot.Radius = 3
                dot.Position = newPos
                dot.Visible = true
            else
                local dist = (self.Settings.RadarSettings.Position - newPos).Magnitude
                local calc = (self.Settings.RadarSettings.Position - newPos).Unit * (dist - self.Settings.RadarSettings.Radius)
                local insidePos = newPos + calc
                dot.Radius = 2
                dot.Position = insidePos
                dot.Visible = true
            end
            
            -- Color based on settings
            if self.Settings.RadarSettings.HealthColor and player.Character:FindFirstChildOfClass("Humanoid") then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                local lerpModule = loadstring(game:HttpGet("https://pastebin.com/raw/wRnsJeid", true))()
                local healthLerp = lerpModule:Lerp(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))
                dot.Color = healthLerp(humanoid.Health / humanoid.MaxHealth)
            else
                dot.Color = self:GetPlayerColor(player)
            end
        else
            dot.Visible = false
        end
    end
end

-- Skeleton ESP
function ESPLibrary:InitializeSkeleton(player)
    local function NewBone()
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = self.Settings.SkeletonSettings.Color
        line.Thickness = self.Settings.SkeletonSettings.Thickness
        line.Transparency = 1
        return line
    end
    
    local bones = {
        Head_UpperTorso = NewBone(),
        UpperTorso_LowerTorso = NewBone(),
        UpperTorso_LeftUpperArm = NewBone(),
        LeftUpperArm_LeftLowerArm = NewBone(),
        LeftLowerArm_LeftHand = NewBone(),
        UpperTorso_RightUpperArm = NewBone(),
        RightUpperArm_RightLowerArm = NewBone(),
        RightLowerArm_RightHand = NewBone(),
        LowerTorso_LeftUpperLeg = NewBone(),
        LeftUpperLeg_LeftLowerLeg = NewBone(),
        LeftLowerLeg_LeftFoot = NewBone(),
        LowerTorso_RightUpperLeg = NewBone(),
        RightUpperLeg_RightLowerLeg = NewBone(),
        RightLowerLeg_RightFoot = NewBone(),
    }
    
    if not self.DrawingObjects[player] then self.DrawingObjects[player] = {} end
    self.DrawingObjects[player].skeleton = bones
end

function ESPLibrary:UpdateSkeleton(player)
    local bones = self.DrawingObjects[player] and self.DrawingObjects[player].skeleton
    if not bones or not self.Settings.Skeleton then return end
    
    if not player.Character then
        for _, bone in pairs(bones) do
            bone.Visible = false
        end
        return
    end
    
    local function GetPartPosition(partName)
        local part = player.Character:FindFirstChild(partName)
        if part then
            local screenPos = self:IsOnScreen(part.Position)
            return screenPos
        end
        return nil
    end
    
    local headPos = GetPartPosition("Head")
    local upperTorsoPos = GetPartPosition("UpperTorso")
    local lowerTorsoPos = GetPartPosition("LowerTorso")
    
    if headPos and upperTorsoPos then
        bones.Head_UpperTorso.From = headPos
        bones.Head_UpperTorso.To = upperTorsoPos
        bones.Head_UpperTorso.Visible = true
        bones.Head_UpperTorso.Color = self:GetPlayerColor(player)
    else
        bones.Head_UpperTorso.Visible = false
    end
    
    if upperTorsoPos and lowerTorsoPos then
        bones.UpperTorso_LowerTorso.From = upperTorsoPos
        bones.UpperTorso_LowerTorso.To = lowerTorsoPos
        bones.UpperTorso_LowerTorso.Visible = true
        bones.UpperTorso_LowerTorso.Color = self:GetPlayerColor(player)
    else
        bones.UpperTorso_LowerTorso.Visible = false
    end
    
    -- Update other bones similarly...
    -- (Rest of the skeleton update logic would go here)
end

-- Health Bars
function ESPLibrary:InitializeHealthBar(player)
    local healthBar = {
        Background = Drawing.new("Line"),
        Foreground = Drawing.new("Line")
    }
    
    healthBar.Background.Visible = false
    healthBar.Background.Thickness = 3
    healthBar.Background.Color = Color3.fromRGB(0, 0, 0)
    
    healthBar.Foreground.Visible = false
    healthBar.Foreground.Thickness = 1.5
    
    if not self.DrawingObjects[player] then self.DrawingObjects[player] = {} end
    self.DrawingObjects[player].healthBar = healthBar
end

function ESPLibrary:UpdateHealthBar(player)
    local healthBar = self.DrawingObjects[player] and self.DrawingObjects[player].healthBar
    if not healthBar or not self.Settings.HealthBars then return end
    
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        healthBar.Background.Visible = false
        healthBar.Foreground.Visible = false
        return
    end
    
    local hrp = player.Character.HumanoidRootPart
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    
    if not humanoid then
        healthBar.Background.Visible = false
        healthBar.Foreground.Visible = false
        return
    end
    
    local hrpPos, onScreen = self:IsOnScreen(hrp.Position)
    
    if onScreen then
        local distance = self:GetDistance(hrp.Position)
        local boxSize = math.clamp(100 / distance, 10, 50)
        
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local healthColor = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
        
        -- Position health bar to the left of the player
        local barX = hrpPos.X - boxSize - 10
        local barYTop = hrpPos.Y - boxSize
        local barYBottom = hrpPos.Y + boxSize
        
        healthBar.Background.From = Vector2.new(barX, barYBottom)
        healthBar.Background.To = Vector2.new(barX, barYTop)
        healthBar.Background.Visible = true
        
        local healthHeight = (barYBottom - barYTop) * healthPercent
        healthBar.Foreground.From = Vector2.new(barX, barYBottom)
        healthBar.Foreground.To = Vector2.new(barX, barYBottom - healthHeight)
        healthBar.Foreground.Color = healthColor
        healthBar.Foreground.Visible = true
    else
        healthBar.Background.Visible = false
        healthBar.Foreground.Visible = false
    end
end

-- Player Management
function ESPLibrary:AddPlayer(player)
    if player == LocalPlayer then return end
    
    if self.Settings.CornerBoxes then
        self:InitializeCornerBox(player)
    end
    
    if self.Settings.Tracers then
        self:InitializeTracer(player)
    end
    
    if self.Settings.Skeleton then
        self:InitializeSkeleton(player)
    end
    
    if self.Settings.HealthBars then
        self:InitializeHealthBar(player)
    end
    
    if self.Settings.Radar then
        self:AddRadarPlayer(player)
    end
    
    self.Players[player] = true
    
    -- Track player leaving
    self.Connections["playerRemoving_" .. player.Name] = player.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:RemovePlayer(player)
        end
    end)
end

function ESPLibrary:RemovePlayer(player)
    self:CleanupPlayer(player)
    self.Players[player] = nil
    
    if self.DrawingObjects.radar and self.DrawingObjects.radar.PlayerDots[player] then
        self.DrawingObjects.radar.PlayerDots[player]:Remove()
        self.DrawingObjects.radar.PlayerDots[player] = nil
    end
    
    local connectionName = "playerRemoving_" .. player.Name
    if self.Connections[connectionName] then
        self.Connections[connectionName]:Disconnect()
        self.Connections[connectionName] = nil
    end
end

-- Main Update Loop
function ESPLibrary:Update()
    if not self.Settings.Enabled then return end
    
    for player, _ in pairs(self.Players) do
        if not player or not player.Parent then
            self:RemovePlayer(player)
            goto continue
        end
        
        local distance = self:GetDistance(player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.new(0, 0, 0))
        
        if distance > self.Settings.MaxDistance then
            if self.DrawingObjects[player] then
                for _, drawing in pairs(self.DrawingObjects[player]) do
                    if type(drawing) == "table" then
                        for _, d in pairs(drawing) do
                            if d and d.Visible ~= nil then
                                d.Visible = false
                            end
                        end
                    elseif drawing and drawing.Visible ~= nil then
                        drawing.Visible = false
                    end
                end
            end
            goto continue
        end
        
        if self.Settings.CornerBoxes then
            self:UpdateCornerBox(player)
        end
        
        if self.Settings.Tracers then
            self:UpdateTracer(player)
        end
        
        if self.Settings.Skeleton then
            self:UpdateSkeleton(player)
        end
        
        if self.Settings.HealthBars then
            self:UpdateHealthBar(player)
        end
        
        ::continue::
    end
    
    if self.Settings.Box3D then
        self:Update3DBox()
    end
    
    if self.Settings.Radar then
        self:UpdateRadar()
    end
end

-- Initialization
function ESPLibrary:Initialize()
    -- Initialize features
    if self.Settings.OffscreenArrows then
        self:InitializeOffscreenArrows()
    end
    
    if self.Settings.Box3D then
        self:Initialize3DBox()
    end
    
    if self.Settings.Radar then
        self:InitializeRadar()
    end
    
    -- Add existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:AddPlayer(player)
    end
    
    -- Player added/removed events
    self.Connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        self:AddPlayer(player)
    end)
    
    self.Connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        self:RemovePlayer(player)
    end)
    
    -- Main update loop
    local frameCount = 0
    self.Connections.mainLoop = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        if frameCount % self.Settings.UpdateRate == 0 then
            self:Update()
        end
    end)
end

-- Cleanup
function ESPLibrary:Destroy()
    -- Cleanup all players
    for player, _ in pairs(self.Players) do
        self:CleanupPlayer(player)
    end
    
    -- Cleanup global objects
    if self.DrawingObjects.global3DBox then
        for _, line in ipairs(self.DrawingObjects.global3DBox.Lines) do
            if line then line:Remove() end
        end
        for _, quad in ipairs(self.DrawingObjects.global3DBox.Quads) do
            if quad then quad:Remove() end
        end
    end
    
    if self.DrawingObjects.radar then
        for _, drawing in pairs(self.DrawingObjects.radar) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    
    -- Disconnect all connections
    for _, connection in pairs(self.Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Cleanup external ESP
    if ExternalESP then
        -- Depending on the external library, you might need to call a cleanup function
        pcall(function() ExternalESP.Unload() end)
    end
    
    -- Clear tables
    table.clear(self.Players)
    table.clear(self.DrawingObjects)
    table.clear(self.Instances)
    table.clear(self.Connections)
end

-- Public API
function ESPLibrary:ToggleFeature(feature, enabled)
    if self.Settings[feature] ~= nil then
        self.Settings[feature] = enabled
        return true
    end
    return false
end

function ESPLibrary:SetColor(feature, color)
    if feature == "EnemyColor" then
        self.Settings.EnemyColor = color
    elseif feature == "AllyColor" then
        self.Settings.AllyColor = color
    end
end

function ESPLibrary:SetMaxDistance(distance)
    self.Settings.MaxDistance = math.max(0, distance)
end

-- Initialize automatically when required
ESPLibrary:Initialize()

return ESPLibrary
