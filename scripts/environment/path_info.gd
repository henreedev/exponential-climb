extends Resource

class_name PathInfo

var start : Vector2i
var end : Vector2i

var angle : float
var length : float

var path_core : Array[Vector2i]
var top_edge : Array[Vector2i]
var bottom_edge : Array[Vector2i]
var total_edge : Array[Vector2i]
var packed_edge : PackedVector2Array
var polygon : Polygon2D

var radius_curve : Curve
