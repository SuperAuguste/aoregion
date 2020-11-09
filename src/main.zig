const std = @import("std");
const region = @import("region/region.zig");

pub fn _main() !void {
    var allocator = std.heap.page_allocator;
    var stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("regionInfo.dat", .{ .read = true });
    defer file.close();

    var r = region.RegionFileReader(@TypeOf(file.reader())).init(file.reader());
    var header = try r.readHeader(allocator);
    defer r.freeHeader(allocator, header);

    try stdout.print(
        \\
        \\|  Region Name         |  {}
        \\|  Matchmaker Address  |  {}
        \\|  Server Count        |  {d}
        \\   Servers:
        \\
    , .{ header.name, header.ip, header.server_count });

    var i: u8 = 0;
    while (i < header.server_count) : (i += 1) {
        var info = try r.readServerInfo(allocator);
        try stdout.print(" " ** 4 ++ "- {}, {}:{}\n", .{info.name, info.ip, info.port});
        r.freeServerInfo(allocator, info);
    }

    // var file = try std.fs.cwd().openFile("regionInfo.dat", .{ .write = true });
    // defer file.close();

    // try file.seekTo(0);
    // try file.setEndPos(0);

    // var w = region.RegionFileWriter(@TypeOf(file.writer())).init(file.writer());
    // try w.writeHeader(.{
    //     .name = "Andrew turned 32 hooray!",
    //     .ip = "192.168.0.191",
    //     .server_count = 1
    // });
    // try w.writeServerInfo(.{
    //     .name = "zsevenwoohoo-Master-1",
    //     .ip = "192.168.0.191",
    //     .port = 22023
    // });
}

pub export fn _start() noreturn {
    _main() catch |err| std.log.err("{}\n", .{err});
    std.process.exit(0);
}

pub export fn WinMainCRTStartup() callconv(.Stdcall) noreturn {
    @setAlignStack(16);

    std.debug.maybeEnableSegfaultHandler();
    _main() catch |err| std.log.err("{}\n", .{err});
    std.process.exit(0);
}
