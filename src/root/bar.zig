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
