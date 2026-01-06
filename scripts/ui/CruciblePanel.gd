extends PanelContainer

signal draw_pressed

@onready var title_label: Label = $VBox/HeaderRow/CrucibleTitle
@onready var level_status_label: Label = $VBox/HeaderRow/LevelStatusLabel
@onready var keys_label: Label = $VBox/KeysRow/KeysLabel
@onready var keys_status_label: Label = $VBox/KeysRow/KeysStatusLabel
@onready var draw_button: Button = $VBox/DrawButton

func _ready() -> void:
	draw_button.pressed.connect(func() -> void:
		emit_signal("draw_pressed")
	)

# Call this from Home.gd
func set_crucible_hud(keys: int, level: int, batch: int = 1, pending: int = 0) -> void:
	title_label.text = "Crucible Lv.%d" % level
	keys_label.text = "Keys: %d" % keys

	var ks := "Batch: %dx" % batch
	if pending > 0:
		ks += " | Pending: %d" % pending
	keys_status_label.text = ks

	level_status_label.text = _build_upgrade_status(level)

func _build_upgrade_status(level: int) -> String:
	# Guard in case upgrade functions aren't present for any reason
	if not Game.has_method("crucible_is_upgrading"):
		return ""

	if Game.crucible_is_upgrading():
		var remain: int = Game.crucible_upgrade_seconds_remaining()
		return "Upgrading %s" % _fmt_short_time(remain)

	# Show partial payment progress if any stages have been paid
	var paid: int = int(Game.player.crucible_upgrade_paid_stages)
	if paid > 0 and Game.has_method("crucible_required_payment_stages"):
		var req: int = int(Game.crucible_required_payment_stages(level))
		return "Paid %d/%d" % [paid, req]

	return ""

func _fmt_short_time(seconds: int) -> String:
	seconds = max(0, seconds)
	var m: int = seconds / 60
	var s: int = seconds % 60
	if m > 0:
		return "%d:%02d" % [m, s]
	return "%ds" % s
