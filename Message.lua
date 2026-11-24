local Message = {}

Meeting.Message = Message
Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
local EVENTS = {
    CREATE = "C",
    REQUEST = "R",
    DECLINE = "D",
    MEMBERS = "M",
    CLOSE = "L",
    VERSION = "V",
}

local function CheckBlockWords(playerName, message, skipDBB)
    -- Never block self
    if playerName == Meeting.player then
        return false
    end
    
    -- Skip empty messages
    if not message or message == "" or message == "_" then
        return false
    end
    
    -- Check Meeting block words
    if Meeting.blockWords and table.getn(Meeting.blockWords) > 0 then
        local lowerMessage = string.lower(message)
        for _, word in ipairs(Meeting.blockWords) do
            if word and word ~= "" then
                local lowerWord = string.lower(word)
                if string.find(lowerMessage, lowerWord, 1, true) then
                    return true
                end
            end
        end
    end

    -- Shared Blacklist synergy with DifficultBulletinBoard (if loaded)
    if not skipDBB and type(DBB2) == "table" and DBB2.api and type(DBB2.api.IsMessageBlacklisted) == "function" then
        if DBB2.api.IsMessageBlacklisted(message, playerName, true) then
            return true
        end
    end
    
    return false
end

Meeting.CheckBlockWords = CheckBlockWords

function Message.OnRecv(playerName, data)
    local _, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 = string.meetingsplit(data, ":")
    if event == EVENTS.CREATE then
        -- 检查活动说明中的屏蔽词
        if CheckBlockWords(playerName, arg2) then
            return
        end
        -- 检查队长名字中的屏蔽词
        if CheckBlockWords(playerName, playerName) then
            return
        end
        if Meeting.OnCreate then
            Meeting:OnCreate(playerName, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
        end
    elseif event == EVENTS.REQUEST then
        if Meeting.OnRequest then
            Meeting:OnRequest(playerName, arg1, arg2, arg3, arg4, arg5, arg6)
        end
    elseif event == EVENTS.DECLINE then
        if Meeting.OnDecline then
            Meeting:OnDecline(playerName, arg1)
        end
    elseif event == EVENTS.MEMBERS then
        if Meeting.OnMembers then
            Meeting:OnMembers(playerName, arg1, arg2)
        end
    elseif event == EVENTS.CLOSE then
        if Meeting.OnClose then
            Meeting:OnClose(playerName)
        end
    elseif event == EVENTS.VERSION then
        if Meeting.OnVersion then
            Meeting:OnVersion(arg1)
        end
    end
end

local matchText = {}
for _, category in ipairs(Meeting.Categories) do
    for _, value in ipairs(category.children) do
        if value.match then
            for _, match in ipairs(value.match) do
                table.insert(matchText, string.lower(match))
            end
        end
    end
end

local distinct = {}
for _, v in ipairs(matchText) do
    if not distinct[v] then
        distinct[v] = true
    end
end
matchText = {}
for k, _ in pairs(distinct) do
    table.insert(matchText, k)
end
distinct = nil

function Message.OnRecvFormChat(channel, playerName, message)
    -- Quest link detection: |Hquest:id:level|h[name]|h
	if string.find(message, "|Hquest:", 1, true) then
		local questStart = string.find(message, "|Hquest:", 1, true)
		if questStart then
			local bracketStart = string.find(message, "[", questStart, true)
			if bracketStart then
				local bracketEnd = string.find(message, "]", bracketStart, true)
				if bracketEnd then
					local pipeHStart = string.find(message, "|h", bracketEnd, true)
					if pipeHStart then
						local linkPart = string.sub(message, questStart, pipeHStart + 1)
						local _, _, questID, questLevel, questName = string.find(
							linkPart,
							"|Hquest:(%d+):(%d+)|h%[([^%]]*)%]|h"
						)
						if questID and questLevel and questName then
							if Meeting.OnCreate then
								Meeting:OnCreate(playerName, "QuestLink",
									questName,
									questLevel,
									"0",
									"0",
									"0",
									nil
								)
							end
							return
						end
					end
				end
			end
		end
	end

    local activity = Meeting.FindActivity and Meeting:FindActivity(playerName)
    if activity and activity.IsChat and not activity:IsChat() then
        return
    end
    local lowerMessage = string.lower(message)
    if string.find(lowerMessage, "求组", 1, true) or string.find(lowerMessage, "lfg", 1, true) then
        return
    end
    if CheckBlockWords(playerName, message) then
        return
    end
    
    -- 获取当前的多选状态和排除关键词
    local matchs, nomatchs = SetMathcKeyWords()
    
    -- 如果没有选择任何活动类型，或者选择了"全部"，则匹配所有
    local shouldMatchAll = Meeting.searchInfo.category == "" or 
                          (Meeting.searchInfo.category ~= "" and Meeting.searchInfo.code == "" and not next(Meeting.searchInfo.codes))
    
    -- 先检查排除关键词
    for _, nomatch in ipairs(nomatchs) do
        if string.find(lowerMessage, string.lower(nomatch), 1, true) then
            return  -- 如果包含排除关键词，不创建活动
        end
    end
    
    -- 如果选择了"全部"或者没有选择任何过滤条件，使用原来的匹配逻辑
    if shouldMatchAll then
        for _, v in ipairs(matchText) do
            if string.find(lowerMessage, v, 1, true) then
                if Meeting.OnCreate then
                    Meeting:OnCreate(playerName, string.upper(channel), message, "0", "0", "0",
                        channel == "hardcore" and "1" or "0")
                end
                return
            end
        end
    else
        -- 多选状态下的匹配逻辑
        for _, match in ipairs(matchs) do
            if string.find(lowerMessage, string.lower(match), 1, true) then
                if Meeting.OnCreate then
                    Meeting:OnCreate(playerName, string.upper(channel), message, "0", "0", "0",
                        channel == "hardcore" and "1" or "0")
                end
                return
            end
        end
    end
end

function Message.Send(event, msg)
    local channel = GetChannelName(Meeting.channel)
    if channel ~= 0 then
        SendChatMessage("Meeting:" .. event .. ":" .. msg, "CHANNEL", nil, channel)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Please join " .. Meeting.channel .. " channel")
    end
end

function Message.CreateActivity(code, comment)
    if not code or code == "" then
        return
    end
    local faction = UnitFactionGroup("player") or "Neutral" -- english token (e.g. "Alliance"/"Horde"), locale-independent
    local data = string.format("%s:%s:%d:%d:%d:%d:%s:%s", code,
        string.isempty(comment) and "_" or comment, UnitLevel("player"),
        Meeting.ClassToNumber(Meeting.playerClass),
        table.getn(Meeting.members) + 1, Meeting.playerIsHC and 1 or 0, Meeting.EncodeGroupClass(), faction)
    MEETING_DB.activity = {
        code = code,
        comment = comment,
        lastTime = time()
    }
    Message.InvokeSyncActivityTimer()
    Message.Send(EVENTS.CREATE, data)
end

function Message.Request(id, comment, role)
    local data = string.format("%s:%d:%d:%d:%s:%d", id, UnitLevel("player"),
        Meeting.ClassToNumber(Meeting.playerClass), Meeting.GetPlayerScore(), string.isempty(comment) and "_" or comment,
        role)
    Message.Send(EVENTS.REQUEST, data)
end

function Message.Decline(name)
    Message.Send(EVENTS.DECLINE, string.format("%s", name))
end

function Message.SyncMembers(members)
    Message.Send(EVENTS.MEMBERS, string.format("%d:%s", members, Meeting.EncodeGroupClass()))
end

function Message.CloseActivity(leave)
    Message.Send(EVENTS.CLOSE, "")
    if not leave then
        MEETING_DB.activity = nil
    end
end

function Message.SendVersion()
    Message.Send(EVENTS.VERSION, Meeting.VERSION.MAJOR .. "." .. Meeting.VERSION.MINOR .. "." .. Meeting.VERSION.PATCH)
end

local syncTimer = nil

function Message.InvokeSyncActivityTimer()
    if syncTimer then
        syncTimer:Cancel()
    end

    syncTimer = C_Timer.NewTicker(60, function()
        if Meeting.isAFK then
            return
        end
        local activity = Meeting:FindActivity(Meeting.player)
        if activity then
            Message.CreateActivity(activity.code, activity.comment)
        end
    end, -1)
end