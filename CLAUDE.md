# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Stackarta is a PICO-8 deck-building tower defense roguelike. The core mechanic is "Burn vs Play": players either play cards to place towers or burn cards to permanently buff tiles. Towers inherit tile buffs when placed.

## Running the Game

```bash
# In PICO-8 console
load stackarta.p8
run

# Or from command line
pico8 -run stackarta.p8
```

## PICO-8 Constraints

- 128x128 pixel display, 16-color palette
- 8192 token limit for code
- 32KB cartridge size
- Lua 5.2 syntax with PICO-8 extensions
- Fixed-point 16:16 numbers (-32768 to ~32767)
- `_init()`, `_update()` (30fps), `_draw()` structure

## Architecture

### Screen Layout
```
grid_ox=24   -- grid offset x (left margin)
grid_oy=12   -- grid offset y (below 10px top bar)
tile_sz=8    -- 8x8 pixel tiles
```
Grid renders 80x80 pixels (10×8), leaving space for UI panels.

### State Machine
`state` variable controls game flow:
```
"title" → "plan" → "wave" → "reward" → "plan" (loop)
                                    ↓
                              "gameover"
```
- `title`: Animated title screen, press Z/X to start
- `plan`: Player places towers and burns cards
- `wave`: Enemies spawn and move, towers auto-fire
- `reward`: Choose 1 of 3 cards to add to deck
- `gameover`: Victory (wave 10) or defeat (core HP = 0)

### Grid System
10x10 grid at `grid[y][x]` (0-indexed). Each tile stores:
- `type`: 0=empty, 1=core, 2=tower, 3=trap
- `buff_dmg`, `buff_rng`: cumulative buffs from burned cards
- `heat`: burn count (every 3 = +1 placement cost)
- `dist`: BFS distance to core (for enemy pathfinding)
- `occupant`: reference to tower/trap object

### Inheritance Mechanic
`get_tower_stats(tower)` returns effective stats: `base_stat + tile_buff`. This is the core strategic loop.

### Pathfinding
`update_pathfinding()` runs BFS from core (5,5). Towers block pathing (dist=99), traps don't. Enemies move toward adjacent tile with lowest `dist`.

### Wave Scaling
`init_wave(w)` calculates dynamic difficulty. Normal waves use formulas:
- **Enemy count**: `5 + (w * 2)`
- **Spawn delay**: `60 - min(w * 2, 30)` frames (faster over time)
- **HP**: `2 * (1.2 ^ (w - 1))` (exponential)
- **Speed**: `min(0.4 + (w * 0.05), 1.2)` px/frame (capped)

**Special Waves:**
- **Wave 5 (Elites)**: 6 enemies, 15 HP, 0.3 speed, yellow diamonds
- **Wave 10 (Boss)**: 1 enemy, 250 HP, 0.2 speed, large pulsing circle

Victory at wave 10.

### Key Functions
- `start_game()`: Initialize/reset all game state, called from title and game over
- `play_card()`: Place tower/trap, deduct energy + heat penalty
- `burn_card()`: Add buffs to tile, increase heat, remove card from game
- `get_place_cost(gx,gy,card)`: Base cost + floor(heat/3)
- `init_wave(w)`: Calculate enemy count, HP, speed, spawn rate for wave
- `update_enemy(e)`: Move via flow field (beeline fallback if blocked), damage core on arrival
- `update_tower(t)`: Fire at nearest enemy in range using inherited stats

### Sound Effects
- `sfx(0)`: Tower fire (descending zap)
- `sfx(1)`: Card burn (noise whoosh)
- `sfx(2)`: Core hit (low thud)

### UI Components
- **Top bar**: Energy pips (yellow), HP bar (red), wave number
- **Hand panel**: Cards with type icons, cost badges, selection indicators
- **Tile info**: Shows buff_dmg, buff_rng, heat when hovering buffed tiles
- **Wave status**: Enemy count and progress bar during combat

## Card System

Cards defined in `card_defs` table. Each card has: `id`, `name`, `cost`, `dmg`, `rng`, `rate` (fire cooldown), `type`, `spr`, `col` (display color), `rar` (rarity 1-3).

Types:
- `"tower"`: Placeable, blocks pathing, auto-fires
- `"trap"`: Placeable, doesn't block pathing, applies effects
- `"boost"`: Burn-only, gives buff to tile stats

Burned tower/trap cards give +1 DMG. Boost cards give their `dmg`/`rng` values as buffs.

### Card Rarities
- **Common (rar=1)**: sentry, shorty, spike, surge (boost)
- **Rare (rar=2)**: l-shot, slower, blaster (AOE), amp (boost), focus (boost)
- **Legendary (rar=3)**: ovrclk (boost), expand (boost), rapid

### Special Card Mechanics
- **spike**: Trap that deals 3 damage once, then disappears
- **blaster**: Tower with `aoe=true`, damages all enemies in range
- **rapid**: Tower with very fast fire rate (rate=8)

### Reward Pool Tiers
After each wave, player picks 1 of 3 cards: **2 boosts + 1 weapon** (tower/trap) from the tier-appropriate pool. This weights rewards toward tile-buffing to reinforce the burn mechanic. If a pool (boost or weapon) is empty for a tier, the other pool fills in.
- Waves 1-3: Common rewards (gray border)
- Waves 4-6: Rare rewards (blue border)
- Waves 7-9: Legendary rewards (yellow border)

### Starter Deck
8 cards: 2× sentry, 1× l-shot, 1× shorty, 1× slower, 2× ovrclk, 1× expand

### Deck Cycling
- Draw 3 cards per wave (max hand size: 5)
- Played cards → discard pile → reshuffled when deck empty
- Burned cards are removed from game permanently

## Controls

**Title Screen**
- Z or X: Start game

**Plan State**
- D-pad: Move cursor
- Z (O button): Play selected card (empty tile) or Sell tower/trap (occupied tile, with confirmation)
- X (X button): Burn selected card (any non-core tile, including occupied)
- Hold Down + Left/Right: Switch cards in hand

Selling a tower/trap requires confirmation (Z=yes, X or move=cancel), refunds 1 energy and clears the tile.
Burning onto an occupied tile buffs it — the tower inherits the buff immediately.

**Reward State**
- Left/Right: Select card
- Z or X: Confirm selection

## Files

- `stackarta.p8` - Main game cartridge
- `Stackarta_PRD.md` - Full design document with wave data, card stats, sprite map
