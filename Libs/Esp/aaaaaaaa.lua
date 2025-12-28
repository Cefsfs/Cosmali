-- ESP Library by Blissful
-- All modules share the same heartbeat and FPS
-- Load with: loadstring(game:HttpGet("YOUR_RAW_URL"))()

local ESPLibrary = {}

-- External dependencies
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- Load external libraries
local ESP = loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-ESP-Library-9570", true))()
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
    CornerBox = {
        Thickness = 2,
        AutoThickness = true,
        TeamCheck = false,
        TeamColor = false
    },
    
    Radar = {
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
        TeamCheck = true
    },
    
    ViewTracer = {
        Color = Color3.fromRGB(255, 203, 138),
        Thickness = 1,
        Transparency = 1,
        AutoThickness = true,
        Length = 15,
        Smoothness = 0.2
    },
    
    TracerBoxHealth = {
        BoxColor = Color3.fromRGB(255, 0, 0),
        TracerColor = Color3.fromRGB(255, 0, 0),
        TracerThickness = 1,
        BoxThickness = 1,
        TracerOrigin = "Bottom",
        TracerFollowMouse = false,
        Tracers = true
    }
}

-- Internal state
ESPLibrary.Modules = {}
ESPLibrary.Connections = {}
ESPLibrary.ActivePlayers = {}

-- Shared utility functions
local function ShouldShowESP(player)
    local localPlayer = Players.LocalPlayer
    if not ESPLibrary.Settings.Enabled then return false end
    if player == localPlayer then return false end
    
    if ESPLibrary.Settings.TeamCheck then
        return player.Team ~= localPlayer.Team
    end
    
    return true
end

local function GetPlayerColor(player)
    local localPlayer = Players.LocalPlayer
    
    if ESPLibrary.Settings.UseTeamColor then
        return player.TeamColor.Color
    end
    
    if ESPLibrary.Settings.TeamCheck then
        return player.Team == localPlayer.Team and 
               ESPLibrary.Settings.FriendsColor or 
               ESPLibrary.Settings.EnemyColor
    end
    
    return ESPLibrary.Settings.DefaultColor
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
        PlayerData = {}
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
    -- To be overridden by child modules
end

function ESPModule:Cleanup()
    -- Clean up drawings
    for _, drawing in pairs(self.Drawings) do
        if drawing.Remove then
            drawing:Remove()
        end
    end
    
    -- Clean up connections
    for _, connection in pairs(self.Connections) do
        if connection.Disconnect then
            connection:Disconnect()
        end
    end
    
    self.Drawings = {}
    self.Connections = {}
    self.PlayerData = {}
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
    for _, player in ipairs(Players:GetPlayers()) do
        if ShouldShowESP(player) then
            ESP.Object:New(ESP:GetCharacter(player))
        end
    end
    
    local charAdded = ESP:CharacterAdded(Players.LocalPlayer):Connect(function(character)
        for _, player in ipairs(Players:GetPlayers()) do
            if ShouldShowESP(player) then
                ESP.Object:New(ESP:GetCharacter(player))
            end
        end
    end)
    
    table.insert(self.Connections, charAdded)
    
    local playerAdded = Players.PlayerAdded:Connect(function(player)
        if ShouldShowESP(player) then
            ESP.Object:New(ESP:GetCharacter(player))
            ESP:CharacterAdded(player):Connect(function(character)
                ESP.Object:New(character)
            end)
        end
    end)
    
    table.insert(self.Connections, playerAdded)
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
    local camera = Workspace.CurrentCamera
    local localPlayer = Players.LocalPlayer
    
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
        
        repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        
        local lines = {
            TL1 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            TL2 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            TR1 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            TR2 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            BL1 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            BL2 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            BR1 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness),
            BR2 = createLine(GetPlayerColor(player), ESPLibrary.Settings.CornerBox.Thickness)
        }
        
        local part = Instance.new("Part")
        part.Parent = Workspace
        part.Transparency = 1
        part.CanCollide = false
        part.Size = Vector3.new(1, 1, 1)
        
        self.PlayerData[player] = {Lines = lines, Part = part}
        
        local connection = RunService.RenderStepped:Connect(function()
            if not self.Enabled then return end
            
            local character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then
                for _, line in pairs(lines) do
                    line.Visible = false
                end
                return
            end
            
            local root = character.HumanoidRootPart
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            
            if onScreen then
                part.Size = Vector3.new(root.Size.X, root.Size.Y * 1.5, root.Size.Z)
                part.CFrame = CFrame.new(root.CFrame.Position, camera.CFrame.Position)
                
                local sizeX, sizeY = part.Size.X, part.Size.Y
                local tl = camera:WorldToViewportPoint((part.CFrame * CFrame.new(sizeX, sizeY, 0)).p)
                local tr = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-sizeX, sizeY, 0)).p)
                local bl = camera:WorldToViewportPoint((part.CFrame * CFrame.new(sizeX, -sizeY, 0)).p)
                local br = camera:WorldToViewportPoint((part.CFrame * CFrame.new(-sizeX, -sizeY, 0)).p)
                
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
                
                -- Update visibility
                for _, line in pairs(lines) do
                    line.Visible = true
                end
            else
                for _, line in pairs(lines) do
                    line.Visible = false
                end
            end
        end)
        
        table.insert(self.Connections, connection)
    end
    
    -- Initialize ESP for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updatePlayerESP(player)
        end
    end
    
    -- Handle new players
    local playerAdded = Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            updatePlayerESP(player)
        end
    end)
    
    table.insert(self.Connections, playerAdded)
end

function CornerBox:Cleanup()
    ESPModule.Cleanup(self)
    
    for _, data in pairs(self.PlayerData) do
        if data.Part then
            data.Part:Destroy()
        end
    end
end

-- Module 3: 3D Box ESP (simplified version)
local Box3D = setmetatable({}, {__index = ESPModule})
Box3D.__index = Box3D

function Box3D.new()
    local self = ESPModule.new("Box3D")
    setmetatable(self, Box3D)
    return self
end

-- Module 4: Radar ESP (simplified version)
local Radar = setmetatable({}, {__index = ESPModule})
Radar.__index = Radar

function Radar.new()
    local self = ESPModule.new("Radar")
    setmetatable(self, Radar)
    return self
end

-- Main library functions
function ESPLibrary:LoadModule(name)
    if not self.Modules[name] then return end
    self.Modules[name]:Enable()
end

function ESPLibrary:UnloadModule(name)
    if not self.Modules[name] then return end
    self.Modules[name]:Disable()
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

-- Initialize modules
ESPLibrary.Modules.OffscreenArrows = OffscreenArrows.new()
ESPLibrary.Modules.CornerBox = CornerBox.new()
ESPLibrary.Modules.Box3D = Box3D.new()
ESPLibrary.Modules.Radar = Radar.new()

-- Return the library
return ESPLibrary
