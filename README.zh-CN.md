# 菲比历险记 · Godot 版

[中文](README.zh-CN.md) · [English](README.en.md)

[![Godot 4.7.2](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/GDScript-2.0-478cbf?logo=godot-engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Git LFS](https://img.shields.io/badge/Git%20LFS-enabled-0b7285?logo=git&logoColor=white)](https://git-lfs.com/)
[![2D Game](https://img.shields.io/badge/Genre-2D%20action%20adventure-ff6b6b)](https://github.com/MrsEWE44/phoebe-adventures-godot)
[![GitHub stars](https://img.shields.io/github/stars/MrsEWE44/phoebe-adventures-godot?style=flat-square&logo=github)](https://github.com/MrsEWE44/phoebe-adventures-godot/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/MrsEWE44/phoebe-adventures-godot?style=flat-square&logo=github)](https://github.com/MrsEWE44/phoebe-adventures-godot/network/members)
[![GitHub issues](https://img.shields.io/github/issues/MrsEWE44/phoebe-adventures-godot?style=flat-square&logo=github)](https://github.com/MrsEWE44/phoebe-adventures-godot/issues)
[![Downloads](https://img.shields.io/github/downloads/MrsEWE44/phoebe-adventures-godot/total?style=flat-square&logo=github)](https://github.com/MrsEWE44/phoebe-adventures-godot/releases)
[![Last commit](https://img.shields.io/github/last-commit/MrsEWE44/phoebe-adventures-godot?style=flat-square)](https://github.com/MrsEWE44/phoebe-adventures-godot/commits/main)
[![Repository size](https://img.shields.io/github/repo-size/MrsEWE44/phoebe-adventures-godot?style=flat-square)](https://github.com/MrsEWE44/phoebe-adventures-godot)

**Topics / 标签:** `godot` · `gdscript` · `godot-4` · `2d-game` · `action-adventure` · `puzzle-game` · `wave-combat` · `npc-dialogue` · `git-lfs`

**Repository / 仓库:** [github.com/MrsEWE44/phoebe-adventures-godot](https://github.com/MrsEWE44/phoebe-adventures-godot)

仓库地址：[GitHub](https://github.com/MrsEWE44/phoebe-adventures-godot)

这是一个使用 Godot 4.7.2 制作的 2D 俯视角动作冒险游戏。玩家会探索地图、破解谜题、解锁角色、收集武器和道具，并在波次战斗中推进菲比与伙伴们的故事。

## 当前内容

- 5 个大关、47 个子关卡
- 探索、解谜、NPC 对话、宝箱、波次战斗和首领战
- 菲比、糯糯、坤坤、Q币企鹅、Doro、咕嘎企鹅及第四、第五章角色
- 共享等级、经验结晶、装备、药品、武器升级和背包系统
- 章节专用武器、角色专属武器与环境属性加成
- 可在 Godot 编辑器中查看和修改的地形碰撞层
- 本地存档、存档重置、主场景传送卷轴和失败重试

## 开始运行

1. 安装 Godot 4.7.2 或兼容的 Godot 4.7 版本。
2. 安装 Git LFS：`git lfs install`。
3. 在 Godot 中导入根目录的 `project.godot`。
4. 等待资源导入后按 F6/F5 运行，入口场景为 `Scence/Main.tscn`。

Windows 导出配置位于 `export_presets.cfg`。正式导出前请在目标机器上重新导入资源并检查音频、视频和输入设置。

## 操作

WASD 移动，鼠标瞄准，左键/J 普攻，右键/K 技能，F 角色大招，E 交互，B/I 背包，L 旅程手册，M 地图，G 丢弃允许丢弃的武器，Esc 暂停或返回主场景。Q/R/T 和 2/3/4/5 可快速使用对应药品或特殊道具。

## 项目结构

`Scence/` 保存场景、关卡和进度逻辑；`Characters/` 保存角色定义、动画和语音；`Combat/` 保存敌人、掉落、宝箱、道具和商店；`Weapons/` 保存武器基类和定义；`Maps/`、`Art/`、`Audio/`、`BGM/`、`Videos/` 保存素材；`Tests/` 保存回归测试；`Docs/` 保存项目说明。

前 17 个子关卡的地形边界已统一为 `Terrain/FloorBoundary_*` 下的可编辑 `CollisionPolygon2D`。修改碰撞后可运行 `Tests/expedition_routes.gd` 检查门、机关、NPC、宝箱和出口是否可达。

## 存档与隐私

运行时数据存放在项目同级 `Data/` 目录，包含存档、备份、日志和音量配置。`Data/` 已被 Git 忽略，不会上传玩家进度。测试脚本使用 `.godot/` 隔离存档。

## 测试与维护

常用检查：

```powershell
python Tools/validate_project.py
godot --headless --path . --script Tests/expedition_routes.gd
godot --headless --path . --script Tests/early_release.gd
```

仓库建议名称：`phoebe-adventures-godot`。

## 许可证与素材

本仓库中的代码、配置和原创素材按仓库维护者的授权使用。第三方角色、音乐、视频、语音和参考素材请在公开发布前确认授权范围，必要时替换或移除相关文件。
