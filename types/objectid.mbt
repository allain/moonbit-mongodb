///|
/// ObjectId - MongoDB's 12-byte unique identifier
/// Format: 4-byte timestamp + 5-byte random + 3-byte counter
pub struct ObjectId {
  bytes : Bytes
}

///|
/// ObjectId generator with state
pub struct ObjectIdGenerator {
  mut counter : Int
  random_bytes : Bytes
}

///|
/// Create a new ObjectId generator
pub fn ObjectIdGenerator::new(random_bytes : Bytes) -> ObjectIdGenerator {
  let rb = if random_bytes.length() >= 5 {
    random_bytes
  } else {
    // Default random bytes
    Bytes::from_array([b'\xAB', b'\xCD', b'\xEF', b'\x12', b'\x34'])
  }
  { counter: 0, random_bytes: rb }
}

///|
/// Generate a new ObjectId
pub fn ObjectIdGenerator::generate(
  self : ObjectIdGenerator,
  timestamp : Int,
) -> ObjectId {
  let arr : Array[Byte] = []

  // 4-byte timestamp (big-endian as per MongoDB spec)
  arr.push(((timestamp >> 24) & 0xFF).to_byte())
  arr.push(((timestamp >> 16) & 0xFF).to_byte())
  arr.push(((timestamp >> 8) & 0xFF).to_byte())
  arr.push((timestamp & 0xFF).to_byte())

  // 5-byte random (process identifier)
  for i = 0; i < 5; i = i + 1 {
    arr.push(self.random_bytes[i])
  }

  // 3-byte counter (big-endian)
  arr.push(((self.counter >> 16) & 0xFF).to_byte())
  arr.push(((self.counter >> 8) & 0xFF).to_byte())
  arr.push((self.counter & 0xFF).to_byte())
  self.counter = self.counter + 1
  if self.counter > 0xFFFFFF {
    self.counter = 0
  }
  { bytes: Bytes::from_array(arr) }
}

///|
/// Create ObjectId from 24-character hex string
pub fn ObjectId::from_hex(hex : String) -> ObjectId? {
  if hex.length() != 24 {
    return None
  }
  let arr : Array[Byte] = []
  let chars = hex.to_array()
  for i = 0; i < 12; i = i + 1 {
    let hi = hex_char_to_int(chars[i * 2])
    let lo = hex_char_to_int(chars[i * 2 + 1])
    match (hi, lo) {
      (Some(h), Some(l)) => arr.push(((h << 4) | l).to_byte())
      _ => return None
    }
  }
  Some({ bytes: Bytes::from_array(arr) })
}

///|
/// Create ObjectId from raw bytes (must be 12 bytes)
pub fn ObjectId::from_bytes(bytes : Bytes) -> ObjectId? {
  if bytes.length() != 12 {
    return None
  }
  Some(ObjectId::{ bytes, })
}

///|
/// Convert ObjectId to hex string
pub fn ObjectId::to_hex(self : ObjectId) -> String {
  let buf = @buffer.new()
  for i = 0; i < 12; i = i + 1 {
    let b = self.bytes[i].to_int()
    buf.write_char(int_to_hex_char((b >> 4) & 0xF))
    buf.write_char(int_to_hex_char(b & 0xF))
  }
  buf.to_string()
}

///|
/// Get the raw bytes
pub fn ObjectId::to_bytes(self : ObjectId) -> Bytes {
  self.bytes
}

///|
/// Convert to BsonValue
pub fn ObjectId::to_bson(self : ObjectId) -> BsonValue {
  BsonValue::ObjectId(self.bytes)
}

///|
/// Get timestamp from ObjectId (first 4 bytes, big-endian)
pub fn ObjectId::timestamp(self : ObjectId) -> Int {
  (self.bytes[0].to_int() << 24) |
  (self.bytes[1].to_int() << 16) |
  (self.bytes[2].to_int() << 8) |
  self.bytes[3].to_int()
}

///|
/// Convert hex character to integer
fn hex_char_to_int(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
/// Convert integer to hex character
fn int_to_hex_char(i : Int) -> Char {
  if i < 10 {
    Int::unsafe_to_char(i + '0'.to_int())
  } else {
    Int::unsafe_to_char(i - 10 + 'a'.to_int())
  }
}

///|
/// Show implementation
pub impl Show for ObjectId with output(self, logger) {
  logger.write_string("ObjectId(\"")
  logger.write_string(self.to_hex())
  logger.write_string("\")")
}
