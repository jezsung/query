import { DynamicCodeBlock } from 'fumadocs-ui/components/dynamic-codeblock';

interface PubspecProps {
  dependencies: Record<string, string>;
}

export function Pubspec({ dependencies }: PubspecProps) {
  const lines = Object.entries(dependencies)
    .filter(([_, version]) => version !== undefined && version !== null)
    .map(([name, version]) => `  ${name}: ${version}`)
    .join('\n');

  const code = `dependencies:\n${lines}`;

  return (
    <DynamicCodeBlock
      lang='yaml'
      code={code}
      codeblock={{ title: 'pubspec.yaml' }}
    />
  );
}
