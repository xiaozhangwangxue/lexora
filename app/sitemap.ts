import type { MetadataRoute } from "next";

const base = "https://lexora.12323456.xyz";

export default function sitemap(): MetadataRoute.Sitemap {
  const routes = [
    { path: "", priority: 1, changeFrequency: "weekly" as const },
    { path: "/app", priority: 0.95, changeFrequency: "weekly" as const },
    { path: "/guides", priority: 0.9, changeFrequency: "monthly" as const },
    { path: "/guides/personal-vocabulary-book", priority: 0.8, changeFrequency: "monthly" as const },
    { path: "/guides/import-word-list", priority: 0.8, changeFrequency: "monthly" as const },
    { path: "/guides/word-to-pdf", priority: 0.8, changeFrequency: "monthly" as const },
    { path: "/vocabulary-book-generator", priority: 0.95, changeFrequency: "monthly" as const },
    { path: "/en/vocabulary-book-generator", priority: 0.9, changeFrequency: "monthly" as const },
    { path: "/donate", priority: 0.3, changeFrequency: "yearly" as const },
  ];
  return routes.map(({ path, ...entry }) => ({
    url: `${base}${path}`,
    lastModified: new Date("2026-08-03"),
    ...entry,
  }));
}
