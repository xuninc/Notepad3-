import { useTheme } from "@/context/ThemeContext";

export function useColors() {
  const { palette, radius } = useTheme();
  return { ...palette, radius };
}
