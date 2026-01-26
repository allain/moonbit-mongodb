///|
/// MongoDB wire protocol message header
/// All integers are little-endian encoded
pub struct MsgHeader {
  /// Total message size, including this header
  message_length : Int
  /// Unique client-generated request identifier
  request_id : Int
  /// For responses, the request_id from the original request; otherwise 0
  response_to : Int
  /// Message type: 2013 for OP_MSG
  op_code : Int
}

///|
/// OP_MSG opcode constant
pub let opmsg_opcode : Int = 2013

///|
/// Header size in bytes
pub let header_size : Int = 16

///|
/// Create a new message header for a request
pub fn MsgHeader::new(message_length : Int, request_id : Int) -> MsgHeader {
  { message_length, request_id, response_to: 0, op_code: opmsg_opcode }
}

///|
/// Create a header from parsed response data
pub fn MsgHeader::from_response(
  message_length : Int,
  request_id : Int,
  response_to : Int,
  op_code : Int,
) -> MsgHeader {
  { message_length, request_id, response_to, op_code }
}

///|
/// Get message length
pub fn MsgHeader::message_length(self : MsgHeader) -> Int {
  self.message_length
}

///|
/// Get request id
pub fn MsgHeader::request_id(self : MsgHeader) -> Int {
  self.request_id
}

///|
/// Get response to
pub fn MsgHeader::response_to(self : MsgHeader) -> Int {
  self.response_to
}

///|
/// Get op code
pub fn MsgHeader::op_code(self : MsgHeader) -> Int {
  self.op_code
}

///|
/// Encode header to bytes (16 bytes, little-endian)
pub fn MsgHeader::encode(self : MsgHeader) -> Bytes {
  let arr : Array[Byte] = []
  write_int32_le_arr(arr, self.message_length)
  write_int32_le_arr(arr, self.request_id)
  write_int32_le_arr(arr, self.response_to)
  write_int32_le_arr(arr, self.op_code)
  Bytes::from_array(arr)
}

///|
/// Write a 32-bit integer in little-endian format to array
fn write_int32_le_arr(arr : Array[Byte], value : Int) -> Unit {
  arr.push((value & 0xFF).to_byte())
  arr.push(((value >> 8) & 0xFF).to_byte())
  arr.push(((value >> 16) & 0xFF).to_byte())
  arr.push(((value >> 24) & 0xFF).to_byte())
}

///|
/// Decode header from bytes
pub fn MsgHeader::decode(bytes : Bytes) -> MsgHeader raise WireError {
  if bytes.length() < 16 {
    raise WireError::InvalidHeader("Header too short: expected 16 bytes")
  }
  let message_length = read_int32_le(bytes, 0)
  let request_id = read_int32_le(bytes, 4)
  let response_to = read_int32_le(bytes, 8)
  let op_code = read_int32_le(bytes, 12)
  { message_length, request_id, response_to, op_code }
}

///|
/// Read a 32-bit integer in little-endian format
pub fn read_int32_le(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}

///|
/// Read a 32-bit unsigned integer in little-endian format
pub fn read_uint32_le(bytes : Bytes, offset : Int) -> UInt {
  bytes[offset].to_uint() |
  (bytes[offset + 1].to_uint() << 8) |
  (bytes[offset + 2].to_uint() << 16) |
  (bytes[offset + 3].to_uint() << 24)
}

///|
/// Read a 64-bit integer in little-endian format
pub fn read_int64_le(bytes : Bytes, offset : Int) -> Int64 {
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
/// Write a 64-bit integer in little-endian format
pub fn write_int64_le_to_array(arr : Array[Byte], value : Int64) -> Unit {
  arr.push((value & 0xFFL).to_byte())
  arr.push(((value >> 8) & 0xFFL).to_byte())
  arr.push(((value >> 16) & 0xFFL).to_byte())
  arr.push(((value >> 24) & 0xFFL).to_byte())
  arr.push(((value >> 32) & 0xFFL).to_byte())
  arr.push(((value >> 40) & 0xFFL).to_byte())
  arr.push(((value >> 48) & 0xFFL).to_byte())
  arr.push(((value >> 56) & 0xFFL).to_byte())
}
