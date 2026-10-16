extends Resource
## Duplicate this resource per character and replace the audio slots in the Inspector.
@export var idle: Array[AudioStream] = []
@export var death: Array[AudioStream] = []
@export var interaction: Array[AudioStream] = []
@export var battle: Array[AudioStream] = []
@export var angry: Array[AudioStream] = []
@export var afraid: Array[AudioStream] = []
@export var terrified: Array[AudioStream] = []
@export var proud: Array[AudioStream] = []
@export var taunt: Array[AudioStream] = []
@export var dialogue: Array[AudioStream] = []
@export var hurt: Array[AudioStream] = []
@export var skill: Array[AudioStream] = []
@export var victory: Array[AudioStream] = []
@export var exhausted: Array[AudioStream] = []
@export var ultimate: Array[AudioStream] = []
## Optional per-event captions, in the same order as the audio slots.
@export var event_text: Dictionary = {}
@export var event_cooldowns: Dictionary = {"hurt": 1.5, "skill": 1.2, "exhausted": 2.0}
@export var interaction_text: Array[String] = ["我在这里，有什么事吗？", "准备好了，我们一起出发吧。", "别急，我会陪你继续探索。"]
@export var volume_db := -10.0
## Minimum gap between low-priority events of this actor; never shared across actors.
@export var shared_cooldown:=0.0
## Placeholder is a music clip; limit each utterance. Set 0 for full real voice lines.
@export_range(0,60,.1) var max_duration := 4.0

func subtitle(event: String, index: int) -> String:
	var lines: Array = event_text.get(event, [])
	if not lines.is_empty():
		return str(lines[index % lines.size()])
	if event == "interaction" and not interaction_text.is_empty():
		return interaction_text[index % interaction_text.size()]
	return {"idle":"等了好一会儿啦，要继续出发吗？", "death":"啊……先休息一下。", "angry":"我有点生气了！", "afraid":"这里让我有些害怕……", "terrified":"啊！吓我一跳！", "proud":"看吧，我做到了！", "dialogue":"我们聊聊吧。"}.get(event, "")
