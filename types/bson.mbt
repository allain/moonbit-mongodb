///|
/// BSON Type enumeration
pub enum BsonValue {
  /// 0x01 - 64-bit floating point
  Double(Double)
  /// 0x02 - UTF-8 string
  String(String)
  /// 0x03 - Embedded document
  Document(Map[String, BsonValue])
  /// 0x04 - Array
  Array(Array[BsonValue])
  /// 0x05 - Binary data
  Binary(Bytes, Byte) // data, subtype
  /// 0x07 - ObjectId (12 bytes)
  ObjectId(Bytes)
  /// 0x08 - Boolean
  Boolean(Bool)
  /// 0x09 - UTC datetime (milliseconds since epoch)
  DateTime(Int64)
  /// 0x0A - Null value
  Null
  /// 0x0B - Regular expression
  Regex(pattern~ : String, options~ : String)
  /// 0x0D - JavaScript code
  Code(String)
  /// 0x0F - JavaScript code with scope
  CodeWithScope(code~ : String, scope~ : Map[String, BsonValue])
  /// 0x10 - 32-bit integer
  Int32(Int)
  /// 0x11 - Timestamp (for internal MongoDB use)
  Timestamp(increment~ : UInt, timestamp~ : UInt)
  /// 0x12 - 64-bit integer
  Int64(Int64)
  /// 0x13 - 128-bit decimal floating point
  Decimal128(Bytes) // 16 bytes IEEE 754-2008
  /// 0x7F - Max key
  MaxKey
  /// 0xFF - Min key
  MinKey
}

///|
/// Create a new empty document
pub fn bson_document() -> BsonValue {
  Document(Map::new())
}

///|
/// Create a string value
pub fn bson_string(s : String) -> BsonValue {
  String(s)
}

///|
/// Create an Int32 value
pub fn bson_int32(i : Int) -> BsonValue {
  Int32(i)
}

///|
/// Create an Int64 value
pub fn bson_int64(i : Int64) -> BsonValue {
  Int64(i)
}

///|
/// Create a Double value
pub fn bson_double(d : Double) -> BsonValue {
  Double(d)
}

///|
/// Create a Boolean value
pub fn bson_bool(b : Bool) -> BsonValue {
  Boolean(b)
}

///|
/// Create a Null value
pub fn bson_null() -> BsonValue {
  Null
}

///|
/// Create an array value
pub fn bson_array() -> BsonValue {
  Array([])
}

///|
/// Create a DateTime value
pub fn bson_datetime(millis : Int64) -> BsonValue {
  DateTime(millis)
}

///|
/// Create an ObjectId from bytes
pub fn bson_objectid(bytes : Bytes) -> BsonValue {
  ObjectId(bytes)
}

///|
/// Create a Binary value
pub fn bson_binary(data : Bytes, subtype : Byte) -> BsonValue {
  Binary(data, subtype)
}

///|
/// Create a Regex value
pub fn bson_regex(pattern : String, options : String) -> BsonValue {
  Regex(pattern~, options~)
}

///|
/// Create a Code value (JavaScript)
pub fn bson_code(code : String) -> BsonValue {
  Code(code)
}

///|
/// Create a CodeWithScope value
pub fn bson_code_with_scope(
  code : String,
  scope : Map[String, BsonValue],
) -> BsonValue {
  CodeWithScope(code~, scope~)
}

///|
/// Create a Timestamp value
pub fn bson_timestamp(increment : UInt, timestamp : UInt) -> BsonValue {
  Timestamp(increment~, timestamp~)
}

///|
/// Create a Decimal128 value from bytes
pub fn bson_decimal128(bytes : Bytes) -> BsonValue {
  Decimal128(bytes)
}

///|
/// Create a MinKey value
pub fn bson_minkey() -> BsonValue {
  MinKey
}

///|
/// Create a MaxKey value
pub fn bson_maxkey() -> BsonValue {
  MaxKey
}

///|
/// Set a field on a document (chainable)
pub fn BsonValue::set(
  self : BsonValue,
  key : String,
  value : BsonValue,
) -> BsonValue {
  match self {
    Document(map) => {
      map.set(key, value)
      Document(map)
    }
    _ => self
  }
}

///|
/// Push a value to an array (chainable)
pub fn BsonValue::push(self : BsonValue, value : BsonValue) -> BsonValue {
  match self {
    Array(arr) => {
      arr.push(value)
      Array(arr)
    }
    _ => self
  }
}

///|
/// Get a field from a document
pub fn BsonValue::get(self : BsonValue, key : String) -> BsonValue? {
  match self {
    Document(map) => map.get(key)
    _ => None
  }
}

///|
/// Get as string
pub fn BsonValue::as_string(self : BsonValue) -> String? {
  match self {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// Get as Int32
pub fn BsonValue::as_int32(self : BsonValue) -> Int? {
  match self {
    Int32(i) => Some(i)
    _ => None
  }
}

///|
/// Get as Int64
pub fn BsonValue::as_int64(self : BsonValue) -> Int64? {
  match self {
    Int64(i) => Some(i)
    Int32(i) => Some(i.to_int64())
    _ => None
  }
}

///|
/// Get as Double
pub fn BsonValue::as_double(self : BsonValue) -> Double? {
  match self {
    Double(d) => Some(d)
    _ => None
  }
}

///|
/// Get as Boolean
pub fn BsonValue::as_bool(self : BsonValue) -> Bool? {
  match self {
    Boolean(b) => Some(b)
    _ => None
  }
}

///|
/// Get as Document map
pub fn BsonValue::as_document(self : BsonValue) -> Map[String, BsonValue]? {
  match self {
    Document(map) => Some(map)
    _ => None
  }
}

///|
/// Get as Array
pub fn BsonValue::as_array(self : BsonValue) -> Array[BsonValue]? {
  match self {
    Array(arr) => Some(arr)
    _ => None
  }
}

///|
/// Get array element by index
pub fn BsonValue::get_index(self : BsonValue, index : Int) -> BsonValue? {
  match self {
    Array(arr) =>
      if index >= 0 && index < arr.length() {
        Some(arr[index])
      } else {
        None
      }
    _ => None
  }
}

///|
/// Get array length
pub fn BsonValue::length(self : BsonValue) -> Int {
  match self {
    Array(arr) => arr.length()
    _ => 0
  }
}

///|
/// Check if value is a document
pub fn BsonValue::is_document(self : BsonValue) -> Bool {
  match self {
    Document(_) => true
    _ => false
  }
}

///|
/// BSON encoding error
pub suberror BsonError {
  EncodingError(String)
  DecodingError(String)
  UnknownType(Byte)
}

///|
pub impl Show for BsonError with output(self, logger) {
  match self {
    EncodingError(msg) => logger.write_string("EncodingError: \{msg}")
    DecodingError(msg) => logger.write_string("DecodingError: \{msg}")
    UnknownType(b) => logger.write_string("UnknownType: \{b}")
  }
}

// ============ Encoding ============

///|
/// Write Int32 little-endian to array
fn write_i32(arr : Array[Byte], value : Int) -> Unit {
  arr.push((value & 0xFF).to_byte())
  arr.push(((value >> 8) & 0xFF).to_byte())
  arr.push(((value >> 16) & 0xFF).to_byte())
  arr.push(((value >> 24) & 0xFF).to_byte())
}

///|
/// Write Int64 little-endian to array
fn write_i64(arr : Array[Byte], value : Int64) -> Unit {
  arr.push((value & 0xFFL).to_byte())
  arr.push(((value >> 8) & 0xFFL).to_byte())
  arr.push(((value >> 16) & 0xFFL).to_byte())
  arr.push(((value >> 24) & 0xFFL).to_byte())
  arr.push(((value >> 32) & 0xFFL).to_byte())
  arr.push(((value >> 40) & 0xFFL).to_byte())
  arr.push(((value >> 48) & 0xFFL).to_byte())
  arr.push(((value >> 56) & 0xFFL).to_byte())
}

///|
/// Convert string to UTF-8 bytes
fn string_to_utf8(s : String) -> Bytes {
  let buf = @buffer.new()
  buf.write_string_utf8(s)
  buf.to_bytes()
}

///|
/// Write a C-string (null-terminated)
fn write_cstring(arr : Array[Byte], s : String) -> Unit {
  let bytes = string_to_utf8(s)
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
  arr.push(b'\x00')
}

///|
/// Write a BSON string (length-prefixed with null terminator)
fn write_bson_string(arr : Array[Byte], s : String) -> Unit {
  let bytes = string_to_utf8(s)
  write_i32(arr, bytes.length() + 1) // +1 for null terminator
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
  arr.push(b'\x00')
}

///|
/// Write bytes to array
fn write_bytes(arr : Array[Byte], bytes : Bytes) -> Unit {
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
}

///|
/// Set Int32 at specific position
fn set_i32_at(arr : Array[Byte], offset : Int, value : Int) -> Unit {
  arr[offset] = (value & 0xFF).to_byte()
  arr[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  arr[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  arr[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}

///|
/// Get BSON type byte for a value
fn type_byte(value : BsonValue) -> Byte {
  match value {
    Double(_) => b'\x01'
    String(_) => b'\x02'
    Document(_) => b'\x03'
    Array(_) => b'\x04'
    Binary(_, _) => b'\x05'
    ObjectId(_) => b'\x07'
    Boolean(_) => b'\x08'
    DateTime(_) => b'\x09'
    Null => b'\x0A'
    Regex(..) => b'\x0B'
    Code(_) => b'\x0D'
    CodeWithScope(..) => b'\x0F'
    Int32(_) => b'\x10'
    Timestamp(..) => b'\x11'
    Int64(_) => b'\x12'
    Decimal128(_) => b'\x13'
    MaxKey => b'\x7F'
    MinKey => b'\xFF'
  }
}

///|
/// Encode a BSON element (type + name + value)
fn encode_element(arr : Array[Byte], name : String, value : BsonValue) -> Unit {
  arr.push(type_byte(value))
  write_cstring(arr, name)
  match value {
    Double(d) => write_i64(arr, d.reinterpret_as_int64())
    String(s) => write_bson_string(arr, s)
    Document(map) => encode_document_to_array(arr, map)
    Array(items) => {
      // Arrays are encoded as documents with string indices
      let size_offset = arr.length()
      write_i32(arr, 0) // placeholder for size
      for i, item in items {
        encode_element(arr, i.to_string(), item)
      }
      arr.push(b'\x00') // document terminator
      set_i32_at(arr, size_offset, arr.length() - size_offset)
    }
    Binary(data, subtype) => {
      write_i32(arr, data.length())
      arr.push(subtype)
      write_bytes(arr, data)
    }
    ObjectId(bytes) => write_bytes(arr, bytes)
    Boolean(b) => arr.push(if b { b'\x01' } else { b'\x00' })
    DateTime(millis) => write_i64(arr, millis)
    Null => ()
    Regex(pattern~, options~) => {
      write_cstring(arr, pattern)
      write_cstring(arr, options)
    }
    Code(code) => write_bson_string(arr, code)
    CodeWithScope(code~, scope~) => {
      // CodeWithScope is: int32 (total size) + string (code) + document (scope)
      let size_offset = arr.length()
      write_i32(arr, 0) // placeholder for size
      write_bson_string(arr, code)
      encode_document_to_array(arr, scope)
      set_i32_at(arr, size_offset, arr.length() - size_offset)
    }
    Int32(i) => write_i32(arr, i)
    Timestamp(increment~, timestamp~) => {
      // Timestamp is stored as: increment (4 bytes) + timestamp (4 bytes)
      write_i32(arr, increment.reinterpret_as_int())
      write_i32(arr, timestamp.reinterpret_as_int())
    }
    Int64(i) => write_i64(arr, i)
    Decimal128(bytes) => write_bytes(arr, bytes)
    MaxKey => ()
    MinKey => ()
  }
}

///|
/// Encode a document map to array
fn encode_document_to_array(
  arr : Array[Byte],
  map : Map[String, BsonValue],
) -> Unit {
  let size_offset = arr.length()
  write_i32(arr, 0) // placeholder for size
  for key, value in map {
    encode_element(arr, key, value)
  }
  arr.push(b'\x00') // document terminator
  set_i32_at(arr, size_offset, arr.length() - size_offset)
}

///|
/// Encode a BsonValue to bytes
pub fn encode_bson(value : BsonValue) -> Bytes raise BsonError {
  match value {
    Document(map) => {
      let arr : Array[Byte] = []
      encode_document_to_array(arr, map)
      Bytes::from_array(arr)
    }
    _ => raise BsonError::EncodingError("Top-level value must be a document")
  }
}

// ============ Decoding ============

///|
/// Read Int32 little-endian from bytes with bounds checking
fn read_i32(bytes : Bytes, offset : Int) -> Int raise BsonError {
  if offset + 4 > bytes.length() {
    raise BsonError::DecodingError(
      "Buffer underflow: need 4 bytes at offset \{offset}, have \{bytes.length()}",
    )
  }
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}

///|
/// Read Int64 little-endian from bytes with bounds checking
fn read_i64(bytes : Bytes, offset : Int) -> Int64 raise BsonError {
  if offset + 8 > bytes.length() {
    raise BsonError::DecodingError(
      "Buffer underflow: need 8 bytes at offset \{offset}, have \{bytes.length()}",
    )
  }
  bytes[offset].to_int64() |
  (bytes[offset + 1].to_int64() << 8) |
  (bytes[offset + 2].to_int64() << 16) |
  (bytes[offset + 3].to_int64() << 24) |
  (bytes[offset + 4].to_int64() << 32) |
  (bytes[offset + 5].to_int64() << 40) |
  (bytes[offset + 6].to_int64() << 48) |
  (bytes[offset + 7].to_int64() << 56)
}

///|
/// Get a slice of bytes as a new Bytes object with bounds checking
fn slice_bytes(bytes : Bytes, offset : Int, len : Int) -> Bytes raise BsonError {
  if offset + len > bytes.length() {
    raise BsonError::DecodingError(
      "Buffer underflow: need \{len} bytes at offset \{offset}, have \{bytes.length()}",
    )
  }
  let arr : Array[Byte] = []
  for i = 0; i < len; i = i + 1 {
    arr.push(bytes[offset + i])
  }
  Bytes::from_array(arr)
}

///|
/// Convert bytes to string by treating each byte as a char (ASCII/Latin-1)
fn bytes_to_ascii_string(bytes : Bytes) -> String {
  let buf = @buffer.new()
  for i = 0; i < bytes.length(); i = i + 1 {
    buf.write_char(Int::unsafe_to_char(bytes[i].to_int()))
  }
  buf.to_string()
}

///|
/// Read a C-string, returns (string, bytes_consumed)
fn read_cstring(bytes : Bytes, offset : Int) -> (String, Int) raise BsonError {
  if offset >= bytes.length() {
    raise BsonError::DecodingError(
      "Buffer underflow: reading cstring at offset \{offset}",
    )
  }
  let mut end = offset
  while end < bytes.length() && bytes[end] != b'\x00' {
    end = end + 1
  }
  if end >= bytes.length() {
    raise BsonError::DecodingError("Unterminated cstring at offset \{offset}")
  }
  let len = end - offset
  let str_bytes = slice_bytes(bytes, offset, len)
  (bytes_to_ascii_string(str_bytes), len + 1) // +1 for null terminator
}

///|
/// Read a BSON string, returns (string, bytes_consumed)
fn read_bson_string(
  bytes : Bytes,
  offset : Int,
) -> (String, Int) raise BsonError {
  let len = read_i32(bytes, offset)
  if len < 1 {
    raise BsonError::DecodingError("Invalid string length: \{len}")
  }
  let str_bytes = slice_bytes(bytes, offset + 4, len - 1) // -1 to exclude null
  (bytes_to_ascii_string(str_bytes), 4 + len)
}

///|
/// Decode a BSON element, returns (key, value, bytes_consumed)
fn decode_element(
  bytes : Bytes,
  offset : Int,
) -> (String, BsonValue, Int) raise BsonError {
  let type_byte = bytes[offset]
  let (name, name_size) = read_cstring(bytes, offset + 1)
  let value_offset = offset + 1 + name_size
  match type_byte {
    b'\x01' => { // Double
      let bits = read_i64(bytes, value_offset)
      (name, Double(bits.reinterpret_as_double()), 1 + name_size + 8)
    }
    b'\x02' => { // String
      let (s, size) = read_bson_string(bytes, value_offset)
      (name, String(s), 1 + name_size + size)
    }
    b'\x03' => { // Document
      let (doc, size) = decode_document_from_bytes(bytes, value_offset)
      (name, doc, 1 + name_size + size)
    }
    b'\x04' => { // Array
      let doc_size = read_i32(bytes, value_offset)
      let arr : Array[BsonValue] = []
      let mut pos = value_offset + 4
      let end = value_offset + doc_size - 1
      while pos < end {
        let (_, value, consumed) = decode_element(bytes, pos)
        arr.push(value)
        pos = pos + consumed
      }
      (name, Array(arr), 1 + name_size + doc_size)
    }
    b'\x05' => { // Binary
      let len = read_i32(bytes, value_offset)
      let subtype = bytes[value_offset + 4]
      let data = slice_bytes(bytes, value_offset + 5, len)
      (name, Binary(data, subtype), 1 + name_size + 5 + len)
    }
    b'\x07' => { // ObjectId
      let oid_bytes = slice_bytes(bytes, value_offset, 12)
      (name, ObjectId(oid_bytes), 1 + name_size + 12)
    }
    b'\x08' => { // Boolean
      let b = bytes[value_offset] != b'\x00'
      (name, Boolean(b), 1 + name_size + 1)
    }
    b'\x09' => { // DateTime
      let millis = read_i64(bytes, value_offset)
      (name, DateTime(millis), 1 + name_size + 8)
    }
    b'\x0A' => // Null
      (name, Null, 1 + name_size)
    b'\x0B' => { // Regex
      let (pattern, pattern_size) = read_cstring(bytes, value_offset)
      let (options, options_size) = read_cstring(
        bytes,
        value_offset + pattern_size,
      )
      (
        name,
        Regex(pattern~, options~),
        1 + name_size + pattern_size + options_size,
      )
    }
    b'\x0D' => { // Code (JavaScript)
      let (code, size) = read_bson_string(bytes, value_offset)
      (name, Code(code), 1 + name_size + size)
    }
    b'\x0F' => { // CodeWithScope
      let total_size = read_i32(bytes, value_offset)
      let (code, code_size) = read_bson_string(bytes, value_offset + 4)
      let (scope_doc, _) = decode_document_from_bytes(
        bytes,
        value_offset + 4 + code_size,
      )
      let scope = match scope_doc {
        Document(m) => m
        _ => Map::new()
      }
      (name, CodeWithScope(code~, scope~), 1 + name_size + total_size)
    }
    b'\x10' => { // Int32
      let i = read_i32(bytes, value_offset)
      (name, Int32(i), 1 + name_size + 4)
    }
    b'\x11' => { // Timestamp
      let increment = read_i32(bytes, value_offset).reinterpret_as_uint()
      let timestamp = read_i32(bytes, value_offset + 4).reinterpret_as_uint()
      (name, Timestamp(increment~, timestamp~), 1 + name_size + 8)
    }
    b'\x12' => { // Int64
      let i = read_i64(bytes, value_offset)
      (name, Int64(i), 1 + name_size + 8)
    }
    b'\x13' => { // Decimal128
      let dec_bytes = slice_bytes(bytes, value_offset, 16)
      (name, Decimal128(dec_bytes), 1 + name_size + 16)
    }
    b'\x7F' => // MaxKey
      (name, MaxKey, 1 + name_size)
    b'\xFF' => // MinKey
      (name, MinKey, 1 + name_size)
    _ => raise BsonError::UnknownType(type_byte)
  }
}

///|
/// Decode a document from bytes, returns (document, bytes_consumed)
fn decode_document_from_bytes(
  bytes : Bytes,
  offset : Int,
) -> (BsonValue, Int) raise BsonError {
  let doc_size = read_i32(bytes, offset)
  let map : Map[String, BsonValue] = Map::new()
  let mut pos = offset + 4
  let end = offset + doc_size - 1 // -1 for terminator
  while pos < end {
    let (key, value, consumed) = decode_element(bytes, pos)
    map.set(key, value)
    pos = pos + consumed
  }
  (Document(map), doc_size)
}

///|
/// Decode bytes to BsonValue
pub fn decode_bson(bytes : Bytes) -> BsonValue raise BsonError {
  let (doc, _) = decode_document_from_bytes(bytes, 0)
  doc
}

///|
/// Show implementation for debugging
pub impl Show for BsonValue with output(self, logger) {
  match self {
    Double(d) => logger.write_string("Double(\{d})")
    String(s) => logger.write_string("String(\"\{s}\")")
    Document(_) => logger.write_string("Document{...}")
    Array(_) => logger.write_string("Array[...]")
    Binary(_, _) => logger.write_string("Binary(...)")
    ObjectId(_) => logger.write_string("ObjectId(...)")
    Boolean(b) => logger.write_string("Boolean(\{b})")
    DateTime(ms) => logger.write_string("DateTime(\{ms})")
    Null => logger.write_string("Null")
    Regex(pattern~, options~) =>
      logger.write_string("Regex(/\{pattern}/\{options})")
    Code(c) => logger.write_string("Code(\{c})")
    CodeWithScope(..) => logger.write_string("CodeWithScope(...)")
    Int32(i) => logger.write_string("Int32(\{i})")
    Timestamp(increment~, timestamp~) =>
      logger.write_string("Timestamp(\{timestamp}, \{increment})")
    Int64(i) => logger.write_string("Int64(\{i})")
    Decimal128(_) => logger.write_string("Decimal128(...)")
    MaxKey => logger.write_string("MaxKey")
    MinKey => logger.write_string("MinKey")
  }
}
