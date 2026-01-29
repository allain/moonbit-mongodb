///|
/// Async MongoDB client
pub struct Client {
  conn : Connection
}

///|
/// Create a new async client and connect
pub async fn Client::connect(
  host : String,
  port : Int,
) -> Client raise MongoError {
  let conn = Connection::connect(host, port)
  { conn, }
}

///|
/// Connect using a URI
pub async fn Client::connect_uri(uri : String) -> Client raise MongoError {
  // Parse URI: mongodb://host:port/database
  guard uri.has_prefix("mongodb://") else {
    raise MongoError::ConnectionFailed(
      "Invalid URI scheme, expected mongodb://",
    )
  }
  let without_scheme = uri[10:].to_string() catch { _ => "" }

  // Split on / to get host:port and database
  let parts : Array[String] = []
  for p in without_scheme.split("/") {
    parts.push(p.to_string())
  }
  if parts.length() == 0 {
    raise MongoError::ConnectionFailed("Invalid URI format")
  }
  let host_port = parts[0]

  // Parse host:port (skip auth for now)
  let hp_parts : Array[String] = []
  for p in host_port.split("@") {
    hp_parts.push(p.to_string())
  }
  let host_port_str = if hp_parts.length() > 1 {
    hp_parts[1]
  } else {
    hp_parts[0]
  }
  let hp : Array[String] = []
  for p in host_port_str.split(":") {
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
  Client::connect(host, port)
}

///|
/// Get a database handle
pub fn Client::database(self : Client, name : String) -> Database {
  { client: self, name }
}

///|
/// Close the client connection
pub fn Client::close(self : Client) -> Unit {
  self.conn.close()
}

///|
/// Async database handle
pub struct Database {
  client : Client
  name : String
}

///|
/// Get a collection handle
pub fn Database::collection(self : Database, name : String) -> Collection {
  { db: self, name }
}

///|
/// Get database name
pub fn Database::name(self : Database) -> String {
  self.name
}

///|
/// Run a database command
pub async fn Database::run_command(
  self : Database,
  command : @types.BsonValue,
) -> @types.BsonValue raise MongoError {
  // Add $db field if not present
  let cmd = match command.get("$db") {
    Some(_) => command
    None => command.set("$db", @types.bson_string(self.name))
  }
  self.client.conn.send_command(cmd)
}

///|
/// Async collection handle
pub struct Collection {
  db : Database
  name : String
}

///|
/// Check if a response indicates command failure
fn check_command_response(response : @types.BsonValue) -> Unit raise MongoError {
  // Check ok field
  let ok = match response.get("ok") {
    Some(@types.Double(v)) => v == 1.0
    Some(@types.Int32(v)) => v == 1
    _ => false
  }
  if not(ok) {
    let errmsg = match response.get("errmsg") {
      Some(@types.String(msg)) => msg
      _ => "Unknown error"
    }
    let code = match response.get("code") {
      Some(@types.Int32(c)) => " (code: \{c})"
      _ => ""
    }
    raise MongoError::CommandFailed("\{errmsg}\{code}")
  }

  // Check for write errors
  match response.get("writeErrors") {
    Some(@types.Array(errors)) =>
      if errors.length() > 0 {
        match errors[0] {
          @types.Document(err_map) => {
            let errmsg = match err_map.get("errmsg") {
              Some(@types.String(msg)) => msg
              _ => "Write error"
            }
            let code = match err_map.get("code") {
              Some(@types.Int32(c)) => " (code: \{c})"
              _ => ""
            }
            raise MongoError::WriteError("\{errmsg}\{code}")
          }
          _ => ()
        }
      }
    _ => ()
  }

  // Check for write concern error
  match response.get("writeConcernError") {
    Some(@types.Document(wce_map)) => {
      let errmsg = match wce_map.get("errmsg") {
        Some(@types.String(msg)) => msg
        _ => "Write concern error"
      }
      raise MongoError::WriteError("WriteConcern: \{errmsg}")
    }
    _ => ()
  }
}

///|
/// Get collection name
pub fn Collection::name(self : Collection) -> String {
  self.name
}

///|
/// Get full namespace (db.collection)
pub fn Collection::full_name(self : Collection) -> String {
  "\{self.db.name}.\{self.name}"
}

///|
/// Insert result
pub struct InsertResult {
  acknowledged : Bool
  inserted_count : Int
}

///|
/// Update result
pub struct UpdateResult {
  acknowledged : Bool
  matched_count : Int
  modified_count : Int
  upserted_id : @types.BsonValue?
}

///|
/// Delete result
pub struct DeleteResult {
  acknowledged : Bool
  deleted_count : Int
}

///|
/// Insert one document
pub async fn Collection::insert_one(
  self : Collection,
  document : @types.BsonValue,
) -> InsertResult raise MongoError {
  self.insert_many([document])
}

///|
/// Insert multiple documents
pub async fn Collection::insert_many(
  self : Collection,
  documents : Array[@types.BsonValue],
) -> InsertResult raise MongoError {
  let doc_array = @types.bson_array()
  for doc in documents {
    ignore(doc_array.push(doc))
  }
  let cmd = @types.bson_document()
    .set("insert", @types.bson_string(self.name))
    .set("documents", doc_array)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let n = match response.get("n") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  { acknowledged: true, inserted_count: n }
}

///|
/// Find documents with options
pub async fn Collection::find(
  self : Collection,
  filter : @types.BsonValue,
  limit? : Int,
  skip? : Int,
  sort? : @types.BsonValue,
  projection? : @types.BsonValue,
  hint? : @types.BsonValue,
  batch_size? : Int,
  max_time_ms? : Int,
) -> Cursor raise MongoError {
  let cmd = @types.bson_document()
    .set("find", @types.bson_string(self.name))
    .set("filter", filter)
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match limit {
    Some(l) => cmd.set("limit", @types.bson_int32(l))
    None => cmd
  }
  let cmd = match skip {
    Some(s) => cmd.set("skip", @types.bson_int32(s))
    None => cmd
  }
  let cmd = match sort {
    Some(s) => cmd.set("sort", s)
    None => cmd
  }
  let cmd = match projection {
    Some(p) => cmd.set("projection", p)
    None => cmd
  }
  let cmd = match hint {
    Some(h) => cmd.set("hint", h)
    None => cmd
  }
  let cmd = match batch_size {
    Some(b) => cmd.set("batchSize", @types.bson_int32(b))
    None => cmd
  }
  let cmd = match max_time_ms {
    Some(t) => cmd.set("maxTimeMS", @types.bson_int32(t))
    None => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)

  // Extract cursor info
  match response.get("cursor") {
    Some(@types.Document(cursor_map)) => {
      let cursor_id = match cursor_map.get("id") {
        Some(@types.Int64(id)) => id
        Some(@types.Int32(id)) => id.to_int64()
        _ => 0L
      }
      let docs = match cursor_map.get("firstBatch") {
        Some(@types.Array(arr)) => arr
        _ => []
      }
      Cursor::new(self, docs, cursor_id)
    }
    _ => raise MongoError::InvalidResponse("No cursor in find response")
  }
}

///|
/// Find one document
pub async fn Collection::find_one(
  self : Collection,
  filter : @types.BsonValue,
) -> @types.BsonValue? raise MongoError {
  let cursor = self.find(filter, limit=1)
  cursor.next()
}

///|
/// Update one document
pub async fn Collection::update_one(
  self : Collection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  upsert? : Bool = false,
) -> UpdateResult raise MongoError {
  let update_doc = @types.bson_document()
    .set("q", filter)
    .set("u", update)
    .set("upsert", @types.bson_bool(upsert))
    .set("multi", @types.bson_bool(false))
  let updates = @types.bson_array().push(update_doc)
  let cmd = @types.bson_document()
    .set("update", @types.bson_string(self.name))
    .set("updates", updates)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let n = match response.get("n") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let n_modified = match response.get("nModified") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let upserted_id = match response.get("upserted") {
    Some(@types.Array(arr)) =>
      if arr.length() > 0 {
        match arr[0] {
          @types.Document(doc) => doc.get("_id")
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
  {
    acknowledged: true,
    matched_count: n,
    modified_count: n_modified,
    upserted_id,
  }
}

///|
/// Update many documents
pub async fn Collection::update_many(
  self : Collection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  upsert? : Bool = false,
) -> UpdateResult raise MongoError {
  let update_doc = @types.bson_document()
    .set("q", filter)
    .set("u", update)
    .set("upsert", @types.bson_bool(upsert))
    .set("multi", @types.bson_bool(true))
  let updates = @types.bson_array().push(update_doc)
  let cmd = @types.bson_document()
    .set("update", @types.bson_string(self.name))
    .set("updates", updates)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let n = match response.get("n") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let n_modified = match response.get("nModified") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let upserted_id = match response.get("upserted") {
    Some(@types.Array(arr)) =>
      if arr.length() > 0 {
        match arr[0] {
          @types.Document(doc) => doc.get("_id")
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
  {
    acknowledged: true,
    matched_count: n,
    modified_count: n_modified,
    upserted_id,
  }
}

///|
/// Delete one document
pub async fn Collection::delete_one(
  self : Collection,
  filter : @types.BsonValue,
) -> DeleteResult raise MongoError {
  self.delete_internal(filter, 1)
}

///|
/// Delete many documents
pub async fn Collection::delete_many(
  self : Collection,
  filter : @types.BsonValue,
) -> DeleteResult raise MongoError {
  self.delete_internal(filter, 0)
}

///|
/// Internal delete implementation
async fn Collection::delete_internal(
  self : Collection,
  filter : @types.BsonValue,
  limit : Int,
) -> DeleteResult raise MongoError {
  let delete_doc = @types.bson_document()
    .set("q", filter)
    .set("limit", @types.bson_int32(limit))
  let deletes = @types.bson_array().push(delete_doc)
  let cmd = @types.bson_document()
    .set("delete", @types.bson_string(self.name))
    .set("deletes", deletes)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let n = match response.get("n") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  { acknowledged: true, deleted_count: n }
}

///|
/// Count documents matching a filter
pub async fn Collection::count_documents(
  self : Collection,
  filter : @types.BsonValue,
) -> Int raise MongoError {
  let cmd = @types.bson_document()
    .set("count", @types.bson_string(self.name))
    .set("query", filter)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  match response.get("n") {
    Some(@types.Int32(n)) => n
    Some(@types.Int64(n)) => n.to_int()
    Some(@types.Double(n)) => n.to_int()
    _ => 0
  }
}

///|
/// Estimated document count (uses collection metadata, faster but approximate)
pub async fn Collection::estimated_count(
  self : Collection,
) -> Int raise MongoError {
  let cmd = @types.bson_document()
    .set("count", @types.bson_string(self.name))
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  match response.get("n") {
    Some(@types.Int32(n)) => n
    Some(@types.Int64(n)) => n.to_int()
    Some(@types.Double(n)) => n.to_int()
    _ => 0
  }
}

///|
/// Get distinct values for a field
pub async fn Collection::distinct(
  self : Collection,
  field : String,
  filter? : @types.BsonValue,
) -> Array[@types.BsonValue] raise MongoError {
  let cmd = @types.bson_document()
    .set("distinct", @types.bson_string(self.name))
    .set("key", @types.bson_string(field))
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match filter {
    Some(f) => cmd.set("query", f)
    None => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  match response.get("values") {
    Some(@types.Array(values)) => values
    _ => []
  }
}

///|
/// Run an aggregation pipeline
pub async fn Collection::aggregate(
  self : Collection,
  pipeline : Array[@types.BsonValue],
  batch_size? : Int,
  max_time_ms? : Int,
  allow_disk_use? : Bool,
) -> Cursor raise MongoError {
  let pipeline_arr = @types.bson_array()
  for stage in pipeline {
    ignore(pipeline_arr.push(stage))
  }
  let cursor_opts = @types.bson_document()
  let cursor_opts = match batch_size {
    Some(b) => cursor_opts.set("batchSize", @types.bson_int32(b))
    None => cursor_opts
  }
  let cmd = @types.bson_document()
    .set("aggregate", @types.bson_string(self.name))
    .set("pipeline", pipeline_arr)
    .set("cursor", cursor_opts)
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match max_time_ms {
    Some(t) => cmd.set("maxTimeMS", @types.bson_int32(t))
    None => cmd
  }
  let cmd = match allow_disk_use {
    Some(true) => cmd.set("allowDiskUse", @types.bson_bool(true))
    _ => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)

  // Extract cursor info
  match response.get("cursor") {
    Some(@types.Document(cursor_map)) => {
      let cursor_id = match cursor_map.get("id") {
        Some(@types.Int64(id)) => id
        Some(@types.Int32(id)) => id.to_int64()
        _ => 0L
      }
      let docs = match cursor_map.get("firstBatch") {
        Some(@types.Array(arr)) => arr
        _ => []
      }
      Cursor::new(self, docs, cursor_id)
    }
    _ => raise MongoError::InvalidResponse("No cursor in aggregate response")
  }
}

///|
/// Return document enum - controls whether findAndModify returns old or new document
pub enum ReturnDocument {
  Before
  After
}

///|
/// Create Before return document option
pub fn ReturnDocument::before() -> ReturnDocument {
  Before
}

///|
/// Create After return document option
pub fn ReturnDocument::after() -> ReturnDocument {
  After
}

///|
/// Find and update a single document atomically
pub async fn Collection::find_one_and_update(
  self : Collection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  return_document? : ReturnDocument,
  upsert? : Bool,
  projection? : @types.BsonValue,
  sort? : @types.BsonValue,
) -> @types.BsonValue? raise MongoError {
  let cmd = @types.bson_document()
    .set("findAndModify", @types.bson_string(self.name))
    .set("query", filter)
    .set("update", update)
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match return_document {
    Some(After) => cmd.set("new", @types.bson_bool(true))
    Some(Before) => cmd.set("new", @types.bson_bool(false))
    None => cmd
  }
  let cmd = match upsert {
    Some(true) => cmd.set("upsert", @types.bson_bool(true))
    _ => cmd
  }
  let cmd = match projection {
    Some(p) => cmd.set("fields", p)
    None => cmd
  }
  let cmd = match sort {
    Some(s) => cmd.set("sort", s)
    None => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  response.get("value")
}

///|
/// Find and replace a single document atomically
pub async fn Collection::find_one_and_replace(
  self : Collection,
  filter : @types.BsonValue,
  replacement : @types.BsonValue,
  return_document? : ReturnDocument,
  upsert? : Bool,
) -> @types.BsonValue? raise MongoError {
  let cmd = @types.bson_document()
    .set("findAndModify", @types.bson_string(self.name))
    .set("query", filter)
    .set("update", replacement)
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match return_document {
    Some(After) => cmd.set("new", @types.bson_bool(true))
    _ => cmd
  }
  let cmd = match upsert {
    Some(true) => cmd.set("upsert", @types.bson_bool(true))
    _ => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  response.get("value")
}

///|
/// Find and delete a single document atomically
pub async fn Collection::find_one_and_delete(
  self : Collection,
  filter : @types.BsonValue,
  projection? : @types.BsonValue,
  sort? : @types.BsonValue,
) -> @types.BsonValue? raise MongoError {
  let cmd = @types.bson_document()
    .set("findAndModify", @types.bson_string(self.name))
    .set("query", filter)
    .set("remove", @types.bson_bool(true))
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match projection {
    Some(p) => cmd.set("fields", p)
    None => cmd
  }
  let cmd = match sort {
    Some(s) => cmd.set("sort", s)
    None => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  response.get("value")
}

///|
/// Replace a single document
pub async fn Collection::replace_one(
  self : Collection,
  filter : @types.BsonValue,
  replacement : @types.BsonValue,
  upsert? : Bool,
) -> UpdateResult raise MongoError {
  let update_doc = @types.bson_document()
    .set("q", filter)
    .set("u", replacement)
    .set("upsert", @types.bson_bool(upsert.unwrap_or(false)))
    .set("multi", @types.bson_bool(false))
  let updates = @types.bson_array().push(update_doc)
  let cmd = @types.bson_document()
    .set("update", @types.bson_string(self.name))
    .set("updates", updates)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let n = match response.get("n") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let n_modified = match response.get("nModified") {
    Some(@types.Int32(v)) => v
    _ => 0
  }
  let upserted_id = match response.get("upserted") {
    Some(@types.Array(arr)) =>
      if arr.length() > 0 {
        match arr[0] {
          @types.Document(doc) => doc.get("_id")
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
  {
    acknowledged: true,
    matched_count: n,
    modified_count: n_modified,
    upserted_id,
  }
}

// ============ Collection Management ============

///|
/// Rename the collection
pub async fn Collection::rename(
  self : Collection,
  new_name : String,
  drop_target? : Bool,
) -> Unit raise MongoError {
  let cmd = @types.bson_document()
    .set("renameCollection", @types.bson_string(self.full_name()))
    .set("to", @types.bson_string("\{self.db.name}.\{new_name}"))
    .set("$db", @types.bson_string("admin"))
  let cmd = match drop_target {
    Some(true) => cmd.set("dropTarget", @types.bson_bool(true))
    _ => cmd
  }
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
}

///|
/// Drop the collection
pub async fn Collection::drop(self : Collection) -> Unit raise MongoError {
  let cmd = @types.bson_document()
    .set("drop", @types.bson_string(self.name))
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  // Ignore "ns not found" error (collection doesn't exist)
  match response.get("ok") {
    Some(@types.Double(v)) if v == 1.0 => ()
    Some(@types.Int32(v)) if v == 1 => ()
    _ =>
      match response.get("code") {
        Some(@types.Int32(26)) => () // NamespaceNotFound - OK
        _ => check_command_response(response)
      }
  }
}

// ============ Database Management ============

///|
/// Collection info returned by list_collections
pub struct CollectionInfo {
  name : String
  type_ : String
  options : @types.BsonValue
}

///|
/// Create a new collection
pub async fn Database::create_collection(
  self : Database,
  name : String,
  capped? : Bool,
  size? : Int64,
  max? : Int64,
  validator? : @types.BsonValue,
  validation_level? : String,
  validation_action? : String,
) -> Collection raise MongoError {
  let cmd = @types.bson_document()
    .set("create", @types.bson_string(name))
    .set("$db", @types.bson_string(self.name))
  let cmd = match capped {
    Some(true) => cmd.set("capped", @types.bson_bool(true))
    _ => cmd
  }
  let cmd = match size {
    Some(s) => cmd.set("size", @types.bson_int64(s))
    None => cmd
  }
  let cmd = match max {
    Some(m) => cmd.set("max", @types.bson_int64(m))
    None => cmd
  }
  let cmd = match validator {
    Some(v) => cmd.set("validator", v)
    None => cmd
  }
  let cmd = match validation_level {
    Some(l) => cmd.set("validationLevel", @types.bson_string(l))
    None => cmd
  }
  let cmd = match validation_action {
    Some(a) => cmd.set("validationAction", @types.bson_string(a))
    None => cmd
  }
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
  self.collection(name)
}

///|
/// Drop a collection by name
pub async fn Database::drop_collection(
  self : Database,
  name : String,
) -> Unit raise MongoError {
  let coll = self.collection(name)
  coll.drop()
}

///|
/// List all collections in the database
pub async fn Database::list_collections(
  self : Database,
  filter? : @types.BsonValue,
) -> Array[CollectionInfo] raise MongoError {
  let cmd = @types.bson_document()
    .set("listCollections", @types.bson_int32(1))
    .set("$db", @types.bson_string(self.name))
  let cmd = match filter {
    Some(f) => cmd.set("filter", f)
    None => cmd
  }
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
  let collections : Array[CollectionInfo] = []
  match response.get("cursor") {
    Some(@types.Document(cursor_map)) =>
      match cursor_map.get("firstBatch") {
        Some(@types.Array(arr)) =>
          for item in arr {
            match item {
              @types.Document(doc) => {
                let name = match doc.get("name") {
                  Some(@types.String(n)) => n
                  _ => ""
                }
                let type_ = match doc.get("type") {
                  Some(@types.String(t)) => t
                  _ => "collection"
                }
                let options = match doc.get("options") {
                  Some(o) => o
                  _ => @types.bson_document()
                }
                collections.push({ name, type_, options })
              }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  collections
}

///|
/// List collection names
pub async fn Database::list_collection_names(
  self : Database,
) -> Array[String] raise MongoError {
  let collections = self.list_collections()
  let names : Array[String] = []
  for coll in collections {
    names.push(coll.name)
  }
  names
}

///|
/// Drop the database
pub async fn Database::drop(self : Database) -> Unit raise MongoError {
  let cmd = @types.bson_document()
    .set("dropDatabase", @types.bson_int32(1))
    .set("$db", @types.bson_string(self.name))
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
}

///|
/// Get database statistics
pub async fn Database::stats(
  self : Database,
) -> @types.BsonValue raise MongoError {
  let cmd = @types.bson_document()
    .set("dbStats", @types.bson_int32(1))
    .set("$db", @types.bson_string(self.name))
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
  response
}

// ============ Client Management ============

///|
/// Database info returned by list_databases
pub struct DatabaseInfo {
  name : String
  size_on_disk : Int64
  empty : Bool
}

///|
/// List all databases
pub async fn Client::list_databases(
  self : Client,
) -> Array[DatabaseInfo] raise MongoError {
  let cmd = @types.bson_document()
    .set("listDatabases", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.conn.send_command(cmd)
  check_command_response(response)
  let databases : Array[DatabaseInfo] = []
  match response.get("databases") {
    Some(@types.Array(arr)) =>
      for item in arr {
        match item {
          @types.Document(doc) => {
            let name = match doc.get("name") {
              Some(@types.String(n)) => n
              _ => ""
            }
            let size_on_disk = match doc.get("sizeOnDisk") {
              Some(@types.Int64(s)) => s
              Some(@types.Int32(s)) => s.to_int64()
              Some(@types.Double(s)) => s.to_int64()
              _ => 0L
            }
            let empty = match doc.get("empty") {
              Some(@types.Boolean(e)) => e
              _ => false
            }
            databases.push({ name, size_on_disk, empty })
          }
          _ => ()
        }
      }
    _ => ()
  }
  databases
}

///|
/// List database names
pub async fn Client::list_database_names(
  self : Client,
) -> Array[String] raise MongoError {
  let databases = self.list_databases()
  let names : Array[String] = []
  for db in databases {
    names.push(db.name)
  }
  names
}

///|
/// Get server info
pub async fn Client::server_info(
  self : Client,
) -> @types.BsonValue raise MongoError {
  let cmd = @types.bson_document()
    .set("buildInfo", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.conn.send_command(cmd)
  check_command_response(response)
  response
}

///|
/// Ping the server
pub async fn Client::ping(self : Client) -> Bool raise MongoError {
  let cmd = @types.bson_document()
    .set("ping", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.conn.send_command(cmd)
  match response.get("ok") {
    Some(@types.Double(v)) => v == 1.0
    Some(@types.Int32(v)) => v == 1
    _ => false
  }
}
