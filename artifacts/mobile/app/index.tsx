import { Feather, Ionicons } from "@expo/vector-icons";
import * as DocumentPicker from "expo-document-picker";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import { useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  NativeScrollEvent,
  NativeSyntheticEvent,
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
import { useColors } from "@/hooks/useColors";

type DiffStatus = "same" | "added" | "removed" | "changed";
type DiffRow = { line: number; leftText: string; rightText: string; status: DiffStatus };
type Token = { text: string; kind: "plain" | "keyword" | "register" | "number" | "string" | "comment" | "label" | "operator" };

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
      return colors.secondary;
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

function IconButton({ icon, onPress, color, disabled }: { icon: keyof typeof Feather.glyphMap; onPress: () => void; color: string; disabled?: boolean }) {
  return (
    <Pressable disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.iconButton, { opacity: disabled ? 0.35 : pressed ? 0.55 : 1 }]} testID={`button-${icon}`}>
      <Feather name={icon} size={21} color={color} />
    </Pressable>
  );
}

function DocumentTab({ item, active }: { item: NoteDocument; active: boolean }) {
  const colors = useColors();
  const { setActiveId } = useNotes();
  return (
    <Pressable onPress={() => setActiveId(item.id)} style={({ pressed }) => [styles.documentTab, { backgroundColor: active ? colors.secondary : colors.card, borderColor: active ? colors.secondary : colors.border, opacity: pressed ? 0.72 : 1 }]} testID={`note-tab-${item.id}`}>
      <Text numberOfLines={1} style={[styles.documentTabTitle, { color: active ? colors.secondaryForeground : colors.foreground }]}>{item.title}</Text>
      <Text style={[styles.documentTabMeta, { color: active ? colors.secondaryForeground : colors.mutedForeground }]}>{getStats(item.body).lines} lines</Text>
    </Pressable>
  );
}

function ToolChip({ icon, label, onPress, active }: { icon: keyof typeof Feather.glyphMap; label: string; onPress: () => void; active?: boolean }) {
  const colors = useColors();
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.toolChip, { backgroundColor: active ? colors.secondary : colors.card, borderColor: active ? colors.secondary : colors.border, opacity: pressed ? 0.7 : 1 }]} testID={`tool-${label}`}>
      <Feather name={icon} size={14} color={active ? colors.secondaryForeground : colors.primary} />
      <Text style={[styles.toolChipText, { color: active ? colors.secondaryForeground : colors.foreground }]}>{label}</Text>
    </Pressable>
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

export default function PocketPadScreen() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const { notes, activeNote, activeId, isLoaded, createNote, importNote, updateActiveNote, deleteActiveNote, duplicateActiveNote } = useNotes();
  const [findOpen, setFindOpen] = useState(false);
  const [findQuery, setFindQuery] = useState("");
  const [replaceOpen, setReplaceOpen] = useState(false);
  const [replaceText, setReplaceText] = useState("");
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);
  const [compareId, setCompareId] = useState<string | null>(null);
  const [zenMode, setZenMode] = useState(false);
  const [selection, setSelection] = useState({ start: 0, end: 0 });
  const [importError, setImportError] = useState("");
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

  if (!isLoaded) {
    return (
      <View style={[styles.loading, { backgroundColor: colors.background }]}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  return (
    <LinearGradient colors={[colors.background, colors.card]} style={styles.screen}>
      <View style={[styles.container, { paddingTop: Platform.OS === "web" ? 67 : insets.top + 10, paddingBottom: Platform.OS === "web" ? 34 : insets.bottom + 10 }]}>
        {!zenMode ? (
          <View style={styles.topBar}>
            <View>
              <Text style={[styles.kicker, { color: colors.primary }]}>PocketPad++</Text>
              <Text style={[styles.title, { color: colors.foreground }]}>Notepad2 shell, ++ tools</Text>
            </View>
            <View style={styles.actions}>
              <IconButton icon="upload" color={colors.foreground} onPress={importFromFiles} />
              <IconButton icon="search" color={colors.foreground} onPress={() => setFindOpen((current) => !current)} />
              <IconButton icon="repeat" color={replaceOpen ? colors.primary : colors.foreground} onPress={() => { setFindOpen(true); setReplaceOpen((current) => !current); }} />
              <IconButton icon="columns" color={compareOpen ? colors.primary : colors.foreground} onPress={() => { setCompareOpen((current) => !current); if (!compareId && comparableNotes[0]) setCompareId(comparableNotes[0].id); }} />
              <IconButton icon="copy" color={colors.foreground} onPress={duplicateActiveNote} />
              <IconButton icon="trash-2" color={colors.destructive} onPress={deleteActiveNote} />
              <IconButton icon="plus" color={colors.primary} onPress={createNote} />
            </View>
          </View>
        ) : null}

        {!zenMode ? (
          <FlatList horizontal data={notes} keyExtractor={(item) => item.id} renderItem={({ item }) => <DocumentTab item={item} active={item.id === activeId} />} style={styles.tabsScroller} showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tabsList} scrollEnabled={notes.length > 0} />
        ) : null}

        {!zenMode ? (
          <ScrollView horizontal style={styles.toolRailScroller} showsHorizontalScrollIndicator={false} contentContainerStyle={styles.toolRail}>
            <ToolChip icon="upload" label="Files" onPress={importFromFiles} />
            <ToolChip icon="clock" label="Stamp" onPress={() => insertTextAtSelection(new Date().toLocaleString())} />
            <ToolChip icon="copy" label="Dup line" onPress={duplicateCurrentLine} />
            <ToolChip icon="scissors" label="Cut line" onPress={deleteCurrentLine} />
            <ToolChip icon="list" label="Sort" onPress={sortLines} />
            <ToolChip icon="align-left" label="Trim" onPress={trimTrailingSpaces} />
            <ToolChip icon="type" label="Case" onPress={() => setCaseSensitive((current) => !current)} active={caseSensitive} />
            <ToolChip icon="columns" label="Compare" active={compareOpen} onPress={() => { setCompareOpen((current) => !current); if (!compareId && comparableNotes[0]) setCompareId(comparableNotes[0].id); }} />
          </ScrollView>
        ) : null}

        {importError ? <Text style={[styles.errorText, { color: colors.destructive }]}>{importError}</Text> : null}

        <View style={[styles.editorShell, { backgroundColor: colors.editorBackground, borderColor: colors.border, shadowColor: colors.foreground }]}>
          <View style={[styles.fileHeader, { borderColor: colors.border }]}>
            <View style={styles.fileTitleWrap}>
              <Ionicons name="document-text-outline" size={20} color={colors.primary} />
              <TextInput value={activeNote.title} onChangeText={(title) => updateActiveNote({ title })} style={[styles.fileTitleInput, { color: colors.foreground }]} placeholder="filename.txt" placeholderTextColor={colors.mutedForeground} testID="filename-input" />
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.languageRail}>
              {languages.map((language) => (
                <Pressable key={language} onPress={() => { Haptics.selectionAsync(); updateActiveNote({ language }); }} style={({ pressed }) => [styles.languagePill, { backgroundColor: activeNote.language === language ? colors.primary : colors.muted, opacity: pressed ? 0.7 : 1 }]} testID={`language-${language}`}>
                  <Text style={[styles.languageText, { color: activeNote.language === language ? colors.primaryForeground : colors.mutedForeground }]}>{language}</Text>
                </Pressable>
              ))}
              <IconButton icon={zenMode ? "minimize-2" : "maximize-2"} color={colors.accent} onPress={() => setZenMode((current) => !current)} />
            </ScrollView>
          </View>

          {findOpen && !zenMode ? (
            <View style={[styles.findPanel, { borderColor: colors.border }]}> 
              <View style={styles.findBar}>
                <Feather name="search" size={17} color={colors.mutedForeground} />
                <TextInput value={findQuery} onChangeText={setFindQuery} style={[styles.findInput, { color: colors.foreground }]} placeholder="Find in document" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="find-input" />
                <Pressable onPress={() => setCaseSensitive((current) => !current)} style={[styles.caseToggle, { backgroundColor: caseSensitive ? colors.primary : colors.muted }]} testID="case-toggle">
                  <Text style={[styles.caseToggleText, { color: caseSensitive ? colors.primaryForeground : colors.mutedForeground }]}>Aa</Text>
                </Pressable>
                <Text style={[styles.findCount, { color: colors.mutedForeground }]}>{matches}</Text>
              </View>
              {replaceOpen ? (
                <View style={styles.findBar}>
                  <Feather name="repeat" size={17} color={colors.mutedForeground} />
                  <TextInput value={replaceText} onChangeText={setReplaceText} style={[styles.findInput, { color: colors.foreground }]} placeholder="Replace with" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="replace-input" />
                  <Pressable onPress={replaceAll} disabled={!findQuery.trim()} style={({ pressed }) => [styles.replaceButton, { backgroundColor: colors.secondary, opacity: !findQuery.trim() ? 0.35 : pressed ? 0.7 : 1 }]} testID="replace-all">
                    <Text style={[styles.replaceButtonText, { color: colors.secondaryForeground }]}>All</Text>
                  </Pressable>
                </View>
              ) : null}
            </View>
          ) : null}

          {compareOpen ? (
            <View style={styles.compareWorkspace}>
              <View style={[styles.compareToolbar, { borderColor: colors.border }]}> 
                <Text style={[styles.compareSummary, { color: colors.foreground }]}>{comparison.similarity}% similar · {comparison.changed} changed · {comparison.added} added · {comparison.removed} removed</Text>
                {comparableNotes.length > 0 ? (
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.compareSelector}>
                    {comparableNotes.map((note) => {
                      const selected = note.id === compareNote?.id;
                      return (
                        <Pressable key={note.id} onPress={() => { setCompareId(note.id); Haptics.selectionAsync(); }} style={({ pressed }) => [styles.compareDocPill, { backgroundColor: selected ? colors.secondary : colors.muted, opacity: pressed ? 0.7 : 1 }]} testID={`compare-${note.id}`}>
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
            <View style={[styles.matchesPanel, { borderColor: colors.border }]}>
              {highlightedPreview.map(({ line, index }) => (
                <Text key={`${index}-${line}`} numberOfLines={1} style={[styles.matchLine, { color: colors.mutedForeground }]}>L{index}: {line.trim()}</Text>
              ))}
            </View>
          ) : null}

          <View style={[styles.statusBar, { borderColor: colors.border }]}> 
            <Text style={[styles.statusText, { color: colors.mutedForeground }]}>{stats.lines} lines</Text>
            <Text style={[styles.statusText, { color: colors.mutedForeground }]}>{stats.words} words</Text>
            <Text style={[styles.statusText, { color: colors.mutedForeground }]}>{stats.chars} chars</Text>
            <Text style={[styles.statusText, { color: colors.mutedForeground }]}>Ln {cursor.line}, Col {cursor.column}</Text>
            {selectedChars > 0 ? <Text style={[styles.statusText, { color: colors.accent }]}>{selectedChars} selected</Text> : null}
            <Text style={[styles.statusText, { color: colors.success }]}>autosaved {formatTime(activeNote.updatedAt)}</Text>
          </View>
        </View>
      </View>
    </LinearGradient>
  );
}

const mono = Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" });

const styles = StyleSheet.create({
  screen: { flex: 1 },
  container: { flex: 1, paddingHorizontal: 16, gap: 10 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center" },
  topBar: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 },
  kicker: { fontFamily: "Inter_700Bold", fontSize: 12, letterSpacing: 1.4, textTransform: "uppercase" },
  title: { fontFamily: "Inter_700Bold", fontSize: 23, letterSpacing: -0.7 },
  actions: { flexDirection: "row", alignItems: "center", gap: 1 },
  iconButton: { alignItems: "center", justifyContent: "center", minHeight: 36, minWidth: 31 },
  tabsList: { gap: 8, paddingRight: 12 },
  tabsScroller: { flexGrow: 0, maxHeight: 62 },
  toolRailScroller: { flexGrow: 0, maxHeight: 42 },
  toolRail: { gap: 8, paddingRight: 12 },
  toolChip: { borderWidth: 1, borderRadius: 5, paddingHorizontal: 11, paddingVertical: 8, flexDirection: "row", alignItems: "center", gap: 6 },
  toolChipText: { fontFamily: "Inter_700Bold", fontSize: 12 },
  documentTab: { width: 128, borderWidth: 1, borderRadius: 5, paddingHorizontal: 12, paddingVertical: 9, gap: 3 },
  documentTabTitle: { fontFamily: "Inter_700Bold", fontSize: 13 },
  documentTabMeta: { fontFamily: "Inter_500Medium", fontSize: 11 },
  errorText: { fontFamily: "Inter_600SemiBold", fontSize: 12 },
  editorShell: { flex: 1, borderWidth: 1, borderRadius: 7, overflow: "hidden", shadowOpacity: 0.08, shadowRadius: 16, shadowOffset: { width: 0, height: 10 }, elevation: 3 },
  fileHeader: { borderBottomWidth: 1, paddingHorizontal: 12, paddingVertical: 10, gap: 8 },
  fileTitleWrap: { flexDirection: "row", alignItems: "center", gap: 8 },
  fileTitleInput: { flex: 1, fontFamily: "Inter_700Bold", fontSize: 18, paddingVertical: 0 },
  languageRail: { flexDirection: "row", alignItems: "center", gap: 6, paddingRight: 8 },
  languagePill: { borderRadius: 4, paddingHorizontal: 9, paddingVertical: 6 },
  languageText: { fontFamily: "Inter_700Bold", fontSize: 11 },
  findPanel: { borderBottomWidth: 1, paddingHorizontal: 12, paddingVertical: 8, gap: 7 },
  findBar: { minHeight: 36, flexDirection: "row", alignItems: "center", gap: 8 },
  findInput: { flex: 1, fontFamily: "Inter_500Medium", fontSize: 15, paddingVertical: 8 },
  findCount: { fontFamily: "Inter_600SemiBold", fontSize: 12, minWidth: 22, textAlign: "right" },
  caseToggle: { borderRadius: 4, paddingHorizontal: 8, paddingVertical: 5 },
  caseToggleText: { fontFamily: "Inter_700Bold", fontSize: 11 },
  replaceButton: { borderRadius: 4, paddingHorizontal: 12, paddingVertical: 7 },
  replaceButtonText: { fontFamily: "Inter_700Bold", fontSize: 12 },
  editorScroll: { flex: 1 },
  editorScrollContent: { minHeight: "100%" },
  editorRow: { flexDirection: "row", minHeight: 360 },
  gutter: { borderRightWidth: 1, paddingHorizontal: 8, paddingTop: 14, alignItems: "flex-end", minWidth: 46 },
  gutterText: { fontFamily: mono, fontSize: 14, lineHeight: 24 },
  editorInput: { flex: 1, minHeight: 360, padding: 14, fontFamily: mono, fontSize: 15, lineHeight: 24 },
  syntaxPreview: { margin: 10, borderWidth: 1, borderRadius: 5, padding: 10, gap: 3 },
  syntaxTitle: { fontFamily: "Inter_700Bold", fontSize: 12, marginBottom: 4 },
  syntaxPreviewLine: { flexDirection: "row", gap: 8 },
  syntaxLineNumber: { fontFamily: mono, minWidth: 28, textAlign: "right", fontSize: 12, lineHeight: 18 },
  syntaxLine: { fontFamily: mono, fontSize: 12, lineHeight: 18 },
  matchesPanel: { borderTopWidth: 1, paddingHorizontal: 14, paddingVertical: 9, gap: 4 },
  matchLine: { fontFamily: "Inter_500Medium", fontSize: 12 },
  compareWorkspace: { flex: 1, gap: 0 },
  compareToolbar: { borderBottomWidth: 1, paddingHorizontal: 12, paddingVertical: 8, gap: 7 },
  compareSummary: { fontFamily: "Inter_700Bold", fontSize: 12 },
  compareSelector: { gap: 8, paddingRight: 12 },
  compareDocPill: { borderRadius: 4, paddingHorizontal: 10, paddingVertical: 7, maxWidth: 145 },
  compareDocText: { fontFamily: "Inter_700Bold", fontSize: 12 },
  comparePane: { flex: 1, borderBottomWidth: 1 },
  comparePaneHeader: { borderBottomWidth: 1, paddingHorizontal: 10, paddingVertical: 6 },
  comparePaneTitle: { fontFamily: "Inter_700Bold", fontSize: 12 },
  compareScroll: { flex: 1 },
  compareLine: { flexDirection: "row", alignItems: "flex-start", minHeight: 24, borderBottomWidth: StyleSheet.hairlineWidth },
  compareMarker: { fontFamily: mono, width: 18, textAlign: "center", fontSize: 12, lineHeight: 22 },
  compareLineNo: { fontFamily: mono, width: 34, textAlign: "right", paddingRight: 6, fontSize: 12, lineHeight: 22 },
  compareCodeCell: { flex: 1, paddingRight: 8 },
  compareEmpty: { margin: 14, borderRadius: 5, padding: 12, gap: 3 },
  compareEmptyTitle: { fontFamily: "Inter_700Bold", fontSize: 13 },
  compareEmptyText: { fontFamily: "Inter_500Medium", fontSize: 12, lineHeight: 17 },
  statusBar: { borderTopWidth: 1, minHeight: 42, paddingHorizontal: 12, flexDirection: "row", alignItems: "center", flexWrap: "wrap", columnGap: 10, rowGap: 2 },
  statusText: { fontFamily: "Inter_600SemiBold", fontSize: 11 },
});
