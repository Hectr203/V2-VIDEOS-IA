---
name: motion
description: Motion风格动画生成：参考图 → Nano Banana 生成关键帧 → Seedance 2.0 生成视频。触发词：/motion、动画、把图动起来、motion动画、图生视频。
---

# Motion 动画流水线

把一张参考图变成 Motion 风格短视频。全程中文交流，步骤简短。

## 输入

用户需提供：
1. **参考图**：本地图片路径（拖进终端即可得到路径）
2. **动作描述**：想让画面怎么动（如"镜头缓慢推近，头发被风吹动"）
3. 可选：比例（默认 9:16 竖屏）、时长（默认模型默认值）

缺参考图时也可以纯文字：让 Nano Banana 直接按描述生成首帧。

## 流程

## 风格预设：复古剪贴报（默认）

不要 AI 电影感写实风（一眼假、无记忆点）。默认用复古拼贴 Motion Design，配方：
1. 高饱和纯色纸纹背景：砖红/钴蓝/墨绿
2. 主体 = 黑白半调网点（halftone）老照片剪贴，白色贴纸描边+投影
3. 一幕一个概念：用视觉双关表达要讲的那个概念词
4. 撕纸标签 + 粗黑中文概念词（生图用 pro 模型保证文字）
5. 少量几何装饰：黑三角/米白圆/锯齿线
6. 动效克制：元素依次贴上、定格动画式微抖、镜头完全固定

关键帧 prompt 骨架：`Retro mid-century collage art, 1950s magazine cut-out style. Solid [颜色] paper background with subtle paper grain. Black-and-white halftone photograph cutouts with white sticker borders and drop shadows: [概念隐喻场景]. Small geometric accents. Torn paper label with bold black condensed Chinese characters "[概念词]". Flat graphic composition, stop-motion paper collage aesthetic, no photorealism.`

视频 prompt 骨架：`Stop-motion paper collage animation, handmade cutout style. [主体动作]. All paper cutout elements wobble subtly with stop-motion jitter. Camera completely static. Flat 2D collage aesthetic, no 3D depth, no camera movement.`

### 第 1 步：生成关键帧（Nano Banana）

用 `mcp__nanobanana__gemini_generate_image`：
- `reference_images`: [用户参考图路径]，保持风格/人物一致
- `prompt`: 描述首帧画面（英文写 prompt 效果更好）
- `aspect_ratio`: 与最终视频一致（默认 "9:16"）
- 需要更高质量时先 `set_model` 为 "pro"

如需首尾帧两张（动作幅度大的场景），再生成一张尾帧，`use_image_history: true` 保持一致性。简单动作只要首帧一张即可，别多生成。

生成后把图片路径发给用户确认，满意再进入下一步（视频要花积分，别浪费）。

### 第 2 步：上传帧到 Higgsfield

本地图片不能直接传路径，先用 higgsfield 的 media 上传工具（ToolSearch 搜 `media_upload`）拿到 `media_id`。

### 第 3 步：生成视频

用 `mcp__higgsfield__generate_video`：
- `model`: "kling3_0_turbo"（默认。seedance_2_0 效果类似但需要 Higgsfield Pro/Ultimate 套餐且贵 3 倍，套餐不够会报 403，报错就换回默认）
- `medias`: [{ "value": 首帧media_id, "role": "start_image" }]，有尾帧再加 end_image
- `prompt`: 动作/运镜描述（英文）
- `aspect_ratio` 与帧一致
- 先带 `get_cost: true` 预查积分，告诉用户花费，确认后再真正提交

提交后轮询结果，完成后把视频链接给用户。如返回 `recovery_tool` 立即调用。

### 第 4 步（可选）：增强

用户嫌糊时用 `mcp__higgsfield__upscale_video`（bytedance provider，需传源视频宽高）。

## 版权红线（每次生成前自检，一条都不许碰）

1. **不生成真人肖像**：马斯克、明星、任何可辨识的真实人物。讲公司画产品/场景隐喻，不画老板的脸
2. **不出现品牌 logo/商标**：prompt 里写 "no logos, no brand marks"，生成后肉眼复查
3. **不生成受版权保护的角色**：Labubu、迪士尼、动漫角色等一律用抽象隐喻替代
4. **参考作品只学配方不搬画面**：分析别人的视频可以，其中任何一帧都不得发布
5. 配乐提醒用户：用免版权音乐或无声，别配流行歌

## 规则

- 每一步产出先给用户看，确认再花积分
- prompt 用英文写给模型，跟用户交流用中文
- 一次只生成 1 个视频（count=1），不满意再迭代
