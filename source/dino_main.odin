package dino

import "core:math/rand"
import "vendor:raylib"

TARGET_FPS :: 60

DEFAULT_WINDOW_W :: 600
DEFAULT_WINDOW_H :: 150

BG_COLOR_DAY :: 0xF7F7F7FF

SPRITE_1X := #load("../assets/offline-sprite-1x.png")
SPRITE_2X := #load("../assets/offline-sprite-2x.png")

TREX_WIDTH_NORMAL :: 44
TREX_WIDTH_DUCK :: 59
TREX_HEIGHT_NORMAL :: 47
TREX_HEIGHT_DUCK :: 25
TREX_SPRITESHEET_WIDTH :: 262

TEXT_X :: 0
TEXT_Y :: 13
TEXT_WIDTH :: 191
TEXT_HEIGHT :: 11

SCREEN_GROUND_X :: 2
SCREEN_GROUND_Y :: 127
SCREEN_GROUND_W :: DEFAULT_WINDOW_W - 2*SCREEN_GROUND_X
SCREEN_GROUND_H :: 12
SCREEN_GROUND_NUM_SECTIONS :: 2 // Arbitrary number
SCREEN_GROUND_SEC_W :: SCREEN_GROUND_W / SCREEN_GROUND_NUM_SECTIONS
#assert(SCREEN_GROUND_SEC_W * SCREEN_GROUND_NUM_SECTIONS == SCREEN_GROUND_W)
SPRITE_1X_GROUND_X :: 2
SPRITE_1X_GROUND_Y :: 54
SPRITE_1X_GROUND_W :: 1200
SPRITE_1X_GROUND_H :: 12
SPRITE_1X_GROUND_NUM_SECTIONS :: 2 // Arbitrary number
SPRITE_1X_GROUND_SEC_W :: SPRITE_1X_GROUND_W / SPRITE_1X_GROUND_NUM_SECTIONS
#assert(SPRITE_1X_GROUND_SEC_W * SPRITE_1X_GROUND_NUM_SECTIONS == SPRITE_1X_GROUND_W)

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
	raylib.SetTargetFPS(TARGET_FPS);
	
	sprite_1x_img := raylib.LoadImageFromMemory(".png", raw_data(SPRITE_1X), cast(i32)len(SPRITE_1X));
	sprite_1x_tex := raylib.LoadTextureFromImage(sprite_1x_img);
	
	// Coordinates on screen of where each sprite starts
	ground_x: [SCREEN_GROUND_NUM_SECTIONS]i32;
	// Coordinates in the spritesheet of where each sprite starts
	sprite_1x_ground_x: [SPRITE_1X_GROUND_NUM_SECTIONS]i32;
	ground_bump_threshold := f32(0.5);
	
	ground_x[0] = 0;
	ground_x[1] = SCREEN_GROUND_SEC_W;
	sprite_1x_ground_x[0] = SPRITE_1X_GROUND_X;
	sprite_1x_ground_x[1] = SPRITE_1X_GROUND_X + SPRITE_1X_GROUND_SEC_W;
	
	current_speed := f32(0);
	
	game_started := false;
	frame_count_since_attempt_start := 0;
	time_since_attempt_start := f32(0);
	
	for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime();
		
		trex_position: [2]f32 = {50, 95};
		
		trex_sprite_rect_waiting: []raylib.Rectangle = {
			{sprite_coordinates_lores.trex.x + 0, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
			{sprite_coordinates_lores.trex.x + 40, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
		};
		trex_sprite_rect_running: []raylib.Rectangle = {
			{sprite_coordinates_lores.trex.x + 88, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
			{sprite_coordinates_lores.trex.x + 132, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL},
		};
		trex_sprite_rect_crashed: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 220, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_jumping: raylib.Rectangle = {sprite_coordinates_lores.trex.x + 0, sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		trex_sprite_rect_ducking: []raylib.Rectangle = {
			{sprite_coordinates_lores.trex.x + 262, sprite_coordinates_lores.trex.y + 17, TREX_WIDTH_DUCK, TREX_HEIGHT_DUCK},
			{sprite_coordinates_lores.trex.x + 321, sprite_coordinates_lores.trex.y + 17, TREX_WIDTH_DUCK, TREX_HEIGHT_DUCK},
		};
		
		trex_sprite_rect: raylib.Rectangle;
		if !game_started {
			trex_sprite_rect = trex_sprite_rect_waiting[0];
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) {
				current_speed = 1;
				
				game_started = true;
				frame_count_since_attempt_start = 0;
			}
		} else {
			running_ms_per_frame := 12;
			waiting_ms_per_frame := 3;
			crashed_ms_per_frame := 60;
			jumping_ms_per_frame := 60;
			ducking_ms_per_frame := 8;
			
			sprite_rect := trex_sprite_rect_running;
			ms_per_frame := running_ms_per_frame;
			if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
				sprite_rect = trex_sprite_rect_ducking;
				ms_per_frame = ducking_ms_per_frame;
				trex_position.y += 17;
			}
			
			trex_sprite_rect = sprite_rect[(frame_count_since_attempt_start / ms_per_frame) % len(sprite_rect)];
		}
		
		raylib.BeginDrawing();
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		// Draw ground
		{
			delta := cast(i32)(current_speed * dt * 200);
			for _, dst_i in ground_x {
				dst_x := ground_x[dst_i];
				dst_x -= delta;
				if dst_x < -SCREEN_GROUND_SEC_W {
					dst_x += SCREEN_GROUND_W;
				}
				ground_x[dst_i] = dst_x;
				
				// This re-uses the same source coordinates for multiple portions of the screen.
				// This makes it more complicated to randomly select them, as setting the
				// coordinates for what is outside the screen will also (potentially) set them
				// for things inside the screen that share the same % index
				src_x := sprite_1x_ground_x[dst_i % len(sprite_1x_ground_x)];
				
				pos := [2]f32 {f32(dst_x), SCREEN_GROUND_Y};
				rec := raylib.Rectangle {f32(src_x), SPRITE_1X_GROUND_Y, SPRITE_1X_GROUND_SEC_W, SPRITE_1X_GROUND_H};
				
				raylib.DrawTextureRec(sprite_1x_tex, rec, pos, raylib.WHITE);
			}
		}
		
		cactus_small_position: [2]f32 = {300, CACTUS_SMALL_Y};
		cactus_small_sprite_rect: raylib.Rectangle = {sprite_coordinates_lores.cactus_small.x, sprite_coordinates_lores.cactus_small.y, CACTUS_SMALL_SPRITE_WIDTH, CACTUS_SMALL_SPRITE_HEIGHT};
		raylib.DrawTextureRec(sprite_1x_tex, cactus_small_sprite_rect, cactus_small_position, raylib.WHITE);
		
		raylib.DrawTextureRec(sprite_1x_tex, trex_sprite_rect, trex_position, raylib.WHITE);
		
		raylib.EndDrawing();
		
		frame_count_since_attempt_start += 1;
		time_since_attempt_start += dt;
	}
}
