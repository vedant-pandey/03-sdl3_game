const sdl = @import("sdl3");
const std = @import("std");
const zm = @import("zmath");

const animation = @import("animation.zig");
const timer = @import("timer.zig");
const gameObject = @import("gameobject.zig");
const utils = @import("utils.zig");

const LevelLayerInd = 0;
const CharacterLayerInd = 1;
const MapRows = 5;
const MapCols = 50;
const TileSize = 32;

const Tile = enum {
    empty,
    ground,
    panel,
    enemy,
    player,
    grass,
    brick,
};

const AppState = struct {
    window: sdl.video.Window = undefined,
    renderer: sdl.render.Renderer = undefined,
    quit: bool = false,
    width: i32 = 0,
    height: i32 = 0,
    lWidth: usize = 0,
    lHeight: usize = 0,
    keys: []const bool = undefined,
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
    animPlayerRun: usize = 1,
    playerAnims: []animation.Animation = undefined,
    textures: []sdl.render.Texture = undefined,
    texIdle: ?sdl.render.Texture = null,
    texRun: ?sdl.render.Texture = null,
    texBrick: ?sdl.render.Texture = null,
    texGrass: ?sdl.render.Texture = null,
    texGround: ?sdl.render.Texture = null,
    texPanel: ?sdl.render.Texture = null,
    len: usize = 0,
    cap: usize,

    const Self = @This();
    pub fn loadTexture(self: *Self, state: AppState, filepath: [:0]const u8) !sdl.render.Texture {
        const tex = try sdl.image.loadTexture(state.renderer, filepath);
        self.textures[self.len] = tex;
        self.len += 1;
        tex.setScaleMode(.nearest) catch unreachable;
        return tex;
    }

    pub fn load(self: *Self, state: AppState, allocator: std.mem.Allocator) !void {
        self.textures = allocator.alloc(sdl.render.Texture, self.cap) catch unreachable;
        self.playerAnims = allocator.alloc(animation.Animation, self.cap) catch unreachable;
        self.playerAnims[self.animPlayerIdle] = animation.Animation{
            .timer = timer.Timer{ .length = 1.6 },
            .frameCount = 8,
        };
        self.playerAnims[self.animPlayerRun] = animation.Animation{
            .timer = timer.Timer{ .length = 0.5 },
            .frameCount = 4,
        };
        self.texIdle = self.loadTexture(state, "data/idle.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
        self.texRun = self.loadTexture(state, "data/run.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
        self.texBrick = self.loadTexture(state, "data/tiles/brick.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
        self.texGrass = self.loadTexture(state, "data/tiles/grass.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
        self.texGround = self.loadTexture(state, "data/tiles/ground.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
        self.texPanel = self.loadTexture(state, "data/tiles/panel.png") catch |err| {
            std.debug.print("error while loading texture {any}\n", .{err});
            return err;
        };
    }

    pub fn unload(self: *Self, allocator: std.mem.Allocator) void {
        for (self.textures[0..self.len]) |*tex| {
            tex.deinit();
        }
        allocator.free(self.textures);
        allocator.free(self.playerAnims);
    }
};

pub fn main() !void {
    var state: AppState = .{
        .width = 1521,
        .height = 1375,
        .lHeight = 320,
        .lWidth = 640,
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (!initializeGame(&state)) {
        return error.GameInitializationFailed;
    }

    defer cleanup(&state);

    state.keys = sdl.keyboard.getState();

    // Load assets
    var res: Resources = .{ .cap = 6 };
    res.load(state, allocator) catch {};
    defer res.unload(allocator);

    // Game data
    var gs: GameState = GameState.init(allocator, 10) catch {
        utils.showErrorDialog("Unable to initialize game state");
        return error.GameStateInitFailed;
    };
    try createTiles(&state, &gs, &res);

    var prevTime = sdl.c.SDL_GetTicks();
    // Game loop
    while (!state.quit) {
        const st = sdl.timer.getPerformanceCounter();
        defer {
            const en = sdl.timer.getPerformanceCounter();
            const elapsedTime = (@as(f32, @floatFromInt(en - st)) * 1000.0) / @as(f32, @floatFromInt(sdl.timer.getPerformanceFrequency()));
            const fps = @trunc(1000.0 / elapsedTime);
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

        for (gs.layers, 0..) |layer, layerInd| {
            for (layer[0..layerInd]) |*obj| {
                try update(&state, &gs, obj, &res, dt);
                if (obj.animations.len > 0) {
                    obj.animations[obj.curAnim].step(dt);
                }
            }
        }

        for (0..gs.layers.len) |layerInd| {
            for (gs.layers[layerInd][0..gs.layerLens[layerInd]]) |*obj| {
                try drawObject(&state, &gs, obj, dt);
            }
        }
    }
}

pub fn cleanup(state: *AppState) void {
    state.renderer.deinit();
    state.window.deinit();
    sdl.shutdown();
}

pub fn initializeGame(state: *AppState) bool {
    sdl.init(.{ .video = true }) catch {
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

pub fn drawObject(state: *const AppState, gs: *GameState, obj: *gameObject.GameObject, dt: f32) !void {
    const spriteSize: f32 = 32;

    _ = gs;
    _ = dt;

    const srcX: f32 = if (obj.animations.len > 0) obj.animations[obj.curAnim].currentFrame() * spriteSize else 0;

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

pub fn update(state: *AppState, gs: *GameState, obj: *gameObject.GameObject, res: *Resources, dt: f32) !void {
    if (obj.dynamic) {
        obj.velocity += zm.Vec{ 0, 500, 0, 0 } * @as(zm.Vec, @splat(dt));
    }

    switch (obj.data) {
        .player => {
            var dir: f32 = 0;
            if (state.keys[@intFromEnum(sdl.Scancode.a)]) {
                dir += -1;
            }
            if (state.keys[@intFromEnum(sdl.Scancode.d)]) {
                dir += 1;
            }
            obj.direction = dir;

            switch (obj.data.player.state) {
                .idle => {
                    if (dir != 0) {
                        obj.data.player.state = .running;
                        obj.texture = res.texRun;
                        obj.curAnim = res.animPlayerRun;
                    } else {
                        if (obj.velocity[0] != 0) {
                            const factor: f32 = if (obj.velocity[0] > 0) -1.5 else 1.5;
                            const amount = factor * obj.acceleration[0] * dt;
                            if (@abs(obj.velocity[0]) < @abs(amount)) {
                                obj.velocity[0] = 0;
                            } else {
                                obj.velocity[0] += amount;
                            }
                        }
                    }
                },

                .running => {
                    if (dir == 0) {
                        obj.data.player.state = .idle;
                        obj.texture = res.texIdle;
                        obj.curAnim = res.animPlayerIdle;
                    }
                },
                .jumping => {},
            }
            // acceleration
            obj.velocity += obj.acceleration * @as(@Vector(4, f32), @splat(dir * dt));
            if (@abs(obj.velocity[0]) > obj.maxSpeedX) {
                obj.velocity[0] = obj.maxSpeedX * dir;
            }
        },
        .level => {},
        .enemy => {},
    }
    obj.position += obj.velocity * @as(@Vector(4, f32), @splat(dt));

    for (gs.layers,0..) |layer, layerInd| {
        for (layer[0..gs.layerLens[layerInd]]) |*objB| {
            if (obj == objB) {
                continue;
            }
            checkCollision(state, gs, res, obj, objB, dt);
        }
    }
}

pub fn createTiles(state: *const AppState, gs: *GameState, res: *const Resources) !void {
    var map: [MapRows][MapCols]Tile = .{.{.empty} ** MapCols} ** MapRows;
    map[0][0] = .player;
    map[3][0] = .panel;
    map[3][1] = .panel;
    map[3][2] = .panel;
    map[3][3] = .panel;
    map[3][4] = .panel;
    map[4][0] = .ground;
    map[4][1] = .ground;
    map[4][2] = .ground;
    map[4][3] = .ground;
    map[4][4] = .ground;

    for (map, 0..) |row, i| {
        for (row, 0..) |tile, j| {
            switch (tile) {
                .player => {
                    try gs.addToLayer(CharacterLayerInd, gameObject.GameObject{
                        .texture = res.texIdle.?,
                        .animations = res.playerAnims,
                        .curAnim = res.animPlayerIdle,
                        .acceleration = zm.Vec{ 300, 0, 0, 0 },
                        .maxSpeedX = 100,
                        .data = .{ .player = .{} },
                        .position = .{
                            @as(f32, @floatFromInt(j)) * TileSize,
                            @as(f32, @floatFromInt(state.lHeight)) - @as(f32, @floatFromInt((MapRows - i) * TileSize)),
                            0,
                            0,
                        },
                        .dynamic = true,
                    });
                },
                .empty => {},
                .brick => {
                    try gs.addToLayer(LevelLayerInd, gameObject.GameObject{
                        .texture = res.texBrick,
                        .position = .{
                            @as(f32, @floatFromInt(j)) * TileSize,
                            @as(f32, @floatFromInt(state.lHeight)) - @as(f32, @floatFromInt((MapRows - i) * TileSize)),
                            0,
                            0,
                        },
                    });
                },
                .enemy => {},
                .grass => {
                    try gs.addToLayer(LevelLayerInd, gameObject.GameObject{
                        .texture = res.texGrass,
                        .position = .{
                            @as(f32, @floatFromInt(j)) * TileSize,
                            @as(f32, @floatFromInt(state.lHeight)) - @as(f32, @floatFromInt((MapRows - i) * TileSize)),
                            0,
                            0,
                        },
                    });
                },
                .ground => {
                    try gs.addToLayer(LevelLayerInd, gameObject.GameObject{
                        .texture = res.texGround,
                        .position = .{
                            @as(f32, @floatFromInt(j)) * TileSize,
                            @as(f32, @floatFromInt(state.lHeight)) - @as(f32, @floatFromInt((MapRows - i) * TileSize)),
                            0,
                            0,
                        },
                    });
                },
                .panel => {
                    try gs.addToLayer(LevelLayerInd, gameObject.GameObject{
                        .texture = res.texPanel,
                        .position = .{
                            @as(f32, @floatFromInt(j)) * TileSize,
                            @as(f32, @floatFromInt(state.lHeight)) - @as(f32, @floatFromInt((MapRows - i) * TileSize)),
                            0,
                            0,
                        },
                    });
                },
            }
        }
    }
}

pub fn checkCollision(state: *AppState, gs: *GameState, res: *Resources, f: *gameObject.GameObject, s: *gameObject.GameObject, dt: f32) void {
    const rectF = sdl.rect.FRect{
        .x = f.position[0],
        .y = f.position[1],
        .w = TileSize,
        .h = TileSize,
    };
    const rectS = sdl.rect.FRect{
        .x = s.position[0],
        .y = s.position[1],
        .w = TileSize,
        .h = TileSize,
    };
    const overlap = sdl.rect.FRect.getIntersection(rectF, rectS);
    if (overlap != null) {
        resolveCollision(state, gs, res, f, s, &rectF, &rectS, &overlap.?, dt);
    }
}

pub fn resolveCollision(state: *AppState, gs: *GameState, res: *Resources, f: *gameObject.GameObject, s: *gameObject.GameObject, rectF: *const sdl.rect.FRect, rectS: *const sdl.rect.FRect, overlap: *const sdl.rect.FRect, dt: f32) void {
    _ = state;
    _ = gs;
    _ = res;
    _ = dt;
    _ = rectF;
    _ = rectS;

    switch (f.data) {
        .player => {
            switch (s.data) {
                .level => {
                    if (overlap.w < overlap.h) {
                        if (f.velocity[0] > 0) {
                            f.position[0] -= overlap.w;
                        } else if (f.velocity[0] < 0) {
                            f.position[0] += overlap.w;
                        }
                    } else {
                        if (f.velocity[1] > 0) {
                            f.position[1] -= overlap.h;
                        } else if (f.velocity[1] < 0) {
                            f.position[1] += overlap.h;
                        }
                    }
                },
                else => unreachable,
            }
        },
        else => {},
    }
}
