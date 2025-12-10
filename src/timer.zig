pub const Timer = struct {
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
