pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- defines/constants
flg_solid=0 -- cannot walk through
flg_draw_over=1 -- player walks under
flg_transparent=2 -- can see through
flg_door=3 -- needs key

snd_grab_item=0
snd_alert=1
snd_door=4

function can_move(x, y)
	return not fget(mget(x / 8, y / 8), flg_solid)
end

-->8
-- player

player = {
	anim_count = 0,
	facing = 0,
	frame = 0,
	x_mirror = false,
 has_key = false
}
player.__index = player

function player:create(x, y)
	local pl = {}
	setmetatable(pl, player)
	pl.x = x
	pl.y = y
	return pl
end

function player:update()
 moving = false
	if btn(0) and can_move(self.x, self.y + 7) then
		self.x = self.x - 1
		self.frame = 1
		self.x_mirror = true
	elseif btn(1) and can_move(self.x + 8, self.y + 7) then
	 self.x = self.x + 1
		self.frame = 1
		self.x_mirror = false
	elseif btn(2) and can_move(self.x + 4, self.y + 6) then
		self.y = self.y - 1
		self.frame = 5
	elseif btn(3) and can_move(self.x + 4, self.y + 8) then
		self.y = self.y + 1
		self.frame = 3
	else
		self.frame = 0
		self.anim_count = 0
	end

	if self.frame > 0 then
		self.anim_count = (self.anim_count + 1) % 12
		if self.anim_count >= 6 then
			self.frame = self.frame + 1
		end
	end

	-- check for unlocking doors
	if self.has_key then
		local doorx = (self.x + 4) / 8
		local doory = (self.y + 4) / 8
		local doortile = mget(doorx, doory)
		if doortile == 62 then
			mset(doorx, doory, 28)
			mset(doorx + 1, doory, 29)
			sfx(snd_door)
			display_caption("you unlocked the door")
		elseif doortile == 63 then
			mset(doorx - 1, doory, 28)
			mset(doorx, doory, 29)
			sfx(snd_door)
			display_caption("you unlocked the door")
		end
	end
end

function player:draw()
	spr(33 + self.frame, self.x, self.y, 1, 1, self.x_mirror)
end

-->8
-- non-player characters

npc = {
	anim_count = 0,
	facing = 0, -- -1 none, 0 up, 1 right, 2 down, 3 left
	frame = 0,
	sees_player = false,
	waypoint_ndx = 0,
	spotted = false,
	delay = 0
}
npc.__index = npc

npcs = {}

function npc:create(basesprite, waypoints)
	local n = {}
	setmetatable(n, npc)
	n.waypoints = waypoints
	n.basesprite = basesprite
	n.x = waypoints[1].x
	n.y = waypoints[1].y
	n.target_x = n.x
	n.target_y = n.y
	return n
end

function npc:update()
	if self.delay > 0 then
	 -- wait
		self.delay = self.delay - 1
	 self.facing = -1
	 self.frame = 0
	elseif self.target_y < self.y then
		-- up
		self.facing = 0
		self.y = self.y - 0.5
		self.frame = 5
	elseif self.target_x > self.x then
	 -- right
	 self.facing = 1
		self.x = self.x + 0.5
		self.frame = 1
	elseif self.target_y > self.y then
		-- down
		self.facing = 2
		self.y = self.y + 0.5
		self.frame = 3	
	elseif self.target_x < self.x then
	 -- left
		self.facing = 3
		self.x = self.x - 0.5
		self.frame = 1
	else
	 -- find next waypoint
		self.delay = self.waypoints[self.waypoint_ndx + 1].d
		self.waypoint_ndx = (self.waypoint_ndx + 1) % #self.waypoints
		local wp = self.waypoints[self.waypoint_ndx + 1]
		self.target_x = wp.x
		self.target_y = wp.y
	end

	if self.facing != -1 then
		self.anim_count = (self.anim_count + 1) % 8
		if self.anim_count > 4 then
			self.frame = self.frame + 1
		end
	end

	if is_on_screen(self.x, self.y) then
		self.sees_player = self:in_view_frustum(plyr.x, plyr.y)
			and has_line_of_sight(self.x + 4, self.y + 7, plyr.x + 4, plyr.y + 7)
		if self.sees_player and not self.spotted then
			self.spotted = true
			sfx(snd_alert)
		end
	end
end

function npc:draw()
	spr(self.basesprite + self.frame, self.x, self.y, 1, 1, self.facing == 3)
	if self.sees_player then
		spr(48, self.x, self.y - 8)
	end
end

function npc:in_view_frustum(x, y)
	-- note: pico 8 angle convention is ccw.
	-- negate y to fix that.
	-- also, angles are 0-1, starting from right
	local angle = atan2(x - self.x, self.y - y)

	if self.facing == 0 then
		-- looking up
		return angle > 0.625 and angle < 0.875	
	elseif self.facing == 1 then
		-- looking right
		return angle < 0.125 or angle > 0.875
	elseif self.facing == 3 then
		-- looking left
		return angle > 0.375 and angle < 0.652
	else
		-- looking down (or standing)
		return angle > 0.125 and angle < 0.375
	end
end

function has_line_of_sight(x1, y1, x2, y2)
	local c1 = flr(x1 / 8)
	local r1 = flr(y1 / 8)
	local c2 = flr(x2 / 8)
	local r2 = flr(y2 / 8)

	if abs(c2 - c1) > abs(r2 - r1) then
	 -- horizontal major axis
	 local r = r1
	 local rstep = (r2 - r1) / (c2 - c1)
		for c = c1, c2, sgn(c2 - c1) do
		 if not unobstructed(c, r) then
		  return false -- walk blocks los
		 end
			rectfill(c * 8, flr(r) * 8, (c + 1) * 8, flr(r + 1) * 8, 2)
			r = r + rstep
		end
	else
	 -- vertical major axis
		local c = c1
		local cstep = (c1 - c2) / (r2 - r1)
		for r = r1, r2, sgn(r2 - r1) do
		 if not unobstructed(c, r) then
		  return false
		 end
			c = c + cstep
		end
	end

	return true
end

function unobstructed(col, row)
	return fget(mget(col, row), flg_transparent)
end

function update_npcs()
	for _, np in ipairs(npcs) do
		np:update()
		if np.spotted then
			return true
		end
	end

	return false
end

function draw_npcs()
	for _, np in ipairs(npcs) do
		np:draw()
	end
end


-->8
-- items
item = {
	held = false,
	is_key = false,
	description = ""
}
item.__index = item

function item:create(x, y, sprite, description)
	i = {}
	setmetatable(i, item)
	i.x = x
	i.y = y
	i.sprite = sprite
	i.description = description
	return i
end

function item:hit()
	self.held = true
	if self.is_key then
		plyr.has_key = true
	end
	sfx(snd_grab_item)
	display_caption("you got the " .. self.description)
end

items = {}

function update_items()
	-- see if the user is over an item
	for _, i in pairs(items) do
		if not i.held and abs(plyr.x - i.x) < 8 and abs(plyr.y - i.y) < 8 then
			i:hit()
		end
	end
end

function draw_items()
	for _, v in pairs(items) do
		if not v.held then
			spr(v.sprite, v.x, v.y)
		end
	end
end

-->8
-- main game loop
state_intro = 0
state_play = 1
state_caught = 2
state_over = 3

camera_x = 0
camera_y = 0
display_menu = false
caption_text = ""
caption_delay = 0
old_menub_state = false -- used to make one-shot
game_state = state_intro
screen_timer = 0

function _init() 
	restart()
end

function restart()
	camera_x = 0
	camera_y = 0
	display_menu = false
	old_menub_state = false -- used to make one-shot
	game_state = state_intro
	screen_timer = 0
	npcs = {}
	items = {}

 add(items, item:create(26 * 8, 5 * 8, 40, "pencil"))
	add(items, item:create(300, 45, 41, "report card"))
	add(items, item:create(53 * 8, 8 * 8, 32, "key"))
	items[3].is_key = true

 -- route for player 1 (janitor)
 -- emptying trash in classrooms
	local p1_rt = {
		{x=16 * 8, y=18 * 8, d=0},
		
		-- room 1
		{x=16 * 8, y=14 * 8, d=0},
		{x=12 * 8, y=14 * 8, d=40},
		{x=16 * 8, y=14 * 8, d=0},

		-- room 2
		{x=16 * 8, y=5 * 8, d=0},
		{x=12 * 8, y=5 * 8, d=40},

		-- room 3
		{x=22 * 8, y=5 * 8, d=40},
		{x=18 * 8, y=5 * 8, d=0},

		-- room 4
		{x=18 * 8, y=14 * 8, d=0},
		{x=22 * 8, y=14 * 8, d=40},
		{x=18 * 8, y=14 * 8, d=0},


	}

	add(npcs, npc:create(54, p1_rt))

 -- route for player 2 (principal)
	local p2_rt = {
		{x=300, y=120, d=60},
		{x=300, y=155, d=10},
		{x=450, y=155, d=10},
		{x=300, y=155, d=10}
	}

	add(npcs, npc:create(64, p2_rt))

	plyr = player:create(26, 56)
end

function menub_pressed()
	local down = btn(4)
	local is_pressed = old_menub_state == false and down
	old_menub_state = down
	return is_pressed
end

function _update()
	if game_state == state_intro then
		screen_timer = screen_timer + 1
		if screen_timer == 45 then
			game_state = state_play
			music(0)
		end
		return		
	end	

	if game_state == state_caught then
		screen_timer = screen_timer + 1
		if screen_timer == 60 then
			game_state = state_over
		end		
		return -- caught
	end

	if game_state == state_over then
	 if btn() != 0 then
   restart()
	 end

		return
	end

	-- game screen
	if display_menu then
		if menub_pressed() then
			display_menu = false
		end
		return
	end

	if menub_pressed() then
		display_menu = true
		return
	end

 plyr:update()
 if update_npcs() then
		game_state = state_caught
		screen_timer = 0
		music(-1)
 end

	update_items()

	if plyr.x < camera_x + 32 then
		camera_x = plyr.x - 32
	elseif plyr.x > camera_x + 88 then
		camera_x = plyr.x - 88
	end
	
	if plyr.y < camera_y + 32 then
		camera_y = plyr.y - 32
	elseif plyr.y > camera_y + 88 then
		camera_y = plyr.y - 88
	end
end

function display_caption(text) 
	caption_text = text
	caption_delay = 30
end

function center_text(s)
	print(s, 64 -  #s / 2 * 4, 62, 7)
end

function _draw()
	cls()
	if game_state == state_intro then
	 camera(0, 0)
		center_text("don't get caught!")
	elseif game_state == state_over then
	 camera(0, 0)
		center_text("game over")
	else
		draw_game_screen()
	end
end	
	
function draw_game_screen()
 camera(camera_x, camera_y)
	map(0, 0, 0, 0, 128, 128)

	draw_items()
	plyr:draw()
	draw_npcs()

 -- draw overlapping portions
	map(0, 0, 0, 0, 128, 128, (1 << flg_draw_over))

	if display_menu then
		menu_width = 90
		rectfill(camera_x + 7, camera_y + 7, camera_x + menu_width + 7 , camera_y + 71, 0)
		rect(camera_x + 8, camera_y + 8, camera_x + menu_width + 7 - 1, camera_y + 70, 7)
		print("inventory", camera_x + 10, camera_y + 10)
		item_x = 0
		item_y = 0
		for _, it in pairs(items) do
			if it.held then
				spr(it.sprite, item_x + camera_x + 15,
					item_y + camera_y + 20)
					item_x = item_x + 8
					if item_x > menu_width then
						item_x = 0
						item_y = item_y + 8
					end
			end
		end
	end

	if caption_delay > 0 then
	 color(0)
	 rectfill(camera_x, camera_y, camera_x + #caption_text * 4 + 1, camera_y + 5)
	 color(7)
		print(caption_text, camera_x, camera_y)
		caption_delay = caption_delay - 1
	end
end

function is_on_screen(x, y)
	return x + 2 > camera_x
		and x + 6 < camera_x + 128
		and y + 2 > camera_y
		and y + 6 < camera_y + 128
end

__gfx__
00000000777755557777777777777777dddddddd6666777777777777444444444444444444444444666677777777555577775555666677777777554444444444
00000000777755557777666666666666dcccdccc66667777666677774ffffffffffffffffffffff4666677777777555566665555666666667777554fffffffff
00700700777755557777566666666666dcccdccc66667777666677774ffffffffffffffffffffff4666677777777555566666555666666667777554fffffffff
00077000777755557777566666666666dcccdccc66667777666677774ffffffffffffffffffffff4666077777777055566666555666666667777554fffffffff
00077000777755557777556666666666dddddddd66667777666677774ffffffffffffffffffffff4660077777777005566666655666666667777554fffffffff
00700700777755557777556666666666dcccdccc66667777666677774ffffffffffffffffffffff4600077777777000566666655666666667777554444444444
00000000777755557777555666666666dcccdccc66667777666677774ffffffffffffffffffffff4000077777777000066666665666666667777555444444444
00000000777755557777555666666666dcccdccc66667777666677774ffff000000ff000000ffff4000077777777000066666665666666667777555544444444
777766666666777766666666777777777777777777777777000000004ffff033330ff033330ffff400007777777700007777777777777777000000004444444d
777777777777777777777777666666666666666666666666000000004ffff033330ff033330ffff40000777777770000666000000000006677777777ffffff4d
777777777777777777777777111111111111111111111111000000004444403333044033330444440000777777770000666000000000006677777777ffffff44
777777777777777777777777611111111111111111111116000000000cc0d033330cc033330c0cc00000777777770000666000000000006677777777ffffff44
777777777777777777777777611111111111111111111116000000000d0dd000000dd000000dd0d00000777777770000666000000000006677777777ffffff44
7777777777777777777777776611111111111111111111660000000000ccd0ccdc0cc0ccdc0ccc00000677777777500066600000000000667777777744444444
777777777777777777777777661111111111111111111166000000000cccd0ccdc0cc0ccdc0cccc0066677777777555066600000000000667777777744444444
77777777777777777777777766666666666666666666666600000000dcccdcccdcccccccdccccccd666677777777555566600000000000667777777744444444
00000000000440000004400000044000000440000004400000044000000440000000000000000000dddddddd0000000066660000000000667777777744444444
00000000000ff000000ff000000ff000000ff000000ff000000440000004400000000f5007777700dddddddd000000000000000000000000000000004fffffff
0aaa0000007777000077770000777000007777000077770000777700007777000000aaf007777770dddddddd000000000000000000000000055555504fffffff
0a0aaaa0007777000f0770f000777f0000077700007770000007770000777000000aaa0007666670dddddddd000000000000000000000000050000504fffffff
0aaa00a000f77f000007700000f7700000077f0000f7700000077f0000f7700000aaa00007777770dddddddd000000000000000000000000055555504fffffff
00000000000110000001100000011000000110000001100000011000000110000aaa000007666670dddddddd0000000000000000000000000505555044444444
0000000000011000000101000001100000011000000110000001100000011000eea0000007777770dddddddd0000000000000000000000000555555044444444
0000000000011000001001000000100000001000000100000000100000010000ee00000000000000dddddddd0000000000000000000000000555555044444444
00000000412356000000a8340a98c834444444444444444400033000000330000003300000033000000330000003300000033000000000007777777777777777
0000000041235600000a08340a98c8344444444444444444000ff000000ff000000ff000000ff000000ff0000005500000055000000000006664444444444466
000800004123564444a448344a98c834444444444444444400333300003333000033300000333300003333000033330000333300000000006664444444444466
008880004444444444444444444444444444444444444444003333000f0330f000333f0000033300003330000003330000333000000000006664444444444466
00888000467978bae000e5d4e2a515d44675008a8675008400f33f000003300000f3300000033f0000f3300000033f0000f33000000000006664444444444466
00080000467978bae333e5d4e2a515d44675008a8675008400033000000330000003300000033000000330000003300000033000000000006664404444444466
00000000467978baebbbe5d4e2a515d44675448a8675448400033000000303000003300000033000000330000003300000033000000000006664444444444466
00080000444444444444444444444444444444444444444400033000003003000000300000003000000300000000300000030000000000006664444444444466
00066000000660000006600000066000000660000006600000066000000000000000000000000000000000000000000000000000000000000000000000000000
000ff000000ff000000ff000000ff000000ff0000006600000066000055505550000000000000000000000000000000000000000000000000000000000000000
00777700007777000077700000777700007777000077770000777700055505550000000000000000000000000000000000000000000000000000000000000000
007777000f0770f000777f0000077700007770000007770000777000055505550000000000000000000000000000000000000000000000000000000000000000
00f77f000007700000f7700000077f0000f7700000077f0000f77000000000000000000000000000000000000000000000000000000000000000000000000000
00055000000550000005500000055000000550000005500000055000055505550000000000000000000000000000000000000000000000000000000000000000
00055000000505000005500000055000000550000005500000055000055505550000000000000000000000000000000000000000000000000000000000000000
00055000005005000000500000005000000500000000500000050000055505550000000000000000000000000000000000000000000000000000000000000000
__label__
66606060066066606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606660600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066606060660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600060606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660666060606060666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600060606660000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060600060000060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066006660000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606000000060006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060666060606660060060006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006060066066606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060606660600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600066606060660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600660666060606060666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606060066006606660666066600000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60006060606060600600600060600000606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606660606060600600660066000000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00606060606060600600600060600000600060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006060660066000600666060600600600066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06600660606006600660600000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60006000606060606060600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606000666060606060600000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00606000606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66000660606066006600666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660606066006660666066000000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060600600600060600000606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606660606060600600660060600000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060600600600060600000600060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060066060600600666066600600600066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600060606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060606000606000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066006600660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606000606000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060666060606660606006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000777070707700000006666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
07000000707070707070000006666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00700000777070707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700077707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000700077707770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ee0e0e0ee00eee0eee0e0e00000eee0eee0eee00ee0eee000000000000000000000000000000000000000000000000000000000000000000000000000000000
e000e0e0e0e00e00e0e0e0e00000e000e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000
eee0eee0e0e00e00eee00e000000ee00ee00ee00e0e0ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00e000e0e0e00e00e0e0e0e00000e000e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee00eee0e0e00e00e0e0e0e00000eee0e0e0e0e0ee00e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000700007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000700077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000777077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc00ccc0ccc0ccc00cc0ccc00cc0ccc0c0c00000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c0c0c00c0000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00cc00cc00c0000c00c0c0cc00ccc0000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c000c00c0000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc0ccc0c0c0ccc00cc00c00cc00c0c0ccc000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060066066606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606660600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066606060660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600060606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660666060606060666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600060606660000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060600060000060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066006660000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606000000060006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060666060606660060060006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006060066066606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060606660600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600066606060660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600660666060606060666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606060066006606660666066600000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60006060606060600600600060600000606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606660606060600600660066000000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00606060606060600600600060600000600060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006060660066000600666060600600600066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06600660606006600660600000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60006000606060606060600000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606000666060606060600000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00606000606060606060600000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66000660606066006600666006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660606066006660666066000000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060600600600060600000606060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606660606060600600660060600000666066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060600600600060600000600060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060066060600600666066600600600066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600060606660666000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060600060606000606000006060606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660600066006600660000006660666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060600060606000606000006000606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606060666060606660606006006000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000777070707770077077707770000007700770707007700770700000007070777077707000000000000000000000000000000000000000000000000000
07000000700070707070707070700700000070007000707070707070700000007070070077707000000000000000000000000000000000000000000000000000
00700000770007007770707077000700000077707000777070707070700000007770070070707000000000000000000000000000000000000000000000000000
07000000700070707000707070700700000000707000707070707070700000007070070070707000000000000000000000000000000000000000000000000000
70000000777070707000770070700700000077000770707077007700777007007070070070707770000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606000666066600660666000000660666066606660606066606660000066600000600066606660666060000000666066606660066066600000000000000000
60606000600060606000600000006000606060600600606060606000000060600000600060606060600060000000600006006060600006000000000000000000
66606000660066606660660000006000666066600600606066006600000066600000600066606600660060000000660006006600666006000000000000000000
60006000600060600060600000006000606060000600606060606000000060600000600060606060600060000000600006006060006006000000000000000000
60006660666060606600666000000660606060000600066060606660000060600000666060606660666066600000600066606060660006000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0401010104010105050502020000010501010101010100050505020202020205000000000000000000000400010101050001010101010000000000000000010100000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0203030303131414150303030303060203030602030303031314141503030303030600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104040404040404040404040404050104040501040404040404040404040404040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104040708090404070809040404050104040501040407080904040708090404040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104041718190404171819040404050104040501040417181904041718190404040502030303030303060134353435343534343534350600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040404040404040404040404040a0b04040a0b040404040404040404040404040501040404040404050131333132313331313331320500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040407080904040708090404041a1b04041a1b04040708090404070809040404050104040404040405012a2a2a2a2a2a2a2a2a2a2a0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404171819040417181904040405010404050104041718190404171819040404050104042f1f04040501343534352a2a2a343534350500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040404040404040404040404040501040405010404040404040404040404040405010404040404040501313331332a2a2a313331320500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
101212121212121212121212121211010404051012121212121212121212121212110104040404040405012a2a2a2a2a2a2a2a2a2a2a0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020303030313141415030303030306010404050203030303131414150303030303061012121e1e12121101343534352a2a2a343534350502030303031314141503030303030604040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404040404040404040404040405010404050104040404040404040404040404050203033e3f03030601313331322a2a2a313331330501040404040404040404040404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404070809040407080904040405010404050104040708090404070809040404050104040404040405012a2a2a2a2a2a2a2a2a2a2a0501040407080904040708090404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404171819040417181904040405010404050104041718190404171819040404050104040404040405012a2a2a2a2a2a2a343534350501040417181904041718190404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040404040404040404040404040a0b04040a0b04040404040404040404040404050104040404040405012a2a2a2a2a2a2a313331330501040404040404040404040404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040407080904040708090404041a1b04041a1b04040708090404070809040404050e0f0f0f1f0404050e0f0f0f1f2a2a2a2a2a2a2a0501040407080904040708090404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404171819040417181904040405010404050104041718190404171819040404050104040404040405012a2a2a2a2a2a2a2a2a2a2a0501040417181904041718190404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010404040404040404040404040405010404050104040404040404040404040404050104040404040405012a2a2a2a2a2a2a2a2a2a2a0501040404040404040404040404040504040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
101212121212121212121212121211010404051012121212121212121212121212111012121e1e12121110121212121e1e1212121212111012121212121e1e1212121212121104040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02032e2e2e2e2e2e2e2e2e2e2e2e030c04040d032e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e031c1d032e2e2e2e2e2e031c1d032e2e2e2e2e2e2e2e2e2e031c1d0303030303030304040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000111601216014160161601a1501e1402013025120271100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000a0200b0500f0501305016050190501b0501d0501f0502105024050270502a0502d0503305018100182001a0001b00010050110501505018050190501b0501e0502105025050260502a0503005035050
001000000016500000000000660506655000000000500000001650660000165000000665500165000000660000165000000660000005066550660000000066000016500005001650000006655001650016500003
001000000c0502400024000240000a000220000a050220000c050250000d0500c5000c0000c0000c0500c0000c0000c5000c0000c5000a0000a0000a0500c5000c0500c5000d0500c500100500d0000d05000000
000300002a6252a6502a6252a6502a655060500605506050040000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000110502400024000240000a000220000f050220001105025000120500c5000c0000c000110500c0000c0000c5000c0000c5000a0000a0000f0500c500110500c500120500c500150500d0001205000000
011000000506500000000000660506655000000000500000051650660005165000000665505165000000660005165000000660000005066550660000000066000516500005051650000006655051650516500003
01100000110502400024000240000a000220000f050220001105025000120500c5000c0000c000110500c0000c0000c5000c0000c5000a0000a0000f0500c500110500c500120500c500110500d0000f05000000
__music__
00 02034745
00 02034344
00 05064344
02 06074344
02 46474344
02 42434344

