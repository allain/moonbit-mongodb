///|
/// Wire protocol errors
pub suberror WireError {
  InvalidHeader(String)
  InvalidOpCode(Int)
  InvalidSection(String)
  EncodingError(String)
  DecodingError(String)
}

///|
pub impl Show for WireError with output(self, logger) {
  match self {
    InvalidHeader(msg) => logger.write_string("InvalidHeader: \{msg}")
    InvalidOpCode(code) => logger.write_string("InvalidOpCode: \{code}")
    InvalidSection(msg) => logger.write_string("InvalidSection: \{msg}")
    EncodingError(msg) => logger.write_string("EncodingError: \{msg}")
    DecodingError(msg) => logger.write_string("DecodingError: \{msg}")
  }
}

///|
/// Convert bytes to array for manipulation
pub fn bytes_to_array(bytes : Bytes) -> Array[Byte] {
  let arr : Array[Byte] = []
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
  arr
}

///|
/// Convert array to bytes
pub fn array_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
/// Append bytes to an array
pub fn append_bytes(arr : Array[Byte], bytes : Bytes) -> Unit {
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
}

///|
/// Write Int32 little-endian to array
pub fn write_int32_le_to_array(arr : Array[Byte], value : Int) -> Unit {
  arr.push((value & 0xFF).to_byte())
  arr.push(((value >> 8) & 0xFF).to_byte())
  arr.push(((value >> 16) & 0xFF).to_byte())
  arr.push(((value >> 24) & 0xFF).to_byte())
}

///|
/// Write UInt32 little-endian to array
pub fn write_uint32_le_to_array(arr : Array[Byte], value : UInt) -> Unit {
  arr.push((value & 0xFFU).to_byte())
  arr.push(((value >> 8) & 0xFFU).to_byte())
  arr.push(((value >> 16) & 0xFFU).to_byte())
  arr.push(((value >> 24) & 0xFFU).to_byte())
}

///|
/// Set Int32 little-endian at specific position in array
pub fn set_int32_le_at(arr : Array[Byte], offset : Int, value : Int) -> Unit {
  arr[offset] = (value & 0xFF).to_byte()
  arr[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  arr[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  arr[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}

///|
/// Write a C-string (null-terminated) to array
pub fn write_cstring(arr : Array[Byte], s : String) -> Unit {
  let buf = @buffer.new()
  buf.write_string_utf8(s)
  let bytes = buf.to_bytes()
  for i = 0; i < bytes.length(); i = i + 1 {
    arr.push(bytes[i])
  }
  arr.push(b'\x00')
}

///|
/// Slice bytes
pub fn slice_bytes(bytes : Bytes, offset : Int, len : Int) -> Bytes {
  let arr : Array[Byte] = []
  for i = 0; i < len; i = i + 1 {
    arr.push(bytes[offset + i])
  }
  Bytes::from_array(arr)
}

///|
/// Read a C-string from bytes starting at offset
/// Returns (string, bytes_consumed)
pub fn read_cstring(bytes : Bytes, offset : Int) -> (String, Int) {
  let mut end = offset
  while end < bytes.length() && bytes[end] != b'\x00' {
    end = end + 1
  }
  let len = end - offset
  let str_bytes = slice_bytes(bytes, offset, len)
  (str_bytes.to_unchecked_string(), len + 1) // +1 for null terminator
}
