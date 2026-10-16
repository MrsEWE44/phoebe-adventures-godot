# 角色创建与扩展

等级系统、100级线性属性、敌人成长、装备防御及复活修复见 [成长系统说明](PROGRESSION.md)。当前可玩角色为菲比、糯糯、坤坤、Q币企鹅、Doro、咕咕嘎嘎；全部沿用 `PlayableCharacter → GameCharacter`，第三章首领同样继承 `GameCharacter`。

所有人物脚本都应继承 `GameCharacter`（`character_base.gd`），或继承它的玩家、敌人、NPC 子类。不要再复制移动、受伤、死亡、语音和大招代码。

```text
GameCharacter
├── PlayableCharacter → Phoebe / Nuonuo
├── Combat/enemy.gd → 兽人 / 恶魔 BOSS / 血怪 BOSS / 原有动物
└── fixed_npc.gd → 士兵守望者 / 待救援糯糯
```

## 在编辑器里创建角色

1. 复制 `Definitions` 中相近的 `.tres` 角色资源，填写唯一 ID 和名称。
2. 设置角色类型：玩家 0、敌人 1、NPC 2、BOSS 3。NPC 的通用伤害入口直接拒绝伤害。
3. 设置最大生命、最大能量、移动速度、默认武器 ID、移动动画、受伤动画、语音和大招资源。
4. 玩家复制 `Player/Phoebe.tscn` 或 `Player/Nuonuo.tscn`；敌人复制 `Actors/orc.tscn`，BOSS 复制 `Actors/demon.tscn`，中立 NPC 复制 `Actors/soldier.tscn`。替换 `definition` 即可复用角色逻辑。
5. 玩家独立预览时关闭 `use_campaign_character`。加入新的可玩角色时需要同步扩展 `Campaign.CHARACTER_IDS`、角色资源映射、解锁条件及背包展示。共享等级自动应用于各角色基础生命；不得复制另一套独立成长逻辑。
6. 敌人场景的 `level` 需要由关卡注入，提供 `player`、`geometry` 和 `level_index`；固定 NPC 的 `level` 还提供机关进度与对话信息。没有 `level` 时可以预览动画，但不执行寻路或关卡对话。

玩家方向动画使用 `down / left / up`（右向镜像）；敌人和士兵使用 `idle / walk / attack / hit / death / ultimate`。资源位于 `Animations`，可直接用 Godot SpriteFrames 编辑。

## 大招

在编辑器中新建或复制 `Ultimates/*.tres`，资源类型是 `UltimateDefinition`。可以调整：名字、按键（默认 F）、模式、伤害、半径、弹速、射程、弹数、初始次数、次数上限、冷却、前摇、专属武器 ID 和颜色。角色定义还可指定单独的大招动画、缩放和偏移。

| 角色 | 大招 | 效果 |
| --- | --- | --- |
| 菲比 | 星环净化 | 半径 110 的范围法术伤害 90 |
| 糯糯 | 星辉贯穿 | 单发 150 法术伤害，允许穿透两次 |
| 士兵 NPC | 守护祈愿 | 对话选择后治疗附近玩家 35 生命 |
| 兽人 | 旋斧重击 | 半径 58，伤害 22 |
| 恶魔 BOSS | 魔焰领域 | 半径 105，伤害 32 |
| 血怪 BOSS | 血晶贯穿 | 三发弹，每发伤害 40 |
| 原有动物 | 野性震荡 | 半径 48，伤害 18 |

普通角色默认有 3 次，最多积累 5 次；Q 币企鹅使用共用 15 秒冷却的高爆弹头，不消耗次数，F / V / 右键均可触发。T 使用绝杀药剂补 1 次；满次数不会消耗药剂。大招与右键/K 的普通技能分开，大招目前消耗次数，不扣能量。玩家大招次数随角色分别保存；死亡复活和重新进入游戏不会刷新次数。死亡会取消正在蓄力的大招；蓄力期间不能切换角色、普通攻击或丢弃武器。

范围伤害和弹丸不会穿过实体墙。NPC 不属于双方伤害目标，并在 `take_damage` 中再次免疫。敌方大招有红色范围预警和前摇，玩家可躲避。三发弹遵守玩家受击无敌时间，不会在同一帧强行叠加三次伤害。

## Enemys 素材接入

- `SoldierAndOrc/Characters(100x100 split)`：士兵作为每关守望者，兽人作为普通敌人。
- `Demon_A_Blood Monster_A/Characters(100x100 split)`：恶魔放在 1-3、1-5，血怪放在 1-7。
- 使用无阴影版本的 100×100 横向分帧原图；原始图片保持不变。Idle、Walk、Attack01、Attack02、Hurt、Death 分别用于待机、移动、攻击、大招、挨打、死亡。
- BOSS 死亡状态写入关卡存档，已击败的 BOSS 不重复刷新；普通怪物也记录于门后遭遇状态，读档不复活；全员倒下重新挑战未通关关卡时重置。

## 武器与宝箱

G 丢弃当前拾取的武器，背包同步移除。站在原地不会立即捡回；离开超过 36 像素后，再靠近可拾取。角色自带武器不可丢弃。正常武器由怪物、宝箱或第二章商店获取；大招专属武器不会进入掉落池。

七张 `Scence/Levels/level_XX.tscn` 各有 `Chests` 容器，三个子节点都是 `Combat/chest.tscn` 的实例。可在编辑器移动、复制；同一关中 `chest_id` 必须唯一。`reward` 默认分别为 `health / energy / ultimate`，也可改为现有道具 ID。

靠近按 E 开箱，奖励直接进入背包；奖励与开箱标记一起存档，防止退出后重复领取或丢失。播放四帧开箱动画后节点移除。宝箱没有实体碰撞，因此开箱前后都不会挡路。原有地形碰撞仍保存在各 `.tscn` 内，本次没有重建或合并地形碰撞。

## 验证

`Tests/character_system_smoke.gd` 验证共用继承、数据属性、NPC 免伤、两类大招、隔墙阻挡、死亡取消、丢弃再拾取、七关宝箱的可达性/去重/消失/读档、BOSS 存档和糯糯语音。原有武器、角色、语音、对话、地图和战役测试仍保留。

## 探险版更新

角色已取消自选情绪互动，`combat_voice.gd` 根据环境与战斗事件反馈。菲比调皮、糯糯安静；原声配置及限制见 `Audio/糯糯/OriginalVariants/README.md`。

`hurtbox_size`、`hurtbox_offset` 控制独立全身受击区；敌人 Area2D 在第 4 层（值 8），玩家在第 5 层（值 16），中立 NPC 为 0。脚底 CharacterBody2D 碰撞保持小范围用于走路，避免完整身体卡住窄道。敌人转身时受击区同步镜像。

死亡自动接替存活队友，全员倒下才显示重试/返回主地图，见 `Scence/Levels/ADVENTURE.md`。

第二章新增 `Definitions/ikun.tres` 和 `Player/Ikun.tscn`，同样继承 `PlayableCharacter → GameCharacter`。`skill_weapon` 可配置角色技能的独立武器贴图，`aquatic` 标识水生敌人供武器克制计算，`faces_right` 用于原始朝向向右的侧身动画。队伍切换和死亡接替遍历已解锁存活角色。详细资源和参数见 `Scence/Levels/CHAPTER2.md`。

## 复苏晶石

40 级商店解锁，180 金币购买。背包药品页使用或角色页指定倒下角色，满生命复活；仅限主场景使用；全队倒下先返回主场景，再通过休整面板复活。复活当前角色恢复能量、碰撞和移动，给予两秒无敌保护。Q 币企鹅仍遵守第三章及本场合同限制。
