const std = @import("std");

pub const BacktestResult = struct {
    // 🌟 核心数据：SOA 布局
    // 每一笔交易的详情分散在不同的数组中，但共享下标
    // 入场 k 索引
    entry_indices: []usize,
    // 出场 k 索引
    exit_indices:  []usize,
    // 入场价格
    entry_prices:  []f32,
    // 出场价格
    exit_prices:   []f32,
    // 单笔盈亏
    profits:       []f32,

    // 🌟 统计数据
    // 当前交易总数
    count:         usize = 0,
    // 内存容量
    capacity:      usize,
    // 累计盈亏
    total_profit:  f32   = 0.0,
    // 盈利次数
    win_count:     usize = 0,
    // 最大回撤
    max_drawdown:  f32   = 0.0,

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

    pub fn deinit(self: *BacktestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.entry_indices);
        allocator.free(self.exit_indices);
        allocator.free(self.entry_prices);
        allocator.free(self.exit_prices);
        allocator.free(self.profits);
    }

    // 原子化添加一笔交易
    pub fn addTrade(self: *BacktestResult, entry_i: usize, exit_i: usize, entry_p: f32, exit_p: f32) void {
        if (self.count >= self.capacity) return; // 简单处理，实际可加 realloc

        const i = self.count;
        self.entry_indices[i] = entry_i;
        self.exit_indices[i]  = exit_i;
        self.entry_prices[i]  = entry_p;
        self.exit_prices[i]   = exit_p;

        const pft = exit_p - entry_p;
        self.profits[i] = pft;

        // 更新统计
        self.total_profit += pft;
        if (pft > 0) self.win_count += 1;
        self.count += 1;
    }
};
