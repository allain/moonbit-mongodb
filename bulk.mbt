///|
/// Bulk operation types for batch writes

///|
/// A single bulk write operation (internal BSON representation)
pub enum BulkOperation {
  InsertOne(@types.BsonValue)
  UpdateOne(
    filter~ : @types.BsonValue,
    update~ : @types.BsonValue,
    upsert~ : Bool
  )
  UpdateMany(
    filter~ : @types.BsonValue,
    update~ : @types.BsonValue,
    upsert~ : Bool
  )
  ReplaceOne(
    filter~ : @types.BsonValue,
    replacement~ : @types.BsonValue,
    upsert~ : Bool
  )
  DeleteOne(@types.BsonValue)
  DeleteMany(@types.BsonValue)
}

///|
/// Create an insert operation (JSON API)
pub fn BulkOperation::insert(doc : Json) -> BulkOperation {
  InsertOne(@types.json_to_bson(doc))
}

///|
/// Create an update one operation (JSON API)
pub fn BulkOperation::update_one(
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> BulkOperation {
  UpdateOne(
    filter=@types.json_to_bson(filter),
    update=@types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Create an update many operation (JSON API)
pub fn BulkOperation::update_many(
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> BulkOperation {
  UpdateMany(
    filter=@types.json_to_bson(filter),
    update=@types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Create a replace operation (JSON API)
pub fn BulkOperation::replace(
  filter : Json,
  replacement : Json,
  upsert? : Bool = false,
) -> BulkOperation {
  ReplaceOne(
    filter=@types.json_to_bson(filter),
    replacement=@types.json_to_bson(replacement),
    upsert~,
  )
}

///|
/// Create a delete one operation (JSON API)
pub fn BulkOperation::delete_one(filter : Json) -> BulkOperation {
  DeleteOne(@types.json_to_bson(filter))
}

///|
/// Create a delete many operation (JSON API)
pub fn BulkOperation::delete_many(filter : Json) -> BulkOperation {
  DeleteMany(@types.json_to_bson(filter))
}

///|
/// Result of a bulk write operation
pub struct BulkWriteResult {
  inserted_count : Int
  matched_count : Int
  modified_count : Int
  deleted_count : Int
  upserted_count : Int
  upserted_ids : Map[Int, @types.BsonValue]
}

///|
/// Execute bulk write operations
pub async fn Collection::bulk_write(
  self : Collection,
  operations : Array[BulkOperation],
  ordered? : Bool,
) -> BulkWriteResult raise MongoError {
  let is_ordered = ordered.unwrap_or(true)
  let mut inserted_count = 0
  let mut matched_count = 0
  let mut modified_count = 0
  let mut deleted_count = 0
  let mut upserted_count = 0
  let upserted_ids : Map[Int, @types.BsonValue] = {}

  // Group operations by type for efficiency
  let inserts : Array[@types.BsonValue] = []
  let updates : Array[@types.BsonValue] = []
  let deletes : Array[@types.BsonValue] = []
  for i, op in operations {
    match op {
      InsertOne(doc) => inserts.push(doc)
      UpdateOne(filter~, update~, upsert~) => {
        let update_doc = @types.bson_document()
          .set("q", filter)
          .set("u", update)
          .set("upsert", @types.bson_bool(upsert))
          .set("multi", @types.bson_bool(false))
        updates.push(update_doc)
      }
      UpdateMany(filter~, update~, upsert~) => {
        let update_doc = @types.bson_document()
          .set("q", filter)
          .set("u", update)
          .set("upsert", @types.bson_bool(upsert))
          .set("multi", @types.bson_bool(true))
        updates.push(update_doc)
      }
      ReplaceOne(filter~, replacement~, upsert~) => {
        let update_doc = @types.bson_document()
          .set("q", filter)
          .set("u", replacement)
          .set("upsert", @types.bson_bool(upsert))
          .set("multi", @types.bson_bool(false))
        updates.push(update_doc)
      }
      DeleteOne(filter) => {
        let delete_doc = @types.bson_document()
          .set("q", filter)
          .set("limit", @types.bson_int32(1))
        deletes.push(delete_doc)
      }
      DeleteMany(filter) => {
        let delete_doc = @types.bson_document()
          .set("q", filter)
          .set("limit", @types.bson_int32(0))
        deletes.push(delete_doc)
      }
    }
    ignore(i)
  }

  // Execute inserts
  if inserts.length() > 0 {
    let doc_array = @types.bson_array()
    for doc in inserts {
      ignore(doc_array.push(doc))
    }
    let cmd = @types.bson_document()
      .set("insert", @types.bson_string(self.name))
      .set("documents", doc_array)
      .set("ordered", @types.bson_bool(is_ordered))
      .set("$db", @types.bson_string(self.db.name))
    let response = self.db.client.conn.send_command(cmd)
    check_command_response(response)
    match response.get("n") {
      Some(@types.Int32(n)) => inserted_count = n
      _ => ()
    }
  }

  // Execute updates
  if updates.length() > 0 {
    let updates_array = @types.bson_array()
    for doc in updates {
      ignore(updates_array.push(doc))
    }
    let cmd = @types.bson_document()
      .set("update", @types.bson_string(self.name))
      .set("updates", updates_array)
      .set("ordered", @types.bson_bool(is_ordered))
      .set("$db", @types.bson_string(self.db.name))
    let response = self.db.client.conn.send_command(cmd)
    check_command_response(response)
    match response.get("n") {
      Some(@types.Int32(n)) => matched_count = n
      _ => ()
    }
    match response.get("nModified") {
      Some(@types.Int32(n)) => modified_count = n
      _ => ()
    }
    match response.get("upserted") {
      Some(@types.Array(arr)) => {
        upserted_count = arr.length()
        for item in arr {
          match item {
            @types.Document(doc) =>
              match (doc.get("index"), doc.get("_id")) {
                (Some(@types.Int32(idx)), Some(id)) => upserted_ids[idx] = id
                _ => ()
              }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  // Execute deletes
  if deletes.length() > 0 {
    let deletes_array = @types.bson_array()
    for doc in deletes {
      ignore(deletes_array.push(doc))
    }
    let cmd = @types.bson_document()
      .set("delete", @types.bson_string(self.name))
      .set("deletes", deletes_array)
      .set("ordered", @types.bson_bool(is_ordered))
      .set("$db", @types.bson_string(self.db.name))
    let response = self.db.client.conn.send_command(cmd)
    check_command_response(response)
    match response.get("n") {
      Some(@types.Int32(n)) => deleted_count = n
      _ => ()
    }
  }
  {
    inserted_count,
    matched_count,
    modified_count,
    deleted_count,
    upserted_count,
    upserted_ids,
  }
}
