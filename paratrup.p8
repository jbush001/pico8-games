pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- cannon control

c_angle = 0
max_angle = 0.15
angle_step = max_angle / 16
bullets = {}
game_over = false
score = 0
gun_pivot_y = 115

function _init()
	for i=1,10,1 do
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
	 ch.drop_x = flr(rnd(48))
	else
  ch.drop_x = flr(rnd(40)) + 74
	end
	return ch
end

function chopper:update()
	self.anim_index = 1 - self.anim_index
	if self.facing == 0 then
	 self.x = self.x - chopper_speed
	 if self.x < self.drop_x and not self.dropped then
    spawn_paratrooper(self.x, self.y + 16)
    self.dropped = true
	 end	 
	else
	 self.x = self.x + chopper_speed
	 if self.x > self.drop_x and not self.dropped then
    spawn_paratrooper(self.x, self.y + 16)
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
	check_chopper_collision()

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
	for _, ch in pairs(choppers) do
		ch:draw()
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

function check_chopper_collision() 
	for _, b in pairs(bullets) do
		if b.live then
			for i = #choppers, 1, -1 do
			 if b.x >= ch.x and b.y >= ch.y and b.x < ch.x + 16 and b.y < ch.y + 16 then
					-- hit
					sfx(1)
					b.live = false
					if ch.facing == 1 then
					 xv  = 1
					else
					 xv = -1
					end
					for i = 1,4 do
						spawn_wreckage(ch.x + rnd(12), ch.y + rnd(12), xv * (rnd(2) + chopper_speed))
					end
					kill_chopper(ch)
				end
		 end	
		end
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
paratrooper = {
 x = 0,
 y = 0,
 para_delay = 0,
 para_deployed = false,
 landed = false
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
	pt.para_delay = 5 + flr(rnd(10))
	return pt
end

function spawn_paratrooper(x, y)
 if not game_over then
  add(ptroops, paratrooper:create(x, y))
 end
end

function update_paras()
	for i = #ptroops, 1, -1 do
  local pt = ptroops[i]
  if not pt.para_deployed then
   if pt.para_delay > 0 then
    pt.para_delay = pt.para_delay - 1
   else
    pt.para_deployed = true
   end
  end
  
  if pt.y < 120 then
   if pt.para_deployed then
    pt.y += 1
   else
    pt.y += 3
   end
  elseif not pt.landed then
   pt.landed = true
   if pt.x < 64 then
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
	 	if b.live and b.x >= pt.x and b.y >= pt.y and b.x < pt.x + 8 and b.y < pt.y + 8 then
    del(ptroops, pt)
    score = score + 5
    sfx(2)
	  end
	 end
	 
	 -- wreckage can kill paratroops
  for i = 1, #wchunks do
   local wc = wchunks[i]
   if wc.x < pt.x + 8 and pt.x < wc.x + 8 and pt.y < wc.y + 8 and wc.y < pt.y + 8 then
    del(ptroops, pt)
    sfx(2)
   end
  end	  
	end
end

function draw_paras()
	for i = #ptroops, 1, -1 do
	 local pt = ptroops[i]
		spr(22, pt.x, pt.y)
		if pt.para_deployed and not pt.landed then
		 spr(6, pt.x, pt.y - 8)
		end
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
00100000386302e620176201060009600026000060018600176001760016600156000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001100001905012050170500d0500d000270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
