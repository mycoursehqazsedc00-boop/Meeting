Meeting.Layout = Meeting.Layout or {}

local DEFAULT_WIDTH = 818
local DEFAULT_HEIGHT = 424
local HEADER_HEIGHT = 28
local TAB_HEIGHT = 28
local CONTENT_MARGIN_X = 10
local BROWSER_INNER_X = 8
local BROWSER_LIST_BOTTOM_PAD = 4
local CREATOR_LEFT_WIDTH = 250
local CREATOR_BOTTOM_PAD = 8
local APPLICANT_HEADER_HEIGHT = 22
local LIST_STEP = 22

local BROWSER_TOOLBAR_ROW_H = 24
local BROWSER_TOOLBAR_TOP = 4
local BROWSER_LIST_HEADER_H = 22
local BROWSER_LIST_HEADER_GAP = 4
local BROWSER_SELECT_W = 140
local BROWSER_SEARCH_BTN_W = 60
local BROWSER_CLEAR_BTN_W = 60
local BROWSER_BLOCK_W = 100
local BROWSER_REFRESH_W = 80
local BROWSER_SEARCH_MAX_W = 200
local BROWSER_SEARCH_MIN_W = 60
local BROWSER_LIST_TOP = 58
local TOOLBAR_GAP = 3
local TOOLBAR_SECTION_GAP = 8
local TOOLBAR_REFRESH_PAD = 6

function Meeting.Layout.ApplyHeader(mainW)
    local frame = Meeting.MainFrame
    if not frame then
        return
    end

    local feedback = frame.feedbackText
    if feedback then
        if mainW < 700 then
            feedback:Hide()
        else
            feedback:Show()
        end
    end

    local translateBtn = frame.translateButton
    local refreshBtn = frame.translateRefreshButton
    local closeBtn = frame.closeButton
    if not closeBtn then
        return
    end

    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", frame.headerFrame, "TOPRIGHT", -6, -6)

    if refreshBtn and refreshBtn:IsShown() then
        refreshBtn:ClearAllPoints()
        refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
        if refreshBtn:IsEnabled() then
            if mainW < 520 then
                refreshBtn:SetWidth(28)
                refreshBtn:SetText("R")
            else
                refreshBtn:SetWidth(58)
                refreshBtn:SetText("Refresh")
            end
        end
    end

    if translateBtn and translateBtn:IsShown() then
        translateBtn:ClearAllPoints()
        if refreshBtn and refreshBtn:IsShown() then
            translateBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)
        else
            translateBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
        end
        if mainW < 560 then
            translateBtn:SetWidth(28)
            translateBtn:SetText("T")
        else
            translateBtn:SetWidth(58)
            translateBtn:SetText("Translate")
        end
    end
end

function Meeting.Layout.ApplyBrowserToolbar(contentW)
    local tb = Meeting.Layout.browserToolbar
    if not tb or not tb.frame then
        return BROWSER_LIST_TOP
    end

    local frame = tb.frame
    local gap = TOOLBAR_GAP
    local sectionGap = TOOLBAR_SECTION_GAP

    local fixedRight = BROWSER_SEARCH_BTN_W + gap + BROWSER_CLEAR_BTN_W + gap + BROWSER_BLOCK_W + sectionGap
    local fixedLeft = BROWSER_SELECT_W + sectionGap
    local refreshReserve = BROWSER_REFRESH_W + TOOLBAR_REFRESH_PAD
    local fullRowW = fixedLeft + BROWSER_SEARCH_MAX_W + gap + fixedRight + refreshReserve
    local singleMinW = fixedLeft + BROWSER_SEARCH_MIN_W + gap + fixedRight + refreshReserve

    local rows = 1
    if contentW < fullRowW and contentW < singleMinW then
        rows = 2
    end

    local function placeRefresh(y)
        tb.refreshButton:ClearAllPoints()
        tb.refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
    end

    if rows == 1 then
        local y = BROWSER_TOOLBAR_TOP
        local searchW = contentW - fixedLeft - gap - fixedRight - refreshReserve
        if searchW > BROWSER_SEARCH_MAX_W then
            searchW = BROWSER_SEARCH_MAX_W
        end
        if searchW < BROWSER_SEARCH_MIN_W then
            searchW = BROWSER_SEARCH_MIN_W
        end

        tb.selectButton:ClearAllPoints()
        tb.selectButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)

        tb.searchInput:SetWidth(searchW)
        tb.searchInput:ClearAllPoints()
        tb.searchInput:SetPoint("TOPLEFT", tb.selectButton, "TOPRIGHT", sectionGap, 0)

        tb.searchButton:ClearAllPoints()
        tb.searchButton:SetPoint("TOPLEFT", tb.searchInput, "TOPRIGHT", gap, 0)

        tb.clearSearchButton:ClearAllPoints()
        tb.clearSearchButton:SetPoint("TOPLEFT", tb.searchButton, "TOPRIGHT", gap, 0)

        tb.blockButton:ClearAllPoints()
        tb.blockButton:SetPoint("TOPLEFT", tb.clearSearchButton, "TOPRIGHT", sectionGap, 0)

        placeRefresh(y)
    else
        local y1 = BROWSER_TOOLBAR_TOP
        local y2 = y1 + BROWSER_TOOLBAR_ROW_H

        tb.selectButton:ClearAllPoints()
        tb.selectButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y1)

        placeRefresh(y1)

        local searchW = contentW - fixedRight
        if searchW < BROWSER_SEARCH_MIN_W then
            searchW = BROWSER_SEARCH_MIN_W
        end

        tb.searchInput:SetWidth(searchW)
        tb.searchInput:ClearAllPoints()
        tb.searchInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y2)

        tb.searchButton:ClearAllPoints()
        tb.searchButton:SetPoint("TOPLEFT", tb.searchInput, "TOPRIGHT", gap, 0)

        tb.clearSearchButton:ClearAllPoints()
        tb.clearSearchButton:SetPoint("TOPLEFT", tb.searchButton, "TOPRIGHT", gap, 0)

        tb.blockButton:ClearAllPoints()
        tb.blockButton:SetPoint("TOPLEFT", tb.clearSearchButton, "TOPRIGHT", sectionGap, 0)
    end

    local toolbarBottom = BROWSER_TOOLBAR_TOP + rows * BROWSER_TOOLBAR_ROW_H
    local listHeaderY = -(toolbarBottom + BROWSER_LIST_HEADER_GAP)
    local listTop = toolbarBottom + BROWSER_LIST_HEADER_GAP + BROWSER_LIST_HEADER_H

    tb.listHeader:ClearAllPoints()
    tb.listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", BROWSER_INNER_X, listHeaderY)

    Meeting.Layout.browserListTop = listTop
    return listTop
end

function Meeting.Layout.GetContentSize()
    local mainW = Meeting.MainFrame:GetWidth()
    local mainH = Meeting.MainFrame:GetHeight()
    return mainW - CONTENT_MARGIN_X * 2, mainH - HEADER_HEIGHT - TAB_HEIGHT
end

local function PositionContentFrame(frame)
    if not frame or not Meeting.MainFrame then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", Meeting.MainFrame, "TOPLEFT", CONTENT_MARGIN_X, -HEADER_HEIGHT)
end

function Meeting.Layout.Apply()
    if not Meeting.MainFrame then
        return
    end

    local mainW = Meeting.MainFrame:GetWidth()
    local mainH = Meeting.MainFrame:GetHeight()
    local contentW, contentH = Meeting.Layout.GetContentSize()

    if Meeting.MainFrame.headerFrame then
        Meeting.MainFrame.headerFrame:SetWidth(mainW)
    end
    if Meeting.MainFrame.headerLine then
        Meeting.MainFrame.headerLine:SetWidth(mainW)
    end
    Meeting.Layout.ApplyHeader(mainW)

    if Meeting.BrowserFrame then
        PositionContentFrame(Meeting.BrowserFrame)
        Meeting.BrowserFrame:SetWidth(contentW)
        Meeting.BrowserFrame:SetHeight(contentH)
    end
    if Meeting.CreatorFrame then
        PositionContentFrame(Meeting.CreatorFrame)
        Meeting.CreatorFrame:SetWidth(contentW)
        Meeting.CreatorFrame:SetHeight(contentH)
    end

    local browserListTop = Meeting.Layout.ApplyBrowserToolbar(contentW)

    if Meeting.Layout.activityListHeader and Meeting.Layout.activityListFrame then
        local listW = contentW - BROWSER_INNER_X * 2
        local listH = contentH - browserListTop - BROWSER_LIST_BOTTOM_PAD
        if listH < LIST_STEP * 3 then
            listH = LIST_STEP * 3
        end
        Meeting.Layout.activityListHeader:SetWidth(listW)
        Meeting.Layout.activityListFrame:UpdateLayout(listW, listH)
    end

    if Meeting.Layout.creatorInfoFrame then
        Meeting.Layout.creatorInfoFrame:SetWidth(CREATOR_LEFT_WIDTH)
        Meeting.Layout.creatorInfoFrame:SetHeight(contentH - CREATOR_BOTTOM_PAD)
    end
    if Meeting.Layout.creatorDividerLine then
        Meeting.Layout.creatorDividerLine:SetHeight(contentH)
    end
    if Meeting.Layout.applicantListHeader and Meeting.Layout.applicantListFrame then
        local listW = contentW - CREATOR_LEFT_WIDTH
        local listH = contentH - APPLICANT_HEADER_HEIGHT - CREATOR_BOTTOM_PAD
        if listH < LIST_STEP * 3 then
            listH = LIST_STEP * 3
        end
        Meeting.Layout.applicantListHeader:SetWidth(listW)
        Meeting.Layout.applicantListFrame:UpdateLayout(listW, listH)
    end

    local resizing = Meeting.MainFrame and Meeting.MainFrame.sizing
    if not resizing then
        if Meeting.BrowserFrame and Meeting.BrowserFrame:IsShown() then
            Meeting.BrowserFrame:UpdateList(true)
        elseif Meeting.CreatorFrame and Meeting.CreatorFrame:IsShown() then
            Meeting.CreatorFrame:UpdateList()
        end
    end

    if Meeting.MainFrame and Meeting.MainFrame.RefreshResizeGrip then
        Meeting.MainFrame:RefreshResizeGrip()
    end
end

function Meeting.Layout.RestoreSize()
    local w = MEETING_DB and MEETING_DB.windowWidth
    local h = MEETING_DB and MEETING_DB.windowHeight
    if w and h and Meeting.MainFrame then
        Meeting.MainFrame:SetWidth(w)
        Meeting.MainFrame:SetHeight(h)
    end
end

function Meeting.Layout.ResetSize()
    if not Meeting.MainFrame then
        return
    end
    Meeting.MainFrame:SetWidth(DEFAULT_WIDTH)
    Meeting.MainFrame:SetHeight(DEFAULT_HEIGHT)
    MEETING_DB.windowWidth = nil
    MEETING_DB.windowHeight = nil
    Meeting.Layout.Apply()
end

Meeting.GUI.EnableResizable(Meeting.MainFrame, {
    minWidth = 600,
    minHeight = 320,
    maxWidth = 1200,
    maxHeight = 800,
    onSizeChanged = function()
        Meeting.Layout.Apply()
    end,
    onResizeStop = function(w, h)
        MEETING_DB.windowWidth = w
        MEETING_DB.windowHeight = h
    end,
})

C_Timer.After(0, function()
    Meeting.Layout.RestoreSize()
    Meeting.Layout.Apply()
end)
