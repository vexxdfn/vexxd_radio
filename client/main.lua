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
        scale = Config.UI.scale,
        sounds = Config.UI.keySounds,
        strings = UIStrings(),
    })

    pushClock(true)
    RadioList.refresh()
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

local function leaveChannel()
    if channel == 0 then return end
    channel = 0
    Voice.leave()
    Voice.resetRx()
    TriggerServerEvent('vexxd_radio:server:left')
end

local function forceOff()
    if isOpen then closeRadio() end
    leaveChannel()
end

exports('useRadio', toggle)
RegisterNetEvent('vexxd_radio:client:toggleRadio', toggle)
RegisterNetEvent('vexxd_radio:client:forceOff', forceOff)
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

    requestJoin(value, function(ok, result)
        if ok then
            channel = result
            Voice.join(channel)
            Voice.resetRx()
        elseif result ~= nil then
            notify(result)
        end
        cb({ ok = ok, channel = channel })
    end)
end)

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
