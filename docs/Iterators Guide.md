# Zig Iterators

## Overview

Zig doesn't have a built-in iterator interface like some languages. Instead, **iterators are a pattern**: a struct with a `next()` method that returns `?T` (optional).

**Core concept:** Call `next()` repeatedly until it returns `null`.

## Basic Iterator Pattern

```zig
const Iterator = struct {
    index: usize,
    items: []const i32,
    
    pub fn next(self: *Iterator) ?i32 {
        if (self.index >= self.items.len) return null;
        
        const item = self.items[self.index];
        self.index += 1;
        return item;
    }
};
```

## Using Iterators: `while` Unwrapping

The standard way to consume an iterator:

```zig
var iter = Iterator{ .index = 0, .items = &[_]i32{1, 2, 3} };

while (iter.next()) |item| {
    std.debug.print("{}\n", .{item});
}
// Prints: 1, 2, 3
// Stops when next() returns null
```

**How it works:**
1. `iter.next()` is called
2. If it returns a value, unwrap it into `item` and execute the block
3. If it returns `null`, exit the loop
4. Repeat

## Creating Your Own Iterator

### Pattern 1: Nested Struct (Common)

Keep the iterator inside the collection:

```zig
pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        elements: []T,
        
        // Nested iterator struct
        pub const Iterator = struct {
            list: *const Self,
            index: usize,
            
            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.list.elements.len) return null;
                
                const item = self.list.elements[self.index];
                self.index += 1;
                return item;
            }
        };
        
        // Factory method to create iterator
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .list = self,
                .index = 0,
            };
        }
    };
}

// Usage:
var list = ArrayList(i32).init(allocator, .{});
try list.add(10);
try list.add(20);

var iter = list.iterator();
while (iter.next()) |item| {
    std.debug.print("{}\n", .{item});
}
```

### Pattern 2: Multi-Level Iterator

For structures like HashSet with buckets:

```zig
pub const Iterator = struct {
    set: *const Self,
    bucket_index: usize,
    item_index: usize,
    
    pub fn next(self: *Iterator) ?T {
        while (self.bucket_index < self.set.buckets.len()) {
            // Get current bucket
            const bucket = self.set.buckets.get(self.bucket_index) catch unreachable;
            
            // Try to get item from current bucket
            if (self.item_index < bucket.len()) {
                const item = bucket.get(self.item_index) catch unreachable;
                self.item_index += 1;
                return item;
            }
            
            // Current bucket exhausted, move to next
            self.bucket_index += 1;
            self.item_index = 0;
        }
        
        return null;  // All buckets exhausted
    }
};
```

### Pattern 3: Standalone Iterator Function

For simple cases:

```zig
pub fn range(start: i32, end: i32) RangeIterator {
    return RangeIterator{
        .current = start,
        .end = end,
    };
}

const RangeIterator = struct {
    current: i32,
    end: i32,
    
    pub fn next(self: *RangeIterator) ?i32 {
        if (self.current >= self.end) return null;
        
        const value = self.current;
        self.current += 1;
        return value;
    }
};

// Usage:
var iter = range(0, 5);
while (iter.next()) |i| {
    std.debug.print("{}\n", .{i});
}
// Prints: 0, 1, 2, 3, 4
```

## Standard Library Iterators

### String Splitting

```zig
var iter = std.mem.splitScalar(u8, "one,two,three", ',');
while (iter.next()) |part| {
    std.debug.print("{s}\n", .{part});
}
// Prints: one, two, three
```

### Tokenizing (Skips Empty)

```zig
var iter = std.mem.tokenizeScalar(u8, "one  two   three", ' ');
while (iter.next()) |token| {
    std.debug.print("{s}\n", .{token});
}
// Prints: one, two, three (skips empty tokens)
```

### Line Iterator

```zig
var iter = std.mem.splitScalar(u8, "line1\nline2\nline3", '\n');
while (iter.next()) |line| {
    std.debug.print("Line: {s}\n", .{line});
}
```

### Directory Iterator

```zig
var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
defer dir.close();

var iter = dir.iterate();
while (try iter.next()) |entry| {
    std.debug.print("{s}\n", .{entry.name});
}
```

## Iterator Variations

### Returning Errors: `!?T`

When iteration can fail:

```zig
pub fn next(self: *Iterator) !?Entry {
    // Might return error, or null (done), or value
    if (self.done) return null;
    
    const entry = try self.readNextEntry();  // Can error
    if (entry == null) {
        self.done = true;
        return null;
    }
    
    return entry;
}

// Usage with try:
while (try iter.next()) |entry| {
    std.debug.print("{s}\n", .{entry.name});
}
```

### Returning Pointers

For modifying elements in-place:

```zig
pub fn next(self: *Iterator) ?*T {
    if (self.index >= self.list.len()) return null;
    
    const ptr = &self.list.elements[self.index];
    self.index += 1;
    return ptr;
}

// Usage:
while (iter.next()) |item_ptr| {
    item_ptr.* += 1;  // Modify in place
}
```

### Index + Value

```zig
const IndexedItem = struct {
    index: usize,
    value: T,
};

pub fn next(self: *Iterator) ?IndexedItem {
    if (self.index >= self.items.len) return null;
    
    const item = IndexedItem{
        .index = self.index,
        .value = self.items[self.index],
    };
    self.index += 1;
    return item;
}

// Usage:
while (iter.next()) |item| {
    std.debug.print("[{}] = {}\n", .{item.index, item.value});
}
```

## Common Iterator Patterns

### Pattern 1: Filter While Iterating

```zig
var iter = list.iterator();
while (iter.next()) |item| {
    if (item < 0) continue;  // Skip negatives
    std.debug.print("{}\n", .{item});
}
```

### Pattern 2: Early Exit

```zig
var iter = list.iterator();
while (iter.next()) |item| {
    if (item == target) {
        std.debug.print("Found!\n", .{});
        break;
    }
}
```

### Pattern 3: Collect Into New Collection

```zig
var result = ArrayList(i32).init(allocator, .{});
defer result.deinit();

var iter = source.iterator();
while (iter.next()) |item| {
    if (item % 2 == 0) {
        try result.add(item);
    }
}
```

### Pattern 4: Transform Values

```zig
var iter = list.iterator();
while (iter.next()) |item| {
    const doubled = item * 2;
    std.debug.print("{}\n", .{doubled});
}
```

### Pattern 5: Enumerate with Index

```zig
var iter = list.iterator();
var index: usize = 0;
while (iter.next()) |item| : (index += 1) {
    std.debug.print("[{}] = {}\n", .{index, item});
}
```

### Pattern 6: Zip Two Iterators

```zig
var iter1 = list1.iterator();
var iter2 = list2.iterator();

while (iter1.next()) |item1| {
    if (iter2.next()) |item2| {
        std.debug.print("{} + {} = {}\n", .{item1, item2, item1 + item2});
    } else break;  // iter2 exhausted
}
```

## Infinite Iterators

Iterators that never return `null`:

```zig
const Counter = struct {
    current: i32,
    
    pub fn next(self: *Counter) i32 {
        const value = self.current;
        self.current += 1;
        return value;
    }
};

// Usage requires manual break:
var counter = Counter{ .current = 0 };
var count: usize = 0;
while (true) {
    const value = counter.next();
    std.debug.print("{}\n", .{value});
    
    count += 1;
    if (count >= 10) break;  // Prevent infinite loop
}
```

## Stateful Iterators

Iterators that maintain complex state:

```zig
const FibonacciIterator = struct {
    a: u64,
    b: u64,
    max: u64,
    
    pub fn next(self: *FibonacciIterator) ?u64 {
        if (self.a > self.max) return null;
        
        const result = self.a;
        const new_b = self.a + self.b;
        self.a = self.b;
        self.b = new_b;
        return result;
    }
};

// Usage:
var fib = FibonacciIterator{ .a = 0, .b = 1, .max = 100 };
while (fib.next()) |num| {
    std.debug.print("{}\n", .{num});
}
// Prints: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
```

## Iterator Invalidation

**Important:** Modifying a collection while iterating usually invalidates the iterator:

```zig
var list = ArrayList(i32).init(allocator, .{});
try list.add(1);
try list.add(2);

var iter = list.iterator();
while (iter.next()) |item| {
    try list.add(item * 2);  // ❌ BAD! Modifies list while iterating
}
```

**Solution:** Collect items first, then modify:

```zig
var items_to_add = ArrayList(i32).init(allocator, .{});
defer items_to_add.deinit();

var iter = list.iterator();
while (iter.next()) |item| {
    try items_to_add.add(item * 2);
}

for (items_to_add.items) |item| {
    try list.add(item);
}
```

## Testing Iterators

```zig
test "iterator returns all items" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();
    
    try list.add(1);
    try list.add(2);
    try list.add(3);
    
    var iter = list.iterator();
    
    try std.testing.expectEqual(@as(?i32, 1), iter.next());
    try std.testing.expectEqual(@as(?i32, 2), iter.next());
    try std.testing.expectEqual(@as(?i32, 3), iter.next());
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "iterator on empty collection returns null" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();
    
    var iter = list.iterator();
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}

test "multiple iterators work independently" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();
    
    try list.add(1);
    try list.add(2);
    
    var iter1 = list.iterator();
    var iter2 = list.iterator();
    
    try std.testing.expectEqual(@as(?i32, 1), iter1.next());
    try std.testing.expectEqual(@as(?i32, 1), iter2.next());
    try std.testing.expectEqual(@as(?i32, 2), iter1.next());
    try std.testing.expectEqual(@as(?i32, 2), iter2.next());
}
```

## Common Mistakes

### ❌ Not checking for null:
```zig
while (true) {
    const item = iter.next();  // Might be null!
    std.debug.print("{}\n", .{item});  // Error if null
}
```
**Fix:** Use `while` unwrapping
```zig
while (iter.next()) |item| {
    std.debug.print("{}\n", .{item});
}
```

### ❌ Forgetting to advance iterator:
```zig
while (iter.next()) |item| {
    if (item == target) {
        // Stuck in infinite loop if we don't break or continue
        std.debug.print("Found!\n", .{});
    }
}
```
**Fix:** Use `break` or ensure loop advances

### ❌ Modifying collection while iterating:
```zig
while (iter.next()) |item| {
    try list.remove(0);  // Invalidates iterator!
}
```
**Fix:** Collect changes, apply after iteration

### ❌ Using value after iterator is consumed:
```zig
var last_item: ?i32 = null;
while (iter.next()) |item| {
    last_item = item;
}

std.debug.print("{}\n", .{last_item.?});  // OK
const another = iter.next();  // Returns null - iterator is done
```

## Performance Considerations

### Iterators Don't Copy
```zig
// Efficient - no copying
var iter = list.iterator();
while (iter.next()) |item| {
    // item is a copy of the value, but iterator doesn't copy the whole list
}

// vs direct loop
for (list.items) |item| {
    // Same efficiency
}
```

### When to Use Iterator vs For Loop

**Use iterator when:**
- Need to control iteration (pause, resume)
- Want to hide internal structure
- Implementing complex iteration logic (multi-level, filtering)
- Iterator state needs to persist between calls

**Use for loop when:**
- Simple iteration over a slice
- Don't need iterator state
- Want clearest/simplest code

```zig
// Simple case - for loop is clearer:
for (list.items) |item| {
    std.debug.print("{}\n", .{item});
}

// Complex case - iterator is better:
var iter = hashset.iterator();  // Hides bucket structure
while (iter.next()) |item| {
    std.debug.print("{}\n", .{item});
}
```

## Real-World Example: File Line Iterator

```zig
const LineIterator = struct {
    file: std.fs.File,
    buffer: [4096]u8,
    file_reader: std.fs.File.Reader,
    
    pub fn init(file: std.fs.File) LineIterator {
        var buf: [4096]u8 = undefined;
        return LineIterator{
            .file = file,
            .buffer = undefined,
            .file_reader = file.reader(&buf),
        };
    }
    
    pub fn next(self: *LineIterator) !?[]const u8 {
        // Read until newline or EOF
        // Returns error, null (EOF), or line
        // Implementation would handle buffering, etc.
    }
};

// Usage:
const file = try std.fs.cwd().openFile("input.txt", .{});
defer file.close();

var iter = LineIterator.init(file);
while (try iter.next()) |line| {
    std.debug.print("{s}\n", .{line});
}
```

## Summary

| Pattern | Returns | Use Case |
|---------|---------|----------|
| `next() ?T` | Optional value | Standard iteration |
| `next() !?T` | Error or optional | Iteration can fail |
| `next() ?*T` | Pointer | Modify in place |
| `next() T` | Always a value | Infinite iterators |

## Best Practices

1. **Use `while` unwrapping** - `while (iter.next()) |item| { }`
2. **Return `?T` from next()** - standard pattern
3. **Keep iterator state minimal** - just what's needed to track position
4. **Document invalidation** - when modifying collection invalidates iterator
5. **Test empty case** - ensure iterator handles empty collections
6. **Don't modify while iterating** - collect changes, apply after
7. **Prefer for loops for simple cases** - iterators for complex iteration

## Key Takeaway

**Iterators in Zig are simple: a struct with `next()` returning `?T`.** Use `while (iter.next()) |item|` to consume them. They provide a consistent way to traverse collections without exposing internal structure. Keep them simple, document when they're invalidated, and prefer for loops for straightforward iteration over slices.
