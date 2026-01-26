///|
/// Pipeline stage helpers for MongoDB aggregation

///|
/// Create a $match stage
pub fn match_stage(filter : Json) -> Json {
  Json::object({ "$match": filter })
}

///|
/// Create a $group stage
pub fn group_stage(id : Json, accumulators : Json) -> Json {
  let group = match accumulators {
    Object(map) => {
      map["_id"] = id
      Json::object(map)
    }
    _ => Json::object({ "_id": id })
  }
  Json::object({ "$group": group })
}

///|
/// Create a $sort stage
pub fn sort_stage(sort : Json) -> Json {
  Json::object({ "$sort": sort })
}

///|
/// Create a $limit stage
pub fn limit_stage(n : Int) -> Json {
  Json::object({ "$limit": Json::number(n.to_double()) })
}

///|
/// Create a $skip stage
pub fn skip_stage(n : Int) -> Json {
  Json::object({ "$skip": Json::number(n.to_double()) })
}

///|
/// Create a $project stage
pub fn project_stage(projection : Json) -> Json {
  Json::object({ "$project": projection })
}

///|
/// Create a $lookup stage for joining collections
pub fn lookup_stage(
  from : String,
  local_field : String,
  foreign_field : String,
  as_ : String,
) -> Json {
  Json::object(
    {
      "$lookup": Json::object(
        {
          "from": Json::string(from),
          "localField": Json::string(local_field),
          "foreignField": Json::string(foreign_field),
          "as": Json::string(as_),
        },
      ),
    },
  )
}

///|
/// Create a $unwind stage
pub fn unwind_stage(path : String) -> Json {
  Json::object({ "$unwind": Json::string(path) })
}

///|
/// Create a $unwind stage with options
pub fn unwind_stage_with_options(
  path : String,
  preserve_null_and_empty? : Bool,
  include_array_index? : String,
) -> Json {
  let opts : Map[String, Json] = { "path": Json::string(path) }
  match preserve_null_and_empty {
    Some(true) => opts["preserveNullAndEmptyArrays"] = Json::boolean(true)
    _ => ()
  }
  match include_array_index {
    Some(idx) => opts["includeArrayIndex"] = Json::string(idx)
    None => ()
  }
  Json::object({ "$unwind": Json::object(opts) })
}

///|
/// Create a $count stage
pub fn count_stage(field_name : String) -> Json {
  Json::object({ "$count": Json::string(field_name) })
}

///|
/// Create a $addFields stage
pub fn add_fields_stage(fields : Json) -> Json {
  Json::object({ "$addFields": fields })
}

///|
/// Create a $set stage (alias for $addFields)
pub fn set_stage(fields : Json) -> Json {
  Json::object({ "$set": fields })
}

///|
/// Create a $unset stage to remove fields
pub fn unset_stage(fields : Array[String]) -> Json {
  let arr : Array[Json] = []
  for f in fields {
    arr.push(Json::string(f))
  }
  Json::object({ "$unset": Json::array(arr) })
}

///|
/// Create a $replaceRoot stage
pub fn replace_root_stage(new_root : Json) -> Json {
  Json::object({ "$replaceRoot": Json::object({ "newRoot": new_root }) })
}

///|
/// Create a $replaceWith stage (shorthand for $replaceRoot)
pub fn replace_with_stage(replacement : Json) -> Json {
  Json::object({ "$replaceWith": replacement })
}

///|
/// Create a $sample stage to randomly select documents
pub fn sample_stage(size : Int) -> Json {
  Json::object(
    { "$sample": Json::object({ "size": Json::number(size.to_double()) }) },
  )
}

///|
/// Create a $out stage to write results to a collection
pub fn out_stage(collection_name : String) -> Json {
  Json::object({ "$out": Json::string(collection_name) })
}

///|
/// Create a $merge stage to merge results into a collection
pub fn merge_stage(
  into : String,
  on? : Array[String],
  when_matched? : String,
  when_not_matched? : String,
) -> Json {
  let opts : Map[String, Json] = { "into": Json::string(into) }
  match on {
    Some(fields) => {
      let arr : Array[Json] = []
      for f in fields {
        arr.push(Json::string(f))
      }
      opts["on"] = Json::array(arr)
    }
    None => ()
  }
  match when_matched {
    Some(action) => opts["whenMatched"] = Json::string(action)
    None => ()
  }
  match when_not_matched {
    Some(action) => opts["whenNotMatched"] = Json::string(action)
    None => ()
  }
  Json::object({ "$merge": Json::object(opts) })
}

///|
/// Create a $facet stage for multiple aggregation pipelines
pub fn facet_stage(facets : Map[String, Array[Json]]) -> Json {
  let facet_map : Map[String, Json] = {}
  for name, pipeline in facets {
    facet_map[name] = Json::array(pipeline)
  }
  Json::object({ "$facet": Json::object(facet_map) })
}

///|
/// Create a $bucket stage for grouping by ranges
pub fn bucket_stage(
  group_by : Json,
  boundaries : Array[Json],
  default_bucket? : Json,
  output? : Json,
) -> Json {
  let opts : Map[String, Json] = {
    "groupBy": group_by,
    "boundaries": Json::array(boundaries),
  }
  match default_bucket {
    Some(d) => opts["default"] = d
    None => ()
  }
  match output {
    Some(o) => opts["output"] = o
    None => ()
  }
  Json::object({ "$bucket": Json::object(opts) })
}

///|
/// Create a $bucketAuto stage for automatic bucket boundaries
pub fn bucket_auto_stage(
  group_by : Json,
  buckets : Int,
  output? : Json,
  granularity? : String,
) -> Json {
  let opts : Map[String, Json] = {
    "groupBy": group_by,
    "buckets": Json::number(buckets.to_double()),
  }
  match output {
    Some(o) => opts["output"] = o
    None => ()
  }
  match granularity {
    Some(g) => opts["granularity"] = Json::string(g)
    None => ()
  }
  Json::object({ "$bucketAuto": Json::object(opts) })
}

///|
/// Create a $sortByCount stage (combines $group and $sort)
pub fn sort_by_count_stage(expression : Json) -> Json {
  Json::object({ "$sortByCount": expression })
}
