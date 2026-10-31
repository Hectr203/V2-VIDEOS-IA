---
name: documentary-image-prompts
description: 将纪录片旁白脚本拆解为精确时间码节拍表，并按 VOXSTAGE 档案纸艺拼贴视觉系统生成逐镜图像提示词。Break a documentary narration into timed beats and VOXSTAGE paper-collage prompts. Use for documentary storyboards, visual beats, paper-collage frames, or shot-by-shot image prompts.
---

# 纪录片图像提示词

若用户使用英语，改读并遵循 [SKILL.en.md](SKILL.en.md) 及英文参考文件。开始前读取 [references/style-boards.md](references/style-boards.md)：默认使用 [assets/mg-voxstage.webp](assets/mg-voxstage.webp)，仅在用户明确指定时切换其余三张风格板。

先完整理解故事，再拆分节拍，最后生成提示词。不要在完成节拍表前写图像提示词；不要输出内部推理。

## 1. 解析故事

通读完整脚本，确认完整故事、时间顺序、关键事件、因果关系、情绪推进、视觉主题、反复出现的人物、地点和物件，以及观点之间的转场。像规划整部电影一样工作，不要逐句机械配图。

## 2. 构建节拍表

将旁白分成最小视觉叙事单位。每个节拍只传达一个画面想法。

- 按每秒 2.5 个词累计计算时间码。
- 每个节拍通常覆盖 2-3 秒、约 5-8 个词。
- 短句通常为一个节拍；长句在逗号、连词或逻辑分句处自然拆分。
- 保留旁白原文，不得改写；不得不自然地切断短语。
- 输出列：节拍编号、开始时间码、结束时间码、确切旁白。
- 检查数量：30 秒约 12-15 个；1 分钟 22-30 个；2 分钟 45-60 个；3 分钟 70-90 个；5 分钟 115-150 个。明显偏离时先调整分段。

## 3. 生成图像提示词

每个节拍准确生成一条连续段落提示词；不得合并、跳过或重复节拍。提示词必须可独立运行，且仅输出节拍表与提示词块，不编号提示词、不加标题、不解释推理。

为每个节拍选择表达“核心想法”的最强纪录片视觉，而不是逐字图解。优先使用能立即表达意义的文档、地图、机器、文物、地点、报纸、肖像、证据、财务记录、政府文件或象征物。

### 构图要求

- 一个主体占约 70% 构图，最多 2-3 个辅助元素。
- 保留充足负空间与明确视觉层级。
- 只有当节拍含日期、人名、地点、数字或组织时，才可在纸条、证物标签、印章或打字机说明条上放置一条 1-4 个词的档案标签；否则不得有可读文字。
- 每条提示词都必须完整包含 [references/style-block.md](references/style-block.md) 中的“风格块”和“结尾块”。在开始前阅读 [references/voxstage-visual-system.md](references/voxstage-visual-system.md)，并把其舞台、组件、色彩与禁令落实到每一帧。

## 输出前检查

确认节拍与旁白一一对应、所有时间码累计正确、每条提示词只有一个画面想法，且每条都包含完整风格块和结尾块。
