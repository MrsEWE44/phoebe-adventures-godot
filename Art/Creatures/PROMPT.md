# 沙漠动物敌人动画素材

`desert_creatures.png` 是通过内建 `image_gen.imagegen` 生成的像素动物动画图集，未使用 CLI/API fallback，未对生成图像进行后处理，原始透明通道完整保留。

- 输出：1448 × 1086 像素，RGBA PNG。
- 布局：4 列 × 3 行，每格 362 × 362 像素。
- 第 0 行：青绿金色圣甲虫，4 帧爬行循环。
- 第 1 行：沙金紫色眼镜蛇，4 帧游动循环。
- 第 2 行：金黑豺狼，4 帧行走循环。
- 朝向：面向左/左前方，游戏中可水平翻转。
- 建议以最近邻过滤显示，按 4–8 FPS 播放。使用同一行一致的裁切区域和基准点，避免逐帧独立裁切造成动画跳动。

## 检查结果

已查看整张图集，确认三种动物、各 4 帧、排列和朝向正确。PNG 为 `Format32bppArgb`，左上角 alpha 为 0。按 362 × 362 分格检查，12 帧的 alpha ≥ 128 主体均没有触及单元格边界。透明区域带有少量低 alpha 噪点，保留生成图原始 alpha。实际主体留白比提示中的 20% 小，但各帧完整可用。

各行主体整体范围（同一行所有帧合并，格内坐标，alpha ≥ 128）：

| 行 | X 范围 | Y 范围 |
| --- | --- | --- |
| 圣甲虫 | 56–322 | 125–331 |
| 眼镜蛇 | 31–343 | 73–290 |
| 豺狼 | 45–339 | 12–294 |

可用这些范围计算每种动物一致的显示偏移。碰撞形状应独立以脚底/躯干设计，不应使用整张透明格子的边界。

## 实际生成提示

```text
Use case: stylized-concept
Asset type: production 2D game enemy animation sprite sheet, transparent PNG
Primary request: exactly one 4-column by 3-row sheet containing twelve separate pixel-art animal sprites for an ancient Egyptian top-down dungeon game. Four sequential looping walking/crawling frames for each creature, left to right.
Scene/backdrop: genuine transparent alpha background. No backdrop, no checkerboard painted into the image, no floor, no ground shadow.
Subject: row 1 is the same teal-and-gold sacred scarab beetle in four crawl-cycle poses; row 2 is the same sandy-gold and violet desert cobra in four slither-cycle poses; row 3 is the same gold-and-black jackal in four walk-cycle poses. Use left-facing or front-left-facing three-quarter top-down views, every frame of each animal faces the same direction. Scarab legs alternate, cobra tail undulates, jackal legs alternate.
Style/medium: crisp hand-crafted retro pixel art, chunky pixel clusters and a dark outline, limited color palette, no smooth 3D or painterly shading. Strong readable silhouettes at 32x32 in a game.
Composition/framing: strict invisible equal-cell grid of 4 columns and 3 rows. Canvas width:height exactly 4:3, preferably 1536x1152. Cells are square. Each creature is independently centered in its own cell, same position and same size across its four frames. Each cell has at least 20 percent fully transparent padding on each side; creature fills the middle 60 percent. No part of any animal crosses a cell boundary. Pixel baselines within each row aligned. Entire creature fully visible in every frame.
Constraints: exactly twelve sprites, no extra animals or objects. No grid lines or borders. No lettering, numbers, labels, logos, watermark, UI, terrain, smoke, glow, or ground shadows. Preserve actual transparency.
```

