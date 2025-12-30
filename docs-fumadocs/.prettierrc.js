/**
 * @see https://prettier.io/docs/configuration
 * @type {import("prettier").Config}
 */
const config = {
  jsxSingleQuote: true,
  printWidth: 80,
  semi: true,
  singleQuote: true,
  tabWidth: 2,
  trailingComma: 'all',

  plugins: ['@trivago/prettier-plugin-sort-imports'],

  // @trivago/prettier-plugin-sort-imports
  importOrder: [
    '<BUILTIN_MODULES>',
    '^react(/.*)?$',
    '^next(/.*)?$',
    '^fumadocs',
    '<THIRD_PARTY_MODULES>',
    '^@/(.*)$',
    '^[./]',
  ],
  importOrderSeparation: false,
  importOrderSortSpecifiers: true,
};

export default config;
