/// The `Context` is a thread-safe hash map that holds the shared state between nodes.
const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

const StoredValue = struct {
    ptr: *anyopaque,
    destructor: *const fn (allocator: Allocator, ptr: *anyopaque) void,
};

pub const Context = struct {
    allocator: Allocator,
    data: StringHashMap(StoredValue),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: Allocator) Context {
        return .{
            .allocator = allocator,
            .data = StringHashMap(StoredValue).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Context) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Free all stored values using their destructors
        var key_it = self.data.iterator();
        while (key_it.next()) |entry| {
            entry.value_ptr.destructor(self.allocator, entry.value_ptr.ptr);
        }

        self.data.deinit();
    }

    pub fn get(self: *Context, comptime T: type, key: []const u8) ?T {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |stored_value| {
            const typed_ptr: *const T = @ptrCast(@alignCast(stored_value.ptr));
            return typed_ptr.*;
        }
        return null;
    }

    pub fn set(self: *Context, key: []const u8, value: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const T = @TypeOf(value);

        // Check if we're replacing an existing value
        if (self.data.get(key)) |old_stored_value| {
            old_stored_value.destructor(self.allocator, old_stored_value.ptr);
        }

        // Always allocate space for T and store a pointer to it
        // This ensures consistent storage regardless of T being a pointer, struct, slice, etc.
        const ptr = try self.allocator.create(T);
        ptr.* = value;

        // Create a destructor function for this type
        const destructor = struct {
            fn destroy(allocator: Allocator, p: *anyopaque) void {
                const typed_ptr: *T = @ptrCast(@alignCast(p));
                allocator.destroy(typed_ptr);
            }
        }.destroy;

        const stored_value = StoredValue{
            .ptr = @ptrCast(ptr),
            .destructor = destructor,
        };

        try self.data.put(key, stored_value);
    }
};
