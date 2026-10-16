# 第二章图像生成记录

模式：内置 image_gen。原图保留，输出另存为透明 PNG；动画使用 Godot AtlasTexture 切片。

最终文件：`ikun_sheet.png`（948×1659 RGBA）、`weapons.png`（1774×887 RGBA）、`aquatic.png`（1269×1239 RGBA）。生成工具返回的原始 PNG 原样复制，未修改像素；不等距的行间距通过资源中的 AtlasTexture 坐标适配。

## ikun 动画图集
Reference: NextPlayer/ikun.jpg, character identity reference only.
Use case: stylized-concept. Create one production game sprite sheet on genuine transparent alpha, exactly 4 columns by 7 rows, equally sized cells, no grid lines or labels. Full body chibi yellow chicken basketball player matching the reference: silver center-parted hair, expressive white eyes, red cheeks, black outfit with gray suspenders, orange feet. Remove the background and REMOVE ALL BASKETBALLS from the character. Keep hands empty. Consistent orthographic 3/4 top-down dungeon RPG style, crisp outlines, readable at 42 pixels high. Each cell contains one complete character centered with feet aligned, ample transparent padding, no overlap. Row 1 idle facing down four subtly different poses; row 2 walk down four-step cycle; row 3 walk side facing right four-step cycle; row 4 walk up back view four-step cycle; row 5 hurt/recoil four escalating poses; row 6 defeated four-stage fall ending lying down, cartoon non-graphic; row 7 ultimate basketball throwing motion with EMPTY HANDS four stages windup to follow-through. No text, no balls, no background, no ground shadows.

## 水下武器与篮球图集
Use case: stylized-concept. One transparent PNG sprite atlas, exact 4 columns by 2 rows of equal cells, no grid, no text. Polished colorful pixel-art dungeon RPG equipment, all centered, isolated with ample margin. Row1 left to right: orange basketball with black seams; silver teal harpoon gun pointing right; cyan coral trident pointing right; brass blue torpedo launcher pointing right. Row2: spinning orange basketball with short gold trail pointing right; long steel harpoon projectile pointing right; small blue torpedo with cyan bubbles pointing right; glowing cyan pressure orb. Consistent scale, sharp readable silhouettes, genuine transparent alpha. Basketball is a separate weapon with no character or hand.

## 水生敌人动画图集
Use case: stylized-concept. One transparent PNG production sprite atlas, exact 4 columns by 4 rows equal cells with no labels/grid. Crisp colorful pixel-art top-down dungeon RPG aquatic monsters, centered complete bodies, consistent feet/bottom alignment and transparent padding. Each row is a four-frame swimming motion loop. Row1 teal snapping crab with coral shell; row2 small blue predatory shark with readable fins, facing right; row3 translucent purple jellyfish with glowing tentacles; row4 large armored abyssal crab king with gold crown-like coral shell and blue claws, facing down. Friendly stylized game enemies, no gore, no environment, no shadows, genuine transparent alpha.
