const std = @import("std");
const builtin = @import("builtin");
const js = @import("root/js.zig");
const indicator = @import("root/indicator.zig");
const pc = @import("root/parse_csv.zig");
const Bar = @import("root/bar.zig").Bar;
const ParseConfig = @import("root/bar.zig").ParseConfig;
const analyzer = @import("root/analyzer.zig");
const QuantContext = @import("root/quant_context.zig").QuantContext;

// 导出解析函数：返回解析后的 Bar 数组指针
// 注意：为了简单，我们把长度存给一个全局变量或通过指针返回
var last_parse_count: usize = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena = std.heap.ArenaAllocator.init(gpa.allocator());
const totalAllocator = arena.allocator();

// 导出分配函数：让 JS 知道去哪里申请内存放 CSV 字符串
pub export fn alloc_memory(len: usize) [*]u8 {
    const slice = totalAllocator.alloc(u8, len) catch @panic("OOM");
    return slice.ptr;
}

pub export fn free_memory() void {
    _ = arena.reset(.free_all);
}

pub export fn parse_csv_wasm(
    // csv 内容数组
    ptr: [*]const u8,
    len: usize,
    time_idx: i32,   // 直接接收参数，不要包在 struct 里
    open_idx: i32,
    high_idx: i32,
    low_idx: i32,
    close_idx: i32,
    volume_idx: i32
) *QuantContext {
    const content = ptr[0..len];

    const config = ParseConfig{
        .time_idx = time_idx,
        .open_idx = open_idx,
        .high_idx = high_idx,
        .low_idx = low_idx,
        .close_idx = close_idx,
        .volume_idx = volume_idx,
    };

    const bars = pc.parseCsv(totalAllocator, content, config)
        catch @panic("Check console for error name");

    last_parse_count = bars.capacity;
    return bars;
}

export fn get_last_parse_count() usize {
    return last_parse_count;
}

export fn calculate_ema(
    bars_ptr: [*]Bar,
    bars_len: usize,
    period: usize,
    output_ptr: [*]f32
) void {
    indicator.calculate_ema(bars_ptr, bars_len, period, output_ptr);
}

pub export fn run_analysis(
    // 传入k线数组指针，这里将其视为 4 字节步长的指针
    bars_ptr: [*]f32,
    out_ptr: [*]u8,       // 🌟 独立传入的输出数组指针
    count: usize
) void {
    const o_ptr = bars_ptr;
    const h_ptr = bars_ptr + count;
    const l_ptr = bars_ptr + 2 * count;
    const c_ptr = bars_ptr + 3 * count;

    // 直接调用你的分析模块，参数一一对应
    analyzer.extract_bar_attributes(
        o_ptr,
        h_ptr,
        l_ptr,
        c_ptr,
        count,
        out_ptr
    );
}
