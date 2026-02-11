package dino

import "core:os/os2"
import "core:math/rand"

import "vendor:raylib"

TARGET_FPS :: 60

DEFAULT_WINDOW_W :: 600
DEFAULT_WINDOW_H :: 150

window_w: i32
window_h: i32

BG_COLOR_DAY :: 0xF7F7F7FF

SPRITE_1X :: #load("../assets/offline-sprite-1x.png")
SPRITE_2X :: #load("../assets/offline-sprite-2x.png")

SPRITE_1X_TREX_WIDTH_NORMAL  ::  44
SPRITE_1X_TREX_HEIGHT_NORMAL ::  47
SPRITE_1X_TREX_WIDTH_DUCK    ::  59
SPRITE_1X_TREX_HEIGHT_DUCK   ::  25
SPRITE_1X_TREX_WIDTH_TOTAL   :: 262

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

sprite_coordinates: Sprite_Coordinates;
sprite_rects: Sprite_Rects;
sprite_bytes: []u8;

// From the top-left corner of the entity sub-sprite
SPRITE_1X_RECTS :: Sprite_Rects {
	trex_waiting = {
		{  0,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL},
		{ 40,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL},
	},
	trex_running = {
		{ 88,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL},
		{132,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL},
	},
	trex_ducking = {
		{262, 17, SPRITE_1X_TREX_WIDTH_DUCK,   SPRITE_1X_TREX_HEIGHT_DUCK},
		{321, 17, SPRITE_1X_TREX_WIDTH_DUCK,   SPRITE_1X_TREX_HEIGHT_DUCK}
	},
	trex_jumping = {
		{  0,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL}
	},
	trex_crashed = {
		{220,  0, SPRITE_1X_TREX_WIDTH_NORMAL, SPRITE_1X_TREX_HEIGHT_NORMAL}
	},
}

Sprite_Rects :: struct {
	trex_waiting: [2]raylib.Rectangle,
	trex_running: [2]raylib.Rectangle,
	trex_ducking: [2]raylib.Rectangle,
	trex_jumping: [1]raylib.Rectangle,
	trex_crashed: [1]raylib.Rectangle,
}

// From the top-left corner of the image
SPRITE_1X_COORDINATES :: Sprite_Coordinates {
	cactus_large = {332, 2},
	cactus_small = {228, 2},
	restart_icon = {  2, 2},
	pterodactyl  = {134, 2},
	horizon = { 2, 54},
	cloud   = {86,  2},
	trex = {677, 2},
	text = {484, 2}
}

SPRITE_2X_COORDINATES :: Sprite_Coordinates {
	cactus_large = {652, 2},
	cactus_small = {446, 2},
	restart_icon = {  2, 2},
	pterodactyl  = {260, 2},
	horizon = {  2, 104},
	cloud   = {166,   2},
	trex = {1338, 2},
	text = { 954, 2}
}

Sprite_Coordinates :: struct {
	cactus_large: [2]f32,
	cactus_small: [2]f32,
	restart_icon: [2]f32,
	pterodactyl:  [2]f32,
	horizon: [2]f32,
	cloud:   [2]f32,
	trex: [2]f32,
	text: [2]f32
}

main :: proc() {
	window_w, window_h = DEFAULT_WINDOW_W, DEFAULT_WINDOW_H;
	sprite_coordinates = SPRITE_1X_COORDINATES;
	sprite_rects = SPRITE_1X_RECTS;
	sprite_bytes = SPRITE_1X;
	for arg in os2.args {
		if arg == "-2x" {
			window_w, window_h = 2*DEFAULT_WINDOW_W, 2*DEFAULT_WINDOW_H;
			sprite_coordinates = SPRITE_2X_COORDINATES;
			for &r in sprite_rects.trex_jumping do r = double_rect(r);
			for &r in sprite_rects.trex_crashed do r = double_rect(r);
			for &r in sprite_rects.trex_waiting do r = double_rect(r);
			for &r in sprite_rects.trex_running do r = double_rect(r);
			for &r in sprite_rects.trex_ducking do r = double_rect(r);
			sprite_bytes = SPRITE_2X;
			
			double_rect :: proc(r: raylib.Rectangle) -> raylib.Rectangle {
				return {r.x * 2, r.y * 2, r.width * 2, r.height * 2};
			}
		}
	}
	
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(window_w, window_h, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(TARGET_FPS);
	
	sprite_img := raylib.LoadImageFromMemory(".png", raw_data(sprite_bytes), cast(i32)len(sprite_bytes));
	sprite_tex := raylib.LoadTextureFromImage(sprite_img);
	
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
		trex_y_shift: f32 = 17;
		
		trex_sprite_rect: raylib.Rectangle;
		{
			running_ms_per_frame := 12;
			waiting_ms_per_frame := 3;
			crashed_ms_per_frame := 60;
			jumping_ms_per_frame := 60;
			ducking_ms_per_frame := 8;
			
			rect_slice: []raylib.Rectangle;
			ms_per_frame: int;
			if !game_started {
				rect_slice = sprite_rects.trex_waiting[:1]; // Temporary :1
				ms_per_frame = waiting_ms_per_frame;
				
				if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) {
					current_speed = 1;
					
					game_started = true;
					frame_count_since_attempt_start = 0;
				}
			} else {
				rect_slice = sprite_rects.trex_running[:];
				ms_per_frame = running_ms_per_frame;
				
				if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
					rect_slice = sprite_rects.trex_ducking[:];
					ms_per_frame = ducking_ms_per_frame;
					
					trex_position.y += trex_y_shift;
				}
			}
			
			rect_index := (frame_count_since_attempt_start / ms_per_frame) % len(rect_slice);
			trex_sprite_rect = rect_slice[rect_index];
			trex_sprite_rect = shift_rect(trex_sprite_rect, sprite_coordinates.trex);
			
			shift_rect :: proc(r: raylib.Rectangle, amount: [2]f32) -> raylib.Rectangle {
				return {r.x + amount.x, r.y + amount.y, r.width, r.height};
			}
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
				
				raylib.DrawTextureRec(sprite_tex, rec, pos, raylib.WHITE);
			}
		}
		
		cactus_small_position: [2]f32 = {300, CACTUS_SMALL_Y};
		cactus_small_sprite_rect: raylib.Rectangle = {SPRITE_1X_COORDINATES.cactus_small.x, SPRITE_1X_COORDINATES.cactus_small.y, CACTUS_SMALL_SPRITE_WIDTH, CACTUS_SMALL_SPRITE_HEIGHT};
		raylib.DrawTextureRec(sprite_tex, cactus_small_sprite_rect, cactus_small_position, raylib.WHITE);
		
		raylib.DrawTextureRec(sprite_tex, trex_sprite_rect, trex_position, raylib.WHITE);
		
		raylib.EndDrawing();
		
		frame_count_since_attempt_start += 1;
		time_since_attempt_start += dt;
	}
}
