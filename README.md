# Lexora

[English](README.en.md) · 简体中文

> 输入单词，得到一本值得阅读的双语词汇书。

Lexora 是一款面向 Android、macOS、Windows 与 Linux 的开源英语单词整理软件。它把零散的单词列表补全为包含难度、词频、英美音标、近义词、反义词、例句与中文翻译的紧凑 PDF，并保存在可直接阅读、导出与分享的历史记录中。

![Lexora 图标](public/lexora-icon-192.png)

## 功能

- 在类似搜索引擎的简洁主页中输入单词，按回车添加。
- 长按拖动调整顺序，向左滑动删除。
- 支持自定义顺序、字母顺序、长度和估算难度排序。
- 联网获取定义、词频、难度、英美音标、近反义词与例句。
- 自动补充中文释义和例句翻译。
- 生成适合屏幕阅读与打印的双语 PDF。
- 在历史页面直接打开 PDF；桌面端可导出或分享，Android 调用系统分享面板。
- 根据平台自适应导航、控件密度、窗口布局和交互反馈。

## 项目结构

```text
apps/lexora/       Flutter 跨平台客户端
app/               Lexora 官网（React / vinext）
worker/            Cloudflare Worker 与 R2 下载代理
.github/workflows/ 四平台构建、GitHub Release 与 R2 镜像
docs/              架构、数据来源与隐私说明
```

## 本地运行客户端

需要 Flutter stable 与对应平台的工具链。

```bash
cd apps/lexora
flutter create --project-name lexora --platforms=android,linux,macos,windows .
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## 本地运行官网

需要 Node.js 22 或更新版本。

```bash
npm install
npm run dev
```

## 数据说明

当前版本从 Dictionary API 获取词典内容，从 Datamuse 获取相关词与公开语料词频信号，并通过 MyMemory 提供中译。PDF 字体由 `printing` 包按需缓存。第三方服务可能限流或暂时不可用；Lexora 会显示明确错误，不会伪造词典结果。完整说明见 [docs/DATA_SOURCES.zh-CN.md](docs/DATA_SOURCES.zh-CN.md)。

## 发布

推送 `v*` 标签会触发 GitHub Actions，分别在 Android、Linux、Windows 与 macOS 原生环境中构建并发布文件。配置 `CLOUDFLARE_API_TOKEN`、`CLOUDFLARE_ACCOUNT_ID` 与 `CLOUDFLARE_R2_BUCKET` 后，Release 文件会同步到 R2，并由官网 `/downloads/*` 下载入口提供服务。

## 许可证

[MIT](LICENSE)
