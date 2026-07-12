import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://lexora.12323456.xyz"),
  title: "Lexora — Words in. A beautiful bilingual book out.",
  description: "Organize English words and turn them into a polished bilingual PDF with difficulty, frequency, phonetics, related words, and examples.",
  icons: {
    icon: [{ url: "/favicon.png", type: "image/png", sizes: "192x192" }],
    apple: [{ url: "/lexora-icon-512.png", sizes: "512x512" }],
  },
  openGraph: {
    title: "Lexora — Make your words worth keeping.",
    description: "From a loose word list to a beautiful bilingual vocabulary book.",
    type: "website",
    locale: "en_US",
    alternateLocale: "zh_CN",
    images: ["/og.png"],
  },
  twitter: { card: "summary_large_image", images: ["/og.png"] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
