class_name CrowdAnimationAsset
extends Resource

@export var mesh: ArrayMesh
@export var positions: ImageTexture
@export var normals: ImageTexture
@export var lengths := PackedFloat32Array()
@export var bounds: AABB
@export var frames_per_clip: int = 8
@export var source_asset: String
