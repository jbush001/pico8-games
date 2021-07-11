pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
ship_x=80
missiles={}
aliens={}
live_aliens=0
last_fire=0
bombs={}
game_over=false
score=0

function _init()
	start_game()
end

function start_game()
	for i=1,10,1 do
		missiles[i] = {
			live=false,
			xpos=0,
			ypos=0,
			anim_frame=0		
		}
		aliens[i] = {
		 live=false,
		 exploding=false,
		 frame=0,
		 x=0,
			y=0,
			xdir=0
		}
		bombs[i] = {
			live=false,
			x=0,
			y=0
		}
	end

	ship_x=80
	live_aliens=0
	last_fire=0
	game_over=false
	score=0
end

function _update()
	-- restart after game over
	if game_over and btn(5) then
		start_game()
		return
	end

 if not game_over then
		if btn(0) and ship_x > 3 then
			ship_x = ship_x - 3
		elseif btn(1) and ship_x < 117 then
			ship_x = ship_x + 3
		end
		
		local fire = btn(4)
		if not last_fire and fire then
			for i=1,#missiles,1 do
				if not missiles[i].live then
					missiles[i].live = true
		 		missiles[i].x = ship_x
					missiles[i].y = 112
					sfx(0)
					break
				end
			end
		end
		last_fire = fire
	end

	-- respawn aliens
	if live_aliens < 10 and rnd(5) < 1 then
		for i=1,#aliens,1 do
			if not aliens[i].live then
				aliens[i].live = true
			 aliens[i].x=rnd(120)
				aliens[i].y=rnd(16)
				aliens[i].xdir = rnd(3) - 1
				live_aliens = live_aliens + 1
				break
			end
		end
	end
	
	for i=1, #missiles, 1 do
		if missiles[i].live then
		 missiles[i].anim_frame = 1 -
		 	missiles[i].anim_frame
			missiles[i].y = missiles[i].y - 4
		 if missiles[i].y < 0 then
		 	missiles[i].live = false
		 end
		 for j = 1,#aliens, 1 do
		 	if aliens[j].live 
		 		and abs(aliens[j].x - missiles[i].x) < 8
		 		and abs(aliens[j].y - missiles[i].y) < 8 then
		 		sfx(1)
		 		aliens[j].live=false
		 		aliens[j].exploding=true
		 		aliens[j].frame = 0
		 		missiles[i].live=false
		 		score = score + 1
				end		 		
		 end
		end

		if aliens[i].live then
			-- alien movement
			aliens[i].x = aliens[i].x + aliens[i].xdir * 0.2
			if aliens[i].x > 112 and aliens[i].xdir > 0 then
				aliens[i].xdir = -1
			elseif aliens[i].x < 8 and aliens[i].xdir < 0 then
				aliens[i].xdir = 1
			end
			aliens[i].y = aliens[i].y + 0.2		
			if aliens[i].y > 120 then
				aliens[i].live = false
				live_aliens = live_aliens - 1
			end
		elseif aliens[i].exploding then
			aliens[i].frame = aliens[i].frame + 1
			if aliens[i].frame == 6 then
				aliens[i].exploding=false
				live_aliens = live_aliens - 1
			end
		end
		
		if bombs[i].live then
			if bombs[i].y > 120 then
				bombs[i].live = false
			else
				if bombs[i].y > 112 and abs(bombs[i].x - ship_x) < 8 then
				 sfx(1)
					game_over = true
				end
				bombs[i].y = bombs[i].y + 2
			end
		elseif aliens[i].live and rnd(50) < 1 then
			bombs[i].live = true
			bombs[i].x = aliens[i].x
			bombs[i].y = aliens[i].y + 8
		end
	end
end

function _draw() 
	cls()
	for i=1, #missiles, 1 do
		if missiles[i].live then
			spr(2 + missiles[i].anim_frame, 
				missiles[i].x, 
				missiles[i].y)
		end

		if aliens[i].live then		
			spr(4, aliens[i].x, aliens[i].y)
	 elseif aliens[i].exploding then
	 	spr(5 + rnd(2), aliens[i].x, aliens[i].y)
		end
		
		if bombs[i].live then
			spr(7, bombs[i].x, bombs[i].y)
		end
	end	

	if game_over then
	 print("game over", 40, 56)
		spr(5 + rnd(2), ship_x, 120)
	else
		spr(1, ship_x, 120)
	end

	print("score " .. score, 0, 0) 
end

__gfx__
00000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000cc00000055000000550000001100000000a0009000900000000000000000000000000000000000000000000000000000000000000000000000000
00700700000cc0000005500000055000001881000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000cc0000005500000055000111111110000800000090000000000000000000000000000000000000000000000000000000000000000000000000000
00077000c0c66c0c000550000005500010888801a0000080080000000d0000d00000000000000000000000000000000000000000000000000000000000000000
00700700ccc66ccc005555000055550010088001000000000000000005d00d500000000000000000000000000000000000000000000000000000000000000000
00000000cccccccc0008a000000a8000100000010080000009000080005dd5000000000000000000000000000000000000000000000000000000000000000000
0000000000088000000a00000000a00000000000000000a000000000000550000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000000000000004150051500615007150091500c1500e150101501315015150181501a1501c1501f15022150261502b150331503d1503d15000000000000000000000000000000000000000000000000000
001000000d670136700a6000a6000b6000b6000a60009600086000860003600036000360003600096000360008600046000460005600000000000000000000000000000000000000000000000000000000000000
