# zLootScroll

A clean, minimal scrolling loot feed for World of Warcraft (Retail). Every item, currency, and gold pickup you receive appears in a single dedicated frame — out of your chat, out of your way.

---

## What It Does

When you loot an item, earn a currency, or pick up gold, zLootScroll catches that event and displays it in a small scrolling feed you can position anywhere on screen. Messages fade out after a configurable duration. The default chat log is untouched.

- **Items** — looted, crafted, or received items, colored by quality
- **Currency** — tokens and special currencies with icons and running totals
- **Money** — gold, silver, and copper pickups displayed with coin icons

---

## Getting Started

Type `/zls` to open the settings panel. That's it. The feed appears on screen at login using sensible defaults and is ready to use immediately.

**Slash commands:**

| Command | What it does |
|---|---|
| `/zls` | Open the settings panel |
| `/zls toggle` | Show or hide the feed frame |
| `/zls move` | Unlock the frame so you can drag it |
| `/zls clear` | Clear the feed and erase the saved loot log |
| `/zls help` | Print the command list to chat |

---

## Settings Overview

Settings are organized into three tabs.

### General

Controls what gets shown and how the feed behaves.

- **Enable Loot Feed** — Master on/off switch for the entire feed
- **Lock Frame** — Prevent the frame from being accidentally moved; also toggleable with `/zls move`
- **Show Items / Show Currency / Show Money** — Enable or disable each category independently
- **Quality Filters** — Show or hide items by quality tier (Poor through Legendary/Artifact) independently
- **Insert Mode** — Choose whether new messages appear at the top or the bottom of the feed
- **Max Lines** — How many messages the feed holds before old ones roll off (5–100)
- **Fade Duration** — How many seconds a message stays visible before fading out (0.5–600)
- **Keep Forever** — Messages never fade. When enabled, Fade Duration is ignored.

### Display

Controls how each message looks and how the feed frame is sized.

- **Show Item Icons** — Prepend a small inline icon to each item message
- **Icon Size** — Size of the inline icon in pixels (10–24)
- **Show Item Level** — Include the item level inside the brackets, e.g. `[620-Cloak of the Sky]`
- **Show Bag Totals** — After a short delay, append how many you now have in your bags, e.g. `(12)`
- **Increment Before Name** — When looting a stack, show `+3 Item Name` instead of `Item Name +3`
- **Frame Width / Frame Height** — Size the feed frame exactly how you want it (pixels)
- **Line Spacing** — Vertical space between each message (0–10)
- **Show Background** — Toggle the semi-transparent black background behind the feed
- **Background Opacity** — How opaque the background is (0 = invisible, 1 = fully opaque)

### Style

Controls the typeface and colors.

- **Font** — Choose any font registered with LibSharedMedia (includes all Blizzard defaults and any fonts added by other addons)
- **Outline** — None, Outline, Thick Outline, Monochrome, or combinations
- **Font Size** — Size of the message text
- **Justification** — Left, Center, or Right alignment
- **Font Shadow** — Toggle a drop shadow behind text, with customizable color and X/Y offset
- **Color by Quality** — Tint each item and currency message with the item's quality color (grey, white, green, blue, purple, etc.)
- **Money Color** — Choose a custom color for gold/silver/copper messages

---

## Tooltips

When the feed is locked, hovering over an item or currency link in the feed will show its standard game tooltip. The frame is otherwise fully click-through — it won't block you from clicking anything behind it.

---

## Loot Log

zLootScroll keeps a rolling history of loot entries per character in your saved variables (default: the last 100; configurable up to 2,000). This serves two purposes:

- **Restore on reload** — If a UI reload or relog happens and an entry is still within its fade window, it reappears in the feed automatically.
- **Keep Forever** — When enabled, the entire log is always shown and nothing ever expires from the feed.

The log redraws in real time whenever you change display settings, so toggling options like icons, timestamps, or quality filters updates everything already in the feed immediately.

### Log Storage

The **Log Storage** settings panel lets you control which entry types and item quality tiers are actually saved to disk. When a tier or type is disabled, matching entries are removed from all characters' logs at the next login or reload. Changes that delete data prompt for confirmation.

Use `/zls clear` to wipe the log and clear the feed.

---

## Position Persistence

The frame position is saved per-character and restored on every login.

---

## Requirements

- World of Warcraft Retail (Interface 120001+)
- No other addons required
