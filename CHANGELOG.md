# 更新日志

本项目的版本号跟随上游：`<Compositor 版本>-<语言包修订号>`。

## 1.4.5-1 — 2026-10-03

### 新增
- 适配 Compositor **1.4.5**（CFBundleVersion ?，待校验），覆盖自 1.0.4 以来的新增 UI 文本。
- 用 `tools/extract-missing.py` 对 v1.4.5 源码扫描，发现并补齐 **182 条**新词条：
  - Camera Raw 整套面板（ColorControls / DetailOptics / GeometryCalibration / Calibration / Slider）
  - 视图：Grid / Guides / Rulers / Snap To / Lock Guides / Clear Guides / Document Bounds / Grid Settings
  - 选区：Color Range / Subject / Expand / Contract / Feather / Trim / Edge（魔棒/对象子选区）
  - 文字：Tracking / Leading / Edit Text / Done / Text color / 字体属性
  - 滤镜：Dither 的 Scanlines (CRT) 风格（Pixel Shape / Light on Dark / Glow / Dots / Wobble）
  - 效果：Stroke / Position / Outside / Inside / Drop Shadow / Inner Shadow / Inner Glow / Outer Glow / Color Overlay
  - 类型：Develop “%@”、Import、Reading the Photoshop file…、Preset sizes
  - 其他：Keyboard Shortcuts 编辑器、Restore Defaults、Tooltip 全文
- 语言包词条数 523 → **705**。

### 修复
- `tools/check-strings.py` 和 `tools/extract-missing.py` 的 ENTRY 正则允许「;」后挂 `// 注释`，方便追踪每个词条的源码位置。原版严格 `;\s*$`，会导致脚本看不到新加的带注释条目。
- `tools/reorganize-strings.py` 同样放宽 ENTRY 正则。

[1.4.5-1]: https://github.com/skyecx/compositor-zh-hans/releases

## 1.0.4-2 — 2026-09-20

### 新增
- 用 `tools/extract-missing.py` 扫出并补齐 12 条**带插值**的漏译词条
  （如 `Current: %lld × %lld pixels`、`Close %@`、`Original %@ histogram` 等）。
  语言包词条数 511 → **523**。

### 修复
- 修正 `tools/check-strings.py`、`tools/extract-missing.py` 的占位符正则：
  - 支持 `%lld` 等带长度修饰符的占位符（此前会漏判）；
  - 不再把 `800% and above` 中的 `% a` 误判为占位符；
  - `%@` 后面紧跟中文时不再误报。

### 工具
- 新增 `tools/reorganize-strings.py`：把语言包按功能分区重排（译文不变）。
- 新增 `tools/gen-glossary.py`：自动生成 `docs/术语对照表.md`。

## 1.0.4-1 — 2026-09-20

### 新增
- 首个公开版本，适配 Compositor **1.0.4**（CFBundleVersion 5）。
- 511 条简体中文词条，覆盖全部可通过 `Localizable.strings` 本地化的界面文本。
- `汉化.sh`：外挂式注入 + ad-hoc 重签，不改上游源码。
- `安装自动恢复.command` + `watchdog.sh`：App 自动更新后自动重新汉化。
- `docs/研究报告.md`：注入原理、三个关键坑、coverage 分析与已知限制。

[1.0.4-2]: https://github.com/skyecx/compositor-zh-hans/releases
