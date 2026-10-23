local L = Config.RadioList
List = {}

local channelOf, members, names = {}, {}, {}

local function kvpKey(id) return 'radioname:' .. id end

local function clean(text, max)
    return text
        :gsub('[%c<>"`\\{}]', '')
        :gsub('%s+', ' ')
        :gsub('^%s+', '')
        :gsub('%s+$', '')
        :sub(1, max)
end

local function displayName(src)
    if names[src] then return names[src] end
    local id = Bridge.idOf(src)
    local custom = id and GetResourceKvpString(kvpKey(id))
    local name = (custom and custom ~= '') and custom or Bridge.nameOf(src)
    names[src] = name
    return name
end

local function canSee(src)
    if type(L.jobs) ~= 'table' or #L.jobs == 0 then return true end
    if L.ace and L.ace ~= '' and IsPlayerAceAllowed(src, L.ace) then return true end
    local job = RadioJobOf and RadioJobOf(src)
    for i = 1, #L.jobs do
        if L.jobs[i] == job then return true end
    end
    return false
end

local function snapshot(ch)
    local out = {}
    for src in pairs(members[ch] or {}) do
        out[#out + 1] = { id = src, name = displayName(src) }
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

local function send(src, ch, list)
    if canSee(src) then
        TriggerClientEvent('vexxd_radio:client:list', src, ch, list or snapshot(ch))
    else
        TriggerClientEvent('vexxd_radio:client:list', src, 0, {})
    end
end

function List.push(ch)
    if not L.enabled or not members[ch] then return end
    local list = snapshot(ch)
    for src in pairs(members[ch]) do send(src, ch, list) end
end

-- Called when a player's job changes: their name and whether they can see the list may have changed.
function List.refresh(src)
    names[src] = nil
    if channelOf[src] then List.push(channelOf[src]) end
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
        if L.enabled then send(src, ch) end
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

local last = {}
AddEventHandler('playerDropped', function() last[source] = nil end)

local function cooldown(src)
    local now = os.time()
    if last[src] and now - last[src] < 3 then return true end
    last[src] = now
    return false
end

if L.enabled and L.allowNameChange and L.nameCommand and L.nameCommand ~= '' then
    RegisterCommand(L.nameCommand, function(src, args)
        if src == 0 or cooldown(src) then return end

        local id = Bridge.idOf(src)
        if not id then
            return TriggerClientEvent('vexxd_radio:client:notify', src, _L('still_loading'))
        end

        local name = clean(table.concat(args, ' '), L.maxNameLength or 24)
        if name == '' then
            DeleteResourceKvp(kvpKey(id))
            TriggerClientEvent('vexxd_radio:client:notify', src, _L('name_reset', Bridge.nameOf(src)), 'inform')
        else
            SetResourceKvp(kvpKey(id), name)
            TriggerClientEvent('vexxd_radio:client:notify', src, _L('name_changed', name), 'inform')
        end
        List.refresh(src)
    end, false)
end
