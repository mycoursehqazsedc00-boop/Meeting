Meeting.Settings = {}

local DEFAULT_FONT_SIZE = 14
local MIN_FONT_SIZE = 10
local MAX_FONT_SIZE = 20
local DEFAULT_MINIMAP_POS = 225
local DEFAULT_BACKGROUND_OPACITY = 50
local MIN_BACKGROUND_OPACITY = 10
local MAX_BACKGROUND_OPACITY = 100
local BACKGROUND_OPACITY_STEP = 10

function Meeting.Settings.EnsureDefaults()
    if MEETING_DB.fontSize == nil then
        MEETING_DB.fontSize = DEFAULT_FONT_SIZE
    end
    if MEETING_DB.blizzardBorders == nil then
        MEETING_DB.blizzardBorders = 0
    end
    if MEETING_DB.backgroundOpacity == nil then
        MEETING_DB.backgroundOpacity = DEFAULT_BACKGROUND_OPACITY
    end
    if MEETING_DB.minimapPos == nil then
        MEETING_DB.minimapPos = DEFAULT_MINIMAP_POS
    end
    if MEETING_DB.translateEnabled == nil then
        MEETING_DB.translateEnabled = 0
    end
end

function Meeting.Settings.GetFontSize(fallback)
    if MEETING_DB and MEETING_DB.fontSize then
        return MEETING_DB.fontSize
    end
    return fallback or DEFAULT_FONT_SIZE
end

function Meeting.Settings.UsesBlizzardBorders()
    return MEETING_DB and MEETING_DB.blizzardBorders == 1
end

function Meeting.Settings.GetBackgroundOpacity()
    if MEETING_DB and MEETING_DB.backgroundOpacity then
        return MEETING_DB.backgroundOpacity
    end
    return DEFAULT_BACKGROUND_OPACITY
end

function Meeting.Settings.GetBackgroundAlpha()
    return Meeting.Settings.GetBackgroundOpacity() / 100
end

function Meeting.Settings.Apply()
    Meeting.Settings.EnsureDefaults()
    if not Meeting.GUI then
        return
    end
    Meeting.GUI.RefreshFonts()
    Meeting.GUI.RefreshBackgrounds()
    if Meeting.FloatFrame and Meeting.FloatFrame.Update then
        Meeting.FloatFrame.Update()
    end
    if Meeting.SettingsFrame and Meeting.SettingsFrame.fontSizeLabel then
        Meeting.SettingsFrame.fontSizeLabel:SetText(tostring(Meeting.Settings.GetFontSize()))
    end
    if Meeting.SettingsFrame and Meeting.SettingsFrame.borderCheck then
        Meeting.SettingsFrame.borderCheck:SetChecked(Meeting.Settings.UsesBlizzardBorders())
    end
    if Meeting.SettingsFrame and Meeting.SettingsFrame.opacityLabel then
        Meeting.SettingsFrame.opacityLabel:SetText(tostring(Meeting.Settings.GetBackgroundOpacity()) .. "%")
    end
    if Meeting.WT and Meeting.WT.UpdateHeaderButtons then
        Meeting.WT.UpdateHeaderButtons()
    end
end

function Meeting.Settings.SetFontSize(size)
    size = math.floor(tonumber(size) or DEFAULT_FONT_SIZE)
    if size < MIN_FONT_SIZE then
        size = MIN_FONT_SIZE
    elseif size > MAX_FONT_SIZE then
        size = MAX_FONT_SIZE
    end
    MEETING_DB.fontSize = size
    Meeting.Settings.Apply()
end

function Meeting.Settings.SetBlizzardBorders(enabled)
    MEETING_DB.blizzardBorders = enabled and 1 or 0
    Meeting.Settings.Apply()
end

function Meeting.Settings.SetBackgroundOpacity(value)
    value = math.floor(tonumber(value) or DEFAULT_BACKGROUND_OPACITY)
    if value < MIN_BACKGROUND_OPACITY then
        value = MIN_BACKGROUND_OPACITY
    elseif value > MAX_BACKGROUND_OPACITY then
        value = MAX_BACKGROUND_OPACITY
    end
    MEETING_DB.backgroundOpacity = value
    Meeting.Settings.Apply()
end

function Meeting.Settings.ToggleFloatVisibility()
    MEETING_DB.hideFloat = MEETING_DB.hideFloat == 1 and 0 or 1
    if MEETING_DB.hideFloat == 1 then
        Meeting.FloatFrame:Hide()
    else
        Meeting.FloatFrame:Show()
        Meeting.FloatFrame.Update()
    end
end

local function CreateSettingsFrame()
    if Meeting.SettingsFrame then
        return Meeting.SettingsFrame
    end

    Meeting.Settings.EnsureDefaults()

    local width = 280
    local height = 220
    local frame = Meeting.GUI.CreateFrame({
        name = "MeetingSettingsFrame",
        width = width,
        height = height,
        anchor = {
            point = "CENTER",
        },
        background = Meeting.GUI.Theme.Brown,
        hide = true,
    })
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "MeetingSettingsFrame")

    Meeting.GUI.CreateText({
        parent = frame,
        text = "Meeting Settings",
        fontSize = 16,
        anchor = {
            point = "TOP",
            relative = frame,
            relativePoint = "TOP",
            y = -12,
        },
    })

    Meeting.GUI.CreateText({
        parent = frame,
        text = "Font size",
        fontSize = 14,
        anchor = {
            point = "TOPLEFT",
            relative = frame,
            relativePoint = "TOPLEFT",
            x = 16,
            y = -48,
        },
    })

    local fontSizeLabel = Meeting.GUI.CreateText({
        parent = frame,
        text = tostring(Meeting.Settings.GetFontSize()),
        fontSize = 14,
        anchor = {
            point = "TOP",
            relative = frame,
            relativePoint = "TOP",
            y = -48,
        },
    })
    frame.fontSizeLabel = fontSizeLabel

    Meeting.GUI.CreateButton({
        parent = frame,
        width = 28,
        height = 24,
        text = "-",
        anchor = {
            point = "TOPRIGHT",
            relative = frame,
            relativePoint = "TOP",
            x = -72,
            y = -44,
        },
        click = function()
            Meeting.Settings.SetFontSize(Meeting.Settings.GetFontSize() - 1)
        end,
    })

    Meeting.GUI.CreateButton({
        parent = frame,
        width = 28,
        height = 24,
        text = "+",
        anchor = {
            point = "TOPRIGHT",
            relative = frame,
            relativePoint = "TOP",
            x = -16,
            y = -44,
        },
        click = function()
            Meeting.Settings.SetFontSize(Meeting.Settings.GetFontSize() + 1)
        end,
    })

    Meeting.GUI.CreateText({
        parent = frame,
        text = "Background opacity",
        fontSize = 14,
        anchor = {
            point = "TOPLEFT",
            relative = frame,
            relativePoint = "TOPLEFT",
            x = 16,
            y = -84,
        },
    })

    local opacityLabel = Meeting.GUI.CreateText({
        parent = frame,
        text = tostring(Meeting.Settings.GetBackgroundOpacity()) .. "%",
        fontSize = 14,
        anchor = {
            point = "TOP",
            relative = frame,
            relativePoint = "TOP",
            y = -84,
        },
    })
    frame.opacityLabel = opacityLabel

    Meeting.GUI.CreateButton({
        parent = frame,
        width = 28,
        height = 24,
        text = "-",
        anchor = {
            point = "TOPRIGHT",
            relative = frame,
            relativePoint = "TOP",
            x = -72,
            y = -80,
        },
        click = function()
            Meeting.Settings.SetBackgroundOpacity(Meeting.Settings.GetBackgroundOpacity() - BACKGROUND_OPACITY_STEP)
        end,
    })

    Meeting.GUI.CreateButton({
        parent = frame,
        width = 28,
        height = 24,
        text = "+",
        anchor = {
            point = "TOPRIGHT",
            relative = frame,
            relativePoint = "TOP",
            x = -16,
            y = -80,
        },
        click = function()
            Meeting.Settings.SetBackgroundOpacity(Meeting.Settings.GetBackgroundOpacity() + BACKGROUND_OPACITY_STEP)
        end,
    })

    local borderCheck = Meeting.GUI.CreateCheck({
        parent = frame,
        anchor = {
            point = "TOPLEFT",
            relative = frame,
            relativePoint = "TOPLEFT",
            x = 12,
            y = -124,
        },
        checked = Meeting.Settings.UsesBlizzardBorders(),
        click = function(checked)
            Meeting.Settings.SetBlizzardBorders(checked)
        end,
    })
    frame.borderCheck = borderCheck

    Meeting.GUI.CreateText({
        parent = frame,
        text = "Blizzard-style borders",
        fontSize = 14,
        anchor = {
            point = "LEFT",
            relative = borderCheck,
            relativePoint = "RIGHT",
            x = 4,
            y = 0,
        },
    })

    Meeting.GUI.CreateButton({
        parent = frame,
        width = 80,
        height = 24,
        text = "Close",
        type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
        anchor = {
            point = "BOTTOM",
            relative = frame,
            relativePoint = "BOTTOM",
            y = 16,
        },
        click = function()
            frame:Hide()
        end,
    })

    Meeting.SettingsFrame = frame
    return frame
end

function Meeting.Settings.ToggleSettingsFrame()
    local frame = CreateSettingsFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        Meeting.Settings.Apply()
        frame:Show()
    end
end

Meeting.Settings.EnsureDefaults()
