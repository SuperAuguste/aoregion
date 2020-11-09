const region = @import("region.zig");

comptime {
    @import("std").testing.refAllDecls(@This());
}
