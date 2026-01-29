///|
/// GridFS support for storing large files in MongoDB

///|
/// Default chunk size (255KB)
let default_chunk_size : Int = 255 * 1024

///|
/// GridFS bucket for file operations
pub struct GridFSBucket {
  db : Database
  bucket_name : String
  chunk_size : Int
}

///|
/// Create a new GridFS bucket
pub fn GridFSBucket::new(
  db : Database,
  bucket_name? : String,
  chunk_size? : Int,
) -> GridFSBucket {
  {
    db,
    bucket_name: bucket_name.unwrap_or("fs"),
    chunk_size: chunk_size.unwrap_or(default_chunk_size),
  }
}

///|
/// Get the files collection
fn GridFSBucket::files_collection(self : GridFSBucket) -> Collection {
  self.db.collection("\{self.bucket_name}.files")
}

///|
/// Get the chunks collection
fn GridFSBucket::chunks_collection(self : GridFSBucket) -> Collection {
  self.db.collection("\{self.bucket_name}.chunks")
}

///|
/// Upload a file to GridFS
pub async fn GridFSBucket::upload(
  self : GridFSBucket,
  filename : String,
  data : Bytes,
  metadata? : @types.BsonValue,
) -> @types.BsonValue raise MongoError {
  // Generate file ID (using default random bytes and timestamp 0 for now)
  let random_bytes = Bytes::from_array([
    b'\xAB', b'\xCD', b'\xEF', b'\x12', b'\x34',
  ])
  let file_id = @types.ObjectIdGenerator::new(random_bytes).generate(0)
  let file_id_bson = @types.bson_objectid(file_id.bytes)

  // Upload chunks
  let total_length = data.length()
  let mut chunk_num = 0
  let mut offset = 0
  let chunks_coll = self.chunks_collection()
  while offset < total_length {
    let chunk_end = if offset + self.chunk_size > total_length {
      total_length
    } else {
      offset + self.chunk_size
    }
    let chunk_size = chunk_end - offset

    // Extract chunk data using Array[Byte]
    let chunk_arr : Array[Byte] = []
    for i = 0; i < chunk_size; i = i + 1 {
      chunk_arr.push(data[offset + i])
    }
    let chunk_data = Bytes::from_array(chunk_arr)

    // Insert chunk
    let chunk_doc = @types.bson_document()
      .set("files_id", file_id_bson)
      .set("n", @types.bson_int32(chunk_num))
      .set("data", @types.bson_binary(chunk_data, b'\x00'))
    let _ = chunks_coll.insert_one(chunk_doc)
    chunk_num = chunk_num + 1
    offset = chunk_end
  }

  // Create file document
  let file_doc = @types.bson_document()
    .set("_id", file_id_bson)
    .set("filename", @types.bson_string(filename))
    .set("length", @types.bson_int64(total_length.to_int64()))
    .set("chunkSize", @types.bson_int32(self.chunk_size))
    .set("uploadDate", @types.bson_datetime(0L)) // Would use current time
  let file_doc = match metadata {
    Some(m) => file_doc.set("metadata", m)
    None => file_doc
  }
  let _ = self.files_collection().insert_one(file_doc)
  file_id_bson
}

///|
/// Download a file from GridFS by ID
pub async fn GridFSBucket::download(
  self : GridFSBucket,
  id : @types.BsonValue,
) -> Bytes raise MongoError {
  // Get file info
  let files_coll = self.files_collection()
  let filter = @types.bson_document().set("_id", id)
  let file_doc = match files_coll.find_one(filter) {
    Some(doc) => doc
    None => raise MongoError::CommandFailed("File not found")
  }
  let length = match file_doc.get("length") {
    Some(@types.Int64(l)) => l.to_int()
    Some(@types.Int32(l)) => l
    _ => raise MongoError::CommandFailed("Invalid file document")
  }

  // Allocate result buffer using Array[Byte]
  let result_arr : Array[Byte] = []

  // Get chunks sorted by n
  let chunks_coll = self.chunks_collection()
  let chunk_filter = @types.bson_document().set("files_id", id)
  let sort = @types.bson_document().set("n", @types.bson_int32(1))
  let cursor = chunks_coll.find(chunk_filter, sort~)
  let chunks = cursor.to_array()
  for chunk in chunks {
    match chunk.get("data") {
      Some(@types.Binary(data, _)) =>
        for i = 0; i < data.length(); i = i + 1 {
          result_arr.push(data[i])
        }
      _ => ()
    }
  }

  // Trim to expected length if needed
  while result_arr.length() > length {
    let _ = result_arr.pop()

  }
  Bytes::from_array(result_arr)
}

///|
/// Download a file by filename
pub async fn GridFSBucket::download_by_name(
  self : GridFSBucket,
  filename : String,
) -> Bytes raise MongoError {
  let files_coll = self.files_collection()
  let filter = @types.bson_document().set(
    "filename",
    @types.bson_string(filename),
  )
  let sort = @types.bson_document().set("uploadDate", @types.bson_int32(-1))
  let cursor = files_coll.find(filter, sort~, limit=1)
  match cursor.next() {
    Some(doc) =>
      match doc.get("_id") {
        Some(id) => self.download(id)
        None => raise MongoError::CommandFailed("Invalid file document")
      }
    None => raise MongoError::CommandFailed("File not found")
  }
}

///|
/// Delete a file from GridFS
pub async fn GridFSBucket::delete(
  self : GridFSBucket,
  id : @types.BsonValue,
) -> Unit raise MongoError {
  // Delete chunks first
  let chunk_filter = @types.bson_document().set("files_id", id)
  let _ = self.chunks_collection().delete_many(chunk_filter)

  // Delete file document
  let file_filter = @types.bson_document().set("_id", id)
  let _ = self.files_collection().delete_one(file_filter)

}

///|
/// Find files matching a filter
pub async fn GridFSBucket::find(
  self : GridFSBucket,
  filter : @types.BsonValue,
) -> Array[@types.BsonValue] raise MongoError {
  let cursor = self.files_collection().find(filter)
  cursor.to_array()
}

///|
/// Rename a file
pub async fn GridFSBucket::rename(
  self : GridFSBucket,
  id : @types.BsonValue,
  new_filename : String,
) -> Unit raise MongoError {
  let filter = @types.bson_document().set("_id", id)
  let update = @types.bson_document().set(
    "$set",
    @types.bson_document().set("filename", @types.bson_string(new_filename)),
  )
  let _ = self.files_collection().update_one(filter, update)

}

///|
/// Drop the GridFS bucket (delete all files and chunks)
pub async fn GridFSBucket::drop(self : GridFSBucket) -> Unit raise MongoError {
  self.files_collection().drop()
  self.chunks_collection().drop()
}

///|
/// Check if a file exists
pub async fn GridFSBucket::exists(
  self : GridFSBucket,
  id : @types.BsonValue,
) -> Bool raise MongoError {
  let filter = @types.bson_document().set("_id", id)
  match self.files_collection().find_one(filter) {
    Some(_) => true
    None => false
  }
}

///|
/// Get file info
pub async fn GridFSBucket::get_file_info(
  self : GridFSBucket,
  id : @types.BsonValue,
) -> @types.BsonValue? raise MongoError {
  let filter = @types.bson_document().set("_id", id)
  self.files_collection().find_one(filter)
}
