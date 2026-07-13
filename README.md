<div align="center">
  <img src="public/lexora-icon-192.png" alt="Lexora 图标" width="128" height="128">

  # Lexora · 双语词汇书

  **输入单词，得到一本值得阅读的双语词汇书。**

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

Lexora 是一款面向 Android、macOS、Windows 与 Linux 的英语单词整理软件。把零散的单词按顺序输入后，它会联网补全难度、词频、英美音标、近义词、反义词、例句与完整中文翻译，再排版成紧凑、清晰、适合阅读和打印的双语 PDF。

> [!IMPORTANT]
> Lexora 不要求账号。单词列表、历史记录和生成的 PDF 默认保存在设备本地；只有点击“开始生成”后，待查询的单词、释义和例句才会发送给公开词典与翻译服务。

## 为什么选择 Lexora

| ✍️ 像搜索一样输入 | ↕️ 像播放列表一样整理 | ✦ 自动补全语境 | 📖 直接得到成品 |
| --- | --- | --- | --- |
| 输入单词后按回车即可添加 | 长按拖动、滑动删除、四种排序 | 音标、词频、难度、近反义词与双语例句 | 自动生成美观紧凑的 PDF 词汇书 |

## 核心功能

- **快速收集**：搜索式主页，按回车添加单词，自动阻止重复和无效输入。
- **自由整理**：长按调整顺序、向左滑动删除，支持自定义、A–Z、长度和估算难度排序。
- **完整查词**：获取英文定义、公开语料词频信号、美式与英式音标、近义词、反义词和例句。
- **更快批量生成**：最多四路并发查询，查询结果在本机缓存 14 天；长词表和重复生成都更快。
- **完整中译**：释义、例句及近反义词均带中文结果；PDF 标签也采用中英双语。
- **中英界面**：自动识别设备语言；中文设备默认显示简体中文，其他设备显示英文。
- **首次引导**：第一次打开应用时，用三步教程说明添加、排序、生成与分享流程。
- **独立设置**：PDF 字号与例句数量集中在设置页，并提供官网快捷入口与捐赠二维码。
- **自定义 PDF**：可选小、中、大三档字号与 0、1 或 2–3 句例句；中小字号自动使用双栏，一页尽量容纳 8–10 个单词。
- **精美 PDF**：中文使用 Noto Sans SC，音标使用完整支持 IPA 的 Noto Sans；缺少近义词或反义词时自动略过空区域。
- **生成记录**：在应用内直接阅读已生成 PDF，支持双指缩放，三点菜单可先预览前几个单词。
- **单词历史**：保留全部生成过的单词，支持按次数、首字母、时间、难度正反排序，星标单词永久置顶。
- **后台完成通知**：生成结束时若 Lexora 不在前台，系统通知会及时提醒。
- **原生分享**：桌面端支持“导出到…”，Android 直接调用系统分享页。
- **平台自适应**：macOS 采用 SwiftUI 液态玻璃导航背景，Android 可在空白区域左右滑动换页，并避开单词的左滑删除手势。

## 下载与安装

推荐从[官方网站下载区](https://lexora.12323456.xyz/#download)获取由 GitHub Actions 在对应原生系统中构建的安装包。下载文件同时镜像到 Cloudflare R2，国内访问无需打开 GitHub。

| 平台 | 安装包 | 系统要求 | 下载 |
| --- | --- | --- | --- |
| Android | APK | Android 8.0+ | [官网下载](https://lexora.12323456.xyz/downloads/lexora-android-v0.4.1.apk) |
| macOS | 拖动安装 DMG | macOS 12+ | [官网下载](https://lexora.12323456.xyz/downloads/lexora-macos-v0.4.1.dmg) |
| Windows | ZIP | Windows 10 / 11 | [官网下载](https://lexora.12323456.xyz/downloads/lexora-windows-v0.4.1.zip) |
| Linux | tar.gz | 64 位 Linux | [官网下载](https://lexora.12323456.xyz/downloads/lexora-linux-v0.4.1.tar.gz) |

<details>
<summary><strong>首次安装被系统拦截怎么办？</strong></summary>

- **Android**：允许当前浏览器或文件管理器“安装未知应用”，再选择 APK。
- **macOS**：打开 DMG，按精心设计的背景箭头将 Lexora 拖入 Applications；若被拦截，按住 Control 点击应用并选择“打开”。
- **Windows**：如果 SmartScreen 出现提示，选择“更多信息”→“仍要运行”。
- **Linux**：解压后为 `lexora` 主程序添加执行权限，再启动。

</details>

> [!IMPORTANT]
> Android v0.2.0 使用了临时构建签名，旧私钥无法恢复，因此升级到采用稳定签名的 v0.3.0 时需要先卸载旧版再安装一次。自 v0.3.0 起，后续版本继续使用同一发布签名，可直接覆盖更新。请先按需导出旧版中的 PDF。

所有发行文件名都包含版本号，例如 `lexora-android-v0.4.1.apk`。这样可以避免浏览器或下载目录把新旧安装包混淆。

## 三步生成词汇书

1. 输入一个英文单词并按回车，继续添加所需单词。
2. 长按调整顺序或选择排序方式，在“设置”中选好字号与例句数量，然后点击“开始生成”。
3. 在“生成记录”阅读、导出或分享 PDF，在“历史”查看所有生成过的单词。

```text
word list → dictionary + corpus + translation → bilingual layout → local PDF → history / export / share
```

## 数据来源与准确性

| 内容 | 来源 | 说明 |
| --- | --- | --- |
| 定义、音标、例句 | [Dictionary API](https://dictionaryapi.dev/) | 免费公开英文词典接口 |
| 相关词、词频信号 | [Datamuse](https://www.datamuse.com/api/) | 用于近义词补充、相对词频和难度估算 |
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
