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

    last_parse_count = bars.count;
    return bars;
}

export fn get_last_parse_count() usize {
    return last_parse_count;
}

export fn calculate_ema(
    ctx: *const QuantContext, // 传入 context 引用
    period: usize,
    output_ptr: [*]f32
) void {
    indicator.calculate_ema(ctx, period, output_ptr);
}

pub export fn run_analysis(
    ctx: *QuantContext // 🌟 直接传入上下文指针
) void {
    // 1. 自动从 ctx 中提取已有的 count
    const count = ctx.count;
    if (count == 0) return;

    // 2. 利用你写的 inline getters 获取数据切片
    // 这样你就再也不用手动去算 bars_ptr + count * 2 这种容易出错的偏移了
    const o = ctx.getOpenSlice();
    const h = ctx.getHighSlice();
    const l = ctx.getLowSlice();
    const c = ctx.getCloseSlice();

    // 3. 结果存储：直接使用 ctx 内部预留的 attributes 空间
    // 如果你依然想用外部传入的 out_ptr，也可以保留参数，但内部 attributes 通常更整洁
    const out = ctx.attributes[0..count];

    // 4. 调用分析模块
    // 既然在写 Zig，我们可以直接传 Slice，让 analyzer 内部处理更安全
    analyzer.extract_bar_attributes(
        o.ptr,
        h.ptr,
        l.ptr,
        c.ptr,
        count,
        out.ptr
    );
}
