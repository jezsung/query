import { createElement } from 'react';
import { type InferPageType, LoaderPlugin, loader } from 'fumadocs-core/source';
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons';
import { docs } from 'fumadocs-mdx:collections/server';
import { icons } from 'lucide-react';

// Plugin to use frontmatter permalink if provided
const permalinkPlugin: LoaderPlugin = {
  transformStorage({ storage }) {
    for (const path of storage.getFiles()) {
      const file = storage.read(path);
      if (!file || file.format !== 'page') continue;

      // Check if frontmatter has custom permalink
      const { permalink } = file.data as { permalink?: string };
      if (permalink) {
        file.slugs = permalink.split('/').filter((s) => s !== '');
      }
    }
  },
};

// See https://fumadocs.dev/docs/headless/source-api for more info
export const source = loader({
  baseUrl: '/docs',
  source: docs.toFumadocsSource(),
  plugins: [lucideIconsPlugin(), permalinkPlugin],
  icon(icon) {
    if (!icon) return;

    if (icon in icons) {
      return createElement(icons[icon as keyof typeof icons]);
    }
  },
});

export function getPageImage(page: InferPageType<typeof source>) {
  const segments = [...page.slugs, 'image.png'];

  return {
    segments,
    url: `/og/docs/${segments.join('/')}`,
  };
}

export async function getLLMText(page: InferPageType<typeof source>) {
  const processed = await page.data.getText('processed');

  return `# ${page.data.title}

${processed}`;
}
