const std = @import("std");

// 蜡烛线
pub const Bar = struct {
    // 时间
    time: i64,
    // 开盘价
    open: f32,
    // 最高价
    high: f32,
    // 最低价
    low: f32,
    // 收盘价
    close: f32,
    // 交易量
    volume: f32,
};

const COMMON_BATCH_SIZE: u8 = 100;

pub fn parseCsv(allocator: std.mem.Allocator, content: []const u8) ![]Bar{
    var list = try std.ArrayList(Bar).initCapacity(
        allocator,
        COMMON_BATCH_SIZE
    );

    errdefer list.deinit(allocator);

    // 按行切分
    var lines = std.mem
        .tokenizeAny(u8, content, "\n");

    while (lines.next()) |line| {
        const trimmed = std.mem
            .trim(u8, line, " ");
        if (trimmed.len == 0) {
            continue;
        }

        var iter = std.mem
            .splitScalar(u8, trimmed, ',');

        const bar = Bar {
            .time = try parseNext(i64, &iter),
            .open = try parseNext(f32, &iter),
            .high = try parseNext(f32, &iter),
            .low = try parseNext(f32, &iter),
            .close = try parseNext(f32, &iter),
            .volume = try parseNext(f32, &iter),
        };

        try list.append(allocator, bar);
    }

    return list.toOwnedSlice(allocator);
}

fn parseNext(comptime T: type, iter: *std.mem.SplitIterator(u8, .scalar)) !T {
    const raw = iter.next()
        orelse return error.MissingColumn;
    const clean = std.mem
        .trim(u8, raw, " ");

    return switch (@typeInfo(T)) {
        .int => try std.fmt.parseInt(T, clean, 10),
        .float => try std.fmt.parseFloat(T, clean),
        else => @compileError("不支持的类型"),
    };
}

