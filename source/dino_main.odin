package dino

import "vendor:raylib"

DEFAULT_WINDOW_W :: 600
DEFAULT_WINDOW_H :: 150

BG_COLOR_DAY :: 0xF7F7F7FF

spritesheet_lores := #load("../assets/offline-sprite-1x.png")
spritesheet_hires := #load("../assets/offline-sprite-2x.png")

TREX_WIDTH_NORMAL :: 44
TREX_WIDTH_DUCK :: 59
TREX_HEIGHT_NORMAL :: 47
TREX_HEIGHT_DUCK :: 25
TREX_SPRITESHEET_WIDTH :: 262

GROUND_X :: 2
GROUND_Y :: 127
GROUND_SPRITE_WIDTH :: 1200
GROUND_SPRITE_HEIGHT :: 12

CACTUS_SMALL_SPRITE_WIDTH  :: 17
CACTUS_SMALL_SPRITE_HEIGHT :: 35
CACTUS_SMALL_Y :: 105

CACTUS_LARGE_SPRITE_WIDTH  :: 25
CACTUS_LARGE_SPRITE_HEIGHT :: 50
CACTUS_LARGE_Y :: 90

PTERODACTYL_SPRITE_WIDTH  :: 46
PTERODACTYL_SPRITE_HEIGHT :: 40
PTERODACTYL_Y :: []int { 100, 75, 50 }

sprite_coordinates_lores := Sprite_Coordinates {
	cactus_large = {332, 2},
	cactus_small = {228, 2},
	cloud = {86, 2},
	ground = {2, 54},
	pterodactyl = {134, 2},
	restart_icon = {2, 2},  // From the top-left corner
	trex = {677, 2},
	text = {484, 2}
}

Sprite_Coordinates :: struct {
	cactus_large: [2]f32,
	cactus_small: [2]f32,
	cloud: [2]f32,
	ground: [2]f32,
	pterodactyl: [2]f32,
	restart_icon: [2]f32,
	trex: [2]f32,
	text: [2]f32
}

main :: proc() {
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(DEFAULT_WINDOW_W, DEFAULT_WINDOW_H, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(60);
	
	spritesheet_lores_img := raylib.LoadImageFromMemory(".png", raw_data(spritesheet_lores), cast(i32)len(spritesheet_lores));
	spritesheet_lores_tex := raylib.LoadTextureFromImage(spritesheet_lores_img);
	
	game_started := false;
	
	frame_count_from_attempt_start := 0;
	
	for !raylib.WindowShouldClose() {
		trex_position: [2]f32 = {50, 95};
		
		trex_sprite_rect_waiting: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 0, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_blinking: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 40, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_running: []raylib.Rectangle = {
			{sprite_coordinates_lores.trex.x + 88, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
			{sprite_coordinates_lores.trex.x + 132, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
		};
		trex_sprite_rect_crashed: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 220, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_jumping: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 0, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_ducking: []raylib.Rectangle = {
			{sprite_coordinates_lores.trex.x + 262, sprite_coordinates_lores.trex.y, TREX_WIDTH_DUCK, TREX_HEIGHT_DUCK},
			{sprite_coordinates_lores.trex.x + 321, sprite_coordinates_lores.trex.y, TREX_WIDTH_DUCK, TREX_HEIGHT_DUCK},
		};
		
		trex_sprite_rect: raylib.Rectangle;
		if !game_started {
			trex_sprite_rect = trex_sprite_rect_waiting;
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) {
				game_started = true;
				frame_count_from_attempt_start = 0;
			}
		} else {
			trex_sprite_rect = trex_sprite_rect_running[(frame_count_from_attempt_start / 12) % 2];
			running_ms_per_frame := 12;
			waiting_ms_per_frame := 3;
			crashed_ms_per_frame := 60;
			jumping_ms_per_frame := 60;
			ducking_ms_per_frame := 8;
			
			trex_sprite_rect = trex_sprite_rect_running[(frame_count_from_attempt_start / running_ms_per_frame) % len(trex_sprite_rect_running)];
		}
		
		raylib.BeginDrawing();
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		ground_position: [2]f32 = {GROUND_X, GROUND_Y};
		ground_sprite_rect: raylib.Rectangle = {sprite_coordinates_lores.ground.x, sprite_coordinates_lores.ground.y, GROUND_SPRITE_WIDTH, GROUND_SPRITE_HEIGHT};
		raylib.DrawTextureRec(spritesheet_lores_tex, ground_sprite_rect, ground_position, raylib.WHITE);
		
		cactus_small_position: [2]f32 = {300, CACTUS_SMALL_Y};
		cactus_small_sprite_rect: raylib.Rectangle = {sprite_coordinates_lores.cactus_small.x, sprite_coordinates_lores.cactus_small.y, CACTUS_SMALL_SPRITE_WIDTH, CACTUS_SMALL_SPRITE_HEIGHT};
		raylib.DrawTextureRec(spritesheet_lores_tex, cactus_small_sprite_rect, cactus_small_position, raylib.WHITE);
		
		raylib.DrawTextureRec(spritesheet_lores_tex, trex_sprite_rect, trex_position, raylib.WHITE);
		
		raylib.EndDrawing();
		
		frame_count_from_attempt_start += 1;
	}
}
