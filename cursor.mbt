///|
/// Async cursor for iterating over query results
pub struct Cursor {
  collection : Collection
  cursor_id : Int64
  batch : Array[@types.BsonValue]
  mut index : Int
  mut exhausted : Bool
}

///|
/// Create a new cursor (internal)
fn Cursor::new(
  collection : Collection,
  batch : Array[@types.BsonValue],
  cursor_id : Int64,
) -> Cursor {
  { collection, cursor_id, batch, index: 0, exhausted: cursor_id == 0L }
}

///|
/// Check if cursor has more results in current batch
pub fn Cursor::has_next(self : Cursor) -> Bool {
  self.index < self.batch.length()
}

///|
/// Get next document from current batch (BSON - used internally)
fn Cursor::next(self : Cursor) -> @types.BsonValue? {
  if self.index < self.batch.length() {
    let doc = self.batch[self.index]
    self.index = self.index + 1
    Some(doc)
  } else {
    None
  }
}

///|
/// Get next document as JSON
pub fn Cursor::next_json(self : Cursor) -> Json? {
  match self.next() {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Check if cursor is exhausted (no more batches available)
pub fn Cursor::is_exhausted(self : Cursor) -> Bool {
  self.exhausted && self.index >= self.batch.length()
}

///|
/// Get the cursor ID
pub fn Cursor::id(self : Cursor) -> Int64 {
  self.cursor_id
}

///|
/// Fetch more results from the server
pub async fn Cursor::get_more(
  self : Cursor,
  batch_size? : Int,
) -> Unit raise MongoError {
  if self.exhausted {
    return
  }
  let cmd = @types.bson_document()
    .set("getMore", @types.bson_int64(self.cursor_id))
    .set("collection", @types.bson_string(self.collection.name))
    .set("$db", @types.bson_string(self.collection.db.name))
  let cmd = match batch_size {
    Some(size) => cmd.set("batchSize", @types.bson_int32(size))
    None => cmd
  }
  let response = self.collection.db.client.conn.send_command(cmd)

  // Check for command errors
  let ok = match response.get("ok") {
    Some(@types.Double(v)) => v == 1.0
    Some(@types.Int32(v)) => v == 1
    _ => false
  }
  if not(ok) {
    let errmsg = match response.get("errmsg") {
      Some(@types.String(msg)) => msg
      _ => "getMore failed"
    }
    raise MongoError::CommandFailed(errmsg)
  }
  match response.get("cursor") {
    Some(@types.Document(cursor_map)) => {
      // Update cursor ID
      let new_cursor_id = match cursor_map.get("id") {
        Some(@types.Int64(id)) => id
        Some(@types.Int32(id)) => id.to_int64()
        _ => 0L
      }
      if new_cursor_id == 0L {
        self.exhausted = true
      }

      // Append new documents
      match cursor_map.get("nextBatch") {
        Some(@types.Array(docs)) =>
          for doc in docs {
            self.batch.push(doc)
          }
        _ => ()
      }
    }
    _ => raise MongoError::InvalidResponse("No cursor in getMore response")
  }
}

///|
/// Collect all documents into a JSON array
pub async fn Cursor::to_array(self : Cursor) -> Array[Json] raise MongoError {
  let bson_result = self.to_bson_array()
  let result : Array[Json] = []
  for doc in bson_result {
    result.push(@types.bson_to_json(doc))
  }
  result
}

///|
/// Collect all documents into a BSON array (internal)
async fn Cursor::to_bson_array(
  self : Cursor,
) -> Array[@types.BsonValue] raise MongoError {
  let result : Array[@types.BsonValue] = []

  // First get current batch
  while self.has_next() {
    match self.next() {
      Some(doc) => result.push(doc)
      None => break
    }
  }

  // Then fetch more if needed
  while not(self.exhausted) {
    self.get_more()
    while self.has_next() {
      match self.next() {
        Some(doc) => result.push(doc)
        None => break
      }
    }
  }
  result
}

///|
/// Close the cursor (send killCursors command)
pub async fn Cursor::close(self : Cursor) -> Unit {
  if self.cursor_id == 0L || self.exhausted {
    return
  }
  let cursor_ids = @types.bson_array().push(@types.bson_int64(self.cursor_id))
  let cmd = @types.bson_document()
    .set("killCursors", @types.bson_string(self.collection.name))
    .set("cursors", cursor_ids)
    .set("$db", @types.bson_string(self.collection.db.name))

  // Send command but ignore response errors
  let _ = self.collection.db.client.conn.send_command(cmd) catch {
    _ => @types.bson_document()
  }
  self.exhausted = true
}

///|
/// Iterate over cursor with a callback (JSON API)
pub async fn Cursor::for_each(
  self : Cursor,
  f : (Json) -> Unit,
) -> Unit raise MongoError {
  self.for_each_bson(fn(doc) { f(@types.bson_to_json(doc)) })
}

///|
/// Iterate over cursor with a callback (internal BSON API)
async fn Cursor::for_each_bson(
  self : Cursor,
  f : (@types.BsonValue) -> Unit,
) -> Unit raise MongoError {
  // Process current batch
  while self.has_next() {
    match self.next() {
      Some(doc) => f(doc)
      None => break
    }
  }

  // Fetch and process more batches
  while not(self.exhausted) {
    self.get_more()
    while self.has_next() {
      match self.next() {
        Some(doc) => f(doc)
        None => break
      }
    }
  }
}
