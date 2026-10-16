# 冥影墓城 (level_06_shadow_necropolis)

- 主题：地下墓城、蛛网、棺椁与深坑 / 恐怖墓穴
- 原图：`map.png`
- 瓦图：`tileset_32x32.png`
- 单瓦尺寸：32×32 px
- 地图网格：53×30
- 原图尺寸：1672×941 px
- 去除纯黑空白后独立瓦片数：1590
- Godot 4.7：推荐使用 `TileMapLayer` + `TileSetAtlasSource`。
- `tilemap.json` / `tilemap.csv` 保存每个格子的瓦片索引；-1 表示空白。
- atlas 索引换算：x = index % 40，y = index / 40（整数除法）。

> 说明：这些瓦图是从对应关卡原图按 32×32 网格切分并重排得到，因此可以严格对应原关卡布局，不使用 Sprite2D 代理 TileMap。
