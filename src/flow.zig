/// The `Flow` manages the execution of nodes in a graph.
const std = @import("std");
const Allocator = std.mem.Allocator;

const BaseNode = @import("node.zig").BaseNode;
const Context = @import("context.zig").Context;
const Node = @import("node.zig").Node;

pub const Flow = struct {
    start_node: Node,
    allocator: Allocator,

    pub fn init(allocator: Allocator, start_node: Node) Flow {
        return .{
            .allocator = allocator,
            .start_node = start_node,
        };
    }

    pub fn run(self: *Flow, context: *Context) !void {
        var current_node: ?Node = self.start_node;

        while (current_node) |node| {
            const prep_res = try node.prep(self.allocator, context);
            defer if (prep_res != null) self.allocator.destroy(prep_res);

            const exec_res = try node.exec(self.allocator, prep_res);
            defer if (exec_res != null) self.allocator.destroy(exec_res);

            const action = try node.post(self.allocator, context, prep_res, exec_res);

            const base_node: *BaseNode = @ptrCast(@alignCast(node.self));

            current_node = base_node.successors.get(action);
        }
    }
};
