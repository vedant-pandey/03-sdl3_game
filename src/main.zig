const sdl3 = @import("sdl3");
const std = @import("std");

const fps = 60;

const Timer = struct {
    length: f32,
    time: f32 = 0,
    timeout: bool = false,

    const Self = @This();

    pub fn step(self: *Self, dt: f32) void {
        self.time += dt;
        if (self.time >= self.length) {
            self.time -= self.length;
            self.timeout = true;
        }
    }

    pub fn reset(self: *Self) void {
        self.time = 0;
    }
};

const Animation = struct {
    timer: Timer,
    frameCount: i32 = 0,

    pub fn currentFrame(self: *const @This()) i32 {
        return @intFromFloat((self.timer.time / self.timer.length) * @as(f32, @floatFromInt(self.frameCount)));
    }
};

const GameState = struct {
    window: sdl3.video.Window = undefined,
    renderer: sdl3.render.Renderer = undefined,
    quit: bool = false,
    width: i32 = 0,
    height: i32 = 0,
    lWidth: i32 = 0,
    lHeight: i32 = 0,
};

const Resources = struct {
    animPlayerIdle: usize = 0,
    playerAnims: []Animation = undefined,
    textures: []sdl3.render.Texture = undefined,
    texIdle: *sdl3.render.Texture = undefined,
    len: usize = 0,
    cap: usize,

    const Self = @This();
    pub fn loadTexture(self: *Self, state: GameState, filepath: [:0]const u8) !sdl3.render.Texture {
        const tex = try sdl3.image.loadTexture(state.renderer, filepath);
        self.textures[self.len] = tex;
        self.len += 1;
        tex.setScaleMode(.nearest) catch unreachable;
        return tex;
    }

    pub fn load(self: *Self, state: GameState, allocator: std.mem.Allocator) !void {
        self.textures = allocator.alloc(sdl3.render.Texture, self.cap) catch unreachable;
        self.playerAnims = allocator.alloc(Animation, self.cap) catch unreachable;
        self.playerAnims[self.animPlayerIdle] = Animation{
            .timer = Timer{ .length = 8, .time = 1.8 },
        };
        self.texIdle.* = try self.loadTexture(state, "data/idle.png");
    }

    pub fn unload(self: *Self, allocator: std.mem.Allocator) void {
        for (self.textures) |*tex| {
            tex.deinit();
        }
        allocator.free(self.textures);
        allocator.free(self.playerAnims);
    }
};

pub fn main() !void {
    var state: GameState = .{
        .width = 1521,
        .height = 1375,
        .lHeight = 320,
        .lWidth = 640,
    };

    defer sdl3.shutdown();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (!initializeGame(&state)) {
        return error.GameInitializationFailed;
    }

    defer cleanup(&state);

    // Configuration
    state.window.setResizable(true) catch unreachable;
    state.renderer.setLogicalPresentation(@intCast(state.lWidth), @intCast(state.lHeight), .letter_box) catch |err| {
        std.debug.print("Error {}\n", .{err});
        return err;
    };

    // Game data
    const keyStates = sdl3.keyboard.getState();
    var playerX: f32 = 15.0;
    const floor: f32 = @floatFromInt(state.lHeight);

    // Load assets
    var res: Resources = .{ .cap = 5 };
    res.load(state, allocator) catch {};
    defer res.unload(allocator);

    var prevTime = sdl3.c.SDL_GetTicks();

    var flipHorizontal = false;

    // Game loop
    while (!state.quit) {
        const nowTime = sdl3.c.SDL_GetTicks();
        const dt: f32 = @as(f32, @floatFromInt(nowTime - prevTime)) / 1000.0;
        prevTime = nowTime;

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
                    state.width = event.window_resized.width;
                    state.height = event.window_resized.height;
                },
                else => {},
            }
        }

        state.renderer.setDrawColor(.{ .r = 128, .g = 30, .b = 255, .a = 255 }) catch unreachable;
        state.renderer.clear() catch unreachable;
        defer state.renderer.present() catch unreachable;

        const spriteSize = 32;

        const src = sdl3.rect.FRect{
            .x = 0,
            .y = 0,
            .w = spriteSize,
            .h = spriteSize,
        };
        const dst = sdl3.rect.FRect{
            .x = playerX,
            .y = floor - spriteSize,
            .w = spriteSize,
            .h = spriteSize,
        };

        var movement: f32 = 0;
        if (keyStates[@intFromEnum(sdl3.Scancode.a)]) {
            movement += -75.0;
            flipHorizontal = true;
        }
        if (keyStates[@intFromEnum(sdl3.Scancode.d)]) {
            movement += 75.0;
            flipHorizontal = false;
        }
        playerX += movement * dt;

        try state.renderer.renderTextureRotated(res.texIdle.*, src, dst, 0, null, .{ .horizontal = flipHorizontal });
    }
}

const init_flags = sdl3.InitFlags{ .video = true };
pub fn cleanup(state: *GameState) void {
    defer sdl3.quit(init_flags);
    state.window.deinit();
    state.renderer.deinit();
}

pub fn initializeGame(state: *GameState) bool {
    sdl3.init(init_flags) catch {
        showErrorDialog("Error initializing SDL");
        return false;
    };

    var window = sdl3.video.Window.init("Hello SDL3", @intCast(state.width), @intCast(state.height), .{ .always_on_top = true }) catch {
        showErrorDialog("Error creating window");
        return false;
    };

    var renderer = sdl3.render.Renderer.init(window, null) catch {
        showErrorDialog("Error creating renderer");
        window.deinit();
        return false;
    };

    state.window = window;
    state.renderer = renderer;

    state.window.raise() catch {
        showErrorDialog("Error raising window");
        window.deinit();
        renderer.deinit();
        return false;
    };

    const displays = sdl3.video.getDisplays() catch unreachable;
    if (displays.len > 1) {
        const display2 = displays[1].getBounds() catch unreachable;
        state.window.setPosition(.{ .absolute = display2.x }, .{ .absolute = display2.y }) catch unreachable;
    }
    return true;
}

pub fn showErrorDialog(message: [:0]const u8) void {
    sdl3.message_box.showSimple(.{ .error_dialog = true }, "Error", message, null) catch unreachable;
}
