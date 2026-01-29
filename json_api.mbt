///|
/// Insert one document
pub async fn Collection::insert_one(
  self : Collection,
  document : Json,
) -> InsertResult raise MongoError {
  self.insert_one_bson(@types.json_to_bson(document))
}

///|
/// Insert multiple documents
pub async fn Collection::insert_many(
  self : Collection,
  documents : Array[Json],
) -> InsertResult raise MongoError {
  let bson_docs : Array[@types.BsonValue] = []
  for doc in documents {
    bson_docs.push(@types.json_to_bson(doc))
  }
  self.insert_many_bson(bson_docs)
}

///|
/// Find documents matching a filter
pub async fn Collection::find(
  self : Collection,
  filter : Json,
  limit? : Int,
  skip? : Int,
  sort? : Json,
  projection? : Json,
) -> Array[Json] raise MongoError {
  let cursor = match (sort, projection) {
    (Some(s), Some(p)) =>
      self.find_bson(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        sort=@types.json_to_bson(s),
        projection=@types.json_to_bson(p),
      )
    (Some(s), None) =>
      self.find_bson(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        sort=@types.json_to_bson(s),
      )
    (None, Some(p)) =>
      self.find_bson(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        projection=@types.json_to_bson(p),
      )
    (None, None) => self.find_bson(@types.json_to_bson(filter), limit?, skip?)
  }
  cursor.to_array()
}

///|
/// Find one document matching a filter
pub async fn Collection::find_one(
  self : Collection,
  filter : Json,
) -> Json? raise MongoError {
  match self.find_one_bson(@types.json_to_bson(filter)) {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Update one document
pub async fn Collection::update_one(
  self : Collection,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> UpdateResult raise MongoError {
  self.update_one_bson(
    @types.json_to_bson(filter),
    @types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Update many documents
pub async fn Collection::update_many(
  self : Collection,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> UpdateResult raise MongoError {
  self.update_many_bson(
    @types.json_to_bson(filter),
    @types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Delete one document
pub async fn Collection::delete_one(
  self : Collection,
  filter : Json,
) -> DeleteResult raise MongoError {
  self.delete_one_bson(@types.json_to_bson(filter))
}

///|
/// Delete many documents
pub async fn Collection::delete_many(
  self : Collection,
  filter : Json,
) -> DeleteResult raise MongoError {
  self.delete_many_bson(@types.json_to_bson(filter))
}

///|
/// Count documents matching a filter
pub async fn Collection::count_documents(
  self : Collection,
  filter : Json,
) -> Int raise MongoError {
  self.count_documents_bson(@types.json_to_bson(filter))
}

///|
/// Run aggregation pipeline
pub async fn Collection::aggregate(
  self : Collection,
  pipeline : Array[Json],
  batch_size? : Int,
  max_time_ms? : Int,
  allow_disk_use? : Bool,
) -> Array[Json] raise MongoError {
  let bson_pipeline : Array[@types.BsonValue] = []
  for stage in pipeline {
    bson_pipeline.push(@types.json_to_bson(stage))
  }
  let cursor = self.aggregate_bson(bson_pipeline, batch_size?, max_time_ms?, allow_disk_use?)
  cursor.to_array()
}

///|
/// Get distinct values for a field
pub async fn Collection::distinct(
  self : Collection,
  field : String,
  filter? : Json,
) -> Array[Json] raise MongoError {
  let values = match filter {
    Some(f) => self.distinct_bson(field, filter=@types.json_to_bson(f))
    None => self.distinct_bson(field)
  }
  let json_values : Array[Json] = []
  for v in values {
    json_values.push(@types.bson_to_json(v))
  }
  json_values
}

///|
/// Find and update a single document atomically
pub async fn Collection::find_one_and_update(
  self : Collection,
  filter : Json,
  update : Json,
  return_new? : Bool,
  upsert? : Bool,
) -> Json? raise MongoError {
  let result = match (return_new, upsert) {
    (Some(true), Some(u)) =>
      self.find_one_and_update_bson(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        return_document=ReturnDocument::After,
        upsert=u,
      )
    (Some(true), None) =>
      self.find_one_and_update_bson(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        return_document=ReturnDocument::After,
      )
    (_, Some(u)) =>
      self.find_one_and_update_bson(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        upsert=u,
      )
    (_, None) =>
      self.find_one_and_update_bson(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
      )
  }
  match result {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Find and delete one document
pub async fn Collection::find_one_and_delete(
  self : Collection,
  filter : Json,
  sort? : Json,
  projection? : Json,
) -> Json? raise MongoError {
  let result = match (sort, projection) {
    (Some(s), Some(p)) =>
      self.find_one_and_delete_bson(
        @types.json_to_bson(filter),
        sort=@types.json_to_bson(s),
        projection=@types.json_to_bson(p),
      )
    (Some(s), None) =>
      self.find_one_and_delete_bson(
        @types.json_to_bson(filter),
        sort=@types.json_to_bson(s),
      )
    (None, Some(p)) =>
      self.find_one_and_delete_bson(
        @types.json_to_bson(filter),
        projection=@types.json_to_bson(p),
      )
    (None, None) => self.find_one_and_delete_bson(@types.json_to_bson(filter))
  }
  match result {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Find and replace one document
pub async fn Collection::find_one_and_replace(
  self : Collection,
  filter : Json,
  replacement : Json,
  return_new? : Bool,
  upsert? : Bool,
) -> Json? raise MongoError {
  let return_doc = match return_new {
    Some(true) => ReturnDocument::After
    _ => ReturnDocument::Before
  }
  let result = self.find_one_and_replace_bson(
    @types.json_to_bson(filter),
    @types.json_to_bson(replacement),
    return_document=return_doc,
    upsert=upsert.unwrap_or(false),
  )
  match result {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Replace one document
pub async fn Collection::replace_one(
  self : Collection,
  filter : Json,
  replacement : Json,
  upsert? : Bool,
) -> UpdateResult raise MongoError {
  self.replace_one_bson(
    @types.json_to_bson(filter),
    @types.json_to_bson(replacement),
    upsert?,
  )
}
