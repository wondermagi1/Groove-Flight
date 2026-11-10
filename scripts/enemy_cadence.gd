extends RefCounted
## Crowd plans refresh at4Hz; motion fills the whole interval without a rest.
const STEP_SECONDS=.25
const MOVE_SECONDS=STEP_SECONDS
const SPEED_SCALE=1.20
const TURN_RADIANS_PER_SECOND=1.
