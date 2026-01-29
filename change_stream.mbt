///|
/// Change stream support for MongoDB real-time notifications

///|
/// Change stream options
pub struct ChangeStreamOptions {
  full_document : String?
  resume_after : @types.BsonValue?
  start_at_operation_time : @types.BsonValue?
  batch_size : Int?
  max_await_time_ms : Int?
}

///|
/// Create default change stream options
pub fn ChangeStreamOptions::default() -> ChangeStreamOptions {
  {
    full_document: None,
    resume_after: None,
    start_at_operation_time: None,
    batch_size: None,
    max_await_time_ms: None,
  }
}

///|
/// Change stream for watching collection/database/client changes
pub struct ChangeStream {
  cursor : Cursor
  mut resume_token : @types.BsonValue?
}

///|
/// Create a change stream on a collection
pub async fn Collection::watch(
  self : Collection,
  pipeline? : Array[@types.BsonValue],
  options? : ChangeStreamOptions,
) -> ChangeStream raise MongoError {
  let opts = options.unwrap_or(ChangeStreamOptions::default())
  let pipeline_arr = @types.bson_array()

  // Add $changeStream stage
  let change_stream_stage = @types.bson_document()
  let change_stream_stage = match opts.full_document {
    Some(fd) => change_stream_stage.set("fullDocument", @types.bson_string(fd))
    None => change_stream_stage
  }
  let change_stream_stage = match opts.resume_after {
    Some(token) => change_stream_stage.set("resumeAfter", token)
    None => change_stream_stage
  }
  let change_stream_stage = match opts.start_at_operation_time {
    Some(time) => change_stream_stage.set("startAtOperationTime", time)
    None => change_stream_stage
  }
  ignore(
    pipeline_arr.push(
      @types.bson_document().set("$changeStream", change_stream_stage),
    ),
  )

  // Add user pipeline stages
  match pipeline {
    Some(stages) =>
      for stage in stages {
        ignore(pipeline_arr.push(stage))
      }
    None => ()
  }

  // Build cursor options
  let cursor_opts = @types.bson_document()
  let cursor_opts = match opts.batch_size {
    Some(b) => cursor_opts.set("batchSize", @types.bson_int32(b))
    None => cursor_opts
  }
  let cmd = @types.bson_document()
    .set("aggregate", @types.bson_string(self.name))
    .set("pipeline", pipeline_arr)
    .set("cursor", cursor_opts)
    .set("$db", @types.bson_string(self.db.name))
  let cmd = match opts.max_await_time_ms {
    Some(t) => cmd.set("maxAwaitTimeMS", @types.bson_int32(t))
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
      let resume_token = cursor_map.get("postBatchResumeToken")
      let cursor = Cursor::new(self, docs, cursor_id)
      { cursor, resume_token }
    }
    _ =>
      raise MongoError::InvalidResponse("No cursor in change stream response")
  }
}

///|
/// Get the next change event
pub async fn ChangeStream::next(
  self : ChangeStream,
) -> @types.BsonValue? raise MongoError {
  // Try to get from current batch
  match self.cursor.next() {
    Some(doc) => {
      // Update resume token from the document
      match doc.get("_id") {
        Some(token) => self.resume_token = Some(token)
        None => ()
      }
      Some(doc)
    }
    None =>
      // Need to get more
      if self.cursor.is_exhausted() {
        None
      } else {
        self.cursor.get_more()
        match self.cursor.next() {
          Some(doc) => {
            match doc.get("_id") {
              Some(token) => self.resume_token = Some(token)
              None => ()
            }
            Some(doc)
          }
          None => None
        }
      }
  }
}

///|
/// Get the current resume token
pub fn ChangeStream::get_resume_token(self : ChangeStream) -> @types.BsonValue? {
  self.resume_token
}

///|
/// Close the change stream
pub async fn ChangeStream::close(self : ChangeStream) -> Unit {
  self.cursor.close()
}

///|
/// Iterate over change events with a callback
pub async fn ChangeStream::for_each(
  self : ChangeStream,
  f : (@types.BsonValue) -> Bool, // Return false to stop
) -> Unit raise MongoError {
  while true {
    match self.next() {
      Some(doc) => if not(f(doc)) { break }
      None =>
        // No more events available right now
        // In a real implementation, we'd wait for more
        break
    }
  }
}

///|
/// Watch changes on a database
pub async fn Database::watch(
  self : Database,
  pipeline? : Array[@types.BsonValue],
  options? : ChangeStreamOptions,
) -> ChangeStream raise MongoError {
  let opts = options.unwrap_or(ChangeStreamOptions::default())
  let pipeline_arr = @types.bson_array()

  // Add $changeStream stage
  let change_stream_stage = @types.bson_document()
  let change_stream_stage = match opts.full_document {
    Some(fd) => change_stream_stage.set("fullDocument", @types.bson_string(fd))
    None => change_stream_stage
  }
  let change_stream_stage = match opts.resume_after {
    Some(token) => change_stream_stage.set("resumeAfter", token)
    None => change_stream_stage
  }
  ignore(
    pipeline_arr.push(
      @types.bson_document().set("$changeStream", change_stream_stage),
    ),
  )

  // Add user pipeline stages
  match pipeline {
    Some(stages) =>
      for stage in stages {
        ignore(pipeline_arr.push(stage))
      }
    None => ()
  }
  let cursor_opts = @types.bson_document()
  let cmd = @types.bson_document()
    .set("aggregate", @types.bson_int32(1))
    .set("pipeline", pipeline_arr)
    .set("cursor", cursor_opts)
    .set("$db", @types.bson_string(self.name))
  let response = self.client.conn.send_command(cmd)
  check_command_response(response)
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
      let resume_token = cursor_map.get("postBatchResumeToken")
      // Create a dummy collection for the cursor
      let coll = self.collection("$cmd.aggregate")
      let cursor = Cursor::new(coll, docs, cursor_id)
      { cursor, resume_token }
    }
    _ =>
      raise MongoError::InvalidResponse("No cursor in change stream response")
  }
}
