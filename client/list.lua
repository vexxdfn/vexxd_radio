local L = Config.RadioList
RadioList = {}

local hidden = GetResourceKvpInt('listHidden') == 1
local current, members = 0, {}

local function labelFor(ch)
    local def = Config.Channels[ch] or Config.Channels[math.floor(ch)]
    return def and def.label or nil
end

function RadioList.refresh()
    if not L.enabled then return end
    local show = current > 0 and not hidden and (L.showWhenClosed or RadioIsOpen())
    SendNUIMessage({
        action = 'list',
        show = show,
        channel = current,
        label = labelFor(current),
        members = members,
        me = GetPlayerServerId(PlayerId()),
        position = L.position,
        max = L.maxShown,
        color = L.color,
        talkColor = L.talkColor,
        header = L.header or 'both',
        mode = L.mode or 'full',
        strings = UIStrings(),
    })
end

RegisterNetEvent('vexxd_radio:client:list', function(ch, list)
    current = tonumber(ch) or 0
    members = type(list) == 'table' and list or {}
    RadioList.refresh()
end)

if L.enabled and L.toggleCommand and L.toggleCommand ~= '' then
    RegisterCommand(L.toggleCommand, function()
        hidden = not hidden
        SetResourceKvpInt('listHidden', hidden and 1 or 0)
        RadioList.refresh()
    end, false)
end

CreateThread(function()
    if not L.enabled then return end
    if L.toggleCommand and L.toggleCommand ~= '' then
        TriggerEvent('chat:addSuggestion', '/' .. L.toggleCommand, _L('suggest_list'))
    end
    if L.allowNameChange and L.nameCommand and L.nameCommand ~= '' then
        TriggerEvent('chat:addSuggestion', '/' .. L.nameCommand, _L('suggest_name'), {
            { name = 'name', help = _L('suggest_name_arg') },
        })
    end
end)
