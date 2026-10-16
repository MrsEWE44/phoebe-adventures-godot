# Ancient Egypt 7-Level Tileset Pack

本包包含 7 张古埃及关卡原图，以及每张图对应的 32×32 瓦图、地图索引和 Godot 4.7 TileMapLayer 辅助脚本。

## 关卡

1. **沉沙神殿** — `level_01_sunken_temple` — 古埃及遗迹神殿地下城 / 初入地宫
2. **崩塌遗迹** — `level_02_collapsed_ruins` — 断桥、深坑、崩塌遗迹 / 探险路线
3. **镜像祭殿** — `level_03_mirror_sanctum` — 对称地宫、祭坛、守护石像 / 神秘仪式感
4. **沉没圣池** — `level_04_drowned_crypt` — 水下遗迹、淹没墓室、残柱 / 阴冷探索
5. **诅咒机关廊** — `level_05_cursed_traps` — 尖刺、机关、狭窄通路 / 高危险陷阱区
6. **冥影墓城** — `level_06_shadow_necropolis` — 地下墓城、蛛网、棺椁与深坑 / 恐怖墓穴
7. **阿努比斯终殿** — `level_07_anubis_temple` — 阿努比斯神殿、中央祭坛、水池 / 终局神殿

## 文件结构

每个关卡目录都包含：
- `map.png`：对应完整关卡地图
- `tileset_32x32.png`：对应瓦图
- `tilemap.json`：完整地图网格与 atlas 索引
- `tilemap.csv`：纯网格版本，便于批量处理
- `godot_tilemap_builder.gd`：Godot 4.7 TileMapLayer 构建辅助代码
- `level_name.txt`：关卡显示名和主题

## Godot 注意

为了避免之前出现的文件名乱码与 UID 引用问题，压缩包内的实际文件夹与资源文件名全部使用 ASCII；中文只放在 UTF-8 文本/JSON 的显示名中。
瓦图是真正的 atlas 图，推荐放进 `TileSetAtlasSource`，不要用大量 Sprite2D 代理 TileMap。

这些瓦图由当前 7 张地图按 32×32 直接切分并重排，重点是“和原地图一一对应、可还原”。如果后续要做成更小、更通用、可自由拼接的美术瓦片库，可以再进一步把墙、地面、水、柱子、门、火盆等按类别整理成公共 TileSet。
