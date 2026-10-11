# Meeting

A group-finder/LFG assistant: broadcasts and browses group listings for dungeons, raids, quests, and world bosses over a shared addon channel, with passive detection of LFG-style messages in normal chat.

## Client mods used

**None.** Both changes in this update are internal — one pure client-side caching fix, one protocol-level feature addition using only native vanilla APIs (`UnitFactionGroup`). No external client mod is required for either.

## Features

- Create and broadcast a group listing for Dungeons, Raids, Party Quests, Raid Quests, World Bosses (Azuregos, Emeriss, Lethon, Taerar, Ysondre, Lord Kazzak, Nerubian Overseer, Dark Reaver of Karazhan, Ostarius, Concavius, Cow King), and other categories, with member count and Hardcore-mode status
- Browse and filter active listings by category, specific activity, or multiple activities at once
- Passive chat scanning: detects LFG/LFM-style messages in configured channels and surfaces them even from players not using the addon
- Request to join a listed group; listing owner can accept or decline requests
- Block-word filtering for both listing comments and poster names
- Quest-link detection and matching
- Group class-composition tracking and display
- Version broadcast and mismatch notice, so outdated users know to update
- Optional translation integration (`WoWTranslate`) for listings in other languages
- Minimap icon, configurable font size, background opacity, and border style

## New feature in this update

**Faction awareness in the group-listing sync protocol.** Previously there was no faction handling anywhere in the addon. Because the addon's shared channel is a custom channel — unlike Blizzard's built-in faction-locked channels (Trade/General/etc.) — it can be joined by both factions, meaning Alliance and Horde players could see each other's listings with no way to tell them apart, despite being unable to ever actually group together. `Message.CreateActivity` now broadcasts the poster's faction, and `Meeting:OnCreate` filters out confirmed cross-faction listings before they're ever shown.

### Backward compatibility — the part that actually mattered here
The protocol is a plain colon-delimited positional string. The new field is **appended at the end only**, following the same pattern already used for an earlier field (`classnum`) — the only safe way to extend this kind of protocol without shifting existing field positions.

- **An older client's listing, read by this updated client:** the faction field is naturally `nil` (Lua's `unpack()` behavior on a shorter list) — no error. A `nil` faction is explicitly treated as "unknown, don't filter," so behavior is **identical to before this update** when talking to an older peer.
- **This client's listing, read by an older client:** the old client simply never reads the extra trailing value — no error.
- Any ambiguous case (`"Neutral"`, or faction unknown on either side) is never filtered — biased toward showing a possibly-unjoinable listing (a minor annoyance) over ever hiding a legitimate one (a silent functionality loss).

**Verified, not assumed:**
- End-to-end wire-format test using the addon's actual split function, across all three directions: old listing → new client, new listing → new client, new listing → old client. Confirmed `nil` where expected, confirmed correct parsing where expected, confirmed no corruption in either direction.
- Filtering logic tested across 9 scenarios: both old-client cases (never filtered), same-faction, cross-faction, and every ambiguous/unknown combination.

## What changed — performance

**`SetMathcKeyWords()` rebuilt its entire keyword-matching list — walking the full activity category tree — on every single chat message** passed through the passive-detection path, even though the result only changes when the user edits their search filter. Added a cheap signature cache (category + selected activity codes); the expensive rebuild now only runs when that signature actually changes.

**Verified against the actual extracted, patched function** (not a reimplementation), with an instrumented rebuild counter: a real filter change correctly triggers exactly one rebuild with correct content; 50 subsequent calls with an unchanged filter trigger zero further rebuilds; switching between multi-select and single-select filter modes correctly invalidates and rebuilds.

## Checked and found clean

Block-word filtering (linear scan, but over a small user-curated list — not worth caching) and the quest-link detection path (already gated behind a cheap substring check before the more expensive parse runs).

## Verification

- All three changed files (`Browser.lua`, `Message.lua`, `Meeting.lua`) syntax-checked (`luac5.1 -p`) — clean.
- Patch reapplies to a clean copy of the originals and reproduces the shipped files exactly, byte for byte.
- Not tested in a live client, or against an actual older build running on a second account — the wire-format and filtering-logic tests specifically exercise the backward-compatibility claim, but a real cross-version test in-game is the only way to be fully certain.

## Files changed

```
Browser.lua
Message.lua
Meeting.lua
```
