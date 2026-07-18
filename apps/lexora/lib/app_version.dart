const appVersion = '1.1.4';
const appBuildNumber = 12;

const releaseNotesZh = <String>[
  '修复安卓端更新说明中文乱码，并优化国内网络下的安装包下载线路。',
  '修复 macOS 应用内更新产生错误隔离标记、安装后无法打开的问题。',
  'macOS 打开安装包后会可靠退出旧版本，并打开“隐私与安全”设置。',
  '新增 DOC、DOCX、PDF、TXT 等文档批量导入，按换行快速加入大量单词或短语。',
  '将未找到、模糊匹配与生成完成信息合并为一个窗口，结果列表可滚动。',
  '增强精确搜索的容错与备用词典来源，避免常见单词因单个服务失败而被跳过。',
  'PDF 会突出显示模糊匹配后的正确单词，并以较小灰字保留原始输入。',
];

const releaseNotesEn = <String>[
  'Fixed garbled Chinese update notes and improved Android download routing.',
  'Fixed the invalid macOS quarantine flag that prevented in-app updates from opening.',
  'macOS now reliably exits the old app after opening the installer and Privacy & Security.',
  'Added newline-based bulk import from DOC, DOCX, PDF, TXT, and other document formats.',
  'Combined missing terms, fuzzy matches, and completion actions into one scrollable dialog.',
  'Improved exact-search resilience and dictionary fallback for common words.',
  'PDF exports now show the corrected term prominently and retain the original input in smaller gray text.',
];
