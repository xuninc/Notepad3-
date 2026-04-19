import { Feather, Ionicons } from "@expo/vector-icons";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import { useMemo, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
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

function getMatches(body: string, query: string) {
  if (!query.trim()) return 0;
  return body.toLowerCase().split(query.trim().toLowerCase()).length - 1;
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
  const [zenMode, setZenMode] = useState(false);
  const stats = getStats(activeNote.body);
  const matches = getMatches(activeNote.body, findQuery);
  const highlightedPreview = findQuery.trim()
    ? activeNote.body
        .split("\n")
        .map((line, index) => ({ line, index: index + 1 }))
        .filter(({ line }) => line.toLowerCase().includes(findQuery.trim().toLowerCase()))
        .slice(0, 3)
    : [];

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
            <View style={[styles.findBar, { borderColor: colors.border }]}>
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
              <Text style={[styles.findCount, { color: colors.mutedForeground }]}>{matches} matches</Text>
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
  findBar: {
    minHeight: 48,
    borderBottomWidth: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingHorizontal: 14,
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