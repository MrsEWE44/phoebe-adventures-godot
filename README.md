# 菲比历险记 / Phoebe Adventures

[中文 / Chinese](README.zh-CN.md) · [English / 英文](README.en.md)

> 中文和 English 两个完整版本见上方链接。

Godot 4.7.2 的 2D 探索、解谜与动作战斗项目，目前包含五章、47 个子关卡。

This is a Godot 4.7.2 2D exploration, puzzle, and action-combat project with five chapters and 47 sub-levels.

## 项目文档

- [完整项目说明](Docs/项目说明.md)：操作、剧情、关卡、角色、武器、经验道具、碰撞编辑、存档与扩展方式。
- [第四章制作说明](Docs/第四章制作说明.md)：十关映射、救援、形态、合奏、可编辑碰撞和测试。
- [数据目录说明](Docs/数据目录说明.md)：程序同级Data目录、存档与音量迁移、备份及日志。
- [本次验证记录](Docs/验证记录.md)
- [实际清理清单](Docs/cleanup_manifest.json)

## 启动

使用 Godot 4.7.2 导入 project.godot，等待资源导入后按 F5。入口场景是 Scence/Main.tscn。

正常新游戏和确认重置存档后从 1 级开始。B 打开背包，L 打开旅程手册；进入子关卡会自动开始 NPC 剧情。

## 经验结晶

每颗增加 100 经验。通过怪物掉落或 1 级商店购买（80 金币），在 B → 道具 → 经验结晶 中点击使用。满级时不会消耗。

## 维护

当前规则以完整项目说明和代码为准；美术生成记录与历史剧情草稿保留为来源资料。功能测试保留在 Tests，旧截图、重复截屏脚本和临时调试输出已清理。