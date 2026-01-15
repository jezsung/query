import fs from 'fs';
import p from 'path';
import yaml from 'yaml';

export interface Pubspec {
  version: string;
  dependencies: Record<string, string>;
}

/**
 * Reads and parses a pubspec.yaml file.
 * @param path - Path to the pubspec.yaml file or directory containing it
 */
export function getPubspec(path: string): Pubspec {
  if (!path.endsWith('pubspec.yaml')) {
    path = p.join(path, 'pubspec.yaml');
  }
  const raw = fs.readFileSync(path, 'utf8');
  return yaml.parse(raw) as Pubspec;
}

/**
 * Resolves a path relative to the project root (docs directory).
 */
export function fromRoot(path: string): string {
  return p.join(process.cwd(), path);
}
