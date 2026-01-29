///|
/// Read and Write Concerns for MongoDB operations

///|
/// Read concern level
pub enum ReadConcernLevel {
  Local
  Available
  Majority
  Linearizable
  Snapshot
}

///|
/// Convert read concern level to string
pub fn ReadConcernLevel::to_string(self : ReadConcernLevel) -> String {
  match self {
    Local => "local"
    Available => "available"
    Majority => "majority"
    Linearizable => "linearizable"
    Snapshot => "snapshot"
  }
}

///|
/// Read concern configuration
pub struct ReadConcern {
  level : ReadConcernLevel
}

///|
/// Create a read concern
pub fn ReadConcern::new(level : ReadConcernLevel) -> ReadConcern {
  { level, }
}

///|
/// Create local read concern
pub fn ReadConcern::local_level() -> ReadConcern {
  { level: Local }
}

///|
/// Create available read concern
pub fn ReadConcern::available() -> ReadConcern {
  { level: Available }
}

///|
/// Create majority read concern
pub fn ReadConcern::majority() -> ReadConcern {
  { level: Majority }
}

///|
/// Create linearizable read concern
pub fn ReadConcern::linearizable() -> ReadConcern {
  { level: Linearizable }
}

///|
/// Create snapshot read concern
pub fn ReadConcern::snapshot() -> ReadConcern {
  { level: Snapshot }
}

///|
/// Write concern w value
pub enum WriteConcernW {
  Number(Int)
  Majority
  Tag(String)
}

///|
/// Create a numeric write concern
pub fn WriteConcernW::number(n : Int) -> WriteConcernW {
  Number(n)
}

///|
/// Create a majority write concern
pub fn WriteConcernW::majority() -> WriteConcernW {
  Majority
}

///|
/// Create a tag-based write concern
pub fn WriteConcernW::tag(t : String) -> WriteConcernW {
  Tag(t)
}

///|
/// Write concern configuration
pub struct WriteConcern {
  w : WriteConcernW?
  j : Bool?
  wtimeout : Int?
}

///|
/// Create default write concern
pub fn WriteConcern::default() -> WriteConcern {
  { w: None, j: None, wtimeout: None }
}

///|
/// Create write concern with numeric w value
pub fn WriteConcern::w(n : Int) -> WriteConcern {
  { w: Some(Number(n)), j: None, wtimeout: None }
}

///|
/// Create write concern with w value
pub fn WriteConcern::with_w(w : WriteConcernW) -> WriteConcern {
  { w: Some(w), j: None, wtimeout: None }
}

///|
/// Create majority write concern
pub fn WriteConcern::majority() -> WriteConcern {
  { w: Some(Majority), j: None, wtimeout: None }
}

///|
/// Create tag-based write concern
pub fn WriteConcern::with_tag(tag : String) -> WriteConcern {
  { w: Some(Tag(tag)), j: None, wtimeout: None }
}

///|
/// Set journal option
pub fn WriteConcern::with_journal(
  self : WriteConcern,
  j : Bool,
) -> WriteConcern {
  { w: self.w, j: Some(j), wtimeout: self.wtimeout }
}

///|
/// Set timeout
pub fn WriteConcern::with_timeout(
  self : WriteConcern,
  timeout_ms : Int,
) -> WriteConcern {
  { w: self.w, j: self.j, wtimeout: Some(timeout_ms) }
}

///|
/// Read preference mode
pub enum ReadPreferenceMode {
  Primary
  PrimaryPreferred
  Secondary
  SecondaryPreferred
  Nearest
}

///|
/// Convert read preference mode to string
pub fn ReadPreferenceMode::to_string(self : ReadPreferenceMode) -> String {
  match self {
    Primary => "primary"
    PrimaryPreferred => "primaryPreferred"
    Secondary => "secondary"
    SecondaryPreferred => "secondaryPreferred"
    Nearest => "nearest"
  }
}

///|
/// Read preference configuration
pub struct ReadPreference {
  mode : ReadPreferenceMode
  tags : Array[@types.BsonValue]?
  max_staleness_seconds : Int?
}

///|
/// Create a read preference
pub fn ReadPreference::new(mode : ReadPreferenceMode) -> ReadPreference {
  { mode, tags: None, max_staleness_seconds: None }
}

///|
/// Create primary read preference
pub fn ReadPreference::primary() -> ReadPreference {
  { mode: Primary, tags: None, max_staleness_seconds: None }
}

///|
/// Create primary preferred read preference
pub fn ReadPreference::primary_preferred() -> ReadPreference {
  { mode: PrimaryPreferred, tags: None, max_staleness_seconds: None }
}

///|
/// Create secondary read preference
pub fn ReadPreference::secondary() -> ReadPreference {
  { mode: Secondary, tags: None, max_staleness_seconds: None }
}

///|
/// Create secondary preferred read preference
pub fn ReadPreference::secondary_preferred() -> ReadPreference {
  { mode: SecondaryPreferred, tags: None, max_staleness_seconds: None }
}

///|
/// Create nearest read preference
pub fn ReadPreference::nearest() -> ReadPreference {
  { mode: Nearest, tags: None, max_staleness_seconds: None }
}

///|
/// Add tag set
pub fn ReadPreference::with_tags(
  self : ReadPreference,
  tags : Array[@types.BsonValue],
) -> ReadPreference {
  {
    mode: self.mode,
    tags: Some(tags),
    max_staleness_seconds: self.max_staleness_seconds,
  }
}

///|
/// Set max staleness
pub fn ReadPreference::with_max_staleness(
  self : ReadPreference,
  seconds : Int,
) -> ReadPreference {
  { mode: self.mode, tags: self.tags, max_staleness_seconds: Some(seconds) }
}

