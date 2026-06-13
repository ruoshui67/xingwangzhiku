# 新建游戏项目

Godot 4 3D RPG 游戏

## 在线游玩

https://abcd-1111-d7g8ch5d2ffbe4f3a-1443037185.tcloudbaseapp.com/

## 部署信息

- **环境**: abcd-1111-d7g8ch5d2ffbe4f3a
- **平台**: 腾讯云 CloudBase 静态网站托管
- **访问域名**: abcd-1111-d7g8ch5d2ffbe4f3a-1443037185.tcloudbaseapp.com
- **最近部署**: 2026-06-18

### 更新部署

1. Godot 编辑器 → 项目 → 导出 → HTML5 → 导出到 `build/web/`
2. 使用 CodeBuddy → CloudBase 集成 → 上传 `build/web/` 到 `/`
3. 或手动：CloudBase 控制台 → 静态网站托管 → 上传文件

### 注意

- `.pck` 约 161MB，首次加载较慢
- 需确保 COOP/COEP 头部配置正确以支持 Godot Web
