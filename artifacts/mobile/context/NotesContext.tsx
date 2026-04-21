import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

export type NoteLanguage = "Plain" | "Markdown" | "Assembly" | "JavaScript" | "Python" | "Web" | "JSON";

// Group rapid keystrokes (< this many ms apart) into a single undo step.
const UNDO_GROUP_MS = 800;
const UNDO_LIMIT = 100;

export interface NoteDocument {
  id: string;
  title: string;
  body: string;
  createdAt: number;
  updatedAt: number;
  language: NoteLanguage;
}

interface NotesContextValue {
  notes: NoteDocument[];
  activeId: string;
  activeNote: NoteDocument;
  isLoaded: boolean;
  setActiveId: (id: string) => void;
  createNote: () => void;
  importNote: (title: string, body: string, language?: NoteLanguage) => void;
  updateActiveNote: (updates: Partial<Pick<NoteDocument, "title" | "body" | "language">>) => void;
  deleteActiveNote: () => void;
  duplicateActiveNote: () => void;
  deleteNote: (id: string) => void;
  closeOthers: (keepId: string) => void;
  renameNote: (id: string, title: string) => void;
  duplicateNote: (id: string) => void;
  undo: () => string | null;
  redo: () => string | null;
  canUndo: boolean;
  canRedo: boolean;
}

const storageKey = "pocketpad-notes-v1";
const STARTER_KEY = "notepad3pp.starterContent";
export type StarterContent = "welcome" | "blank";

const welcomeBody = "Welcome to Notepad 3++\n\nA fast iPhone text editor with the feel of classic desktop notepad utilities.\n\nTry this:\n- Switch between mobile and classic layouts in View > Switch layout\n- Tools > Preferences to switch theme or layout\n- File > Open from Files... to open any file\n- View > Compare documents for a top/bottom diff\n- Edit > line tools without leaving the editor\n\nEverything autosaves locally on this device.";

const starterNote: NoteDocument = {
  id: "welcome",
  title: "scratchpad.txt",
  body: welcomeBody,
  createdAt: Date.now(),
  updatedAt: Date.now(),
  language: "Plain",
};

const blankStarterNote: NoteDocument = {
  ...starterNote,
  body: "",
};

export async function getStarterContent(): Promise<StarterContent> {
  try {
    const v = await AsyncStorage.getItem(STARTER_KEY);
    return v === "blank" ? "blank" : "welcome";
  } catch {
    return "welcome";
  }
}

export async function setStarterContent(value: StarterContent): Promise<void> {
  try {
    await AsyncStorage.setItem(STARTER_KEY, value);
  } catch {
    // ignore
  }
}

const NotesContext = createContext<NotesContextValue | null>(null);

function makeId() {
  return Date.now().toString() + Math.random().toString(36).slice(2, 9);
}

function makeUntitledName(notes: NoteDocument[]) {
  const nextNumber = notes.filter((note) => note.title.startsWith("untitled")).length + 1;
  return `untitled-${nextNumber}.txt`;
}

type History = { undo: string[]; redo: string[]; lastTouch: number };

export function NotesProvider({ children }: { children: ReactNode }) {
  const [notes, setNotes] = useState<NoteDocument[]>([starterNote]);
  const [activeId, setActiveIdState] = useState(starterNote.id);
  const [isLoaded, setIsLoaded] = useState(false);
  const historiesRef = useRef<Map<string, History>>(new Map());
  const [historyTick, setHistoryTick] = useState(0);
  const bumpHistory = useCallback(() => setHistoryTick((t) => t + 1), []);

  const getHistory = useCallback((id: string): History => {
    let h = historiesRef.current.get(id);
    if (!h) {
      h = { undo: [], redo: [], lastTouch: 0 };
      historiesRef.current.set(id, h);
    }
    return h;
  }, []);

  useEffect(() => {
    let mounted = true;
    Promise.all([AsyncStorage.getItem(storageKey), AsyncStorage.getItem(STARTER_KEY)])
      .then(([stored, starterPref]) => {
        if (!mounted) return;
        if (stored) {
          const parsed = JSON.parse(stored) as { notes: NoteDocument[]; activeId?: string };
          const migrated = parsed.notes.map((note) => ({ ...note, language: normalizeLanguage(note.language) }));
          if (migrated.length > 0) {
            setNotes(migrated);
            setActiveIdState(parsed.activeId && migrated.some((note) => note.id === parsed.activeId) ? parsed.activeId : migrated[0].id);
            return;
          }
        }
        if (starterPref === "blank") {
          setNotes([blankStarterNote]);
          setActiveIdState(blankStarterNote.id);
        }
      })
      .finally(() => {
        if (mounted) setIsLoaded(true);
      });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (!isLoaded) return;
    AsyncStorage.setItem(storageKey, JSON.stringify({ notes, activeId }));
  }, [activeId, isLoaded, notes]);

  const activeNote = notes.find((note) => note.id === activeId) ?? notes[0] ?? starterNote;

  const setActiveId = (id: string) => {
    Haptics.selectionAsync();
    setActiveIdState(id);
  };

  const createNote = () => {
    const now = Date.now();
    const note: NoteDocument = {
      id: makeId(),
      title: makeUntitledName(notes),
      body: "",
      createdAt: now,
      updatedAt: now,
      language: "Plain",
    };
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setNotes((current) => [note, ...current]);
    setActiveIdState(note.id);
  };

  const importNote = (title: string, body: string, language: NoteLanguage = "Plain") => {
    const now = Date.now();
    const note: NoteDocument = {
      id: makeId(),
      title,
      body,
      createdAt: now,
      updatedAt: now,
      language,
    };
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setNotes((current) => [note, ...current]);
    setActiveIdState(note.id);
  };

  const recordEdit = useCallback((id: string, prevBody: string) => {
    const h = getHistory(id);
    const now = Date.now();
    const stale = now - h.lastTouch > UNDO_GROUP_MS;
    if (stale || h.undo.length === 0) {
      h.undo.push(prevBody);
      if (h.undo.length > UNDO_LIMIT) h.undo.shift();
      if (h.redo.length > 0) h.redo = [];
      bumpHistory();
    }
    h.lastTouch = now;
  }, [bumpHistory, getHistory]);

  const updateActiveNote = (updates: Partial<Pick<NoteDocument, "title" | "body" | "language">>) => {
    if (updates.body !== undefined && updates.body !== activeNote.body) {
      recordEdit(activeNote.id, activeNote.body);
    }
    setNotes((current) =>
      current.map((note) =>
        note.id === activeNote.id
          ? {
              ...note,
              ...updates,
              language: updates.language ? normalizeLanguage(updates.language) : note.language,
              title: updates.title !== undefined && updates.title.trim().length === 0 ? "untitled.txt" : updates.title ?? note.title,
              updatedAt: Date.now(),
            }
          : note,
      ),
    );
  };

  const undo = useCallback((): string | null => {
    const h = getHistory(activeNote.id);
    const prev = h.undo.pop();
    if (prev === undefined) return null;
    h.redo.push(activeNote.body);
    h.lastTouch = 0;
    setNotes((current) => current.map((note) => (note.id === activeNote.id ? { ...note, body: prev, updatedAt: Date.now() } : note)));
    bumpHistory();
    return prev;
  }, [activeNote.body, activeNote.id, bumpHistory, getHistory]);

  const redo = useCallback((): string | null => {
    const h = getHistory(activeNote.id);
    const next = h.redo.pop();
    if (next === undefined) return null;
    h.undo.push(activeNote.body);
    if (h.undo.length > UNDO_LIMIT) h.undo.shift();
    h.lastTouch = 0;
    setNotes((current) => current.map((note) => (note.id === activeNote.id ? { ...note, body: next, updatedAt: Date.now() } : note)));
    bumpHistory();
    return next;
  }, [activeNote.body, activeNote.id, bumpHistory, getHistory]);

  const activeHistory = historiesRef.current.get(activeNote.id);
  const canUndo = (activeHistory?.undo.length ?? 0) > 0;
  const canRedo = (activeHistory?.redo.length ?? 0) > 0;
  void historyTick;

  const deleteActiveNote = () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    setNotes((current) => {
      if (current.length === 1) {
        const reset = { ...starterNote, id: makeId(), createdAt: Date.now(), updatedAt: Date.now() };
        setActiveIdState(reset.id);
        return [reset];
      }
      const next = current.filter((note) => note.id !== activeNote.id);
      setActiveIdState(next[0].id);
      return next;
    });
  };

  const deleteNote = (id: string) => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    setNotes((current) => {
      if (current.length === 1 && current[0].id === id) {
        const reset = { ...starterNote, id: makeId(), createdAt: Date.now(), updatedAt: Date.now() };
        setActiveIdState(reset.id);
        return [reset];
      }
      const next = current.filter((note) => note.id !== id);
      setActiveIdState((curActive) => (curActive === id ? next[0].id : curActive));
      return next;
    });
  };

  const closeOthers = (keepId: string) => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    setNotes((current) => {
      const keep = current.find((note) => note.id === keepId);
      if (!keep) return current;
      setActiveIdState(keep.id);
      return [keep];
    });
  };

  const renameNote = (id: string, title: string) => {
    const safe = title.trim().length === 0 ? "untitled.txt" : title;
    setNotes((current) => current.map((note) => (note.id === id ? { ...note, title: safe, updatedAt: Date.now() } : note)));
  };

  const duplicateNote = (id: string) => {
    const source = notes.find((note) => note.id === id);
    if (!source) return;
    const now = Date.now();
    const copy: NoteDocument = {
      ...source,
      id: makeId(),
      title: source.title.replace(/(\.[^.]+)?$/, " copy$1"),
      createdAt: now,
      updatedAt: now,
    };
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setNotes((current) => [copy, ...current]);
    setActiveIdState(copy.id);
  };

  const duplicateActiveNote = () => {
    const now = Date.now();
    const copy: NoteDocument = {
      ...activeNote,
      id: makeId(),
      title: activeNote.title.replace(/(\.[^.]+)?$/, " copy$1"),
      createdAt: now,
      updatedAt: now,
    };
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setNotes((current) => [copy, ...current]);
    setActiveIdState(copy.id);
  };

  const value = useMemo(
    () => ({
      notes,
      activeId,
      activeNote,
      isLoaded,
      setActiveId,
      createNote,
      importNote,
      updateActiveNote,
      deleteActiveNote,
      duplicateActiveNote,
      deleteNote,
      closeOthers,
      renameNote,
      duplicateNote,
      undo,
      redo,
      canUndo,
      canRedo,
    }),
    [activeId, activeNote, isLoaded, notes, undo, redo, canUndo, canRedo],
  );

  return <NotesContext.Provider value={value}>{children}</NotesContext.Provider>;
}

export function normalizeLanguage(language: unknown): NoteLanguage {
  if (language === "Code") return "JavaScript";
  if (language === "Plain" || language === "Markdown" || language === "Assembly" || language === "JavaScript" || language === "Python" || language === "Web" || language === "JSON") {
    return language;
  }
  return "Plain";
}

export function detectLanguageFromFileName(name: string): NoteLanguage {
  const lower = name.toLowerCase();
  if (/\.(asm|s|nasm|masm|inc)$/.test(lower)) return "Assembly";
  if (/\.(md|markdown)$/.test(lower)) return "Markdown";
  if (/\.(js|jsx|ts|tsx|mjs|cjs)$/.test(lower)) return "JavaScript";
  if (/\.(py|pyw)$/.test(lower)) return "Python";
  if (/\.(html|htm|css|xml|svg)$/.test(lower)) return "Web";
  if (/\.(json|jsonc)$/.test(lower)) return "JSON";
  return "Plain";
}

export function useNotes() {
  const context = useContext(NotesContext);
  if (!context) {
    throw new Error("useNotes must be used within NotesProvider");
  }
  return context;
}
