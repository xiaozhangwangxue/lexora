import type { Metadata } from "next";
import "@fontsource-variable/manrope/wght.css";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://lexora.12323456.xyz"),
  title: "Lexora — The dictionary that builds your vocabulary book.",
  description: "Search bilingual definitions, examples, collocations, and related words, save what matters, then create your personal PDF, EPUB, DOCX, page images, or long image.",
  openGraph: {
    title: "Lexora — Every lookup builds your vocabulary book.",
    description: "A bilingual dictionary with live suggestions, one-tap saving, and five polished personal vocabulary-book formats.",
    type: "website",
    locale: "en_US",
    alternateLocale: "zh_CN",
    images: ["/og.png"],
  },
  twitter: { card: "summary_large_image", images: ["/og.png"] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN">
    <head>
      <link rel="icon" type="image/png" sizes="192x192" href="/favicon.png?v=5" />
      <link rel="apple-touch-icon" sizes="512x512" href="/lexora-icon-512.png?v=5" />
    </head>
    <body>{children}</body>
  </html>;
}
