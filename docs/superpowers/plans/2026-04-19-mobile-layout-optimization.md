# Mobile Layout Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the desktop-clone layout (top menu bar + top toolbar) with a native-feeling mobile layout (single ••• button → bottom-sheet action sheet, toolbar moved to bottom, larger touch targets, FAB for New Note), toggleable at runtime between `classic` and `mobile`.

**Architecture:** Add a `layoutMode: 'classic' | 'mobile'` preference to `ThemeContext` alongside the existing `tabsLayout` / `toolbarLabels` / `toolbarRows`. Persist via `AsyncStorage` using the same pattern. In `app/index.tsx`, gate existing desktop-style UI on `!isMobile` and render new mobile-specific shell (•••  button, action-sheet Modal, bottom-positioned toolbar, FAB) on `isMobile`. Default to `mobile` if `Dimensions.get('window').width < 768` on first launch.

**Tech Stack:** React Native (Expo), TypeScript 5.9, `@react-native-async-storage/async-storage`, `@expo/vector-icons` (Feather, Ionicons), `expo-linear-gradient`, `expo-haptics`, `react-native-safe-area-context`.

**Files:**
- Modify: `artifacts/mobile/context/ThemeContext.tsx` — add `layoutMode` preference with persistence
- Modify: `artifacts/mobile/app/index.tsx` — consume `layoutMode`, gate menu bar, add mobile shell components, add preference toggle

No new files; the mobile shell components (action sheet, FAB, MobileMoreButton) live inline in `index.tsx` alongside the existing inline components (DropdownItem, MouseOverlay, etc.) since that is the established pattern.

---

### Task 1: Add `layoutMode` to ThemeContext

**Files:**
- Modify: `artifacts/mobile/context/ThemeContext.tsx`

- [ ] **Step 1: Add the type + VALID constant**

Add near the existing `VALID_TABS`/`VALID_ROWS` constants at top of file:

```tsx
export type LayoutMode = "classic" | "mobile";
const VALID_LAYOUT: LayoutMode[] = ["classic", "mobile"];
const LAYOUT_KEY = "notepad3pp.layoutMode";
```

- [ ] **Step 2: Add `layoutMode` to `ThemeContextValue` type**

In the `type ThemeContextValue` block, add:

```tsx
  layoutMode: LayoutMode;
  setLayoutMode: (mode: LayoutMode) => void;
```

- [ ] **Step 3: Add state + default based on screen size**

Near the other `useState` lines inside `ThemeProvider`, add:

```tsx
  const [layoutMode, setLayoutModeState] = useState<LayoutMode>(() => {
    const { width } = Dimensions.get("window");
    return width < 768 ? "mobile" : "classic";
  });
```

And add `Dimensions` to the top-of-file import from `"react-native"`:

```tsx
import { Dimensions, useColorScheme } from "react-native";
```

- [ ] **Step 4: Load persisted value in the existing useEffect**

Add inside the existing `useEffect(() => { ... }, [])` block (after the other `AsyncStorage.getItem` calls):

```tsx
    AsyncStorage.getItem(LAYOUT_KEY)
      .then((value) => {
        if (value && (VALID_LAYOUT as string[]).includes(value)) {
          setLayoutModeState(value as LayoutMode);
        }
      })
      .catch(() => undefined);
```

- [ ] **Step 5: Add setter that persists**

Add near the other setters:

```tsx
  const setLayoutMode = (next: LayoutMode) => {
    setLayoutModeState(next);
    AsyncStorage.setItem(LAYOUT_KEY, next).catch(() => undefined);
  };
```

- [ ] **Step 6: Include `layoutMode` + setter in the memoized context value**

Update the `useMemo` dependencies AND the object:

```tsx
  const value = useMemo<ThemeContextValue>(
    () => ({ themeName, preference, setPreference, tabsLayout, setTabsLayout, toolbarLabels, setToolbarLabels, toolbarRows, setToolbarRows, layoutMode, setLayoutMode, customPalette, setCustomColor, resetCustomPalette, palette, radius: palette.radius ?? colorsModule.radius }),
    [themeName, preference, tabsLayout, toolbarLabels, toolbarRows, layoutMode, customPalette, palette],
  );
```

- [ ] **Step 7: Commit**

```bash
git add artifacts/mobile/context/ThemeContext.tsx
git commit -m "feat(theme): add layoutMode preference with persistence"
```

---

### Task 2: Consume `layoutMode` in index.tsx and gate the menu bar

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Destructure `layoutMode` from `useTheme()`**

Find the `const { ... } = useTheme();` call in the main component (near the top of the render function, line ~470). Add `layoutMode` to the destructured props:

```tsx
const { palette, radius, tabsLayout, toolbarLabels, toolbarRows, setTabsLayout, setToolbarLabels, setToolbarRows, layoutMode, setLayoutMode } = useTheme();
```

If the destructuring list doesn't already contain these (it may differ — read the current value and adapt), add just `layoutMode, setLayoutMode` to whatever is there.

- [ ] **Step 2: Add a `const isMobile` near the destructuring for readability**

```tsx
const isMobile = layoutMode === "mobile";
```

- [ ] **Step 3: Gate the menu bar on `!isMobile`**

Find the existing menu bar block starting with `{!zenMode ? (` followed by `<View style={[styles.menuBar, ...`. Change the condition from `!zenMode` to `!zenMode && !isMobile`:

```tsx
{!zenMode && !isMobile ? (
  <View
    style={[styles.menuBar, { borderColor: colors.border, overflow: "hidden" }]}
    onLayout={(e) => setMenuBarBottom(e.nativeEvent.layout.y + e.nativeEvent.layout.height)}
  >
    {/* ... unchanged ... */}
  </View>
) : null}
```

Also gate the dropdown popup block (the `{openMenu ? ( <> <Pressable .../> <View style={[styles.menuDropdown, ...]}>...` block) on `!isMobile` — dropdowns should not appear in mobile mode since the menu bar is hidden:

```tsx
{openMenu && !isMobile ? (
  <>
    {/* ... existing overlay + dropdown ... */}
  </>
) : null}
```

- [ ] **Step 4: Start the app and switch a test instance to mobile**

Temporarily hard-set `useState<LayoutMode>("mobile")` in ThemeContext (revert after testing) OR use the Preferences toggle added later. For now, verify in Expo Go:

Run in WSL: `cd artifacts/mobile && pnpm install && npx expo start` (if deps aren't installed yet)
Expected: When `layoutMode === "mobile"`, the File/Edit/View/Tools/Help bar is gone.

- [ ] **Step 5: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): gate desktop menu bar on classic layout mode"
```

---

### Task 3: Add "•••" More button in the title bar (mobile mode)

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Add state for the action sheet**

Near the other `useState` calls (around line 478 where `openMenu` is defined), add:

```tsx
const [actionSheetOpen, setActionSheetOpen] = useState(false);
```

- [ ] **Step 2: Add the More button to the title bar**

Find the title bar block (starts with `{!zenMode ? ( <View style={[styles.titleBar, ...`, around line 737). Replace it with this version that adds a right-aligned "•••" button when in mobile mode:

```tsx
{!zenMode ? (
  <View style={[styles.titleBar, { borderColor: colors.border, borderTopLeftRadius: radius, borderTopRightRadius: radius, overflow: "hidden" }]}>
    <LinearGradient colors={palette.titleGradient} style={StyleSheet.absoluteFill} start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }} />
    <Ionicons name="document-text-outline" size={13} color={colors.primaryForeground} />
    <Text numberOfLines={1} style={[styles.titleBarText, { color: colors.primaryForeground }]}>{activeNote.title} - Notepad 3++</Text>
    {isMobile ? (
      <Pressable onPress={() => setActionSheetOpen(true)} style={styles.titleBarMore} testID="title-more" hitSlop={10}>
        <Feather name="more-horizontal" size={18} color={colors.primaryForeground} />
      </Pressable>
    ) : null}
  </View>
) : null}
```

- [ ] **Step 3: Add the `titleBarMore` style**

Find the `styles` object (around line 1440+). Add near `titleBarText`:

```tsx
titleBarMore: { marginLeft: "auto", paddingHorizontal: 8, paddingVertical: 4 },
```

- [ ] **Step 4: Verify in Expo Go**

Expected: in mobile mode, the title bar shows "filename - Notepad 3++" with a "•••" icon on the right. Tapping it sets `actionSheetOpen` to true (nothing visible yet until Task 4).

- [ ] **Step 5: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): add mobile title-bar more button"
```

---

### Task 4: Build the mobile action sheet Modal

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Add a `MobileActionSheet` component (inline, above the main App component)**

Place above the existing `DropdownItem` function (around line 325). This is a helper that renders a single row in the sheet:

```tsx
function SheetRow({ icon, label, hint, onPress, destructive, checked }: { icon?: keyof typeof Feather.glyphMap; label: string; hint?: string; onPress: () => void; destructive?: boolean; checked?: boolean }) {
  const colors = useColors();
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.sheetRow, { backgroundColor: pressed ? colors.secondary : "transparent", borderColor: colors.border }]}>
      {icon ? <Feather name={icon} size={20} color={destructive ? colors.destructive : colors.foreground} style={{ width: 24 }} /> : <View style={{ width: 24 }} />}
      <View style={{ flex: 1, marginLeft: 12 }}>
        <Text style={[styles.sheetRowLabel, { color: destructive ? colors.destructive : colors.foreground }]}>{label}</Text>
        {hint ? <Text style={[styles.sheetRowHint, { color: colors.mutedForeground }]}>{hint}</Text> : null}
      </View>
      {checked === true ? <Feather name="check" size={18} color={colors.primary} /> : null}
    </Pressable>
  );
}

function SheetSection({ title, children }: { title: string; children: React.ReactNode }) {
  const colors = useColors();
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={[styles.sheetSectionTitle, { color: colors.mutedForeground }]}>{title.toUpperCase()}</Text>
      <View style={{ gap: 0 }}>{children}</View>
    </View>
  );
}
```

- [ ] **Step 2: Add sheet styles**

In the `styles` StyleSheet at the bottom of the file, add (near the other dropdown styles):

```tsx
sheetRow: { flexDirection: "row", alignItems: "center", paddingHorizontal: 16, paddingVertical: 14, borderBottomWidth: StyleSheet.hairlineWidth, minHeight: 48 },
sheetRowLabel: { fontFamily: "Inter_500Medium", fontSize: 16 },
sheetRowHint: { fontFamily: "Inter_400Regular", fontSize: 12, marginTop: 2 },
sheetSectionTitle: { fontFamily: "Inter_700Bold", fontSize: 11, letterSpacing: 0.8, paddingHorizontal: 16, paddingVertical: 8 },
sheetContainer: { position: "absolute", left: 0, right: 0, bottom: 0, maxHeight: "85%", borderTopLeftRadius: 16, borderTopRightRadius: 16, paddingTop: 8, paddingBottom: 16 },
sheetHandle: { width: 40, height: 4, borderRadius: 2, alignSelf: "center", marginBottom: 8, marginTop: 4 },
sheetScroll: { paddingBottom: 24 },
```

- [ ] **Step 3: Render the Modal**

Add a new Modal block near the existing ones (near line 1094, before the first existing `<Modal>`):

```tsx
<Modal visible={actionSheetOpen} transparent animationType="slide" onRequestClose={() => setActionSheetOpen(false)}>
  <Pressable onPress={() => setActionSheetOpen(false)} style={[styles.modalBackdrop, { backgroundColor: "rgba(0,0,0,0.45)" }]}>
    <Pressable onPress={(e) => e.stopPropagation()} style={[styles.sheetContainer, { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 }]}>
      <View style={[styles.sheetHandle, { backgroundColor: colors.border }]} />
      <ScrollView contentContainerStyle={styles.sheetScroll} showsVerticalScrollIndicator={false}>
        <SheetSection title="File">
          <SheetRow icon="file-plus" label="New" hint="Blank note" onPress={() => { createNote(); setActionSheetOpen(false); }} />
          <SheetRow icon="folder" label="Open from Files..." onPress={() => { setActionSheetOpen(false); importFromFiles(); }} />
          <SheetRow icon="list" label="Open documents..." hint="Switch between open notes" onPress={() => { setTabListOpen(true); setActionSheetOpen(false); }} />
          <SheetRow icon="copy" label="Duplicate doc" onPress={() => { duplicateActiveNote(); setActionSheetOpen(false); }} />
          <SheetRow icon="edit-2" label="Rename..." onPress={() => { setRenameTarget({ id: activeNote.id, title: activeNote.title }); setActionSheetOpen(false); }} />
          <SheetRow icon="x-circle" label="Close" hint="Close current document" onPress={() => { deleteNote(activeNote.id); setActionSheetOpen(false); }} />
          <SheetRow icon="trash-2" label="Delete doc" destructive onPress={() => { deleteActiveNote(); setActionSheetOpen(false); }} />
        </SheetSection>
        <SheetSection title="Edit">
          <SheetRow icon="scissors" label="Cut" onPress={() => { cutSelection(); setActionSheetOpen(false); }} />
          <SheetRow icon="clipboard" label="Copy" onPress={() => { copySelection(); setActionSheetOpen(false); }} />
          <SheetRow icon="download" label="Paste" onPress={() => { pasteFromClipboard(); setActionSheetOpen(false); }} />
          <SheetRow icon="maximize" label="Select all" onPress={() => { selectAll(); setActionSheetOpen(false); }} />
          <SheetRow icon="search" label="Find" onPress={() => { setFindOpen(true); setReplaceOpen(false); setActionSheetOpen(false); }} />
          <SheetRow icon="repeat" label="Replace" onPress={() => { setFindOpen(true); setReplaceOpen(true); setActionSheetOpen(false); }} />
          <SheetRow icon="clock" label="Insert date" hint="Current timestamp" onPress={() => { insertTextAtSelection(new Date().toLocaleString()); setActionSheetOpen(false); }} />
          <SheetRow icon="plus-square" label="Duplicate line" onPress={() => { duplicateCurrentLine(); setActionSheetOpen(false); }} />
          <SheetRow icon="x-circle" label="Delete line" onPress={() => { deleteCurrentLine(); setActionSheetOpen(false); }} />
          <SheetRow icon="list" label="Sort lines" onPress={() => { sortLines(); setActionSheetOpen(false); }} />
          <SheetRow icon="align-left" label="Trim spaces" onPress={() => { trimTrailingSpaces(); setActionSheetOpen(false); }} />
        </SheetSection>
        <SheetSection title="View">
          <SheetRow icon={readMode ? "eye" : "eye-off"} label="Read mode" hint="Hides the keyboard" checked={readMode} onPress={() => { setReadMode((c) => !c); setActionSheetOpen(false); }} />
          <SheetRow icon="maximize-2" label="Zen mode" checked={zenMode} onPress={() => { setZenMode((c) => !c); setActionSheetOpen(false); }} />
          <SheetRow icon="columns" label="Compare documents" checked={compareOpen} onPress={() => { toggleCompare(); setActionSheetOpen(false); }} />
          <SheetRow icon="mouse-pointer" label="Trackpad" hint="On-screen pointer" checked={mouseOn} onPress={() => { setMouseOn((c) => !c); setActionSheetOpen(false); }} />
        </SheetSection>
        <SheetSection title="Tools">
          <SheetRow icon="code" label="Change syntax..." onPress={() => { setLangOpen(true); setActionSheetOpen(false); }} />
          <SheetRow icon="settings" label="Preferences..." onPress={() => { setPrefsOpen(true); setActionSheetOpen(false); }} />
        </SheetSection>
        <SheetSection title="Help">
          <SheetRow icon="info" label="About Notepad 3++" onPress={() => { setAboutOpen(true); setActionSheetOpen(false); }} />
        </SheetSection>
      </ScrollView>
    </Pressable>
  </Pressable>
</Modal>
```

- [ ] **Step 4: Verify the sheet opens and items work**

In Expo Go, tap the "•••" button in the title bar. A bottom sheet should slide up with sections File / Edit / View / Tools / Help. Tap a few items to confirm behavior (e.g., New creates a new note; Zen mode toggles).

- [ ] **Step 5: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): mobile action sheet replaces dropdown menus"
```

---

### Task 5: Move toolbar to the bottom in mobile mode with larger icons

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Find the existing toolbar block and gate it**

Find the block starting around line 835 with `{!zenMode && toolbarOpen ? (() => {` — this is the IIFE that renders the top toolbar. Change its condition to hide this toolbar in mobile mode:

```tsx
{!zenMode && toolbarOpen && !isMobile ? (() => {
  // ... existing classic toolbar IIFE body unchanged ...
})() : null}
```

- [ ] **Step 2: Add a new bottom toolbar for mobile**

Place this block AFTER the final `</View>` of the main content area (just before the Modals section, around line 1090). It renders absolutely positioned at the bottom of the screen:

```tsx
{!zenMode && isMobile ? (
  <View style={[styles.mobileBottomBar, { backgroundColor: colors.card, borderColor: colors.border, paddingBottom: insets.bottom || 8 }]}>
    <Pressable onPress={() => setTabListOpen(true)} style={styles.mobileBottomBtn} testID="mobile-docs" hitSlop={8}>
      <Feather name="list" size={22} color={colors.foreground} />
      <Text style={[styles.mobileBottomLabel, { color: colors.mutedForeground }]}>Docs</Text>
    </Pressable>
    <Pressable onPress={() => { setFindOpen(!findOpen); setReplaceOpen(false); }} style={styles.mobileBottomBtn} testID="mobile-find" hitSlop={8}>
      <Feather name="search" size={22} color={findOpen ? colors.primary : colors.foreground} />
      <Text style={[styles.mobileBottomLabel, { color: findOpen ? colors.primary : colors.mutedForeground }]}>Find</Text>
    </Pressable>
    <Pressable onPress={() => setReadMode((c) => !c)} style={styles.mobileBottomBtn} testID="mobile-read" hitSlop={8}>
      <Feather name={readMode ? "eye" : "eye-off"} size={22} color={readMode ? colors.primary : colors.foreground} />
      <Text style={[styles.mobileBottomLabel, { color: readMode ? colors.primary : colors.mutedForeground }]}>Read</Text>
    </Pressable>
    <Pressable onPress={toggleCompare} style={styles.mobileBottomBtn} testID="mobile-compare" hitSlop={8}>
      <Feather name="columns" size={22} color={compareOpen ? colors.primary : colors.foreground} />
      <Text style={[styles.mobileBottomLabel, { color: compareOpen ? colors.primary : colors.mutedForeground }]}>Compare</Text>
    </Pressable>
    <Pressable onPress={() => setActionSheetOpen(true)} style={styles.mobileBottomBtn} testID="mobile-more" hitSlop={8}>
      <Feather name="more-horizontal" size={22} color={colors.foreground} />
      <Text style={[styles.mobileBottomLabel, { color: colors.mutedForeground }]}>More</Text>
    </Pressable>
  </View>
) : null}
```

- [ ] **Step 3: Add bottom-bar styles**

In the `styles` StyleSheet, near the other toolbar styles:

```tsx
mobileBottomBar: { position: "absolute", left: 0, right: 0, bottom: 0, flexDirection: "row", justifyContent: "space-around", alignItems: "flex-start", borderTopWidth: 1, paddingTop: 6, paddingHorizontal: 4, zIndex: 50 },
mobileBottomBtn: { flex: 1, alignItems: "center", justifyContent: "center", paddingVertical: 6, minHeight: 48 },
mobileBottomLabel: { fontFamily: "Inter_500Medium", fontSize: 10, marginTop: 2 },
```

- [ ] **Step 4: Ensure the editor scroll area has bottom padding in mobile mode so the bar doesn't overlap**

Find the main container View (around line 736, `<View style={[styles.container, { paddingTop: ..., paddingBottom: ... }]}>`) and change its `paddingBottom` to account for the 64ish-px bottom bar when in mobile mode:

```tsx
<View style={[styles.container, { paddingTop: Platform.OS === "web" ? 67 : insets.top, paddingBottom: (Platform.OS === "web" ? 34 : insets.bottom) + (isMobile && !zenMode ? 64 : 0) }]}>
```

- [ ] **Step 5: Verify**

Expected: in mobile mode with `zenMode` off, a 5-button bottom bar renders: Docs / Find / Read / Compare / More. Each button has a 48pt touch target. Tapping More opens the action sheet from Task 4.

- [ ] **Step 6: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): mobile bottom toolbar with 5 primary actions"
```

---

### Task 6: Add FAB for New Note (mobile mode only)

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Add the FAB next to the bottom bar block**

Immediately AFTER the bottom-bar block from Task 5, add:

```tsx
{!zenMode && isMobile ? (
  <Pressable
    onPress={() => { createNote(); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium); }}
    style={({ pressed }) => [styles.mobileFab, { backgroundColor: colors.primary, bottom: 80 + (insets.bottom || 0), opacity: pressed ? 0.85 : 1 }]}
    testID="mobile-fab-new"
  >
    <Feather name="plus" size={26} color={colors.primaryForeground} />
  </Pressable>
) : null}
```

- [ ] **Step 2: Add FAB styles**

```tsx
mobileFab: { position: "absolute", right: 16, width: 56, height: 56, borderRadius: 28, alignItems: "center", justifyContent: "center", zIndex: 60, shadowColor: "#000", shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.25, shadowRadius: 6, elevation: 6 },
```

- [ ] **Step 3: Verify**

Expected: a circular "+" button floats above the bottom bar in the lower-right. Tap creates a new note and triggers a medium haptic.

- [ ] **Step 4: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): add New Note FAB in mobile mode"
```

---

### Task 7: Hide line numbers by default on mobile

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Find the `EditorGutter` usage**

Find `<EditorGutter lineCount={stats.lines} />` (around line 1034). Wrap it in a mobile check:

```tsx
{!isMobile ? <EditorGutter lineCount={stats.lines} /> : null}
```

- [ ] **Step 2: Verify**

Expected: in mobile mode, the left-side line-number column is gone, giving the editor more horizontal room.

- [ ] **Step 3: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): hide editor gutter on mobile by default"
```

---

### Task 8: Bump editor font size on mobile

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Find the editor TextInput and adjust style**

Find the main editor `TextInput` (the one with `testID="editor-input"`, around line 1035). It currently uses `styles.editorInput`. Add a mobile-only size override:

```tsx
<TextInput editable={!readMode} value={activeNote.body} onChangeText={(body) => updateActiveNote({ body })} multiline textAlignVertical="top" autoCapitalize="none" autoCorrect={false} spellCheck={false} style={[styles.editorInput, { color: colors.foreground }, isMobile ? { fontSize: 16, lineHeight: 24 } : null]} placeholder="Start typing..." placeholderTextColor={colors.mutedForeground} selection={selection} onSelectionChange={(event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => setSelection(event.nativeEvent.selection)} testID="editor-input" />
```

- [ ] **Step 2: Verify**

Expected: in mobile mode the editor body font is clearly larger (16pt vs whatever the classic size was). Classic mode is unchanged.

- [ ] **Step 3: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): larger editor font size on mobile"
```

---

### Task 9: Add layoutMode toggle to Preferences

**Files:**
- Modify: `artifacts/mobile/app/index.tsx`

- [ ] **Step 1: Find the existing Preferences modal body**

Find the `<Modal visible={prefsOpen}` block around line 1208. Locate the section where other layout prefs are rendered — look for existing uses of `setTabsLayout` or `setToolbarLabels` inside the prefs body. Add a new row for layout mode near those.

If the Preferences modal doesn't already have inline layout options (just a TL;DR of the modal contents), add this block inside the prefs scrollable area, right before or after the tabs-layout row:

```tsx
<View style={{ paddingVertical: 8, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: colors.border }}>
  <Text style={{ fontFamily: "Inter_700Bold", fontSize: 13, color: colors.foreground, marginBottom: 6 }}>Layout</Text>
  <View style={{ flexDirection: "row", gap: 8 }}>
    <Pressable onPress={() => setLayoutMode("classic")} style={{ flex: 1, padding: 10, borderRadius: 6, borderWidth: 1, borderColor: layoutMode === "classic" ? colors.primary : colors.border, backgroundColor: layoutMode === "classic" ? colors.primary : "transparent" }}>
      <Text style={{ fontFamily: "Inter_500Medium", fontSize: 13, color: layoutMode === "classic" ? colors.primaryForeground : colors.foreground, textAlign: "center" }}>Classic</Text>
      <Text style={{ fontFamily: "Inter_400Regular", fontSize: 10, color: layoutMode === "classic" ? colors.primaryForeground : colors.mutedForeground, textAlign: "center", marginTop: 2 }}>Desktop-style menus</Text>
    </Pressable>
    <Pressable onPress={() => setLayoutMode("mobile")} style={{ flex: 1, padding: 10, borderRadius: 6, borderWidth: 1, borderColor: layoutMode === "mobile" ? colors.primary : colors.border, backgroundColor: layoutMode === "mobile" ? colors.primary : "transparent" }}>
      <Text style={{ fontFamily: "Inter_500Medium", fontSize: 13, color: layoutMode === "mobile" ? colors.primaryForeground : colors.foreground, textAlign: "center" }}>Mobile</Text>
      <Text style={{ fontFamily: "Inter_400Regular", fontSize: 10, color: layoutMode === "mobile" ? colors.primaryForeground : colors.mutedForeground, textAlign: "center", marginTop: 2 }}>Bottom bar + sheet</Text>
    </Pressable>
  </View>
</View>
```

- [ ] **Step 2: Verify**

Expected: opening Preferences shows a new "Layout" section with two cards (Classic / Mobile). Tapping a card switches immediately and the change persists across restarts.

- [ ] **Step 3: Commit**

```bash
git add artifacts/mobile/app/index.tsx
git commit -m "feat(ui): add layout mode selector in preferences"
```

---

### Task 10: Parse + typecheck verification

**Files:**
- Read only

- [ ] **Step 1: Parse check**

Run in WSL:

```bash
cd /home/corey/repos/xuninc/Notepad3-/artifacts/mobile
node -e "const ts=require('typescript'); const s=require('fs').readFileSync('app/index.tsx','utf8'); const sf=ts.createSourceFile('i.tsx',s,ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX); const d=sf.parseDiagnostics||[]; if(d.length){for(const x of d.slice(0,5)){const p=sf.getLineAndCharacterOfPosition(x.start);console.log('ERR line',p.line+1,typeof x.messageText==='string'?x.messageText:x.messageText.messageText);}}else console.log('parse ok');"
```

(requires `typescript` available — install in `/tmp/tsparse` if missing)
Expected: `parse ok`

- [ ] **Step 2: Full typecheck if deps are installed**

```bash
cd /home/corey/repos/xuninc/Notepad3- && pnpm install && cd artifacts/mobile && pnpm exec tsc --noEmit
```

Expected: no errors. If errors reference missing imports of `Dimensions` or `Feather`, add them to the corresponding import blocks at the top of the affected file.

- [ ] **Step 3: Smoke test in Expo Go**

```bash
cd artifacts/mobile && pnpm exec expo start
```

In the Expo Go app, verify:
- On first launch (small screen), app boots into mobile mode automatically
- Title bar shows "•••" on the right
- Tap "•••" opens a bottom sheet with File/Edit/View/Tools/Help sections
- Bottom bar shows 5 buttons: Docs, Find, Read, Compare, More
- FAB "+" is in the bottom-right
- Preferences → Layout lets you switch Classic / Mobile and the change is instant
- In Classic mode, the old menu bar + top toolbar is back and the mobile controls are hidden

- [ ] **Step 4: Commit (if any small fixes were needed during verification)**

```bash
git add -A
git commit -m "chore: typecheck fixes after mobile-layout rollout"
```

---

## Self-review notes

- Task 1 covers persistence; Task 2 gates menu bar; Tasks 3–4 build the ••• sheet; Task 5 adds bottom toolbar; Task 6 adds FAB; Tasks 7–8 are mobile typography/layout tweaks; Task 9 adds the user-facing toggle; Task 10 verifies.
- `layoutMode` is the single source of truth for classic vs mobile. All conditional rendering gates off `isMobile = layoutMode === "mobile"`.
- No duplicate menu logic — the existing menu item handlers (`createNote`, `cutSelection`, etc.) are reused in both the old dropdowns and the new sheet, so renaming/refactoring one set automatically keeps the other consistent.
- Existing modals (rename, prefs, lang, about, tabList, tabMenu, goto) still work identically in both layouts.
- Read mode and Zen mode (already added) continue to function alongside the new layout mode.
