# Stackarta

**Burn the hand. Build the land.**

A deck-building tower defense roguelike. Defend your core for 10 waves using cards that can be played as towers or burned to permanently buff the map.

## How to Play

Each round you get a hand of cards. You must use every card before the wave begins. For each card, choose:

- **Build** -- Place it on the grid as a tower or trap. Towers block enemy paths and auto-fire. Traps don't block paths but apply effects when enemies walk over them.
- **Burn** -- Sacrifice the card to permanently buff a tile. Burned cards are removed from your deck forever, but the tile keeps its buffs. Any tower placed on a buffed tile inherits those buffs.

This is the core decision: a card used now as a tower, or burned to make a tile stronger for the rest of the run?

## Controls

**Title Screen**
- Left/Right: Select difficulty
- Z or X: Start game

**Planning Phase**
- D-pad: Move cursor on grid
- Z: Build selected card (empty tile) or Sell tower (occupied tile, requires confirmation)
- X: Burn selected card onto any tile
- Down at bottom edge: Cycle through cards in hand

**Wave Phase**
- Z + X together: Pause/unpause

**Reward Screen**
- Left/Right: Browse cards
- Z or X: Pick a card to add to your deck

## Cards

**Towers** (block enemy paths, auto-fire)
- Sentry -- Balanced all-rounder
- L-Shot -- Long range, high damage, slow fire rate
- Shorty -- Short range, fast fire rate, cheap
- Blaster -- Area damage to all enemies in range
- Rapid -- Very fast fire rate

**Traps** (don't block paths)
- Slower -- Halves enemy speed in the tile
- Spike -- Deals damage once, then disappears

**Boosts** (burn only, can't be placed)
- Ovrclk -- Burn for +2 damage on a tile
- Expand -- Burn for +2 range on a tile

## Tile Buffs and Heat

Burning a tower or trap card onto a tile gives +1 damage. Burning a boost card gives its stated bonus.

Each burn increases a tile's **heat**. Every 3 heat adds +1 to the placement cost of building on that tile. Stacking buffs is powerful but expensive.

## Waves

- Waves 1-4: Normal enemies, scouts join at wave 2, tanks at wave 4
- Wave 5: Elite wave (tough yellow diamonds)
- Waves 6-9: Swarm enemies join the mix
- Wave 10: Boss fight

After each wave, pick 1 of 3 reward cards to add to your deck:
- Waves 1-3: Common rewards
- Waves 4-6: Rare rewards
- Waves 7-9: Legendary rewards

Survive wave 10 to win, or continue into endless mode.

## Tips

- Burn boost cards onto tiles where you plan to build your strongest towers
- Towers on buffed tiles are much stronger than unbuffed towers -- plan your layout early
- Traps don't block paths, so place slowers on enemy routes without disrupting pathing
- Selling a tower refunds 1 energy -- useful if you need to reposition
- Burning thins your deck, meaning you see your best cards more often
