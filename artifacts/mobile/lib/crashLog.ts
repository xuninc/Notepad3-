import AsyncStorage from "@react-native-async-storage/async-storage";

const KEY = "notepad3pp.lastCrash";

export type CrashRecord = {
  message: string;
  stack: string;
  componentStack: string;
  section: string | null;
  at: number;
};

export async function recordCrash(error: Error, componentStack: string, section?: string | null): Promise<void> {
  const record: CrashRecord = {
    message: error?.message ?? String(error),
    stack: typeof error?.stack === "string" ? error.stack.split("\n").slice(0, 12).join("\n") : "",
    componentStack: componentStack.split("\n").slice(0, 12).join("\n"),
    section: section ?? null,
    at: Date.now(),
  };
  try {
    await AsyncStorage.setItem(KEY, JSON.stringify(record));
  } catch {
    // ignore — crash logging is best-effort
  }
}

export async function readLastCrash(): Promise<CrashRecord | null> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && typeof parsed.message === "string") return parsed as CrashRecord;
    return null;
  } catch {
    return null;
  }
}

export async function clearLastCrash(): Promise<void> {
  try {
    await AsyncStorage.removeItem(KEY);
  } catch {
    // ignore
  }
}
