import type { Metadata } from "next";
import "@fontsource-variable/manrope/wght.css";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://lexora.12323456.xyz"),
  title: "Lexora — Words in. A beautiful bilingual book out.",
  description: "Import and organize English words, then create a compact bilingual PDF, EPUB, editable DOCX, page images, or a long image with smart layout.",
  openGraph: {
    title: "Lexora — Make your words worth keeping.",
    description: "From a loose word list to five polished bilingual formats with smart compact layout.",
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
