# Zig: Slices vs Arrays

## Overview

Zig has two main ways to work with sequential data:
- **Arrays** `[N]T` - fixed size, known at compile time
- **Slices** `[]T` - dynamic view into memory, size known at runtime

Understanding the difference is crucial for working with Zig effectively.

## Arrays: `[N]T`

### Definition

Fixed-size collection where size is part of the type:

```zig
const numbers: [5]i32 = [_]i32{1, 2, 3, 4, 5};
const bytes: [100]u8 = undefined;
const chars: [3]u8 = .{'a', 'b', 'c'};
```

### Key Characteristics

**Size is part of the type:**
```zig
const arr1: [5]i32 = [_]i32{1, 2, 3, 4, 5};
const arr2: [10]i32 = undefined;

// arr1 and arr2 are DIFFERENT types!
// [5]i32 != [10]i32
```

**Stored on the stack (if local) or inline (if in struct):**
```zig
fn example() void {
    const arr = [_]i32{1, 2, 3};  // On the stack
}

const Point = struct {
    coords: [3]f32,  // Inline in the struct, not a pointer
};
```

**Size must be known at compile time:**
```zig
const size = 5;
const arr: [size]i32 = undefined;  // ✅ OK - comptime constant

var runtime_size: usize = 10;
const arr2: [runtime_size]i32 = undefined;  // ❌ Error! Not comptime
```

### Creating Arrays

**Array literals:**
```zig
const nums = [_]i32{1, 2, 3, 4, 5};  // Type inferred
const explicit: [5]i32 = .{1, 2, 3, 4, 5};
```

**Initialize with same value:**
```zig
const zeros = [_]i32{0} ** 10;  // [10]i32 of zeros
const fives = [_]i32{5} ** 8;   // [8]i32 of fives
```

**Undefined (uninitialized):**
```zig
var buffer: [1024]u8 = undefined;  // Don't care about initial values
```

**String literals are arrays:**
```zig
const message = "hello";
// Type is: *const [5:0]u8
// Null-terminated array of 5 bytes
```

### Accessing Arrays

```zig
const arr = [_]i32{10, 20, 30};

const first = arr[0];      // 10
const second = arr[1];     // 20
const len = arr.len;       // 3 (comptime known!)

// Bounds checking at runtime
var index: usize = 5;
const value = arr[index];  // Panic! Out of bounds
```

### Arrays Are Values (Copied)

```zig
const arr1 = [_]i32{1, 2, 3};
const arr2 = arr1;  // COPIES the entire array!

arr1[0] = 99;  // Error if arr1 is const
// arr2[0] is still 1 (separate copy)
```

## Slices: `[]T`

### Definition

A **view** into a sequence of elements - pointer + length:

```zig
const slice: []const i32 = &[_]i32{1, 2, 3, 4, 5};
var buffer: [100]u8 = undefined;
const view: []u8 = &buffer;
```

### Internal Structure

A slice is actually a struct:
```zig
struct {
    ptr: [*]T,    // Pointer to first element
    len: usize,   // Number of elements
}
```

### Key Characteristics

**Size is NOT part of the type:**
```zig
const slice1: []i32 = &[_]i32{1, 2, 3};      // length 3
const slice2: []i32 = &[_]i32{1, 2, 3, 4, 5}; // length 5

// Same type! Both are []i32
```

**Runtime size:**
```zig
var size: usize = getUserInput();
const slice = try allocator.alloc(i32, size);  // ✅ OK - runtime size
defer allocator.free(slice);
```

**Slices are views, not copies:**
```zig
var arr = [_]i32{1, 2, 3};
const slice = arr[0..];  // View into arr

slice[0] = 99;  // Modifies arr!
// arr[0] is now 99
```

### Creating Slices

**From arrays:**
```zig
var arr = [_]i32{1, 2, 3, 4, 5};

const all: []i32 = &arr;           // Entire array
const partial: []i32 = arr[1..4];  // Elements 1, 2, 3 (indices 1, 2, 3)
const from_start: []i32 = arr[0..3]; // First 3 elements
const to_end: []i32 = arr[2..];    // From index 2 to end
```

**From allocation:**
```zig
const slice = try allocator.alloc(i32, 100);
defer allocator.free(slice);
```

**From pointer + length:**
```zig
const ptr: [*]i32 = getPointer();
const slice: []i32 = ptr[0..length];
```

### Accessing Slices

```zig
var arr = [_]i32{10, 20, 30, 40};
const slice = arr[1..3];  // [20, 30]

const first = slice[0];    // 20 (relative to slice start)
const len = slice.len;     // 2 (runtime value)
const ptr = slice.ptr;     // Pointer to first element
```

### Slice vs Const Slice

```zig
var arr = [_]i32{1, 2, 3};

// Mutable slice - can modify elements
const slice: []i32 = &arr;
slice[0] = 99;  // ✅ OK

// Const slice - cannot modify elements
const const_slice: []const i32 = &arr;
const_slice[0] = 99;  // ❌ Error! Can't modify through const slice
```

## Converting Between Arrays and Slices

### Array to Slice

**Taking a reference:**
```zig
var arr = [_]i32{1, 2, 3};
const slice: []i32 = &arr;  // Entire array as slice
```

**Slicing syntax:**
```zig
const slice: []i32 = arr[0..];  // Entire array
const partial: []i32 = arr[1..3]; // Part of array
```

### Slice to Array (Compile-Time Known Size)

**Cannot convert directly at runtime:**
```zig
const slice: []i32 = getSlice();
const arr: [5]i32 = slice;  // ❌ Error! Can't convert
```

**Copy elements:**
```zig
var arr: [3]i32 = undefined;
@memcpy(&arr, slice[0..3]);  // Copy 3 elements
```

**Use slice[0..N] when size is known:**
```zig
const arr: *const [3]i32 = slice[0..3];  // Pointer to array
```

## String Literals: Special Arrays

String literals are null-terminated arrays:

```zig
const message = "hello";
// Type: *const [5:0]u8
// - Pointer to array
// - 5 elements
// - Null-terminated (:0)
// - bytes (u8)
// - constant (*const)

// As a slice:
const slice: []const u8 = "hello";  // Converts to slice
```

## Common Patterns

### Pattern 1: Function Parameters

**Prefer slices for flexibility:**
```zig
// ✅ Good - works with any size
fn processItems(items: []const i32) void {
    for (items) |item| {
        std.debug.print("{}\n", .{item});
    }
}

// Can call with different sizes:
const arr1 = [_]i32{1, 2, 3};
const arr2 = [_]i32{1, 2, 3, 4, 5};
processItems(&arr1);  // Works!
processItems(&arr2);  // Works!

// ❌ Less flexible - only works with exact size
fn processExactly5(items: [5]i32) void {
    // ...
}
```

### Pattern 2: Building Strings

```zig
var buffer: [100]u8 = undefined;
const slice = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{"World"});
// slice is a view into buffer with the actual length used
```

### Pattern 3: Dynamic Array (ArrayList)

```zig
pub fn ArrayList(comptime T: type) type {
    return struct {
        items: []T,       // Slice - dynamic view
        capacity: usize,  // How much is allocated
        
        // items.len = current number of elements
        // capacity = total allocated space
    };
}
```

### Pattern 4: Passing Subsets

```zig
fn processFirst3(items: []const i32) void {
    for (items[0..3]) |item| {
        std.debug.print("{}\n", .{item});
    }
}

const arr = [_]i32{1, 2, 3, 4, 5, 6};
processFirst3(&arr);  // Pass whole array, function uses first 3
```

### Pattern 5: Growing a View

```zig
var buffer: [100]u8 = undefined;
var view: []u8 = buffer[0..0];  // Empty view

// "Grow" the view
view = buffer[0..10];  // Now viewing first 10 elements
view = buffer[0..view.len + 5];  // Grow by 5 more
```

## Memory Layout

### Arrays

```
Stack or inline in struct:
[1][2][3][4][5]
 ↑
 Fixed size, contiguous memory
```

### Slices

```
Slice struct (on stack):
┌─────────┬────────┐
│ ptr     │ len    │
│ 0x1234  │ 5      │
└────┼────┴────────┘
     ↓
Actual data (heap or elsewhere):
[1][2][3][4][5]
```

## Working with .ptr and .len

### Getting pointer from slice:

```zig
const slice: []i32 = &[_]i32{1, 2, 3};

const ptr: [*]i32 = slice.ptr;  // Many-item pointer
const len: usize = slice.len;

// Reconstruct slice:
const same_slice: []i32 = ptr[0..len];
```

### Creating slices from pointers:

```zig
const ptr: [*]u8 = getPointer();
const length: usize = getLength();

const slice: []u8 = ptr[0..length];
```

## Const Semantics

### Array Constness

```zig
const arr = [_]i32{1, 2, 3};
arr[0] = 99;  // ❌ Error! arr is const

var mut_arr = [_]i32{1, 2, 3};
mut_arr[0] = 99;  // ✅ OK
```

### Slice Constness

```zig
var arr = [_]i32{1, 2, 3};

// const slice variable, mutable elements
const slice: []i32 = &arr;
slice[0] = 99;  // ✅ OK - elements are mutable
slice = other_slice;  // ❌ Error - slice variable is const

// mutable slice variable, const elements
var const_slice: []const i32 = &arr;
const_slice[0] = 99;  // ❌ Error - elements are const
const_slice = other_slice;  // ✅ OK - slice variable is mutable
```

## Common Operations

### Length

```zig
const arr = [_]i32{1, 2, 3};
const arr_len = arr.len;  // Comptime constant: 3

const slice: []i32 = &arr;
const slice_len = slice.len;  // Runtime value: 3
```

### Iteration

**Arrays:**
```zig
const arr = [_]i32{1, 2, 3, 4, 5};
for (arr) |item| {
    std.debug.print("{}\n", .{item});
}
```

**Slices:**
```zig
const slice: []const i32 = &[_]i32{1, 2, 3, 4, 5};
for (slice) |item| {
    std.debug.print("{}\n", .{item});
}
```

### Copying

```zig
const src = [_]i32{1, 2, 3};
var dst: [3]i32 = undefined;

@memcpy(&dst, &src);  // Copy array to array

// Or with slices:
const slice_src: []const i32 = &src;
var slice_dst: []i32 = &dst;
@memcpy(slice_dst, slice_src);
```

### Comparison

```zig
const arr1 = [_]i32{1, 2, 3};
const arr2 = [_]i32{1, 2, 3};

const equal = std.mem.eql(i32, &arr1, &arr2);  // true
```

## Common Mistakes

### ❌ Confusing array and slice types:
```zig
fn process(items: [5]i32) void { }

const arr = [_]i32{1, 2, 3, 4, 5, 6};
process(arr);  // Error! [6]i32 != [5]i32
```
**Fix:** Use slices for parameters

### ❌ Returning local array as slice:
```zig
fn getBadSlice() []i32 {
    var arr = [_]i32{1, 2, 3};
    return &arr;  // ❌ DANGER! arr is destroyed when function returns
}
```
**Fix:** Allocate or return array by value

### ❌ Not freeing allocated slices:
```zig
const slice = try allocator.alloc(i32, 100);
// ... use slice ...
// Forgot to free! Memory leak
```
**Fix:** Always `defer allocator.free(slice)`

### ❌ Modifying through const slice:
```zig
const slice: []const i32 = getSlice();
slice[0] = 99;  // Error! Elements are const
```

### ❌ Assuming slice copies data:
```zig
var arr = [_]i32{1, 2, 3};
const slice = arr[0..];
slice[0] = 99;
// arr[0] is now 99! Slice is a view, not a copy
```

## Performance Considerations

### Arrays
- ✅ Fixed size - no runtime overhead
- ✅ Stack allocated (usually) - fast
- ✅ Size known at compile time - optimizations possible
- ❌ Copying entire array can be expensive for large arrays

### Slices
- ✅ Just pointer + length - cheap to pass around
- ✅ No copying of underlying data
- ✅ Flexible size
- ❌ Bounds checking at runtime (negligible cost)
- ❌ Indirection through pointer (usually negligible)

## When to Use Each

### Use Arrays `[N]T` when:
- ✅ Size is known at compile time
- ✅ Want stack allocation
- ✅ Size is small
- ✅ Fixed-size buffers
- Examples: coordinates `[3]f32`, small buffers `[256]u8`

### Use Slices `[]T` when:
- ✅ Size determined at runtime
- ✅ Want to pass views into data
- ✅ Function parameters (flexibility)
- ✅ Working with allocated memory
- Examples: function parameters, dynamic arrays, views into arrays

## Summary Table

| Feature | Array `[N]T` | Slice `[]T` |
|---------|-------------|-------------|
| Size | Compile-time | Runtime |
| Type includes size | Yes | No |
| Memory | Stack/inline | View (ptr+len) |
| Allocation | Automatic | Manual (allocator) |
| Pass to function | Copies | Cheap (ptr+len) |
| Flexibility | Fixed size | Any size |
| Use case | Known size | Dynamic/flexible |

## Key Takeaway

**Arrays are fixed-size values with compile-time size.** They're copied when assigned. **Slices are runtime views** (pointer + length) into sequences of data. They don't own the memory, just point to it. Use arrays for fixed-size data, slices for parameters and dynamic-size data. Understanding the difference prevents bugs related to copying, ownership, and lifetime.
