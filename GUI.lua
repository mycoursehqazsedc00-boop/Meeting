local GUI = {

    Theme = {
        Black = {
            r = 0,
            g = 0,
            b = 0
        },
        White = {
            r = 1,
            g = 1,
            b = 1
        },
        Brown = {
            r = 24 / 255,
            g = 20 / 255,
            b = 18 / 255
        },
        LightBrown = {
            r = 53 / 255,
            g = 47 / 255,
            b = 44 / 255
        },
        Orange = {
            r = 245 / 255,
            g = 127 / 255,
            b = 26 / 255
        },
        Green = {
            r = 103 / 255,
            g = 194 / 255,
            b = 58 / 255
        },
        Red = {
            r = 245 / 255,
            g = 108 / 255,
            b = 108 / 255
        }
    },

    BUTTON_TYPE = {
        NORMAL = 1,
        PRIMARY = 2,
        SUCCESS = 3,
        DANGER = 4
    }
}

Meeting.GUI = GUI

GUI.fontElements = {}
GUI.backdropElements = {}

function GUI.GetFontSize(configSize)
    configSize = configSize or 14
    local base = 14
    if Meeting.Settings and Meeting.Settings.GetFontSize then
        base = Meeting.Settings.GetFontSize(14)
    end
    local size = configSize + (base - 14)
    if size < 8 then
        size = 8
    elseif size > 24 then
        size = 24
    end
    return size
end

function GUI.RegisterFontElement(element, configSize, fontPath, flags)
    table.insert(GUI.fontElements, {
        element = element,
        configSize = configSize,
        fontPath = fontPath or STANDARD_TEXT_FONT,
        flags = flags,
    })
end

function GUI.RefreshFonts()
    for _, entry in ipairs(GUI.fontElements) do
        entry.element:SetFont(entry.fontPath, GUI.GetFontSize(entry.configSize), entry.flags)
    end
end

function GUI.RefreshBackgrounds()
    for _, entry in ipairs(GUI.backdropElements) do
        GUI.ApplyBackground(entry.frame, entry.color, entry.borderColor)
    end
end

function GUI.EnableMovable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
end

function GUI.EnableResizable(frame, config)
    config = config or {}
    if frame._resizeButton then
        frame:RefreshResizeGrip()
        return frame._resizeButton
    end

    frame:SetResizable(true)
    frame:EnableMouse(true)
    if frame.SetMinResize then
        frame:SetMinResize(config.minWidth or 600, config.minHeight or 320)
    end
    if frame.SetMaxResize then
        frame:SetMaxResize(config.maxWidth or 1200, config.maxHeight or 800)
    end
    frame:SetClampedToScreen(true)

    local resizeName = (frame:GetName() or "MeetingFrame") .. "Resize"
    local resize = CreateFrame("Button", resizeName, UIParent)
    resize:SetWidth(20)
    resize:SetHeight(20)
    resize:SetFrameStrata("TOOLTIP")
    resize:EnableMouse(true)
    resize:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    resize:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    resize:SetBackdropBorderColor(1, 0.82, 0, 1)

    local knob = resize:CreateTexture(nil, "ARTWORK")
    knob:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    knob:SetWidth(14)
    knob:SetHeight(14)
    knob:SetPoint("CENTER", resize, "CENTER", 0, 0)

    frame._resizeButton = resize
    frame._resizeConfig = config

    function frame:RefreshResizeGrip()
        local grip = self._resizeButton
        if not grip then
            return
        end
        grip:ClearAllPoints()
        grip:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2)
        if self:IsShown() then
            grip:Show()
        else
            grip:Hide()
        end
    end

    local sizingLayoutPending = false

    local function flushSizingLayout()
        sizingLayoutPending = false
        frame:SetScript("OnUpdate", nil)
    end

    local function onResizeMouseDown()
        frame.sizing = true
        frame:StartSizing()
    end

    local function onResizeMouseUp()
        frame.sizing = false
        frame:StopMovingOrSizing()
        flushSizingLayout()
        local cfg = frame._resizeConfig
        if cfg and cfg.onSizeChanged then
            cfg.onSizeChanged(frame)
        end
        if cfg and cfg.onResizeStop then
            cfg.onResizeStop(frame:GetWidth(), frame:GetHeight())
        end
        frame:RefreshResizeGrip()
    end

    resize:SetScript("OnMouseDown", onResizeMouseDown)
    resize:SetScript("OnMouseUp", onResizeMouseUp)

    frame:SetScript("OnShow", function()
        frame:RefreshResizeGrip()
    end)
    frame:SetScript("OnHide", function()
        flushSizingLayout()
        if frame._resizeButton then
            frame._resizeButton:Hide()
        end
    end)

    if config.onSizeChanged then
        frame:SetScript("OnSizeChanged", function()
            if frame.sizing then
                if not sizingLayoutPending then
                    sizingLayoutPending = true
                    frame:SetScript("OnUpdate", function()
                        flushSizingLayout()
                        config.onSizeChanged(frame)
                    end)
                end
            else
                config.onSizeChanged(frame)
            end
        end)
    end

    frame:RefreshResizeGrip()
    return resize
end

function GUI.ApplyBackground(frame, color, borderColor)
    local useBlizzard = Meeting.Settings and Meeting.Settings.UsesBlizzardBorders and Meeting.Settings.UsesBlizzardBorders()
    local alpha = 0.5
    if Meeting.Settings and Meeting.Settings.GetBackgroundAlpha then
        alpha = Meeting.Settings.GetBackgroundAlpha()
    end
    local bg

    if useBlizzard then
        bg = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        }
    else
        bg = {
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 0.7,
            insets = {
                left = -0.7,
                right = -0.7,
                top = -0.7,
                bottom = -0.7
            }
        }
        if borderColor then
            bg.edgeFile = "Interface\\BUTTONS\\WHITE8X8"
        end
    end

    frame:SetBackdrop(bg)

    if not color then
        color = GUI.Theme.Black
    end

    if useBlizzard then
        frame:SetBackdropColor(0, 0, 0, alpha)
        if borderColor then
            frame:SetBackdropBorderColor(1, 1, 1, 1)
        end
    else
        frame:SetBackdropColor(color.r, color.g, color.b, alpha)
        if borderColor then
            frame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)
        end
    end
end

function GUI.SetBackground(frame, color, borderColor)
    local found = false
    for _, entry in ipairs(GUI.backdropElements) do
        if entry.frame == frame then
            entry.color = color
            entry.borderColor = borderColor
            found = true
            break
        end
    end
    if not found then
        table.insert(GUI.backdropElements, {
            frame = frame,
            color = color,
            borderColor = borderColor,
        })
    end
    GUI.ApplyBackground(frame, color, borderColor)
end

function GUI.CreateFrame(config)
    local parent = config.parent or UIParent
    local frame = CreateFrame(config.frameType or "Frame", config.name, parent, config.template)
    frame:SetWidth(config.width or 0)
    frame:SetHeight(config.height or 0)
    if config.anchor then
        frame:SetPoint(config.anchor.point, config.anchor.relative, config.anchor.relativePoint, config.anchor.x or 0,
            config.anchor.y or 0)
    end
    if config.background then
        GUI.SetBackground(frame, config.background)
    end
    if config.movable then
        GUI.EnableMovable(frame)
    end
    if config.hide then
        frame:Hide()
    end
    return frame
end

function GUI.CreateText(config)
    local parent = config.parent or UIParent
    local text = parent:CreateFontString(nil)
    text:SetWidth(config.width or 0)
    text:SetHeight(config.height or 0)
    local fontSize = GUI.GetFontSize(config.fontSize or 14)
    text:SetFont(STANDARD_TEXT_FONT, fontSize)
    GUI.RegisterFontElement(text, config.fontSize or 14)
    if config.anchor then
        text:SetPoint(config.anchor.point, config.anchor.relative, config.anchor.relativePoint, config.anchor.x or 0,
            config.anchor.y or 0)
    end
    if config.color then
        text:SetTextColor(config.color.r, config.color.g, config.color.b)
    else
        text:SetTextColor(1, 1, 1)
    end
    text:SetJustifyH("LEFT")
    local displayText = config.text or ""
    if Meeting.WT and Meeting.WT.L then
        displayText = Meeting.WT.L(displayText)
    end
    text:SetText(displayText)
    return text
end

function GUI.ApplyButtonType(button, buttonType)
    if not button or button._meetingPlainRow then
        return
    end
    buttonType = buttonType or GUI.BUTTON_TYPE.NORMAL
    if buttonType == GUI.BUTTON_TYPE.DANGER then
        button:SetTextColor(1, 0.25, 0.25)
    elseif buttonType == GUI.BUTTON_TYPE.SUCCESS then
        button:SetTextColor(0.25, 1, 0.25)
    elseif buttonType == GUI.BUTTON_TYPE.PRIMARY then
        button:SetTextColor(1, 0.82, 0)
    else
        button:SetTextColor(1, 0.82, 0)
    end
end

function GUI.CreateButton(config)
    local parent = config.parent or UIParent
    local useBlizzard = config.blizzard ~= false
    local button

    if useBlizzard then
        button = CreateFrame("Button", config.name, parent, "UIPanelButtonTemplate")
        button:SetWidth(config.width or 80)
        button:SetHeight(config.height or 22)
        if config.anchor then
            button:SetPoint(config.anchor.point, config.anchor.relative, config.anchor.relativePoint,
                config.anchor.x or 0, config.anchor.y or 0)
        end
    else
        config.frameType = "Button"
        button = GUI.CreateFrame(config)
        if not config.type then
            config.type = GUI.BUTTON_TYPE.NORMAL
        end
        if config.type == GUI.BUTTON_TYPE.NORMAL then
            GUI.SetBackground(button, GUI.Theme.Brown)
        elseif config.type == GUI.BUTTON_TYPE.PRIMARY then
            GUI.SetBackground(button, GUI.Theme.Orange)
        elseif config.type == GUI.BUTTON_TYPE.SUCCESS then
            GUI.SetBackground(button, GUI.Theme.Green)
        elseif config.type == GUI.BUTTON_TYPE.DANGER then
            GUI.SetBackground(button, GUI.Theme.Red)
        end
    end

    button:SetText((Meeting.WT and Meeting.WT.L and Meeting.WT.L(config.text or "")) or (config.text or ""))
    if useBlizzard then
        if not config.type then
            config.type = GUI.BUTTON_TYPE.NORMAL
        end
        GUI.ApplyButtonType(button, config.type)
    else
        button:SetTextColor(1, 1, 1)
        button:SetDisabledTextColor(0.8, 0.8, 0.8)
    end

    local fontSize = GUI.GetFontSize(config.fontSize or 16)
    button:SetFont(STANDARD_TEXT_FONT, fontSize)
    GUI.RegisterFontElement(button, config.fontSize or 16)

    button:SetScript("OnClick", function()
        if config.click then
            config.click(arg1)
        end
    end)

    if config.disabled then
        button:Disable()
    end
    if config.movable then
        GUI.EnableMovable(button)
    end
    if config.hide then
        button:Hide()
    end

    return button
end

local function CreateListRow(parent, width, anchorRelative, index, step)
    local cell = CreateFrame("Button", nil, parent)
    cell._meetingPlainRow = true
    cell:SetWidth(width)
    cell:SetHeight(step)
    cell:SetPoint("TOPLEFT", anchorRelative, "BOTTOMLEFT", 0, -step * (index - 1))
    cell:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function()
        this:OnHover(true)
    end)
    cell:SetScript("OnLeave", function()
        this:OnHover(false)
    end)
    return cell
end

function GUI.CreateListFrame(config)
    config.frameType = "ScrollFrame"
    config.template = "FauxScrollFrameTemplate"
    config.maxDisplay = config.maxDisplay or config.display
    local frame = GUI.CreateFrame(config)
    frame.pool = {}
    for i = 1, config.maxDisplay do
        local cell = CreateListRow(config.parent, config.width, config.anchor.relative, i, config.step)
        cell:Hide()
        table.insert(frame.pool, cell)
        config.cell(cell)
    end
    frame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(config.step, function()
            this.OnScroll(this, true, true)
        end)
    end)
    frame.UpdateLayout = function(self, width, height)
        local display = math.floor(height / config.step)
        if display < 3 then
            display = 3
        elseif display > config.maxDisplay then
            display = config.maxDisplay
        end

        self:SetWidth(width)
        self:SetHeight(height)
        config.width = width
        config.height = height
        config.display = display

        for i, cell in ipairs(self.pool) do
            cell:SetWidth(width)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", config.anchor.relative, "BOTTOMLEFT", 0, -config.step * (i - 1))
            if i > display then
                cell:Hide()
            end
        end

        if self.onLayout then
            self.onLayout(width, display)
        end
    end
    frame.Reload = function(self, num, cb)
        if num < config.display then
            for i = num + 1, config.display do
                local cell = frame.pool[i]
                cell:Hide()
            end
        end

        FauxScrollFrame_Update(self, num, config.display, config.step, nil, nil, nil, nil, config.width, config
            .height)
        local offset = FauxScrollFrame_GetOffset(self)
        for i = 1, config.display, 1 do
            local j = i + offset
            if j <= num then
                local cell = frame.pool[i]
                cell:Show()
                cb(cell, j)
            end
        end
    end
    return frame
end

function GUI.CreateTabs(config)
    local tabWidth = config.width
    local tabHeight = config.height or 32
    local tabOverlap = config.tabOverlap or -16
    local isBottom = config.edge == "bottom"
    local selectedRise = config.selectedRise or 3
    local frameName = config.name or "MeetingTabFrame"
    config.name = frameName
    local numTabs = table.getn(config.list)

    if isBottom then
        config.width = numTabs * tabWidth + (numTabs - 1) * tabOverlap
        config.height = tabHeight
    end

    local frame = GUI.CreateFrame(config)
    frame.tabs = {}

    local function layoutBottomTabs(selectedIndex)
        selectedIndex = selectedIndex or frame.selectedTab or 1
        local x = 0
        for i, tab in ipairs(frame.tabs) do
            local y = (i == selectedIndex) and selectedRise or 0
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
            x = x + tab:GetWidth() + tabOverlap
        end
    end

    for index, value in ipairs(config.list) do
        local info = value
        local prev = frame.tabs[index - 1]
        local buttonName = frameName .. "Tab" .. index
        local button = CreateFrame("Button", buttonName, frame, "CharacterFrameTabButtonTemplate")
        button:SetID(index)
        button:SetText(info.title)
        button:SetWidth(tabWidth)
        button:SetHeight(tabHeight)
        if not isBottom then
            if index == 1 then
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            else
                button:SetPoint("LEFT", prev, "RIGHT", tabOverlap, 0)
            end
        end
        button:SetScript("OnClick", function()
            local id = this:GetID()
            if PanelTemplates_SetTab then
                PanelTemplates_SetTab(frame, id)
            end
            if isBottom then
                frame.selectedTab = id
                layoutBottomTabs(id)
            end
            info.select(index)
        end)
        table.insert(frame.tabs, button)
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(frame, numTabs)
    end
    if PanelTemplates_SetTab then
        PanelTemplates_SetTab(frame, config.default or 1)
    end
    if isBottom then
        frame.selectedTab = config.default or 1
        layoutBottomTabs(frame.selectedTab)
    end
end

function GUI.CreateInput(config)
    config.frameType = "EditBox"
    local frame = GUI.CreateFrame(config)
    frame:SetFontObject("ChatFontNormal")
    if config.limit then
        frame:SetMaxBytes(config.limit)
    end
    frame:SetScript("OnEscapePressed", function()
        frame:ClearFocus()
    end)
    frame:SetAutoFocus(false)
    frame:SetMultiLine(config.multiLine or false)
    return frame
end

function GUI.CreateDialog(config)
    if Meeting.GUI.currentDialog then
        Meeting.GUI.currentDialog:Hide()
    end

    config.width = config.width or 300
    config.height = config.height or 75
    local parent = GUI.CreateFrame(config)
    parent:SetFrameLevel(999)
    GUI.SetBackground(parent, GUI.Theme.Black, GUI.Theme.Black)
    local title = GUI.CreateText({
        parent = parent,
        width = config.width,
        height = 20,
        anchor = {
            point = "TOP",
            relative = parent,
            relativePoint = "TOP",
            x = 10,
            y = -10
        },
        text = config.title,
        color = GUI.Theme.White
    })

    local customFrame = nil
    if config.onCustomFrame then
        customFrame = config.onCustomFrame(parent, title)
    end

    GUI.CreateButton({
        parent = parent,
        width = 80,
        height = 24,
        text = "OK",
        type = GUI.BUTTON_TYPE.PRIMARY,
        anchor = {
            point = "TOPRIGHT",
            relative = customFrame or title,
            relativePoint = "BOTTOMRIGHT",
            x = 0,
            y = -10
        },
        click = function()
            config._confirm()
            parent:Hide()
            Meeting.GUI.currentDialog = nil
        end
    })

    GUI.CreateButton({
        parent = parent,
        width = 80,
        height = 24,
        text = "Cancel",
        type = GUI.BUTTON_TYPE.DANGER,
        anchor = {
            point = "TOPLEFT",
            relative = customFrame or title,
            relativePoint = "BOTTOMLEFT",
            x = 0,
            y = -10
        },
        click = function()
            parent:Hide()
            Meeting.GUI.currentDialog = nil
        end
    })
    Meeting.GUI.currentDialog = parent
    return parent
end

function GUI.CreateCheck(config)
    config.frameType = "CheckButton"
    local c = CreateFrame("CheckButton", config.name, config.parent, "UICheckButtonTemplate")
    c:SetWidth(config.width or 20)
    c:SetHeight(config.height or 20)
    if config.anchor then
        c:SetPoint(config.anchor.point, config.anchor.relative, config.anchor.relativePoint, config.anchor.x or 0,
            config.anchor.y or 0)
    end
    c:SetScript("OnClick", function()
        if config.click then
            config.click(this:GetChecked())
        end
    end)
    if config.checked then
        c:SetChecked(true)
    else
        c:SetChecked(false)
    end
    return c
end
