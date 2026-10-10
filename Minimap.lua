Meeting.Minimap = {}

local MINIMAP_BUTTON_RADIUS = 80
local DEFAULT_POSITION = 225
local initialized = false

local function IsInMBF(button)
    return button and MinimapButtonFrame and button:GetParent() == MinimapButtonFrame
end

local function RequestMBFScan()
    if type(MBF_Include) == "table" then
        local found
        for _, name in ipairs(MBF_Include) do
            if name == "MeetingMinimapButton" then
                found = true
                break
            end
        end
        if not found then
            table.insert(MBF_Include, "MeetingMinimapButton")
        end
    end

    if type(MBF_RequestScan) == "function" then
        MBF_RequestScan(0.25)
    elseif MBF_Scan then
        MBF_Scan()
    end
end

local function UpdatePosition(button)
    if not button or not Minimap then
        return
    end
    if IsInMBF(button) then
        return
    end
    local angle = DEFAULT_POSITION
    if MEETING_DB and MEETING_DB.minimapPos then
        angle = tonumber(MEETING_DB.minimapPos) or DEFAULT_POSITION
    end
    local rad = math.rad(angle)
    local x = math.cos(rad) * MINIMAP_BUTTON_RADIUS
    local y = math.sin(rad) * MINIMAP_BUTTON_RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Meeting.Minimap.CreateButton()
    if not Minimap then
        return Meeting.MinimapButton
    end

    local button = Meeting.MinimapButton
    if button then
        if IsInMBF(button) then
            return button
        end

        if button:GetParent() ~= Minimap then
            button:SetParent(Minimap)
        end

        UpdatePosition(button)
        if Meeting.UpdateIcons then
            Meeting.UpdateIcons()
        end
        button:Show()
        RequestMBFScan()
        return button
    end

    button = CreateFrame("Button", "MeetingMinimapButton", Minimap)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(9)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\Meeting\\assets\\LFG.blp")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 1, 0)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetWidth(32)
    highlight:SetHeight(32)
    highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    highlight:SetBlendMode("ADD")

    button:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or Minimap:GetScale()
            cx, cy = cx / scale, cy / scale
            if not MEETING_DB then
                MEETING_DB = {}
            end
            MEETING_DB.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition(this)
        end)
    end)

    button:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            Meeting.Settings.ToggleFloatVisibility()
        elseif arg1 == "RightButton" then
            Meeting.Settings.ToggleSettingsFrame()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("Meeting")
        GameTooltip:AddLine("Left-click: show/hide Meeting button", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:Show()
    Meeting.MinimapButton = button
    UpdatePosition(button)
    if Meeting.UpdateIcons then
        Meeting.UpdateIcons()
    end
    RequestMBFScan()
    return button
end

function Meeting.Minimap.Init()
    if initialized then
        Meeting.Minimap.CreateButton()
        return
    end
    if Meeting.Settings and Meeting.Settings.EnsureDefaults then
        Meeting.Settings.EnsureDefaults()
    end
    if Meeting.Minimap.CreateButton() then
        initialized = true
    end
end
