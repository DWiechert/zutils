# Zig Optionals

## Overview

Optionals represent values that **might not exist**. In languages like Java/C, you might use `null`. In Zig, you explicitly mark types as optional with `?T`.

**Key principle:** There's no implicit null. A `T` cannot be null, but a `?T` can be either a value or `null`.

## The Optional Type: `?T`

```zig
const maybe_number: ?i32 = 42;        // Has a value
const no_number: ?i32 = null;         // No value

const name: []const u8 = "Alice";     // Cannot be null
const maybe_name: ?[]const u8 = null; // Can be null
```

## Creating Optionals

### From a Value

```zig
const age: ?i32 = 25;
const name: ?[]const u8 = "Bob";
```

### Null

```zig
const nothing: ?i32 = null;
const no_user: ?User = null;
```

### From Functions

```zig
fn findUser(id: u32) ?User {
    // Search logic...
    if (found) {
        return user;
    }
    return null;  // Not found
}

fn getFirst(list: []i32) ?i32 {
    if (list.len == 0) return null;
    return list[0];
}
```

## Unwrapping Optionals

### 1. `orelse` - Provide Default Value

The most common pattern:

```zig
const maybe_age: ?i32 = getAge();
const age = maybe_age orelse 0;  // Use 0 if null

const maybe_name: ?[]const u8 = getName();
const name = maybe_name orelse "Anonymous";  // Use "Anonymous" if null
```

**Execute code on null:**
```zig
const age = maybe_age orelse {
    std.debug.print("No age provided\n", .{});
    return 0;
};
```

**Return early on null:**
```zig
const user = findUser(id) orelse return error.UserNotFound;
```

### 2. `if` Unwrapping - Conditional Execution

Execute code only if value exists:

```zig
const maybe_user = findUser(id);

if (maybe_user) |user| {
    // user is unwrapped and available here
    std.debug.print("Found user: {s}\n", .{user.name});
} else {
    std.debug.print("User not found\n", .{});
}
```

**Without else:**
```zig
if (maybe_user) |user| {
    std.debug.print("User: {s}\n", .{user.name});
}
// user is not available here
```

**Pointer to optional:**
```zig
var maybe_count: ?i32 = 5;

if (&maybe_count) |*count| {
    count.* += 1;  // Modify the value
}
// maybe_count is now 6
```

### 3. `while` Unwrapping - Loop Until Null

Commonly used with iterators:

```zig
var iter = list.iterator();
while (iter.next()) |item| {
    std.debug.print("Item: {}\n", .{item});
}
// Stops when next() returns null
```

**Another example:**
```zig
while (getNextJob()) |job| {
    processJob(job);
}
```

### 4. `.?` - Force Unwrap (Unsafe)

**Panics if null** - use only when you're certain:

```zig
const maybe_value: ?i32 = getValue();
const value = maybe_value.?;  // Crashes if null!

// Safer alternative:
const value = maybe_value orelse unreachable;
```

**When to use `.?`:**
- Never in production code
- Only in tests or when logic guarantees non-null
- Better to use `orelse unreachable` for clarity

## Checking for Null

### Direct Comparison

```zig
const maybe_age: ?i32 = getAge();

if (maybe_age == null) {
    std.debug.print("No age\n", .{});
}

if (maybe_age != null) {
    std.debug.print("Has age\n", .{});
}
```

### With Unwrapping (Better)

```zig
if (maybe_age) |age| {
    std.debug.print("Age is {}\n", .{age});
} else {
    std.debug.print("No age\n", .{});
}
```

## Common Patterns

### Pattern 1: Return Early on Null

```zig
fn processUser(id: u32) !void {
    const user = findUser(id) orelse return error.UserNotFound;
    
    // user is guaranteed to exist here
    std.debug.print("Processing {s}\n", .{user.name});
}
```

### Pattern 2: Chain Optionals

```zig
fn getUserEmail(user_id: u32) ?[]const u8 {
    const user = findUser(user_id) orelse return null;
    const profile = user.profile orelse return null;
    return profile.email;
}
```

### Pattern 3: Convert to Error Union

```zig
fn getUserOrError(id: u32) !User {
    return findUser(id) orelse error.UserNotFound;
}
```

### Pattern 4: Iterator Pattern

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

// Usage:
var iter = Iterator{ .index = 0, .items = &[_]i32{1, 2, 3} };
while (iter.next()) |item| {
    std.debug.print("{}\n", .{item});
}
```

### Pattern 5: Optional Fields in Structs

```zig
const User = struct {
    id: u32,
    name: []const u8,
    email: ?[]const u8,  // Email is optional
    age: ?u32,           // Age is optional
};

const user = User{
    .id = 1,
    .name = "Alice",
    .email = null,      // No email
    .age = 25,          // Has age
};

// Access with orelse
const email = user.email orelse "no-email@example.com";
```

### Pattern 6: Optional Pointers

```zig
fn findInList(list: []const i32, target: i32) ?*const i32 {
    for (list) |*item| {
        if (item.* == target) return item;
    }
    return null;
}

// Usage:
const numbers = [_]i32{1, 2, 3, 4, 5};
if (findInList(&numbers, 3)) |ptr| {
    std.debug.print("Found: {}\n", .{ptr.*});
}
```

## Optional vs Error Union

### Optional: `?T` - Value Might Not Exist

No error, just absence:

```zig
fn findFirst(list: []i32, predicate: fn(i32) bool) ?i32 {
    for (list) |item| {
        if (predicate(item)) return item;
    }
    return null;  // Not found, but not an error
}
```

### Error Union: `!T` - Operation Might Fail

Failure with a reason:

```zig
fn readFile(path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    // File not found is an ERROR, not just absence
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024);
}
```

### Combined: `!?T` - Can Fail OR Return Nothing

```zig
fn searchDatabase(query: []const u8) !?User {
    // Returns:
    // - error.ConnectionFailed if database is down (error)
    // - null if query succeeded but no results (optional)
    // - User if found (success with value)
    
    const db = try connectToDatabase();  // Can error
    defer db.close();
    
    return db.findUser(query);  // Can return null (not found)
}

// Usage:
const maybe_user = searchDatabase("Alice") catch |err| {
    std.debug.print("Database error: {}\n", .{err});
    return;
};

if (maybe_user) |user| {
    std.debug.print("Found: {s}\n", .{user.name});
} else {
    std.debug.print("No results\n", .{});
}
```

## Modifying Optional Values

### Using Pointer Unwrapping

```zig
var maybe_count: ?i32 = 5;

if (&maybe_count) |*count_ptr| {
    count_ptr.* += 1;
}

std.debug.print("Count: {?}\n", .{maybe_count});  // 6
```

### Setting to Null

```zig
var user: ?User = getUser();
user = null;  // Clear the value
```

### Conditional Assignment

```zig
var result: ?i32 = null;

if (shouldCalculate()) {
    result = calculate();
}

// Use result
const final_value = result orelse 0;
```

## Testing with Optionals

```zig
test "findUser returns user when found" {
    const user = findUser(1);
    try std.testing.expect(user != null);
    try std.testing.expectEqualStrings("Alice", user.?.name);
}

test "findUser returns null when not found" {
    const user = findUser(999);
    try std.testing.expectEqual(@as(?User, null), user);
}

test "iterator eventually returns null" {
    var iter = makeIterator();
    
    _ = iter.next();
    _ = iter.next();
    _ = iter.next();
    
    try std.testing.expectEqual(@as(?i32, null), iter.next());
}
```

## Formatting Optionals

```zig
const maybe_value: ?i32 = 42;

// Use {?} for optionals
std.debug.print("Value: {?}\n", .{maybe_value});  // "Value: 42"

const nothing: ?i32 = null;
std.debug.print("Value: {?}\n", .{nothing});      // "Value: null"
```

## Common Mistakes

### ❌ Using `.?` without checking:
```zig
const value = maybe_value.?;  // Crashes if null!
```
**Fix:** Use `orelse` or `if` unwrapping

### ❌ Comparing unwrapped value to null:
```zig
if (maybe_value) |value| {
    if (value == null) { ... }  // Error! value is already unwrapped
}
```
**Fix:** Check before unwrapping

### ❌ Not handling null case:
```zig
const user = findUser(id);
std.debug.print("{s}\n", .{user.name});  // Error! user might be null
```
**Fix:** Unwrap first
```zig
if (findUser(id)) |user| {
    std.debug.print("{s}\n", .{user.name});
}
```

### ❌ Unnecessary optionals:
```zig
fn divide(a: i32, b: i32) ?i32 {
    if (b == 0) return null;
    return @divTrunc(a, b);
}
```
**Fix:** Use error union instead - this is an error, not absence
```zig
fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
```

## Advanced: Optional Slices

```zig
const maybe_slice: ?[]const u8 = getSlice();

// Check both null and empty
if (maybe_slice) |slice| {
    if (slice.len > 0) {
        std.debug.print("First char: {c}\n", .{slice[0]});
    }
}

// Or combine
const slice = maybe_slice orelse &[_]u8{};  // Empty slice as default
```

## Optional in Switch

```zig
const status: ?Status = getStatus();

const message = switch (status) {
    .active => "Active",
    .inactive => "Inactive",
    null => "Unknown",
};
```

## Real-World Example: ArrayList

```zig
pub fn get(self: Self, index: usize) !T {
    if (index >= self.elements.len) return error.IndexOutOfBounds;
    return self.elements[index];
}

pub fn pop(self: *Self) ?T {
    if (self.elements.len == 0) return null;
    
    self.elements.len -= 1;
    return self.elements[self.elements.len];
}

// Usage:
var list = ArrayList(i32).init(allocator, .{});
try list.add(42);

// get returns error union (can fail)
const value = try list.get(0);

// pop returns optional (might be empty, not an error)
if (list.pop()) |value| {
    std.debug.print("Popped: {}\n", .{value});
}
```

## Summary Table

| Pattern | Syntax | Use When | Example |
|---------|--------|----------|---------|
| Default value | `opt orelse default` | Want fallback | `age orelse 0` |
| Return early | `opt orelse return` | Null is error condition | `user orelse return` |
| If unwrap | `if (opt) \|val\| { }` | Conditional execution | Check before use |
| While unwrap | `while (opt) \|val\| { }` | Loop until null | Iterators |
| Force unwrap | `opt.?` | **Avoid!** Crashes if null | Tests only |
| Check null | `opt == null` | Need to know if null | Comparisons |
| Pointer unwrap | `if (&opt) \|*ptr\| { }` | Modify optional | Increment value |

## Best Practices

1. **Use `?T` for absence, `!T` for errors** - different semantics
2. **Prefer `orelse` for defaults** - clear and concise
3. **Use `if` unwrapping for conditional logic** - safe and readable
4. **Avoid `.?` in production code** - crashes on null
5. **Document when functions return null** - explain what null means
6. **Test null cases** - verify null handling works

## Key Takeaway

**Optionals make null explicit and safe.** You can't accidentally access a null value - the compiler forces you to handle it. Use `orelse` for defaults, `if` unwrapping for conditional logic, and `while` unwrapping for iteration. Optionals represent **absence without error**, while error unions represent **failure with a reason**.
