import type { BetaSettings, Word } from "../domain/types";

let activeAudio: HTMLAudioElement | null = null;

export function stopSpeech() {
  activeAudio?.pause();
  activeAudio = null;
  if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
}

export async function speakText(text: string, settings: BetaSettings, locale?: string) {
  stopSpeech();
  if (typeof speechSynthesis === "undefined") throw new Error("当前浏览器无法朗读");
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = locale ?? (settings.preferredAccent === "uk" ? "en-GB" : "en-US");
  utterance.rate = settings.speechRate;
  await new Promise<void>((resolve, reject) => {
    utterance.onend = () => resolve();
    utterance.onerror = () => reject(new Error("朗读失败，请稍后重试"));
    speechSynthesis.speak(utterance);
  });
}

export async function playWord(word: Word, settings: BetaSettings, accent = settings.preferredAccent) {
  stopSpeech();
  const primary = accent === "uk" ? word.audioUK : word.audioUS;
  const secondary = accent === "uk" ? word.audioUS : word.audioUK;
  const source = primary || secondary;
  if (!source) return speakText(word.text, settings, accent === "uk" ? "en-GB" : "en-US");
  activeAudio = new Audio(source);
  activeAudio.playbackRate = settings.speechRate;
  try {
    await activeAudio.play();
  } catch {
    return speakText(word.text, settings, accent === "uk" ? "en-GB" : "en-US");
  }
}
