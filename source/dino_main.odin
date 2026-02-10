package dino

import "vendor:raylib"

DEFAULT_WINDOW_W :: 600
DEFAULT_WINDOW_H :: 150

spritesheet_lores := #load("../assets/offline-sprite-1x.png")
spritesheet_hires := #load("../assets/offline-sprite-2x.png")

main :: proc() {
	raylib.SetTraceLogLevel(.ERROR);
	raylib.InitWindow(DEFAULT_WINDOW_W, DEFAULT_WINDOW_H, "A window");
	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL);
	raylib.SetTargetFPS(60);
	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing();
		raylib.ClearBackground(raylib.RAYWHITE);
		raylib.EndDrawing();
	}
}
