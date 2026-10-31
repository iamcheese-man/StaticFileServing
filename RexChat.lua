-- REX-Chat | OpenFun Chatroom (Multi-Room)
-- Rooms: REX-Chat-Room1 ... REX-Chat-Room15
--
-- Protocol (unchanged):
--   joined -> room confirmation + Data.history
--   say -> incoming chat
--   user-joined / user-left / error -> system events
--
-- Commands:
--   /clear        clears the locally displayed messages only
--   /rooms        back to the room list
--   /room <1-15>  jump straight to a room
--   /mute <name>  hide a user's messages on your client
--   /unmute <name>
--
-- Spam protection (rate limits, flood hiding, IP limits) is enforced by the relay Worker.
--   X button      closes the WebSocket and destroys the GUI

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local Username = Player.Name

local ROOM_PREFIX = "REX-Chat-Room"
local ROOM_COUNT = 15
-- the relay is broken so ill use the direct endp
local ENDPOINT = "wss://openfunproxy.zerdgeservers.workers.dev/ws"
local MAX_MESSAGES = 200


-- Clean up a previous execution
local Env = (getgenv and getgenv()) or _G
if Env.REXChatClose then
    pcall(Env.REXChatClose)
end
local OldGui = CoreGui:FindFirstChild("ZDChatGUI")
if OldGui then
    OldGui:Destroy()
end

-- State
local Closed = false
local Socket = nil
local CurrentRoom = nil
local Generation = 0         -- bumped on every disconnect so stale callbacks are ignored
local Connections = {}       -- GUI connections (live until the GUI closes)
local SocketConnections = {} -- per-socket connections (reset on room change)
local Labels = {}            -- message labels, oldest first
local MessageOrder = 0

-- Manual /mute list (lowercase username -> true)
local Muted = {}

-- GUI setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZDChatGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 400, 0, 350)
Main.Position = UDim2.new(0.5, -200, 0.5, -175)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local DragDetector = Instance.new("UIDragDetector")
DragDetector.Parent = Main

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -125, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "REX-Chat | " .. Username
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Parent = TitleBar

-- X button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Size = UDim2.new(0, 30, 0, 28)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(190, 50, 55)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseButton

-- Rooms button (back to room list)
local RoomsButton = Instance.new("TextButton")
RoomsButton.Name = "Rooms"
RoomsButton.Size = UDim2.new(0, 70, 0, 28)
RoomsButton.Position = UDim2.new(1, -110, 0, 5)
RoomsButton.BackgroundColor3 = Color3.fromRGB(65, 120, 220)
RoomsButton.BorderSizePixel = 0
RoomsButton.Text = "Rooms"
RoomsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RoomsButton.TextSize = 14
RoomsButton.Font = Enum.Font.GothamBold
RoomsButton.Visible = false
RoomsButton.Parent = TitleBar

local RoomsCorner = Instance.new("UICorner")
RoomsCorner.CornerRadius = UDim.new(0, 5)
RoomsCorner.Parent = RoomsButton

-- Room picker view
local Picker = Instance.new("ScrollingFrame")
Picker.Name = "Picker"
Picker.Position = UDim2.new(0, 10, 0, 48)
Picker.Size = UDim2.new(1, -20, 1, -58)
Picker.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
Picker.BorderSizePixel = 0
Picker.ScrollBarThickness = 5
Picker.CanvasSize = UDim2.new(0, 0, 0, 0)
Picker.AutomaticCanvasSize = Enum.AutomaticSize.Y
Picker.Parent = Main

local PickerCorner = Instance.new("UICorner")
PickerCorner.CornerRadius = UDim.new(0, 6)
PickerCorner.Parent = Picker

local PickerPadding = Instance.new("UIPadding")
PickerPadding.PaddingTop = UDim.new(0, 10)
PickerPadding.PaddingBottom = UDim.new(0, 10)
PickerPadding.PaddingLeft = UDim.new(0, 8)
PickerPadding.PaddingRight = UDim.new(0, 8)
PickerPadding.Parent = Picker

local PickerGrid = Instance.new("UIGridLayout")
PickerGrid.CellSize = UDim2.new(0, 112, 0, 40)
PickerGrid.CellPadding = UDim2.new(0, 8, 0, 8)
PickerGrid.SortOrder = Enum.SortOrder.LayoutOrder
PickerGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
PickerGrid.Parent = Picker

-- Chat view
local ChatView = Instance.new("Frame")
ChatView.Name = "ChatView"
ChatView.Position = UDim2.new(0, 0, 0, 38)
ChatView.Size = UDim2.new(1, 0, 1, -38)
ChatView.BackgroundTransparency = 1
ChatView.Visible = false
ChatView.Parent = Main

local Messages = Instance.new("ScrollingFrame")
Messages.Name = "Messages"
Messages.Position = UDim2.new(0, 10, 0, 10)
Messages.Size = UDim2.new(1, -20, 1, -70)
Messages.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
Messages.BorderSizePixel = 0
Messages.ScrollBarThickness = 5
Messages.CanvasSize = UDim2.new(0, 0, 0, 0)
Messages.AutomaticCanvasSize = Enum.AutomaticSize.Y
Messages.Parent = ChatView

local MessagesCorner = Instance.new("UICorner")
MessagesCorner.CornerRadius = UDim.new(0, 6)
MessagesCorner.Parent = Messages

local MessageLayout = Instance.new("UIListLayout")
MessageLayout.Padding = UDim.new(0, 5)
MessageLayout.SortOrder = Enum.SortOrder.LayoutOrder
MessageLayout.Parent = Messages

local MessagePadding = Instance.new("UIPadding")
MessagePadding.PaddingTop = UDim.new(0, 8)
MessagePadding.PaddingBottom = UDim.new(0, 8)
MessagePadding.PaddingLeft = UDim.new(0, 8)
MessagePadding.PaddingRight = UDim.new(0, 8)
MessagePadding.Parent = Messages

local Input = Instance.new("TextBox")
Input.Name = "Input"
Input.Position = UDim2.new(0, 10, 1, -50)
Input.Size = UDim2.new(1, -100, 0, 40)
Input.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
Input.BorderSizePixel = 0
Input.PlaceholderText = "Type a message..."
Input.Text = ""
Input.TextColor3 = Color3.fromRGB(255, 255, 255)
Input.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
Input.TextSize = 14
Input.Font = Enum.Font.Gotham
Input.ClearTextOnFocus = false
Input.Parent = ChatView

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 6)
InputCorner.Parent = Input

local SendButton = Instance.new("TextButton")
SendButton.Name = "Send"
SendButton.Position = UDim2.new(1, -80, 1, -50)
SendButton.Size = UDim2.new(0, 70, 0, 40)
SendButton.BackgroundColor3 = Color3.fromRGB(65, 120, 220)
SendButton.BorderSizePixel = 0
SendButton.Text = "Send"
SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SendButton.TextSize = 14
SendButton.Font = Enum.Font.GothamBold
SendButton.Parent = ChatView

local SendCorner = Instance.new("UICorner")
SendCorner.CornerRadius = UDim.new(0, 6)
SendCorner.Parent = SendButton

-- Message helpers
local function AddMessage(Text)
    if Closed or not ScreenGui.Parent then
        return
    end

    MessageOrder += 1

    local Label = Instance.new("TextLabel")
    Label.Name = "ChatMessage"
    Label.LayoutOrder = MessageOrder
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, -4, 0, 22)
    Label.AutomaticSize = Enum.AutomaticSize.Y
    Label.Text = tostring(Text)
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.TextSize = 14
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextWrapped = true
    Label.RichText = false
    Label.Parent = Messages

    table.insert(Labels, Label)
    while #Labels > MAX_MESSAGES do
        local Oldest = table.remove(Labels, 1)
        if Oldest then
            Oldest:Destroy()
        end
    end

    task.defer(function()
        if Closed or not Messages.Parent then
            return
        end

        Messages.CanvasPosition = Vector2.new(
            0,
            math.max(0, Messages.AbsoluteCanvasSize.Y - Messages.AbsoluteSize.Y)
        )
    end)
end

-- Clears only what's displayed on this client
local function ClearMessages()
    for _, Label in ipairs(Labels) do
        Label:Destroy()
    end
    table.clear(Labels)
    Messages.CanvasPosition = Vector2.zero
end

-- View switching
local function ShowPicker()
    Title.Text = "REX-Chat | Choose a room"
    Picker.Visible = true
    ChatView.Visible = false
    RoomsButton.Visible = false
end

local function ShowChat(RoomName)
    Title.Text = RoomName .. " | " .. Username
    Picker.Visible = false
    ChatView.Visible = true
    RoomsButton.Visible = true
end

-- Networking
local function SendPacket(Packet)
    if Closed or not Socket then
        return false, "Socket is closed"
    end

    local Success, ErrorMessage = pcall(function()
        Socket:Send(HttpService:JSONEncode(Packet))
    end)

    return Success, ErrorMessage
end

-- Drops the current socket (if any) and invalidates its callbacks
local function Disconnect()
    Generation += 1

    for _, Connection in ipairs(SocketConnections) do
        pcall(function()
            Connection:Disconnect()
        end)
    end
    table.clear(SocketConnections)

    local OldSocket = Socket
    Socket = nil
    CurrentRoom = nil

    if OldSocket then
        pcall(function()
            OldSocket:Close()
        end)
    end
end

-- Personal /mute list. Spam handling happens in the relay, not here.
local function IsMuted(Name)
    return Muted[tostring(Name):lower()] == true
end

local function HandleMessage(RawMessage)
    local Success, Data = pcall(function()
        return HttpService:JSONDecode(tostring(RawMessage))
    end)

    if not Success or type(Data) ~= "table" then
        return
    end

    if Data.type == "joined" then
        AddMessage("(S) Joined room: " .. tostring(Data.room))

        if type(Data.history) == "table" then
            for _, Entry in ipairs(Data.history) do
                if type(Entry) == "table" then
                    local Payload = Entry.payload

                    if type(Payload) == "table"
                        and Payload.type == "chat"
                        and type(Payload.text) == "string" then

                        if not IsMuted(Entry.username) then
                            AddMessage(tostring(Entry.username) .. ": " .. Payload.text)
                        end
                    end
                end
            end
        end

    elseif Data.type == "say" then
        local Payload = Data.payload

        if type(Payload) == "table"
            and Payload.type == "chat"
            and type(Payload.text) == "string" then

            if not IsMuted(Data.username) then
                AddMessage(tostring(Data.username) .. ": " .. Payload.text)
            end
        end

    elseif Data.type == "user-joined" then
        AddMessage("(S) " .. tostring(Data.username) .. " joined the room.")

    elseif Data.type == "user-left" then
        AddMessage("(S) " .. tostring(Data.username) .. " left the room.")

    elseif Data.type == "error" then
        AddMessage("(S) " .. tostring(Data.code) .. ": " .. tostring(Data.message))
    end
end

-- Leaves any current room and joins room Index
local function JoinRoom(Index)
    if Closed then
        return
    end

    Disconnect()
    ClearMessages()

    local RoomName = ROOM_PREFIX .. Index
    CurrentRoom = RoomName
    ShowChat(RoomName)
    AddMessage("(S) Connecting to " .. RoomName .. "...")

    local MyGeneration = Generation

    local ConnectSuccess, ConnectResult = pcall(function()
        return WebSocket.connect(ENDPOINT)
    end)

    if not ConnectSuccess or not ConnectResult then
        AddMessage("(S) Connection failed: " .. tostring(ConnectResult))
        return
    end

    -- The user may have switched rooms or closed the GUI while connecting
    if Closed or MyGeneration ~= Generation then
        pcall(function()
            ConnectResult:Close()
        end)
        return
    end

    Socket = ConnectResult

    table.insert(SocketConnections, Socket.OnMessage:Connect(function(RawMessage)
        if Closed or MyGeneration ~= Generation then
            return
        end
        HandleMessage(RawMessage)
    end))

    table.insert(SocketConnections, Socket.OnClose:Connect(function()
        if Closed or MyGeneration ~= Generation then
            return
        end

        Socket = nil
        AddMessage("(S) Disconnected from OpenFun. Use /room <1-" .. ROOM_COUNT .. "> to rejoin.")
    end))

    local JoinSuccess, JoinError = SendPacket({
        type = "join",
        room = RoomName,
        username = Username
    })

    if not JoinSuccess then
        AddMessage("(S) Failed to send join request: " .. tostring(JoinError))
    end
end

local function LeaveToPicker()
    Disconnect()
    ClearMessages()
    ShowPicker()
end

-- Close the connection and destroy the GUI
local function CloseChat()
    if Closed then
        return
    end

    Closed = true
    Disconnect()

    for _, Connection in ipairs(Connections) do
        pcall(function()
            Connection:Disconnect()
        end)
    end
    table.clear(Connections)

    if Env.REXChatClose == CloseChat then
        Env.REXChatClose = nil
    end

    ScreenGui:Destroy()
end

Env.REXChatClose = CloseChat

-- Build the room buttons
for Index = 1, ROOM_COUNT do
    local RoomButton = Instance.new("TextButton")
    RoomButton.Name = "Room" .. Index
    RoomButton.LayoutOrder = Index
    RoomButton.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    RoomButton.BorderSizePixel = 0
    RoomButton.Text = "Room " .. Index
    RoomButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RoomButton.TextSize = 14
    RoomButton.Font = Enum.Font.GothamBold
    RoomButton.AutoButtonColor = true
    RoomButton.Parent = Picker

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = RoomButton

    table.insert(Connections, RoomButton.MouseButton1Click:Connect(function()
        JoinRoom(Index)
    end))
end

-- Sending
local function SendMessage()
    if Closed then
        return
    end

    local Message = Input.Text

    if not Message:match("%S") then
        return
    end

    -- Local commands: never sent to OpenFun
    if Message:lower():match("^%s*/clear%s*$") then
        ClearMessages()
        Input.Text = ""
        return
    end

    if Message:lower():match("^%s*/rooms%s*$") then
        Input.Text = ""
        LeaveToPicker()
        return
    end

    local RoomArg = Message:lower():match("^%s*/room%s+(%d+)%s*$")
    if RoomArg then
        Input.Text = ""
        local RoomIndex = tonumber(RoomArg)
        if RoomIndex and RoomIndex >= 1 and RoomIndex <= ROOM_COUNT then
            JoinRoom(RoomIndex)
        else
            AddMessage("(S) Room must be between 1 and " .. ROOM_COUNT .. ".")
        end
        return
    end

    local MuteName = Message:lower():match("^%s*/mute%s+(%S+)%s*$")
    if MuteName then
        Input.Text = ""
        if MuteName == Username:lower() then
            AddMessage("(S) You can't mute yourself.")
        else
            Muted[MuteName] = true
            AddMessage("(S) Muted " .. MuteName .. ". Use /unmute " .. MuteName .. " to undo.")
        end
        return
    end

    local UnmuteName = Message:lower():match("^%s*/unmute%s+(%S+)%s*$")
    if UnmuteName then
        Input.Text = ""
        Muted[UnmuteName] = nil
        AddMessage("(S) Unmuted " .. UnmuteName .. ".")
        return
    end

    if #Message > 100 then
        AddMessage("(S) Messages must be 100 characters or fewer.")
        return
    end

    local Success = SendPacket({
        type = "say",
        payload = {
            type = "chat",
            text = Message
        }
    })

    if Success then
        Input.Text = ""
    else
        AddMessage("(S) Failed to send message.")
    end
end

table.insert(Connections, SendButton.MouseButton1Click:Connect(SendMessage))

table.insert(Connections, Input.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        SendMessage()
    end
end))

table.insert(Connections, RoomsButton.MouseButton1Click:Connect(LeaveToPicker))
table.insert(Connections, CloseButton.MouseButton1Click:Connect(CloseChat))

-- Start on the room list
ShowPicker()
