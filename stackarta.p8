pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- stackarta
-- burn the hand. build the land.

-- constants
grid_ox=24  -- grid offset x
grid_oy=4   -- grid offset y
tile_sz=8   -- tile size in pixels
core_gx=5   -- core grid x
core_gy=5   -- core grid y

-- game state
state="plan" -- plan, wave, reward, gameover
wave_num=1
energy=3
max_energy=3
core_hp=10
max_core_hp=10

-- card definitions
card_defs={
 {id=1,name="sentry",cost=2,dmg=1,rng=25,rate=30,type="tower",spr=16,col=12},
 {id=2,name="l-shot",cost=3,dmg=2,rng=50,rate=75,type="tower",spr=17,col=3},
 {id=3,name="shorty",cost=1,dmg=1,rng=15,rate=15,type="tower",spr=18,col=13},
 {id=4,name="slower",cost=2,dmg=0,rng=20,rate=0,type="trap",spr=19,col=1},
 {id=5,name="ovrclk",cost=0,dmg=2,rng=0,rate=0,type="boost",spr=20,col=8},
 {id=6,name="expand",cost=0,dmg=0,rng=2,rate=0,type="boost",spr=21,col=12}
}

-- wave scaling (dynamic)

-- collections
grid={}
deck={}
hand={}
discard={}
towers={}
enemies={}

-- cursor
cur_x=5
cur_y=5
cur_sel=1 -- selected card index

-- visual feedback
shake=0
msg=""
msg_t=0

function _init()
 init_grid()
 init_deck()
 draw_hand(3)
 update_pathfinding()
end

function init_grid()
 for y=0,9 do
  grid[y]={}
  for x=0,9 do
   grid[y][x]={
    type=0,     -- 0:empty,1:core,2:tower,3:trap
    buff_dmg=0,
    buff_rng=0,
    heat=0,
    dist=0,
    occupant=nil
   }
  end
 end
 -- place core
 grid[core_gy][core_gx].type=1
 grid[core_gy][core_gx].dist=0
end

function init_deck()
 -- starter deck: 2 sentry, 1 longshot, 1 shorty, 1 slower, 2 ovrclk, 1 expand
 local starter={1,1,2,3,4,5,5,6}
 for id in all(starter) do
  add(deck,{def=card_defs[id]})
 end
 shuffle_deck()
end

function shuffle_deck()
 for i=#deck,2,-1 do
  local j=flr(rnd(i))+1
  deck[i],deck[j]=deck[j],deck[i]
 end
end

function draw_hand(n)
 for i=1,n do
  if #deck==0 then
   -- reshuffle discard into deck
   if #discard==0 then return end
   for c in all(discard) do
    add(deck,c)
   end
   discard={}
   shuffle_deck()
  end
  if #deck>0 and #hand<5 then
   add(hand,deli(deck,1))
  end
 end
 if #hand>0 then cur_sel=1 end
end

function update_pathfinding()
 -- reset distances
 for y=0,9 do
  for x=0,9 do
   grid[y][x].dist=99
  end
 end

 -- bfs from core
 local queue={{x=core_gx,y=core_gy,d=0}}
 grid[core_gy][core_gx].dist=0

 while #queue>0 do
  local curr=deli(queue,1)
  local nb={
   {x=curr.x+1,y=curr.y},
   {x=curr.x-1,y=curr.y},
   {x=curr.x,y=curr.y+1},
   {x=curr.x,y=curr.y-1}
  }
  for n in all(nb) do
   if n.x>=0 and n.x<=9 and n.y>=0 and n.y<=9 then
    local tile=grid[n.y][n.x]
    -- can path through empty, core, trap; blocked by tower
    if tile.dist==99 and tile.type!=2 then
     tile.dist=curr.d+1
     add(queue,{x=n.x,y=n.y,d=curr.d+1})
    end
   end
  end
 end
end

-- get tile placement cost (base + heat penalty)
function get_place_cost(gx,gy,card)
 local tile=grid[gy][gx]
 local heat_penalty=flr(tile.heat/3)
 return card.def.cost+heat_penalty
end

-- play a card (place tower/trap)
function play_card()
 if #hand==0 then return false end
 local card=hand[cur_sel]
 local def=card.def
 local tile=grid[cur_y][cur_x]

 -- boost cards cannot be played
 if def.type=="boost" then
  show_msg("burn only!")
  return false
 end

 -- check tile is empty
 if tile.type!=0 then
  show_msg("occupied!")
  return false
 end

 -- check energy
 local cost=get_place_cost(cur_x,cur_y,card)
 if energy<cost then
  show_msg("need "..cost.." nrg")
  return false
 end

 -- place the unit
 energy-=cost
 tile.type=def.type=="tower" and 2 or 3

 -- create tower/trap with inheritance
 local unit={
  gx=cur_x,
  gy=cur_y,
  def=def,
  reload=0
 }
 tile.occupant=unit
 add(towers,unit)

 -- remove card from hand
 deli(hand,cur_sel)
 add(discard,card)
 cur_sel=mid(1,cur_sel,#hand)

 -- update pathfinding (towers block)
 update_pathfinding()

 show_msg(def.name.." placed")
 return true
end

-- burn a card (add buffs to tile)
function burn_card()
 if #hand==0 then return false end
 local card=hand[cur_sel]
 local def=card.def
 local tile=grid[cur_y][cur_x]

 -- cannot burn on core
 if tile.type==1 then
  show_msg("not on core!")
  return false
 end

 -- apply buff based on card type
 local dmg_add=0
 local rng_add=0

 if def.type=="boost" then
  -- boost cards give their stats as buffs
  dmg_add=def.dmg
  rng_add=def.rng
 else
  -- tower/trap cards give +1 dmg when burned
  dmg_add=1
 end

 tile.buff_dmg+=dmg_add
 tile.buff_rng+=rng_add
 tile.heat+=1

 -- remove card from hand
 deli(hand,cur_sel)
 -- burned cards are removed from game (not to discard)
 cur_sel=mid(1,cur_sel,#hand)

 -- screen shake feedback
 shake=4
 sfx(1) -- burn sound

 local buff_str=""
 if dmg_add>0 then buff_str=buff_str.."+"..dmg_add.."dmg " end
 if rng_add>0 then buff_str=buff_str.."+"..rng_add.."rng" end
 show_msg(buff_str)
 return true
end

-- get effective tower stats (inheritance)
function get_tower_stats(tower)
 local tile=grid[tower.gy][tower.gx]
 local def=tower.def
 return {
  dmg=def.dmg+tile.buff_dmg,
  rng=def.rng+tile.buff_rng,
  rate=def.rate
 }
end

function show_msg(txt)
 msg=txt
 msg_t=60
end

function _update()
 -- decay shake
 if shake>0 then shake-=1 end
 if msg_t>0 then msg_t-=1 end

 if state=="plan" then
  update_plan()
 elseif state=="wave" then
  update_wave()
 elseif state=="reward" then
  update_reward()
 end
end

function update_plan()
 -- cursor movement
 if btnp(0) then cur_x=max(0,cur_x-1) end
 if btnp(1) then cur_x=min(9,cur_x+1) end
 if btnp(2) then cur_y=max(0,cur_y-1) end
 if btnp(3) then cur_y=min(9,cur_y+1) end

 -- card selection (left/right while holding down)
 if btn(3) then
  if btnp(0) then cur_sel=max(1,cur_sel-1) end
  if btnp(1) then cur_sel=min(#hand,cur_sel+1) end
 end

 -- play card (o button)
 if btnp(4) then
  play_card()
 end

 -- burn card (x button)
 if btnp(5) then
  burn_card()
 end

 -- start wave when hand is empty or press both buttons
 if #hand==0 or (btn(4) and btn(5)) then
  if #hand==0 then
   start_wave()
  end
 end
end

function init_wave(w)
 -- enemy count scales: 5 + 2 per wave
 wave_cnt=5+(w*2)
 -- spawn delay decreases (faster spawns)
 spawn_delay=60-min(w*2,30)
 -- hp scales exponentially: 2 * 1.2^(w-1)
 wave_hp=2*(1.2^(w-1))
 -- speed scales linearly, capped at 1.2
 wave_spd=min(0.4+(w*0.05),1.2)
end

function start_wave()
 state="wave"
 spawn_timer=0
 spawned=0
 init_wave(wave_num)
end

function update_wave()
 -- spawn enemies
 if spawned<wave_cnt then
  spawn_timer-=1
  if spawn_timer<=0 then
   spawn_enemy()
   spawned+=1
   spawn_timer=spawn_delay
  end
 end

 -- update enemies
 for e in all(enemies) do
  update_enemy(e)
 end

 -- update towers
 for t in all(towers) do
  update_tower(t)
 end

 -- remove dead enemies
 for i=#enemies,1,-1 do
  if enemies[i].hp<=0 then
   deli(enemies,i)
  end
 end

 -- check wave complete
 if spawned>=wave_cnt and #enemies==0 then
  end_wave()
 end

 -- check game over
 if core_hp<=0 then
  state="gameover"
 end
end

function spawn_enemy()
 -- spawn from random edge
 local side=flr(rnd(4))
 local gx,gy
 if side==0 then gx=0 gy=flr(rnd(10))
 elseif side==1 then gx=9 gy=flr(rnd(10))
 elseif side==2 then gx=flr(rnd(10)) gy=0
 else gx=flr(rnd(10)) gy=9 end

 local px=grid_ox+gx*tile_sz+4
 local py=grid_oy+gy*tile_sz+4

 add(enemies,{
  x=px,y=py,
  gx=gx,gy=gy,
  hp=wave_hp,
  max_hp=wave_hp,
  spd=wave_spd,
  slowed=0
 })
end

function update_enemy(e)
 -- apply slow effect
 local spd=e.spd
 if e.slowed>0 then
  spd*=0.5
  e.slowed-=1
 end

 -- check traps
 local tile=grid[e.gy][e.gx]
 if tile.type==3 and tile.occupant then
  local trap=tile.occupant
  -- slower trap applies slow
  if trap.def.name=="slower" then
   e.slowed=30
  end
 end

 -- move toward lower dist
 local cur_d=grid[e.gy][e.gx].dist
 local best_d=cur_d
 local tx,ty=e.gx,e.gy
 local nb={
  {x=e.gx+1,y=e.gy},
  {x=e.gx-1,y=e.gy},
  {x=e.gx,y=e.gy+1},
  {x=e.gx,y=e.gy-1}
 }
 for n in all(nb) do
  if n.x>=0 and n.x<=9 and n.y>=0 and n.y<=9 then
   local d=grid[n.y][n.x].dist
   if d<best_d then
    best_d=d
    tx,ty=n.x,n.y
   end
  end
 end

 -- fallback: if stuck (no path), move directly toward core
 local target_px,target_py
 if best_d>=99 then
  -- no valid path, beeline to core
  target_px=grid_ox+core_gx*tile_sz+4
  target_py=grid_oy+core_gy*tile_sz+4
 else
  target_px=grid_ox+tx*tile_sz+4
  target_py=grid_oy+ty*tile_sz+4
 end

 local dx=target_px-e.x
 local dy=target_py-e.y
 local dist=sqrt(dx*dx+dy*dy)

 if dist>0.5 then
  e.x+=dx/dist*spd
  e.y+=dy/dist*spd
  -- update grid pos based on pixel pos
  e.gx=flr((e.x-grid_ox)/tile_sz)
  e.gy=flr((e.y-grid_oy)/tile_sz)
  e.gx=mid(0,e.gx,9)
  e.gy=mid(0,e.gy,9)
 else
  e.gx=tx
  e.gy=ty
 end

 -- reached core?
 local core_px=grid_ox+core_gx*tile_sz+4
 local core_py=grid_oy+core_gy*tile_sz+4
 local cdx=core_px-e.x
 local cdy=core_py-e.y
 if sqrt(cdx*cdx+cdy*cdy)<4 then
  core_hp-=1
  e.hp=0
  shake=6
  sfx(2) -- core hit sound
 end
end

function update_tower(t)
 if t.def.type=="trap" then return end

 t.reload-=1
 if t.reload>0 then return end

 local stats=get_tower_stats(t)
 local px=grid_ox+t.gx*tile_sz+4
 local py=grid_oy+t.gy*tile_sz+4

 -- find nearest enemy in range
 local target=nil
 local best_dist=stats.rng+1

 for e in all(enemies) do
  local dx=e.x-px
  local dy=e.y-py
  local d=sqrt(dx*dx+dy*dy)
  if d<=stats.rng and d<best_dist then
   best_dist=d
   target=e
  end
 end

 if target then
  target.hp-=stats.dmg
  t.reload=stats.rate
  t.last_target=target
  t.fire_t=4
  sfx(0) -- fire sound
 end
end

function end_wave()
 wave_num+=1
 if wave_num>10 then
  state="gameover"
  msg="victory!"
  msg_t=9999
  return
 end

 -- refill energy
 energy=max_energy+flr(wave_num/5)

 -- draw new hand
 draw_hand(3)

 -- go to reward or plan
 state="reward"
 init_reward()
end

-- reward state
reward_cards={}
reward_sel=1

function init_reward()
 reward_cards={}
 for i=1,3 do
  local id=flr(rnd(#card_defs))+1
  add(reward_cards,card_defs[id])
 end
 reward_sel=1
end

function update_reward()
 if btnp(0) then reward_sel=max(1,reward_sel-1) end
 if btnp(1) then reward_sel=min(3,reward_sel+1) end

 if btnp(4) or btnp(5) then
  -- add selected card to deck
  add(deck,{def=reward_cards[reward_sel]})
  state="plan"
 end
end

function _draw()
 -- apply shake
 local sx=0
 local sy=0
 if shake>0 then
  sx=rnd(shake)-shake/2
  sy=rnd(shake)-shake/2
 end
 camera(sx,sy)

 cls(0)

 if state=="gameover" then
  draw_gameover()
  return
 end

 draw_grid()
 draw_towers()
 draw_enemies()
 draw_cursor()
 draw_ui()

 if state=="reward" then
  draw_reward()
 end

 -- message
 if msg_t>0 then
  local mx=64-#msg*2
  print(msg,mx,60,7)
 end

 camera(0,0)
end

function draw_grid()
 -- grid lines
 for i=0,10 do
  local x=grid_ox+i*tile_sz
  local y=grid_oy+i*tile_sz
  line(x,grid_oy,x,grid_oy+80,5)
  line(grid_ox,y,grid_ox+80,y,5)
 end

 -- tile buffs (pips)
 for y=0,9 do
  for x=0,9 do
   local tile=grid[y][x]
   local px=grid_ox+x*tile_sz
   local py=grid_oy+y*tile_sz

   -- dmg pips (red, top-left)
   for i=1,min(tile.buff_dmg,3) do
    pset(px+i,py+1,8)
   end

   -- rng pips (blue, top-right)
   for i=1,min(tile.buff_rng,3) do
    pset(px+7-i,py+1,12)
   end
  end
 end

 -- core
 local cx=grid_ox+core_gx*tile_sz
 local cy=grid_oy+core_gy*tile_sz
 local pulse=sin(time()*2)*0.5+0.5
 circfill(cx+4,cy+4,3+pulse,14)
 rectfill(cx+2,cy+2,cx+5,cy+5,15)
end

function draw_towers()
 for t in all(towers) do
  local px=grid_ox+t.gx*tile_sz
  local py=grid_oy+t.gy*tile_sz
  local col=t.def.col

  -- draw based on type
  if t.def.name=="sentry" then
   -- triangle
   line(px+4,py+1,px+1,py+6,col)
   line(px+4,py+1,px+7,py+6,col)
   line(px+1,py+6,px+7,py+6,col)
  elseif t.def.name=="l-shot" then
   -- tall rect with lens
   rectfill(px+3,py+2,px+5,py+6,col)
   pset(px+4,py+1,7)
  elseif t.def.name=="shorty" then
   -- diamond
   line(px+4,py+1,px+7,py+4,col)
   line(px+7,py+4,px+4,py+7,col)
   line(px+4,py+7,px+1,py+4,col)
   line(px+1,py+4,px+4,py+1,col)
  elseif t.def.name=="slower" then
   -- 4 dots
   pset(px+2,py+2,col)
   pset(px+5,py+2,col)
   pset(px+2,py+5,col)
   pset(px+5,py+5,col)
  end

  -- fire beam
  if t.fire_t and t.fire_t>0 and t.last_target then
   line(px+4,py+4,t.last_target.x,t.last_target.y,7)
   t.fire_t-=1
  end
 end
end

function draw_enemies()
 for e in all(enemies) do
  local col=8
  if e.slowed>0 then col=1 end
  rectfill(e.x-2,e.y-2,e.x+2,e.y+2,col)
  -- hp bar
  local hp_w=4*e.hp/e.max_hp
  rectfill(e.x-2,e.y-4,e.x-2+hp_w,e.y-3,11)
 end
end

function draw_cursor()
 if state!="plan" then return end

 local px=grid_ox+cur_x*tile_sz
 local py=grid_oy+cur_y*tile_sz
 local pulse=sin(time()*4)*0.5+0.5
 local col=7
 if pulse>0.5 then col=6 end

 rect(px,py,px+7,py+7,col)

 -- show range preview if tower selected
 if #hand>0 then
  local card=hand[cur_sel]
  if card.def.type=="tower" then
   local rng=card.def.rng
   circ(px+4,py+4,rng,5)
  end
 end
end

function draw_ui()
 -- top bar
 rectfill(0,0,127,3,0)

 -- energy (yellow pips)
 for i=1,energy do
  rectfill(i*4-2,1,i*4,2,10)
 end

 -- core hp (red bar)
 local hp_w=40*core_hp/max_core_hp
 rectfill(86,1,86+hp_w,2,8)
 print("hp",80,0,7)

 -- wave number
 print("w"..wave_num,116,0,7)

 -- hand (bottom)
 if state=="plan" then
  draw_hand_ui()
 end

 -- tile info
 if state=="plan" then
  local tile=grid[cur_y][cur_x]
  local info=""
  if tile.buff_dmg>0 then info=info.."d+"..tile.buff_dmg.." " end
  if tile.buff_rng>0 then info=info.."r+"..tile.buff_rng.." " end
  if tile.heat>0 then info=info.."h"..tile.heat end
  print(info,0,120,5)
 end
end

function draw_hand_ui()
 local y=100
 local start_x=64-(#hand*18)/2

 for i,card in ipairs(hand) do
  local x=start_x+(i-1)*18
  local cy=y
  if i==cur_sel then cy=y-2 end

  -- card bg
  local col=card.def.col
  rectfill(x,cy,x+15,cy+20,col)
  rect(x,cy,x+15,cy+20,6)

  -- card name (abbreviated)
  print(sub(card.def.name,1,4),x+1,cy+2,0)

  -- cost
  local cost=card.def.cost
  if #hand>0 and i==cur_sel then
   cost=get_place_cost(cur_x,cur_y,card)
  end
  print(cost,x+6,cy+14,0)

  -- selected indicator
  if i==cur_sel then
   print("\x8e",x+6,cy+22,7)
  end
 end

 -- instructions
 print("\x97:play \x8e:burn",32,92,5)
end

function draw_reward()
 rectfill(20,40,108,88,0)
 rect(20,40,108,88,7)
 print("choose a card",36,44,7)

 for i=1,3 do
  local def=reward_cards[i]
  local x=24+(i-1)*30
  local y=54
  local col=def.col

  if i==reward_sel then
   rect(x-1,y-1,x+26,y+28,7)
  end

  rectfill(x,y,x+25,y+27,col)
  rect(x,y,x+25,y+27,6)
  print(sub(def.name,1,6),x+1,y+2,0)
  print("c"..def.cost,x+1,y+12,0)
  if def.dmg>0 then print("d"..def.dmg,x+1,y+18,0) end
  if def.rng>0 then print("r"..def.rng,x+12,y+18,0) end
 end
end

function draw_gameover()
 cls(0)
 if core_hp<=0 then
  print("game over",44,50,8)
  print("wave "..wave_num,48,60,7)
 else
  print("victory!",46,50,11)
  print("core defended!",32,60,7)
 end
 print("\x97 to restart",38,80,5)

 if btnp(4) then
  -- reset game
  grid={}
  deck={}
  hand={}
  discard={}
  towers={}
  enemies={}
  wave_num=1
  energy=3
  core_hp=10
  state="plan"
  cur_x=5
  cur_y=5
  _init()
 end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010400002835026340243302232020310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001865518645186351862518615000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000765007640076300762007610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
