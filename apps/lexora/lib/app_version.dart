const appVersion = '3.2.5';
const appBuildNumber = 24;

const releaseNotesZh = <String>[
  '搜索提交后立即进入结果页，核心释义目标在 2 秒内呈现，其余内容继续在后台补全。',
  '新增 Cloudflare 边缘词典聚合，完整英文释义、音标、词性和关联内容会在第二阶段快速出现。',
  '中文翻译改为边缘批量请求；联想与近反义词、例句、短语独立补齐，不再串行阻塞搜索。',
  '搜索历史和结果中的关联词统一使用可拖拽浮层；上滑全屏、下滑关闭，系统返回可回到上一个词。',
  '开发者模式记录输入、导航、搜索、网络响应、耗时、生成和阅读器等完整诊断信息。',
];

const releaseNotesEn = <String>[
  'Search now enters the result immediately, targets the core definition within two seconds, and completes the rest in the background.',
  'Cloudflare edge aggregation brings in the complete English dictionary, pronunciation, parts of speech, and related content as a fast second stage.',
  'Chinese translation now uses edge batching while related words, examples, and phrases fill independently without serially blocking search.',
  'Search history and linked words now share a draggable sheet that expands, dismisses, and returns through linked results naturally.',
  'Developer mode captures detailed input, navigation, search, backend response, timing, generation, and reader diagnostics.',
];
