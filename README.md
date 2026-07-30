<div align="center">
  <img src="public/lexora-icon-192.png" alt="Lexora 图标" width="128" height="128">

  # Lexora · 能生成个人词汇书的双语词典

  **每一次查词，都在写你自己的词汇书。**

  [![Release](https://img.shields.io/github/v/release/xiaozhangwangxue/lexora?style=flat-square&color=2444c8)](https://github.com/xiaozhangwangxue/lexora/releases/latest)
  [![Build](https://img.shields.io/github/actions/workflow/status/xiaozhangwangxue/lexora/build-release.yml?branch=main&style=flat-square&label=4-platform%20build)](https://github.com/xiaozhangwangxue/lexora/actions/workflows/build-release.yml)
  [![License](https://img.shields.io/github/license/xiaozhangwangxue/lexora?style=flat-square)](LICENSE)
  [![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-10131d?style=flat-square)](#下载与安装)

  [官方网站](https://lexora.12323456.xyz) · [下载应用](https://lexora.12323456.xyz/#download) · [捐款支持](https://lexora.12323456.xyz/donate) · [English](README.en.md)
</div>

<p align="center">
  <img src="public/og.png" alt="Lexora — Make your words worth keeping" width="900">
</p>

---

Lexora 是一款面向 Android、macOS、Windows 与 Linux、可以生成个人词汇书的双语词典。搜索时会实时联想，并按词性展示英文释义、中文释义、相关词、近义词、反义词、例句与常用搭配；有价值的词可以一键加入词汇书，再排版为紧凑、清晰、适合阅读和打印的 PDF、EPUB、可编辑 DOCX、分页图片或长图。

> [!IMPORTANT]
> Lexora 不要求账号。单词列表、历史记录和生成的 PDF 默认保存在设备本地；只有点击“开始生成”后，待查询的单词、释义和例句才会发送给公开词典与翻译服务。

## Lexora 4.0.1 更新说明

<!-- release-notes:zh:start -->

### 4.0.1 可选服务器加速

- 设置新增“Lexora 服务器加速”开关，可同时加速查单词、实时联想和词汇书生成。
- 开关默认关闭，安装或升级 4.0.1 后仍使用原来的搜索方式，不改变现有使用习惯。
- 用户主动开启后优先通过 Cloudflare 中转连接 Lexora 词典服务器；连接失败会自动回退到原有词典来源。
- 离线词库继续保持最高优先级，服务器开关和用户选择会保存在本机。

### 字典与个人词汇书

- 新增独立单词搜索页：实时联想、按词性整理的双语释义、例句、搭配和可点击相关词。
- 搜索结果可一键加入或移出词汇书，并用轻量动画和自动消失提示即时反馈。
- 历史页新增“生成历史 / 搜索历史”切换，曾经查过的单词可直接再次搜索。
- 设置新增搜索结果字号精细调节，默认针对手机阅读优化。
- 导航升级为单词、词汇书、生成记录、历史和设置五个清晰工作区。
- 结果文字支持选择复制，关联词可双击打开可拖拽的快速预览。
- 词性在中英文界面中都同时显示中文说明。

### 搜索速度与准确性

- 搜索提交后立即进入结果页，核心释义目标在 2 秒内呈现，其余内容继续在后台补全。
- 新增 Cloudflare 边缘词典聚合，完整英文释义、音标、词性和关联内容会在第二阶段快速出现。
- 中文翻译改为边缘批量请求；联想与近反义词、例句、短语独立补齐，不再串行阻塞搜索。
- 联想输入时仅预取前三个候选的英文词典数据，并只预热首项释义翻译，避免翻译服务限流。
- 翻译请求限制为两路并发，遇到限流会渐进重试；失败结果不再污染缓存。
- 确认查询后保留已完成的翻译缓存，重复查看释义更快、更稳定。
- 修复部分词条显示原始音标编码的问题，音标统一转换为可读 IPA。
- 4.0.0 将联想列表改为独立悬浮层，输入和内容补全不再反复推动页面布局。

### 历史、预览与交互

- 搜索历史支持多种排序、多选删除和批量加入词汇书。
- 搜索历史和结果中的关联词统一使用可拖拽浮层；上滑全屏、下滑关闭，系统返回可回到上一个词。
- 双击桌面侧栏“单词”可返回搜索主页，联想出现时立即隐藏 GitHub 按钮。
- 历史页顶栏和搜索历史列表使用统一布局。
- 重新优化软件中的搜索、拖拽、状态反馈、页面切换和桌面边栏动画。
- 完善减少动态效果支持，保留必要的状态反馈并移除不必要的位移动画。

### 跨平台稳定性与更新

- 修复 macOS 导出图片时因相册权限说明缺失而闪退的问题。
- 快速调整桌面窗口宽度时暂停高成本侧栏动画，松手后自然恢复，明显减少卡顿。
- 搜索结果显示后自动隐藏 GitHub 按钮，避免遮挡内容。
- 修复窄窗口下搜索结果挤压错位，并限制桌面窗口最小尺寸。
- 重新居中 macOS 收起侧栏后的红绿灯按钮，并适当加宽收起状态。
- macOS 更新改为跳转官网下载安装，并自动退出应用及打开“隐私与安全”。
- 修复阅读器无法通过桌面侧栏退出、安卓切换词汇书时误弹键盘的问题。
- 更新检查增加官网、Cloudflare Worker 与 GitHub 三路清单容错，单个入口受网络限制时会自动切换。
- macOS 侧栏改为贴边原生半透明材质，并把交互式液态玻璃限制在选中项以降低缩放开销。
- 全面复核 Android、macOS、Windows 和 Linux 的构建、安装、升级及下载完整性。

### 官网、文档与诊断

- 官网演示会按设备显示移动端或桌面端外观，并可切换多个功能页面。
- 官网、README 和首次教程全面更新，并继续提供历史版本下载。
- 开发者模式记录输入、导航、搜索、网络响应、耗时、生成和阅读器等完整诊断信息。
- 4.0.0 将高频滚动日志合并并移出界面主线程，同时增加 P50、P95、最差帧和慢帧统计。
- GitHub、官网和 README 使用同一份完整更新说明，应用内使用适合小屏幕阅读的精简版。

### 4.0.0 性能、安全与动画

- 官网拖拽预览改为逐帧更新 GPU 合成变换，不再在每次指针移动时重新渲染整个页面。
- 单词换位使用可中断的 FLIP 动画，首页标志和演示页面使用更短、更自然的非线性过渡。
- 移除动态阴影滤镜、背景位置、top 和 transition: all 等高开销或不可控动画。
- 统一版本号、构建号、下载文件名、校验值和发布说明，发布前自动检查各处是否一致。
- 更新网页运行与构建依赖，修复已知高危安全漏洞。
- 新增小屏更新说明、快速输入、桌面实时缩放、减少动态效果和发布清单兼容测试。

<!-- release-notes:zh:end -->

## 为什么选择 Lexora

| 🔎 像搜索引擎一样查词 | ＋ 一键收藏到词汇书 | ↕️ 像播放列表一样整理 | 📖 直接得到成品 |
| --- | --- | --- | --- |
| 历史优先的实时联想与完整双语结果 | 加号变为对勾，随时加入或取消 | 长按拖动、滑动删除、四种排序 | 自动生成五种格式的个人词汇书 |

## 核心功能

- **完整双语词典**：独立搜索页提供历史优先的实时联想、按词性分组的多条中英文释义、相关词、近反义词、例句和常用搭配。
- **搜索即收藏**：搜索结果中的英文相关词可点击继续查询；右上角加号可一键加入词汇书，并用轻量动画和自动消失提示即时反馈。
- **快速收集**：在词汇书页按回车添加单词，自动阻止重复和无效输入。
- **文档批量导入**：从 DOC、DOCX、PDF、TXT、RTF、ODT 等文件按换行提取大量单词或短语，一次加入列表。
- **自由整理**：长按调整顺序、向左滑动删除，支持自定义、A–Z、长度和估算难度排序。
- **完整查词**：获取英文定义、公开语料词频信号、美式与英式音标、近义词、反义词和例句。
- **安全模糊搜索**：完全匹配失败时，仅采用拼写高度相似且能再次取得完整词典数据的候选词；结果页会用红色标出跳过项、黄色标出相似匹配及实际采用的单词。
- **更快批量生成**：最多四路并发查询，查询结果在本机缓存 14 天；长词表和重复生成都更快。
- **完整中译**：释义、例句及近反义词均带中文结果；PDF 标签也采用中英双语。
- **中英界面**：自动识别设备语言；中文设备默认显示简体中文，其他设备显示英文。
- **双历史记录**：历史页可在生成历史和搜索历史间切换，曾经查过的词可一键再次搜索。
- **搜索字号**：设置页可精细调节搜索结果字号，默认针对手机阅读优化。
- **首次引导**：第一次打开应用时会介绍搜索、收藏、整理、生成与历史功能。
- **独立设置**：文档格式、字号与例句数量集中在设置页，并提供官网快捷入口与捐赠二维码。
- **三种导出格式**：可生成适合打印的 PDF、适合电子书阅读器的 EPUB，以及保留结构且方便继续编辑的 DOCX。
- **自定义排版**：可选小、中、大三档字号与 0、1 或 2–3 句例句；中号使用紧凑双栏，字号足够小时自动使用三栏，并以独立分栏消除高矮卡片之间的空洞。
- **稳定字体**：中文使用 Noto Sans SC，音标使用完整支持 IPA 的 Noto Sans；DOCX 同样内嵌字体，跨设备打开不乱码。
- **生成记录**：在应用内直接阅读 PDF、EPUB 和 DOCX，支持双指缩放，三点菜单可先预览前几个单词。
- **单词历史**：保留全部生成过的单词，支持按次数、首字母、时间、难度正反排序，星标单词永久置顶。
- **后台完成通知**：生成结束时若 Lexora 不在前台，系统通知会及时提醒。
- **原生分享**：桌面端支持“导出到…”，Android 直接调用系统分享页。
- **平台自适应**：macOS 采用 SwiftUI 液态玻璃导航背景，Android 可在空白区域左右滑动换页，并避开单词的左滑删除手势。

## 下载与安装

推荐从[官方网站下载区](https://lexora.12323456.xyz/#download)获取由 GitHub Actions 在对应原生系统中构建的安装包。官网只在浏览器本地识别设备系统并推荐对应版本，不会上传设备信息；下载文件同时镜像到 Cloudflare R2，国内访问无需打开 GitHub。

| 平台 | 安装包 | 系统要求 | 下载 |
| --- | --- | --- | --- |
| Android | APK | Android 8.0+ | [官网下载](https://lexora.12323456.xyz/downloads/lexora-android-v4.0.1.apk) |
| macOS | 拖动安装 DMG | macOS 12+ | [官网下载](https://lexora.12323456.xyz/downloads/lexora-macos-v4.0.1.dmg) |
| Windows | 安装程序 EXE（默认安装后启动） | Windows 10 / 11 | [官网下载](https://lexora.12323456.xyz/downloads/lexora-windows-v4.0.1-setup.exe) |
| Linux | tar.gz | 64 位 Linux | [官网下载](https://lexora.12323456.xyz/downloads/lexora-linux-v4.0.1.tar.gz) |

<details>
<summary><strong>首次安装被系统拦截怎么办？</strong></summary>

- **Android**：允许当前浏览器或文件管理器“安装未知应用”，再选择 APK。
- **macOS**：打开 DMG，按精心设计的背景箭头将 Lexora 拖入 Applications；若被拦截，按住 Control 点击应用并选择“打开”。
- **Windows**：双击安装程序，按向导完成安装；最后的“启动 Lexora”默认勾选。如果 SmartScreen 出现提示，选择“更多信息”→“仍要运行”。
- **Linux**：解压后为 `lexora` 主程序添加执行权限，再启动。

</details>

> [!IMPORTANT]
> Android v0.2.0 使用了临时构建签名，旧私钥无法恢复，因此升级到采用稳定签名的 v0.3.0 时需要先卸载旧版再安装一次。自 v0.3.0 起，后续版本继续使用同一发布签名，可直接覆盖更新。请先按需导出旧版中的 PDF。

所有发行文件名都包含版本号，例如 `lexora-android-v4.0.1.apk`。官网的“历史版本”中继续提供 3.2.5 和 3.1.0，不会从 R2 删除。应用内更新优先使用 Cloudflare R2，并在打开安装包前校验下载完整性与 SHA-256。

## 三步生成词汇书

1. 在“单词”中搜索并一键收藏，或在“词汇书”中输入、批量导入单词和短语。
2. 长按调整顺序或选择排序方式，在“设置”中选好字号与例句数量，然后点击“开始生成”。
3. 选择 PDF、EPUB、DOCX、分页图片或长图，在“生成记录”阅读、导出或分享，在“历史”查看所有生成过的单词。

```text
word list → dictionary + corpus + translation → bilingual layout → PDF / EPUB / DOCX → history / export / share
```

## 数据来源与准确性

| 内容 | 来源 | 说明 |
| --- | --- | --- |
| 定义、音标、例句 | [Dictionary API](https://dictionaryapi.dev/) | 免费公开英文词典接口 |
| 相关词、词频信号与拼写建议 | [Datamuse](https://www.datamuse.com/api/) | 用于近义词补充、相对词频、难度估算及严格模糊匹配 |
| 中文翻译 | [MyMemory](https://mymemory.translated.net/) | 用于释义、例句及相关词中译 |
| PDF 中文与音标字体 | Noto Sans SC + Noto Sans | 首次生成时获取并缓存，完整覆盖 IPA 字符 |

难度是基于词频和词形长度的学习级别估算，并非官方考试分级。第三方服务可能限流或暂时不可用；Lexora 会显示明确错误，不会伪造查询结果。详见 [数据来源与隐私](docs/DATA_SOURCES.zh-CN.md)。

## 从源码运行

需要 Flutter stable 与目标平台工具链：

```bash
git clone https://github.com/xiaozhangwangxue/lexora.git
cd lexora/apps/lexora
flutter create --project-name lexora --platforms=android,linux,macos,windows .
flutter pub get
dart run flutter_launcher_icons
flutter run
```

官网需要 Node.js 22 或更新版本：

```bash
cd lexora
npm install
npm run dev
```

<details>
<summary><strong>项目结构与发布流程</strong></summary>

```text
apps/lexora/       Flutter 跨平台客户端
app/               Lexora 宣传官网与捐款页面
worker/            Cloudflare Worker、R2 下载与受保护上传通道
wrangler.deploy.jsonc 独立 Cloudflare Worker 与官方域名路由
.github/workflows/ 四平台构建、GitHub Release 与 R2 镜像
docs/              架构、数据来源与隐私说明
```

官网由 `lexora-official` Cloudflare Worker 直接提供，并通过 Worker Route 接管 `lexora.12323456.xyz/*`，不经过 ChatGPT.site。推送 `v*` 标签会分别在 Android、Linux、Windows 与 macOS 原生 runner 中执行静态检查、图标生成、Release 构建与打包，再发布 GitHub Release；配置 Cloudflare 凭据后可自动同步 R2。

</details>

## 捐款支持

如果 Lexora 帮你节省了整理时间，可以自愿支持跨平台适配、数据服务和长期维护。也可以打开更适合手机扫码的[独立捐款页面](https://lexora.12323456.xyz/donate)。

| 微信支付 | 支付宝 |
| :---: | :---: |
| <img src="https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate/wechat.png" alt="微信支付收款码" width="260"> | <img src="https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate/alipay.jpg" alt="支付宝收款码" width="260"> |

## 参与项目

欢迎提交 [Issue](https://github.com/xiaozhangwangxue/lexora/issues) 与 Pull Request。Lexora 基于 [MIT License](LICENSE) 发布。

<div align="center">
  <sub>Make your words worth keeping. · 把单词变成值得保存的东西。</sub>
</div>
