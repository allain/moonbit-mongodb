///|
/// Async MongoDB connection using TCP (internal)
struct Connection {
  tcp : @socket.TCP
  mut request_id : Int
}

///|
/// Connection errors
pub suberror MongoError {
  ConnectionFailed(String)
  SendFailed(String)
  ReceiveFailed(String)
  HandshakeFailed(String)
  InvalidResponse(String)
  ProtocolError(String)
  CommandFailed(String) // MongoDB returned ok:0 or error
  WriteError(String) // Write operation error
  Closed
}

///|
pub impl Show for MongoError with output(self, logger) {
  match self {
    ConnectionFailed(msg) => logger.write_string("ConnectionFailed: \{msg}")
    SendFailed(msg) => logger.write_string("SendFailed: \{msg}")
    ReceiveFailed(msg) => logger.write_string("ReceiveFailed: \{msg}")
    HandshakeFailed(msg) => logger.write_string("HandshakeFailed: \{msg}")
    InvalidResponse(msg) => logger.write_string("InvalidResponse: \{msg}")
    ProtocolError(msg) => logger.write_string("ProtocolError: \{msg}")
    CommandFailed(msg) => logger.write_string("CommandFailed: \{msg}")
    WriteError(msg) => logger.write_string("WriteError: \{msg}")
    Closed => logger.write_string("Connection closed")
  }
}

///|
/// Create a new async connection and connect to MongoDB (internal)
async fn Connection::connect(
  host : String,
  port : Int,
) -> Connection raise MongoError {
  let tcp = @socket.TCP::new()

  // Parse address
  let addr_str = "\{host}:\{port}"
  let addr = @socket.Addr::parse(addr_str) catch {
    _ => raise MongoError::ConnectionFailed("Invalid address: \{addr_str}")
  }

  // Connect
  tcp.connect(addr) catch {
    e => raise MongoError::ConnectionFailed("Failed to connect: \{e}")
  }
  let conn : Connection = { tcp, request_id: 1 }

  // Perform handshake
  conn.handshake()
  conn
}

///|
/// Get next request ID (internal)
fn Connection::next_request_id(self : Connection) -> Int {
  let id = self.request_id
  self.request_id = self.request_id + 1
  id
}

///|
/// Perform MongoDB handshake (hello command)
async fn Connection::handshake(self : Connection) -> Unit raise MongoError {
  let hello_cmd = @types.bson_document()
    .set("hello", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.send_command(hello_cmd)

  // Check for ok: 1 in response
  match response.get("ok") {
    Some(@types.Double(v)) =>
      if v != 1.0 {
        raise MongoError::HandshakeFailed("Server returned ok: \{v}")
      }
    Some(@types.Int32(v)) =>
      if v != 1 {
        raise MongoError::HandshakeFailed("Server returned ok: \{v}")
      }
    _ => raise MongoError::HandshakeFailed("No ok field in response")
  }
}

///|
/// Send a command and receive the response (internal)
async fn Connection::send_command(
  self : Connection,
  command : @types.BsonValue,
) -> @types.BsonValue raise MongoError {
  let request_id = self.next_request_id()

  // Create OpMsg
  let msg = @wire.OpMsg::new(request_id, command)

  // Encode to bytes
  let msg_bytes = msg.encode() catch {
    e => raise MongoError::ProtocolError("Failed to encode message: \{e}")
  }

  // Send the message
  self.tcp.send(msg_bytes) catch {
    e => raise MongoError::SendFailed("Failed to send: \{e}")
  }

  // Receive the response header (16 bytes)
  let header_bytes = self.tcp.recv_exactly(16) catch {
    @socket.ConnectionClosed => raise MongoError::Closed
    e => raise MongoError::ReceiveFailed("Failed to receive header: \{e}")
  }

  // Parse header to get message length
  let msg_length = @wire.read_int32_le(header_bytes, 0)
  if msg_length < 16 {
    raise MongoError::ProtocolError("Invalid message length: \{msg_length}")
  }

  // Receive the rest of the message
  let remaining_len = msg_length - 16
  let body_bytes = if remaining_len > 0 {
    self.tcp.recv_exactly(remaining_len) catch {
      @socket.ConnectionClosed => raise MongoError::Closed
      e => raise MongoError::ReceiveFailed("Failed to receive body: \{e}")
    }
  } else {
    Bytes::new(0)
  }

  // Combine header and body
  let full_msg = combine_bytes(header_bytes, body_bytes)

  // Parse the response
  let response_msg = @wire.OpMsg::decode(full_msg) catch {
    e => raise MongoError::ProtocolError("Failed to decode response: \{e}")
  }

  // Extract the body document
  match response_msg.body() {
    Some(doc) => doc
    None => raise MongoError::InvalidResponse("No body in response")
  }
}

///|
/// Close the connection (internal)
fn Connection::close(self : Connection) -> Unit {
  self.tcp.close()
}

///|
/// Combine two Bytes into one
fn combine_bytes(a : Bytes, b : Bytes) -> Bytes {
  let arr : Array[Byte] = []
  for i = 0; i < a.length(); i = i + 1 {
    arr.push(a[i])
  }
  for i = 0; i < b.length(); i = i + 1 {
    arr.push(b[i])
  }
  Bytes::from_array(arr)
}
