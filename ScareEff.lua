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

-- Create ScareEff folder

if not isfolder(folderName) then

    makefolder(folderName)

end

local soundPath = folderName .. "/" .. soundFileName

local soundAsset

if isfile(soundPath) then

    print("[ScareEff] Audio already exists. Skipping download.")

else

    print("[ScareEff] Downloading audio...")

    local requestSuccess, response = pcall(function()

        return request({

            Url = soundURL,

            Method = "GET"

        })

    end)

    if not requestSuccess then

        warn("[ScareEff] Request failed:", response)

        return

    end

    if response.StatusCode ~= 200 then

        warn("[ScareEff] HTTP error:", response.StatusCode)

        return

    end

    if not response.Body or #response.Body == 0 then

        warn("[ScareEff] Downloaded file is empty.")

        return

    end

    local writeSuccess, writeError = pcall(function()

        writefile(soundPath, response.Body)

    end)

    if not writeSuccess then

        warn("[ScareEff] Failed to save audio:", writeError)

        return

    end

    print("[ScareEff] Download successful!")

end

-- Load audio asset

local assetSuccess, assetResult = pcall(function()

    return getcustomasset(soundPath)

end)

if not assetSuccess then

    warn("[ScareEff] Failed to load audio asset:", assetResult)

    return

end

soundAsset = assetResult

print("[ScareEff] Initializing horror effects...")

-- Lighting targets
local targetClockTime = 20
local targetBrightness = 0.2
local targetAmbient = Color3.fromRGB(30, 30, 30)
local targetOutdoorAmbient = Color3.fromRGB(30, 30, 30)
local targetFogColor = Color3.fromRGB(40, 40, 50)
local targetFogStart = 10
local targetFogEnd = 70

-- Stop existing workspace sounds
for _, sound in ipairs(workspace:GetDescendants()) do
    if sound:IsA("Sound") then
        sound:Stop()
    end
end

-- Create horror sound
local horrorSound = Instance.new("Sound")
horrorSound.Name = "ScareSound"
horrorSound.SoundId = soundAsset
horrorSound.Volume = 0
horrorSound.Looped = false
horrorSound.Parent = workspace

-- Initial camera configuration
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom
player.CameraMode = Enum.CameraMode.Classic

-- Fade duration
local fadeTime = 3
local elapsed = 0

-- Lighting tween
local tweenInfo = TweenInfo.new(
    fadeTime,
    Enum.EasingStyle.Linear
)

local lightingGoals = {
    ClockTime = targetClockTime,
    Brightness = targetBrightness,
    Ambient = targetAmbient,
    OutdoorAmbient = targetOutdoorAmbient,
    FogColor = targetFogColor,
    FogStart = targetFogStart,
    FogEnd = targetFogEnd,
}

local tween = TweenService:Create(
    Lighting,
    tweenInfo,
    lightingGoals
)

-- Start effects
horrorSound:Play()
tween:Play()

-- Fade sound and transition camera
local connection

connection = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt

    local alpha = math.clamp(elapsed / fadeTime, 0, 1)

    horrorSound.Volume = alpha

    if alpha < 0.5 then
        player.CameraMode = Enum.CameraMode.Classic
    else
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end

    if alpha >= 1 then
        connection:Disconnect()
        print("[ScareEff] Horror effects initialized.")
    end
end)
