import type { Metadata } from "next";
import "@fontsource-variable/manrope/wght.css";
import "./globals.css";
import releaseManifest from "../public/version.json";

export const metadata: Metadata = {
  metadataBase: new URL("https://lexora.12323456.xyz"),
  title: "Lexora｜免费个人英语词汇书生成器与英汉词典",
  description: "批量导入英语单词和短语，自动补全英美音标、双语释义、词频、例句与近反义词，生成适合手机阅读和打印的 PDF、EPUB、DOCX 或长图词汇书。",
  applicationName: "Lexora",
  keywords: [
    "Lexora",
    "词汇书生成器",
    "英语词汇书",
    "个人词汇书",
    "单词表转PDF",
    "英汉词典",
    "vocabulary book generator",
    "word list to PDF",
  ],
  creator: "Lexora open-source project",
  publisher: "Lexora open-source project",
  alternates: { canonical: "/" },
  robots: { index: true, follow: true },
  openGraph: {
    title: "Lexora｜把零散单词变成个人英语词汇书",
    description: "免费的英汉词典与个人词汇书生成器，支持批量导入、PDF、EPUB、DOCX、分页图片和长图。",
    type: "website",
    locale: "zh_CN",
    alternateLocale: "en_US",
    url: "/",
    siteName: "Lexora",
    images: ["/og.png"],
  },
  twitter: { card: "summary_large_image", images: ["/og.png"] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const softwareApplication = {
    "@type": "SoftwareApplication",
    name: "Lexora",
    url: "https://lexora.12323456.xyz/",
    image: "https://lexora.12323456.xyz/lexora-icon-512.png",
    description: "免费的英汉词典与个人英语词汇书生成器，支持批量导入并导出 PDF、EPUB、DOCX、分页图片和长图。",
    applicationCategory: "EducationalApplication",
    operatingSystem: "Web, Android, macOS, Windows, Linux",
    softwareVersion: releaseManifest.version,
    offers: { "@type": "Offer", price: "0", priceCurrency: "CNY" },
    downloadUrl: "https://lexora.12323456.xyz/#download",
    installUrl: "https://lexora.12323456.xyz/app",
    inLanguage: ["zh-CN", "en"],
    isAccessibleForFree: true,
    sameAs: ["https://github.com/xiaozhangwangxue/lexora"],
    featureList: [
      "Bilingual English and Chinese dictionary",
      "Personal vocabulary book generator",
      "No-account web app",
      "PDF, EPUB, DOCX and image export",
      "Web, Android, macOS, Windows and Linux support",
    ],
  };
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      softwareApplication,
      {
        "@type": "WebSite",
        name: "Lexora",
        url: "https://lexora.12323456.xyz/",
        description: "Free bilingual dictionary and personal vocabulary book generator.",
        inLanguage: ["zh-CN", "en"],
      },
      {
        "@type": "SoftwareSourceCode",
        name: "Lexora source code",
        codeRepository: "https://github.com/xiaozhangwangxue/lexora",
        url: "https://github.com/xiaozhangwangxue/lexora",
        license: "https://github.com/xiaozhangwangxue/lexora/blob/main/LICENSE",
        programmingLanguage: ["Dart", "Swift", "TypeScript", "C++"],
        runtimePlatform: ["Android", "macOS", "Windows", "Linux"],
      },
    ],
  };
  return <html lang="zh-CN">
    <head>
      <link rel="icon" type="image/png" sizes="192x192" href="/favicon.png?v=5" />
      <link rel="apple-touch-icon" sizes="180x180" href="/lexora-apple-touch-icon-180.png?v=1" />
      <meta name="apple-mobile-web-app-capable" content="yes" />
      <meta name="apple-mobile-web-app-status-bar-style" content="default" />
      <meta name="apple-mobile-web-app-title" content="Lexora" />
      <meta name="theme-color" content="#f5f6fa" />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
    </head>
    <body>{children}</body>
  </html>;
}
