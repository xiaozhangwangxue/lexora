const appVersion = '3.1.0';
const appBuildNumber = 18;

const releaseNotesZh = <String>[
  '恢复经过验证的稳定智能排版逻辑，避免新版自动排序导致栏位更加凌乱。',
  '优化 PDF 阅读器的缓存、阴影绘制和打开动画，滚动与缩放更加流畅。',
  '减少 Android 页面切换时的实时模糊和相邻页面预渲染，降低闪烁与掉帧。',
  '优化单词拖拽、桌面侧栏动画和大批量生成日志，长列表操作更轻快。',
  '修复 macOS 应用内更新因沙盒无法改写 DMG 隔离属性而中断的问题。',
  'macOS 收起侧栏时应用图标改为严格居中，并放大为原来的两倍。',
];

const releaseNotesEn = <String>[
  'Restored the proven stable Smart reorder layout to avoid the uneven results introduced by the newer packing algorithm.',
  'Optimized PDF cache, page painting, and opening transitions for smoother scrolling and zooming.',
  'Reduced live blur and adjacent-page prerendering during Android navigation to prevent flashes and dropped frames.',
  'Optimized word dragging, desktop sidebar motion, and large-batch diagnostic logging.',
  'Fixed macOS in-app updates stopping when the sandbox cannot rewrite the DMG quarantine attribute.',
  'Centered the macOS app icon in the collapsed sidebar and doubled its size.',
];
