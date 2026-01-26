///| MongoDB driver for MoonBit
///
/// This module provides an async MongoDB client with a simple JSON-based API.
/// No knowledge of BSON is required - just use regular JSON literals!
///
/// ## Quick Start
/// ```moonbit
/// async fn example() {
///   // Connect to MongoDB
///   let client = @async_client.AsyncClient::connect("localhost", 27017)!
///   let coll = client.database("mydb").collection("users")
///
///   // Insert documents using JSON literals
///   coll.insert({ "name": "Alice", "age": 30 })!
///   coll.insert_all([
///     { "name": "Bob", "age": 25 },
///     { "name": "Charlie", "age": 35 },
///   ])!
///
///   // Query documents - returns JSON
///   let users = coll.query({ "age": { "$gte": 25 } })!
///   for user in users {
///     match user {
///       { "name": String(name), .. } => println(name)
///       _ => ()
///     }
///   }
///
///   // Update documents
///   coll.modify_one({ "name": "Alice" }, { "$set": { "age": 31 } })!
///
///   // Delete documents
///   coll.remove_one({ "name": "Bob" })!
///
///   client.close()
/// }
/// ```
///
/// ## API Methods
/// - `insert(doc)` - Insert one document
/// - `insert_all(docs)` - Insert multiple documents
/// - `query(filter, limit?)` - Find documents, returns Array[Json]
/// - `query_one(filter)` - Find one document, returns Json?
/// - `modify_one(filter, update)` - Update one document
/// - `modify_all(filter, update)` - Update all matching documents
/// - `remove_one(filter)` - Delete one document
/// - `remove_all(filter)` - Delete all matching documents
/// - `count(filter)` - Count matching documents
///
/// ## Advanced BSON API
/// For advanced use cases (ObjectId, DateTime, Binary), use the BSON API:
/// - `@types.bson_document()`, `@types.bson_string()`, etc.
/// - `insert_one()`, `find()`, `update_one()`, `delete_one()`

///|
/// Create a BSON document
pub fn bson_document() -> @types.BsonValue {
  @types.bson_document()
}

///|
/// Create a BSON array
pub fn bson_array() -> @types.BsonValue {
  @types.bson_array()
}

///|
/// Create a BSON string
pub fn bson_string(s : String) -> @types.BsonValue {
  @types.bson_string(s)
}

///|
/// Create a BSON int32
pub fn bson_int32(v : Int) -> @types.BsonValue {
  @types.bson_int32(v)
}

///|
/// Create a BSON int64
pub fn bson_int64(v : Int64) -> @types.BsonValue {
  @types.bson_int64(v)
}

///|
/// Create a BSON double
pub fn bson_double(v : Double) -> @types.BsonValue {
  @types.bson_double(v)
}

///|
/// Create a BSON bool
pub fn bson_bool(b : Bool) -> @types.BsonValue {
  @types.bson_bool(b)
}

///|
/// Create a BSON null
pub fn bson_null() -> @types.BsonValue {
  @types.bson_null()
}

///|
/// Create a new ObjectId generator
pub fn new_object_id_generator(
  random_bytes : Bytes,
) -> @types.ObjectIdGenerator {
  @types.ObjectIdGenerator::new(random_bytes)
}

///|
/// Parse a MongoDB connection URI
/// Format: mongodb://[username:password@]host[:port][/database]
pub fn parse_uri(uri : String) -> (String, Int, String?)? {
  if not(uri.has_prefix("mongodb://")) {
    return None
  }
  let without_scheme = uri[10:].to_string() catch { _ => return None }

  // Find host and port
  let parts : Array[String] = []
  for p in without_scheme.split("/") {
    parts.push(p.to_string())
  }
  if parts.length() == 0 {
    return None
  }
  let host_port_str = parts[0]
  let database : String? = if parts.length() > 1 {
    Some(parts[1])
  } else {
    None
  }

  // Parse host:port (skip auth for now)
  let host_parts : Array[String] = []
  for p in host_port_str.split("@") {
    host_parts.push(p.to_string())
  }
  let host_port = if host_parts.length() > 1 {
    host_parts[1]
  } else {
    host_parts[0]
  }
  let hp : Array[String] = []
  for p in host_port.split(":") {
    hp.push(p.to_string())
  }
  let host = hp[0]
  let port = if hp.length() > 1 {
    @strconv.parse_int(hp[1]) catch {
      _ => 27017
    }
  } else {
    27017
  }
  Some((host, port, database))
}
