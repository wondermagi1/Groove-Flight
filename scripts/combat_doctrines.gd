extends RefCounted
## V56 unified arsenal. Legacy doctrine identifiers never restrict an acquisition.
const IDS=[]
const ROWS=[]
static func valid(_id: String) -> bool:return false
static func row(_id: String) -> Dictionary:return {"name":"统一武器库","starters":[]}
static func weapon_allowed(_weapon: Dictionary,_id: String) -> bool:return true
static func primary_allowed(_key: String,_id: String) -> bool:return true
static func item_allowed(_item: Dictionary,_id: String) -> bool:return true
static func starters(_id: String) -> Array:return [{"kind":"pulse","slot":2},{"kind":"rail","slot":11}]
static func starting_attributes(_id: String) -> Dictionary:return {}
static func weapon_ids(catalogue: Array,_id: String) -> Array:return catalogue.map(func(w):return str(w.id))
static func boon_allowed(_boon: Dictionary,_id: String) -> bool:return true
