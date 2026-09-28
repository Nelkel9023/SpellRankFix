# SpellRankFix

Small World of Warcraft **3.3.5 (WotLK)** addon that fixes stale spell ranks on your action bars.

## The problem it fixes

With dual specialization:

1. You are on Spec 2 and a spell ranks up (e.g. *Fireball Rank 3* becomes *Rank 5*).
2. You switch back to Spec 1.
3. The bar still shows and casts the old rank (*Fireball Rank 3*).

The client keeps each spec's bars exactly as they were saved and never updates the
ranks on the inactive spec's bars. SpellRankFix upgrades them automatically.

Macros are never touched - only real spell actions are checked.

## What triggers a fix

- Dual spec switch (checked immediately, then again 1 second later)
- Level up
- Spellbook changed (learning/ranking up a spell)
- Talent update
- Login / loading screen (2 seconds after)
- A verification pass 3 seconds after any fix

The scan skips itself if you are holding something on your cursor or are in combat,
and retries a bit later instead.

## Install

1. Copy the `SpellRankFix` folder into `Interface\AddOns\`.
2. Enable **SpellRankFix** in the addon list at the character select screen or in game.
3. Restart the game client (or reload the UI with `/reload`).

## Commands

| Command | Effect |
|---|---|
| `/rankfix` | Scan and fix right now, reports how many slots were upgraded |
| `/rankfix on` | Turn automatic fixing on (default) |
| `/rankfix off` | Turn automatic fixing off, manual `/rankfix` still works |
| `/rankfix exclude Frostbolt(Rank 1)` | Never auto-upgrade a Frostbolt that sits at Rank 1 |
| `/rankfix unexclude Frostbolt` | Remove that exclusion |
| `/rankfix list` | Show all excluded spells |

### Exclusions

Use an exclusion when you **want** to keep a low rank on purpose
(for example Rank 1 Frostbolt for slower mana/aggro while kiting):

```
/rankfix exclude Frostbolt(Rank 1)
/rankfix exclude Frostbolt Rank 1
/rankfix exclude Frostbolt 1
```

All three spellings work. The exclusion matches that **exact** rank:
if the bar has Frostbolt Rank 1 it stays Rank 1, but a Frostbolt Rank 3
on the same bar still gets upgraded to your highest known rank.
Exclusions are saved between sessions.

## How it works

1. Builds a map of every spell in your spellbook with the highest rank you know.
2. Reads all 120 action slots and resolves each spell action's name and current rank.
3. If a slot's rank is lower than your highest known rank, it picks up the best
   rank from the spellbook and places it on the slot (`PickupSpell` + `PlaceAction`).
4. Slots holding macros, items, or excluded ranks are skipped.

## Requirements

- WoW 3.3.5a client (Interface 30300)
- Works with the default action bars and action bar addons such as Bartender4
