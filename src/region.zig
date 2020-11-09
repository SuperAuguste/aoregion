const std = @import("std");

pub const RegionHeader = struct {
    name: []const u8,
    ip: []const u8,
    server_count: u8
};

pub const ServerInfo = struct {
    name: []const u8,
    ip: []const u8,
    port: u16
};

fn ipTou32(ip: []const u8) !u32 {
    var components: [4]u8 = undefined;
    var split = std.mem.split(ip, ".");

    var i: usize = 0;
    while (split.next()) |num| {
        components[i] = try std.fmt.parseInt(u8, num, 10);
        i += 1;
    }

    return std.mem.bytesAsSlice(u32, &components)[0];
}

pub fn RegionFileReader(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        reader: ReaderType,

        pub fn init(reader: ReaderType) Self {
            return Self{
                .reader = reader
            };
        }

        /// Caller must free returned memory.
        pub fn readString(self: Self, allocator: *std.mem.Allocator) ![]const u8 {
            var string = try allocator.alloc(u8, try self.reader.readInt(u8, std.builtin.Endian.Little));
            _ = try self.reader.read(string);
            return string;
        }

        /// Caller must free returned memory with `freeHeader`.
        pub fn readHeader(self: Self, allocator: *std.mem.Allocator) !RegionHeader {
            var i: usize = 0;
            while (i < 4) : (i += 1) _ = try self.reader.readByte();

            var name = try self.readString(allocator);
            var ip = try self.readString(allocator);
            var server_count = try self.reader.readInt(u8, std.builtin.Endian.Little);

            i = 0;
            while (i < 3) : (i += 1) _ = try self.reader.readByte();

            return RegionHeader{
                .name = name,
                .ip = ip,
                .server_count = server_count
            };
        }

        pub fn freeHeader(self: Self, allocator: *std.mem.Allocator, header: RegionHeader) void {
            allocator.free(header.ip);
            allocator.free(header.name);
        }

        /// Caller must free returned memory with `freeServerInfo`.
        pub fn readServerInfo(self: Self, allocator: *std.mem.Allocator) !ServerInfo {
            var name = try self.readString(allocator);
            var ip = try self.reader.readInt(u32, std.builtin.Endian.Little);
            var port = try self.reader.readInt(u16, std.builtin.Endian.Little);

            var i: usize = 0;
            while (i < 4) : (i += 1) _ = try self.reader.readByte();

            var components = std.mem.sliceAsBytes(&[1]u32{ip});

            return ServerInfo{
                .name = name,
                .ip = try std.fmt.allocPrint(allocator, "{}.{}.{}.{}", .{components[0], components[1], components[2], components[3]}),
                .port = port
            };
        }

        pub fn freeServerInfo(self: Self, allocator: *std.mem.Allocator, info: ServerInfo) void {
            allocator.free(info.name);
            allocator.free(info.ip);
        }
    };
}

pub fn RegionFileWriter(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        writer: WriterType,

        pub fn init(writer: WriterType) Self {
            return Self{
                .writer = writer
            };
        }

        pub fn writeString(self: Self, string: []const u8) !void {
            try self.writer.writeInt(u8, @intCast(u8, string.len), std.builtin.Endian.Little);
            _ = try self.writer.write(string);
        }

        pub fn writeHeader(self: Self, header: RegionHeader) !void {
            var i: usize = 0;
            while (i < 4) : (i += 1) _ = try self.writer.writeByte(0);

            try self.writeString(header.name);
            try self.writeString(header.ip);
            try self.writer.writeInt(u8, header.server_count, std.builtin.Endian.Little);

            i = 0;
            while (i < 3) : (i += 1) _ = try self.writer.writeByte(0);
        }

        pub fn writeServerInfo(self: Self, header: ServerInfo) !void {
            try self.writeString(header.name);
            _ = try self.writer.writeInt(u32, try ipTou32(header.ip), std.builtin.Endian.Little);
            _ = try self.writer.writeInt(u16, header.port, std.builtin.Endian.Little);

            var i: usize = 0;
            while (i < 4) : (i += 1) _ = try self.writer.writeByte(0);
        }
    };
}

test "Read/Write Region Data File" {
    const allocator = std.testing.allocator;

    const test_in = @embedFile("test.dat");
    var test_out: [test_in.len]u8 = undefined;

    var test_reader = std.io.fixedBufferStream(test_in).reader();
    var region_reader = RegionFileReader(@TypeOf(test_reader)).init(test_reader);

    var test_writer = std.io.fixedBufferStream(&test_out).writer();
    var region_writer = RegionFileWriter(@TypeOf(test_writer)).init(test_writer);

    var header = try region_reader.readHeader(allocator);
    defer region_reader.freeHeader(allocator, header);
    try region_writer.writeHeader(header);

    var index: usize = 0;
    while (index < header.server_count) : (index += 1) {
        var info = try region_reader.readServerInfo(allocator);
        try region_writer.writeServerInfo(info);
        region_reader.freeServerInfo(allocator, info);
    }

    std.testing.expectEqualSlices(u8, test_in, &test_out);
}
