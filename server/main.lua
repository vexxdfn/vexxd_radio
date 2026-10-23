local jobCache = {}
local onRadio = {}
local lastJoin, queued = {}, {}
local scale = 10 ^ math.max(0, math.min(2, math.floor(Config.Decimals or 0)))

local function toChannel(value)
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    n = math.floor(n * scale + 0.5) / scale
    if n == math.floor(n) then n = math.floor(n) end
    if n < Config.MinChannel or n > Config.MaxChannel then return nil end
    return n
end

RadioToChannel = toChannel

local function ruleFor(channel)
    return Config.Channels[channel] or Config.Channels[math.floor(channel)]
end

local function cachedJob(src)
    local hit = jobCache[src]
    local now = GetGameTimer()
    if hit and now - hit.at < Config.JobCacheMs then return hit.job end
    local job = Bridge.jobOf(src)
    jobCache[src] = { job = job, at = now }
    return job
end

local function allowedOn(src, channel)
    local rule = ruleFor(channel)
    local hasJobs = rule and rule.jobs and #rule.jobs > 0
    if not rule or (not hasJobs and not rule.ace) then return true end
    if rule.ace and IsPlayerAceAllowed(src, rule.ace) then return true end
    if hasJobs then
        local job = cachedJob(src)
        for i = 1, #rule.jobs do
            if rule.jobs[i] == job then return true end
        end
    end
    return false
end

local function canJoin(src, value)
    if not Inventory.hasRadio(src) then return false, _L('need_radio') end

    local channel = toChannel(value)
    if not channel then return false, _L('invalid_channel') end

    if not allowedOn(src, channel) then
        return false, _L('restricted', tostring(channel))
    end
    return true, nil, channel
end

RadioCanJoin = canJoin
RadioJobOf = cachedJob

local function takeOff(src, event, ...)
    local channel = onRadio[src]
    onRadio[src] = nil
    Guard.clear(src)
    List.remove(src)
    pcall(function() exports['pma-voice']:setPlayerRadio(src, 0) end)
    TriggerClientEvent(event, src, ...)
    return channel
end

local function doJoin(src, value, token)
    local slot = type(value) == 'string' and tonumber(value:match('^p(%d)$'))
    if slot then
        value = Presets and Presets.get(src, slot) or 0
        if value == 0 then
            return TriggerClientEvent('vexxd_radio:client:joinResult', src, token, false, _L('preset_empty', slot))
        end
    end
    local ok, reason, channel = canJoin(src, value)
    if ok then
        onRadio[src] = channel
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

local function recheck(src)
    local channel = onRadio[src]
    if not channel then return end
    if not GetPlayerName(src) then
        onRadio[src] = nil
    elseif Config.RequireItem and not Inventory.hasRadio(src) then
        takeOff(src, 'vexxd_radio:client:forceOff')
    elseif not allowedOn(src, channel) then
        takeOff(src, 'vexxd_radio:client:kicked', channel)
    end
end

-- Job changes take effect right away instead of waiting for the next check.
local function onJobChange(src)
    src = tonumber(src)
    if not src or not onRadio[src] then return end
    jobCache[src] = nil
    recheck(src)
    if onRadio[src] then List.refresh(src) end
end

CreateThread(function()
    while not Bridge.ready do Wait(250) end
    if Bridge.name == 'qb' or Bridge.name == 'qbx' then
        AddEventHandler('QBCore:Server:OnJobUpdate', function(src) onJobChange(src) end)
    elseif Bridge.name == 'esx' then
        AddEventHandler('esx:setJob', function(src) onJobChange(src) end)
    end
end)

local hasRules = next(Config.Channels) ~= nil

CreateThread(function()
    if not Config.RequireItem and not hasRules then return end
    while true do
        Wait(Config.ItemCheckMs)
        for src in pairs(onRadio) do recheck(src) end
    end
end)
