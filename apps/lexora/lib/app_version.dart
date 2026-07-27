const appVersion = '3.2.4';
const appBuildNumber = 23;

const releaseNotesZh = <String>[
  '联想输入时仅预取前三个候选的英文词典数据，并只预热首项释义翻译，避免翻译服务限流。',
  '翻译请求限制为两路并发，遇到限流会渐进重试；失败结果不再污染缓存。',
  '确认查询后保留已完成的翻译缓存，重复查看释义更快、更稳定。',
  'macOS 侧栏改为贴边原生半透明材质，选中态与收展动画更接近系统应用。',
  '词性在中英文界面中都同时显示中文说明。',
];

const releaseNotesEn = <String>[
  'Typing now prefetches English dictionary data for only the top three suggestions and warms just the first definition translation.',
  'Translation work is capped at two concurrent requests with progressive retries; failed responses are no longer cached.',
  'Completed translation cache survives a confirmed search for faster, more reliable repeat viewing.',
  'The macOS sidebar now uses a flush native translucent material with calmer selection and resizing motion.',
  'Parts of speech include Chinese labels in both interface languages.',
];
