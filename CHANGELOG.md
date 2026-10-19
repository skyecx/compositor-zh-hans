# 更新日志

本项目的版本号跟随上游：`<Compositor 版本>-<语言包修订号>`。

## 1.5.3-1 — 2026-10-19

### 新增
- 适配 Compositor **1.5.3**（CFBundleVersion 49，2026-10-15 发布），一次跨过 9 个版本（1.4.6 → 1.5.3）。
- 用 `tools/extract-missing.py` 对 v1.5.3 源码扫描，**高置信度待翻译 55 条**全部补齐：
  - **CMYK 印刷**（1.5 新增）：`CMYK` / `校样颜色` / `色域警告` / `配置文件` / `载入配置文件…`，以及「视图 › CMYK › 配置文件」提示句。
  - **全新的「导出为…」面板**（1.4.8 新增，本版大幅扩写）：`导出为` / `格式` / `位深` / `页面` / `每通道 16 位` / `更多格式` / `缩放导出…` / `CMYK 通过…输出印刷油墨` 等。
  - **命令面板**（1.4.6 新增，1.4.7 移到 ⌘F）：`搜索命令…` / `搜索命令与工具` / `没有匹配的命令`。
  - **导航器缩略图**（1.4.8 新增）：`导航器（300% 及以上）` / `导航器` / `点击或拖动以移动视图`。
  - **画布旋转**（1.4.6）：`顺时针旋转画布 90°` / `逆时针旋转画布 90°`。
  - **扫描线滤镜**（1.4.8 独立成滤镜）：整套参数 tooltip（间隙/移位/平滑度/阈值/色彩分离/黑场 …）。
  - **渐进模糊**（1.5.1 新增）：起止点、保留透明度、全部 tooltip。
  - **快捷键窗口**（1.5.2）：`移除该快捷键`、带 ⊗ 的清除说明句。
  - **Camera Raw / RAW 导入**（1.4.10、1.5.2）：`Reset %@`、`高光恢复`、`Camera Raw…`、`导入后打开 Camera Raw 滤镜`。
  - **形状工具**（1.5.3）：`填充颜色`、`平滑拐角`。
- 另从 `candidates.txt` 挑出 **78 条** 1.5.x 新功能文案一并翻译（见下方「准备项」说明），词条总数 793 → **926**。
- 两条「保持原文」词条：`CMYK`、`Camera Raw…`（与既有的 `RGB`、`px` 同类，避免界面出现半截翻译）。

### 修复
- `tools/extract-missing.py`：新增**手写字符串字面量词法分析**，正确处理插值里嵌套字符串的写法，例如
  `.help("Other formats: TIFF and PDF\(flag ? ", and EXR…" : "")")`。
  旧的正则会在插值里第一个引号处截断，把真正的词条算成 `"Other formats: TIFF and PDF%"` 这种不存在的 key，
  于是**已经翻译好的词条被误报成缺失**。现在 `find_interps()` 也会跳过插值里的嵌套字符串。
- 修正语言包中两处**占位符类型错误**（`%@` → `%lld`）：`That shape is too large. A shape can cover up to %lld megapixels.`、
  `The copied layers exceed this project’s %lld-megapixel limit.` —— 源码里是 `Int`，写成 `%@` 会**静默失效**。

### 准备项说明（当前不生效，待上游改源码后自动生效）
本版新增的 78 条里有相当一部分属于「B 类」：上游把它们写在枚举 `rawValue`、计算属性或三元表达式里，
最终以 `Text(<String>)` / `.help(<String>)` 的逐字渲染通道输出，**不会查语言包**。已翻译并入库，
等上游把这些调用点改成 `LocalizedStringKey` 即可直接生效，无需再补翻译。典型的有：

| 位置 | 例子 | 原因 |
|---|---|---|
| 多层选择标签 | `16 位图层：…`、`HDR 图层：…` | `toolTip = <String>` |
| 图层右键菜单 | `转换为 16 位` / `转换为 8 位` | `NSMenuItem(title:)` |
| Sparkle 更新弹窗 | `安装更新` / `稍后提醒` / `跳过此版本` | `alert.addButton(withTitle:)` |
| 画布单位/DPI 胶囊 | `分辨率：72 …`、`单位：像素…` | `CyclePill(_ title: String, help: String)` |
| 扫描线/胶片参数 | `黑场`、`色彩分离`、`阈值` | `control(_ title: String, …)` |
| 命令面板条目 | `工具 › %@`、`图层 › 添加图层蒙版` | `CommandPaletteEntry(id: <String>)` |

### 状态
- 高置信度缺失：**0 条**；`stale` 44 条（旧文案被上游改名/删除，按惯例保留不删）。
- `check-strings.py` 警告 4 → 6 条：仅新增 `CMYK`、`Camera Raw…` 两条「原文即译文」，无其它问题。

[1.5.3-1]: https://github.com/skyecx/compositor-zh-hans/releases

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
