local addonName, env = ...

env.configDefaults = {
    displayMin       = 2,
    updateInterval   = 5,
    debug            = false,
    showServer       = false,
    reportResets     = false,
    reportLockedOnly = false,
    colorProgress    = false,
    width            = 300,
    height           = 15,
    xOffset          = 0,
    yOffset          = 55,
}

-- EVENT HANDLERS --
env.onEvent = {}

function env.onEvent.ADDON_LOADED(s, n)
    if n == addonName then
        -- Instantiate database
        local db = InstanceHistoryExtraSV or {}

        db.histGeneration = db.histGeneration or 1
        db.History = db.History or {}
        db.Instances = db.Instances or {}
        db.config = db.config or {}
        -- Fill in missing values
        env.updateTable(db.config, env.configDefaults, true)

        -- Session variable
        db.sess = {}
        db.lastDisplayUpdate = 0

        -- Load progress bar saved settings
        env.f.drawProgressBar()

        -- Populate options frame
        env.optionsFrame.populateOptions()

        InstanceHistoryExtraSV = db
        env.f.updateProgress()
        env.f.updateText()
    end
end

function env.onEvent.CHAT_MSG_SYSTEM(s, msg)
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
    db.lastLoc = env.f.getLocation()
end

function env.onEvent.CHAT_MSG_ADDON(s, pre, msg, channel, sender)
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
local text = progressBar:CreateFontString(nil, "ARTWORK")
text:SetFontObject(SystemFont_Outline_Small)
text:SetTextColor(0.6, 0.6, 0.6)
progressBar.text = text
env.progressBar = progressBar

-- Handle slash command
SLASH_INSTANCEHISTEX1 = "/ihex"
function SlashCmdList.INSTANCEHISTEX(arg)
    local t = {}
    for s in arg:gmatch("([^ ]+)") do
        table.insert(t, s)
    end

    if t[1] == "forcereset" then
        env.chatMsg("Assuming instance has been reset.")
        env.f.HistoryUpdate(true)
    elseif t[1] == "repop" then
        env.optionsFrame.populateOptions()
    else
        InterfaceOptionsFrame_OpenToCategory(env.optionsFrame)
    end
end
