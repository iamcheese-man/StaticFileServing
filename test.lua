
--[[
    Executor Workspace Audio Browser
    Scans the executor's "workspace" directory recursively.
    Lists audio files and attempts playback when clicked.

    Required executor APIs:
        listfiles
        isfolder
        getcustomasset or getsynasset
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ListFiles = listfiles
local IsFolder = isfolder
local GetAsset = getcustomasset or getsynasset

assert(type(ListFiles) == "function", "Executor requires listfiles")
assert(type(IsFolder) == "function", "Executor requires isfolder")
assert(type(GetAsset) == "function", "Executor requires getcustomasset or getsynasset")

local ROOT = "workspace"

local AUDIO_EXTENSIONS = {
    mp3 = true,
    wav = true,
    ogg = true,
    flac = true,
    m4a = true,
    aac = true,
    mp4 = true,
    wma = true,
    opus = true,
    aiff = true,
    aif = true,
    mid = true,
    midi = true,
}

-- Remove any previous GUI.
local previous = PlayerGui:FindFirstChild("ExecutorAudioBrowser")
if previous then
    previous:Destroy()
end

-- State.
local currentSound = nil
local currentSoundEnded = nil
local scanGeneration = 0
local playbackGeneration = 0

-- Main GUI.
local gui = Instance.new("ScreenGui")
gui.Name = "ExecutorAudioBrowser"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(320, 360)
main.Position = UDim2.new(0.5, -160, 0.5, -180)
main.BackgroundColor3 = Color3.fromRGB(23, 24, 31)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 9)
mainCorner.Parent = main

-- Drag detector is attached directly to the main GUI frame.
local dragDetector = Instance.new("UIDragDetector")
dragDetector.Parent = main

-- Title.
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(0, 0)
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
title.BorderSizePixel = 0
title.Text = "  Audio Browser"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 9)
titleCorner.Parent = title

-- Status.
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(9, 39)
status.Size = UDim2.new(1, -18, 0, 20)
status.BackgroundTransparency = 1
status.Text = "Initializing..."
status.TextColor3 = Color3.fromRGB(175, 180, 195)
status.TextSize = 10
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = main

-- Refresh button.
local refresh = Instance.new("TextButton")
refresh.Name = "Refresh"
refresh.Position = UDim2.new(1, -148, 0, 5)
refresh.Size = UDim2.fromOffset(65, 26)
refresh.BackgroundColor3 = Color3.fromRGB(60, 105, 195)
refresh.BorderSizePixel = 0
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.new(1, 1, 1)
refresh.TextSize = 11
refresh.Font = Enum.Font.GothamBold
refresh.Parent = main

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 5)
refreshCorner.Parent = refresh

-- Stop button.
local stop = Instance.new("TextButton")
stop.Name = "Stop"
stop.Position = UDim2.new(1, -78, 0, 5)
stop.Size = UDim2.fromOffset(70, 26)
stop.BackgroundColor3 = Color3.fromRGB(170, 55, 65)
stop.BorderSizePixel = 0
stop.Text = "Stop Audio"
stop.TextColor3 = Color3.new(1, 1, 1)
stop.TextSize = 11
stop.Font = Enum.Font.GothamBold
stop.Parent = main

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 5)
stopCorner.Parent = stop

-- Audio file list.
local scrolling = Instance.new("ScrollingFrame")
scrolling.Name = "AudioFiles"
scrolling.Position = UDim2.fromOffset(8, 64)
scrolling.Size = UDim2.new(1, -16, 1, -72)
scrolling.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
scrolling.BorderSizePixel = 0
scrolling.ScrollBarThickness = 5
scrolling.ScrollBarImageColor3 = Color3.fromRGB(100, 105, 125)
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
scrolling.ScrollingDirection = Enum.ScrollingDirection.Y
scrolling.Parent = main

local scrollingCorner = Instance.new("UICorner")
scrollingCorner.CornerRadius = UDim.new(0, 6)
scrollingCorner.Parent = scrolling

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingBottom = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.Parent = scrolling

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scrolling

-- Playback management.
local function stopAudio(silent)
    playbackGeneration += 1

    if currentSoundEnded then
        currentSoundEnded:Disconnect()
        currentSoundEnded = nil
    end

    if currentSound then
        local oldSound = currentSound
        currentSound = nil

        pcall(function()
            oldSound:Stop()
            oldSound:Destroy()
        end)
    end

    if not silent and gui.Parent then
        status.Text = "Playback stopped"
    end
end

-- File helpers.
local function getExtension(path)
    local filename = path:match("[^/\\]+$") or path
    local extension = filename:match("%.([^%.]+)$")

    if extension then
        return extension:lower()
    end

    return nil
end

local function getFilename(path)
    return path:match("[^/\\]+$") or path
end

-- Recursive executor filesystem scan.
local function scanDirectory(directory, results, visited, depth)
    if depth > 30 then
        return
    end

    local ok, files = pcall(ListFiles, directory)

    if not ok or type(files) ~= "table" then
        return
    end

    for _, path in ipairs(files) do
        if type(path) == "string" then
            local normalized = path:gsub("\\", "/")

            if not visited[normalized] then
                visited[normalized] = true

                local folderOK, folder = pcall(IsFolder, path)

                if folderOK and folder then
                    scanDirectory(path, results, visited, depth + 1)
                else
                    local extension = getExtension(path)

                    if extension and AUDIO_EXTENSIONS[extension] then
                        table.insert(results, path)
                    end
                end
            end
        end
    end
end

-- Play a selected local file through the executor asset API.
local function playFile(path)
    stopAudio(true)

    local thisPlayback = playbackGeneration
    status.Text = "Loading: " .. getFilename(path)

    task.spawn(function()
        local ok, assetOrError = pcall(GetAsset, path)

        if thisPlayback ~= playbackGeneration or not gui.Parent then
            return
        end

        if not ok or type(assetOrError) ~= "string" then
            status.Text = "Asset error: " .. tostring(assetOrError)
            return
        end

        local sound = Instance.new("Sound")
        sound.Name = "ExecutorLocalAudio"
        sound.SoundId = assetOrError
        sound.Volume = 1
        sound.Looped = false
        sound.Parent = SoundService

        currentSound = sound
        status.Text = "Preparing: " .. getFilename(path)

        local loadOK, loadError = pcall(function()
            sound:Play()
        end)

        if not loadOK then
            if currentSound == sound then
                currentSound = nil
            end

            sound:Destroy()
            status.Text = "Playback error: " .. tostring(loadError)
            return
        end

        if thisPlayback ~= playbackGeneration or not gui.Parent then
            if currentSound == sound then
                currentSound = nil
            end

            sound:Destroy()
            return
        end

        status.Text = "Playing: " .. getFilename(path)

        currentSoundEnded = sound.Ended:Connect(function()
            if currentSound == sound then
                currentSound = nil
                status.Text = "Finished: " .. getFilename(path)
            end

            if currentSoundEnded then
                currentSoundEnded:Disconnect()
                currentSoundEnded = nil
            end

            sound:Destroy()
        end)
    end)
end

-- Remove old entries.
local function clearList()
    for _, child in ipairs(scrolling:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Add one clickable audio file entry.
local function addFile(path, index)
    local filename = getFilename(path)

    local button = Instance.new("TextButton")
    button.Name = "AudioFile_" .. index
    button.Size = UDim2.new(1, -4, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(37, 39, 51)
    button.BorderSizePixel = 0
    button.Text = ""
    button.LayoutOrder = index
    button.AutoButtonColor = true
    button.Parent = scrolling

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Filename"
    nameLabel.Position = UDim2.fromOffset(7, 2)
    nameLabel.Size = UDim2.new(1, -14, 0, 18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "▶  " .. filename
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = button

    local pathLabel = Instance.new("TextLabel")
    pathLabel.Name = "FilePath"
    pathLabel.Position = UDim2.fromOffset(7, 20)
    pathLabel.Size = UDim2.new(1, -14, 0, 15)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Text = path
    pathLabel.TextColor3 = Color3.fromRGB(155, 160, 180)
    pathLabel.TextSize = 9
    pathLabel.Font = Enum.Font.Code
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
    pathLabel.Parent = button

    button.Activated:Connect(function()
        playFile(path)
    end)
end

-- Refresh the audio library.
local function refreshFiles()
    scanGeneration += 1
    local thisScan = scanGeneration

    clearList()
    status.Text = "Scanning executor workspace..."

    task.spawn(function()
        local results = {}

        scanDirectory(ROOT, results, {}, 0)

        if thisScan ~= scanGeneration or not gui.Parent then
            return
        end

        table.sort(results, function(a, b)
            return a:lower() < b:lower()
        end)

        for index, path in ipairs(results) do
            if thisScan ~= scanGeneration or not gui.Parent then
                return
            end

            addFile(path, index)
        end

        status.Text = string.format(
            "%d audio file(s) found",
            #results
        )
    end)
end

refresh.Activated:Connect(refreshFiles)
stop.Activated:Connect(function()
    stopAudio(false)
end)

gui.Destroying:Connect(function()
    stopAudio(true)
end)

-- Initial scan.
refreshFiles()
