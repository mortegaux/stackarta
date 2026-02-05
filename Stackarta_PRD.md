# PRD: Stackarta (PICO-8)

**Version:** 1.0
**Genre:** Deck-Building Tower Defense Roguelike
**Platform:** PICO-8 (128x128, 16-color)
**Tagline:** *Burn the hand. Build the land. Hold the line.*

---

## 1. Product Vision
Stackarta is a minimalist strategy game that solves the "static" nature of traditional Tower Defense. By merging deck-building with spatial planning, it creates a high-stakes decision loop: players must choose whether to play a card as a unit or "Burn" it to permanently upgrade the terrain.

---

## 2. Core Mechanics

### A. The "Burn to Build" Loop
* **The Hand:** Players draw 3 cards per wave.
* **Action - Play:** Spend Energy to place a unit. Base Energy is 3.
* **Action - Burn:** Discard a card (0 Energy cost) to add +1 Damage or +1 Range to a tile's permanent stats.
* **Inheritance:** Towers placed on a tile gain its `buff_dmg` and `buff_rng`. Removing/replacing a unit does not reset these buffs.
* **Heat Penalty:** Every 3 burns on a single tile increases the Energy cost to place a unit there by +1.

### B. Enemy Pathfinding (Flow Field)
* **Goal:** Enemies move toward the "Core" at grid center (5,5).
* **Logic:** A BFS (Breadth-First Search) calculates the distance of every tile from the Core. Enemies move to the adjacent tile with the lowest distance value.

---

## 3. Technical Specifications

### A. Data Schemas
```lua
-- Grid initialization
grid = {}
for y=0,9 do
  grid[y]={}
  for x=0,9 do
    grid[y][x] = {
      type = 0,      -- 0:empty, 1:core, 2:tower, 3:trap
      buff_dmg = 0,
      buff_rng = 0,
      heat = 0,
      dist = 0,
      occupant = nil
    }
  end
end

-- Card Library
card_defs = {
  {id=1, name="sentry", cost=2, dmg=1, rng=25, rate=30, type="tower", spr=16},
  {id=2, name="l-shot", cost=3, dmg=2, rng=50, rate=75, type="tower", spr=17},
  {id=3, name="shorty", cost=1, dmg=1, rng=15, rate=15, type="tower", spr=18},
  {id=4, name="slower", cost=2, dmg=0, rng=20, rate=0,  type="trap",  spr=19},
  {id=5, name="ovrclk", cost=0, dmg=2, rng=0,  rate=0,  type="boost", spr=20},
  {id=6, name="expand", cost=0, dmg=0, rng=2,  rate=0,  type="boost", spr=21}
}
```

### B. Wave Scaling Algorithm

```lua
function init_wave(w)
  wave_count = w
  enemies_to_spawn = 5 + (w * 2)
  spawn_delay = 60 - min(w * 2, 30) -- Enemies spawn faster over time

  -- Enemy Stat Scaling
  e_hp = 2 * (1.2 ^ (w - 1))
  e_spd = min(0.4 + (w * 0.05), 1.2)
end
```

### C. Pathfinding Algorithm

```lua
function update_pathfinding()
    local target_x, target_y = 5, 5
    for y=0,9 do for x=0,9 do grid[y][x].dist = 99 end end
    local queue = {{x=target_x, y=target_y, d=0}}
    grid[target_y][target_x].dist = 0
    while #queue > 0 do
        local curr = deli(queue, 1)
        local neighbors = {{x=curr.x+1, y=curr.y}, {x=curr.x-1, y=curr.y}, {x=curr.x, y=curr.y+1}, {x=curr.x, y=curr.y-1}}
        for n in all(neighbors) do
            if n.x>=0 and n.x<=9 and n.y>=0 and n.y<=9 then
                if grid[n.y][n.x].dist == 99 then
                    grid[n.y][n.x].dist = curr.d + 1
                    add(queue, {x=n.x, y=n.y, d=curr.d+1})
                end
            end
        end
    end
end
```

---

## 4. User Experience (UX) & UI

### Controls

* **D-Pad:** Move cursor.
* **Button (O) / Z:** Play current card (Costs Energy).
* **Button (X) / X:** Burn current card (0 Energy, +Buffs).

### Information Architecture

* **Visual Pips:** Draw 1px dots on tiles (Red = Dmg, Blue = Range).
* **Energy Bar:** Yellow pips (Color 10) at screen top.
* **Core Health:** Red bar (Color 8) at screen top.
* **The Hand:** Rendered at `y=100`. Selected card is elevated 2px.

---

## 5. Visual Assets (Sprite Map)

* **0:** Cursor (Hollow frame)
* **1:** Core (Pink circle)
* **16-19:** Towers (Triangle, Rectangle, Diamond, Field)
* **32:** Basic Enemy (Red blob)
* **64:** Card Frame (16x24 hollow border)

---

## 6. Enemy Waves

| Wave | Enemy Count | HP (Per Unit) | Speed (px/frame) | Reward Pool | UX Goal |
| --- | --- | --- | --- | --- | --- |
| 1 | 5 | 2 | 0.4 | Common | Introduce "Play" vs "Burn" choice. |
| 2 | 8 | 3 | 0.4 | Common | Force player to use their first "Burn" buff. |
| 3 | 10 | 4 | 0.5 | Common | Introduce "Slower" trap utility. |
| 4 | 12 | 6 | 0.5 | Rare | Test "Stack" depth (Damage check). |
| 5 | 6 (Elites) | 15 | 0.3 | Rare | Slow but tanky; requires a "Super Tile." |
| 6 | 15 | 8 | 0.6 | Rare | Speed increases; focus on Range buffs. |
| 7 | 20 | 10 | 0.6 | Legendary | High volume; requires AOE or fast fire. |
| 8 | 25 | 12 | 0.7 | Legendary | Pressure on the Core; test "Heat" management. |
| 9 | 30 | 15 | 0.8 | Legendary | Pure survival; maximum deck efficiency. |
| 10 | 1 (Boss) | 250 | 0.2 | Victory | The "Siege"; must have 3+ highly buffed tiles. |

---

## 7. Implementation Instructions for Claude Code

1. Initialize a 10x10 grid with the BFS Pathfinding logic.
2. Implement a card system with Draw, Play, and Burn states.
3. Ensure Towers dynamically calculate stats based on `base_stat + tile_buff`.
4. Implement a simple Wave State where enemies spawn and move toward the Core.
5. Include a Reward State: Choose 1 of 3 random cards after each wave.
6. Add tactile feedback: screen shake on "Burn" and sound triggers for firing.
