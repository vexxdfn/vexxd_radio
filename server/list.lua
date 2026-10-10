local L = Config.RadioList
List = {}

local channelOf, members, names = {}, {}, {}

local function kvpKey(id) return 'radioname:' .. id end

local function displayName(src)
    if names[src] then return names[src] end
    local id = Bridge.idOf(src)
    local custom = id and GetResourceKvpString(kvpKey(id))
    local name = (custom and custom ~= '') and custom or Bridge.nameOf(src)
    names[src] = name
    return name
end

local function snapshot(ch)
    local out = {}
    for src in pairs(members[ch] or {}) do
        out[#out + 1] = { id = src, name = displayName(src) }
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

function List.push(ch)
    if not L.enabled or not members[ch] then return end
    local list = snapshot(ch)
    for src in pairs(members[ch]) do
        TriggerClientEvent('vexxd_radio:client:list', src, ch, list)
    end
end

function List.remove(src, silent)
    local ch = channelOf[src]
    if not ch then return end
    channelOf[src] = nil
    if members[ch] then
        members[ch][src] = nil
        if not next(members[ch]) then members[ch] = nil end
    end
    if not silent then TriggerClientEvent('vexxd_radio:client:list', src, 0, {}) end
    List.push(ch)
end

function List.set(src, ch)
    if channelOf[src] == ch then
        if L.enabled then TriggerClientEvent('vexxd_radio:client:list', src, ch, snapshot(ch)) end
        return
    end
    names[src] = nil
    if channelOf[src] then List.remove(src, true) end
    channelOf[src] = ch
    members[ch] = members[ch] or {}
    members[ch][src] = true
    List.push(ch)
end

AddEventHandler('playerDropped', function()
    local src = source
    List.remove(src, true)
    names[src] = nil
end)

if L.enabled and L.allowNameChange and L.nameCommand and L.nameCommand ~= '' then
    local last = {}

    RegisterCommand(L.nameCommand, function(src, args)
        if src == 0 then return end
        local now = os.time()
        if last[src] and now - last[src] < 3 then return end
        last[src] = now

        local id = Bridge.idOf(src)
        if not id then
            return TriggerClientEvent('vexxd_radio:client:notify', src, _L('still_loading'))
        end

        local name = table.concat(args, ' ')
            :gsub('[%c<>"`\\{}]', '')
            :gsub('%s+', ' ')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
        name = name:sub(1, L.maxNameLength or 24)

        if name == '' then
            DeleteResourceKvp(kvpKey(id))
            names[src] = nil
            TriggerClientEvent('vexxd_radio:client:notify', src, _L('name_reset', Bridge.nameOf(src)), 'inform')
        else
            SetResourceKvp(kvpKey(id), name)
            names[src] = nil
            TriggerClientEvent('vexxd_radio:client:notify', src, _L('name_changed', name), 'inform')
        end

        if channelOf[src] then List.push(channelOf[src]) end
    end, false)

    AddEventHandler('playerDropped', function() last[source] = nil end)
end
