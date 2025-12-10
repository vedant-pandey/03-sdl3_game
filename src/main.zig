const sdl = @import("sdl3");
const std = @import("std");
const animation = @import("animation.zig");
const timer = @import("timer.zig");
const gameObject = @import("gameobject.zig");
const utils = @import("utils.zig");

const LevelLayerInd = 0;
const CharacterLayerInd = 1;

const SdlState = struct {
    window: sdl.video.Window = undefined,
    renderer: sdl.render.Renderer = undefined,
    quit: bool = false,
    width: i32 = 0,
    height: i32 = 0,
    lWidth: i32 = 0,
    lHeight: i32 = 0,
};

const GameState = struct {
    layers: [2][]gameObject.GameObject = undefined,
    layerLens: [2]usize = .{0} ** 2,
    cap: usize = 0,
    playerInd: usize = 0,

    pub fn init(allocator: std.mem.Allocator, nums: usize) !GameState {
        return GameState{
            .layers = .{
                try allocator.alloc(gameObject.GameObject, nums),
                try allocator.alloc(gameObject.GameObject, nums),
            },
            .cap = nums,
        };
    }

    pub fn addToLayer(self: *@This(), layerInd: usize, obj: gameObject.GameObject) !void {
        const len = self.layerLens[layerInd];
        if (len == self.cap) {
            return error.LayerSizeOverFlow;
        }
        self.layers[layerInd][len] = obj;
        self.layerLens[layerInd] = len + 1;
    }
};

const Resources = struct {
    animPlayerIdle: usize = 0,
    playerAnims: []animation.Animation = undefined,
    textures: []sdl.render.Texture = undefined,
    texIdle: ?sdl.render.Texture = null,
    len: usize = 0,
    cap: usize,

    const Self = @This();
    pub fn loadTexture(self: *Self, state: SdlState, filepath: [:0]const u8) !sdl.render.Texture {
        const tex = try sdl.image.loadTexture(state.renderer, filepath);
        self.textures[self.len] = tex;
        self.len += 1;
        tex.setScaleMode(.nearest) catch unreachable;
        return tex;
    }

    pub fn load(self: *Self, state: SdlState, allocator: std.mem.Allocator) !void {
        self.textures = allocator.alloc(sdl.render.Texture, self.cap) catch unreachable;
        self.playerAnims = allocator.alloc(animation.Animation, self.cap) catch unreachable;
        self.playerAnims[self.animPlayerIdle] = animation.Animation{
            .timer = timer.Timer{ .length = 1.8 },
            .frameCount = 8,
        };
        self.texIdle = self.loadTexture(state, "data/idle.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
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
    var state: SdlState = .{
        .width = 1521,
        .height = 1375,
        .lHeight = 320,
        .lWidth = 640,
    };

    defer sdl.shutdown();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (!initializeGame(&state)) {
        return error.GameInitializationFailed;
    }

    defer cleanup(&state);

    // Game data
    // const keyStates = sdl.keyboard.getState();

    // Load assets
    var res: Resources = .{ .cap = 5 };
    res.load(state, allocator) catch {};
    defer res.unload(allocator);

    // Game data
    var gs: GameState = GameState.init(allocator, 10) catch {
        utils.showErrorDialog("Unable to initialize game state");
        return error.GameStateInitFailed;
    };
    var player: gameObject.GameObject = .{
        .type = .player,
        .texture = res.texIdle.?,
        .animations = res.playerAnims,
        .curAnim = res.animPlayerIdle,
    };

    try gs.addToLayer(CharacterLayerInd, player);

    _ = &player;
    _ = &gs;

    var prevTime = sdl.c.SDL_GetTicks();
    // Game loop
    while (!state.quit) {
        const st = sdl.timer.getPerformanceCounter();
        defer {
            const en = sdl.timer.getPerformanceCounter();
            const elapsedTime = (@as(f32, @floatFromInt(en - st)) * 1000.0) / @as(f32, @floatFromInt(sdl.timer.getPerformanceFrequency()));
            const fps = 1000.0 / elapsedTime;
            std.debug.print("FPS {}\n", .{fps});
        }
        const nowTime = sdl.c.SDL_GetTicks();
        const dt: f32 = @as(f32, @floatFromInt(nowTime - prevTime)) / 1000.0;
        prevTime = nowTime;

        while (sdl.events.poll()) |event| {
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

        for (0..gs.layers.len) |layerInd| {
            for (0..gs.layerLens[layerInd]) |oInd| {
                const obj = &gs.layers[layerInd][oInd];
                var anim = &obj.animations[obj.curAnim];
                anim.step(dt);
            }
        }

        for (0..gs.layers.len) |layerInd| {
            for (0..gs.layerLens[layerInd]) |oInd| {
                const obj = &gs.layers[layerInd][oInd];
                try drawObject(&state, &gs, obj, dt);
            }
        }
    }
}

const init_flags = sdl.InitFlags{ .video = true };
pub fn cleanup(state: *SdlState) void {
    defer sdl.quit(init_flags);
    state.window.deinit();
    state.renderer.deinit();
}

pub fn initializeGame(state: *SdlState) bool {
    sdl.init(init_flags) catch {
        utils.showErrorDialog("Error initializing SDL");
        return false;
    };

    var window = sdl.video.Window.init("Hello SDL3", @intCast(state.width), @intCast(state.height), .{ .always_on_top = true }) catch {
        utils.showErrorDialog("Error creating window");
        return false;
    };

    var renderer = sdl.render.Renderer.init(window, null) catch {
        utils.showErrorDialog("Error creating renderer");
        window.deinit();
        return false;
    };

    state.window = window;
    state.renderer = renderer;

    state.window.raise() catch {
        utils.showErrorDialog("Error raising window");
        window.deinit();
        renderer.deinit();
        return false;
    };

    const displays = sdl.video.getDisplays() catch unreachable;
    if (displays.len > 1) {
        const display2 = displays[1].getBounds() catch unreachable;
        state.window.setPosition(.{ .absolute = display2.x }, .{ .absolute = display2.y }) catch unreachable;
    }

    state.window.setResizable(true) catch unreachable;
    state.renderer.setLogicalPresentation(@intCast(state.lWidth), @intCast(state.lHeight), .letter_box) catch {
        utils.showErrorDialog("Error unable to set logical presentation");
        return false;
    };

    return true;
}

pub fn drawObject(state: *const SdlState, gs: *GameState, obj: *gameObject.GameObject, dt: f32) !void {
    const spriteSize: f32 = 32;

    _ = gs;
    _ = dt;

    const srcX: f32 = obj.animations[obj.curAnim].currentFrame() * spriteSize;

    const src = sdl.rect.FRect{
        .x = srcX,
        .y = 0,
        .w = spriteSize,
        .h = spriteSize,
    };
    const dst = sdl.rect.FRect{
        .x = obj.position[0],
        .y = obj.position[1],
        .w = spriteSize,
        .h = spriteSize,
    };

    try state.renderer.renderTextureRotated(obj.texture.?, src, dst, 0, null, .{ .horizontal = obj.direction == -1 });
}
