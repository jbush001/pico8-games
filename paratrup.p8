pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- cannon control and main loop
-- todo:
--   make cannon barrel thicker

game_state_t = {
  gs_playing = 1,
  gs_game_over = 2
}

c_angle = 0
max_angle = 0.15
angle_step = max_angle / 16
bullets = {}
score = 0
gun_pivot_y = 115
game_state = game_state_t.gs_playing

function _init()
	for i = 1, 10 do
		bullets[i] = {
		 live = false,
		 x = 0,
		 y = 0,
		 xvel = 0,
		 yvel = 0,
		}
	end

 game_state = game_state_t.gs_playing	
	init_choppers()
end

function _update() 
 if game_state != game_state_t.gs_game_over then
	 if btn(0) and c_angle > -max_angle then
	 	c_angle = c_angle - angle_step
	 elseif btn(1) and c_angle < max_angle then
			c_angle = c_angle + angle_step
	 end
	
	 fire = btn(4)
	 if fire and not last_fire then
	  fire_bullet()
	 end
	 
	 last_fire = fire
 end

	for _, b in pairs(bullets) do
		if b.live then
		  b.x = b.x + b.xvel
		  b.y = b.y + b.yvel
		  if b.x < 0 or b.x > 128 or b.y < 0 then
		   b.live = false
		  end
		end
	end
	
	update_choppers()
	update_wreckage()
	update_troops()
end

function _draw()
 cls(12)
 print(score, 5, 5, 7)
 line(0, 127, 127, 127, 5)

 if game_state != game_state_t.gs_game_over then
		line(64, gun_pivot_y, 64 - sin(c_angle) * 8, gun_pivot_y - cos(c_angle) * 8, 15)
		circfill(64, gun_pivot_y, 4)
 end

	rectfill(54, gun_pivot_y, 74, 128, 5)

	for _, b in pairs(bullets) do
		if b.live then
		 pset(b.x, b.y, 15)
		end
	end

	draw_choppers()
	draw_wreckage()
	draw_troops()
	if game_state == game_state_t.gs_game_over then
	 print("game over", 48, 60)
	end
end

function trigger_game_over()
 if game_state == game_state_t.gs_playing then
  game_state = game_state_t.gs_game_over
	 for i = 1, 5 do
		 spawn_wreckage(64, 105, rnd(5) - 3, -rnd(5) - 2)
	 end
	end
end

function fire_bullet() 
	for _, b in pairs(bullets) do
		if not b.live then
		 b.live = true
		 b.x = 64 - sin(c_angle) * 8
		 b.y = gun_pivot_y - cos(c_angle) * 8
		 b.xvel = -sin(c_angle) * 4
		 b.yvel = -cos(c_angle) * 4
		 sfx(0)
		 if score > 0 then
		  score = score - 1
		 end
		 break
		end
	end
end

-->8
-- choppers
-- todo:
--  fix so these can't overlap
--  debris can destroy choppers

chopper = {
	anim_index = 0,
	x = 0,
	y = 0,
	facing = 1,
	drop_x = 0,
	dropped = false
}

chopper.__index = chopper
choppers = {}
respawn_delay = -1
chopper_speed = 2
max_choppers = 2

function chopper:create()
	local ch = {}
	setmetatable(ch, chopper)
	
	-- dont drop on turret
	if rnd(2) < 1 then
	 ch.drop_x = flr(rnd(6)) * 8
	else
  ch.drop_x = 74 + (flr(rnd(5)) * 8) + 2
	end

	return ch
end

function chopper:update()
	for _, b in pairs(bullets) do
		if b.live 
		 and b.x >= self.x 
		 and b.y >= self.y 
		 and b.x < self.x + 16 
		 and b.y < self.y + 16 then
			-- hit by bullet
			sfx(1)
			b.live = false
			if self.facing == 1 then
			 xv  = 1
			else
			 xv = -1
			end
			for i = 1,4 do
				spawn_wreckage(
				 self.x + rnd(12), 
				 self.y + rnd(12), 
				 xv * (rnd(2) + chopper_speed),
				 0)
			end
			return false
		end
	end

	self.anim_index = 1 - self.anim_index
	if self.facing == 0 then
	 self.x = self.x - chopper_speed
 if self.x < self.drop_x 
	 and not self.dropped then
   spawn_paratrooper(self.drop_x, self.y + 16)
   self.dropped = true
	 end	 
	else
	 self.x = self.x + chopper_speed
	 if self.x > self.drop_x 
	  and not self.dropped then
    spawn_paratrooper(self.drop_x, self.y + 16)
    self.dropped = true
	 end	 
	end
	
	if self.x < -16 or self.x > 128 then
	 return false
	end

 return true
end

function chopper:draw()
	spr(1 + self.anim_index * 2, self.x, self.y, 2, 2, self.facing == 0)
end

function init_choppers()
 respawn_delay = flr(rnd(15))
end

function update_choppers()
 for i = #choppers, 1, -1 do
   if not choppers[i]:update() then
    kill_chopper(choppers[i])
   end
	end
	
	if respawn_delay > 0 then
		respawn_delay = respawn_delay - 1
	elseif respawn_delay == 0 then
		respawn_chopper()
	end
end

function draw_choppers()
	for i = 1, #choppers do 
		choppers[i]:draw()
	end
end

function kill_chopper(ch)
 del(choppers, ch)
 score = score + 5
 if #choppers < max_choppers and respawn_delay < 0 then
		respawn_delay = flr(rnd(40)) + 20
	end
end

function respawn_chopper()
 if game_state != game_state_t.gs_playing then
  return
 end
 ch = chopper:create()

	ch.facing = flr(rnd(2))
	-- pick a side of screen
	if ch.facing == 0 then
		ch.x = 128
	else
		ch.x = -16
	end
	
	ch.y =  flr(rnd(8))
	add(choppers, ch)

	if #choppers < max_choppers then
		respawn_delay = flr(rnd(40)) + 20
	else
	 respawn_delay = -1
	end 
end

-->8
-- wreckage

wreckage = {
 x = 0,
 y = 0,
 xvel = 0,
 yvel = 0,
 sprite = 0
}

wreckage.__index = wreckage
wchunks = {}

function wreckage:create(x, y, xv, yv, sprite)
	local wr = {}
	setmetatable(wr, wreckage)
	wr.x = x
	wr.y = y
	wr.xvel = xv
	wr.yvel = yv
	if sprite == 0 then
 	wr.sprite = 5
 else
  wr.sprite = 21
 end
	return wr
end

function spawn_wreckage(x, y, xv, yv)
	add(wchunks, wreckage:create(x, y, xv, yv, flr(rnd(2))))
end

function update_wreckage()
 for i = #wchunks, 1, -1 do
  local wr = wchunks[i]
	 wr.x = wr.x + wr.xvel
	 wr.y = wr.y + wr.yvel
	 wr.yvel = wr.yvel + 0.4
	 if wr.x < -8 or wr.x > 128 or wr.y > 110 then
   del(wchunks, wr)
	 end
 end
end

function draw_wreckage() 
	for i = 1, #wchunks do
	 local wr = wchunks[i]
  spr(wr.sprite, wr.x, wr.y)
	end
end

-->8
-- paratroopers
-- todo:
--  when four paratroopers are on a side, animate them blowing up turett
--  show a skull when a paratrooper hits the ground and dies
--  show smaller wrecakge for killed paratroopers

para_state = {
 initial = 1,
 deployed = 2,
 landed = 3,
 falling = 4, -- chute shot off
 crushed = 5  -- someone landed on
}

paratrooper = {
 x = 0,
 y = 0,
 chute_delay = 0,
 state = para_state.initial,
}

paratrooper.__index = paratrooper
ptroops = {}
landed = {}

function paratrooper:create(x, y)
	local pt = {}
	setmetatable(pt, paratrooper)
	pt.x = x
	pt.y = y
	pt.chute_delay = 5 + flr(rnd(10))
	return pt
end

function paratrooper:update()
 -- need to clean up here to keep list
 -- intact.
 if self.state == para_state.crushed then
  return false
 end

 if self.state == para_state.initial then
  if self.chute_delay > 0 then
   self.chute_delay = self.chute_delay - 1
  else
   self.state = para_state.deployed
  end
 end

 gnd_level = landed[flr(self.x / 8)]
 if gnd_level == nil then
  gnd_level = 128
 end

 if self.y + 8 < gnd_level then
  if self.state == para_state.deployed then
   self.y += 1
  else
   self.y += 3
  end
 elseif self.state == para_state.falling then
  -- crater
  sfx(2)
	 for j = 1, #ptroops do
	  if ptroops[j].x == self.x and ptroops[j] != self and ptroops[j].state == para_state.landed then
	   ptroops[j].state = para_state.crushed
	  end
	 end
	 
	 -- reset landing height
	 landed[flr(self.x / 8)] = nil
  return false
 elseif self.state != para_state.landed then
  self.state = para_state.landed
  landed[flr(self.x / 8)] = self.y

  if check_ground_count() then
   trigger_game_over()
  end
 end

 -- check bullet collisions  
	for _, b in pairs(bullets) do
 	if b.live and b.x >= self.x and b.x < self.x + 8 and b.y > self.y - 16 and b.y < self.y + 8 then
 	 if self.state == para_state.deployed and b.y < self.y then
 	  -- struck the chute
 	  self.state = para_state.falling
 	  b.live = false
 	 elseif b.y >= self.y then
 	  -- on the body 
 	  b.live = false
    score = score + 5
    sfx(2)
    return false
 	 end
  end
 end
 
 -- wreckage can kill paratroops
 for i = 1, #wchunks do
  local wc = wchunks[i]
  if wc.x < self.x + 8 
   and wc.x + 8 > self.x 
   and wc.y + 8 > self.y 
   and wc.y < self.y + 8 then
   sfx(2)
   return false
  end
 end	  
 
 return true
end

function paratrooper:draw()
	spr(22, self.x, self.y)
	if self.state == para_state.deployed then
	 spr(6, self.x, self.y - 8)
	end
end

function spawn_paratrooper(x, y)
 if game_state == game_state_t.gs_playing then
  add(ptroops, paratrooper:create(x, y))
 end
end

function update_troops()
	for i = #ptroops, 1, -1 do
  if not ptroops[i]:update() then
   del(ptroops, ptroops[i])
	 end
	end
end

function draw_troops()
	for i = #ptroops, 1, -1 do
	 ptroops[i]:draw()
	end
end

function check_ground_count()
 left_count = 0
 right_count = 0
 for j = 1, #ptroops do
  if ptroops[j].state == para_state.landed then
   if ptroops[j].x < 64 then
    left_count = left_count + 1
   else 
    right_count = right_count + 1
   end
  end
 end

 return left_count >= 4 or right_count >= 4
end

__gfx__
00000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000330000000111100000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000030300001111110000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000033333300000333333000000033300011111111000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000030000000000000003000000033530011111111000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000030000000000000003000000003550001000010000000000000000000000000000000000000000000000000000000000000000000000000
00000000330000003333330033000000333333000003333000100100000000000000000000000000000000000000000000000000000000000000000000000000
00000000330000033333313033000003333331300000000000100100000000000000000000000000000000000000000000000000000000000000000000000000
00000000333333333333311333333333333331130000000000033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000033333333333333303333333333333330003000000033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000033333333000000003333333300000305303333330000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003333330000000000333333000003333300033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000033300000033000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000300300000300300000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000030000300300000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000003000300300000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003805000000220002b050000000400000000250500500001000000001e0500000000000000001805000000000000400012050000000000000000000000000000000000000000000000000000000000000
000900001365009640056200550008600026001160008500096001760005600156000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900000f0500a05008050030000d000270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000038150371500000038150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
