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

### State Machine
`state` variable controls game flow: `"plan"` → `"wave"` → `"reward"` → `"plan"` (loop) or `"gameover"`

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
`init_wave(w)` calculates dynamic difficulty. No hardcoded wave table.
- **Enemy count**: `5 + (w * 2)`
- **Spawn delay**: `60 - min(w * 2, 30)` frames (faster over time)
- **HP**: `2 * (1.2 ^ (w - 1))` (exponential)
- **Speed**: `min(0.4 + (w * 0.05), 1.2)` px/frame (capped)

Victory at wave 10.

### Key Functions
- `play_card()`: Place tower/trap, deduct energy + heat penalty
- `burn_card()`: Add buffs to tile, increase heat, remove card from game
- `get_place_cost(gx,gy,card)`: Base cost + floor(heat/3)
- `init_wave(w)`: Calculate enemy count, HP, speed, spawn rate for wave
- `update_enemy(e)`: Move via flow field, apply trap effects, damage core on arrival
- `update_tower(t)`: Fire at nearest enemy in range using inherited stats

## Card System

Cards defined in `card_defs` table. Types:
- `"tower"`: Placeable, blocks pathing, auto-fires
- `"trap"`: Placeable, doesn't block pathing, applies effects
- `"boost"`: Burn-only, gives +2 to specific stat

Burned tower/trap cards give +1 DMG. Boost cards give their `dmg`/`rng` values as buffs.

## Controls (Plan State)

- D-pad: Move cursor
- O (Z key): Play selected card
- X (X key): Burn selected card
- Hold Down + Left/Right: Switch cards in hand

## Files

- `stackarta.p8` - Main game cartridge
- `Stackarta_PRD.md` - Full design document with wave data, card stats, sprite map
