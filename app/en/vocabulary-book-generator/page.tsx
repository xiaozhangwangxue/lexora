import type { Metadata } from "next";
import { GuideShell } from "../../guides/guide-shell";

export const metadata: Metadata = {
  title: "Free Vocabulary Book Generator for PDF, EPUB and DOCX | Lexora",
  description: "Import English words and phrases, add bilingual definitions, IPA, examples and frequency, then export a personal vocabulary book as PDF, EPUB, editable DOCX, images or one long image.",
  alternates: {
    canonical: "/en/vocabulary-book-generator",
    languages: {
      "zh-CN": "/vocabulary-book-generator",
      en: "/en/vocabulary-book-generator",
    },
  },
  openGraph: {
    title: "Lexora — Free personal vocabulary book generator",
    description: "Turn your own English word list into a bilingual vocabulary book for reading or print.",
    url: "/en/vocabulary-book-generator",
    type: "article",
  },
};

const questions = [
  ["What is Lexora?", "Lexora is a free bilingual dictionary and personal vocabulary book generator for Android, macOS, Windows, and Linux."],
  ["Can it turn a word list into a PDF?", "Yes. Lexora enriches imported words with IPA, bilingual definitions, examples, frequency, and related words before creating a phone-friendly or printable PDF."],
  ["Which formats are supported?", "You can export PDF, EPUB, editable DOCX, page images, or one long image in A4, A5, or B5 layouts."],
  ["Is Lexora open source?", "Yes. Lexora is free to use and its source code, releases, and issue history are public on GitHub."],
];

export default function EnglishVocabularyBookGeneratorPage() {
  const faq = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: questions.map(([name, text]) => ({
      "@type": "Question",
      name,
      acceptedAnswer: { "@type": "Answer", text },
    })),
  };
  return (
    <GuideShell language="en" eyebrow="Lexora vocabulary book generator" title="A free personal vocabulary book generator" intro="Import the English words and phrases you actually encounter, enrich them with reliable dictionary details, and export a compact bilingual book for reading, review, or print.">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faq) }} />
      <h2>From a word list to a complete vocabulary book</h2>
      <p>Lexora adds US and UK pronunciation, parts of speech, English and Chinese definitions, frequency, synonyms, antonyms, examples, and collocations before laying out your words.</p>
      <ol>
        <li><strong>Collect:</strong> type words one by one or import TXT, PDF, DOC, and DOCX files.</li>
        <li><strong>Organize:</strong> drag to reorder, remove entries, or sort by alphabet, length, and difficulty.</li>
        <li><strong>Generate:</strong> choose typography, examples, paper size, and output format.</li>
        <li><strong>Review:</strong> read inside Lexora or export to a phone, computer, printer, or e-reader.</li>
      </ol>
      <h2>Common questions</h2>
      {questions.map(([question, answer]) => <section key={question}><h3>{question}</h3><p>{answer}</p></section>)}
      <p>Visit the <a href="https://github.com/xiaozhangwangxue/lexora">Lexora open-source repository on GitHub</a> to inspect the source, releases, and project history.</p>
    </GuideShell>
  );
}
