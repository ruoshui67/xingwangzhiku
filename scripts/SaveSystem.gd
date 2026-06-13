extends Node
## 自动存档单例 —— 保存/恢复游戏进度
##
## 存档内容：双方角色位置 / 背包 / 技能经验&等级 / 日志 / 控制权 / NPC对话进度
## 使用 ConfigFile 写入 user://save_game.cfg

const SAVE_PATH := "user://save_game.cfg"
const AUTO_SAVE_INTERVAL := 30.0  # 每 30 秒自动存档

var _auto_timer: float = 0.0
var _dirty: bool = false  # 有变更待写入
var _pending_load: bool = false  # 从主菜单点击"继续游戏"后触发
var _opening_triggered: bool = false  # 开场对话框是否已触发
var _opening_lines: Array[String] = []  # 开场文本（由外部填充）

# NPC 叙事阶段追踪（Player1/Player2 共用）
var npc_done_count: int = 0
var dieter_p1_done: bool = false
var monologue_pending: bool = false
var moro_finale_pending: bool = false
var epilogue_pending: bool = false

# 教程弹窗追踪
var tutorial_inventory_shown: bool = false
var tutorial_skill_shown: bool = false
var tutorial_journal_shown: bool = false


func reset_npc_phase() -> void:
	npc_done_count = 0
	dieter_p1_done = false
	monologue_pending = false
	moro_finale_pending = false
	epilogue_pending = false
	tutorial_inventory_shown = false
	tutorial_skill_shown = false
	tutorial_journal_shown = false
	_resume_pending = false
	_resume_npc_name = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 主题曲（循环播放，间隔 20s）
	var theme := AudioStreamPlayer.new()
	theme.name = "ThemeMusic"
	var stream := load("res://assets/audio/theme.mp3") as AudioStream
	if stream:
		theme.stream = stream
	theme.process_mode = Node.PROCESS_MODE_ALWAYS
	theme.finished.connect(_on_theme_finished)
	add_child(theme)
	call_deferred("_start_theme")
	# ★ 开场文本
	_opening_lines = [
		"你醒了。\n\n不是从睡眠中——你根本没睡着。你只是趴在旅社房间的书桌上，额头枕着一封没写完的信。墨水在信纸上洇开了，最后一个德文单词的尾巴拖成一条细线，像某个还没决定方向的岔路。窗外的光是铅灰色的，分不清是凌晨还是黄昏。\n\n你的太阳穴在跳。后颈僵硬得像被人用枪管抵了整夜。你慢慢抬起脸，纸粘在颧骨上一秒才落下。\n\n这间屋子很小。墙角一只旧皮箱，箱盖上的柏林火车站托运标签还没撕。床铺整齐——不是你整理的，是旅社老板娘玛格丽特太太的作风。窗户对着莱茵河方向，但今天河面没有反光。雾太大了。\n\n你在科隆。第三天。",
		"[理性 · 纪律/秩序 · 普鲁士纪律]\n\n侦探。坐直。把信纸折好放进抽屉。用冷水洗脸。然后看窗外——不是看风景，是看这个城市：巡逻队经过的频率，市民避让的距离，运河上船只是多还是少。这些是数据。数据不会背叛你。",
		"[感性 · 共情/民间 · 莱茵河畔]\n\n……但雾里有煤烟味儿。是工业区那边飘来的，还是烧什么的？有个女人在运河边唱什么，太远了听不清词，但你认得那个调子——是战前科隆的磨坊小调。她唱完一句就停了。然后继续洗衣服。好像这只是十月里一个普通的星期二。",
		"[理性 · 博学/历史 · 帝国幽灵]\n\n这里曾经叫科隆自由市——帝国自由市。汉萨同盟成员，莱茵河上最骄傲的码头之一。现在呢？1902年，这地方在法律上不叫科隆——叫法兰西共和国莱茵兰军事管制区行政首府。大教堂的北塔缺了一角，是1891年围城战留下的。法国人没修。他们说这是一种……提醒。\n\n而那还不是最糟的。最糟的是——你是个柏林来的德国警察。你走进的每一扇门，上面都钉着法兰西第三共和国的铭牌。",
		"[协调 · 逻辑/法理 · 红衣逻辑]\n\n但你拥有程序上的合法性。巴黎和柏林签署过《科隆条约》第17条第4款：跨辖区刑事案件允许德方派遣一名观察员级警官协作。你不是来执行权力的——你是来观察的。观察不需要权限，只需要眼睛。\n\n第七起失踪案。法军列兵让·杜邦。二十二岁，蓝眼睛，第17步兵团。最后目击地点：运河边靠近工业区——那里有一家鞋铺，一个马厩作坊，和一座桥。\n\n这七起案子有没有共同点？如果有，前面六个人没人找到。如果有，为什么法军宪兵至今没有正式并案？",
		"[体格 · 恐吓/暴力 · 灰烬喉]\n\n（低沉的，几乎是喉咙里的震动）\n\n你知道吗——你走进警察局那天，楼下的法军宪兵看了你一眼就不再看第二眼。不是不把你当回事。是那个眼神太短了。短到像是故意不让自己有反应。像一个人看见烟的时候把火柴藏进手心。\n\n他们在怕什么。不是怕你。是怕你发现的东西。\n\n运河。所有七个人最后都出现在运河附近。你以为一个失踪的人怎么才能不留痕迹地消失在水边？你见过淹死的人吗？我见过。只要你愿意想，我现在就可以告诉你。",
		"[感性 · 激情/革命 · 红色脉搏]\n\n（低语，像有人在耳后吹气）\n\n想想——占领军内部的失踪案，发生在自己人眼皮底下。如果是德国人干的，为什么前面六具尸体一具都没被抛出来示威？如果是法国人自己干的——那是谁在吃自己人？\n\n（停顿）\n\n你从柏林来。你知道柏林想要什么——他们只关心一件事：这案子能不能在法国人脸上划一刀。但你不会只当一颗棋子，对吧？\n\n……对吧？",
		"[体格 · 意志/民族 · 铁十字]\n\n你站在一栋不属于你的国家的警察局里。你佩带一支不被允许开枪的配枪。你写报告用的纸是法国人提供的公文笺。你的每一个动作都在提醒自己：你们输了一场战争。\n\n但你还站在这里。你没脱这身制服。七个人失踪了，法国人六年前就开始习惯。你没有。你从柏林请调到这里，四十八小时火车，不是为了习惯。",
		"[协调 · 美感/伤感 · 枯玫瑰]\n\n（几乎听不见，像纸页自己翻开的声音）\n\n……其实你知道那封信为什么没写完。\n\n你不是不知道怎么写——你是不知道怎么收尾。写了三遍\"一切都好\"，但科隆不好。莱茵河上的雾太厚了，厚到你能理解为什么有人从这里消失。不是被杀——是走进去，被裹住，再也没人能证明你存在过。\n\n你已经知道他死了。你不是猜的——你是感觉到的。在这个房间里，这个被雾裹住的城市里，死亡不像结论，像前提。",
		"你站起身。洗脸。冷水刺骨。\n\n镜子里的男人三十九岁，普鲁士警察探员埃伯哈德·弗莱。衬衣领口发黄，黑眼圈很深。下巴上有一道刮胡子时留下的新口子——还没结痂。\n\n窗外雾开始散了。你看见莱茵河对岸的轮廓。是一个城市。曾经是。\n\n你折好那封没写完的信。放进抽屉。锁上。",
		"推开旅社大门。石板主街湿漉漉的，昨夜的雾在地上留下了水渍。两个法军宪兵从街对面走过，肩章在灰蒙蒙的天光里显得过分鲜艳。他们没看你——他们看的是你背后的门牌号。你在科隆的住址已经被登记过了。你很清楚。\n\n沿着石板主街往警察局走。十月的风从莱茵河方向吹过来，带着水腥味和煤烟。你经过一个报摊，德文报纸和法文报纸并排摆着，头版分别是柏林议会选举和巴黎秋季沙龙。没有人买。\n\n警察局到了。铁门上的法文铭牌被擦得很亮——宪兵每天擦它，不是出于骄傲，是出于规矩。你推开门。大厅里一个法军文书正在用打字机，抬头看了你一眼，用口音很重的德语说：「杜瓦尔中尉在审讯室等您。」",
		"审讯室在走廊尽头。走廊很窄，灯是煤气灯——法国人把电灯装了，但供电不稳定。墙皮剥落的地方露出了更旧的墙皮，一层一层，像地质层。你走过的时候数了一下：三层油漆，最底下那层是深绿色的。普鲁士时期。\n\n门没关严。从门缝里，你先闻到了烟味——法国的烟，比德国烟冲。然后是皮质手套搁在木桌上的声音。然后是呼吸。她在等人。\n\n你推开门。",
		"审讯室不大。一张灰色铁桌，两把椅子面对面摆着。墙上挂着一张手绘的科隆运河区域地图，图钉是新钉的，周围没有钉孔——这张图是为了今天的会临时挂上去的。桌上摊着七张档案，最上面那张是让·杜邦的。蓝眼睛的年轻人从照片里看着你，和档案室里一样，袖口长了一截。\n\n她——卡米耶·杜瓦尔，法国宪兵中尉，三十三岁——站在桌子另一边，手里夹着烟，正在往地图上标一个点。她的制服穿得很板正，但扣子不是今天早上系的——是昨晚没换。\n\n她抬头。\n「弗莱探员。请坐。」",
	]


func _start_theme() -> void:
	var theme: AudioStreamPlayer = get_node_or_null("ThemeMusic")
	if theme:
		theme.play()


func _on_theme_finished() -> void:
	var theme: AudioStreamPlayer = get_node_or_null("ThemeMusic")
	if theme:
		await get_tree().create_timer(20.0).timeout
		if is_instance_valid(theme):
			theme.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if not get_tree() or not get_tree().current_scene:
			return  # 场景树已销毁，无法保存
		if _dirty or has_save():
			save()


func _process(delta: float) -> void:
	# ── 跨场景加载：从主菜单"继续游戏"后恢复存档 ──
	if _pending_load:
		if not get_tree() or not get_tree().current_scene:
			return  # 场景尚未加载，下帧再试
		if not get_tree().current_scene.scene_file_path.begins_with("res://scenes/Main"):
			return  # 还在主菜单，等待切换
		# 确认 Player 节点已就绪
		var scene := get_tree().current_scene
		if not scene.get_node_or_null("Player1") and not scene.get_node_or_null("Player2"):
			return  # Player 尚未实例化
		_pending_load = false
		_opening_triggered = true  # 读档不走开场
		load_save()
		_resume_pending = true  # 下一帧恢复活跃对话

	# ── 自动存档（仅游戏运行时） ──
	if not get_tree() or not get_tree().current_scene:
		return
	var cur := get_tree().current_scene
	if not cur.scene_file_path or not cur.scene_file_path.begins_with("res://scenes/Main"):
		return  # 不是游戏场景，不存档
	# ── 新游戏开场对话框（延迟一帧确保 UI 节点就绪） ──
	if not _opening_triggered and _opening_lines.size() > 0:
		_opening_triggered = true
		call_deferred("_try_show_opening")

	# ── 恢复活跃对话（延迟到 load_save 的下一个帧确保 UI 节点就绪）──
	if _resume_pending:
		_resume_pending = false
		_resume_active_dialogue(_resume_npc_name)

	_auto_timer += delta
	if _auto_timer >= AUTO_SAVE_INTERVAL and _dirty:
		_auto_timer = 0.0
		save()


## 是否有存档文件
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 写入存档
func save() -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	var scene := get_tree().current_scene
	var cfg := ConfigFile.new()

	# ── 玩家数据 ──
	var players := get_tree().get_nodes_in_group("player")
	var p1: Node3D = null
	var p2: Node3D = null
	for p in players:
		if p.name == "Player1" or p.name.to_lower().begins_with("player1"):
			p1 = p
		elif p.name == "Player2" or p.name.to_lower().begins_with("player2"):
			p2 = p

	if not p1:
		p1 = scene.get_node_or_null("Player1")
	if not p2:
		p2 = scene.get_node_or_null("Player2")

	# Player1
	if p1:
		cfg.set_value("Player1", "pos_x", p1.global_position.x)
		cfg.set_value("Player1", "pos_y", p1.global_position.y)
		cfg.set_value("Player1", "pos_z", p1.global_position.z)
		cfg.set_value("Player1", "rot_y", p1.global_rotation.y)
		_save_player_vars(cfg, "Player1", p1)

	# Player2
	if p2:
		cfg.set_value("Player2", "pos_x", p2.global_position.x)
		cfg.set_value("Player2", "pos_y", p2.global_position.y)
		cfg.set_value("Player2", "pos_z", p2.global_position.z)
		cfg.set_value("Player2", "rot_y", p2.global_rotation.y)
		_save_player_vars(cfg, "Player2", p2)

	# ── NPC 对话进度（按名称保存每个 NPC 的完整状态）──
	_save_all_npcs(cfg)

	# ── 当前活跃对话的 NPC（静态变量精确追踪）──
	var active_npc_name := ""
	var npcs := _find_all_npcs()
	if npcs.size() > 0 and "_active_speaker" in npcs[0]:
		active_npc_name = npcs[0].get("_active_speaker")
	cfg.set_value("NPC_Phase", "active_npc", active_npc_name)

	# ── 开场对话进度 ──
	_save_opening_state(cfg)

	# ── NPC 叙事阶段 ──
	cfg.set_value("NPC_Phase", "npc_done_count", npc_done_count)
	cfg.set_value("NPC_Phase", "dieter_p1_done", dieter_p1_done)
	cfg.set_value("NPC_Phase", "monologue_pending", monologue_pending)
	cfg.set_value("NPC_Phase", "moro_finale_pending", moro_finale_pending)
	cfg.set_value("NPC_Phase", "epilogue_pending", epilogue_pending)
	cfg.set_value("NPC_Phase", "tutorial_inventory", tutorial_inventory_shown)
	cfg.set_value("NPC_Phase", "tutorial_skill", tutorial_skill_shown)
	cfg.set_value("NPC_Phase", "tutorial_journal", tutorial_journal_shown)

	# ── 日志 AI 结果 ──
	var jp: Node = _find_journal_panel()
	if jp and "_ai_result_text" in jp:
		cfg.set_value("Journal", "ai_result", jp.get("_ai_result_text"))

	cfg.save(SAVE_PATH)
	_dirty = false


func _save_player_vars(cfg: ConfigFile, section: String, player: Node) -> void:
	if "inventory" in player:
		cfg.set_value(section, "inventory", var_to_str(player.inventory))
	if "journal" in player:
		cfg.set_value(section, "journal", var_to_str(player.journal))
	if "_skill_xp" in player:
		cfg.set_value(section, "skill_xp", var_to_str(player._skill_xp))
	if "_skill_level" in player:
		cfg.set_value(section, "skill_level", var_to_str(player._skill_level))
	if "_is_controlled" in player:
		cfg.set_value(section, "is_controlled", player._is_controlled)


## 读取存档 → 恢复到游戏世界
func load_save() -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	if not has_save():
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	var scene := get_tree().current_scene
	var p1: Node3D = scene.get_node_or_null("Player1")
	var p2: Node3D = scene.get_node_or_null("Player2")
	if not p1:
		for c in scene.get_children():
			if c.name == "Player1" or c.name.to_lower().begins_with("player1"):
				p1 = c; break
	if not p2:
		for c in scene.get_children():
			if c.name == "Player2" or c.name.to_lower().begins_with("player2"):
				p2 = c; break

	# 恢复 Player1
	if p1 and cfg.has_section("Player1"):
		p1.global_position = Vector3(
			cfg.get_value("Player1", "pos_x", p1.global_position.x),
			cfg.get_value("Player1", "pos_y", p1.global_position.y),
			cfg.get_value("Player1", "pos_z", p1.global_position.z))
		p1.global_rotation.y = cfg.get_value("Player1", "rot_y", 0.0)
		p1.velocity = Vector3.ZERO
		_load_player_vars(cfg, "Player1", p1)

	# 恢复 Player2
	if p2 and cfg.has_section("Player2"):
		p2.global_position = Vector3(
			cfg.get_value("Player2", "pos_x", p2.global_position.x),
			cfg.get_value("Player2", "pos_y", p2.global_position.y),
			cfg.get_value("Player2", "pos_z", p2.global_position.z))
		p2.global_rotation.y = cfg.get_value("Player2", "rot_y", 0.0)
		if p2 is CharacterBody3D:
			p2.velocity = Vector3.ZERO
		if p2.has_method("_freeze_npc_mode") and not cfg.get_value("Player2", "is_controlled", false):
			p2._freeze_npc_mode()
		_load_player_vars(cfg, "Player2", p2)

	# 恢复控制权
	if p1 and p2 and cfg.has_section_key("Player1", "is_controlled") and cfg.has_section_key("Player2", "is_controlled"):
		var p1_ctrl: bool = cfg.get_value("Player1", "is_controlled")
		if p1.has_method("set_controlled"):
			p1.set_controlled(p1_ctrl)
		if p2.has_method("set_controlled"):
			p2.set_controlled(not p1_ctrl)

	# 恢复 NPC 对话进度（按名称恢复每个 NPC 的完整状态）
	_load_all_npcs(cfg)

	# 恢复 NPC 叙事阶段 & 活跃对话
	if cfg.has_section("NPC_Phase"):
		npc_done_count = cfg.get_value("NPC_Phase", "npc_done_count", 0)
		dieter_p1_done = cfg.get_value("NPC_Phase", "dieter_p1_done", false)
		monologue_pending = cfg.get_value("NPC_Phase", "monologue_pending", false)
		moro_finale_pending = cfg.get_value("NPC_Phase", "moro_finale_pending", false)
		epilogue_pending = cfg.get_value("NPC_Phase", "epilogue_pending", false)
		tutorial_inventory_shown = cfg.get_value("NPC_Phase", "tutorial_inventory", false)
		tutorial_skill_shown = cfg.get_value("NPC_Phase", "tutorial_skill", false)
		tutorial_journal_shown = cfg.get_value("NPC_Phase", "tutorial_journal", false)
		# 恢复活跃对话：延迟到下一帧 _process 处理
		_resume_npc_name = cfg.get_value("NPC_Phase", "active_npc", "")

	# 恢复日志 AI 结果
	if cfg.has_section_key("Journal", "ai_result"):
		var jp: Node = _find_journal_panel()
		if jp and "_ai_result_text" in jp:
			jp._ai_result_text = cfg.get_value("Journal", "ai_result")


func _load_player_vars(cfg: ConfigFile, section: String, player: Node) -> void:
	if cfg.has_section_key(section, "inventory"):
		var si: String = cfg.get_value(section, "inventory")
		if si.begins_with("[") and "inventory" in player:
			var raw: Variant = str_to_var(si)
			if raw is Array:
				player.inventory.clear()
				for item in raw:
					player.inventory.append(str(item))
	if cfg.has_section_key(section, "journal"):
		var sj: String = cfg.get_value(section, "journal")
		if sj.begins_with("[") and "journal" in player:
			var raw: Variant = str_to_var(sj)
			if raw is Array:
				player.journal.clear()
				for item in raw:
					player.journal.append(str(item))
	if cfg.has_section_key(section, "skill_xp"):
		var sx: String = cfg.get_value(section, "skill_xp")
		if sx.begins_with("{") and "_skill_xp" in player:
			var dx: Variant = str_to_var(sx)
			if dx is Dictionary: player._skill_xp = dx
	if cfg.has_section_key(section, "skill_level"):
		var sl: String = cfg.get_value(section, "skill_level")
		if sl.begins_with("{") and "_skill_level" in player:
			var dl: Variant = str_to_var(sl)
			if dl is Dictionary: player._skill_level = dl


## 延迟查找并激活开场对话框（最多重试 10 帧）
var _opening_retry: int = 0

func _try_show_opening() -> void:
	_opening_retry += 1
	if _opening_retry > 10:
		return
	var scene := get_tree().current_scene
	if not scene:
		call_deferred("_try_show_opening")
		return
	var ui := scene.get_node_or_null("UI")
	if not ui:
		call_deferred("_try_show_opening")
		return
	var dlg := ui.get_node_or_null("OpeningDialog")
	if not dlg or not dlg.has_method("start"):
		call_deferred("_try_show_opening")
		return
	_opening_retry = 0
	dlg.start(_opening_lines)


## 标记数据已变更（触发下一次自动存档）
func mark_dirty() -> void:
	_dirty = true


## 删除存档（新游戏时调用）
func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save_game.cfg"):
		dir.remove("save_game.cfg")
	_dirty = false


func _find_npc() -> Node:
	if not get_tree() or not get_tree().current_scene:
		return null
	for c in get_tree().current_scene.get_children():
		if c is Node3D and not c.name.begins_with("Player"):
			if c.has_method("_is_npc") or c.get("dialogue_text") != null:
				return c
	var all := get_tree().get_nodes_in_group("interactable")
	for node in all:
		if not node.name.to_lower().begins_with("player") and "dialogue_text" in node:
			return node
	return null


func _find_all_npcs() -> Array[Node]:
	var result: Array[Node] = []
	if not get_tree() or not get_tree().current_scene:
		return result
	for c in get_tree().current_scene.get_children():
		if c is Node3D and not c.name.begins_with("Player"):
			if c.has_method("_is_npc") or c.get("dialogue_text") != null:
				result.append(c)
	if result.is_empty():
		var all := get_tree().get_nodes_in_group("interactable")
		for node in all:
			if not node.name.to_lower().begins_with("player") and "dialogue_text" in node:
				result.append(node)
	return result


func _save_all_npcs(cfg: ConfigFile) -> void:
	for npc in _find_all_npcs():
		var sec := "NPC_" + npc.name
		_save_npc_val(cfg, sec, npc, "_dialogue_index", 0)
		_save_npc_val(cfg, sec, npc, "_round_index", 0)
		_save_npc_val(cfg, sec, npc, "_dialogue_finished", false)
		_save_npc_val(cfg, sec, npc, "_p1_dialogue_ever_completed", false)
		_save_npc_val(cfg, sec, npc, "_p2_dialogue_ever_completed", false)
		_save_npc_val(cfg, sec, npc, "_is_post_dialogue", false)
		_save_npc_val(cfg, sec, npc, "_using_p2", false)
		_save_npc_val(cfg, sec, npc, "_choices_displayed", false)
		_save_npc_val(cfg, sec, npc, "_history_before_choices", "")
		_save_npc_val(cfg, sec, npc, "_history_text", "")
		_save_npc_val(cfg, sec, npc, "_is_typing", false)
		_save_npc_val(cfg, sec, npc, "_type_index", 0)
		_save_npc_val(cfg, sec, npc, "_current_full_text", "")
		cfg.set_value(sec, "process_mode", int(npc.process_mode))
		cfg.set_value(sec, "visible", npc.visible)
		if npc is Node3D:
			cfg.set_value(sec, "pos_x", npc.global_position.x)
			cfg.set_value(sec, "pos_y", npc.global_position.y)
			cfg.set_value(sec, "pos_z", npc.global_position.z)


func _save_npc_val(cfg: ConfigFile, sec: String, npc: Node, var_name: String, default: Variant) -> void:
	cfg.set_value(sec, var_name, npc.get(var_name) if var_name in npc else default)


func _load_all_npcs(cfg: ConfigFile) -> void:
	for npc in _find_all_npcs():
		var sec := "NPC_" + npc.name
		if not cfg.has_section(sec):
			continue
		_load_npc_val(npc, cfg, sec, "_dialogue_index")
		_load_npc_val(npc, cfg, sec, "_round_index")
		_load_npc_val(npc, cfg, sec, "_dialogue_finished")
		_load_npc_val(npc, cfg, sec, "_p1_dialogue_ever_completed")
		_load_npc_val(npc, cfg, sec, "_p2_dialogue_ever_completed")
		_load_npc_val(npc, cfg, sec, "_is_post_dialogue")
		_load_npc_val(npc, cfg, sec, "_using_p2")
		_load_npc_val(npc, cfg, sec, "_choices_displayed")
		_load_npc_val(npc, cfg, sec, "_history_before_choices")
		_load_npc_val(npc, cfg, sec, "_history_text")
		_load_npc_val(npc, cfg, sec, "_is_typing")
		_load_npc_val(npc, cfg, sec, "_type_index")
		_load_npc_val(npc, cfg, sec, "_current_full_text")
		npc.process_mode = cfg.get_value(sec, "process_mode", 0)
		npc.visible = cfg.get_value(sec, "visible", true)
		if npc is Node3D and cfg.has_section_key(sec, "pos_x"):
			npc.global_position = Vector3(
				cfg.get_value(sec, "pos_x", 0.0),
				cfg.get_value(sec, "pos_y", 0.0),
				cfg.get_value(sec, "pos_z", 0.0))


func _load_npc_val(npc: Node, cfg: ConfigFile, sec: String, var_name: String) -> void:
	if var_name in npc and cfg.has_section_key(sec, var_name):
		npc.set(var_name, cfg.get_value(sec, var_name))


var _resume_pending: bool = false
var _resume_npc_name: String = ""
var _resume_retry: int = 0

func _resume_active_dialogue(npc_name: String) -> void:
	if not get_tree() or not get_tree().current_scene:
		return
	# 先检查是否有开场对话需恢复
	if _has_opening_save():
		var dlg := _find_opening_dialog()
		if not dlg:
			# 节点未就绪，延迟重试
			_resume_retry += 1
			if _resume_retry < 10:
				call_deferred("_resume_active_dialogue", npc_name)
			else:
				_resume_retry = 0
			return
		_resume_retry = 0
		_resume_opening()
		return
	_resume_retry = 0
	var npc: Node = get_tree().current_scene.get_node_or_null(npc_name)
	if npc and npc.has_method("_resume_dialogue"):
		npc._resume_dialogue()


func _has_opening_save() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return cfg.has_section("Opening") and cfg.has_section_key("Opening", "current_para")


func _save_opening_state(cfg: ConfigFile) -> void:
	var dlg := _find_opening_dialog()
	if not dlg or not dlg.visible:
		return
	cfg.set_value("Opening", "current_para", dlg.get("_current_para"))
	cfg.set_value("Opening", "char_index", dlg.get("_char_index"))
	cfg.set_value("Opening", "finished", dlg.get("_finished"))
	cfg.set_value("Opening", "waiting", dlg.get("_waiting"))
	cfg.set_value("Opening", "paras_done", var_to_str(dlg.get("_paras_done")))
	cfg.set_value("Opening", "paused", get_tree().paused)


func _resume_opening() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # 已经确认存在，忽略错误
	# 确保不暂停（读档应该从断点继续播放）
	get_tree().paused = false
	# 启动开场对话
	var dlg := _find_opening_dialog()
	dlg.start(_opening_lines)
	# 快进到存档位置
	dlg._current_para = cfg.get_value("Opening", "current_para")
	dlg._char_index = cfg.get_value("Opening", "char_index")
	dlg._finished = cfg.get_value("Opening", "finished")
	dlg._waiting = cfg.get_value("Opening", "waiting")
	var raw: String = cfg.get_value("Opening", "paras_done", "")
	if raw != "":
		var arr: Variant = str_to_var(raw)
		if arr is Array:
			dlg._paras_done = arr
	# 渲染当前状态
	dlg._label.clear()
	for i in dlg._paras_done.size():
		dlg._render_para_full(dlg._paras_done[i])
		if i < dlg._paras_done.size() - 1:
			dlg._label.append_text("\n\n\n\n")
	if dlg._finished:
		dlg._label.append_text("\n\n\n\n")
		dlg._continue_hint.visible = true
	elif dlg._waiting:
		dlg._continue_hint.visible = true
	elif dlg._current_para < dlg._lines.size():
		var body: String = dlg._bodies[dlg._current_para]
		var remaining: int = dlg._char_index
		dlg._render_para_partial(dlg._current_para, remaining, "")
	dlg._label.scroll_following = true
	_opening_triggered = true


func _find_opening_dialog() -> Node:
	if not get_tree() or not get_tree().current_scene:
		return null
	var ui := get_tree().current_scene.get_node_or_null("UI")
	if not ui:
		ui = get_tree().current_scene.get_node_or_null("UI")
	if ui:
		var dlg := ui.get_node_or_null("OpeningDialog")
		if dlg:
			return dlg
	return null


func _find_journal_panel() -> Node:
	if not get_tree() or not get_tree().current_scene:
		return null
	var scene := get_tree().current_scene
	for child in scene.get_children():
		if child.name == "UI" or child is CanvasLayer:
			var jp := child.get_node_or_null("JournalPanel")
			if jp:
				return jp
	return null
