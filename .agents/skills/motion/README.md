# /motion — Claude Code 动画生成 Skill

[English](README_EN.md) | 中文

一个 Claude Code skill：把一张参考图（或一句描述）变成**复古剪贴报风格**的动画短视频。

流水线：参考图 → Nano Banana 生成关键帧 → Kling 图生视频 → （可选）超分增强。全程对话式操作，每一步花钱前先确认。

![效果演示](assets/demo-motion.gif)

▶️ [高清版演示视频](assets/demo-motion.mp4) · [在线看](https://imluna.pages.dev/skills/motion)

## 为什么是复古剪贴报

AI 电影感写实风一眼假、无记忆点。这个 skill 内置了一套验证过的复古拼贴 Motion Design 配方：高饱和纸纹背景 + 黑白半调网点剪贴 + 撕纸标签粗黑中文 + 定格动画式微抖。关键帧和视频的 prompt 骨架都写好了，直接出片。

## 安装

```bash
git clone https://github.com/LunaAI519/motion-skill.git ~/.claude/skills/motion
```

重启 Claude Code 后输入 `/motion` 即可。

**前置要求**（两个 MCP server）：

| MCP | 用途 | 说明 |
|---|---|---|
| nanobanana（Gemini 图像） | 生成关键帧 | 需自己的 Gemini API key |
| higgsfield | 图生视频 + 超分 | Kling 默认约 7.5 积分/条视频 |

## 使用

```
/motion
```

然后给它：一张参考图（拖进终端）+ 一句动作描述（如「镜头缓慢推近，头发被风吹动」）。默认 9:16 竖屏。没有参考图也行，纯文字直接生成首帧。

每一步的产出（关键帧图、积分花费）都会先给你确认，不会自己偷偷烧积分。

## 作品集

全部由本 skill 生成，从想法到成片每条约 3 分钟。

| | |
|---|---|
| ![山城纸雕](showcase/chongqing-papercraft.gif) | ![市盈率](showcase/pe-ratio.gif) |
| **山城纸雕**：立体纸雕风格的山城夜景，索道穿楼而过。[高清 mp4](showcase/chongqing-papercraft.mp4) · [关键帧1](showcase/chongqing-papercraft-frame1.png) · [关键帧2](showcase/chongqing-papercraft-frame2.png) | **市盈率**：为一篇讲市盈率的科普文生成，天平称利润。[高清 mp4](showcase/pe-ratio.mp4) |
| ![片头](showcase/hero.gif) | ![月亮关键帧](showcase/moon.jpg) |
| **网站片头**：[imluna.ai](https://imluna.ai) 首页动态片头。[高清 mp4](showcase/hero.mp4) | **月亮**：纯文字生成的关键帧，没用任何参考图 |

▶️ 更多：[SpaceX 进入纳指100](showcase/spacex.mp4)（巨手把火箭放进货架，规则只认块头）

## 版权红线

skill 内置五条自检，每次生成前过一遍：不生成真人肖像、不出现品牌 logo、不生成受版权保护的角色、参考作品只学配方不搬画面、配乐用免版权音乐。

## 相关项目

- [xsub](https://github.com/LunaAI519/xsub) — Chrome 扩展，x.com 英文视频自动中文字幕
- [video-to-brain](https://github.com/LunaAI519/video-to-brain) — 发视频给 Telegram Bot，AI 笔记自动进 Obsidian
- 更多作品见 [imluna.ai](https://imluna.ai)

## License

MIT © Luna ([imluna.ai](https://imluna.ai))
