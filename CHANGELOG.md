# 更新日志

本项目的版本号跟随上游：`<Compositor 版本>-<语言包修订号>`。

## 1.4.5-2 — 2026-10-05

### 新增
- 从 `tools/extract-missing.py` 的 candidates.txt 补齐 **88 条**遗漏：
  - 工具按钮 tooltip（Marquee/Lasso/Magic/Brush/Spot Healing/Clone Stamp/Smear/Gradient/Shape/Crop/Move/Hand/Zoom/Eyedropper/Type）—— 已加入语言包。**注**：`.help(tool.label)` 当前源码走 `StringProtocol` 重载（swiftui verbatim），**不会**查语言包；它们仅作未来源码切到 `LocalizedStringKey` 时的准备。
  - AX 标签：`Font`、`Blend mode`、`Canvas text`、`Canvas`、`Horizontal ruler`、`Vertical ruler`、`Press keys…`、`Press a shortcut` —— `setAccessibilityLabel(String)` 同上为 verbatim，本版本不生效。
  - Color Picker 标题（10 条：Text/Background/Foreground/Gradient Map Highlights/Shadows/Vignette/Dither Light/Dark/%@）—— 这些 `NSAlert`/AppKit 字面量**会自动查表**，v1.4.5-2 起生效。
  - 错误/提示（14 条）：「已选中多个图层」、「%@」是文件夹 / 隐藏 / 调整图层、「图层蒙版已关闭」、「对象选择需要 macOS 14」、「复制的图层超出 %@ 兆像素」等。
  - 引导线颜色（7 条：浅灰/浅蓝/浅红/中蓝/黄/品红/青）。
  - 滤镜名（4 条：光晕/辉光、抖动、色调对比度、Camera Raw 滤镜）。
  - 调整图层/混合模式（10 条：色彩平衡、柔光/强光/亮光/线性光/点光/实色混合/排除/划分/线性加深/线性减淡）。
  - 显示选区/隐藏菜单/羽化选区/新建文字图层/对象选择等。
- 修正两处原翻译：
  - `Type`：`类型` → **`字体`**（按用户反馈；`Text("Type")` at TypeControls 文字工具面板 header）
  - `Magic Wand`：`魔棒` → **`魔法棒`**（按用户偏好统一 Wand/Magic 三个 key）
- 词条总数 705 → **793**。

### 仍无法覆盖的「B 类」（需上游改源码）
1. `.help(String)` / `.accessibilityLabel(String)` —— swiftui StringProtocol 重载，verbatim 不查表。需把源码改成 `.help(LocalizedStringKey(...))`。
2. `Text(condition ? "X" : "Y")` 三元式 —— 类型推断为 `String`，走 verbatim 重载。需拆成显式 `LocalizedStringKey` 或两个独立分支。
3. `button.setAccessibilityLabel("X")`（AppKit 路径）—— 接 String 不查表；需 `setAccessibilityLabel(LocalizedStringKey("X"))` 或 `setAccessibilityLabel(NSAttributedString(string: NSLocalizedString("X", comment: "")))`。
4. 计算属性 `var label: String { ... }`（如 NavigationTool.label）同上，verbatim 返回 String。

[1.4.5-2]: https://github.com/skyecx/compositor-zh-hans/releases

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
