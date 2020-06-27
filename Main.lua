local addonName, env = ...

-- Defaults, and instantiate saved variable
env.configDefaults = {
    debugMode           = false,
    reportResets        = false,
    reportLockedOnly    = false,
    colorProgress       = true,
    force24H            = false,
    updateInterval      = 5,
    displayMin          = 2,
    width               = 300,
    height              = 15,
    xOffset             = 0,
    yOffset             = 55,
    fontSize            = 10,
}
InstanceHistoryExtraSV = InstanceHistoryExtraSV or {}

-- EVENT HANDLERS --
env.onEvent = {}

function env.onEvent.ADDON_LOADED(...)
    local n = select(2, ...)
    if n == addonName then
        -- Instantiate database
        local db = InstanceHistoryExtraSV
        db.histGeneration = db.histGeneration or 1
        db.History = db.History or {}
        db.Instances = db.Instances or {}
        db.colorOffset = db.colorOffset or 0
        db.config = db.config or {}

        -- Fill in missing values
        env.updateTable(db.config, env.configDefaults, true)

        -- Remove unused configs
        for k, _ in pairs(db.config) do
            if env.configDefaults[k] == nil then
                db.config[k] = nil
            end
        end

        -- Session variable
        db.sess = {}
        db.lastDisplayUpdate = 0

        -- Load progress bar saved settings
        env.f.drawProgressBar()

        -- Populate options frame
        env.optionsFrame.populateOptions()

        env.f.updateProgress()
        env.f.updateText()
    end
end

function env.onEvent.CHAT_MSG_SYSTEM(...)
    local msg = select(2, ...)
    local raiddiffmsg = ERR_RAID_DIFFICULTY_CHANGED_S:gsub("%%s",".+")
    local dungdiffmsg = ERR_DUNGEON_DIFFICULTY_CHANGED_S:gsub("%%s",".+")

    if msg == INSTANCE_SAVED then -- just got saved
        C_Timer.After(4, env.f.HistoryUpdate)
    elseif (msg:match("^"..raiddiffmsg.."$") or msg:match("^"..dungdiffmsg.."$")) and
            not env.f.histZoneKey() then -- ignore difficulty messages when creating a party while inside an instance
        env.f.HistoryUpdate(true)
    elseif msg:match(TRANSFER_ABORT_TOO_MANY_INSTANCES) then
        env.f.HistoryUpdate(false,true)
    end
end

function env.onEvent.INSTANCE_BOOT_START()
    env.f.HistoryUpdate(true)
end

function env.onEvent.INSTANCE_BOOT_STOP()
    if env.f.InGroup() then
        db.sess.delayedReset = false
    end
end

function env.onEvent.GROUP_ROSTER_UPDATE()
    local db = InstanceHistoryExtraSV
    if db.sess.histInGroup and not env.f.InGroup() and -- ignore failed invites when solo
            not env.f.histZoneKey() then -- left group outside instance, resets now
        env.f.HistoryUpdate(true)
    end
end

function env.onEvent.PLAYER_ENTERING_WORLD()
    C_Timer.After(6, function()
        local db = InstanceHistoryExtraSV
        db.sess.enterLoc = env.f.getLocation()
    end)

    env.f.zoneChanged()
end

function env.onEvent.ZONE_CHANGED_NEW_AREA()
    env.f.zoneChanged()
end

function env.onEvent.RAID_INSTANCE_WELCOME()
    env.f.zoneChanged()
end

function env.onEvent.PLAYER_CAMPING()
    local db = InstanceHistoryExtraSV
    db.lastLoc = env.f.getLocation()
end

function env.onEvent.CHAT_MSG_ADDON(...)
    local pre, msg, _, sender = select(2, ...)
    if pre == env.c.prefix then
        if msg == "GENERATION_ADVANCE" and not UnitIsUnit(sender, "player") then
            env.f.HistoryUpdate(true)
        elseif msg == "RESET_REQUEST" then
            if UnitIsGroupLeader("player") then
                env.chatMsg(string.format("Received reset request from %s. All instances will be reset once %s is offline.", sender, sender))
                env.autoReset = string.match(sender, "^[^%-]+")
            end
        end
    end
end

function env.onEvent.SEND_INSTANCE_RESET_REQUEST()
    local channel = env.f.InGroup()

    if channel then
        C_ChatInfo.SendAddonMessage(env.c.prefix, "RESET_REQUEST", channel)
    end
end

function env.handler(self, event, ...)
    env.onEvent[event](self, ...)
end

-- Create main frame
local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("CHAT_MSG_SYSTEM")
mainFrame:RegisterEvent("INSTANCE_BOOT_START")
mainFrame:RegisterEvent("INSTANCE_BOOT_STOP")
mainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
mainFrame:RegisterEvent("RAID_INSTANCE_WELCOME")
mainFrame:RegisterEvent("PLAYER_CAMPING")
mainFrame:RegisterEvent("CHAT_MSG_ADDON")
--mainFrame:RegisterEvent("SEND_INSTANCE_RESET_REQUEST")
mainFrame:SetScript("OnEvent", env.handler)
C_ChatInfo.RegisterAddonMessagePrefix(env.c.prefix)

-- Create progress bar frame
local progressBar = CreateFrame("Frame", nil, UIParent)
progressBar.textures = {}
progressBar:SetBackdrop({bgFile = env.c.texture})
progressBar:SetBackdropColor(0.3, 0.3, 0.3)
progressBar.toggle = false
local text = progressBar:CreateFontString(nil, "ARTWORK")
text:SetFont(env.c.font, env.configDefaults.fontSize, "OUTLINE")
text:SetTextColor(0.6, 0.6, 0.6)
progressBar.text = text
env.progressBar = progressBar

-- Secret progress bar feature!!!
progressBar:SetScript("OnEnter", function()
    progressBar:RegisterEvent("MODIFIER_STATE_CHANGED")
    -- In case Ctrl is held before entering
    if IsControlKeyDown() then
        progressBar.toggle = true
        env.f.drawProgressBar()
    end
end)
progressBar:SetScript("OnLeave", function()
    progressBar:UnregisterEvent("MODIFIER_STATE_CHANGED")
    -- When cursor leaves frame, revert back if Ctrl is held
    if IsControlKeyDown() then
        progressBar.toggle = false
        env.f.drawProgressBar()
    end
end)
progressBar:SetScript("OnEvent", function(...)
    -- Ignore if it's not Ctrl key
    local key, value = select(3, ...)
    if not key:find("CTRL") then return end

    progressBar.toggle = value == 1 and true or false
    env.f.drawProgressBar()
end)

-- Handle slash command
SLASH_INSTANCEHISTEX1 = "/ihex"
function SlashCmdList.INSTANCEHISTEX(arg)
    local t = {}
    for s in arg:gmatch("([^ ]+)") do
        table.insert(t, s)
    end

    if t[1] == "forcereset" then
        env.chatMsg("Assuming current instance has been reset...")
        env.f.HistoryUpdate(true)
    else
        InterfaceOptionsFrame_OpenToCategory(env.optionsFrame)
    end
end
