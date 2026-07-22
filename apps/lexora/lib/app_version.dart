const appVersion = '1.3.0-beta';
const appBuildNumber = 14;

const releaseNotesZh = <String>[
  '修复 Android 从历史或设置切换到生成记录时错误返回首页并唤起键盘的问题。',
  '桌面窗口过窄、侧栏无法展开时不再显示无效的展开按钮，并优化非线性过渡。',
  '新增 A4、A5、B5 纸张尺寸，PDF、DOCX 与 EPUB 会按纸张和字号自动选择一至三栏。',
  '小字号预设的单词标题调整为 12pt，所有精细字号最低可设为 6pt。',
  '修复 EPUB 中未定义空格实体导致部分第三方阅读器无法打开的问题。',
  '更新首次使用教程，加入批量导入、模糊匹配、多格式导出与历史重用说明。',
];

const releaseNotesEn = <String>[
  'Fixed Android opening Home and the keyboard when switching from History or Settings to Generated.',
  'Hidden the unavailable desktop sidebar toggle in narrow windows and refined its nonlinear transition.',
  'Added A4, A5, and B5 page sizes with automatic one-to-three-column layouts for PDF, DOCX, and EPUB.',
  'Set the Small preset word title to 12pt and lowered every fine typography control to 6pt.',
  'Fixed an undefined space entity that prevented some third-party EPUB readers from opening books.',
  'Updated onboarding for bulk import, fuzzy matching, multi-format export, and history reuse.',
];
