class_name SpriteUtils

static func atlas_cell(sheet: Texture2D, cols: int, rows: int, index: int) -> AtlasTexture:
	var cw := sheet.get_width() / cols
	var ch := sheet.get_height() / rows
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((index % cols) * cw, (index / cols) * ch, cw, ch)
	return atlas

static func set_sprite(spr: Sprite2D, sheet: Texture2D, cols: int, rows: int, index: int, target_w: float, target_h: float) -> void:
	var tex := atlas_cell(sheet, cols, rows, index)
	spr.texture = tex
	spr.scale = Vector2(target_w / tex.get_width(), target_h / tex.get_height())
