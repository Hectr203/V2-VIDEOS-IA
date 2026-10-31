---
name: brewreel
description: 精酿 · BrewReel：四种玩法。宣传片：做竖版产品宣传短片（1080x1920，15–45 秒，抖音/视频号/小红书）。用户要做产品宣传片、推广短视频、App 介绍视频、功能演示视频、上新短片、带货片头时使用。支持软件、餐饮、电商实物、教培、美业、文旅住宿六个行业，支持中英双语。你只写 storyboard.json，校验拦规则和行业合规，一条命令出片。口播配画面：用户有 talk.mp4，或要给口播配画面时，只读 broll/SKILL-broll.md，只写 broll.json，跑 node scripts/talk.mjs，不要写 storyboard.json。造 AI 画面风格：用户用一句话描述画面风格时，读 docs/style-factory.md，跑 node scripts/broll/new-style.mjs，不要自己出图，不要替人跑 approve-style.mjs。讲课视频：用户要做讲解课、课程、普法、教程类横版视频时，只读 lesson/SKILL-lesson.md，只写 lesson.json（或 brief），跑 node scripts/lesson/make-lesson.mjs。
---

Entrada generada. Antes de actuar, lee la [fuente canónica](../../../skills/motion-video-skills/skills/brewreel/SKILL.md).
Resuelve scripts, referencias y recursos desde el directorio de esa fuente.
Aplica la precedencia de reglas de la agencia; no cargues variantes con el mismo nombre.
Selecciona por objetivo, entradas y exclusiones conforme al [contrato común](../../../agentes/contrato-agente.md).
Recibe la tarea concreta como contexto; no ejecuta todas las herramientas ni amplía autorización.
