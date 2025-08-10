extends Control
class_name AchievementNotification

# Simple achievement notification popup

@onready var background = $Background
@onready var title_label = $Background/VBox/Title
@onready var description_label = $Background/VBox/Description
@onready var skin_label = $Background/VBox/SkinUnlocked

var tween: Tween

signal notification_finished

func show_achievement(achievement_name: String, achievement_description: String, unlocked_skin_id: int = -1):
	"""Show an achievement unlock notification"""
	title_label.text = "Achievement Unlocked: " + achievement_name
	description_label.text = achievement_description
	
	if unlocked_skin_id > 0:
		skin_label.text = "New House Skin Unlocked: " + HouseSkinManager.get_skin_name(unlocked_skin_id)
		skin_label.visible = true
	else:
		skin_label.visible = false
	
	# Animation
	modulate.a = 0.0
	visible = true
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Hold for 3 seconds
	tween.tween_delay(3.0)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	# Hide and emit signal
	tween.tween_callback(func(): 
		visible = false
		notification_finished.emit()
	)
