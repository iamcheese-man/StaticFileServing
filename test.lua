local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

-- Configuration
local folderName = "ScareEff"
local soundFileName = "Moonlit-River-Park.mp3"
local soundURL = "https://iamcheese-man.github.io/StaticFileServing/Moonlit-River-Park.mp3"

-- Create the ScareEff folder in Delta workspace
if not isfolder(folderName) then
    makefolder(folderName)
end

-- Download the sound into ScareEff
local soundPath = folderName .. "/" .. soundFileName

local success, response = pcall(function()
    return request({
        Url = soundURL,
        Method = "GET"
    })
end)

if not success then
    error("Sound download failed: " .. tostring(response))
end

if response.StatusCode ~= 200 then
    error("Sound download failed with HTTP status: " .. tostring(response.StatusCode))
end

writefile(soundPath, response.Body)

-- Original lighting targets
local targetClockTime = 20
local targetBrightness = 0.2
local targetAmbient = Color3.fromRGB(30, 30, 30)
local targetOutdoorAmbient = Color3.fromRGB(30, 30, 30)
local targetFogColor = Color3.fromRGB(40, 40, 50)
local targetFogStart = 10
local targetFogEnd = 70

-- Stop all existing sounds in workspace
for _, sound in ipairs(workspace:GetDescendants()) do
    if sound:IsA("Sound") then
        sound:Stop()
    end
end

-- Create and play the horror sound
local horrorSound = Instance.new("Sound")
horrorSound.Name = "ScareSound"
horrorSound.SoundId = getcustomasset(soundPath)
horrorSound.Volume = 0
horrorSound.Looped = false
horrorSound.Parent = workspace
horrorSound:Play()

-- Fade duration
local fadeTime = 3
local elapsed = 0

-- Initial camera settings
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom
player.CameraMode = Enum.CameraMode.Classic

-- Tween lighting changes
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

-- Heartbeat loop: fade sound and transition camera
local connection

connection = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt

    local alpha = math.clamp(elapsed / fadeTime, 0, 1)

    -- Fade in sound volume
    horrorSound.Volume = alpha

    -- Transition from third person to first person
    if alpha < 0.5 then
        player.CameraMode = Enum.CameraMode.Classic
    else
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end

    if alpha >= 1 then
        connection:Disconnect()
    end
end)
