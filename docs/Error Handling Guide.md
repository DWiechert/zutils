# Zig Error Handling

## Overview

Zig uses **explicit error handling** with error unions. There's no exceptions, no try-catch blocks like Java/Python. Instead, errors are values that must be handled explicitly.

## Core Concepts

### Error Union Type: `!T`

An error union can be either:
- A success value of type `T`
- An error from an error set

```zig
fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

// Return type is: error{DivisionByZero}!i32
// Meaning: either an error OR an i32
```

### Error Sets

Errors are grouped into sets:

```zig
// Define custom errors
const FileError = error{
    FileNotFound,
    PermissionDenied,
    DiskFull,
};

const NetworkError = error{
    ConnectionRefused,
    Timeout,
};

// Combine error sets
const AppError = FileError || NetworkError;
```

### Inferred Error Sets

Let Zig infer the error set:

```zig
fn readConfig() ![]const u8 {
    // Zig infers all possible errors from the function body
    const file = try std.fs.cwd().openFile("config.txt", .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024);
}
```

## Handling Errors

### 1. `try` - Propagate Errors Up

The most common pattern - if error occurs, return it to caller:

```zig
fn loadFile(path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    return content;
}

// If openFile fails, the error is immediately returned
// If readToEndAlloc fails, the error is immediately returned
```

**Equivalent to:**
```zig
const file = std.fs.cwd().openFile(path, .{}) catch |err| return err;
```

### 2. `catch` - Handle Errors

Handle the error yourself instead of propagating:

```zig
fn getFileSize(path: []const u8) usize {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return 0;  // Return default on error
    };
    defer file.close();
    
    const stat = file.stat() catch return 0;
    return stat.size;
}
```

**Capture the error:**
```zig
const file = std.fs.cwd().openFile(path, .{}) catch |err| {
    std.debug.print("Failed to open file: {}\n", .{err});
    return 0;
};
```

### 3. `catch unreachable` - Assert No Error

Use when you're **certain** an error can't happen:

```zig
fn getElement(list: ArrayList(i32), index: usize) i32 {
    // We already checked bounds, so this can't fail
    return list.get(index) catch unreachable;
}

// If it DOES error, program crashes - use carefully!
```

**When to use:**
- After bounds checking
- When logic guarantees success
- Better than ignoring errors silently

### 4. `orelse` - Provide Default for Optionals

Not for errors, but related - for optionals (`?T`):

```zig
const name: ?[]const u8 = getName();
const actual_name = name orelse "Anonymous";
```

### 5. Switch on Errors

Handle different errors differently:

```zig
const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
    error.FileNotFound => {
        std.debug.print("File not found, using defaults\n", .{});
        return getDefaults();
    },
    error.AccessDenied => {
        std.debug.print("Permission denied\n", .{});
        return error.AccessDenied;
    },
    else => {
        std.debug.print("Unexpected error: {}\n", .{err});
        return err;
    },
};
```

## Cleanup with `defer` and `errdefer`

### `defer` - Always Execute

Runs when scope exits, regardless of success or error:

```zig
fn processFile(path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();  // ALWAYS runs when function returns
    
    // ... work with file ...
    
    // file.close() is called here, even if error occurs below
}
```

### `errdefer` - Execute Only on Error

Runs only if an error is returned from the current scope:

```zig
fn createResource() !*Resource {
    const resource = try allocator.create(Resource);
    errdefer allocator.destroy(resource);  // Only if error occurs after this
    
    try resource.initialize();  // If this fails, resource is destroyed
    errdefer resource.deinitialize();  // Only if error occurs after this
    
    try resource.configure();  // If this fails, both errdefers run
    
    return resource;  // Success! No errdefers run
}
```

**Key difference:**
- `defer` = cleanup on **any** exit (success or error)
- `errdefer` = cleanup only on **error** exit

### Real Example: Memory Management

```zig
fn loadAndProcess(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();  // Close file no matter what
    
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(content);  // Free only if processing fails
    
    try processContent(content);  // If this fails, content is freed
    
    return content;  // Success! Content is NOT freed (caller owns it)
}
```

## Common Patterns

### Pattern 1: Try Everything, Let Caller Handle

```zig
fn readConfig(path: []const u8) !Config {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);
    
    const config = try parseConfig(content);
    return config;
}
```

### Pattern 2: Provide Defaults on Error

```zig
fn readConfigOrDefault(path: []const u8) Config {
    return readConfig(path) catch {
        std.debug.print("Using default config\n", .{});
        return Config.default();
    };
}
```

### Pattern 3: Convert Errors

```zig
const AppError = error{
    ConfigError,
    NetworkError,
};

fn loadData() AppError!Data {
    const config = readConfig() catch {
        return error.ConfigError;
    };
    
    const data = fetchData(config) catch {
        return error.NetworkError;
    };
    
    return data;
}
```

### Pattern 4: Accumulate Errors

```zig
fn processMany(items: []Item) !void {
    var had_error = false;
    
    for (items) |item| {
        processItem(item) catch |err| {
            std.debug.print("Failed to process item: {}\n", .{err});
            had_error = true;
            continue;  // Keep processing other items
        };
    }
    
    if (had_error) return error.SomeItemsFailed;
}
```

## Returning Errors

### Create and Return Errors

```zig
fn validateAge(age: i32) !void {
    if (age < 0) return error.InvalidAge;
    if (age > 150) return error.InvalidAge;
}

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
```

### Error Payloads (Advanced)

Errors can't carry data, but you can return a struct:

```zig
const Result = struct {
    value: i32,
    error_msg: ?[]const u8,
};

fn divide(a: i32, b: i32) Result {
    if (b == 0) return .{ .value = 0, .error_msg = "Division by zero" };
    return .{ .value = @divTrunc(a, b), .error_msg = null };
}
```

Or use error unions with context:

```zig
const ParseError = struct {
    line: usize,
    column: usize,
    message: []const u8,
};

fn parse(input: []const u8) !Ast {
    // ... parsing ...
    if (invalid) {
        // Can't attach ParseError directly to error
        // Need to handle separately or use different pattern
        return error.ParseFailed;
    }
}
```

## Testing Error Cases

```zig
test "divide by zero returns error" {
    const result = divide(10, 0);
    try std.testing.expectError(error.DivisionByZero, result);
}

test "valid division succeeds" {
    const result = try divide(10, 2);
    try std.testing.expectEqual(@as(i32, 5), result);
}

test "handles file not found" {
    const content = loadFile("nonexistent.txt");
    try std.testing.expectError(error.FileNotFound, content);
}
```

## Error vs Optional

### Error Union: `!T`
- Something can fail with a **reason**
- Use when operation might fail (file I/O, parsing, network)
```zig
fn openFile(path: []const u8) !File
```

### Optional: `?T`
- Something might not exist (no error, just absence)
- Use for nullable values, searches that might not find anything
```zig
fn findUser(id: u32) ?User
```

### Combined: `!?T`
- Operation can fail (error) OR succeed with optional value
```zig
fn searchDatabase(query: []const u8) !?User {
    // Error: database connection failed
    // null: query succeeded but no results
    // User: found a user
}
```

## Common Mistakes

### ❌ Ignoring errors silently:
```zig
_ = openFile("test.txt");  // BAD! Error is ignored
```
**Fix:** Use `try` or `catch`

### ❌ Using `catch unreachable` when error is possible:
```zig
const file = std.fs.cwd().openFile(path, .{}) catch unreachable;
// If file doesn't exist, program crashes!
```
**Fix:** Handle the error properly

### ❌ Forgetting `try`:
```zig
const result = divide(10, 0);  // result is error union, not i32
const doubled = result * 2;    // Error! Can't multiply error union
```
**Fix:**
```zig
const result = try divide(10, 0);  // Unwrapped to i32
const doubled = result * 2;
```

### ❌ Wrong defer order:
```zig
const mem = try allocator.alloc(u8, 100);
const file = try std.fs.cwd().createFile("out.txt", .{});
defer allocator.free(mem);  // Runs second
defer file.close();         // Runs first

// Better:
const file = try std.fs.cwd().createFile("out.txt", .{});
defer file.close();
const mem = try allocator.alloc(u8, 100);
defer allocator.free(mem);
```

## Best Practices

1. **Use `try` by default** - let errors propagate
2. **Use `defer` for cleanup** - ensures resources are freed
3. **Use `errdefer` for rollback** - cleanup only on error path
4. **Handle specific errors** - use `catch |err| switch` when needed
5. **Don't use `catch unreachable`** unless you're certain
6. **Test error cases** - verify error handling works
7. **Document errors** - explain what errors your functions can return

## Summary Table

| Pattern | Syntax | Use When |
|---------|--------|----------|
| Propagate | `try func()` | Default - let caller handle |
| Handle | `func() catch { }` | Want to handle error locally |
| Capture error | `func() catch \|err\| { }` | Need to know which error |
| Assert success | `func() catch unreachable` | Certain it won't error |
| Default value | `func() catch default_value` | Want fallback on error |
| Switch on error | `func() catch \|err\| switch (err)` | Different handling per error |
| Always cleanup | `defer cleanup()` | Resource must be freed |
| Cleanup on error | `errdefer cleanup()` | Rollback if operation fails |

## Key Takeaway

**Errors in Zig are explicit and must be handled.** You can't accidentally ignore them. This makes code more robust but requires more thought about error handling paths. Use `try`, `catch`, `defer`, and `errdefer` to build reliable, resource-safe code.
