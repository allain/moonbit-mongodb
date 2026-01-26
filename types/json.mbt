///|
/// Convert a JSON value to a BSON value
/// Note: JSON numbers are converted to Double in BSON
pub fn json_to_bson(json : Json) -> BsonValue {
  match json {
    Null => BsonValue::Null
    True => Boolean(true)
    False => Boolean(false)
    Number(n, ..) => Double(n)
    String(s) => BsonValue::String(s)
    Array(arr) => {
      let bson_arr : Array[BsonValue] = []
      for item in arr {
        bson_arr.push(json_to_bson(item))
      }
      BsonValue::Array(bson_arr)
    }
    Object(entries) => {
      // Check for MongoDB Extended JSON types first
      if entries.length() == 1 {
        for key, value in entries {
          match parse_extended_json(key, value) {
            Some(bson) => return bson
            None => ()
          }
        }
      }
      // Check for regex with options (2 keys: $regex and $options)
      if entries.length() == 2 {
        match (entries.get("$regex"), entries.get("$options")) {
          (Some(String(pattern)), Some(String(options))) =>
            return Regex(pattern~, options~)
          (Some(String(pattern)), None) => return Regex(pattern~, options="")
          _ => ()
        }
      }
      // Check for timestamp (2 keys: t and i in $timestamp)
      if entries.length() == 1 {
        match entries.get("$timestamp") {
          Some(Object(ts)) =>
            match (ts.get("t"), ts.get("i")) {
              (Some(Number(t, ..)), Some(Number(i, ..))) =>
                return Timestamp(
                  increment=i.to_int().reinterpret_as_uint(),
                  timestamp=t.to_int().reinterpret_as_uint(),
                )
              _ => ()
            }
          _ => ()
        }
      }
      // Check for code with scope
      if entries.length() == 2 {
        match (entries.get("$code"), entries.get("$scope")) {
          (Some(String(code)), Some(Object(scope_json))) => {
            let scope : Map[String, BsonValue] = Map::new()
            for key, value in scope_json {
              scope.set(key, json_to_bson(value))
            }
            return CodeWithScope(code~, scope~)
          }
          _ => ()
        }
      }
      let map : Map[String, BsonValue] = Map::new()
      for key, value in entries {
        map.set(key, json_to_bson(value))
      }
      Document(map)
    }
  }
}

///|
/// Parse MongoDB Extended JSON types like $oid, $date, etc.
fn parse_extended_json(key : String, value : Json) -> BsonValue? {
  match key {
    "$oid" =>
      match value {
        String(hex) =>
          match ObjectId::from_hex(hex) {
            Some(oid) => Some(ObjectId(oid.bytes))
            None => None
          }
        _ => None
      }
    "$date" =>
      match value {
        Number(n, ..) => Some(DateTime(n.to_int64()))
        _ => None
      }
    "$numberInt" =>
      match value {
        String(s) => {
          let n = @strconv.parse_int(s) catch { _ => return None }
          Some(Int32(n))
        }
        Number(n, ..) => Some(Int32(n.to_int()))
        _ => None
      }
    "$numberLong" =>
      match value {
        String(s) => {
          let n = @strconv.parse_int64(s) catch { _ => return None }
          Some(Int64(n))
        }
        Number(n, ..) => Some(Int64(n.to_int64()))
        _ => None
      }
    "$minKey" => Some(MinKey)
    "$maxKey" => Some(MaxKey)
    "$code" =>
      match value {
        String(code) => Some(Code(code))
        _ => None
      }
    "$regex" => None // Handled separately with $options
    "$numberDecimal" =>
      match value {
        String(_) =>
          // Decimal128 parsing from string requires IEEE 754 decimal implementation
          // For now, create a placeholder with zero bytes
          Some(Decimal128(Bytes::new(16)))
        _ => None
      }
    _ => None
  }
}

///|
/// Convert a BSON value to a JSON value
/// Note: Some BSON types use MongoDB Extended JSON format
pub fn bson_to_json(bson : BsonValue) -> Json {
  match bson {
    Null => Json::null()
    Boolean(b) => Json::boolean(b)
    Double(d) => Json::number(d)
    BsonValue::String(s) => Json::string(s)
    Int32(n) => Json::number(n.to_double())
    Int64(n) =>
      // Use extended JSON for Int64 to preserve precision
      Json::object({ "$numberLong": Json::string(n.to_string()) })
    DateTime(millis) =>
      Json::object({ "$date": Json::number(millis.to_double()) })
    ObjectId(bytes) =>
      match ObjectId::from_bytes(bytes) {
        Some(oid) => Json::object({ "$oid": Json::string(oid.to_hex()) })
        None => Json::null() // Invalid ObjectId bytes
      }
    Binary(data, subtype) => {
      let hex = bytes_to_hex(data)
      Json::object(
        {
          "$binary": Json::object(
            {
              "base64": Json::string(hex),
              "subType": Json::string(subtype.to_int().to_string()),
            },
          ),
        },
      )
    }
    Regex(pattern~, options~) =>
      Json::object(
        { "$regex": Json::string(pattern), "$options": Json::string(options) },
      )
    Code(code) => Json::object({ "$code": Json::string(code) })
    CodeWithScope(code~, scope~) => {
      let scope_json : Map[String, Json] = {}
      for key, value in scope {
        scope_json[key] = bson_to_json(value)
      }
      Json::object(
        { "$code": Json::string(code), "$scope": Json::object(scope_json) },
      )
    }
    Timestamp(increment~, timestamp~) =>
      Json::object(
        {
          "$timestamp": Json::object(
            {
              "t": Json::number(timestamp.reinterpret_as_int().to_double()),
              "i": Json::number(increment.reinterpret_as_int().to_double()),
            },
          ),
        },
      )
    Decimal128(bytes) => {
      // Convert bytes to hex for now (full decimal128 string conversion would need IEEE 754)
      let hex = bytes_to_hex(bytes)
      Json::object({ "$numberDecimal": Json::string(hex) })
    }
    MinKey => Json::object({ "$minKey": Json::number(1.0) })
    MaxKey => Json::object({ "$maxKey": Json::number(1.0) })
    BsonValue::Array(arr) => {
      let json_arr : Array[Json] = []
      for item in arr {
        json_arr.push(bson_to_json(item))
      }
      Json::array(json_arr)
    }
    Document(map) => {
      let json_map : Map[String, Json] = {}
      for key, value in map {
        json_map[key] = bson_to_json(value)
      }
      Json::object(json_map)
    }
  }
}

///|
/// Convert bytes to hex string (for Binary type)
fn bytes_to_hex(bytes : Bytes) -> String {
  let hex_chars = "0123456789abcdef"
  let buf = @buffer.new()
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i].to_int()
    buf.write_char(Int::unsafe_to_char(hex_chars[b >> 4].to_int()))
    buf.write_char(Int::unsafe_to_char(hex_chars[b & 0x0F].to_int()))
  }
  buf.to_string()
}
