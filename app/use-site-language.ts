"use client";

import { useEffect, useState } from "react";

export type SiteLanguage = "en" | "zh";

const storageKey = "lexora.site.language";

export function useSiteLanguage() {
  // Chinese is the stable server-rendered default for Lexora's primary audience.
  const [language, setLanguageState] = useState<SiteLanguage>("zh");

  useEffect(() => {
    const saved = window.localStorage.getItem(storageKey);
    const detected = window.navigator.languages.some((item) =>
      item.toLowerCase().startsWith("zh"),
    ) ? "zh" : "en";
    const next = saved === "zh" || saved === "en" ? saved : detected;
    document.documentElement.lang = next === "zh" ? "zh-CN" : "en";
    // Defer the client-only preference until hydration has completed so the
    // stable Chinese server render never conflicts with the first client tree.
    queueMicrotask(() => setLanguageState(next));
  }, []);

  function setLanguage(next: SiteLanguage) {
    setLanguageState(next);
    window.localStorage.setItem(storageKey, next);
    document.documentElement.lang = next === "zh" ? "zh-CN" : "en";
  }

  return { language, setLanguage, zh: language === "zh" };
}
