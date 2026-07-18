const appVersion = '1.2.0';
const appBuildNumber = 13;

const releaseNotesZh = <String>[
  '修复 macOS 首次启动时侧边栏材质穿透引导页的显示问题。',
  '修复 macOS 更新时签名丢失沙盒身份、导致历史记录看似消失的问题，并新增本地恢复索引。',
  '桌面端侧边栏会随窗口宽度自动收窄，并新增左下角手动展开按钮与非线性过渡。',
  '新增 EPUB 与可编辑 DOCX 导出，保留 Lexora 的双语卡片样式与中英文字体。',
  '新增 EPUB/DOCX 内置阅读器，支持双指缩放、分享和用其他应用编辑。',
  '生成任务完成或失败后，可从生成记录顶部用叉号移除进度卡片。',
  '修复 Android 长时间后台闲置后可能留下停滞动画或弹窗遮罩、导致界面无法操作的问题。',
];

const releaseNotesEn = <String>[
  'Fixed the macOS first-launch sidebar material showing through onboarding.',
  'Preserved the macOS sandbox identity across updates and added a durable local history recovery index.',
  'Added responsive desktop sidebar compaction, a manual bottom-left toggle, and nonlinear transitions.',
  'Added EPUB and editable DOCX export with Lexora bilingual card styling and embedded multilingual fonts.',
  'Added in-app EPUB/DOCX readers with pinch zoom, sharing, and external editing.',
  'Completed or failed generation progress cards can now be dismissed with a close button.',
  'Fixed stale Android animations and modal barriers that could freeze the UI after a long idle period.',
];
