Meeting.WT = {}

local STRINGS = {
    ["-- 成员 --"] = "-- Members --",
    ["<双击>悄悄话"] = "<Double-click> Whisper",
    ["申请加入"] = "Apply to join ",
    ["个"] = "",
}

local commentCache = {}

local translateQueue = {}
local translateInFlight = 0
local translatePendingByText = {}
local MAX_TRANSLATE_INFLIGHT = 4
local translating = false
local translateBatchId = 0
local activeBatch = nil

local OUTGOING_LANG_NAMES = {
    zh = "Chinese",
    en = "English",
    ko = "Korean",
    ja = "Japanese",
    ru = "Russian",
    de = "German",
    fr = "French",
    es = "Spanish",
    pt = "Portuguese",
}

local function PreprocessOutgoing(text)
    if not text then
        return text
    end
    text = string.gsub(text, "(%d+)g([^%a])", "%1G%2")
    text = string.gsub(text, "(%d+)g$", "%1G")
    if string.find(text, "%d+[gG]") then
        text = string.gsub(text, "(%d+)s([^%a])", "%1Y%2")
        text = string.gsub(text, "(%d+)s$", "%1Y")
    end
    return text
end

local function ApplyOutgoingGlossary(text)
    local outFromLang = WoWTranslateDB and WoWTranslateDB.outgoingFromLang or "en"
    if outFromLang == "en" then
        text = PreprocessOutgoing(text)
        if WoWTranslate_CheckOutGlossaryExact then
            local glossaryResult = WoWTranslate_CheckOutGlossaryExact(text)
            if not glossaryResult and WoWTranslate_CheckOutGlossaryPartial then
                glossaryResult = WoWTranslate_CheckOutGlossaryPartial(text)
            end
            if glossaryResult then
                return glossaryResult
            end
        end
    else
        if WoWTranslate_CheckGlossaryExact then
            local glossaryResult = WoWTranslate_CheckGlossaryExact(text)
            if not glossaryResult and WoWTranslate_CheckGlossaryPartial then
                glossaryResult = WoWTranslate_CheckGlossaryPartial(text)
            end
            if glossaryResult then
                return glossaryResult
            end
        end
    end
    return text
end

local function SanitizeMeetingComment(text)
    text = string.gsub(text or "", "\n", "")
    text = string.gsub(text, ":", "：")
    return text
end

local function IsLikelyEnglish(text)
    local total = string.len(text or "")
    if total == 0 then
        return true
    end
    local ascii = 0
    for i = 1, total do
        if string.byte(text, i) < 128 then
            ascii = ascii + 1
        end
    end
    return (ascii / total) > 0.8
end

function Meeting.WT.IsInstalled()
    return WoWTranslateDB ~= nil
        and (WoWTranslate_CheckGlossary or WoWTranslate_API)
end

function Meeting.WT.IsEnabled()
    if not Meeting.WT.IsInstalled() then
        return false
    end
    return MEETING_DB and MEETING_DB.translateEnabled == 1
end

function Meeting.WT.CanTranslateOutgoing()
    return Meeting.WT.IsInstalled()
        and WoWTranslate_API
        and WoWTranslate_API.IsAvailable()
end

function Meeting.WT.GetOutgoingTargetLang()
    if WoWTranslateDB and WoWTranslateDB.outgoingToLang then
        return WoWTranslateDB.outgoingToLang
    end
    return "zh"
end

function Meeting.WT.GetOutgoingTargetLangName()
    local code = Meeting.WT.GetOutgoingTargetLang()
    return OUTGOING_LANG_NAMES[code] or code
end

function Meeting.WT.UpdateHeaderButtons()
    local toggleBtn = Meeting.MainFrame and Meeting.MainFrame.translateButton
    local refreshBtn = Meeting.MainFrame and Meeting.MainFrame.translateRefreshButton
    if not toggleBtn and not refreshBtn then
        return
    end
    if not Meeting.WT.IsInstalled() then
        if toggleBtn then toggleBtn:Hide() end
        if refreshBtn then refreshBtn:Hide() end
        return
    end
    if toggleBtn then
        toggleBtn:Show()
        toggleBtn:Enable()
        toggleBtn:SetText("Translate")
        if Meeting.WT.IsEnabled() then
            Meeting.GUI.SetBackground(toggleBtn, Meeting.GUI.Theme.Green)
            Meeting.GUI.ApplyButtonType(toggleBtn, Meeting.GUI.BUTTON_TYPE.SUCCESS)
        else
            Meeting.GUI.SetBackground(toggleBtn, Meeting.GUI.Theme.Orange)
            Meeting.GUI.ApplyButtonType(toggleBtn, Meeting.GUI.BUTTON_TYPE.PRIMARY)
        end
    end
    if refreshBtn then
        refreshBtn:Show()
        if translating then
            refreshBtn:Disable()
            refreshBtn:SetText("...")
        else
            refreshBtn:Enable()
            refreshBtn:SetText("Refresh")
            Meeting.GUI.SetBackground(refreshBtn, Meeting.GUI.Theme.Orange)
            Meeting.GUI.ApplyButtonType(refreshBtn, Meeting.GUI.BUTTON_TYPE.PRIMARY)
        end
    end
    if Meeting.Layout and Meeting.Layout.ApplyHeader and Meeting.MainFrame then
        Meeting.Layout.ApplyHeader(Meeting.MainFrame:GetWidth())
    end
end

function Meeting.WT.UpdateHeaderButton()
    Meeting.WT.UpdateHeaderButtons()
end

function Meeting.WT.ApplyVisible()
    if Meeting.BrowserFrame and Meeting.BrowserFrame:IsShown() and Meeting.BrowserFrame.UpdateList then
        Meeting.BrowserFrame:UpdateList()
    end
    if Meeting.CreatorFrame and Meeting.CreatorFrame:IsShown() and Meeting.CreatorFrame.UpdateList then
        Meeting.CreatorFrame:UpdateList()
    end
end

function Meeting.WT.RestoreVisible()
    Meeting.WT.ApplyVisible()
end

function Meeting.WT.SetEnabled(enabled)
    if not MEETING_DB then
        MEETING_DB = {}
    end
    MEETING_DB.translateEnabled = enabled and 1 or 0
    Meeting.WT.ApplyVisible()
    Meeting.WT.UpdateHeaderButtons()
end

function Meeting.WT.ToggleEnabled()
    if not Meeting.WT.IsInstalled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: WoWTranslate is not available.")
        return
    end
    Meeting.WT.SetEnabled(not Meeting.WT.IsEnabled())
end

function Meeting.WT.L(text)
    if not text or text == "" then
        return text or ""
    end
    if STRINGS[text] then
        return STRINGS[text]
    end
    if Meeting.WT.IsEnabled() and WoWTranslate_CheckGlossary then
        local glossary = WoWTranslate_CheckGlossary(text)
        if glossary then
            return glossary
        end
    end
    return text
end

function Meeting.WT.FormatClassCount(clsname, count)
    if Meeting.WT.IsEnabled() then
        return clsname .. " x" .. count
    end
    return clsname .. " " .. count .. "个"
end

function Meeting.WT.LookupCached(text)
    if not text or text == "" or text == "_" then
        return text or ""
    end
    if commentCache[text] then
        return commentCache[text]
    end
    local quick = Meeting.WT.L(text)
    if quick ~= text then
        commentCache[text] = quick
        return quick
    end
    if WoWTranslate_CacheGet then
        local cached, found = WoWTranslate_CacheGet("meeting:" .. text)
        if found then
            commentCache[text] = cached
            return cached
        end
        cached, found = WoWTranslate_CacheGet(text)
        if found then
            commentCache[text] = cached
            return cached
        end
    end
    return text
end

function Meeting.WT.DisplayText(text)
    text = text or ""
    if text == "" or text == "_" then
        return ""
    end
    if not Meeting.WT.IsEnabled() or IsLikelyEnglish(text) then
        return text
    end
    return Meeting.WT.LookupCached(text)
end

function Meeting.WT.TranslateSync(text)
    if not Meeting.WT.IsEnabled() then
        return text or ""
    end
    if not text or text == "" or text == "_" or IsLikelyEnglish(text) then
        return text or ""
    end
    return Meeting.WT.LookupCached(text)
end

local function FlushTranslateWaiters(text, result)
    local waiters = translatePendingByText[text]
    translatePendingByText[text] = nil
    if not waiters then
        return
    end
    for i = 1, table.getn(waiters) do
        waiters[i](result)
    end
end

local function PumpTranslateQueue()
    while translateInFlight < MAX_TRANSLATE_INFLIGHT and table.getn(translateQueue) > 0 do
        local text = table.remove(translateQueue, 1)
        if not translatePendingByText[text] then
            -- Skip stale queue entry.
        else
            local sync = Meeting.WT.LookupCached(text)
            if sync ~= text then
                FlushTranslateWaiters(text, sync)
            elseif not WoWTranslate_API or not WoWTranslate_API.IsAvailable() then
                FlushTranslateWaiters(text, text)
            else
                translateInFlight = translateInFlight + 1
                local ok = WoWTranslate_API.Translate(text, function(translation, err)
                    translateInFlight = translateInFlight - 1
                    local result = text
                    if translation and translation ~= "" then
                        commentCache[text] = translation
                        if WoWTranslate_CacheSave then
                            WoWTranslate_CacheSave("meeting:" .. text, translation)
                        end
                        result = translation
                    end
                    FlushTranslateWaiters(text, result)
                    PumpTranslateQueue()
                end, "zh")
                if not ok then
                    translateInFlight = translateInFlight - 1
                    table.insert(translateQueue, 1, text)
                    if not translateQueue._retryScheduled then
                        translateQueue._retryScheduled = true
                        C_Timer.After(0.25, function()
                            translateQueue._retryScheduled = nil
                            PumpTranslateQueue()
                        end)
                    end
                    return
                end
            end
        end
    end
end

function Meeting.WT.TranslateIncoming(text, callback)
    if not callback then
        return
    end
    if not text or text == "" or text == "_" then
        callback(text or "")
        return
    end
    if IsLikelyEnglish(text) then
        callback(text)
        return
    end
    local sync = Meeting.WT.LookupCached(text)
    if sync ~= text then
        callback(sync)
        return
    end
    if not WoWTranslate_API or not WoWTranslate_API.IsAvailable() then
        callback(text)
        return
    end

    if not translatePendingByText[text] then
        translatePendingByText[text] = {}
        table.insert(translateQueue, text)
    end
    table.insert(translatePendingByText[text], callback)
    PumpTranslateQueue()
end

function Meeting.WT.TranslateOutgoing(text, callback)
    if not callback then
        return
    end
    text = string.trim(text or "")
    if text == "" then
        callback(nil, "Description is empty")
        return
    end
    if not Meeting.WT.CanTranslateOutgoing() then
        callback(nil, "WoWTranslate is not available")
        return
    end

    local textToTranslate = ApplyOutgoingGlossary(text)
    WoWTranslate_API.TranslateOutgoing(textToTranslate, function(translation, err)
        if translation and translation ~= "" then
            translation = SanitizeMeetingComment(translation)
            if string.len(translation) > 200 then
                translation = string.sub(translation, 1, 200)
            end
            callback(translation, nil)
        else
            callback(nil, err or "Translation failed")
        end
    end)
end

local function TranslateFontString(fontString, text, stillValid, batch)
    if not fontString or not text or text == "" or text == "_" or IsLikelyEnglish(text) then
        return
    end

    batch.pending = batch.pending + 1
    Meeting.WT.TranslateIncoming(text, function(result)
        batch.pending = batch.pending - 1
        if batch.id ~= translateBatchId then
            Meeting.WT.ScheduleFinishTranslateBatch()
            return
        end
        if stillValid and not stillValid() then
            Meeting.WT.ScheduleFinishTranslateBatch()
            return
        end
        if Meeting.WT.IsEnabled() then
            fontString:SetText(result)
        end
        Meeting.WT.ScheduleFinishTranslateBatch()
    end)
end

function Meeting.WT.ScheduleFinishTranslateBatch()
    C_Timer.After(0, function()
        Meeting.WT.TryFinishTranslateBatch()
    end)
end

function Meeting.WT.TryFinishTranslateBatch()
    if not translating or not activeBatch then
        return
    end
    if activeBatch.pending > 0 then
        return
    end
    if translateInFlight > 0 or table.getn(translateQueue) > 0 then
        return
    end

    translating = false
    activeBatch = nil
    Meeting.WT.UpdateHeaderButtons()
    if Meeting.WT.IsEnabled() then
        Meeting.WT.ApplyVisible()
    end
end

function Meeting.WT.RefreshVisible()
    if translating then
        return
    end
    Meeting.WT.TranslateVisible()
end

function Meeting.WT.TranslateVisible()
    if not Meeting.WT.IsInstalled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: WoWTranslate is not available.")
        return
    end
    if not WoWTranslate_API or not WoWTranslate_API.IsAvailable() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: WoWTranslate API is unavailable.")
        return
    end

    translateBatchId = translateBatchId + 1
    local batchId = translateBatchId
    activeBatch = { id = batchId, pending = 0 }
    translating = true
    Meeting.WT.UpdateHeaderButtons()

    local batch = activeBatch

    local listFrame = Meeting.Layout and Meeting.Layout.activityListFrame
    if listFrame and listFrame.pool and Meeting.BrowserFrame and Meeting.BrowserFrame:IsShown() then
        for _, cell in ipairs(listFrame.pool) do
            if cell:IsShown() and cell.activity then
                local activity = cell.activity
                local info = Meeting.GetActivityInfo(activity.code)
                TranslateFontString(cell.nameFrame, info and info.name, function()
                    return cell.activity == activity
                end, batch)
                TranslateFontString(cell.leaderFrame, activity.unitname, function()
                    return cell.activity == activity
                end, batch)
                local comment = activity.comment ~= "_" and activity.comment or ""
                TranslateFontString(cell.commentFrame, comment, function()
                    return cell.activity == activity
                end, batch)
            end
        end
    end

    local applicantList = Meeting.Layout and Meeting.Layout.applicantListFrame
    if applicantList and applicantList.pool and Meeting.CreatorFrame and Meeting.CreatorFrame:IsShown() then
        for _, cell in ipairs(applicantList.pool) do
            if cell:IsShown() and cell.applicant then
                local applicant = cell.applicant
                local comment = applicant.comment ~= "_" and applicant.comment or ""
                TranslateFontString(cell.commentFrame, comment, function()
                    return cell.applicant == applicant
                end, batch)
            end
        end
    end

    Meeting.WT.ScheduleFinishTranslateBatch()

    C_Timer.After(35, function()
        if translating and activeBatch and activeBatch.id == batchId then
            translating = false
            activeBatch = nil
            Meeting.WT.UpdateHeaderButtons()
            if Meeting.WT.IsEnabled() then
                Meeting.WT.ApplyVisible()
            end
        end
    end)
end

function Meeting.WT.SetFontStringText(fontString, text)
    if fontString then
        fontString:SetText(text or "")
    end
end

function Meeting.WT.AddTooltipLine(text, r, g, b, a)
    if not text or text == "" or text == "_" then
        return
    end
    GameTooltip:AddLine(Meeting.WT.TranslateSync(text), r or 1, g or 1, b or 1, a or 1)
end
