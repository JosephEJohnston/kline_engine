const QuantContext = @import("../quant_context.zig").QuantContext;
const BacktestResult = @import("backtest_result.zig").BacktestResult;
const Flags = @import("../analyzer.zig").Flags;

pub fn consecutive_trend_up(
    ctx: *QuantContext,
    n: usize,
    result: *BacktestResult,
) void {
    var up_streak: usize = 0;
    var current_equity: f32 = 0.0;
    var peak_equity: f32 = 0.0;

    // 🌟 引入状态变量
    var in_position: bool = false;
    var entry_idx: usize = 0;
    var entry_p: f32 = 0.0;

    for (0..ctx.count) |i| {
        const attr = ctx.attributes[i];

        if (!in_position) {
            // 1. 未持仓逻辑：寻找入场信号
            if ((attr & Flags.FLAG_TREND_UP) != 0) {
                up_streak += 1;
            } else {
                up_streak = 0;
            }

            // 触发入场：连续 N 根强阳线，且下一根 K 线存在
            if (up_streak >= n and i + 1 < ctx.count) {
                in_position = true;
                entry_idx = i + 1;
                entry_p = ctx.open[entry_idx];
                up_streak = 0; // 重置计数器，防止在持仓期间重复触发逻辑
            }
        } else {
            // 2. 持仓逻辑：等待 FLAG_TREND_DOWN 离场
            if ((attr & Flags.FLAG_TREND_DOWN) != 0) {
                const exit_idx = i;
                const exit_p = ctx.close[exit_idx]; // 在该根趋势阴线收盘时离场

                // 记录交易记录
                result.addTrade(entry_idx, exit_idx, entry_p, exit_p);

                // 🌟 计算收益与回撤（在离场时统一结算）
                const trade_profit = exit_p - entry_p;
                current_equity += trade_profit;

                if (current_equity > peak_equity) {
                    peak_equity = current_equity;
                }
                const dd = peak_equity - current_equity;
                if (dd > result.max_drawdown) {
                    result.max_drawdown = dd;
                }

                in_position = false;
                // 离场后重置 streak，准备下一次入场
                up_streak = 0;
            }
        }
    }
}
