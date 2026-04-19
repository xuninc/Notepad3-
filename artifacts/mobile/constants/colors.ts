export type ThemeName = "classic" | "light" | "dark";

export type Palette = {
  text: string;
  tint: string;
  background: string;
  foreground: string;
  card: string;
  cardForeground: string;
  primary: string;
  primaryForeground: string;
  secondary: string;
  secondaryForeground: string;
  muted: string;
  mutedForeground: string;
  accent: string;
  accentForeground: string;
  destructive: string;
  destructiveForeground: string;
  border: string;
  input: string;
  editorBackground: string;
  editorGutter: string;
  success: string;
};

export const themes: Record<ThemeName, Palette> = {
  classic: {
    text: "#000000",
    tint: "#0a246a",
    background: "#c0c0c0",
    foreground: "#000000",
    card: "#d4d0c8",
    cardForeground: "#000000",
    primary: "#0a246a",
    primaryForeground: "#ffffff",
    secondary: "#b8b4a8",
    secondaryForeground: "#000000",
    muted: "#dcdcdc",
    mutedForeground: "#404040",
    accent: "#316ac5",
    accentForeground: "#ffffff",
    destructive: "#7a0000",
    destructiveForeground: "#ffffff",
    border: "#808080",
    input: "#808080",
    editorBackground: "#ffffff",
    editorGutter: "#ebebeb",
    success: "#005900",
  },
  light: {
    text: "#1a1a1a",
    tint: "#0a64a4",
    background: "#f3f3f3",
    foreground: "#1a1a1a",
    card: "#ffffff",
    cardForeground: "#1a1a1a",
    primary: "#0a64a4",
    primaryForeground: "#ffffff",
    secondary: "#e6e6e6",
    secondaryForeground: "#1a1a1a",
    muted: "#f0f0f0",
    mutedForeground: "#5a5a5a",
    accent: "#0a64a4",
    accentForeground: "#ffffff",
    destructive: "#a83232",
    destructiveForeground: "#ffffff",
    border: "#cfcfcf",
    input: "#cfcfcf",
    editorBackground: "#ffffff",
    editorGutter: "#f4f4f4",
    success: "#1f6f3f",
  },
  dark: {
    text: "#e6e6e6",
    tint: "#7da0d4",
    background: "#1e1e1e",
    foreground: "#e6e6e6",
    card: "#2a2a2a",
    cardForeground: "#e6e6e6",
    primary: "#4ea3dc",
    primaryForeground: "#ffffff",
    secondary: "#3a3a3a",
    secondaryForeground: "#e6e6e6",
    muted: "#262626",
    mutedForeground: "#a8a8a8",
    accent: "#4ea3dc",
    accentForeground: "#ffffff",
    destructive: "#e07070",
    destructiveForeground: "#1a1a1a",
    border: "#3f3f46",
    input: "#3f3f46",
    editorBackground: "#1e1e1e",
    editorGutter: "#262626",
    success: "#7fbf7f",
  },
};

const colors = {
  light: themes.classic,
  dark: themes.dark,
  radius: 0,
};

export default colors;
