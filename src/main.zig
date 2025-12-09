const sdl3 = @import("sdl3");
const std = @import("std");

const fps = 60;

const GameState = struct {
    window: *sdl3.video.Window,
    renderer: *sdl3.render.Renderer,
    quit: bool = false,
};

pub fn main() !void {
    var screenWidth: i32 = 1521;
    var screenHeight: i32 = 1375;

    defer sdl3.shutdown();

    // Initial config Start
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var window = sdl3.video.Window.init("Hello SDL3", @intCast(screenWidth), @intCast(screenHeight), .{ .always_on_top = true }) catch {
        try sdl3.message_box.showSimple(.{ .error_dialog = true }, "Error", "Error creating window", null);
        return error.SDLWindowInitFailed;
    };
    defer window.deinit();

    var renderer = sdl3.render.Renderer.init(window, null) catch {
        try sdl3.message_box.showSimple(.{ .error_dialog = true }, "Error", "Error creating window", null);
        return error.SDLWindowInitFailed;
    };
    defer renderer.deinit();
    var state: GameState = .{
        .window = &window,
        .renderer = &renderer,
    };

    try state.window.raise();
    const displays = try sdl3.video.getDisplays();
    if (displays.len > 1) {
        const display2 = try displays[1].getBounds();
        try state.window.setPosition(.{ .absolute = display2.x }, .{ .absolute = display2.y });
    }
    // Initial config End

    // Configuration
    const lWidth = 640;
    const lHeight = 320;
    state.window.setResizable(true) catch unreachable;
    try state.renderer.setLogicalPresentation(lWidth, lHeight, .letter_box);

    // Load assets
    const idleTex = try sdl3.image.loadTexture(state.renderer.*, "data/idle.png");
    defer idleTex.deinit();

    try idleTex.setScaleMode(.nearest);

    // Game loop
    while (!state.quit) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit => state.quit = true,
                .terminating => state.quit = true,
                .key_down => {
                    if (event.key_down.key.? == .q) {
                        state.quit = true;
                    }
                },
                .window_resized => {
                    screenWidth = event.window_resized.width;
                    screenHeight = event.window_resized.height;
                },
                else => {},
            }
        }

        state.renderer.setDrawColor(.{ .r = 128, .g = 30, .b = 255, .a = 255 }) catch unreachable;
        state.renderer.clear() catch unreachable;
        defer state.renderer.present() catch unreachable;

        const src = sdl3.rect.FRect{
            .x = 0,
            .y = 0,
            .w = 32,
            .h = 32,
        };
        const dst = sdl3.rect.FRect{
            .x = 0,
            .y = 0,
            .w = 32,
            .h = 32,
        };
        try state.renderer.renderTexture(idleTex, src, dst);
    }
}
