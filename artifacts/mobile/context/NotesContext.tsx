import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";

export interface NoteDocument {
  id: string;
  title: string;
  body: string;
  createdAt: number;
  updatedAt: number;
  language: "Plain" | "Markdown" | "Code";
}

interface NotesContextValue {
  notes: NoteDocument[];
  activeId: string;
  activeNote: NoteDocument;
  isLoaded: boolean;
  setActiveId: (id: string) => void;
  createNote: () => void;
  updateActiveNote: (updates: Partial<Pick<NoteDocument, "title" | "body" | "language">>) => void;
  deleteActiveNote: () => void;
  duplicateActiveNote: () => void;
}

const storageKey = "pocketpad-notes-v1";

const starterNote: NoteDocument = {
  id: "welcome",
  title: "scratchpad.txt",
  body: "Welcome to PocketPad++\n\nA fast iPhone notepad for serious text work.\n\nTry this:\n- Create multiple documents\n- Search within a file\n- Toggle the document type\n- Watch line, word, and character counts update live\n\nEverything autosaves locally on this device.",
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
          if (parsed.notes.length > 0) {
            setNotes(parsed.notes);
            setActiveIdState(parsed.activeId && parsed.notes.some((note) => note.id === parsed.activeId) ? parsed.activeId : parsed.notes[0].id);
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

  const updateActiveNote = (updates: Partial<Pick<NoteDocument, "title" | "body" | "language">>) => {
    setNotes((current) =>
      current.map((note) =>
        note.id === activeNote.id
          ? {
              ...note,
              ...updates,
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
      updateActiveNote,
      deleteActiveNote,
      duplicateActiveNote,
    }),
    [activeId, activeNote, isLoaded, notes],
  );

  return <NotesContext.Provider value={value}>{children}</NotesContext.Provider>;
}

export function useNotes() {
  const context = useContext(NotesContext);
  if (!context) {
    throw new Error("useNotes must be used within NotesProvider");
  }
  return context;
}