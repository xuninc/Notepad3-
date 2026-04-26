import * as Clipboard from "expo-clipboard";
import { reloadAppAsync } from "expo";
import React from "react";
import {
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { useColors } from "@/hooks/useColors";
import { resetLayoutModeToMobile } from "@/context/ThemeContext";

export type ErrorFallbackProps = {
  error: Error;
  resetError: () => void;
};

export function ErrorFallback({ error, resetError }: ErrorFallbackProps) {
  const colors = useColors();
  const insets = useSafeAreaInsets();

  const handleRestart = async () => {
    try {
      await resetLayoutModeToMobile();
      await reloadAppAsync();
    } catch (restartError) {
      console.error("Failed to restart app:", restartError);
      resetError();
    }
  };

  const handleSafeMode = async () => {
    try {
      await resetLayoutModeToMobile();
    } catch {
      // ignore — resetError() still gives the user a way out
    }
    resetError();
  };

  const formatErrorDetails = (): string => {
    let details = `Error: ${error.message}\n\n`;
    if (error.stack) {
      const lines = error.stack.split("\n").slice(0, 12).join("\n");
      details += `Stack:\n${lines}`;
    }
    return details;
  };

  const handleCopy = async () => {
    try {
      await Clipboard.setStringAsync(formatErrorDetails());
    } catch {
      // ignore
    }
  };

  const monoFont = Platform.select({
    ios: "Menlo",
    android: "monospace",
    default: "monospace",
  });

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.background }}
      contentContainerStyle={[styles.container, { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 24 }]}
      showsVerticalScrollIndicator
    >
      <View style={styles.content}>
        <Text style={[styles.title, { color: colors.foreground }]}>
          Something went wrong
        </Text>

        <Text style={[styles.message, { color: colors.mutedForeground }]}>
          Tap a button below to recover. The error details are at the bottom — copy and share them if this keeps happening.
        </Text>

        <Pressable
          onPress={handleRestart}
          style={({ pressed }) => [
            styles.button,
            {
              backgroundColor: colors.primary,
              opacity: pressed ? 0.9 : 1,
              transform: [{ scale: pressed ? 0.98 : 1 }],
            },
          ]}
        >
          <Text style={[styles.buttonText, { color: colors.primaryForeground }]}>Try Again</Text>
        </Pressable>

        <Pressable
          onPress={handleSafeMode}
          style={({ pressed }) => [
            styles.button,
            styles.secondaryButton,
            { borderColor: colors.border, opacity: pressed ? 0.85 : 1 },
          ]}
        >
          <Text style={[styles.buttonText, { color: colors.foreground }]}>Use mobile layout</Text>
        </Pressable>

        <View style={[styles.errorBlock, { backgroundColor: colors.card, borderColor: colors.border }]}>
          <View style={styles.errorHeader}>
            <Text style={[styles.errorHeaderText, { color: colors.mutedForeground }]}>Error details</Text>
            <Pressable
              onPress={handleCopy}
              style={({ pressed }) => [styles.copyButton, { borderColor: colors.border, opacity: pressed ? 0.6 : 1 }]}
            >
              <Text style={[styles.copyButtonText, { color: colors.foreground }]}>Copy</Text>
            </Pressable>
          </View>
          <Text selectable style={[styles.errorText, { color: colors.foreground, fontFamily: monoFont }]}>
            {formatErrorDetails()}
          </Text>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    width: "100%",
    alignItems: "center",
    paddingHorizontal: 24,
  },
  content: {
    alignItems: "center",
    gap: 16,
    width: "100%",
    maxWidth: 600,
  },
  title: {
    fontSize: 28,
    fontWeight: "700",
    textAlign: "center",
    lineHeight: 40,
  },
  message: {
    fontSize: 14,
    textAlign: "center",
    lineHeight: 20,
  },
  button: {
    paddingVertical: 16,
    borderRadius: 8,
    paddingHorizontal: 24,
    minWidth: 220,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  secondaryButton: {
    backgroundColor: "transparent",
    borderWidth: 1,
    shadowOpacity: 0,
    elevation: 0,
  },
  buttonText: {
    fontWeight: "600",
    textAlign: "center",
    fontSize: 16,
  },
  errorBlock: {
    width: "100%",
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    marginTop: 8,
  },
  errorHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  errorHeaderText: {
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 0.6,
    textTransform: "uppercase",
  },
  copyButton: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 4,
    borderWidth: 1,
  },
  copyButtonText: {
    fontSize: 12,
    fontWeight: "600",
  },
  errorText: {
    fontSize: 11,
    lineHeight: 16,
    width: "100%",
  },
});
