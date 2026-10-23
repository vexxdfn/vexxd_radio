local P = Config.Presets
if not (P and P.enabled) then return end

local slots = math.max(1, math.min(9, math.floor(P.slots or 4)))
local last = {}

local function key(id) return 'radiopresets:' .. id end

local function load(src)
    local id = Bridge.idOf(src)
    if not id then return nil end
    local raw = GetResourceKvpString(key(id))
    local ok, data = pcall(json.decode, raw or '[]')
    local out = {}
    for i = 1, slots do
        local ch = ok and type(data) == 'table' and RadioToChannel(data[i]) or nil
        out[i] = ch or 0
    end
    return out, id
end

Presets = {}

function Presets.get(src, slot)
    local list = load(src)
    return list and list[slot] or 0
end

RegisterNetEvent('vexxd_radio:server:presets', function()
    local src = source
    local list = load(src)
    if list then TriggerClientEvent('vexxd_radio:client:presets', src, list) end
end)

RegisterNetEvent('vexxd_radio:server:savePreset', function(slot, value)
    local src = source
    local now = GetGameTimer()
    if last[src] and now - last[src] < 500 then return end
    last[src] = now

    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > slots then return end
    local channel = RadioToChannel(value)
    if not channel then return end

    local list, id = load(src)
    if not list then
        return TriggerClientEvent('vexxd_radio:client:notify', src, _L('still_loading'))
    end
    list[slot] = channel
    SetResourceKvp(key(id), json.encode(list))
    TriggerClientEvent('vexxd_radio:client:presets', src, list)
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
