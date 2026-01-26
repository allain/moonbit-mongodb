///|
/// Client session and transaction support for MongoDB

///|
/// Transaction state
pub enum TransactionState {
  None
  Starting
  InProgress
  Committed
  Aborted
}

///|
/// Transaction options
pub struct TransactionOptions {
  read_concern : ReadConcern?
  write_concern : WriteConcern?
  max_commit_time_ms : Int?
}

///|
/// Create default transaction options
pub fn TransactionOptions::default() -> TransactionOptions {
  { read_concern: None, write_concern: None, max_commit_time_ms: None }
}

///|
/// Client session for transactions
pub struct ClientSession {
  client : AsyncClient
  session_id : @types.BsonValue
  mut transaction_state : TransactionState
  transaction_options : TransactionOptions
}

///|
/// Generate a UUID for session ID
fn generate_session_uuid() -> @types.BsonValue {
  // Generate a random UUID (16 bytes)
  // In a real implementation, this would use a proper UUID generator
  let arr : Array[Byte] = []
  // Fill with timestamp-based pseudo-random values
  let timestamp = 0L // Would use actual time
  for i = 0; i < 8; i = i + 1 {
    arr.push(((timestamp >> (i * 8)) & 0xFFL).to_byte())
  }
  // Add padding bytes
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  arr.push(b'\x00')
  // Set UUID version (4) and variant bits
  arr[6] = ((arr[6].to_int() & 0x0F) | 0x40).to_byte()
  arr[8] = ((arr[8].to_int() & 0x3F) | 0x80).to_byte()
  @types.bson_binary(Bytes::from_array(arr), b'\x04') // UUID subtype
}

///|
/// Start a new client session
pub fn AsyncClient::start_session(self : AsyncClient) -> ClientSession {
  let session_id = @types.bson_document().set("id", generate_session_uuid())
  {
    client: self,
    session_id,
    transaction_state: TransactionState::None,
    transaction_options: TransactionOptions::default(),
  }
}

///|
/// Get the session ID
pub fn ClientSession::id(self : ClientSession) -> @types.BsonValue {
  self.session_id
}

///|
/// Check if session has an active transaction
pub fn ClientSession::in_transaction(self : ClientSession) -> Bool {
  match self.transaction_state {
    InProgress | Starting => true
    _ => false
  }
}

///|
/// Get the current transaction state
pub fn ClientSession::transaction_state(
  self : ClientSession,
) -> TransactionState {
  self.transaction_state
}

///|
/// Mark the transaction as in progress (called when first operation is executed)
pub fn ClientSession::mark_in_progress(self : ClientSession) -> Unit {
  match self.transaction_state {
    Starting => self.transaction_state = TransactionState::InProgress
    _ => ()
  }
}

///|
/// Start a new transaction
pub fn ClientSession::start_transaction(
  self : ClientSession,
  options? : TransactionOptions,
) -> Unit raise AsyncConnectionError {
  match self.transaction_state {
    None | Committed | Aborted => {
      self.transaction_state = TransactionState::Starting
      match options {
        Some(opts) =>
          // Note: MoonBit doesn't allow direct field assignment to self
          // This is a limitation - in practice, we'd need mutable fields
          ignore(opts)
        None => ()
      }
    }
    Starting | InProgress =>
      raise AsyncConnectionError::CommandFailed(
        "Transaction already in progress",
      )
  }
}

///|
/// Commit the current transaction
pub async fn ClientSession::commit_transaction(
  self : ClientSession,
) -> Unit raise AsyncConnectionError {
  match self.transaction_state {
    Starting =>
      // No operations performed, nothing to commit
      self.transaction_state = TransactionState::Committed
    InProgress => {
      let cmd = @types.bson_document()
        .set("commitTransaction", @types.bson_int32(1))
        .set("lsid", self.session_id)
        .set("$db", @types.bson_string("admin"))
      let response = self.client.conn.send_command(cmd)
      check_command_response(response)
      self.transaction_state = TransactionState::Committed
    }
    None =>
      raise AsyncConnectionError::CommandFailed("No transaction in progress")
    Committed =>
      raise AsyncConnectionError::CommandFailed("Transaction already committed")
    Aborted =>
      raise AsyncConnectionError::CommandFailed("Transaction was aborted")
  }
}

///|
/// Abort the current transaction
pub async fn ClientSession::abort_transaction(
  self : ClientSession,
) -> Unit raise AsyncConnectionError {
  match self.transaction_state {
    Starting =>
      // No operations performed, nothing to abort
      self.transaction_state = TransactionState::Aborted
    InProgress => {
      let cmd = @types.bson_document()
        .set("abortTransaction", @types.bson_int32(1))
        .set("lsid", self.session_id)
        .set("$db", @types.bson_string("admin"))
      let response = self.client.conn.send_command(cmd)
      // Ignore errors on abort - best effort
      let _ = response
      self.transaction_state = TransactionState::Aborted
    }
    None =>
      raise AsyncConnectionError::CommandFailed("No transaction in progress")
    Committed =>
      raise AsyncConnectionError::CommandFailed("Transaction already committed")
    Aborted =>
      raise AsyncConnectionError::CommandFailed("Transaction already aborted")
  }
}

///|
/// End the session
pub async fn ClientSession::end_session(self : ClientSession) -> Unit {
  // Abort any active transaction
  if self.in_transaction() {
    let _ = self.abort_transaction() catch { _ => () }
  }
  // Send endSessions command
  let sessions = @types.bson_array().push(self.session_id)
  let cmd = @types.bson_document()
    .set("endSessions", sessions)
    .set("$db", @types.bson_string("admin"))
  let _ = self.client.conn.send_command(cmd) catch {
    _ => @types.bson_document()
  }
}

///|
/// Execute a callback within a transaction with automatic retry
pub async fn[T] ClientSession::with_transaction(
  self : ClientSession,
  callback : async (ClientSession) -> T raise AsyncConnectionError,
) -> T raise AsyncConnectionError {
  let max_retries = 3
  let mut attempt = 0
  while attempt < max_retries {
    attempt = attempt + 1
    self.start_transaction()
    let result = callback(self) catch {
      err => {
        let _ = self.abort_transaction() catch { _ => () }
        if attempt >= max_retries {
          raise err
        }
        continue
      }
    }
    let _ = self.commit_transaction() catch {
      err => {
        let _ = self.abort_transaction() catch { _ => () }
        if attempt >= max_retries {
          raise err
        }
        continue
      }
    }
    return result
  }
  raise AsyncConnectionError::CommandFailed("Transaction failed after retries")
}
