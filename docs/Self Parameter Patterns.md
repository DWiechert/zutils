# Zig: Passing `Self` to Methods

## Overview

In Zig structs, you have three main ways to pass `self` to a method:
1. `self: Self` - Pass by value (copy)
2. `self: *Self` - Pass by mutable pointer
3. `self: *const Self` - Pass by read-only pointer

## Quick Reference

| Pattern | When to Use | Can Modify? | Copies Data? |
|---------|-------------|-------------|--------------|
| `Self` | Read-only, small structs | ❌ No | ✅ Yes |
| `*Self` | Modify the struct | ✅ Yes | ❌ No |
| `*const Self` | Read-only, avoid copy | ❌ No | ❌ No |

## Pattern 1: `self: Self` (Pass by Value)

### When to use:
- Method only **reads** from the struct
- Struct is **small** (< 64 bytes typically)
- You want to signal "this method doesn't modify anything"

### Behavior:
- Creates a **copy** of the struct
- Changes to `self` inside the function don't affect the original
- Works with `const` variables

### Examples:

```zig
const Point = struct {
    const Self = @This();
    
    x: i32,
    y: i32,
    
    // Read-only method - pass by value
    pub fn distanceFromOrigin(self: Self) f32 {
        const x_float = @as(f32, @floatFromInt(self.x));
        const y_float = @as(f32, @floatFromInt(self.y));
        return @sqrt(x_float * x_float + y_float * y_float);
    }
    
    // Another read-only method
    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }
};

// Usage:
const p = Point{ .x = 3, .y = 4 };  // const is fine!
const dist = p.distanceFromOrigin();  // Works with const
```

### For ArrayList/HashSet:

```zig
pub fn len(self: Self) usize {
    return self.elements.len;
}

pub fn isEmpty(self: Self) bool {
    return self.elements.len == 0;
}

pub fn contains(self: Self, element: T) bool {
    var iter = self.iterator();
    while (iter.next()) |item| {
        if (std.meta.eql(element, item)) {
            return true;
        }
    }
    return false;
}
```

### Pros:
✅ Clear intent - "this is read-only"  
✅ Works with `const` variables  
✅ Prevents accidental modification  
✅ Good for small structs  

### Cons:
❌ Copies the entire struct (inefficient for large structs)  
❌ Can't modify the original struct

## Pattern 2: `self: *Self` (Mutable Pointer)

### When to use:
- Method **modifies** the struct's fields
- Need to change state (add elements, update counters, etc.)

### Behavior:
- Receives a **pointer** to the original struct
- Changes affect the original struct
- Requires `var`, not `const`

### Examples:

```zig
const ArrayList = struct {
    const Self = @This();
    
    elements: []T,
    capacity: usize,
    allocator: std.mem.Allocator,
    
    // Modifies the struct - needs mutable pointer
    pub fn add(self: *Self, item: T) !void {
        if (self.elements.len >= self.capacity) {
            try self.grow();  // Modifies capacity and elements
        }
        
        const old_len = self.elements.len;
        self.elements = self.elements.ptr[0..old_len + 1];  // Modifies elements
        self.elements[old_len] = item;
    }
    
    // Another modifying method
    pub fn remove(self: *Self, index: usize) !T {
        if (index >= self.elements.len) return error.IndexOutOfBounds;
        
        const element = self.elements[index];
        
        if (index < self.elements.len - 1) {
            @memcpy(
                self.elements[index..self.elements.len - 1],
                self.elements[index + 1..self.elements.len]
            );
        }
        
        self.elements = self.elements.ptr[0..self.elements.len - 1];  // Modifies
        return element;
    }
    
    // Internal helper that modifies
    fn grow(self: *Self) !void {
        const new_capacity = self.calculateNewCapacity();
        const new_memory = try self.allocator.alloc(T, new_capacity);
        
        if (self.elements.len > 0) {
            @memcpy(new_memory[0..self.elements.len], self.elements);
            self.allocator.free(self.elements.ptr[0..self.capacity]);
        }
        
        self.elements.ptr = new_memory.ptr;
        self.capacity = new_capacity;  // Modifies capacity
    }
};

// Usage:
var list = ArrayList(i32).init(allocator, .{});  // MUST be var, not const
try list.add(42);  // Works - list is var
try list.remove(0);  // Works - list is var

const const_list = ArrayList(i32).init(allocator, .{});
try const_list.add(42);  // ❌ ERROR! Can't get mutable pointer from const
```

### Pros:
✅ Can modify the struct  
✅ No copying overhead  
✅ Changes persist after function returns  

### Cons:
❌ Requires `var`, not `const`  
❌ Less clear if method actually modifies or not

## Pattern 3: `self: *const Self` (Read-only Pointer)

### When to use:
- Method only **reads** from the struct
- Struct is **large** (want to avoid copying)
- You want to signal "read-only" while avoiding copy overhead

### Behavior:
- Receives a **pointer** to the struct
- **Cannot modify** through this pointer
- No copying, but still read-only
- Works with `const` variables

### Examples:

```zig
const LargeStruct = struct {
    const Self = @This();
    
    data: [1000]u8,
    count: usize,
    metadata: [100]u8,
    
    // Read-only, but avoid copying 1100 bytes
    pub fn checksum(self: *const Self) u32 {
        var sum: u32 = 0;
        for (self.data) |byte| {
            sum +%= byte;
        }
        return sum;
    }
    
    // Another read-only method
    pub fn getCount(self: *const Self) usize {
        return self.count;
    }
};

// Usage:
const large = LargeStruct{ /* ... */ };  // const is fine
const sum = large.checksum();  // Works with const, no copy
```

### For ArrayList - alternative to `Self`:

```zig
// Instead of copying the whole struct
pub fn len(self: *const Self) usize {
    return self.elements.len;
}

// Avoids copy, still read-only
pub fn iterator(self: *const Self) Iterator {
    return Iterator{
        .list = self,
        .index = 0,
    };
}
```

### Pros:
✅ No copying overhead  
✅ Clear intent - "read-only"  
✅ Works with `const` variables  
✅ Good for large structs  

### Cons:
❌ Slightly more verbose  
❌ Overkill for small structs

## When to Use Each Pattern

### Use `self: Self` when:
- ✅ Method is read-only
- ✅ Struct is small (< 64 bytes: a few pointers, integers, bools)
- ✅ You want clearest "read-only" signal
- ✅ Examples: `Point`, `Color`, `Range`

### Use `self: *Self` when:
- ✅ Method modifies fields
- ✅ Need to change state
- ✅ Examples: `add()`, `remove()`, `reset()`, `clear()`

### Use `self: *const Self` when:
- ✅ Method is read-only
- ✅ Struct is large (want to avoid copy)
- ✅ Want to be explicit about pointer semantics
- ✅ Examples: reading from large buffers, complex structs

## Special Case: `deinit()`

For `deinit()`, you have two choices:

### Option 1: `self: Self` (by value)
```zig
pub fn deinit(self: Self) void {
    if (self.capacity > 0) {
        self.allocator.free(self.elements.ptr[0..self.capacity]);
    }
}
```
✅ You're only reading fields to free memory  
✅ Not modifying the struct itself  
✅ Can be called on `const`

### Option 2: `self: *Self` (by pointer)
```zig
pub fn deinit(self: *Self) void {
    if (self.capacity > 0) {
        self.allocator.free(self.elements.ptr[0..self.capacity]);
    }
    self.capacity = 0;  // Optional: reset state
    self.elements = &[_]T{};
}
```
✅ If you want to reset fields after cleanup  
❌ Requires `var`, not `const`

**Most common:** Use `Self` for `deinit()` since you're just cleaning up, not modifying.

## Real-World Example: ArrayList

```zig
pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        
        elements: []T,
        capacity: usize,
        allocator: std.mem.Allocator,
        scale_factor: f32,
        
        // No modifications - pass by value (small struct)
        pub fn len(self: Self) usize {
            return self.elements.len;
        }
        
        // No modifications - pass by value
        pub fn isEmpty(self: Self) bool {
            return self.elements.len == 0;
        }
        
        // Modifies elements - needs mutable pointer
        pub fn add(self: *Self, item: T) !void {
            // ... modifies self.elements
        }
        
        // Modifies elements - needs mutable pointer
        pub fn remove(self: *Self, index: usize) !T {
            // ... modifies self.elements
        }
        
        // Read-only, but returns an iterator that needs a pointer
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .list = self,
                .index = 0,
            };
        }
        
        // Could use Self, but *const Self avoids tiny copy
        pub fn get(self: *const Self, index: usize) !T {
            if (index >= self.elements.len) return error.IndexOutOfBounds;
            return self.elements[index];
        }
        
        // Could use Self or *const Self - both work
        pub fn contains(self: Self, element: T) bool {
            var iter = self.iterator();
            while (iter.next()) |item| {
                if (std.meta.eql(element, item)) return true;
            }
            return false;
        }
        
        // Cleanup - just reading fields
        pub fn deinit(self: Self) void {
            if (self.capacity > 0) {
                self.allocator.free(self.elements.ptr[0..self.capacity]);
            }
        }
    };
}
```

## Common Mistakes

### ❌ Using `Self` when you need to modify:
```zig
pub fn add(self: Self, item: T) !void {
    self.elements = ...;  // ERROR! Can't modify a copy
}
```
**Fix:** Use `self: *Self`

### ❌ Using `*Self` for read-only on small structs:
```zig
pub fn len(self: *Self) usize {  // Unnecessary pointer
    return self.elements.len;
}
```
**Fix:** Use `self: Self` for clarity

### ❌ Calling mutable methods on `const`:
```zig
const list = ArrayList(i32).init(allocator, .{});
try list.add(42);  // ERROR! list is const, add() needs *Self
```
**Fix:** Use `var list = ...`

## Summary: The Decision Tree

```
Does the method modify the struct?
├─ YES → Use `self: *Self`
│   └─ Examples: add(), remove(), clear(), reset()
│
└─ NO (read-only)
    ├─ Is the struct small (< 64 bytes)?
    │   ├─ YES → Use `self: Self`
    │   │   └─ Examples: len(), isEmpty(), equals()
    │   │
    │   └─ NO (large struct) → Use `self: *const Self`
    │       └─ Examples: checksum(), complexCalculation()
    │
    └─ Special case: Iterator creation
        └─ Use `self: *const Self` (iterator needs pointer)
```

## Key Takeaways

1. **Modifying?** → `*Self`
2. **Read-only + small?** → `Self`
3. **Read-only + large?** → `*const Self`
4. **When in doubt for read-only:** `Self` is safe and clear
5. **For `deinit()`:** Usually `Self` (just reading to cleanup)

The pattern you choose signals intent to readers of your code!
