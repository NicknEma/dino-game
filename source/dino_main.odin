package dino

// TODO(ema): Review all casts
// TODO(ema): Review all uses of framerate
// TODO(ema): Review all drawing sites for possible math.round() calls

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

WINDOW_W :: 600
WINDOW_H :: 150

BOTTOM_PAD :: 10;

BG_COLOR_DAY :: 0xF7F7F7FF

OFFLINE_SOUND_PRESS   :: #load("../assets/offline_sound_press.ogg")
OFFLINE_SOUND_HIT     :: #load("../assets/offline_sound_hit.ogg")
OFFLINE_SOUND_REACHED :: #load("../assets/offline_sound_reached.ogg")

////////////////////////////////
// Sprites

SPRITE             :: SPRITE_1X
SPRITE_COORDINATES :: SPRITE_1X_COORDINATES

SPRITE_1X :: #load("../assets/offline-sprite-1x.png")
SPRITE_2X :: #load("../assets/offline-sprite-2x.png")

SPRITE_1X_COORDINATES :: Sprite_Coordinates {
	obstacles = {
		.Cactus_Small = {228, 2},
		.Cactus_Large = {332, 2},
		.Pterodactyl  = {134, 2}
	},
	restart_icon = {  2, 2},
	game_over = {484, 15},
	horizon = { 2, 54},
	cloud   = {86,  2},
	score   = {484, 2},
	trex = {677, 2}
}

SPRITE_2X_COORDINATES :: Sprite_Coordinates {
	obstacles = {
		.Cactus_Small = {446, 2},
		.Cactus_Large = {652, 2},
		.Pterodactyl  = {260, 2}
	},
	restart_icon = {  2, 2},
	game_over = {954, 15},
	horizon = {  2, 104},
	cloud   = {166,   2},
	score   = {954, 2},
	trex  = {1338, 2}
}

// NOTE(ema): From the top-left corner of the image
Sprite_Coordinates :: struct {
	obstacles: [Obstacle_Tag][2]f32,
	restart_icon: [2]f32,
	game_over: [2]f32,
	horizon: [2]f32,
	cloud:   [2]f32,
	score:   [2]f32,
	trex: [2]f32
}

////////////////////////////////
// Trex constants & types

// TODO(ema): Better names for: drop velocity, drop coef (?); speed drop
// TODO(ema): Implement CLEAR_TIME

TREX_START_POSITION_X :: 50;
TREX_START_POSITION_Y :: WINDOW_H - BOTTOM_PAD - TREX_H_NORMAL;

TREX_INITIAL_RUN_SPEED :: 6;
TREX_MAX_RUN_SPEED     :: 13;
TREX_RUN_ACCELERATION  :: 0.001;

TREX_MAX_JUMP_HEIGHT :: 30;
TREX_MIN_JUMP_HEIGHT :: 30;
TREX_DROP_VELOCITY :: -5;
TREX_GRAVITY :: 0.6;
TREX_SPEED_DROP_COEFFICIENT :: 3;
TREX_START_JUMP_VELOCITY :: -10;

TREX_WAITING_ANIM_BLINK_TIMING :: 7000;

Trex_Status :: enum {
	Waiting, Running, Ducking, Jumping, Crashed
}

Trex :: struct {
	status: Trex_Status,
	hitboxes: []raylib.Rectangle, // TODO(ema): Is it necessary? Can be inferred at any time from the status
	screen_pos: [2]f32,
	
	distance_ran: f32,
	run_speed: f32,
	
	jump_velocity: f32,
	reached_min_height: bool,
	speed_drop: bool,
	
	waiting_anim_blink_delay: f32,
	waiting_anim_start_time: f32,
	anim_frame_index: i32,
	anim_timer: f32,
}

@(rodata)
trex_status_anim_frames_per_ms := [Trex_Status]int {
	.Running = 12, .Waiting =  3, .Crashed = 60,
	.Jumping = 60, .Ducking =  8
}

TREX_W_NORMAL ::  44;
TREX_H_NORMAL ::  47;
TREX_W_DUCK   ::  59;
// TREX_H_DUCK   ::  25; // Unused
// TREX_W_TOTAL  :: 262; // Unused

// NOTE(ema): From the top-left corner of the entity sub-sprite
@(rodata)
trex_sprite_recs := [Trex_Status][]raylib.Rectangle {
	.Waiting = {
		{  0,  0, TREX_W_NORMAL, TREX_H_NORMAL},
		{ 44,  0, TREX_W_NORMAL, TREX_H_NORMAL}
	},
	.Running = {
		{ 88,  0, TREX_W_NORMAL, TREX_H_NORMAL},
		{132,  0, TREX_W_NORMAL, TREX_H_NORMAL}
	},
	.Jumping = {
		{  0,  0, TREX_W_NORMAL, TREX_H_NORMAL}
	},
	.Crashed = {
		{220,  0, TREX_W_NORMAL, TREX_H_NORMAL}
	},
	
	// NOTE(ema): Pretend that the ducking sprite has the same height as the others,
	// avoid the whole update-y-based-on-status shenanigans (and the bugs that
	// come along with them). Use H_NORMAL.
	.Ducking = {
		{262,  0, TREX_W_DUCK,   TREX_H_NORMAL},
		{321,  0, TREX_W_DUCK,   TREX_H_NORMAL}
	},
}

@(rodata)
trex_hitboxes_running := [?]raylib.Rectangle {
	{22,  0, 17, 16}, { 1, 18, 30,  9}, {10, 35, 14,  8},
	{ 1, 24, 29,  5}, { 5, 30, 21,  4}, { 9, 34, 15,  4}
}

// NOTE(ema): The original hitbox (from the website) has a width of 55, however
// that creates weird spacing issues when you crash into an obstacle
// while ducking
@(rodata)
trex_hitboxes_ducking := [?]raylib.Rectangle {
	{ 1, 18, 40, 25}
}

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
	.Pterodactyl  = {0, 0, 46, 40},
}

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

////////////////////////////////
// Score text constants

METER_CHAR_W :: 10;
METER_CHAR_H :: 13;

METER_CHAR_SPACE :: 1; // NOTE(ema): Space between chars on screen

////////////////////////////////
// Game over text constants

GAME_OVER_TEXT_W :: 191;
GAME_OVER_TEXT_H ::  11;

////////////////////////////////
// Restart icon constants

RESTART_ICON_W :: 36;
RESTART_ICON_H :: 32;

////////////////////////////////
// Game code

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
	double_resolution := false; // TODO(ema): Remove
	
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(WINDOW_W, WINDOW_H, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(TARGET_FPS);
	
	raylib.InitAudioDevice();
	
	sound_press   := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_PRESS),   cast(i32)len(OFFLINE_SOUND_PRESS)));
	sound_hit     := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_HIT),     cast(i32)len(OFFLINE_SOUND_HIT)));
	sound_reached := raylib.LoadSoundFromWave(raylib.LoadWaveFromMemory(".ogg", raw_data(OFFLINE_SOUND_REACHED), cast(i32)len(OFFLINE_SOUND_REACHED)));
	
	sprite_mem := SPRITE;
	sprite_img := raylib.LoadImageFromMemory(".png", raw_data(sprite_mem), cast(i32)len(sprite_mem));
	sprite_tex := raylib.LoadTextureFromImage(sprite_img);
	
	////////////////////////////////
	// Trex variables
	
	trex: Trex;
	trex.status = .Waiting;
	
	trex.screen_pos.x = TREX_START_POSITION_X;
	trex.screen_pos.y = TREX_START_POSITION_Y;
	
	trex_min_jump_height := f32(TREX_START_POSITION_Y - TREX_MIN_JUMP_HEIGHT); // TODO(ema): What? Rename vars, this is confusing
	trex_jump_count: int;
	
	////////////////////////////////
	// Obstacle variables
	
	obstacle_history: small_array.Small_Array(OBSTACLE_HISTORY_CAP, Obstacle_Tag);
	obstacles: small_array.Small_Array(MAX_OBSTACLES, Obstacle);
	
	make_obstacle :: proc(history: []Obstacle_Tag, trex_run_speed: f32, x: f32, gen_tag := context.random_generator) -> Obstacle {
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
			if slice.count(history, tag) < MAX_OBSTACLE_DUPLICATION &&
				trex_run_speed >= templates[tag].min_trex_run_speed_for_single_spawn {
				break;
			}
			if it == 100 {
				tag = .Cactus_Small;
				break;
			}
		}
		
		templates := OBSTACLE_TEMPLATES;
		template  := templates[tag];
		
		obstacle  := Obstacle { tag = tag };
		small_array.push_back_elems(&obstacle.hitboxes, ..template.hitboxes);
		
		if trex_run_speed >= template.min_trex_run_speed_for_multiple_spawn {
			obstacle.length = cast(f32)rand.int32_range(1, MAX_COMPOUND_OBSTACLE_LENGTH + 1);
		} else {
			obstacle.length = 1;
		}
		
		obstacle_width := get_obstacle_width(obstacle);
		
		DO_UGLY_BUT_FAITHFUL_POP_IN :: false;
		
		when DO_UGLY_BUT_FAITHFUL_POP_IN {
			obstacle.world_position.x = WINDOW_W - obstacle_width;
		} else {
			obstacle.world_position.x = WINDOW_W;
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
			min_gap := obstacle_width * trex_run_speed + template.min_gap * MIN_OBSTACLE_GAP_COEFFICIENT;
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
	
	////////////////////////////////
	// Ground variables
	
	GROUND_TOTAL_W        :: 1200;
	GROUND_SECTION_W      :: WINDOW_W;
	GROUND_SECTION_COUNT  :: GROUND_TOTAL_W / GROUND_SECTION_W;
	
	GROUND_BUMP_THRESHOLD :: 0.5;
	
	GROUND_Y :: 127;
	GROUND_H ::  12;
	
	Ground_Section :: struct {
		screen_x: f32,
		sprite_x: f32,
	}
	
	ground_sections: [GROUND_SECTION_COUNT]Ground_Section; // Coordinates on screen of where each sprite starts
	
	init_ground(ground_sections[:]);
	
	init_ground :: proc(ground_sections: []Ground_Section, gen_bump := context.random_generator) {
		for &section, section_index in ground_sections {
			section.screen_x = f32(section_index) * GROUND_SECTION_W;
			section.sprite_x = SPRITE_COORDINATES.horizon.x + (rand.float32(gen_bump) > GROUND_BUMP_THRESHOLD ? 0 : GROUND_SECTION_W);
		}
	}
	
	////////////////////////////////
	// Clouds variables
	
	MAX_CLOUD_GAP :: 400;
	MAX_SKY_LEVEL :: 71;
	MIN_CLOUD_GAP :: 100;
	MIN_SKY_LEVEL :: 30;
	
	CLOUD_FREQUENCY :: 0.5;
	CLOUD_SPEED   :: 0.2;
	MAX_CLOUDS    :: 6;
	
	CLOUD_W :: 46;
	CLOUD_H :: 14;
	
	cloud_rec := raylib.Rectangle {
		SPRITE_COORDINATES.cloud.x, SPRITE_COORDINATES.cloud.y,
		CLOUD_W, CLOUD_H
	}
	
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
	
	METER_DEFAULT_DIGIT_COUNT  :: 5;
	
	METER_ACHIEVEMENT_DISTANCE :: 100;
	METER_INTERNAL_TO_DISPLAY_COEFFICIENT :: 0.025;
	
	METER_FLASH_DURATION   :: 1000 / 4;
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
	
	////////////////////////////////
	// Game-over screen variables
	
	game_over_text_rec := raylib.Rectangle {
		SPRITE_COORDINATES.game_over.x, SPRITE_COORDINATES.game_over.y,
		GAME_OVER_TEXT_W, GAME_OVER_TEXT_H
	};
	
	game_over_text_pos := [2]f32 {
		math.round(f32((WINDOW_W) / 2.0 - GAME_OVER_TEXT_W / 2.0)),
		math.round(f32((WINDOW_H - 25.0) / 3.0))
	};
	
	restart_icon_rec := raylib.Rectangle {
		SPRITE_COORDINATES.restart_icon.x, SPRITE_COORDINATES.restart_icon.y,
		RESTART_ICON_W, RESTART_ICON_H
	}
	
	restart_icon_pos := [2]f32 {
		math.round(f32(WINDOW_W / 2.0 - RESTART_ICON_W / 2.0)),
		math.round(f32(WINDOW_H / 2.0))
	}
	
	////////////////////////////////
	// Other variables
	
	// Attempt info
	frame_count_since_attempt_start := 0;
	time_since_attempt_start := f32(0);
	time_since_startup := f32(0);
	
	// Session info
	attempt_count := 0;
	
	mute_sfx := false;
	
	when ODIN_DEBUG {
		Debug_Draw_Flag :: enum {
			Hotkeys,
			Hitboxes,
			Variables,
			Mute_Sfx,
			Obstacles
		}
		
		debug_draw_flags := bit_set[Debug_Draw_Flag] { .Hotkeys, .Mute_Sfx };
		mute_sfx = true;
	}
	
	////////////////////////////////
	// Main loop
	
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
				trex.run_speed = min(1.1*trex.run_speed, TREX_MAX_RUN_SPEED);
			}
			
			if raylib.IsKeyPressed(raylib.KeyboardKey.KP_SUBTRACT) {
				trex.run_speed = max(0.9*trex.run_speed, TREX_INITIAL_RUN_SPEED);
			}
		}
		
		////////////////////////////////
		// Pre-render update
		
		// Simulate trex
		// TODO(ema): Add 1 frame of cooldown between crash and the ability to start a new game
		trex_prev_status := trex.status;
		for trex_prevent_jump := false; true; {
			trex_status_changed := false;
			
			if trex.status == .Waiting || trex.status == .Crashed {
				should_start := false;
				
				if trex.status == .Waiting {
					if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.UP) || raylib.IsMouseButtonPressed(.LEFT) {
						should_start = true;
						trex_prevent_jump = true;
					}
				} else {
					if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.UP) || raylib.IsMouseButtonPressed(.LEFT) {
						should_start = true;
						trex_prevent_jump = true;
						if !mute_sfx {
							raylib.PlaySound(sound_press);
						}
					}
				}
				
				if should_start {
					trex.status = .Running;
					trex_status_changed = true;
					
					attempt_count += 1;
					
					meter.score = 0;
					meter.digit_count = METER_DEFAULT_DIGIT_COUNT;
					meter.flash_iterations = 0;
					meter.flash_timer = 0.0;
					meter.achievement = false;
					if meter.high_digit_count < METER_DEFAULT_DIGIT_COUNT {
						meter.high_digit_count = METER_DEFAULT_DIGIT_COUNT;
					}
					
					trex.distance_ran = 0;
					trex.run_speed = TREX_INITIAL_RUN_SPEED;
					trex.screen_pos.x = TREX_START_POSITION_X;
					trex.screen_pos.y = TREX_START_POSITION_Y;
					
					trex_jump_count = 0;
					
					small_array.clear(&obstacle_history);
					small_array.clear(&obstacles);
					init_ground(ground_sections[:]);
					small_array.clear(&clouds);
					small_array.push_back(&clouds, make_cloud(x = WINDOW_W));
					
					frame_count_since_attempt_start = 0;
					time_since_attempt_start = 0;
				}
			} else {
				// if playing intro, play intro, else:
				
				#partial switch trex.status {
					case .Running: {
						trex.hitboxes = trex_hitboxes_running[:];
						
						if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
							trex.status = .Ducking;
							trex_status_changed = true;
						}
						
						if raylib.IsKeyPressed(raylib.KeyboardKey.UP) && trex.status != .Ducking && !trex_prevent_jump {
							if !mute_sfx {
								raylib.PlaySound(sound_press);
							}
							
							trex.status = .Jumping;
							trex_status_changed = true;
							
							trex.jump_velocity = TREX_START_JUMP_VELOCITY - (trex.run_speed / 10.0);
							trex.reached_min_height = false;
						}
					}
					
					case .Ducking: {
						trex.hitboxes = trex_hitboxes_ducking[:];
						
						if raylib.IsKeyUp(raylib.KeyboardKey.DOWN) {
							trex.status = .Running;
							trex_status_changed = true;
						}
					}
					
					case .Jumping: {
						trex.hitboxes = trex_hitboxes_running[:];
						
						// TODO(ema): Rename this variable
						z := dt * TARGET_FPS;
						
						if raylib.IsKeyReleased(raylib.KeyboardKey.UP) {
							if trex.reached_min_height && trex.jump_velocity < TREX_DROP_VELOCITY {
								trex.jump_velocity = TREX_DROP_VELOCITY;
							}
						}
						
						if raylib.IsKeyDown(raylib.KeyboardKey.DOWN) {
							if !trex.speed_drop {
								trex.jump_velocity = 1;
								trex.speed_drop = true;
							}
							
							trex.screen_pos.y += trex.jump_velocity * z * TREX_SPEED_DROP_COEFFICIENT;
						} else {
							trex.screen_pos.y += trex.jump_velocity * z;
						}
						
						trex.jump_velocity += TREX_GRAVITY * z;
						
						if trex.screen_pos.y < trex_min_jump_height || trex.speed_drop {
							trex.reached_min_height = true;
						}
						
						if trex.screen_pos.y < TREX_MAX_JUMP_HEIGHT || trex.speed_drop {
							if trex.reached_min_height && trex.jump_velocity < TREX_DROP_VELOCITY {
								trex.jump_velocity = TREX_DROP_VELOCITY;
							}
						}
						
						if trex.screen_pos.y > TREX_START_POSITION_Y {
							trex.screen_pos.y = TREX_START_POSITION_Y;
							trex.jump_velocity = 0;
							trex.status = .Running;
							trex_status_changed = true;
							trex.speed_drop = false;
							
							// TODO(ema): Maybe add: if UP pressed, keep status = jumping, else set status = running
						}
					}
					
					case: {
						raylib.TraceLog(.ERROR, strings.clone_to_cstring(fmt.tprintf("Invalid switch case %v",
																					 trex.status),
																		 context.temp_allocator));
					}
				}
			}
			
			if !trex_status_changed {
				break;
			}
		}
		
		// Simulate rest of the world
		if trex.status != .Waiting && trex.status != .Crashed {
			
			// Update horizon line (ground)
			{
				delta := trex.run_speed * TARGET_FPS * dt;
				
				for &section in ground_sections {
					section.screen_x -= delta;
					
					if section.screen_x + GROUND_SECTION_W < 0 {
						section.screen_x += 2.0 * GROUND_SECTION_W;
						section.sprite_x  = SPRITE_COORDINATES.horizon.x + (rand.float32() > GROUND_BUMP_THRESHOLD ? 0 : GROUND_SECTION_W);
					}
				}
			}
			
			// Update clouds
			{
				delta := CLOUD_SPEED * TARGET_FPS * dt * trex.run_speed;
				
				passed_clouds: small_array.Small_Array(len(clouds.data), int);
				for cloud_index := 0; cloud_index < small_array.len(clouds); cloud_index += 1 {
					cloud := small_array.get_ptr(&clouds, cloud_index);
					cloud.screen_pos.x -= delta;
					
					is_visible_or_to_the_right := cloud.screen_pos.x + CLOUD_W > 0;
					if !is_visible_or_to_the_right {
						small_array.append(&passed_clouds, cloud_index);
					}
				}
				
				ordered_remove_elems(&clouds, small_array.slice(&passed_clouds));
				
				try_add_cloud := false;
				if small_array.len(clouds) > 0 {
					last := small_array.get(clouds, small_array.len(clouds) - 1);
					if small_array.space(clouds) > 0 && last.screen_pos.x + CLOUD_W + last.gap < WINDOW_W {
						try_add_cloud = true;
					}
				} else {
					try_add_cloud = true;
				}
				
				if try_add_cloud && rand.float32() < CLOUD_FREQUENCY {
					small_array.push_back(&clouds, make_cloud(x = WINDOW_W));
				}
			}
			
			// Update obstacles
			{
				templates := OBSTACLE_TEMPLATES;
				
				compute_delta :: proc(trex_run_speed: f32, obstacle_speed_offset: f32, dt: f32) -> f32 {
					speed := trex_run_speed + obstacle_speed_offset;
					delta := speed * TARGET_FPS * dt;
					return delta;
				}
				
				passed_obstacles: small_array.Small_Array(len(obstacles.data), int);
				for obstacle_index := 0; obstacle_index < small_array.len(obstacles); obstacle_index += 1 {
					obstacle := small_array.get_ptr(&obstacles, obstacle_index);
					obstacle.world_position.x -= compute_delta(trex.run_speed, obstacle.speed_offset, dt);
					
					obstacle.seconds_since_anim_frame_changed += dt;
					if obstacle.seconds_since_anim_frame_changed > obstacle.anim_frames_per_second {
						obstacle.current_anim_frame += 1;
						if obstacle.current_anim_frame == templates[obstacle.tag].num_anim_frames {
							obstacle.current_anim_frame = 0;
						}
						
						obstacle.seconds_since_anim_frame_changed = 0;
					}
					
					is_visible_or_to_the_right := obstacle.world_position.x + get_obstacle_width(obstacle^) > 0;
					if !is_visible_or_to_the_right {
						small_array.push_back(&passed_obstacles, obstacle_index);
					}
				}
				
				ordered_remove_elems(&obstacles, small_array.slice(&passed_obstacles));
				
				add_obstacle := false;
				if small_array.len(obstacles) > 0 {
					last := small_array.get(obstacles, small_array.len(obstacles) - 1);
					if small_array.space(obstacles) > 0 && last.world_position.x + get_obstacle_width(last) + last.gap < WINDOW_W {
						add_obstacle = true;
					}
				} else {
					add_obstacle = true;
				}
				
				if add_obstacle {
					obstacle := make_obstacle(small_array.slice(&obstacle_history), trex.run_speed, x = WINDOW_W);
					
					small_array.push_back(&obstacles, obstacle);
					force_push_front(&obstacle_history, obstacle.tag);
				}
			}
			
			// check collisions
			{
				hit := false;
				obstacle_loop: for &obstacle in small_array.slice(&obstacles) {
					for obstacle_hitbox in small_array.slice(&obstacle.hitboxes) {
						rectA := shift_rect(obstacle_hitbox, obstacle.world_position);
						for trex_hitbox in trex.hitboxes {
							rectB := shift_rect(trex_hitbox, trex.screen_pos);
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
					
					trex.status = .Crashed;
					meter.score = meter.up_to_date_score;
					meter.high_score = max(meter.high_score, meter.score);
				}
			}
		}
		
		meter_should_draw := true;
		
		// Simulate trex run
		if trex.status != .Crashed && trex.status != .Waiting {
			// NOTE(ema): Don't do this before collision checking, because *technically*
			// you haven't run the distance if you crashed
			trex.distance_ran += trex.run_speed * dt * TARGET_FPS;
			if trex.run_speed < TREX_MAX_RUN_SPEED {
				trex.run_speed += TREX_RUN_ACCELERATION;
			}
			
			// Update high score
			{
				score := cast(i32)math.round(METER_INTERNAL_TO_DISPLAY_COEFFICIENT * math.ceil(trex.distance_ran));
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
		}
		
		// Animate trex
		{
			trex.anim_timer += dt;
			
			reset_blink :: proc(trex: ^Trex, time_since_startup: f32) {
				trex.waiting_anim_start_time = time_since_startup;
				trex.waiting_anim_blink_delay = rand.float32() * TREX_WAITING_ANIM_BLINK_TIMING;
			}
			
			if trex_prev_status != trex.status {
				trex.anim_frame_index = 0;
				
				if trex.status == .Waiting {
					reset_blink(&trex, time_since_startup);
				}
			}
			
			if trex.status == .Waiting {
				trex.anim_frame_index = 0;
				if time_since_startup - trex.waiting_anim_start_time >= trex.waiting_anim_blink_delay {
					reset_blink(&trex, time_since_startup);
					trex.anim_frame_index = 1;
				}
			} else {
				anim_frames_per_ms := cast(f32)trex_status_anim_frames_per_ms[trex.status];
				anim_ms_per_frame  := 1.0 / anim_frames_per_ms;
				if trex.anim_timer >= anim_ms_per_frame {
					trex.anim_frame_index = (trex.anim_frame_index == cast(i32)len(trex_sprite_recs[trex.status]) - 1) ? 0 : (trex.anim_frame_index + 1);
					trex.anim_timer = 0;
				}
			}
		}
		
		////////////////////////////////
		// Render
		
		raylib.BeginDrawing();
		
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		// Draw horizon line (ground)
		for section in ground_sections {
			pos := [2]f32 {section.screen_x, GROUND_Y};
			rec := raylib.Rectangle {
				section.sprite_x, SPRITE_COORDINATES.horizon.y,
				GROUND_SECTION_W, GROUND_H
			}
			
			raylib.DrawTextureRec(sprite_tex, rec, pos, raylib.WHITE);
		}
		
		// Draw clouds
		for cloud in small_array.slice(&clouds) {
			raylib.DrawTextureRec(sprite_tex, cloud_rec, cloud.screen_pos, raylib.WHITE);
		}
		
		// Draw obstacles
		{
			obstacle_sprite_rects := OBSTACLE_SPRITE_RECTS;
			for o in small_array.slice(&obstacles) {
				offsets := SPRITE_COORDINATES.obstacles;
				offset  := offsets[o.tag];
				
				rec := shift_rect(obstacle_sprite_rects[o.tag], offset);
				pos := o.world_position;
				
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
			rec := trex_sprite_recs[trex.status][trex.anim_frame_index];
			rec  = shift_rect(rec, SPRITE_COORDINATES.trex);
			
			raylib.DrawTextureRec(sprite_tex, rec, trex.screen_pos, raylib.WHITE);
		}
		
		// Draw score
		{
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
			
			digit_base_rec := raylib.Rectangle {
				SPRITE_COORDINATES.score.x, SPRITE_COORDINATES.score.y,
				METER_CHAR_W, METER_CHAR_H
			};
			
			digit_base_pos := [2]f32 {
				WINDOW_W - ((METER_CHAR_W + METER_CHAR_SPACE) * (f32(meter.digit_count) + 1.0)),
				5.0
			};
			
			if meter_should_draw {
				draw_meter(meter.score, meter.digit_count, nil, sprite_tex, digit_base_rec, digit_base_pos,
						   METER_CHAR_W, METER_CHAR_W + METER_CHAR_SPACE, raylib.WHITE);
			}
			
			digit_base_pos.x -= (f32(meter.digit_count) * 2.0) * (METER_CHAR_W + METER_CHAR_SPACE);
			
			if meter.high_score > 0 {
				high_score_alpha := f32(0.8);
				high_score_color := raylib.ColorAlpha(raylib.WHITE, high_score_alpha);
				
				// NOTE(ema): Since the texture contains the character images in the form of the
				// string "0123456789HI ", we can use hardcoded "indices" to indicate chars
				// that aren't digits (10 for H, 11 for I, 12 for empty space)
				@(static, rodata) HIGH_SCORE_PREFIX_INDICES := [?]i32 {10, 11, 12};
				
				draw_meter(meter.high_score, meter.high_digit_count, HIGH_SCORE_PREFIX_INDICES[:], sprite_tex, digit_base_rec, digit_base_pos,
						   METER_CHAR_W, METER_CHAR_W + METER_CHAR_SPACE, high_score_color);
			}
		}
		
		// Draw game over panel
		if trex.status == .Crashed {
			raylib.DrawTextureRec(sprite_tex, game_over_text_rec, game_over_text_pos, raylib.WHITE); // Draw text
			raylib.DrawTextureRec(sprite_tex, restart_icon_rec, restart_icon_pos, raylib.WHITE);     // Draw restart icon
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
				for r in trex.hitboxes {
					shifted := shift_rect(r, trex.screen_pos);
					raylib.DrawRectangleLinesEx(shifted, 1, raylib.RED);
				}
				
				for &o in small_array.slice(&obstacles) {
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
			}
			
			if .Variables in debug_draw_flags {
				name_of :: proc(v: $T, expr := #caller_expression(v)) -> string {
					return expr;
				}
				
				variables := [?]string {
					fmt.tprintf("%v: %v", name_of(MS_PER_FRAME), MS_PER_FRAME),
					fmt.tprintf("%v: %v", name_of(trex.status), trex.status),
					fmt.tprintf("%v: %v", name_of(trex.run_speed), trex.run_speed),
					fmt.tprintf("%v: %v", name_of(trex.waiting_anim_start_time), trex.waiting_anim_start_time),
					fmt.tprintf("%v: %v", name_of(trex.anim_timer), trex.anim_timer),
					fmt.tprintf("%v: %v", name_of(trex.waiting_anim_blink_delay), trex.waiting_anim_blink_delay),
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
			
			if .Obstacles in debug_draw_flags {
				font_size := i32(10);
				text_y := i32(10);
				text_x := i32(10);
				text_x += MeasureAndDrawText("[", global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
				for i in 0..<small_array.cap(obstacles) {
					o, exists := small_array.get_safe(obstacles, i);
					s: cstring;
					if exists {
						s = strings.clone_to_cstring(fmt.tprintf("%v", o.gap), context.temp_allocator);
					} else {
						s = "-";
					}
					text_x += MeasureAndDrawText(s, global_debug_text_x + text_x, text_y, font_size, raylib.BLACK);
					if i + 1 < small_array.cap(obstacles) {
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
		
		////////////////////////////////
		// Post-render update
		
		frame_count_since_attempt_start += 1;
		time_since_attempt_start += dt;
		time_since_startup += dt;
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
