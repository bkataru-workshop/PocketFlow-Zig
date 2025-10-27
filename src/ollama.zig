const std = @import("std");
const http = std.http;
const json = std.json;
const mem = std.mem;
const testing = std.testing;

/// Ollama API client for local LLM inference
pub const OllamaClient = struct {
    allocator: mem.Allocator,
    client: http.Client,
    base_url: []const u8,

    pub const Error = error{
        RequestFailed,
        InvalidResponse,
        NetworkError,
        EndOfStream,
        ReadFailed,
        JsonParseError,
    } || mem.Allocator.Error || http.Client.RequestError || http.Client.FetchError || http.Client.ConnectError || json.ParseError(json.Scanner);

    /// Initialize a new Ollama client
    pub fn init(allocator: mem.Allocator, base_url: ?[]const u8) !OllamaClient {
        return .{
            .allocator = allocator,
            .client = http.CLient{ .allocator = allocator },
            .base_url = base_url orelse "http://locahost:11434",
        };
    }
};
