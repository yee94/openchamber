import { registerCustomTheme, type ThemeRegistrationResolved } from '@pierre/diffs';
import type { Theme } from '@/types/theme';

// Name of the static Shiki theme we register once. Its token colors reference
// CSS custom properties (`--md-syntax-*`) instead of concrete colors, so a
// highlighted code block does NOT need to be re-tokenized when the app theme
// changes — only the CSS variables on the markdown container update, and the
// browser repaints. This mirrors OpenCode's `var(--syntax-*)` theme approach
// and keeps highlighting results cacheable across theme switches.
export const MARKDOWN_SHIKI_THEME = 'openchamber-md';

let registered = false;

/**
 * Register the static, CSS-variable-driven Shiki theme. Safe to call multiple
 * times; only the first call registers.
 */
export const ensureMarkdownShikiTheme = (): void => {
  if (registered) return;
  registered = true;

  registerCustomTheme(MARKDOWN_SHIKI_THEME, () =>
    Promise.resolve({
      name: MARKDOWN_SHIKI_THEME,
      colors: {
        'editor.background': 'transparent',
        'editor.foreground': 'var(--md-syntax-foreground)',
      },
      tokenColors: [
        {
          scope: ['comment', 'punctuation.definition.comment', 'string.comment'],
          settings: { foreground: 'var(--md-syntax-comment)', fontStyle: 'italic' },
        },
        {
          scope: ['string', 'punctuation.definition.string', 'string.template'],
          settings: { foreground: 'var(--md-syntax-string)' },
        },
        {
          scope: ['constant.numeric', 'constant.language', 'constant.character', 'constant'],
          settings: { foreground: 'var(--md-syntax-number)' },
        },
        {
          scope: ['keyword', 'storage', 'storage.type', 'storage.modifier', 'keyword.control'],
          settings: { foreground: 'var(--md-syntax-keyword)' },
        },
        {
          scope: ['keyword.operator', 'punctuation.separator', 'punctuation.terminator'],
          settings: { foreground: 'var(--md-syntax-operator)' },
        },
        {
          scope: ['entity.name.function', 'support.function', 'meta.function-call'],
          settings: { foreground: 'var(--md-syntax-function)' },
        },
        {
          scope: [
            'entity.name.type',
            'entity.name.class',
            'support.type',
            'support.class',
            'entity.other.inherited-class',
          ],
          settings: { foreground: 'var(--md-syntax-type)' },
        },
        {
          scope: ['variable', 'variable.other', 'variable.parameter', 'meta.definition.variable'],
          settings: { foreground: 'var(--md-syntax-variable)' },
        },
        {
          scope: ['variable.other.property', 'meta.property-name', 'support.type.property-name'],
          settings: { foreground: 'var(--md-syntax-property)' },
        },
        {
          scope: ['entity.name.tag', 'punctuation.definition.tag'],
          settings: { foreground: 'var(--md-syntax-keyword)' },
        },
        {
          scope: ['entity.other.attribute-name'],
          settings: { foreground: 'var(--md-syntax-property)' },
        },
        {
          scope: ['markup.bold', 'punctuation.definition.bold'],
          settings: { fontStyle: 'bold' },
        },
        {
          scope: ['markup.italic', 'punctuation.definition.italic'],
          settings: { fontStyle: 'italic' },
        },
        {
          scope: ['markup.heading', 'markup.heading entity.name'],
          settings: { foreground: 'var(--md-syntax-keyword)', fontStyle: 'bold' },
        },
        {
          scope: ['markup.inserted', 'punctuation.definition.inserted'],
          settings: { foreground: 'var(--md-syntax-inserted)' },
        },
        {
          scope: ['markup.deleted', 'punctuation.definition.deleted'],
          settings: { foreground: 'var(--md-syntax-deleted)' },
        },
        {
          scope: ['invalid', 'invalid.illegal'],
          settings: { foreground: 'var(--md-syntax-deleted)' },
        },
      ],
    } as unknown as ThemeRegistrationResolved),
  );
};

/**
 * Build the `--md-syntax-*` CSS custom properties for the given app theme.
 * Apply the result as inline styles on the markdown container so the static
 * Shiki theme resolves to the active palette.
 */
export const getMarkdownSyntaxVars = (theme: Theme): Record<string, string> => {
  const base = theme.colors.syntax.base;
  const tokens = theme.colors.syntax.tokens ?? {};
  const status = theme.colors.status;

  return {
    '--md-syntax-foreground': base.foreground,
    '--md-syntax-comment': base.comment,
    '--md-syntax-string': base.string,
    '--md-syntax-number': base.number,
    '--md-syntax-keyword': base.keyword,
    '--md-syntax-operator': base.operator,
    '--md-syntax-function': base.function,
    '--md-syntax-type': base.type,
    '--md-syntax-variable': base.variable,
    '--md-syntax-property': tokens.variableProperty ?? base.variable,
    '--md-syntax-inserted': status.success,
    '--md-syntax-deleted': status.error,
  };
};
