pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- cannon control and main loop
-- todo:
--   make cannon barrel thicker


c_angle = 0
max_angle = 0.15
angle_step = max_angle / 16
bullets = {}
game_over = false
score = 0
gun_pivot_y = 115

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
	
	init_choppers()
end

function _update() 
 if not game_over then
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
	update_paras()
end

function _draw()
 cls()
 print(score, 5, 5)
	line(64, gun_pivot_y, 64 - sin(c_angle) * 8, gun_pivot_y - cos(c_angle) * 8, 15)
	circfill(64, gun_pivot_y, 4)
	rectfill(54, gun_pivot_y, 74, 128)
	for _, b in pairs(bullets) do
		if b.live then
		 pset(b.x, b.y, 15)
		end
	end

	draw_choppers()
	draw_wreckage()
	draw_paras()
	if game_over then
	 print("game over", 48, 60)
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
	if flr(rnd(2)) == 0 then
	 ch.drop_x = flr(rnd(6)) * 8
	else
  ch.drop_x = (flr(rnd(5)) * 8) + 2
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
				 xv * (rnd(2) + chopper_speed))
			end
			return false
		end
	end

	self.anim_index = 1 - self.anim_index
	if self.facing == 0 then
	 self.x = self.x - chopper_speed
	 if self.x < self.drop_x and not self.dropped then
    spawn_paratrooper(self.drop_x, self.y + 16)
    self.dropped = true
	 end	 
	else
	 self.x = self.x + chopper_speed
	 if self.x > self.drop_x and not self.dropped then
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
 if game_over then
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
}

wreckage.__index = wreckage
wchunks = {}

function wreckage:create(x, y, xv)
	local wr = {}
	setmetatable(wr, wreckage)
	wr.x = x
	wr.y = y
	wr.xvel = xv
	return wr
end

function spawn_wreckage(x, y, xv)
	add(wchunks, wreckage:create(x, y, xv))
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
  spr(5, wr.x, wr.y)
	end
end

-->8
-- paratroopers
-- todo:
--  if a paratrooper lands on another, stack
--  when four paratroopers are on a side, animate them blowing up turett
--  if a paratrooper falls on another one, kill the one on the ground
--  show a skull when a paratrooper hits the ground and dies

para_state = {
 initial = 1,
 deployed = 2,
 landed = 3,
 falling = 4 -- chute shot off
}

paratrooper = {
 x = 0,
 y = 0,
 chute_delay = 0,
 state = para_state.initial,
}

paratrooper.__index = paratrooper
ptroops = {}
left_landed = 0
right_landed = 0

function paratrooper:create(x, y)
	local pt = {}
	setmetatable(pt, paratrooper)
	pt.x = x
	pt.y = y
	pt.chute_delay = 5 + flr(rnd(10))
	return pt
end

function paratrooper:update()
 if self.state == para_state.initial then
  if self.chute_delay > 0 then
   self.chute_delay = self.chute_delay - 1
  else
   self.state = para_state.deployed
  end
 end
 
 if self.y < 120 then
  if self.state == para_state.deployed then
   self.y += 1
  else
   self.y += 3
  end
 elseif self.state == para_state.falling then
  -- crater
  return false
 elseif self.state != para_state.landed then
  self.state = para_state.landed
  if self.x < 64 then
   left_landed = left_landed + 1
  else
   right_landed = right_landed + 1
  end
  if left_landed == 4 or right_landed == 4 then
   game_over = true
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
  if wc.x < self.x + 8 and self.x < self.x + 8 and self.y < wc.y + 8 and wc.y < self.y + 8 then
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
 if not game_over then
  add(ptroops, paratrooper:create(x, y))
 end
end

function update_paras()
	for i = #ptroops, 1, -1 do
  if not ptroops[i]:update() then
   del(ptroops, ptroops[i])
	 end
	end
end

function draw_paras()
	for i = #ptroops, 1, -1 do
	 ptroops[i]:draw()
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000070700000777700000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000077777700000777777000000077700077777777000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000070000000000000007000000077770077777777000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000070000000000000007000000007770007000070000000000000000000000000000000000000000000000000000000000000000000000000
00000000770000007777770077000000777777000007777000700700000000000000000000000000000000000000000000000000000000000000000000000000
00000000770000077777717077000007777771700000000000700700000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777777777711777777777777771170000000000077000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077777777777777707777777777777770000000000077000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000077777777000000007777777700000000007777770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777770000000000777777000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000700700000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000700700000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000700700000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003805000000220002b050000000400000000250500500001000000001e0500000000000000001805000000000000400012050000000000000000000000000000000000000000000000000000000000000
000d0000206301b620176200e61000610026000060018600176001760016600156000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900001905012050170500d0500d000270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
