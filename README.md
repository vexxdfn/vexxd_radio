# Radio

A handheld radio for FiveM built on [pma-voice](https://github.com/AvarianKnight/pma-voice). Runs standalone or with QBCore, Qbox or ESX. Use the radio item and it's instantly in your hand with a realistic radio. Walk, drive and talk with it open, then put it away and stay on your channel.

## Support

Join the Discord for support: https://discord.gg/TzNJ6Z92Y5

<img width="1874" height="786" alt="Radio" src="https://github.com/user-attachments/assets/d3ac3d4f-34fd-41fb-b72a-5662d469e817" />

## Features

- Item-based, or open with a command/keybind
- Runs standalone or with QBCore, Qbox or ESX
- Walk and drive while it's open (mouse look and weapons are blocked)
- Keypad, channel and volume knobs, nav rocker, mute and power keys
- Type a channel on the keypad or click the screen and use your keyboard
- Restricted channels by job or ACE permission, with labels. Lose the job and you're taken off the channel
- Decimal channels like `100.5`, with sub channels following their main channel's rules
- Saved presets: hold a number to save a channel, press OK to cycle them, or bind keys to jump straight to one
- Goes quiet while you're dead or downed and puts you back on your channel when you get up
- TX/RX lights and an in-game clock on the screen
- On-screen channel list showing everyone on your channel, with whoever's talking lit up (works for several people at once). It moves aside while the radio is open, and its colors can be changed
- Optional `/radioname` to set the name others see on the list (off by default, turn on with `allowNameChange` in the config)
- The radio's screen shows who you're hearing, plus signal and glow effects when sending or receiving
- `/radiolist` to hide or show the list
- List options for serious servers: show only who's talking, limit the list to jobs like police and EMS, and pick what the top of the list shows
- Beep when you start and stop talking (replaces pma-voice mic clicks)
- Translated into English, Spanish, French, German and Portuguese, and easy to add more
- Custom sounds: drop your own clips in `web/sounds/`
- Held prop and animation, switches to an in-vehicle pose automatically
- Closes itself on death, ragdoll, swimming or cuffs
- Works with all major inventories
- Leaving a channel automatically if the radio is dropped, given away or removed
- No database, no bridge resource

## Requirements

- [pma-voice](https://github.com/AvarianKnight/pma-voice)
- QBCore, Qbox or ESX (optional, auto-detected)
- ox_lib (optional, used for notifications)

## Installation

1. Place `vexxd_radio` in your `resources` folder.
2. Add the radio item using the file in `install/` for your inventory (see below).
3. Copy `install/images/radio.png` into your inventory's image folder.
4. Add `ensure vexxd_radio` to your `server.cfg`, after your framework, inventory and `pma-voice`.

| Inventory | Item file | Image folder |
| --- | --- | --- |
| ox_inventory | `install/ox_inventory.lua` → `ox_inventory/data/items.lua` | `ox_inventory/web/images/` |
| qb / ps / lj / qs and other QBCore inventories | `install/qb_items.lua` → `qb-core/shared/items.lua` | your inventory's `html/images/` |
| ESX | run `install/esx_items.sql` in your database | not needed |

## Inventories

The radio registers itself through your framework's usable-item system (QBCore, Qbox or ESX), which all major inventories use. Just add the item the normal way for your inventory.

| Inventory | Supported |
| --- | --- |
| ox_inventory | Yes |
| qs-inventory | Yes |
| qb-inventory | Yes |
| ps-inventory / lj-inventory | Yes |
| codem-inventory | Yes |
| tgiann-inventory | Yes |
| core_inventory | Yes |
| origen_inventory | Yes |
| ESX default inventory | Yes |

### ox_inventory

The `client.export` line in `install/ox_inventory.lua` is optional but recommended. It opens the radio instantly without a trip to the server.

### Anything else

If your inventory doesn't use the framework's usable items, trigger this server event from its item-use callback:

```lua
TriggerServerEvent('vexxd_radio:server:itemUsed')
```

If it also doesn't keep the framework's item functions up to date, tell the radio how to count items in `config.lua`:

```lua
Config.CustomItemCount = function(source, item)
    return exports['your_inventory']:GetItemCount(source, item)
end
```

## Configuration

All options are in `config.lua`.

| Option | Description |
| --- | --- |
| `Config.Framework` | `'auto'`, `'qbx'`, `'qb'`, `'esx'` or `'none'` |
| `Config.Inventory` | `'auto'`, or `'ox'`, `'qs'`, `'qb'`, `'ps'`, `'lj'`, `'codem'`, `'tgiann'`, `'core'`, `'origen'`, `'esx'` |
| `Config.ItemName` | Item that opens the radio |
| `Config.RequireItem` | Require the item to use the radio |
| `Config.Command` | Command that opens the radio |
| `Config.Keybind` | Default key for the command, e.g. `'F10'` (players can rebind it) |
| `Config.ItemCheckMs` | How often players on a channel are checked for still having the radio |
| `Config.JoinCooldownMs` | Minimum time between channel changes per player |
| `Config.BlockOutsideJoins` | Take players off the radio if they join a channel without using this radio |
| `Config.CustomItemCount` | Optional item count function for unsupported inventories |
| `Config.WalkWhileOpen` | Allow moving while the radio is open |
| `Config.DefaultVolume` | Radio volume, 0-100 |
| `Config.MinChannel` / `Config.MaxChannel` | Allowed channel range |
| `Config.Decimals` | Decimal places allowed in a channel: `0`, `1` (100.5) or `2` (100.25) |
| `Config.Presets` | Saved channel slots, how many, and the command/keybind name |
| `Config.OffWhenDown` | Take players off the radio while dead or downed |
| `Config.RejoinOnRevive` | Put them back on the same channel when they get up |
| `Config.Channels` | Restricted channels, their jobs and screen labels |
| `Config.UI.scale` | Size of the radio on screen |
| `Config.UI.keySounds` | Beep on key presses |
| `Config.UI.radioSounds` | Beep when you start and stop talking |
| `Config.RadioList` | Channel list position, size, and the `/radiolist` and `/radioname` commands |

### Restricted channels

```lua
Config.Channels = {
    [1] = { label = 'LEO MAIN', jobs = { 'police' }, ace = 'vexxd_radio.leo' },
    [2] = { label = 'EMS MAIN', jobs = { 'ambulance', 'ems' }, ace = 'vexxd_radio.ems' },
}
```

A player can join if their job is listed **or** they have the ACE permission. Any channel not listed is open to everyone. Use either or both.

Sub channels follow their main channel, so `1.5` uses the rules for `1`. Players who lose the job are taken off the channel right away.

## Channel list

Everything is under `Config.RadioList` in `config.lua`.

| Option | Description |
| --- | --- |
| `color` | Color of the channel tag at the top of the list (blue by default) |
| `talkColor` | Color of whoever is talking (green by default) |
| `header` | `'both'` shows `LEO MAIN 1`, `'label'` shows `LEO MAIN`, `'channel'` shows `1`, `'none'` hides the top |
| `mode` | `'full'` lists everyone on the channel. `'talking'` only pops up with whoever is talking |
| `jobs` | `false` lets everyone see the list. A list like `{ 'police', 'ambulance' }` limits it to those jobs. Everyone else still hears the radio, just without names |
| `ace` | Players with this ace always see the list |

A setup for a serious server:

```lua
header = 'channel',
mode   = 'talking',
jobs   = { 'police', 'ambulance' },
```

## Presets

Each character gets their own saved channels (4 by default, set with `Config.Presets.slots`).

- Hold a number on the keypad to save the current channel to that slot. The screen shows `SAVED P2`.
- Press OK on the radio to jump to the next saved channel.
- `/radiopreset 2` joins preset 2, radio open or not.
- Players can bind a key to each preset in **Settings > Key Bindings > FiveM**.

## Dead or downed

With `Config.OffWhenDown` on, players are taken off the radio when they die or go down (Qbox, QBCore and ESX deaths, plus plain GTA deaths on standalone servers) and can't join a channel until they get up. With `Config.RejoinOnRevive` on, they go back to the same channel when revived.

## Standalone

No framework needed. In `config.lua`:

```lua
Config.Framework = 'none'
Config.RequireItem = false
Config.Keybind = 'F10'
```

Players open the radio with `/radio` or the keybind. Restrict channels with ACE permissions in your `server.cfg`:

```cfg
add_ace group.police vexxd_radio.leo allow
add_principal identifier.license:xxxxxxxx group.police
```

To keep the item requirement without a framework, use ox_inventory, or provide `Config.CustomItemCount`.

## Custom sounds

Place `key_up` and/or `key_down` (`.ogg`, `.mp3` or `.wav`) in `web/sounds/` and restart the resource. `key_up` plays when you start talking, `key_down` when you stop. Missing files fall back to the built-in beeps. Keep clips short and trimmed to the start.

## Controls

| Control | Action |
| --- | --- |
| Keypad | Enter a channel, `.` for a decimal, ✓ to join |
| Hold 1-4 | Save the current channel to that preset |
| Soft keys while typing | DEL, CLR, ENT |
| ✕ key (with `Config.Decimals = 0`) | Delete, in place of `.` |
| Channel knob (scroll) | Tune up or down |
| Volume knob (scroll) | Volume up or down |
| Rocker ▲ ▼ | Tune up or down |
| Rocker ◀ ▶ | Volume down or up |
| OK | Confirm, or jump to the next preset |
| Power key | Leave channel |
| Mute key | Mute / unmute |
| Click the screen | Type a channel with your keyboard |
| ESC | Put the radio away |

## Notes

- pma-voice supports one radio channel at a time, so there is no multi-channel scanning.
- Restricted channels are also checked by pma-voice itself, so a cheat menu calling pma-voice directly can't get onto them. With `Config.BlockOutsideJoins` on, anyone who joins any channel without using this radio is taken off it. Turn it off if another script also puts players on radio channels.
- When `radioSounds` is enabled, pma-voice's mic clicks are turned off for each player and restored when the resource stops.

## License

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
Free to use on any server, including monetized ones. You may not sell or resell this script.

## Translations

Set the language in `config.lua`:

```lua
Config.Locale = 'en' -- 'en', 'es', 'fr', 'de' or 'pt'
```

To add a language, copy `locales/en.lua` to a new file (for example `locales/it.lua`), change `Locales['en']` to `Locales['it']`, translate the text on the right, and set `Config.Locale = 'it'`. Anything you leave out falls back to English. Pull requests with new languages are welcome!

## 💎 Paid Scripts

[🛒 VEXXD SCRIPTS | Tebex Store](https://vexxdscripts.com)
