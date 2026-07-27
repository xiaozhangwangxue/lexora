const appVersion = '3.2.3';
const appBuildNumber = 22;

const releaseNotesZh = <String>[
  '输入时并发预取全部联想词结果，确认查询后只保留当前词条缓存。',
  '修复部分词条显示原始音标编码的问题，音标统一转换为可读 IPA。',
  '结果文字支持选择复制，关联词可双击打开可拖拽的快速预览。',
  '双击桌面侧栏“单词”可返回搜索主页，联想出现时立即隐藏 GitHub 按钮。',
  '词性增加中文说明，历史页顶栏和搜索历史列表使用统一布局。',
  '调整设置页中搜索字体与开发者模式的位置。',
];

const releaseNotesEn = <String>[
  'All visible suggestions now prefetch concurrently; only the chosen result remains cached after search.',
  'Fixed raw pronunciation codes by converting fallback phonetics into readable IPA.',
  'Result text is selectable, and related words open in a draggable preview on double-click.',
  'Double-click Words in the desktop sidebar to return home; GitHub hides as suggestions appear.',
  'Parts of speech include Chinese labels, with a unified history header and list layout.',
  'Reordered search text and developer settings for a clearer settings flow.',
];
