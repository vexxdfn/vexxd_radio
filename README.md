# vexxd_radio

A handheld radio for FiveM built on [pma-voice](https://github.com/AvarianKnight/pma-voice). Runs standalone or with QBCore, Qbox or ESX. Use the radio item and it's instantly in your hand with a realistic radio. Walk, drive and talk with it open, then put it away and stay on your channel.

# Support
Join discord for support! http://discord.gg/TzNJ6Z92Y5

<img width="1874" height="786" alt="vexxd_phone1" src="https://github.com/user-attachments/assets/d3ac3d4f-34fd-41fb-b72a-5662d469e817" />
<img width="1255" height="767" alt="v1 1 0" src="https://github.com/user-attachments/assets/0ca4797a-15be-4b3f-ab19-5edbb3aef0b0" />


## Features

- Item-based, or open with a command/keybind
- Runs standalone or with QBCore, Qbox or ESX
- Walk and drive while it's open (mouse look and weapons are blocked)
- Keypad, channel and volume knobs, nav rocker, mute and power keys
- Type a channel on the keypad or click the screen and use your keyboard
- Restricted channels by job or ACE permission, with labels
- TX/RX lights and an in-game clock on the screen
- On-screen channel list showing everyone on your channel, with whoever's talking lit up (works for several people at once)
- Optional `/radioname` to set the name others see on the list (off by default, turn on with `allowNameChange` in the config)
- The radio's screen shows who you're hearing, plus signal and glow effects when sending or receiving
- `/radiolist` to hide or show the list
- Beep when you start and stop talking (replaces pma-voice mic clicks)
- Translated into English, Spanish, French, German and Portuguese, and easy to add more
- Custom sounds: drop your own clips in `web/sounds/`
- Held prop and animation, switches to an in-vehicle pose automatically
- Closes itself on death, ragdoll, swimming or cuffs
- Works with all major inventories
- Leaving a channel automatically if the radio is dropped, given away or removed
- No database, no bridge resource
- 0.00ms resmon while idle

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
| `Config.Channels` | Restricted channels, their jobs and screen labels |
| `Config.UI.scale` | Size of the radio on screen |
| `Config.UI.keySounds` | Beep on key presses |
| `Config.UI.radioSounds` | Beep when you start and stop talking |

### Restricted channels

```lua
Config.Channels = {
    [1] = { label = 'LEO MAIN', jobs = { 'police' }, ace = 'vexxd_radio.leo' },
    [2] = { label = 'EMS MAIN', jobs = { 'ambulance', 'ems' }, ace = 'vexxd_radio.ems' },
}
```

A player can join if their job is listed **or** they have the ACE permission. Any channel not listed is open to everyone. Use either or both.

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
| Keypad | Enter a channel, ✓ to join, ✕ to delete |
| Channel knob (scroll) | Tune up or down |
| Volume knob (scroll) | Volume up or down |
| Rocker ▲ ▼ | Tune up or down |
| Rocker ◀ ▶ | Volume down or up |
| OK | Confirm |
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

Looking for more scripts? Check out the full collection of paid scripts available on my Tebex store!

🛒 **[VEXXD SCRIPTS | Tebex Store](https://vexxd-scripts.tebex.store/)**


