class_name DebugViewStrategy
extends RefCounted

## Called at the beginning of each render frame to initialize debug strategy.
func begin(_compute_list:int, _rd:RenderingDevice, _debug_view_sprite2d:Sprite2D):
    pass

## Called to add a view step to the debug strategy.
func add_step(
    _key:String,
    _texture_rid:RID,
    _multigrid_idx:int
):
    pass

## Returns the number of steps in the debug strategy.
func get_number_of_steps() -> int:
    return 0

## Returns the debug name of the step at the given index.
func get_step_debug_name(_step_idx:int) -> String:
    return ""

func next_view():
    pass

func previous_view():
    pass

func enable_debug(_new_state:bool):
    pass

func is_debug_enabled() -> bool:
    return false

