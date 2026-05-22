# Docs Authoring Guide

This package is docs content source-of-truth for OpenChamber.

## Add a new docs page

1. Create a new file in `packages/docs/content/docs/`.
   - Example: `packages/docs/content/docs/remote-access.mdx`
2. Add frontmatter at top:

   ```mdx
   ---
   title: Remote Access
   description: Access OpenChamber from outside your local network.
   ---
   ```

3. Use route-safe naming:
   - `foo.mdx` -> `/foo/`
   - `folder/index.mdx` -> `/folder/`
   - `folder/bar.mdx` -> `/folder/bar/`
4. Add translations for the page — see [Localization](#localization). Translations
   are optional per page (a missing translation falls back to English), but ship
   them together with the page when you can.
5. If the page is linked from the sidebar, add its localized labels too — see
   [Translate the sidebar](#translate-the-sidebar).
6. Run validation:

   ```bash
   bun run docs:validate
   ```

## Add a new sidebar section

Edit `packages/docs/sidebar.config.json`.

Example:

```json
{
  "label": "Advanced",
  "items": [{ "label": "Remote Access", "link": "/remote-access/" }]
}
```

Rules:

- use trailing slash in links (`/page/`)
- every sidebar link must map to an existing MDX file
- keep section labels short and task-oriented

## Localization

The docs are translated into the same languages the OpenChamber app ships in.
English is the source of truth and lives at the root of `content/docs/`. Every
other language mirrors the English files under a locale folder.

### Supported locales

| Language | Content folder | Sidebar `translations` key |
| --- | --- | --- |
| English | _(root, no folder)_ | `en` |
| Ukrainian | `uk/` | `uk` |
| Chinese (Simplified) | `zh-cn/` | `zh-CN` |
| Spanish | `es/` | `es` |
| Brazilian Portuguese | `pt-br/` | `pt-BR` |
| Korean | `ko/` | `ko` |
| Polish | `pl/` | `pl` |

> [!IMPORTANT]
> The **content folder** uses the lowercase locale key (`zh-cn`, `pt-br`); the
> **sidebar `translations`** key uses the BCP-47 language tag (`zh-CN`, `pt-BR`).
> They look similar but are not interchangeable — Starlight resolves them with
> different rules. Everything else (`uk`, `es`, `ko`, `pl`, `en`) is identical
> in both columns.

This locale set is mirrored in the website at
`openchamber-website/apps/docs/astro.config.mjs` (`locales`). If a language is
added or removed, update both places.

### Translate a page

Mirror the English file under each locale folder, keeping the **exact same
filename and path**. Starlight matches a translation to its English page by path.

```
content/docs/
  install.mdx              # English (source of truth)
  uk/install.mdx           # Ukrainian
  zh-cn/install.mdx        # Chinese (Simplified)
  es/install.mdx           # Spanish
  pt-br/install.mdx        # Brazilian Portuguese
  ko/install.mdx           # Korean
  pl/install.mdx           # Polish

  guides/tunnels.mdx       # nested English page
  uk/guides/tunnels.mdx    # its Ukrainian translation
```

Each translated file needs its **own translated frontmatter** (`title` and
`description` are required by validation):

```mdx
---
title: Встановлення
description: Встановіть OpenChamber для десктопа, вебу або VS Code.
---
```

You do **not** have to translate every page at once. A page that is missing in a
locale automatically falls back to the English version, so translations can land
incrementally.

### Translate the sidebar

Do **not** create separate sidebar entries per language and do **not** add a
locale prefix to `link` — Starlight prefixes the active locale automatically.
Instead, add a `translations` map (keyed by the BCP-47 tag from the table above)
to each section and item in `sidebar.config.json`:

```json
{
  "label": "Start here",
  "translations": {
    "uk": "Почніть тут",
    "zh-CN": "从这里开始",
    "es": "Empieza aquí",
    "pt-BR": "Comece aqui",
    "ko": "여기서 시작",
    "pl": "Zacznij tutaj"
  },
  "items": [
    {
      "label": "Install",
      "link": "/install/",
      "translations": {
        "uk": "Встановлення",
        "zh-CN": "安装",
        "es": "Instalación",
        "pt-BR": "Instalação",
        "ko": "설치",
        "pl": "Instalacja"
      }
    }
  ]
}
```

A label with no translation for the active locale falls back to the English
`label`.

### What not to translate

- brand and product nouns: OpenChamber, OpenCode, VS Code, PWA, GitHub, Discord,
  macOS, SSH
- code blocks, shell commands, file paths, flags, and config keys
- the page filename and the sidebar `link` (these stay identical across locales)

### Validate

`bun run docs:validate` walks every `.mdx` under `content/docs/` — **including
translations** — and fails if any page is missing `title` or `description`
frontmatter, or if a sidebar `link` does not resolve to an English page. Run it
after adding or translating pages.

## Sync into openchamber-website

`openchamber-website` renders/deploys docs via Starlight in `apps/docs`.

After docs content updates here:

1. copy `packages/docs/content/docs/*` -> `openchamber-website/apps/docs/src/content/docs/*`
   (this is recursive, so locale folders like `uk/` and `zh-cn/` carry over with
   no extra steps)
2. map `packages/docs/sidebar.config.json` into `openchamber-website/apps/docs/astro.config.mjs` sidebar
   (the `translations` maps carry over as-is)
3. run docs checks/build in website repo

Automation support exists in `.github/workflows/docs-source.yml` (release/manual packaging of docs source artifact).
