# 武器扩展

关卡武器已按大关收敛：第一章只有青铜短剑、遗迹手枪；第二章只有珊瑚三叉戟、潮猎鱼叉枪；第三章只有原有固定奖励静音共振枪、凑企鹅原石，仍不随机掉落武器。怪物、BOSS、宝箱与 NPC 赠礼统一遵守 `weapon_registry.gd` 的 `CHAPTER_WEAPONS` 名单，每章最多两种。

屠龙刀、电弧冲击枪等商店商品，以及角色自带武器单独管理，不计入关卡产出上限。深海鱼雷炮改为仅商店购买。旧存档中已删除的7种武器替换为短剑或手枪并继承最高强化，其它有效装备保留，尚未领取的旧宝箱、NPC 武器奖励按当前关卡名单替换，第三章替换为能量药剂。

`hit_effect` 可设 `shock / burn / frost`。背包支持强化至 +10；普通攻击继续计算角色等级与强化，「一刀999」固定造成 999 真实伤害。详见 [成长与装备规则](../Characters/PROGRESSION.md)。

`WeaponDefinition` 是所有武器共用的 Resource 基类。伤害、名字、能量消耗、冷却、射程、贴图、子弹贴图、弹速、散射、穿透、爆炸半径与持握位置都由它定义。

## 加入新武器

在 `Weapons/Definitions/` 新建一个 `.gd`，继承基类并设置初始值。例如：

```gdscript
extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
	weapon_id = "frost_staff" # 唯一 ID；发布后不要改，以兼容旧存档。
	weapon_name = "霜晶法杖"
	kind = "ranged"
	damage_type = "magic"
	damage = 32
	energy_cost = 4
	cooldown = 0.45
	attack_range = 450
	projectile_speed = 280
	texture = preload("res://Weapons/weapon_art.gd").texture(9)
	projectile_texture = preload("res://Weapons/weapon_art.gd").texture(15)
	display_width = 35
	projectile_width = 18
	drop_order = 12
```

这里复用已有法杖贴图；有新 PNG 时可直接写 `texture = preload("res://Weapons/你的贴图.png")`。也可以继承现有武器脚本，只覆盖需要改变的参数。

重新运行游戏后，注册表会自动扫描 `Definitions` 第一层的子类。注册资源不会自动进入关卡掉落池：关卡武器必须加入 `CHAPTER_WEAPONS`，每章最多两种，并通过 `drop_enabled`、`drop_chapters`、`drop_levels` 过滤。商店商品加入 `Combat/shop_catalog.gd`。旧 `drop_ids()` 保留为存档物品识别列表，实际掉落必须调用 `drops_for_level()`。导出时保留动态扫描的脚本及贴图。

## 武器资源档案（包含已退出关卡掉落的旧装备）

| ID | 武器 | 类型 | 每发伤害 | 每次扣能量 | 特点 |
| --- | --- | --- | --- | --- | --- |
| bronze_blade | 青铜短剑 | 近战物理 | 25 | 0 | 快速挥击 |
| sun_spear | 烈阳长枪 | 近战物理 | 33 | 0 | 更长攻击距离 |
| iron_pistol | 遗迹手枪 | 远程物理 | 18 | 0 | 普通子弹 |
| rune_staff | 符文法杖 | 远程法术 | 38 | 6 | 能量弹 |
| plasma_cannon | 星辉能量炮 | 远程法术 | 45 | 8 | 34 像素范围伤害 |
| pili_blade | 屠龙刀 | 近战物理 | 48 | 0 | V 一刀999，独立武器绝招 |

武器通过击败怪物、宝箱或第二章商店获得。前两章使用概率和地域武器池；第三章禁止随机掉落武器，3-9 通关固定奖励静音共振枪，3-10 固定将凑企鹅原石与技能交给咕咕嘎嘎。角色技能独立于当前装备：消耗 20 能量，菲比三发、糯糯五发、坤坤随机发动高伤直线传球或运球爆破突进。

## 公共表现与碰撞

- `weapon_mount.gd`：围绕角色跟随鼠标，左右翻转握把、所有瞄准方向均显示在角色前方，修复向上被人物遮挡、开火后坐力、枪口闪光、近战挥击。死亡时隐藏武器。
- `Combat/projectile.gd`：显示子弹、箭矢、火箭或能量弹贴图，圆形运动扫掠防止高速穿墙，处理穿透和爆炸。枪口贴墙时从墙前发射；爆炸不会越过实体墙伤敌。
- `Combat/loot.gd` 和背包：复用武器贴图；背包可滚动，显示伤害与能量消耗。
- 武器图集：`Generated/weapons_projectiles.png`，基于原始 `weapons.png` 使用内置 image_gen 生成；原图保留。区域定义为 `weapon_art.gd`，不要根据等分网格重新截取，首行长武器已单独校正边界。

完整生成提示见 `Art/Characters/GENERATION.md`。

G 丢弃当前拾取的武器；离开再靠近可拾回。`phoebe_relic` 和 `nuonuo_relic` 是大招使用的非掉落武器，继承同一 WeaponDefinition；施放结束后恢复原装备。

## 探险版手感调整

普通枪械显示宽度调整至 20–36 像素，子弹 10–14、箭/法球 16、火箭 18 像素。`projectile_hit_radius` 可单独配置伤害半径，0 表示按贴图可见高度推算。子弹使用圆形运动扫掠，保留高速防穿墙、爆炸遮挡和同一敌人只受击一次。近战扇区由 `melee_half_angle` 定义，刀/法刃/长枪射程为 52/60/72。1 键或背包可切回空手，避免耗尽能量后无攻击手段。

第二章新增 `harpoon`、`coral_trident`、`torpedo` 与角色自带 `basketball`。均继承 `WeaponDefinition`，继续由注册表自动发现。`aquatic_multiplier` 设置对水生角色的伤害倍率；`bounces` 配置碰壁反弹次数。贴图坐标位于 `chapter2_art.gd`，独立角色图不含篮球。参数及价格见 `Scence/Levels/CHAPTER2.md`。

## 武器绝招与专属装备

`WeaponDefinition.SpecialAttack` 区分 `NONE` / `THUNDER_CRESCENT` / `DECISIVE_CANNON` / `METEOR` / `EXPLOSIVE_ROUND`；`special_*` 参数配置名称、伤害、能量消耗、冷却、射程、半径和动画。屠龙刀仅通过商店购买，按 **V / 右键 / K** 或屏幕按钮施放一刀999（固定真伤 999、40 能量、6 秒冷却，前方 520 距离、340 宽度，受墙体阻挡），角色大招仍为 **F**。

`CharacterDefinition.allowed_weapons` 为空时允许所有武器；坤坤设为 `["basketball"]`，禁止装备和丢弃其它武器，拾到的武器保留在共享背包供其他角色使用。篮球无需手动切回。完整参数、素材与验证见 [本次战斗更新](COMBAT_UPDATE.md)。

共振枪的 `damage_type = "true"` 跳过护甲防御；`target_health_ratios` 指定按敌人最大生命计的最低伤害，`critical_chance` / `critical_multiplier` 配置暴击，`chain_targets` / `chain_radius` 配置连锁目标数与每跳距离。默认均不改变其它武器。共振枪对奶娃/凑企鹅幼体、小 BOSS、完全体的比例分别为 100% / 60% / 18%，暴击率 30%、倍率 1.8，最多额外连锁 5 名敌人，连锁不能穿墙。原石仅咕咕嘎嘎可装备，支持投石、碎石雨、陨石与 H 飞踢。
