const std = @import("std");
const http = std.http;
const json = std.json;
const mem = std.mem;
const testing = std.testing;

/// Pollinations.ai API client for LLM and AI image generation
pub const PollinationsClient = struct {
    allocator: mem.Allocator,
    client: http.Client,
    base_url: []const u8,

    pub const Error = error{
        RequestFailed,
        InvalidResponse,
        NetworkError,
        EndOfStream,
        ReadFailed,
    } || mem.Allocator.Error || http.Client.RequestError || http.Client.FetchError || http.Client.ConnectError;

    /// Initialize a new Poliinations client
    pub fn init(allocator: mem.Allocator) !PollinationsClient {
        return .{
            .allocator = allocator,
            .client = http.Client{ .allocator = allocator },
            .base_url = "https://text.pollinations.ai",
        };
    }

    /// Clean up resources
    pub fn deinit(self: *PollinationsClient) void {
        self.client.deinit();
    }

    /// Message structure for chat requests
    pub const Message = struct {
        role: []const u8,
        content: []const u8,
    };

    /// Request options for text generation
    pub const TextOptions = struct {
        model: []const u8 = "openai",
        seed: ?i32 = null,
        jsonMode: bool = false,
        system: ?[]const u8 = null,
    };

    /// Response from text generation
    pub const TextResponse = struct {
        content: []const u8,
        allocator: mem.Allocator,

        pub fn deinit(self: TextResponse) void {
            self.allocator.free(self.content);
        }
    };

    fn urlEncode(self: *PollinationsClient, buffer: *std.ArrayList(u8), payload: []const u8) !void {
        for (payload) |c| {
            switch (c) {
                ' ' => try buffer.appendSlice(self.allocator, "%20"),
                '\n' => try buffer.appendSlice(self.allocator, "%0A"),
                '?' => try buffer.appendSlice(self.allocator, "%3F"),
                '&' => try buffer.appendSlice(self.allocator, "%26"),
                '=' => try buffer.appendSlice(self.allocator, "%3D"),
                '/' => try buffer.appendSlice(self.allocator, "%2F"),
                else => try buffer.append(self.allocator, c),
            }
        }
    }

    /// Generate text using the Pollinations.ai API
    /// Caller owns returned TextResponse.content's memory and must free when done
    pub fn generateText(
        self: *PollinationsClient,
        messages: []const Message,
        options: TextOptions,
    ) Error!TextResponse {
        // Build URL with query parameters
        var url_buffer = std.ArrayList(u8).empty;
        defer url_buffer.deinit(self.allocator);

        try url_buffer.print(self.allocator, "{s}/", .{self.base_url});

        // Add messages to URL path
        for (messages, 0..) |msg, i| {
            if (i > 0) try url_buffer.appendSlice(self.allocator, "%0A"); // URL encoded newline

            try url_buffer.print(self.allocator, "{s}: ", .{msg.role});
            // URL encode the content
            try self.urlEncode(&url_buffer, msg.content);
        }

        // Add query parameters
        try url_buffer.print(self.allocator, "?model={s}", .{options.model});
        if (options.seed) |seed| {
            try url_buffer.print(self.allocator, "&seed={d}", .{seed});
        }
        if (options.jsonMode) {
            try url_buffer.appendSlice(self.allocator, "&jsonMode=true");
        }
        if (options.system) |sys| {
            try url_buffer.appendSlice(self.allocator, "&system=");
            try self.urlEncode(&url_buffer, sys);
        }

        const url = try url_buffer.toOwnedSlice(self.allocator);
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);

        // TODO: fix this annoying TLS error or wait for a fix from zig
        var req = try self.client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&.{});

        // Check status
        if (response.head.status != .ok) {
            return Error.RequestFailed;
        }

        // Read response body
        var reader_buffer: [1024 * 1024 * 10]u8 = undefined;
        const body_reader = response.reader(&reader_buffer);

        try body_reader.readSliceAll(&reader_buffer);

        return TextResponse{
            .content = try self.allocator.dupe(u8, &reader_buffer),
            .allocator = self.allocator,
        };
    }

    /// Generate an image URL (Pollinations returns URLs, not binary data)
    /// Caller owns returned memory and must free when done
    pub fn generateImageUrl(
        self: *PollinationsClient,
        prompt: []const u8,
        options: struct {
            model: []const u8 = "flux",
            seed: ?i32 = null,
            width: u32 = 1024,
            height: u32 = 1024,
            nologo: bool = false,
            enhance: bool = false,
        },
    ) Error![]const u8 {
        var url_buffer = std.ArrayList(u8).empty;
        defer url_buffer.deinit(self.allocator);

        try url_buffer.appendSlice(self.allocator, "https://image.pollinations.ai/prompt/");
        // URL encode prompt
        try self.urlEncode(&url_buffer, prompt);

        // Add query parameters
        try url_buffer.print(self.allocator, "?model={s}", .{options.model});
        try url_buffer.print(self.allocator, "&width={d}", .{options.width});
        try url_buffer.print(self.allocator, "&height={d}", .{options.height});
        if (options.seed) |seed| {
            try url_buffer.print(self.allocator, "&seed={d}", .{seed});
        }
        if (options.nologo) {
            try url_buffer.appendSlice(self.allocator, "&nologo=true");
        }
        if (options.enhance) {
            try url_buffer.appendSlice(self.allocator, "&enhance=true");
        }

        return url_buffer.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "PollinationsClient - init and deinit" {
    var gpa = std.testing.allocator_instance;
    var client = try PollinationsClient.init(gpa.allocator());
    defer client.deinit();

    try testing.expect(client.base_url.len > 0);
}

test "PollinationsClient - generateImageUrl basic" {
    var gpa = std.testing.allocator_instance;
    var client = try PollinationsClient.init(gpa.allocator());
    defer client.deinit();

    const url = try client.generateImageUrl("a cute cat", .{});
    defer client.allocator.free(url);

    std.debug.print("Generated URL: {s}\n", .{url});

    try testing.expect(mem.indexOf(u8, url, "image.pollinations.ai") != null);
    try testing.expect(mem.indexOf(u8, url, "cute") != null);
    try testing.expect(mem.indexOf(u8, url, "cat") != null);
}

test "PollinationsClient - generateImageUrl with options" {
    var gpa = std.testing.allocator_instance;
    var client = try PollinationsClient.init(gpa.allocator());
    defer client.deinit();

    const url = try client.generateImageUrl("a landscape", .{
        .model = "flux-pro",
        .seed = 42,
        .width = 512,
        .height = 512,
        .nologo = true,
        .enhance = true,
    });
    defer client.allocator.free(url);

    try testing.expect(mem.indexOf(u8, url, "model=flux-pro") != null);
    try testing.expect(mem.indexOf(u8, url, "seed=42") != null);
    try testing.expect(mem.indexOf(u8, url, "width=512") != null);
    try testing.expect(mem.indexOf(u8, url, "height=512") != null);
    try testing.expect(mem.indexOf(u8, url, "nologo=true") != null);
    try testing.expect(mem.indexOf(u8, url, "enhance=true") != null);
}

test "PollinationsClient - generateImageUrl URL encoding" {
    var gpa = std.testing.allocator_instance;
    var client = try PollinationsClient.init(gpa.allocator());
    defer client.deinit();

    const url = try client.generateImageUrl("hello world & test?", .{});
    defer client.allocator.free(url);

    try std.testing.expect(mem.indexOf(u8, url, "%20") != null); // space
    try std.testing.expect(mem.indexOf(u8, url, "%26") != null); // &
    try std.testing.expect(mem.indexOf(u8, url, "%3F") != null); // ?
}

test "PollinationsClient - Message structure" {
    const msg = PollinationsClient.Message{
        .role = "user",
        .content = "Hello, AI!",
    };

    try std.testing.expectEqualStrings("user", msg.role);
    try std.testing.expectEqualStrings("Hello, AI!", msg.content);
}

test "PollinationsClient - TextOptions defaults" {
    const opts = PollinationsClient.TextOptions{};

    try std.testing.expectEqualStrings("openai", opts.model);
    try std.testing.expect(opts.seed == null);
    try std.testing.expect(opts.jsonMode == false);
    try std.testing.expect(opts.system == null);
}

test "PollinationsClient - TextOptions custom" {
    const opts = PollinationsClient.TextOptions{
        .model = "mistral",
        .seed = 123,
        .jsonMode = true,
        .system = "You are a helpful assistant",
    };

    try std.testing.expectEqualStrings("mistral", opts.model);
    try std.testing.expect(opts.seed.? == 123);
    try std.testing.expect(opts.jsonMode == true);
    try std.testing.expectEqualStrings("You are a helpful assistant", opts.system.?);
}

// Integration test - only runs with network access
test "PollinationsClient - generateText integration" {
    var gpa = std.testing.allocator_instance;

    var client = try PollinationsClient.init(gpa.allocator());
    defer client.deinit();

    const messages = [_]PollinationsClient.Message{
        .{ .role = "user", .content = "Say hello in one word" },
    };

    const response = try client.generateText(&messages, .{
        .model = "openai",
    });
    defer response.deinit();

    try testing.expect(response.content.len > 0);
    std.debug.print("\ngenerateText API Response: {s}\n", .{response.content});
}
