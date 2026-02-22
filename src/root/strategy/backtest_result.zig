pub const BacktestResult = struct {
    total_profit: f32,    // 总盈亏百分比
    win_rate: f32,        // 胜率
    trade_count: u32,     // 总交易次数
    max_drawdown: f32,    // 最大回撤
};
