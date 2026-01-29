# MongoDB Driver for MoonBit

An async MongoDB driver for MoonBit with a simple JSON-based API.

## Features

- **Async/Await API** - Built on `moonbitlang/async` for non-blocking operations
- **JSON-First Design** - Use native MoonBit JSON literals for all documents
- **Full CRUD Operations** - Insert, query, update, and delete documents
- **Aggregation Pipelines** - Complex data processing with pipeline stage helpers
- **Cursor Support** - Efficient iteration over large result sets with batching
- **Index Management** - Create, list, and drop indexes with full options support
- **Bulk Operations** - Batch multiple write operations for efficiency
- **Change Streams** - Watch real-time changes on collections and databases
- **Atomic Operations** - Find-and-modify operations for atomic updates
- **Extended JSON** - Automatic handling of ObjectId, DateTime, Int64 types
- **Binary Wire Protocol** - Native OP_MSG implementation for MongoDB 3.6+

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "allain/mongodb": "0.1.0",
    "moonbitlang/async": "0.2.1"
  }
}
```

Add to your `moon.pkg.json`:

```json
{
  "import": [
    "allain/mongodb",
    "moonbitlang/async"
  ]
}
```

For advanced use cases requiring direct BSON access, also import `allain/mongodb/types`.

Run with native target (required for async TCP):

```bash
moon run <your-package> --target native
```

## Usage Examples

### Connecting to MongoDB

```moonbit
fn main {
  @async.with_event_loop(run) catch { e => println("Error: \{e}") }
}

async fn run(_group : @async.TaskGroup[Unit]) -> Unit raise Error {
  // Connect with host and port
  let client = @mongodb.Client::connect("localhost", 27017)!

  // Or connect with URI
  let client = @mongodb.Client::connect_uri("mongodb://localhost:27017/mydb")!

  // Get database and collection handles
  let db = client.database("mydb")
  let users = db.collection("users")

  // ... perform operations ...

  client.close()
}
```

### Inserting Documents

```moonbit
// Insert a single document
let result = users.insert_one({ "name": "Alice", "age": 30, "city": "NYC" })!
println("Inserted: \{result.inserted_count}")

// Insert multiple documents
let result = users.insert_many([
  { "name": "Bob", "age": 25 },
  { "name": "Charlie", "age": 35 },
])!
```

### Querying Documents

```moonbit
// Find all documents
let all_users = users.find({})!

// Find with filter
let adults = users.find({ "age": { "$gte": 18 } })!

// Find with limit, skip, and sort
let top_users = users.find(
  { "active": true },
  limit=10,
  skip=0,
  sort={ "score": -1 },
)!

// Find one document
match users.find_one({ "name": "Alice" })! {
  Some(user) => println(user.stringify())
  None => println("Not found")
}

// Count documents
let count = users.count_documents({ "status": "active" })!
```

### Updating Documents

```moonbit
// Update one document
let result = users.update_one(
  { "name": "Alice" },
  { "$set": { "age": 31 } },
)!
println("Modified: \{result.modified_count}")

// Update with upsert (insert if not found)
users.update_one(
  { "name": "Dave" },
  { "$set": { "age": 28 } },
  upsert=true,
)!

// Update multiple documents
users.update_many(
  { "status": "pending" },
  { "$set": { "status": "processed" } },
)!

// Replace a document entirely
users.replace_one(
  { "name": "Alice" },
  { "name": "Alice", "age": 32, "city": "LA" },
)!
```

### Deleting Documents

```moonbit
// Delete one document
let result = users.delete_one({ "name": "Alice" })!
println("Deleted: \{result.deleted_count}")

// Delete multiple documents
users.delete_many({ "status": "inactive" })!
```

### Atomic Find-and-Modify

```moonbit
// Find and update atomically, returning the new document
let updated = users.find_one_and_update(
  { "name": "Alice" },
  { "$inc": { "visits": 1 } },
  return_new=true,
)!
```

### Aggregation Pipelines

```moonbit
// Using pipeline stage helpers
let results = users.aggregate([
  @mongodb.match_stage({ "status": "active" }),
  @mongodb.group_stage(
    { "city": "$city" },
    { "count": { "$sum": 1 }, "avgAge": { "$avg": "$age" } },
  ),
  @mongodb.sort_stage({ "count": -1 }),
  @mongodb.limit_stage(10),
])!

// Available pipeline stages:
// match_stage, group_stage, sort_stage, limit_stage, skip_stage
// project_stage, lookup_stage, unwind_stage, count_stage
// add_fields_stage, set_stage, unset_stage, replace_root_stage
// sample_stage, out_stage, merge_stage, facet_stage
// bucket_stage, bucket_auto_stage, sort_by_count_stage
```

### Index Management

```moonbit
// Create a simple index
users.create_index({ "email": 1 })!

// Create a unique index with options
users.create_index(
  { "username": 1 },
  options={
    name: Some("username_unique"),
    unique: Some(true),
    sparse: None,
    expire_after_seconds: None,
    partial_filter: None,
    background: None,
  },
)!

// Create a TTL index (auto-expire documents)
users.create_index(
  { "createdAt": 1 },
  options={
    name: None,
    unique: None,
    sparse: None,
    expire_after_seconds: Some(3600), // 1 hour
    partial_filter: None,
    background: None,
  },
)!

// List all indexes
let indexes = users.list_indexes()!
for idx in indexes {
  println("Index: \{idx.name}")
}

// Drop an index
users.drop_index("email_1")!
```

### Bulk Operations

```moonbit
let operations = [
  @mongodb.BulkOperation::insert({ "name": "User1" }),
  @mongodb.BulkOperation::insert({ "name": "User2" }),
  @mongodb.BulkOperation::update_one(
    { "name": "Alice" },
    { "$set": { "updated": true } },
  ),
  @mongodb.BulkOperation::delete_one({ "status": "deleted" }),
]

let result = users.bulk_write(operations)!
println("Inserted: \{result.inserted_count}, Modified: \{result.modified_count}")
```

### Change Streams

```moonbit
// Watch for changes on a collection
let stream = users.watch()!

// Process change events
stream.for_each(fn(change) {
  match change {
    { "operationType": String(op), .. } => println("Operation: \{op}")
    _ => ()
  }
  true // Return false to stop watching
})!

stream.close()
```

### Database Management

```moonbit
// List all databases
let databases = client.list_databases()!
for db in databases {
  println("\{db.name}: \{db.size_on_disk} bytes")
}

// List collections in a database
let collections = db.list_collection_names()!

// Create a capped collection
db.create_collection("logs", capped=true, size=10485760L, max=5000L)!

// Drop a collection
db.drop_collection("old_data")!

// Get database stats
let stats = db.stats()!
```

### Working with Query Results

Query results are JSON values that can be pattern matched:

```moonbit
let results = users.find({})!

for user in results {
  match user {
    { "name": String(name), "age": Number(age, ..), .. } =>
      println("\{name} is \{age.to_int()} years old")
    _ => println("Unknown format")
  }
}
```

### MongoDB Query Operators

```moonbit
// Comparison
{ "age": { "$gt": 25 } }       // greater than
{ "age": { "$gte": 25 } }      // greater than or equal
{ "age": { "$lt": 30 } }       // less than
{ "age": { "$lte": 30 } }      // less than or equal
{ "age": { "$ne": 25 } }       // not equal
{ "age": { "$in": [25, 30] } } // in array

// Logical
{ "$and": [{ "age": { "$gte": 25 } }, { "active": true }] }
{ "$or": [{ "name": "Alice" }, { "name": "Bob" }] }

// Element
{ "email": { "$exists": true } }

// Array
{ "tags": { "$all": ["mongodb", "database"] } }
```

### MongoDB Update Operators

```moonbit
{ "$set": { "name": "Alice", "age": 31 } }   // Set fields
{ "$unset": { "temp": "" } }                 // Remove fields
{ "$inc": { "count": 1 } }                   // Increment
{ "$push": { "tags": "new" } }               // Push to array
{ "$pull": { "tags": "old" } }               // Remove from array
{ "$addToSet": { "tags": "unique" } }        // Add unique to array
```

### Error Handling

```moonbit
///|
let result = users.insert_one({ "name": "Alice" }) catch {
  @mongodb.MongoError::ConnectionFailed(msg) => {
    println("Connection failed: \{msg}")
    return
  }
  @mongodb.MongoError::CommandFailed(msg) => {
    println("Command failed: \{msg}")
    return
  }
  @mongodb.MongoError::WriteError(msg) => {
    println("Write error: \{msg}")
    return
  }
  e => {
    println("Error: \{e}")
    return
  }
}
```

**Error type:** `@mongodb.MongoError` with variants: `ConnectionFailed`, `SendFailed`, `ReceiveFailed`, `HandshakeFailed`, `InvalidResponse`, `ProtocolError`, `CommandFailed`, `WriteError`, `Closed`

### Extended JSON Types

Special types are represented using MongoDB Extended JSON:

| BSON Type | Extended JSON Format |
|-----------|---------------------|
| ObjectId | `{ "$oid": "507f1f77bcf86cd799439011" }` |
| DateTime | `{ "$date": 1704067200000 }` |
| Int64 | `{ "$numberLong": "9223372036854775807" }` |
| Int32 | `{ "$numberInt": "42" }` |

```moonbit
// Query by ObjectId
let user = users.find_one({ "_id": { "$oid": "507f1f77bcf86cd799439011" } })!
```

## Requirements

- MoonBit toolchain
- Native target (required for async TCP)
- MongoDB 3.6+ (uses OP_MSG wire protocol)

## Running Tests

The integration tests require a running MongoDB instance on `localhost:27017`.

### Using the test script (recommended)

The test script automatically starts a MongoDB container, runs tests, and cleans up:

```bash
./scripts/test.sh
```

Pass additional options to `moon test`:

```bash
./scripts/test.sh --update  # Update snapshots
```

### Manual setup

If you prefer to manage MongoDB yourself:

```bash
# Start MongoDB (e.g., via Docker)
docker run -d -p 27017:27017 mongo:7

# Run tests
moon test --target native
```

## License

Apache-2.0 License - see [LICENSE](LICENSE) for details.
