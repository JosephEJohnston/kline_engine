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

const BarIndex = struct {
    const time: usize = 1;
    const open: usize = 2;
    const high: usize = 3;
    const low: usize = 4;
    const close: usize = 5;
    const volume: usize = 6;
};

const COMMON_BATCH_SIZE: u8 = 100;

// 导出解析函数：返回解析后的 Bar 数组指针
// 注意：为了简单，我们把长度存给一个全局变量或通过指针返回
var last_parse_count: usize = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena = std.heap.ArenaAllocator.init(gpa.allocator());
const totalAllocator = arena.allocator();

// 导出分配函数：让 JS 知道去哪里申请内存放 CSV 字符串
export fn alloc_memory(len: usize) [*]u8 {
    const slice = totalAllocator.alloc(u8, len) catch @panic("OOM");
    return slice.ptr;
}

export fn free_memory() void {
    _ = arena.reset(.free_all);
}

export fn parse_csv_wasm(ptr: [*]const u8, len: usize) [*]Bar {
    const content = ptr[0..len];

    const bars = parseCsv(totalAllocator, content) catch @panic("Parse Error");

    last_parse_count = bars.len;
    return bars.ptr;
}

export fn get_last_parse_count() usize {
    return last_parse_count;
}

pub fn parseCsv(allocator: std.mem.Allocator, content: []const u8) ![]Bar {
    var list = try std.ArrayList(Bar).initCapacity(allocator, COMMON_BATCH_SIZE);

    errdefer list.deinit(allocator);

    // 按行切分
    var lines = std.mem
        .tokenizeAny(u8, content, "\n");

    // 去除标头
    _ = lines.next();

    while (lines.next()) |line| {
        const trimmed = std.mem
            .trim(u8, line, " ");
        if (trimmed.len == 0) {
            continue;
        }

        var iter = std.mem
            .splitScalar(u8, trimmed, ',');

        var columns = [_][]const u8{""} ** 20;

        var i: u8 = 0;
        while (iter.next()) |item| {
            if (i >= columns.len) {
                break;
            }
            columns[i] = item;
            i += 1;
        }

        const bar = Bar{
            .time = try parseDateTimeToUnix(columns[BarIndex.time]),
            .open = try std.fmt.parseFloat(f32, columns[BarIndex.open]),
            .high = try std.fmt.parseFloat(f32, columns[BarIndex.high]),
            .low = try std.fmt.parseFloat(f32, columns[BarIndex.low]),
            .close = try std.fmt.parseFloat(f32, columns[BarIndex.close]),
            .volume = try std.fmt.parseFloat(f32, columns[BarIndex.volume]),
        };

        try list.append(allocator, bar);
    }

    return list.toOwnedSlice(allocator);
}

pub fn parseDateTimeToUnix(s: []const u8) !i64 {
    // 基本长度校验
    if (s.len < 19) return error.InvalidFormat;

    // 1. 提取数字 (极其快速，因为下标是固定的)
    const year = try std.fmt.parseInt(i32, s[0..4], 10);
    const month = try std.fmt.parseInt(i32, s[5..7], 10);
    const day = try std.fmt.parseInt(i32, s[8..10], 10);
    const hour = try std.fmt.parseInt(i64, s[11..13], 10);
    const min = try std.fmt.parseInt(i64, s[14..16], 10);
    const sec = try std.fmt.parseInt(i64, s[17..19], 10);

    // 2. 计算日期部分的 Unix Days
    // 这个算法来自 http://howardhinnant.github.io/date_algorithms.html
    const y: i32 = year - @intFromBool(month <= 2);
    const m: u32 = if (month > 2) @intCast(month - 3) else @intCast(month + 9);
    const era = @divFloor(y, 400);
    const yoe = @as(u32, @intCast(y - era * 400));
    const doy = (153 * m + 2) / 5 + @as(u32, @intCast(day)) - 1;
    const doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    const days = era * 146097 + @as(i64, @intCast(doe)) - 719468;

    // 3. 组合成秒
    return days * 86400 + hour * 3600 + min * 60 + sec;
}
