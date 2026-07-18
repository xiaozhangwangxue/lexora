const appVersion = '1.1.3';
const appBuildNumber = 11;

const releaseNotesZh = <String>[
  '新增 DOC、DOCX、PDF、TXT 等文档批量导入，按换行快速加入大量单词或短语。',
  '将未找到、模糊匹配与生成完成信息合并为一个窗口，结果列表可滚动。',
  '增强精确搜索的容错与备用词典来源，避免常见单词因单个服务失败而被跳过。',
  'PDF 会突出显示模糊匹配后的正确单词，并以较小灰字保留原始输入。',
];

const releaseNotesEn = <String>[
  'Added newline-based bulk import from DOC, DOCX, PDF, TXT, and other document formats.',
  'Combined missing terms, fuzzy matches, and completion actions into one scrollable dialog.',
  'Improved exact-search resilience and dictionary fallback for common words.',
  'PDF exports now show the corrected term prominently and retain the original input in smaller gray text.',
];
