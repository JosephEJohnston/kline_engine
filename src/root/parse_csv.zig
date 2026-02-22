const std = @import("std");
const builtin = @import("builtin");
const js = @import("js.zig");
const Bar = @import("bar.zig").Bar;
const ParseConfig = @import("bar.zig").ParseConfig;
const qc = @import("quant_context.zig");

const COMMON_BATCH_SIZE: u8 = 100;

pub fn parseCsv(
    allocator: std.mem.Allocator,
    content: []const u8,
    config: ParseConfig
) !*qc.QuantContext {
    const lc = get_line_count(content);

    var quantContext = try qc
        .create_context(allocator, lc);

    // 按行切分
    var lines = std.mem
        .tokenizeAny(u8, content, "\n");

    // 去除标头
    _ = lines.next();

    var lineIndex: usize = 0;
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
            js.logDebug("Parsing column item, item : {s}, index : {d} .", .{item, i});

            i += 1;
        }

        js.logDebug("Parsing column, column : {s} .", .{line});

        const bar = Bar{
            // 时间处理：如果索引有效则解析，否则设为 0
            .time = if (config.time_idx >= 0)
                try parseDateTimeToUnix(columns[@intCast(config.time_idx)])
            else 0,
            .open  = try parseOptionalFloat(&columns, config.open_idx),
            .high  = try parseOptionalFloat(&columns, config.high_idx),
            .low   = try parseOptionalFloat(&columns, config.low_idx),
            .close = try parseOptionalFloat(&columns, config.close_idx),
            .volume= try parseOptionalFloat(&columns, config.volume_idx),
        };

        js.logDebug("Line parsed successfully.", .{});

        quantContext.receiveBar(lineIndex, bar);

        lineIndex += 1;
    }

    return quantContext;
}

pub fn get_line_count(content: []const u8) usize {
    // 直接统计换行符的数量，速度极快
    const total_newlines = std.mem.count(u8, content, "\n");

    // 如果最后一行没有换行符，通常需要根据具体 CSV 情况处理
    // 但对于大部分标准 CSV，这个数量减去 1（标头）就是数据行数
    return total_newlines;
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

    js.logDebug("parseOptionalFloat, item : {s} .", .{columns[col_idx]});

    return std.fmt.parseFloat(f32, columns[col_idx]);
}

pub fn parseDateTimeToUnix(s: []const u8) !i64 {
    js.logDebug("parseDateTimeToUnix, item : {s} .", .{s});

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
