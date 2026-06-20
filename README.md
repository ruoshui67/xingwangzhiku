# 《兴亡之苦》

> Godot 4 3D RPG 双角色扮演游戏

---

## 🎮 评委 / 协作者预览（3 种方式）

### 方式 ①：浏览器直接打开（无需任何工具）

👉 **[点击试玩](https://game-webgame-d5gvpmllx933a460a.webapps.tcloudbase.com)**

---

### 方式 ②：Docker 一键启动（需安装 Docker）

```bash
docker pull docker.cnb.cool/ruoshui67/xingwangzhiku:latest
docker run -p 8080:80 docker.cnb.cool/ruoshui67/xingwangzhiku:latest
# 浏览器打开 http://localhost:8080
```

---

### 方式 ③：CNB 平台 Launch（比赛用）

> Fork 仓库 → 进入仓库 → 云原生构建 → 检测到 `.cnb.yml` → 点击启动 → 获得预览地址

镜像地址使用**常量**（非变量），评委 Fork 后始终拉取本仓库的公共镜像，不受 Fork 影响。

---

## 🛠️ 开发说明

### 环境要求
- **Godot 4.6.2** stable
- 编辑器路径已在 `.vscode/settings.json` 中配置

### 导出 Web 版本
1. Godot 编辑器 → 项目 → 导出
2. 选择 HTML5 → 导出到 `build/web/`

### 部署到 CloudBase（腾讯云静态托管）

#### 方式 A：CodeBuddy 集成（推荐）
1. Godot 导出 HTML5 → `build/web/`
2. CodeBuddy → CloudBase 集成 → 上传 `build/web/` 到 `/`
3. 自动获得公网访问地址

#### 方式 B：手动上传
1. 打开 [CloudBase 控制台](https://tcb.cloud.tencent.com/dev?envId=abcd-1111-d7g8ch5d2ffbe4f3a#/static-hosting)
2. 静态网站托管 → 上传 `build/web/` 所有文件
3. 访问 `https://game-webgame-d5gvpmllx933a460a.webapps.tcloudbase.com`

### 本地构建 Docker

```bash
# 1. 先在 Godot 中导出 HTML5 到 build/web/
# 2. 构建并运行
docker build -t xingwangzhiku .
docker run -p 8080:80 xingwangzhiku
# 浏览器打开 http://localhost:8080
```

### 注意
- `.pck` 文件较大（~430MB），首次加载较慢
- nginx 已配置 COOP/COEP 头部，支持 SharedArrayBuffer
