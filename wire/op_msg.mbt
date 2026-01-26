///|
/// OP_MSG flag bits
pub let flag_checksum_present : UInt = 1U // bit 0

///|
pub let flag_more_to_come : UInt = 2U // bit 1

///|
pub let flag_exhaust_allowed : UInt = 0x10000U // bit 16

///|
/// Section kind constants
let section_body : Byte = b'\x00'

///|
let section_doc_seq : Byte = b'\x01'

///|
/// OP_MSG Section types
pub enum Section {
  /// Kind 0: Single body document
  Body(@types.BsonValue)
  /// Kind 1: Document sequence (identifier + documents)
  DocumentSequence(String, Array[@types.BsonValue])
}

///|
/// OP_MSG message structure
pub struct OpMsg {
  /// Message header
  header : MsgHeader
  /// Flag bits
  flag_bits : UInt
  /// Message sections
  sections : Array[Section]
  /// Optional checksum (if flag_checksum_present is set)
  checksum : UInt?
}

///|
/// Create a new OP_MSG with a single body section
pub fn OpMsg::new(request_id : Int, body : @types.BsonValue) -> OpMsg {
  {
    header: MsgHeader::new(0, request_id), // message_length set during encoding
    flag_bits: 0U,
    sections: [Section::Body(body)],
    checksum: None,
  }
}

///|
/// Create an OP_MSG with body and document sequence
pub fn OpMsg::with_documents(
  request_id : Int,
  body : @types.BsonValue,
  identifier : String,
  documents : Array[@types.BsonValue],
) -> OpMsg {
  {
    header: MsgHeader::new(0, request_id),
    flag_bits: 0U,
    sections: [
      Section::Body(body),
      Section::DocumentSequence(identifier, documents),
    ],
    checksum: None,
  }
}

///|
/// Encode an OP_MSG to bytes
pub fn OpMsg::encode(self : OpMsg) -> Bytes raise WireError {
  let buf : Array[Byte] = []

  // Reserve 16 bytes for header (will be filled at the end)
  for i = 0; i < 16; i = i + 1 {
    buf.push(b'\x00')
  }

  // Write flag bits (4 bytes)
  write_uint32_le_to_array(buf, self.flag_bits)

  // Write sections
  for section in self.sections {
    match section {
      Body(doc) => {
        buf.push(section_body)
        let bson_bytes = @types.encode_bson(doc) catch {
          e => raise WireError::EncodingError("Failed to encode BSON: \{e}")
        }
        append_bytes(buf, bson_bytes)
      }
      DocumentSequence(identifier, docs) => {
        buf.push(section_doc_seq)
        // Reserve 4 bytes for section size
        let size_offset = buf.length()
        for i = 0; i < 4; i = i + 1 {
          buf.push(b'\x00')
        }
        let section_start = buf.length()

        // Write identifier as C-string
        write_cstring(buf, identifier)

        // Write documents
        for doc in docs {
          let bson_bytes = @types.encode_bson(doc) catch {
            e => raise WireError::EncodingError("Failed to encode BSON: \{e}")
          }
          append_bytes(buf, bson_bytes)
        }

        // Update section size (includes size field itself)
        let section_size = buf.length() - section_start + 4
        set_int32_le_at(buf, size_offset, section_size)
      }
    }
  }

  // Write checksum if present
  match self.checksum {
    Some(csum) => write_uint32_le_to_array(buf, csum)
    None => ()
  }

  // Update header with correct message length
  let message_length = buf.length()
  set_int32_le_at(buf, 0, message_length)
  set_int32_le_at(buf, 4, self.header.request_id)
  set_int32_le_at(buf, 8, self.header.response_to)
  set_int32_le_at(buf, 12, opmsg_opcode)
  array_to_bytes(buf)
}

///|
/// Decode an OP_MSG from bytes (including header)
pub fn OpMsg::decode(bytes : Bytes) -> OpMsg raise WireError {
  if bytes.length() < 21 { // 16 header + 4 flags + 1 section kind minimum
    raise WireError::DecodingError("Message too short")
  }

  // Decode header
  let header = MsgHeader::decode(bytes)
  if header.op_code != opmsg_opcode {
    raise WireError::InvalidOpCode(header.op_code)
  }

  // Read flag bits
  let flag_bits = read_uint32_le(bytes, 16)

  // Calculate if checksum is present
  let has_checksum = (flag_bits & flag_checksum_present) != 0U
  let end_offset = if has_checksum {
    header.message_length - 4
  } else {
    header.message_length
  }

  // Parse sections
  let sections : Array[Section] = []
  let mut offset = 20 // After header (16) and flags (4)
  while offset < end_offset {
    let kind = bytes[offset]
    offset = offset + 1
    if kind == section_body {
      // Read BSON document length
      let doc_len = read_int32_le(bytes, offset)
      let doc_bytes = slice_bytes(bytes, offset, doc_len)
      let doc = @types.decode_bson(doc_bytes) catch {
        e => raise WireError::DecodingError("Failed to decode BSON: \{e}")
      }
      sections.push(Section::Body(doc))
      offset = offset + doc_len
    } else if kind == section_doc_seq {
      // Read section size
      let section_size = read_int32_le(bytes, offset)
      let section_end = offset + section_size
      offset = offset + 4

      // Read identifier
      let (identifier, consumed) = read_cstring(bytes, offset)
      offset = offset + consumed

      // Read documents
      let docs : Array[@types.BsonValue] = []
      while offset < section_end {
        let doc_len = read_int32_le(bytes, offset)
        let doc_bytes = slice_bytes(bytes, offset, doc_len)
        let doc = @types.decode_bson(doc_bytes) catch {
          e => raise WireError::DecodingError("Failed to decode BSON: \{e}")
        }
        docs.push(doc)
        offset = offset + doc_len
      }
      sections.push(Section::DocumentSequence(identifier, docs))
    } else {
      raise WireError::InvalidSection("Unknown section kind: \{kind}")
    }
  }

  // Read checksum if present
  let checksum = if has_checksum {
    Some(read_uint32_le(bytes, end_offset))
  } else {
    None
  }
  { header, flag_bits, sections, checksum }
}

///|
/// Get the body document from an OP_MSG
pub fn OpMsg::body(self : OpMsg) -> @types.BsonValue? {
  for section in self.sections {
    match section {
      Body(doc) => return Some(doc)
      _ => continue
    }
  }
  None
}

///|
/// Get the cursor ID from a response (if present)
pub fn OpMsg::cursor_id(self : OpMsg) -> Int64? {
  match self.body() {
    Some(body) =>
      match body {
        @types.Document(map) =>
          match map.get("cursor") {
            Some(@types.Document(cursor_map)) =>
              match cursor_map.get("id") {
                Some(@types.Int64(id)) => Some(id)
                Some(@types.Int32(id)) => Some(id.to_int64())
                _ => None
              }
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
/// Check if the response indicates success (ok: 1)
pub fn OpMsg::is_ok(self : OpMsg) -> Bool {
  match self.body() {
    Some(body) =>
      match body {
        @types.Document(map) =>
          match map.get("ok") {
            Some(@types.Double(v)) => v == 1.0
            Some(@types.Int32(v)) => v == 1
            Some(@types.Int64(v)) => v == 1L
            _ => false
          }
        _ => false
      }
    None => false
  }
}
