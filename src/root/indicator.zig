const Bar = @import("bar.zig").Bar;

pub fn calculate_ema(
    bars_ptr: [*]Bar,
    bars_len: usize,
    period: usize,
    output_ptr: [*]f32
) void {
    // 数据不够计算周期，直接返回
    if (bars_len < period) return;

    // 将裸指针切片为 Zig 的 Slice，方便操作
    const bars = bars_ptr[0..bars_len];
    const output = output_ptr[0..bars_len];

    // 1. 计算平滑因子 alpha
    const alpha: f32 = 2.0 / @as(f32, @floatFromInt(period + 1));

    // 2. 初始化：计算第一个 EMA 值（用前 N 个周期的 SMA 代替）
    var sum: f32 = 0;
    var i: usize = 0;
    while (i < period) : (i += 1) {
        sum += bars[i].close;
        // 在计算出第一个有效值之前，先把前面的填充为 0 或 NaN
        if (i < period - 1) {
            output[i] = 0;
        }
    }
    // 第 period-1 个位置存放初始 SMA 值
    output[period - 1] = sum / @as(f32, @floatFromInt(period));

    // 3. 高速递归计算后续 EMA 值
    i = period;
    while (i < bars_len) : (i += 1) {
        // EMA_today = α * Close_today + (1 - α) * EMA_yesterday
        output[i] = (alpha * bars[i].close) + ((1.0 - alpha) * output[i - 1]);
    }
}
