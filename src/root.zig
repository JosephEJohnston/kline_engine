const std = @import("std");
const builtin = @import("builtin");

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
    ema20: f32,
};

// 编译时检查，确保万无一失
comptime {
    if (@sizeOf(Bar) != 32) @compileError("Bar size must be 32 bytes!");
}

// 6 个字段 * 4 字节 = 24 字节的固定内存块
pub const ParseConfig = extern struct {
    time_idx: i32 = -1,
    open_idx: i32 = -1,
    high_idx: i32 = -1,
    low_idx: i32 = -1,
    close_idx: i32 = -1,
    volume_idx: i32 = -1,
};

const COMMON_BATCH_SIZE: u8 = 100;

// 导出解析函数：返回解析后的 Bar 数组指针
// 注意：为了简单，我们把长度存给一个全局变量或通过指针返回
var last_parse_count: usize = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena = std.heap.ArenaAllocator.init(gpa.allocator());
const totalAllocator = arena.allocator();

// 告诉 Zig：这个函数的实现在 JS 那头
// 只有在目标是 WASM 时才声明 extern 函数
const js_log_err = if (builtin.target.cpu.arch == .wasm32)
    struct { extern fn js_log_err(ptr: [*]const u8, len: usize) void; }.js_log_err
else null;

// 写一个包装函数，方便调用
fn logDebug(comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode == .Debug) {
        if (builtin.target.cpu.arch == .wasm32) {
            // 如果是 WASM，调用 JS 函数
        if (js_log_err) {
                var buf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
                js_log_err(msg.ptr, msg.len);
            }
        } else {
            // 如果是本地 Native 环境，直接打印到终端
        std.debug.print(fmt, args);
            std.debug.print("\n", .{});
        }
    }
}

// 导出分配函数：让 JS 知道去哪里申请内存放 CSV 字符串
export fn alloc_memory(len: usize) [*]u8 {
    const slice = totalAllocator.alloc(u8, len) catch @panic("OOM");
    return slice.ptr;
}

export fn free_memory() void {
    _ = arena.reset(.free_all);
}

export fn parse_csv_wasm(
    ptr: [*]const u8,
    len: usize,
    time_idx: i32,   // 直接接收参数，不要包在 struct 里
    open_idx: i32,
    high_idx: i32,
    low_idx: i32,
    close_idx: i32,
    volume_idx: i32
) [*]Bar {
    const content = ptr[0..len];

    const config = ParseConfig{
        .time_idx = time_idx,
        .open_idx = open_idx,
        .high_idx = high_idx,
        .low_idx = low_idx,
        .close_idx = close_idx,
        .volume_idx = volume_idx,
    };

    const bars = parseCsv(totalAllocator, content, config)
        catch @panic("Check console for error name");

    last_parse_count = bars.len;
    return bars.ptr;
}

export fn get_last_parse_count() usize {
    return last_parse_count;
}

pub fn parseCsv(
    allocator: std.mem.Allocator,
    content: []const u8,
    config: ParseConfig
) ![]Bar {
    var list = try std.ArrayList(Bar).initCapacity(allocator, COMMON_BATCH_SIZE);

    errdefer list.deinit(allocator);

    // 按行切分
    var lines = std.mem
        .tokenizeAny(u8, content, "\n");

    // 去除标头
    _ = lines.next();

    while (lines.next()) |line| {
        const trimmed = std.mem
            .trim(u8, line, " \t\r\n");
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
            logDebug("Parsing column item, item : {s}, index : {d} .", .{item, i});

            i += 1;
        }

        logDebug("Parsing column, column : {s} .", .{line});

        const bar = Bar{
            // 时间处理：如果索引有效则解析，否则设为 0
            .time = if (config.time_idx >= 0)
                try parseDateTimeToUnix(columns[@intCast(config.time_idx)])
            else 0,
            .open   = try parseOptionalFloat(&columns, config.open_idx),
            .high   = try parseOptionalFloat(&columns, config.high_idx),
            .low    = try parseOptionalFloat(&columns, config.low_idx),
            .close  = try parseOptionalFloat(&columns, config.close_idx),
            .volume = try parseOptionalFloat(&columns, config.volume_idx),
        };

        logDebug("Line parsed successfully.", .{});

        try list.append(allocator, bar);
    }

    return list.toOwnedSlice(allocator);
}

fn parseOptionalFloat(columns: [][]const u8, index: i32) !f32 {
    if (index < 0) {
        return 0.0;
    }
    const col_idx: usize = @intCast(index);
    // 检查列是否存在，防止越界
    if (col_idx >= columns.len) {
        return 0.0;
    }

    logDebug("parseOptionalFloat, item : {s} .", .{columns[col_idx]});

    return std.fmt.parseFloat(f32, columns[col_idx]);
}

pub fn parseDateTimeToUnix(s: []const u8) !i64 {
    logDebug("parseDateTimeToUnix, item : {s} .", .{s});

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

export fn calculate_ema(bars_ptr: [*]Bar, bars_len: usize, period: usize) void {
    // 数据不够计算周期，直接返回
    if (bars_len < period) return;

    // 将裸指针切片为 Zig 的 Slice，方便操作
    const bars = bars_ptr[0..bars_len];

    // 1. 计算平滑因子 alpha
    const alpha: f32 = 2.0 / @as(f32, @floatFromInt(period + 1));

    // 2. 初始化：计算第一个 EMA 值（用前 N 个周期的 SMA 代替）
    var sum: f32 = 0;
    var i: usize = 0;
    while (i < period) : (i += 1) {
        sum += bars[i].close;
        // 在计算出第一个有效值之前，先把前面的填充为 0 或 NaN
        if (i < period - 1) bars[i].ema20 = 0;
    }
    // 第 period-1 个位置存放初始 SMA 值
    bars[period - 1].ema20 = sum / @as(f32, @floatFromInt(period));

    // 3. 高速递归计算后续 EMA 值
    i = period;
    while (i < bars_len) : (i += 1) {
        // EMA_today = α * Close_today + (1 - α) * EMA_yesterday
        bars[i].ema20 = (alpha * bars[i].close) + ((1.0 - alpha) * bars[i - 1].ema20);
    }
}
