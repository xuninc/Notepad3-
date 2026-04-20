import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";
import { Dimensions, useColorScheme } from "react-native";

import colorsModule, { buildCustomPalette, CustomPaletteKey, CustomPaletteOverrides, customDefaults, Palette, themes, ThemeName } from "@/constants/colors";

type ThemePreference = ThemeName | "system";
export type TabsLayout = "tabs" | "list";
export type ToolbarRows = "single" | "double";
export type LayoutMode = "classic" | "mobile";

const VALID: ThemePreference[] = ["classic", "light", "dark", "retro", "modern", "cyberpunk", "sunset", "custom", "system"];
const VALID_TABS: TabsLayout[] = ["tabs", "list"];
const VALID_ROWS: ToolbarRows[] = ["single", "double"];
const VALID_LAYOUT: LayoutMode[] = ["classic", "mobile"];

type ThemeContextValue = {
  themeName: ThemeName;
  preference: ThemePreference;
  setPreference: (preference: ThemePreference) => void;
  tabsLayout: TabsLayout;
  setTabsLayout: (layout: TabsLayout) => void;
  toolbarLabels: boolean;
  setToolbarLabels: (next: boolean) => void;
  toolbarRows: ToolbarRows;
  setToolbarRows: (next: ToolbarRows) => void;
  layoutMode: LayoutMode;
  setLayoutMode: (mode: LayoutMode) => void;
  customPalette: CustomPaletteOverrides;
  setCustomColor: (key: CustomPaletteKey, value: string) => void;
  resetCustomPalette: () => void;
  palette: Palette;
  radius: number;
};

const STORAGE_KEY = "notepad3pp.themePreference";
const TABS_KEY = "notepad3pp.tabsLayout.v2";
const LABELS_KEY = "notepad3pp.toolbarLabels";
const ROWS_KEY = "notepad3pp.toolbarRows";
const CUSTOM_KEY = "notepad3pp.customPalette";
const LAYOUT_KEY = "notepad3pp.layoutMode";
// Set on startup when we're about to render classic layout; cleared once we've stayed
// alive long enough to know that render didn't crash. If we boot up and find this flag
// still set, the previous attempt didn't survive — fall back to mobile so the app stays
// reachable instead of looping into the same crash.
const LAYOUT_PENDING_KEY = "notepad3pp.layoutMode.pendingClassic";
const LAYOUT_STABLE_MS = 1500;

export async function resetLayoutModeToMobile(): Promise<void> {
  await Promise.all([
    AsyncStorage.setItem(LAYOUT_KEY, "mobile"),
    AsyncStorage.removeItem(LAYOUT_PENDING_KEY),
  ]).catch(() => undefined);
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const systemScheme = useColorScheme();
  const [preference, setPreferenceState] = useState<ThemePreference>("classic");
  const [tabsLayout, setTabsLayoutState] = useState<TabsLayout>("tabs");
  const [toolbarLabels, setToolbarLabelsState] = useState<boolean>(false);
  const [toolbarRows, setToolbarRowsState] = useState<ToolbarRows>("single");
  const [layoutMode, setLayoutModeState] = useState<LayoutMode>(() => {
    const { width } = Dimensions.get("window");
    return width < 768 ? "mobile" : "classic";
  });
  const [customPalette, setCustomPaletteState] = useState<CustomPaletteOverrides>({});

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY)
      .then((value) => {
        if (value && (VALID as string[]).includes(value)) {
          setPreferenceState(value as ThemePreference);
        }
      })
      .catch(() => undefined);
    AsyncStorage.getItem(TABS_KEY)
      .then((value) => {
        if (value && (VALID_TABS as string[]).includes(value)) {
          setTabsLayoutState(value as TabsLayout);
        }
      })
      .catch(() => undefined);
    AsyncStorage.getItem(LABELS_KEY)
      .then((value) => {
        if (value === "true" || value === "false") setToolbarLabelsState(value === "true");
      })
      .catch(() => undefined);
    AsyncStorage.getItem(ROWS_KEY)
      .then((value) => {
        if (value && (VALID_ROWS as string[]).includes(value)) setToolbarRowsState(value as ToolbarRows);
      })
      .catch(() => undefined);
    Promise.all([AsyncStorage.getItem(LAYOUT_KEY), AsyncStorage.getItem(LAYOUT_PENDING_KEY)])
      .then(([value, pending]) => {
        if (value && (VALID_LAYOUT as string[]).includes(value)) {
          if (value === "classic" && pending === "1") {
            AsyncStorage.setItem(LAYOUT_KEY, "mobile").catch(() => undefined);
            AsyncStorage.removeItem(LAYOUT_PENDING_KEY).catch(() => undefined);
            setLayoutModeState("mobile");
            return;
          }
          setLayoutModeState(value as LayoutMode);
          if (value === "classic") {
            AsyncStorage.setItem(LAYOUT_PENDING_KEY, "1").catch(() => undefined);
          }
        }
      })
      .catch(() => undefined);
    AsyncStorage.getItem(CUSTOM_KEY)
      .then((value) => {
        if (!value) return;
        try {
          const parsed = JSON.parse(value);
          if (parsed && typeof parsed === "object") setCustomPaletteState(parsed as CustomPaletteOverrides);
        } catch {
          // ignore
        }
      })
      .catch(() => undefined);
  }, []);

  const setPreference = (next: ThemePreference) => {
    setPreferenceState(next);
    AsyncStorage.setItem(STORAGE_KEY, next).catch(() => undefined);
  };

  const setTabsLayout = (next: TabsLayout) => {
    setTabsLayoutState(next);
    AsyncStorage.setItem(TABS_KEY, next).catch(() => undefined);
  };

  const setToolbarLabels = (next: boolean) => {
    setToolbarLabelsState(next);
    AsyncStorage.setItem(LABELS_KEY, next ? "true" : "false").catch(() => undefined);
  };

  const setToolbarRows = (next: ToolbarRows) => {
    setToolbarRowsState(next);
    AsyncStorage.setItem(ROWS_KEY, next).catch(() => undefined);
  };

  const setLayoutMode = (next: LayoutMode) => {
    setLayoutModeState(next);
    AsyncStorage.setItem(LAYOUT_KEY, next).catch(() => undefined);
    if (next === "classic") {
      AsyncStorage.setItem(LAYOUT_PENDING_KEY, "1").catch(() => undefined);
    } else {
      AsyncStorage.removeItem(LAYOUT_PENDING_KEY).catch(() => undefined);
    }
  };

  useEffect(() => {
    if (layoutMode !== "classic") return;
    const t = setTimeout(() => {
      AsyncStorage.removeItem(LAYOUT_PENDING_KEY).catch(() => undefined);
    }, LAYOUT_STABLE_MS);
    return () => clearTimeout(t);
  }, [layoutMode]);

  const setCustomColor = (key: CustomPaletteKey, value: string) => {
    setCustomPaletteState((prev) => {
      const next = { ...prev, [key]: value };
      AsyncStorage.setItem(CUSTOM_KEY, JSON.stringify(next)).catch(() => undefined);
      return next;
    });
  };

  const resetCustomPalette = () => {
    setCustomPaletteState({});
    AsyncStorage.removeItem(CUSTOM_KEY).catch(() => undefined);
  };

  const themeName: ThemeName = preference === "system" ? (systemScheme === "dark" ? "dark" : "light") : preference;

  const palette = themeName === "custom" ? buildCustomPalette(customPalette) : themes[themeName];
  void customDefaults;
  const value = useMemo<ThemeContextValue>(
    () => ({ themeName, preference, setPreference, tabsLayout, setTabsLayout, toolbarLabels, setToolbarLabels, toolbarRows, setToolbarRows, layoutMode, setLayoutMode, customPalette, setCustomColor, resetCustomPalette, palette, radius: palette.radius ?? colorsModule.radius }),
    [themeName, preference, tabsLayout, toolbarLabels, toolbarRows, layoutMode, customPalette, palette],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used inside ThemeProvider");
  return ctx;
}
