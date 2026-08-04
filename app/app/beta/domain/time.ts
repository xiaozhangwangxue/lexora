export function localDateKey(value: Date | string = new Date()) {
  const date = typeof value === "string" ? new Date(value) : value;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function addMinutes(value: Date, minutes: number) {
  return new Date(value.getTime() + minutes * 60_000);
}

export function formatDueTime(iso: string, now = new Date()) {
  const due = new Date(iso);
  const difference = due.getTime() - now.getTime();
  if (difference <= 0) return "现在";
  const minutes = Math.ceil(difference / 60_000);
  if (minutes < 60) return `${minutes} 分钟后`;
  const hours = Math.ceil(minutes / 60);
  if (hours < 24) return `${hours} 小时后`;
  const days = Math.ceil(hours / 24);
  return `${days} 天后`;
}

export function formatInterval(minutes: number) {
  if (minutes < 60) return `${Math.round(minutes)} 分钟`;
  if (minutes < 24 * 60) return `${Math.round(minutes / 60)} 小时`;
  return `${Math.round(minutes / (24 * 60))} 天`;
}
