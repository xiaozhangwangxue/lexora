import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode.toLowerCase() == 'zh';

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String get words => isZh ? '单词' : 'Words';
  String get generationRecords => isZh ? '生成记录' : 'Generated';
  String get history => isZh ? '历史' : 'History';
  String get settings => isZh ? '设置' : 'Settings';
  String get tagline => isZh
      ? '输入单词或短语，生成精美的双语词汇书。'
      : 'Words and phrases in. A beautiful bilingual book out.';
  String get inputHint =>
      isZh ? '输入英文单词或短语后按回车' : 'Type an English word or phrase and press Enter';
  String get addWord => isZh ? '添加词条' : 'Add entry';
  String get importFile => isZh ? '导入文件' : 'Import files';
  String get importFileHint => isZh
      ? '每行一个词条 · DOC、DOCX、PDF、TXT 等'
      : 'One entry per line · DOC, DOCX, PDF, TXT and more';
  String get importingFile => isZh ? '正在读取文件…' : 'Reading files…';
  String importSummary(int added, int duplicates, int invalid) => isZh
      ? '已添加 $added 个词条；跳过 $duplicates 个重复项、$invalid 个无效行。'
      : 'Added $added entries; skipped $duplicates duplicates and $invalid invalid lines.';
  String importFailed(String error) =>
      isZh ? '导入失败：$error' : 'Import failed: $error';
  String get noImportableEntries => isZh
      ? '文件中没有找到可导入的英文单词或短语。请确保每行只有一个词条。'
      : 'No importable English words or phrases were found. Put one entry on each line.';
  String get generate => isZh ? '开始生成' : 'Start generating';
  String get generating => isZh ? '正在生成…' : 'Generating…';
  String get generationInProgress =>
      isZh ? '生成任务进行中' : 'Generation in progress';
  String get github => 'GitHub';
  String get openGitHubFailed =>
      isZh ? '无法打开 GitHub 页面。' : 'Could not open the GitHub page.';
  String get preparing => isZh ? '正在准备词汇书…' : 'Preparing your vocabulary book…';
  String lookup(String word, int current, int total) => isZh
      ? '已完成 $word  ·  $current/$total（并发查询）'
      : 'Completed $word  ·  $current/$total (parallel lookup)';
  String get typesetting =>
      isZh ? '正在排版双语词汇书…' : 'Typesetting the bilingual vocabulary book…';
  String get invalidWord =>
      isZh ? '请输入有效的英文单词或短语。' : 'Please enter a valid English word or phrase.';
  String duplicate(String word) =>
      isZh ? '“$word” 已在列表中。' : '“$word” is already in the list.';
  String wordCount(int count) =>
      isZh ? '$count 个单词' : '$count ${count == 1 ? 'word' : 'words'}';
  String termCount(int count) =>
      isZh ? '$count 个词条' : '$count ${count == 1 ? 'entry' : 'entries'}';
  String get sortWords => isZh ? '排序单词' : 'Sort words';
  String get customOrder => isZh ? '自定义顺序' : 'Custom order';
  String get alphabetical => isZh ? '字母顺序' : 'Alphabetical';
  String get wordLength => isZh ? '单词长度' : 'Word length';
  String get estimatedDifficulty => isZh ? '预估难度' : 'Estimated difficulty';
  String get custom => isZh ? '自定义' : 'Custom';
  String letters(int count) => isZh ? '$count 个字母' : '$count letters';
  String characters(int count) => isZh ? '$count 个字母' : '$count letters';
  String get phrase => isZh ? '短语' : 'Phrase';
  String get emptyTitle =>
      isZh ? '你的单词和短语将显示在这里' : 'Your words and phrases will appear here';
  String get emptyHint =>
      isZh ? '长按拖动排序 · 向左滑动删除' : 'Long-press to reorder · swipe left to delete';
  String get confirmGenerationTitle => isZh ? '开始生成词汇书？' : 'Start generating?';
  String confirmGenerationBody(int count) => isZh
      ? '将开始查询 $count 个词条，并把当前列表清空，方便你继续准备下一本词汇书。生成进度会显示在“生成记录”中。'
      : 'Lexora will look up $count entries and clear this list so you can prepare the next book. Progress will appear under Generated.';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get confirmGeneration => isZh ? '确认并开始' : 'Confirm and start';
  String get lookupProgressTitle => isZh ? '正在查询词条' : 'Looking up entries';
  String get typesettingHint => isZh
      ? '查询完成，正在整理短语并排版 PDF。'
      : 'Lookup is complete. Adding phrases and typesetting the PDF.';
  String get generationCompleted =>
      isZh ? '词汇书已完成' : 'Vocabulary book completed';
  String get generationCompletedHint =>
      isZh ? 'PDF 已保存，可在下方记录中打开。' : 'The PDF is saved and ready below.';
  String get generationFailed => isZh ? '生成未完成' : 'Generation did not finish';
  String get skippedItemsTitle =>
      isZh ? '部分词条未找到' : 'Some entries were not found';
  String get skippedItemsBody => isZh
      ? '以下词条已跳过，其余内容已继续生成。'
      : 'These entries were skipped. The remaining content was generated normally.';
  String get noItemsGenerated => isZh
      ? '所有词条都未找到，因此没有生成 PDF。'
      : 'No entries were found, so no PDF was created.';
  String get lookupResultsTitle => isZh ? '词条匹配结果' : 'Entry match results';
  String lookupResultsBody(bool hasFailures) => isZh
      ? (hasFailures
            ? '红色词条未找到并已跳过；黄色词条已采用严格筛选的相似匹配。'
            : '以下黄色词条未找到完全匹配，已采用严格筛选的相似匹配。')
      : (hasFailures
            ? 'Red entries were not found and were skipped. Yellow entries use a carefully checked similar match.'
            : 'The yellow entries had no exact match, so Lexora used a carefully checked similar match.');
  String fuzzyMatchedTerm(String term, String matchedTerm) =>
      isZh ? '$term（$matchedTerm）' : '$term ($matchedTerm)';
  String get lookupFailed => isZh ? '匹配失败' : 'Match failed';
  String get fuzzyMatched => isZh ? '模糊匹配' : 'Fuzzy matched';
  String generationError(String error) =>
      isZh ? '生成失败：$error' : 'Generation failed: $error';
  String get gotIt => isZh ? '知道了' : 'Got it';
  String get customize => isZh ? '自定义文档' : 'Customize document';
  String get pdfSettings => isZh ? '文档自定义' : 'Document customization';
  String get exportFormat => isZh ? '导出格式' : 'Export format';
  String get pageImages => isZh ? '分页图片' : 'Page images';
  String get longImage => isZh ? '长图' : 'Long image';
  String get smartReorder => isZh ? '智能调整顺序' : 'Smart reorder';
  String get smartReorderHint => isZh
      ? '只改变词条顺序，不修改任何内容。Lexora 会根据每个词条的长度智能分配位置，让长短内容互相补位，减少页面留白并节约纸张。'
      : 'Only the entry order changes; no content is edited. Lexora balances longer and shorter entries to reduce empty space and use less paper.';
  String get smartReorderHelp => isZh ? '了解智能排版' : 'About smart layout';
  String get paperSize => isZh ? '纸张尺寸' : 'Paper size';
  String get paperSizeHint => isZh
      ? 'Lexora 会根据纸张和字号自动选择一栏、两栏或三栏。'
      : 'Lexora automatically chooses one, two, or three columns for the paper and font sizes.';
  String get settingsIntroTitle => isZh
      ? '把零散单词，变成真正想读的词汇书。'
      : 'Turn loose words into a book worth reading.';
  String get settingsIntroBody => isZh
      ? 'Lexora 会联网补全难度、词频、英美音标、近反义词、双语例句与中文翻译，再排版成 PDF、EPUB、可编辑 DOCX、分页图片或长图。'
      : 'Lexora completes difficulty, frequency, phonetics, related words, bilingual examples, and Chinese translations, then typesets PDF, EPUB, editable DOCX, page images, or a long image.';
  String get pdfFontSize => isZh ? '文档字号' : 'Document font size';
  String get fontPreset => isZh ? '字号预设' : 'Font preset';
  String get fineTuneTypography => isZh ? '精细调整字体' : 'Fine-tune typography';
  String get fineTuneTypographyHint => isZh
      ? '分别调整各部分字号，数值会直接用于下一份词汇书。'
      : 'Adjust each section independently. These values apply to the next book.';
  String get scrollToAdjust => isZh
      ? '滚轮、双指或拖动内容继续调整'
      : 'Scroll, swipe, or drag the content to see every control';
  String get wordTitleFont => isZh ? '单词标题' : 'Word title';
  String get phoneticFont => isZh ? '英美音标' : 'Phonetics';
  String get definitionFont => isZh ? '中英文释义' : 'Definitions';
  String get relatedFont => isZh ? '近义词与反义词' : 'Related words';
  String get exampleFont => isZh ? '双语例句' : 'Examples';
  String get phraseFont => isZh ? '短语与涵义' : 'Phrases';
  String get typographyPreview => isZh ? '实时预览' : 'Live preview';
  String get saveChanges => isZh ? '保存调整' : 'Save changes';
  String get small => isZh ? '小' : 'Small';
  String get medium => isZh ? '中' : 'Medium';
  String get large => isZh ? '大' : 'Large';
  String get examples => isZh ? '例句' : 'Examples';
  String get noExamples => isZh ? '不添加' : 'None';
  String get oneExample => isZh ? '1 句' : '1 sentence';
  String get upToThreeExamples => isZh ? '2–3 句' : '2–3 sentences';
  String get historySubtitle => isZh
      ? '阅读、导出或分享已生成的词汇书。'
      : 'Read, export, or share your generated vocabulary books.';
  String get emptyHistory =>
      isZh ? '生成的词汇书将显示在这里。' : 'Your generated books will appear here.';
  String get wordHistorySubtitle => isZh
      ? '查看所有生成过的单词，并用星标将重要单词置顶。'
      : 'Browse every generated word and star important words to keep them on top.';
  String get emptyWordHistory =>
      isZh ? '生成过的单词将显示在这里。' : 'Words from generated books will appear here.';
  String get firstWords => isZh ? '前几个单词' : 'First words';
  String get noPreviewWords =>
      isZh ? '旧记录暂无单词预览' : 'No word preview for this older record';
  String get moreActions => isZh ? '更多操作' : 'More actions';
  String get exportTo => isZh ? '导出到…' : 'Export to…';
  String get share => isZh ? '分享…' : 'Share…';
  String get print => isZh ? '打印' : 'Print';
  String get openExternally => isZh ? '用其他应用打开' : 'Open in another app';
  String get readerContentUnavailable => isZh
      ? '这是旧版生成的文档，暂无内置阅读数据。可使用右上角在其他应用中打开。'
      : 'This older document has no in-app reading data. Open it in another app from the top-right button.';
  String get delete => isZh ? '删除' : 'Delete';
  String get vocabularyBook => isZh ? 'Lexora 词汇书' : 'Lexora vocabulary book';
  String get sortBy => isZh ? '排序方式' : 'Sort by';
  String get generationCount => isZh ? '生成次数' : 'Generation count';
  String get initialLetter => isZh ? '首字母' : 'Initial letter';
  String get generatedTime => isZh ? '生成时间' : 'Generated time';
  String get difficulty => isZh ? '单词难度' : 'Difficulty';
  String get ascending => isZh ? '正序' : 'Ascending';
  String get descending => isZh ? '倒序' : 'Descending';
  String generatedTimes(int count) => isZh
      ? '生成 $count 次'
      : 'Generated $count ${count == 1 ? 'time' : 'times'}';
  String get starWord => isZh ? '加上星标并置顶' : 'Star and pin word';
  String get unstarWord => isZh ? '取消星标' : 'Remove star';
  String get select => isZh ? '多选' : 'Select';
  String get finishSelecting => isZh ? '完成' : 'Done';
  String get selectAll => isZh ? '全选' : 'Select all';
  String get clearSelection => isZh ? '取消全选' : 'Clear selection';
  String selectedCount(int count) => isZh ? '已选择 $count 项' : '$count selected';
  String get shareSelected => isZh ? '批量分享' : 'Share selected';
  String get deleteSelected => isZh ? '批量删除' : 'Delete selected';
  String get regenerateSelected => isZh ? '重新生成' : 'Generate again';
  String get confirmDeleteTitle => isZh ? '删除所选内容？' : 'Delete selected items?';
  String confirmDeleteBody(int count) => isZh
      ? '将永久删除选中的 $count 项，此操作无法撤销。'
      : 'This permanently deletes $count selected items and cannot be undone.';
  String get confirmRegenerateTitle =>
      isZh ? '重新生成所选单词？' : 'Generate selected words again?';
  String confirmRegenerateBody(int count) => isZh
      ? '将使用当前 PDF 设置重新查询并生成 $count 个单词。'
      : 'Lexora will look up $count words again using the current PDF settings.';
  String get generationReadyBody => isZh
      ? '词汇书已保存。你可以继续整理下一批词条，也可以立即查看或分享。'
      : 'The vocabulary book is saved. Keep preparing another list, or view and share it now.';
  String get dismissProgress => isZh ? '移除已完成任务' : 'Dismiss completed task';
  String get stayHere => isZh ? '忽略' : 'Ignore';
  String get viewGenerated => isZh ? '打开' : 'Open';
  String get shareNow => isZh ? '分享' : 'Share';
  String get noFilesToShare => isZh
      ? '所选 PDF 文件不存在，无法分享。'
      : 'The selected PDF files could not be found.';
  String get generationAlreadyRunning =>
      isZh ? '已有生成任务正在进行。' : 'A generation task is already running.';
  String get quickLinks => isZh ? '快速链接' : 'Quick links';
  String get developerMode => isZh ? '开发者模式' : 'Developer mode';
  String get developerLogging =>
      isZh ? '详细诊断日志' : 'Detailed diagnostic logging';
  String get developerLoggingHint => isZh
      ? '启用后会低开销记录运行、生成、导出和错误信息，方便诊断问题。日志可能包含你输入的词条，请仅发送给信任的人。'
      : 'Records runtime, generation, export, and error details with low overhead. Logs may contain entered terms; share them only with people you trust.';
  String get exportLogs => isZh ? '导出完整日志文件' : 'Export full log file';
  String get exportLogsHint => isZh
      ? '生成可直接分享的 JSONL 诊断文件'
      : 'Create a shareable JSONL diagnostics file';
  String exportLogsFailed(String error) =>
      isZh ? '日志导出失败：$error' : 'Could not export logs: $error';
  String get deleteLogs => isZh ? '删除日志文件' : 'Delete log files';
  String get deleteLogsConfirm => isZh
      ? '确定删除 Lexora 已保存的全部诊断日志吗？'
      : 'Delete all diagnostic logs saved by Lexora?';
  String get logsDeleted => isZh ? '诊断日志已删除。' : 'Diagnostic logs deleted.';
  String get officialWebsite => isZh ? 'Lexora 官网' : 'Lexora website';
  String get officialWebsiteHint =>
      isZh ? '下载更新、查看安装说明' : 'Downloads, updates, and installation help';
  String get checkForUpdates => isZh ? '检查更新' : 'Check for updates';
  String get checkForUpdatesHint => isZh
      ? '从 Lexora 官网获取最新版本'
      : 'Check the Lexora website for a newer version';
  String get checkingForUpdates => isZh ? '正在检查更新…' : 'Checking for updates…';
  String get upToDate => isZh ? '已是最新版本' : 'You are up to date';
  String get upToDateBody => isZh
      ? '当前安装的 Lexora 已是最新版本。'
      : 'This Lexora installation is the latest version.';
  String updateAvailable(String version) =>
      isZh ? '发现 Lexora $version' : 'Lexora $version is available';
  String get downloadAndInstall => isZh ? '下载并安装' : 'Download and install';
  String get downloadingUpdate => isZh ? '正在下载安装包…' : 'Downloading installer…';
  String get launchingInstaller =>
      isZh ? '正在启动系统安装器…' : 'Opening the system installer…';
  String get macUpdateExitHint => isZh
      ? '下载并校验完成后，Lexora 会打开 DMG 与“隐私与安全”设置并自动退出。拖动安装后若被拦截，请在该页面选择“仍要打开”。'
      : 'After download and verification, Lexora opens the DMG and Privacy & Security, then quits automatically. If macOS blocks the updated app, choose Open Anyway there.';
  String updateFailed(String error) =>
      isZh ? '更新失败：$error' : 'Update failed: $error';
  String get retry => isZh ? '重试' : 'Retry';
  String get whatsNew => isZh ? '本次更新内容' : 'What’s new';
  String get continueLabel => isZh ? '继续使用' : 'Continue';
  String get openWebsiteFailed =>
      isZh ? '无法打开 Lexora 官网。' : 'Could not open the Lexora website.';
  String get donate => isZh ? '支持 Lexora' : 'Support Lexora';
  String get donateHint => isZh
      ? '捐款完全自愿，不会解锁付费功能。'
      : 'Donations are optional and never unlock paid features.';
  String get donationChannels => isZh ? '捐款渠道' : 'Donation channels';
  String get wechatPay => isZh ? '微信支付' : 'WeChat Pay';
  String get alipay => isZh ? '支付宝' : 'Alipay';
  String get close => isZh ? '关闭' : 'Close';
  String get notificationReadyTitle =>
      isZh ? '词汇书已生成' : 'Vocabulary book ready';
  String get onboardingSkip => isZh ? '跳过' : 'Skip';
  String get onboardingNext => isZh ? '下一步' : 'Next';
  String get onboardingStart => isZh ? '开始使用' : 'Get started';
  String get onboardingOneTitle =>
      isZh ? '输入，或一次导入整份词表' : 'Type, or import a whole word list';
  String get onboardingOneBody => isZh
      ? '输入单词或短语后按回车，也可以从 TXT、PDF、DOC、DOCX 等文件按行批量导入。长按排序，左滑删除。'
      : 'Press Enter after a word or phrase, or import line-separated entries from TXT, PDF, DOC, DOCX, and more. Long-press to reorder and swipe to delete.';
  String get onboardingTwoTitle =>
      isZh ? '准确补全，也能识别相近拼写' : 'Accurate lookup with careful fuzzy matching';
  String get onboardingTwoBody => isZh
      ? 'Lexora 会补全音标、词频、难度、例句、常用短语和中文翻译。拼写接近时会标明原词与匹配结果，不会悄悄替换。'
      : 'Lexora adds phonetics, frequency, difficulty, examples, phrases, and Chinese translations. Similar spellings are clearly marked instead of silently replaced.';
  String get onboardingThreeTitle =>
      isZh ? '让每本词汇书适合它的用途' : 'Shape every book for its purpose';
  String get onboardingThreeBody => isZh
      ? '选择 PDF、EPUB 或可编辑 DOCX，再选择 A4、A5 或 B5。Lexora 会根据纸张和字号自动排成一至三栏。'
      : 'Choose PDF, EPUB, or editable DOCX, then A4, A5, or B5. Lexora automatically uses one to three columns for the paper and typography.';
  String get onboardingFourTitle =>
      isZh ? '在生成记录中阅读，在历史中重用' : 'Read in Generated, reuse from History';
  String get onboardingFourBody => isZh
      ? '生成完成后可在应用内缩放阅读、分享或导出；历史会保存生成过的词条，方便星标、排序和再次生成。'
      : 'When ready, read with zoom, share, or export in the app. History keeps generated entries for starring, sorting, and generating again.';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'en', 'zh'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
