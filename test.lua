
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local listfiles = listfiles
local isfolder = isfolder
local getasset = getcustomasset or getsynasset

assert(type(listfiles) == "function", "Executor requires listfiles")
assert(type(isfolder) == "function", "Executor requires isfolder")
assert(type(getasset) == "function", "Executor requires getcustomasset or getsynasset")

local ROOT = ""

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

local previous = PlayerGui:FindFirstChild("ExecutorAudioBrowser")
if previous then
    previous:Destroy()
end

local currentSound
local playbackGeneration = 0
local scanGeneration = 0

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
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 9)

-- Directly attached to the main frame.
local dragDetector = Instance.new("UIDragDetector")
dragDetector.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
title.BorderSizePixel = 0
title.Text = "  Audio Browser"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

Instance.new("UICorner", title).CornerRadius = UDim.new(0, 9)

local refresh = Instance.new("TextButton")
refresh.Name = "Refresh"
refresh.Position = UDim2.new(1, -148, 0, 5)
refresh.Size = UDim2.fromOffset(65, 26)
refresh.BackgroundColor3 = Color3.fromRGB(60, 105, 195)
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.new(1, 1, 1)
refresh.TextSize = 11
refresh.Font = Enum.Font.GothamBold
refresh.Parent = main

Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 5)

local stop = Instance.new("TextButton")
stop.Name = "Stop"
stop.Position = UDim2.new(1, -78, 0, 5)
stop.Size = UDim2.fromOffset(70, 26)
stop.BackgroundColor3 = Color3.fromRGB(170, 55, 65)
stop.Text = "Stop"
stop.TextColor3 = Color3.new(1, 1, 1)
stop.TextSize = 11
stop.Font = Enum.Font.GothamBold
stop.Parent = main

Instance.new("UICorner", stop).CornerRadius = UDim.new(0, 5)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(9, 39)
status.Size = UDim2.new(1, -18, 0, 20)
status.BackgroundTransparency = 1
status.Text = "Scanning sandbox..."
status.TextColor3 = Color3.fromRGB(175, 180, 195)
status.TextSize = 10
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = main

local scrolling = Instance.new("ScrollingFrame")
scrolling.Name = "AudioFiles"
scrolling.Position = UDim2.fromOffset(8, 64)
scrolling.Size = UDim2.new(1, -16, 1, -72)
scrolling.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
scrolling.BorderSizePixel = 0
scrolling.ScrollBarThickness = 5
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new()
scrolling.ScrollingDirection = Enum.ScrollingDirection.Y
scrolling.Parent = main

Instance.new("UICorner", scrolling).CornerRadius = UDim.new(0, 6)

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

local function getFilename(path)
    return path:gsub("\\", "/"):match("([^/]+)$") or path
end

local function isAudioFile(path)
    local name = getFilename(path)
    local extension = name:match("%.([^%.]+)$")

    return extension ~= nil
        and AUDIO_EXTENSIONS[extension:lower()] == true
end

local function clearList()
    for _, child in ipairs(scrolling:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function stopAudio()
    playbackGeneration += 1

    if currentSound then
        local sound = currentSound
        currentSound = nil

        pcall(function()
            sound:Stop()
            sound:Destroy()
        end)
    end

    status.Text = "Playback stopped"
end

local function playFile(path)
    stopAudio()

    local thisPlayback = playbackGeneration
    status.Text = "Loading: " .. getFilename(path)

    task.spawn(function()
        local ok, asset = pcall(getasset, path)

        if thisPlayback ~= playbackGeneration or not gui.Parent then
            return
        end

        if not ok or type(asset) ~= "string" then
            status.Text = "Asset conversion failed"
            return
        end

        local sound = Instance.new("Sound")
        sound.Name = "ExecutorLocalAudio"
        sound.SoundId = asset
        sound.Volume = 1
        sound.Looped = false
        sound.Parent = SoundService
        currentSound = sound

        local playOK, playError = pcall(function()
            sound:Play()
        end)

        if not playOK then
            currentSound = nil
            sound:Destroy()
            status.Text = "Playback error: " .. tostring(playError)
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

        sound.Ended:Connect(function()
            if currentSound == sound then
                currentSound = nil
                status.Text = "Finished: " .. getFilename(path)
            end

            sound:Destroy()
        end)
    end)
end

local function addFile(path, index)
    local button = Instance.new("TextButton")
    button.Name = "AudioFile_" .. index
    button.Size = UDim2.new(1, -4, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(37, 39, 51)
    button.BorderSizePixel = 0
    button.Text = ""
    button.LayoutOrder = index
    button.Parent = scrolling

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Filename"
    nameLabel.Position = UDim2.fromOffset(7, 2)
    nameLabel.Size = UDim2.new(1, -14, 0, 18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "▶  " .. getFilename(path)
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

local function scanDirectory(path, results, visited, depth)
    if depth > 30 then
        return
    end

    local ok, entries = pcall(ListFiles, path)

    if not ok or type(entries) ~= "table" then
        return
    end

    for _, entry in ipairs(entries) do
        if type(entry) == "string" then
            local normalized = entry:gsub("\\", "/")

            if not visited[normalized] then
                visited[normalized] = true

                local folderOK, folder = pcall(IsFolder, entry)

                if folderOK and folder then
                    scanDirectory(entry, results, visited, depth + 1)
                elseif isAudioFile(entry) then
                    table.insert(results, entry)
                end
            end
        end
    end
end

local function refreshFiles()
    scanGeneration += 1
    local thisScan = scanGeneration

    clearList()
    status.Text = "Scanning sandbox..."

    task.spawn(function()
        local results = {}

        -- The executor sandbox root is the empty string.
        scanDirectory("", results, {}, 0)

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

        status.Text = string.format("%d audio file(s) found", #results)
    end)
end

refresh.Activated:Connect(refreshFiles)

stop.Activated:Connect(function()
    stopAudio()
end)

gui.Destroying:Connect(function()
    stopAudio()
end)

refreshFiles()
