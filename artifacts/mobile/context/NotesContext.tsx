import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";

export type NoteLanguage = "Plain" | "Markdown" | "Assembly" | "JavaScript" | "Python" | "Web" | "JSON";

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
}

const storageKey = "pocketpad-notes-v1";

const starterNote: NoteDocument = {
  id: "welcome",
  title: "scratchpad.txt",
  body: "Welcome to PocketPad++\n\nA fast iPhone notepad for serious text work.\n\nTry this:\n- Import files from the Files app\n- Compare two documents top and bottom\n- Switch to Assembly or code mode for syntax coloring\n- Use line tools without leaving the editor\n\nEverything autosaves locally on this device.",
  createdAt: Date.now(),
  updatedAt: Date.now(),
  language: "Plain",
};

const NotesContext = createContext<NotesContextValue | null>(null);

function makeId() {
  return Date.now().toString() + Math.random().toString(36).slice(2, 9);
}

function makeUntitledName(notes: NoteDocument[]) {
  const nextNumber = notes.filter((note) => note.title.startsWith("untitled")).length + 1;
  return `untitled-${nextNumber}.txt`;
}

export function NotesProvider({ children }: { children: ReactNode }) {
  const [notes, setNotes] = useState<NoteDocument[]>([starterNote]);
  const [activeId, setActiveIdState] = useState(starterNote.id);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    let mounted = true;
    AsyncStorage.getItem(storageKey)
      .then((stored) => {
        if (!mounted) return;
        if (stored) {
          const parsed = JSON.parse(stored) as { notes: NoteDocument[]; activeId?: string };
          const migrated = parsed.notes.map((note) => ({ ...note, language: normalizeLanguage(note.language) }));
          if (migrated.length > 0) {
            setNotes(migrated);
            setActiveIdState(parsed.activeId && migrated.some((note) => note.id === parsed.activeId) ? parsed.activeId : migrated[0].id);
          }
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

  const updateActiveNote = (updates: Partial<Pick<NoteDocument, "title" | "body" | "language">>) => {
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
    }),
    [activeId, activeNote, isLoaded, notes],
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
