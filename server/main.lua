local jobCache = {}
local onRadio = {}
local lastJoin, queued = {}, {}

local function toChannel(value)
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    n = math.floor(n)
    if n < Config.MinChannel or n > Config.MaxChannel then return nil end
    return n
end

local function cachedJob(src)
    local hit = jobCache[src]
    local now = GetGameTimer()
    if hit and now - hit.at < Config.JobCacheMs then return hit.job end
    local job = Bridge.jobOf(src)
    jobCache[src] = { job = job, at = now }
    return job
end

local function canJoin(src, value)
    if not Inventory.hasRadio(src) then return false, _L('need_radio') end

    local channel = toChannel(value)
    if not channel then return false, _L('invalid_channel') end

    local rule = Config.Channels[channel]
    local hasJobs = rule and rule.jobs and #rule.jobs > 0
    if not rule or (not hasJobs and not rule.ace) then
        return true, nil, channel
    end

    if rule.ace and IsPlayerAceAllowed(src, rule.ace) then
        return true, nil, channel
    end

    if hasJobs then
        local job = cachedJob(src)
        for i = 1, #rule.jobs do
            if rule.jobs[i] == job then return true, nil, channel end
        end
    end

    return false, _L('restricted', channel)
end

RadioCanJoin = canJoin

local function doJoin(src, value, token)
    local ok, reason, channel = canJoin(src, value)
    if ok then
        onRadio[src] = true
        Guard.allow(src, channel)
        List.set(src, channel)
    end
    TriggerClientEvent('vexxd_radio:client:joinResult', src, token, ok, ok and channel or reason)
end

RegisterNetEvent('vexxd_radio:server:join', function(value, token)
    local src = source
    local now = GetGameTimer()
    local wait = (lastJoin[src] or -math.huge) + (Config.JoinCooldownMs or 1000) - now
    if wait <= 0 then
        lastJoin[src] = now
        return doJoin(src, value, token)
    end

    local prev = queued[src]
    queued[src] = { value = value, token = token }
    if prev then
        TriggerClientEvent('vexxd_radio:client:joinResult', src, prev.token, false, nil)
        return
    end
    SetTimeout(math.ceil(wait), function()
        local q = queued[src]
        queued[src] = nil
        if not q or not GetPlayerName(src) then return end
        lastJoin[src] = GetGameTimer()
        doJoin(src, q.value, q.token)
    end)
end)

RegisterNetEvent('vexxd_radio:server:left', function()
    onRadio[source] = nil
    Guard.clear(source)
    List.remove(source)
end)

AddEventHandler('playerDropped', function()
    jobCache[source] = nil
    onRadio[source] = nil
    lastJoin[source] = nil
    queued[source] = nil
    Guard.clear(source)
end)

CreateThread(function()
    if not Config.RequireItem then return end
    while true do
        Wait(Config.ItemCheckMs)
        for src in pairs(onRadio) do
            if not GetPlayerName(src) then
                onRadio[src] = nil
            elseif not Inventory.hasRadio(src) then
                onRadio[src] = nil
                Guard.clear(src)
                List.remove(src)
                TriggerClientEvent('vexxd_radio:client:forceOff', src)
            end
        end
    end
end)
