import { Feather, Ionicons } from "@expo/vector-icons";
import * as DocumentPicker from "expo-document-picker";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Modal,
  NativeScrollEvent,
  NativeSyntheticEvent,
  PanResponder,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TextInputSelectionChangeEventData,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { detectLanguageFromFileName, NoteDocument, NoteLanguage, useNotes } from "@/context/NotesContext";
import { useTheme } from "@/context/ThemeContext";
import { useColors } from "@/hooks/useColors";

type ThemeChoiceId = "classic" | "light" | "dark" | "retro" | "modern" | "cyberpunk" | "system";
type ThemeChoice = { id: ThemeChoiceId; label: string; hint: string };
const themeChoices: ThemeChoice[] = [
  { id: "classic", label: "Classic", hint: "Notepad2 on Windows 7 Aero" },
  { id: "light", label: "Light", hint: "Clean and bright" },
  { id: "dark", label: "Dark", hint: "Easy on the eyes" },
  { id: "retro", label: "Retro", hint: "Windows 95 chrome" },
  { id: "modern", label: "Modern", hint: "Soft, rounded, indigo" },
  { id: "cyberpunk", label: "Cyberpunk", hint: "Neon magenta and cyan" },
  { id: "system", label: "Match system", hint: "Follow the iPhone setting" },
];

type DiffStatus = "same" | "added" | "removed" | "changed";
type DiffRow = { line: number; leftText: string; rightText: string; status: DiffStatus };
type Token = { text: string; kind: "plain" | "keyword" | "register" | "number" | "string" | "comment" | "label" | "operator" };
type MouseRect = { x: number; y: number; w: number; h: number; onPress: () => void };
type MouseRegistry = {
  enabled: boolean;
  set: (id: string, rect: { x: number; y: number; w: number; h: number }, onPress: () => void) => void;
  remove: (id: string) => void;
};

const languages: NoteLanguage[] = ["Plain", "Markdown", "Assembly", "JavaScript", "Python", "Web", "JSON"];
const assemblyOps = new Set(
  "mov lea push pop call ret jmp je jne jz jnz ja jae jb jbe jl jle jg jge cmp test add sub inc dec mul imul div idiv and or xor not shl shr sal sar rol ror nop int syscall sysenter leave enter rep repe repne stosb stosw stosd movsb movsw movsd lodsb lodsw lodsd scasb scasw scasd cmpsb cmpsw cmpsd db dw dd dq section global extern bits org equ".split(" "),
);
const registers = new Set(
  "al ah ax eax rax bl bh bx ebx rbx cl ch cx ecx rcx dl dh dx edx rdx si esi rsi di edi rdi sp esp rsp bp ebp rbp r8 r9 r10 r11 r12 r13 r14 r15 r8d r9d r10d r11d r12d r13d r14d r15d xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7 ymm0 ymm1 ymm2 ymm3 ymm4 ymm5 ymm6 ymm7 cs ds es fs gs ss".split(" "),
);
const codeKeywords = new Set(
  "const let var function return if else for while switch case break continue class import export from async await try catch finally throw new typeof interface type extends def lambda pass in is and or not true false null undefined None True False public private protected static void int char float double bool string".split(" "),
);

const MouseContext = createContext<MouseRegistry>({ enabled: false, set: () => {}, remove: () => {} });

function MTarget({ id, onPress, children }: { id: string; onPress: () => void; children: React.ReactNode }) {
  const reg = useContext(MouseContext);
  const ref = useRef<View>(null);
  const onPressRef = useRef(onPress);
  onPressRef.current = onPress;
  const measureSelf = () => {
    if (!reg.enabled) return;
    ref.current?.measureInWindow((x, y, w, h) => {
      if (typeof x === "number" && typeof y === "number") reg.set(id, { x, y, w, h }, () => onPressRef.current());
    });
  };
  useEffect(() => () => reg.remove(id), [id, reg]);
  useEffect(() => {
    if (reg.enabled) measureSelf();
  }, [reg.enabled]);
  return (
    <View ref={ref} onLayout={measureSelf} collapsable={false}>
      {children}
    </View>
  );
}

function MouseOverlay({ targetsRef, palette, colors, radius, onClose }: { targetsRef: React.MutableRefObject<Map<string, MouseRect>>; palette: ReturnType<typeof useTheme>["palette"]; colors: ReturnType<typeof useColors>; radius: number; onClose: () => void }) {
  const [pos, setPos] = useState({ x: 200, y: 360 });
  const [ripple, setRipple] = useState<{ x: number; y: number; key: number } | null>(null);
  const posRef = useRef(pos);
  posRef.current = pos;
  const dragStart = useRef({ x: 0, y: 0 });
  const panResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: () => true,
    onPanResponderGrant: () => { dragStart.current = { ...posRef.current }; },
    onPanResponderMove: (_e, g) => setPos({ x: dragStart.current.x + g.dx, y: dragStart.current.y + g.dy }),
  }), []);
  const move = (dx: number, dy: number) => setPos((c) => ({ x: c.x + dx, y: c.y + dy }));
  const click = () => {
    const p = posRef.current;
    setRipple({ x: p.x, y: p.y, key: Date.now() });
    Haptics.selectionAsync();
    const list = Array.from(targetsRef.current.values()).reverse();
    for (const t of list) {
      if (p.x >= t.x && p.x <= t.x + t.w && p.y >= t.y && p.y <= t.y + t.h) {
        t.onPress();
        return;
      }
    }
  };
  useEffect(() => {
    if (!ripple) return;
    const t = setTimeout(() => setRipple(null), 380);
    return () => clearTimeout(t);
  }, [ripple]);
  return (
    <>
      {ripple ? <View pointerEvents="none" style={[styles.clickRipple, { left: ripple.x - 18, top: ripple.y - 18, borderColor: colors.primary }]} /> : null}
      <View {...panResponder.panHandlers} style={[styles.mousePointer, { left: pos.x, top: pos.y }]}>
        <Feather name="navigation" size={26} color={colors.primary} style={{ transform: [{ rotate: "-30deg" }] }} />
        <View style={[styles.mousePointerDot, { backgroundColor: colors.primary }]} />
      </View>
      <View style={[styles.mousePad, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius }]}>
        <View style={styles.mousePadRow}>
          <View style={styles.mousePadCell} />
          <Pressable onPress={() => move(0, -18)} style={[styles.mousePadKey, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Feather name="chevron-up" size={14} color={colors.foreground} /></Pressable>
          <View style={styles.mousePadCell} />
        </View>
        <View style={styles.mousePadRow}>
          <Pressable onPress={() => move(-18, 0)} style={[styles.mousePadKey, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Feather name="chevron-left" size={14} color={colors.foreground} /></Pressable>
          <Pressable onPress={click} style={[styles.mousePadClick, { backgroundColor: colors.primary, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Text style={[styles.mousePadClickText, { color: colors.primaryForeground }]}>Click</Text></Pressable>
          <Pressable onPress={() => move(18, 0)} style={[styles.mousePadKey, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Feather name="chevron-right" size={14} color={colors.foreground} /></Pressable>
        </View>
        <View style={styles.mousePadRow}>
          <Pressable onPress={onClose} style={[styles.mousePadKey, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Feather name="x" size={12} color={colors.foreground} /></Pressable>
          <Pressable onPress={() => move(0, 18)} style={[styles.mousePadKey, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]}><Feather name="chevron-down" size={14} color={colors.foreground} /></Pressable>
          <View style={styles.mousePadCell} />
        </View>
      </View>
    </>
  );
}

function formatTime(value: number) {
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }).format(new Date(value));
}

function getStats(body: string) {
  const lines = body.length === 0 ? 1 : body.split("\n").length;
  const words = body.trim().length === 0 ? 0 : body.trim().split(/\s+/).length;
  return { lines, words, chars: body.length };
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getMatches(body: string, query: string, caseSensitive: boolean) {
  if (!query.trim()) return 0;
  const haystack = caseSensitive ? body : body.toLowerCase();
  const needle = caseSensitive ? query.trim() : query.trim().toLowerCase();
  return haystack.split(needle).length - 1;
}

function getCursorPosition(body: string, index: number) {
  const before = body.slice(0, index);
  const lines = before.split("\n");
  return { line: lines.length, column: (lines[lines.length - 1]?.length ?? 0) + 1 };
}

function getLineRange(body: string, index: number) {
  const start = body.lastIndexOf("\n", Math.max(0, index - 1)) + 1;
  const rawEnd = body.indexOf("\n", index);
  return { start, end: rawEnd === -1 ? body.length : rawEnd };
}

function compareDocuments(left: NoteDocument, right?: NoteDocument) {
  if (!right) return { rows: [] as DiffRow[], added: 0, removed: 0, changed: 0, same: 0, similarity: 100 };
  const leftLines = left.body.split("\n");
  const rightLines = right.body.split("\n");
  const total = Math.max(leftLines.length, rightLines.length);
  const rows: DiffRow[] = Array.from({ length: total }, (_, index) => {
    const leftText = leftLines[index];
    const rightText = rightLines[index];
    const status: DiffStatus =
      leftText === rightText ? "same" : leftText === undefined ? "added" : rightText === undefined ? "removed" : "changed";
    return { line: index + 1, leftText: leftText ?? "", rightText: rightText ?? "", status };
  });
  const same = rows.filter((row) => row.status === "same").length;
  return {
    rows,
    added: rows.filter((row) => row.status === "added").length,
    removed: rows.filter((row) => row.status === "removed").length,
    changed: rows.filter((row) => row.status === "changed").length,
    same,
    similarity: total === 0 ? 100 : Math.round((same / total) * 100),
  };
}

function tokenizeLine(line: string, language: NoteLanguage): Token[] {
  if (language === "Plain") return [{ text: line || " ", kind: "plain" }];
  const commentIndex = language === "Assembly" ? line.search(/[;]/) : line.search(/\/\/|#|<!--/);
  const code = commentIndex >= 0 ? line.slice(0, commentIndex) : line;
  const comment = commentIndex >= 0 ? line.slice(commentIndex) : "";
  const pattern = /("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'|`[^`]*`|\b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?\b|[A-Za-z_.$][\w.$]*:?|[{}()[\],.+\-*/%=<>!&|:]+)/g;
  const tokens: Token[] = [];
  let cursor = 0;
  for (const match of code.matchAll(pattern)) {
    const text = match[0];
    const index = match.index ?? 0;
    if (index > cursor) tokens.push({ text: code.slice(cursor, index), kind: "plain" });
    const normalized = text.replace(/:$/, "").replace(/^\./, "").toLowerCase();
    let kind: Token["kind"] = "plain";
    if (/^['"`]/.test(text)) kind = "string";
    else if (/^(0x[\da-f]+|\d)/i.test(text)) kind = "number";
    else if (text.endsWith(":")) kind = "label";
    else if (language === "Assembly" && registers.has(normalized)) kind = "register";
    else if (language === "Assembly" && assemblyOps.has(normalized)) kind = "keyword";
    else if (language !== "Assembly" && codeKeywords.has(normalized)) kind = "keyword";
    else if (/^[{}()[\],.+\-*/%=<>!&|:]+$/.test(text)) kind = "operator";
    tokens.push({ text, kind });
    cursor = index + text.length;
  }
  if (cursor < code.length) tokens.push({ text: code.slice(cursor), kind: "plain" });
  if (comment) tokens.push({ text: comment, kind: "comment" });
  return tokens.length ? tokens : [{ text: " ", kind: "plain" }];
}

function tokenColor(kind: Token["kind"], colors: ReturnType<typeof useColors>) {
  switch (kind) {
    case "keyword":
      return colors.primary;
    case "register":
      return colors.accent;
    case "number":
      return colors.success;
    case "string":
      return colors.destructive;
    case "comment":
      return colors.mutedForeground;
    case "label":
      return colors.accent;
    case "operator":
      return colors.mutedForeground;
    default:
      return colors.foreground;
  }
}

function SyntaxLine({ line, language, muted }: { line: string; language: NoteLanguage; muted?: boolean }) {
  const colors = useColors();
  return (
    <Text style={[styles.syntaxLine, { color: muted ? colors.mutedForeground : colors.foreground }]}>
      {tokenizeLine(line, language).map((token, index) => (
        <Text key={`${index}-${token.text}`} style={{ color: muted ? colors.mutedForeground : tokenColor(token.kind, colors) }}>
          {token.text}
        </Text>
      ))}
    </Text>
  );
}

function DropdownItem({ label, hint, onPress, destructive, checked }: { label: string; hint?: string; onPress: () => void; destructive?: boolean; checked?: boolean }) {
  const colors = useColors();
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.dropdownItem, { backgroundColor: pressed ? colors.primary : "transparent" }]}>
      {({ pressed }) => (
        <View style={styles.dropdownItemRow}>
          <Text style={[styles.dropdownCheck, { color: pressed ? colors.primaryForeground : colors.foreground }]}>{checked ? "✓" : " "}</Text>
          <View style={{ flex: 1 }}>
            <Text style={[styles.dropdownLabel, { color: pressed ? colors.primaryForeground : destructive ? colors.destructive : colors.foreground }]}>{label}</Text>
            {hint ? <Text style={[styles.dropdownHint, { color: pressed ? colors.primaryForeground : colors.mutedForeground }]}>{hint}</Text> : null}
          </View>
        </View>
      )}
    </Pressable>
  );
}

function DropdownSeparator() {
  const colors = useColors();
  return <View style={[styles.dropdownSeparator, { backgroundColor: colors.border }]} />;
}

function IconButton({ id, icon, onPress, color, disabled }: { id: string; icon: keyof typeof Feather.glyphMap; onPress: () => void; color: string; disabled?: boolean }) {
  const colors = useColors();
  const { radius } = useTheme();
  return (
    <MTarget id={id} onPress={onPress}>
      <Pressable disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.iconButton, { backgroundColor: pressed ? colors.secondary : "transparent", opacity: disabled ? 0.35 : 1, borderRadius: Math.min(radius, 4) }]} testID={`button-${icon}`}>
        <Feather name={icon} size={16} color={color} />
      </Pressable>
    </MTarget>
  );
}

function DocumentTab({ item, active }: { item: NoteDocument; active: boolean }) {
  const colors = useColors();
  const { radius } = useTheme();
  const { setActiveId } = useNotes();
  return (
    <MTarget id={`tab-${item.id}`} onPress={() => setActiveId(item.id)}>
      <Pressable onPress={() => setActiveId(item.id)} style={({ pressed }) => [styles.documentTab, { backgroundColor: active ? colors.editorBackground : colors.muted, borderColor: colors.border, borderTopLeftRadius: radius, borderTopRightRadius: radius, borderBottomColor: active ? colors.editorBackground : colors.border, opacity: pressed ? 0.85 : 1 }]} testID={`note-tab-${item.id}`}>
        <Text numberOfLines={1} style={[styles.documentTabTitle, { color: colors.foreground, fontFamily: active ? "Inter_700Bold" : "Inter_500Medium" }]}>{item.title}</Text>
      </Pressable>
    </MTarget>
  );
}

function EditorGutter({ lineCount }: { lineCount: number }) {
  const colors = useColors();
  const lines = useMemo(() => Array.from({ length: Math.max(lineCount, 1) }, (_, index) => index + 1), [lineCount]);
  return (
    <View style={[styles.gutter, { backgroundColor: colors.editorGutter, borderColor: colors.border }]}>
      {lines.map((line) => (
        <Text key={line} style={[styles.gutterText, { color: colors.mutedForeground }]}>{line}</Text>
      ))}
    </View>
  );
}

function ComparePane({ title, rows, side, language, onScroll, scrollRef }: { title: string; rows: DiffRow[]; side: "left" | "right"; language: NoteLanguage; onScroll: (event: NativeSyntheticEvent<NativeScrollEvent>) => void; scrollRef: React.RefObject<ScrollView | null> }) {
  const colors = useColors();
  return (
    <View style={[styles.comparePane, { borderColor: colors.border, backgroundColor: colors.editorBackground }]}>
      <View style={[styles.comparePaneHeader, { borderColor: colors.border }]}>
        <Text numberOfLines={1} style={[styles.comparePaneTitle, { color: colors.foreground }]}>{title}</Text>
      </View>
      <ScrollView ref={scrollRef} onScroll={onScroll} scrollEventThrottle={16} showsVerticalScrollIndicator={false} style={styles.compareScroll}>
        {rows.map((row) => {
          const marker = row.status === "added" ? "+" : row.status === "removed" ? "-" : row.status === "changed" ? "~" : " ";
          const bg = row.status === "added" ? "#dff2d8" : row.status === "removed" ? "#f9d5d1" : row.status === "changed" ? "#fff1b8" : colors.editorBackground;
          const text = side === "left" ? row.leftText : row.rightText;
          const muted = (side === "left" && row.status === "added") || (side === "right" && row.status === "removed");
          return (
            <View key={`${side}-${row.line}`} style={[styles.compareLine, { backgroundColor: bg, borderColor: colors.border }]}>
              <Text style={[styles.compareMarker, { color: row.status === "same" ? colors.mutedForeground : colors.foreground }]}>{marker}</Text>
              <Text style={[styles.compareLineNo, { color: colors.mutedForeground }]}>{row.line}</Text>
              <View style={styles.compareCodeCell}>
                <SyntaxLine line={text || " "} language={language} muted={muted} />
              </View>
            </View>
          );
        })}
      </ScrollView>
    </View>
  );
}

function SyntaxPreview({ note }: { note: NoteDocument }) {
  const colors = useColors();
  if (note.language === "Plain") return null;
  const lines = note.body.split("\n").slice(0, 80);
  return (
    <View style={[styles.syntaxPreview, { borderColor: colors.border, backgroundColor: colors.muted }]}>
      <Text style={[styles.syntaxTitle, { color: colors.foreground }]}>{note.language} syntax coloring</Text>
      {lines.map((line, index) => (
        <View key={`${index}-${line}`} style={styles.syntaxPreviewLine}>
          <Text style={[styles.syntaxLineNumber, { color: colors.mutedForeground }]}>{index + 1}</Text>
          <SyntaxLine line={line} language={note.language} />
        </View>
      ))}
    </View>
  );
}

export default function NotepadScreen() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const { preference, setPreference, palette, radius } = useTheme();
  const { notes, activeNote, activeId, isLoaded, createNote, importNote, updateActiveNote, deleteActiveNote, duplicateActiveNote } = useNotes();
  const [findOpen, setFindOpen] = useState(false);
  const [findQuery, setFindQuery] = useState("");
  const [replaceOpen, setReplaceOpen] = useState(false);
  const [replaceText, setReplaceText] = useState("");
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);
  const [compareId, setCompareId] = useState<string | null>(null);
  const [zenMode, setZenMode] = useState(false);
  const [toolbarOpen, setToolbarOpen] = useState(true);
  const [selection, setSelection] = useState({ start: 0, end: 0 });
  const [importError, setImportError] = useState("");
  const [openMenu, setOpenMenu] = useState<null | "file" | "edit" | "view" | "tools" | "help">(null);
  const [prefsOpen, setPrefsOpen] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [langOpen, setLangOpen] = useState(false);
  const [mouseOn, setMouseOn] = useState(false);
  const mouseTargetsRef = useRef<Map<string, MouseRect>>(new Map());
  const topCompareRef = useRef<ScrollView>(null);
  const bottomCompareRef = useRef<ScrollView>(null);
  const syncingRef = useRef(false);
  const stats = getStats(activeNote.body);
  const cursor = getCursorPosition(activeNote.body, selection.start);
  const selectedChars = Math.max(0, selection.end - selection.start);
  const comparableNotes = notes.filter((note) => note.id !== activeId);
  const compareNote = comparableNotes.find((note) => note.id === compareId) ?? comparableNotes[0];
  const comparison = compareDocuments(activeNote, compareNote);
  const matches = getMatches(activeNote.body, findQuery, caseSensitive);
  const highlightedPreview = findQuery.trim()
    ? activeNote.body
        .split("\n")
        .map((line, index) => ({ line, index: index + 1 }))
        .filter(({ line }) => (caseSensitive ? line : line.toLowerCase()).includes(caseSensitive ? findQuery.trim() : findQuery.trim().toLowerCase()))
        .slice(0, 3)
    : [];

  const mouseRegistry = useMemo<MouseRegistry>(() => ({
    enabled: mouseOn,
    set: (id, rect, onPress) => mouseTargetsRef.current.set(id, { ...rect, onPress }),
    remove: (id) => { mouseTargetsRef.current.delete(id); },
  }), [mouseOn]);

  const syncScroll = (target: React.RefObject<ScrollView | null>) => (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    target.current?.scrollTo({ y: event.nativeEvent.contentOffset.y, animated: false });
    setTimeout(() => {
      syncingRef.current = false;
    }, 40);
  };

  const importFromFiles = async () => {
    setImportError("");
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ["text/*", "application/json", "application/javascript", "application/xml", "application/octet-stream"],
        copyToCacheDirectory: true,
        multiple: false,
      });
      if (result.canceled) return;
      const asset = result.assets[0];
      const response = await fetch(asset.uri);
      const text = await response.text();
      importNote(asset.name || "imported.txt", text, detectLanguageFromFileName(asset.name || ""));
    } catch {
      setImportError("Could not import that file. Try a plain text, markdown, code, JSON, or assembly file.");
    }
  };

  const insertTextAtSelection = (value: string) => {
    updateActiveNote({ body: `${activeNote.body.slice(0, selection.start)}${value}${activeNote.body.slice(selection.end)}` });
    const nextIndex = selection.start + value.length;
    setSelection({ start: nextIndex, end: nextIndex });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const replaceAll = () => {
    if (!findQuery.trim()) return;
    updateActiveNote({ body: caseSensitive ? activeNote.body.split(findQuery.trim()).join(replaceText) : activeNote.body.replace(new RegExp(escapeRegExp(findQuery.trim()), "gi"), replaceText) });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const duplicateCurrentLine = () => {
    const range = getLineRange(activeNote.body, selection.start);
    const line = activeNote.body.slice(range.start, range.end);
    updateActiveNote({ body: `${activeNote.body.slice(0, range.end)}\n${line}${activeNote.body.slice(range.end)}` });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const deleteCurrentLine = () => {
    const range = getLineRange(activeNote.body, selection.start);
    const removeEnd = activeNote.body[range.end] === "\n" ? range.end + 1 : range.end;
    updateActiveNote({ body: `${activeNote.body.slice(0, range.start)}${activeNote.body.slice(removeEnd)}` });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
  };

  const sortLines = () => {
    updateActiveNote({ body: activeNote.body.split("\n").sort((a, b) => a.localeCompare(b)).join("\n") });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  };

  const trimTrailingSpaces = () => {
    updateActiveNote({ body: activeNote.body.split("\n").map((line) => line.replace(/[ \t]+$/g, "")).join("\n") });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const toggleCompare = () => {
    setCompareOpen((current) => !current);
    if (!compareId && comparableNotes[0]) setCompareId(comparableNotes[0].id);
  };

  if (!isLoaded) {
    return (
      <View style={[styles.loading, { backgroundColor: colors.background }]}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  const cardOuter = { borderRadius: radius, overflow: "hidden" as const };

  return (
    <MouseContext.Provider value={mouseRegistry}>
      <View style={[styles.screen, { backgroundColor: colors.background }]}>
        <View style={[styles.container, { paddingTop: Platform.OS === "web" ? 67 : insets.top, paddingBottom: Platform.OS === "web" ? 34 : insets.bottom }]}>
          {!zenMode ? (
            <View style={[styles.titleBar, { borderColor: colors.border, borderTopLeftRadius: radius, borderTopRightRadius: radius, overflow: "hidden" }]}>
              <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
              <Ionicons name="document-text-outline" size={13} color={colors.primaryForeground} />
              <Text numberOfLines={1} style={[styles.titleBarText, { color: colors.primaryForeground }]}>{activeNote.title} - Notepad 3++</Text>
            </View>
          ) : null}

          {!zenMode ? (
            <View style={[styles.menuBar, { borderColor: colors.border, overflow: "hidden" }]}>
              <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
              {(["file", "edit", "view", "tools", "help"] as const).map((id) => (
                <MTarget key={id} id={`menu-${id}`} onPress={() => setOpenMenu((current) => (current === id ? null : id))}>
                  <Pressable onPress={() => setOpenMenu((current) => (current === id ? null : id))} style={({ pressed }) => [styles.menuItem, { backgroundColor: openMenu === id ? colors.primary : pressed ? colors.secondary : "transparent" }]} testID={`menu-${id}`}>
                    <Text style={[styles.menuItemText, { color: openMenu === id ? colors.primaryForeground : colors.foreground }]}>{id[0].toUpperCase() + id.slice(1)}</Text>
                  </Pressable>
                </MTarget>
              ))}
            </View>
          ) : null}

          {openMenu ? (
            <Pressable onPress={() => setOpenMenu(null)} style={styles.menuOverlay}>
              <View style={[styles.menuDropdown, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, left: openMenu === "file" ? 0 : openMenu === "edit" ? 44 : openMenu === "view" ? 88 : openMenu === "tools" ? 132 : 176 }]}>
                {openMenu === "file" ? (
                  <>
                    <DropdownItem label="New" hint="Blank note" onPress={() => { createNote(); setOpenMenu(null); }} />
                    <DropdownItem label="Open from Files..." onPress={() => { setOpenMenu(null); importFromFiles(); }} />
                    <DropdownItem label="Duplicate" onPress={() => { duplicateActiveNote(); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Delete" destructive onPress={() => { deleteActiveNote(); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "edit" ? (
                  <>
                    <DropdownItem label="Find" onPress={() => { setFindOpen(true); setReplaceOpen(false); setOpenMenu(null); }} />
                    <DropdownItem label="Replace" onPress={() => { setFindOpen(true); setReplaceOpen(true); setOpenMenu(null); }} />
                    <DropdownItem label={caseSensitive ? "Case sensitive" : "Case sensitive"} checked={caseSensitive} onPress={() => { setCaseSensitive((current) => !current); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Insert timestamp" onPress={() => { insertTextAtSelection(new Date().toLocaleString()); setOpenMenu(null); }} />
                    <DropdownItem label="Duplicate line" onPress={() => { duplicateCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Cut line" onPress={() => { deleteCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Sort lines" onPress={() => { sortLines(); setOpenMenu(null); }} />
                    <DropdownItem label="Trim trailing spaces" onPress={() => { trimTrailingSpaces(); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "view" ? (
                  <>
                    <DropdownItem label="Toolbar" checked={toolbarOpen} onPress={() => { setToolbarOpen((current) => !current); setOpenMenu(null); }} />
                    <DropdownItem label="Compare documents" checked={compareOpen} onPress={() => { toggleCompare(); setOpenMenu(null); }} />
                    <DropdownItem label="Zen mode" checked={zenMode} onPress={() => { setZenMode((current) => !current); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Simulated mouse" hint="On-screen pointer" checked={mouseOn} onPress={() => { setMouseOn((current) => !current); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "tools" ? (
                  <>
                    <DropdownItem label="Preferences..." onPress={() => { setPrefsOpen(true); setOpenMenu(null); }} />
                    <DropdownItem label="Change syntax..." onPress={() => { setLangOpen(true); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "help" ? (
                  <>
                    <DropdownItem label="About Notepad 3++" onPress={() => { setAboutOpen(true); setOpenMenu(null); }} />
                  </>
                ) : null}
              </View>
            </Pressable>
          ) : null}

          {!zenMode && toolbarOpen ? (
            <View style={[styles.toolbar, { borderColor: colors.border, overflow: "hidden" }]}>
              <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
              <IconButton id="tb-new" icon="file-plus" color={colors.foreground} onPress={createNote} />
              <IconButton id="tb-open" icon="folder" color={colors.foreground} onPress={importFromFiles} />
              <IconButton id="tb-dup" icon="copy" color={colors.foreground} onPress={duplicateActiveNote} />
              <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
              <IconButton id="tb-find" icon="search" color={findOpen ? colors.primary : colors.foreground} onPress={() => setFindOpen((current) => !current)} />
              <IconButton id="tb-rep" icon="repeat" color={replaceOpen ? colors.primary : colors.foreground} onPress={() => { setFindOpen(true); setReplaceOpen((current) => !current); }} />
              <IconButton id="tb-stamp" icon="clock" color={colors.foreground} onPress={() => insertTextAtSelection(new Date().toLocaleString())} />
              <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
              <IconButton id="tb-dupl" icon="plus-square" color={colors.foreground} onPress={duplicateCurrentLine} />
              <IconButton id="tb-cutl" icon="scissors" color={colors.foreground} onPress={deleteCurrentLine} />
              <IconButton id="tb-sort" icon="list" color={colors.foreground} onPress={sortLines} />
              <IconButton id="tb-trim" icon="align-left" color={colors.foreground} onPress={trimTrailingSpaces} />
              <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
              <IconButton id="tb-cmp" icon="columns" color={compareOpen ? colors.primary : colors.foreground} onPress={toggleCompare} />
              <IconButton id="tb-zen" icon={zenMode ? "minimize-2" : "maximize-2"} color={colors.foreground} onPress={() => setZenMode((current) => !current)} />
              <IconButton id="tb-mouse" icon="mouse-pointer" color={mouseOn ? colors.primary : colors.foreground} onPress={() => setMouseOn((current) => !current)} />
              <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
              <IconButton id="tb-del" icon="trash-2" color={colors.destructive} onPress={deleteActiveNote} />
              <View style={styles.toolbarSpacer} />
              <IconButton id="tb-collapse" icon="chevron-up" color={colors.foreground} onPress={() => setToolbarOpen(false)} />
            </View>
          ) : null}

          {!zenMode && !toolbarOpen ? (
            <View style={[styles.toolbarStrip, { borderColor: colors.border, overflow: "hidden" }]}>
              <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
              <Pressable onPress={() => setToolbarOpen(true)} style={styles.toolbarStripPress}>
                <Feather name="chevron-down" size={14} color={colors.mutedForeground} />
                <Text style={[styles.toolbarStripText, { color: colors.mutedForeground }]}>Show toolbar</Text>
              </Pressable>
            </View>
          ) : null}

          {!zenMode ? (
            <FlatList horizontal data={notes} keyExtractor={(item) => item.id} renderItem={({ item }) => <DocumentTab item={item} active={item.id === activeId} />} style={[styles.tabsScroller, { backgroundColor: colors.background, borderColor: colors.border }]} showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tabsList} scrollEnabled={notes.length > 0} />
          ) : null}

          {importError ? <Text style={[styles.errorText, { color: colors.destructive, backgroundColor: colors.card }]}>{importError}</Text> : null}

          <View style={[styles.editorShell, cardOuter, { backgroundColor: colors.editorBackground, borderColor: colors.border }]}>
            <View style={[styles.fileHeader, { borderColor: colors.border, backgroundColor: colors.card }]}>
              <TextInput value={activeNote.title} onChangeText={(title) => updateActiveNote({ title })} style={[styles.fileTitleInput, { color: colors.foreground }]} placeholder="filename.txt" placeholderTextColor={colors.mutedForeground} testID="filename-input" />
              <MTarget id="lang-button" onPress={() => setLangOpen(true)}>
                <Pressable onPress={() => setLangOpen(true)} style={({ pressed }) => [styles.languageButton, { backgroundColor: pressed ? colors.secondary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="language-button">
                  <Text style={[styles.languageButtonText, { color: colors.foreground }]}>{activeNote.language}</Text>
                  <Feather name="chevron-down" size={11} color={colors.mutedForeground} />
                </Pressable>
              </MTarget>
            </View>

            {findOpen && !zenMode ? (
              <View style={[styles.findPanel, { borderColor: colors.border, backgroundColor: colors.card }]}>
                <View style={styles.findBar}>
                  <Feather name="search" size={17} color={colors.mutedForeground} />
                  <TextInput value={findQuery} onChangeText={setFindQuery} style={[styles.findInput, { color: colors.foreground, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} placeholder="Find in document" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="find-input" />
                  <Pressable onPress={() => setCaseSensitive((current) => !current)} style={[styles.caseToggle, { backgroundColor: caseSensitive ? colors.primary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="case-toggle">
                    <Text style={[styles.caseToggleText, { color: caseSensitive ? colors.primaryForeground : colors.mutedForeground }]}>Aa</Text>
                  </Pressable>
                  <Text style={[styles.findCount, { color: colors.mutedForeground }]}>{matches}</Text>
                </View>
                {replaceOpen ? (
                  <View style={styles.findBar}>
                    <Feather name="repeat" size={17} color={colors.mutedForeground} />
                    <TextInput value={replaceText} onChangeText={setReplaceText} style={[styles.findInput, { color: colors.foreground, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} placeholder="Replace with" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="replace-input" />
                    <Pressable onPress={replaceAll} disabled={!findQuery.trim()} style={({ pressed }) => [styles.replaceButton, { backgroundColor: colors.secondary, borderRadius: Math.min(radius, 4), opacity: !findQuery.trim() ? 0.35 : pressed ? 0.7 : 1 }]} testID="replace-all">
                      <Text style={[styles.replaceButtonText, { color: colors.secondaryForeground }]}>All</Text>
                    </Pressable>
                  </View>
                ) : null}
              </View>
            ) : null}

            {compareOpen ? (
              <View style={styles.compareWorkspace}>
                <View style={[styles.compareToolbar, { borderColor: colors.border, backgroundColor: colors.card }]}>
                  <Text style={[styles.compareSummary, { color: colors.foreground }]}>{comparison.similarity}% similar · {comparison.changed} changed · {comparison.added} added · {comparison.removed} removed</Text>
                  {comparableNotes.length > 0 ? (
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.compareSelector}>
                      {comparableNotes.map((note) => {
                        const selected = note.id === compareNote?.id;
                        return (
                          <Pressable key={note.id} onPress={() => { setCompareId(note.id); Haptics.selectionAsync(); }} style={({ pressed }) => [styles.compareDocPill, { backgroundColor: selected ? colors.secondary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4), opacity: pressed ? 0.7 : 1 }]} testID={`compare-${note.id}`}>
                            <Text numberOfLines={1} style={[styles.compareDocText, { color: selected ? colors.secondaryForeground : colors.foreground }]}>{note.title}</Text>
                          </Pressable>
                        );
                      })}
                    </ScrollView>
                  ) : null}
                </View>
                {compareNote ? (
                  <>
                    <ComparePane title={`Top: ${activeNote.title}`} rows={comparison.rows} side="left" language={activeNote.language} scrollRef={topCompareRef} onScroll={syncScroll(bottomCompareRef)} />
                    <ComparePane title={`Bottom: ${compareNote.title}`} rows={comparison.rows} side="right" language={compareNote.language} scrollRef={bottomCompareRef} onScroll={syncScroll(topCompareRef)} />
                  </>
                ) : (
                  <View style={[styles.compareEmpty, { backgroundColor: colors.muted }]}>
                    <Text style={[styles.compareEmptyTitle, { color: colors.foreground }]}>Open another document to compare.</Text>
                    <Text style={[styles.compareEmptyText, { color: colors.mutedForeground }]}>Import a file or duplicate this document, edit one copy, then return here.</Text>
                  </View>
                )}
              </View>
            ) : (
              <ScrollView style={styles.editorScroll} contentContainerStyle={styles.editorScrollContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
                <View style={styles.editorRow}>
                  <EditorGutter lineCount={stats.lines} />
                  <TextInput value={activeNote.body} onChangeText={(body) => updateActiveNote({ body })} multiline textAlignVertical="top" autoCapitalize="none" autoCorrect={false} spellCheck={false} style={[styles.editorInput, { color: colors.foreground }]} placeholder="Start typing..." placeholderTextColor={colors.mutedForeground} selection={selection} onSelectionChange={(event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => setSelection(event.nativeEvent.selection)} testID="editor-input" />
                </View>
                <SyntaxPreview note={activeNote} />
              </ScrollView>
            )}

            {highlightedPreview.length > 0 && !zenMode && !compareOpen ? (
              <View style={[styles.matchesPanel, { borderColor: colors.border, backgroundColor: colors.muted }]}>
                {highlightedPreview.map(({ line, index }) => (
                  <Text key={`${index}-${line}`} numberOfLines={1} style={[styles.matchLine, { color: colors.mutedForeground }]}>L{index}: {line.trim()}</Text>
                ))}
              </View>
            ) : null}
          </View>

          <View style={[styles.statusBar, { borderColor: colors.border, overflow: "hidden" }]}>
            <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>Ln {cursor.line}, Col {cursor.column}</Text>
            <View style={[styles.statusSep, { backgroundColor: colors.border }]} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>{stats.lines}L  {stats.words}W  {stats.chars}C</Text>
            {selectedChars > 0 ? (
              <>
                <View style={[styles.statusSep, { backgroundColor: colors.border }]} />
                <Text style={[styles.statusText, { color: colors.accent }]}>Sel {selectedChars}</Text>
              </>
            ) : null}
            <View style={[styles.statusSep, { backgroundColor: colors.border }]} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>{activeNote.language}</Text>
            <View style={[styles.statusSep, { backgroundColor: colors.border }]} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>UTF-8</Text>
            <View style={[styles.statusSep, { backgroundColor: colors.border }]} />
            <Text style={[styles.statusText, { color: colors.foreground }]}>CRLF</Text>
            <View style={styles.statusSpacer} />
            <Text style={[styles.statusText, { color: colors.success }]}>saved {formatTime(activeNote.updatedAt)}</Text>
          </View>
        </View>

        {mouseOn ? (
          <MouseOverlay targetsRef={mouseTargetsRef} palette={palette} colors={colors} radius={radius} onClose={() => setMouseOn(false)} />
        ) : null}

        <Modal visible={langOpen} transparent animationType="fade" onRequestClose={() => setLangOpen(false)}>
          <Pressable onPress={() => setLangOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden" }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>Change syntax</Text>
                <Pressable onPress={() => setLangOpen(false)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="lang-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <View style={styles.modalBody}>
                {languages.map((language) => {
                  const selected = activeNote.language === language;
                  return (
                    <Pressable key={language} onPress={() => { Haptics.selectionAsync(); updateActiveNote({ language }); setLangOpen(false); }} style={({ pressed }) => [styles.prefRow, { backgroundColor: selected ? colors.primary : pressed ? colors.secondary : "transparent", borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID={`language-${language}`}>
                      <View style={[styles.radio, { borderColor: selected ? colors.primaryForeground : colors.foreground }]}>
                        {selected ? <View style={[styles.radioDot, { backgroundColor: colors.primaryForeground }]} /> : null}
                      </View>
                      <Text style={[styles.prefRowLabel, { color: selected ? colors.primaryForeground : colors.foreground }]}>{language}</Text>
                    </Pressable>
                  );
                })}
              </View>
            </Pressable>
          </Pressable>
        </Modal>

        <Modal visible={prefsOpen} transparent animationType="fade" onRequestClose={() => setPrefsOpen(false)}>
          <Pressable onPress={() => setPrefsOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden" }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>Preferences</Text>
                <Pressable onPress={() => setPrefsOpen(false)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="prefs-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <ScrollView style={{ maxHeight: 460 }} contentContainerStyle={styles.modalBody}>
                <Text style={[styles.modalSection, { color: colors.foreground }]}>Theme</Text>
                {themeChoices.map((choice) => {
                  const selected = preference === choice.id;
                  return (
                    <Pressable key={choice.id} onPress={() => setPreference(choice.id)} style={({ pressed }) => [styles.prefRow, { backgroundColor: selected ? colors.primary : pressed ? colors.secondary : "transparent", borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID={`theme-${choice.id}`}>
                      <View style={[styles.radio, { borderColor: selected ? colors.primaryForeground : colors.foreground }]}>
                        {selected ? <View style={[styles.radioDot, { backgroundColor: colors.primaryForeground }]} /> : null}
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.prefRowLabel, { color: selected ? colors.primaryForeground : colors.foreground }]}>{choice.label}</Text>
                        <Text style={[styles.prefRowHint, { color: selected ? colors.primaryForeground : colors.mutedForeground }]}>{choice.hint}</Text>
                      </View>
                    </Pressable>
                  );
                })}
                <Text style={[styles.modalNote, { color: colors.mutedForeground }]}>Choices are saved on this device.</Text>
              </ScrollView>
            </Pressable>
          </Pressable>
        </Modal>

        <Modal visible={aboutOpen} transparent animationType="fade" onRequestClose={() => setAboutOpen(false)}>
          <Pressable onPress={() => setAboutOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden" }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>About Notepad 3++</Text>
                <Pressable onPress={() => setAboutOpen(false)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="about-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <View style={styles.modalBody}>
                <Text style={[styles.aboutBig, { color: colors.foreground }]}>Notepad 3++</Text>
                <Text style={[styles.aboutText, { color: colors.foreground }]}>A pocket text editor with the look of Notepad2 on Windows 7 and the tools of Notepad++.</Text>
                <Text style={[styles.aboutText, { color: colors.mutedForeground }]}>Multi-document tabs, find/replace, top-bottom diff, file import, line tools, syntax coloring, and a simulated mouse for desktop nostalgia.</Text>
                <Text style={[styles.aboutText, { color: colors.mutedForeground }]}>Version 1.1.0</Text>
              </View>
            </Pressable>
          </Pressable>
        </Modal>
      </View>
    </MouseContext.Provider>
  );
}

const mono = Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" });

const styles = StyleSheet.create({
  screen: { flex: 1 },
  container: { flex: 1 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center" },
  titleBar: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 8, paddingVertical: 6, borderBottomWidth: 1 },
  titleBarText: { fontFamily: "Inter_500Medium", fontSize: 12, flex: 1 },
  toolbar: { flexDirection: "row", alignItems: "center", paddingHorizontal: 4, paddingVertical: 3, borderBottomWidth: 1, gap: 1 },
  toolbarSep: { width: 1, height: 18, marginHorizontal: 3 },
  toolbarSpacer: { flex: 1 },
  toolbarStrip: { borderBottomWidth: 1, height: 18, justifyContent: "center" },
  toolbarStripPress: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 4, height: 18 },
  toolbarStripText: { fontFamily: "Inter_500Medium", fontSize: 10 },
  iconButton: { alignItems: "center", justifyContent: "center", minHeight: 26, minWidth: 26, paddingHorizontal: 4 },
  tabsList: { paddingHorizontal: 4 },
  tabsScroller: { flexGrow: 0, maxHeight: 28, borderBottomWidth: 1 },
  documentTab: { maxWidth: 160, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 4, marginRight: 2, marginTop: 2, justifyContent: "center" },
  documentTabTitle: { fontSize: 11 },
  errorText: { fontFamily: "Inter_500Medium", fontSize: 11, paddingHorizontal: 8, paddingVertical: 4 },
  editorShell: { flex: 1, borderTopWidth: 1, borderBottomWidth: 1 },
  fileHeader: { borderBottomWidth: 1, paddingHorizontal: 6, paddingVertical: 4, gap: 6, flexDirection: "row", alignItems: "center" },
  fileTitleInput: { flex: 1, fontFamily: "Inter_500Medium", fontSize: 12, paddingVertical: 0 },
  languageButton: { borderWidth: 1, paddingHorizontal: 8, paddingVertical: 3, flexDirection: "row", alignItems: "center", gap: 4 },
  languageButtonText: { fontFamily: "Inter_500Medium", fontSize: 11 },
  findPanel: { borderBottomWidth: 1, paddingHorizontal: 6, paddingVertical: 4, gap: 4 },
  findBar: { minHeight: 28, flexDirection: "row", alignItems: "center", gap: 6 },
  findInput: { flex: 1, fontFamily: mono, fontSize: 12, paddingVertical: 4, paddingHorizontal: 4, borderWidth: 1 },
  findCount: { fontFamily: mono, fontSize: 11, minWidth: 22, textAlign: "right" },
  caseToggle: { paddingHorizontal: 6, paddingVertical: 3, borderWidth: 1 },
  caseToggleText: { fontFamily: "Inter_700Bold", fontSize: 10 },
  replaceButton: { paddingHorizontal: 8, paddingVertical: 4 },
  replaceButtonText: { fontFamily: "Inter_500Medium", fontSize: 11 },
  editorScroll: { flex: 1 },
  editorScrollContent: { minHeight: "100%" },
  editorRow: { flexDirection: "row", minHeight: 360 },
  gutter: { borderRightWidth: 1, paddingHorizontal: 6, paddingTop: 8, alignItems: "flex-end", minWidth: 40 },
  gutterText: { fontFamily: mono, fontSize: 12, lineHeight: 18 },
  editorInput: { flex: 1, minHeight: 360, padding: 8, fontFamily: mono, fontSize: 13, lineHeight: 18 },
  syntaxPreview: { marginHorizontal: 0, marginTop: 0, borderTopWidth: 1, padding: 8, gap: 0 },
  syntaxTitle: { fontFamily: "Inter_500Medium", fontSize: 10, marginBottom: 4, opacity: 0.7 },
  syntaxPreviewLine: { flexDirection: "row", gap: 6 },
  syntaxLineNumber: { fontFamily: mono, minWidth: 24, textAlign: "right", fontSize: 11, lineHeight: 16 },
  syntaxLine: { fontFamily: mono, fontSize: 11, lineHeight: 16 },
  matchesPanel: { borderTopWidth: 1, paddingHorizontal: 8, paddingVertical: 4, gap: 2 },
  matchLine: { fontFamily: mono, fontSize: 11 },
  compareWorkspace: { flex: 1 },
  compareToolbar: { borderBottomWidth: 1, paddingHorizontal: 6, paddingVertical: 4, gap: 4 },
  compareSummary: { fontFamily: "Inter_500Medium", fontSize: 11 },
  compareSelector: { gap: 4, paddingRight: 4 },
  compareDocPill: { borderWidth: 1, paddingHorizontal: 6, paddingVertical: 3, maxWidth: 145 },
  compareDocText: { fontFamily: "Inter_500Medium", fontSize: 11 },
  comparePane: { flex: 1, borderBottomWidth: 1 },
  comparePaneHeader: { borderBottomWidth: 1, paddingHorizontal: 6, paddingVertical: 3 },
  comparePaneTitle: { fontFamily: "Inter_500Medium", fontSize: 11 },
  compareScroll: { flex: 1 },
  compareLine: { flexDirection: "row", alignItems: "flex-start", minHeight: 18, borderBottomWidth: StyleSheet.hairlineWidth },
  compareMarker: { fontFamily: mono, width: 16, textAlign: "center", fontSize: 11, lineHeight: 16 },
  compareLineNo: { fontFamily: mono, width: 30, textAlign: "right", paddingRight: 4, fontSize: 11, lineHeight: 16 },
  compareCodeCell: { flex: 1, paddingRight: 4 },
  compareEmpty: { margin: 8, padding: 8, gap: 2 },
  compareEmptyTitle: { fontFamily: "Inter_500Medium", fontSize: 12 },
  compareEmptyText: { fontFamily: "Inter_500Medium", fontSize: 11, lineHeight: 16 },
  statusBar: { borderTopWidth: 1, minHeight: 22, paddingHorizontal: 6, flexDirection: "row", alignItems: "center", gap: 6 },
  statusSep: { width: 1, height: 12 },
  statusSpacer: { flex: 1 },
  statusText: { fontFamily: mono, fontSize: 11 },
  menuBar: { flexDirection: "row", alignItems: "stretch", borderBottomWidth: 1, paddingHorizontal: 2, height: 24 },
  menuItem: { paddingHorizontal: 8, justifyContent: "center", height: 22, marginVertical: 1 },
  menuItemText: { fontFamily: "Inter_500Medium", fontSize: 12 },
  menuOverlay: { ...StyleSheet.absoluteFillObject, zIndex: 100 },
  menuDropdown: { position: "absolute", top: 50, minWidth: 220, borderWidth: 1, paddingVertical: 4 },
  dropdownItem: { paddingHorizontal: 8, paddingVertical: 6, gap: 1 },
  dropdownItemRow: { flexDirection: "row", alignItems: "flex-start", gap: 6 },
  dropdownCheck: { fontFamily: mono, fontSize: 12, width: 12, textAlign: "center" },
  dropdownLabel: { fontFamily: "Inter_500Medium", fontSize: 12 },
  dropdownHint: { fontFamily: "Inter_400Regular", fontSize: 10 },
  dropdownSeparator: { height: StyleSheet.hairlineWidth, marginVertical: 4 },
  modalBackdrop: { flex: 1, alignItems: "center", justifyContent: "center", padding: 20 },
  modalCard: { width: "100%", maxWidth: 380, borderWidth: 1 },
  modalHeader: { flexDirection: "row", alignItems: "center", paddingHorizontal: 8, height: 28, borderBottomWidth: 1 },
  modalTitle: { flex: 1, fontFamily: "Inter_700Bold", fontSize: 13 },
  modalClose: { width: 20, height: 20, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  modalCloseText: { fontFamily: "Inter_700Bold", fontSize: 14, lineHeight: 14 },
  modalBody: { padding: 12, gap: 6 },
  modalSection: { fontFamily: "Inter_700Bold", fontSize: 11, marginBottom: 4, textTransform: "uppercase", letterSpacing: 0.6 },
  modalNote: { fontFamily: "Inter_400Regular", fontSize: 11, marginTop: 8 },
  prefRow: { flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 8, paddingVertical: 8, borderWidth: 1 },
  radio: { width: 14, height: 14, borderRadius: 7, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  radioDot: { width: 6, height: 6, borderRadius: 3 },
  prefRowLabel: { fontFamily: "Inter_500Medium", fontSize: 12 },
  prefRowHint: { fontFamily: "Inter_400Regular", fontSize: 10, marginTop: 1 },
  aboutBig: { fontFamily: "Inter_700Bold", fontSize: 16, marginBottom: 4 },
  aboutText: { fontFamily: "Inter_400Regular", fontSize: 12, lineHeight: 16 },
  mousePointer: { position: "absolute", width: 36, height: 36, alignItems: "center", justifyContent: "center", zIndex: 200 },
  mousePointerDot: { position: "absolute", width: 4, height: 4, borderRadius: 2, top: 14, left: 14 },
  clickRipple: { position: "absolute", width: 36, height: 36, borderRadius: 18, borderWidth: 2, zIndex: 199 },
  mousePad: { position: "absolute", right: 12, bottom: 24, padding: 4, borderWidth: 1, gap: 3, zIndex: 201 },
  mousePadRow: { flexDirection: "row", gap: 3 },
  mousePadCell: { width: 28, height: 28 },
  mousePadKey: { width: 28, height: 28, alignItems: "center", justifyContent: "center", borderWidth: 1 },
  mousePadClick: { width: 28, height: 28, alignItems: "center", justifyContent: "center", borderWidth: 1 },
  mousePadClickText: { fontFamily: "Inter_700Bold", fontSize: 9 },
});
