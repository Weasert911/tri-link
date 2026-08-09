extends SceneTree

## Dev tool: samples pixels from the captured screenshots to verify the
## toon treatment is visible (banding, RGB emission on players, vignette)
## and that revert/apply round-trip restores the original look.

func _initialize() -> void:
	var toon := Image.load_from_file("res://tools/toon_preview.png")
	var reverted := Image.load_from_file("res://tools/toon_reverted_preview.png")
	var reapplied := Image.load_from_file("res://tools/toon_reapplied_preview.png")
	print("size: ", toon.get_size())

	# Center (player area) and corner (vignette) samples.
	var center := toon.get_pixel(toon.get_width() / 2, toon.get_height() / 2)
	var corner := toon.get_pixel(8, 8)
	var corner_r := reverted.get_pixel(8, 8)
	print("toon    center=", center, " corner=", corner)
	print("reverted corner=", corner_r)
	print("reapplied center=", reapplied.get_pixel(reapplied.get_width() / 2, reapplied.get_height() / 2))

	# Count distinct-ish brightness buckets across the image to confirm the
	# 3-band quantization actually banded the scene.
	var buckets := {}
	for x in range(0, toon.get_width(), 16):
		for y in range(0, toon.get_height(), 16):
			var lum := int(toon.get_pixel(x, y).get_luminance() * 20.0)
			buckets[lum] = buckets.get(lum, 0) + 1
	print("toon brightness buckets: ", buckets.keys())

	var buckets_r := {}
	for x in range(0, reverted.get_width(), 16):
		for y in range(0, reverted.get_height(), 16):
			var lum := int(reverted.get_pixel(x, y).get_luminance() * 20.0)
			buckets_r[lum] = buckets_r.get(lum, 0) + 1
	print("reverted brightness buckets: ", buckets_r.keys())

	print("toon vs reverted differ: ", toon != reverted)
	print("toon vs reapplied differ: ", toon != reapplied)
	quit(0)
