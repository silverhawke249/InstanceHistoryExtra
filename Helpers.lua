local _, env = ...

function env.chatMsg(...)
    print("\124cFFFF0000Instance History\124r: " .. string.format(...))
end

function env.debug(...)
    local db = InstanceHistoryExtraSV

    if db.config.debugMode then
        env.chatMsg(...)
    end
end

function env.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[env.deepcopy(orig_key)] = env.deepcopy(orig_value)
        end
        setmetatable(copy, env.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function env.pad(n)
    local s = ""

    for i = 1, n do
        s = s.."     "
    end

    return s
end

function env.dump(t, depth)
    if DevTools_Dump then
        DevTools_Dump(t)
        return
    end

    if type(t) == "table" then
        if not depth then
            depth = 1
            debug("Table dump: {")
        end

        if depth > 5 then return end

        for k,v in pairs(t) do
            if type(v) == "string" or type(v) == "number" then
                print(pad(depth)..k.."="..v)
            elseif type(v) == "table" then
                print(pad(depth)..k.."={")
                env.dump(v, depth+1)
                print(pad(depth).."}")
            end
        end

        print("}")
    else
        print(t)
    end
end

-- Copies values from t2 to t1, recursively
-- With an option to only overwrite nils
function env.updateTable(t1, t2, onlyNilValues)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if t1[k] == nil then t1[k] = {} end
            env.updateTable(t1[k], v)
        else
            if not onlyNilValues or t1[k] == nil then
                t1[k] = v
            end
        end
    end
end
