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

Sprites :: struct {
	cactus_large: raylib.Image,
	cactus_small: raylib.Image,
	cloud: raylib.Image,
	ground: raylib.Image,
	pterodactyl: raylib.Image,
	restart_icon: raylib.Image,
	trex: raylib.Image,
	text: raylib.Image
}

main :: proc() {
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(DEFAULT_WINDOW_W, DEFAULT_WINDOW_H, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(60);
	
	spritesheet_lores_img := raylib.LoadImageFromMemory(".png", raw_data(spritesheet_lores), cast(i32)len(spritesheet_lores));
	spritesheet_lores_tex := raylib.LoadTextureFromImage(spritesheet_lores_img);
	
	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing();
		bg_color := raylib.GetColor(BG_COLOR_DAY);
		raylib.ClearBackground(bg_color);
		
		trex_position: [2]f32 = {50, 50};
		trex_frame_rect: raylib.Rectangle = {sprite_coordinates_lores.trex.x,sprite_coordinates_lores.trex.y, TREX_WIDTH_NORMAL, TREX_HEIGHT_NORMAL};
		raylib.DrawTextureRec(spritesheet_lores_tex, trex_frame_rect, trex_position, raylib.WHITE);
		
		raylib.EndDrawing();
	}
}
