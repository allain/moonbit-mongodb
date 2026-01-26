///|
/// Index management for MongoDB collections

///|
/// Index creation options
pub struct IndexOptions {
  name : String?
  unique : Bool?
  sparse : Bool?
  expire_after_seconds : Int?
  partial_filter : @types.BsonValue?
  background : Bool?
}

///|
/// Create default index options
pub fn IndexOptions::default() -> IndexOptions {
  {
    name: None,
    unique: None,
    sparse: None,
    expire_after_seconds: None,
    partial_filter: None,
    background: None,
  }
}

///|
/// Information about an index
pub struct IndexInfo {
  name : String
  key : @types.BsonValue
  unique : Bool
  sparse : Bool
}

///|
/// Create a single index
pub async fn AsyncCollection::create_index(
  self : AsyncCollection,
  keys : @types.BsonValue,
  options? : IndexOptions,
) -> String raise AsyncConnectionError {
  let index_doc = @types.bson_document().set("key", keys)
  let opts = options.unwrap_or(IndexOptions::default())
  let index_doc = match opts.name {
    Some(n) => index_doc.set("name", @types.bson_string(n))
    None => {
      // Generate name from keys
      let name = generate_index_name(keys)
      index_doc.set("name", @types.bson_string(name))
    }
  }
  let index_doc = match opts.unique {
    Some(true) => index_doc.set("unique", @types.bson_bool(true))
    _ => index_doc
  }
  let index_doc = match opts.sparse {
    Some(true) => index_doc.set("sparse", @types.bson_bool(true))
    _ => index_doc
  }
  let index_doc = match opts.expire_after_seconds {
    Some(secs) => index_doc.set("expireAfterSeconds", @types.bson_int32(secs))
    None => index_doc
  }
  let index_doc = match opts.partial_filter {
    Some(filter) => index_doc.set("partialFilterExpression", filter)
    None => index_doc
  }
  let index_doc = match opts.background {
    Some(true) => index_doc.set("background", @types.bson_bool(true))
    _ => index_doc
  }
  let indexes_array = @types.bson_array().push(index_doc)
  let cmd = @types.bson_document()
    .set("createIndexes", @types.bson_string(self.name))
    .set("indexes", indexes_array)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)

  // Return the index name
  match index_doc.get("name") {
    Some(@types.String(n)) => n
    _ => ""
  }
}

///|
/// Index specification for batch index creation
pub struct IndexSpec {
  keys : @types.BsonValue
  options : IndexOptions?
}

///|
/// Create an index specification
pub fn IndexSpec::new(
  keys : @types.BsonValue,
  options? : IndexOptions,
) -> IndexSpec {
  { keys, options }
}

///|
/// Create multiple indexes
pub async fn AsyncCollection::create_indexes(
  self : AsyncCollection,
  indexes : Array[IndexSpec],
) -> Array[String] raise AsyncConnectionError {
  let indexes_array = @types.bson_array()
  let names : Array[String] = []
  for index in indexes {
    let keys = index.keys
    let opts = index.options.unwrap_or(IndexOptions::default())
    let index_doc = @types.bson_document().set("key", keys)
    let name = match opts.name {
      Some(n) => n
      None => generate_index_name(keys)
    }
    names.push(name)
    let index_doc = index_doc.set("name", @types.bson_string(name))
    let index_doc = match opts.unique {
      Some(true) => index_doc.set("unique", @types.bson_bool(true))
      _ => index_doc
    }
    let index_doc = match opts.sparse {
      Some(true) => index_doc.set("sparse", @types.bson_bool(true))
      _ => index_doc
    }
    let index_doc = match opts.expire_after_seconds {
      Some(secs) => index_doc.set("expireAfterSeconds", @types.bson_int32(secs))
      None => index_doc
    }
    let index_doc = match opts.partial_filter {
      Some(filter) => index_doc.set("partialFilterExpression", filter)
      None => index_doc
    }
    ignore(indexes_array.push(index_doc))
  }
  let cmd = @types.bson_document()
    .set("createIndexes", @types.bson_string(self.name))
    .set("indexes", indexes_array)
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  names
}

///|
/// Drop a single index by name
pub async fn AsyncCollection::drop_index(
  self : AsyncCollection,
  name : String,
) -> Unit raise AsyncConnectionError {
  let cmd = @types.bson_document()
    .set("dropIndexes", @types.bson_string(self.name))
    .set("index", @types.bson_string(name))
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
}

///|
/// Drop all indexes except _id
pub async fn AsyncCollection::drop_indexes(
  self : AsyncCollection,
) -> Unit raise AsyncConnectionError {
  let cmd = @types.bson_document()
    .set("dropIndexes", @types.bson_string(self.name))
    .set("index", @types.bson_string("*"))
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
}

///|
/// List all indexes on a collection
pub async fn AsyncCollection::list_indexes(
  self : AsyncCollection,
) -> Array[IndexInfo] raise AsyncConnectionError {
  let cmd = @types.bson_document()
    .set("listIndexes", @types.bson_string(self.name))
    .set("$db", @types.bson_string(self.db.name))
  let response = self.db.client.conn.send_command(cmd)
  check_command_response(response)
  let indexes : Array[IndexInfo] = []
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
                let key = match doc.get("key") {
                  Some(k) => k
                  _ => @types.bson_document()
                }
                let unique = match doc.get("unique") {
                  Some(@types.Boolean(b)) => b
                  _ => false
                }
                let sparse = match doc.get("sparse") {
                  Some(@types.Boolean(b)) => b
                  _ => false
                }
                indexes.push({ name, key, unique, sparse })
              }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  indexes
}

///|
/// Generate an index name from keys
fn generate_index_name(keys : @types.BsonValue) -> String {
  let buf = @buffer.new()
  let mut first = true
  match keys {
    @types.Document(map) =>
      for key, value in map {
        if not(first) {
          buf.write_char('_')
        }
        first = false
        buf.write_string(key)
        buf.write_char('_')
        match value {
          @types.Int32(n) => buf.write_string(n.to_string())
          @types.Double(n) => buf.write_string(n.to_int().to_string())
          @types.String(s) => buf.write_string(s)
          _ => buf.write_string("1")
        }
      }
    _ => buf.write_string("index")
  }
  buf.to_string()
}
