import { Feather, Ionicons } from "@expo/vector-icons";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import { useMemo, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
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

import { NoteDocument, useNotes } from "@/context/NotesContext";
import { useColors } from "@/hooks/useColors";

function formatTime(value: number) {
  const formatter = new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
  return formatter.format(new Date(value));
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
  return {
    line: lines.length,
    column: (lines[lines.length - 1]?.length ?? 0) + 1,
  };
}

function getLineRange(body: string, index: number) {
  const start = body.lastIndexOf("\n", Math.max(0, index - 1)) + 1;
  const rawEnd = body.indexOf("\n", index);
  const end = rawEnd === -1 ? body.length : rawEnd;
  return { start, end };
}

function compareDocuments(left: NoteDocument, right?: NoteDocument) {
  if (!right) {
    return { rows: [], added: 0, removed: 0, changed: 0, same: 0 };
  }
  const leftLines = left.body.split("\n");
  const rightLines = right.body.split("\n");
  const total = Math.max(leftLines.length, rightLines.length);
  const rows = Array.from({ length: total }, (_, index) => {
    const leftText = leftLines[index];
    const rightText = rightLines[index];
    const status =
      leftText === rightText
        ? "same"
        : leftText === undefined
          ? "added"
          : rightText === undefined
            ? "removed"
            : "changed";
    return {
      line: index + 1,
      leftText: leftText ?? "",
      rightText: rightText ?? "",
      status,
    };
  });
  return {
    rows,
    added: rows.filter((row) => row.status === "added").length,
    removed: rows.filter((row) => row.status === "removed").length,
    changed: rows.filter((row) => row.status === "changed").length,
    same: rows.filter((row) => row.status === "same").length,
  };
}

function IconButton({
  icon,
  onPress,
  color,
  disabled,
}: {
  icon: keyof typeof Feather.glyphMap;
  onPress: () => void;
  color: string;
  disabled?: boolean;
}) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [styles.iconButton, { opacity: disabled ? 0.35 : pressed ? 0.55 : 1 }]}
      testID={`button-${icon}`}
    >
      <Feather name={icon} size={21} color={color} />
    </Pressable>
  );
}

function DocumentTab({ item, active }: { item: NoteDocument; active: boolean }) {
  const colors = useColors();
  const { setActiveId } = useNotes();
  return (
    <Pressable
      onPress={() => setActiveId(item.id)}
      style={({ pressed }) => [
        styles.documentTab,
        {
          backgroundColor: active ? colors.secondary : colors.card,
          borderColor: active ? colors.secondary : colors.border,
          opacity: pressed ? 0.72 : 1,
        },
      ]}
      testID={`note-tab-${item.id}`}
    >
      <Text numberOfLines={1} style={[styles.documentTabTitle, { color: active ? colors.secondaryForeground : colors.foreground }]}>
        {item.title}
      </Text>
      <Text style={[styles.documentTabMeta, { color: active ? colors.secondaryForeground : colors.mutedForeground }]}>{getStats(item.body).lines} lines</Text>
    </Pressable>
  );
}

function ToolChip({
  icon,
  label,
  onPress,
  active,
}: {
  icon: keyof typeof Feather.glyphMap;
  label: string;
  onPress: () => void;
  active?: boolean;
}) {
  const colors = useColors();
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.toolChip,
        {
          backgroundColor: active ? colors.secondary : colors.card,
          borderColor: active ? colors.secondary : colors.border,
          opacity: pressed ? 0.7 : 1,
        },
      ]}
      testID={`tool-${label}`}
    >
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
        <Text key={line} style={[styles.gutterText, { color: colors.mutedForeground }]}>
          {line}
        </Text>
      ))}
    </View>
  );
}

export default function PocketPadScreen() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const { notes, activeNote, activeId, isLoaded, createNote, updateActiveNote, deleteActiveNote, duplicateActiveNote } = useNotes();
  const [findOpen, setFindOpen] = useState(false);
  const [findQuery, setFindQuery] = useState("");
  const [replaceOpen, setReplaceOpen] = useState(false);
  const [replaceText, setReplaceText] = useState("");
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);
  const [compareId, setCompareId] = useState<string | null>(null);
  const [zenMode, setZenMode] = useState(false);
  const [selection, setSelection] = useState({ start: 0, end: 0 });
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
        .filter(({ line }) => {
          const haystack = caseSensitive ? line : line.toLowerCase();
          const needle = caseSensitive ? findQuery.trim() : findQuery.trim().toLowerCase();
          return haystack.includes(needle);
        })
        .slice(0, 3)
    : [];

  const handleSelectionChange = (event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => {
    setSelection(event.nativeEvent.selection);
  };

  const insertTextAtSelection = (value: string) => {
    const nextBody = `${activeNote.body.slice(0, selection.start)}${value}${activeNote.body.slice(selection.end)}`;
    updateActiveNote({ body: nextBody });
    const nextIndex = selection.start + value.length;
    setSelection({ start: nextIndex, end: nextIndex });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const replaceAll = () => {
    if (!findQuery.trim()) return;
    const nextBody = caseSensitive
      ? activeNote.body.split(findQuery.trim()).join(replaceText)
      : activeNote.body.replace(new RegExp(escapeRegExp(findQuery.trim()), "gi"), replaceText);
    updateActiveNote({ body: nextBody });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const duplicateCurrentLine = () => {
    const range = getLineRange(activeNote.body, selection.start);
    const line = activeNote.body.slice(range.start, range.end);
    const insertion = range.end === activeNote.body.length ? `\n${line}` : `\n${line}`;
    const nextBody = `${activeNote.body.slice(0, range.end)}${insertion}${activeNote.body.slice(range.end)}`;
    updateActiveNote({ body: nextBody });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const deleteCurrentLine = () => {
    const range = getLineRange(activeNote.body, selection.start);
    const removeEnd = activeNote.body[range.end] === "\n" ? range.end + 1 : range.end;
    const nextBody = `${activeNote.body.slice(0, range.start)}${activeNote.body.slice(removeEnd)}`;
    updateActiveNote({ body: nextBody });
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
              <Text style={[styles.title, { color: colors.foreground }]}>Mobile text bench</Text>
            </View>
            <View style={styles.actions}>
              <IconButton icon="search" color={colors.foreground} onPress={() => setFindOpen((current) => !current)} />
              <IconButton
                icon="repeat"
                color={replaceOpen ? colors.primary : colors.foreground}
                onPress={() => {
                  setFindOpen(true);
                  setReplaceOpen((current) => !current);
                }}
              />
              <IconButton
                icon="columns"
                color={compareOpen ? colors.primary : colors.foreground}
                onPress={() => {
                  setCompareOpen((current) => !current);
                  if (!compareId && comparableNotes[0]) setCompareId(comparableNotes[0].id);
                }}
              />
              <IconButton icon="copy" color={colors.foreground} onPress={duplicateActiveNote} />
              <IconButton icon="trash-2" color={colors.destructive} onPress={deleteActiveNote} />
              <IconButton icon="plus" color={colors.primary} onPress={createNote} />
            </View>
          </View>
        ) : null}

        {!zenMode ? (
          <FlatList
            horizontal
            data={notes}
            keyExtractor={(item) => item.id}
            renderItem={({ item }) => <DocumentTab item={item} active={item.id === activeId} />}
            style={styles.tabsScroller}
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.tabsList}
            scrollEnabled={notes.length > 0}
          />
        ) : null}

        {!zenMode ? (
          <ScrollView horizontal style={styles.toolRailScroller} showsHorizontalScrollIndicator={false} contentContainerStyle={styles.toolRail}>
            <ToolChip icon="clock" label="Stamp" onPress={() => insertTextAtSelection(new Date().toLocaleString())} />
            <ToolChip icon="copy" label="Dup line" onPress={duplicateCurrentLine} />
            <ToolChip icon="scissors" label="Cut line" onPress={deleteCurrentLine} />
            <ToolChip icon="list" label="Sort" onPress={sortLines} />
            <ToolChip icon="align-left" label="Trim" onPress={trimTrailingSpaces} />
            <ToolChip icon="type" label="Case" onPress={() => setCaseSensitive((current) => !current)} active={caseSensitive} />
            <ToolChip
              icon="columns"
              label="Compare"
              active={compareOpen}
              onPress={() => {
                setCompareOpen((current) => !current);
                if (!compareId && comparableNotes[0]) setCompareId(comparableNotes[0].id);
              }}
            />
          </ScrollView>
        ) : null}

        <View style={[styles.editorShell, { backgroundColor: colors.editorBackground, borderColor: colors.border, shadowColor: colors.foreground }]}>
          <View style={[styles.fileHeader, { borderColor: colors.border }]}>
            <View style={styles.fileTitleWrap}>
              <Ionicons name="document-text-outline" size={20} color={colors.primary} />
              <TextInput
                value={activeNote.title}
                onChangeText={(title) => updateActiveNote({ title })}
                style={[styles.fileTitleInput, { color: colors.foreground }]}
                placeholder="filename.txt"
                placeholderTextColor={colors.mutedForeground}
                testID="filename-input"
              />
            </View>
            <View style={styles.fileHeaderActions}>
              {(["Plain", "Markdown", "Code"] as const).map((language) => (
                <Pressable
                  key={language}
                  onPress={() => {
                    Haptics.selectionAsync();
                    updateActiveNote({ language });
                  }}
                  style={({ pressed }) => [
                    styles.languagePill,
                    {
                      backgroundColor: activeNote.language === language ? colors.primary : colors.muted,
                      opacity: pressed ? 0.7 : 1,
                    },
                  ]}
                  testID={`language-${language}`}
                >
                  <Text style={[styles.languageText, { color: activeNote.language === language ? colors.primaryForeground : colors.mutedForeground }]}>{language}</Text>
                </Pressable>
              ))}
              <IconButton icon={zenMode ? "minimize-2" : "maximize-2"} color={colors.accent} onPress={() => setZenMode((current) => !current)} />
            </View>
          </View>

          {findOpen && !zenMode ? (
            <View style={[styles.findPanel, { borderColor: colors.border }]}>
              <View style={styles.findBar}>
                <Feather name="search" size={17} color={colors.mutedForeground} />
                <TextInput
                  value={findQuery}
                  onChangeText={setFindQuery}
                  style={[styles.findInput, { color: colors.foreground }]}
                  placeholder="Find in document"
                  placeholderTextColor={colors.mutedForeground}
                  autoCapitalize="none"
                  testID="find-input"
                />
                <Pressable
                  onPress={() => setCaseSensitive((current) => !current)}
                  style={[styles.caseToggle, { backgroundColor: caseSensitive ? colors.primary : colors.muted }]}
                  testID="case-toggle"
                >
                  <Text style={[styles.caseToggleText, { color: caseSensitive ? colors.primaryForeground : colors.mutedForeground }]}>Aa</Text>
                </Pressable>
                <Text style={[styles.findCount, { color: colors.mutedForeground }]}>{matches}</Text>
              </View>
              {replaceOpen ? (
                <View style={styles.findBar}>
                  <Feather name="repeat" size={17} color={colors.mutedForeground} />
                  <TextInput
                    value={replaceText}
                    onChangeText={setReplaceText}
                    style={[styles.findInput, { color: colors.foreground }]}
                    placeholder="Replace with"
                    placeholderTextColor={colors.mutedForeground}
                    autoCapitalize="none"
                    testID="replace-input"
                  />
                  <Pressable
                    onPress={replaceAll}
                    disabled={!findQuery.trim()}
                    style={({ pressed }) => [
                      styles.replaceButton,
                      {
                        backgroundColor: colors.secondary,
                        opacity: !findQuery.trim() ? 0.35 : pressed ? 0.7 : 1,
                      },
                    ]}
                    testID="replace-all"
                  >
                    <Text style={[styles.replaceButtonText, { color: colors.secondaryForeground }]}>All</Text>
                  </Pressable>
                </View>
              ) : null}
            </View>
          ) : null}

          {compareOpen && !zenMode ? (
            <View style={[styles.comparePanel, { borderColor: colors.border }]}>
              <View style={styles.compareHeader}>
                <View style={styles.compareTitleWrap}>
                  <Feather name="columns" size={17} color={colors.primary} />
                  <Text style={[styles.compareTitle, { color: colors.foreground }]}>Compare with</Text>
                </View>
                <Text style={[styles.compareSummary, { color: colors.mutedForeground }]}>
                  {comparison.changed} changed · {comparison.added} added · {comparison.removed} removed
                </Text>
              </View>
              {comparableNotes.length === 0 ? (
                <View style={[styles.compareEmpty, { backgroundColor: colors.muted }]}>
                  <Text style={[styles.compareEmptyTitle, { color: colors.foreground }]}>Create or duplicate a document to compare.</Text>
                  <Text style={[styles.compareEmptyText, { color: colors.mutedForeground }]}>Use the copy button to make a version, edit it, then compare the two files.</Text>
                </View>
              ) : (
                <>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.compareSelector}>
                    {comparableNotes.map((note) => {
                      const selected = note.id === compareNote?.id;
                      return (
                        <Pressable
                          key={note.id}
                          onPress={() => {
                            setCompareId(note.id);
                            Haptics.selectionAsync();
                          }}
                          style={({ pressed }) => [
                            styles.compareDocPill,
                            {
                              backgroundColor: selected ? colors.secondary : colors.muted,
                              opacity: pressed ? 0.7 : 1,
                            },
                          ]}
                          testID={`compare-${note.id}`}
                        >
                          <Text numberOfLines={1} style={[styles.compareDocText, { color: selected ? colors.secondaryForeground : colors.foreground }]}>
                            {note.title}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </ScrollView>
                  <ScrollView style={styles.diffList} nestedScrollEnabled showsVerticalScrollIndicator={false}>
                    {comparison.rows
                      .filter((row) => row.status !== "same")
                      .slice(0, 40)
                      .map((row) => {
                        const tone =
                          row.status === "added"
                            ? colors.success
                            : row.status === "removed"
                              ? colors.destructive
                              : colors.accent;
                        return (
                          <View key={`${row.line}-${row.status}`} style={[styles.diffRow, { borderColor: colors.border, backgroundColor: colors.muted }]}>
                            <Text style={[styles.diffLineNumber, { color: tone }]}>L{row.line}</Text>
                            <View style={styles.diffColumns}>
                              <Text numberOfLines={2} style={[styles.diffText, { color: colors.foreground }]}>
                                {row.leftText || "∅"}
                              </Text>
                              <Text numberOfLines={2} style={[styles.diffText, { color: colors.foreground }]}>
                                {row.rightText || "∅"}
                              </Text>
                            </View>
                          </View>
                        );
                      })}
                    {comparison.rows.some((row) => row.status !== "same") ? null : (
                      <View style={[styles.compareEmpty, { backgroundColor: colors.muted }]}>
                        <Text style={[styles.compareEmptyTitle, { color: colors.foreground }]}>No differences found.</Text>
                        <Text style={[styles.compareEmptyText, { color: colors.mutedForeground }]}>These two documents match line-for-line.</Text>
                      </View>
                    )}
                  </ScrollView>
                </>
              )}
            </View>
          ) : null}

          <ScrollView
            style={styles.editorScroll}
            contentContainerStyle={styles.editorScrollContent}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.editorRow}>
              <EditorGutter lineCount={stats.lines} />
              <TextInput
                value={activeNote.body}
                onChangeText={(body) => updateActiveNote({ body })}
                multiline
                textAlignVertical="top"
                autoCapitalize="none"
                autoCorrect={false}
                spellCheck={false}
                style={[styles.editorInput, { color: colors.foreground }]}
                placeholder="Start typing..."
                placeholderTextColor={colors.mutedForeground}
                selection={selection}
                onSelectionChange={handleSelectionChange}
                testID="editor-input"
              />
            </View>
          </ScrollView>

          {highlightedPreview.length > 0 && !zenMode ? (
            <View style={[styles.matchesPanel, { borderColor: colors.border }]}>
              {highlightedPreview.map(({ line, index }) => (
                <Text key={`${index}-${line}`} numberOfLines={1} style={[styles.matchLine, { color: colors.mutedForeground }]}>
                  L{index}: {line.trim()}
                </Text>
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

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flex: 1,
    paddingHorizontal: 16,
    gap: 12,
  },
  loading: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
  },
  kicker: {
    fontFamily: "Inter_700Bold",
    fontSize: 12,
    letterSpacing: 1.4,
    textTransform: "uppercase",
  },
  title: {
    fontFamily: "Inter_700Bold",
    fontSize: 25,
    letterSpacing: -0.7,
  },
  actions: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  iconButton: {
    alignItems: "center",
    justifyContent: "center",
    minHeight: 38,
    minWidth: 34,
  },
  tabsList: {
    gap: 8,
    paddingRight: 12,
  },
  tabsScroller: {
    flexGrow: 0,
    maxHeight: 66,
  },
  toolRailScroller: {
    flexGrow: 0,
    maxHeight: 42,
  },
  toolRail: {
    gap: 8,
    paddingRight: 12,
  },
  toolChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 11,
    paddingVertical: 8,
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  toolChipText: {
    fontFamily: "Inter_700Bold",
    fontSize: 12,
  },
  documentTab: {
    width: 128,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 3,
  },
  documentTabTitle: {
    fontFamily: "Inter_700Bold",
    fontSize: 13,
  },
  documentTabMeta: {
    fontFamily: "Inter_500Medium",
    fontSize: 11,
  },
  editorShell: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 26,
    overflow: "hidden",
    shadowOpacity: 0.12,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 16 },
    elevation: 4,
  },
  fileHeader: {
    borderBottomWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 10,
  },
  fileTitleWrap: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  fileTitleInput: {
    flex: 1,
    fontFamily: "Inter_700Bold",
    fontSize: 18,
    paddingVertical: 0,
  },
  fileHeaderActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  languagePill: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  languageText: {
    fontFamily: "Inter_700Bold",
    fontSize: 11,
  },
  findPanel: {
    borderBottomWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 8,
    gap: 7,
  },
  findBar: {
    minHeight: 36,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  findInput: {
    flex: 1,
    fontFamily: "Inter_500Medium",
    fontSize: 15,
    paddingVertical: 8,
  },
  findCount: {
    fontFamily: "Inter_600SemiBold",
    fontSize: 12,
    minWidth: 22,
    textAlign: "right",
  },
  caseToggle: {
    borderRadius: 9,
    paddingHorizontal: 8,
    paddingVertical: 5,
  },
  caseToggleText: {
    fontFamily: "Inter_700Bold",
    fontSize: 11,
  },
  replaceButton: {
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  replaceButtonText: {
    fontFamily: "Inter_700Bold",
    fontSize: 12,
  },
  editorScroll: {
    flex: 1,
  },
  editorScrollContent: {
    minHeight: "100%",
  },
  editorRow: {
    flexDirection: "row",
    minHeight: 420,
  },
  gutter: {
    borderRightWidth: 1,
    paddingHorizontal: 8,
    paddingTop: 14,
    alignItems: "flex-end",
    minWidth: 46,
  },
  gutterText: {
    fontFamily: Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" }),
    fontSize: 14,
    lineHeight: 24,
  },
  editorInput: {
    flex: 1,
    minHeight: 420,
    padding: 14,
    fontFamily: Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" }),
    fontSize: 15,
    lineHeight: 24,
  },
  matchesPanel: {
    borderTopWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
    gap: 4,
  },
  matchLine: {
    fontFamily: "Inter_500Medium",
    fontSize: 12,
  },
  comparePanel: {
    borderBottomWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 10,
    gap: 9,
    maxHeight: 250,
  },
  compareHeader: {
    gap: 4,
  },
  compareTitleWrap: {
    flexDirection: "row",
    alignItems: "center",
    gap: 7,
  },
  compareTitle: {
    fontFamily: "Inter_700Bold",
    fontSize: 14,
  },
  compareSummary: {
    fontFamily: "Inter_600SemiBold",
    fontSize: 11,
  },
  compareSelector: {
    gap: 8,
    paddingRight: 12,
  },
  compareDocPill: {
    borderRadius: 999,
    paddingHorizontal: 11,
    paddingVertical: 7,
    maxWidth: 140,
  },
  compareDocText: {
    fontFamily: "Inter_700Bold",
    fontSize: 12,
  },
  compareEmpty: {
    borderRadius: 14,
    padding: 12,
    gap: 3,
  },
  compareEmptyTitle: {
    fontFamily: "Inter_700Bold",
    fontSize: 13,
  },
  compareEmptyText: {
    fontFamily: "Inter_500Medium",
    fontSize: 12,
    lineHeight: 17,
  },
  diffList: {
    maxHeight: 118,
  },
  diffRow: {
    borderWidth: 1,
    borderRadius: 12,
    padding: 8,
    marginBottom: 6,
    flexDirection: "row",
    gap: 8,
  },
  diffLineNumber: {
    fontFamily: Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" }),
    fontSize: 12,
    minWidth: 30,
  },
  diffColumns: {
    flex: 1,
    flexDirection: "row",
    gap: 8,
  },
  diffText: {
    flex: 1,
    fontFamily: Platform.select({ ios: "Menlo", android: "monospace", default: "monospace" }),
    fontSize: 12,
    lineHeight: 16,
  },
  statusBar: {
    borderTopWidth: 1,
    minHeight: 42,
    paddingHorizontal: 14,
    flexDirection: "row",
    alignItems: "center",
    flexWrap: "wrap",
    columnGap: 12,
    rowGap: 2,
  },
  statusText: {
    fontFamily: "Inter_600SemiBold",
    fontSize: 11,
  },
});