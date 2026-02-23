const QuantContext = @import("../quant_context.zig").QuantContext;
const BacktestResult = @import("backtest_result.zig").BacktestResult;
const Flags = @import("../analyzer.zig").Flags;

pub fn consecutive_trend_up(
    ctx: *QuantContext,
    n: usize,
    result: *BacktestResult, // 传入预分配好的结果集
) void {
    var up_streak: usize = 0;
    var current_equity: f32 = 0.0;
    var peak_equity: f32 = 0.0;

    for (0..ctx.count) |i| {
        const attr = ctx.attributes[i];

        // 1. 判断是否符合强阳线标志
        if ((attr & Flags.FLAG_TREND_UP) != 0) {
            up_streak += 1;
        } else {
            up_streak = 0;
        }

        // 2. 触发信号：连续 N 根阳线，且下一根 K 线存在
        if (up_streak >= n and i + 1 < ctx.count) {
            const entry_idx = i + 1;
            const exit_idx  = i + 1;
            const entry_p   = ctx.open[entry_idx];
            const exit_p    = ctx.close[exit_idx];

            // 记录交易
            result.addTrade(entry_idx, exit_idx, entry_p, exit_p);

            // 3. 计算回撤 (Max Drawdown)
            current_equity += (exit_p - entry_p);
            if (current_equity > peak_equity) {
                peak_equity = current_equity;
            }
            const dd = peak_equity - current_equity;
            if (dd > result.max_drawdown) {
                result.max_drawdown = dd;
            }

            // 为了不让信号重叠，触发后重置计数器
            up_streak = 0;
        }
    }
}
