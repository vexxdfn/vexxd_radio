Config = {}

-- Language: 'en', 'es', 'fr', 'de' or 'pt'. Add your own by copying locales/en.lua.
Config.Locale = 'en'

Config.Framework = 'auto' -- 'auto', 'qbx', 'qb', 'esx' or 'none' (standalone)
-- 'auto' detects it. Or set one of: 'ox', 'qs', 'qb', 'ps', 'lj', 'codem',
-- 'tgiann', 'core', 'origen', 'esx'
Config.Inventory = 'auto'

Config.ItemName = 'radio'

-- Require the radio item to use the radio. Set false for standalone servers.
Config.RequireItem = true

-- Command that opens the radio. With RequireItem on, the player still needs the item.
Config.Command = 'radio'
Config.Keybind = '' -- default key for the command, e.g. 'F10'. Leave '' for none.

-- How often (ms) players on a channel are checked for still having the radio.
Config.ItemCheckMs = 5000

-- Optional: return how many radios a player has, for inventories not covered.
-- Config.CustomItemCount = function(source, item) return 0 end

-- Walk and drive with the radio open. Mouse look and weapons are blocked while it's up.
Config.WalkWhileOpen = true

Config.DefaultVolume = 50 -- 0-100

Config.MinChannel = 1
Config.MaxChannel = 999

-- Decimal places allowed in a channel: 0 = whole channels only, 1 = 100.5, 2 = 100.25.
-- Sub channels like 1.5 follow the rules of channel 1 below.
Config.Decimals = 1

-- Saved channels players can jump to. Hold a number on the keypad to save the current
-- channel to that slot, press OK to cycle through them, or bind keys to them in
-- Settings > Key Bindings > FiveM. /radiopreset 2 also works.
Config.Presets = {
    enabled = true,
    slots   = 4,
    command = 'radiopreset', -- '' to disable the command and keybinds
}

-- Take players off the radio while they're dead or downed, and put them back on the
-- same channel when they get up.
Config.OffWhenDown = true
Config.RejoinOnRevive = true

-- Restricted channels. Any channel not listed is open to everyone.
-- A player can join if their job is listed OR they have the ace permission.
-- Players who lose the job are taken off the channel.
-- Standalone servers: use ace only (see README).
Config.Channels = {
    [1] = { label = 'LEO MAIN', jobs = { 'police' }, ace = 'vexxd_radio.leo' },
    [2] = { label = 'EMS MAIN', jobs = { 'ambulance', 'ems' }, ace = 'vexxd_radio.ems' },
}

Config.UI = {
    scale       = 1.0,
    keySounds   = true, -- beep on key presses
    radioSounds = true, -- beep when you start and stop talking (replaces pma-voice mic clicks)
}

Config.Prop = {
    model    = `prop_cs_hand_radio`,
    bone     = 28422,
    offset   = { x = 0.0, y = 0.0, z = 0.0 },
    rotation = { x = 0.0, y = 0.0, z = 0.0 },
}

Config.Anim = {
    foot    = { dict = 'cellphone@',          clip = 'cellphone_text_in' },
    vehicle = { dict = 'cellphone@in_car@ds', clip = 'cellphone_text_in' },
}

Config.JobCacheMs = 15000

-- Minimum time (ms) between channel changes per player. Extra requests in between are
-- merged, so only the last channel picked is joined.
Config.JoinCooldownMs = 1000

-- Take anyone off the radio who joins a channel without using this radio (for example a
-- cheat menu calling pma-voice directly). Turn off if another script also puts players
-- on radio channels.
Config.BlockOutsideJoins = true

-- On-screen list of everyone on your channel, with who's talking lit up.
Config.RadioList = {
    enabled         = true,
    position        = 'middle-right', -- 'middle-right', 'middle-left', 'top-right' or 'top-left'
    showWhenClosed  = true,        -- keep the list on screen after putting the radio away
    maxShown        = 12,          -- names shown before it says "+X more"
    color           = '#78aaff',   -- color of the channel tag at the top
    talkColor       = '#41e08a',   -- color of whoever is talking

    -- 'both' shows "LEO MAIN 1", 'label' shows "LEO MAIN", 'channel' shows "1", 'none' hides the top
    header          = 'both',

    -- 'full' lists everyone on the channel. 'talking' only pops up with whoever is
    -- talking, like the caller ID on a real radio.
    mode            = 'full',

    -- Who sees the list. false = everyone, or a list of jobs like { 'police', 'ambulance' }.
    -- Players with the ace below always see it. Everyone else hears the radio without names.
    jobs            = false,
    ace             = 'vexxd_radio.list',

    toggleCommand   = 'radiolist', -- hides/shows the list for that player. '' to disable
    allowNameChange = false,       -- let players pick the name others see on the list (/radioname)
    nameCommand     = 'radioname', -- /radioname Roger Scott  (/radioname on its own resets it)
    maxNameLength   = 24,
}
