const appVersion = '1.1.2';
const appBuildNumber = 10;

const releaseNotesZh = <String>[
  '优化官网 Lexora 文字标的首帧与入场动画，并加入品牌音标。',
  '统一软件首页与官网首页的 Lexora 文字标样式。',
  '修复 Android 在键盘展开时返回桌面、再次进入后仍错误预留键盘空间的问题。',
  '应用内更新改用 Cloudflare R2 直连与 GitHub 备用源，改善中国大陆下载稳定性。',
  '下载过程增加断流检测、文件格式、大小与 SHA-256 完整性校验，避免安装不完整文件。',
  'macOS 更新会在校验后打开 DMG 与“隐私与安全”设置并自动退出；Android 更新继续使用相同签名覆盖安装。',
];

const releaseNotesEn = <String>[
  'Refined the website wordmark’s first frame and entrance motion, and added the brand pronunciation.',
  'Matched the app home wordmark precisely to the website hero.',
  'Fixed the stale Android keyboard inset that could leave a large blank area after returning from the launcher.',
  'Moved in-app updates to a Cloudflare R2 primary mirror with GitHub fallback for better regional reliability.',
  'Added interrupted-download, container, size, and SHA-256 integrity checks before installers can open.',
  'macOS now opens the verified DMG and Privacy & Security before quitting; Android keeps stable-signature in-place updates.',
];
