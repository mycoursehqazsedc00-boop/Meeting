# Meeting (Patched for WoW 1.12 / Turtle WoW)

> A group-finder / LFG assistant for Vanilla WoW 1.12.x and Turtle WoW that broadcasts and browses group listings over a shared addon channel (`LFT`) and passively detects LFG/LFM messages in chat.

## Client Mods Used

**None.** This addon runs on stock WoW 1.12.x (`Lua 5.0`) using native client APIs only.

*(Optional addon integration: `WoWTranslate` for translating activity names, leader names, descriptions, and applicant notes.)*

## Features

- **Group Listings (`Browse` & `Manage`):** Create, edit, and browse listings for Dungeons, Raids, Party Quests, Raid Quests, World Bosses, and other activities, with member count, class composition tooltip, and Hardcore (`HC`) indicator.
- **Multi-Activity & Keyword Filtering:** Filter by a single activity, multiple activities across categories, or live text search (with IME composition delay handling).
- **Passive Chat Scanning:** Detects LFG/LFM-style messages and quest links (`|Hquest:...|h`) in `world` / `china` / `lfg` and `hardcore` channels, surfacing listings even from players without the addon.
- **Role-Based Applications:** Apply to listings with Tank / Healer / Damage role selection and an optional note; leaders can accept, decline, or double-click to whisper applicants.
- **Block-Word Filtering:** Filter out unwanted listings by leader name or description via UI (`Block Words`) or `/meeting block` commands.
- **UI Customization:** Resizable main window, movable floating `Meeting` button, minimap button (with `MinimapButtonFrame` support), configurable font size, background opacity, and Blizzard-style borders.
- **Protocol Compatibility:** Fully backward- and forward-compatible with all `Meeting` versions over the shared `LFT` channel.

## What Was Added / Improved

- **Fixed:**
  - `OnMemberChange` unassigned `local activity` bug so your own listing automatically closes when losing group leadership or joining another group.
  - Forward `ipairs` + `table.remove` loops in `OnMemberChange` and the 5-second expiry ticker converted to reverse iteration to prevent skipping elements.
  - `table.remove(..., -1)` out-of-bounds removal when an applicant is not found in `OnDecline` and `CreatorFrame` decline handler.
  - Applicant `"Accepted"` button state not persisting on scroll/refresh (`APPLICANT_STATUS.Accepted` -> `APPLICANT_STATUS.Invited`).
  - Invite decline system message detection now uses `ERR_DECLINE_GROUP_S` (with Chinese fallback) so it works on English and non-English clients.
  - Removed the hard cross-faction listing filter in `OnCreate` so cross-faction realms can see and join all compatible listings (while keeping the optional trailing `faction` field in the wire protocol for full version compatibility).
  - `Reset Block Words` UI action now resets to English defaults (`Boost`, `Taobao`, `Gold`, `Powerlevel`) matching `/meeting block reset`, and English tooltip fallbacks (`-- Members --`, `xN`) replace leftover non-English strings.
  - `Add Block Word` dialog now uses a direct `blockInput` reference instead of `GetChildren()`, and `UpdateList` no longer overwrites the search input while typing.
  - Double-click / Whisper (`ChatFrame_OpenChat`) now includes a trailing space after the player name (`/w <name> `).
  - Guarded `Message.CreateActivity` against empty activity codes and cleaned up `CHAT_MSG_CHANNEL` channel index parsing.
- **Improved:**
  - Throttled `MainFrame` hover-check `OnUpdate` to `0.1s` intervals to reduce per-frame overhead.
  - Cached `SetMathcKeyWords()` with a filter signature so passive chat scanning no longer rebuilds the full keyword list on every chat message.
  - Hardened search box `OnChar` against non-string / empty inputs (`type(char) == "string"` and `string.len(char) > 0`).

## Usage

- `/meeting` — Show command help
- `/meeting visible` — Show/hide the floating `Meeting` button
- `/meeting toggle` — Show/hide the main `Meeting` window
- `/meeting reset` — Reset window size, positions, settings, and default block words
- `/meeting block add <keyword>` — Add a block word
- `/meeting block del <keyword>` — Remove a block word
- `/meeting block list` — List current block words
- `/meeting block clear` — Clear all block words
- `/meeting block reset` — Reset block words to defaults

## Credits & License

- Original addon: 龟壳, 武藤纯子酱, Wind, Sunelegy (`Meeting` v1.1.5)
- License: Same as original addon.
