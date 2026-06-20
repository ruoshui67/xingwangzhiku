# 《兴亡之苦》

> Godot 4 3D RPG 双角色扮演游戏

---

## 🎮 在线演示

| 方式 | 地址 |
|------|------|
| **CloudBase 静态托管** | [点击试玩](https://abcd-1111-d7g8ch5d2ffbe4f3a-1443037185.tcloudbaseapp.com/) |
| **CNB 预览启动** | 在 CNB 平台启动 `.cnb.yml` 的 Launch 即可预览 |

---

## 🐳 Docker 部署（评委/协作者可用）

### 方式一：使用预构建镜像（推荐）

```bash
docker pull docker.cnb.cool/ruoshui67/xingwangzhiku:latest
docker run -p 8080:80 docker.cnb.cool/ruoshui67/xingwangzhiku:latest
# 浏览器打开 http://localhost:8080
```

### 方式二：本地构建

```bash
# 1. 先在 Godot 中导出 HTML5 到 build/web/
# 2. 构建并运行
docker build -t xingwangzhiku .
docker run -p 8080:80 xingwangzhiku
```

---

## 📦 CNB 流水线

项目根目录的 `.cnb.yml` 配置了预览模式：
- 镜像地址使用**常量**而非变量，评委 Fork 后可正常启动
- 制品库需设为**公有**，确保镜像可被拉取

---

## 🛠️ 开发说明

### 环境要求
- **Godot 4.6.2** stable
- 编辑器路径已在 `.vscode/settings.json` 中配置

### 导出 Web 版本
1. Godot 编辑器 → 项目 → 导出
2. 选择 HTML5 → 导出到 `build/web/`
3. 运行 `docker build -t xingwangzhiku . && docker run -p 8080:80 xingwangzhiku` 本地预览

### 注意
- `.pck` 文件较大（~430MB），首次加载较慢
- nginx 已配置 COOP/COEP 头部，支持 SharedArrayBuffer
