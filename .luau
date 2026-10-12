local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GUI_NAME = "SuperTrackerDeluxe"

local gui
local selectedPlayer
local profileRequestId = 0
local refreshScheduled = false
local destroyed = false
local connections = {}

local function ErrorHandler(err)
    local success, traceback = pcall(debug.traceback, tostring(err), 2)
    return success and traceback or tostring(err)
end

local function SafeCall(label, callback, ...)
    local args = table.pack(...)

    local success, result = xpcall(function()
        return callback(table.unpack(args, 1, args.n))
    end, ErrorHandler)

    if not success then
        warn("[SuperTrackerDeluxe] " .. tostring(label) .. ":\n" .. tostring(result))
    end

    return success, result
end

local function AddConnection(connection)
    if connection then
        table.insert(connections, connection)
    end

    return connection
end

local function IsGuiAvailable()
    return not destroyed and gui ~= nil and gui.Parent ~= nil
end

local function GetJson(url)
    local success, result = xpcall(function()
        assert(type(request) == "function", "HTTP request function unavailable")

        local response = request({
            Url = url,
            Method = "GET"
        })

        assert(type(response) == "table", "Invalid HTTP response")

        local statusCode = tonumber(response.StatusCode)
        assert(statusCode, "Invalid HTTP status code")
        assert(statusCode >= 200 and statusCode < 300, "HTTP " .. tostring(statusCode))
        assert(type(response.Body) == "string", "Missing response body")

        return HttpService:JSONDecode(response.Body)
    end, ErrorHandler)

    if not success then
        warn(
            "[SuperTrackerDeluxe] API Error:\nURL: "
            .. tostring(url) .. "\n" .. tostring(result)
        )

        return nil
    end

    return result
end

local function GetCount(url)
    local data = GetJson(url)

    if type(data) == "table" and data.count ~= nil then
        return tostring(data.count)
    end

    return "N/A"
end

gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false

SafeCall("Set GUI parent", function()
    if type(get_hidden_gui) == "function" then
        gui.Parent = get_hidden_gui()
    elseif type(gethui) == "function" then
        gui.Parent = gethui()
    elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
        syn.protect_gui(gui)
        gui.Parent = CoreGui
    else
        gui.Parent = CoreGui
    end
end)

if not gui.Parent then
    SafeCall("Fallback GUI parent", function()
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end)
end

local function Create(className, properties, parentObject)
    local object

    local success, result = xpcall(function()
        object = Instance.new(className)

        for property, value in pairs(properties or {}) do
            object[property] = value
        end

        object.Parent = parentObject
        return object
    end, ErrorHandler)

    if not success then
        warn("[SuperTrackerDeluxe] Create " .. tostring(className) .. ":\n" .. tostring(result))

        if object then
            SafeCall("Destroy incomplete instance", function()
                object:Destroy()
            end)
        end

        return nil
    end

    return result
end

local function Corner(object, radius)
    if not object then
        return
    end

    SafeCall("UICorner", function()
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = object
    end)
end


local mainFrame = Create("Frame", {
    Size = UDim2.new(0, 650, 0, 400),
    Position = UDim2.new(0.5, -325, 0.5, -200),
    BackgroundColor3 = Color3.fromRGB(25, 25, 25),
    BorderSizePixel = 0,
    Active = true,
    Draggable = false
}, gui)

assert(mainFrame, "Failed to create main frame")
Corner(mainFrame, 10)


local topBar = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(35, 35, 35),
    BorderSizePixel = 0,
    Active = true
}, mainFrame)

Corner(topBar, 10)

local SCRIPT_VERSION = "1.2"

Create("TextLabel", {
    Size = UDim2.new(0, 160, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1,
    Text = GUI_NAME,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left
}, topBar)

Create("TextLabel", {
    Size = UDim2.new(0, 50, 1, 0),
    Position = UDim2.new(0, 140, 0, 0),
    BackgroundTransparency = 1,
    Text = SCRIPT_VERSION,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextXAlignment = Enum.TextXAlignment.Left
}, topBar)

local closeButton = Create("TextButton", {
    Name = "CloseButton",
    Size = UDim2.new(0, 26, 0, 25),
    Position = UDim2.new(1, -31, 0, 4),
    BackgroundColor3 = Color3.fromRGB(180, 45, 45),
    BorderSizePixel = 0,
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true
}, topBar)

Corner(closeButton, 6)


local searchBox = Create("TextBox", {
    Size = UDim2.new(0, 180, 0, 27),
    Position = UDim2.new(0, 10, 0, 43),
    PlaceholderText = "Search Player...",
    Text = "",
    ClearTextOnFocus = false,
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderColor3 = Color3.fromRGB(155, 155, 155),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    BorderSizePixel = 0
}, mainFrame)

Corner(searchBox, 7)


local playerList = Create("Frame", {
    Name = "PlayerList",
    Position = UDim2.new(0, 10, 0, 78),
    Size = UDim2.new(0, 200, 1, -88),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BorderSizePixel = 0,
    ClipsDescendants = true
}, mainFrame)

Corner(playerList, 8)

local scrollFrame = Create("ScrollingFrame", {
    Name = "PlayerScrollFrame",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.None,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Active = true,
    ClipsDescendants = true
}, playerList)

local layout = Create("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 7),
    HorizontalAlignment = Enum.HorizontalAlignment.Center
}, scrollFrame)

local isScrolling = false
local scrollInputActive = false

local function BeginScrolling(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        isScrolling = true
        scrollInputActive = true
        mainFrame.Active = false
    end
end

local function EndScrolling(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        task.delay(0.1, function()
            if destroyed then
                return
            end

            scrollInputActive = false
            isScrolling = false
            mainFrame.Active = true
        end)
    end
end

AddConnection(scrollFrame.InputBegan:Connect(function(input)
    SafeCall("Scroll InputBegan", BeginScrolling, input)
end))

AddConnection(scrollFrame.InputEnded:Connect(function(input)
    SafeCall("Scroll InputEnded", EndScrolling, input)
end))

AddConnection(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseWheel
        or not scrollFrame
        or not scrollFrame.Parent then
        return
    end

    local mousePosition = UserInputService:GetMouseLocation()
    local absolutePosition = scrollFrame.AbsolutePosition
    local absoluteSize = scrollFrame.AbsoluteSize

    local inside =
        mousePosition.X >= absolutePosition.X
        and mousePosition.X <= absolutePosition.X + absoluteSize.X
        and mousePosition.Y >= absolutePosition.Y
        and mousePosition.Y <= absolutePosition.Y + absoluteSize.Y

    if inside then
        isScrolling = true
        mainFrame.Active = false

        task.delay(0.15, function()
            if destroyed or scrollInputActive then
                return
            end

            isScrolling = false
            mainFrame.Active = true
        end)
    end
end))

AddConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SafeCall("Update scroll canvas", function()
        if scrollFrame and scrollFrame.Parent then
            scrollFrame.CanvasSize = UDim2.new(
                0, 0, 0, layout.AbsoluteContentSize.Y + 7
            )
        end
    end)
end))


local dragging, dragInput, dragStart, startPos

local function updateDrag(input)
    if isScrolling or not dragging then
        return
    end

    local delta = input.Position - dragStart

    local pos = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )

    SafeCall("Tween window position", function()
        TweenService:Create(
            mainFrame,
            TweenInfo.new(0.12),
            {Position = pos}
        ):Play()
    end)
end

AddConnection(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        if isScrolling then
            return
        end

        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        AddConnection(input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end))
    end
end))

AddConnection(topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        dragInput = input
    end
end))

AddConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and not isScrolling and input == dragInput then
        updateDrag(input)
    end
end))


local profileFrame = Create("Frame", {
    Position = UDim2.new(0, 220, 0, 43),
    Size = UDim2.new(1, -230, 1, -53),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BorderSizePixel = 0
}, mainFrame)

Corner(profileFrame, 8)

local avatar = Create("ImageLabel", {
    Size = UDim2.new(0, 85, 0, 85),
    Position = UDim2.new(0, 10, 0, 12),
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
    BorderSizePixel = 0,
    BackgroundTransparency = 0,
    ScaleType = Enum.ScaleType.Crop
}, profileFrame)

Corner(avatar, 8)

local infoLabel = Create("TextLabel", {
    Position = UDim2.new(0, 105, 0, 10),
    Size = UDim2.new(1, -115, 1, -20),
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Gotham,
    TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1),
    TextWrapped = true,
    Text = "Select a player..."
}, profileFrame)

local function CloseGUI()
    if destroyed then
        return
    end

    destroyed = true
    profileRequestId += 1

    for _, connection in ipairs(connections) do
        SafeCall("Disconnect event", function()
            connection:Disconnect()
        end)
    end

    table.clear(connections)

    SafeCall("Destroy GUI", function()
        if gui then
            gui:Destroy()
        end
    end)
end

AddConnection(closeButton.MouseButton1Click:Connect(function()
    SafeCall("Close GUI", CloseGUI)
end))

local function LoadProfile(player)
    if destroyed or not player or not player.Parent then
        return
    end

    profileRequestId += 1

    local requestId = profileRequestId
    selectedPlayer = player

    infoLabel.Text = "Loading profile..."
    avatar.Image = ""

    task.spawn(function()
        local success, err = xpcall(function()
            local userId = player.UserId

            local profile = {
                Username = player.Name,
                DisplayName = player.DisplayName,
                UserId = tostring(userId),
                Created = "N/A",
                AccountAge = "N/A",
                Friends = "N/A",
                Followers = "N/A",
                Following = "N/A",
                Groups = "N/A",
                Badges = "N/A",
                Presence = "N/A",
                RAP = "N/A",
                Value = "N/A"
            }

            local thumbnailSuccess, thumbnail = xpcall(function()
                return Players:GetUserThumbnailAsync(
                    userId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size420x420
                )
            end, ErrorHandler)

            if not thumbnailSuccess then
                warn("[SuperTrackerDeluxe] Profile thumbnail:\n" .. tostring(thumbnail))
            elseif requestId == profileRequestId and IsGuiAvailable() then
                avatar.Image = thumbnail
            end

            local userData = GetJson(
                "https://users.roblox.com/v1/users/" .. tostring(userId)
            )

            if type(userData) == "table" then
                if type(userData.created) == "string" then
                    profile.Created = string.sub(userData.created, 1, 10)

                    local ageSuccess, age = xpcall(function()
                        local year, month, day = userData.created:match(
                            "(%d+)-(%d+)-(%d+)"
                        )

                        assert(year and month and day, "Invalid account creation date")

                        local createdAt = os.time({
                            year = tonumber(year),
                            month = tonumber(month),
                            day = tonumber(day),
                            hour = 0,
                            min = 0,
                            sec = 0
                        })

                        return math.max(
                            0,
                            math.floor((os.time() - createdAt) / 86400)
                        )
                    end, ErrorHandler)

                    if ageSuccess then
                        profile.AccountAge = tostring(age) .. " days"
                    else
                        warn("[SuperTrackerDeluxe] Account age:\n" .. tostring(age))
                    end
                end

                if type(userData.name) == "string" then
                    profile.Username = userData.name
                end

                if type(userData.displayName) == "string" then
                    profile.DisplayName = userData.displayName
                end
            end

            profile.Friends = GetCount(
                "https://friends.roblox.com/v1/users/"
                .. tostring(userId) .. "/friends/count"
            )

            profile.Followers = GetCount(
                "https://friends.roblox.com/v1/users/"
                .. tostring(userId) .. "/followers/count"
            )

            profile.Following = GetCount(
                "https://friends.roblox.com/v1/users/"
                .. tostring(userId) .. "/followings/count"
            )

            local groups = GetJson(
                "https://groups.roblox.com/v1/users/"
                .. tostring(userId) .. "/groups/roles"
            )

            if type(groups) == "table" and type(groups.data) == "table" then
                profile.Groups = tostring(#groups.data)
            end

            local badges = GetJson(
                "https://badges.roblox.com/v1/users/"
                .. tostring(userId) .. "/badges?limit=100"
            )

            if type(badges) == "table" and type(badges.data) == "table" then
                profile.Badges = tostring(#badges.data) .. " (first page)"
            end

            if requestId ~= profileRequestId or not IsGuiAvailable() then
                return
            end

            if not player.Parent then
                selectedPlayer = nil
                avatar.Image = ""
                infoLabel.Text = "Selected player left the server."
                return
            end

            infoLabel.Text =
                "Username : " .. profile.Username ..
                "\nDisplay : " .. profile.DisplayName ..
                "\nUserId : " .. profile.UserId ..
                "\nCreated : " .. profile.Created ..
                "\nAccount Age : " .. profile.AccountAge ..
                "\nFriends : " .. profile.Friends ..
                "\nFollowers : " .. profile.Followers ..
                "\nFollowing : " .. profile.Following ..
                "\nGroups : " .. profile.Groups ..
                "\nBadges : " .. profile.Badges ..
                "\nStatus : " .. profile.Presence ..
                "\nRAP : " .. profile.RAP ..
                "\nValue : " .. profile.Value
        end, ErrorHandler)

        if not success then
            warn("[SuperTrackerDeluxe] LoadProfile error:\n" .. tostring(err))

            if requestId == profileRequestId and IsGuiAvailable() then
                infoLabel.Text = "Failed to load profile.\nCheck console for details."
            end
        end
    end)
end

local function SafeRefreshPlayers()
    if destroyed or refreshScheduled then
        return
    end

    refreshScheduled = true

    task.defer(function()
        refreshScheduled = false

        if not IsGuiAvailable() then
            return
        end

        SafeCall("RefreshPlayers", function()
            local search = string.lower(searchBox.Text)
            local order = 0

            for _, child in ipairs(scrollFrame:GetChildren()) do
                if child:GetAttribute("SFDPlayerCard") then
                    child:Destroy()
                end
            end

            local currentPlayers = Players:GetPlayers()

            table.sort(currentPlayers, function(a, b)
                return string.lower(a.Name) < string.lower(b.Name)
            end)

            for _, player in ipairs(currentPlayers) do
                if destroyed then
                    return
                end

                local username = string.lower(player.Name)
                local displayName = string.lower(player.DisplayName)

                local matches =
                    search == ""
                    or string.find(username, search, 1, true) ~= nil
                    or string.find(displayName, search, 1, true) ~= nil

                if matches then
                    order += 1

                    local card = Create("TextButton", {
                        Name = "Player_" .. tostring(player.UserId),
                        Size = UDim2.new(1, -8, 0, 55),
                        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
                        BorderSizePixel = 0,
                        Text = "",
                        LayoutOrder = order,
                        AutoButtonColor = true
                    }, scrollFrame)

                    if not card then
                        continue
                    end

                    card:SetAttribute("SFDPlayerCard", true)
                    card:SetAttribute("SFDUserId", player.UserId)
                    Corner(card, 7)

                    local head = Create("ImageLabel", {
                        Size = UDim2.new(0, 40, 0, 40),
                        Position = UDim2.new(0, 6, 0, 7),
                        BackgroundTransparency = 1,
                        ScaleType = Enum.ScaleType.Crop
                    }, card)

                    Create("TextLabel", {
                        Position = UDim2.new(0, 53, 0, 6),
                        Size = UDim2.new(1, -59, 0, 19),
                        BackgroundTransparency = 1,
                        TextColor3 = Color3.new(1, 1, 1),
                        Font = Enum.Font.GothamBold,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = player.Name
                    }, card)

                    Create("TextLabel", {
                        Position = UDim2.new(0, 53, 0, 28),
                        Size = UDim2.new(1, -59, 0, 17),
                        BackgroundTransparency = 1,
                        TextColor3 = Color3.fromRGB(180, 180, 180),
                        Font = Enum.Font.Gotham,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = "@" .. player.DisplayName
                    }, card)

                    if head then
                        task.spawn(function()
                            local thumbnailSuccess, image = xpcall(function()
                                return Players:GetUserThumbnailAsync(
                                    player.UserId,
                                    Enum.ThumbnailType.HeadShot,
                                    Enum.ThumbnailSize.Size150x150
                                )
                            end, ErrorHandler)

                            if not thumbnailSuccess then
                                warn("[SuperTrackerDeluxe] Player thumbnail:\n" .. tostring(image))
                                return
                            end

                            if not destroyed
                                and card.Parent
                                and head.Parent
                                and player.Parent then

                                head.Image = image
                            end
                        end)
                    end

                    card.MouseButton1Click:Connect(function()
                        SafeCall("Select player", function()
                            if player.Parent then
                                LoadProfile(player)
                            end
                        end)
                    end)
                end
            end
        end)
    end)
end

AddConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    SafeCall("Search event", SafeRefreshPlayers)
end))

AddConnection(Players.PlayerAdded:Connect(function()
    SafeCall("PlayerAdded event", SafeRefreshPlayers)
end))

AddConnection(Players.PlayerRemoving:Connect(function(player)
    SafeCall("PlayerRemoving event", function()
        if selectedPlayer == player then
            selectedPlayer = nil
            profileRequestId += 1

            if IsGuiAvailable() then
                avatar.Image = ""
                infoLabel.Text = "Selected player left the server."
            end
        end

        SafeRefreshPlayers()
    end)
end))

SafeCall("Initial player refresh", SafeRefreshPlayers)
