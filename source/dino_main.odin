package dino

import "base:runtime"
import "base:intrinsics"

import os "core:os/os2"

import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import "core:math/rand"
import "core:container/small_array"
import "core:encoding/base64"

import "vendor:raylib"

TARGET_FPS :: 60
MS_PER_FRAME :: 1000 / TARGET_FPS

DEFAULT_WINDOW_W :: 600
DEFAULT_WINDOW_H :: 150

window_w: i32
window_h: i32

BG_COLOR_DAY :: 0xF7F7F7FF

OFFLINE_SOUND_PRESS   :: #load("../assets/offline_sound_press.ogg")
OFFLINE_SOUND_HIT     :: #load("../assets/offline_sound_hit.ogg")
OFFLINE_SOUND_REACHED :: #load("../assets/offline_sound_reached.ogg")

SPRITE_1X :: #load("../assets/offline-sprite-1x.png")
SPRITE_2X :: #load("../assets/offline-sprite-2x.png")

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

// NOTE(ema): From the top-left corner of the image
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

// NOTE(ema): From the top-left corner of the entity sub-sprite
Sprite_Rects :: struct {
	trex_waiting: [2]raylib.Rectangle,
	trex_running: [2]raylib.Rectangle,
	trex_ducking: [2]raylib.Rectangle,
	trex_jumping: [1]raylib.Rectangle,
	trex_crashed: [1]raylib.Rectangle,
}

SPRITE_1X_TREX_WIDTH_NORMAL  ::  44
SPRITE_1X_TREX_HEIGHT_NORMAL ::  47
SPRITE_1X_TREX_WIDTH_DUCK    ::  59
SPRITE_1X_TREX_HEIGHT_DUCK   ::  25
SPRITE_1X_TREX_WIDTH_TOTAL   :: 262

trex_w_normal: f32 // TODO(ema): Use these to potentially stretch the texture when drawing
trex_h_normal: f32
trex_w_duck: f32
trex_h_duck: f32

@(rodata)
trex_collision_boxes_running := [?]raylib.Rectangle {
	{22,  0, 17, 16}, { 1, 18, 30,  9}, {10, 35, 14,  8},
	{ 1, 24, 29,  5}, { 5, 30, 21,  4}, { 9, 34, 15,  4}
}

@(rodata)
trex_collision_boxes_ducking := [?]raylib.Rectangle {
	{ 1, 18, 55, 25}
}

Trex_Status :: enum {
	Waiting, Running, Ducking, Jumping, Crashed
};

@(rodata)
trex_status_anim_frames_per_ms := [len(Trex_Status)]int {
	Trex_Status.Running = 12,
	Trex_Status.Waiting =  3,
	Trex_Status.Crashed = 60,
	Trex_Status.Jumping = 60,
	Trex_Status.Ducking =  8,
}

////////////////////////////////
// Ground constants & types

SPRITE_1X_GROUND_W :: 600 // NOTE(ema): The width of a ground *SECTION*
SPRITE_1X_GROUND_H :: 12

sprite_ground_x := SPRITE_1X_COORDINATES.horizon.x;
sprite_ground_y := SPRITE_1X_COORDINATES.horizon.y;
sprite_ground_w := f32(SPRITE_1X_GROUND_W);
sprite_ground_h := f32(SPRITE_1X_GROUND_H);

SCREEN_GROUND_X :: 0
SCREEN_GROUND_Y :: 127 // TODO(ema): WINDOW_H(150) - BOTTOM_PAD(10) - GROUND_H(12) = 128... which one is right?
SCREEN_GROUND_W :: DEFAULT_WINDOW_W - 2*SCREEN_GROUND_X
SCREEN_GROUND_H :: 12

screen_ground_x := f32(SCREEN_GROUND_X);
screen_ground_y := f32(SCREEN_GROUND_Y);
screen_ground_w := f32(SCREEN_GROUND_W);
screen_ground_h := f32(SCREEN_GROUND_H);

sprite_coordinates: Sprite_Coordinates;
sprite_rects: Sprite_Rects;
sprite_bytes: []u8;

////////////////////////////////
// Obstacle constants & types

// NOTE(ema): "Gap" means the amount of empty space following each obstacle before a new
// obstacle can be placed.

MAX_OBSTACLES                :: 5;
MAX_OBSTACLE_DUPLICATION     :: 2;
MAX_COMPOUND_OBSTACLE_LENGTH :: 3;
MIN_OBSTACLE_GAP_COEFFICIENT :: 0.6;
MAX_OBSTACLE_GAP_COEFFICIENT :: 1.5;
OBSTACLE_HISTORY_CAP :: MAX_OBSTACLE_DUPLICATION * len(Obstacle_Tag);

Obstacle_Tag :: enum { Cactus_Small, Cactus_Large, Pterodactyl }
Obstacle_Template :: struct {
	hitboxes: []raylib.Rectangle,
	possible_y_positions: []f32,
	width, height: f32,
	min_gap: f32,
	min_trex_run_speed_for_single_spawn: f32,
	min_trex_run_speed_for_multiple_spawn: f32,
	speed_offset: f32, // The speed of the obstacle itself, to be added to the trex run speed
	
	anim_frames_per_second: f32, // Animation framerate
	num_anim_frames: i32,
}

OBSTACLE_TEMPLATES :: [Obstacle_Tag]Obstacle_Template {
	.Cactus_Small = {
		hitboxes = { {0,7,5,27}, {4,0,6,34}, {10,4,7,14} },
		possible_y_positions = {105.0},
		width = 17.0, height = 35.0,
		min_gap = 120.0,
		min_trex_run_speed_for_single_spawn = 0.0,
		min_trex_run_speed_for_multiple_spawn = 4.0,
		num_anim_frames = 1,
	},
	
	.Cactus_Large = {
		hitboxes = { {0,12,7,38}, {8,0,7,49}, {13,10,10,38} },
		possible_y_positions = {90.0},
		width = 25.0, height = 50.0,
		min_gap = 120.0,
		min_trex_run_speed_for_single_spawn = 0.0,
		min_trex_run_speed_for_multiple_spawn = 7.0,
		num_anim_frames = 1,
	},
	
	.Pterodactyl = {
		hitboxes = { {15,15,16,5}, {18,21,24,6}, {2,14,4,3}, {6,10,4,7}, {10,8,6,9} },
		possible_y_positions = {100.0, 75.0, 50.0},
		width = 46.0, height = 40.0,
		min_gap = 150.0,
		min_trex_run_speed_for_single_spawn = 8.5,
		min_trex_run_speed_for_multiple_spawn = 999.0, // TODO(ema): Make this TREX_MAX_SPEED + 1? It's probabily clearer if it stays 999
		speed_offset = 0.8,
		
		anim_frames_per_second = 1.0 / 6.0,
		num_anim_frames = 2,
	}
}

// NOTE(ema): Each of these rectangle indicates only the *FIRST* image of the category, e.g.
// the *FIRST* small cactus out of 6.
OBSTACLE_SPRITE_RECTS :: [Obstacle_Tag]raylib.Rectangle {
	.Cactus_Small = {0, 0, 17, 35},
	.Cactus_Large = {0, 0, 25, 50},
	.Pterodactyl  = {0, 0, 46,  40},
}

obstacle_sprite_rects: [Obstacle_Tag]raylib.Rectangle;

Obstacle :: struct {
	tag: Obstacle_Tag,
	
	hitboxes: small_array.Small_Array(5, raylib.Rectangle),
	world_position: [2]f32,
	speed_offset: f32,
	length: f32, // NOTE(ema): Stored as a f32 for convenience, but it's really an integer
	gap: f32,
	
	seconds_since_anim_frame_changed: f32,
	anim_frames_per_second: f32,
	current_anim_frame: i32,
	
	using debug: Obstacle_Debug,
}

when ODIN_DEBUG {
	Obstacle_Debug :: struct {
		color: raylib.Color,
	}
} else {
	Obstacle_Debug :: struct {}
}

@(disabled=!ODIN_DEBUG)
write_sound_assets_to_disk :: proc() {
	// NOTE(ema): This was used to generate the asset files from the strings found on the
	// website, paste the strings again in case you want to use it.
	OFFLINE_SOUND_PRESS_BASE64, OFFLINE_SOUND_HIT_BASE64, OFFLINE_SOUND_REACHED_BASE64 :: ``, ``, ``;
	
	names  := [?]string {"assets/offline_sound_press.ogg", "assets/offline_sound_hit.ogg", "assets/offline_sound_reached.ogg"}
	sounds := [?]string {OFFLINE_SOUND_PRESS_BASE64, OFFLINE_SOUND_HIT_BASE64, OFFLINE_SOUND_REACHED_BASE64};
	
	for encoded, index in sounds {
		context.allocator = context.temp_allocator;
		
		decoded, alloc_err := base64.decode(encoded);
		if alloc_err != nil {
			raylib.TraceLog(.ERROR, "Failed to decode '%s'\n", strings.clone_to_cstring(names[index]));
			continue;
		}
		
		write_err := os.write_entire_file(names[index], decoded);
		if write_err != nil {
			raylib.TraceLog(.ERROR, "Failed to write to '%s'\n", strings.clone_to_cstring(names[index]));
		}
	}
}

main :: proc() {
	double_resolution := false;
	for arg in os.args {
		if arg == "-2x" {
			double_resolution = true;
		}
	}
	
	window_w, window_h = DEFAULT_WINDOW_W, DEFAULT_WINDOW_H;
	sprite_coordinates = SPRITE_1X_COORDINATES;
	sprite_rects = SPRITE_1X_RECTS;
	sprite_bytes = SPRITE_1X;
	trex_w_normal = SPRITE_1X_TREX_WIDTH_NORMAL;
	trex_h_normal = SPRITE_1X_TREX_HEIGHT_NORMAL;
	trex_w_duck = SPRITE_1X_TREX_WIDTH_DUCK;
	trex_h_duck = SPRITE_1X_TREX_HEIGHT_DUCK;
	if double_resolution {
		window_w, window_h = 2*DEFAULT_WINDOW_W, 2*DEFAULT_WINDOW_H;
		sprite_coordinates = SPRITE_2X_COORDINATES;
		for &r in sprite_rects.trex_jumping do r = double_rect(r);
		for &r in sprite_rects.trex_crashed do r = double_rect(r);
		for &r in sprite_rects.trex_waiting do r = double_rect(r);
		for &r in sprite_rects.trex_running do r = double_rect(r);
		for &r in sprite_rects.trex_ducking do r = double_rect(r);
		sprite_bytes = SPRITE_2X;
		trex_w_normal *= 2;
		trex_h_normal *= 2;
		trex_w_duck *= 2;
		trex_h_duck *= 2;
		
		sprite_ground_x, sprite_ground_y = SPRITE_2X_COORDINATES.horizon.x, SPRITE_2X_COORDINATES.horizon.y;
		sprite_ground_w, sprite_ground_h = sprite_ground_w * 2, sprite_ground_h * 2;
		screen_ground_x, screen_ground_y = screen_ground_x * 2, screen_ground_y * 2;
		screen_ground_w, screen_ground_h = screen_ground_w * 2, screen_ground_h * 2;
	}
	
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(window_w, window_h, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(TARGET_FPS);
	
	raylib.InitAudioDevice();
	
	sound_press   := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_PRESS),   cast(i32)len(OFFLINE_SOUND_PRESS)));
	sound_hit     := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_HIT),     cast(i32)len(OFFLINE_SOUND_HIT)));
	sound_reached := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_REACHED), cast(i32)len(OFFLINE_SOUND_REACHED)));
	
	sprite_img := raylib.LoadImageFromMemory(".png", raw_data(sprite_bytes), cast(i32)len(sprite_bytes));
	sprite_tex := raylib.LoadTextureFromImage(sprite_img);
	
	BOTTOM_PAD :: 10;
	bottom_pad := i32(BOTTOM_PAD);
	if double_resolution {
		bottom_pad *= 2;
	}
	
	////////////////////////////////
	// T-rex variables
	
	// TODO(ema): Better names for: drop velocity, x-accel (run accel), max speed (max run speed),
	// drop coef (?); speed drop
	
	// TODO(ema): Implement CLEAR_TIME
	
	TREX_WORLD_POSITION_X :: 50;
	TREX_MAX_JUMP_HEIGHT :: 30;
	TREX_MIN_JUMP_HEIGHT :: 30;
	TREX_DROP_VELOCITY :: -5;
	TREX_INITIAL_RUN_SPEED :: 6;
	TREX_X_ACCELERATION :: 0.001;
	TREX_MAX_SPEED :: 13;
	TREX_GRAVITY :: 0.6;
	SPEED_DROP_COEFFICIENT :: 3;
	TREX_START_JUMP_VELOCITY :: -10;
	
	trex_status := Trex_Status.Waiting;
	
	trex_ground_y_normal := f32(window_h - bottom_pad) - trex_h_normal;
	trex_ground_y_duck := f32(window_h - bottom_pad) - trex_h_duck;
	
	trex_world_x := f32(TREX_WORLD_POSITION_X);
	trex_world_y := trex_ground_y_normal;
	if double_resolution {
		trex_world_x *= 2;
	}
	
	trex_min_jump_height := f32(trex_ground_y_normal - TREX_MIN_JUMP_HEIGHT);
	
	trex_collision_boxes: []raylib.Rectangle;
	trex_jump_velocity: f32;
	trex_reached_min_height: bool;
	trex_distance_ran: f32;
	trex_speed_drop: bool;
	trex_run_speed: f32;
	trex_jump_count: int;
	
	////////////////////////////////
	// Obstacle variables
	
	obstacle_history: small_array.Small_Array(OBSTACLE_HISTORY_CAP, Obstacle_Tag);
	obstacle_buffer: small_array.Small_Array(MAX_OBSTACLES, Obstacle);
	
	////////////////////////////////
	// Ground variables
	
	Ground_Section :: struct {
		screen_x: f32,
		sprite_x: f32,
	}
	
	screen_ground_sections: [2]Ground_Section; // Coordinates on screen of where each sprite starts
	ground_bump_threshold := f32(0.5);
	
	{
		screen_ground_sections[0].screen_x = screen_ground_x;
		screen_ground_sections[1].screen_x = screen_ground_x + screen_ground_w;
		
		for &section in screen_ground_sections {
			section.sprite_x = sprite_ground_x + (rand.float32() > ground_bump_threshold ? 0 : sprite_ground_w);
		}
	}
	
	////////////////////////////////
	// Clouds variables
	
	MAX_CLOUD_GAP :: 400;
	MAX_SKY_LEVEL :: 71;
	MIN_CLOUD_GAP :: 100;
	MIN_SKY_LEVEL :: 30;
	
	CLOUD_FREQUENCY :: 0.5;
	CLOUD_SPEED :: 0.2;
	MAX_CLOUDS  :: 6;
	
	SPRITE_1X_CLOUD_W :: 46;
	SPRITE_1X_CLOUD_H :: 14;
	
	SCREEN_CLOUD_W :: 46;
	SCREEN_CLOUD_H :: 14;
	
	sprite_cloud_w := f32(SPRITE_1X_CLOUD_W);
	sprite_cloud_h := f32(SPRITE_1X_CLOUD_H);
	
	screen_cloud_w := f32(SCREEN_CLOUD_W);
	screen_cloud_h := f32(SCREEN_CLOUD_H);
	
	if double_resolution {
		sprite_cloud_w, sprite_cloud_h = 2*sprite_cloud_w, 2*sprite_cloud_h;
		screen_cloud_w, screen_cloud_h = 2*screen_cloud_w, 2*screen_cloud_h;
	}
	
	sprite_cloud_rec := raylib.Rectangle {
		sprite_coordinates.cloud.x, sprite_coordinates.cloud.y,
		sprite_cloud_w, sprite_cloud_h
	};
	
	Cloud :: struct {
		screen_pos: [2]f32,
		gap: f32,
	}
	
	clouds: small_array.Small_Array(MAX_CLOUDS, Cloud);
	
	make_cloud :: proc(x: f32, gen_y := context.random_generator, gen_gap := context.random_generator) -> Cloud {
		cloud := Cloud {
			screen_pos = {x, math.round(rand.float32_range(MIN_SKY_LEVEL, MAX_SKY_LEVEL, gen = gen_y))},
			gap = math.round(rand.float32_range(MIN_CLOUD_GAP, MAX_CLOUD_GAP, gen = gen_gap)),
		};
		return cloud;
	}
	
	////////////////////////////////
	// Distance meter variables
	
	METER_DEFAULT_DIGIT_COUNT :: 5;
	
	METER_ACHIEVEMENT_DISTANCE :: 100;
	METER_COEFFICIENT :: 0.025;
	
	METER_FLASH_DURATION :: 1000 / 4;
	METER_FLASH_ITERATIONS :: 3;
	
	Meter :: struct {
		up_to_date_score: i32,
		score: i32,
		digit_count: i32,
		
		high_score: i32,
		high_digit_count: i32,
		
		flash_iterations: i32,
		flash_timer: f32,
		achievement: bool,
	}
	
	meter: Meter;
	
	// Attempt info
	frame_count_since_attempt_start := 0;
	time_since_attempt_start := f32(0);
	
	// Session info
	attempt_count := 0;
	
	mute_sfx := false;
	
	when ODIN_DEBUG {
		Debug_Draw_Flag :: enum {
			Hotkeys,
			Hitboxes,
			Variables,
			Mute_Sfx,
			Obstacle_Buffer
		}
		
		debug_draw_flags := bit_set[Debug_Draw_Flag] { .Hotkeys, .Hitboxes, .Mute_Sfx };
		mute_sfx = true;
	}
	
	for !raylib.WindowShouldClose() {
		free_all(context.temp_allocator);
		
		FIXED_DT :: ODIN_DEBUG;
		when FIXED_DT {
			dt := f32(1.0 / TARGET_FPS);
		} else {
			dt := raylib.GetFrameTime();
		}
		
		when ODIN_DEBUG {
			for f in Debug_Draw_Flag {
				k := raylib.KeyboardKey(cast(int)f + cast(int)raylib.KeyboardKey.ZERO);
				if raylib.IsKeyPressed(raylib.KeyboardKey(k)) {
					debug_draw_flags ~= {f};
				}
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.M) {
				mute_sfx = !mute_sfx;
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.KP_ADD) {
				trex_run_speed = min(1.1*trex_run_speed, TREX_MAX_SPEED);
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.KP_SUBTRACT) {
				trex_run_speed = max(0.9*trex_run_speed, TREX_INITIAL_RUN_SPEED);
			}
		}
		
		// Simulate trex
		{
			if trex_status == .Waiting || trex_status == .Crashed {
				should_start := false;
				
				if trex_status == .Waiting {
					if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.UP) || raylib.IsMouseButtonPressed(.LEFT) {
						should_start = true;
					}
				} else {
					if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.UP) || raylib.IsMouseButtonPressed(.LEFT) {
						should_start = true;
						if !mute_sfx {
							raylib.PlaySound(sound_press);
						}
					}
				}
				
				if should_start {
					trex_status = .Running;
					attempt_count += 1;
					
					meter.score = 0;
					meter.digit_count = METER_DEFAULT_DIGIT_COUNT;
					meter.flash_iterations = 0;
					meter.flash_timer = 0.0;
					meter.achievement = false;
					if meter.high_digit_count < METER_DEFAULT_DIGIT_COUNT {
						meter.high_digit_count = METER_DEFAULT_DIGIT_COUNT;
					}
					
					trex_distance_ran = 0;
					trex_run_speed = TREX_INITIAL_RUN_SPEED;
					trex_jump_count = 0;
					trex_world_x = TREX_WORLD_POSITION_X;
					trex_world_y = trex_ground_y_normal;
					
					small_array.clear(&obstacle_history);
					small_array.clear(&obstacle_buffer);
					// TODO(ema): Reset ground
					small_array.clear(&clouds);
					small_array.push_back(&clouds, make_cloud(x = f32(window_w)));
					
					frame_count_since_attempt_start = 0;
					time_since_attempt_start = 0;
				}
			} else {
				// if playing intro, play intro, else:
				
				trex_collision_boxes = trex_collision_boxes_running[:];
				
				// TODO(ema): Maybe loop over this switch until prev status == status? so
				// it doesn't feel like the inputs are happening 1 frame later
				#partial switch trex_status {
					case .Running: {
						trex_world_y = trex_ground_y_normal;
						
						if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
							trex_status = .Ducking;
						}
						
						if raylib.IsKeyPressed(raylib.KeyboardKey.UP) && trex_status != .Ducking {
							if !mute_sfx {
								raylib.PlaySound(sound_press);
							}
							trex_status = .Jumping;
							
							trex_jump_velocity = TREX_START_JUMP_VELOCITY - (trex_run_speed / 10.0);
							trex_reached_min_height = false;
						}
					}
					
					case .Ducking: {
						trex_world_y = trex_ground_y_duck;
						trex_collision_boxes = trex_collision_boxes_ducking[:];
						
						if raylib.IsKeyUp(raylib.KeyboardKey.DOWN) {
							trex_status = .Running;
						}
					}
					
					case .Jumping: {
						z := dt * 1000.0 / MS_PER_FRAME;
						
						if raylib.IsKeyReleased(raylib.KeyboardKey.UP) {
							if trex_reached_min_height && trex_jump_velocity < TREX_DROP_VELOCITY {
								trex_jump_velocity = TREX_DROP_VELOCITY;
							}
						}
						
						if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
							if !trex_speed_drop {
								trex_jump_velocity = 1;
								trex_speed_drop = true;
							}
							
							trex_world_y += trex_jump_velocity * z * SPEED_DROP_COEFFICIENT;
						} else {
							trex_world_y += trex_jump_velocity * z;
						}
						
						trex_jump_velocity += TREX_GRAVITY * z;
						
						if trex_world_y < trex_min_jump_height || trex_speed_drop {
							trex_reached_min_height = true;
						}
						
						if trex_world_y < TREX_MAX_JUMP_HEIGHT || trex_speed_drop {
							if trex_reached_min_height && trex_jump_velocity < TREX_DROP_VELOCITY {
								trex_jump_velocity = TREX_DROP_VELOCITY;
							}
						}
						
						if trex_world_y > trex_ground_y_normal {
							trex_world_y = trex_ground_y_normal;
							trex_jump_velocity = 0;
							trex_status = .Running;
							trex_speed_drop = false;
							// @Maybe add: if UP pressed, keep status = jumping, else set status = running
						}
					}
					
					case: {
						raylib.TraceLog(.ERROR, strings.clone_to_cstring(fmt.tprintf("Invalid switch case %v",
																					 trex_status),
																		 context.temp_allocator));
					}
				}
			}
		}
		
		// Simulate rest of the world
		if trex_status != .Waiting && trex_status != .Crashed {
			
			// Update horizon line (ground)
			{
				delta := trex_run_speed * TARGET_FPS * dt;
				for &section in screen_ground_sections {
					section.screen_x -= delta;
					if section.screen_x + screen_ground_w < 0 {
						section.screen_x += 2*screen_ground_w;
						section.sprite_x = sprite_ground_x + (rand.float32() > ground_bump_threshold ? 0 : sprite_ground_w);
					}
				}
			}
			
			// Update clouds
			{
				delta := CLOUD_SPEED * TARGET_FPS * dt * trex_run_speed;
				
				passed_clouds: small_array.Small_Array(len(clouds.data), int);
				for cloud_index := 0; cloud_index < small_array.len(clouds); cloud_index += 1 {
					cloud := small_array.get_ptr(&clouds, cloud_index);
					cloud.screen_pos.x -= delta;
					
					is_visible_or_to_the_right := cloud.screen_pos.x + screen_cloud_w > 0;
					if !is_visible_or_to_the_right {
						small_array.append(&passed_clouds, cloud_index);
					}
				}
				
				ordered_remove_elems(&clouds, small_array.slice(&passed_clouds));
				
				try_add_cloud := false;
				if small_array.len(clouds) > 0 {
					last := small_array.get(clouds, small_array.len(clouds) - 1);
					if small_array.space(clouds) > 0 && last.screen_pos.x + screen_cloud_w + last.gap < f32(window_w) {
						try_add_cloud = true;
					}
				} else {
					try_add_cloud = true;
				}
				
				if try_add_cloud && rand.float32() < CLOUD_FREQUENCY {
					small_array.push_back(&clouds, make_cloud(x = f32(window_w)));
				}
			}
			
			// TODO(ema): Inline these functions
			update_obstacles(&obstacle_history, &obstacle_buffer, trex_run_speed, dt, f32(window_w));
			
			update_obstacles :: proc(history: ^small_array.Small_Array($H, Obstacle_Tag),
									 buffer: ^small_array.Small_Array($B, Obstacle),
									 current_speed: f32, dt: f32, horizon_w: f32) {
				passed_obstacles: small_array.Small_Array(B, int);
				for &o, i in small_array.slice(buffer) {
					templates := OBSTACLE_TEMPLATES;
					template  := templates[o.tag];
					
					speed := current_speed + o.speed_offset;
					delta := (speed * TARGET_FPS * dt);
					o.world_position.x -= delta;
					
					o.seconds_since_anim_frame_changed += dt;
					if o.seconds_since_anim_frame_changed > o.anim_frames_per_second {
						o.current_anim_frame += 1;
						if o.current_anim_frame == template.num_anim_frames do o.current_anim_frame = 0;
						
						o.seconds_since_anim_frame_changed = 0;
					}
					
					is_visible_or_to_the_right := o.world_position.x + get_obstacle_width(o) > 0;
					if !is_visible_or_to_the_right {
						small_array.push_back(&passed_obstacles, i);
					}
				}
				
				ordered_remove_elems(buffer, small_array.slice(&passed_obstacles));
				
				if small_array.len(buffer^) > 0 {
					last := small_array.get(buffer^, small_array.len(buffer^) - 1);
					if last.world_position.x + get_obstacle_width(last) + last.gap < horizon_w &&
						small_array.len(buffer^) < small_array.cap(buffer^) {
						append_obstacle(history, buffer, current_speed, horizon_w);
					}
				} else {
					append_obstacle(history, buffer, current_speed, horizon_w);
				}
			}
			
			append_obstacle :: proc(history: ^small_array.Small_Array($H, Obstacle_Tag),
									buffer: ^small_array.Small_Array($B, Obstacle),
									current_speed: f32, horizon_w: f32) {
				TAG_WEIGHTS :: [len(Obstacle_Tag)]int {
					Obstacle_Tag.Cactus_Small = 1,
					Obstacle_Tag.Cactus_Large = 1,
					Obstacle_Tag.Pterodactyl  = 10
				};
				
				tag: Obstacle_Tag = ---;
				for it := 0;; it += 1 {
					tag_weights := TAG_WEIGHTS;
					tag = weighted_choice_enum(Obstacle_Tag, tag_weights);
					templates := OBSTACLE_TEMPLATES;
					if slice.count(small_array.slice(history), tag) < MAX_OBSTACLE_DUPLICATION &&
						current_speed >= templates[tag].min_trex_run_speed_for_single_spawn {
						break;
					}
					if it == 100 {
						tag = .Cactus_Small;
						break;
					}
				}
				
				obstacle := make_obstacle(tag, current_speed, horizon_w);
				force_push_back(buffer, obstacle); // TODO(ema): Should not be necessary as we only push when there is space
				force_push_front(history, tag);
			}
			
			make_obstacle :: proc(tag: Obstacle_Tag, current_speed: f32, horizon_w: f32) -> Obstacle {
				templates := OBSTACLE_TEMPLATES;
				template  := templates[tag];
				
				obstacle  := Obstacle { tag = tag };
				small_array.push_back_elems(&obstacle.hitboxes, ..template.hitboxes);
				
				if current_speed >= template.min_trex_run_speed_for_multiple_spawn {
					obstacle.length = cast(f32)rand.int32_range(1, MAX_COMPOUND_OBSTACLE_LENGTH + 1);
				} else {
					obstacle.length = 1;
				}
				
				obstacle_width := get_obstacle_width(obstacle);
				
				DO_UGLY_BUT_FAITHFUL_POP_IN :: false;
				
				when DO_UGLY_BUT_FAITHFUL_POP_IN {
					obstacle.world_position.x = horizon_w - obstacle_width;
				} else {
					obstacle.world_position.x = horizon_w;
				}
				
				obstacle.world_position.y = template.possible_y_positions[int32_range_clamped(0, cast(i32)len(template.possible_y_positions) - 1)];
				
				#no_bounds_check if obstacle.length > 1 {
					#assert(len(obstacle.hitboxes.data) >= 3);
					b := small_array.slice(&obstacle.hitboxes);
					
					// NOTE(ema): When the obstacle is a compound obstacle, make adjustments to the
					// collision boxes so that they cover the entire width.
					b[1].width = obstacle_width - b[0].width - b[2].width; // Make the middle one wider
					b[2].x = obstacle_width - b[2].width;                  // Shift the last one to the right
				}
				
				obstacle.speed_offset = template.speed_offset * (rand.float32() < 0.5 ? -1 : +1);
				
				{
					min_gap := obstacle_width * current_speed + template.min_gap * MIN_OBSTACLE_GAP_COEFFICIENT;
					max_gap := min_gap * MAX_OBSTACLE_GAP_COEFFICIENT;
					obstacle.gap = rand.float32_range(min_gap, max_gap);
				}
				
				obstacle.seconds_since_anim_frame_changed = 0;
				obstacle.anim_frames_per_second = template.anim_frames_per_second;
				obstacle.current_anim_frame = 0;
				
				when ODIN_DEBUG {
					debug_colors := []raylib.Color {
						raylib.RED, raylib.ORANGE, raylib.GREEN, raylib.SKYBLUE, raylib.PURPLE
					};
					@(static) debug_color_index := 0;
					
					obstacle.color = debug_colors[debug_color_index];
					debug_color_index = (debug_color_index + 1) % len(debug_colors);
				}
				
				return obstacle;
			}
			
			// check collisions
			{
				hit := false;
				obstacle_loop: for &obstacle in small_array.slice(&obstacle_buffer) {
					for obstacle_hitbox in small_array.slice(&obstacle.hitboxes) {
						rectA := shift_rect(obstacle_hitbox, obstacle.world_position);
						for trex_hitbox in trex_collision_boxes {
							rectB := shift_rect(trex_hitbox, {trex_world_x, trex_world_y});
							hit = raylib.CheckCollisionRecs(rectA, rectB);
							if hit {
								break obstacle_loop;
							}
						}
					}
				}
				
				if hit {
					if !mute_sfx {
						raylib.PlaySound(sound_hit);
					}
					
					trex_status = .Crashed;
					meter.score = meter.up_to_date_score;
					meter.high_score = max(meter.high_score, meter.score);
				}
			}
		}
		
		meter_should_draw := true;
		
		// Simulate trex run & animate
		if trex_status != .Crashed && trex_status != .Waiting {
			// NOTE(ema): Don't do this before collision checking, because *technically*
			// you haven't run the distance if you crashed
			trex_distance_ran += trex_run_speed * dt * 1000 / MS_PER_FRAME;
			if trex_run_speed < TREX_MAX_SPEED {
				trex_run_speed += TREX_X_ACCELERATION;
			}
			
			// Update high score
			{
				score := cast(i32)math.round(METER_COEFFICIENT * math.ceil(trex_distance_ran));
				meter.up_to_date_score = score;
				if !meter.achievement {
					digit_count := cast(i32)math.count_digits_of_base(score, 10);
					
					if digit_count > meter.digit_count && meter.digit_count == METER_DEFAULT_DIGIT_COUNT {
						meter.digit_count += 1;
					}
					
					if score > 0 && score % METER_ACHIEVEMENT_DISTANCE == 0 {
						meter.achievement = true;
						meter.flash_timer = 0;
						
						if !mute_sfx {
							raylib.PlaySound(sound_reached); // TODO(ema): Play on different channel?
						}
					}
					
					meter.score = score;
				} else {
					if meter.flash_iterations <= METER_FLASH_ITERATIONS {
						meter.flash_timer += dt * 1000;
						
						if meter.flash_timer < METER_FLASH_DURATION {
							meter_should_draw = false;
						} else if meter.flash_timer > METER_FLASH_DURATION * 2 {
							meter.flash_iterations += 1;
							meter.flash_timer = 0.0;
						}
					} else {
						meter.flash_iterations = 0;
						meter.flash_timer = 0.0;
						meter.achievement = false;
					}
				}
			}
			
			// if trex changed status
			//  animation frame index = 0
			//  if status == waiting
			//   waiting anim start time = current time
			//   blink delay = random() * BLINK_TIMING
			// if status == waiting
			//  if time - waiting anim start time >= blink delay
			//   set blink sprite
			//   set new blink delay
			//   waiting anim start time = current time
		}
		
		raylib.BeginDrawing();
		
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		// Draw ground
		{
			for section in screen_ground_sections {
				pos := [2]f32 {section.screen_x, screen_ground_y};
				rec := raylib.Rectangle {
					section.sprite_x, sprite_ground_y,
					sprite_ground_w, sprite_ground_h
				};
				
				raylib.DrawTextureRec(sprite_tex, rec, pos, raylib.WHITE);
			}
		}
		
		// Draw clouds
		for cloud in small_array.slice(&clouds) {
			raylib.DrawTextureRec(sprite_tex, sprite_cloud_rec, cloud.screen_pos, raylib.WHITE);
		}
		
		// Draw obstacles
		{
			obstacle_sprite_rects = OBSTACLE_SPRITE_RECTS;
			if double_resolution {
				// TODO(ema): Incomplete
			}
			for o in small_array.slice(&obstacle_buffer) {
				pos := o.world_position;
				// rec := o.sprite_rec;
				
				when false {
					rec: raylib.Rectangle;
					switch o.tag {
						case .Cactus_Small: {
							rec.x = SPRITE_1X_COORDINATES.cactus_small.x;
							rec.y = SPRITE_1X_COORDINATES.cactus_small.y;
							rec.width = CACTUS_SMALL_SPRITE_WIDTH;
							rec.height = CACTUS_SMALL_SPRITE_HEIGHT;
						}
						
						case .Cactus_Large: {
							rec.x = SPRITE_1X_COORDINATES.cactus_large.x;
							rec.y = SPRITE_1X_COORDINATES.cactus_large.y;
							rec.width = CACTUS_LARGE_SPRITE_WIDTH;
							rec.height = CACTUS_LARGE_SPRITE_HEIGHT;
						}
						
						case .Pterodactyl: {
							rec.x = SPRITE_1X_COORDINATES.pterodactyl.x;
							rec.y = SPRITE_1X_COORDINATES.pterodactyl.y;
							rec.width = PTERODACTYL_SPRITE_WIDTH;
							rec.height = PTERODACTYL_SPRITE_HEIGHT;
						}
					}
				} else {
					coords: [2]f32; // TODO(ema): See if we can avoid this switch
					switch o.tag {
						case .Cactus_Small: coords = sprite_coordinates.cactus_small;
						case .Cactus_Large: coords = sprite_coordinates.cactus_large;
						case .Pterodactyl: coords = sprite_coordinates.pterodactyl;
					}
					rec := shift_rect(obstacle_sprite_rects[o.tag], coords);
				}
				
				// Here we have to map the length to the offset like this:
				//  1 -> 0 * width
				//  2 -> 1 * width
				//  3 -> 3 * width
				// We can use the formula: 0.5 * (length - 1) * length * width
				//  1 -> 0.5 * 0 * 1 * width -> 0 * width
				//  2 -> 0.5 * 1 * 2 * width -> 1 * width
				//  3 -> 0.5 * 2 * 3 * width -> 3 * width
				// Then adjust the rect to point to the correct animation frame
				rec.x += 0.5 * (o.length - 1) * o.length * rec.width;
				rec.x += f32(o.current_anim_frame) * rec.width;
				rec.width *= o.length;
				
				raylib.DrawTextureRec(sprite_tex, rec, pos, raylib.WHITE);
			}
		}
		
		// Draw trex
		{
			trex_sprite_rect: raylib.Rectangle;
			rect_slice: []raylib.Rectangle;
			trex_anim_frames_per_ms: int;
			
			switch trex_status {
				case .Waiting: {
					rect_slice = sprite_rects.trex_waiting[:1]; // Temporary :1
					trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Waiting];
				}
				
				case .Crashed: {
					rect_slice = sprite_rects.trex_crashed[:1];
					trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Crashed];
				}
				
				case .Running: {
					rect_slice = sprite_rects.trex_running[:];
					trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Running];
				}
				
				case .Ducking: {
					rect_slice = sprite_rects.trex_ducking[:];
					trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Ducking];
				}
				
				case .Jumping: {
					rect_slice = sprite_rects.trex_jumping[:];
					trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Jumping];
				}
			}
			
			rect_index := (frame_count_since_attempt_start / trex_anim_frames_per_ms) % len(rect_slice);
			trex_sprite_rect = rect_slice[rect_index];
			trex_sprite_rect = shift_rect(trex_sprite_rect, sprite_coordinates.trex);
			
			raylib.DrawTextureRec(sprite_tex, trex_sprite_rect, {trex_world_x, trex_world_y}, raylib.WHITE);
		}
		
		// Draw score
		{
			SPRITE_1X_METER_CHAR_W :: 10;
			SPRITE_1X_METER_CHAR_H :: 13;
			
			SCREEN_METER_CHAR_W :: 10 + 1; // NOTE(ema): Wider than the sprite
			SCREEN_METER_CHAR_H :: 13;
			
			sprite_meter_char_w := f32(SPRITE_1X_METER_CHAR_W);
			sprite_meter_char_h := f32(SPRITE_1X_METER_CHAR_H);
			
			screen_meter_char_w := f32(SCREEN_METER_CHAR_W);
			screen_meter_char_h := f32(SCREEN_METER_CHAR_H);
			
			if double_resolution {
				sprite_meter_char_w, sprite_meter_char_h = 2.0*sprite_meter_char_w, 2.0*sprite_meter_char_h;
				screen_meter_char_w, screen_meter_char_h = 2.0*screen_meter_char_w, 2.0*screen_meter_char_h;
			}
			
			draw_meter :: proc(score: i32, digit_count: i32, prefix_indices: []i32, sprite_tex: raylib.Texture, sprite_base_rec: raylib.Rectangle,
							   screen_base_pos: [2]f32, sprite_w: f32, screen_w: f32, color: raylib.Color) {
				score := score;
				score_digits := make([]i32, digit_count + cast(i32)len(prefix_indices), context.temp_allocator);
				start := cast(i32)copy(score_digits[:], prefix_indices);
				for digit_index := digit_count - 1 + start; digit_index > -1 + start; digit_index -= 1 {
					score_digits[digit_index] = score % 10;
					score /= 10;
				}
				
				for digit, digit_index in score_digits {
					sprite_rec := shift_rect(sprite_base_rec, {sprite_w * f32(digit), 0.0});
					screen_pos := screen_base_pos + {screen_w * f32(digit_index), 0.0};
					
					raylib.DrawTextureRec(sprite_tex, sprite_rec, screen_pos, color);
				}
			}
			
			sprite_digit_base_rec := raylib.Rectangle {
				sprite_coordinates.text.x, sprite_coordinates.text.y,
				sprite_meter_char_w, sprite_meter_char_h
			};
			
			score_meter_x := f32(window_w) - (screen_meter_char_w * (f32(meter.digit_count) + 1.0));
			score_meter_y := f32(5.0);
			
			if meter_should_draw {
				screen_digit_base_pos := [2]f32 {
					score_meter_x, score_meter_y
				};
				
				draw_meter(meter.score, meter.digit_count, nil, sprite_tex, sprite_digit_base_rec, screen_digit_base_pos,
						   sprite_meter_char_w, screen_meter_char_w, raylib.WHITE);
			}
			
			// TODO(ema): Why sprite_* and not screen_*? Maybe change this to screen_* and subtract 1 so it looks the same
			high_score_meter_x := score_meter_x - (f32(meter.digit_count) * 2.0) * sprite_meter_char_w;
			high_score_meter_y := score_meter_y;
			
			if meter.high_score > 0 {
				high_score_alpha := f32(0.8);
				high_score_color := raylib.ColorAlpha(raylib.WHITE, high_score_alpha);
				
				// NOTE(ema): Since the texture contains the character images in the form of the
				// string "0123456789HI ", we can use hardcoded "indices" to indicate chars
				// that aren't digits (10 for H, 11 for I, 12 for empty space)
				@(static, rodata) HIGH_SCORE_PREFIX_INDICES := [?]i32 {10, 11, 12};
				
				screen_digit_base_pos := [2]f32 {
					high_score_meter_x, high_score_meter_y
				};
				
				draw_meter(meter.high_score, meter.high_digit_count, HIGH_SCORE_PREFIX_INDICES[:], sprite_tex, sprite_digit_base_rec, screen_digit_base_pos,
						   sprite_meter_char_w, screen_meter_char_w, high_score_color);
			}
		}
		
		// Draw game over panel
		if trex_status == .Crashed {
			// Draw text
			{
				SPRITE_1X_TEXT_Y ::  13;
				
				SPRITE_1X_TEXT_W :: 191;
				SPRITE_1X_TEXT_H ::  11;
				
				SCREEN_TEXT_W :: 191;
				SCREEN_TEXT_H ::  11;
				
				sprite_text_y := f32(SPRITE_1X_TEXT_Y);
				
				sprite_text_w := f32(SPRITE_1X_TEXT_W);
				sprite_text_h := f32(SPRITE_1X_TEXT_H);
				
				screen_text_w := f32(SCREEN_TEXT_W);
				screen_text_h := f32(SCREEN_TEXT_H);
				
				if double_resolution {
					sprite_text_y                = 2*sprite_text_y;
					sprite_text_w, sprite_text_h = 2*sprite_text_w, 2*sprite_text_h;
					screen_text_w, screen_text_h = 2*screen_text_w, 2*screen_text_h;
				}
				
				sprite_text_rec := raylib.Rectangle {
					sprite_coordinates.text.x, sprite_coordinates.text.y + sprite_text_y,
					sprite_text_w, sprite_text_h
				};
				
				screen_text_pos := [2]f32 {
					f32(window_w) / 2 - screen_text_w / 2, // TODO(ema): Round?
					(f32(window_h) - 25) / 3 // TODO(ema): Round?
				};
				
				raylib.DrawTextureRec(sprite_tex, sprite_text_rec, screen_text_pos, raylib.WHITE);
			}
			
			// Draw restart icon
			{
				SPRITE_1X_RESTART_ICON_W :: 36;
				SPRITE_1X_RESTART_ICON_H :: 32;
				
				SCREEN_RESTART_ICON_W :: 36;
				SCREEN_RESTART_ICON_H :: 32;
				
				sprite_restart_icon_w := f32(SPRITE_1X_RESTART_ICON_W);
				sprite_restart_icon_h := f32(SPRITE_1X_RESTART_ICON_H);
				
				screen_restart_icon_w := f32(SCREEN_RESTART_ICON_W);
				screen_restart_icon_h := f32(SCREEN_RESTART_ICON_H);
				
				if double_resolution {
					sprite_restart_icon_w, sprite_restart_icon_h = 2*sprite_restart_icon_w, 2*sprite_restart_icon_h;
					screen_restart_icon_w, screen_restart_icon_h = 2*screen_restart_icon_w, 2*screen_restart_icon_h;
				}
				
				sprite_restart_icon_rec := raylib.Rectangle {
					sprite_coordinates.restart_icon.x, sprite_coordinates.restart_icon.y,
					sprite_restart_icon_w, sprite_restart_icon_h
				};
				
				screen_restart_icon_pos := [2]f32 {
					f32(window_w) / 2 - screen_restart_icon_w / 2,
					f32(window_h) / 2
				};
				
				raylib.DrawTextureRec(sprite_tex, sprite_restart_icon_rec, screen_restart_icon_pos, raylib.WHITE);
			}
		}
		
		// Draw debug info
		when ODIN_DEBUG {
			global_debug_text_x := i32(0);
			if .Hotkeys in debug_draw_flags {
				max_text_w := i32(0);
				font_size := i32(10);
				text_y := i32(10);
				text_x := i32(10);
				for f in Debug_Draw_Flag {
					k := raylib.KeyboardKey(cast(int)f + cast(int)raylib.KeyboardKey.ZERO);
					s := strings.clone_to_cstring(fmt.tprintf("%v: %v", f, k),
												  context.temp_allocator);
					text_w := raylib.MeasureText(s, font_size);
					raylib.DrawText(s, global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
					max_text_w = max(max_text_w, text_w);
					text_y = text_y + font_size + 5;
				}
				global_debug_text_x += text_x + max_text_w;
			}
			
			if .Hitboxes in debug_draw_flags {
				for r in trex_collision_boxes {
					shifted := shift_rect(r, {trex_world_x, trex_world_y});
					raylib.DrawRectangleLinesEx(shifted, 1, raylib.RED);
				}
				
				for &o in small_array.slice(&obstacle_buffer) {
					for b in small_array.slice(&o.hitboxes) {
						shifted := shift_rect(b, o.world_position);
						raylib.DrawRectangleLinesEx(shifted, 1, o.color);
					}
					
					gap_start := o.world_position.x + get_obstacle_width(o);
					gap_end := gap_start + o.gap;
					gap_y := o.world_position.y;
					raylib.DrawLineV({gap_start, gap_y}, {gap_end, gap_y},
									 o.color);
				}
				
				when false {
					raylib.DrawLineV({0, trex_world_y}, {f32(window_w), trex_world_y}, raylib.GREEN);
					raylib.DrawLineV({0, trex_ground_y_normal}, {f32(window_w), trex_ground_y_normal}, raylib.RED);
					raylib.DrawLineV({0, trex_min_jump_height}, {f32(window_w), trex_min_jump_height}, raylib.BLUE);
					raylib.DrawText("trex current y", 10, i32(trex_world_y + 5), 20, raylib.GREEN);
					raylib.DrawText("trex ground y", window_w / 2, i32(trex_ground_y_normal + 5), 20, raylib.RED);
				}
			}
			
			if .Variables in debug_draw_flags {
				name_of :: proc(v: $T, expr := #caller_expression(v)) -> string {
					return expr;
				}
				
				variables := [?]string {
					fmt.tprintf("%v: %v", name_of(MS_PER_FRAME), MS_PER_FRAME),
					fmt.tprintf("%v: %v", name_of(trex_status), trex_status),
					fmt.tprintf("%v: %v", name_of(trex_distance_ran), trex_distance_ran),
					fmt.tprintf("%v: %v", name_of(math.ceil(trex_distance_ran)), math.ceil(trex_distance_ran)),
					fmt.tprintf("%v: %v", name_of(math.round(METER_COEFFICIENT*math.ceil(trex_distance_ran))), math.round(METER_COEFFICIENT*math.ceil(trex_distance_ran))),
					fmt.tprintf("%v: %v", name_of(trex_run_speed), trex_run_speed),
				};
				
				max_text_w := i32(0);
				font_size := i32(10);
				text_y := i32(10);
				text_x := i32(10);
				for v in variables {
					s := strings.clone_to_cstring(v, context.temp_allocator);
					text_w := raylib.MeasureText(s, font_size);
					raylib.DrawText(s, global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
					max_text_w = max(max_text_w, text_w);
					text_y = text_y + font_size + 5;
				}
				global_debug_text_x += text_x + max_text_w;
			}
			
			if .Mute_Sfx in debug_draw_flags {
				font_size := i32(10);
				text_x := i32(10);
				s := mute_sfx ? cstring("Mute on") : cstring("Mute off");
				text_w := raylib.MeasureText(s, font_size);
				raylib.DrawText(s, global_debug_text_x + text_x, 10, font_size, raylib.BLACK);
				global_debug_text_x += text_x + text_w;
			}
			
			if .Obstacle_Buffer in debug_draw_flags {
				font_size := i32(10);
				text_y := i32(10);
				text_x := i32(10);
				text_x += MeasureAndDrawText("[", global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
				for i in 0..<small_array.cap(obstacle_buffer) {
					o, exists := small_array.get_safe(obstacle_buffer, i);
					s: cstring;
					if exists {
						s = strings.clone_to_cstring(fmt.tprintf("%v", o.gap), context.temp_allocator);
					} else {
						s = "-";
					}
					text_x += MeasureAndDrawText(s, global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
					if i + 1 < small_array.cap(obstacle_buffer) {
						text_x += MeasureAndDrawText(", ", global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
					}
				}
				text_x += MeasureAndDrawText("]", global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
				global_debug_text_x += text_x;
			}
			
			MeasureAndDrawText :: proc(text: cstring, posX, posY, fontSize: i32, color: raylib.Color) -> i32 {
				width := raylib.MeasureText(text, fontSize);
				raylib.DrawText(text, posX, posY, fontSize, color);
				
				return width;
			}
		}
		
		raylib.EndDrawing();
		
		frame_count_since_attempt_start += 1;
		time_since_attempt_start += dt;
	}
}

////////////////////////////////
// Game-specific utils

get_obstacle_width :: proc(o: Obstacle) -> f32 {
	templates := OBSTACLE_TEMPLATES;
	template  := templates[o.tag];
	
	return template.width * o.length;
}

////////////////////////////////
// Generic utils

// TODO(ema): These 3 small_array procedures can probabily be made faster by
// using the struct fields directly instead of relying on the provided
// procedures.
// TODO(ema): They are also overly-generic for what their purpose is, so
// more specialized versions can be made and would probabily be better.

ordered_remove_elems :: proc(a: ^$A/small_array.Small_Array($N, $T), indices: []int) {
	if a != nil && N > 0 {
		num_removed := 0;
		for index in indices {
			shifted_index := index - num_removed;
			if shifted_index < small_array.len(a^) {
				small_array.ordered_remove(a, shifted_index);
				num_removed += 1;
			}
		}
	}
}

force_push_back :: proc(a: ^$A/small_array.Small_Array($N, $T), item: T) -> (evicted: T) {
	if a != nil && N > 0 {
		if small_array.len(a^) == small_array.cap(a^) {
			evicted = small_array.pop_front(a);
		}
		small_array.push_back(a, item);
	}
	return evicted;
}

force_push_front :: proc(a: ^$A/small_array.Small_Array($N, $T), item: T) -> (evicted: T) {
	if a != nil && N > 0  {
		if small_array.len(a^) == small_array.cap(a^) {
			evicted = small_array.pop_back(a);
		}
		small_array.push_front(a, item);
	}
	return evicted;
}

// TODO(ema): This should *in theory* return a random value weighted using the passed array,
// but it doesn't look like the result is fair with respect to its inputs. Figure out
// if we can distribute the results better.

@(require_results)
weighted_choice_enum :: proc($T: typeid, weights: [$N]int, gen := context.random_generator) -> T where intrinsics.type_is_enum(T), N == len(T) {
	total := 0;
	for weight in weights do total += weight;
	
	n := rand.int_max(total, gen);
	
	result: T;
	weight_index := 0;
	for field in T {
		if weight_index >= len(weights) {
			break;
		}
		weight := weights[weight_index];
		if n < weight {
			result = field;
			break;
		}
		weight_index += 1;
		n -= weight;
	}
	assert(weight_index < len(weights), "No suitable choice was found");
	return result;
}

// Returns a random `i32` in the range `[lo, hi)`. If `lo >= hi`, returns the lowest of the two.
@(require_results)
int32_range_clamped :: proc(lo, hi: i32, gen := context.random_generator) -> (val: i32) {
	if lo < hi {
		val = rand.int32_range(lo, hi, gen);
	} else {
		val = min(lo, hi);
	}
	return val;
}

// Returns a new rect with the `x` and `y` fields incremented by `amount`.
@(require_results)
shift_rect :: proc(r: raylib.Rectangle, amount: [2]f32) -> raylib.Rectangle {
	return {r.x + amount.x, r.y + amount.y, r.width, r.height};
}

// Returns a new rect with every field multiplied by `2`.
@(require_results)
double_rect :: proc(r: raylib.Rectangle) -> raylib.Rectangle {
	return {r.x * 2, r.y * 2, r.width * 2, r.height * 2};
}
