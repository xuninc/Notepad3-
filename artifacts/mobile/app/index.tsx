import { Feather, Ionicons } from "@expo/vector-icons";
import * as Clipboard from "expo-clipboard";
import * as DocumentPicker from "expo-document-picker";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Dimensions,
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

import { CUSTOM_PALETTE_KEYS, customDefaults, customPaletteLabels, CustomPaletteKey } from "@/constants/colors";
import { detectLanguageFromFileName, NoteDocument, NoteLanguage, useNotes } from "@/context/NotesContext";
import { useTheme } from "@/context/ThemeContext";
import { useColors } from "@/hooks/useColors";

type ThemeChoiceId = "classic" | "light" | "dark" | "retro" | "modern" | "cyberpunk" | "sunset" | "custom" | "system";
type ThemeChoice = { id: ThemeChoiceId; label: string; hint: string };
const themeChoices: ThemeChoice[] = [
  { id: "classic", label: "Classic", hint: "Notepad2 on Windows 7 Aero" },
  { id: "light", label: "Light", hint: "Clean and bright" },
  { id: "dark", label: "Dark", hint: "Easy on the eyes" },
  { id: "retro", label: "Retro", hint: "Windows 95 chrome" },
  { id: "modern", label: "Modern", hint: "Soft, rounded, indigo" },
  { id: "cyberpunk", label: "Cyberpunk", hint: "Neon magenta and cyan" },
  { id: "sunset", label: "Rachel's Sunset", hint: "Orange, turquoise and hot pink" },
  { id: "custom", label: "Custom", hint: "Pick your own colors" },
  { id: "system", label: "Match system", hint: "Follow the iPhone setting" },
];

const customSwatches: string[] = [
  "#ffffff", "#f5f5f5", "#e6e6e6", "#cccccc", "#888888", "#444444", "#1a1a1a", "#000000",
  "#fff6fa", "#ffe8f1", "#ffd6e6", "#ffb3d1", "#ff7aae", "#ff3d8a", "#e0246b", "#a01657",
  "#fff5e6", "#ffd9b3", "#ffb380", "#ff944d", "#ff7a3d", "#e85a1f", "#b3420f", "#7a2a08",
  "#fff9d6", "#fff066", "#ffe029", "#f5c518", "#d4a017", "#a87c10", "#7a5a0a", "#3d2d05",
  "#e6f7e6", "#c7ecc7", "#8fd9b8", "#4ec07d", "#2a9d5a", "#1e7a44", "#155a30", "#0b3a1e",
  "#e6f1fb", "#cfe6df", "#d6ecff", "#a9d2f5", "#5fa8e0", "#2d7dc4", "#1a4f8a", "#0d2e57",
  "#f0e6ff", "#d6c7ff", "#b39bff", "#8a66ff", "#5a3de0", "#3d24a8", "#251466", "#120a33",
  "#3a1a3a", "#5a2a5a", "#6e3a5e", "#1f3a3a", "#3d6e6e", "#4f6e6e", "#1f3a5a", "#0b0820",
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

const MouseOverlay = React.memo(function MouseOverlay({ targetsRef, palette, colors, radius, onClose }: { targetsRef: React.MutableRefObject<Map<string, MouseRect>>; palette: ReturnType<typeof useTheme>["palette"]; colors: ReturnType<typeof useColors>; radius: number; onClose: () => void }) {
  const screen = Dimensions.get("window");
  const [pos, setPos] = useState({ x: Math.round(screen.width / 2), y: Math.round(screen.height / 2) });
  const [ripple, setRipple] = useState<{ x: number; y: number; key: number } | null>(null);
  const [moved, setMoved] = useState(false);
  const [finger, setFinger] = useState<{ x: number; y: number } | null>(null);
  const posRef = useRef(pos);
  posRef.current = pos;
  const lastRef = useRef({ x: 0, y: 0 });
  const movedRef = useRef(false);
  const SENS = 1.8;
  const fireClickAt = useCallback((x: number, y: number) => {
    setRipple({ x, y, key: Date.now() });
    Haptics.selectionAsync();
    const list = Array.from(targetsRef.current.values()).reverse();
    for (const t of list) {
      if (x >= t.x && x <= t.x + t.w && y >= t.y && y <= t.y + t.h) {
        t.onPress();
        return;
      }
    }
  }, [targetsRef]);
  const trackpad = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: () => true,
    onPanResponderGrant: (e) => {
      lastRef.current = { x: 0, y: 0 };
      movedRef.current = false;
      setMoved(false);
      setFinger({ x: e.nativeEvent.locationX, y: e.nativeEvent.locationY });
    },
    onPanResponderMove: (e, g) => {
      const ddx = (g.dx - lastRef.current.x) * SENS;
      const ddy = (g.dy - lastRef.current.y) * SENS;
      lastRef.current = { x: g.dx, y: g.dy };
      if (Math.abs(g.dx) > 4 || Math.abs(g.dy) > 4) {
        if (!movedRef.current) { movedRef.current = true; setMoved(true); }
      }
      setFinger({ x: e.nativeEvent.locationX, y: e.nativeEvent.locationY });
      setPos((c) => {
        const w = Dimensions.get("window");
        return { x: Math.max(0, Math.min(w.width - 1, c.x + ddx)), y: Math.max(0, Math.min(w.height - 1, c.y + ddy)) };
      });
    },
    onPanResponderRelease: (_e, g) => {
      setFinger(null);
      if (!movedRef.current && Math.abs(g.dx) < 4 && Math.abs(g.dy) < 4) {
        const p = posRef.current;
        fireClickAt(p.x, p.y);
      }
    },
    onPanResponderTerminate: () => { setFinger(null); },
  }), [fireClickAt]);
  useEffect(() => {
    if (!ripple) return;
    const t = setTimeout(() => setRipple(null), 380);
    return () => clearTimeout(t);
  }, [ripple]);
  return (
    <>
      {ripple ? <View pointerEvents="none" style={[styles.clickRipple, { left: ripple.x - 18, top: ripple.y - 18, borderColor: colors.primary }]} /> : null}
      <View pointerEvents="none" style={[styles.mousePointer, { left: pos.x - 3, top: pos.y - 3 }]}>
        <Feather name="mouse-pointer" size={22} color={colors.primary} />
      </View>
      <View style={[styles.trackpadCard, { backgroundColor: colors.card, borderColor: colors.primary, borderRadius: radius, overflow: "hidden" }]}>
        <LinearGradient colors={palette.titleGradient} style={styles.trackpadHeader} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }}>
          <Feather name="mouse-pointer" size={12} color={colors.primaryForeground} />
          <Text style={[styles.trackpadHeaderText, { color: colors.primaryForeground }]} numberOfLines={1}>Trackpad · drag here, pointer moves above</Text>
          <Pressable onPress={onClose} style={styles.trackpadClose} testID="mouse-close" hitSlop={8}>
            <Feather name="x" size={14} color={colors.primaryForeground} />
          </Pressable>
        </LinearGradient>
        <View {...trackpad.panHandlers} style={[styles.trackpadSurface, { backgroundColor: colors.muted, borderColor: colors.border }]} testID="trackpad-surface">
          <View pointerEvents="none" style={styles.trackpadGrid}>
            {[0.25, 0.5, 0.75].map((f) => (
              <View key={`h${f}`} style={{ position: "absolute", left: 0, right: 0, top: `${f * 100}%`, height: 1, backgroundColor: colors.foreground }} />
            ))}
            {[0.25, 0.5, 0.75].map((f) => (
              <View key={`v${f}`} style={{ position: "absolute", top: 0, bottom: 0, left: `${f * 100}%`, width: 1, backgroundColor: colors.foreground }} />
            ))}
          </View>
          {finger ? (
            <View pointerEvents="none" style={[styles.trackpadFinger, { left: finger.x - 19, top: finger.y - 19, borderColor: colors.primary, backgroundColor: colors.primary + "33" }]} />
          ) : (
            <View>
              <Text style={[styles.trackpadHint, { color: colors.mutedForeground }]}>Drag anywhere here to move the pointer</Text>
              <Text style={[styles.trackpadHintSub, { color: colors.mutedForeground }]}>Tap = click at pointer · finger stays here</Text>
            </View>
          )}
        </View>
        <View style={styles.trackpadButtons}>
          <Pressable onPress={() => fireClickAt(posRef.current.x, posRef.current.y)} style={({ pressed }) => [styles.trackpadClick, { backgroundColor: colors.primary, borderColor: colors.border, borderRadius: Math.min(radius, 4), opacity: pressed ? 0.75 : 1 }]} testID="trackpad-click">
            <Feather name="mouse-pointer" size={12} color={colors.primaryForeground} />
            <Text style={[styles.trackpadClickText, { color: colors.primaryForeground, marginLeft: 6 }]}>Click at pointer</Text>
          </Pressable>
          <Pressable onPress={onClose} style={({ pressed }) => [styles.trackpadClick, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4), opacity: pressed ? 0.75 : 1, flex: 0, paddingHorizontal: 14 }]} testID="trackpad-close-btn">
            <Text style={[styles.trackpadClickText, { color: colors.foreground }]}>Hide</Text>
          </Pressable>
        </View>
      </View>
    </>
  );
});

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

function IconButton({ id, icon, onPress, color, disabled, label, showLabel, onLongPress }: { id: string; icon: keyof typeof Feather.glyphMap; onPress: () => void; color: string; disabled?: boolean; label?: string; showLabel?: boolean; onLongPress?: (label: string) => void }) {
  const colors = useColors();
  const { radius } = useTheme();
  const handleLong = label && onLongPress ? () => onLongPress(label) : undefined;
  return (
    <MTarget id={id} onPress={onPress}>
      <Pressable
        disabled={disabled}
        onPress={onPress}
        onLongPress={handleLong}
        delayLongPress={400}
        style={({ pressed }) => [styles.iconButton, showLabel ? styles.iconButtonWithLabel : null, { backgroundColor: pressed ? colors.secondary : "transparent", opacity: disabled ? 0.35 : 1, borderRadius: Math.min(radius, 4) }]}
        testID={`button-${icon}`}
        accessibilityRole="button"
        accessibilityLabel={label ?? icon}
      >
        <Feather name={icon} size={16} color={color} />
        {showLabel && label ? (
          <Text numberOfLines={1} style={[styles.iconButtonLabel, { color: colors.foreground }]}>{label}</Text>
        ) : null}
      </Pressable>
    </MTarget>
  );
}

function DocumentTab({ item, active, onLongPress }: { item: NoteDocument; active: boolean; onLongPress: (id: string) => void }) {
  const colors = useColors();
  const { radius } = useTheme();
  const { setActiveId, deleteNote } = useNotes();
  return (
    <View style={[styles.documentTab, { backgroundColor: active ? colors.editorBackground : colors.muted, borderColor: colors.border, borderTopLeftRadius: radius, borderTopRightRadius: radius, borderBottomColor: active ? colors.editorBackground : colors.border }]}>
      <MTarget id={`tab-${item.id}`} onPress={() => setActiveId(item.id)}>
        <Pressable onPress={() => setActiveId(item.id)} onLongPress={() => onLongPress(item.id)} delayLongPress={350} style={({ pressed }) => [styles.documentTabBody, { opacity: pressed ? 0.7 : 1 }]} testID={`note-tab-${item.id}`} accessibilityRole="button" accessibilityLabel={`Document ${item.title}, long press for options`}>
          <Text numberOfLines={1} style={[styles.documentTabTitle, { color: colors.foreground, fontFamily: active ? "Inter_700Bold" : "Inter_500Medium" }]}>{item.title}</Text>
        </Pressable>
      </MTarget>
      <Pressable onPress={() => deleteNote(item.id)} hitSlop={8} style={({ pressed }) => [styles.documentTabClose, { opacity: pressed ? 0.5 : 1 }]} testID={`note-tab-close-${item.id}`} accessibilityRole="button" accessibilityLabel={`Close ${item.title}`}>
        <Feather name="x" size={12} color={colors.mutedForeground} />
      </Pressable>
    </View>
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
  const { preference, setPreference, tabsLayout, setTabsLayout, toolbarLabels, setToolbarLabels, toolbarRows, setToolbarRows, layoutMode, setLayoutMode, customPalette, setCustomColor, resetCustomPalette, palette, radius } = useTheme();
  const isMobile = layoutMode === "mobile";
  const [toolbarTip, setToolbarTip] = useState<string | null>(null);
  const tipTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showTip = useCallback((text: string) => {
    setToolbarTip(text);
    if (tipTimerRef.current) clearTimeout(tipTimerRef.current);
    tipTimerRef.current = setTimeout(() => setToolbarTip(null), 1600);
  }, []);
  useEffect(() => () => { if (tipTimerRef.current) clearTimeout(tipTimerRef.current); }, []);
  const { notes, activeNote, activeId, isLoaded, createNote, importNote, updateActiveNote, deleteActiveNote, duplicateActiveNote, deleteNote, closeOthers, renameNote, duplicateNote, setActiveId } = useNotes();
  const [tabMenuId, setTabMenuId] = useState<string | null>(null);
  const [renameTarget, setRenameTarget] = useState<{ id: string; title: string } | null>(null);
  const [tabListOpen, setTabListOpen] = useState(false);
  const tabMenuNote = notes.find((n) => n.id === tabMenuId) ?? null;
  const [findOpen, setFindOpen] = useState(false);
  const [findQuery, setFindQuery] = useState("");
  const [replaceOpen, setReplaceOpen] = useState(false);
  const [replaceText, setReplaceText] = useState("");
  const [caseSensitive, setCaseSensitive] = useState(false);
  const [wholeWord, setWholeWord] = useState(false);
  const [useWildcards, setUseWildcards] = useState(false);
  const [useRegex, setUseRegex] = useState(false);
  const [pasteError, setPasteError] = useState("");
  const [compareOpen, setCompareOpen] = useState(false);
  const [compareId, setCompareId] = useState<string | null>(null);
  const [zenMode, setZenMode] = useState(false);
  const [readMode, setReadMode] = useState(false);
  const [toolbarOpen, setToolbarOpen] = useState(true);
  const [selection, setSelection] = useState({ start: 0, end: 0 });
  const [importError, setImportError] = useState("");
  const [openMenu, setOpenMenu] = useState<null | "file" | "edit" | "view" | "tools" | "help">(null);
  const [menuBarBottom, setMenuBarBottom] = useState(24);
  const [menuItemLeft, setMenuItemLeft] = useState<Record<string, number>>({});
  const [prefsOpen, setPrefsOpen] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [gotoOpen, setGotoOpen] = useState(false);
  const [gotoValue, setGotoValue] = useState("");
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

  const buildFindRegex = (global: boolean): RegExp | null => {
    const raw = findQuery;
    if (!raw) return null;
    let pattern: string;
    try {
      if (useRegex) {
        pattern = raw;
      } else if (useWildcards) {
        pattern = raw.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".");
      } else {
        pattern = escapeRegExp(raw);
      }
      if (wholeWord) pattern = `\\b(?:${pattern})\\b`;
      const flags = `${global ? "g" : ""}${caseSensitive ? "" : "i"}`;
      return new RegExp(pattern, flags);
    } catch {
      return null;
    }
  };

  const matchInfo = useMemo(() => {
    if (!findQuery) return { count: 0, error: "" };
    const re = buildFindRegex(true);
    if (!re) return { count: 0, error: "Invalid pattern" };
    return { count: (activeNote.body.match(re) || []).length, error: "" };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [findQuery, caseSensitive, wholeWord, useWildcards, useRegex, activeNote.body]);
  const matchesCount = matchInfo.count;
  const findError = matchInfo.error;

  const replaceAll = () => {
    if (!findQuery) return;
    const re = buildFindRegex(true);
    if (!re) return;
    updateActiveNote({ body: activeNote.body.replace(re, replaceText) });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const replaceNext = () => {
    if (!findQuery) return;
    const re = buildFindRegex(true);
    if (!re) return;
    re.lastIndex = selection.start;
    let match = re.exec(activeNote.body);
    if (!match) {
      re.lastIndex = 0;
      match = re.exec(activeNote.body);
    }
    if (!match) return;
    const before = activeNote.body.slice(0, match.index);
    const after = activeNote.body.slice(match.index + match[0].length);
    updateActiveNote({ body: `${before}${replaceText}${after}` });
    const next = match.index + replaceText.length;
    setSelection({ start: next, end: next });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const findNext = () => {
    if (!findQuery) return;
    const re = buildFindRegex(true);
    if (!re) return;
    re.lastIndex = selection.end;
    let match = re.exec(activeNote.body);
    if (!match) {
      re.lastIndex = 0;
      match = re.exec(activeNote.body);
    }
    if (!match) return;
    setSelection({ start: match.index, end: match.index + match[0].length });
    Haptics.selectionAsync();
  };

  const selectAll = () => {
    setSelection({ start: 0, end: activeNote.body.length });
    Haptics.selectionAsync();
  };

  const selectLine = () => {
    const range = getLineRange(activeNote.body, selection.start);
    setSelection({ start: range.start, end: range.end });
    Haptics.selectionAsync();
  };

  const selectParagraph = () => {
    const body = activeNote.body.replace(/\r\n/g, "\n");
    const lines = body.split("\n");
    const isBlank = (line: string) => /^\s*$/.test(line);
    const offsets: number[] = [0];
    for (let i = 0; i < lines.length; i += 1) offsets.push(offsets[i] + lines[i].length + 1);
    const caret = Math.min(selection.start, body.length);
    let lineIdx = 0;
    for (let i = 0; i < lines.length; i += 1) {
      if (caret >= offsets[i] && caret < offsets[i + 1]) { lineIdx = i; break; }
      if (i === lines.length - 1) lineIdx = i;
    }
    if (isBlank(lines[lineIdx])) {
      setSelection({ start: offsets[lineIdx], end: offsets[lineIdx] + lines[lineIdx].length });
      Haptics.selectionAsync();
      return;
    }
    let startLine = lineIdx;
    while (startLine > 0 && !isBlank(lines[startLine - 1])) startLine -= 1;
    let endLine = lineIdx;
    while (endLine < lines.length - 1 && !isBlank(lines[endLine + 1])) endLine += 1;
    const start = offsets[startLine];
    const end = offsets[endLine] + lines[endLine].length;
    setSelection({ start, end });
    Haptics.selectionAsync();
  };

  const copySelection = async () => {
    setPasteError("");
    const text = selection.end > selection.start
      ? activeNote.body.slice(selection.start, selection.end)
      : activeNote.body;
    try {
      await Clipboard.setStringAsync(text);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch {
      setPasteError("Could not copy to the clipboard.");
    }
  };

  const cutSelection = async () => {
    setPasteError("");
    if (selection.end <= selection.start) return;
    const text = activeNote.body.slice(selection.start, selection.end);
    try {
      await Clipboard.setStringAsync(text);
      updateActiveNote({ body: `${activeNote.body.slice(0, selection.start)}${activeNote.body.slice(selection.end)}` });
      setSelection({ start: selection.start, end: selection.start });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    } catch {
      setPasteError("Could not cut to the clipboard.");
    }
  };

  const pasteFromClipboard = async () => {
    setPasteError("");
    try {
      const text = await Clipboard.getStringAsync();
      if (!text) { setPasteError("Clipboard is empty."); return; }
      insertTextAtSelection(text);
    } catch {
      setPasteError("Could not read the clipboard.");
    }
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

          {!zenMode && !isMobile ? (
            <View
              style={[styles.menuBar, { borderColor: colors.border, overflow: "hidden" }]}
              onLayout={(e) => setMenuBarBottom(e.nativeEvent.layout.y + e.nativeEvent.layout.height)}
            >
              <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
              {(["file", "edit", "view", "tools", "help"] as const).map((id) => (
                <MTarget key={id} id={`menu-${id}`} onPress={() => setOpenMenu((current) => (current === id ? null : id))}>
                  <Pressable
                    onPress={() => setOpenMenu((current) => (current === id ? null : id))}
                    onLayout={(e) => setMenuItemLeft((prev) => (prev[id] === e.nativeEvent.layout.x ? prev : { ...prev, [id]: e.nativeEvent.layout.x }))}
                    style={({ pressed }) => [styles.menuItem, { backgroundColor: openMenu === id ? colors.primary : pressed ? colors.secondary : "transparent" }]}
                    testID={`menu-${id}`}
                  >
                    <Text style={[styles.menuItemText, { color: openMenu === id ? colors.primaryForeground : colors.foreground }]}>{id[0].toUpperCase() + id.slice(1)}</Text>
                  </Pressable>
                </MTarget>
              ))}
            </View>
          ) : null}

          {openMenu && !isMobile ? (
            <>
              <Pressable onPress={() => setOpenMenu(null)} style={[styles.menuOverlay, { top: menuBarBottom }]} />
              <View style={[styles.menuDropdown, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, left: menuItemLeft[openMenu] ?? 0, top: menuBarBottom + 2 }]}>
                {openMenu === "file" ? (
                  <>
                    <DropdownItem label="New" hint="Blank note" onPress={() => { createNote(); setOpenMenu(null); }} />
                    <DropdownItem label="Open from Files..." onPress={() => { setOpenMenu(null); importFromFiles(); }} />
                    <DropdownItem label="Open documents..." hint="Switch between open notes" onPress={() => { setTabListOpen(true); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Duplicate doc" onPress={() => { duplicateActiveNote(); setOpenMenu(null); }} />
                    <DropdownItem label="Rename..." onPress={() => { setRenameTarget({ id: activeNote.id, title: activeNote.title }); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Close" hint="Close current document" onPress={() => { deleteNote(activeNote.id); setOpenMenu(null); }} />
                    <DropdownItem label="Close others" onPress={() => { closeOthers(activeNote.id); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Delete doc" destructive onPress={() => { deleteActiveNote(); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "edit" ? (
                  <>
                    <DropdownItem label="Cut" onPress={() => { cutSelection(); setOpenMenu(null); }} />
                    <DropdownItem label="Copy" onPress={() => { copySelection(); setOpenMenu(null); }} />
                    <DropdownItem label="Paste" onPress={() => { pasteFromClipboard(); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Select all" onPress={() => { selectAll(); setOpenMenu(null); }} />
                    <DropdownItem label="Select line" onPress={() => { selectLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Select paragraph" onPress={() => { selectParagraph(); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Find" onPress={() => { setFindOpen(true); setReplaceOpen(false); setOpenMenu(null); }} />
                    <DropdownItem label="Replace" onPress={() => { setFindOpen(true); setReplaceOpen(true); setOpenMenu(null); }} />
                    <DropdownItem label="Case sensitive" checked={caseSensitive} onPress={() => { setCaseSensitive((current) => !current); setOpenMenu(null); }} />
                    <DropdownItem label="Whole word" checked={wholeWord} onPress={() => { setWholeWord((c) => !c); setOpenMenu(null); }} />
                    <DropdownItem label="Wildcards (* ?)" checked={useWildcards} onPress={() => { setUseWildcards((c) => { const n = !c; if (n) setUseRegex(false); return n; }); setOpenMenu(null); }} />
                    <DropdownItem label="Regular expression" checked={useRegex} onPress={() => { setUseRegex((c) => { const n = !c; if (n) setUseWildcards(false); return n; }); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Insert date" hint="Current timestamp" onPress={() => { insertTextAtSelection(new Date().toLocaleString()); setOpenMenu(null); }} />
                    <DropdownItem label="Duplicate line" onPress={() => { duplicateCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Delete line" onPress={() => { deleteCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Sort lines" onPress={() => { sortLines(); setOpenMenu(null); }} />
                    <DropdownItem label="Trim spaces" hint="Remove trailing whitespace" onPress={() => { trimTrailingSpaces(); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "view" ? (
                  <>
                    <DropdownItem label="Toolbar" checked={toolbarOpen} onPress={() => { setToolbarOpen((current) => !current); setOpenMenu(null); }} />
                    <DropdownItem label="Hide toolbar" onPress={() => { setToolbarOpen(false); setOpenMenu(null); }} />
                    <DropdownItem label="Show text under icons" checked={toolbarLabels} onPress={() => { setToolbarLabels(!toolbarLabels); setOpenMenu(null); }} />
                    <DropdownItem label="Two-row toolbar" checked={toolbarRows === "double"} onPress={() => { setToolbarRows(toolbarRows === "double" ? "single" : "double"); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Document tabs" checked={tabsLayout === "tabs"} onPress={() => { setTabsLayout("tabs"); setOpenMenu(null); }} />
                    <DropdownItem label="Document list" checked={tabsLayout === "list"} onPress={() => { setTabsLayout("list"); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Read mode" hint="Hides the keyboard · taps won't open it" checked={readMode} onPress={() => { setReadMode((current) => !current); setOpenMenu(null); }} />
                    <DropdownItem label="Zen mode" checked={zenMode} onPress={() => { setZenMode((current) => !current); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "tools" ? (
                  <>
                    <DropdownItem label="Compare documents" hint="Top / bottom diff view" checked={compareOpen} onPress={() => { toggleCompare(); setOpenMenu(null); }} />
                    <DropdownItem label="Trackpad" hint="On-screen pointer" checked={mouseOn} onPress={() => { setMouseOn((current) => !current); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Insert date" onPress={() => { insertTextAtSelection(new Date().toLocaleString()); setOpenMenu(null); }} />
                    <DropdownItem label="Duplicate line" onPress={() => { duplicateCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Delete line" onPress={() => { deleteCurrentLine(); setOpenMenu(null); }} />
                    <DropdownItem label="Sort lines" onPress={() => { sortLines(); setOpenMenu(null); }} />
                    <DropdownItem label="Trim spaces" onPress={() => { trimTrailingSpaces(); setOpenMenu(null); }} />
                    <DropdownSeparator />
                    <DropdownItem label="Change syntax..." onPress={() => { setLangOpen(true); setOpenMenu(null); }} />
                    <DropdownItem label="Preferences..." onPress={() => { setPrefsOpen(true); setOpenMenu(null); }} />
                  </>
                ) : null}
                {openMenu === "help" ? (
                  <>
                    <DropdownItem label="About Notepad 3++" onPress={() => { setAboutOpen(true); setOpenMenu(null); }} />
                  </>
                ) : null}
              </View>
            </>
          ) : null}

          {!zenMode && toolbarOpen ? (() => {
            type TbItem = { kind: "btn"; id: string; icon: keyof typeof Feather.glyphMap; label: string; onPress: () => void; color: string } | { kind: "sep" };
            const items: TbItem[] = [
              { kind: "btn", id: "tb-new", icon: "file-plus", label: "New", onPress: createNote, color: colors.foreground },
              { kind: "btn", id: "tb-open", icon: "folder", label: "Open", onPress: importFromFiles, color: colors.foreground },
              { kind: "btn", id: "tb-dup", icon: "copy", label: "Duplicate doc", onPress: duplicateActiveNote, color: colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-cut", icon: "scissors", label: "Cut", onPress: cutSelection, color: colors.foreground },
              { kind: "btn", id: "tb-copy", icon: "clipboard", label: "Copy", onPress: copySelection, color: colors.foreground },
              { kind: "btn", id: "tb-paste", icon: "download", label: "Paste", onPress: pasteFromClipboard, color: colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-selall", icon: "maximize", label: "Select all", onPress: selectAll, color: colors.foreground },
              { kind: "btn", id: "tb-selline", icon: "minus", label: "Select line", onPress: selectLine, color: colors.foreground },
              { kind: "btn", id: "tb-selpar", icon: "align-justify", label: "Select paragraph", onPress: selectParagraph, color: colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-find", icon: "search", label: "Find", onPress: () => setFindOpen((c) => !c), color: findOpen ? colors.primary : colors.foreground },
              { kind: "btn", id: "tb-rep", icon: "repeat", label: "Replace", onPress: () => { setFindOpen(true); setReplaceOpen((c) => !c); }, color: replaceOpen ? colors.primary : colors.foreground },
              { kind: "btn", id: "tb-stamp", icon: "clock", label: "Insert date", onPress: () => insertTextAtSelection(new Date().toLocaleString()), color: colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-dupl", icon: "plus-square", label: "Duplicate line", onPress: duplicateCurrentLine, color: colors.foreground },
              { kind: "btn", id: "tb-cutl", icon: "x-circle", label: "Delete line", onPress: deleteCurrentLine, color: colors.foreground },
              { kind: "btn", id: "tb-sort", icon: "list", label: "Sort lines", onPress: sortLines, color: colors.foreground },
              { kind: "btn", id: "tb-trim", icon: "align-left", label: "Trim spaces", onPress: trimTrailingSpaces, color: colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-cmp", icon: "columns", label: "Compare", onPress: toggleCompare, color: compareOpen ? colors.primary : colors.foreground },
              { kind: "btn", id: "tb-read", icon: readMode ? "eye" : "eye-off", label: "Read mode", onPress: () => setReadMode((c) => !c), color: readMode ? colors.primary : colors.foreground },
              { kind: "btn", id: "tb-zen", icon: zenMode ? "minimize-2" : "maximize-2", label: "Zen mode", onPress: () => setZenMode((c) => !c), color: colors.foreground },
              { kind: "btn", id: "tb-mouse", icon: "mouse-pointer", label: "Trackpad", onPress: () => setMouseOn((c) => !c), color: mouseOn ? colors.primary : colors.foreground },
              { kind: "sep" },
              { kind: "btn", id: "tb-del", icon: "trash-2", label: "Delete doc", onPress: deleteActiveNote, color: colors.destructive },
            ];
            const renderItem = (it: TbItem, idx: number) => it.kind === "sep"
              ? <View key={`sep-${idx}`} style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
              : <IconButton key={it.id} id={it.id} icon={it.icon} color={it.color} onPress={it.onPress} label={it.label} showLabel={toolbarLabels} onLongPress={showTip} />;
            const rowHeight = toolbarLabels ? 44 : 30;
            if (toolbarRows === "double") {
              const half = Math.ceil(items.length / 2);
              const top = items.slice(0, half);
              const bot = items.slice(half);
              return (
                <View style={[styles.toolbar, styles.toolbarDouble, { borderColor: colors.border, overflow: "hidden" }]}>
                  <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                  <View style={{ flex: 1 }}>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.toolbarRow} style={{ height: rowHeight }}>
                      {top.map(renderItem)}
                    </ScrollView>
                    <View style={[styles.toolbarRowSep, { backgroundColor: colors.border }]} />
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.toolbarRow} style={{ height: rowHeight }}>
                      {bot.map(renderItem)}
                    </ScrollView>
                  </View>
                  <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
                  <IconButton id="tb-collapse" icon="chevron-up" color={colors.foreground} onPress={() => setToolbarOpen(false)} label="Hide toolbar" onLongPress={showTip} />
                </View>
              );
            }
            return (
              <View style={[styles.toolbar, { borderColor: colors.border, overflow: "hidden" }]}>
                <LinearGradient colors={palette.chromeGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.toolbarRow} style={{ height: rowHeight }}>
                  {items.map(renderItem)}
                </ScrollView>
                <View style={[styles.toolbarSep, { backgroundColor: colors.border }]} />
                <IconButton id="tb-collapse" icon="chevron-up" color={colors.foreground} onPress={() => setToolbarOpen(false)} label="Hide toolbar" onLongPress={showTip} />
              </View>
            );
          })() : null}

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
            tabsLayout === "tabs" ? (
              <View style={[styles.tabsScroller, { backgroundColor: colors.background, borderColor: colors.border, flexDirection: "row" }]}>
                <FlatList horizontal data={notes} keyExtractor={(item) => item.id} renderItem={({ item }) => <DocumentTab item={item} active={item.id === activeId} onLongPress={(id) => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium); setTabMenuId(id); }} />} style={{ flex: 1 }} showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tabsList} scrollEnabled={notes.length > 0} />
                <Pressable onPress={() => { Haptics.selectionAsync(); setTabListOpen(true); }} style={[styles.tabsListBtn, { borderLeftColor: colors.border }]} testID="tabs-list-button">
                  <Feather name="list" size={13} color={colors.foreground} />
                </Pressable>
              </View>
            ) : (
              <Pressable onPress={() => { Haptics.selectionAsync(); setTabListOpen(true); }} style={[styles.tabsListBar, { backgroundColor: colors.background, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="tabs-list-bar">
                <Feather name="folder" size={12} color={colors.mutedForeground} />
                <Text numberOfLines={1} style={[styles.tabsListBarTitle, { color: colors.foreground }]}>{activeNote.title}</Text>
                <Text style={[styles.tabsListBarCount, { color: colors.mutedForeground }]}>{notes.length} open</Text>
                <Feather name="chevron-down" size={12} color={colors.mutedForeground} />
              </Pressable>
            )
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
                  <TextInput value={findQuery} onChangeText={setFindQuery} style={[styles.findInput, { color: colors.foreground, borderColor: findError ? colors.destructive : colors.border, borderRadius: Math.min(radius, 4) }]} placeholder="Find in document" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="find-input" />
                  <Pressable onPress={findNext} disabled={!findQuery || matchesCount === 0} style={({ pressed }) => [styles.replaceButton, { backgroundColor: colors.secondary, borderRadius: Math.min(radius, 4), opacity: (!findQuery || matchesCount === 0) ? 0.35 : pressed ? 0.7 : 1 }]} testID="find-next">
                    <Text style={[styles.replaceButtonText, { color: colors.secondaryForeground }]}>Next</Text>
                  </Pressable>
                  <Text style={[styles.findCount, { color: findError ? colors.destructive : colors.mutedForeground }]}>{findError || `${matchesCount}`}</Text>
                </View>
                <View style={styles.findOptionsRow}>
                  <Pressable onPress={() => setCaseSensitive((c) => !c)} style={[styles.findOpt, { backgroundColor: caseSensitive ? colors.primary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="opt-case">
                    <Text style={[styles.findOptText, { color: caseSensitive ? colors.primaryForeground : colors.mutedForeground }]}>Aa</Text>
                  </Pressable>
                  <Pressable onPress={() => setWholeWord((c) => !c)} style={[styles.findOpt, { backgroundColor: wholeWord ? colors.primary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="opt-word">
                    <Text style={[styles.findOptText, { color: wholeWord ? colors.primaryForeground : colors.mutedForeground }]}>W</Text>
                  </Pressable>
                  <Pressable onPress={() => { setUseWildcards((c) => !c); if (!useWildcards) setUseRegex(false); }} style={[styles.findOpt, { backgroundColor: useWildcards ? colors.primary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="opt-wild">
                    <Text style={[styles.findOptText, { color: useWildcards ? colors.primaryForeground : colors.mutedForeground }]}>* ?</Text>
                  </Pressable>
                  <Pressable onPress={() => { setUseRegex((c) => !c); if (!useRegex) setUseWildcards(false); }} style={[styles.findOpt, { backgroundColor: useRegex ? colors.primary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="opt-regex">
                    <Text style={[styles.findOptText, { color: useRegex ? colors.primaryForeground : colors.mutedForeground }]}>.*</Text>
                  </Pressable>
                  <View style={{ flex: 1 }} />
                  <Pressable onPress={() => { setFindOpen(false); setReplaceOpen(false); }} style={[styles.findOpt, { backgroundColor: colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="find-close">
                    <Feather name="x" size={12} color={colors.mutedForeground} />
                  </Pressable>
                </View>
                {replaceOpen ? (
                  <>
                    <View style={styles.findBar}>
                      <Feather name="repeat" size={17} color={colors.mutedForeground} />
                      <TextInput value={replaceText} onChangeText={setReplaceText} style={[styles.findInput, { color: colors.foreground, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} placeholder="Replace with (empty = remove)" placeholderTextColor={colors.mutedForeground} autoCapitalize="none" testID="replace-input" />
                      <Pressable onPress={replaceNext} disabled={!findQuery || matchesCount === 0} style={({ pressed }) => [styles.replaceButton, { backgroundColor: colors.secondary, borderRadius: Math.min(radius, 4), opacity: (!findQuery || matchesCount === 0) ? 0.35 : pressed ? 0.7 : 1 }]} testID="replace-next">
                        <Text style={[styles.replaceButtonText, { color: colors.secondaryForeground }]}>One</Text>
                      </Pressable>
                      <Pressable onPress={replaceAll} disabled={!findQuery || matchesCount === 0} style={({ pressed }) => [styles.replaceButton, { backgroundColor: colors.primary, borderRadius: Math.min(radius, 4), opacity: (!findQuery || matchesCount === 0) ? 0.35 : pressed ? 0.7 : 1 }]} testID="replace-all">
                        <Text style={[styles.replaceButtonText, { color: colors.primaryForeground }]}>All</Text>
                      </Pressable>
                    </View>
                    {!replaceText && findQuery ? (
                      <Text style={[styles.findHint, { color: colors.mutedForeground }]}>Empty replace removes every match.</Text>
                    ) : null}
                  </>
                ) : null}
              </View>
            ) : null}
            {pasteError ? <Text style={[styles.errorText, { color: colors.destructive, backgroundColor: colors.card }]}>{pasteError}</Text> : null}

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
                  <TextInput editable={!readMode} value={activeNote.body} onChangeText={(body) => updateActiveNote({ body })} multiline textAlignVertical="top" autoCapitalize="none" autoCorrect={false} spellCheck={false} style={[styles.editorInput, { color: colors.foreground }]} placeholder="Start typing..." placeholderTextColor={colors.mutedForeground} selection={selection} onSelectionChange={(event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => setSelection(event.nativeEvent.selection)} testID="editor-input" />
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
            <Pressable onPress={() => { setGotoValue(String(cursor.line)); setGotoOpen(true); }} testID="status-goto" hitSlop={6}>
              <Text style={[styles.statusText, { color: colors.foreground, textDecorationLine: "underline" }]}>Ln {cursor.line}, Col {cursor.column}</Text>
            </Pressable>
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

        {zenMode ? (
          <Pressable onPress={() => setZenMode(false)} style={[styles.zenExit, { top: insets.top + 8, backgroundColor: colors.card, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="zen-exit">
            <Feather name="minimize-2" size={14} color={colors.foreground} />
            <Text style={[styles.zenExitText, { color: colors.foreground }]}>Exit Zen</Text>
          </Pressable>
        ) : null}

        {mouseOn ? (
          <MouseOverlay targetsRef={mouseTargetsRef} palette={palette} colors={colors} radius={radius} onClose={() => setMouseOn(false)} />
        ) : null}

        {toolbarTip ? (
          <View pointerEvents="none" style={[styles.tooltipBubble, { top: insets.top + 6, backgroundColor: colors.foreground, borderColor: colors.border, borderRadius: Math.min(radius, 6) }]}>
            <Text style={[styles.tooltipText, { color: colors.background }]} numberOfLines={1}>{toolbarTip}</Text>
          </View>
        ) : null}

        <Modal visible={tabMenuId !== null} transparent animationType="fade" onRequestClose={() => setTabMenuId(null)}>
          <Pressable onPress={() => setTabMenuId(null)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden", maxWidth: 320 }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text numberOfLines={1} style={[styles.modalTitle, { color: colors.primaryForeground }]}>{tabMenuNote?.title ?? "Document"}</Text>
                <Pressable onPress={() => setTabMenuId(null)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="tab-menu-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <View style={styles.modalBody}>
                <DropdownItem label="Switch to" onPress={() => { if (tabMenuId) setActiveId(tabMenuId); setTabMenuId(null); }} />
                <DropdownItem label="Rename" onPress={() => { if (tabMenuNote) setRenameTarget({ id: tabMenuNote.id, title: tabMenuNote.title }); setTabMenuId(null); }} />
                <DropdownItem label="Duplicate" onPress={() => { if (tabMenuId) duplicateNote(tabMenuId); setTabMenuId(null); }} />
                <DropdownSeparator />
                <DropdownItem label="Close" onPress={() => { if (tabMenuId) deleteNote(tabMenuId); setTabMenuId(null); }} />
                <DropdownItem label="Close others" onPress={() => { if (tabMenuId) closeOthers(tabMenuId); setTabMenuId(null); }} />
              </View>
            </Pressable>
          </Pressable>
        </Modal>

        <Modal visible={tabListOpen} transparent animationType="fade" onRequestClose={() => setTabListOpen(false)}>
          <Pressable onPress={() => setTabListOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden" }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>Open documents</Text>
                <Pressable onPress={() => setTabListOpen(false)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="tab-list-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <ScrollView style={{ maxHeight: 420 }} contentContainerStyle={styles.modalBody}>
                {notes.map((note) => {
                  const selected = note.id === activeId;
                  return (
                    <View key={note.id} style={[styles.docListRow, { borderColor: colors.border, borderRadius: Math.min(radius, 4), backgroundColor: selected ? colors.primary : "transparent" }]}>
                      <Pressable onPress={() => { setActiveId(note.id); setTabListOpen(false); }} onLongPress={() => { setTabListOpen(false); setTabMenuId(note.id); }} delayLongPress={350} style={styles.docListMain} testID={`doc-list-${note.id}`}>
                        <Feather name="file-text" size={13} color={selected ? colors.primaryForeground : colors.mutedForeground} />
                        <View style={{ flex: 1 }}>
                          <Text numberOfLines={1} style={[styles.docListTitle, { color: selected ? colors.primaryForeground : colors.foreground }]}>{note.title}</Text>
                          <Text numberOfLines={1} style={[styles.docListMeta, { color: selected ? colors.primaryForeground : colors.mutedForeground }]}>{note.language} · {note.body.length} chars</Text>
                        </View>
                      </Pressable>
                      <Pressable onPress={() => { setRenameTarget({ id: note.id, title: note.title }); setTabListOpen(false); }} hitSlop={6} style={styles.docListAction} testID={`doc-list-rename-${note.id}`}>
                        <Feather name="edit-2" size={13} color={selected ? colors.primaryForeground : colors.mutedForeground} />
                      </Pressable>
                      <Pressable onPress={() => deleteNote(note.id)} hitSlop={6} style={styles.docListAction} testID={`doc-list-close-${note.id}`}>
                        <Feather name="x" size={14} color={selected ? colors.primaryForeground : colors.mutedForeground} />
                      </Pressable>
                    </View>
                  );
                })}
                <Pressable onPress={() => { createNote(); setTabListOpen(false); }} style={({ pressed }) => [styles.docListNew, { backgroundColor: pressed ? colors.secondary : colors.muted, borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="doc-list-new">
                  <Feather name="file-plus" size={13} color={colors.foreground} />
                  <Text style={[styles.docListTitle, { color: colors.foreground }]}>New document</Text>
                </Pressable>
              </ScrollView>
            </Pressable>
          </Pressable>
        </Modal>

        <Modal visible={renameTarget !== null} transparent animationType="fade" onRequestClose={() => setRenameTarget(null)}>
          <Pressable onPress={() => setRenameTarget(null)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden", maxWidth: 320 }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>Rename document</Text>
                <Pressable onPress={() => setRenameTarget(null)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="rename-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <View style={styles.modalBody}>
                <TextInput value={renameTarget?.title ?? ""} onChangeText={(t) => setRenameTarget((c) => (c ? { ...c, title: t } : c))} autoFocus style={[styles.findInput, { color: colors.foreground, borderColor: colors.border, borderRadius: Math.min(radius, 4), paddingHorizontal: 8, paddingVertical: 8 }]} placeholder="filename.txt" placeholderTextColor={colors.mutedForeground} testID="rename-input" />
                <View style={{ flexDirection: "row", gap: 8, marginTop: 10 }}>
                  <Pressable onPress={() => setRenameTarget(null)} style={({ pressed }) => [styles.replaceButton, { flex: 1, backgroundColor: colors.muted, borderRadius: Math.min(radius, 4), opacity: pressed ? 0.7 : 1 }]}>
                    <Text style={[styles.replaceButtonText, { color: colors.foreground }]}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={() => { if (renameTarget) renameNote(renameTarget.id, renameTarget.title); setRenameTarget(null); }} style={({ pressed }) => [styles.replaceButton, { flex: 1, backgroundColor: colors.primary, borderRadius: Math.min(radius, 4), opacity: pressed ? 0.7 : 1 }]} testID="rename-save">
                    <Text style={[styles.replaceButtonText, { color: colors.primaryForeground }]}>Rename</Text>
                  </Pressable>
                </View>
              </View>
            </Pressable>
          </Pressable>
        </Modal>

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
                {preference === "custom" ? (
                  <View style={{ marginTop: 10, padding: 8, borderWidth: 1, borderColor: colors.border, borderRadius: Math.min(radius, 4), backgroundColor: colors.muted }}>
                    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginBottom: 6 }}>
                      <Text style={[styles.modalSection, { color: colors.foreground, marginTop: 0 }]}>Custom palette</Text>
                      <Pressable onPress={resetCustomPalette} style={({ pressed }) => [{ paddingHorizontal: 8, paddingVertical: 4, borderWidth: 1, borderColor: colors.border, borderRadius: 3, backgroundColor: pressed ? colors.secondary : "transparent" }]} testID="custom-reset">
                        <Text style={{ fontFamily: mono, fontSize: 10, color: colors.foreground }}>Reset</Text>
                      </Pressable>
                    </View>
                    {CUSTOM_PALETTE_KEYS.map((k: CustomPaletteKey) => {
                      const current = customPalette[k] ?? customDefaults[k];
                      const meta = customPaletteLabels[k];
                      return (
                        <View key={k} style={{ marginBottom: 8 }}>
                          <View style={{ flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 4 }}>
                            <View style={{ width: 18, height: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: current, borderRadius: 3 }} />
                            <View style={{ flex: 1 }}>
                              <Text style={{ fontFamily: mono, fontSize: 11, color: colors.foreground, fontWeight: "600" }}>{meta.label}</Text>
                              <Text style={{ fontFamily: mono, fontSize: 9, color: colors.mutedForeground }}>{meta.hint} — {current}</Text>
                            </View>
                          </View>
                          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 4 }}>
                            {customSwatches.map((sw) => {
                              const selected = sw.toLowerCase() === current.toLowerCase();
                              return (
                                <Pressable key={`${k}-${sw}`} onPress={() => setCustomColor(k, sw)} testID={`swatch-${k}-${sw}`} style={({ pressed }) => [{ width: 22, height: 22, borderRadius: 3, backgroundColor: sw, borderWidth: selected ? 2 : 1, borderColor: selected ? colors.foreground : colors.border, opacity: pressed ? 0.7 : 1 }]} />
                              );
                            })}
                          </View>
                        </View>
                      );
                    })}
                  </View>
                ) : null}
                <Text style={[styles.modalSection, { color: colors.foreground, marginTop: 12 }]}>Document tabs</Text>
                {([{ id: "tabs" as const, label: "Tabs", hint: "Notepad++ style row of tabs" }, { id: "list" as const, label: "Dropdown list", hint: "One bar that opens a list of open documents" }]).map((opt) => {
                  const selected = tabsLayout === opt.id;
                  return (
                    <Pressable key={opt.id} onPress={() => setTabsLayout(opt.id)} style={({ pressed }) => [styles.prefRow, { backgroundColor: selected ? colors.primary : pressed ? colors.secondary : "transparent", borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID={`tabs-layout-${opt.id}`}>
                      <View style={[styles.radio, { borderColor: selected ? colors.primaryForeground : colors.foreground }]}>
                        {selected ? <View style={[styles.radioDot, { backgroundColor: colors.primaryForeground }]} /> : null}
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.prefRowLabel, { color: selected ? colors.primaryForeground : colors.foreground }]}>{opt.label}</Text>
                        <Text style={[styles.prefRowHint, { color: selected ? colors.primaryForeground : colors.mutedForeground }]}>{opt.hint}</Text>
                      </View>
                    </Pressable>
                  );
                })}
                <Text style={[styles.modalSection, { color: colors.foreground, marginTop: 12 }]}>Toolbar layout</Text>
                {([{ id: "single" as const, label: "Single row", hint: "Scroll horizontally to reach more icons" }, { id: "double" as const, label: "Two rows", hint: "Stack icons in two scrollable rows" }]).map((opt) => {
                  const selected = toolbarRows === opt.id;
                  return (
                    <Pressable key={opt.id} onPress={() => setToolbarRows(opt.id)} style={({ pressed }) => [styles.prefRow, { backgroundColor: selected ? colors.primary : pressed ? colors.secondary : "transparent", borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID={`toolbar-rows-${opt.id}`}>
                      <View style={[styles.radio, { borderColor: selected ? colors.primaryForeground : colors.foreground }]}>
                        {selected ? <View style={[styles.radioDot, { backgroundColor: colors.primaryForeground }]} /> : null}
                      </View>
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.prefRowLabel, { color: selected ? colors.primaryForeground : colors.foreground }]}>{opt.label}</Text>
                        <Text style={[styles.prefRowHint, { color: selected ? colors.primaryForeground : colors.mutedForeground }]}>{opt.hint}</Text>
                      </View>
                    </Pressable>
                  );
                })}
                <Pressable onPress={() => setToolbarLabels(!toolbarLabels)} style={({ pressed }) => [styles.prefRow, { backgroundColor: toolbarLabels ? colors.primary : pressed ? colors.secondary : "transparent", borderColor: colors.border, borderRadius: Math.min(radius, 4) }]} testID="toolbar-labels-toggle">
                  <View style={[styles.radio, { borderColor: toolbarLabels ? colors.primaryForeground : colors.foreground, borderRadius: 3 }]}>
                    {toolbarLabels ? <Feather name="check" size={12} color={colors.primaryForeground} /> : null}
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.prefRowLabel, { color: toolbarLabels ? colors.primaryForeground : colors.foreground }]}>Show text under icons</Text>
                    <Text style={[styles.prefRowHint, { color: toolbarLabels ? colors.primaryForeground : colors.mutedForeground }]}>Always visible labels for every toolbar button</Text>
                  </View>
                </Pressable>
                <Text style={[styles.modalNote, { color: colors.mutedForeground }]}>Tip: long-press any toolbar icon to see its name. Choices are saved on this device.</Text>
              </ScrollView>
            </Pressable>
          </Pressable>
        </Modal>

        <Modal visible={gotoOpen} transparent animationType="fade" onRequestClose={() => setGotoOpen(false)}>
          <Pressable onPress={() => setGotoOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
            <Pressable onPress={() => undefined} style={[styles.modalCard, { backgroundColor: colors.card, borderColor: colors.border, borderRadius: radius, overflow: "hidden", maxWidth: 320 }]}>
              <View style={[styles.modalHeader, { borderColor: colors.border }]}>
                <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
                <Text style={[styles.modalTitle, { color: colors.primaryForeground }]}>Go to line</Text>
                <Pressable onPress={() => setGotoOpen(false)} style={[styles.modalClose, { borderColor: colors.primaryForeground }]} testID="goto-close">
                  <Text style={[styles.modalCloseText, { color: colors.primaryForeground }]}>×</Text>
                </Pressable>
              </View>
              <View style={styles.modalBody}>
                <Text style={[styles.aboutText, { color: colors.mutedForeground, marginBottom: 6 }]}>Line 1 to {stats.lines}</Text>
                <TextInput
                  value={gotoValue}
                  onChangeText={setGotoValue}
                  keyboardType="number-pad"
                  autoFocus
                  returnKeyType="go"
                  onSubmitEditing={() => {
                    const n = parseInt(gotoValue, 10);
                    if (!Number.isFinite(n) || n < 1) { setGotoOpen(false); return; }
                    const body = activeNote.body.replace(/\r\n/g, "\n");
                    const lines = body.split("\n");
                    const target = Math.max(1, Math.min(n, lines.length));
                    let off = 0;
                    for (let i = 0; i < target - 1; i += 1) off += lines[i].length + 1;
                    setSelection({ start: off, end: off });
                    setGotoOpen(false);
                    Haptics.selectionAsync();
                  }}
                  style={{ borderWidth: 1, borderColor: colors.border, borderRadius: 4, paddingHorizontal: 8, paddingVertical: 6, fontFamily: mono, fontSize: 14, color: colors.foreground, backgroundColor: colors.editorBackground }}
                  testID="goto-input"
                />
                <Text style={[styles.modalNote, { color: colors.mutedForeground }]}>Tip: tap "Ln X, Col Y" any time to jump.</Text>
              </View>
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
  toolbarDouble: { alignItems: "stretch", paddingVertical: 2 },
  toolbarSep: { width: 1, height: 18, marginHorizontal: 3 },
  toolbarRowSep: { height: 1, marginVertical: 2 },
  toolbarSpacer: { flex: 1 },
  toolbarRow: { flexDirection: "row", alignItems: "center", paddingRight: 4 },
  findOptionsRow: { flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 6, paddingTop: 2 },
  findOpt: { paddingHorizontal: 8, paddingVertical: 3, borderWidth: 1, alignItems: "center", justifyContent: "center", minWidth: 28 },
  findOptText: { fontFamily: mono, fontSize: 11, fontWeight: "600" },
  findHint: { fontFamily: mono, fontSize: 10, paddingHorizontal: 8, paddingBottom: 4 },
  zenExit: { position: "absolute", right: 12, flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 10, paddingVertical: 6, borderWidth: 1, opacity: 0.92 },
  zenExitText: { fontFamily: mono, fontSize: 11 },
  toolbarStrip: { borderBottomWidth: 1, height: 18, justifyContent: "center" },
  toolbarStripPress: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 4, height: 18 },
  toolbarStripText: { fontFamily: "Inter_500Medium", fontSize: 10 },
  iconButton: { alignItems: "center", justifyContent: "center", minHeight: 26, minWidth: 26, paddingHorizontal: 4 },
  iconButtonWithLabel: { minWidth: 52, paddingHorizontal: 6, paddingVertical: 2 },
  iconButtonLabel: { fontFamily: "Inter_500Medium", fontSize: 9, marginTop: 2, maxWidth: 64, textAlign: "center" },
  tooltipBubble: { position: "absolute", alignSelf: "center", left: 24, right: 24, paddingHorizontal: 12, paddingVertical: 6, borderWidth: 1, alignItems: "center" },
  tooltipText: { fontFamily: "Inter_700Bold", fontSize: 12 },
  tabsList: { paddingHorizontal: 4 },
  tabsScroller: { flexGrow: 0, maxHeight: 28, borderBottomWidth: 1 },
  documentTab: { maxWidth: 180, borderWidth: 1, marginRight: 2, marginTop: 2, flexDirection: "row", alignItems: "center" },
  documentTabBody: { paddingLeft: 10, paddingRight: 4, paddingVertical: 4, justifyContent: "center" },
  documentTabTitle: { fontSize: 11, maxWidth: 130 },
  documentTabClose: { paddingHorizontal: 6, paddingVertical: 4, marginRight: 2 },
  tabsListBtn: { paddingHorizontal: 8, alignItems: "center", justifyContent: "center", borderLeftWidth: 1 },
  tabsListBar: { marginHorizontal: 6, marginTop: 4, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 6, flexDirection: "row", alignItems: "center", gap: 8 },
  tabsListBarTitle: { flex: 1, fontFamily: "Inter_700Bold", fontSize: 12 },
  tabsListBarCount: { fontFamily: mono, fontSize: 10 },
  docListRow: { flexDirection: "row", alignItems: "center", borderWidth: 1, paddingVertical: 6, paddingHorizontal: 4, marginBottom: 4 },
  docListMain: { flex: 1, flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 8, paddingVertical: 2 },
  docListTitle: { fontFamily: "Inter_500Medium", fontSize: 13 },
  docListMeta: { fontFamily: mono, fontSize: 10, marginTop: 2 },
  docListAction: { paddingHorizontal: 8, paddingVertical: 6 },
  docListNew: { flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 12, paddingVertical: 8, borderWidth: 1, marginTop: 6 },
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
  menuDropdown: { position: "absolute", minWidth: 180, borderWidth: 1, paddingVertical: 4, zIndex: 101, shadowColor: "#000", shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.15, shadowRadius: 6, elevation: 4 },
  dropdownItem: { paddingHorizontal: 10, paddingVertical: 5, gap: 1 },
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
  mousePointer: { position: "absolute", zIndex: 200 },
  clickRipple: { position: "absolute", width: 36, height: 36, borderRadius: 18, borderWidth: 2, zIndex: 199 },
  trackpadCard: { position: "absolute", left: 12, right: 12, bottom: 16, borderWidth: 2, zIndex: 201 },
  trackpadHeader: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 10, paddingVertical: 6 },
  trackpadHeaderText: { flex: 1, fontFamily: "Inter_500Medium", fontSize: 11 },
  trackpadClose: { padding: 4 },
  trackpadSurface: { height: 180, borderTopWidth: 1, borderBottomWidth: 1, alignItems: "center", justifyContent: "center", position: "relative" },
  trackpadHint: { fontFamily: mono, fontSize: 12, opacity: 0.55, textAlign: "center" },
  trackpadHintSub: { fontFamily: mono, fontSize: 10, opacity: 0.4, textAlign: "center", marginTop: 4 },
  trackpadGrid: { ...StyleSheet.absoluteFillObject, opacity: 0.08 },
  trackpadFinger: { position: "absolute", width: 38, height: 38, borderRadius: 19, borderWidth: 2 },
  trackpadButtons: { flexDirection: "row", padding: 8, gap: 8 },
  trackpadClick: { flex: 1, paddingVertical: 12, alignItems: "center", justifyContent: "center", borderWidth: 1 },
  trackpadClickText: { fontFamily: "Inter_700Bold", fontSize: 12 },
  mousePad: { position: "absolute", right: 12, bottom: 24, padding: 4, borderWidth: 1, gap: 3, zIndex: 201 },
  mousePadRow: { flexDirection: "row", gap: 3 },
  mousePadCell: { width: 28, height: 28 },
  mousePadKey: { width: 28, height: 28, alignItems: "center", justifyContent: "center", borderWidth: 1 },
  mousePadClick: { width: 28, height: 28, alignItems: "center", justifyContent: "center", borderWidth: 1 },
  mousePadClickText: { fontFamily: "Inter_700Bold", fontSize: 9 },
});
