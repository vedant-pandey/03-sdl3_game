const sdl3 = @import("sdl3");
const animation = @import("animation.zig");
const zm = @import("zmath");

pub const ObjectType = enum {
    player,
    level,
    enemy,
};

pub const GameObject = struct {
    type: ObjectType = .level,
    position: zm.Vec = zm.Vec{0,0,0,0},
    animation: zm.Vec = zm.Vec{0,0,0,0},
    acceleration:zm.Vec = zm.Vec{0,0,0,0},
    direction: f32 = 1,
    animations: []animation.Animation = undefined,
    curAnim: usize = 0,
    texture: ?sdl3.render.Texture = null,
};
