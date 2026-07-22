const appVersion = '3.0.1';
const appBuildNumber = 16;

const releaseNotesZh = <String>[
  '修复 macOS 应用内更新在安装包下载完成后无法准备和打开 DMG 的问题。',
  '分页图片与长图阅读器改用专用多点手势引擎，恢复双指缩放并避免缩放时误翻页。',
  '优化图片、EPUB 和 DOCX 阅读器的后台解析与返回过渡，快速返回不再拖慢动画或造成卡顿。',
  '智能调整顺序升级为按页面和栏位最佳填充，短词条会补入当前页剩余空间，进一步减少留白。',
  '设置中新增低开销开发者模式，可导出或删除包含完整错误堆栈的详细诊断日志。',
  'Android 设置标题旁新增当前版本号，便于确认安装版本。',
];

const releaseNotesEn = <String>[
  'Fixed macOS in-app updates failing to prepare and open the DMG after a successful download.',
  'Moved page-image and long-image reading to a dedicated multi-touch engine, restoring pinch zoom without accidental page changes.',
  'Moved reader parsing off the UI thread and shortened reverse transitions so quickly closing images, EPUB, or DOCX stays smooth.',
  'Upgraded Smart reorder with page-and-column best-fit packing so short entries fill remaining page space.',
  'Added an opt-in low-overhead Developer mode with full diagnostic log export and deletion.',
  'Added the installed version beside the Android Settings title.',
];
