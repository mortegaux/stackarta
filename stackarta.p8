pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- stackarta
-- burn the hand. build the land.

-- constants
grid_ox=24  -- grid offset x
grid_oy=12  -- grid offset y (below top bar)
tile_sz=8   -- tile size in pixels
core_gx=5   -- core grid x
core_gy=5   -- core grid y

-- game state
state="title" -- title, plan, wave, reward, gameover
wave_num=1
energy=3
max_energy=3
core_hp=10
max_core_hp=10
kills=0
paused=false
difficulty=2 -- 1=easy, 2=normal, 3=hard
diff_names={"easy","normal","hard"}
mulligan_used=false -- once per wave
show_deck=false -- deck viewer toggle
endless_mode=false -- continue after wave 10

-- card definitions
-- rar: 1=common, 2=rare, 3=legendary
card_defs={
 {id=1,name="sentry",cost=2,dmg=1,rng=25,rate=30,type="tower",spr=16,col=12,rar=1},
 {id=2,name="l-shot",cost=3,dmg=2,rng=50,rate=75,type="tower",spr=17,col=3,rar=2},
 {id=3,name="shorty",cost=1,dmg=1,rng=15,rate=15,type="tower",spr=18,col=13,rar=1},
 {id=4,name="slower",cost=2,dmg=0,rng=20,rate=0,type="trap",spr=19,col=1,rar=2},
 {id=5,name="ovrclk",cost=0,dmg=2,rng=0,rate=0,type="boost",spr=20,col=8,rar=3},
 {id=6,name="expand",cost=0,dmg=0,rng=2,rate=0,type="boost",spr=21,col=12,rar=3},
 {id=7,name="spike",cost=1,dmg=3,rng=0,rate=0,type="trap",spr=22,col=8,rar=1},
 {id=8,name="blaster",cost=3,dmg=1,rng=20,rate=45,type="tower",spr=23,col=9,rar=2,aoe=true},
 {id=9,name="rapid",cost=4,dmg=1,rng=30,rate=8,type="tower",spr=24,col=11,rar=3}
}

-- wave scaling (dynamic)

-- enemy type definitions
-- spd_mult, hp_mult, armor, col, size
enemy_types={
 normal={spd=1,hp=1,armor=0,col=8,sz=2},
 scout={spd=1.6,hp=0.5,armor=0,col=11,sz=1},
 tank={spd=0.5,hp=2.5,armor=1,col=4,sz=3},
 swarm={spd=1.1,hp=0.4,armor=0,col=9,sz=1}
}

-- tower targeting modes
tgt_modes={"near","strong","fast"}
tgt_icons={"\x97","\x96","\x8b"} -- symbols for each mode

-- collections
grid={}
deck={}
hand={}
discard={}
towers={}
enemies={}
particles={}

-- cursor
cur_x=5
cur_y=5
cur_sel=1 -- selected card index

-- visual feedback
shake=0
msg=""
msg_t=0

function _init()
 state="title"
 title_t=0
 music(0) -- start background music
 -- load high scores
 cartdata("stackarta_v1")
 best_wave=dget(0)
 best_kills=dget(1)
end

function start_game()
 state="plan"
 wave_num=1
 energy=3
 core_hp=10
 kills=0
 paused=false
 mulligan_used=false
 show_deck=false
 endless_mode=false
 grid={}
 deck={}
 hand={}
 discard={}
 towers={}
 enemies={}
 particles={}
 cur_x=5
 cur_y=5
 init_grid()
 init_deck()
 draw_hand(3)
 update_pathfinding()
 music(0) -- restart music
end

-- mulligan: discard hand and redraw (costs 1 energy, once per wave)
function mulligan()
 if mulligan_used then
  show_msg("already mulled")
  return false
 end
 if energy<1 then
  show_msg("need 1 nrg")
  return false
 end
 if #hand==0 then
  show_msg("no cards")
  return false
 end
 -- discard hand
 for c in all(hand) do
  add(discard,c)
 end
 hand={}
 -- pay cost and redraw
 energy-=1
 draw_hand(3)
 mulligan_used=true
 sfx(1)
 show_msg("mulligan!")
 return true
end

-- upgrade tower: spend energy to add +1 dmg or +1 rng
function upgrade_tower(stat)
 local tile=grid[cur_y][cur_x]
 if tile.type!=2 then
  show_msg("no tower")
  return false
 end
 if energy<2 then
  show_msg("need 2 nrg")
  return false
 end
 energy-=2
 if stat=="dmg" then
  tile.buff_dmg+=1
  show_msg("+1 dmg")
 else
  tile.buff_rng+=1
  show_msg("+1 rng")
 end
 sfx(1)
 return true
end

-- cycle tower targeting mode
function cycle_target_mode()
 local tile=grid[cur_y][cur_x]
 if tile.type!=2 or not tile.occupant then
  return false
 end
 local t=tile.occupant
 t.tgt_mode=(t.tgt_mode%3)+1
 show_msg("target:"..tgt_modes[t.tgt_mode])
 return true
end

function save_highscore()
 local dominated=false
 if wave_num>best_wave then
  best_wave=wave_num
  dset(0,best_wave)
  dominated=true
 end
 if kills>best_kills then
  best_kills=kills
  dset(1,best_kills)
  dominated=true
 end
 return dominated
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
  reload=0,
  tgt_mode=1 -- 1=near, 2=strong, 3=fast
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

-- sell a tower/trap (refund 1 energy)
function sell_tower()
 local tile=grid[cur_y][cur_x]

 -- must be tower or trap
 if tile.type!=2 and tile.type!=3 then
  return false
 end

 -- remove from towers list
 if tile.occupant then
  del(towers,tile.occupant)
 end

 -- clear tile
 tile.type=0
 tile.occupant=nil

 -- refund energy
 energy=min(energy+1,max_energy+2)

 -- update pathfinding
 update_pathfinding()

 sfx(1)
 show_msg("sold +1 nrg")
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

 if state=="title" then
  title_t+=1
  -- difficulty selection
  if btnp(0) then difficulty=max(1,difficulty-1) end
  if btnp(1) then difficulty=min(3,difficulty+1) end
  if btnp(4) or btnp(5) then
   start_game()
  end
 elseif state=="plan" then
  update_plan()
 elseif state=="wave" then
  update_wave()
 elseif state=="reward" then
  update_reward()
 elseif state=="victory_choice" then
  -- z: end game, x: endless mode
  if btnp(4) then
   state="gameover"
   music(-1)
  elseif btnp(5) then
   endless_mode=true
   mulligan_used=false
   energy=max_energy+flr(wave_num/5)
   draw_hand(3)
   state="reward"
   init_reward()
   show_msg("endless mode!")
  end
 end
end

function update_plan()
 -- if deck viewer open
 if show_deck then
  -- x: mulligan from deck viewer
  if btnp(5) then
   if mulligan() then
    show_deck=false
   end
   return
  end
  -- any other button closes it
  if btnp(4) or btnp(0) or btnp(1) or btnp(2) or btnp(3) then
   show_deck=false
  end
  return
 end

 -- deck viewer toggle (z + up)
 if btn(4) and btnp(2) then
  show_deck=true
  return
 end

 -- cursor movement (up cycles target mode if on tower)
 if btnp(0) then cur_x=max(0,cur_x-1) end
 if btnp(1) then cur_x=min(9,cur_x+1) end
 if btnp(2) then
  local tile=grid[cur_y][cur_x]
  if tile.type==2 and tile.occupant then
   cycle_target_mode()
  else
   cur_y=max(0,cur_y-1)
  end
 end
 if btnp(3) then cur_y=min(9,cur_y+1) end

 -- card selection (left/right while holding down)
 if btn(3) then
  if btnp(0) then cur_sel=max(1,cur_sel-1) end
  if btnp(1) then cur_sel=min(#hand,cur_sel+1) end
 end

 -- play card (o button)
 if btnp(4) then
  local tile=grid[cur_y][cur_x]
  -- if on tower, upgrade dmg
  if tile.type==2 then
   upgrade_tower("dmg")
  else
   play_card()
  end
 end

 -- x button: context-sensitive
 if btnp(5) then
  local tile=grid[cur_y][cur_x]
  if tile.type==2 then
   -- on tower: tap for upgrade rng, z+x for sell
   if btn(4) then
    sell_tower()
   else
    upgrade_tower("rng")
   end
  elseif tile.type==3 then
   sell_tower()
  else
   burn_card()
  end
 end

 -- start wave when hand is empty
 if #hand==0 then
  start_wave()
 end
end

-- difficulty multipliers: {hp, spd, cnt}
diff_mult={
 {0.7,0.85,0.8},  -- easy
 {1,1,1},         -- normal
 {1.4,1.15,1.2}   -- hard
}

-- get wave info for preview (returns table)
function get_wave_info(w)
 local dm=diff_mult[difficulty]
 -- special waves every 5 (elites) and every 10 (boss)
 if w%10==5 then
  local scale=1+flr(w/10)*0.5 -- harder elites in endless
  return {cnt=flr(6*dm[3]*scale),hp=flr(15*dm[1]*scale),spd=0.3*dm[2],type="elite",mix={}}
 end
 if w%10==0 then
  local scale=1+flr(w/10-1)*0.8 -- harder bosses in endless
  return {cnt=1,hp=flr(250*dm[1]*scale),spd=0.2*dm[2],type="boss",mix={}}
 end
 -- enemy mix based on wave
 local mix={"normal"}
 if w>=2 then add(mix,"scout") end -- scouts from wave 2
 if w>=4 then add(mix,"tank") end  -- tanks from wave 4
 if w>=6 then add(mix,"swarm") end -- swarms from wave 6
 return {
  cnt=flr((5+(w*2))*dm[3]),
  hp=flr(2*(1.2^(w-1))*dm[1]),
  spd=min((0.4+(w*0.05))*dm[2],1.4),
  type="normal",
  mix=mix
 }
end

function init_wave(w)
 local info=get_wave_info(w)
 wave_cnt=info.cnt
 wave_hp=info.hp
 wave_spd=info.spd
 wave_type=info.type
 wave_mix=info.mix
 -- spawn delay
 if w==5 then
  spawn_delay=90
 elseif w==10 then
  spawn_delay=0
 else
  spawn_delay=60-min(w*2,30)
 end
end

function start_wave()
 state="wave"
 spawn_timer=0
 spawned=0
 init_wave(wave_num)
 -- boss warning for wave 10
 if wave_num==10 then
  boss_warn=90 -- 3 second warning
 else
  boss_warn=0
 end
end

function update_wave()
 -- pause toggle (o+x)
 if btn(4) and btn(5) then
  if not pause_held then
   paused=not paused
   pause_held=true
  end
 else
  pause_held=false
 end

 -- skip updates when paused
 if paused then return end

 -- boss warning countdown
 if boss_warn>0 then
  boss_warn-=1
  if boss_warn==60 then shake=8 end
  if boss_warn==30 then shake=12 end
  return
 end

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

 -- remove dead enemies (spawn death particles)
 for i=#enemies,1,-1 do
  local e=enemies[i]
  if e.hp<=0 then
   -- count kill (not leak)
   if not e.leaked then
    kills+=1
   end
   -- particle color based on enemy type
   local edef=enemy_types[e.etype] or enemy_types.normal
   local col=edef.col
   local cnt=6
   if e.etype=="elite" then cnt=10
   elseif e.etype=="boss" then cnt=20
   elseif e.etype=="swarm" then cnt=3
   elseif e.etype=="tank" then cnt=12
   end
   spawn_particles(e.x,e.y,col,cnt)
   deli(enemies,i)
  end
 end

 -- update particles
 update_particles()

 -- check wave complete
 if spawned>=wave_cnt and #enemies==0 then
  end_wave()
 end

 -- check game over
 if core_hp<=0 then
  state="gameover"
  music(-1) -- stop music
  save_highscore()
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

 -- pick enemy type from wave mix
 local etype=wave_type
 if wave_mix and #wave_mix>0 then
  etype=wave_mix[flr(rnd(#wave_mix))+1]
 end
 local edef=enemy_types[etype] or enemy_types.normal

 -- apply type multipliers
 local hp=flr(wave_hp*edef.hp)
 local spd=wave_spd*edef.spd

 -- swarm spawns 3 enemies at once
 local count=1
 if etype=="swarm" then count=3 end

 for i=1,count do
  local ox=(i-1)*4 -- offset for swarm cluster
  add(enemies,{
   x=px+ox,y=py,
   gx=gx,gy=gy,
   hp=hp,
   max_hp=hp,
   spd=spd,
   slowed=0,
   etype=etype,
   armor=edef.armor
  })
 end
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
  -- spike trap deals damage once then disappears
  if trap.def.name=="spike" and not trap.used then
   e.hp-=trap.def.dmg+tile.buff_dmg
   trap.used=true
   -- remove spike from grid
   tile.type=0
   tile.occupant=nil
   del(towers,trap)
   sfx(0)
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
  e.leaked=true -- not a kill
  shake=12 -- intense screen shake
  sfx(2) -- core hit sound
  -- spawn warning particles at core
  spawn_particles(core_px,core_py,8,8)
 end
end

function update_tower(t)
 if t.def.type=="trap" then return end

 t.reload-=1
 if t.reload>0 then return end

 local stats=get_tower_stats(t)
 local px=grid_ox+t.gx*tile_sz+4
 local py=grid_oy+t.gy*tile_sz+4

 -- aoe tower hits all in range
 if t.def.aoe then
  local hit_any=false
  for e in all(enemies) do
   local dx=e.x-px
   local dy=e.y-py
   local d=sqrt(dx*dx+dy*dy)
   if d<=stats.rng then
    local dmg=max(1,stats.dmg-(e.armor or 0))
    e.hp-=dmg
    hit_any=true
   end
  end
  if hit_any then
   t.reload=stats.rate
   t.fire_t=6
   t.aoe_pulse=8
   sfx(0)
  end
  return
 end

 -- find target based on targeting mode
 local target=nil
 local best_val=nil
 local mode=t.tgt_mode or 1

 for e in all(enemies) do
  local dx=e.x-px
  local dy=e.y-py
  local d=sqrt(dx*dx+dy*dy)
  if d<=stats.rng then
   local val
   if mode==1 then
    -- nearest: lowest distance
    val=-d
   elseif mode==2 then
    -- strongest: highest hp
    val=e.hp
   else
    -- fastest: highest speed
    val=e.spd
   end
   if best_val==nil or val>best_val then
    best_val=val
    target=e
   end
  end
 end

 if target then
  local dmg=max(1,stats.dmg-(target.armor or 0))
  target.hp-=dmg
  t.reload=stats.rate
  t.last_target=target
  t.fire_t=4
  sfx(0) -- fire sound
 end
end

-- particle system for death effects
function spawn_particles(x,y,col,count)
 count=count or 6
 for i=1,count do
  local angle=rnd(1)
  local spd=0.5+rnd(1.5)
  add(particles,{
   x=x,y=y,
   dx=cos(angle)*spd,
   dy=sin(angle)*spd,
   col=col,
   life=15+flr(rnd(10))
  })
 end
end

function update_particles()
 for i=#particles,1,-1 do
  local p=particles[i]
  p.x+=p.dx
  p.y+=p.dy
  p.dy+=0.1 -- gravity
  p.life-=1
  if p.life<=0 then
   deli(particles,i)
  end
 end
end

function draw_particles()
 for p in all(particles) do
  local col=p.col
  if p.life<5 then col=5 end -- fade to dark
  pset(p.x,p.y,col)
 end
end

function end_wave()
 wave_num+=1

 -- wave 10 complete: offer endless mode or victory
 if wave_num==11 and not endless_mode then
  state="victory_choice"
  sfx(6) -- victory fanfare
  save_highscore()
  return
 end

 -- refill energy
 energy=max_energy+flr(wave_num/5)

 -- reset mulligan
 mulligan_used=false

 -- draw new hand
 draw_hand(3)

 -- go to reward or plan
 state="reward"
 init_reward()
end

-- reward state
reward_cards={}
reward_sel=1

-- get reward tier based on wave
function get_reward_tier(w)
 if w<=3 then return 1 end
 if w<=6 then return 2 end
 return 3
end

-- get cards of specific rarity
function get_cards_by_rar(rar)
 local pool={}
 for c in all(card_defs) do
  if c.rar==rar then add(pool,c) end
 end
 return pool
end

function init_reward()
 reward_cards={}
 local tier=get_reward_tier(wave_num-1)
 local pool=get_cards_by_rar(tier)
 -- fallback if pool empty
 if #pool==0 then pool=card_defs end
 for i=1,3 do
  local idx=flr(rnd(#pool))+1
  add(reward_cards,pool[idx])
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

 if state=="title" then
  draw_title()
  camera(0,0)
  return
 end

 if state=="gameover" then
  draw_gameover()
  return
 end

 if state=="victory_choice" then
  draw_victory_choice()
  return
 end

 draw_grid()
 draw_towers()
 draw_enemies()
 draw_particles()
 draw_cursor()
 draw_ui()

 -- wave status panel
 if state=="wave" then
  rectfill(0,90,127,99,1)
  line(0,90,127,90,5)
  local remaining=wave_cnt-spawned+#enemies
  -- show wave type
  local wlbl="wave "..wave_num
  local wcol=7
  if wave_type=="elite" then
   wlbl="elites!"
   wcol=10
  elseif wave_type=="boss" then
   wlbl="!! boss !!"
   wcol=14
  end
  print(wlbl,4,92,wcol)
  print("enemies:"..remaining,50,92,8)
  -- progress bar
  local prog=1-(remaining/(wave_cnt))
  rectfill(100,92,124,97,5)
  rectfill(100,92,100+24*prog,97,11)
  rect(100,92,124,97,6)
 end

 if state=="reward" then
  draw_reward()
 end

 -- boss warning overlay
 if boss_warn and boss_warn>0 then
  -- flashing background
  local flash=boss_warn%10<5
  if flash then
   rectfill(0,0,127,127,2)
  end
  -- warning box
  rectfill(20,45,108,75,0)
  rect(20,45,108,75,8)
  rect(21,46,107,74,14)
  -- text
  local pulse=boss_warn%6<3
  print("!! warning !!",34,50,pulse and 8 or 14)
  print("boss incoming",34,60,7)
  -- countdown dots
  local dots=flr(boss_warn/30)+1
  for i=1,dots do
   circfill(54+i*8,70,2,14)
  end
 end

 -- pause overlay
 if paused and state=="wave" then
  rectfill(30,45,98,80,0)
  rect(30,45,98,80,7)
  rect(31,46,97,79,5)
  print("paused",50,50,7)
  print("o+x: resume",40,62,6)
  print("z: restart",43,70,6)
  -- restart option
  if btnp(4) and not btn(5) then
   paused=false
   start_game()
  end
 end

 -- message
 if msg_t>0 and not paused then
  rectfill(40,56,88,68,0)
  rect(40,56,88,68,7)
  local mx=64-#msg*2
  print(msg,mx,60,7)
 end

 -- deck viewer overlay
 if show_deck and state=="plan" then
  draw_deck_viewer()
 end

 camera(0,0)
end

function draw_deck_viewer()
 rectfill(10,15,118,85,0)
 rect(10,15,118,85,7)
 rect(11,16,117,84,5)
 print("deck ("..#deck+#discard.." cards)",30,18,7)

 -- count cards by type
 local counts={}
 for c in all(deck) do
  local n=c.def.name
  counts[n]=(counts[n] or 0)+1
 end
 for c in all(discard) do
  local n=c.def.name
  counts[n]=(counts[n] or 0)+1
 end

 -- display counts
 local y=28
 local x=14
 local col=0
 for _,def in ipairs(card_defs) do
  local cnt=counts[def.name] or 0
  if cnt>0 then
   print(def.name..":"..cnt,x,y,def.col)
   col+=1
   if col>=2 then
    col=0
    y+=8
    x=14
   else
    x=68
   end
  end
 end

 -- show deck/discard split
 print("draw:"..#deck.." disc:"..#discard,24,72,6)
 -- mulligan option
 if not mulligan_used and #hand>0 then
  print("x: mulligan (1 nrg)",22,78,10)
 else
  print("mulligan used",34,78,5)
 end
 print("any key to close",28,84,5)
end

function draw_victory_choice()
 cls(0)

 -- celebration particles
 for i=0,20 do
  local x=rnd(128)
  local y=rnd(60)
  pset(x,y,rnd(16))
 end

 rectfill(14,20,114,70,1)
 rect(14,20,114,70,11)
 rect(15,21,113,69,10)

 print("victory!",46,25,11)
 print("core defended!",32,35,7)
 print("wave 10 complete",28,45,6)

 print("z: end game",40,58,7)
 print("x: endless mode",32,66,10)

 -- stats below
 print("kills: "..kills,48,80,6)
 print("["..diff_names[difficulty].."]",48,90,6)
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
  elseif t.def.name=="spike" then
   -- spikes (X pattern)
   line(px+1,py+1,px+6,py+6,col)
   line(px+6,py+1,px+1,py+6,col)
   pset(px+4,py+4,7)
  elseif t.def.name=="blaster" then
   -- circle with rays
   circfill(px+4,py+4,2,col)
   pset(px+4,py+1,col)
   pset(px+4,py+7,col)
   pset(px+1,py+4,col)
   pset(px+7,py+4,col)
  elseif t.def.name=="rapid" then
   -- double barrel
   rectfill(px+2,py+2,px+3,py+6,col)
   rectfill(px+5,py+2,px+6,py+6,col)
   pset(px+2,py+1,7)
   pset(px+5,py+1,7)
  end

  -- buff indicators (bottom corners)
  local tile=grid[t.gy][t.gx]
  if tile.buff_dmg>0 or tile.buff_rng>0 then
   -- glow outline for buffed towers
   rect(px,py,px+7,py+7,5)
  end
  -- dmg pips (red, bottom left)
  for i=1,min(tile.buff_dmg,3) do
   pset(px+i-1,py+7,8)
  end
  -- rng pips (blue, bottom right)
  for i=1,min(tile.buff_rng,3) do
   pset(px+8-i,py+7,12)
  end
  -- targeting mode indicator (top right corner)
  if t.tgt_mode and t.tgt_mode>1 then
   local tcol=t.tgt_mode==2 and 8 or 11 -- red for strong, yellow for fast
   pset(px+7,py,tcol)
  end

  -- aoe pulse effect
  if t.aoe_pulse and t.aoe_pulse>0 then
   local stats=get_tower_stats(t)
   circ(px+4,py+4,stats.rng*(t.aoe_pulse/8),9)
   t.aoe_pulse-=1
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
  local edef=enemy_types[e.etype] or enemy_types.normal
  local col=edef.col
  if e.slowed>0 then col=1 end

  if e.etype=="boss" then
   -- boss: large pulsing circle
   local pulse=sin(time()*3)*1
   circfill(e.x,e.y,5+pulse,14)
   circfill(e.x,e.y,3,15)
   -- boss hp bar (wider)
   local hp_w=12*e.hp/e.max_hp
   rectfill(e.x-6,e.y-8,e.x-6+hp_w,e.y-6,11)
   rect(e.x-6,e.y-8,e.x+6,e.y-6,0)
  elseif e.etype=="elite" then
   -- elite: larger yellow diamond
   local c=e.slowed>0 and 1 or 10
   line(e.x,e.y-3,e.x+3,e.y,c)
   line(e.x+3,e.y,e.x,e.y+3,c)
   line(e.x,e.y+3,e.x-3,e.y,c)
   line(e.x-3,e.y,e.x,e.y-3,c)
   pset(e.x,e.y,9)
   -- elite hp bar
   local hp_w=6*e.hp/e.max_hp
   rectfill(e.x-3,e.y-5,e.x-3+hp_w,e.y-4,11)
  elseif e.etype=="scout" then
   -- scout: small fast triangle
   line(e.x,e.y-2,e.x+2,e.y+1,col)
   line(e.x+2,e.y+1,e.x-2,e.y+1,col)
   line(e.x-2,e.y+1,e.x,e.y-2,col)
  elseif e.etype=="tank" then
   -- tank: large armored square with border
   rectfill(e.x-3,e.y-3,e.x+3,e.y+3,col)
   rect(e.x-3,e.y-3,e.x+3,e.y+3,5)
   pset(e.x,e.y,0) -- armor core
   -- tank hp bar
   local hp_w=6*e.hp/e.max_hp
   rectfill(e.x-3,e.y-5,e.x-3+hp_w,e.y-4,11)
  elseif e.etype=="swarm" then
   -- swarm: tiny dot
   circfill(e.x,e.y,1,col)
  else
   -- normal: red square
   rectfill(e.x-2,e.y-2,e.x+2,e.y+2,col)
   -- hp bar
   local hp_w=4*e.hp/e.max_hp
   rectfill(e.x-2,e.y-4,e.x-2+hp_w,e.y-3,11)
  end
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
 -- top bar background
 rectfill(0,0,127,9,1)
 line(0,9,127,9,5)

 -- energy section (left)
 print("\x8b",1,2,10) -- lightning bolt
 for i=1,max_energy+2 do
  local col=5 -- dark bg
  if i<=energy then col=10 end -- yellow if filled
  rectfill(8+i*5,2,8+i*5+3,6,col)
 end

 -- core hp section (center-right)
 print("\x96",68,2,8) -- heart
 rectfill(76,2,116,6,5) -- bg bar
 local hp_w=40*core_hp/max_core_hp
 rectfill(76,2,76+hp_w,6,8) -- hp bar
 rect(76,2,116,6,6) -- border

 -- wave indicator (right)
 rectfill(119,1,127,8,0)
 local wcol=7
 if endless_mode then wcol=10 end
 print(wave_num,121,2,wcol)

 -- hand (bottom)
 if state=="plan" then
  draw_hand_ui()
 end

 -- tile info panel (bottom left)
 if state=="plan" then
  local tile=grid[cur_y][cur_x]
  if tile.buff_dmg>0 or tile.buff_rng>0 or tile.heat>0 then
   rectfill(0,112,40,127,1)
   rect(0,112,40,127,5)
   local ty=114
   if tile.buff_dmg>0 then
    print("dmg+"..tile.buff_dmg,2,ty,8)
    ty+=6
   end
   if tile.buff_rng>0 then
    print("rng+"..tile.buff_rng,2,ty,12)
    ty+=6
   end
   if tile.heat>0 then
    print("heat:"..tile.heat,2,ty,9)
   end
  end

  -- wave preview panel (bottom right)
  local info=get_wave_info(wave_num)
  local wcol=6
  if info.type=="elite" then wcol=10
  elseif info.type=="boss" then wcol=14 end
  rectfill(87,104,127,127,1)
  rect(87,104,127,127,5)
  print("wave "..wave_num,89,106,wcol)
  print("x"..info.cnt,89,113,7)
  print("hp:"..flr(info.hp),105,113,8)
  -- show enemy type icons
  if info.mix and #info.mix>0 then
   local mx=89
   for i,et in ipairs(info.mix) do
    local ec=enemy_types[et].col
    pset(mx,121,ec)
    pset(mx+1,121,ec)
    mx+=4
   end
  else
   print("spd:"..info.spd,89,120,12)
  end
 end
end

function draw_hand_ui()
 -- hand panel background
 rectfill(0,91,127,127,1)
 line(0,91,127,91,5)

 -- deck count (top left of hand panel)
 print("\x83"..#deck+#discard,2,93,5)

 if #hand==0 then
  print("- wave starts -",32,108,5)
  return
 end

 -- card stats preview (top line)
 local card=hand[cur_sel]
 local def=card.def
 local stats=""
 if def.type=="tower" then
  stats="d:"..def.dmg.." r:"..def.rng.." f:"..def.rate
  if def.aoe then stats=stats.." aoe" end
 elseif def.type=="trap" then
  if def.name=="slower" then stats="slows 50%"
  elseif def.name=="spike" then stats="d:"..def.dmg.." once" end
 elseif def.type=="boost" then
  if def.dmg>0 then stats="+"..def.dmg.."dmg" end
  if def.rng>0 then stats=stats.."+"..def.rng.."rng" end
 end
 print(stats,4,93,5)

 -- instructions (right side)
 local tile=grid[cur_y][cur_x]
 if tile.type==2 then
  -- show current targeting mode
  local t=tile.occupant
  local tmode=t and t.tgt_mode or 1
  print("\x83:"..tgt_modes[tmode],72,93,6)
 elseif tile.type==3 then
  print("z:play x:sell",72,93,6)
 else
  print("z:play x:burn",72,93,6)
 end
 -- mulligan hint
 if not mulligan_used and #hand>0 then
  print("\x8e",1,93,10) -- indicator for mulligan available
 end

 local y=100
 local start_x=64-(#hand*18)/2

 for i,card in ipairs(hand) do
  local x=start_x+(i-1)*18
  local cy=y
  local sel=i==cur_sel

  -- card shadow
  if sel then
   cy=y-3
   rectfill(x+1,cy+1,x+16,cy+23,0)
  end

  -- card bg
  local col=card.def.col
  rectfill(x,cy,x+15,cy+21,col)
  rect(x,cy,x+15,cy+21,sel and 7 or 5)

  -- card type icon
  local icon="\x8e" -- default
  if card.def.type=="tower" then icon="\x94"
  elseif card.def.type=="trap" then icon="\x97"
  elseif card.def.type=="boost" then icon="\x8b"
  end
  print(icon,x+1,cy+1,0)

  -- card name
  print(sub(card.def.name,1,5),x+1,cy+8,0)

  -- cost badge
  local cost=card.def.cost
  if sel then
   cost=get_place_cost(cur_x,cur_y,card)
  end
  circfill(x+12,cy+18,4,0)
  print(cost,x+10,cy+16,10)

  -- selection arrow
  if sel then
   print("\x83",x+5,cy+24,7)
  end
 end
end

function draw_reward()
 rectfill(20,40,108,88,0)
 rect(20,40,108,88,7)
 -- show tier label
 local tier=get_reward_tier(wave_num-1)
 local tlbl="common"
 local tcol=6
 if tier==2 then tlbl="rare" tcol=12
 elseif tier==3 then tlbl="legendary" tcol=10 end
 print(tlbl.." reward",38,44,tcol)

 for i=1,3 do
  local def=reward_cards[i]
  local x=24+(i-1)*30
  local y=54
  local col=def.col
  -- rarity border color
  local bcol=6
  if def.rar==2 then bcol=12
  elseif def.rar==3 then bcol=10 end

  if i==reward_sel then
   rect(x-1,y-1,x+26,y+28,7)
  end

  rectfill(x,y,x+25,y+27,col)
  rect(x,y,x+25,y+27,bcol)
  print(sub(def.name,1,6),x+1,y+2,0)
  print("c"..def.cost,x+1,y+12,0)
  if def.dmg>0 then print("d"..def.dmg,x+1,y+18,0) end
  if def.rng>0 then print("r"..def.rng,x+12,y+18,0) end
 end
end

function draw_title()
 -- animated background
 for i=0,15 do
  local y=(title_t*0.3+i*12)%140-10
  local x=sin(i*0.1+title_t*0.01)*20+64
  circfill(x,y,2,1)
 end

 -- title box
 rectfill(14,20,114,48,1)
 rect(14,20,114,48,12)
 rect(15,21,113,47,5)

 -- title text
 local bounce=sin(title_t*0.05)*2
 print("stackarta",34,26+bounce,12)
 print("stackarta",33,25+bounce,7)

 -- tagline
 print("burn the hand.",28,40,6)
 print("build the land.",26,46,6)

 -- decorative core
 local pulse=sin(title_t*0.1)*2
 circfill(64,64,6+pulse,14)
 circfill(64,64,4+pulse*0.5,15)

 -- difficulty selector
 local dcol={11,6,8}
 rectfill(30,76,98,88,1)
 rect(30,76,98,88,5)
 print("\139",32,80,6)
 print(diff_names[difficulty],50,80,dcol[difficulty])
 print("\145",90,80,6)

 -- instructions panel
 rectfill(24,92,104,114,1)
 rect(24,92,104,114,5)

 print("\x97 place towers",32,95,10)
 print("\x8e burn for buffs",30,102,8)
 print("z+\x83 deck",42,109,5)

 -- high score (if any)
 if best_wave>0 then
  print("best:w"..best_wave.." k"..best_kills,34,118,5)
 end

 -- start prompt
 local blink=title_t%40<20
 if blink then
  print("press z or x",36,125,7)
 end
end

function draw_gameover()
 cls(0)
 local dcol={11,6,8}
 if core_hp<=0 then
  print("game over",44,25,8)
  print("wave "..wave_num,48,35,7)
  if endless_mode then
   print("(endless)",46,42,10)
  end
 else
  print("victory!",46,25,11)
  print("core defended!",32,35,7)
 end
 -- difficulty and stats
 local dy=core_hp<=0 and 50 or 45
 print("["..diff_names[difficulty].."]",48,dy,dcol[difficulty])
 print("enemies slain: "..kills,28,dy+10,6)

 -- high scores
 local hy=core_hp<=0 and 70 or 65
 rectfill(24,hy,104,hy+30,1)
 rect(24,hy,104,hy+30,5)
 print("- best -",48,hy+3,6)
 print("wave: "..best_wave,36,hy+13,7)
 print("kills: "..best_kills,66,hy+13,7)
 -- new record indicator
 if wave_num>=best_wave or kills>=best_kills then
  print("*new*",52,hy+23,10)
 end

 print("z to restart",40,hy+40,5)

 if btnp(4) then
  start_game()
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
011800000c0430000000000000000070430000000000000000c0430000000000000000070430000000000000000c0430000000000000000070430000000000000000c043000000000000000007043000000000000
010800001815018150181501c1501c1501c1501f1501f1501815018150181501c1501c1501c1501f1501f1501815018150181501c1501c1501c1501f1501f1501815018150181501c1501c1501c1501f1501f150
011000000464000000106400000004640000001064000000046400000010640000000464000000106400000004640000001064000000046400000010640000000464000000106400000004640000001064000000
010400001815018150001501c1501c150001501f1501f150001502415024150001502815028150281500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 03040544
