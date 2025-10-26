A Zig implementation of [PocketFlow](https://github.com/The-Pocket/PocketFlow), a minimalist flow-based programming framework.

## Overview

mention how it's a port of the original python package, but how it differs from that having been written/ported to zig due to zig's unique capabilities

## Features

- exploits comptime well?
- multithreaded?
- uses state machines?

## Quick Start

### 0. Setup

```bash
```

### 1. Define Custom States


```zig
```

### 2. Implement Nodes

```zig
```

### 3. Build Flows

```zig
```

### 4. Batch Processing

```zig
```

## Advanced Usage

### Custom State Management

Define your own states to control flow transitions:

```zig
```

### Complex Flow Construction

Build complex workflows with multiple nodes and state transitions:

```zig
```

## Examples

Check out the `examples/` directory for more detailed examples:

- basic.zig: Basic flow with custom states
- text2sql: Text-to-SQL workflow example
- [pocketflow-zig-rag](./examples/pocketflow-zig-rag/README.md): Retrieval-Augmented Generation (RAG) workflow example

## Development

### Building the Project

```bash
```

### Running Tests

```bash
```

## Contributing

Contributions are welcome! We're particularly looking for volunteers to:

1.  Implement asynchronous operation support
  - e.g., using one or more of state machines, event loops (io_uring, libuv, etc.), and the new Zig 0.15.1 Async I/O interface.
2.  Add more comprehensive test coverage, including edge cases and error handling.
3.  Improve documentation and provide more complex examples (e.g., LLM integration stubs).
4.  Refine the API for better Zig idiomatic usage if applicable.

Please feel free to submit pull requests or open issues for discussion.

## License

[MIT License](LICENSE)
