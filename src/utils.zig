const sdl = @import("sdl3");

pub fn showErrorDialog(message: [:0]const u8) void {
    sdl.message_box.showSimple(.{ .error_dialog = true }, "Error", message, null) catch unreachable;
}
