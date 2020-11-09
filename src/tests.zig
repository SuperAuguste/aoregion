const region = @import("region/region.zig");

comptime {
    @import("std").testing.refAllDecls(@This());
}
