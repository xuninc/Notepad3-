import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";
import { useColorScheme } from "react-native";

import colorsModule, { Palette, themes, ThemeName } from "@/constants/colors";

type ThemePreference = ThemeName | "system";
export type TabsLayout = "tabs" | "list";

const VALID: ThemePreference[] = ["classic", "light", "dark", "retro", "modern", "cyberpunk", "system"];
const VALID_TABS: TabsLayout[] = ["tabs", "list"];

type ThemeContextValue = {
  themeName: ThemeName;
  preference: ThemePreference;
  setPreference: (preference: ThemePreference) => void;
  tabsLayout: TabsLayout;
  setTabsLayout: (layout: TabsLayout) => void;
  palette: Palette;
  radius: number;
};

const STORAGE_KEY = "notepad3pp.themePreference";
const TABS_KEY = "notepad3pp.tabsLayout";

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const systemScheme = useColorScheme();
  const [preference, setPreferenceState] = useState<ThemePreference>("classic");
  const [tabsLayout, setTabsLayoutState] = useState<TabsLayout>("tabs");

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
  }, []);

  const setPreference = (next: ThemePreference) => {
    setPreferenceState(next);
    AsyncStorage.setItem(STORAGE_KEY, next).catch(() => undefined);
  };

  const setTabsLayout = (next: TabsLayout) => {
    setTabsLayoutState(next);
    AsyncStorage.setItem(TABS_KEY, next).catch(() => undefined);
  };

  const themeName: ThemeName = preference === "system" ? (systemScheme === "dark" ? "dark" : "light") : preference;

  const palette = themes[themeName];
  const value = useMemo<ThemeContextValue>(
    () => ({ themeName, preference, setPreference, tabsLayout, setTabsLayout, palette, radius: palette.radius ?? colorsModule.radius }),
    [themeName, preference, tabsLayout, palette],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used inside ThemeProvider");
  return ctx;
}
