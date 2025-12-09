const sdl3 = @import("sdl3");
const std = @import("std");

const fps = 60;

const SDLState = struct {
    window: *sdl3.video.Window,
    renderer: *sdl3.render.Renderer,
};

pub fn main() !void {
    const screen_width = 640;
    const screen_height = 480;
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    var window = sdl3.video.Window.init("Hello SDL3", screen_width, screen_height, .{ .always_on_top = true }) catch {
        try sdl3.message_box.showSimple(.{ .error_dialog = true }, "Error", "Error creating window", null);
        return error.SDLWindowInitFailed;
    };
    defer window.deinit();

    var renderer = sdl3.render.Renderer.init(window, null) catch {
        try sdl3.message_box.showSimple(.{ .error_dialog = true }, "Error", "Error creating window", null);
        return error.SDLWindowInitFailed;
    };
    defer renderer.deinit();
    var state: SDLState = .{
        .window = &window,
        .renderer = &renderer,
    };

    var fps_capper = sdl3.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    var quit = false;
    _ = &quit;
    while (!quit) {
        const dt = fps_capper.delay();
        _ = dt;

        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                .key_down => {
                    if (event.key_down.key.? == .q) {
                        quit = true;
                    }
                },
                else => {},
            }
        }

        // 128, 30, 255
        try state.renderer.setDrawColor(.{ .r = 128, .g = 30, .b = 255, .a = 255 });
        try state.renderer.clear();
        try state.renderer.present();
    }
}
