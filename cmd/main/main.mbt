///|
/// MongoDB async client integration test using JSON API
fn main {
  @async.with_event_loop(run_test) catch {
    e => println("Error: \{e}")
  }
}

///|
/// Run the async MongoDB test
async fn run_test(_group : @async.TaskGroup[Unit]) -> Unit {
  println("Connecting to MongoDB at localhost:27017...")
  let client = @async_client.AsyncClient::connect("127.0.0.1", 27017) catch {
    e => {
      println("Failed to connect: \{e}")
      return
    }
  }
  println("Connected successfully!")
  let db = client.database("test_moonbit")
  let coll = db.collection("users")
  println("\n--- Testing Insert (JSON API) ---")

  // Insert documents using JSON literals - no BSON knowledge needed!
  let result = coll.insert_all(
    [
      { "name": "Alice", "age": 30, "city": "New York" },
      { "name": "Bob", "age": 25, "city": "Los Angeles" },
      { "name": "Charlie", "age": 35, "city": "Chicago" },
    ],
  ) catch {
    e => {
      println("Insert failed: \{e}")
      client.close()
      return
    }
  }
  println("Inserted \{result.inserted_count} documents")
  println("\n--- Testing Find (JSON API) ---")

  // Find all documents - returns Json array
  let docs = coll.query({}, limit=10) catch {
    e => {
      println("Find failed: \{e}")
      client.close()
      return
    }
  }
  println("Found \{docs.length()} documents:")
  for doc in docs {
    // Access JSON fields directly
    let name = match doc {
      { "name": String(n), .. } => n
      _ => "?"
    }
    let age = match doc {
      { "age": Number(a, ..), .. } => a.to_int().to_string()
      _ => "?"
    }
    let city = match doc {
      { "city": String(c), .. } => c
      _ => "?"
    }
    println("  - \{name}, age: \{age}, city: \{city}")
  }
  println("\n--- Testing Find One (JSON API) ---")

  // Find one document
  let alice = coll.query_one({ "name": "Alice" }) catch {
    e => {
      println("Find one failed: \{e}")
      client.close()
      return
    }
  }
  match alice {
    Some({ "age": Number(age, ..), .. }) =>
      println("Found Alice with age: \{age.to_int()}")
    Some(_) => println("Found Alice but age not found")
    None => println("Alice not found")
  }
  println("\n--- Testing Update (JSON API) ---")

  // Update Alice's age using JSON
  let update_result = coll.modify_one(
    { "name": "Alice" },
    { "$set": { "age": 31 } },
  ) catch {
    e => {
      println("Update failed: \{e}")
      client.close()
      return
    }
  }
  println("Updated \{update_result.modified_count} document(s)")

  // Verify the update
  let alice_updated = coll.query_one({ "name": "Alice" }) catch {
    e => {
      println("Find after update failed: \{e}")
      client.close()
      return
    }
  }
  match alice_updated {
    Some({ "age": Number(age, ..), .. }) =>
      println("Alice's new age: \{age.to_int()}")
    _ => println("Alice not found after update")
  }
  println("\n--- Testing Count (JSON API) ---")
  let count = coll.count({}) catch {
    e => {
      println("Count failed: \{e}")
      client.close()
      return
    }
  }
  println("Total documents: \{count}")
  println("\n--- Testing Delete (JSON API) ---")

  // Delete Bob
  let delete_result = coll.remove_one({ "name": "Bob" }) catch {
    e => {
      println("Delete failed: \{e}")
      client.close()
      return
    }
  }
  println("Deleted \{delete_result.deleted_count} document(s)")

  // Count after delete
  let count_after = coll.count({}) catch {
    e => {
      println("Count after delete failed: \{e}")
      client.close()
      return
    }
  }
  println("Documents after delete: \{count_after}")
  println("\n--- Cleanup ---")

  // Delete all remaining test documents
  let cleanup = coll.remove_all({}) catch {
    e => {
      println("Cleanup failed: \{e}")
      client.close()
      return
    }
  }
  println("Cleaned up \{cleanup.deleted_count} document(s)")
  client.close()
  println("\nTest completed successfully!")
}
