
## Bindings.xml
```xml
<Bindings>
	<Binding name="CS_MEETING_NAME" header="CS_MEETING_HEADER"> 
		Meeting:Toggle()
	</Binding>
</Bindings>
```

## Browser.lua
```lua
-- 添加屏蔽关键词状态 by 武藤纯子酱 2025.12.30
Meeting.blockWords = MEETING_DB.blockWords or {}
Meeting.blockDropdownState = {}  -- 屏蔽词下拉窗口状态
-- 在文件开头添加多选状态变量和下拉窗口状态 by 武藤纯子酱 2025.9.22
Meeting.multiSelect = {}
Meeting.searchInfo.codes = {}  -- 改为存储多个代码
Meeting.dropdownState = {}     -- 下拉窗口状态
-- 添加搜索文本状态 by 武藤纯子酱 2025.9.24
Meeting.searchInfo.text = ""   -- 搜索文本
Meeting.searchInfo.isComposing = false  -- 是否正在输入中文
Meeting.searchInfo.lastSearchText = ""  -- 上次搜索的文本
Meeting.searchInfo.timer = nil  -- 延迟搜索的计时器
local Menu = AceLibrary("Dewdrop-2.0")
local function CreateSyncTip()
    local tip = Meeting.GUI.CreateFrame({
        parent = Meeting.BrowserFrame,
        width = 200,
        height = 24,
        anchor = {
            point = "BOTTOMLEFT",
            relative = Meeting.BrowserFrame,
            relativePoint = "BOTTOMLEFT",
            x = 0,
            y = 4
        }
    })
    tip.text = Meeting.GUI.CreateText({
        parent = tip,
        text = "Syncing data...",
        fontSize = 10,
        width = 200,
        anchor = {
            point = "TOPLEFT",
            relative = tip,
            relativePoint = "TOPLEFT",
        }
    })
    tip:Show()
    local i = 0
    C_Timer.NewTicker(1, function()
        i = i + 1
        tip.text:SetText("Syncing data..." .. (math.mod(i, 2) == 0 and "" or "..."))
        if i >= 60 then
            tip:Hide()
            return
        end
    end, 60)
end
local browserFrame = Meeting.GUI.CreateFrame({
    parent = Meeting.MainFrame,
    width = 782,
    height = 390,
    anchor = {
        point = "TOPLEFT",
        relative = Meeting.MainFrame,
        relativePoint = "TOPLEFT",
        x = 10,
        y = -28
    }
})
browserFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
browserFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" and not Meeting.syncTipCreated then
        Meeting.syncTipCreated = true
        CreateSyncTip()
    end
end)
Meeting.BrowserFrame = browserFrame
browserFrame:EnableMouse(true)
browserFrame:EnableMouseWheel(true)
Meeting.searchInfo.category = ""
Meeting.searchInfo.code = ""
local matchs = {}
-- 修改 SetMathcKeyWords 函数支持跨类别多选 by 武藤纯子酱 2025.9.22
function SetMathcKeyWords()
    matchs = {}
    local nomatchs = {}  -- 存储排除关键词
    
    -- 添加任务链接匹配条件
    if Meeting.searchInfo.code == "QuestLink" then
        table.insert(matchs, "|Hquest:")
        return matchs, nomatchs
    end
    
    -- 处理多选情况 - 支持跨类别选择
    if next(Meeting.searchInfo.codes) then
        -- 遍历所有选中的活动代码
        for activityKey, isSelected in pairs(Meeting.searchInfo.codes) do
            if isSelected then
                -- 在所有类别中查找匹配的活动
                for _, category in ipairs(Meeting.Categories) do
                    for _, activity in ipairs(category.children) do
                        if activity.key == activityKey then
                            -- 添加匹配关键词
                            if activity.match then
                                for _, match in ipairs(activity.match) do
                                    table.insert(matchs, match)
                                end
                            end
                            
                            -- 添加排除关键词
                            if activity.nomatch then
                                for _, nomatch in ipairs(activity.nomatch) do
                                    table.insert(nomatchs, nomatch)
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    elseif Meeting.searchInfo.code ~= "" then
        -- 单个选择的情况
        local info = Meeting.GetActivityInfo(Meeting.searchInfo.code)
        if info.match then
            for _, v in ipairs(info.match) do
                table.insert(matchs, v)
            end
        end
        if info.nomatch then
            for _, v in ipairs(info.nomatch) do
                table.insert(nomatchs, v)
            end
        end
    end
    
    return matchs, nomatchs
end
-- 修改菜单选项创建逻辑，添加全部选项 by 武藤纯子酱 2025.9.22
local options = {
    type = 'group',
    args = {
        ALL = {
            order = 1,
            type = "toggle",
            name = "All",
            desc = "All",
            get = function() 
                return Meeting.searchInfo.category == "" and Meeting.searchInfo.code == "" and not next(Meeting.searchInfo.codes)
            end,
            set = function()
                Meeting.searchInfo.category = ""
                Meeting.searchInfo.code = ""
                Meeting.searchInfo.codes = {}
                Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
                if searchInput then
                    searchInput:SetText("")  -- 清空搜索框
                end
                SetMathcKeyWords()
                Menu:Close()
                MeetingBworserSelectButton:SetText("Select Activity")
                Meeting.BrowserFrame:UpdateList(true)
            end,
        },
        -- 添加确认按钮
        CONFIRM_SELECTION = {
            order = 8,
            type = "execute",
            name = "Confirm Selection",
            desc = "Confirm selected dungeons",
            func = function()
                -- 获取选中的数量
                local count = 0
                for _ in pairs(Meeting.searchInfo.codes) do
                    count = count + 1
                end
                
                if count > 0 then
                    MeetingBworserSelectButton:SetText("Selected " .. count)
                    SetMathcKeyWords()
                    Meeting.BrowserFrame:UpdateList(true)
                    Menu:Close()
                    Meeting.dropdownState.isOpen = false
                    
                    -- 显示确认提示
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Confirmed selection of " .. count .. " dungeons")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Please select dungeons to filter")
                end
            end,
        },
        -- 添加清空按钮
        CLEAR_SELECTION = {
            order = 9,
            type = "execute",
            name = "Clear Selection",
            desc = "Clear all selected dungeons",
            func = function()
                Meeting.searchInfo.codes = {}
                Meeting.searchInfo.code = ""
                Meeting.searchInfo.category = ""
                Meeting.searchInfo.text = ""
                
                if searchInput then
                    searchInput:SetText("")  -- 清空搜索框
                end
                
                SetMathcKeyWords()
                MeetingBworserSelectButton:SetText("Select Activity")
                Meeting.BrowserFrame:UpdateList(true)
                Menu:Close()
                Meeting.dropdownState.isOpen = false
                
                -- 显示清空提示
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Cleared all dungeon selections")
            end,
        },
    },
}
-- 创建所有活动的扁平化列表，支持跨类别多选
local allActivities = {}
-- 首先收集所有活动
for i, category in ipairs(Meeting.Categories) do
    if not category.hide then
        -- 创建局部变量保存当前类别的引用，避免闭包问题
        local currentCategory = category
        
        -- 为每个类别添加"全部"选项
        options.args[category.key] = {
            order = i + 1,
            type = 'group',
            name = category.name,
            desc = category.name,
            args = {
                -- 添加类别级别的"全部"选项
                ["ALL_" .. category.key] = {
                    order = 1,
                    type = "toggle",
                    name = "All",
                    desc = "Select all activities in " .. category.name,
                    get = function()
                        -- 检查该类别下所有子选项是否都被选中
                        local allSelected = true
                        local anySelected = false
                        
                        -- 使用局部变量 currentCategory 而不是 category
                        if not currentCategory or not currentCategory.children then 
                            return false 
                        end
                        
                        for j, activity in ipairs(currentCategory.children) do
                            if Meeting.searchInfo.codes[activity.key] then
                                anySelected = true
                            else
                                allSelected = false
                            end
                        end
                        
                        -- 如果全部选中返回true，如果有选中但不是全部返回nil（显示为混合状态）
                        if allSelected and anySelected then
                            return true
                        elseif not anySelected then
                            return false
                        else
                            return nil  -- 混合状态
                        end
                    end,
					set = function(checked)
						local shouldSelect = true
						
						-- 检查当前是否已经全部选中
						local allCurrentlySelected = true
						for j, activity in ipairs(currentCategory.children) do
							if not Meeting.searchInfo.codes[activity.key] then
								allCurrentlySelected = false
								break
							end
						end
						
						-- 如果已经全部选中，则取消选中所有
						if allCurrentlySelected then
							shouldSelect = false
						end
						
						-- 设置该类别下所有活动的选中状态
						for j, activity in ipairs(currentCategory.children) do
							if shouldSelect then
								Meeting.searchInfo.codes[activity.key] = true
							else
								Meeting.searchInfo.codes[activity.key] = nil
							end
						end
						
						-- 更新多选模式状态
						if next(Meeting.searchInfo.codes) then
							Meeting.searchInfo.code = "MULTI"
							Meeting.searchInfo.category = ""
						else
							Meeting.searchInfo.code = ""
							Meeting.searchInfo.category = ""
						end
						
						Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
						if searchInput then
							searchInput:SetText("")  -- 清空搜索框
						end
						
						SetMathcKeyWords()
						Meeting.BrowserFrame:UpdateList(true)
						
						-- 更新按钮文本显示选中的数量
						local count = 0
						for _ in pairs(Meeting.searchInfo.codes) do
							count = count + 1
						end
						
						if count > 0 then
							MeetingBworserSelectButton:SetText("Selected " .. count)
						else
							MeetingBworserSelectButton:SetText("Select Activity")
						end
					end,
                    isNotRadio = true,  -- 允许混合状态显示
                }
            }
        }
        
        -- 添加类别下的具体活动
        for j, activity in ipairs(category.children) do
            local activityKey = activity.key
            local activityName = activity.name
            
            options.args[category.key].args[activityKey] = {
                order = j + 1,  -- 从2开始，1是"全部"选项
                type = "toggle",
                name = activityName,
                desc = activityName,
                get = function() 
                    return Meeting.searchInfo.codes[activityKey] or false
                end,
				set = function(checked)
					if checked then
						Meeting.searchInfo.codes[activityKey] = true
						Meeting.searchInfo.code = "MULTI"  -- 标记为多选模式
						Meeting.searchInfo.category = ""   -- 清空类别选择
					else
						Meeting.searchInfo.codes[activityKey] = nil
						-- 如果没有选中任何项目，清空多选
						if not next(Meeting.searchInfo.codes) then
							Meeting.searchInfo.code = ""
							Meeting.searchInfo.category = ""
						end
					end
					
					Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
					if searchInput then
						searchInput:SetText("")  -- 清空搜索框
					end
					
					SetMathcKeyWords()
					Meeting.BrowserFrame:UpdateList(true)
					
					-- 更新按钮文本显示选中的数量
					local count = 0
					for _ in pairs(Meeting.searchInfo.codes) do
						count = count + 1
					end
					
					if count > 0 then
						MeetingBworserSelectButton:SetText("Selected " .. count)
					else
						MeetingBworserSelectButton:SetText("Select Activity")
					end
				end,
            }
            
            -- 同时添加到扁平化列表
            allActivities[activityKey] = {
                category = category.key,
                name = activityName,
                order = i * 100 + j
            }
        end
    end
end

-- 修改 selectButton 的点击事件 by 武藤纯子酱 2025.9.22
local selectButton = Meeting.GUI.CreateButton({
    name = "MeetingBworserSelectButton",
    parent = browserFrame,
    text = "Select Activity",
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    width = 140,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = browserFrame,
        relativePoint = "TOPLEFT",
        y = -4
    },
    click = function()
        if Meeting.dropdownState.isOpen then
            Menu:Close()
            Meeting.dropdownState.isOpen = false
        else
            Menu:Open(this)
            Meeting.dropdownState.isOpen = true
        end
    end
})
-- 添加搜索框 by 武藤纯子酱 2025.9.24
local searchInput = Meeting.GUI.CreateInput({
    parent = browserFrame,
    width = 200,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = selectButton,
        relativePoint = "TOPRIGHT",
        x = 8,
        y = 0
    },
    placeholder = "Search description...",
    limit = 50,
    multiLine = false
})
Meeting.GUI.SetBackground(searchInput, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)

-- 搜索框文本变化事件 - 修复删除字符残留问题
searchInput:SetScript("OnTextChanged", function()
    local text = this:GetText()
    if text then
        text = string.lower(text)
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        
        -- 检测是否包含中文字符（判断是否在输入中文）
        local hasChinese = string.find(text, "[^\1-\127]")
        
        -- 取消之前的延迟搜索计时器
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        if hasChinese then
            -- 如果有中文，可能是拼音输入法正在输入，延迟搜索
            Meeting.searchInfo.isComposing = true
            Meeting.searchInfo.lastSearchText = text
            
            -- 延迟5秒执行搜索，避免拼音干扰
            Meeting.searchInfo.timer = C_Timer.NewTimer(5, function()
                if Meeting.searchInfo.lastSearchText == text then
                    Meeting.searchInfo.text = text
                    Meeting.searchInfo.isComposing = false
                    Meeting.BrowserFrame:UpdateList(true)
                end
            end)
        else
            -- 纯英文、数字、符号，实时搜索
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    else
        -- 文本为空时立即搜索
        Meeting.searchInfo.text = ""
        Meeting.searchInfo.isComposing = false
        
        -- 取消之前的计时器
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        Meeting.BrowserFrame:UpdateList(true)
    end
end)
-- 修改输入法开始合成事件
searchInput:SetScript("OnChar", function(char)
    -- 检测到中文字符输入开始
    if char and string.byte(char) > 127 then
        Meeting.searchInfo.isComposing = true
    else
        -- 英文字符，立即处理
        Meeting.searchInfo.isComposing = false
        
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
    end
end)
-- 修改输入法结束合成事件
searchInput:SetScript("OnEditFocusLost", function()
    -- 取消之前的延迟搜索
    if Meeting.searchInfo.timer then
        Meeting.searchInfo.timer:Cancel()
        Meeting.searchInfo.timer = nil
    end
    
    -- 输入框失去焦点时，强制完成搜索
    if Meeting.searchInfo.isComposing then
        local text = this:GetText()
        if text then
            text = string.lower(text)
            text = string.gsub(text, "^%s*(.-)%s*$", "%1")
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    end
end)
-- 修改回车键确认搜索
searchInput:SetScript("OnEnterPressed", function()
    -- 取消之前的延迟搜索
    if Meeting.searchInfo.timer then
        Meeting.searchInfo.timer:Cancel()
        Meeting.searchInfo.timer = nil
    end
    
    local text = this:GetText()
    if text then
        text = string.lower(text)
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        Meeting.searchInfo.text = text
        Meeting.searchInfo.isComposing = false
        Meeting.BrowserFrame:UpdateList(true)
    end
    this:ClearFocus()
end)
-- 修改搜索按钮点击事件
local searchButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Search",
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = searchInput,
        relativePoint = "TOPRIGHT",
        x = 3,
        y = 0
    },
    click = function()
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        local text = searchInput:GetText()
        if text then
            text = string.lower(text)
            text = string.gsub(text, "^%s*(.-)%s*$", "%1")
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    end
})
-- 修改清空搜索按钮
local clearSearchButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Clear",
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = searchButton,
        relativePoint = "TOPRIGHT",
        x = 3,
        y = 0
    },
    click = function()
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        Meeting.searchInfo.text = ""
        Meeting.searchInfo.isComposing = false
        searchInput:SetText("")
        Meeting.BrowserFrame:UpdateList(true)
    end
})

-- 添加屏蔽关键词按钮 by 武藤纯子酱 2025.12.30
local blockButton = Meeting.GUI.CreateButton({
    name = "MeetingBlockButton",
    parent = browserFrame,
    text = "Block Words",
    type = Meeting.GUI.BUTTON_TYPE.DANGER,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = clearSearchButton,
        relativePoint = "TOPRIGHT",
        x = 8,
        y = 0
    },
    click = function()
        if Meeting.blockDropdownState.isOpen then
            Menu:Close()
            Meeting.blockDropdownState.isOpen = false
        else
            -- 创建屏蔽词菜单
            local blockOptions = {
                type = 'group',
                args = {
                    TITLE = {
                        order = 1,
                        type = "header",
                        name = "Block Words Management",
                    },
                    ADD_BLOCK = {
                        order = 5,
                        type = "execute",  -- 改为execute，然后弹出输入框
                        name = "Add Block Word",
                        desc = "Enter keyword to block",
                        func = function()
                            -- 创建添加屏蔽词的输入对话框
                            local dialog = Meeting.GUI.CreateDialog({
                                parent = Meeting.BrowserFrame,
                                anchor = {
                                    point = "CENTER",
                                    relative = Meeting.BrowserFrame,
                                    relativePoint = "CENTER",
                                    x = 0,
                                    y = 0
                                },
                                title = "Add Block Word",
                                width = 300,
                                height = 100,
                                onCustomFrame = function(parent, anchor)
                                    local frame = Meeting.GUI.CreateFrame({
                                        parent = parent,
                                        width = 280,
                                        height = 40,
                                        anchor = {
                                            point = "TOPLEFT",
                                            relative = anchor,
                                            relativePoint = "BOTTOMLEFT",
                                            x = 0,
                                            y = -10
                                        }
                                    })
                                    
                                    local input = Meeting.GUI.CreateInput({
                                        parent = frame,
                                        width = 280,
                                        height = 20,
                                        anchor = {
                                            point = "TOPLEFT",
                                            relative = frame,
                                            relativePoint = "TOPLEFT",
                                            x = 0,
                                            y = 0
                                        },
                                        limit = 50,
                                        multiLine = false
                                    })
                                    Meeting.GUI.SetBackground(input, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)
                                    input:SetFocus()
                                    
                                    return frame
                                end,
                                _confirm = function()
                                    local input = this:GetParent():GetChildren()
                                    while input and not input.GetText do
                                        input = input:GetChildren()
                                    end
                                    if input and input.GetText then
                                        local value = input:GetText()
                                        if value and value ~= "" then
                                            value = string.trim(value)
                                            local exists = false
                                            for _, word in ipairs(Meeting.blockWords) do
                                                if word == value then
                                                    exists = true
                                                    break
                                                end
                                            end
                                            
                                            if not exists then
                                                table.insert(Meeting.blockWords, value)
                                                MEETING_DB.blockWords = Meeting.blockWords
                                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Added block word: " .. value)
                                                
                                                -- 重新过滤活动列表
                                                Meeting:ReFilterActivities()
                                            else
                                                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Block word already exists: " .. value)
                                            end
                                        end
                                    end
									Menu:Close()
                                end
                            })
                            dialog:SetPoint("CENTER", Meeting.BrowserFrame, "CENTER", 0, 0)
                        end
                    },
                    CLEAR_ALL = {
                        order = 10,
                        type = "execute",
                        name = "Clear All Block Words",
                        desc = "Clear all set block words",
                        func = function()
                            Meeting.blockWords = {}
                            MEETING_DB.blockWords = Meeting.blockWords
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Cleared all block words")
                            Meeting:ReFilterActivities()
							Menu:Close()
                        end,
                    },
                    RESET = {
                        order = 15,
                        type = "execute",
                        name = "Reset Block Words",
                        desc = "Reset block words to default",
                        func = function()
							MEETING_DB.blockWords = { -- 新增重置默认屏蔽词 by 武藤纯子酱 2025.12.30
								'加速器',
								'淘宝',
								'代充',
								'代练'
							}
							Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Reset block words")
                            Meeting:ReFilterActivities()
							Menu:Close()
                        end,
                    },
                    SEPARATOR1 = {
                        order = 20,
                        type = "header",
                        name = " ",
                    },
                    LIST_TITLE = {
                        order = 25,
                        type = "header",
                        name = "Current Block Words (" .. table.getn(Meeting.blockWords) .. ")",
                    },
                }
            }
            
            -- 动态添加当前屏蔽词列表
            local order = 50
            for i, word in ipairs(Meeting.blockWords) do
				local blockword = word
                blockOptions.args["BLOCK_" .. i] = {
                    order = order,
                    type = "execute",
                    name = word,
                    desc = "Click to delete",
                    func = function()
						for i, word in ipairs(Meeting.blockWords) do
							if word == blockword then
								table.remove(Meeting.blockWords, i)
								found = true
								break
							end
						end
                        MEETING_DB.blockWords = Meeting.blockWords
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Deleted block word: " .. blockword)
                        Meeting:ReFilterActivities()
                    end,
                }
                order = order + 1
            end
            
            -- 如果没有屏蔽词，显示提示
            if table.getn(Meeting.blockWords) == 0 then
                blockOptions.args.NO_BLOCKS = {
                    order = 55,
                    type = "header",
                    name = "|cffccccccNo block words|r",
                }
            end
            
            -- 注册并打开菜单
            Menu:Register(this,
                'children', function()
                    Menu:FeedAceOptionsTable(blockOptions)
                end,
                'cursorX', true,
                'cursorY', true,
                'dontHook', true,
                'onClose', function()
                    Meeting.blockDropdownState.isOpen = false
                end
            )
            
            Menu:Open(this)
            Meeting.blockDropdownState.isOpen = true
        end
    end
})

-- 修改菜单注册，添加关闭时的回调 by 武藤纯子酱 2025.9.22
Menu:Register(selectButton,
    'children', function()
        Menu:FeedAceOptionsTable(options)
    end,
    'cursorX', true,
    'cursorY', true,
    'dontHook', true,
    'onClose', function()
        Meeting.dropdownState.isOpen = false
    end
)

local refreshButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Refresh",
    type = Meeting.GUI.BUTTON_TYPE.SUCCESS,
    width = 80,
    height = 24,
    anchor = {
        point = "TOPRIGHT",
        relative = browserFrame,
        relativePoint = "TOPRIGHT",
        x = 0,
        y = -4
    },
    click = function()
        Meeting.BrowserFrame:UpdateList(true)
    end
})

local activityListHeaderFrame = Meeting.GUI.CreateFrame({
    parent = browserFrame,
    width = 746,
    height = 22,
    anchor = {
        point = "TOPLEFT",
        relative = browserFrame,
        relativePoint = "TOPLEFT",
        x = 8,
        y = -32
    }
})

local activityTypeText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Activity",
    fontSize = 14,
    width = 135,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = activityListHeaderFrame,
        relativePoint = "TOPLEFT",
    }
})

local modeText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Mode",
    fontSize = 14,
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = activityTypeText,
        relativePoint = "TOPRIGHT",
    }
})

local membersText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Members",
    fontSize = 14,
    width = 80,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = modeText,
        relativePoint = "TOPRIGHT",

    }
})

local leaderText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Leader",
    fontSize = 14,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = membersText,
        relativePoint = "TOPRIGHT",
    }
})

local commentText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Note",
    fontSize = 14,
    width = 300,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = leaderText,
        relativePoint = "TOPRIGHT",
    }
})

local actionText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Action",
    fontSize = 14,
    width = 70,
    height = 24,
    anchor = {
        point = "TOPRIGHT",
        relative = activityListHeaderFrame,
        relativePoint = "TOPRIGHT",
        x = -4,
        y = 0
    }
})
actionText:SetJustifyH("RIGHT")

local hoverBackgrop = {
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeSize = 24,
    insets = { left = -1, right = -1, top = -1, bottom = -1 },
}

local function CreateRequestPrompt(config)
    config.width = config.width or 300
    config.height = 185

    if not MEETING_DB.role or MEETING_DB.role == 0 then
        MEETING_DB.role = Meeting.GetClassRole(Meeting.playerClass)
    end

    config.onCustomFrame = function(parent, anchor)
        local frame = Meeting.GUI.CreateFrame({
            parent = parent,
            width = config.width - 20,
            height = 100,
            anchor = {
                point = "TOPLEFT",
                relative = anchor,
                relativePoint = "BOTTOMLEFT",
                x = 0,
                y = -10
            }
        })

        local roleEnable = Meeting.GetClassRole(Meeting.playerClass)

        local function createRole(role, anchor)
            local enable = bit.band(roleEnable, role) == role
            local ckecked = bit.band(MEETING_DB.role, role) == role

            local roleFrame = Meeting.GUI.CreateButton({
                parent = frame,
                width = 40,
                height = 40,
                blizzard = false,
                anchor = anchor,
                disabled = not enable,
                click = function()
                    local ckeck = this.checkButton:GetChecked()
                    if bit.band(MEETING_DB.role, role) == role then
                        MEETING_DB.role = bit.bxor(MEETING_DB.role, role)
                    else
                        MEETING_DB.role = bit.bor(MEETING_DB.role, role)
                    end
                    this.checkButton:SetChecked(not ckeck)
                end
            })

            local tankTexture = roleFrame:CreateTexture()
            local textureName = "damage"
            if role == Meeting.Role.Tank then
                textureName = "tank"
            elseif role == Meeting.Role.Healer then
                textureName = "healer"
            end
            tankTexture:SetTexture("Interface\\AddOns\\Meeting\\assets\\" .. textureName .. ".blp")
            tankTexture:SetWidth(40)
            tankTexture:SetHeight(40)
            tankTexture:SetPoint("TOPLEFT", roleFrame, "TOPLEFT", 0, 0)
            if not enable then
                tankTexture:SetVertexColor(0.2, 0.2, 0.2, 1)
            else
                roleFrame.checkButton = Meeting.GUI.CreateCheck({
                    parent = roleFrame,
                    width = 20,
                    height = 20,
                    anchor = {
                        point = "BOTTOMRIGHT",
                        relative = roleFrame,
                        relativePoint = "BOTTOMRIGHT",
                        x = 0,
                        y = 0
                    },
                    checked = enable and ckecked,
                    click = function(checked)
                        if bit.band(MEETING_DB.role, role) == role then
                            MEETING_DB.role = bit.bxor(MEETING_DB.role, role)
                        else
                            MEETING_DB.role = bit.bor(MEETING_DB.role, role)
                        end
                    end
                })
            end
            return roleFrame
        end

        local tank = createRole(Meeting.Role.Tank, {
            point = "TOPLEFT",
            relative = frame,
            relativePoint = "TOPLEFT",
            x = 70,
            y = 0
        })

        local healer = createRole(Meeting.Role.Healer, {
            point = "TOPLEFT",
            relative = tank,
            relativePoint = "TOPRIGHT",
            x = 10,
            y = 0

        })

        local damage = createRole(Meeting.Role.Damage, {
            point = "TOPLEFT",
            relative = healer,
            relativePoint = "TOPRIGHT",
            x = 10,
            y = 0
        })

        local commentFrame = Meeting.GUI.CreateText({
            parent = frame,
            anchor = {
                point = "TOPLEFT",
                relative = tank,
                relativePoint = "BOTTOMLEFT",
                x = -70,
                y = -5
            },
            text = "Note",
        })

        local input = Meeting.GUI.CreateInput({
            parent = frame,
            width = config.width - 20,
            height = 20,
            anchor = {
                point = "TOPLEFT",
                relative = commentFrame,
                relativePoint = "BOTTOMLEFT",
                x = 0,
                y = -10
            },
            limit = 128,
            multiLine = false
        })
        Meeting.GUI.SetBackground(input, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)

        config._confirm = function()
            local text = input:GetText()
            text = string.gsub(text, ":", "：")
            config.confirm(text, MEETING_DB.role)
        end

        return frame
    end

    return Meeting.GUI.CreateDialog(config)
end

local activityListFrame = Meeting.GUI.CreateListFrame({
    name = "MeetingActivityListFrame",
    parent = browserFrame,
    width = 746,
    height = 240,
    maxDisplay = 20,
    anchor = {
        point = "TOPLEFT",
        relative = activityListHeaderFrame,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = 0
    },
    step = 22,
    display = 10,
    cell = function(f)
        f.OnHover = function(this, isHover)
            if isHover then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT", 40)
                GameTooltip:SetText(this.name, 1, 1, 1, 1)
                local classColor = this.activity.classColor
                GameTooltip:AddLine(this.leader, classColor.r, classColor.g, classColor.b, 1)

                if this.level ~= nil and this.level > 0 then
                    local color = GetDifficultyColor(this.level)
                    GameTooltip:AddLine(
                        format('%s |cff%02x%02x%02x%s|r', LEVEL, color.r * 255, color.g * 255, color.b * 255,
                            this.level), 1, 1, 1)
                end

                if this.comment ~= "_" then
                    if Meeting.WT and Meeting.WT.AddTooltipLine then
                        Meeting.WT.AddTooltipLine(this.comment, 0.75, 0.75, 0.75, 1)
                    else
                        GameTooltip:AddLine(this.comment, 0.75, 0.75, 0.75, 1)
                    end
                end

                local classMap = this.activity:GetClassMap()
                if classMap then
                    GameTooltip:AddLine(" ")
                    if Meeting.WT and Meeting.WT.L then
                        GameTooltip:AddLine(Meeting.WT.L("-- 成员 --"), 0.75, 0.75, 0.75, 1)
                    else
                        GameTooltip:AddLine("-- 成员 --", 0.75, 0.75, 0.75, 1)
                    end
                    for k, v in pairs(classMap) do
                        local clsname = Meeting.GetClassLocaleName(k)
                        if Meeting.WT and Meeting.WT.FormatClassCount then
                            GameTooltip:AddLine(Meeting.WT.FormatClassCount(clsname, v), 1, 1, 1, 1)
                        else
                            GameTooltip:AddLine(clsname .. " " .. v .. "个", 1, 1, 1, 1)
                        end
                    end
                end
                GameTooltip:AddLine(" ")
                if Meeting.WT and Meeting.WT.L then
                    GameTooltip:AddLine(Meeting.WT.L("<双击>悄悄话"), 1, 1, 1, 1)
                else
                    GameTooltip:AddLine("<Double Click> Whisper", 1, 1, 1, 1)
                end
                GameTooltip:SetWidth(220)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
        f:SetScript("OnDoubleClick", function()
            if this.leader == Meeting.player then
                return
            end
            ChatFrame_OpenChat("/w " .. this.leader, SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME)
        end)

        f.nameFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 135,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f,
                relativePoint = "TOPLEFT",
                x = 0,
                y = -6
            }
        })

        f.hcFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 60,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.nameFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.membersFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            width = 80,
            height = 24,
            fontSize = 14,
            anchor = {
                point = "TOPLEFT",
                relative = f.hcFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.leaderFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 100,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.membersFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.commentFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 300,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.leaderFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.requestButton = Meeting.GUI.CreateButton({
            parent = f,
            text = "Apply",
            width = 60,
            height = 18,
            type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
            anchor = {
                point = "TOPRIGHT",
                relative = f,
                relativePoint = "TOPRIGHT",
                x = -4,
                y = -3
            },
            click = function()
                if f.isChat then
                    ChatFrame_OpenChat("/w " .. f.leader, SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME)
                else
                    local frame = CreateRequestPrompt({
                        parent = Meeting.BrowserFrame,
                        anchor = {
                            point = "CENTER",
                            relative = Meeting.BrowserFrame,
                            relativePoint = "CENTER",
                            x = 0,
                            y = 0
                        },
                        title = (Meeting.WT and Meeting.WT.L and Meeting.WT.L("申请加入") or "Apply to join ") .. f.name,
                        confirm = function(text, role)
                            Meeting.Message.Request(f.id, text, role)
                            local activity = Meeting:FindActivity(f.id)
                            activity.applicantStatus = Meeting.APPLICANT_STATUS.Invited
                            Meeting.BrowserFrame:UpdateActivity(activity)
                            f.requestButton:Disable()
                        end
                    })
                    frame:SetPoint("TOP", Meeting.BrowserFrame, "TOP", 0, -50)
                end
            end
        })

        f.statusFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 70,
            color = { r = 0, g = 1, b = 0 },
            anchor = {
                point = "TOPRIGHT",
                relative = f.requestButton,
                relativePoint = "TOPLEFT",
                x = -6,
                y = -2
            }
        })
        f.statusFrame:SetJustifyH("RIGHT")
    end
})

local BROWSER_LEFT_WIDTH = 135 + 60 + 80 + 100
local BROWSER_ACTION_WIDTH = 136

activityListFrame.onLayout = function(listW)
    local commentW = listW - BROWSER_LEFT_WIDTH - BROWSER_ACTION_WIDTH
    if commentW < 80 then
        commentW = 80
    end
    for _, cell in ipairs(activityListFrame.pool) do
        if cell.commentFrame then
            cell.commentFrame:SetWidth(commentW)
        end
        if cell.requestButton then
            cell.requestButton:ClearAllPoints()
            cell.requestButton:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -4, -3)
        end
        if cell.statusFrame and cell.requestButton then
            cell.statusFrame:ClearAllPoints()
            cell.statusFrame:SetPoint("TOPRIGHT", cell.requestButton, "TOPLEFT", -6, -2)
        end
    end
end

Meeting.Layout = Meeting.Layout or {}
Meeting.Layout.activityListHeader = activityListHeaderFrame
Meeting.Layout.activityListFrame = activityListFrame
Meeting.Layout.browserToolbar = {
    frame = browserFrame,
    selectButton = selectButton,
    searchInput = searchInput,
    searchButton = searchButton,
    clearSearchButton = clearSearchButton,
    blockButton = blockButton,
    refreshButton = refreshButton,
    listHeader = activityListHeaderFrame,
}

local function ReloadCell(frame, activity)
	if not frame then return end
    local info = Meeting.GetActivityInfo(activity.code)
    local activityName = info.name
    if Meeting.WT and Meeting.WT.DisplayText then
        frame.nameFrame:SetText(Meeting.WT.DisplayText(activityName))
        frame.leaderFrame:SetText(Meeting.WT.DisplayText(activity.unitname))
    else
        frame.nameFrame:SetText(activityName)
        frame.leaderFrame:SetText(activity.unitname)
    end
    local classColor = activity.classColor
    frame.leaderFrame:SetTextColor(classColor.r, classColor.g, classColor.b)
    frame.hcFrame:SetText(activity.isHC and "HC" or "")
    local maxMambers = Meeting.GetActivityMaxMembers(activity.code)
    local isChat = activity:IsChat()
    if isChat then
        frame.membersFrame:SetText("-")
    else
        frame.membersFrame:SetText(activity.members .. "/" .. maxMambers)
    end

    local comment = activity.comment ~= "_" and activity.comment or ""
    if Meeting.WT and Meeting.WT.DisplayText then
        frame.commentFrame:SetText(Meeting.WT.DisplayText(comment))
    else
        frame.commentFrame:SetText(comment)
    end

    if activity.unitname == Meeting.player or (Meeting.joinedActivity and Meeting.joinedActivity.unitname == activity.unitname) then
        frame.statusFrame:SetText("Joined")
        frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
            Meeting.GUI.Theme.Green.b)
        frame.statusFrame:Show()
        frame.requestButton:Hide()
    else
        if activity.applicantStatus == Meeting.APPLICANT_STATUS.Invited then
            frame.statusFrame:SetText("Applied")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
                Meeting.GUI.Theme.Green.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        elseif activity.applicantStatus == Meeting.APPLICANT_STATUS.Declined then
            frame.statusFrame:SetText("Declined")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Red.r, Meeting.GUI.Theme.Red.g, Meeting.GUI.Theme.Red.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        elseif activity.applicantStatus == Meeting.APPLICANT_STATUS.Joined then
            frame.statusFrame:SetText("Joined")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
                Meeting.GUI.Theme.Green.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        else
            frame.statusFrame:Hide()
            frame.requestButton:Show()
            if isChat then
                frame.requestButton:Enable()
                frame.requestButton:SetText("Whisper")
            elseif activity.members >= maxMambers then
                frame.requestButton:Disable()
                frame.requestButton:SetText("Full")
            else
                frame.requestButton:Enable()
                frame.requestButton:SetText("Apply")
            end
        end
    end

    frame.activity = activity
    frame.id = activity.unitname
    frame.name = info.name
    frame.isChat = isChat
    frame.leader = activity.unitname
    frame.level = activity.level
    frame.comment = activity.comment
end

local activities = {}

function Meeting.BrowserFrame:UpdateList(force, scroll)
    if not Meeting.MainFrame:IsShown() or not Meeting.BrowserFrame:IsShown() then
        return
    end
    if not scroll then
        if not force then
            if Meeting.isHover then
                Meeting.GUI.ApplyButtonType(refreshButton, Meeting.GUI.BUTTON_TYPE.DANGER)
                return
            end
        end
        Meeting.GUI.ApplyButtonType(refreshButton, Meeting.GUI.BUTTON_TYPE.SUCCESS)
        activities = {}
        
        -- 修改搜索逻辑，移除类别限制
        local function search(activity)
            -- 如果有多选，使用多选逻辑
            if next(Meeting.searchInfo.codes) then
                return Meeting.searchInfo.codes[activity.code] or false
            -- 如果有单个选择
            elseif Meeting.searchInfo.code ~= "" then
                return Meeting.searchInfo.code == activity.code
            -- 如果选择了类别但没有选择具体活动
            elseif Meeting.searchInfo.category ~= "" then
                return Meeting.searchInfo.category == activity.category
            -- 全部显示
            else
                return true
            end
        end
        
        -- 修改匹配逻辑，添加排除检查
        local function match(activity, matchs, nomatchs)
			if not activity or not activity.comment then return false end
		
            local lower = string.lower(activity.comment)
            
			if not lower then return false end
			
            -- 先检查排除关键词
            for _, nomatch in ipairs(nomatchs) do
                if string.find(lower, nomatch) then
                    return false  -- 如果包含排除关键词，不匹配
                end
            end
            
            -- 再检查匹配关键词
            for _, match in ipairs(matchs) do
                if string.find(lower, match) then
                    return true
                end
            end
            
            return false
        end
        
        -- 添加搜索文本过滤函数 by 武藤纯子酱 2025.9.24
        local function textSearch(activity)
            if Meeting.searchInfo.text == "" then
                return true  -- 没有搜索文本，显示所有
            end
            
            -- 在活动说明中搜索
            local commentMatch = activity.comment and 
                                string.find(string.lower(activity.comment), Meeting.searchInfo.text, 1, true)
            
            -- 在队长名字中搜索
            local leaderMatch = activity.unitname and 
                               string.find(string.lower(activity.unitname), Meeting.searchInfo.text, 1, true)
            
            -- 在活动名称中搜索
            local activityInfo = Meeting.GetActivityInfo(activity.code)
            local activityNameMatch = activityInfo and activityInfo.name and
                                     string.find(string.lower(activityInfo.name), Meeting.searchInfo.text, 1, true)
            
            return commentMatch or leaderMatch or activityNameMatch
        end
        
        -- 获取匹配和排除关键词
        local matchs, nomatchs = SetMathcKeyWords()
        
        local function matchActivity(activity)
            return match(activity, matchs, nomatchs)
        end
        
        for _, activity in ipairs(Meeting.activities) do
			-- 添加屏蔽词检查
			local shouldShow = true
			
			-- 检查队长名字中的屏蔽词
			if Meeting.CheckBlockWords(activity.unitname, activity.unitname) then
				shouldShow = false
			end
			
			-- 检查活动说明中的屏蔽词
			if shouldShow and Meeting.CheckBlockWords(activity.unitname, activity.comment) then
				shouldShow = false
			end

			if shouldShow then
				if activity:IsChat() then
					-- 聊天活动的特殊处理
					if next(Meeting.searchInfo.codes) or Meeting.searchInfo.code ~= "" then
						if matchActivity(activity) and textSearch(activity) then  -- 添加搜索过滤
							table.insert(activities, activity)
						end
					else
						if search(activity) and textSearch(activity) then  -- 添加搜索过滤
							table.insert(activities, activity)
						end
					end
				else
					-- 普通活动的处理
					if search(activity) and textSearch(activity) then  -- 添加搜索过滤
						table.insert(activities, activity)
					end
				end
			end
        end
    end
    activityListFrame:Reload(table.getn(activities), function(frame, index)
        ReloadCell(frame, activities[index])
    end)
    
    -- 更新搜索结果显示 by 武藤纯子酱 2025.9.24
    if Meeting.searchInfo.text ~= "" then
        searchInput:SetText(Meeting.searchInfo.text)
    end
end

activityListFrame.OnScroll = Meeting.BrowserFrame.UpdateList

function Meeting.BrowserFrame:UpdateActivity(activity)
    local index = -1
    for i, value in ipairs(activities) do
        if value.unitname == activity.unitname then
            index = i
            break
        end
    end
    if index == -1 then
        return
    end

    local offset = FauxScrollFrame_GetOffset(activityListFrame) + 1
    if index < offset or index > offset + table.getn(activityListFrame.pool) then
        return
    end

    local frame = activityListFrame.pool[index - offset + 1]
    ReloadCell(frame, activity)
end

C_Timer.After(0, function()
    if Meeting.Settings and Meeting.Settings.Apply then
        Meeting.Settings.Apply()
    end
end)
```

## Compat.lua
```lua
--[[
    API: C_Timer
]]
local function GenerateTimer()
    local Timer       = CreateFrame("Frame")
    local TimerObject = {}

    Timer.Infinite    = 0  -- -1 infinite，0 stop，1..n loop n times
    Timer.ElapsedTime = 0
    
    function Timer:Start(duration, callback)
        if type(duration) ~= "number" then
            duration = 0
        end
        
        self:SetScript("OnUpdate", function()
            self.ElapsedTime = self.ElapsedTime + arg1
 
            if self.ElapsedTime >= duration and type(callback) == "function" then
                callback()

                self.ElapsedTime = 0
    
                if self.Infinite == 0 then
                    self:SetScript("OnUpdate", nil) 
                elseif self.Infinite > 0 then
                    self.Infinite = self.Infinite - 1
                end
            end
        end)
    end
    
    function TimerObject:IsCancelled()
        return not Timer:GetScript("OnUpdate")
    end
    
    function TimerObject:Cancel()
        if Timer:GetScript("OnUpdate") then
            Timer:SetScript("OnUpdate", nil) 
            Timer.Infinite    = 0
            Timer.ElapsedTime = 0
        end
    end

    return Timer, TimerObject
end

C_Timer = C_Timer or {
    After = function (duration, callback)
        GenerateTimer():Start(duration, callback)
    end,
    NewTimer = function (duration, callback)
        local timer, timerObj = GenerateTimer()
        
        timer:Start(duration, callback)

        return timerObj
    end,
    NewTicker = function (duration, callback, ...)
        local timer, timerObj = GenerateTimer()
        local iterations = unpack(arg)

        if type(iterations) ~= "number" or iterations < 0 then
            iterations = 0  -- will be infinite
        end

        timer.Infinite = iterations - 1
        timer:Start(duration, callback)

        return timerObj
    end
}
```

## Creator.lua
```lua
local Menu = AceLibrary("Dewdrop-2.0")

local creatorFrame = Meeting.GUI.CreateFrame({
    parent = Meeting.MainFrame,
    width = 782,
    height = 390,
    anchor = {
        point = "TOPLEFT",
        relative = Meeting.MainFrame,
        relativePoint = "TOPLEFT",
        x = 10,
        y = -28
    },
    hide = true
})
Meeting.CreatorFrame = creatorFrame

local creatorInfoFrame = Meeting.GUI.CreateFrame({
    parent = creatorFrame,
    width = 250,
    height = 372,
    anchor = {
        point = "TOPLEFT",
        relative = creatorFrame,
        relativePoint = "TOPLEFT",
    }
})

local line = creatorFrame:CreateTexture()
line:SetWidth(0.5)
line:SetHeight(390)
line:SetTexture(1, 1, 1, 0.5)
line:SetPoint("TOPLEFT", creatorInfoFrame, "TOPRIGHT", -10, 0)

local activityTypeTextFrame = Meeting.GUI.CreateText({
    parent = creatorInfoFrame,
    text = "Activity:",
    fontSize = 16,
    anchor = {
        point = "TOPLEFT",
        relative = creatorInfoFrame,
        relativePoint = "TOPLEFT",
        x = 0,
        y = -8
    }
})

local options = {
    type = 'group',
    args = {},
}

for i, value in ipairs(Meeting.Categories) do
    if not value.hide then
        local children = {}

        for j, child in ipairs(value.children) do
            local k = child.key
            local name = child.name
            children[k] = {
                order = j,
                type = "toggle",
                name = name,
                desc = name,
                get = function() return Meeting.createInfo.code == k end,
                set = function()
                    Meeting.createInfo.code = k
                    MeetingCreatorSelectButton:SetText(name)
                    Menu:Close()
                    Meeting.CreatorFrame.UpdateActivity()
                end,
            }
        end

        options.args[value.key] = {
            order = i,
            type = 'group',
            name = value.name,
            desc = value.name,
            args = children,
        }
    end
end

local selectButton = Meeting.GUI.CreateButton({
    parent = creatorInfoFrame,
    name = "MeetingCreatorSelectButton",
    text = "Select Activity",
    width = 140,
    height = 24,
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    anchor = {
        point = "TOPLEFT",
        relative = activityTypeTextFrame,
        relativePoint = "TOPRIGHT",
        x = 6,
        y = 2
    },
    click = function()
        Menu:Open(this)
    end
})

Menu:Register(selectButton,
    'children', function()
        Menu:FeedAceOptionsTable(options)
    end,
    'cursorX', true,
    'cursorY', true,
    'dontHook', true
)

local commentTextFrame = Meeting.GUI.CreateText({
    parent = creatorInfoFrame,
    text = "Description:",
    fontSize = 16,
    anchor = {
        point = "TOPLEFT",
        relative = activityTypeTextFrame,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = -12
    }
})

local commentButton = CreateFrame("Button", nil, creatorInfoFrame)
commentButton:SetWidth(220)
commentButton:SetHeight(140)
commentButton:SetPoint("TOPLEFT", commentTextFrame, "BOTTOMLEFT", 0, -8)
commentButton:SetScript("OnClick", function()
    MeetingCreateEditBox:SetFocus()
end)
Meeting.GUI.SetBackground(commentButton, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)

local commentFrame = CreateFrame("EditBox", "MeetingCreateEditBox", commentButton)
commentFrame:SetWidth(220)
commentFrame:SetHeight(140)
commentFrame:SetPoint("TOPLEFT", commentButton, "TOPLEFT", 0, 0)
commentFrame:SetMultiLine(true)
commentFrame:SetJustifyV("TOP")
commentFrame:SetJustifyH("LEFT")
commentFrame:SetMaxBytes(200)
commentFrame:SetAutoFocus(false)
commentFrame:SetFontObject("ChatFontNormal")
commentFrame._focus = false
commentFrame.HasFocus = function(self)
    return self._focus == true
end
commentFrame:SetScript("OnEditFocusGained", function()
    this._focus = true
end)
commentFrame:SetScript("OnEditFocusLost", function()
    this._focus = false
    local text = commentFrame:GetText()
    text = string.gsub(text, "\n", "")
    text = string.gsub(text, ":", "：")
    commentFrame:SetText(text)
    if not Meeting.joinedActivity then
        Meeting.createInfo.comment = text
    end
end)
commentFrame:SetScript("OnEscapePressed", function()
    commentFrame:ClearFocus()
end)

local translateButton
translateButton = Meeting.GUI.CreateButton({
    parent = creatorInfoFrame,
    width = 80,
    height = 22,
    text = "Translate",
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    click = function()
        local text = string.trim(commentFrame:GetText() or "")
        if text == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Enter a description to translate.")
            return
        end
        if not Meeting.WT or not Meeting.WT.CanTranslateOutgoing() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: WoWTranslate is not available.")
            return
        end

        this:Disable()
        this:SetText("Translating...")
        Meeting.WT.TranslateOutgoing(text, function(result, err)
            if translateButton then
                translateButton:Enable()
                Meeting.CreatorFrame.UpdateTranslateButton()
            end
            if result then
                commentFrame:SetText(result)
                if not Meeting.joinedActivity then
                    Meeting.createInfo.comment = result
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Description translated to "
                    .. Meeting.WT.GetOutgoingTargetLangName() .. ".")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: "
                    .. (err or "Translation failed") .. ".")
            end
        end)
    end
})
translateButton:ClearAllPoints()
translateButton:SetPoint("LEFT", commentTextFrame, "RIGHT", 8, 0)
Meeting.CreatorFrame.translateButton = translateButton
translateButton:Hide()
translateButton:SetScript("OnEnter", function()
    if not Meeting.WT or not Meeting.WT.CanTranslateOutgoing() then
        return
    end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Translate description", 1, 1, 1)
    GameTooltip:AddLine("Target language (WoWTranslate outgoing):", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(Meeting.WT.GetOutgoingTargetLangName(), 1, 0.82, 0)
    GameTooltip:Show()
end)
translateButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function Meeting.CreatorFrame.UpdateTranslateButton()
    local btn = translateButton or Meeting.CreatorFrame.translateButton
    if not btn then
        return
    end
    if not Meeting.WT or not Meeting.WT.IsInstalled() then
        btn:Hide()
        return
    end
    btn:Show()
    if btn:IsEnabled() then
        btn:SetText("Translate")
    end
end

local createButton = Meeting.GUI.CreateButton({
    parent = creatorInfoFrame,
    width = 220,
    height = 24,
    text = "Create Activity",
    type = Meeting.GUI.BUTTON_TYPE.SUCCESS,
    anchor = {
        point = "TOPLEFT",
        relative = commentButton,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = -10
    },
    click = function()
        commentFrame:ClearFocus()
        Meeting.Message.CreateActivity(Meeting.createInfo.code, Meeting.createInfo.comment)
    end
})
createButton:Disable()

local closeButton = Meeting.GUI.CreateButton({
    parent = creatorInfoFrame,
    width = 220,
    height = 24,
    text = "Disband Activity",
    type = Meeting.GUI.BUTTON_TYPE.DANGER,
    anchor = {
        point = "TOPLEFT",
        relative = createButton,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = -10
    },
    click = function()
        Meeting.Message.CloseActivity()
    end
})
closeButton:Disable()

local applicantListHeaderFrame = Meeting.GUI.CreateFrame({
    parent = creatorFrame,
    width = 504,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = creatorInfoFrame,
        relativePoint = "TOPRIGHT",
        x = 0,
        y = 0
    }
})

local nameText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Name",
    fontSize = 14,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = applicantListHeaderFrame,
        relativePoint = "TOPLEFT",
    }
})

local levelText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Level",
    fontSize = 14,
    width = 50,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = nameText,
        relativePoint = "TOPRIGHT",
    }
})

local roleText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Role",
    fontSize = 14,
    width = 45,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = levelText,
        relativePoint = "TOPRIGHT",
    }
})

local scoreText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Item Level",
    fontSize = 14,
    width = 80,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = roleText,
        relativePoint = "TOPRIGHT",

    }
})

local commentText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Note",
    fontSize = 14,
    width = 145,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = scoreText,
        relativePoint = "TOPRIGHT",
    }
})

local actionText = Meeting.GUI.CreateText({
    parent = applicantListHeaderFrame,
    text = "Action",
    fontSize = 14,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = commentText,
        relativePoint = "TOPRIGHT",
    }
})

local applicantListFrame = Meeting.GUI.CreateListFrame({
    name = "MeetingApplicantListFrame",
    parent = creatorFrame,
    width = 504,
    height = 336,
    maxDisplay = 20,
    anchor = {
        point = "TOPLEFT",
        relative = applicantListHeaderFrame,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = 0
    },
    step = 22,
    display = 14,
    cell = function(f)
        f.OnHover = function(self, isHover)
            if isHover then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT", 40)
                GameTooltip:SetText(this.applicant.name, this.classColor.r, this.classColor.g, this.classColor.b, 1)
                if this.applicant.score > 0 then
                    GameTooltip:AddLine("Item Level: " .. this.applicant.score)
                end

                local color = GetDifficultyColor(this.applicant.level)
                GameTooltip:AddLine(
                    format('%s |cff%02x%02x%02x%s|r', LEVEL, color.r * 255, color.g * 255, color.b * 255,
                        this.applicant.level), 1, 1, 1)

                if this.applicant.comment ~= "_" then
                    if Meeting.WT and Meeting.WT.AddTooltipLine then
                        Meeting.WT.AddTooltipLine(this.applicant.comment, 0.75, 0.75, 0.75, 1)
                    else
                        GameTooltip:AddLine(this.applicant.comment, 0.75, 0.75, 0.75, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("<Double Click> Whisper", 1, 1, 1, 1)
                GameTooltip:SetWidth(220)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
        f:SetScript("OnDoubleClick", function()
            if this.applicant.name == Meeting.player then
                return
            end
            ChatFrame_OpenChat("/w " .. this.applicant.name, SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME)
        end)

        f.nameFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 100,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f,
                relativePoint = "TOPLEFT",
                x = 0,
                y = -6
            }
        })

        f.levelFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            width = 50,
            height = 24,
            fontSize = 14,
            anchor = {
                point = "TOPLEFT",
                relative = f.nameFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.roleFrame = Meeting.GUI.CreateFrame({
            parent = f,
            width = 45,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.levelFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        local tank = f:CreateTexture()
        tank:SetTexture("Interface\\AddOns\\Meeting\\assets\\tank.blp")
        tank:SetWidth(11)
        tank:SetHeight(11)
        f.roleFrame.tank = tank

        local healer = f:CreateTexture()
        healer:SetTexture("Interface\\AddOns\\Meeting\\assets\\healer.blp")
        healer:SetWidth(11)
        healer:SetHeight(11)
        f.roleFrame.healer = healer

        local damage = f:CreateTexture()
        damage:SetTexture("Interface\\AddOns\\Meeting\\assets\\damage.blp")
        damage:SetWidth(11)
        damage:SetHeight(11)
        f.roleFrame.damage = damage

        f.scoreFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 80,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.roleFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.commentFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 145,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.scoreFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.acceptButton = Meeting.GUI.CreateButton({
            parent = f,
            text = "Accept",
            type = Meeting.GUI.BUTTON_TYPE.SUCCESS,
            width = 60,
            height = 18,
            anchor = {
                point = "TOPLEFT",
                relative = f.commentFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 3
            },
            click = function()
                f.applicant.status = Meeting.APPLICANT_STATUS.Invited
                InviteByName(f.applicant.name)
                this:SetText("Accepted")
                this:Disable()
            end
        })

        f.declineButton = Meeting.GUI.CreateButton({
            parent = f,
            text = "x",
            type = Meeting.GUI.BUTTON_TYPE.DANGER,
            width = 18,
            height = 18,
            anchor = {
                point = "TOPLEFT",
                relative = f.acceptButton,
                relativePoint = "TOPRIGHT",
                x = 4,
                y = 0
            },
            click = function()
                f.applicant.status = Meeting.APPLICANT_STATUS.Declined
                Meeting.Message.Decline(f.applicant.name)
                local activity = Meeting:FindActivity(Meeting.player)
                if activity then
                    local i = -1
                    for index, value in ipairs(activity.applicantList) do
                        if value.name == f.applicant.name then
                            i = index
                            break
                        end
                    end
                    table.remove(activity.applicantList, i)
                    Meeting.CreatorFrame:UpdateList()
                end
            end
        })
    end
})

local APPLICANT_ROW_FIXED_WIDTH = 100 + 50 + 45 + 80 + 100

applicantListFrame.onLayout = function(listW)
    local commentW = listW - APPLICANT_ROW_FIXED_WIDTH
    if commentW < 80 then
        commentW = 80
    end
    for _, cell in ipairs(applicantListFrame.pool) do
        if cell.commentFrame then
            cell.commentFrame:SetWidth(commentW)
        end
    end
end

Meeting.Layout = Meeting.Layout or {}
Meeting.Layout.creatorInfoFrame = creatorInfoFrame
Meeting.Layout.creatorDividerLine = line
Meeting.Layout.applicantListHeader = applicantListHeaderFrame
Meeting.Layout.applicantListFrame = applicantListFrame

function Meeting.CreatorFrame:UpdateList()
    if not Meeting.CreatorFrame:IsShown() then
        return
    end

    local activity = Meeting.joinedActivity or Meeting:FindActivity(Meeting.player)
    local notLeader = IsRaidLeader() ~= 1
    applicantListFrame:Reload(activity and table.getn(activity.applicantList) or 0, function(frame, index)
        local applicant = activity.applicantList[index]
        local name = applicant.name

        frame.nameFrame:SetText(name)
        local rgb = Meeting.GetClassRGBColor(applicant.class, name)
        frame.nameFrame:SetTextColor(rgb.r, rgb.g, rgb.b)
        frame.levelFrame:SetText(applicant.level)
        frame.scoreFrame:SetText(applicant.score == 0 and "-" or applicant.score)
        local applicantComment = applicant.comment ~= "_" and applicant.comment or ""
        if Meeting.WT and Meeting.WT.DisplayText then
            frame.commentFrame:SetText(Meeting.WT.DisplayText(applicantComment))
        else
            frame.commentFrame:SetText(applicantComment)
        end

        frame.roleFrame.tank:Hide()
        frame.roleFrame.healer:Hide()
        frame.roleFrame.damage:Hide()

        if applicant.role ~= 0 then
            local prev = nil
            if bit.band(applicant.role, Meeting.Role.Tank) == Meeting.Role.Tank then
                prev = frame.roleFrame.tank
                frame.roleFrame.tank:SetPoint("TOPLEFT", frame.roleFrame, "TOPLEFT", 0, 0)
                frame.roleFrame.tank:Show()
            end
            if bit.band(applicant.role, Meeting.Role.Healer) == Meeting.Role.Healer then
                if prev then
                    frame.roleFrame.healer:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
                else
                    frame.roleFrame.healer:SetPoint("TOPLEFT", frame.roleFrame, "TOPLEFT", 0, 0)
                end
                prev = frame.roleFrame.healer
                frame.roleFrame.healer:Show()
            end
            if bit.band(applicant.role, Meeting.Role.Damage) == Meeting.Role.Damage then
                if prev then
                    frame.roleFrame.damage:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
                else
                    frame.roleFrame.damage:SetPoint("TOPLEFT", frame.roleFrame, "TOPLEFT", 0, 0)
                end
                frame.roleFrame.damage:Show()
            end
        end

        if notLeader then
            frame.acceptButton:Hide()
            frame.declineButton:Hide()
        else
            frame.acceptButton:Show()
            frame.declineButton:Show()
        end

        if applicant.status == Meeting.APPLICANT_STATUS.Accepted then
            frame.acceptButton:SetText("Accepted")
            frame.acceptButton:Disable()
        elseif applicant.status == Meeting.APPLICANT_STATUS.None then
            frame.acceptButton:SetText("Accept")
            frame.acceptButton:Enable()
        elseif applicant.status == Meeting.APPLICANT_STATUS.Declined then
            frame.acceptButton:SetText("Declined")
            frame.acceptButton:Enable()
        end
        frame.applicant = applicant
        frame.classColor = rgb
    end)
end

applicantListFrame.OnScroll = Meeting.CreatorFrame.UpdateList

function Meeting.CreatorFrame.UpdateActivity()
    if not Meeting.MainFrame:IsShown() or not Meeting.CreatorFrame:IsShown() then
        return
    end

    local ml = table.getn(Meeting.members)
    local isLeader = ml == 0 or (ml > 0 and IsRaidLeader() == 1)
    if isLeader then
        if Meeting.createInfo.code then
            selectButton:SetText(Meeting.GetActivityInfo(Meeting.createInfo.code).name)
        else
            selectButton:SetText("Select Activity")
        end
        if not commentFrame:HasFocus() then
            commentFrame:SetText(Meeting.createInfo.comment or "")
        end
        selectButton:Enable()
        local has = Meeting:OwnerActivity()
        if has then
            createButton:SetText("Edit Activity")
        else
            createButton:SetText("Create Activity")
        end

        if string.isempty(Meeting.createInfo.code) then
            createButton:Disable()
        else
            createButton:Enable()
        end

        if has then
            closeButton:Enable()
        else
            closeButton:Disable()
        end

        if table.getn(Meeting.members) > 0 and IsRaidLeader() ~= 1 then
            createButton:Hide()
            closeButton:Hide()
            translateButton:Hide()
        else
            createButton:Show()
            closeButton:Show()
            Meeting.CreatorFrame.UpdateTranslateButton()
        end
    elseif Meeting.joinedActivity then
        selectButton:SetText(Meeting.GetActivityInfo(Meeting.joinedActivity.code).name)
        commentFrame:SetText(Meeting.joinedActivity.comment == "_" and "" or Meeting.joinedActivity.comment or "")
        selectButton:Disable()
        createButton:Hide()
        closeButton:Hide()
        translateButton:Hide()
    else
        selectButton:SetText("Select Activity")
        commentFrame:SetText("")
        selectButton:Disable()
        createButton:Hide()
        closeButton:Hide()
        translateButton:Hide()
    end
end

Meeting.CreatorFrame.UpdateTranslateButton()
Meeting.CreatorFrame.UpdateActivity()
```

## Float.lua
```lua
local floatFrame = Meeting.GUI.CreateButton({
    name = "MettingFloatFrame",
    width = 100,
    height = 20,
    text = "Meeting",
    blizzard = false,
    type = Meeting.GUI.BUTTON_TYPE.NORMAL,
    anchor = {
        point = "TOP",
    },
    movable = true,
    click = function()
        Meeting:Toggle()
    end
})
--Meeting.GUI.SetBackground(floatFrame, Meeting.GUI.Theme.Black)
floatFrame:SetFrameStrata("DIALOG")
floatFrame:SetPoint("TOP", 0, -20)
floatFrame:SetNormalTexture(nil)
floatFrame:SetHighlightTexture(nil)
floatFrame:SetPushedTexture(nil)
floatFrame:SetBackdrop(nil)

-- 添加贴图
local icon = floatFrame:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\Meeting\\assets\\LFG.blp")
icon:SetWidth(28)
icon:SetHeight(28)
icon:SetPoint("LEFT", floatFrame, "LEFT", 2, -1)
floatFrame.icon = icon

local crown = floatFrame:CreateTexture(nil, "OVERLAY")
crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
crown:SetWidth(14)
crown:SetHeight(14)
-- Centered on icon; negative Y overlaps the top so it stays visible near screen edge.
crown:SetPoint("CENTER", icon, "TOP", 0, -4)
crown:Hide()
floatFrame.crown = crown

floatFrame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT", 85, -5)
    local activity = Meeting:FindActivity(Meeting.player)
    GameTooltip:SetText((activity and table.getn(activity.applicantList) or 0) .. " applicants", 1, 1, 1, 1)
    GameTooltip:AddLine(table.getn(Meeting.activities) .. " activities", 1, 1, 1, 1)
    GameTooltip:Show()
end)
floatFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

Meeting.FloatFrame = floatFrame
local flashing = false
local flashElapsed = 0
local flashSpeed = 1 -- 闪烁速度（秒）
local lastUpdate = 0

local function StartFlashing()
    if not flashing then
        flashing = true
        lastUpdate = GetTime() -- 初始化
        floatFrame:SetScript("OnUpdate", function(self)
            local now = GetTime()
            local elapsed = now - lastUpdate
            lastUpdate = now
            flashElapsed = flashElapsed + elapsed
            local alpha = 0.5 + 0.5 * math.abs(math.sin(flashElapsed * math.pi / flashSpeed))
            icon:SetAlpha(alpha)
        end)
    end
end

local function StopFlashing()
    if flashing then
        flashing = false
        floatFrame:SetScript("OnUpdate", nil)
        icon:SetAlpha(1)
        flashElapsed = 0
    end
end

function floatFrame.Update()
    Meeting.UpdateIcons()
    if not floatFrame:IsShown() then
        StopFlashing()
        return
    end
    local activity = Meeting.joinedActivity or Meeting:FindActivity(Meeting.player)
    local n = activity and table.getn(activity.applicantList) or 0
    -- 只显示数字，不显示“集合石”
    floatFrame:SetText("   Meeting")
    floatFrame:SetFont("Fonts\\FRIZQT__.TTF", Meeting.GUI.GetFontSize(15), "OUTLINE")
    if n > 0 then
        StartFlashing()
    else
        StopFlashing()
    end
end
```

## GUI.lua
```lua
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
```

## Init.lua
```lua
BINDING_HEADER_CS_MEETING_HEADER = "Meeting"
BINDING_NAME_CS_MEETING_NAME = "Show/Hide"

MEETING_DB = MEETING_DB or {}

local _, class = UnitClass("player")

Meeting = {
    VERSION = {
        MAJOR = 1,
        MINOR = 1,
        PATCH = 5,
    },

    player = UnitName("player"),

    playerClass = class,

    APPLICANT_STATUS = { None = 1, Invited = 2, Declined = 3, Joined = 4 },

    createInfo = {},

    searchInfo = {},

    activities = {},

    playerIsHC = false,

    channel = "LFT",

    isAFK = false,

    members = {},

    blockWords = {}, -- 添加屏蔽词引用 by 武藤纯子酱 2025.12.30
}

local classNameMap = {
    [1] = "WARLOCK",
    [2] = "HUNTER",
    [3] = "PRIEST",
    [4] = "PALADIN",
    [5] = "MAGE",
    [6] = "ROGUE",
    [7] = "DRUID",
    [8] = "SHAMAN",
    [9] = "WARRIOR",
}

local classNumberMap = {
    ["WARLOCK"] = 1,
    ["HUNTER"] = 2,
    ["PRIEST"] = 3,
    ["PALADIN"] = 4,
    ["MAGE"] = 5,
    ["ROGUE"] = 6,
    ["DRUID"] = 7,
    ["SHAMAN"] = 8,
    ["WARRIOR"] = 9,
}

local classChineseNameMap = {
    [1] = "Warlock",
    [2] = "Hunter",
    [3] = "Priest",
    [4] = "Paladin",
    [5] = "Mage",
    [6] = "Rogue",
    [7] = "Druid",
    [8] = "Shaman",
    [9] = "Warrior",
}

function Meeting.NumberToClass(n)
    return classNameMap[n]
end

function Meeting.ClassToNumber(class)
    return classNumberMap[class]
end

function Meeting.GetClassRGBColor(class, unitname)
    local rgb = RAID_CLASS_COLORS[class]
    if not class or not rgb then
        if SCCN_storage then
            local cache = SCCN_storage[unitname]
            if cache then
                return Meeting.GetClassRGBColor(Meeting.NumberToClass(cache.c))
            end
        end
        rgb = RAID_CLASS_COLORS[nil]
    end
    if not rgb then
        rgb = { r = 0.6, g = 0.6, b = 0.6 }
    end
    return rgb
end

Meeting.Categories = {
    {
        key = "DUNGENO",
        name = "Dungeons",
        members = 5,
        children = {
            {
                key = "RFC",
                name = "Ragefire Chasm",
                minLevel = 13,
                match = { "怒焰", "ny", "rfc", "ragefire" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "FH",
                name = "Frostmane Hold",
                minLevel = 13,
                match = { "霜鬃", "szg", "fh", "frostmane" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "WC",
                name = "Wailing Caverns",
                minLevel = 17,
                match = { "哀嚎", "ah", "wc", "wailing" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DM",
                name = "Deadmines",
                minLevel = 17,
                match = { "死矿", "sw", "dm", "deadmines" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SFK",
                name = "Shadowfang Keep",
                minLevel = 22,
                match = { "影牙", "sfk", "shadowfang" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STOCKS",
                name = "The Stockade",
                minLevel = 22,
                match = { "监狱", "stocks", "stockade" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BFD",
                name = "Blackfathom Deeps",
                minLevel = 23,
                match = { "深渊", "bfd", "blackfathom" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DR",
                name = "Dragonmaw Garrison",
                minLevel = 27,
                match = { "龙喉","格瑞姆巴托", "dragonmaw", "dr" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "WINDCAN",
                name = "Windhorn Ravine",
                minLevel = 27,
                match = { "风角","峡谷","牛头本", "windhorn", "windcan" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },				
            {
                key = "SMGY",
                name = "Scarlet Monastery Graveyard",
                minLevel = 27,
                match = { "血色", "sm", "scarlet" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SMLIB",
                name = "Scarlet Monastery Library",
                minLevel = 28,
                match = { "血色", "sm", "scarlet" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "GNOMER",
                name = "Gnomeregan",
                minLevel = 29,
				match = { "矮子本", "gnomer", "gnomeregan" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RFK",
                name = "Razorfen Kraul",
                minLevel = 29,
                match = { "剃刀", "rfk", "rfd", "razorfen" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "TCG",
                name = "Crescent Grove",
                minLevel = 32,
                match = { "新月", "cg", "crescent" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SMARMORY",
                name = "Scarlet Monastery Armory",
                minLevel = 32,
                match = { "血色", "sm", "scarlet" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STORM",
                name = "Ruins of Storm",
                minLevel = 35,
                match = { "风暴","风暴废墟","风暴之临","风暴城堡","巴洛", "storm", "barov" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },				
            {
                key = "SMCATH",
                name = "Scarlet Monastery Cathedral",
                minLevel = 35,
                match = { "血色","教堂", "sm", "cath" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RFD",
                name = "Razorfen Downs",
                minLevel = 36,
                match = { "剃刀", "rfk", "rfd", "razorfen" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ULDA",
                name = "Uldaman",
                minLevel = 40,
                match = { "奥达曼", "ulda", "uldaman" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "GILNEAS",
                name = "Gilneas City",
                minLevel = 42,
				match = { "吉尔尼斯", "狼人", "gilneas" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ZF",
                name = "Zul'Farrak",
                minLevel = 44,
                match = { "祖尔", "zul", "zf" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "MARA",
                name = "Maraudon",
                minLevel = 45,
                match = { "玛拉顿", "mara" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ST",
                name = "Sunken Temple",
                minLevel = 50,
                match = { "神庙", "st", "sunken" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "HFQ",
                name = "Hateforge Quarry",
                minLevel = 50,
                match = { "采石场", "hfq", "hateforge" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BRD",
                name = "Blackrock Depths",
                minLevel = 52,
				match = { "黑石深渊", "brd", "depths" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "UBRS",
                name = "Upper Blackrock Spire",
                minLevel = 55,
                members = 10,
                match = { "黑上", "ubrs" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "LBRS",
                name = "Lower Blackrock Spire",
                minLevel = 55,
                match = { "黑下", "lbrs" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22

            },
            {
                key = "DME",
                name = "Dire Maul East",
                minLevel = 55,
                match = { "厄运东", "dme" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DMN",
                name = "Dire Maul North",
                minLevel = 57,
                match = { "厄运北", "dmn" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DMW",
                name = "Dire Maul West",
                minLevel = 57,
                match = { "厄运西", "dmw" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SCHOLO",
                name = "Scholomance",
                minLevel = 58,
                members = 10,
                match = { "通灵", "tl", "scholo" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STRAT",
                name = "Stratholme",
                minLevel = 58,
                members = 10,
                match = { "斯坦索姆", "stsm", "strat" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "KC",
                name = "Karazhan Crypt",
                minLevel = 58,
                match = { "卡拉赞墓穴", "klz", "墓穴", "kc", "crypt" },
				nomatch = {"卡上", "卡下", "40人卡拉赞", "40人klz", "40klz", "klz40", "klz上层", "上层klz", "上层卡拉赞", "卡拉赞上层", "卡拉赞之塔", "k40"}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "COTBM",
                name = "Black Morass",
                minLevel = 60,
                match = { "时光", "沼泽", "bm", "morass" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SWV",
                name = "Stormwind Vault",
                minLevel = 60,
				match = { "大监狱", "地牢", "swv", "vault" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
        }
    },
    {
        key = "RAID",
        name = "Raids",
        members = 40,
        children = {
            {
                key = "MC",
                name = "Molten Core",
                minLevel = 60,
                match = { "mc", "molten core" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ONY",
                name = "Onyxia's Lair",
                minLevel = 60,
                match = { "黑龙", "ony", "onyxia" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BWL",
                name = "Blackwing Lair",
                minLevel = 60,
                match = { "黑翼", "bwl", "blackwing" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AQ40",
                name = "Temple of Ahn'Qiraj",
                minLevel = 60,
                match = { "安其拉", "taq", "aq40" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "NAXX",
                name = "Naxxramas",
                minLevel = 60,
                match = { "naxx", "naxxramas" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ZUG",
                name = "Zul'Gurub",
                minLevel = 60,
                members = 20,
                match = { "祖格", "zug", "zg", "龙虎金", "zg" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AQ20",
                name = "Ruins of Ahn'Qiraj",
                minLevel = 60,
                members = 20,
                match = { "废墟", "fx", "aq20" },
				nomatch = { "风暴废墟" }  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "TH",
                name = "Timbermaw Hold",
                minLevel = 60,
                members = 20,
                match = { "木喉", "要塞", "熊怪", "timbermaw", "th" },
				nomatch = { "风暴要塞" }  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "LKH",
                name = "Lower Karazhan Halls",
                minLevel = 60,
                members = 10,
                match = { "10人卡拉赞", "10人klz", "10klz", "klz10", "klz下层", "下层klz", "下层卡拉赞", "卡拉赞上层", "卡拉赞", "klz", "卡下", "lkh", "lower kara" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ES",
                name = "Emerald Sanctum",
                minLevel = 60,
                match = { "翡翠", "es", "emerald" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
			{
				key = "TOK",              -- 唯一标识符（需唯一）
				name = "Tower of Karazhan",        -- 显示名称
				minLevel = 60,              -- 最低等级要求（根据实际设定调整）
				match = { "40人卡拉赞", "40人klz", "40klz", "klz40", "klz上层", "上层klz", "上层卡拉赞", "卡拉赞上层", "卡拉赞之塔", "k40", "卡上", "tok", "upper kara"  },	 -- 匹配关键词（用户搜索时会触发）
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
			}		
        }
    },
    {
        key = "QUEST",
        name = "Quests",
        members = 5,
        children = {
            {
                key = "PartyQuest",
                name = "Party Quests",
                members = 5,
				match = { "任务", "quest" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RaidQuest",
                name = "Raid Quests",
                members = 40,
				match = { "任务", "quest" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
			{
				key = "QuestLink",  -- 新增任务链接追踪
				name = "Quest Link",
				members = 5,
				match = { "quest:" },  -- 匹配任务链接特征
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
			},			
        }
    },
    {
        key = "BOSS",
        name = "World Bosses",
        members = 40,
        children = {
            {
                key = "Azuregos",
                name = "Azuregos",
                members = 40,
				match = { "蓝龙", "艾萨拉", "世界BOSS", "azuregos", "azshara", "wb" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Emeriss",
                name = "Emeriss",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Lethon",
                name = "Lethon",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Taerar",
                name = "Taerar",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Ysondre",
                name = "Ysondre",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Kazzak",
                name = "Lord Kazzak",
                members = 40,
				match = { "卡扎克", "诅咒之地", "世界BOSS", "kazzak", "wb" },			
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "Nerubian",
                name = "Nerubian Overseer",
                members = 40,
				match = { "蛛魔监工", "东瘟疫", "世界BOSS", "nerubian", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "DarkReaver",
                name = "Dark Reaver of Karazhan",
                members = 40,
				match = { "黑暗掠夺者", "逆风小径", "世界BOSS", "dark reaver", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Ostarius",
                name = "Ostarius",
                members = 40,
				match = { "奥兹塔里亚斯", "奥丹姆", "塔纳利斯", "世界BOSS", "ostarius", "wb" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Concavius",
                name = "Concavius",
                members = 40,
				match = { "空卡维斯", "虚空之子", "凄凉之地", "世界BOSS", "concavius", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Cow",
                name = "Cow King",
                members = 40,
				match = { "奶牛", "艾尔文森林", "世界BOSS", "cow", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Cla'ckora",
                name = "Cla'ckora",
                members = 40,
				match = { "克拉科拉", "鱼人", "艾萨拉", "世界BOSS", "clackora", "murloc", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },			
        }
    },
    {
        key = "PVP",
        name = "PvP",
        children = {
            {
                key = "AV",
                name = "Alterac Valley",
                minLevel = 51,
                members = 40,
				match = { "奥特兰克", "奥山", "大战场", "av", "alterac" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "WSG",
                name = "Warsong Gulch",
                minLevel = 10,
                members = 10,
				match = { "战歌", "小战场", "wsg", "warsong" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AB",
                name = "Arathi Basin",
                minLevel = 20,
                members = 15,
				match = { "阿拉希", "ALX", "ab", "arathi" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BR",
                name = "Blood Ring",
                minLevel = 11,
                members = 3,
				match = { "血环", "竞技场", "blood ring", "arena" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "PVP",
                name = "World PvP",
                minLevel = 1,
                members = 40,
				match = { "PVP", "pvp", "world pvp" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
        }
    },
    {
        key = "OTHER",
        name = "Other",
        members = 40,
        children = {
            {
                key = "OTHER",
                name = "Other",
                minLevel = 1,
            },
        }
    },
    {
        key = "CHAT",
        name = "Channels",
        members = 40,
        hide = true,
        children = {
            {
                key = "WORLD",
                name = "World Channel",
                minLevel = 1,
            },
            {
                key = "CHINA",
                name = "Chinese Channel",
                minLevel = 1,
            },
            {
                key = "HARDCORE",
                name = "Hardcore Channel",
                minLevel = 1,
            },
        }
    }
}

local activityCategoryMap = {}

for _, value in ipairs(Meeting.Categories) do
    for _, child in ipairs(value.children) do
        activityCategoryMap[child.key] = { key = value.key, members = value.members }
    end
end

function Meeting.GetActivityCategory(code)
    return activityCategoryMap[code]
end

function Meeting.GetActivityMaxMembers(code)
    local info = Meeting.GetActivityInfo(code)
    if info and info.members then
        return info.members
    end

    local category = Meeting.GetActivityCategory(code)
    if category then
        return category.members
    end

    return 40
end

local activityInfoMap = {}

function Meeting.GetActivityInfo(code)
    if activityInfoMap[code] then
        return activityInfoMap[code]
    end
    for _, value in pairs(Meeting.Categories) do
        for _, value in pairs(value.children) do
            if value.key == code then
                activityInfoMap[code] = value
                return value
            end
        end
    end
    local other = Meeting.GetActivityInfo("OTHER")
    activityInfoMap[code] = other
    return other
end

function Meeting.GetPlayerScore()
    if ItemSocre and ItemSocre.ScanUnit then
        local score = ItemSocre:ScanUnit("player")
        if score and score > 0 then
            return score
        end
    end
    return 0
end

local Role = {
    Tank = bit.lshift(1, 1),
    Healer = bit.lshift(1, 2),
    Damage = bit.lshift(1, 3)
}
Meeting.Role = Role

local classRoleMap = {
    ["WARLOCK"] = Role.Damage,
    ["HUNTER"] = Role.Damage,
    ["PRIEST"] = bit.bor(Role.Healer, Role.Damage),
    ["PALADIN"] = bit.bor(Role.Tank, Role.Healer, Role.Damage),
    ["MAGE"] = Role.Damage,
    ["ROGUE"] = Role.Damage,
    ["DRUID"] = bit.bor(Role.Tank, Role.Healer, Role.Damage),
    ["SHAMAN"] = bit.bor(Role.Healer, Role.Damage),
    ["WARRIOR"] = bit.bor(Role.Tank, Role.Damage),
}

function Meeting.GetClassRole(class)
    return classRoleMap[class]
end

local fortyone = { "0",
    "1", "2", "3", "4", "5",
    "6", "7", "8", "9", "a",
    "b", "c", "d", "e", "f",
    "g", "h", "i", "j", "k",
    "l", "m", "n", "o", "p",
    "q", "r", "s", "t", "u",
    "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E" }
local fortyoneIndexes = {}
for index, value in ipairs(fortyone) do
    fortyoneIndexes[value] = index - 1
end

function Meeting.EncodeGroupClass()
    local raid = false
    local arr = {}
    for _, value in ipairs(classNameMap) do
        if value == Meeting.playerClass then
            arr[value] = 1
        else
            arr[value] = 0
        end
    end

	for i = 1, GetNumRaidMembers() do
		raid = true
		local _, class = UnitClass("raid" .. i)
		if class then
			arr[class] = (arr[class] or 0) + 1
		end
	end

	if not raid then
		for i = 1, GetNumPartyMembers() do
			local _, class = UnitClass("party" .. i)
			if class then
				arr[class] = (arr[class] or 0) + 1
			end
		end
	end

    local result = ""
    for _, v in ipairs(classNameMap) do
        local num = arr[v]
        result = result .. fortyone[num + 1]
    end
    return result
end

function Meeting.DecodeGroupClass(str)
    if not str then
        return
    end
    local arr = {}
    for i = 1, string.len(str) do
        local c = string.sub(str, i, i)
        local num = fortyoneIndexes[c]
        if num ~= nil and num > 0 then
            arr[i] = num
        end
    end
    return arr
end

local colorCache = {}

function Meeting.GetClassLocaleName(i)
    if colorCache[i] then
        return colorCache[i]
    end
    local color = Meeting.GetClassRGBColor(Meeting.NumberToClass(i))
    local str = string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, classChineseNameMap
        [i])
    colorCache[i] = str
    return str
end

-- 添加初始化 by 武藤纯子酱 2025.9.22
Meeting.searchInfo.codes = {}  -- 初始化多选状态
```

## Layout.lua
```lua
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
```

## libs/AceLibrary.lua
```lua
--[[
Name: AceLibrary
Revision: $Rev: 14130 $
Developed by: The Ace Development Team (http://www.wowace.com/index.php/The_Ace_Development_Team)
Inspired By: Iriel (iriel@vigilance-committee.org)
             Tekkub (tekkub@gmail.com)
             Revision: $Rev: 14130 $
Website: http://www.wowace.com/
Documentation: http://www.wowace.com/index.php/AceLibrary
SVN: http://svn.wowace.com/root/trunk/Ace2/AceLibrary
Description: Versioning library to handle other library instances, upgrading,
             and proper access.
             It also provides a base for libraries to work off of, providing
             proper error tools. It is handy because all the errors occur in the
             file that called it, not in the library file itself.
Dependencies: None
]]

local ACELIBRARY_MAJOR = "AceLibrary"
local ACELIBRARY_MINOR = "$Revision: 14130 $"

local table_setn
do
	local version = GetBuildInfo()
	if string.find(version, "^2%.") then
		-- 2.0.0
		table_setn = function() end
	else
		table_setn = table.setn
	end
end

local string_gfind = string.gmatch or string.gfind

local _G = getfenv(0)
local previous = _G[ACELIBRARY_MAJOR]
if previous and not previous:IsNewVersion(ACELIBRARY_MAJOR, ACELIBRARY_MINOR) then return end

-- @table AceLibrary
-- @brief System to handle all versioning of libraries.
local AceLibrary = {}
local AceLibrary_mt = {}
setmetatable(AceLibrary, AceLibrary_mt)

local tmp
local function error(self, message, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	if type(self) ~= "table" then
		_G.error(string.format("Bad argument #1 to `error' (table expected, got %s)", type(self)), 2)
	end
	if not tmp then
		tmp = {}
	else
		for k in pairs(tmp) do tmp[k] = nil end
		table_setn(tmp, 0)
	end

	table.insert(tmp, a1)
	table.insert(tmp, a2)
	table.insert(tmp, a3)
	table.insert(tmp, a4)
	table.insert(tmp, a5)
	table.insert(tmp, a6)
	table.insert(tmp, a7)
	table.insert(tmp, a8)
	table.insert(tmp, a9)
	table.insert(tmp, a10)
	table.insert(tmp, a11)
	table.insert(tmp, a12)
	table.insert(tmp, a13)
	table.insert(tmp, a14)
	table.insert(tmp, a15)
	table.insert(tmp, a16)
	table.insert(tmp, a17)
	table.insert(tmp, a18)
	table.insert(tmp, a19)
	table.insert(tmp, a20)

	local stack = debugstack()
	if not message then
		local _,_,second = string.find(stack, "\n(.-)\n")
		message = "error raised! " .. second
	else
		for i = 1,table.getn(tmp) do
			tmp[i] = tostring(tmp[i])
		end
		for i = 1,10 do
			table.insert(tmp, "nil")
		end
		message = string.format(message, unpack(tmp))
	end

	if getmetatable(self) and getmetatable(self).__tostring then
		message = string.format("%s: %s", tostring(self), message)
	elseif type(rawget(self, 'GetLibraryVersion')) == "function" and AceLibrary:HasInstance(self:GetLibraryVersion()) then
		message = string.format("%s: %s", self:GetLibraryVersion(), message)
	elseif type(rawget(self, 'class')) == "table" and type(rawget(self.class, 'GetLibraryVersion')) == "function" and AceLibrary:HasInstance(self.class:GetLibraryVersion()) then
		message = string.format("%s: %s", self.class:GetLibraryVersion(), message)
	end

	local first = string.gsub(stack, "\n.*", "")
	local file = string.gsub(first, ".*\\(.*).lua:%d+: .*", "%1")
	file = string.gsub(file, "([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1")

	local i = 0
	for s in string_gfind(stack, "\n([^\n]*)") do
		i = i + 1
		if not string.find(s, file .. "%.lua:%d+:") then
			file = string.gsub(s, "^.*\\(.*).lua:%d+: .*", "%1")
			file = string.gsub(file, "([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1")
			break
		end
	end
	local j = 0
	for s in string_gfind(stack, "\n([^\n]*)") do
		j = j + 1
		if j > i and not string.find(s, file .. "%.lua:%d+:") then
			_G.error(message, j + 1)
			return
		end
	end
	_G.error(message, 2)
	return
end

local function assert(self, condition, message, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	if not condition then
		if not message then
			local stack = debugstack()
			local _,_,second = string.find(stack, "\n(.-)\n")
			message = "assertion failed! " .. second
		end
		error(self, message, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
		return
	end
	return condition
end

local function argCheck(self, arg, num, kind, kind2, kind3, kind4, kind5)
	if type(num) ~= "number" then
		error(self, "Bad argument #3 to `argCheck' (number expected, got %s)", type(num))
	elseif type(kind) ~= "string" then
		error(self, "Bad argument #4 to `argCheck' (string expected, got %s)", type(kind))
	end
	local errored = false
	arg = type(arg)
	if arg ~= kind and arg ~= kind2 and arg ~= kind3 and arg ~= kind4 and arg ~= kind5 then
		local _,_,func = string.find(debugstack(), "`argCheck'.-([`<].-['>])")
		if not func then
			_,_,func = string.find(debugstack(), "([`<].-['>])")
		end
		if kind5 then
			error(self, "Bad argument #%s to %s (%s, %s, %s, %s, or %s expected, got %s)", tonumber(num) or 0/0, func, kind, kind2, kind3, kind4, kind5, arg)
		elseif kind4 then
			error(self, "Bad argument #%s to %s (%s, %s, %s, or %s expected, got %s)", tonumber(num) or 0/0, func, kind, kind2, kind3, kind4, arg)
		elseif kind3 then
			error(self, "Bad argument #%s to %s (%s, %s, or %s expected, got %s)", tonumber(num) or 0/0, func, kind, kind2, kind3, arg)
		elseif kind2 then
			error(self, "Bad argument #%s to %s (%s or %s expected, got %s)", tonumber(num) or 0/0, func, kind, kind2, arg)
		else
			error(self, "Bad argument #%s to %s (%s expected, got %s)", tonumber(num) or 0/0, func, kind, arg)
		end
	end
end

local function pcall(self, func, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20 = _G.pcall(func, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	if not a1 then
		error(self, string.gsub(a2, ".-%.lua:%d-: ", ""))
	else
		return a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20
	end
end

local recurse = {}
local function addToPositions(t, major)
	if not AceLibrary.positions[t] or AceLibrary.positions[t] == major then
		rawset(t, recurse, true)
		AceLibrary.positions[t] = major
		for k,v in pairs(t) do
			if type(v) == "table" and not rawget(v, recurse) then
				addToPositions(v, major)
			end
			if type(k) == "table" and not rawget(k, recurse) then
				addToPositions(k, major)
			end
		end
		local mt = getmetatable(t)
		if mt and not rawget(mt, recurse) then
			addToPositions(mt, major)
		end
		rawset(t, recurse, nil)
	end
end

local function svnRevisionToNumber(text)
	if type(text) == "string" then
		if string.find(text, "^%$Revision: (%d+) %$$") then
			return tonumber((string.gsub(text, "^%$Revision: (%d+) %$$", "%1")))
		elseif string.find(text, "^%$Rev: (%d+) %$$") then
			return tonumber((string.gsub(text, "^%$Rev: (%d+) %$$", "%1")))
		elseif string.find(text, "^%$LastChangedRevision: (%d+) %$$") then
			return tonumber((string.gsub(text, "^%$LastChangedRevision: (%d+) %$$", "%1")))
		end
	elseif type(text) == "number" then
		return text
	end
	return nil
end

local crawlReplace
do
	local recurse = {}
	local function func(t, to, from)
		if recurse[t] then
			return
		end
		recurse[t] = true
		local mt = getmetatable(t)
		setmetatable(t, nil)
		rawset(t, to, rawget(t, from))
		rawset(t, from, nil)
		for k,v in pairs(t) do
			if v == from then
				t[k] = to
			elseif type(v) == "table" then
				if not recurse[v] then
					func(v, to, from)
				end
			end

			if type(k) == "table" then
				if not recurse[k] then
					func(k, to, from)
				end
			end
		end
		setmetatable(t, mt)
		if mt then
			if mt == from then
				setmetatable(t, to)
			elseif not recurse[mt] then
				func(mt, to, from)
			end
		end
	end
	function crawlReplace(t, to, from)
		func(t, to, from)
		for k in pairs(recurse) do
			recurse[k] = nil
		end
	end
end

-- @function destroyTable
-- @brief    remove all the contents of a table
-- @param t  table to destroy
local function destroyTable(t)
	setmetatable(t, nil)
	for k,v in pairs(t) do t[k] = nil end
	table_setn(t, 0)
end

local function isFrame(frame)
	return type(frame) == "table" and type(rawget(frame, 0)) == "userdata" and type(rawget(frame, 'IsFrameType')) == "function" and getmetatable(frame) and type(rawget(getmetatable(frame), '__index')) == "function"
end

local new, del
do
	local tables = setmetatable({}, {__mode = "k"})

	function new()
		local t = next(tables)
		if t then
			tables[t] = nil
			return t
		else
			return {}
		end
	end

	function del(t, depth)
		if depth and depth > 0 then
			for k,v in pairs(t) do
				if type(v) == "table" and not isFrame(v) then
					del(v, depth - 1)
				end
			end
		end
		destroyTable(t)
		tables[t] = true
	end
end

-- @function   copyTable
-- @brief      Create a shallow copy of a table and return it.
-- @param from The table to copy from
-- @return     A shallow copy of the table
local function copyTable(from)
	local to = new()
	for k,v in pairs(from) do to[k] = v end
	table_setn(to, table.getn(from))
	setmetatable(to, getmetatable(from))
	return to
end

-- @function         deepTransfer
-- @brief            Fully transfer all data, keeping proper previous table
--                   backreferences stable.
-- @param to         The table with which data is to be injected into
-- @param from       The table whose data will be injected into the first
-- @param saveFields If available, a shallow copy of the basic data is saved
--                   in here.
-- @param list       The account of table references
-- @param list2      The current status on which tables have been traversed.
local deepTransfer
do
	-- @function   examine
	-- @brief      Take account of all the table references to be shared
	--             between the to and from tables.
	-- @param to   The table with which data is to be injected into
	-- @param from The table whose data will be injected into the first
	-- @param list An account of the table references
	local function examine(to, from, list, major)
		list[from] = to
		for k,v in pairs(from) do
			if rawget(to, k) and type(from[k]) == "table" and type(to[k]) == "table" and not list[from[k]] then
				if from[k] == to[k] then
					list[from[k]] = to[k]
				elseif AceLibrary.positions[from[v]] ~= major and AceLibrary.positions[from[v]] then
					list[from[k]] = from[k]
				elseif not list[from[k]] then
					examine(to[k], from[k], list, major)
				end
			end
		end
		return list
	end

	function deepTransfer(to, from, saveFields, major, list, list2)
		setmetatable(to, nil)
		local createdList
		if not list then
			createdList = true
			list = new()
			list2 = new()
			examine(to, from, list, major)
		end
		list2[to] = to
		for k,v in pairs(to) do
			if type(rawget(from, k)) ~= "table" or type(v) ~= "table" or isFrame(v) then
				if saveFields then
					saveFields[k] = v
				end
				to[k] = nil
			elseif v ~= _G then
				if saveFields then
					saveFields[k] = copyTable(v)
				end
			end
		end
		for k in pairs(from) do
			if rawget(to, k) and to[k] ~= from[k] and AceLibrary.positions[to[k]] == major and from[k] ~= _G then
				if not list2[to[k]] then
					deepTransfer(to[k], from[k], nil, major, list, list2)
				end
				to[k] = list[to[k]] or list2[to[k]]
			else
				rawset(to, k, from[k])
			end
		end
		table_setn(to, table.getn(from))
		setmetatable(to, getmetatable(from))
		local mt = getmetatable(to)
		if mt then
			if list[mt] then
				setmetatable(to, list[mt])
			elseif mt.__index and list[mt.__index] then
				mt.__index = list[mt.__index]
			end
		end
		destroyTable(from)
		if createdList then
			del(list)
			del(list2)
		end
	end
end

-- @method      TryToLoadStandalone
-- @brief       Attempt to find and load a standalone version of the requested library
-- @param major A string representing the major version
-- @return      If library is found, return values from the call to LoadAddOn are returned
--              If the library has been requested previously, nil is returned.
local function TryToLoadStandalone(major)
	if not AceLibrary.scannedlibs then AceLibrary.scannedlibs = {} end
	if AceLibrary.scannedlibs[major] then return end

	AceLibrary.scannedlibs[major] = true

	local name, _, _, enabled, loadable = GetAddOnInfo(major)
	if loadable then
		return LoadAddOn(name)
	end

	for i=1,GetNumAddOns() do
		if GetAddOnMetadata(i, "X-AceLibrary-"..major) then
			local name, _, _, enabled, loadable = GetAddOnInfo(i)
			if loadable then
				return LoadAddOn(name)
			end
		end
	end
end

-- @method      IsNewVersion
-- @brief       Obtain whether the supplied version would be an upgrade to the
--              current version. This allows for bypass code in library
--              declaration.
-- @param major A string representing the major version
-- @param minor An integer or an svn revision string representing the minor version
-- @return      whether the supplied version would be newer than what is
--              currently available.
function AceLibrary:IsNewVersion(major, minor)
	argCheck(self, major, 2, "string")
	TryToLoadStandalone(major)

	if type(minor) == "string" then
		local m = svnRevisionToNumber(minor)
		if m then
			minor = m
		else
			_G.error(string.format("Bad argument #3 to  `IsNewVersion'. Must be a number or SVN revision string. %q is not appropriate", minor), 2)
		end
	end
	argCheck(self, minor, 3, "number")
	local data = self.libs[major]
	if not data then
		return true
	end
	return data.minor < minor
end

-- @method      HasInstance
-- @brief       Returns whether an instance exists. This allows for optional support of a library.
-- @param major A string representing the major version.
-- @param minor (optional) An integer or an svn revision string representing the minor version.
-- @return      Whether an instance exists.
function AceLibrary:HasInstance(major, minor)
	argCheck(self, major, 2, "string")
	TryToLoadStandalone(major)

	if minor then
		if type(minor) == "string" then
			local m = svnRevisionToNumber(minor)
			if m then
				minor = m
			else
				_G.error(string.format("Bad argument #3 to  `HasInstance'. Must be a number or SVN revision string. %q is not appropriate", minor), 2)
			end
		end
		argCheck(self, minor, 3, "number")
		if not self.libs[major] then
			return
		end
		return self.libs[major].minor == minor
	end
	return self.libs[major] and true
end

-- @method      GetInstance
-- @brief       Returns the library with the given major/minor version.
-- @param major A string representing the major version.
-- @param minor (optional) An integer or an svn revision string representing the minor version.
-- @return      The library with the given major/minor version.
function AceLibrary:GetInstance(major, minor)
	argCheck(self, major, 2, "string")
	TryToLoadStandalone(major)

	local data = self.libs[major]
	if not data then
		_G.error(string.format("Cannot find a library instance of %s.", major), 2)
		return
	end
	if minor then
		if type(minor) == "string" then
			local m = svnRevisionToNumber(minor)
			if m then
				minor = m
			else
				_G.error(string.format("Bad argument #3 to  `GetInstance'. Must be a number or SVN revision string. %q is not appropriate", minor), 2)
			end
		end
		argCheck(self, minor, 2, "number")
		if data.minor ~= minor then
			_G.error(string.format("Cannot find a library instance of %s, minor version %d.", major, minor), 2)
			return
		end
	end
	return data.instance
end

-- Syntax sugar.  AceLibrary("FooBar-1.0")
AceLibrary_mt.__call = AceLibrary.GetInstance

local donothing

local AceEvent

-- @method               Register
-- @brief                Registers a new version of a given library.
-- @param newInstance    the library to register
-- @param major          the major version of the library
-- @param minor          the minor version of the library
-- @param activateFunc   (optional) A function to be called when the library is
--                       fully activated. Takes the arguments
--                       (newInstance [, oldInstance, oldDeactivateFunc]). If
--                       oldInstance is given, you should probably call
--                       oldDeactivateFunc(oldInstance).
-- @param deactivateFunc (optional) A function to be called by a newer library's
--                       activateFunc.
-- @param externalFunc   (optional) A function to be called whenever a new
--                       library is registered.
function AceLibrary:Register(newInstance, major, minor, activateFunc, deactivateFunc, externalFunc)
	argCheck(self, newInstance, 2, "table")
	argCheck(self, major, 3, "string")
	if type(minor) == "string" then
		local m = svnRevisionToNumber(minor)
		if m then
			minor = m
		else
			_G.error(string.format("Bad argument #4 to  `Register'. Must be a number or SVN revision string. %q is not appropriate", minor), 2)
		end
	end
	argCheck(self, minor, 4, "number")
	if math.floor(minor) ~= minor or minor < 0 then
		error(self, "Bad argument #4 to `Register' (integer >= 0 expected, got %s)", minor)
	end
	argCheck(self, activateFunc, 5, "function", "nil")
	argCheck(self, deactivateFunc, 6, "function", "nil")
	argCheck(self, externalFunc, 7, "function", "nil")
	if not deactivateFunc then
		if not donothing then
			donothing = function() end
		end
		deactivateFunc = donothing
	end
	local data = self.libs[major]
	if not data then
		-- This is new
		local instance = copyTable(newInstance)
		crawlReplace(instance, instance, newInstance)
		destroyTable(newInstance)
		if AceLibrary == newInstance then
			self = instance
			AceLibrary = instance
		end
		self.libs[major] = {
			instance = instance,
			minor = minor,
			deactivateFunc = deactivateFunc,
			externalFunc = externalFunc,
		}
		rawset(instance, 'GetLibraryVersion', function(self)
			return major, minor
		end)
		if not rawget(instance, 'error') then
			rawset(instance, 'error', error)
		end
		if not rawget(instance, 'assert') then
			rawset(instance, 'assert', assert)
		end
		if not rawget(instance, 'argCheck') then
			rawset(instance, 'argCheck', argCheck)
		end
		if not rawget(instance, 'pcall') then
			rawset(instance, 'pcall', pcall)
		end
		addToPositions(instance, major)
		if activateFunc then
			activateFunc(instance, nil, nil) -- no old version, so explicit nil
		end

		if externalFunc then
			for k,data in pairs(self.libs) do
				if k ~= major then
					externalFunc(instance, k, data.instance)
				end
			end
		end

		for k,data in pairs(self.libs) do
			if k ~= major and data.externalFunc then
				data.externalFunc(data.instance, major, instance)
			end
		end
		if major == "AceEvent-2.0" then
			AceEvent = instance
		end
		if AceEvent then
			AceEvent.TriggerEvent(self, "AceLibrary_Register", major, instance)
		end

		return instance
	end
	local instance = data.instance
	if minor <= data.minor then
		-- This one is already obsolete, raise an error.
		_G.error(string.format("Obsolete library registered. %s is already registered at version %d. You are trying to register version %d. Hint: if not AceLibrary:IsNewVersion(%q, %d) then return end", major, data.minor, minor, major, minor), 2)
		return
	end
	-- This is an update
	local oldInstance = new()

	addToPositions(newInstance, major)
	local isAceLibrary = (AceLibrary == newInstance)
	local old_error, old_assert, old_argCheck, old_pcall
	if isAceLibrary then
		self = instance
		AceLibrary = instance

		old_error = instance.error
		old_assert = instance.assert
		old_argCheck = instance.argCheck
		old_pcall = instance.pcall

		self.error = error
		self.assert = assert
		self.argCheck = argCheck
		self.pcall = pcall
	end
	deepTransfer(instance, newInstance, oldInstance, major)
	crawlReplace(instance, instance, newInstance)
	local oldDeactivateFunc = data.deactivateFunc
	data.minor = minor
	data.deactivateFunc = deactivateFunc
	data.externalFunc = externalFunc
	rawset(instance, 'GetLibraryVersion', function(self)
		return major, minor
	end)
	if not rawget(instance, 'error') then
		rawset(instance, 'error', error)
	end
	if not rawget(instance, 'assert') then
		rawset(instance, 'assert', assert)
	end
	if not rawget(instance, 'argCheck') then
		rawset(instance, 'argCheck', argCheck)
	end
	if not rawget(instance, 'pcall') then
		rawset(instance, 'pcall', pcall)
	end
	if isAceLibrary then
		for _,v in pairs(self.libs) do
			local i = type(v) == "table" and v.instance
			if type(i) == "table" then
				if not rawget(i, 'error') or i.error == old_error then
					rawset(i, 'error', error)
				end
				if not rawget(i, 'assert') or i.assert == old_assert then
					rawset(i, 'assert', assert)
				end
				if not rawget(i, 'argCheck') or i.argCheck == old_argCheck then
					rawset(i, 'argCheck', argCheck)
				end
				if not rawget(i, 'pcall') or i.pcall == old_pcall then
					rawset(i, 'pcall', pcall)
				end
			end
		end
	end
	if activateFunc then
		activateFunc(instance, oldInstance, oldDeactivateFunc)
	else
		oldDeactivateFunc(oldInstance)
	end
	del(oldInstance)

	if externalFunc then
		for k,data in pairs(self.libs) do
			if k ~= major then
				externalFunc(instance, k, data.instance)
			end
		end
	end

	return instance
end

local iter
function AceLibrary:IterateLibraries()
	if not iter then
		local function iter(t, k)
			k = next(t, k)
			if not k then
				return nil
			else
				return k, t[k].instance
			end
		end
	end
	return iter, self.libs, nil
end

-- @function            Activate
-- @brief               The activateFunc for AceLibrary itself. Called when
--                      AceLibrary properly registers.
-- @param self          Reference to AceLibrary
-- @param oldLib        (optional) Reference to an old version of AceLibrary
-- @param oldDeactivate (optional) Function to deactivate the old lib
local function activate(self, oldLib, oldDeactivate)
	if not self.libs then
		if oldLib then
			self.libs = oldLib.libs
			self.scannedlibs = oldLib.scannedlibs
		end
		if not self.libs then
			self.libs = {}
		end
		if not self.scannedlibs then
			self.scannedlibs = {}
		end
	end
	if not self.positions then
		if oldLib then
			self.positions = oldLib.positions
		end
		if not self.positions then
			self.positions = setmetatable({}, { __mode = "k" })
		end
	end

	-- Expose the library in the global environment
	_G[ACELIBRARY_MAJOR] = self

	if oldDeactivate then
		oldDeactivate(oldLib)
	end
end

if not previous then
	previous = AceLibrary
end
if not previous.libs then
	previous.libs = {}
end
AceLibrary.libs = previous.libs
if not previous.positions then
	previous.positions = setmetatable({}, { __mode = "k" })
end
AceLibrary.positions = previous.positions
AceLibrary:Register(AceLibrary, ACELIBRARY_MAJOR, ACELIBRARY_MINOR, activate)
```

## libs/Dewdrop-2.0.lua
```lua
--[[
Name: Dewdrop-2.0
Revision: $Rev: 15465 $
Author(s): ckknight (ckknight@gmail.com)
Website: http://ckknight.wowinterface.com/
Documentation: http://wiki.wowace.com/index.php/Dewdrop-2.0
SVN: http://svn.wowace.com/root/trunk/DewdropLib/Dewdrop-2.0
Description: A library to provide a clean dropdown menu interface.
Dependencies: AceLibrary
]]

local MAJOR_VERSION = "Dewdrop-2.0"
local MINOR_VERSION = "$Revision: 15465 $"

if not AceLibrary then error(MAJOR_VERSION .. " requires AceLibrary") end
if not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION) then return end

local Dewdrop = {}

local lua51 = loadstring("return function(...) return ... end") and true or false

local table_setn = lua51 and function() end or table.setn

local function new(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	local t = {}
	if k1 then t[k1] = v1
	if k2 then t[k2] = v2
	if k3 then t[k3] = v3
	if k4 then t[k4] = v4
	if k5 then t[k5] = v5
	if k6 then t[k6] = v6
	if k7 then t[k7] = v7
	if k8 then t[k8] = v8
	if k9 then t[k9] = v9
	if k10 then t[k10] = v10
	if k11 then t[k11] = v11
	if k12 then t[k12] = v12
	if k13 then t[k13] = v13
	if k14 then t[k14] = v14
	if k15 then t[k15] = v15
	if k16 then t[k16] = v16
	if k17 then t[k17] = v17
	if k18 then t[k18] = v18
	if k19 then t[k19] = v19
	if k20 then t[k20] = v20
	end end end end end end end end end end end end end end end end end end end end
	return t
end
if lua51 then
	new = loadstring("return function(...) local t = {}; for i = 1, select('#', ...), 2 do if select(i, ...) then t[select(i, ...)] = select(i+1, ...); else break; end; end; return t; end")()
end

local tmp
do
	local t = {}
	function tmp(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
		for k in pairs(t) do
			t[k] = nil
		end
		if type(k1) == "table" then
			for k,v in pairs(k1) do
				t[k] = v
			end
		else
			if k1 then t[k1] = v1
			if k2 then t[k2] = v2
			if k3 then t[k3] = v3
			if k4 then t[k4] = v4
			if k5 then t[k5] = v5
			if k6 then t[k6] = v6
			if k7 then t[k7] = v7
			if k8 then t[k8] = v8
			if k9 then t[k9] = v9
			if k10 then t[k10] = v10
			if k11 then t[k11] = v11
			if k12 then t[k12] = v12
			if k13 then t[k13] = v13
			if k14 then t[k14] = v14
			if k15 then t[k15] = v15
			if k16 then t[k16] = v16
			if k17 then t[k17] = v17
			if k18 then t[k18] = v18
			if k19 then t[k19] = v19
			if k20 then t[k20] = v20
			end end end end end end end end end end end end end end end end end end end end
		end
		return t
	end
	if lua51 then
		tmp = loadstring("local t = {}; return function(...) for k in pairs(t) do t[k] = nil end; for i = 1, select('#', ...), 2 do if select(i, ...) then t[select(i, ...)] = select(i+1, ...) else break; end; end; return t; end")()
	end
end
local tmp2
do
	local t = {}
	function tmp2(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
		for k in pairs(t) do
			t[k] = nil
		end
		if k1 then t[k1] = v1
		if k2 then t[k2] = v2
		if k3 then t[k3] = v3
		if k4 then t[k4] = v4
		if k5 then t[k5] = v5
		if k6 then t[k6] = v6
		if k7 then t[k7] = v7
		if k8 then t[k8] = v8
		if k9 then t[k9] = v9
		if k10 then t[k10] = v10
		if k11 then t[k11] = v11
		if k12 then t[k12] = v12
		if k13 then t[k13] = v13
		if k14 then t[k14] = v14
		if k15 then t[k15] = v15
		if k16 then t[k16] = v16
		if k17 then t[k17] = v17
		if k18 then t[k18] = v18
		if k19 then t[k19] = v19
		if k20 then t[k20] = v20
		end end end end end end end end end end end end end end end end end end end end
		return t
	end
	if lua51 then
		tmp2 = loadstring("local t = {}; return function(...) for k in pairs(t) do t[k] = nil end; for i = 1, select('#', ...), 2 do if select(i, ...) then t[select(i, ...)] = select(i+1, ...) else break; end; end; return t; end")()
	end
end
local levels
local buttons

local function GetScaledCursorPosition()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	return x / scale, y / scale
end

local function StartCounting(self, levelNum)
	for i = levelNum, table.getn(levels) do
		if levels[i] then
			levels[i].count = 3
		end
	end
end

local function StopCounting(self, level)
	for i = level, 1, -1 do
		if levels[i] then
			levels[i].count = nil
		end
	end
end

local function OnUpdate(self, arg1)
	for _,level in ipairs(levels) do
		if level.count then
			level.count = level.count - arg1
			if level.count < 0 then
				level.count = nil
				self:Close(level.num)
			end
		end
	end
end

local function CheckDualMonitor(self, frame)
	local ratio = GetScreenWidth() / GetScreenHeight()
	if ratio >= 2.4 and frame:GetRight() > GetScreenWidth() / 2 and frame:GetLeft() < GetScreenWidth() / 2 then
		local offsetx
		if GetCursorPosition() / GetScreenHeight() * 768 < GetScreenWidth() / 2 then
			offsetx = GetScreenWidth() / 2 - frame:GetRight()
		else
			offsetx = GetScreenWidth() / 2 - frame:GetLeft()
		end
		local point, parent, relativePoint, x, y = frame:GetPoint(1)
		frame:SetPoint(point, parent, relativePoint, (x or 0) + offsetx, y or 0)
	end
end

local function CheckSize(self, level)
	if not level.buttons then
		return
	end
	local height = 20
	for _, button in ipairs(level.buttons) do
		height = height + button:GetHeight()
	end
	level:SetHeight(height)
	local width = 160
	for _, button in ipairs(level.buttons) do
		local extra = 1
		if button.hasArrow or button.hasColorSwatch then
			extra = extra + 16
		end
		if not button.notCheckable then
			extra = extra + 24
		end
		button.text:SetFont(STANDARD_TEXT_FONT, button.textHeight)
		if button.text:GetWidth() + extra > width then
			width = button.text:GetWidth() + extra
		end
	end
	level:SetWidth(width + 20)
	if level:GetLeft() and level:GetRight() and level:GetTop() and level:GetBottom() and (level:GetLeft() < 0 or level:GetRight() > GetScreenWidth() or level:GetTop() > GetScreenHeight() or level:GetBottom() < 0) then
		level:ClearAllPoints()
		if level.lastDirection == "RIGHT" then
			if level.lastVDirection == "DOWN" then
				level:SetPoint("TOPLEFT", level.parent or level:GetParent(), "TOPRIGHT", 5, 10)
			else
				level:SetPoint("BOTTOMLEFT", level.parent or level:GetParent(), "BOTTOMRIGHT", 5, -10)
			end
		else
			if level.lastVDirection == "DOWN" then
				level:SetPoint("TOPRIGHT", level.parent or level:GetParent(), "TOPLEFT", -5, 10)
			else
				level:SetPoint("BOTTOMRIGHT", level.parent or level:GetParent(), "BOTTOMLEFT", -5, -10)
			end
		end
	end
	local dirty = false
	if not level:GetRight() then
		self:Close()
		return
	end
	if level:GetRight() > GetScreenWidth() and level.lastDirection == "RIGHT" then
		level.lastDirection = "LEFT"
		dirty = true
	elseif level:GetLeft() < 0 and level.lastDirection == "LEFT" then
		level.lastDirection = "RIGHT"
		dirty = true
	end
	if level:GetTop() > GetScreenHeight() and level.lastVDirection == "UP" then
		level.lastVDirection = "DOWN"
		dirty = true
	elseif level:GetBottom() < 0 and level.lastVDirection == "DOWN" then
		level.lastVDirection = "UP"
		dirty = true
	end
	if dirty then
		level:ClearAllPoints()
		if level.lastDirection == "RIGHT" then
			if level.lastVDirection == "DOWN" then
				level:SetPoint("TOPLEFT", level.parent or level:GetParent(), "TOPRIGHT", 5, 10)
			else
				level:SetPoint("BOTTOMLEFT", level.parent or level:GetParent(), "BOTTOMRIGHT", 5, -10)
			end
		else
			if level.lastVDirection == "DOWN" then
				level:SetPoint("TOPRIGHT", level.parent or level:GetParent(), "TOPLEFT", -5, 10)
			else
				level:SetPoint("BOTTOMRIGHT", level.parent or level:GetParent(), "BOTTOMLEFT", -5, -10)
			end
		end
	end
	if level:GetTop() > GetScreenHeight() then
		local top = level:GetTop()
		local point, parent, relativePoint, x, y = level:GetPoint(1)
		level:ClearAllPoints()
		level:SetPoint(point, parent, relativePoint, x or 0, (y or 0) + GetScreenHeight() - top)
	elseif level:GetBottom() < 0 then
		local bottom = level:GetBottom()
		local point, parent, relativePoint, x, y = level:GetPoint(1)
		level:ClearAllPoints()
		level:SetPoint(point, parent, relativePoint, x or 0, (y or 0) - bottom)
	end
	CheckDualMonitor(self, level)
	if mod(level.num, 5) == 0 then
		local left, bottom = level:GetLeft(), level:GetBottom()
		level:ClearAllPoints()
		level:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	end
end

local Open
local OpenSlider
local OpenEditBox
local Refresh
local Clear
local function ReleaseButton(self, level, index)
	if not level.buttons then
		return
	end
	if not level.buttons[index] then
		return
	end
	local button = level.buttons[index]
	button:Hide()
	if button.highlight then
		button.highlight:Hide()
	end
--	button.arrow:SetVertexColor(1, 1, 1)
	button.arrow:SetHeight(16)
	button.arrow:SetWidth(16)
	table.remove(level.buttons, index)
	table.insert(buttons, button)
	for k in pairs(button) do
		if k ~= 0 and k ~= "text" and k ~= "check" and k ~= "arrow" and k ~= "colorSwatch" and k ~= "highlight" and k ~= "radioHighlight" then
			button[k] = nil
		end
	end
	return true
end

local function Scroll(self, level, down)
	if down then
		if level:GetBottom() < 0 then
			local point, parent, relativePoint, x, y = level:GetPoint(1)
			level:SetPoint(point, parent, relativePoint, x, y + 50)
			if level:GetBottom() > 0 then
				level:SetPoint(point, parent, relativePoint, x, y + 50 - level:GetBottom())
			end
		end
	else
		if level:GetTop() > GetScreenHeight() then
			local point, parent, relativePoint, x, y = level:GetPoint(1)
			level:SetPoint(point, parent, relativePoint, x, y - 50)
			if level:GetTop() < GetScreenHeight() then
				level:SetPoint(point, parent, relativePoint, x, y - 50 + GetScreenHeight() - level:GetTop())
			end
		end
	end
end

local sliderFrame
local editBoxFrame

local function AcquireButton(self, level)
	if not levels[level] then
		return
	end
	level = levels[level]
	if not level.buttons then
		level.buttons = {}
	end
	local button
	if table.getn(buttons) == 0 then
		button = CreateFrame("Button")
		button:SetFrameStrata("FULLSCREEN_DIALOG")
		button:SetHeight(16)
		local highlight = button:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		button.highlight = highlight
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(button)
		highlight:Hide()
		local check = button:CreateTexture(nil, "ARTWORK")
		button.check = check
		check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		check:SetPoint("CENTER", button, "LEFT", 12, 0)
		check:SetWidth(24)
		check:SetHeight(24)
		local radioHighlight = button:CreateTexture(nil, "ARTWORK")
		button.radioHighlight = radioHighlight
		radioHighlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
		radioHighlight:SetAllPoints(check)
		radioHighlight:SetBlendMode("ADD")
		radioHighlight:SetTexCoord(0.5, 0.75, 0, 1)
		radioHighlight:Hide()
		button:SetScript("OnEnter", function()
			local this = this
			if (sliderFrame and sliderFrame:IsShown() and sliderFrame.mouseDown and sliderFrame.level == this.level.num + 1) or (editBoxFrame and editBoxFrame:IsShown() and editBoxFrame.mouseDown and editBoxFrame.level == this.level.num + 1) then
				for i = 1, this.level.num do
					Refresh(self, levels[i])
				end
				return
			end
			self:Close(this.level.num + 1)
			if not this.disabled then
				if this.hasSlider then
					OpenSlider(self, this)
				elseif this.hasEditBox then
					OpenEditBox(self, this)
				elseif this.hasArrow then
					Open(self, this, nil, this.level.num + 1, this.value)
				end
			end
			if not this.level then -- button reclaimed
				return
			end
			StopCounting(self, this.level.num + 1)
			if not this.disabled then
				highlight:Show()
				if this.isRadio then
					button.radioHighlight:Show()
				end
			end
			if this.tooltipTitle or this.tooltipText then
				GameTooltip_SetDefaultAnchor(GameTooltip, this)
				local disabled = not this.isTitle and this.disabled
				if this.tooltipTitle then
					if disabled then
						GameTooltip:SetText(this.tooltipTitle, 0.5, 0.5, 0.5, 1)
					else
						GameTooltip:SetText(this.tooltipTitle, 1, 1, 1, 1)
					end
					if this.tooltipText then
						if disabled then
							GameTooltip:AddLine(this.tooltipText, (NORMAL_FONT_COLOR.r + 0.5) / 2, (NORMAL_FONT_COLOR.g + 0.5) / 2, (NORMAL_FONT_COLOR.b + 0.5) / 2, 1)
						else
							GameTooltip:AddLine(this.tooltipText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
						end
					end
				else
					if disabled then
						GameTooltip:SetText(this.tooltipText, 0.5, 0.5, 0.5, 1)
					else
						GameTooltip:SetText(this.tooltipText, 1, 1, 1, 1)
					end
				end
				GameTooltip:Show()
			end
			if this.tooltipFunc then
				GameTooltip:SetOwner(this, "ANCHOR_NONE")
				GameTooltip:SetPoint("TOPLEFT", this, "TOPRIGHT", 5, 0)
				this.tooltipFunc(this.tooltipArg1, this.tooltipArg2, this.tooltipArg3, this.tooltipArg4)
				GameTooltip:Show()
			end
		end)
		button:SetScript("OnLeave", function()
			highlight:Hide()
			button.radioHighlight:Hide()
			if this.level then
				StartCounting(self, this.level.num)
			end
			GameTooltip:Hide()
		end)
		button:SetScript("OnClick", function()
			if not this.disabled then
				if this.hasColorSwatch then
					local func = button.colorFunc
					local a1,a2,a3,a4 = button.colorArg1, button.colorArg2, button.colorArg3, button.colorArg4
					local hasOpacity = this.hasOpacity
					ColorPickerFrame.func = function()
						if func then
							local r,g,b = ColorPickerFrame:GetColorRGB()
							local a = hasOpacity and 1 - OpacitySliderFrame:GetValue() or nil
							if a1 == nil then
								func(r, g, b, a)
							elseif a2 == nil then
								func(a1, r, g, b, a)
							elseif a3 == nil then
								func(a1, a2, r, g, b, a)
							elseif a4 == nil then
								func(a1, a2, a3, r, g, b, a)
							else
								func(a1, a2, a3, a4, r, g, b, a)
							end
						end
					end
					ColorPickerFrame.hasOpacity = this.hasOpacity
					ColorPickerFrame.opacityFunc = ColorPickerFrame.func
					ColorPickerFrame.opacity = 1 - this.opacity
					ColorPickerFrame:SetColorRGB(this.r, this.g, this.b)
					local r, g, b, a = this.r, this.g, this.b, this.opacity
					ColorPickerFrame.cancelFunc = function()
						if a1 == nil then
							func(r, g, b, a)
						elseif a2 == nil then
							func(a1, r, g, b, a)
						elseif a3 == nil then
							func(a1, a2, r, g, b, a)
						else
							func(a1, a2, a3, r, g, b, a)
						end
					end
					self:Close(1)
					ShowUIPanel(ColorPickerFrame)
				elseif this.func then
					local level = button.level
					if type(this.func) == "string" then
						self:assert(type(this.arg1[this.func]) == "function", "Cannot call method " .. this.func)
						this.arg1[this.func](this.arg1, this.arg2, this.arg3, this.arg4)
					else
						this.func(this.arg1, this.arg2, this.arg3, this.arg4)
					end
					if this.closeWhenClicked then
						self:Close()
					elseif level:IsShown() then
						for i = 1, level.num do
							Refresh(self, levels[i])
						end
					end
				elseif this.closeWhenClicked then
					self:Close()
				end
			end
		end)
		local text = button:CreateFontString(nil, "ARTWORK")
		button.text = text
		text:SetFontObject(GameFontHighlightSmall)
		button.text:SetFont(STANDARD_TEXT_FONT, UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT)
		button:SetScript("OnMouseDown", function()
			if not this.disabled and (this.func or this.colorFunc or this.closeWhenClicked) then
				text:SetPoint("LEFT", button, "LEFT", this.notCheckable and 1 or 25, -1)
			end
		end)
		button:SetScript("OnMouseUp", function()
			if not this.disabled and (this.func or this.colorFunc or this.closeWhenClicked) then
				text:SetPoint("LEFT", button, "LEFT", this.notCheckable and 0 or 24, 0)
			end
		end)
		local arrow = button:CreateTexture(nil, "ARTWORK")
		button.arrow = arrow
		arrow:SetPoint("LEFT", button, "RIGHT", -16, 0)
		arrow:SetWidth(16)
		arrow:SetHeight(16)
		arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
		local colorSwatch = button:CreateTexture(nil, "OVERLAY")
		button.colorSwatch = colorSwatch
		colorSwatch:SetWidth(20)
		colorSwatch:SetHeight(20)
		colorSwatch:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
		local texture = button:CreateTexture(nil, "OVERLAY")
		colorSwatch.texture = texture
		texture:SetTexture(1, 1, 1)
		texture:SetWidth(11.5)
		texture:SetHeight(11.5)
		texture:Show()
		texture:SetPoint("CENTER", colorSwatch, "CENTER")
		colorSwatch:SetPoint("RIGHT", button, "RIGHT", 0, 0)
	else
		button = buttons[table.getn(buttons)]
		table.remove(buttons, table.getn(buttons))
	end
	button:ClearAllPoints()
	button:SetParent(level)
	button:SetFrameStrata(level:GetFrameStrata())
	button:SetFrameLevel(level:GetFrameLevel() + 1)
	button:SetPoint("LEFT", level, "LEFT", 10, 0)
	button:SetPoint("RIGHT", level, "RIGHT", -10, 0)
	if table.getn(level.buttons) == 0 then
		button:SetPoint("TOP", level, "TOP", 0, -10)
	else
		button:SetPoint("TOP", level.buttons[table.getn(level.buttons)], "BOTTOM", 0, 0)
	end
	button.text:SetPoint("LEFT", button, "LEFT", 24, 0)
	button:Show()
	button.level = level
	table.insert(level.buttons, button)
	if not level.parented then
		level.parented = true
		level:ClearAllPoints()
		if level.num == 1 then
			if level.parent ~= UIParent then
				level:SetPoint("TOPRIGHT", level.parent, "TOPLEFT")
			else
				level:SetPoint("CENTER", level.parent, "CENTER")
			end
		else
			if level.lastDirection == "RIGHT" then
				if level.lastVDirection == "DOWN" then
					level:SetPoint("TOPLEFT", level.parent, "TOPRIGHT", 5, 10)
				else
					level:SetPoint("BOTTOMLEFT", level.parent, "BOTTOMRIGHT", 5, -10)
				end
			else
				if level.lastVDirection == "DOWN" then
					level:SetPoint("TOPRIGHT", level.parent, "TOPLEFT", -5, 10)
				else
					level:SetPoint("BOTTOMRIGHT", level.parent, "BOTTOMLEFT", -5, -10)
				end
			end
		end
		level:SetFrameStrata("FULLSCREEN_DIALOG")
	end
	return button
end

local function AcquireLevel(self, level)
	if not levels[level] then
		for i = table.getn(levels) + 1, level, -1 do
			local i = i
			local frame = CreateFrame("Button")
			if i == 1 then
				local old_CloseWindows = CloseWindows
				function CloseWindows(ignoreCenter)
					local found = old_CloseWindows(ignoreCenter)
					if levels[1]:IsShown() then
						self:Close()
						return 1
					end
					return found
				end
			end
			levels[i] = frame
			frame.num = i
			frame:SetParent(UIParent)
			frame:SetFrameStrata("FULLSCREEN_DIALOG")
			frame:Hide()
			frame:SetWidth(180)
			frame:SetHeight(10)
			frame:SetFrameLevel(i * 3)
			frame:SetScript("OnHide", function()
				self:Close(level + 1)
			end)
			frame:SetFrameStrata("FULLSCREEN_DIALOG")
			if frame.SetTopLevel then
				frame:SetTopLevel(true)
			end
			frame:EnableMouse(true)
			frame:EnableMouseWheel(true)
			local backdrop = CreateFrame("Frame", nil, frame)
			backdrop:SetAllPoints(frame)
			backdrop:SetBackdrop(tmp(
				'bgFile', "Interface\\Tooltips\\UI-Tooltip-Background",
				'edgeFile', "Interface\\Tooltips\\UI-Tooltip-Border",
				'tile', true,
				'insets', tmp2(
					'left', 5,
					'right', 5,
					'top', 5,
					'bottom', 5
				),
				'tileSize', 16,
				'edgeSize', 16
			))
			backdrop:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
			backdrop:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
			frame:SetScript("OnClick", function()
				self:Close(i)
			end)
			frame:SetScript("OnEnter", function()
				StopCounting(self, i)
			end)
			frame:SetScript("OnLeave", function()
				StartCounting(self, i)
			end)
			frame:SetScript("OnMouseWheel", function()
				Scroll(self, frame, arg1 < 0)
			end)
			if i == 1 then
				frame:SetScript("OnUpdate", function()
					OnUpdate(self, arg1)
				end)
				levels[1].lastDirection = "RIGHT"
				levels[1].lastVDirection = "DOWN"
			else
				levels[i].lastDirection = levels[i - 1].lastDirection
				levels[i].lastVDirection = levels[i - 1].lastVDirection
			end
		end
	end
	return levels[level]
end

local function checkValidate(validateFunc, func, arg1, arg2, arg3)
	local text
	if arg3 ~= nil then
		text = arg3
	elseif arg2 ~= nil then
		text = arg2
	else
		text = arg1
	end
	if not validateFunc(text) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff7fValidation error: [|r" .. tostring(text) .. "|cffffff7f]|r")
	else
		func(arg1, arg2, arg3)
	end
end

local function validateOptions(options, position, baseOptions, fromPass)
	if not baseOptions then
		baseOptions = options
	end
	if type(options) ~= "table" then
		return "Options must be a table.", position
	end
	local kind = options.type
	if type(kind) ~= "string" then
		return '"type" must be a string.', position
	elseif kind ~= "group" and kind ~= "range" and kind ~= "text" and kind ~= "execute" and kind ~= "toggle" and kind ~= "color" and kind ~= "header" then
		return '"type" must either be "range", "text", "group", "toggle", "execute", "color", or "header".', position
	end
	if options.aliases then
		if type(options.aliases) ~= "table" and type(options.aliases) ~= "string" then
			return '"alias" must be a table or string', position
		end
	end
	if not fromPass then
		if kind == "execute" then
			if type(options.func) ~= "string" and type(options.func) ~= "function" then
				return '"func" must be a string or function', position
			end
		elseif kind == "range" or kind == "text" or kind == "toggle" then
			if type(options.set) ~= "string" and type(options.set) ~= "function" then
				return '"set" must be a string or function', position
			end
			if kind == "text" and options.get == false then
			elseif type(options.get) ~= "string" and type(options.get) ~= "function" then
				return '"get" must be a string or function', position
			end
		elseif kind == "group" and options.pass then
			if options.pass ~= true then
				return '"pass" must be either nil, true, or false', position
			end
			if not options.func then
				if type(options.set) ~= "string" and type(options.set) ~= "function" then
					return '"set" must be a string or function', position
				end
				if type(options.get) ~= "string" and type(options.get) ~= "function" then
					return '"get" must be a string or function', position
				end
			elseif type(options.func) ~= "string" and type(options.func) ~= "function" then
				return '"func" must be a string or function', position
			end
		end
	else
		if kind == "group" then
			return 'cannot have "type" = "group" as a subgroup of a passing group', position
		end
	end
	if options ~= baseOptions then
		if kind == "header" then
		elseif type(options.desc) ~= "string" then
			return '"desc" must be a string', position
		elseif string.len(options.desc) == 0 then
			return '"desc" cannot be a 0-length string', position
		end
	end
	if options ~= baseOptions or kind == "range" or kind == "text" or kind == "toggle" or kind == "color" then
		if options.type == "header" and not options.cmdName and not options.name then
		elseif options.cmdName then
			if type(options.cmdName) ~= "string" then
				return '"cmdName" must be a string or nil', position
			elseif string.len(options.cmdName) == 0 then
				return '"cmdName" cannot be a 0-length string', position
			end
			if type(options.guiName) ~= "string" then
				if not options.guiNameIsMap then
					return '"guiName" must be a string or nil', position
				end
			elseif string.len(options.guiName) == 0 then
				return '"guiName" cannot be a 0-length string', position
			end
		else
			if type(options.name) ~= "string" then
				return '"name" must be a string', position
			elseif string.len(options.name) == 0 then
				return '"name" cannot be a 0-length string', position
			end
		end
	end
	if options.guiNameIsMap then
		if type(options.guiNameIsMap) ~= "boolean" then
			return '"guiNameIsMap" must be a boolean or nil', position
		elseif options.type ~= "toggle" then
			return 'if "guiNameIsMap" is true, then "type" must be set to \'toggle\'', position
		elseif type(options.map) ~= "table" then
			return '"map" must be a table', position
		end
	end
	if options.message and type(options.message) ~= "string" then
		return '"message" must be a string or nil', position
	end
	if options.error and type(options.error) ~= "string" then
		return '"error" must be a string or nil', position
	end
	if options.current and type(options.current) ~= "string" then
		return '"current" must be a string or nil', position
	end
	if options.order then
		if type(options.order) ~= "number" or (-1 < options.order and options.order < 0.999) then
			return '"order" must be a non-zero number or nil', position
		end
	end
	if options.disabled then
		if type(options.disabled) ~= "function" and type(options.disabled) ~= "string" and options.disabled ~= true then
			return '"disabled" must be a function, string, or boolean', position
		end
	end
	if options.cmdHidden then
		if type(options.cmdHidden) ~= "function" and type(options.cmdHidden) ~= "string" and options.cmdHidden ~= true then
			return '"cmdHidden" must be a function, string, or boolean', position
		end
	end
	if options.guiHidden then
		if type(options.guiHidden) ~= "function" and type(options.guiHidden) ~= "string" and options.guiHidden ~= true then
			return '"guiHidden" must be a function, string, or boolean', position
		end
	end
	if options.hidden then
		if type(options.hidden) ~= "function" and type(options.hidden) ~= "string" and options.hidden ~= true then
			return '"hidden" must be a function, string, or boolean', position
		end
	end
	if kind == "text" then
		if type(options.validate) == "table" then
			local t = options.validate
			local iTable = nil
			for k,v in pairs(t) do
				if type(k) == "number" then
					if iTable == nil then
						iTable = true
					elseif not iTable then
						return '"validate" must either have all keys be indexed numbers or strings', position
					elseif k < 1 or k > table.getn(t) then
						return '"validate" numeric keys must be indexed properly. >= 1 and <= table.getn', position
					end
				else
					if iTable == nil then
						iTable = false
					elseif iTable then
						return '"validate" must either have all keys be indexed numbers or strings', position
					end
				end
				if type(v) ~= "string" then
					return '"validate" values must all be strings', position
				end
			end
		else
			if type(options.usage) ~= "string" then
				return '"usage" must be a string', position
			elseif options.validate and type(options.validate) ~= "string" and type(options.validate) ~= "function" then
				return '"validate" must be a string, function, or table', position
			end
		end
	elseif kind == "range" then
		if options.min or options.max then
			if type(options.min) ~= "number" then
				return '"min" must be a number', position
			elseif type(options.max) ~= "number" then
				return '"max" must be a number', position
			elseif options.min >= options.max then
				return '"min" must be less than "max"', position
			end
		end
		if options.step then
			if type(options.step) ~= "number" then
				return '"step" must be a number', position
			elseif options.step < 0 then
				return '"step" must be nonnegative', position
			end
		end
		if options.isPercent and options.isPercent ~= true then
			return '"isPercent" must either be nil, true, or false', position
		end
	elseif kind == "toggle" then
		if options.map then
			if type(options.map) ~= "table" then
				return '"map" must be a table', position
			elseif type(options.map[true]) ~= "string" then
				return '"map[true]" must be a string', position
			elseif type(options.map[false]) ~= "string" then
				return '"map[false]" must be a string', position
			end
		end
	elseif kind == "color" then
		if options.hasAlpha and options.hasAlpha ~= true then
			return '"hasAlpha" must be nil, true, or false', position
		end
	elseif kind == "group" then
		if options.pass and options.pass ~= true then
			return '"pass" must be nil, true, or false', position
		end
		if type(options.args) ~= "table" then
			return '"args" must be a table', position
		end
		for k,v in pairs(options.args) do
			if type(k) ~= "string" then
				return '"args" keys must be strings', position
			elseif string.find(k, "%s") then
				return string.format('"args" keys must not include spaces. %q is not appropriate.', k), position
			elseif string.len(k) == 0 then
				return '"args" keys must not be 0-length strings.', position
			end
			if type(v) ~= "table" then
				return '"args" values must be tables', position and position .. "." .. k or k
			end
			local newposition
			if position then
				newposition = position .. ".args." .. k
			else
				newposition = "args." .. k
			end
			local err, pos = validateOptions(v, newposition, baseOptions, options.pass)
			if err then
				return err, pos
			end
		end
	end
	if options.icon and type(options.icon) ~= "string" then
		return'"icon" must be a string', position
	end
	if options.iconWidth or options.iconHeight then
		if (options.iconWidth and type(options.iconWidth) ~= "number") or (options.iconHeight and type(options.iconHeight) ~= "number") then
			return '"iconHeight" and "iconWidth" must be numbers', position
		end
	end
end

local validatedOptions

local values
local mysort_args
local mysort
local othersort
local othersort_validate

local baseFunc, currentLevel

function Dewdrop:FeedAceOptionsTable(options, difference)
	self:argCheck(options, 2, "table")
	self:argCheck(difference, 3, "nil", "number")
	self:assert(currentLevel, "Cannot call `FeedAceOptionsTable' outside of a Dewdrop declaration")
	if not difference then
		difference = 0
	end
	if not validatedOptions then
		validatedOptions = {}
	end
	if not validatedOptions[options] then
		local err, position = validateOptions(options)
		
		if err then
			if position then
				Dewdrop:error(position .. ": " .. err)
			else
				Dewdrop:error(err)
			end
		end
		
		validatedOptions[options] = true
	end
	local level = levels[currentLevel]
	self:assert(level, "Improper level given")
	if not values then
		values = {}
	else
		for k,v in pairs(values) do
			values[k] = nil
		end
		table_setn(values, 0)
	end
	
	local current = level
	while current do
		if current.num == difference + 1 then
			break
		end
		table.insert(values, current.value)
		current = levels[current.num - 1]
	end
	
	local realOptions = options
	local handler = options.handler
	local passTable
	local passValue
	while table.getn(values) > 0 do
		passTable = options.pass and current or nil
		local value = table.remove(values)
		options = options.args and options.args[value]
		if not options then
			return
		end
		handler = options.handler or handler
		passValue = passTable and value or nil
	end
	
	if options.type == "group" then
		for k in pairs(options.args) do
			table.insert(values, k)
		end
		if not mysort then
			mysort = function(a, b)
				local alpha, bravo = mysort_args[a], mysort_args[b]
				local alpha_order = alpha.order or 100
				local bravo_order = bravo.order or 100
				local alpha_name = alpha.guiName or alpha.name
				local bravo_name = bravo.guiName or bravo.name
				if alpha_order == bravo_order then
					if not alpha_name then
						return true
					elseif not bravo_name then
						return false
					else
						return string.upper(alpha_name) < string.upper(bravo_name)
					end
				else
					if alpha_order < 0 then
						if bravo_order > 0 then
							return false
						end
					else
						if bravo_order < 0 then
							return true
						end
					end
					return alpha_order < bravo_order
				end
			end
		end
		mysort_args = options.args
		table.sort(values, mysort)
		mysort_args = nil
		local hasBoth = table.getn(values) >= 1 and (options.args[values[1]].order or 100) > 0 and (options.args[values[table.getn(values)]].order or 100) < 0
		local last_order = 1
		for _,k in ipairs(values) do
			local v = options.args[k]
			local handler = v.handler or handler
			if hasBoth and last_order > 0 and (v.order or 100) < 0 then
				hasBoth = false
				self:AddLine()
			end
			local hidden, disabled = v.guiHidden or v.hidden, v.disabled
			if type(hidden) == "function" then
				hidden = hidden()
			elseif type(hidden) == "string" then
				hidden = handler[hidden](handler)
			end
			if not hidden then
				if type(disabled) == "function" then
					disabled = disabled()
				elseif type(disabled) == "string" then
					disabled = handler[disabled](handler)
				end
				local name = (v.guiIconOnly and v.icon) and "" or (v.guiName or v.name)
				local desc = v.desc
				local iconHeight = v.iconHeight or 16
				local iconWidth = v.iconWidth or 16
				local tooltipTitle, tooltipText
				tooltipTitle = name
				if name ~= desc then
					tooltipText = desc
				end
				if v.type == "toggle" then
					local checked
					if type(v.get) == "function" then
						checked = v.get(passValue)
					else
						if not handler[v.get] then
							Dewdrop:error("Handler %q not available", v.get)
						end
						checked = handler[v.get](handler, passValue)
					end
					local func, arg1, arg2, arg3
					if type(v.set) == "function" then
						func = v.set
						if passValue ~= nil then
							arg1 = passValue
							arg2 = not checked
						else
							arg1 = not checked
						end
					else
						if not handler[v.set] then
							Dewdrop:error("Handler %q not available", v.set)
						end
						func = handler[v.set]
						arg1 = handler
						if passValue ~= nil then
							arg2 = passValue
							arg3 = not checked
						else
							arg2 = not checked
						end
					end
					if v.guiNameIsMap then
						checked = checked and true or false
						name = string.gsub(tostring(v.map and v.map[checked]), "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
						checked = nil
					end
					self:AddLine(
						'text', name,
						'checked', checked,
						'isRadio', v.isRadio,
						'func', func,
						'arg1', arg1,
						'arg2', arg2,
						'arg3', arg3,
						'disabled', disabled,
						'tooltipTitle', tooltipTitle,
						'tooltipText', tooltipText
					)
				elseif v.type == "execute" then
					local func, arg1, arg2
					if type(v.func) == "function" then
						func = v.func
						arg1 = passValue
					else
						if not handler[v.func] then
							Dewdrop:error("Handler %q not available", v.func)
						end
						func = handler[v.func]
						arg1 = handler
						arg2 = passValue
					end
					self:AddLine(
						'text', name,
						'checked', checked,
						'func', func,
						'arg1', arg1,
						'arg2', arg2,
						'disabled', disabled,
						'tooltipTitle', tooltipTitle,
						'tooltipText', tooltipText,
						'icon', v.icon,
						'iconHeight', iconHeight,
						'iconWidth', iconWidth
					)
				elseif v.type == "range" then
					local sliderValue
					if type(v.get) == "function" then
						sliderValue = v.get(passValue)
					else
						if not handler[v.get] then
							Dewdrop:error("Handler %q not available", v.get)
						end
						sliderValue = handler[v.get](handler, passValue)
					end
					local sliderFunc, sliderArg1, sliderArg2
					if type(v.set) == "function" then
						sliderFunc = v.set
						sliderArg1 = passValue
					else
						if not handler[v.set] then
							Dewdrop:error("Handler %q not available", v.set)
						end
						sliderFunc = handler[v.set]
						sliderArg1 = handler
						sliderArg2 = passValue
					end
					self:AddLine(
						'text', name,
						'hasArrow', true,
						'hasSlider', true,
						'sliderMin', v.min or 0,
						'sliderMax', v.max or 1,
						'sliderStep', v.step or 0,
						'sliderIsPercent', v.isPercent or false,
						'sliderValue', sliderValue,
						'sliderFunc', sliderFunc,
						'sliderArg1', sliderArg1,
						'sliderArg2', sliderArg2,
						'disabled', disabled,
						'tooltipTitle', tooltipTitle,
						'tooltipText', tooltipText,
						'icon', v.icon,
						'iconHeight', iconHeight,
						'iconWidth', iconWidth
					)
				elseif v.type == "color" then
					local r,g,b,a
					if type(v.get) == "function" then
						r,g,b,a = v.get(passValue)
					else
						if not handler[v.get] then
							Dewdrop:error("Handler %q not available", v.get)
						end
						r,g,b,a = handler[v.get](handler, passValue)
					end
					local colorFunc, colorArg1, colorArg2
					if type(v.set) == "function" then
						colorFunc = v.set
						colorArg1 = passValue
					else
						if not handler[v.set] then
							Dewdrop:error("Handler %q not available", v.set)
						end
						colorFunc = handler[v.set]
						colorArg1 = handler
						colorArg2 = passValue
					end
					self:AddLine(
						'text', name,
						'hasArrow', true,
						'hasColorSwatch', true,
						'r', r,
						'g', g,
						'b', b,
						'opacity', v.hasAlpha and a or nil,
						'hasOpacity', v.hasAlpha,
						'colorFunc', colorFunc,
						'colorArg1', colorArg1,
						'colorArg2', colorArg2,
						'disabled', disabled,
						'tooltipTitle', tooltipTitle,
						'tooltipText', tooltipText
					)
				elseif v.type == "text" then
					if type(v.validate) == "table" then
						self:AddLine(
							'text', name,
							'hasArrow', true,
							'value', k,
							'disabled', disabled,
							'tooltipTitle', tooltipTitle,
							'tooltipText', tooltipText,
							'icon', v.icon,
							'iconHeight', iconHeight,
							'iconWidth', iconWidth
						)
					else
						local editBoxText
						if type(v.get) == "function" then
							editBoxText = v.get(passValue)
						elseif v.get == false then
							editBoxText = nil
						else
							if not handler[v.get] then
								Dewdrop:error("Handler %q not available", v.get)
							end
							editBoxText = handler[v.get](handler, passValue)
						end
						local editBoxFunc, editBoxArg1, editBoxArg2
						if type(v.set) == "function" then
							editBoxFunc = v.set
							editBoxArg1 = passValue
						else
							if not handler[v.set] then
								Dewdrop:error("Handler %q not available", v.set)
							end
							editBoxFunc = handler[v.set]
							editBoxArg1 = handler
							editBoxArg2 = passValue
						end
						
						local editBoxValidateFunc, editBoxValidateArg1
						
						if v.validate then
							if type(v.validate) == "function" then
								editBoxValidateFunc = v.validate
							else
								if not handler[v.validate] then
									Dewdrop:error("Handler %q not available", v.validate)
								end
								editBoxValidateFunc = handler[v.validate]
								editBoxValidateArg1 = handler
							end
						end
						
						self:AddLine(
							'text', name,
							'hasArrow', true,
							'icon', v.icon,
							'iconHeight', iconHeight,
							'iconWidth', iconWidth,
							'hasEditBox', true,
							'editBoxText', editBoxText,
							'editBoxFunc', editBoxFunc,
							'editBoxArg1', editBoxArg1,
							'editBoxArg2', editBoxArg2,
							'editBoxValidateFunc', editBoxValidateFunc,
							'editBoxValidateArg1', editBoxValidateArg1,
							'disabled', disabled,
							'tooltipTitle', tooltipTitle,
							'tooltipText', tooltipText
						)
					end
				elseif v.type == "group" then
					self:AddLine(
						'text', name,
						'hasArrow', true,
						'value', k,
						'disabled', disabled,
						'tooltipTitle', tooltipTitle,
						'tooltipText', tooltipText,
						'icon', v.icon,
						'iconHeight', iconHeight,
						'iconWidth', iconWidth
					)
				elseif v.type == "header" then
					if name == "" or not name then
						self:AddLine(
							'isTitle', true,
							'icon', v.icon,
							'iconHeight', iconHeight,
							'iconWidth', iconWidth
						)
					else
						self:AddLine(
							'text', name,
							'isTitle', true,
							'icon', v.icon,
							'iconHeight', iconHeight,
							'iconWidth', iconWidth
						)
					end
				end
			end
			last_order = v.order or 100
		end
	elseif options.type == "text" and type(options.validate) == "table" then
		local current
		if type(options.get) == "function" then
			current = options.get(passValue)
		else
			if not handler[options.get] then
				Dewdrop:error("Handler %q not available", options.get)
			end
			current = handler[options.get](handler, passValue)
		end
		local indexed = true
		for k,v in pairs(options.validate) do
			if type(k) ~= "number" then
				indexed = false
			end
			table.insert(values, k)
		end
		if not indexed then
			if not othersort then
				othersort = function(alpha, bravo)
					return othersort_validate[alpha] < othersort_validate[bravo]
				end
			end
			othersort_validate = options.validate
			table.sort(values, othersort)
			othersort_validate = nil
		end
		for _,k in ipairs(values) do
			local v = options.validate[k]
			if type(k) == "number" then
				k = v
			end
			local func, arg1, arg2
			if type(options.set) == "function" then
				func = options.set
				if passValue ~= nil then
					arg1 = passValue
					arg2 = k
				else
					arg1 = k
				end
			else
				if not handler[options.set] then
					Dewdrop:error("Handler %q not available", options.set)
				end
				func = handler[options.set]
				arg1 = handler
				if passValue ~= nil then
					arg2 = passValue
					arg3 = k
				else
					arg2 = k
				end
			end
			local checked = (k == current or (type(k) == "string" and type(current) == "string" and string.lower(k) == string.lower(current)))
			self:AddLine(
				'text', v,
				'func', not checked and func or nil,
				'arg1', not checked and arg1 or nil,
				'arg2', not checked and arg2 or nil,
				'arg3', not checked and arg3 or nil,
				'isRadio', true,
				'checked',  checked,
				'tooltipTitle', options.guiName or options.name,
				'tooltipText', v
			)
		end
		for k in pairs(values) do
			values[k] = nil
		end
		table_setn(values, 0)
	else
		return false
	end
	return true
end

function Refresh(self, level)
	if type(level) == "number" then
		level = levels[level]
	end
	if not level then
		return
	end
	if baseFunc then
		Clear(self, level)
		currentLevel = level.num
		if type(baseFunc) == "table" then
			if currentLevel == 1 then
				local handler = baseFunc.handler
				if handler then
					local name = tostring(handler)
					if not string.find(name, '^table:') then
						name = string.gsub(name, "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
						self:AddLine(
							'text', name,
							'isTitle', true
						)
					end
				end
--			elseif level.parentText then
--				self:AddLine(
--					'text', level.parentText,
--					'tooltipTitle', level.parentTooltipTitle,
--					'tooltipText', level.parentTooltipText,
--					'tooltipFunc', level.parentTooltipFunc,
--					'isTitle', true
--				)
			end
			self:FeedAceOptionsTable(baseFunc)
			if currentLevel == 1 then
				self:AddLine(
					'text', CLOSE,
					'closeWhenClicked', true
				)
			end
		else
--			if level.parentText then
--				self:AddLine(
--					'text', level.parentText,
--					'tooltipTitle', level.parentTooltipTitle,
--					'tooltipText', level.parentTooltipText,
--					'tooltipFunc', level.parentTooltipFunc,
--					'isTitle', true
--				)
--			end
			baseFunc(currentLevel, level.value, levels[level.num - 1] and levels[level.num - 1].value, levels[level.num - 2] and levels[level.num - 2].value, levels[level.num - 3] and levels[level.num - 3].value, levels[level.num - 4] and levels[level.num - 4].value)
		end
		currentLevel = nil
		CheckSize(self, level)
	end
end

function Dewdrop:Refresh(level)
	self:argCheck(level, 2, "number")
	Refresh(self, levels[level])
end

function OpenSlider(self, parent)
	if not sliderFrame then
		sliderFrame = CreateFrame("Frame", nil, UIParent)
		sliderFrame:SetWidth(80)
		sliderFrame:SetHeight(170)
		sliderFrame:SetBackdrop(tmp(
			'bgFile', "Interface\\Tooltips\\UI-Tooltip-Background",
			'edgeFile', "Interface\\Tooltips\\UI-Tooltip-Border",
			'tile', true,
			'insets', tmp2(
				'left', 5,
				'right', 5,
				'top', 5,
				'bottom', 5
			),
			'tileSize', 16,
			'edgeSize', 16
		))
		sliderFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		if sliderFrame.SetTopLevel then
			sliderFrame:SetTopLevel(true)
		end
		sliderFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		sliderFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
		sliderFrame:EnableMouse(true)
		sliderFrame:Hide()
		sliderFrame:SetPoint("CENTER", UIParent, "CENTER")
		local slider = CreateFrame("Slider", nil, sliderFrame)
		sliderFrame.slider = slider
		slider:SetOrientation("VERTICAL")
		slider:SetMinMaxValues(0, 1)
		slider:SetValueStep(0.01)
		slider:SetValue(0.5)
		slider:SetWidth(16)
		slider:SetHeight(128)
		slider:SetPoint("LEFT", sliderFrame, "LEFT", 15, 0)
		slider:SetBackdrop(tmp(
			'bgFile', "Interface\\Buttons\\UI-SliderBar-Background",
			'edgeFile', "Interface\\Buttons\\UI-SliderBar-Border",
			'tile', true,
			'edgeSize', 8,
			'tileSize', 8,
			'insets', tmp2(
				'left', 3,
				'right', 3,
				'top', 3,
				'bottom', 3
			)
		))
		local texture = slider:CreateTexture()
		slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
		local text = slider:CreateFontString(nil, "ARTWORK")
		sliderFrame.topText = text
		text:SetFontObject(GameFontGreenSmall)
		text:SetText("100%")
		text:SetPoint("BOTTOM", slider, "TOP")
		local text = slider:CreateFontString(nil, "ARTWORK")
		sliderFrame.bottomText = text
		text:SetFontObject(GameFontGreenSmall)
		text:SetText("0%")
		text:SetPoint("TOP", slider, "BOTTOM")
		local text = slider:CreateFontString(nil, "ARTWORK")
		sliderFrame.currentText = text
		text:SetFontObject(GameFontHighlightSmall)
		text:SetText("50%")
		text:SetPoint("LEFT", slider, "RIGHT")
		text:SetPoint("RIGHT", sliderFrame, "RIGHT", -6, 0)
		text:SetJustifyH("CENTER")
		local changed = false
		local inside = false
		slider:SetScript("OnValueChanged", function()
			if sliderFrame.changing then
				return
			end
			changed = true
			local done = false
			if sliderFrame.parent then
				if sliderFrame.parent.sliderFunc then
					local min = sliderFrame.parent.sliderMin or 0
					local max = sliderFrame.parent.sliderMax or 1
					local step = sliderFrame.parent.sliderStep or (max - min) / 100
					local a1,a2,a3,a4 = sliderFrame.parent.sliderArg1, sliderFrame.parent.sliderArg2, sliderFrame.parent.sliderArg3, sliderFrame.parent.sliderArg4
					local value = (1 - slider:GetValue()) * (max - min) + min
					if step > 0 then
						value = math.floor((value - min) / step + 0.5) * step + min
						if value > max then
							value = max
						elseif value < min then
							value = min
						end
					end
					local text
					if a1 == nil then
						text = sliderFrame.parent.sliderFunc(value)
					elseif a2 == nil then
						text = sliderFrame.parent.sliderFunc(a1, value)
					elseif a3 == nil then
						text = sliderFrame.parent.sliderFunc(a1, a2, value)
					elseif a4 == nil then
						text = sliderFrame.parent.sliderFunc(a1, a2, a3, value)
					else
						text = sliderFrame.parent.sliderFunc(a1, a2, a3, a4, value)
					end
					if text then
						sliderFrame.currentText:SetText(text)
						done = true
					end
				end
			end
			if not done then
				local min = sliderFrame.parent.sliderMin or 0
				local max = sliderFrame.parent.sliderMax or 1
				local step = sliderFrame.parent.sliderStep or (max - min) / 100
				local value = (1 - slider:GetValue()) * (max - min) + min
				if step > 0 then
					value = math.floor((value - min) / step + 0.5) * step + min
					if value > max then
						value = max
					elseif value < min then
						value = min
					end
				end
				if sliderFrame.parent.sliderIsPercent then
					sliderFrame.currentText:SetText(string.format("%.0f%%", value * 100))
				else
					if step < 0.1 then
						sliderFrame.currentText:SetText(string.format("%.2f", value))
					elseif step < 1 then
						sliderFrame.currentText:SetText(string.format("%.1f", value))
					else
						sliderFrame.currentText:SetText(string.format("%.0f", value))
					end
				end
			end
		end)
		sliderFrame:SetScript("OnEnter", function()
			StopCounting(self, sliderFrame.level)
		end)
		sliderFrame:SetScript("OnLeave", function()
			StartCounting(self, sliderFrame.level)
		end)
		slider:SetScript("OnMouseDown", function()
			sliderFrame.mouseDown = true
		end)
		slider:SetScript("OnMouseUp", function()
			sliderFrame.mouseDown = false
			if changed and not inside then
				local parent = sliderFrame.parent
				for i = 1, sliderFrame.level - 1 do
					Refresh(self, levels[i])
				end
				OpenSlider(self, parent)
			end
		end)
		slider:SetScript("OnEnter", function()
			inside = true
			StopCounting(self, sliderFrame.level)
		end)
		slider:SetScript("OnLeave", function()
			inside = false
			StartCounting(self, sliderFrame.level)
			if changed and not sliderFrame.mouseDown then
				local parent = sliderFrame.parent
				for i = 1, sliderFrame.level - 1 do
					Refresh(self, levels[i])
				end
				OpenSlider(self, parent)
			end
		end)
	end
	sliderFrame.parent = parent
	sliderFrame.level = parent.level.num + 1
	sliderFrame.parentValue = parent.level.value
	sliderFrame:SetFrameLevel(parent.level:GetFrameLevel() + 3)
	sliderFrame.slider:SetFrameLevel(sliderFrame:GetFrameLevel() + 1)
	sliderFrame.changing = true
	if not parent.sliderMin or not parent.sliderMax then
		return
	end
	
	if parent.arrow then
--		parent.arrow:SetVertexColor(0.2, 0.6, 0)
		parent.arrow:SetHeight(24)
		parent.arrow:SetWidth(24)
	end
	
	if not parent.sliderValue then
		parent.sliderValue = (parent.sliderMin + parent.sliderMax) / 2
	end
	sliderFrame.slider:SetValue(1 - (parent.sliderValue - parent.sliderMin) / (parent.sliderMax - parent.sliderMin))
	sliderFrame.changing = false
	sliderFrame.bottomText:SetText(parent.sliderMinText or "0")
	sliderFrame.topText:SetText(parent.sliderMaxText or "1")
	local text
	if parent.sliderFunc then
		local a1,a2,a3,a4 = parent.sliderArg1, parent.sliderArg2, parent.sliderArg3, parent.sliderArg4
		if a1 == nil then
			text = parent.sliderFunc(parent.sliderValue)
		elseif a2 == nil then
			text = parent.sliderFunc(a1, parent.sliderValue)
		elseif a3 == nil then
			text = parent.sliderFunc(a1, a2, parent.sliderValue)
		elseif a4 == nil then
			text = parent.sliderFunc(a1, a2, a3, parent.sliderValue)
		else
			text = parent.sliderFunc(a1, a2, a3, a4, parent.sliderValue)
		end
	end
	if text then
		sliderFrame.currentText:SetText(text)
	elseif parent.sliderIsPercent then
		sliderFrame.currentText:SetText(string.format("%.0f%%", parent.sliderValue * 100))
	else
		sliderFrame.currentText:SetText(parent.sliderValue)
	end
	
	local level = parent.level
	sliderFrame:Show()
	sliderFrame:ClearAllPoints()
	if level.lastDirection == "RIGHT" then
		if level.lastVDirection == "DOWN" then
			sliderFrame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 5, 10)
		else
			sliderFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 5, -10)
		end
	else
		if level.lastVDirection == "DOWN" then
			sliderFrame:SetPoint("TOPRIGHT", parent, "TOPLEFT", -5, 10)
		else
			sliderFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -5, -10)
		end
	end
	local dirty
	if level.lastDirection == "RIGHT" then
		if sliderFrame:GetRight() > GetScreenWidth() then
			level.lastDirection = "LEFT"
			dirty = true
		end
	elseif sliderFrame:GetLeft() < 0 then
		level.lastDirection = "RIGHT"
		dirty = true
	end
	if level.lastVDirection == "DOWN" then
		if sliderFrame:GetBottom() < 0 then
			level.lastVDirection = "UP"
			dirty = true
		end
	elseif sliderFrame:GetTop() > GetScreenWidth() then
		level.lastVDirection = "DOWN"
		dirty = true
	end
	if dirty then
		sliderFrame:ClearAllPoints()
		if level.lastDirection == "RIGHT" then
			if level.lastVDirection == "DOWN" then
				sliderFrame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 5, 10)
			else
				sliderFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 5, -10)
			end
		else
			if level.lastVDirection == "DOWN" then
				sliderFrame:SetPoint("TOPRIGHT", parent, "TOPLEFT", -5, 10)
			else
				sliderFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -5, -10)
			end
		end
	end
	local left, bottom = sliderFrame:GetLeft(), sliderFrame:GetBottom()
	sliderFrame:ClearAllPoints()
	sliderFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	if mod(level.num, 5) == 0 then
		local left, bottom = level:GetLeft(), level:GetBottom()
		level:ClearAllPoints()
		level:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	end
end

function OpenEditBox(self, parent)
	if not editBoxFrame then
		editBoxFrame = CreateFrame("Frame", nil, UIParent)
		editBoxFrame:SetWidth(200)
		editBoxFrame:SetHeight(40)
		editBoxFrame:SetBackdrop(tmp(
			'bgFile', "Interface\\Tooltips\\UI-Tooltip-Background",
			'edgeFile', "Interface\\Tooltips\\UI-Tooltip-Border",
			'tile', true,
			'insets', tmp2(
				'left', 5,
				'right', 5,
				'top', 5,
				'bottom', 5
			),
			'tileSize', 16,
			'edgeSize', 16
		))
		editBoxFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		if editBoxFrame.SetTopLevel then
			editBoxFrame:SetTopLevel(true)
		end
		editBoxFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		editBoxFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
		editBoxFrame:EnableMouse(true)
		editBoxFrame:Hide()
		editBoxFrame:SetPoint("CENTER", UIParent, "CENTER")
		
		local editBox = CreateFrame("EditBox", nil, editBoxFrame)
		editBoxFrame.editBox = editBox
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetWidth(160)
		editBox:SetHeight(13)
		editBox:SetPoint("CENTER", editBoxFrame, "CENTER", 0, 0)
		
		local left = editBox:CreateTexture(nil, "BACKGROUND")
		left:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Left")
		left:SetTexCoord(0, 100 / 256, 0, 1)
		left:SetWidth(100)
		left:SetHeight(32)
		left:SetPoint("LEFT", editBox, "LEFT", -10, 0)
		local right = editBox:CreateTexture(nil, "BACKGROUND")
		right:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-Right")
		right:SetTexCoord(156/256, 1, 0, 1)
		right:SetWidth(100)
		right:SetHeight(32)
		right:SetPoint("RIGHT", editBox, "RIGHT", 10, 0)
		
		editBox:SetScript("OnEnterPressed", function()
			if editBoxFrame.parent and editBoxFrame.parent.editBoxValidateFunc then
				local a1,a2,a3,a4 = editBoxFrame.parent.editBoxValidateArg1, editBoxFrame.parent.editBoxValidateArg2, editBoxFrame.parent.editBoxValidateArg3, editBoxFrame.parent.editBoxValidateArg4
				
				local result
				if a1 == nil then
					result = editBoxFrame.parent.editBoxValidateFunc(editBox:GetText() or "")
				elseif a2 == nil then
					result = editBoxFrame.parent.editBoxValidateFunc(a1, editBox:GetText() or "")
				elseif a3 == nil then
					result = editBoxFrame.parent.editBoxValidateFunc(a1, a2, editBox:GetText() or "")
				elseif a4 == nil then
					result = editBoxFrame.parent.editBoxValidateFunc(a1, a2, a3, editBox:GetText() or "")
				else
					result = editBoxFrame.parent.editBoxValidateFunc(a1, a2, a3, a4, editBox:GetText() or "")
				end
				if not result then
					message("Validation error: [" .. tostring(text) .. "]")
					return
				end
			end
			if editBoxFrame.parent and editBoxFrame.parent.editBoxFunc then
				local a1,a2,a3,a4 = editBoxFrame.parent.editBoxArg1, editBoxFrame.parent.editBoxArg2, editBoxFrame.parent.editBoxArg3, editBoxFrame.parent.editBoxArg4
				if a1 == nil then
					editBoxFrame.parent.editBoxFunc(editBox:GetText() or "")
				elseif a2 == nil then
					editBoxFrame.parent.editBoxFunc(a1, editBox:GetText() or "")
				elseif a3 == nil then
					editBoxFrame.parent.editBoxFunc(a1, a2, editBox:GetText() or "")
				elseif a4 == nil then
					editBoxFrame.parent.editBoxFunc(a1, a2, a3, editBox:GetText() or "")
				else
					editBoxFrame.parent.editBoxFunc(a1, a2, a3, a4, editBox:GetText() or "")
				end
			end
			self:Close(editBoxFrame.level)
			for i = 1, editBoxFrame.level - 1 do
				Refresh(self, levels[i])
			end
		end)
		editBox:SetScript("OnEscapePressed", function()
			self:Close(editBoxFrame.level)
		end)
		local changing = false
		local skipNext = false
		
		function editBox:SpecialSetText(text)
			local oldText = editBox:GetText() or ""
			if not text then
				text = ""
			end
			if text ~= oldText then
				changing = true
				self:SetText(text)
				changing = false
				skipNext = true
			end
		end
		
		editBox:SetScript("OnTextChanged", function()
			if skipNext then
				skipNext = false
			elseif not changing and editBoxFrame.parent and editBoxFrame.parent.editBoxChangeFunc then
				local a1,a2,a3,a4 = editBoxFrame.parent.editBoxChangeArg1, editBoxFrame.parent.editBoxChangeArg2, editBoxFrame.parent.editBoxChangeArg3, editBoxFrame.parent.editBoxChangeArg4
				local text
				if a1 == nil then
					text = editBoxFrame.parent.editBoxChangeFunc(editBox:GetText() or "")
				elseif a2 == nil then
					text = editBoxFrame.parent.editBoxChangeFunc(a1, editBox:GetText() or "")
				elseif a3 == nil then
					text = editBoxFrame.parent.editBoxChangeFunc(a1, a2, editBox:GetText() or "")
				elseif a4 == nil then
					text = editBoxFrame.parent.editBoxChangeFunc(a1, a2, a3, editBox:GetText() or "")
				else
					text = editBoxFrame.parent.editBoxChangeFunc(a1, a2, a3, a4, editBox:GetText() or "")
				end
				if text then
					editBox:SpecialSetText(text)
				end
			end
		end)
		editBoxFrame:SetScript("OnEnter", function()
			StopCounting(self, editBoxFrame.level)
		end)
		editBoxFrame:SetScript("OnLeave", function()
			StartCounting(self, editBoxFrame.level)
		end)
		editBox:SetScript("OnEnter", function()
			StopCounting(self, editBoxFrame.level)
		end)
		editBox:SetScript("OnLeave", function()
			StartCounting(self, editBoxFrame.level)
		end)
	end
	editBoxFrame.parent = parent
	editBoxFrame.level = parent.level.num + 1
	editBoxFrame.parentValue = parent.level.value
	editBoxFrame:SetFrameLevel(parent.level:GetFrameLevel() + 3)
	editBoxFrame.editBox:SetFrameLevel(editBoxFrame:GetFrameLevel() + 1)
	editBoxFrame.editBox:SpecialSetText(parent.editBoxText)
	
	if parent.arrow then
--		parent.arrow:SetVertexColor(0.2, 0.6, 0)
		parent.arrow:SetHeight(24)
		parent.arrow:SetWidth(24)
	end
	
	local level = parent.level
	editBoxFrame:Show()
	editBoxFrame:ClearAllPoints()
	if level.lastDirection == "RIGHT" then
		if level.lastVDirection == "DOWN" then
			editBoxFrame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 5, 10)
		else
			editBoxFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 5, -10)
		end
	else
		if level.lastVDirection == "DOWN" then
			editBoxFrame:SetPoint("TOPRIGHT", parent, "TOPLEFT", -5, 10)
		else
			editBoxFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -5, -10)
		end
	end
	local dirty
	if level.lastDirection == "RIGHT" then
		if editBoxFrame:GetRight() > GetScreenWidth() then
			level.lastDirection = "LEFT"
			dirty = true
		end
	elseif editBoxFrame:GetLeft() < 0 then
		level.lastDirection = "RIGHT"
		dirty = true
	end
	if level.lastVDirection == "DOWN" then
		if editBoxFrame:GetBottom() < 0 then
			level.lastVDirection = "UP"
			dirty = true
		end
	elseif editBoxFrame:GetTop() > GetScreenWidth() then
		level.lastVDirection = "DOWN"
		dirty = true
	end
	if dirty then
		editBoxFrame:ClearAllPoints()
		if level.lastDirection == "RIGHT" then
			if level.lastVDirection == "DOWN" then
				editBoxFrame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 5, 10)
			else
				editBoxFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 5, -10)
			end
		else
			if level.lastVDirection == "DOWN" then
				editBoxFrame:SetPoint("TOPRIGHT", parent, "TOPLEFT", -5, 10)
			else
				editBoxFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -5, -10)
			end
		end
	end
	local left, bottom = editBoxFrame:GetLeft(), editBoxFrame:GetBottom()
	editBoxFrame:ClearAllPoints()
	editBoxFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	if mod(level.num, 5) == 0 then
		local left, bottom = level:GetLeft(), level:GetBottom()
		level:ClearAllPoints()
		level:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	end
end

function Dewdrop:IsOpen(parent)
	self:argCheck(parent, 2, "table", "nil")
	return levels[1] and levels[1]:IsShown() and (not parent or parent == levels[1].parent or parent == levels[1]:GetParent())
end

function Dewdrop:GetOpenedParent()
	return (levels[1] and levels[1]:IsShown()) and (levels[1].parent or levels[1]:GetParent())
end

function Open(self, parent, func, level, value, point, relativePoint, cursorX, cursorY)
	self:Close(level)
	if DewdropLib then
		local d = DewdropLib:GetInstance('1.0')
		local ret, val = pcall(d, IsOpen, d)
		if ret and val then
			DewdropLib:GetInstance('1.0'):Close()
		end
	end
	parent:GetCenter()
	local frame = AcquireLevel(self, level)
	if level == 1 then
		frame.lastDirection = "RIGHT"
		frame.lastVDirection = "DOWN"
	else
		frame.lastDirection = levels[level - 1].lastDirection
		frame.lastVDirection = levels[level - 1].lastVDirection
	end
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:ClearAllPoints()
	frame.parent = parent
	frame:SetPoint("LEFT", UIParent, "RIGHT", 10000, 0)
	frame:Show()
	if level == 1 then
		baseFunc = func
	end
	levels[level].value = value
--	levels[level].parentText = parent.text and parent.text:GetText() or nil
--	levels[level].parentTooltipTitle = parent.tooltipTitle
--	levels[level].parentTooltipText = parent.tooltipText
--	levels[level].parentTooltipFunc = parent.tooltipFunc
	if parent.arrow then
--		parent.arrow:SetVertexColor(0.2, 0.6, 0)
		parent.arrow:SetHeight(24)
		parent.arrow:SetWidth(24)
	end
	relativePoint = relativePoint or point
	Refresh(self, levels[level])
	if point or (cursorX and cursorY) then
		frame:ClearAllPoints()
		if cursorX and cursorY then
			local curX, curY = GetScaledCursorPosition()
			if curY < GetScreenHeight() / 2 then
				point, relativePoint = "BOTTOM", "BOTTOM"
			else
				point, relativePoint = "TOP", "TOP"
			end
			if curX < GetScreenWidth() / 2 then
				point, relativePoint = point .. "LEFT", relativePoint .. "RIGHT"
			else
				point, relativePoint = point .. "RIGHT", relativePoint .. "LEFT"
			end
		end
		frame:SetPoint(point, parent, relativePoint)
		if cursorX and cursorY then
			local left = frame:GetLeft()
			local width = frame:GetWidth()
			local bottom = frame:GetBottom()
			local height = frame:GetHeight()
			local curX, curY = GetScaledCursorPosition()
			frame:ClearAllPoints()
			relativePoint = relativePoint or point
			if point == "BOTTOM" or point == "TOP" then
				if curX < GetScreenWidth() / 2 then
					point = point .. "LEFT"
				else
					point = point .. "RIGHT"
				end
			elseif point == "CENTER" then
				if curX < GetScreenWidth() / 2 then
					point = "LEFT"
				else
					point = "RIGHT"
				end
			end
			local xOffset, yOffset = 0, 0
			if curY > GetScreenHeight() / 2 then
				yOffset = -height
			end
			if curX > GetScreenWidth() / 2 then
				xOffset = -width
			end
			frame:SetPoint(point, parent, relativePoint, curX - left + xOffset, curY - bottom + yOffset)
			if level == 1 then
				frame.lastDirection = "RIGHT"
			end
		elseif cursorX then
			local left = frame:GetLeft()
			local width = frame:GetWidth()
			local curX, curY = GetScaledCursorPosition()
			frame:ClearAllPoints()
			relativePoint = relativePoint or point
			if point == "BOTTOM" or point == "TOP" then
				if curX < GetScreenWidth() / 2 then
					point = point .. "LEFT"
				else
					point = point .. "RIGHT"
				end
			elseif point == "CENTER" then
				if curX < GetScreenWidth() / 2 then
					point = "LEFT"
				else
					point = "RIGHT"
				end
			end
			frame:SetPoint(point, parent, relativePoint, curX - left - width / 2, 0)
			if level == 1 then
				frame.lastDirection = "RIGHT"
			end
		elseif cursorY then
			local bottom = frame:GetBottom()
			local height = frame:GetHeight()
			local curX, curY = GetScaledCursorPosition()
			frame:ClearAllPoints()
			relativePoint = relativePoint or point
			if point == "LEFT" or point == "RIGHT" then
				if curX < GetScreenHeight() / 2 then
					point = point .. "BOTTOM"
				else
					point = point .. "TOP"
				end
			elseif point == "CENTER" then
				if curX < GetScreenHeight() / 2 then
					point = "BOTTOM"
				else
					point = "TOP"
				end
			end
			frame:SetPoint(point, parent, relativePoint, 0, curY - bottom - height / 2)
			if level == 1 then
				frame.lastDirection = "DOWN"
			end
		end
		if (strsub(point, 1, 3) ~= strsub(relativePoint, 1, 3)) then
			if frame:GetBottom() < 0 then
				local point, parent, relativePoint, x, y = frame:GetPoint(1)
				local change = GetScreenHeight() - frame:GetTop()
				local otherChange = -frame:GetBottom()
				if otherChange < change then
					change = otherChange
				end
				frame:SetPoint(point, parent, relativePoint, x, y + change)
			elseif frame:GetTop() > GetScreenHeight() then
				local point, parent, relativePoint, x, y = frame:GetPoint(1)
				local change = GetScreenHeight() - frame:GetTop()
				local otherChange = -frame:GetBottom()
				if otherChange < change then
					change = otherChange
				end
				frame:SetPoint(point, parent, relativePoint, x, y + change)
			end
		end
	end
	CheckDualMonitor(self, frame)
	StartCounting(self, level)
end

function Dewdrop:IsRegistered(parent)
	self:argCheck(parent, 2, "table")
	return not not self.registry[parent]
end

function Dewdrop:Register(parent, k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	self:argCheck(parent, 2, "table")
	if self.registry[parent] then
		self:Unregister(parent)
	end
	local info = new(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	if type(info.children) == "table" then
		local err, position = validateOptions(info.children)
		
		if err then
			if position then
				Dewdrop:error(position .. ": " .. err)
			else
				Dewdrop:error(err)
			end
		end
	end
	self.registry[parent] = info
	if not info.dontHook and not self.onceRegistered[parent] then
		if parent:HasScript("OnMouseUp") then
			local script = parent:GetScript("OnMouseUp")
			parent:SetScript("OnMouseUp", function()
				if script then
					script()
				end
				if arg1 == "RightButton" and self.registry[parent] then
					if self:IsOpen(parent) then
						self:Close()
					else
						self:Open(parent)
					end
				end
			end)
		end
		if parent:HasScript("OnMouseDown") then
			local script = parent:GetScript("OnMouseDown")
			parent:SetScript("OnMouseDown", function()
				if script then
					script()
				end
				if self.registry[parent] then
					self:Close()
				end
			end)
		end
	end
	self.onceRegistered[parent] = true
end

function Dewdrop:Unregister(parent)
	self:argCheck(parent, 2, "table")
	self.registry[parent] = nil
end

function Dewdrop:Open(parent, k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	self:argCheck(parent, 2, "table")
	local info
	if type(k1) == "table" and k1[0] and k1.IsFrameType and self.registry[k1] then
		info = tmp()
		for k,v in pairs(self.registry[k1]) do
			info[k] = v
		end
	else
		info = tmp(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
		if self.registry[parent] then
			for k,v in pairs(self.registry[parent]) do
				if info[k] == nil then
					info[k] = v
				end
			end
		end
	end
	local point = info.point
	local relativePoint = info.relativePoint
	local cursorX = info.cursorX
	local cursorY = info.cursorY
	if type(point) == "function" then
		local b
		point, b = point(parent)
		if b then
			relativePoint = b
		end
	end
	if type(relativePoint) == "function" then
		relativePoint = relativePoint(parent)
	end
	Open(self, parent, info.children, 1, nil, point, relativePoint, cursorX, cursorY)
end

function Clear(self, level)
	if level then
		if level.buttons then
			for i = table.getn(level.buttons), 1, -1 do
				ReleaseButton(self, level, i)
			end
		end
	end
end

function Dewdrop:Close(level)
	if DropDownList1:IsShown() then
		DropDownList1:Hide()
	end
	if DewdropLib then
		local d = DewdropLib:GetInstance('1.0')
		local ret, val = pcall(d, IsOpen, d)
		if ret and val then
			DewdropLib:GetInstance('1.0'):Close()
		end
	end
	self:argCheck(level, 2, "number", "nil")
	if not level then
		level = 1
	end
	if level == 1 and levels[level] then
		levels[level].parented = false
	end
	if level > 1 and levels[level-1].buttons then
		local buttons = levels[level-1].buttons
		for _,button in ipairs(buttons) do
			button.arrow:SetWidth(16)
			button.arrow:SetHeight(16)
--			button.arrow:SetVertexColor(1, 1, 1)
		end
	end
	if sliderFrame and sliderFrame.level >= level then
		sliderFrame:Hide()
	end
	if editBoxFrame and editBoxFrame.level >= level then
		editBoxFrame:Hide()
	end
	for i = level, table.getn(levels) do
		Clear(self, levels[level])
		levels[level]:Hide()
		levels[i]:ClearAllPoints()
		levels[i]:SetPoint("CENTER", UIParent, "CENTER")
	end
end

function Dewdrop:AddLine(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	local info = tmp(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10, k11, v11, k12, v12, k13, v13, k14, v14, k15, v15, k16, v16, k17, v17, k18, v18, k19, v19, k20, v20)
	local level = info.level or currentLevel
	info.level = nil
	local button = AcquireButton(self, level)
	if not next(info) then
		info.disabled = true
	end
	button.disabled = info.isTitle or info.notClickable or info.disabled
	button.isTitle = info.isTitle
	button.notClickable = info.notClickable
	if button.isTitle then
		button.text:SetFontObject(GameFontNormalSmall)
	elseif button.notClickable then
		button.text:SetFontObject(GameFontHighlightSmall)
	elseif button.disabled then
		button.text:SetFontObject(GameFontDisableSmall)
	else
		button.text:SetFontObject(GameFontHighlightSmall)
	end
	if info.disabled then
		button.arrow:SetDesaturated(true)
		button.check:SetDesaturated(true)
	else
		button.arrow:SetDesaturated(false)
		button.check:SetDesaturated(false)
	end
	if info.textR and info.textG and info.textB then
		button.textR = info.textR
		button.textG = info.textG
		button.textB = info.textB
		button.text:SetTextColor(button.textR, button.textG, button.textB)
	else
		button.text:SetTextColor(button.text:GetFontObject():GetTextColor())
	end
	button.notCheckable = info.notCheckable
	button.text:SetPoint("LEFT", button, "LEFT", button.notCheckable and 0 or 24, 0)
	button.checked = not info.notCheckable and info.checked
	button.isRadio = not info.notCheckable and info.isRadio
	if info.isRadio then
		button.check:Show()
		button.check:SetTexture(info.checkIcon or "Interface\\Buttons\\UI-RadioButton")
		if button.checked then
			button.check:SetTexCoord(0.25, 0.5, 0, 1)
			button.check:SetVertexColor(1, 1, 1, 1)
		else
			button.check:SetTexCoord(0, 0.25, 0, 1)
			button.check:SetVertexColor(1, 1, 1, 0.5)
		end
		button.radioHighlight:SetTexture(info.checkIcon or "Interface\\Buttons\\UI-RadioButton")
		button.check:SetWidth(16)
		button.check:SetHeight(16)
	elseif info.icon then 
		button.check:Show()
		button.check:SetTexture(info.icon)
		if info.iconWidth and info.iconHeight then
			button.check:SetWidth(info.iconWidth)
			button.check:SetHeight(info.iconHeight)
		else
			button.check:SetWidth(16)
			button.check:SetHeight(16)
		end
		button.check:SetVertexColor(1, 1, 1, 1)
		button.check:SetTexCoord(0, 1, 0, 1)
	else
		if button.checked then
			if info.checkIcon then
				button.check:SetWidth(16)
				button.check:SetHeight(16)
				button.check:SetTexture(info.checkIcon)
				if string.sub(info.checkIcon, 1, 16) == "Interface\\Icons\\" then
					button.check:SetTexCoord(0.05, 0.95, 0.05, 0.95)
				else
					button.check:SetTexCoord(0, 1, 0, 1)
				end
			else
				button.check:SetWidth(24)
				button.check:SetHeight(24)
				button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
				button.check:SetTexCoord(0, 1, 0, 1)
			end
			button.check:SetVertexColor(1, 1, 1, 1)
		else
			button.check:SetVertexColor(1, 1, 1, 0)
		end
	end
	if not button.disabled then
		button.func = info.func
	end
	button.hasColorSwatch = info.hasColorSwatch
	if button.hasColorSwatch then
		button.colorSwatch:Show()
		button.colorSwatch.texture:Show()
		button.r = info.r or 1
		button.g = info.g or 1
		button.b = info.b or 1
		button.colorSwatch.texture:SetTexture(button.r, button.g, button.b)
		button.checked = false
		button.func = nil
		button.colorFunc = info.colorFunc
		button.colorArg1 = info.colorArg1
		button.colorArg2 = info.colorArg2
		button.colorArg3 = info.colorArg3
		button.colorArg4 = info.colorArg4
		button.hasOpacity = info.hasOpacity
		button.opacity = info.opacity or 1
	else
		button.colorSwatch:Hide()
		button.colorSwatch.texture:Hide()
	end
	button.hasArrow = not button.hasColorSwatch and (info.value or info.hasSlider or info.hasEditBox) and info.hasArrow
	if button.hasArrow then
		button.arrow:SetAlpha(1)
		if info.hasSlider then
			button.hasSlider = true
			button.sliderMin = info.sliderMin or 0
			button.sliderMax = info.sliderMax or 1
			button.sliderStep = info.sliderStep or 0
			button.sliderIsPercent = info.sliderIsPercent and true or false
			button.sliderMinText = info.sliderMinText or button.sliderIsPercent and string.format("%.0f%%", button.sliderMin * 100) or button.sliderMin
			button.sliderMaxText = info.sliderMaxText or button.sliderIsPercent and string.format("%.0f%%", button.sliderMax * 100) or button.sliderMax
			button.sliderFunc = info.sliderFunc
			button.sliderValue = info.sliderValue
			button.sliderArg1 = info.sliderArg1
			button.sliderArg2 = info.sliderArg2
			button.sliderArg3 = info.sliderArg3
			button.sliderArg4 = info.sliderArg4
		elseif info.hasEditBox then
			button.hasEditBox = true
			button.editBoxText = info.editBoxText or ""
			button.editBoxFunc = info.editBoxFunc
			button.editBoxArg1 = info.editBoxArg1
			button.editBoxArg2 = info.editBoxArg2
			button.editBoxArg3 = info.editBoxArg3
			button.editBoxArg4 = info.editBoxArg4
			button.editBoxChangeFunc = info.editBoxChangeFunc
			button.editBoxChangeArg1 = info.editBoxChangeArg1
			button.editBoxChangeArg2 = info.editBoxChangeArg2
			button.editBoxChangeArg3 = info.editBoxChangeArg3
			button.editBoxChangeArg4 = info.editBoxChangeArg4
			button.editBoxValidateFunc = info.editBoxValidateFunc
			button.editBoxValidateArg1 = info.editBoxValidateArg1
			button.editBoxValidateArg2 = info.editBoxValidateArg2
			button.editBoxValidateArg3 = info.editBoxValidateArg3
			button.editBoxValidateArg4 = info.editBoxValidateArg4
		else
			button.value = info.value
		end
	else
		button.arrow:SetAlpha(0)
	end
	button.arg1 = info.arg1
	button.arg2 = info.arg2
	button.arg3 = info.arg3
	button.arg4 = info.arg4
	button.closeWhenClicked = info.closeWhenClicked
	button.textHeight = info.textHeight or UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT or 10
	local font,_ = button.text:GetFont()
	button.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", button.textHeight)
	button:SetHeight(button.textHeight + 6)
	button.text:SetPoint("RIGHT", button.arrow, (button.hasColorSwatch or button.hasArrow) and "LEFT" or "RIGHT")
	button.text:SetJustifyH(info.justifyH or "LEFT")
	button.text:SetText(info.text)
	button.tooltipTitle = info.tooltipTitle
	button.tooltipText = info.tooltipText
	button.tooltipFunc = info.tooltipFunc
	button.tooltipArg1 = info.tooltipArg1
	button.tooltipArg2 = info.tooltipArg2
	button.tooltipArg3 = info.tooltipArg3
	button.tooltipArg4 = info.tooltipArg4
	if not button.tooltipTitle and not button.tooltipText and not button.tooltipFunc and not info.isTitle then
		button.tooltipTitle = info.text
	end
	if type(button.func) == "string" then
		self:assert(type(button.arg1) == "table", "Cannot call method " .. button.func .. " on a non-table")
		self:assert(type(button.arg1[button.func]) == "function", "Method " .. button.func .. " nonexistant.")
	end
end

function Dewdrop:InjectAceOptionsTable(handler, options)
	self:argCheck(handler, 2, "table")
	self:argCheck(options, 3, "table")
	if string.lower(tostring(options.type)) ~= "group" then
		self:error('Cannot inject into options table argument #3 if its type is not "group"')
	end
	if options.handler ~= nil and options.handler ~= handler then
		self:error("Cannot inject into options table argument #3 if it has a different handler than argument #2")
	end
	options.handler = handler
	local class = handler.class
	if not AceLibrary:HasInstance("AceOO-2.0") or not class then
		self:error("Cannot retrieve AceOptions tables from a non-object argument #2")
	end
	while class and class ~= AceLibrary("AceOO-2.0").Class do
		if type(class.GetAceOptionsDataTable) == "function" then
			local t = class:GetAceOptionsDataTable(handler)
			for k,v in pairs(t) do
				if type(options.args) ~= "table" then
					options.args = {}
				end
				if options.args[k] == nil then
					options.args[k] = v
				end
			end
		end
		local mixins = class.mixins
		if mixins then
			for mixin in pairs(mixins) do
				if type(mixin.GetAceOptionsDataTable) == "function" then
					local t = mixin:GetAceOptionsDataTable(handler)
					for k,v in pairs(t) do
						if type(options.args) ~= "table" then
							options.args = {}
						end
						if options.args[k] == nil then
							options.args[k] = v
						end
					end
				end
			end
		end
		class = class.super
	end
	return options
end

local function activate(self, oldLib, oldDeactivate)
	Dewdrop = self
	if oldLib and oldLib.registry then
		self.registry = oldLib.registry
		self.onceRegistered = oldLib.onceRegistered
	else
		self.registry = {}
		self.onceRegistered = {}

		local WorldFrame_OnMouseDown = WorldFrame:GetScript("OnMouseDown")
		local WorldFrame_OnMouseUp = WorldFrame:GetScript("OnMouseUp")
		local oldX, oldY, clickTime
		WorldFrame:SetScript("OnMouseDown", function()
			oldX,oldY = GetCursorPosition()
			clickTime = GetTime()
			if WorldFrame_OnMouseDown then
				WorldFrame_OnMouseDown()
			end
		end)

		WorldFrame:SetScript("OnMouseUp", function()
			local x,y = GetCursorPosition()
			if not oldX or not oldY or not x or not y or not clickTime then
				self:Close()
				if WorldFrame_OnMouseUp then
					WorldFrame_OnMouseUp()
				end
				return
			end
			local d = math.abs(x - oldX) + math.abs(y - oldY)
			if d <= 5 and GetTime() - clickTime < 0.5 then
				self:Close()
			end
			if WorldFrame_OnMouseUp then
				WorldFrame_OnMouseUp()
			end
		end)
		
		if hooksecurefunc then
			hooksecurefunc(DropDownList1, "Show", function()
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
			end)
		else
			local DropDownList1_Show = DropDownList1.Show
			function DropDownList1.Show(DropDownList1)
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
				DropDownList1_Show(DropDownList1)
			end
		end
		
		if hooksecurefunc then
			hooksecurefunc("HideDropDownMenu", function()
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
			end)
		else
			local old_HideDropDownMenu = HideDropDownMenu
			function HideDropDownMenu(num)
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
				old_HideDropDownMenu(num)
			end
		end
		
		if hooksecurefunc then
			hooksecurefunc("CloseDropDownMenus", function()
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
			end)
		else
			local old_CloseDropDownMenus = CloseDropDownMenus
			function CloseDropDownMenus(num)
				if levels[1] and levels[1]:IsVisible() then
					self:Close()
				end
				old_CloseDropDownMenus(num)
			end
		end
	end
	levels = {}
	buttons = {}
	
	if oldDeactivate then
		oldDeactivate(oldLib)
	end
end

AceLibrary:Register(Dewdrop, MAJOR_VERSION, MINOR_VERSION, activate)
```

## Meeting.lua
```lua
local AFK_MESSAGE = string.format(MARKED_AFK_MESSAGE, DEFAULT_AFK_MESSAGE)

local function GetMembers()
    local members = {}
    for i = 1, GetNumRaidMembers() do
        local n = UnitName("raid" .. i)
        table.insert(members, n)
    end
    if table.getn(members) == 0 then
        for i = 1, GetNumPartyMembers() do
            local n = UnitName("party" .. i)
            table.insert(members, n)
        end
    end
    return members
end

local function OnMemberChange()
    Meeting.members = GetMembers()

    local joined = nil
    for _, activity in ipairs(Meeting.activities) do
        for _, member in ipairs(Meeting.members) do
            if member == activity.unitname then
                joined = activity
                break
            end
        end
    end

    local needUpdateBrowser = false
    local needUpdateCreator = false
    local activity = joined or Meeting:FindActivity(Meeting.player)
    if activity then
        needUpdateBrowser = true
        for i, applicant in ipairs(activity.applicantList) do
            local isMember = false
            for _, member in ipairs(Meeting.members) do
                if member == applicant.name then
                    isMember = true
                    break
                end
            end
            if isMember then
                table.remove(activity.applicantList, i)
            else
                applicant.status = Meeting.APPLICANT_STATUS.None
            end
        end

        if activity.unitname == Meeting.player then
            local members = table.getn(Meeting.members) + 1
            activity.members = members
            Meeting.Message.SyncMembers(members)
            if members >= Meeting.GetActivityMaxMembers(activity.code) then
                Meeting.Message.CloseActivity()
            end
        end
        needUpdateCreator = true
    end

    local ml = table.getn(Meeting.members)
    local isLeader = ml == 0 or (ml > 0 and IsRaidLeader() == 1)
    if not isLeader then
        local activity
        Meeting:FindActivity(Meeting.player)
        if activity and not activity:IsChat() then
            Meeting.Message.CloseActivity()
            needUpdateBrowser = true
            needUpdateCreator = true
        end
    end

    if joined and joined.unitname ~= Meeting.player then
        joined.applicantStatus = Meeting.APPLICANT_STATUS.Joined
        Meeting.BrowserFrame:UpdateActivity(joined)
        needUpdateBrowser = true
    end

    if Meeting.joinedActivity then
        local activity = Meeting:FindActivity(Meeting.joinedActivity.unitname)
        if activity then
            activity.applicantStatus = Meeting.APPLICANT_STATUS.None
            needUpdateBrowser = true
        end
        if not joined then
            needUpdateCreator = true
        end
    end

    Meeting.joinedActivity = joined

    if needUpdateBrowser then
        Meeting.BrowserFrame:UpdateList()
    end
    Meeting.CreatorFrame.UpdateActivity()
    if needUpdateCreator then
        Meeting.CreatorFrame:UpdateList()
    end
    Meeting.FloatFrame.Update()
end

local f = CreateFrame("Frame", "Meeting", UIParent)
f:RegisterEvent("CHAT_MSG_HARDCORE")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("PARTY_LEADER_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("SPELLS_CHANGED")
f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL" then
        local _, _, source = string.find(arg4, "(%d+)%.")
        local name = nil
        if source then
            _, name = GetChannelName(source)
        end
        if name then
            if name == Meeting.channel and string.startswith(arg1, "Meeting:") then
                Meeting.Message.OnRecv(arg2, arg1)
            else
                local lowname = string.lower(name)
                if lowname == "world" or lowname == "china" or lowname == "world" or lowname == "lfg" then
                    lowname = "world"
                    Meeting.Message.OnRecvFormChat(lowname, arg2, arg1)
                end
            end
        end
    elseif event == "CHAT_MSG_HARDCORE" then
        Meeting.Message.OnRecvFormChat("hardcore", arg2, arg1)
    elseif event == "PARTY_LEADER_CHANGED" then
        if table.getn(Meeting.members) > 0 and IsRaidLeader() ~= 1 then
            if Meeting:FindActivity(Meeting.player) then
                Meeting.Message.CloseActivity()
            end
        end
        Meeting.CreatorFrame.UpdateActivity()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        OnMemberChange()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Meeting.Settings.EnsureDefaults()
        if Meeting.WT and Meeting.WT.UpdateHeaderButtons then
            Meeting.WT.UpdateHeaderButtons()
        end
        Meeting.Minimap.Init()
        Meeting.members = GetMembers()

		if not MEETING_DB.blockWords then -- 新增进入游戏初始化默认屏蔽词 by 武藤纯子酱 2025.12.30
			MEETING_DB.blockWords = {
				'Boost',
				'Taobao',
				'Gold',
				'Powerlevel'
			}
		end
		Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30

        if MEETING_DB.hideFloat == 1 then
            Meeting.FloatFrame:Hide()
        else
            Meeting.FloatFrame:Show()
        end
        Meeting.FloatFrame.Update()

        C_Timer.After(2, function()
            Meeting.CheckLFTChannel()
            Meeting.CheckPlayerHCMode()
            if not Meeting.versionSent then
                Meeting.versionSent = true
                Meeting.Message.SendVersion()
            end
            if MEETING_DB.activity then
                local now = time()
                if now - MEETING_DB.activity.lastTime < 120 then
                    MEETING_DB.activity.lastTime = now
                    Meeting.createInfo.code = MEETING_DB.activity.code
                    Meeting.createInfo.comment = MEETING_DB.activity.comment == "_" and "" or MEETING_DB.activity.comment
                    Meeting.CreatorFrame.UpdateActivity()
                    Meeting.Message.CreateActivity(Meeting.createInfo.code, Meeting.createInfo.comment)
                end
            end
        end)
    elseif event == "PLAYER_LEAVING_WORLD" then
        if Meeting:FindActivity(Meeting.player) then
            Meeting.Message.CloseActivity(true)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local _, _, playerName = string.find(arg1, "^(.+)拒绝了你邀请其加入队伍的请求。")
        if playerName then
            Meeting.DeclinedInvite(playerName)
        end

        if arg1 == AFK_MESSAGE then
            Meeting.isAFK = true
        elseif arg1 == CLEARED_AFK then
            Meeting.isAFK = false
        end
    elseif event == "SPELLS_CHANGED" then
        Meeting.CheckPlayerHCMode()
    end
end)

Meeting.isHover = false
f:SetScript("OnUpdate", function()
    if not Meeting.MainFrame:IsShown() or not Meeting.BrowserFrame:IsShown() then
        return
    end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local t = Meeting.MainFrame:GetTop() * scale
    local b = Meeting.MainFrame:GetBottom() * scale
    local l = Meeting.MainFrame:GetLeft() * scale
    local r = Meeting.MainFrame:GetRight() * scale
    local cur = x >= l and x <= r and y >= b and y <= t
    if cur ~= Meeting.isHover then
        Meeting.isHover = cur
        if not cur then
            Meeting.BrowserFrame:UpdateList()
        end
    end
end)

function Meeting.CheckPlayerHCMode()
    local isHC = false
    local i = 1
    while true do
        local spellName, _ = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        if spellName == "Hardcore" then
            isHC = true
            break
        else
            i = i + 1
        end
    end
    Meeting.playerIsHC = isHC
end

function Meeting:OwnerActivity()
    for i, item in ipairs(Meeting.activities) do
        if item.unitname == Meeting.player then
            return item
        end
    end
    return nil
end

function Meeting.IsInActiveGroup()
    return Meeting.joinedActivity ~= nil or Meeting:OwnerActivity() ~= nil
end

function Meeting.UpdateIcons()
    local active = Meeting.IsInActiveGroup()
    local isLeader = Meeting:OwnerActivity() ~= nil
    local r, g, b
    if active then
        r = Meeting.GUI.Theme.Green.r
        g = Meeting.GUI.Theme.Green.g
        b = Meeting.GUI.Theme.Green.b
    else
        r, g, b = 0.5, 0.9, 1
    end
    if Meeting.FloatFrame and Meeting.FloatFrame.icon then
        Meeting.FloatFrame.icon:SetVertexColor(r, g, b)
    end
    if Meeting.MinimapButton and Meeting.MinimapButton.icon then
        Meeting.MinimapButton.icon:SetVertexColor(r, g, b)
    end
    if Meeting.FloatFrame and Meeting.FloatFrame.crown then
        if isLeader then
            Meeting.FloatFrame.crown:Show()
        else
            Meeting.FloatFrame.crown:Hide()
        end
    end
end

local mainFrame = Meeting.GUI.CreateFrame({
    name = "MeetingMainFrame",
    width = 818,
    height = 424,
    movable = true,
    anchor = {
        point = "CENTER",
        x = 0,
        y = 0
    },
})
mainFrame:SetFrameStrata("DIALOG")
Meeting.GUI.SetBackground(mainFrame, Meeting.GUI.Theme.Brown)
mainFrame:Hide()
tinsert(UISpecialFrames, "MeetingMainFrame");
Meeting.MainFrame = mainFrame

local headerFrame = Meeting.GUI.CreateFrame({
    parent = mainFrame,
    width = 818,
    height = 28,
    anchor = {
        point = "TOP",
        relative = mainFrame,
        relativePoint = "TOP",
    }
})
mainFrame.headerFrame = headerFrame
local line = mainFrame:CreateTexture()
mainFrame.headerLine = line
line:SetWidth(818)
line:SetHeight(0.5)
line:SetTexture(1, 1, 1, 0.5)
line:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)

local title = "Meeting " .. Meeting.VERSION.MAJOR .. "." .. Meeting.VERSION.MINOR .. "." .. Meeting.VERSION.PATCH
local titleFrame = Meeting.GUI.CreateText({
    parent = headerFrame,
    text = title,
    fontSize = 16,
    anchor = {
        point = "TOP",
        relative = headerFrame,
        relativePoint = "TOP",
        x = 0,
        y = -7
    }
})

local feedbackTextFrame = Meeting.GUI.CreateText({
    parent = headerFrame,
    text = "Feedback and issues on Discord",
    fontSize = 10,
    anchor = {
        point = "TOPLEFT",
        relative = headerFrame,
        relativePoint = "TOPLEFT",
        x = 8,
        y = -9
    }
})
mainFrame.feedbackText = feedbackTextFrame
mainFrame.titleFrame = titleFrame

local closeHeaderButton = Meeting.GUI.CreateButton({
    parent = headerFrame,
    width = 22,
    height = 22,
    text = "X",
    type = Meeting.GUI.BUTTON_TYPE.DANGER,
    anchor = {
        point = "TOPRIGHT",
        relative = headerFrame,
        relativePoint = "TOPRIGHT",
        x = -6,
        y = -6
    },
    click = function()
        Meeting:Toggle()
    end
})
mainFrame.closeButton = closeHeaderButton

local refreshHeaderButton = Meeting.GUI.CreateButton({
    parent = headerFrame,
    width = 58,
    height = 22,
    text = "Refresh",
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    anchor = {
        point = "RIGHT",
        relative = closeHeaderButton,
        relativePoint = "LEFT",
        x = -6,
        y = 0
    },
    click = function()
        if Meeting.WT and Meeting.WT.RefreshVisible then
            Meeting.WT.RefreshVisible()
        end
    end
})
refreshHeaderButton:SetScript("OnEnter", function()
    if not Meeting.WT or not Meeting.WT.IsInstalled() then
        return
    end
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("Refresh translations", 1, 1, 1)
    GameTooltip:AddLine("Fetches translations for visible activity names, leaders, and notes.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
refreshHeaderButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local translateHeaderButton = Meeting.GUI.CreateButton({
    parent = headerFrame,
    width = 58,
    height = 22,
    text = "Translate",
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    anchor = {
        point = "RIGHT",
        relative = refreshHeaderButton,
        relativePoint = "LEFT",
        x = -6,
        y = 0
    },
    click = function()
        if Meeting.WT and Meeting.WT.ToggleEnabled then
            Meeting.WT.ToggleEnabled()
        end
    end
})
translateHeaderButton:SetScript("OnEnter", function()
    if not Meeting.WT or not Meeting.WT.IsInstalled() then
        return
    end
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("Toggle translation display", 1, 1, 1)
    if Meeting.WT.IsEnabled() then
        GameTooltip:AddLine("Currently ON — showing translated text where available.", 0.25, 1, 0.25)
        GameTooltip:AddLine("Click to show original text.", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Currently OFF — showing original text.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Click to show cached translations. Use Refresh to fetch new ones.", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end)
translateHeaderButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
mainFrame.translateButton = translateHeaderButton
mainFrame.translateRefreshButton = refreshHeaderButton
if Meeting.WT and Meeting.WT.UpdateHeaderButtons then
    Meeting.WT.UpdateHeaderButtons()
end

Meeting.GUI.CreateTabs({
    name = "MeetingMainTabs",
    parent = mainFrame,
    width = 80,
    height = 28,
    edge = "bottom",
    anchor = {
        point = "BOTTOMLEFT",
        relative = mainFrame,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = 0
    },
    list = {
        {
            title = "Browse",
            select = function()
                Meeting.CreatorFrame:Hide()
                Meeting.BrowserFrame:Show()
                Meeting.BrowserFrame:UpdateList()
            end
        },
        {
            title = "Manage",
            select = function()
                Meeting.BrowserFrame:Hide()
                Meeting.CreatorFrame:Show()
                Meeting.CreatorFrame:UpdateList()
                Meeting.CreatorFrame:UpdateActivity()
            end
        },
    }
})

function Meeting:Toggle()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        if mainFrame.RefreshResizeGrip then
            mainFrame:RefreshResizeGrip()
        end
        if Meeting.BrowserFrame:IsShown() then
            Meeting.BrowserFrame:UpdateList(true)
        elseif Meeting.CreatorFrame:IsShown() then
            Meeting.CreatorFrame:UpdateList()
        end
    end
end

function Meeting:FindActivity(creator)
    local index = -1
    for i, item in ipairs(Meeting.activities) do
        if item.unitname == creator then
            index = i
            break
        end
    end
    if index ~= -1 then
        return Meeting.activities[index], index
    else
        return nil
    end
end

function Meeting:DeleteActivity(id)
    local index = -1
    for i, item in ipairs(Meeting.activities) do
        if item.unitname == id then
            index = i
            break
        end
    end
    if index ~= -1 then
        local activity = Meeting.activities[index]
        table.remove(Meeting.activities, index)
        return activity
    end
end

function Meeting:OnCreate(id, code, comment, level, class, members, hc, classnum)
    -- 检查屏蔽词
    if Meeting.CheckBlockWords(id, id) or Meeting.CheckBlockWords(id, comment) then
        return  -- 如果包含屏蔽词，不创建活动
    end

    local item, index = Meeting:FindActivity(id)
    local code = Meeting.GetActivityInfo(code).key
    local class = Meeting.NumberToClass(tonumber(class))
    local classColor = Meeting.GetClassRGBColor(class, id)
    if item then
        item.category = Meeting.GetActivityCategory(code).key
        item.code = code
        item.comment = comment
        item.level = tonumber(level)
        item.class = class
        item.members = tonumber(members)
        item.isHC = hc == "1"
        item.updated = time()
        item.classColor = classColor
        if classnum then
            item.classnum = classnum
        end
        table.remove(Meeting.activities, index)
    else
        item = {
            unitname = id,
            category = Meeting.GetActivityCategory(code).key,
            code = code,
            comment = comment,
            level = tonumber(level),
            class = class,
            members = tonumber(members),
            isHC = hc == "1",
            updated = time(),
            applicantList = {},
            classnum = classnum,
            classColor = classColor,
            IsChat = function(self)
                return self.category == "CHAT"
            end,
            GetClassMap = function(self)
                return Meeting.DecodeGroupClass(self.classnum)
            end
        }
    end

    for _, member in ipairs(Meeting.members) do
        if member == item.unitname then
            Meeting.joinedActivity = item
            break
        end
    end

    table.insert(Meeting.activities, 1, item)
    if item:IsChat() and table.getn(Meeting.activities) > 1 then
        table.sort(Meeting.activities, function(a, b)
            if a:IsChat() and not b:IsChat() then
                return false
            elseif not a:IsChat() and b:IsChat() then
                return true
            else
                return a.updated > b.updated
            end
        end)
    end

    Meeting.FloatFrame.Update()
    Meeting.CreatorFrame.UpdateActivity()
    Meeting.BrowserFrame:UpdateList()
end

function Meeting:OnRequest(name, id, level, class, score, comment, role)
    local activity = Meeting:FindActivity(id)
    if activity and (activity.unitname == Meeting.player or (Meeting.joinedActivity and Meeting.joinedActivity.unitname == id)) then
        local i = -1
        for index, value in ipairs(activity.applicantList) do
            if value.name == name then
                i = index
                break
            end
        end
        if i ~= -1 then
            local applicant = activity.applicantList[i]
            applicant.level = tonumber(level)
            applicant.score = tonumber(score)
            applicant.comment = comment
            applicant.status = Meeting.APPLICANT_STATUS.None
            applicant.role = role and tonumber(role) or 0
        else
            local applicant = {
                name = name,
                level = tonumber(level),
                class = Meeting.NumberToClass(tonumber(class)),
                score = tonumber(score),
                comment = comment,
                status = Meeting.APPLICANT_STATUS.None,
                role = role and tonumber(role) or 0
            }
            table.insert(activity.applicantList, applicant)
        end
        PlaySoundFile("Interface\\AddOns\\Meeting\\assets\\request.ogg")

        Meeting.CreatorFrame:UpdateList()
        Meeting.FloatFrame.Update()
    end
end

function Meeting:OnDecline(id, name)
    if name == Meeting.player then
        local activity = Meeting:FindActivity(id)
        if activity then
            activity.applicantStatus = Meeting.APPLICANT_STATUS.Declined
            Meeting.BrowserFrame:UpdateActivity(activity)
            Meeting.BrowserFrame:UpdateList()
        end
    end
    if id ~= Meeting.player and Meeting.joinedActivity and Meeting.joinedActivity.unitname == id then
        local i = -1
        for index, value in ipairs(Meeting.joinedActivity.applicantList) do
            if value.name == name then
                i = index
                break
            end
        end
        table.remove(Meeting.joinedActivity.applicantList, i)
        Meeting.CreatorFrame:UpdateList()
    end
    Meeting.FloatFrame.Update()
end

function Meeting:OnMembers(id, members, classnum)
    local activity, index = Meeting:FindActivity(id)
    if activity then
        activity.members = tonumber(members)
        activity.classnum = classnum
        table.remove(Meeting.activities, index)
        table.insert(Meeting.activities, 1, activity)
        Meeting.BrowserFrame:UpdateList()
    end
end

function Meeting:OnClose(id)
    local activity = Meeting:DeleteActivity(id)
    if activity and activity.unitname == Meeting.player then
        Meeting.CreatorFrame.UpdateActivity()
    end

    if Meeting.joinedActivity and Meeting.joinedActivity.unitname == id then
        Meeting.joinedActivity = nil
    end
    Meeting.BrowserFrame:UpdateList()
    Meeting.CreatorFrame:UpdateList()
    Meeting.FloatFrame.Update()
end

function Meeting.DeclinedInvite(playerName)
    local activity = Meeting:FindActivity(Meeting.player)
    if activity then
        for i, applicant in ipairs(activity.applicantList) do
            if applicant.name == playerName then
                applicant.status = Meeting.APPLICANT_STATUS.Declined
                Meeting.CreatorFrame:UpdateList()
                Meeting.FloatFrame.Update()
                break
            end
        end
    end
end

local needUpdate = false
function Meeting:OnVersion(version)
    if needUpdate then
        return
    end
    local major, minor, patch = string.meetingsplit(version, ".")
    if not major or not minor or not patch then
        return
    end
    major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
    if major ~= nil and minor ~= nil and patch ~= nil then
        if major > Meeting.VERSION.MAJOR or (major == Meeting.VERSION.MAJOR and minor > Meeting.VERSION.MINOR) or
            (major == Meeting.VERSION.MAJOR and minor == Meeting.VERSION.MINOR and patch > Meeting.VERSION.PATCH) then
            needUpdate = true
        end
    end
    if needUpdate then
        titleFrame:SetText(title .. "  (New version available)")
    end
end

function Meeting.CheckLFTChannel()
    local i = -1
    for index, value in ipairs({ GetChannelList() }) do
        if value == Meeting.channel then
            i = index
            break
        end
    end
    if i == -1 then
        JoinChannelByName(Meeting.channel)
    end
    Meeting.RemoveLFTChannelFromWindows()
end

function Meeting.RemoveLFTChannelFromWindows()
    for windowIndex = 1, 9 do
        local DefaultChannels = { GetChatWindowChannels(windowIndex) }
        for _, v in DefaultChannels do
            if v == Meeting.channel then
                if getglobal("ChatFrame" .. windowIndex) then
                    ChatFrame_RemoveChannel(getglobal("ChatFrame" .. windowIndex), Meeting.channel)
                end
            end
        end
    end
end

C_Timer.NewTicker(5, function()
    local now = time()
    local update = false
    for index, activity in ipairs(Meeting.activities) do
        local rm = false
        if activity:IsChat() then
            rm = activity.updated + 60 < now
        elseif activity.unitname ~= Meeting.player then
            rm = activity.updated + 120 < now
        end

        if rm then
            update = true
            table.remove(Meeting.activities, index)
        end
    end

    if update then
        Meeting.BrowserFrame:UpdateList()
        Meeting.FloatFrame.Update()
    end
end)

-- 新增：重新过滤活动列表，移除包含屏蔽词的活动 by 武藤纯子酱 2025.12.30
function Meeting:ReFilterActivities()
    local needUpdate = false
    
    -- 从后往前遍历，避免删除时索引错乱
    for i = table.getn(Meeting.activities), 1, -1 do
        local activity = Meeting.activities[i]
        -- 跳过自己的活动
        if activity.unitname ~= Meeting.player then
            -- 检查队长名字和活动说明是否包含屏蔽词
            if Meeting.CheckBlockWords(activity.unitname, activity.unitname) or 
               Meeting.CheckBlockWords(activity.unitname, activity.comment) then
                -- 从列表中移除
                table.remove(Meeting.activities, i)
                needUpdate = true
                
                -- 如果是已加入的活动，也需要清理
                if Meeting.joinedActivity and Meeting.joinedActivity.unitname == activity.unitname then
                    Meeting.joinedActivity = nil
                end
            end
        end
    end
    
    if needUpdate then
        Meeting.BrowserFrame:UpdateList()
        Meeting.CreatorFrame:UpdateList()
        Meeting.FloatFrame.Update()
    end
end

SLASH_MEETING1 = "/meeting"
SlashCmdList["MEETING"] = function(msg, editbox)
    if (msg == "" or msg == nil) then
        print("Meeting:")
        print("  /meeting visible |cffcccccc- Show/Hide float window")
        print("  /meeting toggle |cffcccccc- Show/Hide main UI")
        print("  /meeting reset |cffcccccc- Reset")
        print("  /meeting block |cffcccccc- Block words management") -- 新屏蔽关键词相关命令 by 武藤纯子酱 2025.12.30
        print("    /meeting block add <keyword> |cffcccccc- Add block word")
        print("    /meeting block del <keyword> |cffcccccc- Delete block word")
        print("    /meeting block clear |cffcccccc- Clear block words")
        print("    /meeting block list |cffcccccc- List block words")
        return
    end

    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
    cmd = string.lower(cmd)
    if cmd == "visible" then
        MEETING_DB.hideFloat = MEETING_DB.hideFloat == 1 and 0 or 1
        if MEETING_DB.hideFloat == 1 then
            Meeting.FloatFrame:Hide()
        else
            Meeting.FloatFrame:Show()
        end
    elseif cmd == "toggle" then
        Meeting:Toggle()
    elseif cmd == "reset" then
        MEETING_DB = {}

		MEETING_DB.blockWords = { -- 新增重置默认屏蔽词 by 武藤纯子酱 2025.12.30
			'Boost',
			'Taobao',
			'Gold',
			'Powerlevel'
		}
        Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
        Meeting.Settings.EnsureDefaults()
		Meeting:ReFilterActivities()

        Meeting.FloatFrame:ClearAllPoints()
        Meeting.FloatFrame:SetPoint("TOP", 0, -20)
        Meeting.FloatFrame:Show()
        MEETING_DB.hideFloat = 0

        Meeting.MainFrame:ClearAllPoints()
        Meeting.MainFrame:SetPoint("CENTER", 0, 0)
        if Meeting.Layout and Meeting.Layout.ResetSize then
            Meeting.Layout.ResetSize()
        end

        Meeting.Settings.Apply()
        Meeting.Minimap.Init()
        if Meeting.SettingsFrame then
            Meeting.SettingsFrame.fontSizeLabel:SetText(tostring(Meeting.Settings.GetFontSize()))
            Meeting.SettingsFrame.borderCheck:SetChecked(Meeting.Settings.UsesBlizzardBorders())
        end
    elseif cmd == "block" then -- 新屏蔽关键词相关命令 by 武藤纯子酱 2025.12.30
        -- 屏蔽词管理功能
        local _, _, subcmd, keyword = string.find(args, "%s?(%w+)%s?(.*)")
        subcmd = string.lower(subcmd or "")
        
        if not MEETING_DB.blockWords then
            MEETING_DB.blockWords = {}
        end
        
        if subcmd == "add" and keyword and keyword ~= "" then
            -- 添加屏蔽词
            keyword = string.trim(keyword)
            local exists = false
            for _, word in ipairs(MEETING_DB.blockWords) do
                if word == keyword then
                    exists = true
                    break
                end
            end
            
            if not exists then
                table.insert(MEETING_DB.blockWords, keyword)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Added block word: " .. keyword)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Block word exists: " .. keyword)
            end
            Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
			Meeting:ReFilterActivities()
        elseif subcmd == "del" and keyword and keyword ~= "" then
            -- 删除屏蔽词
            keyword = string.trim(keyword)
            local found = false
            for i, word in ipairs(MEETING_DB.blockWords) do
                if word == keyword then
                    table.remove(MEETING_DB.blockWords, i)
                    found = true
                    break
                end
            end
            
            if found then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Deleted block word: " .. keyword)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Block word not found: " .. keyword)
            end
            Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
			Meeting:ReFilterActivities()
        elseif subcmd == "clear" then
            -- 清空屏蔽词
            MEETING_DB.blockWords = {}
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Cleared all block words")
            Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
			Meeting:ReFilterActivities()
        elseif subcmd == "list" then
            -- 列出屏蔽词
            if table.getn(MEETING_DB.blockWords) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: No block words")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Current block words (" .. table.getn(MEETING_DB.blockWords) .. "):")
                for i, word in ipairs(MEETING_DB.blockWords) do
                    DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. word)
                end
            end
        elseif subcmd == "reset" then
			MEETING_DB.blockWords = { -- 新增重置默认屏蔽词 by 武藤纯子酱 2025.12.30
				'Boost',
				'Taobao',
				'Gold',
				'Powerlevel'
			}
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Reset all block words")
            Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
			Meeting:ReFilterActivities()		         
        else
            -- 显示帮助
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Block words commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /meeting block add <keyword> - Add block word")
            DEFAULT_CHAT_FRAME:AddMessage("  /meeting block del <keyword> - Delete block word")
            DEFAULT_CHAT_FRAME:AddMessage("  /meeting block clear - Clear block words")
            DEFAULT_CHAT_FRAME:AddMessage("  /meeting block list - List block words")
            DEFAULT_CHAT_FRAME:AddMessage("  /meeting block reset - Reset block words")
        end
    end
end
```

## Meeting.toc
```toc
## Interface: 11200
## Title:|CFF33AAFF[Assist]|R Meeting
## Title-zhCN: |CFF33AAFF[Assist]|R Meeting
## Notes:|CFF33AAFFMeeting|R|N A gadget to help you find groups
## Notes-zhCN: |CFF33AAFFMeeting|R|N A gadget to help you find groups
## Version: 1.1.5
## Author: ??, ?????, Wind, Sunelegy
## SavedVariablesPerCharacter: MEETING_DB
## OptionalDeps: WoWTranslate

Util.lua
Compat.lua
Init.lua
GUI.lua
Settings.lua
WoWTranslate.lua
Minimap.lua
Meeting.lua
Message.lua
libs\AceLibrary.lua
libs\Dewdrop-2.0.lua

Float.lua
Creator.lua
Browser.lua
Layout.lua


```

## Message.lua
```lua
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

local function CheckBlockWords(playerName, message)
    -- 如果玩家是自己，不屏蔽
    if playerName == Meeting.player then
        return false
    end
    
    -- 检查消息是否为空
    if not message or message == "" or message == "_" then
        return false
    end
    
    -- 检查屏蔽词列表是否存在
    if not Meeting.blockWords or table.getn(Meeting.blockWords) == 0 then
        return false
    end
    
    -- 转换为小写进行不区分大小写的匹配
    local lowerMessage = string.lower(message)
    
    -- 检查每个屏蔽词
    for _, word in ipairs(Meeting.blockWords) do
        if word and word ~= "" then
            local lowerWord = string.lower(word)
            if string.find(lowerMessage, lowerWord) then
                return true
            end
        end
    end
    
    return false
end

Meeting.CheckBlockWords = CheckBlockWords

function Message.OnRecv(playerName, data)
    local _, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7 = string.meetingsplit(data, ":")
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
            Meeting:OnCreate(playerName, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
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
                table.insert(matchText, match)
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
    -- 新增任务链接检测逻辑
	if string.find(message, "|Hquest:") then
		-- 安全解析任务链接：确保括号配对
		local questStart = string.find(message, "|Hquest:")
		if questStart then
			-- 查找对应的"]"
			local bracketStart = string.find(message, "%[", questStart)
			if bracketStart then
				local bracketEnd = string.find(message, "%]", bracketStart)
				if bracketEnd then
					-- 继续查找"|h"结束位置，确保格式完整
					local pipeHStart = string.find(message, "|h", bracketEnd)
					if pipeHStart then
						-- 截取完整的任务链接部分（从questStart开始）
						local linkPart = string.sub(message, questStart)
						-- 查找链接结束位置
						local linkEnd = string.find(linkPart, "|h")
						if linkEnd then
							linkPart = string.sub(linkPart, 1, linkEnd + 1) -- 包含|h
							
							-- 现在我们可以安全解析
							-- 注意：魔兽世界1.12的任务链接格式是：|Hquest:id:level|h[name]|h
							local _, _, questID, questLevel, questName = string.find(
								linkPart, 
								"|Hquest:(%d+):(%d+)|h%[([^%]]*)%]|h"
							)
							
							-- 如果解析成功
							if questID and questLevel and questName then
								-- 自动创建任务追踪活动
                                if Meeting.OnCreate then
                                    Meeting:OnCreate(playerName, "QuestLink", 
                                        questName,                    -- 任务名字
                                        questLevel,                   -- 任务等级
                                        "0",                          -- 职业占位
                                        "0",                          -- 人数占位
                                        "0",                          -- 硬核模式
                                        questID                       -- 使用任务ID作为分类标识
                                    )
                                end
								return
							end
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
    if string.find(message, "求组") or string.find(message, "lfg") or string.find(message, "lfm") then
        return
    end
    if CheckBlockWords(playerName, message) then
        return
    end
    -- 修改匹配逻辑，添加多选状态检查和排除检查
    local lowerMessage = string.lower(message)
    
    -- 获取当前的多选状态和排除关键词
    local matchs, nomatchs = SetMathcKeyWords()
    
    -- 如果没有选择任何活动类型，或者选择了"全部"，则匹配所有
    local shouldMatchAll = Meeting.searchInfo.category == "" or 
                          (Meeting.searchInfo.category ~= "" and Meeting.searchInfo.code == "" and not next(Meeting.searchInfo.codes))
    
    -- 先检查排除关键词
    for _, nomatch in ipairs(nomatchs) do
        if string.find(lowerMessage, nomatch) then
            return  -- 如果包含排除关键词，不创建活动
        end
    end
    
    -- 如果选择了"全部"或者没有选择任何过滤条件，使用原来的匹配逻辑
    if shouldMatchAll then
        for _, v in ipairs(matchText) do
            if string.find(lowerMessage, v) then
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
            if string.find(lowerMessage, match) then
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
    else
        print("Please join " .. Meeting.channel .. " channel")
    end
end

function Message.CreateActivity(code, comment)
    local data = string.format("%s:%s:%d:%d:%d:%d:%s", code,
        string.isempty(comment) and "_" or comment, UnitLevel("player"),
        Meeting.ClassToNumber(Meeting.playerClass),
        table.getn(Meeting.members) + 1, Meeting.playerIsHC and 1 or 0, Meeting.EncodeGroupClass())
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
```

## Minimap.lua
```lua
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
```

## Settings.lua
```lua
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
```

## Util.lua
```lua
function string.startswith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function string.isempty(s)
    return s == nil or s == ''
end

function string.meetingsplit(str, delimiter)
    if not str then
        return nil
    end
    local delimiter, fields = delimiter or ":", {}
    local pattern = string.format("([^%s]+)", delimiter)
    string.gsub(str, pattern, function(c)
        fields[table.getn(fields) + 1] = c
    end)
    return unpack(fields)
end

-- 添加字符串trim函数 by 武藤纯子酱 2025.12.30
function string.trim(str)
    if not str then return "" end
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end
```

## WoWTranslate.lua
```lua
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
```

