# Meeting (Patched for WoW 1.12 / Turtle WoW)

> A group-finder / LFG assistant for Vanilla WoW 1.12.x and Turtle WoW that broadcasts and browses group listings over a shared addon channel (`LFT`) and passively detects LFG/LFM messages in chat.

## Client Mods & Optional Addons Used

| Mod / Addon | Purpose in this addon | Required? |
|---|---|---|
| **[ClassicAPI](https://github.com/brues-code/ClassicAPI)** | Calls `C_PlayerCache.GetPlayerInfoByName` in `Meeting.GetClassRGBColor` to display cross-faction class colors for chat-scraped leaders (`World` / `China` / `Hardcore`). | Optional |
| **UnitXP SP3** | Calls `UnitXP("notify", "taskbarIcon")` (5s cooldown) when a new applicant applies to your group while alt-tabbed. | Optional |
| **WoWTranslate** (v2.2 fork) | Shares the unified raw cache key (with legacy `"meeting:"` read fallback), uses `"LOW"` priority queue, and subscribes to `WoWTranslate_RegisterCallback("ON_TRANSLATED")` for zero-duplicate live updates. | Optional |
| **DifficultBulletinBoard (DBB2)** | Shared Blacklist / Block Words synergy (`DBB2.api.IsMessageBlacklisted`) and `Meeting.QuickApply(leaderName)` bridge (`Alt+Click` a leader in DBB2 to open Meeting's Apply prompt directly). | Optional |

No other client DLL mods (SuperWoW, Nampower, VanillaHelpers, WeirdUtils) are required or called by this addon. Runs on stock WoW 1.12.x (`Lua 5.0`).

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
  - Raid member counting & class encoding: excluded `Meeting.player` from `GetMembers()` in raids (fixing off-by-+1 raid counts, premature auto-close at 9/10 or 39/40, and self-matching `joinedActivity`) and fixed `EncodeGroupClass()` double-counting the leader's class (with 40-man clamp).
  - Quest link chat tracking: fixed `Message.OnRecvFormChat` truncating at the first `|h` and stopped passing `questID` as `classnum`.
  - Vanilla 1.12 crash fixes: replaced undefined global `print(...)` calls with `DEFAULT_CHAT_FRAME:AddMessage(...)`, guarded `/meeting` whitespace/punctuation nil `cmd`, guarded malformed `LFT` wire fields (`code`, `level`, `members`, `score`), and used plain-text `string.find(..., 1, true)` in `CheckBlockWords` and keyword matching so magic characters (`[`, `(`, `%`, `-`) never throw pattern errors.
  - UI & filter fixes: forward-declared `local searchInput` so dropdown filters clear the search box, fixed `OnChar` using `arg1` instead of a Lua 5.1 parameter, fixed Settings `-`/`+` buttons overlapping labels (`relativePoint = "TOPRIGHT"`), snapshotted `targetId` in the Apply dialog so list refreshes cannot misdirect applications, hid stale rows in `GUI.CreateListFrame:Reload`, fixed off-by-one in `UpdateActivity`, preserved the `"china"` channel category, fixed `lfg`-only case-insensitive chat filtering (no longer dropping `"lfm"` recruiters), lowercased uppercase match keywords (`世界boss`/`alx`/`pvp`/`|hquest:`), separated `RFK`/`RFD`/`LKH` match keywords, cleared `Meeting.joinedActivity` on 120s expiry, fixed `FloatFrame` tooltip for joined activities, and fixed `translateInFlight` double-decrement on synchronous DLL failures.
- **Improved:**
  - **Hub-and-Spoke Synergy:** Unified `WoWTranslate` cache keys (removed `"meeting:"` save prefix), subscribed to `ON_TRANSLATED` push updates, added `"LOW"` queue priority, linked shared Blacklist with `DifficultBulletinBoard`, and exposed `Meeting.QuickApply(leaderName)`.
  - **Client Mods & Memory:** Added ClassicAPI `C_PlayerCache` cross-faction class colors, UnitXP SP3 applicant taskbar alerts, `GUI.CreateDialog` `dialogKey` frame pooling (eliminating dialog frame leaks), and `/meeting status` diagnostics.
  - Throttled `MainFrame` hover-check `OnUpdate` to `0.1s` intervals and cached `SetMathcKeyWords()` with a filter signature.

## Usage

- `/meeting` — Show command help
- `/meeting status` — Show `LFT` channel, client-mod, `WoWTranslate` Hub, and `DBB2` synergy status
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
