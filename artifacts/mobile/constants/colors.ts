/**
 * Semantic design tokens for the mobile app.
 *
 * These tokens mirror the naming conventions used in web artifacts (index.css)
 * so that multi-artifact projects share a cohesive visual identity.
 *
 * Replace the placeholder values below with values that match the project's
 * brand. If a sibling web artifact exists, read its index.css and convert the
 * HSL values to hex so both artifacts use the same palette.
 *
 * To add dark mode, add a `dark` key with the same token names.
 * The useColors() hook will automatically pick it up.
 */

const colors = {
  light: {
    text: "#1a1c22",
    tint: "#d9822b",
    background: "#f3eadc",
    foreground: "#1a1c22",
    card: "#fff9ee",
    cardForeground: "#1a1c22",
    primary: "#d9822b",
    primaryForeground: "#15171c",
    secondary: "#233047",
    secondaryForeground: "#fff9ee",
    muted: "#e7dcc9",
    mutedForeground: "#6f695f",
    accent: "#4d6d7f",
    accentForeground: "#fff9ee",
    destructive: "#b84242",
    destructiveForeground: "#fff9ee",
    border: "#d8cab4",
    input: "#d8cab4",
    editorBackground: "#fffdf7",
    editorGutter: "#ede0ca",
    success: "#4f7d57",
  },
  dark: {
    text: "#f7efdf",
    tint: "#f0a756",
    background: "#111826",
    foreground: "#f7efdf",
    card: "#182235",
    cardForeground: "#f7efdf",
    primary: "#f0a756",
    primaryForeground: "#111826",
    secondary: "#2b3b59",
    secondaryForeground: "#f7efdf",
    muted: "#243147",
    mutedForeground: "#aeb5c1",
    accent: "#78a0ad",
    accentForeground: "#111826",
    destructive: "#ff7777",
    destructiveForeground: "#111826",
    border: "#30405b",
    input: "#30405b",
    editorBackground: "#0d1320",
    editorGutter: "#162033",
    success: "#83b98c",
  },
  radius: 18,
};

export default colors;
