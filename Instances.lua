local _, env = ...

local f = {}

function f.InGroup()
    if IsInRaid() then return "RAID"
    elseif GetNumGroupMembers() > 0 then return "PARTY"
    else return nil end
end

function f.histZoneKey()
    local instname, insttype, diff, diffname, maxPlayers, playerDifficulty, isDynamicInstance = GetInstanceInfo()

    -- PVP doesn't count
    if insttype == nil or insttype == "none" or insttype == "arena" or insttype == "pvp" then
        return nil
    end

    -- 40-man raids doesn't count
    if insttype == "raid" and maxPlayers == 40 then
        return nil
    end

    -- LFG instances don't count, but Holiday Event counts
    --[[
    if (IsInLFGDungeon() or IsInScenarioGroup()) and diff ~= 19 then
        return nil
    end  ]]

    local db = InstanceHistoryExtraSV

    -- Check if we're locked (using FindInstance so we don't complain about unsaved unknown instances)
    local truename = f.findInstance(instname, insttype == "raid")
    local locked = false
    local inst = truename and db.Instances[truename]
    inst = inst and inst[env.c.thisToon]

    for d = 1, env.c.maxdiff do
        if inst and inst[d] and inst[d].Locked then
            locked = true
        end
    end

    if diff == 1 and maxPlayers == 5 then -- never locked to 5-man regs
        locked = false
    end

    local toonstr = env.c.thisToon

    if db.config.showServer then
        toonstr = strsplit(" - ", toonstr)
    end

    local desc = toonstr .. ": " .. instname

    if diffname and #diffname > 0 then
        desc = desc .. " - " .. diffname
    end

    local key = toonstr..":"..instname..":"..insttype..":"..diff

    if not locked then
        key = key..":"..db.histGeneration
    end

    return key, desc, locked
end

function f.normalizeName(str)
    return str:gsub("%p",""):gsub("%s"," "):gsub("%s%s"," "):gsub("^%s+",""):gsub("%s+$",""):upper()
end

-- some instances (like sethekk halls) are named differently by GetSavedInstanceInfo() and LFGGetDungeonInfoByID()
-- we use the latter name to key our database, and this function to convert as needed
function f.findInstance(name, raid)
    if not name or #name == 0 then return nil end

    local db = InstanceHistoryExtraSV

    local nname = f.normalizeName(name)
    -- first pass, direct match
    local info = db.Instances[name]

    if info then
        return name, info.LFDID
    end

    -- hyperlink id lookup: must precede substring match for ticket 99
    -- (so transInstance can override incorrect substring matches)
    for i = 1, GetNumSavedInstances() do
        local link = GetSavedInstanceChatLink(i) or ""
        local lid,lname = link:match(":(%d+):%d+:%d+\124h%[(.+)%]\124h")
        lname = lname and f.normalizeName(lname)
        lid = lid and tonumber(lid)
        local lfdid = lid and env.c.transInstance[lid]
        if lname == nname and lfdid then
            -- zero idea what was `addon` referring to
            local truename = addon:UpdateInstance(lfdid)
            if truename then
                return truename, lfdid
            end
        end
    end
    -- normalized substring match
    for truename, info in pairs(db.Instances) do
        local tname = f.normalizeName(truename)
        if (tname:find(nname, 1, true) or nname:find(tname, 1, true)) and
                info.Raid == raid then -- Tempest Keep: The Botanica
            --env.debug("FindInstance("..name..") => "..truename)
            return truename, info.LFDID
        end
    end
    return nil
end

function f.generationAdvance()
    local db = InstanceHistoryExtraSV
    env.debug("HistoryUpdate generation advance")
    db.histGeneration = (db.histGeneration + 1) % 100000
    db.sess.delayedReset = false
end

function f.HistoryUpdate(forcereset, forcemesg)
    local db = InstanceHistoryExtraSV
    db.histGeneration = db.histGeneration or 1

    if forcereset and f.histZoneKey() then -- delay reset until we zone out
        env.debug("HistoryUpdate reset delayed")
        db.sess.delayedReset = true
    end

    if (forcereset or db.sess.delayedReset) and not f.histZoneKey() then
        f.generationAdvance()
    elseif db.lastLoc then
        if not db.sess.enterLoc then
            -- delay until enterLoc is defined
            C_Timer.After(1, f.HistoryUpdate)
            return
        end

        if db.sess.enterLoc.instance == db.lastLoc.instance and db.lastLoc.instance >= 0 and db.sess.enterLoc.subzone ~= db.lastLoc.subzone then
            env.debug("Offline forced reset detected.")
            f.generationAdvance()
        else
            env.debug("Location data resolved, no reset detected.")

            --[[if db.config.debug then
                print(db.sess.enterLoc.instance, db.sess.enterLoc.subzone, db.lastLoc.instance, db.lastLoc.subzone)
            end]]
        end

        --[[if db.lastLoc then
            env.debug("lastLoc cleared")
        end]]

        db.lastLoc = nil
    end

    local now = time()

    if db.sess.delayUpdate and now < db.sess.delayUpdate then
        --env.debug("HistoryUpdate delayed")
        C_Timer.After(db.sess.delayUpdate - now + 0.05, f.HistoryUpdate)
        return
    end

    local newzone, newdesc, locked = f.histZoneKey()

    -- touch zone we left
    if db.sess.histLastZone then
        local lz = db.History[db.sess.histLastZone]
        if lz then
            -- if last touched at least 30 mins ago, it's a new instance
            if now - lz.last >= 1800 then
                f.generationAdvance()
                newzone, newdesc, locked = f.histZoneKey()
            else
                lz.last = now
            end
        end
    end

    db.sess.histLastZone = newzone
    db.sess.histInGroup = f.InGroup()

    -- touch/create new zone
    if newzone then
        local nz = db.History[newzone]

        if not nz then
            nz = { create = now, desc = newdesc }
            db.History[newzone] = nz

            if locked then -- creating a locked instance, delete unlocked version
                db.History[newzone..":"..db.histGeneration] = nil
            end
        end

        nz.last = now
    end

    -- reap old zones
    local livecnt = 0
    local oldestkey, oldesttime

    for zk, zi in pairs(db.History) do
        if now > zi.last + env.c.histReapTime then
            env.debug("Reaping %s",zi.desc)
            db.History[zk] = nil
        else
            livecnt = livecnt + 1

            if not oldesttime or zi.last < oldesttime then
                oldestkey = zk
                oldesttime = zi.last
            end
        end
    end

    local oldestrem = oldesttime and (oldesttime + env.c.histReapTime - now)
    local oldestremt = (oldestrem and SecondsToTime(oldestrem,false,false,1)) or "n/a"

    if db.config.debug then
        local msg = livecnt.." live instances, oldest ("..(oldestkey or "none")..") expires in "..oldestremt..". Current Zone="..(newzone or "nil")
        if msg ~= db.sess.lasthistdbg then
            db.sess.lasthistdbg = msg
            env.debug(msg)
        end
    end

    db.sess.histLiveCount = livecnt
    db.sess.histOldest = oldestremt
end

-- fixme localize or something
function f.doExplicitReset(instancemsg, failed)
    if f.InGroup() and not UnitIsGroupLeader("player") then
        return
    end

    local db = InstanceHistoryExtraSV

    if not failed then
        f.HistoryUpdate(true)
    end

    local reportchan = f.InGroup()

    if reportchan then
        if not failed then
            C_ChatInfo.SendAddonMessage(env.c.prefix, "GENERATION_ADVANCE", reportchan)
        end
        if db.config.reportResets then
            local msg = instancemsg or RESET_INSTANCES
            msg = msg:gsub("\1241.+.+","") -- ticket 76, remove |1;; escapes on koKR
            SendChatMessage("All instances have been reset.", reportchan)
        end
    end
end

hooksecurefunc("ResetInstances", f.doExplicitReset)

function f.zoneChanged(extraDelay)
    -- delay updates while settings stabilize
    local db = InstanceHistoryExtraSV

    local waittime = 3 + math.max(0,10 - GetFramerate()) + (extraDelay or 0)
    local d = time() + waittime

    if d > (db.sess.delayUpdate or 0) then
        db.sess.delayUpdate = d
    end

    C_Timer.After(waittime + 0.05, f.HistoryUpdate)
end

function f.getLocation()
    local _, instanceType = GetInstanceInfo()
    local instanceID = select(8, GetInstanceInfo())

    local loc

    if instanceType == "none" then
        loc = {}
        loc.instance = -1
    else
        loc = {}
        loc.instance = instanceID
        loc.subzone = GetSubZoneText()
    end

    return loc
end

function f.doAutoReset()
    if not env.autoReset then
        return
    end

    if not UnitIsGroupLeader("player") then
        env.debug("Player is not leader, auto reset disabled.")
        env.autoReset = nil
        return
    end

    local name = env.autoReset

    if UnitExists(name) then
        if not UnitIsConnected(name) then
            C_Timer.After(1, function()
                ResetInstances()
            end)
            env.autoReset = nil
            return
        end
    else
        env.debug("Sender does not exist, auto reset disabled.")
        env.autoReset = nil
        return
    end
end

function f.updateProgress(noCallback)
    if not noCallback then
        -- Run this function every second
        C_Timer.After(1, f.updateProgress)
    end

    if env.autoReset then
        f.doAutoReset()
    end

    local db = InstanceHistoryExtraSV

    if GetTime() - db.lastDisplayUpdate >= db.config.updateInterval then
        local s = {}

        local count, daycount = 0, 0
        local now = time()

        for _, v in pairs(db.History) do
            if now - 3600 <= v.last and v.last <= now then
                count = count + 1
            end
            daycount = daycount + 1
        end

        s.show = max(count, daycount) >= db.config.displayMin

        if count >= db.config.displayMin then
            s.total = 3600
        else
            s.total = 24*3600
        end

        s.additionalProgress = {}

        local start = now - s.total
        local czk = f.histZoneKey()
        local ordered = {}

        for k,v in pairs(db.History) do
            if k == czk then
                v.last = now
            end

            table.insert(ordered, {k, v.create})
        end

        table.sort(ordered, function(a,b) return a[2]<b[2] end)

        for _, t in pairs(ordered) do
            local k = t[1]
            local v = db.History[k]

            if v.last >= start then
                local o = {}

                --modifying this cuz i get bothered by the little gap at the beginning
                o.max = max(0, min(s.total, v.last - start))
                o.min = max(0, min(s.total, v.create - start))

                table.insert(s.additionalProgress, o)
            end
        end

        --DevTools_Dump(s.additionalProgress)
        db.lastDisplayUpdate = GetTime()

        f.displayProgress(s, daycount)
    end
end

function f.displayProgress(s, n)
    local p = env.progressBar
    local width, height = p:GetSize()
    local db = InstanceHistoryExtraSV
    local c1, c2 = unpack(env.c.colors)

    if not s.show then
        p:Hide()
    else
        p:Show()
        -- Add additional textures if we need more
        while #p.textures < #s.additionalProgress do
            local t = p:CreateTexture()
            t:SetTexture(env.c.texture)
            table.insert(p.textures, t)
        end

        -- Position and align textures correctly, and hide excess textures
        for i, t in ipairs(p.textures) do
            local chunk = s.additionalProgress[i]
            if chunk then
                local chunk_start = chunk.min / s.total
                local chunk_end = chunk.max / s.total
                local chunk_length = (chunk.max - chunk.min) / s.total

                t:SetSize(chunk_length * width, height)
                t:SetPoint("TOPLEFT", p, "TOPLEFT", chunk_start * width, 0)
                if db.config.colorProgress then
                    local c
                    if n == 1 then
                        c = 1
                    else
                        c = (n - #s.additionalProgress + i - 1) / (n - 1)
                    end
                    t:SetVertexColor((c * (c2.r - c1.r) + c1.r) / 255,
                                     (c * (c2.g - c1.g) + c1.g) / 255,
                                     (c * (c2.b - c1.b) + c1.b) / 255)
                else
                    t:SetVertexColor(1, 1, 1)
                end
                t:SetTexCoord(chunk_start, chunk_end, 0, 1)
                t:Show()
            else
                t:Hide()
            end
        end
    end
end

function f.updateText(noCallback)
    if not noCallback then
        C_Timer.After(1, f.updateText)
    end

    local now = time()
    local db = InstanceHistoryExtraSV
    local fs = env.progressBar.text

    local oldestTime, oldestDayTime
    local count = 0
    local daycount = 0

    for _, v in pairs(db.History) do
        if now - 3600 <= v.last then
            count = count + 1
            daycount = daycount + 1

            if not oldestTime or v.last < oldestTime then
                oldestTime = v.last
            end
            if not oldestDayTime or v.last < oldestDayTime then
                oldestDayTime = v.last
            end
        elseif now - 24*3600 <= v.last then
            daycount = daycount + 1

            if not oldestDayTime or v.last < oldestDayTime then
                oldestDayTime = v.last
            end
        end
    end

    local rem = oldestTime and (oldestTime + 3600 - now)
    local remday = oldestDayTime and (oldestDayTime + 24*3600 - now)

    local instanceStr, timestr
    local plural = {[true]='instances', [false]='instance'}

    if daycount > 0 then
        if count > 0 then
            instanceStr = string.format("You have entered %d %s in the last 24 hours,\nand %d %s in the past hour.", daycount, plural[daycount>1], count, plural[count>1])
        else
            instanceStr = string.format("You have entered %d %s in the last 24 hours.", daycount, plural[daycount>1])
        end
    end

    if db.config.reportLockedOnly then
        if daycount == 30 then
            timestr = remday and SecondsToTime(remday):lower() or "n/a"
        elseif count == 5 then
            timestr = rem and SecondsToTime(rem):lower() or "n/a"
        end
    else
        if count == 5 then
            timestr = rem and SecondsToTime(rem):lower() or "n/a"
        elseif daycount > 0 then
            timestr = remday and SecondsToTime(remday):lower() or "n/a"
        end
    end

    if timestr then
        instanceStr = instanceStr .. string.format("\nMore instances will be available in %s.", timestr)
    end

    fs:SetText(instanceStr)
    fs:SetPoint("BOTTOM", env.progressBar, "TOP", 0, 4)
end

function f.drawProgressBar()
    local db = InstanceHistoryExtraSV
    local p = env.progressBar
    local scale = UIParent:GetEffectiveScale()

    p:SetSize(db.config.width / scale, db.config.height / scale)
    p:SetPoint("TOP", UIParent, "TOP", db.config.xOffset / scale, -db.config.yOffset / scale)

    -- redraw the sub-progress bars
    db.lastDisplayUpdate = 0
    f.updateProgress(true)
    f.updateText(true)
end

env.f = f
