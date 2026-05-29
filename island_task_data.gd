extends RefCounted

class_name IslandTaskData

const FONT_PATH: String = "res://HYPixel11pxU-2.ttf"
const TREASURE_TEXTURE_PATH: String = "res://Sprite/宝藏.png"

const ENDING_TEXT: String = (
	"挖开沙滩，桐木宝箱里放着三件物品：祖父的环球旅行手账、装着36种植物种子的玻璃瓶，还有最后一封信。\n"
	+ "信的结尾写着：\"记住，世界很大，不用着急，慢慢走就好。只要心怀热爱，哪里都是星途。\"\n"
	+ "夕阳下，暮秋坐在沙滩上翻开手账，在第一页写下：\"2026年夏天，我的旅行，从星途岛开始。\""
)

const TASKS: Array[Dictionary] = [
	{
		"id": "lighthouse",
		"trigger_path": NodePath("MapBackground/LighthouseTrigger"),
		"board_text": "登上灯塔，点击石门，输入八位数密码",
		"zone_hint": "灯塔 · 石门",
		"prompt": "石门上有八个凹槽，请输入八位数密码：",
		"answer": "19870413",
		"success_text": "密码正确，石门缓缓打开。\n该任务已完成。",
		"fail_text": "密码不对，石门纹丝不动。",
		"requires_prior": [],
		"no_input": false,
	},
	{
		"id": "cave",
		"trigger_path": NodePath("MapBackground/CaveTrigger"),
		"board_text": "来到岛西洞穴，点击石门石碑，输入四字词语",
		"zone_hint": "岛西洞穴 · 石门石碑",
		"prompt": "石碑上刻着四个空格，请输入四字词语：",
		"answer": "远山暮林",
		"success_text": "咒语正确，洞穴深处传来回响。\n该任务已完成。",
		"fail_text": "词语不对，石碑毫无反应。",
		"requires_prior": [],
		"no_input": false,
	},
	{
		"id": "fruit",
		"trigger_path": NodePath("MapBackground/FruitTrigger"),
		"board_text": "来到南侧果树下，点击铁盒，输入数字",
		"zone_hint": "南侧果树 · 铁盒",
		"prompt": "铁盒上有一个数字锁，请输入数字：",
		"answer": "6",
		"success_text": "铁盒咔哒一声打开。\n该任务已完成。",
		"fail_text": "数字不对，铁盒依然锁着。",
		"requires_prior": [],
		"no_input": false,
	},
	{
		"id": "lake",
		"trigger_path": NodePath("MapBackground/LakeTrigger"),
		"board_text": "来到中央小湖边，触摸湖面，输入一个汉字",
		"zone_hint": "中央小湖 · 湖面",
		"prompt": "湖面如镜，请输入一个汉字：",
		"answer": "影",
		"success_text": "湖水荡起涟漪，映出你的答案。\n该任务已完成。",
		"fail_text": "湖面平静无波，似乎不是这个答案。",
		"requires_prior": [],
		"no_input": false,
	},
	{
		"id": "treasure",
		"trigger_path": NodePath("MapBackground/TreasureTrigger"),
		"board_text": "完成前四项任务后，领取祖父的宝藏",
		"zone_hint": "沙滩 · 祖父的宝藏",
		"prompt": "",
		"answer": "",
		"success_text": "你挖开了沙滩上的桐木宝箱，找到了祖父留下的宝藏！\n该任务已完成。",
		"fail_text": "宝箱还埋在沙里，似乎还需完成前四个任务。",
		"requires_prior": ["lighthouse", "cave", "fruit", "lake"],
		"no_input": true,
	},
]

static func get_task_by_id(task_id: String) -> Dictionary:
	for task in TASKS:
		if task.get("id", "") == task_id:
			return task
	return {}

static func core_task_ids() -> Array[String]:
	return ["lighthouse", "cave", "fruit", "lake"]
