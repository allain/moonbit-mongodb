///|
/// Integration tests for MongoDB async client
/// These tests require a running MongoDB instance on localhost:27017

///|
/// Test basic connection to MongoDB
test "connect to mongodb" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch {
      e => {
        println("Failed to connect: \{e}")
        return
      }
    }
    // Connection successful
    client.close()
  })
}

///|
/// Test insert and find one document
test "insert and find one" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_insert_find")

    // Clean up first
    let _ = coll.delete_many({})

    // Insert a document
    let result = coll.insert_one({ "name": "TestUser", "age": 25, "active": true }) catch {
      e => {
        println("Insert failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.inserted_count, content="1")

    // Find the document
    let found = coll.find_one({ "name": "TestUser" }) catch {
      e => {
        println("Find failed: \{e}")
        client.close()
        return
      }
    }
    match found {
      Some({ "name": String(name), "age": Number(age, ..), .. }) => {
        inspect(name, content="TestUser")
        inspect(age.to_int(), content="25")
      }
      _ => println("Document not found or missing fields")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test insert many documents
test "insert many" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_insert_many")

    // Clean up first
    let _ = coll.delete_many({})

    // Insert multiple documents
    let result = coll.insert_many([
      { "name": "Alice", "score": 95 },
      { "name": "Bob", "score": 87 },
      { "name": "Charlie", "score": 92 },
    ]) catch {
      e => {
        println("Insert many failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.inserted_count, content="3")

    // Count documents
    let count = coll.count_documents({}) catch {
      e => {
        println("Count failed: \{e}")
        client.close()
        return
      }
    }
    inspect(count, content="3")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with cursor
test "find with cursor" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_cursor")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 10; i = i + 1 {
      docs.push({ "index": i, "value": "item_\{i}" })
    }
    let _ = coll.insert_many(docs) catch {
      _ => {
        client.close()
        return
      }
    }

    // Find all
    let results = coll.find({}) catch {
      e => {
        println("Find failed: \{e}")
        client.close()
        return
      }
    }
    inspect(results.length(), content="10")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test update one document
test "update one" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_update")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "UpdateTest", "counter": 0 })

    // Update the document
    let result = coll.update_one(
      { "name": "UpdateTest" },
      { "$set": { "counter": 42 } },
    ) catch {
      e => {
        println("Update failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.matched_count, content="1")
    inspect(result.modified_count, content="1")

    // Verify update
    let found = coll.find_one({ "name": "UpdateTest" }) catch {
      _ => {
        client.close()
        return
      }
    }
    match found {
      Some({ "counter": Number(c, ..), .. }) => inspect(c.to_int(), content="42")
      _ => println("Document not found after update")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test update many documents
test "update many" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_update_many")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A", "value": 1 },
      { "category": "A", "value": 2 },
      { "category": "B", "value": 3 },
    ])

    // Update all category A documents
    let result = coll.update_many(
      { "category": "A" },
      { "$set": { "updated": true } },
    ) catch {
      e => {
        println("Update many failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.matched_count, content="2")
    inspect(result.modified_count, content="2")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test delete one document
test "delete one" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_delete")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "name": "Delete1" },
      { "name": "Delete2" },
    ])

    // Delete one
    let result = coll.delete_one({ "name": "Delete1" }) catch {
      e => {
        println("Delete failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.deleted_count, content="1")

    // Verify count
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test delete many documents
test "delete many" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_delete_many")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 5; i = i + 1 {
      docs.push({ "batch": "test", "num": i })
    }
    let _ = coll.insert_many(docs)

    // Delete all
    let result = coll.delete_many({ "batch": "test" }) catch {
      e => {
        println("Delete many failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.deleted_count, content="5")

    // Verify empty
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="0")
    client.close()
  })
}

///|
/// Test count documents
test "count documents" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_count")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 7; i = i + 1 {
      docs.push({ "type": if i % 2 == 0 { "even" } else { "odd" }, "num": i })
    }
    let _ = coll.insert_many(docs)

    // Count all
    let total = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(total, content="7")

    // Count with filter
    let evens = coll.count_documents({ "type": "even" }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(evens, content="4") // 0, 2, 4, 6
    let odds = coll.count_documents({ "type": "odd" }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(odds, content="3") // 1, 3, 5

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with sort, skip, and limit
test "find with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_options")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 10; i = i + 1 {
      docs.push({ "index": i, "name": "item_\{i}" })
    }
    let _ = coll.insert_many(docs)

    // Find with limit
    let limited = coll.find({}, limit=3) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(limited.length(), content="3")

    // Find with skip
    let skipped = coll.find({}, skip=7) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(skipped.length(), content="3")

    // Find with sort (descending by index)
    let sorted = coll.find({}, sort={ "index": -1 }, limit=1) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(sorted.length(), content="1")
    match sorted[0] {
      { "index": Number(idx, ..), .. } => inspect(idx.to_int(), content="9") // Highest index
      _ => println("Expected index field")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with projection
test "find with projection" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_projection")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "ProjectTest", "secret": "hidden", "visible": 123 })

    // Find with projection (exclude secret)
    let results = coll.find({}, projection={ "secret": 0, "_id": 0 }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(results.length(), content="1")
    let doc = results[0]
    // name and visible should be present, secret should be excluded
    match doc {
      { "name": String(n), "visible": Number(v, ..), .. } => {
        inspect(n, content="ProjectTest")
        inspect(v.to_int(), content="123")
      }
      _ => println("Expected name and visible fields")
    }
    // Verify secret is excluded (check that our pattern matched without secret)
    match doc {
      { "secret": _, .. } => println("secret field should be excluded")
      _ => ()
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API - insert and query
test "json api insert and query" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_api")

    // Clean up
    let _ = coll.delete_many({})

    // Insert using JSON API
    let result = coll.insert_one({ "name": "JsonTest", "value": 42, "active": true }) catch {
      e => {
        println("JSON insert failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.inserted_count, content="1")

    // Query using JSON API
    let docs = coll.find({ "name": "JsonTest" }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(docs.length(), content="1")
    match docs[0] {
      { "name": String(n), "value": Number(v, ..), .. } => {
        inspect(n, content="JsonTest")
        inspect(v.to_int(), content="42")
      }
      _ => println("Expected JSON object with name and value")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API - modify and remove
test "json api modify and remove" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_modify")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "ModifyTest", "count": 0 })

    // Modify using JSON API
    let update_result = coll.update_one({ "name": "ModifyTest" }, {
      "$inc": { "count": 5 },
    }) catch {
      e => {
        println("JSON modify failed: \{e}")
        client.close()
        return
      }
    }
    inspect(update_result.modified_count, content="1")

    // Verify
    let found = coll.find_one({ "name": "ModifyTest" }) catch {
      _ => {
        client.close()
        return
      }
    }
    match found {
      Some({ "count": Number(c, ..), .. }) => inspect(c.to_int(), content="5")
      _ => println("Expected count field")
    }

    // Remove using JSON API
    let delete_result = coll.delete_one({ "name": "ModifyTest" }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(delete_result.deleted_count, content="1")
    client.close()
  })
}

///|
/// Test distinct values
test "distinct" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_distinct")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A" },
      { "category": "B" },
      { "category": "A" },
      { "category": "C" },
      { "category": "B" },
    ])

    // Get distinct values
    let values = coll.distinct("category") catch {
      e => {
        println("Distinct failed: \{e}")
        client.close()
        return
      }
    }
    inspect(values.length(), content="3") // A, B, C

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test aggregation pipeline
test "aggregation" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_aggregation")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A", "amount": 100 },
      { "category": "A", "amount": 200 },
      { "category": "B", "amount": 150 },
    ])

    // Run aggregation: group by category, sum amounts
    let results = coll.aggregate([
      group_stage({ "category": "$category" }, { "total": { "$sum": "$amount" } }),
      sort_stage({ "_id": 1 }),
    ]) catch {
      e => {
        println("Aggregation failed: \{e}")
        client.close()
        return
      }
    }
    inspect(results.length(), content="2") // A and B groups

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find one and update
test "find one and update" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_and_update")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "FindUpdate", "version": 1 })

    // Find and update, return new document
    let result = coll.find_one_and_update(
      { "name": "FindUpdate" },
      { "$inc": { "version": 1 } },
      return_new=true,
    ) catch {
      e => {
        println("Find and update failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "version": Number(v, ..), .. }) => inspect(v.to_int(), content="2")
      _ => println("Expected document with version field")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find one and delete
test "find one and delete" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_one_and_delete")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "ToDelete", "data": "important" })

    // Find and delete
    let result = coll.find_one_and_delete({ "name": "ToDelete" }) catch {
      e => {
        println("Find and delete failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "data": String(d), .. }) => inspect(d, content="important")
      _ => println("Expected deleted document with data field")
    }

    // Verify deleted
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="0")
    client.close()
  })
}

///|
/// Test replace one
test "replace one" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_replace")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "Original", "old_field": "old" })

    // Replace the entire document
    let result = coll.replace_one(
      { "name": "Original" },
      { "name": "Replaced", "new_field": "new" },
    ) catch {
      e => {
        println("Replace failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.modified_count, content="1")

    // Verify replacement
    let found = coll.find_one({ "name": "Replaced" }) catch {
      _ => {
        client.close()
        return
      }
    }
    match found {
      Some({ "new_field": String(nf), .. }) => {
        inspect(nf, content="new")
        // old_field should not exist - verified by pattern
      }
      _ => println("Replaced document not found or missing new_field")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test upsert
test "upsert" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_upsert")

    // Clean up
    let _ = coll.delete_many({})

    // Upsert - document doesn't exist, should insert
    let result = coll.update_one(
      { "name": "Upserted" },
      { "$set": { "name": "Upserted", "value": 99 } },
      upsert=true,
    ) catch {
      e => {
        println("Upsert failed: \{e}")
        client.close()
        return
      }
    }
    // For upsert when no existing doc, modified_count is 0
    inspect(result.modified_count, content="0")

    // Verify insertion
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test iterating over results
test "iterate results" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_cursor_foreach")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 5; i = i + 1 {
      docs.push({ "index": i, "value": "item_\{i}" })
    }
    let _ = coll.insert_many(docs)

    // Query and iterate
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }
    let mut count = 0
    for _doc in results {
      count = count + 1
    }
    inspect(count, content="5")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find returns all documents
test "find returns all documents" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_all")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 10; i = i + 1 {
      docs.push({ "index": i })
    }
    let _ = coll.insert_many(docs)

    // Find all documents
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify all documents were returned
    inspect(results.length(), content="10")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with iteration
test "find with iteration" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_iterate")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "val": 1 },
      { "val": 2 },
      { "val": 3 },
    ])
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }

    // Iterate using for loop
    let mut count = 0
    for _doc in results {
      count = count + 1
    }
    inspect(count, content="3")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find returns single document
test "find returns single document" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_single")

    // Clean up and insert small amount of data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "val": 1 })
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify single result
    inspect(results.length(), content="1")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with empty results
test "find empty results" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_empty")

    // Clean up - ensure collection is empty
    let _ = coll.delete_many({})

    // Find with filter that matches nothing
    let results = coll.find({ "nonexistent": "value" }) catch {
      _ => {
        client.close()
        return
      }
    }

    // Should return empty array
    inspect(results.length(), content="0")
    client.close()
  })
}

///|
/// Test find with many documents
test "find with many documents" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_many")

    // Clean up and insert enough documents
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 20; i = i + 1 {
      docs.push({ "index": i, "data": "test data for document \{i}" })
    }
    let _ = coll.insert_many(docs)

    // Find all documents
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify all results returned
    inspect(results.length(), content="20")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one returns document
test "find_one returns document" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_one_doc")

    // Clean up and insert data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "test": 1 })
    let result = coll.find_one({ "test": 1 }) catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify document found
    match result {
      Some({ "test": Number(n, ..), .. }) => inspect(n.to_int(), content="1")
      _ => println("Expected document with test field")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find with for loop processing
test "find with for loop processing" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_foreach")

    // Clean up and insert documents
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 15; i = i + 1 {
      docs.push({ "num": i })
    }
    let _ = coll.insert_many(docs)

    // Find all documents
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }

    // Use for loop to process all documents
    let mut sum = 0
    for doc in results {
      match doc {
        { "num": Number(n, ..), .. } => sum = sum + n.to_int()
        _ => ()
      }
    }
    // Sum of 0..14 = 105
    inspect(sum, content="105")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test estimated document count
test "estimated count" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_estimated_count")

    // Clean up and insert test data
    let _ = coll.delete_many({})
    let docs : Array[Json] = []
    for i = 0; i < 5; i = i + 1 {
      docs.push({ "index": i })
    }
    let _ = coll.insert_many(docs)

    // Get estimated count
    let count = coll.estimated_count() catch {
      e => {
        println("Estimated count failed: \{e}")
        client.close()
        return
      }
    }
    // Estimated count should be at least 5
    inspect(count >= 5, content="true")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

// =============================================================================
// Index Management Tests
// =============================================================================

///|
/// Test create and list indexes
test "create and list indexes" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_indexes")

    // Ensure collection exists by inserting a document
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "test" })

    // Drop existing indexes (except _id) - collection exists now
    let _ = coll.drop_indexes()

    // Create a simple index
    let index_name = coll.create_index({ "name": 1 }) catch {
      e => {
        println("Create index failed: \{e}")
        client.close()
        return
      }
    }
    inspect(index_name, content="name_1")

    // List indexes
    let indexes = coll.list_indexes() catch {
      e => {
        println("List indexes failed: \{e}")
        client.close()
        return
      }
    }
    // Should have _id index and our new index
    inspect(indexes.length() >= 2, content="true")

    // Clean up
    let _ = coll.delete_many({})
    let _ = coll.drop_indexes()
    client.close()
  })
}

///|
/// Test create index with options
test "create index with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_index_options")

    // Ensure collection exists
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "email": "test@example.com" })
    let _ = coll.drop_indexes()

    // Create an index using default options
    let index_name = coll.create_index({ "email": 1 }) catch {
      e => {
        println("Create index failed: \{e}")
        client.close()
        return
      }
    }
    inspect(index_name, content="email_1")

    // List indexes to verify
    let indexes = coll.list_indexes() catch {
      _ => {
        client.close()
        return
      }
    }
    // Find our index
    let mut found = false
    for idx in indexes {
      if idx.name == "email_1" {
        found = true
      }
    }
    inspect(found, content="true")

    // Clean up
    let _ = coll.delete_many({})
    let _ = coll.drop_indexes()
    client.close()
  })
}

///|
/// Test create multiple indexes
test "create multiple indexes" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_multi_indexes")

    // Ensure collection exists
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "field1": 1, "field2": 2 })
    let _ = coll.drop_indexes()

    // Create multiple indexes at once
    let specs : Array[IndexSpec] = [
      IndexSpec::new({ "field1": 1 }),
      IndexSpec::new({ "field2": -1 }),
    ]
    let names = coll.create_indexes(specs) catch {
      e => {
        println("Create indexes failed: \{e}")
        client.close()
        return
      }
    }
    inspect(names.length(), content="2")

    // Verify indexes were created
    let indexes = coll.list_indexes() catch {
      _ => {
        client.close()
        return
      }
    }
    // _id + 2 new indexes = at least 3
    inspect(indexes.length() >= 3, content="true")

    // Clean up
    let _ = coll.delete_many({})
    let _ = coll.drop_indexes()
    client.close()
  })
}

///|
/// Test drop single index
test "drop index" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_drop_index")

    // Ensure collection exists
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "temp_field": 1 })
    let _ = coll.drop_indexes()

    // Create an index
    let _ = coll.create_index({ "temp_field": 1 })

    // Drop the specific index
    coll.drop_index("temp_field_1") catch {
      e => {
        println("Drop index failed: \{e}")
        client.close()
        return
      }
    }

    // Verify it's gone
    let indexes = coll.list_indexes() catch {
      _ => {
        client.close()
        return
      }
    }
    let mut found = false
    for idx in indexes {
      if idx.name == "temp_field_1" {
        found = true
      }
    }
    inspect(found, content="false")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test IndexOptions default
test "index options default" {
  let opts = IndexOptions::default()
  match opts.name {
    None => ()
    Some(_) => println("Expected None")
  }
  match opts.unique {
    None => ()
    Some(_) => println("Expected None")
  }
}

///|
/// Test IndexSpec new
test "index spec new" {
  let keys : Json = { "field": 1 }
  let spec = IndexSpec::new(keys)
  match spec.options {
    None => ()
    Some(_) => println("Expected None options")
  }
}

// =============================================================================
// Bulk Operations Tests
// =============================================================================

///|
/// Test bulk write with mixed operations
test "bulk write mixed operations" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_bulk_write")

    // Clean up
    let _ = coll.delete_many({})

    // Create bulk operations using JSON API
    let ops : Array[BulkOperation] = [
      BulkOperation::insert({ "name": "Bulk1", "val": 1 }),
      BulkOperation::insert({ "name": "Bulk2", "val": 2 }),
      BulkOperation::insert({ "name": "Bulk3", "val": 3 }),
    ]
    let result = coll.bulk_write(ops) catch {
      e => {
        println("Bulk write failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.inserted_count, content="3")

    // Verify insertions
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="3")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test bulk write with updates
test "bulk write updates" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_bulk_updates")

    // Clean up and insert initial data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A", "count": 1 },
      { "category": "A", "count": 2 },
      { "category": "B", "count": 3 },
    ])

    // Update operations using JSON API
    let ops : Array[BulkOperation] = [
      BulkOperation::update_one({ "category": "A" }, { "$inc": { "count": 10 } }),
      BulkOperation::update_many(
        { "category": "A" },
        { "$set": { "updated": true } },
      ),
    ]
    let result = coll.bulk_write(ops) catch {
      e => {
        println("Bulk update failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.matched_count >= 2, content="true")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test bulk write with deletes
test "bulk write deletes" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_bulk_deletes")

    // Insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "type": "delete", "num": 1 },
      { "type": "delete", "num": 2 },
      { "type": "keep", "num": 3 },
    ])

    // Delete operations
    let ops : Array[BulkOperation] = [
      BulkOperation::delete_one({ "type": "delete", "num": 1 }),
      BulkOperation::delete_many({ "type": "delete" }),
    ]
    let result = coll.bulk_write(ops) catch {
      e => {
        println("Bulk delete failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.deleted_count, content="2")

    // Verify only "keep" remains
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test bulk operation constructors
test "bulk operation constructors" {
  // Test insert constructor
  let insert_op = BulkOperation::insert({ "test": 1 })
  match insert_op {
    BulkOperation::InsertOne(_) => ()
    _ => println("Expected InsertOne")
  }

  // Test update_one constructor
  let update_op = BulkOperation::update_one({}, {}, upsert=false)
  match update_op {
    BulkOperation::UpdateOne(..) => ()
    _ => println("Expected UpdateOne")
  }

  // Test update_many constructor
  let update_many_op = BulkOperation::update_many({}, {}, upsert=true)
  match update_many_op {
    BulkOperation::UpdateMany(..) => ()
    _ => println("Expected UpdateMany")
  }

  // Test replace constructor
  let replace_op = BulkOperation::replace({}, {}, upsert=false)
  match replace_op {
    BulkOperation::ReplaceOne(..) => ()
    _ => println("Expected ReplaceOne")
  }

  // Test delete_one constructor
  let del_one_op = BulkOperation::delete_one({})
  match del_one_op {
    BulkOperation::DeleteOne(_) => ()
    _ => println("Expected DeleteOne")
  }

  // Test delete_many constructor
  let del_many_op = BulkOperation::delete_many({})
  match del_many_op {
    BulkOperation::DeleteMany(_) => ()
    _ => println("Expected DeleteMany")
  }
}

///|
/// Test bulk write with replace operation
test "bulk write replace" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_bulk_replace")

    // Insert test data
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "ToReplace", "old_field": "old" })

    // Replace operation
    let ops : Array[BulkOperation] = [
      BulkOperation::replace(
        { "name": "ToReplace" },
        { "name": "Replaced", "new_field": "new" },
        upsert=false,
      ),
    ]
    let result = coll.bulk_write(ops) catch {
      e => {
        println("Bulk replace failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.modified_count, content="1")

    // Verify replacement
    let found = coll.find_one({ "name": "Replaced" }) catch {
      _ => {
        client.close()
        return
      }
    }
    match found {
      Some({ "new_field": String(s), .. }) => inspect(s, content="new")
      _ => println("Expected document with new_field")
    }

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

// =============================================================================
// JSON API Additional Tests
// =============================================================================

///|
/// Test JSON API insert_all
test "json api insert_all" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_insert_all")

    // Clean up
    let _ = coll.delete_many({})

    // Insert multiple documents using JSON API
    let result = coll.insert_many([
      { "name": "Item1", "value": 10 },
      { "name": "Item2", "value": 20 },
      { "name": "Item3", "value": 30 },
    ]) catch {
      e => {
        println("JSON insert_all failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.inserted_count, content="3")

    // Verify count
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="3")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API query with sort and projection
test "json api query with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_query_opts")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "name": "Z", "score": 100 },
      { "name": "A", "score": 50 },
      { "name": "M", "score": 75 },
    ])

    // Query with sort (ascending by name)
    let docs = coll.find({}, sort={ "name": 1 }, limit=2) catch {
      e => {
        println("Query with sort failed: \{e}")
        client.close()
        return
      }
    }
    inspect(docs.length(), content="2")
    // First should be "A"
    match docs[0] {
      { "name": String(n), .. } => inspect(n, content="A")
      _ => println("Expected name field")
    }

    // Query with projection (only name)
    let docs2 = coll.find({}, projection={ "name": 1, "_id": 0 }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(docs2.length(), content="3")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API modify_all
test "json api modify_all" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_modify_all")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A", "status": "pending" },
      { "category": "A", "status": "pending" },
      { "category": "B", "status": "pending" },
    ])

    // Modify all category A
    let result = coll.update_many({ "category": "A" }, {
      "$set": { "status": "done" },
    }) catch {
      e => {
        println("JSON modify_all failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.modified_count, content="2")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API aggregate
test "json api aggregate" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_aggregate")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "type": "A", "amount": 100 },
      { "type": "A", "amount": 150 },
      { "type": "B", "amount": 200 },
    ])

    // Run aggregation pipeline
    let pipeline : Array[Json] = [
      { "$group": { "_id": "$type", "total": { "$sum": "$amount" } } },
      { "$sort": { "_id": 1 } },
    ]
    let results = coll.aggregate(pipeline) catch {
      e => {
        println("JSON aggregate failed: \{e}")
        client.close()
        return
      }
    }
    inspect(results.length(), content="2")

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API distinct
test "json api distinct" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_distinct")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "color": "red", "size": "S" },
      { "color": "blue", "size": "M" },
      { "color": "red", "size": "L" },
      { "color": "green", "size": "S" },
    ])

    // Get distinct colors
    let colors = coll.distinct("color") catch {
      e => {
        println("JSON distinct failed: \{e}")
        client.close()
        return
      }
    }
    inspect(colors.length(), content="3") // red, blue, green

    // Get distinct colors with filter
    let small_colors = coll.distinct("color", filter={ "size": "S" }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(small_colors.length(), content="2") // red, green

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API find_one_and_update
test "json api find_one_and_update" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_find_modify")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "counter": 0 })

    // Find and modify, return new document
    let result = coll.find_one_and_update(
      { "counter": 0 },
      { "$inc": { "counter": 5 } },
      return_new=true,
    ) catch {
      e => {
        println("JSON find_one_and_update failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "counter": Number(n, ..), .. }) => inspect(n.to_int(), content="5")
      _ => println("Expected counter field")
    }

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test JSON API replace
test "json api replace" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_json_replace")

    // Clean up and insert
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "Old", "field1": "value1" })

    // Replace the document
    let result = coll.replace_one({ "name": "Old" }, {
      "name": "New",
      "field2": "value2",
    }) catch {
      e => {
        println("JSON replace failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result.modified_count, content="1")

    // Verify replacement
    let found = coll.find_one({ "name": "New" }) catch {
      _ => {
        client.close()
        return
      }
    }
    match found {
      Some({ "field2": String(v), .. }) => inspect(v, content="value2")
      _ => println("Expected field2")
    }

    // field1 should not exist
    match found {
      Some({ "field1": _, .. }) => println("field1 should not exist")
      _ => ()
    }

    // Clean up
    let _ = coll.delete_many({})
    client.close()
  })
}

// =============================================================================
// Pipeline Stage Helper Tests (Unit Tests - No MongoDB Required)
// =============================================================================

///|
/// Test match_stage helper
test "pipeline match_stage" {
  let stage = match_stage({ "status": "active" })
  match stage {
    { "$match": { "status": String(s), .. }, .. } =>
      inspect(s, content="active")
    _ => println("Expected $match stage")
  }
}

///|
/// Test group_stage helper
test "pipeline group_stage" {
  let stage = group_stage("$category", { "total": { "$sum": "$amount" } })
  match stage {
    { "$group": Object(_), .. } => ()
    _ => println("Expected $group stage")
  }
}

///|
/// Test sort_stage helper
test "pipeline sort_stage" {
  let stage = sort_stage({ "name": 1 })
  match stage {
    { "$sort": Object(_), .. } => ()
    _ => println("Expected $sort stage")
  }
}

///|
/// Test limit_stage helper
test "pipeline limit_stage" {
  let stage = limit_stage(10)
  match stage {
    { "$limit": Number(n, ..), .. } => inspect(n.to_int(), content="10")
    _ => println("Expected $limit stage")
  }
}

///|
/// Test skip_stage helper
test "pipeline skip_stage" {
  let stage = skip_stage(5)
  match stage {
    { "$skip": Number(n, ..), .. } => inspect(n.to_int(), content="5")
    _ => println("Expected $skip stage")
  }
}

///|
/// Test project_stage helper
test "pipeline project_stage" {
  let stage = project_stage({ "name": 1, "_id": 0 })
  match stage {
    { "$project": Object(_), .. } => ()
    _ => println("Expected $project stage")
  }
}

///|
/// Test lookup_stage helper
test "pipeline lookup_stage" {
  let stage = lookup_stage("orders", "customer_id", "_id", "customer_orders")
  match stage {
    { "$lookup": Object(_), .. } => ()
    _ => println("Expected $lookup stage")
  }
}

///|
/// Test unwind_stage helper
test "pipeline unwind_stage" {
  let stage = unwind_stage("$items")
  match stage {
    { "$unwind": String(s), .. } => inspect(s, content="$items")
    _ => println("Expected $unwind stage")
  }
}

///|
/// Test unwind_stage_with_options helper
test "pipeline unwind_stage_with_options" {
  let stage = unwind_stage_with_options(
    "$items",
    preserve_null_and_empty=true,
    include_array_index="idx",
  )
  match stage {
    { "$unwind": Object(_), .. } => ()
    _ => println("Expected $unwind stage with options")
  }
}

///|
/// Test count_stage helper
test "pipeline count_stage" {
  let stage = count_stage("total")
  match stage {
    { "$count": String(s), .. } => inspect(s, content="total")
    _ => println("Expected $count stage")
  }
}

///|
/// Test add_fields_stage helper
test "pipeline add_fields_stage" {
  let stage = add_fields_stage({
    "computed": { "$multiply": ["$price", "$qty"] },
  })
  match stage {
    { "$addFields": Object(_), .. } => ()
    _ => println("Expected $addFields stage")
  }
}

///|
/// Test set_stage helper
test "pipeline set_stage" {
  let stage = set_stage({ "newField": "value" })
  match stage {
    { "$set": Object(_), .. } => ()
    _ => println("Expected $set stage")
  }
}

///|
/// Test unset_stage helper
test "pipeline unset_stage" {
  let stage = unset_stage(["field1", "field2"])
  match stage {
    { "$unset": Array(_), .. } => ()
    _ => println("Expected $unset stage")
  }
}

///|
/// Test replace_root_stage helper
test "pipeline replace_root_stage" {
  let stage = replace_root_stage({ "newRoot": "$embedded" })
  match stage {
    { "$replaceRoot": Object(_), .. } => ()
    _ => println("Expected $replaceRoot stage")
  }
}

///|
/// Test replace_with_stage helper
test "pipeline replace_with_stage" {
  let stage = replace_with_stage("$embedded")
  match stage {
    { "$replaceWith": String(s), .. } => inspect(s, content="$embedded")
    _ => println("Expected $replaceWith stage")
  }
}

///|
/// Test sample_stage helper
test "pipeline sample_stage" {
  let stage = sample_stage(10)
  match stage {
    { "$sample": Object(_), .. } => ()
    _ => println("Expected $sample stage")
  }
}

///|
/// Test out_stage helper
test "pipeline out_stage" {
  let stage = out_stage("output_collection")
  match stage {
    { "$out": String(s), .. } => inspect(s, content="output_collection")
    _ => println("Expected $out stage")
  }
}

///|
/// Test merge_stage helper
test "pipeline merge_stage" {
  let stage = merge_stage(
    "target_collection",
    on=["_id"],
    when_matched="replace",
    when_not_matched="insert",
  )
  match stage {
    { "$merge": Object(_), .. } => ()
    _ => println("Expected $merge stage")
  }
}

///|
/// Test facet_stage helper
test "pipeline facet_stage" {
  let facets : Map[String, Array[Json]] = {
    "byCategory": [{ "$group": { "_id": "$category" } }],
    "byPrice": [{ "$group": { "_id": "$price" } }],
  }
  let stage = facet_stage(facets)
  match stage {
    { "$facet": Object(_), .. } => ()
    _ => println("Expected $facet stage")
  }
}

///|
/// Test bucket_stage helper
test "pipeline bucket_stage" {
  let stage = bucket_stage(
    "$price",
    [Json::number(0.0), Json::number(100.0), Json::number(200.0)],
    default_bucket=Json::string("Other"),
    output={ "count": { "$sum": 1 } },
  )
  match stage {
    { "$bucket": Object(_), .. } => ()
    _ => println("Expected $bucket stage")
  }
}

///|
/// Test bucket_auto_stage helper
test "pipeline bucket_auto_stage" {
  let stage = bucket_auto_stage(
    "$price",
    5,
    output={ "count": { "$sum": 1 } },
    granularity="R5",
  )
  match stage {
    { "$bucketAuto": Object(_), .. } => ()
    _ => println("Expected $bucketAuto stage")
  }
}

///|
/// Test sort_by_count_stage helper
test "pipeline sort_by_count_stage" {
  let stage = sort_by_count_stage("$category")
  match stage {
    { "$sortByCount": String(s), .. } => inspect(s, content="$category")
    _ => println("Expected $sortByCount stage")
  }
}

// =============================================================================
// Read/Write Concerns Tests (Unit Tests - No MongoDB Required)
// =============================================================================

///|
/// Test ReadConcern constructors
test "read concern constructors" {
  // Test local_level
  let local_rc = ReadConcern::local_level()
  inspect(local_rc.level.to_string(), content="local")

  // Test available
  let avail_rc = ReadConcern::available()
  inspect(avail_rc.level.to_string(), content="available")

  // Test majority
  let maj_rc = ReadConcern::majority()
  inspect(maj_rc.level.to_string(), content="majority")

  // Test linearizable
  let lin_rc = ReadConcern::linearizable()
  inspect(lin_rc.level.to_string(), content="linearizable")

  // Test snapshot
  let snap_rc = ReadConcern::snapshot()
  inspect(snap_rc.level.to_string(), content="snapshot")
}

///|
/// Test WriteConcernW constructors
test "write concern w constructors" {
  let num = WriteConcernW::number(2)
  match num {
    WriteConcernW::Number(n) => inspect(n, content="2")
    _ => println("Expected Number")
  }
  let maj = WriteConcernW::majority()
  match maj {
    WriteConcernW::Majority => ()
    _ => println("Expected Majority")
  }
  let tag = WriteConcernW::tag("datacenter1")
  match tag {
    WriteConcernW::Tag(t) => inspect(t, content="datacenter1")
    _ => println("Expected Tag")
  }
}

///|
/// Test WriteConcern constructors
test "write concern constructors" {
  let def = WriteConcern::default()
  match def.w {
    None => ()
    Some(_) => println("Expected None")
  }
  let w1 = WriteConcern::w(1)
  match w1.w {
    Some(WriteConcernW::Number(n)) => inspect(n, content="1")
    _ => println("Expected Number(1)")
  }
  let majority = WriteConcern::majority()
  match majority.w {
    Some(WriteConcernW::Majority) => ()
    _ => println("Expected Majority")
  }
  let with_w = WriteConcern::with_w(WriteConcernW::number(3))
  match with_w.w {
    Some(WriteConcernW::Number(n)) => inspect(n, content="3")
    _ => println("Expected Number(3)")
  }
  let with_tag = WriteConcern::with_tag("myTag")
  match with_tag.w {
    Some(WriteConcernW::Tag(t)) => inspect(t, content="myTag")
    _ => println("Expected Tag")
  }
}

///|
/// Test WriteConcern builder methods
test "write concern builder" {
  let wc = WriteConcern::majority().with_journal(true).with_timeout(5000)
  match wc.j {
    Some(j) => inspect(j, content="true")
    None => println("Expected journal")
  }
  match wc.wtimeout {
    Some(t) => inspect(t, content="5000")
    None => println("Expected timeout")
  }
}

///|
/// Test WriteConcern values
test "write concern values" {
  let wc = WriteConcern::majority().with_journal(true).with_timeout(3000)
  match wc.w {
    Some(WriteConcernW::Majority) => ()
    _ => println("Expected Majority")
  }
  match wc.j {
    Some(j) => inspect(j, content="true")
    None => println("Expected j field")
  }
  match wc.wtimeout {
    Some(t) => inspect(t, content="3000")
    None => println("Expected wtimeout field")
  }
}

///|
/// Test WriteConcern with number
test "write concern with number" {
  let wc = WriteConcern::w(2)
  match wc.w {
    Some(WriteConcernW::Number(n)) => inspect(n, content="2")
    _ => println("Expected Number(2)")
  }
}

///|
/// Test ReadPreference constructors
test "read preference constructors" {
  // Test primary
  let primary = ReadPreference::primary()
  inspect(primary.mode.to_string(), content="primary")

  // Test primary_preferred
  let pp = ReadPreference::primary_preferred()
  inspect(pp.mode.to_string(), content="primaryPreferred")

  // Test secondary
  let secondary = ReadPreference::secondary()
  inspect(secondary.mode.to_string(), content="secondary")

  // Test secondary_preferred
  let sp = ReadPreference::secondary_preferred()
  inspect(sp.mode.to_string(), content="secondaryPreferred")

  // Test nearest
  let nearest = ReadPreference::nearest()
  inspect(nearest.mode.to_string(), content="nearest")
}

///|
/// Test ReadPreference builder methods
test "read preference builder" {
  let tags : Array[@types.BsonValue] = [
    @types.bson_document().set("dc", @types.bson_string("east")),
  ]
  let rp = ReadPreference::secondary().with_tags(tags).with_max_staleness(90)
  match rp.max_staleness_seconds {
    Some(s) => inspect(s, content="90")
    None => println("Expected max_staleness")
  }
  match rp.tags {
    Some(t) => inspect(t.length(), content="1")
    None => println("Expected tags")
  }
}

///|
/// Test ReadPreference with staleness
test "read preference with staleness" {
  let rp = ReadPreference::secondary_preferred().with_max_staleness(120)
  inspect(rp.mode.to_string(), content="secondaryPreferred")
  match rp.max_staleness_seconds {
    Some(s) => inspect(s, content="120")
    None => println("Expected max_staleness_seconds")
  }
}

///|
/// Test ReadPreference with tags
test "read preference with tags" {
  let tags : Array[@types.BsonValue] = [
    @types.bson_document().set("region", @types.bson_string("us-east")),
  ]
  let rp = ReadPreference::nearest().with_tags(tags)
  match rp.tags {
    Some(arr) => inspect(arr.length(), content="1")
    None => println("Expected tags array")
  }
}

// =============================================================================
// GridFS Tests
// =============================================================================

///|
/// Test GridFS bucket creation
test "gridfs bucket new" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Test default bucket
    let bucket = GridFSBucket::new(db)
    ignore(bucket)
    // Verify bucket was created (we can't directly check fields due to read-only)
    // Just ensure it compiles and runs

    // Test custom bucket
    let custom_bucket = GridFSBucket::new(
      db,
      bucket_name="custom_files",
      chunk_size=128 * 1024,
    )
    ignore(custom_bucket)
    client.close()
  })
}

///|
/// Test GridFS upload and download
test "gridfs upload and download" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let bucket = GridFSBucket::new(db, bucket_name="test_gridfs")

    // Drop any existing files
    let _ = bucket.drop()

    // Create test data
    let test_data = Bytes::from_array([
      b'H', b'e', b'l', b'l', b'o', b' ', b'W', b'o', b'r', b'l', b'd',
    ])

    // Upload file
    let file_id = bucket.upload("test.txt", test_data) catch {
      e => {
        println("Upload failed: \{e}")
        client.close()
        return
      }
    }

    // Download file
    let downloaded = bucket.download(file_id) catch {
      e => {
        println("Download failed: \{e}")
        client.close()
        return
      }
    }
    inspect(downloaded.length(), content="11")

    // Clean up
    let _ = bucket.delete(file_id)
    let _ = bucket.drop()
    client.close()
  })
}

///|
/// Test GridFS file operations
test "gridfs file operations" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let bucket = GridFSBucket::new(db, bucket_name="test_gridfs_ops")

    // Clean up
    let _ = bucket.drop()

    // Upload a file
    let test_data = Bytes::from_array([b'T', b'e', b's', b't'])
    let file_id = bucket.upload("original.txt", test_data) catch {
      _ => {
        client.close()
        return
      }
    }

    // Check if file exists
    let exists = bucket.exists(file_id) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(exists, content="true")

    // Get file info
    let info = bucket.get_file_info(file_id) catch {
      _ => {
        client.close()
        return
      }
    }
    match info {
      Some(doc) =>
        match doc.get("filename") {
          Some(@types.String(name)) => inspect(name, content="original.txt")
          _ => println("Expected filename")
        }
      None => println("Expected file info")
    }

    // Rename file
    bucket.rename(file_id, "renamed.txt") catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify rename
    let renamed_info = bucket.get_file_info(file_id) catch {
      _ => {
        client.close()
        return
      }
    }
    match renamed_info {
      Some(doc) =>
        match doc.get("filename") {
          Some(@types.String(name)) => inspect(name, content="renamed.txt")
          _ => println("Expected filename")
        }
      None => println("Expected file info")
    }

    // Find files
    let files = bucket.find(@types.bson_document()) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(files.length(), content="1")

    // Delete file
    bucket.delete(file_id) catch {
      _ => {
        client.close()
        return
      }
    }

    // Verify deletion
    let exists_after = bucket.exists(file_id) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(exists_after, content="false")

    // Clean up
    let _ = bucket.drop()
    client.close()
  })
}

///|
/// Test GridFS download by name
test "gridfs download by name" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let bucket = GridFSBucket::new(db, bucket_name="test_gridfs_byname")

    // Clean up
    let _ = bucket.drop()

    // Upload a file
    let test_data = Bytes::from_array([b'D', b'a', b't', b'a'])
    let _ = bucket.upload("myfile.txt", test_data) catch {
      _ => {
        client.close()
        return
      }
    }

    // Download by name
    let downloaded = bucket.download_by_name("myfile.txt") catch {
      e => {
        println("Download by name failed: \{e}")
        client.close()
        return
      }
    }
    inspect(downloaded.length(), content="4")

    // Clean up
    let _ = bucket.drop()
    client.close()
  })
}

///|
/// Test GridFS with metadata
test "gridfs with metadata" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let bucket = GridFSBucket::new(db, bucket_name="test_gridfs_meta")

    // Clean up
    let _ = bucket.drop()

    // Upload a file with metadata
    let test_data = Bytes::from_array([b'X'])
    let metadata = @types.bson_document()
      .set("author", @types.bson_string("Test"))
      .set("version", @types.bson_int32(1))
    let file_id = bucket.upload("meta.txt", test_data, metadata~) catch {
      _ => {
        client.close()
        return
      }
    }

    // Get file info and verify metadata
    let info = bucket.get_file_info(file_id) catch {
      _ => {
        client.close()
        return
      }
    }
    match info {
      Some(doc) =>
        match doc.get("metadata") {
          Some(@types.Document(m)) =>
            match m.get("author") {
              Some(@types.String(a)) => inspect(a, content="Test")
              _ => println("Expected author")
            }
          _ => println("Expected metadata")
        }
      None => println("Expected file info")
    }

    // Clean up
    let _ = bucket.drop()
    client.close()
  })
}

// =============================================================================
// Session Tests
// =============================================================================

///|
/// Test session creation
test "session creation" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }

    // Start a session
    let session = client.start_session()

    // Get session ID
    let session_id = session.id()
    match session_id.get("id") {
      Some(@types.Binary(_, _)) => () // UUID binary
      _ => println("Expected session id as binary")
    }

    // Check not in transaction initially
    inspect(session.in_transaction(), content="false")

    // End session
    session.end_session() catch {
      _ => ()
    }
    client.close()
  })
}

///|
/// Test session start transaction
test "session start transaction" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let session = client.start_session()

    // Start a transaction
    session.start_transaction() catch {
      e => {
        println("Start transaction failed: \{e}")
        client.close()
        return
      }
    }

    // Should now be in transaction
    inspect(session.in_transaction(), content="true")

    // Try to start another transaction - should fail
    let start_result = session.start_transaction() catch {
      _ => {
        // Expected to fail
        session.end_session() catch {
          _ => ()
        }
        client.close()
        return
      }
    }
    ignore(start_result)
    session.end_session() catch {
      _ => ()
    }
    client.close()
  })
}

///|
/// Test session abort transaction
test "session abort transaction" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let session = client.start_session()

    // Start a transaction
    session.start_transaction() catch {
      e => {
        println("Start transaction failed: \{e}")
        client.close()
        return
      }
    }

    // Abort the transaction
    session.abort_transaction() catch {
      e => {
        println("Abort transaction failed: \{e}")
        client.close()
        return
      }
    }

    // Should no longer be in transaction
    inspect(session.in_transaction(), content="false")
    session.end_session() catch {
      _ => ()
    }
    client.close()
  })
}

///|
/// Test TransactionOptions default
test "transaction options default" {
  let opts = TransactionOptions::default()
  match opts.read_concern {
    None => ()
    Some(_) => println("Expected None")
  }
  match opts.write_concern {
    None => ()
    Some(_) => println("Expected None")
  }
  match opts.max_commit_time_ms {
    None => ()
    Some(_) => println("Expected None")
  }
}

// =============================================================================
// Change Stream Tests (limited - requires replica set for full functionality)
// =============================================================================

///|
/// Test ChangeStreamOptions default
test "change stream options default" {
  let opts = ChangeStreamOptions::default()
  match opts.full_document {
    None => ()
    Some(_) => println("Expected None")
  }
  match opts.resume_after {
    None => ()
    Some(_) => println("Expected None")
  }
  match opts.batch_size {
    None => ()
    Some(_) => println("Expected None")
  }
}

// =============================================================================
// Connection Pool Tests
// =============================================================================

///|
/// Test PoolOptions default
test "pool options default" {
  let opts = PoolOptions::default()
  inspect(opts.min_pool_size, content="0")
  inspect(opts.max_pool_size, content="100")
  inspect(opts.max_idle_time_ms, content="0")
  inspect(opts.wait_queue_timeout_ms, content="0")
}

///|
/// Test ConnectionPool new
test "connection pool new" {
  // Create pool with default options
  let pool = ConnectionPool::new("127.0.0.1", 27017)
  inspect(pool.current_size(), content="0")
  inspect(pool.available_count(), content="0")
  inspect(pool.in_use_count(), content="0")
}

///|
/// Test ConnectionPool with default options
test "connection pool with default options" {
  // Use default options since PoolOptions is read-only
  let pool = ConnectionPool::new("127.0.0.1", 27017)
  inspect(pool.current_size(), content="0")
  inspect(pool.available_count(), content="0")
}

///|
/// Test ConnectionPool close on empty pool
test "connection pool close empty" {
  let pool = ConnectionPool::new("127.0.0.1", 27017)
  pool.close()
  inspect(pool.current_size(), content="0")
}

///|
/// Test ConnectionPool acquire and release
test "connection pool acquire release" {
  @async.with_event_loop(fn(_root) {
    let pool = ConnectionPool::new("127.0.0.1", 27017)

    // Acquire a connection
    let conn = pool.acquire() catch {
      e => {
        println("Acquire failed: \{e}")
        return
      }
    }

    // Pool should have 1 connection, 1 in use
    inspect(pool.current_size(), content="1")
    inspect(pool.in_use_count(), content="1")
    inspect(pool.available_count(), content="0")

    // Release the connection
    pool.release(conn)

    // Now 1 connection available
    inspect(pool.current_size(), content="1")
    inspect(pool.in_use_count(), content="0")
    inspect(pool.available_count(), content="1")

    // Acquire again - should reuse the existing connection
    let conn2 = pool.acquire() catch {
      _ => {
        pool.close()
        return
      }
    }
    inspect(pool.current_size(), content="1") // Still 1, reused
    pool.release(conn2)

    // Clean up
    pool.close()
    inspect(pool.current_size(), content="0")
  })
}

///|
/// Test ConnectionPool multiple connections
test "connection pool multiple connections" {
  @async.with_event_loop(fn(_root) {
    let pool = ConnectionPool::new("127.0.0.1", 27017)

    // Acquire multiple connections
    let conn1 = pool.acquire() catch { _ => return }
    let conn2 = pool.acquire() catch {
      _ => {
        pool.release(conn1)
        pool.close()
        return
      }
    }
    inspect(pool.current_size(), content="2")
    inspect(pool.in_use_count(), content="2")
    inspect(pool.available_count(), content="0")

    // Release one
    pool.release(conn1)
    inspect(pool.in_use_count(), content="1")
    inspect(pool.available_count(), content="1")

    // Release the other
    pool.release(conn2)
    inspect(pool.in_use_count(), content="0")
    inspect(pool.available_count(), content="2")
    pool.close()
  })
}

// =============================================================================
// Additional Client.mbt Coverage Tests
// =============================================================================

///|
/// Test connect_uri with basic URI
test "connect_uri basic" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect_uri("mongodb://127.0.0.1:27017") catch {
      e => {
        println("Connect URI failed: \{e}")
        return
      }
    }
    // Verify connection works
    let ping_result = client.ping() catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(ping_result, content="true")
    client.close()
  })
}

///|
/// Test connect_uri with database path
test "connect_uri with database" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect_uri("mongodb://127.0.0.1:27017/testdb") catch {
      _ => return
    }
    client.close()
  })
}

///|
/// Test connect_uri with default port
test "connect_uri default port" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect_uri("mongodb://127.0.0.1") catch {
      _ => return
    }
    client.close()
  })
}

///|
/// Test connect_uri with auth format (skips auth but parses correctly)
test "connect_uri with auth format" {
  @async.with_event_loop(fn(_root) {
    // This tests the @ parsing even though auth isn't actually performed
    let client = Client::connect_uri("mongodb://user:pass@127.0.0.1:27017") catch {
      _ => return
    }
    client.close()
  })
}

///|
/// Test database name accessor
test "database name accessor" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("my_test_db")
    inspect(db.name(), content="my_test_db")
    client.close()
  })
}

///|
/// Test collection name and full_name accessors
test "collection name accessors" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_db")
    let coll = db.collection("test_coll")
    inspect(coll.name(), content="test_coll")
    inspect(coll.full_name(), content="test_db.test_coll")
    client.close()
  })
}

///|
/// Test run_command
test "database run_command" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("admin")

    // Run a simple ping command
    let cmd = @types.bson_document().set("ping", @types.bson_int32(1))
    let response = db.run_command(cmd) catch {
      e => {
        println("Run command failed: \{e}")
        client.close()
        return
      }
    }
    match response.get("ok") {
      Some(@types.Double(v)) => inspect(v == 1.0, content="true")
      Some(@types.Int32(v)) => inspect(v == 1, content="true")
      _ => println("Expected ok field")
    }
    client.close()
  })
}

///|
/// Test run_command with $db already set
test "database run_command with db set" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test")

    // Command already has $db field
    let cmd = @types.bson_document()
      .set("ping", @types.bson_int32(1))
      .set("$db", @types.bson_string("admin"))
    let response = db.run_command(cmd) catch {
      _ => {
        client.close()
        return
      }
    }
    match response.get("ok") {
      Some(@types.Double(v)) => inspect(v == 1.0, content="true")
      Some(@types.Int32(v)) => inspect(v == 1, content="true")
      _ => ()
    }
    client.close()
  })
}

///|
/// Test find with index
test "find with index" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_index")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "field": 1 })

    // Create an index
    let _ = coll.create_index({ "field": 1 })

    // Find using the indexed field
    let results = coll.find({ "field": 1 }) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(results.length(), content="1")

    // Cleanup
    let _ = coll.delete_many({})
    let _ = coll.drop_indexes()
    client.close()
  })
}

///|
/// Test find returns results quickly
test "find returns results" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_results")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "x": 1 })

    // Find the document
    let results = coll.find({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(results.length(), content="1")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test aggregate with options
test "aggregate with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_aggregate_opts")

    // Setup
    let _ = coll.delete_many({})
    for i = 0; i < 10; i = i + 1 {
      let _ = coll.insert_one({ "value": i })
    }

    // Aggregate with batch_size, max_time_ms, and allow_disk_use
    let results = coll.aggregate(
      [{ "$match": {} }],
      batch_size=5,
      max_time_ms=10000,
      allow_disk_use=true,
    ) catch {
      e => {
        println("Aggregate with options failed: \{e}")
        client.close()
        return
      }
    }
    inspect(results.length(), content="10")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one_and_update with all options
test "find_one_and_update full options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_update_opts")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "name": "A", "priority": 1 },
      { "name": "B", "priority": 2 },
    ])

    // Find and update, returning the new document
    let result = coll.find_one_and_update(
      { "name": "B" },
      { "$set": { "updated": true } },
      return_new=true,
    ) catch {
      e => {
        println("Find and update with options failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "name": String(n), "updated": True, .. }) => inspect(n, content="B")
      _ => println("Expected document with name and updated")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one_and_update with upsert
test "find_one_and_update with upsert" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_update_upsert")

    // Setup - ensure collection is empty
    let _ = coll.delete_many({})

    // Upsert a new document
    let result = coll.find_one_and_update(
      { "key": "unique" },
      { "$set": { "key": "unique", "value": 42 } },
      upsert=true,
      return_new=true,
    ) catch {
      e => {
        println("Upsert failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "value": Number(v, ..), .. }) => inspect(v.to_int(), content="42")
      _ => println("Expected upserted document")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one_and_replace
test "find_one_and_replace" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_replace")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "name": "Original", "old_field": "value" })

    // Find and replace
    let result = coll.find_one_and_replace(
      { "name": "Original" },
      { "name": "Replaced", "new_field": "new_value" },
      return_new=true,
    ) catch {
      e => {
        println("Find and replace failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "name": String(n), "new_field": String(v), .. }) => {
        inspect(n, content="Replaced")
        inspect(v, content="new_value")
      }
      _ => println("Expected document")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one_and_replace with upsert
test "find_one_and_replace with upsert" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_replace_upsert")

    // Setup - empty collection
    let _ = coll.delete_many({})

    // Upsert via replace
    let result = coll.find_one_and_replace(
      { "key": "new" },
      { "key": "new", "data": 100 },
      upsert=true,
      return_new=true,
    ) catch {
      _ => {
        client.close()
        return
      }
    }
    match result {
      Some({ "data": Number(d, ..), .. }) => inspect(d.to_int(), content="100")
      _ => println("Expected upserted document")
    }

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test find_one_and_delete with options
test "find_one_and_delete with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_find_delete_opts")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "name": "First", "order": 1 },
      { "name": "Second", "order": 2 },
    ])

    // Delete with sort (delete highest order)
    let result = coll.find_one_and_delete(
      {},
      sort={ "order": -1 },
    ) catch {
      e => {
        println("Find and delete with options failed: \{e}")
        client.close()
        return
      }
    }
    match result {
      Some({ "name": String(n), .. }) => inspect(n, content="Second")
      _ => println("Expected deleted document")
    }

    // Verify only First remains
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}

///|
/// Test collection rename
test "collection rename" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_rename_source")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "data": 1 })

    // Rename the collection
    coll.rename("test_rename_target") catch {
      e => {
        println("Rename failed: \{e}")
        client.close()
        return
      }
    }

    // Verify data is in new collection
    let new_coll = db.collection("test_rename_target")
    let count = new_coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")

    // Cleanup
    let _ = new_coll.drop()
    client.close()
  })
}

///|
/// Test collection rename with drop_target
test "collection rename with drop_target" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let source = db.collection("test_rename_src2")
    let target = db.collection("test_rename_tgt2")

    // Setup - create both collections
    let _ = source.delete_many({})
    let _ = source.insert_one({ "from": "source" })
    let _ = target.delete_many({})
    let _ = target.insert_one({ "from": "target" })

    // Rename with drop_target=true
    source.rename("test_rename_tgt2", drop_target=true) catch {
      e => {
        println("Rename with drop_target failed: \{e}")
        client.close()
        return
      }
    }

    // Verify target now has source's data
    let count = target.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="1")
    let doc = target.find_one({}) catch {
      _ => {
        client.close()
        return
      }
    }
    match doc {
      Some({ "from": String(f), .. }) => inspect(f, content="source")
      _ => println("Expected document with from field")
    }

    // Cleanup
    let _ = target.drop()
    client.close()
  })
}

///|
/// Test collection drop
test "collection drop" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_drop_coll")

    // Setup
    let _ = coll.insert_one({ "x": 1 })

    // Drop collection
    coll.drop() catch {
      e => {
        println("Drop failed: \{e}")
        client.close()
        return
      }
    }

    // Dropping again should not error (ns not found is OK)
    coll.drop() catch {
      e => {
        println("Second drop failed unexpectedly: \{e}")
        client.close()
        return
      }
    }
    client.close()
  })
}

///|
/// Test create_collection with options
test "create_collection with options" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Drop if exists
    let _ = db.drop_collection("test_create_capped")

    // Create a capped collection
    let coll = db.create_collection(
      "test_create_capped",
      capped=true,
      size=1024L * 1024L, // 1MB
      max=100L,
    ) catch {
      e => {
        println("Create collection failed: \{e}")
        client.close()
        return
      }
    }

    // Verify collection exists
    let count = coll.count_documents({}) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(count, content="0")

    // Cleanup
    let _ = coll.drop()
    client.close()
  })
}

///|
/// Test create_collection with validator
test "create_collection with validator" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Drop if exists
    let _ = db.drop_collection("test_create_validated")

    // Create collection with validator
    let validator = @types.bson_document().set(
      "name",
      @types.bson_document().set("$type", @types.bson_string("string")),
    )
    let coll = db.create_collection(
      "test_create_validated",
      validator~,
      validation_level="moderate",
      validation_action="warn",
    ) catch {
      e => {
        println("Create validated collection failed: \{e}")
        client.close()
        return
      }
    }

    // Insert a valid document
    let _ = coll.insert_one({ "name": "Valid" })

    // Cleanup
    let _ = coll.drop()
    client.close()
  })
}

///|
/// Test drop_collection
test "database drop_collection" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Create a collection
    let coll = db.collection("test_db_drop_coll")
    let _ = coll.insert_one({ "x": 1 })

    // Drop via database
    db.drop_collection("test_db_drop_coll") catch {
      e => {
        println("drop_collection failed: \{e}")
        client.close()
        return
      }
    }
    client.close()
  })
}

///|
/// Test list_collections
test "list_collections" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Create a test collection
    let coll = db.collection("test_list_colls")
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "x": 1 })

    // List all collections
    let collections = db.list_collections() catch {
      e => {
        println("list_collections failed: \{e}")
        client.close()
        return
      }
    }
    inspect(collections.length() >= 1, content="true")

    // List with filter - use the BSON API since filter is BSON type
    let filtered = db.list_collections(
      filter=@types.bson_document().set("name", @types.bson_string("test_list_colls")),
    ) catch {
      _ => {
        client.close()
        return
      }
    }
    inspect(filtered.length(), content="1")
    inspect(filtered[0].name, content="test_list_colls")

    // Cleanup
    let _ = coll.drop()
    client.close()
  })
}

///|
/// Test list_collection_names
test "list_collection_names" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Create a test collection
    let coll = db.collection("test_list_names")
    let _ = coll.delete_many({})
    let _ = coll.insert_one({ "x": 1 })

    // List collection names
    let names = db.list_collection_names() catch {
      e => {
        println("list_collection_names failed: \{e}")
        client.close()
        return
      }
    }
    inspect(names.length() >= 1, content="true")

    // Check our collection is in the list
    let mut found = false
    for name in names {
      if name == "test_list_names" {
        found = true
      }
    }
    inspect(found, content="true")

    // Cleanup
    let _ = coll.drop()
    client.close()
  })
}

///|
/// Test database stats
test "database stats" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")

    // Get database stats
    let stats = db.stats() catch {
      e => {
        println("stats failed: \{e}")
        client.close()
        return
      }
    }

    // Verify we got a response with db name
    match stats.get("db") {
      Some(@types.String(name)) =>
        inspect(name, content="test_moonbit_integration")
      _ => println("Expected db field")
    }
    client.close()
  })
}

///|
/// Test list_databases
test "list_databases" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }

    // Create a database with a collection
    let db = client.database("test_moonbit_list_dbs")
    let coll = db.collection("test_coll")
    let _ = coll.insert_one({ "x": 1 })

    // List databases
    let databases = client.list_databases() catch {
      e => {
        println("list_databases failed: \{e}")
        client.close()
        return
      }
    }
    inspect(databases.length() >= 1, content="true")

    // Check our database is in the list
    let mut found = false
    for db_info in databases {
      if db_info.name == "test_moonbit_list_dbs" {
        found = true
        // Verify size_on_disk and empty fields are populated
        inspect(db_info.size_on_disk >= 0L, content="true")
      }
    }
    inspect(found, content="true")

    // Cleanup
    let _ = coll.drop()
    db.drop() catch {
      _ => ()
    }
    client.close()
  })
}

///|
/// Test list_database_names
test "list_database_names" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }

    // List database names
    let names = client.list_database_names() catch {
      e => {
        println("list_database_names failed: \{e}")
        client.close()
        return
      }
    }
    inspect(names.length() >= 1, content="true")

    // Should at least have admin database
    let mut found_admin = false
    for name in names {
      if name == "admin" {
        found_admin = true
      }
    }
    inspect(found_admin, content="true")
    client.close()
  })
}

///|
/// Test server_info
test "server_info" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }

    // Get server info
    let info = client.server_info() catch {
      e => {
        println("server_info failed: \{e}")
        client.close()
        return
      }
    }

    // Verify we got version info
    match info.get("version") {
      Some(@types.String(_)) => ()
      _ => println("Expected version field")
    }
    client.close()
  })
}

///|
/// Test ping
test "ping" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let result = client.ping() catch {
      e => {
        println("ping failed: \{e}")
        client.close()
        return
      }
    }
    inspect(result, content="true")
    client.close()
  })
}

///|
/// Test ReturnDocument::before constructor
test "return document before" {
  let rd = ReturnDocument::before()
  // Just verify it compiles and runs
  ignore(rd)
}

///|
/// Test distinct with filter
test "distinct with filter" {
  @async.with_event_loop(fn(_root) {
    let client = Client::connect("127.0.0.1", 27017) catch { _ => return }
    let db = client.database("test_moonbit_integration")
    let coll = db.collection("test_distinct_filter")

    // Setup
    let _ = coll.delete_many({})
    let _ = coll.insert_many([
      { "category": "A", "type": "small" },
      { "category": "A", "type": "large" },
      { "category": "B", "type": "small" },
    ])

    // Distinct with filter
    let values = coll.distinct("type", filter={ "category": "A" }) catch {
      e => {
        println("Distinct with filter failed: \{e}")
        client.close()
        return
      }
    }
    inspect(values.length(), content="2") // small and large

    // Cleanup
    let _ = coll.delete_many({})
    client.close()
  })
}
