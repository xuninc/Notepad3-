# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Each package manages its own dependencies.

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)

## Artifacts

- **Notepad 3++** (`artifacts/mobile`) — Expo iPhone Notepad2-style editor with local AsyncStorage persistence, file import from the device file manager, multi-document tabs, a line-numbered editor, find/replace with case-sensitive matching, top/bottom synced document comparison with traditional diff markers, language modes including Assembly/JavaScript/Python/Web/JSON, syntax-colored code previews and compare panes, line/word/character/cursor stats, autosave status, note duplication/deletion, and Notepad++-inspired line tools for timestamp insertion, duplicate line, cut line, sort lines, and trim trailing spaces.

## Key Commands

- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- `pnpm --filter @workspace/api-server run dev` — run API server locally

See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details.
