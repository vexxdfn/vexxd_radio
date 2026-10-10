Guard = {}

local approved = {}

function Guard.allow(src, channel) approved[src] = channel end
function Guard.clear(src) approved[src] = nil end

local function voiceRunning()
    return GetResourceState('pma-voice') == 'started'
end

local function addChecks()
    if not voiceRunning() then return end
    for ch in pairs(Config.Channels) do
        local channel = ch
        local ok = pcall(function()
            exports['pma-voice']:addChannelCheck(channel, function(src)
                return (RadioCanJoin(src, channel)) == true
            end)
        end)
        if not ok then
            print(('^1[vexxd_radio]^7 Could not protect channel %s. Update pma-voice to a version with addChannelCheck.'):format(channel))
        end
    end
end

local function removeChecks()
    if not voiceRunning() then return end
    for ch in pairs(Config.Channels) do
        pcall(function() exports['pma-voice']:removeChannelCheck(ch) end)
    end
end

CreateThread(function()
    for _ = 1, 20 do
        if voiceRunning() then break end
        Wait(500)
    end
    addChecks()
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'pma-voice' then
        approved = {}
        SetTimeout(1000, addChecks)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeChecks() end
end)

AddEventHandler('playerDropped', function()
    approved[source] = nil
end)

if Config.BlockOutsideJoins then
    AddStateBagChangeHandler('radioChannel', nil, function(bagName, _, value)
        local src = GetPlayerFromStateBagName(bagName)
        if not src or src == 0 then return end
        local channel = tonumber(value) or 0
        if channel == 0 or approved[src] == channel then return end

        SetTimeout(0, function()
            if not GetPlayerName(src) or approved[src] == channel then return end
            if (tonumber(Player(src).state.radioChannel) or 0) ~= channel then return end
            pcall(function() exports['pma-voice']:setPlayerRadio(src, 0) end)
            TriggerClientEvent('vexxd_radio:client:forceOff', src)
        end)
    end)
end
