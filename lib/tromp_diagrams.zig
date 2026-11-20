const std = @import("std");
const Expr = @import("expr.zig").Expr;

const Canvas = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    rows: [][]bool,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .rows = &.{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }

        self.allocator.free(self.rows);
    }

    pub fn resize(self: *Self, width: usize, height: usize) !void {
        const rows = try self.allocator.realloc(self.rows, height);
        @memset(rows[self.rows.len..], &.{});
        self.rows = rows;

        for (self.rows) |*row| {
            const new_row = try self.allocator.realloc(row.*, width);
            @memset(new_row[row.len..], false);
            row.* = new_row;
        }
    }

    pub inline fn get_height(self: Self) usize {
        return self.rows.len;
    }

    pub inline fn get_width(self: Self) usize {
        return self.rows[0].len;
    }

    pub inline fn set(self: *Self, x: usize, y: usize, v: bool) void {
        self.rows[y][x] = v;
    }

    pub inline fn get(self: Self, x: usize, y: usize) bool {
        return self.rows[y][x];
    }

    pub fn place_another_canvas_at(self: *Self, other: Self, x: usize, y: usize) void {
        for (0.., y..y + other.get_height()) |it_other_y, it_y| {
            for (0.., x..x + other.get_width()) |it_other_x, it_x| {
                self.set(it_x, it_y, other.get(it_other_x, it_other_y));
            }
        }
    }

    pub fn dump(self: Self, allocator: std.mem.Allocator, sb: *std.ArrayList(u8)) !void {
        for (self.rows) |row| {
            for (row) |col| {
                const char: u8 = if (col) '#' else ' ';
                try sb.append(allocator, char);
            }
            try sb.append(allocator, '\n');
        }
    }

    pub fn dump_console_debug(self: Self) void {
        var buffer: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = fba.allocator();

        var sb = std.ArrayList(u8).empty;
        defer sb.deinit(allocator);
        self.dump(allocator, &sb) catch unreachable;
        std.debug.print("{s}", .{sb.items});
    }
};

test {
    const allocator = std.testing.allocator;

    var canvas = Canvas.init(allocator);
    defer canvas.deinit();
    try canvas.resize(5, 5);

    canvas.set(0, 0, true);
    canvas.set(2, 2, true);
    canvas.set(4, 4, true);

    canvas.dump_console_debug();
}

fn get_width(expr: *const Expr) void {
    const input_vars = expr.function.arg;
    _ = input_vars;
}

const Var = struct {
    depth: usize,
    ptr: []const u8,
};

pub fn render(expr: *const Expr, allocator: std.mem.Allocator) !Canvas {
    switch (expr.*) {
        .variable => {
            var canvas = Canvas.init(allocator);
            try canvas.resize(3, 2);

            canvas.set(1, 0, true);
            canvas.set(1, 1, true);

            return canvas;
        },
        .function => |*func| {
            var body_canvas = try render(func.expr, allocator);
            defer body_canvas.deinit();

            var canvas = Canvas.init(allocator);
            try canvas.resize(body_canvas.get_width(), body_canvas.get_height() + 2);

            @memset(canvas.rows[0], true);

            canvas.place_another_canvas_at(body_canvas, 0, 2);

            return canvas;
        },
        .application => @panic("todo"),
    }
}
