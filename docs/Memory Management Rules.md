# Zig Memory Management: free() vs deinit()

## Core Principle
**Only free memory you explicitly allocated.** Zig has no garbage collector - you must manually manage heap memory.

## When to use `free()`

Use `allocator.free()` for memory you allocated directly with the allocator.

### Allocator methods that require `free()`:
- `allocator.alloc(T, n)` - allocate a slice
- `allocator.create(T)` - allocate a single item
- `allocator.dupe(u8, slice)` - duplicate a slice

### Examples:

```zig
// Allocate a slice - MUST free
const numbers = try allocator.alloc(i32, 100);
defer allocator.free(numbers);

// Allocate a single struct - MUST free
const person = try allocator.create(Person);
defer allocator.destroy(person);  // Note: destroy() for create()

// Duplicate a string - MUST free
const name_copy = try allocator.dupe(u8, "Alice");
defer allocator.free(name_copy);
```

## When to use `deinit()`

Use `deinit()` for structs that manage their own internal memory.

### Pattern:
If a struct has an `init()` function, it usually needs a `deinit()` to clean up.

### Examples:

```zig
// ArrayList manages internal memory
var list = ArrayList(i32).init(allocator, .{});
defer list.deinit();  // Internally calls allocator.free()

// HashMap manages internal memory
var map = std.AutoHashMap(i32, []const u8).init(allocator);
defer map.deinit();

// File handles need cleanup
const file = try std.fs.cwd().openFile("test.txt", .{});
defer file.close();  // Not deinit, but same pattern
```

### Inside a `deinit()` implementation:

```zig
pub fn deinit(self: Self) void {
    // Free memory the struct owns
    if (self.capacity > 0) {
        self.allocator.free(self.elements.ptr[0..self.capacity]);
    }
}
```

## What NEVER needs freeing

### Primitives (stack-allocated):
- `i32`, `u64`, `usize`, `f32`, `f64` - all integer and float types
- `bool` - booleans
- `enum` types
- Pointers themselves (the pointer value, not what they point to)

### String literals:
```zig
const name = "Alice";  // Compile-time constant
// DON'T free this - it's not heap allocated!
```

### Stack-allocated structs:
```zig
const point = Point{ .x = 10, .y = 20 };
// DON'T free - it's on the stack
```

### Examples - NO freeing needed:

```zig
const BenchmarkResult = struct {
    name: []const u8,  // String literal from caller - don't free
    iterations: usize, // Primitive - don't free
    total_ns: u64,     // Primitive - don't free
    avg_ns: u64,       // Primitive - don't free
};

// The struct itself is stored in an ArrayList
// When you call arrayList.deinit(), the ArrayList frees its internal storage
// You don't need to free individual BenchmarkResult fields
```

## Common Patterns

### Pattern 1: Direct allocation + free
```zig
const buffer = try allocator.alloc(u8, 1024);
defer allocator.free(buffer);

// Use buffer...
```

### Pattern 2: Struct with init/deinit
```zig
const MyStruct = struct {
    data: []u8,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, size: usize) !MyStruct {
        const data = try allocator.alloc(u8, size);
        return MyStruct{
            .data = data,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *MyStruct) void {
        self.allocator.free(self.data);
    }
};

// Usage:
var my_struct = try MyStruct.init(allocator, 100);
defer my_struct.deinit();
```

### Pattern 3: No allocation - no freeing
```zig
const Point = struct {
    x: i32,
    y: i32,
};

const p = Point{ .x = 5, .y = 10 };
// Nothing to free - just stack data
```

## The Golden Rule

**If you didn't call `alloc()`, `create()`, or `dupe()`, don't call `free()`.**

**If a struct has `init()`, it probably needs `deinit()`.**

## Memory Leak Detection

Use the testing allocator to detect leaks:

```zig
test "no memory leaks" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();  // If you forget this, test fails!
    
    try list.add(42);
    // std.testing.allocator will report leaks if deinit() is missing
}
```

## Common Mistakes

### ❌ Freeing string literals:
```zig
const name = "Alice";
allocator.free(name);  // CRASH! This is a compile-time constant
```

### ❌ Freeing primitives:
```zig
const count: usize = 42;
allocator.free(&count);  // NONSENSE! Primitives aren't allocated
```

### ❌ Double-free:
```zig
const buffer = try allocator.alloc(u8, 100);
allocator.free(buffer);
allocator.free(buffer);  // CRASH! Already freed
```

### ❌ Forgetting deinit:
```zig
var list = ArrayList(i32).init(allocator, .{});
try list.add(42);
// Forgot list.deinit() - MEMORY LEAK!
```

### ✅ Correct usage:
```zig
var list = ArrayList(i32).init(allocator, .{});
defer list.deinit();  // Cleanup guaranteed

const buffer = try allocator.alloc(u8, 100);
defer allocator.free(buffer);  // Cleanup guaranteed
```

## Summary Table

| Type | Needs free/deinit? | Method | Why |
|------|-------------------|--------|-----|
| `i32`, `u64`, primitives | ❌ No | - | Stack allocated |
| String literal `"hello"` | ❌ No | - | Compile-time constant |
| Stack struct `Point{.x=1}` | ❌ No | - | Stack allocated |
| `allocator.alloc()` | ✅ Yes | `allocator.free()` | Heap allocated |
| `allocator.create()` | ✅ Yes | `allocator.destroy()` | Heap allocated |
| `allocator.dupe()` | ✅ Yes | `allocator.free()` | Heap allocated |
| `ArrayList.init()` | ✅ Yes | `.deinit()` | Manages heap memory |
| `HashMap.init()` | ✅ Yes | `.deinit()` | Manages heap memory |
| `File.open()` | ✅ Yes | `.close()` | Resource handle |

## Key Takeaway

**Memory management in Zig is explicit and manual.** If you allocate it, you free it. If a struct manages resources, it provides `deinit()` to clean up. Use `defer` to ensure cleanup happens automatically when scope exits.
