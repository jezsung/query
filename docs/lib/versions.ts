import fs from 'fs';
import p from 'path';
import yaml from 'yaml';

interface Pubspec {
  version: string;
  dependencies: Record<string, string>;
}

function getPubspec(path: string): Pubspec {
  if (!path.endsWith('pubspec.yaml')) {
    path = p.join(path, 'pubspec.yaml');
  }
  const raw = fs.readFileSync(path, 'utf8');
  return yaml.parse(raw) as Pubspec;
}

const cwd = process.cwd();

const flutter_query = getPubspec(`${cwd}/../packages/flutter_query`);
const basic_query_with_http = getPubspec(
  `${cwd}/../examples/basic_query_with_http`,
);

const versions = {
  installation: {
    flutter_query: `^${flutter_query.version}`,
    flutter_hooks: flutter_query.dependencies.flutter_hooks,
  },
  basic_query_with_http: {
    ...basic_query_with_http.dependencies,
    flutter: undefined,
    flutter_query: `^${basic_query_with_http.dependencies.flutter_query}`,
  },
};

export default versions;
