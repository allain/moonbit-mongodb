///|
/// Connection pooling for MongoDB

///|
/// Pool configuration options
pub struct PoolOptions {
  min_pool_size : Int
  max_pool_size : Int
  max_idle_time_ms : Int
  wait_queue_timeout_ms : Int
}

///|
/// Create default pool options
pub fn PoolOptions::default() -> PoolOptions {
  {
    min_pool_size: 0,
    max_pool_size: 100,
    max_idle_time_ms: 0, // No limit
    wait_queue_timeout_ms: 0, // No limit
  }
}

///|
/// A pooled connection (internal)
struct PooledConnection {
  conn : Connection
  mut in_use : Bool
}

///|
/// Connection pool
pub struct ConnectionPool {
  options : PoolOptions
  connections : Array[PooledConnection]
  mut size : Int
  host : String
  port : Int
}

///|
/// Create a new connection pool
pub fn ConnectionPool::new(
  host : String,
  port : Int,
  options? : PoolOptions,
) -> ConnectionPool {
  {
    options: options.unwrap_or(PoolOptions::default()),
    connections: [],
    size: 0,
    host,
    port,
  }
}

///|
/// Acquire a connection from the pool
pub async fn ConnectionPool::acquire(
  self : ConnectionPool,
) -> PooledConnection raise MongoError {
  // Look for an available connection
  for conn in self.connections {
    if not(conn.in_use) {
      conn.in_use = true
      return conn
    }
  }

  // Create a new connection if under max
  if self.size < self.options.max_pool_size {
    let conn = Connection::connect(self.host, self.port)
    let pooled = { conn, in_use: true }
    self.connections.push(pooled)
    self.size = self.size + 1
    return pooled
  }

  // Pool exhausted - in a real implementation, we'd wait
  raise MongoError::ConnectionFailed("Connection pool exhausted")
}

///|
/// Release a connection back to the pool
pub fn ConnectionPool::release(
  self : ConnectionPool,
  conn : PooledConnection,
) -> Unit {
  conn.in_use = false
  ignore(self)
}

///|
/// Close all connections in the pool
pub fn ConnectionPool::close(self : ConnectionPool) -> Unit {
  for conn in self.connections {
    conn.conn.close()
  }
  self.connections.clear()
  self.size = 0
}

///|
/// Get current pool size
pub fn ConnectionPool::current_size(self : ConnectionPool) -> Int {
  self.size
}

///|
/// Get number of available connections
pub fn ConnectionPool::available_count(self : ConnectionPool) -> Int {
  let mut count = 0
  for conn in self.connections {
    if not(conn.in_use) {
      count = count + 1
    }
  }
  count
}

///|
/// Get number of in-use connections
pub fn ConnectionPool::in_use_count(self : ConnectionPool) -> Int {
  self.size - self.available_count()
}

///|
/// Execute an operation with a pooled connection
pub async fn[T] ConnectionPool::with_connection(
  self : ConnectionPool,
  operation : async (Connection) -> T raise MongoError,
) -> T raise MongoError {
  let pooled = self.acquire()
  let result = operation(pooled.conn) catch {
    err => {
      self.release(pooled)
      raise err
    }
  }
  self.release(pooled)
  result
}
