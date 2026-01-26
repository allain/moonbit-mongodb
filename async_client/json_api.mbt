///|
/// Insert one document (JSON API)
pub async fn AsyncCollection::insert(
  self : AsyncCollection,
  document : Json,
) -> AsyncInsertResult raise AsyncConnectionError {
  self.insert_one(@types.json_to_bson(document))
}

///|
/// Insert multiple documents (JSON API)
pub async fn AsyncCollection::insert_all(
  self : AsyncCollection,
  documents : Array[Json],
) -> AsyncInsertResult raise AsyncConnectionError {
  let bson_docs : Array[@types.BsonValue] = []
  for doc in documents {
    bson_docs.push(@types.json_to_bson(doc))
  }
  self.insert_many(bson_docs)
}

///|
/// Find documents (JSON API)
pub async fn AsyncCollection::query(
  self : AsyncCollection,
  filter : Json,
  limit? : Int,
  skip? : Int,
  sort? : Json,
  projection? : Json,
) -> Array[Json] raise AsyncConnectionError {
  let cursor = match (sort, projection) {
    (Some(s), Some(p)) =>
      self.find(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        sort=@types.json_to_bson(s),
        projection=@types.json_to_bson(p),
      )
    (Some(s), None) =>
      self.find(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        sort=@types.json_to_bson(s),
      )
    (None, Some(p)) =>
      self.find(
        @types.json_to_bson(filter),
        limit?,
        skip?,
        projection=@types.json_to_bson(p),
      )
    (None, None) => self.find(@types.json_to_bson(filter), limit?, skip?)
  }
  let bson_docs = cursor.to_array()
  let json_docs : Array[Json] = []
  for doc in bson_docs {
    json_docs.push(@types.bson_to_json(doc))
  }
  json_docs
}

///|
/// Find one document (JSON API)
pub async fn AsyncCollection::query_one(
  self : AsyncCollection,
  filter : Json,
) -> Json? raise AsyncConnectionError {
  match self.find_one(@types.json_to_bson(filter)) {
    Some(doc) => Some(@types.bson_to_json(doc))
    None => None
  }
}

///|
/// Update one document (JSON API)
pub async fn AsyncCollection::modify_one(
  self : AsyncCollection,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> AsyncUpdateResult raise AsyncConnectionError {
  self.update_one(
    @types.json_to_bson(filter),
    @types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Update many documents (JSON API)
pub async fn AsyncCollection::modify_all(
  self : AsyncCollection,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> AsyncUpdateResult raise AsyncConnectionError {
  self.update_many(
    @types.json_to_bson(filter),
    @types.json_to_bson(update),
    upsert~,
  )
}

///|
/// Delete one document (JSON API)
pub async fn AsyncCollection::remove_one(
  self : AsyncCollection,
  filter : Json,
) -> AsyncDeleteResult raise AsyncConnectionError {
  self.delete_one(@types.json_to_bson(filter))
}

///|
/// Delete many documents (JSON API)
pub async fn AsyncCollection::remove_all(
  self : AsyncCollection,
  filter : Json,
) -> AsyncDeleteResult raise AsyncConnectionError {
  self.delete_many(@types.json_to_bson(filter))
}

///|
/// Count documents matching a filter (JSON API)
pub async fn AsyncCollection::count(
  self : AsyncCollection,
  filter : Json,
) -> Int raise AsyncConnectionError {
  self.count_documents(@types.json_to_bson(filter))
}

///|
/// Run aggregation pipeline (JSON API)
pub async fn AsyncCollection::aggregate_json(
  self : AsyncCollection,
  pipeline : Array[Json],
) -> Array[Json] raise AsyncConnectionError {
  let bson_pipeline : Array[@types.BsonValue] = []
  for stage in pipeline {
    bson_pipeline.push(@types.json_to_bson(stage))
  }
  let cursor = self.aggregate(bson_pipeline)
  let bson_docs = cursor.to_array()
  let json_docs : Array[Json] = []
  for doc in bson_docs {
    json_docs.push(@types.bson_to_json(doc))
  }
  json_docs
}

///|
/// Get distinct values for a field (JSON API)
pub async fn AsyncCollection::distinct_json(
  self : AsyncCollection,
  field : String,
  filter? : Json,
) -> Array[Json] raise AsyncConnectionError {
  let values = match filter {
    Some(f) => self.distinct(field, filter=@types.json_to_bson(f))
    None => self.distinct(field)
  }
  let json_values : Array[Json] = []
  for v in values {
    json_values.push(@types.bson_to_json(v))
  }
  json_values
}

///|
/// Find and update a single document atomically (JSON API)
pub async fn AsyncCollection::find_one_and_modify(
  self : AsyncCollection,
  filter : Json,
  update : Json,
  return_new? : Bool,
  upsert? : Bool,
) -> Json? raise AsyncConnectionError {
  let result = match (return_new, upsert) {
    (Some(true), Some(u)) =>
      self.find_one_and_update(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        return_document=ReturnDocument::After,
        upsert=u,
      )
    (Some(true), None) =>
      self.find_one_and_update(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        return_document=ReturnDocument::After,
      )
    (_, Some(u)) =>
      self.find_one_and_update(
        @types.json_to_bson(filter),
        @types.json_to_bson(update),
        upsert=u,
      )
    (_, None) =>
      self.find_one_and_update(
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
/// Replace one document (JSON API)
pub async fn AsyncCollection::replace(
  self : AsyncCollection,
  filter : Json,
  replacement : Json,
  upsert? : Bool,
) -> AsyncUpdateResult raise AsyncConnectionError {
  self.replace_one(
    @types.json_to_bson(filter),
    @types.json_to_bson(replacement),
    upsert?,
  )
}
