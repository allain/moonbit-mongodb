///|
/// Async MongoDB client
pub struct AsyncClient {
  conn : AsyncConnection
}

///|
/// Create a new async client and connect
pub async fn AsyncClient::connect(
  host : String,
  port : Int,
) -> AsyncClient raise AsyncConnectionError {
  let conn = AsyncConnection::connect(host, port)
  { conn, }
}

///|
/// Connect using a URI
pub async fn AsyncClient::connect_uri(
  uri : String,
) -> AsyncClient raise AsyncConnectionError {
  // Parse URI: mongodb://host:port/database
  guard uri.has_prefix("mongodb://") else {
    raise AsyncConnectionError::ConnectionFailed(
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
    raise AsyncConnectionError::ConnectionFailed("Invalid URI format")
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
  AsyncClient::connect(host, port)
}

///|
/// Get a database handle
pub fn AsyncClient::database(
  self : AsyncClient,
  name : String,
) -> AsyncDatabase {
  { client: self, name }
}

///|
/// Close the client connection
pub fn AsyncClient::close(self : AsyncClient) -> Unit {
  self.conn.close()
}

///|
/// Async database handle
pub struct AsyncDatabase {
  client : AsyncClient
  name : String
}

///|
/// Get a collection handle
pub fn AsyncDatabase::collection(
  self : AsyncDatabase,
  name : String,
) -> AsyncCollection {
  { db: self, name }
}

///|
/// Get database name
pub fn AsyncDatabase::name(self : AsyncDatabase) -> String {
  self.name
}

///|
/// Run a database command
pub async fn AsyncDatabase::run_command(
  self : AsyncDatabase,
  command : @types.BsonValue,
) -> @types.BsonValue raise AsyncConnectionError {
  // Add $db field if not present
  let cmd = match command.get("$db") {
    Some(_) => command
    None => command.set("$db", @types.bson_string(self.name))
  }
  self.client.conn.send_command(cmd)
}

///|
/// Async collection handle
pub struct AsyncCollection {
  db : AsyncDatabase
  name : String
}

///|
/// Check if a response indicates command failure
fn check_command_response(
  response : @types.BsonValue,
) -> Unit raise AsyncConnectionError {
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
    raise AsyncConnectionError::CommandFailed("\{errmsg}\{code}")
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
            raise AsyncConnectionError::WriteError("\{errmsg}\{code}")
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
      raise AsyncConnectionError::WriteError("WriteConcern: \{errmsg}")
    }
    _ => ()
  }
}

///|
/// Get collection name
pub fn AsyncCollection::name(self : AsyncCollection) -> String {
  self.name
}

///|
/// Get full namespace (db.collection)
pub fn AsyncCollection::full_name(self : AsyncCollection) -> String {
  "\{self.db.name}.\{self.name}"
}

///|
/// Insert result
pub struct AsyncInsertResult {
  acknowledged : Bool
  inserted_count : Int
}

///|
/// Update result
pub struct AsyncUpdateResult {
  acknowledged : Bool
  matched_count : Int
  modified_count : Int
  upserted_id : @types.BsonValue?
}

///|
/// Delete result
pub struct AsyncDeleteResult {
  acknowledged : Bool
  deleted_count : Int
}

///|
/// Insert one document
pub async fn AsyncCollection::insert_one(
  self : AsyncCollection,
  document : @types.BsonValue,
) -> AsyncInsertResult raise AsyncConnectionError {
  self.insert_many([document])
}

///|
/// Insert multiple documents
pub async fn AsyncCollection::insert_many(
  self : AsyncCollection,
  documents : Array[@types.BsonValue],
) -> AsyncInsertResult raise AsyncConnectionError {
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
pub async fn AsyncCollection::find(
  self : AsyncCollection,
  filter : @types.BsonValue,
  limit? : Int,
  skip? : Int,
  sort? : @types.BsonValue,
  projection? : @types.BsonValue,
  hint? : @types.BsonValue,
  batch_size? : Int,
  max_time_ms? : Int,
) -> AsyncCursor raise AsyncConnectionError {
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
      AsyncCursor::new(self, docs, cursor_id)
    }
    _ =>
      raise AsyncConnectionError::InvalidResponse("No cursor in find response")
  }
}

///|
/// Find one document
pub async fn AsyncCollection::find_one(
  self : AsyncCollection,
  filter : @types.BsonValue,
) -> @types.BsonValue? raise AsyncConnectionError {
  let cursor = self.find(filter, limit=1)
  cursor.next()
}

///|
/// Update one document
pub async fn AsyncCollection::update_one(
  self : AsyncCollection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  upsert? : Bool = false,
) -> AsyncUpdateResult raise AsyncConnectionError {
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
pub async fn AsyncCollection::update_many(
  self : AsyncCollection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  upsert? : Bool = false,
) -> AsyncUpdateResult raise AsyncConnectionError {
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
pub async fn AsyncCollection::delete_one(
  self : AsyncCollection,
  filter : @types.BsonValue,
) -> AsyncDeleteResult raise AsyncConnectionError {
  self.delete_internal(filter, 1)
}

///|
/// Delete many documents
pub async fn AsyncCollection::delete_many(
  self : AsyncCollection,
  filter : @types.BsonValue,
) -> AsyncDeleteResult raise AsyncConnectionError {
  self.delete_internal(filter, 0)
}

///|
/// Internal delete implementation
async fn AsyncCollection::delete_internal(
  self : AsyncCollection,
  filter : @types.BsonValue,
  limit : Int,
) -> AsyncDeleteResult raise AsyncConnectionError {
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
pub async fn AsyncCollection::count_documents(
  self : AsyncCollection,
  filter : @types.BsonValue,
) -> Int raise AsyncConnectionError {
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
pub async fn AsyncCollection::estimated_count(
  self : AsyncCollection,
) -> Int raise AsyncConnectionError {
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
pub async fn AsyncCollection::distinct(
  self : AsyncCollection,
  field : String,
  filter? : @types.BsonValue,
) -> Array[@types.BsonValue] raise AsyncConnectionError {
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
pub async fn AsyncCollection::aggregate(
  self : AsyncCollection,
  pipeline : Array[@types.BsonValue],
  batch_size? : Int,
  max_time_ms? : Int,
  allow_disk_use? : Bool,
) -> AsyncCursor raise AsyncConnectionError {
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
      AsyncCursor::new(self, docs, cursor_id)
    }
    _ =>
      raise AsyncConnectionError::InvalidResponse(
        "No cursor in aggregate response",
      )
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
pub async fn AsyncCollection::find_one_and_update(
  self : AsyncCollection,
  filter : @types.BsonValue,
  update : @types.BsonValue,
  return_document? : ReturnDocument,
  upsert? : Bool,
  projection? : @types.BsonValue,
  sort? : @types.BsonValue,
) -> @types.BsonValue? raise AsyncConnectionError {
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
pub async fn AsyncCollection::find_one_and_replace(
  self : AsyncCollection,
  filter : @types.BsonValue,
  replacement : @types.BsonValue,
  return_document? : ReturnDocument,
  upsert? : Bool,
) -> @types.BsonValue? raise AsyncConnectionError {
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
pub async fn AsyncCollection::find_one_and_delete(
  self : AsyncCollection,
  filter : @types.BsonValue,
  projection? : @types.BsonValue,
  sort? : @types.BsonValue,
) -> @types.BsonValue? raise AsyncConnectionError {
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
pub async fn AsyncCollection::replace_one(
  self : AsyncCollection,
  filter : @types.BsonValue,
  replacement : @types.BsonValue,
  upsert? : Bool,
) -> AsyncUpdateResult raise AsyncConnectionError {
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
pub async fn AsyncCollection::rename(
  self : AsyncCollection,
  new_name : String,
  drop_target? : Bool,
) -> Unit raise AsyncConnectionError {
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
pub async fn AsyncCollection::drop(
  self : AsyncCollection,
) -> Unit raise AsyncConnectionError {
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
pub async fn AsyncDatabase::create_collection(
  self : AsyncDatabase,
  name : String,
  capped? : Bool,
  size? : Int64,
  max? : Int64,
  validator? : @types.BsonValue,
  validation_level? : String,
  validation_action? : String,
) -> AsyncCollection raise AsyncConnectionError {
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
pub async fn AsyncDatabase::drop_collection(
  self : AsyncDatabase,
  name : String,
) -> Unit raise AsyncConnectionError {
  let coll = self.collection(name)
  coll.drop()
}

///|
/// List all collections in the database
pub async fn AsyncDatabase::list_collections(
  self : AsyncDatabase,
  filter? : @types.BsonValue,
) -> Array[CollectionInfo] raise AsyncConnectionError {
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
pub async fn AsyncDatabase::list_collection_names(
  self : AsyncDatabase,
) -> Array[String] raise AsyncConnectionError {
  let collections = self.list_collections()
  let names : Array[String] = []
  for coll in collections {
    names.push(coll.name)
  }
  names
}

///|
/// Drop the database
pub async fn AsyncDatabase::drop(
  self : AsyncDatabase,
) -> Unit raise AsyncConnectionError {
  let cmd = @types.bson_document()
    .set("dropDatabase", @types.bson_int32(1))
    .set("$db", @types.bson_string(self.name))
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
}

///|
/// Get database statistics
pub async fn AsyncDatabase::stats(
  self : AsyncDatabase,
) -> @types.BsonValue raise AsyncConnectionError {
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
pub async fn AsyncClient::list_databases(
  self : AsyncClient,
) -> Array[DatabaseInfo] raise AsyncConnectionError {
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
pub async fn AsyncClient::list_database_names(
  self : AsyncClient,
) -> Array[String] raise AsyncConnectionError {
  let databases = self.list_databases()
  let names : Array[String] = []
  for db in databases {
    names.push(db.name)
  }
  names
}

///|
/// Get server info
pub async fn AsyncClient::server_info(
  self : AsyncClient,
) -> @types.BsonValue raise AsyncConnectionError {
  let cmd = @types.bson_document()
    .set("buildInfo", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.conn.send_command(cmd)
  check_command_response(response)
  response
}

///|
/// Ping the server
pub async fn AsyncClient::ping(
  self : AsyncClient,
) -> Bool raise AsyncConnectionError {
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
