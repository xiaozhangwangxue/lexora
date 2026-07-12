import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode.toLowerCase() == 'zh';

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String get words => isZh ? '单词' : 'Words';
  String get history => isZh ? '历史' : 'History';
  String get tagline => isZh ? '输入单词，生成精美的双语词汇书。' : 'Words in. A beautiful bilingual book out.';
  String get inputHint => isZh ? '输入英文单词后按回车' : 'Type an English word and press Enter';
  String get addWord => isZh ? '添加单词' : 'Add word';
  String get generate => isZh ? '开始生成' : 'Start generating';
  String get generating => isZh ? '正在生成…' : 'Generating…';
  String get github => 'GitHub';
  String get openGitHubFailed => isZh ? '无法打开 GitHub 页面。' : 'Could not open the GitHub page.';
  String get preparing => isZh ? '正在准备词汇书…' : 'Preparing your vocabulary book…';
  String lookup(String word, int current, int total) => isZh
      ? '已完成 $word  ·  $current/$total（并发查询）'
      : 'Completed $word  ·  $current/$total (parallel lookup)';
  String get typesetting => isZh ? '正在排版双语 PDF…' : 'Typesetting the bilingual PDF…';
  String get invalidWord => isZh ? '请输入一个有效的英文单词。' : 'Please enter one English word.';
  String duplicate(String word) => isZh ? '“$word” 已在列表中。' : '“$word” is already in the list.';
  String wordCount(int count) => isZh ? '$count 个单词' : '$count ${count == 1 ? 'word' : 'words'}';
  String get sortWords => isZh ? '排序单词' : 'Sort words';
  String get customOrder => isZh ? '自定义顺序' : 'Custom order';
  String get alphabetical => isZh ? '字母顺序' : 'Alphabetical';
  String get wordLength => isZh ? '单词长度' : 'Word length';
  String get estimatedDifficulty => isZh ? '预估难度' : 'Estimated difficulty';
  String get custom => isZh ? '自定义' : 'Custom';
  String letters(int count) => isZh ? '$count 个字母' : '$count letters';
  String get emptyTitle => isZh ? '你的单词将显示在这里' : 'Your words will appear here';
  String get emptyHint => isZh ? '长按拖动排序 · 向左滑动删除' : 'Long-press to reorder · swipe left to delete';
  String get customize => isZh ? '自定义 PDF' : 'Customize PDF';
  String get pdfFontSize => isZh ? 'PDF 字号' : 'PDF font size';
  String get small => isZh ? '小' : 'Small';
  String get medium => isZh ? '中' : 'Medium';
  String get large => isZh ? '大' : 'Large';
  String get examples => isZh ? '例句' : 'Examples';
  String get noExamples => isZh ? '不添加' : 'None';
  String get oneExample => isZh ? '1 句' : '1 sentence';
  String get upToThreeExamples => isZh ? '2–3 句' : '2–3 sentences';
  String get historySubtitle => isZh ? '阅读、导出或分享已生成的词汇书。' : 'Read, export, or share your generated vocabulary books.';
  String get emptyHistory => isZh ? '生成的 PDF 将显示在这里。' : 'Your generated PDFs will appear here.';
  String get moreActions => isZh ? '更多操作' : 'More actions';
  String get exportTo => isZh ? '导出到…' : 'Export to…';
  String get share => isZh ? '分享…' : 'Share…';
  String get print => isZh ? '打印' : 'Print';
  String get delete => isZh ? '删除' : 'Delete';
  String get vocabularyBook => isZh ? 'Lexora 词汇书' : 'Lexora vocabulary book';
  String get onboardingSkip => isZh ? '跳过' : 'Skip';
  String get onboardingNext => isZh ? '下一步' : 'Next';
  String get onboardingStart => isZh ? '开始使用' : 'Get started';
  String get onboardingOneTitle => isZh ? '先收集你的单词' : 'Collect your words';
  String get onboardingOneBody => isZh ? '输入英文单词后按回车。长按可调整顺序，向左滑可删除。' : 'Type a word and press Enter. Long-press to reorder it, or swipe left to delete it.';
  String get onboardingTwoTitle => isZh ? '按你喜欢的方式生成' : 'Make the PDF yours';
  String get onboardingTwoBody => isZh ? '生成前可选择字号和例句数量，Lexora 会自动补全音标、词频、难度和中文翻译。' : 'Choose a font size and example count. Lexora adds phonetics, frequency, difficulty, and Chinese translations.';
  String get onboardingThreeTitle => isZh ? '随时阅读与分享' : 'Read and share anytime';
  String get onboardingThreeBody => isZh ? '完成后可在“历史”中直接阅读 PDF，也可导出或调用系统分享。' : 'Open finished PDFs from History, export them, or use your device’s share sheet.';
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
