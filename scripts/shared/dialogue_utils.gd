## 对话系统共用工具（静态方法，NPC 和 Player2 共享）
extends RefCounted

## 技能颜色映射
const SKILL_COLOR_MAP := {
	"枯玫瑰": "#A08A8A", "红色脉搏": "#8B1A1A", "莱茵河畔": "#7D9B8E", "帝国幽灵": "#8A7A65",
	"共和国准则": "#7B8CA0", "三色旗": "#4E5F7D", "灰烬喉": "#2C2218", "三段论": "#5E6775",
	"铁十字": "#5A5A5A", "普鲁士纪律": "#5A5A5A", "红衣逻辑": "#5A5A5A",
}


## 把【技能名】开头的文本包裹 BBCode 颜色
static func apply_skill_color(text: String) -> String:
	var start := text.find("【")
	var end := text.find("】")
	if start == 0 and end != -1:
		var tag := text.substr(start + 1, end - start - 1)
		var color: String = SKILL_COLOR_MAP.get(tag, "")
		if color != "":
			return "[color=" + color + "]" + text + "[/color]"
	return text


## 从文本中提取技能标签名
static func extract_skill_tag(text: String) -> String:
	var start := text.find("【")
	var end := text.find("】")
	if start != -1 and end != -1 and end > start:
		var tag := text.substr(start + 1, end - start - 1)
		var dash := tag.find(" - ")
		if dash != -1:
			tag = tag.substr(0, dash)
		return tag
	return ""


## 打字机效果：在 label 上逐字显示 text，点击/按F可跳过
## @param tree    场景树（用于 create_timer）
## @param label   显示文本的 RichTextLabel
## @param text    要显示的纯文本
## @param prefix  前缀（已累积的历史文本）
## @param speed   打字速度（字符/秒）
static func typewrite(tree: SceneTree, label: RichTextLabel, text: String, prefix: String, speed: float) -> void:
	label.text = prefix
	# 提取前导 BBCode（如 [color=#XXX]）避免闪现标签
	var bcode := ""
	if text.begins_with("[color="):
		var tag_end := text.find("]")
		if tag_end != -1:
			bcode = text.substr(0, tag_end + 1)
			text = text.substr(tag_end + 1)
	# 先显示完整 BBCode + 前缀
	if bcode != "":
		label.text = prefix + bcode
	# 逐字打字：用 process_frame 计数模拟延迟（speed=字符/秒）
	var frame_count := 0
	var frames_per_char: int = max(1, int(60.0 / speed))
	var j := 0
	while j <= text.length():
		if frame_count % frames_per_char == 0:
			label.text = prefix + bcode + text.substr(0, j)
			j += 1
		frame_count += 1
		var clicked := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("interact")
		if clicked:
			label.text = prefix + bcode + text
			while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				await tree.process_frame
			return
		await tree.process_frame


## 等待玩家点击鼠标或按交互键
## @param tree 场景树
static func wait_for_click(tree: SceneTree) -> void:
	# 先等鼠标松开，防止上一个点击被复用
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await tree.process_frame
	await tree.create_timer(0.2).timeout
	# 等待新点击
	while true:
		await tree.process_frame
		if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			await tree.create_timer(0.15).timeout
			return


## 生成干净的感叹号纹理（64×64，透明背景，黄色 "!"）
static func make_exclamation_texture() -> ImageTexture:
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 全透明背景
	var yellow := Color(1, 0.85, 0, 1)
	# 竖线主体
	for x in range(24, 40):
		for y in range(6, 42):
			img.set_pixel(x, y, yellow)
	# 底部圆点
	var cx: float = 32.0
	var cy: float = 50.0
	var r: float = 8.0
	for x in range(18, 47):
		for y in range(42, 59):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, yellow)
	return ImageTexture.create_from_image(img)
