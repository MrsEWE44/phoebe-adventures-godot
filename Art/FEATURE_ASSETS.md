# 本次角色与宝箱生成素材

生成方式：内置 `image_gen`，以现有游戏素材作角色/风格参考，生成透明 PNG；原始 alpha 保留，未对位图做二次绘制。Godot 使用 AtlasTexture 裁帧。

## 宝箱

- 保存文件：`Art/Props/chest_opening.png`，2172×724，4 列 1 行。
- 接入：`Art/Props/chest_frames.tres`、`Combat/chest.tscn`，7 fps，不循环。
- 生成提示要求概要：参考 Maps/Tile/sheet 中的棕色木箱与银色包边；生成同一只像素宝箱的四个连续开启姿态，关闭、略开、半开、完全打开带金色光芒；严格等宽分帧，透明背景，无文字和格线，保持统一视角与位置。

## 菲比、糯糯大招

- 保存文件：`Art/Characters/ultimate_casts.png`，1774×887，4 列 2 行。
- 接入：`Characters/Animations/phoebe_ultimate.tres` 与 `nuonuo_ultimate.tres`，每人 4 帧，7 fps，不循环。
- 生成提示要求概要：以上排菲比、下排糯糯制作大招施放精灵图；保留参考图的面孔、发型、衣服和像素比例。菲比金紫色光环，糯糯青红色光效，四帧连续蓄力施放动作；等宽等高单元格，同一角色基线一致，不相互重叠，真正透明背景，无文字、标签或格线。

以上为生成要求概要，供继续迭代；输出按实际尺寸建立了 AtlasTexture。两位玩家已有的挨打/受伤/死亡图集和武器图集记录仍见 `Characters/GENERATION.md`。
