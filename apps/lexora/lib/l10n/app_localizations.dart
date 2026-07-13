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
  String get tagline => isZh ? '输入单词或短语，生成精美的双语词汇书。' : 'Words and phrases in. A beautiful bilingual book out.';
  String get inputHint => isZh ? '输入英文单词或短语后按回车' : 'Type an English word or phrase and press Enter';
  String get addWord => isZh ? '添加词条' : 'Add entry';
  String get generate => isZh ? '开始生成' : 'Start generating';
  String get generating => isZh ? '正在生成…' : 'Generating…';
  String get generationInProgress => isZh ? '生成任务进行中' : 'Generation in progress';
  String get github => 'GitHub';
  String get openGitHubFailed => isZh ? '无法打开 GitHub 页面。' : 'Could not open the GitHub page.';
  String get preparing => isZh ? '正在准备词汇书…' : 'Preparing your vocabulary book…';
  String lookup(String word, int current, int total) => isZh
      ? '已完成 $word  ·  $current/$total（并发查询）'
      : 'Completed $word  ·  $current/$total (parallel lookup)';
  String get typesetting => isZh ? '正在排版双语 PDF…' : 'Typesetting the bilingual PDF…';
  String get invalidWord => isZh ? '请输入有效的英文单词或短语。' : 'Please enter a valid English word or phrase.';
  String duplicate(String word) => isZh ? '“$word” 已在列表中。' : '“$word” is already in the list.';
  String wordCount(int count) => isZh ? '$count 个单词' : '$count ${count == 1 ? 'word' : 'words'}';
  String termCount(int count) => isZh ? '$count 个词条' : '$count ${count == 1 ? 'entry' : 'entries'}';
  String get sortWords => isZh ? '排序单词' : 'Sort words';
  String get customOrder => isZh ? '自定义顺序' : 'Custom order';
  String get alphabetical => isZh ? '字母顺序' : 'Alphabetical';
  String get wordLength => isZh ? '单词长度' : 'Word length';
  String get estimatedDifficulty => isZh ? '预估难度' : 'Estimated difficulty';
  String get custom => isZh ? '自定义' : 'Custom';
  String letters(int count) => isZh ? '$count 个字母' : '$count letters';
  String characters(int count) => isZh ? '$count 个字母' : '$count letters';
  String get phrase => isZh ? '短语' : 'Phrase';
  String get emptyTitle => isZh ? '你的单词和短语将显示在这里' : 'Your words and phrases will appear here';
  String get emptyHint => isZh ? '长按拖动排序 · 向左滑动删除' : 'Long-press to reorder · swipe left to delete';
  String get confirmGenerationTitle => isZh ? '开始生成词汇书？' : 'Start generating?';
  String confirmGenerationBody(int count) => isZh
      ? '将开始查询 $count 个词条，并把当前列表清空，方便你继续准备下一本词汇书。生成进度会显示在“生成记录”中。'
      : 'Lexora will look up $count entries and clear this list so you can prepare the next book. Progress will appear under Generated.';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get confirmGeneration => isZh ? '确认并开始' : 'Confirm and start';
  String get lookupProgressTitle => isZh ? '正在查询词条' : 'Looking up entries';
  String get typesettingHint => isZh ? '查询完成，正在整理短语并排版 PDF。' : 'Lookup is complete. Adding phrases and typesetting the PDF.';
  String get generationCompleted => isZh ? '词汇书已完成' : 'Vocabulary book completed';
  String get generationCompletedHint => isZh ? 'PDF 已保存，可在下方记录中打开。' : 'The PDF is saved and ready below.';
  String get generationFailed => isZh ? '生成未完成' : 'Generation did not finish';
  String get skippedItemsTitle => isZh ? '部分词条未找到' : 'Some entries were not found';
  String get skippedItemsBody => isZh ? '以下词条已跳过，其余内容已继续生成。' : 'These entries were skipped. The remaining content was generated normally.';
  String get noItemsGenerated => isZh ? '所有词条都未找到，因此没有生成 PDF。' : 'No entries were found, so no PDF was created.';
  String generationError(String error) => isZh ? '生成失败：$error' : 'Generation failed: $error';
  String get gotIt => isZh ? '知道了' : 'Got it';
  String get customize => isZh ? '自定义 PDF' : 'Customize PDF';
  String get pdfSettings => isZh ? 'PDF 自定义' : 'PDF customization';
  String get settingsIntroTitle => isZh ? '把零散单词，变成真正想读的词汇书。' : 'Turn loose words into a book worth reading.';
  String get settingsIntroBody => isZh
      ? 'Lexora 会联网补全难度、词频、英美音标、近反义词、双语例句与中文翻译，再排版成适合手机阅读和打印的 PDF。'
      : 'Lexora completes difficulty, frequency, US and UK phonetics, related words, bilingual examples, and Chinese translations, then typesets a PDF made for phones and print.';
  String get pdfFontSize => isZh ? 'PDF 字号' : 'PDF font size';
  String get fontPreset => isZh ? '字号预设' : 'Font preset';
  String get fineTuneTypography => isZh ? '精细调整字体' : 'Fine-tune typography';
  String get fineTuneTypographyHint => isZh
      ? '分别调整各部分字号，数值会直接用于下一份 PDF。'
      : 'Adjust each section independently. These values apply to the next PDF.';
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
  String get historySubtitle => isZh ? '阅读、导出或分享已生成的词汇书。' : 'Read, export, or share your generated vocabulary books.';
  String get emptyHistory => isZh ? '生成的 PDF 将显示在这里。' : 'Your generated PDFs will appear here.';
  String get wordHistorySubtitle => isZh ? '查看所有生成过的单词，并用星标将重要单词置顶。' : 'Browse every generated word and star important words to keep them on top.';
  String get emptyWordHistory => isZh ? '生成过的单词将显示在这里。' : 'Words from generated books will appear here.';
  String get firstWords => isZh ? '前几个单词' : 'First words';
  String get noPreviewWords => isZh ? '旧记录暂无单词预览' : 'No word preview for this older record';
  String get moreActions => isZh ? '更多操作' : 'More actions';
  String get exportTo => isZh ? '导出到…' : 'Export to…';
  String get share => isZh ? '分享…' : 'Share…';
  String get print => isZh ? '打印' : 'Print';
  String get delete => isZh ? '删除' : 'Delete';
  String get vocabularyBook => isZh ? 'Lexora 词汇书' : 'Lexora vocabulary book';
  String get sortBy => isZh ? '排序方式' : 'Sort by';
  String get generationCount => isZh ? '生成次数' : 'Generation count';
  String get initialLetter => isZh ? '首字母' : 'Initial letter';
  String get generatedTime => isZh ? '生成时间' : 'Generated time';
  String get difficulty => isZh ? '单词难度' : 'Difficulty';
  String get ascending => isZh ? '正序' : 'Ascending';
  String get descending => isZh ? '倒序' : 'Descending';
  String generatedTimes(int count) => isZh ? '生成 $count 次' : 'Generated $count ${count == 1 ? 'time' : 'times'}';
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
  String get confirmRegenerateTitle => isZh ? '重新生成所选单词？' : 'Generate selected words again?';
  String confirmRegenerateBody(int count) => isZh
      ? '将使用当前 PDF 设置重新查询并生成 $count 个单词。'
      : 'Lexora will look up $count words again using the current PDF settings.';
  String get generationReadyBody => isZh
      ? 'PDF 已保存。你可以继续整理下一批词条，也可以立即查看或分享。'
      : 'The PDF is saved. Keep preparing another list, or view and share it now.';
  String get stayHere => isZh ? '留在此页' : 'Stay here';
  String get viewGenerated => isZh ? '前往生成记录' : 'View generated';
  String get shareNow => isZh ? '分享' : 'Share';
  String get noFilesToShare => isZh ? '所选 PDF 文件不存在，无法分享。' : 'The selected PDF files could not be found.';
  String get generationAlreadyRunning => isZh ? '已有生成任务正在进行。' : 'A generation task is already running.';
  String get quickLinks => isZh ? '快速链接' : 'Quick links';
  String get officialWebsite => isZh ? 'Lexora 官网' : 'Lexora website';
  String get officialWebsiteHint => isZh ? '下载更新、查看安装说明' : 'Downloads, updates, and installation help';
  String get openWebsiteFailed => isZh ? '无法打开 Lexora 官网。' : 'Could not open the Lexora website.';
  String get donate => isZh ? '支持 Lexora' : 'Support Lexora';
  String get donateHint => isZh ? '捐款完全自愿，不会解锁付费功能。' : 'Donations are optional and never unlock paid features.';
  String get donationChannels => isZh ? '捐款渠道' : 'Donation channels';
  String get wechatPay => isZh ? '微信支付' : 'WeChat Pay';
  String get alipay => isZh ? '支付宝' : 'Alipay';
  String get close => isZh ? '关闭' : 'Close';
  String get notificationReadyTitle => isZh ? '词汇书已生成' : 'Vocabulary book ready';
  String get onboardingSkip => isZh ? '跳过' : 'Skip';
  String get onboardingNext => isZh ? '下一步' : 'Next';
  String get onboardingStart => isZh ? '开始使用' : 'Get started';
  String get onboardingOneTitle => isZh ? '先收集单词和短语' : 'Collect words and phrases';
  String get onboardingOneBody => isZh ? '输入英文单词或短语后按回车。长按可调整顺序，向左滑可删除。' : 'Type a word or phrase and press Enter. Long-press to reorder it, or swipe left to delete it.';
  String get onboardingTwoTitle => isZh ? '按你喜欢的方式生成' : 'Make the PDF yours';
  String get onboardingTwoBody => isZh ? '在“设置”中选择字号和例句数量，Lexora 会自动补全音标、词频、难度、常用短语和中文翻译。' : 'Choose font size and example count in Settings. Lexora adds phonetics, frequency, difficulty, useful phrases, and Chinese translations.';
  String get onboardingThreeTitle => isZh ? '随时阅读与分享' : 'Read and share anytime';
  String get onboardingThreeBody => isZh ? '完成后可在“生成记录”中阅读 PDF，也可导出或调用系统分享。' : 'Open finished PDFs from Generated, export them, or use your device’s share sheet.';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => const {'en', 'zh'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
