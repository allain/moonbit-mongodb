///|
/// Test BSON document creation and manipulation
test "bson_document" {
  let doc = bson_document()
    .set("name", bson_string("Alice"))
    .set("age", bson_int32(30))
    .set("active", bson_bool(true))
  inspect(doc.get("name"), content="Some(String(\"Alice\"))")
  inspect(doc.get("age"), content="Some(Int32(30))")
  inspect(doc.get("active"), content="Some(Boolean(true))")
  inspect(doc.get("missing"), content="None")
}

///|
/// Test BSON array creation and manipulation
test "bson_array" {
  let arr = bson_array()
    .push(bson_string("first"))
    .push(bson_int32(42))
    .push(bson_null())
  inspect(arr.get_index(0), content="Some(String(\"first\"))")
  inspect(arr.get_index(1), content="Some(Int32(42))")
  inspect(arr.get_index(2), content="Some(Null)")
  inspect(arr.length(), content="3")
}

///|
/// Test nested BSON documents
test "bson_nested" {
  let inner = bson_document()
    .set("city", bson_string("New York"))
    .set("zip", bson_string("10001"))
  let doc = bson_document()
    .set("name", bson_string("Bob"))
    .set("address", inner)
  match doc.get("address") {
    Some(addr) => {
      inspect(addr.get("city"), content="Some(String(\"New York\"))")
      inspect(addr.get("zip"), content="Some(String(\"10001\"))")
    }
    None => fail("Expected address field")
  }
}

///|
/// Test ObjectId creation from hex string
test "objectid_from_hex" {
  let oid = @types.ObjectId::from_hex("507f1f77bcf86cd799439011")
  inspect(oid is Some(_), content="true")
  match oid {
    Some(o) => {
      let hex = o.to_hex()
      inspect(hex == "507f1f77bcf86cd799439011", content="true")
    }
    None => fail("ObjectId should be Some")
  }
}

///|
/// Test ObjectId invalid hex string
test "objectid_invalid_hex" {
  let oid1 = @types.ObjectId::from_hex("invalid")
  inspect(oid1 is None, content="true")
  let oid2 = @types.ObjectId::from_hex("507f1f77bcf86cd79943901") // too short
  inspect(oid2 is None, content="true")
  let oid3 = @types.ObjectId::from_hex("507f1f77bcf86cd7994390111") // too long
  inspect(oid3 is None, content="true")
}

///|
/// Test ObjectId generator
test "objectid_generator" {
  let gen = new_object_id_generator(
    Bytes::from_array([b'\x01', b'\x02', b'\x03', b'\x04', b'\x05']),
  )
  let oid1 = gen.generate(1704067200) // Some timestamp
  let oid2 = gen.generate(1704067200)
  // ObjectIds should be different (counter increments)
  inspect(oid1.to_hex() != oid2.to_hex(), content="true")
  // Timestamps should be the same
  inspect(oid1.timestamp() == 1704067200, content="true")
  inspect(oid2.timestamp() == 1704067200, content="true")
}

///|
/// Test URI parsing
test "parse_uri_basic" {
  let result = parse_uri("mongodb://localhost:27017/testdb")
  match result {
    Some((host, port, db)) => {
      inspect(host == "localhost", content="true")
      inspect(port, content="27017")
      match db {
        Some(d) => inspect(d == "testdb", content="true")
        None => fail("Expected database")
      }
    }
    None => fail("URI parsing failed")
  }
}

///|
/// Test URI parsing with default port
test "parse_uri_default_port" {
  let result = parse_uri("mongodb://localhost/testdb")
  match result {
    Some((host, port, db)) => {
      inspect(host == "localhost", content="true")
      inspect(port, content="27017")
      match db {
        Some(d) => inspect(d == "testdb", content="true")
        None => fail("Expected database")
      }
    }
    None => fail("URI parsing failed")
  }
}

///|
/// Test URI parsing without database
test "parse_uri_no_db" {
  let result = parse_uri("mongodb://localhost:27017")
  match result {
    Some((host, port, db)) => {
      inspect(host == "localhost", content="true")
      inspect(port, content="27017")
      inspect(db is None, content="true")
    }
    None => fail("URI parsing failed")
  }
}

///|
/// Test invalid URI
test "parse_uri_invalid" {
  let result = parse_uri("http://localhost:27017")
  inspect(result is None, content="true")
}

///|
/// Test wire protocol header encoding/decoding
test "wire_header" {
  let header = @wire.MsgHeader::from_response(100, 42, 0, 2013)
  let bytes = header.encode()
  inspect(bytes.length(), content="16")
  let decoded = @wire.MsgHeader::decode(bytes)
  inspect(decoded.message_length(), content="100")
  inspect(decoded.request_id(), content="42")
  inspect(decoded.response_to(), content="0")
  inspect(decoded.op_code(), content="2013")
}

///|
/// Test BSON encoding of a simple document
test "bson_encode_simple" {
  let doc = bson_document()
    .set("name", bson_string("test"))
    .set("value", bson_int32(42))
  let encoded = @types.encode_bson(doc)
  // Verify it's a non-empty bytes
  inspect(encoded.length() > 0, content="true")
}

///|
/// Test BSON encoding and decoding roundtrip
test "bson_roundtrip" {
  let doc = bson_document()
    .set("name", bson_string("test"))
    .set("value", bson_int32(42))
    .set("flag", bson_bool(true))
  let encoded = @types.encode_bson(doc)
  let decoded = @types.decode_bson(encoded)
  inspect(decoded.get("name"), content="Some(String(\"test\"))")
  inspect(decoded.get("value"), content="Some(Int32(42))")
  inspect(decoded.get("flag"), content="Some(Boolean(true))")
}

///|
/// Test JSON to BSON conversion
test "json_to_bson" {
  let json : Json = { "name": "Alice", "age": 30, "active": true }
  let bson = @types.json_to_bson(json)
  inspect(bson.get("name"), content="Some(String(\"Alice\"))")
  inspect(bson.get("age"), content="Some(Double(30))")
  inspect(bson.get("active"), content="Some(Boolean(true))")
}

///|
/// Test BSON to JSON conversion
test "bson_to_json" {
  let bson = bson_document()
    .set("name", bson_string("Bob"))
    .set("count", bson_int32(42))
  let json = @types.bson_to_json(bson)
  // Check individual fields since map order is not guaranteed
  match json {
    { "name": String(name), "count": Number(count, ..), .. } => {
      inspect(name == "Bob", content="true")
      inspect(count.to_int() == 42, content="true")
    }
    _ => fail("Expected object with name and count")
  }
}

///|
/// Test JSON with nested objects
test "json_nested" {
  let json : Json = { "user": { "name": "Charlie", "address": { "city": "NYC" } } }
  let bson = @types.json_to_bson(json)
  match bson.get("user") {
    Some(user) =>
      match user.get("address") {
        Some(addr) => inspect(addr.get("city"), content="Some(String(\"NYC\"))")
        None => fail("Expected address field")
      }
    None => fail("Expected user field")
  }
}

///|
/// Test JSON arrays
test "json_array" {
  let json : Json = { "items": [1, 2, 3], "names": ["a", "b"] }
  let bson = @types.json_to_bson(json)
  match bson.get("items") {
    Some(arr) => inspect(arr.length(), content="3")
    None => fail("Expected items field")
  }
}

///|
/// Test Extended JSON ObjectId
test "json_extended_oid" {
  let json : Json = { "$oid": "507f1f77bcf86cd799439011" }
  let bson = @types.json_to_bson(json)
  match bson {
    @types.ObjectId(_) => inspect(true, content="true")
    _ => fail("Expected ObjectId")
  }
}

///|
/// Test Extended JSON Int64
test "json_extended_int64" {
  let json : Json = { "$numberLong": "9223372036854775807" }
  let bson = @types.json_to_bson(json)
  match bson {
    @types.Int64(n) => inspect(n == 9223372036854775807L, content="true")
    _ => fail("Expected Int64")
  }
}
