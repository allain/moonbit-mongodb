///|
/// Async MongoDB connection using TCP
pub struct AsyncConnection {
  tcp : @socket.TCP
  mut request_id : Int
  host : String
  port : Int
}

///|
/// Connection errors
pub suberror AsyncConnectionError {
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
pub impl Show for AsyncConnectionError with output(self, logger) {
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
/// Create a new async connection and connect to MongoDB
pub async fn AsyncConnection::connect(
  host : String,
  port : Int,
) -> AsyncConnection raise AsyncConnectionError {
  let tcp = @socket.TCP::new()

  // Parse address
  let addr_str = "\{host}:\{port}"
  let addr = @socket.Addr::parse(addr_str) catch {
    _ =>
      raise AsyncConnectionError::ConnectionFailed(
        "Invalid address: \{addr_str}",
      )
  }

  // Connect
  tcp.connect(addr) catch {
    e => raise AsyncConnectionError::ConnectionFailed("Failed to connect: \{e}")
  }
  let conn : AsyncConnection = { tcp, request_id: 1, host, port }

  // Perform handshake
  conn.handshake()
  conn
}

///|
/// Get next request ID
pub fn AsyncConnection::next_request_id(self : AsyncConnection) -> Int {
  let id = self.request_id
  self.request_id = self.request_id + 1
  id
}

///|
/// Perform MongoDB handshake (hello command)
async fn AsyncConnection::handshake(
  self : AsyncConnection,
) -> Unit raise AsyncConnectionError {
  let hello_cmd = @types.bson_document()
    .set("hello", @types.bson_int32(1))
    .set("$db", @types.bson_string("admin"))
  let response = self.send_command(hello_cmd)

  // Check for ok: 1 in response
  match response.get("ok") {
    Some(@types.Double(v)) =>
      if v != 1.0 {
        raise AsyncConnectionError::HandshakeFailed("Server returned ok: \{v}")
      }
    Some(@types.Int32(v)) =>
      if v != 1 {
        raise AsyncConnectionError::HandshakeFailed("Server returned ok: \{v}")
      }
    _ => raise AsyncConnectionError::HandshakeFailed("No ok field in response")
  }
}

///|
/// Send a command and receive the response
pub async fn AsyncConnection::send_command(
  self : AsyncConnection,
  command : @types.BsonValue,
) -> @types.BsonValue raise AsyncConnectionError {
  let request_id = self.next_request_id()

  // Create OpMsg
  let msg = @wire.OpMsg::new(request_id, command)

  // Encode to bytes
  let msg_bytes = msg.encode() catch {
    e =>
      raise AsyncConnectionError::ProtocolError(
        "Failed to encode message: \{e}",
      )
  }

  // Send the message
  self.tcp.send(msg_bytes) catch {
    e => raise AsyncConnectionError::SendFailed("Failed to send: \{e}")
  }

  // Receive the response header (16 bytes)
  let header_bytes = self.tcp.recv_exactly(16) catch {
    @socket.ConnectionClosed => raise AsyncConnectionError::Closed
    e =>
      raise AsyncConnectionError::ReceiveFailed(
        "Failed to receive header: \{e}",
      )
  }

  // Parse header to get message length
  let msg_length = @wire.read_int32_le(header_bytes, 0)
  if msg_length < 16 {
    raise AsyncConnectionError::ProtocolError(
      "Invalid message length: \{msg_length}",
    )
  }

  // Receive the rest of the message
  let remaining_len = msg_length - 16
  let body_bytes = if remaining_len > 0 {
    self.tcp.recv_exactly(remaining_len) catch {
      @socket.ConnectionClosed => raise AsyncConnectionError::Closed
      e =>
        raise AsyncConnectionError::ReceiveFailed(
          "Failed to receive body: \{e}",
        )
    }
  } else {
    Bytes::new(0)
  }

  // Combine header and body
  let full_msg = combine_bytes(header_bytes, body_bytes)

  // Parse the response
  let response_msg = @wire.OpMsg::decode(full_msg) catch {
    e =>
      raise AsyncConnectionError::ProtocolError(
        "Failed to decode response: \{e}",
      )
  }

  // Extract the body document
  match response_msg.body() {
    Some(doc) => doc
    None => raise AsyncConnectionError::InvalidResponse("No body in response")
  }
}

///|
/// Close the connection
pub fn AsyncConnection::close(self : AsyncConnection) -> Unit {
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
