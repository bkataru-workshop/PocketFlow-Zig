/// The `Node` defines the basic unit of work with `prep`, `exec`, and `post` methods.
/// We use a vtable to create a generic interface.
const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("context.zig").Context;

pub const Action = []const u8;

pub const Node = struct {
    self: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        prep: *const fn (self: *anyopaque, allocator: Allocator, context: *Context) anyerror!*anyopaque,
        exec: *const fn (self: *anyopaque, allocator: Allocator, prep_res: *anyopaque) anyerror!*anyopaque,
        post: *const fn (self: *anyopaque, allocator: Allocator, context: *Context, prep_res: *anyopaque, exec_res: *anyopaque) anyerror!Action,
        cleanup_prep: *const fn (self: *anyopaque, allocator: Allocator, prep_res: *anyopaque) void,
        cleanup_exec: *const fn (self: *anyopaque, allocator: Allocator, exec_res: *anyopaque) void,
    };

    pub fn prep(self: Node, allocator: Allocator, context: *Context) !*anyopaque {
        return self.vtable.prep(self.self, allocator, context);
    }

    pub fn exec(self: Node, allocator: Allocator, prep_res: *anyopaque) !*anyopaque {
        return self.vtable.exec(self.self, allocator, prep_res);
    }

    pub fn post(self: Node, allocator: Allocator, context: *Context, prep_res: *anyopaque, exec_res: *anyopaque) !Action {
        return self.vtable.post(self.self, allocator, context, prep_res, exec_res);
    }

    pub fn cleanupPrep(self: Node, allocator: Allocator, prep_res: *anyopaque) void {
        self.vtable.cleanup_prep(self.self, allocator, prep_res);
    }

    pub fn cleanupExec(self: Node, allocator: Allocator, exec_res: *anyopaque) void {
        self.vtable.cleanup_exec(self.self, allocator, exec_res);
    }
};

pub const BaseNode = struct {
    successors: std.StringHashMap(Node),

    pub fn init(allocator: Allocator) BaseNode {
        return .{
            .successors = std.StringHashMap(Node).init(allocator),
        };
    }

    pub fn deinit(self: *BaseNode) void {
        self.successors.deinit();
    }

    pub fn next(self: *BaseNode, action: Action, node: Node) void {
        self.successors.put(action, node) catch @panic("Failed to add successor");
    }
};
