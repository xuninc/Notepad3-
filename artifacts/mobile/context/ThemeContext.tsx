import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";
import { useColorScheme } from "react-native";

import colorsModule, { Palette, themes, ThemeName } from "@/constants/colors";

type ThemePreference = ThemeName | "system";
export type TabsLayout = "tabs" | "list";
export type ToolbarRows = "single" | "double";

const VALID: ThemePreference[] = ["classic", "light", "dark", "retro", "modern", "cyberpunk", "sunset", "system"];
const VALID_TABS: TabsLayout[] = ["tabs", "list"];
const VALID_ROWS: ToolbarRows[] = ["single", "double"];

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
  palette: Palette;
  radius: number;
};

const STORAGE_KEY = "notepad3pp.themePreference";
const TABS_KEY = "notepad3pp.tabsLayout.v2";
const LABELS_KEY = "notepad3pp.toolbarLabels";
const ROWS_KEY = "notepad3pp.toolbarRows";

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const systemScheme = useColorScheme();
  const [preference, setPreferenceState] = useState<ThemePreference>("classic");
  const [tabsLayout, setTabsLayoutState] = useState<TabsLayout>("tabs");
  const [toolbarLabels, setToolbarLabelsState] = useState<boolean>(false);
  const [toolbarRows, setToolbarRowsState] = useState<ToolbarRows>("single");

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

  const themeName: ThemeName = preference === "system" ? (systemScheme === "dark" ? "dark" : "light") : preference;

  const palette = themes[themeName];
  const value = useMemo<ThemeContextValue>(
    () => ({ themeName, preference, setPreference, tabsLayout, setTabsLayout, toolbarLabels, setToolbarLabels, toolbarRows, setToolbarRows, palette, radius: palette.radius ?? colorsModule.radius }),
    [themeName, preference, tabsLayout, toolbarLabels, toolbarRows, palette],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used inside ThemeProvider");
  return ctx;
}
