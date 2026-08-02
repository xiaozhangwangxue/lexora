import type { Metadata } from "next";
import "@fontsource-variable/manrope/wght.css";
import "./globals.css";
import releaseManifest from "../public/version.json";

export const metadata: Metadata = {
  metadataBase: new URL("https://lexora.12323456.xyz"),
  title: "Lexora｜免费个人英语词汇书生成器与英汉词典",
  description: "批量导入英语单词和短语，自动补全英美音标、双语释义、词频、例句与近反义词，生成适合手机阅读和打印的 PDF、EPUB、DOCX 或长图词汇书。",
  applicationName: "Lexora",
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
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Lexora",
    url: "https://lexora.12323456.xyz/",
    image: "https://lexora.12323456.xyz/lexora-icon-512.png",
    description: "免费的英汉词典与个人英语词汇书生成器，支持批量导入并导出 PDF、EPUB、DOCX、分页图片和长图。",
    applicationCategory: "EducationalApplication",
    operatingSystem: "Android, macOS, Windows, Linux",
    softwareVersion: releaseManifest.version,
    offers: { "@type": "Offer", price: "0", priceCurrency: "CNY" },
    downloadUrl: "https://lexora.12323456.xyz/#download",
    inLanguage: ["zh-CN", "en"],
    isAccessibleForFree: true,
  };
  return <html lang="zh-CN">
    <head>
      <link rel="icon" type="image/png" sizes="192x192" href="/favicon.png?v=5" />
      <link rel="apple-touch-icon" sizes="512x512" href="/lexora-icon-512.png?v=5" />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareApplication) }}
      />
    </head>
    <body>{children}</body>
  </html>;
}
