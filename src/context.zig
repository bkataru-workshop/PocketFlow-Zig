const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

// this is an interface that structs can implement contracts for
const Value = struct {
    init: *const fn (anytype) anyerror!Value,
    destroy: *const fn () void,
    to: *const fn (type) anyerror!type,
};

pub const Context = struct {
    allocator: Allocator,
    data: StringHashMap(Value),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator) Context {
        return .{
            .allocator = allocator,
            .data = StringHashMap(Value).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Context) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.data.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.destroy();
        }
        self.data.deinit();
    }

    pub fn get(self: *Context, comptime T: type, key: []const u8) ?T {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |val| {
            return val.to(T) catch |err| {
                std.debug.print("Type mismatch for key '{s}': {any}\n", .{ key, err });
            };
        }
        return null;
    }

    pub fn set(self: *Context, key: []const u8, value: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const val = try Value.init(value);
        try self.data.put(key, val);
    }
};
