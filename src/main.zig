const std = @import("std");
const kline_engine = @import("kline_engine");

pub fn main() !void {

}

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
