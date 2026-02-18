const std = @import("std");
const kline_engine = @import("kline_engine");

pub fn main() !void {
    // 打开 csv 文件
    // const file_path = "D:/Users/PC/WebstormProjects/kline_engine/python/600000_5m.csv";
    const file_path = "C:/Users/PC/Desktop/600000_5m.csv";
    const file = std.fs.cwd().openFile(file_path, .{}) catch |e| {
        std.debug.print("❌ 错误: 找不到文件 '{s}'。请确保文件存在。\n", .{file_path});
        std.debug.print("错误详情: {}\n", .{e});
        return undefined;
    };
    defer file.close();

    // 初始化分配器
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 将文件写入内存
    const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
    // std.debug.print("content: {s}", .{content});
    defer allocator.free(content);

    // 计时并解析
    var timer = try std.time.Timer.start();
    // const bars: [0]kline_engine.Bar = .{};
    const bars = try kline_engine.parseCsv(allocator, content, .{
        .time_idx = 1,
        .open_idx = 2,
        .high_idx = 4,
        .low_idx = 3,
        .close_idx = 5,
        .volume_idx = 8,
    });
    defer allocator.free(bars);
    const elapsed = timer.read();

    // 打印性能报告
    const ms = @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms;
    std.debug.print("\n----------------------------------\n", .{});
    std.debug.print("✅ Zig 引擎解析完成!\n", .{});
    std.debug.print("📊 记录总数: {d} 行\n", .{bars.len});
    std.debug.print("⏱️ 耗时: {d:.3} ms\n", .{ms});

    if (bars.len > 0) {
        const last = bars[bars.len - 1];
        std.debug.print("💡 样例数据: Time={d}, Close={d:.2}\n", .{ last.time, last.close });
    }
    std.debug.print("----------------------------------\n", .{});
}
