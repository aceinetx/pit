const std = @import("std");

pub const ExprTag = enum {
    variable,
    function,
    application,
};

pub const Expr = union(ExprTag) {
    variable: ExprVariable,
    function: ExprFunction,
    application: ExprApplication,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator, kill_myself: bool) void {
        switch (self.*) {
            inline else => |*ex| {
                ex.deinit(allocator);
            },
        }

        if (kill_myself) {
            self.* = undefined;
            allocator.destroy(self);
        }
    }

    pub fn dupe(self: *@This(), allocator: std.mem.Allocator) std.mem.Allocator.Error!*@This() {
        const new = try allocator.create(@This());
        new.* = switch (self.*) {
            .variable => |*ex| .{ .variable = try ex.dupe(allocator) },
            .function => |*ex| .{ .function = try ex.dupe(allocator) },
            .application => |*ex| .{ .application = try ex.dupe(allocator) },
        };
        return new;
    }

    pub fn dump(self: *@This(), indent: usize) void {
        for (0..indent) |_| {
            std.debug.print("....", .{});
        }
        switch (self.*) {
            .variable => |*ex| {
                std.debug.print("- {s}({})\n", .{ ex.name, ex.static });
            },
            .function => |*ex| {
                std.debug.print("- \\{s}({}).\n", .{ ex.arg.name, ex.arg.static });
                ex.expr.dump(indent + 1);
            },
            .application => |*ex| {
                std.debug.print("- Application\n", .{});
                ex.lhs.dump(indent + 1);
                ex.rhs.dump(indent + 1);
            },
        }
    }

    pub fn display(self: *@This(), allocator: std.mem.Allocator, sb: *std.ArrayList(u8)) !void {
        switch (self.*) {
            .variable => |*ex| {
                try sb.appendSlice(allocator, ex.name);
            },
            .function => |*ex| {
                try sb.append(allocator, '\\');
                try sb.appendSlice(allocator, ex.arg.name);
                try sb.append(allocator, '.');
                try ex.expr.display(allocator, sb);
            },
            .application => |*ex| {
                {
                    const do_parens = ex.lhs.* == .function;
                    if (do_parens) try sb.append(allocator, '(');
                    try ex.lhs.display(allocator, sb);
                    if (do_parens) try sb.append(allocator, ')');
                }

                try sb.append(allocator, ' ');

                {
                    const do_parens = ex.rhs.* != .variable;
                    if (do_parens) try sb.append(allocator, '(');
                    try ex.rhs.display(allocator, sb);
                    if (do_parens) try sb.append(allocator, ')');
                }
            },
        }
    }

    pub fn display_dump(self: *@This(), allocator: std.mem.Allocator) void {
        var sb = std.ArrayList(u8).empty;
        defer sb.deinit(allocator);

        if (self.display(allocator, &sb)) |_| {
            std.debug.print("{s}\n", .{sb.items});
        } else |_| {}
    }
};

pub const ExprVariable = struct {
    name: []const u8,
    static: bool = true,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (!self.static) allocator.free(self.name);
    }

    pub fn dupe(self: *@This(), allocator: std.mem.Allocator) !@This() {
        if (!self.static) {
            return .{
                .name = try allocator.dupe(u8, self.name),
                .static = false,
            };
        }
        return self.*;
    }

    pub fn eq(self: ExprVariable, other: ExprVariable) bool {
        return std.mem.eql(u8, self.name, other.name);
    }
};

pub const ExprFunction = struct {
    arg: ExprVariable,
    expr: *Expr,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.arg.deinit(allocator);
        self.expr.deinit(allocator, true);
    }

    pub fn dupe(self: *@This(), allocator: std.mem.Allocator) !@This() {
        return .{
            .arg = try self.arg.dupe(allocator),
            .expr = try self.expr.dupe(allocator),
        };
    }
};

pub const ExprApplication = struct {
    lhs: *Expr,
    rhs: *Expr,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.lhs.deinit(allocator, true);
        self.rhs.deinit(allocator, true);
    }

    pub fn dupe(self: *@This(), allocator: std.mem.Allocator) !@This() {
        return .{
            .lhs = try self.lhs.dupe(allocator),
            .rhs = try self.rhs.dupe(allocator),
        };
    }
};

test "Dupe" {
    const allocator = std.testing.allocator;

    const expr = try allocator.create(Expr);
    defer expr.deinit(allocator, true);
    expr.* = Expr{ .variable = .{ .name = "abc" } };

    const clone = try expr.dupe(allocator);
    defer clone.deinit(allocator, true);
}

test "Memory 1" {
    var allocator = std.testing.allocator;

    const body = try allocator.create(Expr);
    defer body.deinit(allocator, true);
    body.* = .{
        .variable = .{
            .name = "x",
        },
    };
}
