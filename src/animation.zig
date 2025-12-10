const timer = @import("timer.zig");
pub const Animation = struct {
    timer: timer.Timer,
    frameCount: i32,
    const Self = @This();

    pub fn currentFrame(self: *Self) f32 {
        return @floor((self.timer.time / self.timer.length) * @as(f32, @floatFromInt(self.frameCount)));
    }

    pub inline fn step(self: *Self, dt: f32) void {
        self.timer.step(dt);
    }
};
