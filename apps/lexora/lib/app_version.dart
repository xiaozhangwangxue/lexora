const appVersion = '3.2.1';
const appBuildNumber = 20;

const releaseNotesZh = <String>[
  '修复 macOS 导出图片时因相册权限说明缺失而闪退的问题。',
  '快速调整桌面窗口宽度时暂停高成本毛玻璃和侧栏动画，松手后自动恢复，明显减少卡顿。',
  '搜索结果显示后自动隐藏 GitHub 按钮，避免遮挡内容。',
  '修复窄窗口下搜索结果挤压错位，并限制桌面窗口最小尺寸。',
  '重新居中 macOS 收起侧栏后的红绿灯按钮，并适当加宽收起状态。',
];

const releaseNotesEn = <String>[
  'Fixed a macOS crash when exporting images caused by missing Photos permission descriptions.',
  'Reduced desktop resize jank by pausing expensive glass effects and sidebar animation during live resizing, then restoring them afterward.',
  'The GitHub button now hides when a search result is shown so it cannot cover content.',
  'Fixed compressed search-result layouts and enforced a safe minimum desktop window size.',
  'Recentered macOS traffic-light controls in the wider collapsed sidebar.',
];
