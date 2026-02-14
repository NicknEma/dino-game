package dino

import "base:runtime"

import os "core:os/os2"

import "core:fmt"
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

Obstacle_Tag :: enum { Cactus_Small, Cactus_Large, Pterodactyl }
Obstacle_Template :: struct {
	width: f32,
	height: f32,
	possible_y_positions: []f32,
	multiple_speed: f32, // minimum required speed for this obstacle to appear in groups TODO(ema): Better name
	min_gap: f32,
	min_speed: f32,
	collision_boxes: []raylib.Rectangle,
	// num_frames,
	// frame_rate,
	speed_offset: f32,
}

OBSTACLE_TEMPLATES :: [len(Obstacle_Tag)]Obstacle_Template {
	Obstacle_Tag.Cactus_Small = {
		width = 17,
		height = 35,
		possible_y_positions = {105},
		multiple_speed = 4,
		min_gap = 120,
		min_speed = 0,
		collision_boxes = { {0,7,5,27}, {4,0,6,34}, {10,4,7,14} }
	},
	
	Obstacle_Tag.Cactus_Large = {
		width = 25,
		height = 50,
		possible_y_positions = {90},
		multiple_speed = 7,
		min_gap = 120,
		min_speed = 0,
		collision_boxes = { {0,12,7,38}, {8,0,7,49}, {13,10,10,38} }
	},
	
	Obstacle_Tag.Pterodactyl = {
		width = 46,
		height = 40,
		possible_y_positions = {100, 75, 50},
		multiple_speed = 999, // TODO(ema): Review this
		min_gap = 150,
		min_speed = 8.5,
		collision_boxes = { {15,15,16,5}, {18,21,24,6}, {2,14,4,3}, {6,10,4,7}, {10,8,6,9} },
		speed_offset = 0.8,
	}
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
	double_size := false;
	for arg in os.args {
		if arg == "-2x" {
			double_size = true;
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
	if double_size {
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
		
		double_rect :: proc(r: raylib.Rectangle) -> raylib.Rectangle {
			return {r.x * 2, r.y * 2, r.width * 2, r.height * 2};
		}
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
	if double_size {
		bottom_pad *= 2;
	}
	
	////////////////////////////////
	// T-rex variables
	
	// TODO(ema): Better names for: drop velocity, x-accel (run accel), max speed (max run speed),
	// drop coef (?); speed drop
	
	TREX_WORLD_POSITION_X :: 50;
	TREX_MAX_JUMP_HEIGHT :: 30;
	TREX_MIN_JUMP_HEIGHT :: 30;
	TREX_DROP_VELOCITY :: -5;
	TREX_INITIAL_RUN_SPEED :: 1; // 6; TODO(ema): Fix moving ground and restore this to 6
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
	if double_size {
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
	// Obstacles
	
	Obstacle :: struct {
		collision_boxes: small_array.Small_Array(5, raylib.Rectangle),
		sprite_rec: raylib.Rectangle,
		on_screen_position: [2]f32,
		width: f32,
		gap: f32, // TODO(ema): Do I have a better name for this?
	}
	
	MAX_OBSTACLES :: 5;
	MAX_COMPOUND_OBSTACLE_LENGTH :: 3;
	MIN_OBSTACLE_GAP_COEFFICIENT :: 0.6; // TODO(ema): Do I have a better name for these?
	MAX_OBSTACLE_GAP_COEFFICIENT :: 1.5;
	MAX_OBSTACLE_DUPLICATION :: 2;
	OBSTACLE_HISTORY_CAP :: MAX_OBSTACLE_DUPLICATION * len(Obstacle_Tag);
	obstacle_history: small_array.Small_Array(OBSTACLE_HISTORY_CAP, Obstacle_Tag);
	obstacle_buffer: small_array.Small_Array(MAX_OBSTACLES, Obstacle);
	
	////////////////////////////////
	// Ground
	
	// Coordinates on screen of where each sprite starts
	ground_x: [SCREEN_GROUND_NUM_SECTIONS]i32;
	// Coordinates in the spritesheet of where each sprite starts
	sprite_1x_ground_x: [SPRITE_1X_GROUND_NUM_SECTIONS]i32;
	ground_bump_threshold := f32(0.5);
	
	ground_x[0] = 0;
	ground_x[1] = SCREEN_GROUND_SEC_W;
	sprite_1x_ground_x[0] = SPRITE_1X_GROUND_X;
	sprite_1x_ground_x[1] = SPRITE_1X_GROUND_X + SPRITE_1X_GROUND_SEC_W;
	
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
			Mute_Sfx
		}
		
		debug_draw_flags := bit_set[Debug_Draw_Flag] { .Hotkeys, .Hitboxes, .Mute_Sfx };
		mute_sfx = true;
	}
	
	for !raylib.WindowShouldClose() {
		free_all(context.temp_allocator);
		
		dt := raylib.GetFrameTime();
		
		when ODIN_DEBUG {
			for f in Debug_Draw_Flag {
				k := raylib.KeyboardKey(cast(int)f + cast(int)raylib.KeyboardKey.ZERO);
				if raylib.IsKeyPressed(raylib.KeyboardKey(k)) {
					if f in debug_draw_flags { // TODO(ema): More idiomatic way to toggle flag?
						debug_draw_flags -= {f};
					} else {
						debug_draw_flags += {f};
					}
				}
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.M) {
				mute_sfx = !mute_sfx;
			}
		}
		
		trex_sprite_rect: raylib.Rectangle;
		{
			rect_slice: []raylib.Rectangle;
			trex_anim_frames_per_ms: int;
			if trex_status == .Waiting {
				rect_slice = sprite_rects.trex_waiting[:1]; // Temporary :1
				trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Waiting];
				
				if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) || raylib.IsKeyPressed(raylib.KeyboardKey.UP) ||
					raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {
					trex_status = .Running;
					attempt_count += 1;
					
					// set distance meter = 0
					// set distance ran = 0
					// set speed to initial
					// set accel = 0
					// reset trex position
					// clear hazard queue
					small_array.clear(&obstacle_history);
					small_array.clear(&obstacle_buffer);
					// reset ground
					// add cloud
					
					frame_count_since_attempt_start = 0;
					time_since_attempt_start = 0;
					trex_run_speed = TREX_INITIAL_RUN_SPEED;
					trex_jump_count = 0;
				}
			} else if trex_status == .Crashed {
				// save high score
				
				if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) || raylib.IsKeyPressed(raylib.KeyboardKey.UP) {
					if !mute_sfx {
						raylib.PlaySound(sound_press);
					}
					
					// restart
				}
			} else {
				// if playing intro, play intro, else:
				
				rect_slice = sprite_rects.trex_running[:];
				trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Running];
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
							raylib.PlaySound(sound_press);
							trex_status = .Jumping;
							
							trex_jump_velocity = TREX_START_JUMP_VELOCITY - (trex_run_speed / 10.0);
							trex_reached_min_height = false;
						}
					}
					
					case .Ducking: {
						rect_slice = sprite_rects.trex_ducking[:];
						trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Ducking];
						
						trex_world_y = trex_ground_y_duck;
						trex_collision_boxes = trex_collision_boxes_ducking[:];
						
						if raylib.IsKeyUp(raylib.KeyboardKey.DOWN) {
							trex_status = .Running;
						}
					}
					
					case .Jumping: {
						rect_slice = sprite_rects.trex_jumping[:];
						trex_anim_frames_per_ms = trex_status_anim_frames_per_ms[Trex_Status.Jumping];
						
						ms_per_frame := 1.0 / f32(trex_anim_frames_per_ms);
						z := dt / ms_per_frame;
						
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
				
				// update horizon line (ground)
				// update clouds
				
				// update obstacles:
				//  for each obstacle
				//   update it
				//   if it should be removed   TODO(ema): Is it necessary? See below todo
				//    remove it
				// if num obstacles > 0
				//  d := last obstacle
				//  
				// else
				//  add new obstacle
				
				update_obstacles(&obstacle_history, &obstacle_buffer, trex_run_speed, dt, f32(window_w));
				
				// TODO(ema): Pass horizon width in and remove hardcoded values
				// TODO(ema): Draw obstacles
				// TODO(ema): Why not automatically evict obstacles as well? Why do separate checks?
				update_obstacles :: proc(history: ^small_array.Small_Array($H, Obstacle_Tag),
										 buffer: ^small_array.Small_Array($B, Obstacle),
										 current_speed: f32, dt: f32, horizon_w: f32) {
					for &o in small_array.slice(buffer) {
						delta := (current_speed * dt * 200); // TODO(ema): Remove @Hardcoded val
						o.on_screen_position.x -= delta;
					}
					
					if small_array.len(buffer^) > 0 {
						last := small_array.get(buffer^, small_array.len(buffer^) - 1);
						if last.on_screen_position.x + last.width + last.gap < horizon_w {
							append_obstacle(history, buffer, current_speed, horizon_w);
						}
					} else {
						append_obstacle(history, buffer, current_speed, horizon_w);
					}
				}
				
				append_obstacle :: proc(history: ^small_array.Small_Array($H, Obstacle_Tag),
										buffer: ^small_array.Small_Array($B, Obstacle),
										current_speed: f32, horizon_w: f32) {
					tag: Obstacle_Tag = ---;
					for it in 0..<10 {
						tag = rand.choice_enum(Obstacle_Tag);
						templates := OBSTACLE_TEMPLATES;
						if slice.count(small_array.slice(history), tag) < MAX_OBSTACLE_DUPLICATION &&
							current_speed >= templates[tag].min_speed {
							break;
						}
					}
					
					obstacle := make_obstacle(tag, current_speed, horizon_w);
					if !small_array.push_back(buffer, obstacle) {
						raylib.TraceLog(.ERROR, "Tried to add an obstacle to the buffer, but it was full");
					}
					force_push_front(history, tag);
					
					force_push_front :: proc(a: ^$A/small_array.Small_Array($N, $T), item: T) -> (evicted: T) {
						if a != nil {
							if small_array.len(a^) > 0 {
								evicted = small_array.pop_back(a);
							}
							small_array.push_front(a, item);
						}
						return evicted;
					}
				}
				
				make_obstacle :: proc(tag: Obstacle_Tag, current_speed: f32, horizon_w: f32) -> Obstacle {
					templates := OBSTACLE_TEMPLATES;
					template  := templates[tag];
					
					obstacle: Obstacle;
					small_array.push_back_elems(&obstacle.collision_boxes, ..template.collision_boxes);
					
					length: i32 = 1;
					if current_speed >= template.multiple_speed {
						length = rand.int32_range(0, MAX_COMPOUND_OBSTACLE_LENGTH - 1);
					}
					
					int32_range_clamped :: proc(lo, hi: i32, gen := context.random_generator) -> (val: i32) {
						if lo < hi {
							val = rand.int32_range(lo, hi, gen);
						} else {
							val = min(lo, hi);
						}
						return val;
					}
					
					width := template.width * f32(length);
					x_pos := horizon_w; // TODO(ema): horizon width - this.width ??
					y_pos := template.possible_y_positions[int32_range_clamped(0, cast(i32)len(template.possible_y_positions) - 1)];
					#no_bounds_check if length > 1 {
						#assert(len(obstacle.collision_boxes.data) >= 3);
						b := small_array.slice(&obstacle.collision_boxes);
						
						// When the obstacle is a compound obstacle, make adjustments to the
						// collision boxes so that they cover the entire width
						b[1].width = width - b[0].width - b[2].width;
						b[2].x = width - b[2].width;
					}
					speed_offset := template.speed_offset * (rand.float32() < 0.5 ? -1 : +1);
					
					min_gap := width * current_speed + template.min_gap * MIN_OBSTACLE_GAP_COEFFICIENT;
					max_gap := min_gap * MAX_OBSTACLE_GAP_COEFFICIENT;
					gap := rand.float32_range(min_gap, max_gap);
					
					// TODO(ema): For cactuses, randomly pick a sprite for each element of the group
					switch tag {
						case .Cactus_Small: {
							obstacle.sprite_rec.x = SPRITE_1X_COORDINATES.cactus_small.x;
							obstacle.sprite_rec.y = SPRITE_1X_COORDINATES.cactus_small.y;
							obstacle.sprite_rec.width = CACTUS_SMALL_SPRITE_WIDTH;
							obstacle.sprite_rec.height = CACTUS_SMALL_SPRITE_HEIGHT;
						}
						
						case .Cactus_Large: {
							obstacle.sprite_rec.x = SPRITE_1X_COORDINATES.cactus_large.x;
							obstacle.sprite_rec.y = SPRITE_1X_COORDINATES.cactus_large.y;
							obstacle.sprite_rec.width = CACTUS_LARGE_SPRITE_WIDTH;
							obstacle.sprite_rec.height = CACTUS_LARGE_SPRITE_HEIGHT;
						}
						
						case .Pterodactyl: {
							unimplemented();
						}
					}
					
					obstacle.gap = gap;
					obstacle.width = width;
					obstacle.on_screen_position = {x_pos, y_pos};
					return obstacle;
				}
				
				// check collisions
				
				// NOTE(ema): Don't do this before collision checking, because *technically*
				// you haven't run the distance if you crashed
				trex_distance_ran += trex_run_speed * dt / MS_PER_FRAME;
				if trex_run_speed < TREX_MAX_SPEED {
					trex_run_speed += TREX_X_ACCELERATION;
				}
				
				// update high score
				// play new high score sound
				
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
			
			rect_index := (frame_count_since_attempt_start / trex_anim_frames_per_ms) % len(rect_slice);
			trex_sprite_rect = rect_slice[rect_index];
			trex_sprite_rect = shift_rect(trex_sprite_rect, sprite_coordinates.trex);
		}
		
		raylib.BeginDrawing();
		
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		// Draw ground
		{
			delta := cast(i32)(trex_run_speed * dt * 200);
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
		
		// Draw obstacles
		{
			for o in small_array.slice(&obstacle_buffer) {
				pos := o.on_screen_position;
				rec := o.sprite_rec;
				raylib.DrawTextureRec(sprite_tex, rec, pos, raylib.WHITE);
			}
		}
		
		raylib.DrawTextureRec(sprite_tex, trex_sprite_rect, {trex_world_x, trex_world_y}, raylib.WHITE);
		
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
					for b in small_array.slice(&o.collision_boxes) {
						shifted := shift_rect(b, o.on_screen_position);
						raylib.DrawRectangleLinesEx(shifted, 1, raylib.RED);
					}
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
					fmt.tprintf("%v: %v", name_of(trex_min_jump_height), trex_min_jump_height),
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
				s := mute_sfx ? cstring("Mute on") : cstring("Mute off");
				raylib.DrawText(s, global_debug_text_x, 10, 10, raylib.BLACK);
			}
		}
		
		raylib.EndDrawing();
		
		frame_count_since_attempt_start += 1;
		time_since_attempt_start += dt;
	}
}

shift_rect :: proc(r: raylib.Rectangle, amount: [2]f32) -> raylib.Rectangle {
	return {r.x + amount.x, r.y + amount.y, r.width, r.height};
}
