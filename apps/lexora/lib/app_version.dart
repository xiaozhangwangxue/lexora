const appVersion = '3.0.0';
const appBuildNumber = 15;

const releaseNotesZh = <String>[
  '新增分页图片与长图导出：分页图片会保存到系统相册，所有图片都可在生成记录中阅读、缩放和分享。',
  '重做 EPUB 流式排版并嵌入中英文字体，修复第三方阅读器中标题挤压、居中错乱和异常断词。',
  '新增“智能调整顺序”，根据词条长度平衡各栏内容，进一步减少页面留白和纸张浪费。',
  '导出文件名精确到秒，同一分钟连续生成多份词汇书也不会互相覆盖。',
  '关闭首页文档自定义窗口后不再自动弹出键盘。',
  'macOS 改用 SwiftUI 原生导航壳层，并在 macOS 26 及以上使用系统 Liquid Glass 效果。',
  'macOS 文档自定义改为原生液态玻璃窗口；Android、Windows 与 Linux 同步减少弹窗重绘，滑块拖动更流畅。',
  '官网更新为更清晰的一次性动效与五种导出介绍，并精简为单一捐赠区域。',
];

const releaseNotesEn = <String>[
  'Added page-image and long-image export. Page images are saved to Photos, and every image opens, zooms, and shares from Generated.',
  'Rebuilt EPUB with conservative reflow and embedded Chinese and Latin fonts to prevent crushed headings, forced centering, and broken hyphenation in third-party readers.',
  'Added Smart reorder to balance entry lengths across columns and reduce empty space and paper use.',
  'Export filenames now include seconds, preventing books created in the same minute from overwriting each other.',
  'Closing document customization on Home no longer reopens the keyboard.',
  'Moved macOS navigation into a native SwiftUI shell with system Liquid Glass on macOS 26 and newer.',
  'Moved macOS document customization into a native Liquid Glass sheet and reduced dialog repaint work on Android, Windows, and Linux for smoother slider dragging.',
  'Refined the website with purposeful one-shot motion, five-format copy, and one concise donation section.',
];
