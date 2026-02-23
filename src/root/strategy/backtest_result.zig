const std = @import("std");

pub const BacktestResult = struct {
    // 基础统计
    total_trades: usize = 0,
    total_profit: f32   = 0.0,

    // 交易详情列表 (SOA 布局)
    entry_indices: []usize, // 入场索引
    exit_indices:  []usize, // 出场索引
    entry_prices:  []f32,   // 入场价
    exit_prices:   []f32,   // 出场价
    profits:       []f32,   // 单笔盈亏

    capacity: usize,
    count:    usize = 0,

    pub fn init(allocator: std.mem.Allocator, cap: usize) !BacktestResult {
        return .{
            .entry_indices = try allocator.alloc(usize, cap),
            .exit_indices  = try allocator.alloc(usize, cap),
            .entry_prices  = try allocator.alloc(f32, cap),
            .exit_prices   = try allocator.alloc(f32, cap),
            .profits       = try allocator.alloc(f32, cap),
            .capacity      = cap,
        };
    }
};

