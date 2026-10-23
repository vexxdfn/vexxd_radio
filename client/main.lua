local isOpen = false
local channel = 0

function RadioIsOpen() return isOpen end
local volume = Config.DefaultVolume
local prop = nil
local playing = nil
local lastMinute = -1
local openRadio, closeRadio

local labels = {}
for ch, def in pairs(Config.Channels) do
    if def.label then labels[tostring(ch)] = def.label end
end

local BLOCKED = {
    1, 2, 24, 25, 257, 263, 140, 141, 142, 143,
    14, 15, 16, 17, 37, 68, 69, 70, 91, 92, 106,
    199, 200, 322,
}

local notifyWith = 'feed'
if GetResourceState('vexxd_notify') == 'started' then
    notifyWith = 'vexxd'
elseif GetResourceState('ox_lib') == 'started' then
    notifyWith = 'ox'
end

local function notify(message, kind)
    if notifyWith == 'vexxd' then
        if pcall(function() exports.vexxd_notify:Notify({ type = kind or 'error', description = message }) end) then return end
    elseif notifyWith == 'ox' then
        if pcall(function() exports.ox_lib:notify({ type = kind or 'error', description = message }) end) then return end
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

local pending, nextToken = {}, 0

local function requestJoin(value, cb)
    nextToken = nextToken + 1
    local token = nextToken
    pending[token] = cb
    SetTimeout(8000, function()
        if pending[token] then
            pending[token] = nil
            cb(false, _L('timed_out'))
        end
    end)
    TriggerServerEvent('vexxd_radio:server:join', value, token)
end

RegisterNetEvent('vexxd_radio:client:joinResult', function(token, ok, result)
    local cb = pending[token]
    if not cb then return end
    pending[token] = nil
    cb(ok, result)
end)

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local deadline = GetGameTimer() + 500
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    return HasModelLoaded(model)
end

CreateThread(function()
    RequestModel(Config.Prop.model)
    RequestAnimDict(Config.Anim.foot.dict)
    RequestAnimDict(Config.Anim.vehicle.dict)
end)

local function wantedAnim(ped)
    return IsPedInAnyVehicle(ped, false) and Config.Anim.vehicle or Config.Anim.foot
end

local function playHold(ped)
    local anim = wantedAnim(ped)
    if not loadDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 50, 0.0, false, false, false)
    playing = anim
end

local function attachProp(ped)
    if prop and DoesEntityExist(prop) then return end
    if not loadModel(Config.Prop.model) then return end

    local coords = GetEntityCoords(ped)
    prop = CreateObject(Config.Prop.model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(prop, false, false)

    local o, r = Config.Prop.offset, Config.Prop.rotation
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, Config.Prop.bone),
        o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true)
end

local function raise()
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    attachProp(ped)
    playHold(ped)
end

local function lower()
    local ped = PlayerPedId()
    if playing then
        StopAnimTask(ped, playing.dict, playing.clip, 4.0)
        playing = nil
    end
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, false)
        DeleteEntity(prop)
    end
    prop = nil
end

local function pushClock(force)
    local minute = GetClockMinutes()
    if force or minute ~= lastMinute then
        lastMinute = minute
        SendNUIMessage({ action = 'clock', h = GetClockHours(), m = minute })
    end
end

local function controlLoop()
    local nextCheck = 0
    while isOpen do
        for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end

        local now = GetGameTimer()
        if now >= nextCheck then
            nextCheck = now + 400
            local ped = PlayerPedId()

            if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedCuffed(ped) then
                closeRadio()
                break
            end

            local want = wantedAnim(ped)
            if playing ~= want or not IsEntityPlayingAnim(ped, want.dict, want.clip, 3) then
                if playing and playing ~= want then
                    StopAnimTask(ped, playing.dict, playing.clip, 4.0)
                end
                playHold(ped)
            end

            if not prop or not DoesEntityExist(prop) then attachProp(ped) end
            pushClock(false)
        end

        Wait(0)
    end
end

-- ESC closes the radio on key down, but the pause menu opens on key up.
-- Block the pause keys briefly after closing so only the radio closes.
local function swallowPause()
    CreateThread(function()
        local deadline = GetGameTimer() + 500
        while GetGameTimer() < deadline do
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        end
    end)
end

function openRadio()
    if isOpen then return end
    isOpen = true

    SetNuiFocus(true, true)
    if Config.WalkWhileOpen then SetNuiFocusKeepInput(true) end

    SendNUIMessage({
        action = 'open',
        channel = channel,
        volume = volume,
        labels = labels,
        min = Config.MinChannel,
        max = Config.MaxChannel,
        decimals = Config.Decimals or 0,
        presets = Config.Presets and Config.Presets.enabled and (Config.Presets.slots or 4) or 0,
        scale = Config.UI.scale,
        sounds = Config.UI.keySounds,
        strings = UIStrings(),
    })

    pushClock(true)
    RadioList.refresh()
    if Config.Presets and Config.Presets.enabled then TriggerServerEvent('vexxd_radio:server:presets') end
    CreateThread(raise)
    CreateThread(controlLoop)
end

function closeRadio()
    if not isOpen then return end
    isOpen = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    RadioList.refresh()
    swallowPause()
    lower()
end

local lastToggle = 0

-- Some inventories fire both the item export and the framework handler.
-- Ignore a second toggle arriving right after the first.
local function toggle()
    local now = GetGameTimer()
    if now - lastToggle < 400 then return end
    lastToggle = now
    if isOpen then closeRadio() else openRadio() end
end

local function setChannel(value)
    channel = value
    Voice.join(channel)
    Voice.resetRx()
    if isOpen then SendNUIMessage({ action = 'channel', channel = channel }) end
end

local function leaveChannel()
    if channel == 0 then return end
    channel = 0
    Voice.leave()
    Voice.resetRx()
    TriggerServerEvent('vexxd_radio:server:left')
    if isOpen then SendNUIMessage({ action = 'channel', channel = 0 }) end
end

local function forceOff()
    if isOpen then closeRadio() end
    leaveChannel()
end

-- Off when dead or downed, back on the same channel when up again.
local downChannel = nil
local downBy = {}
local isDown = false

local function updateDown()
    local now = false
    for _, v in pairs(downBy) do if v then now = true break end end
    if now == isDown then return end
    isDown = now
    if isDown then
        if channel ~= 0 then
            downChannel = Config.RejoinOnRevive and channel or nil
            forceOff()
            notify(_L('down_off'), 'inform')
        elseif isOpen then
            closeRadio()
        end
    elseif downChannel then
        local back = downChannel
        downChannel = nil
        requestJoin(back, function(ok, result)
            if ok then setChannel(result) end
        end)
    end
end

local function setDown(reason, value)
    if not Config.OffWhenDown then return end
    downBy[reason] = value == true
    updateDown()
end

if Config.OffWhenDown then
    RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
        local m = type(data) == 'table' and data.metadata
        if m then setDown('meta', m.isdead == true or m.inlaststand == true) end
    end)
    AddEventHandler('esx:onPlayerDeath', function() setDown('esx', true) end)
    AddEventHandler('esx:onPlayerSpawn', function() setDown('esx', false) end)
    AddStateBagChangeHandler('isDead', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
        setDown('state', value == true)
    end)

    CreateThread(function()
        while true do
            if channel ~= 0 or downChannel or isDown then
                setDown('ped', IsEntityDead(PlayerPedId()))
                Wait(1000)
            else
                Wait(2500)
            end
        end
    end)
end

exports('useRadio', toggle)
RegisterNetEvent('vexxd_radio:client:toggleRadio', toggle)
RegisterNetEvent('vexxd_radio:client:forceOff', forceOff)
RegisterNetEvent('vexxd_radio:client:kicked', function(ch)
    leaveChannel()
    notify(_L('removed', tostring(ch)))
end)

RegisterNetEvent('vexxd_radio:client:presets', function(list)
    SendNUIMessage({ action = 'presets', list = list })
end)
RegisterNetEvent('vexxd_radio:client:notify', notify)

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, function()
        TriggerServerEvent('vexxd_radio:server:itemUsed')
    end, false)

    if Config.Keybind and Config.Keybind ~= '' then
        RegisterKeyMapping(Config.Command, _L('keymap_open'), 'keyboard', Config.Keybind)
    end
end

AddEventHandler('ox_inventory:itemCount', function(itemName, count)
    if itemName == Config.ItemName and (count or 0) <= 0 then forceOff() end
end)

RegisterNUICallback('close', function(_, cb)
    closeRadio()
    cb({ ok = true })
end)

RegisterNUICallback('typing', function(body, cb)
    if isOpen and Config.WalkWhileOpen then
        SetNuiFocusKeepInput(not (body and body.value == true))
    end
    cb({ ok = true })
end)

RegisterNUICallback('join', function(body, cb)
    local value = tonumber(body and body.channel)
    if not value then return cb({ ok = false, channel = channel }) end

    if isDown then
        notify(_L('down_off'))
        return cb({ ok = false, channel = channel })
    end
    requestJoin(value, function(ok, result)
        if ok then
            setChannel(result)
        elseif result ~= nil then
            notify(result)
        end
        cb({ ok = ok, channel = channel })
    end)
end)

RegisterNUICallback('savePreset', function(body, cb)
    local slot = tonumber(body and body.slot)
    if slot and channel ~= 0 then TriggerServerEvent('vexxd_radio:server:savePreset', slot, channel) end
    cb({ ok = true })
end)

local P = Config.Presets
if P and P.enabled and P.command and P.command ~= '' then
    local slots = math.max(1, math.min(9, math.floor(P.slots or 4)))

    local function usePreset(slot)
        slot = math.floor(tonumber(slot) or 0)
        if slot < 1 or slot > slots then return end
        if isDown then return notify(_L('down_off')) end
        requestJoin('p' .. slot, function(ok, result)
            if ok then
                setChannel(result)
                notify(_L('preset_join', tostring(result)), 'inform')
            elseif result ~= nil then
                notify(result)
            end
        end)
    end

    RegisterCommand(P.command, function(_, args) usePreset(args[1]) end, false)
    for i = 1, slots do
        RegisterCommand(P.command .. i, function() usePreset(i) end, false)
        RegisterKeyMapping(P.command .. i, _L('keymap_preset', i), 'keyboard', '')
    end

    CreateThread(function()
        TriggerEvent('chat:addSuggestion', '/' .. P.command, _L('suggest_preset'), {
            { name = 'slot', help = ('1-%d'):format(slots) },
        })
        for i = 1, slots do TriggerEvent('chat:removeSuggestion', '/' .. P.command .. i) end
    end)
end

RegisterNUICallback('leave', function(_, cb)
    leaveChannel()
    cb({ ok = true })
end)

RegisterNUICallback('volume', function(body, cb)
    local value = tonumber(body and body.value) or volume
    volume = math.max(0, math.min(100, math.floor(value)))
    Voice.setVolume(volume)
    cb({ ok = true, volume = volume })
end)

CreateThread(function()
    for _ = 1, 24 do
        if Voice.available then
            Voice.setVolume(volume)
            return
        end
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then closeRadio() end
    if channel ~= 0 then Voice.leave() end
end)
