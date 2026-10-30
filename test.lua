local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

-- Original lighting targets
local targetClockTime = 20
local targetBrightness = 0.2
local targetAmbient = Color3.fromRGB(30, 30, 30)
local targetOutdoorAmbient = Color3.fromRGB(30, 30, 30)
local targetFogColor = Color3.fromRGB(40, 40, 50)
local targetFogStart = 10
local targetFogEnd = 70

-- Store original lighting for fade-in start
local originalClockTime = Lighting.ClockTime
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local originalFogColor = Lighting.FogColor
local originalFogStart = Lighting.FogStart
local originalFogEnd = Lighting.FogEnd

-- Stop all existing sounds in workspace
for _, sound in ipairs(workspace:GetDescendants()) do
    if sound:IsA("Sound") then
        sound:Stop()
    end
end

-- Create the horror sound and start at volume 
local horrorSound = Instance.new("Sound")
horrorSound.SoundId = getcustomasset("Moonlit-River-Park.mp3")
horrorSound.Volume = 0
horrorSound.Parent = workspace
horrorSound:Play()

-- Fade duration
local fadeTime = 3
local elapsed = 0

-- Initial camera type and subject for smooth transition
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom
player.CameraMode = Enum.CameraMode.Classic -- start in third person

-- Tween info for lighting changes
local tweenInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Linear)

local lightingGoals = {
    ClockTime = targetClockTime,
    Brightness = targetBrightness,
    Ambient = targetAmbient,
    OutdoorAmbient = targetOutdoorAmbient,
    FogColor = targetFogColor,
    FogStart = targetFogStart,
    FogEnd = targetFogEnd,
}

local tween = TweenService:Create(Lighting, tweenInfo, lightingGoals)
tween:Play()

-- Function for linear interpolation of camera field of view or other properties if needed
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Heartbeat loop to fade sound and switch camera mode gradually
local connection
connection = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    local alpha = math.clamp(elapsed / fadeTime, 0, 1)
    
    -- Fade in sound volume
    horrorSound.Volume = alpha
    
    -- Gradually switch camera mode from Classic (3rd person) to LockFirstPerson
    -- Since CameraMode is an enum, switch it at halfway point smoothly
    if alpha < 0.5 then
        player.CameraMode = Enum.CameraMode.Classic
    else
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end

    if alpha >= 1 then
        connection:Disconnect()
    end
end)
