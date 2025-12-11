const sdl3 = @import("sdl3");
const zm = @import("zmath");
const animation = @import("animation.zig");

pub const ObjectType = enum {
    player,
    level,
    enemy,
};

pub const GameObject = struct {
    data: ObjectData = .{ .level = .{} },
    maxSpeedX: f32 = 0,
    position: zm.Vec = zm.Vec{0,0,0,0},
    velocity: zm.Vec = zm.Vec{0,0,0,0},
    acceleration:zm.Vec = zm.Vec{0,0,0,0},
    direction: f32 = 1,
    animations: []animation.Animation = undefined,
    curAnim: usize = 0,
    texture: ?sdl3.render.Texture = null,
};

pub const PlayerState = enum {
    idle,
    running,
    jumping,
};

pub const PlayerData = struct {
    state: PlayerState = .idle,
};

pub const LevelData = struct {
};

pub const EnemyData = struct {
};

pub const ObjectData = union(ObjectType) {
    player: PlayerData,
    level: LevelData,
    enemy: EnemyData,
};
