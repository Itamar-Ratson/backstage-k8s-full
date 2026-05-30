import fs from 'node:fs';
import path from 'node:path';

// nunjucks ships no TypeScript types; this is a test-only import.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const nunjucks = require('nunjucks') as {
  configure: (opts: object) => {
    renderString: (str: string, ctx: object) => string;
  };
};

const repoRoot = path.resolve(__dirname, '../../../../');
const catalogInfoPath = 'catalog-info.yaml';
const chartTemplatePath = 'templates/application/template.yaml';
const ciPipelineTemplatePath = 'templates/ci-pipeline/template.yaml';
const decommissionTemplatePath =
  'templates/decommission-component/template.yaml';
const platformTemplatePaths = [
  chartTemplatePath,
  ciPipelineTemplatePath,
  decommissionTemplatePath,
] as const;
const chartCatalogPath =
  'templates/application/skeleton/image/catalog-info.yaml.njk';
const readmePath = 'README.md';
const forbiddenRepoSlugs = [
  ['Itamar-Ratson', 'backstage-k8s-full'].join('/'),
  [['itamar', 'ratson'].join('-'), 'backstage-k8s-full'].join('/'),
] as const;
const ignoredRepoSearchDirectories = new Set([
  '.git',
  '.terraform',
  'node_modules',
  '.techdocs-output',
]);

function readRepoFile(relativePath: string) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

function expectFileToContain(
  relativePath: string,
  snippets: readonly string[],
) {
  const contents = readRepoFile(relativePath);

  for (const snippet of snippets) {
    expect(contents).toContain(snippet);
  }
}

describe('application template contract', () => {
  it('registers the template and publishes the expected scaffold', () => {
    const fileExpectations = [
      {
        path: catalogInfoPath,
        snippets: [
          'kind: Location',
          'name: application-template',
          'target: ./templates/application/template.yaml',
        ],
      },
      {
        path: chartTemplatePath,
        snippets: [
          'kind: Template',
          'title: New Application',
          'branchName: scaffold/application/${{ parameters.name }}',
          'draft: false',
          'targetPath: charts/workloads/${{ parameters.name }}',
          "repository: ${{ parameters.repository or (steps.defaults.output.imageRepositoryBase + '/' + parameters.name) }}",
          'tag: ${{ parameters.tag }}',
        ],
      },
      {
        path: chartCatalogPath,
        snippets: [
          'lifecycle: experimental',
          'backstage.io/kubernetes-id: ${{ values.name }}',
          `backstage.io/source-paths: '["charts/workloads/\${{ values.name }}"]'`,
        ],
      },
    ] as const;

    for (const { path: relativePath, snippets } of fileExpectations) {
      expectFileToContain(relativePath, snippets);
    }

    const readme = readRepoFile(readmePath);
    expect(readme).toContain('## What\'s next');
    expect(readme).toContain('docs/operator/operations.md');
    expect(readme).toContain('docs/developer/backstage-development.md');
  });
});

describe('scaffolder platform identity contract', () => {
  it.each(platformTemplatePaths)(
    '%s resolves platform defaults before other steps',
    templatePath => {
      const template = readRepoFile(templatePath);
      const firstStep = extractFirstStep(template);

      expect(firstStep).toContain('id: defaults');
      expect(firstStep).toContain('action: platform:resolve-repo-url');
    },
  );

  it.each(platformTemplatePaths)(
    '%s publishes pull requests to the resolved repo URL',
    templatePath => {
      expect(readRepoFile(templatePath)).toContain(
        'repoUrl: ${{ steps.defaults.output.repoUrl }}',
      );
    },
  );

  it('uses the resolved image repository base in scaffolder output', () => {
    expect(readRepoFile(chartTemplatePath)).toContain(
      "steps.defaults.output.imageRepositoryBase + '/' + parameters.name",
    );
    expect(readRepoFile(ciPipelineTemplatePath)).toContain(
      'imageRepositoryBase: ${{ steps.defaults.output.imageRepositoryBase }}',
    );
  });

  it('keeps scaffolder templates and backend action code free of literal repo slugs', () => {
    const pathsToCheck = [
      'templates',
      'backstage/packages/backend/src',
    ] as const;

    for (const relativePath of pathsToCheck) {
      for (const filePath of listFiles(path.join(repoRoot, relativePath))) {
        const contents = fs.readFileSync(filePath, 'utf8');

        for (const repoSlug of forbiddenRepoSlugs) {
          expect(contents).not.toContain(repoSlug);
        }
      }
    }
  });

  it('omits fork-specific catalog annotations from the application skeleton', () => {
    const catalogInfo = readRepoFile(chartCatalogPath);

    expect(catalogInfo).not.toContain('github.com/project-slug:');
    expect(catalogInfo).not.toContain('backstage.io/source-location:');
  });

  it('omits fork-specific catalog annotations from in-repo catalog-info files', () => {
    const catalogInfoFiles = listRepoCatalogInfoFiles(repoRoot);

    expect(catalogInfoFiles.length).toBeGreaterThan(0);
    for (const filePath of catalogInfoFiles) {
      const contents = fs.readFileSync(filePath, 'utf8');

      expect(contents).not.toContain('github.com/project-slug:');
      expect(contents).not.toContain('backstage.io/source-location:');
    }
  });
});

describe('generic decommission component template contract', () => {
  it('registers the template and documents the decommission flow', () => {
    const fileExpectations = [
      {
        path: catalogInfoPath,
        snippets: [
          'kind: Location',
          'name: decommission-component-template',
          'target: ./templates/decommission-component/template.yaml',
        ],
      },
      {
        path: decommissionTemplatePath,
        snippets: [
          'kind: Template',
          'name: decommission-component',
          'branchName: decommission/component/',
          'filesToDelete:',
          'targetBranchName: main',
          'action: util:assert',
          'action: util:parseJsonArray',
          'action: util:filterByAttribute',
          'action: catalog:fetch',
          'action: fetch:plain',
          'action: fs:classifyPaths',
          'action: fs:readdir',
          'backstage.io/source-paths',
          'steps.collectFilesToDelete.output.files',
          'ArgoCD will detect the removal and prune the running resources within ~3 minutes.',
          'draft: false',
        ],
      },
      {
        path: chartCatalogPath,
        snippets: [
          'backstage.io/managed-by-template: application',
          `backstage.io/source-paths: '["charts/workloads/\${{ values.name }}"]'`,
        ],
      },
    ] as const;

    for (const { path: relativePath, snippets } of fileExpectations) {
      expectFileToContain(relativePath, snippets);
    }

    const readme = readRepoFile(readmePath);
    expect(readme).toContain('## What\'s next');
    expect(readme).toContain('docs/operator/manual-rbac-demo.md');
  });

  it('renders every util:assert condition in the template to a real boolean', () => {
    const templateSource = readRepoFile(decommissionTemplatePath);
    const conditions = extractAssertConditions(templateSource);
    expect(conditions.length).toBeGreaterThan(0);

    const env = nunjucks.configure({
      autoescape: false,
      tags: { variableStart: '${{', variableEnd: '}}' },
    });

    const sampleContext = {
      parameters: { component: 'component:default/test-01' },
      steps: {
        fetchEntity: {
          output: {
            entity: {
              metadata: {
                name: 'test-01',
                annotations: {
                  'backstage.io/managed-by-template': 'application',
                  'backstage.io/source-paths': '["charts/workloads/test-01"]',
                },
              },
            },
          },
        },
        collectBlockingRelations: {
          output: { count: 0, matches: [], extracted: [] },
        },
      },
    };

    for (const condition of conditions) {
      const rendered = JSON.parse(
        env.renderString(`\${{ (${condition}) | dump }}`, sampleContext),
      ) as unknown;
      expect(typeof rendered).toBe('boolean');
    }
  });
});

function extractAssertConditions(templateSource: string): string[] {
  const lines = templateSource.split('\n');
  const conditions: string[] = [];
  let insideAssertInput = false;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (/action:\s+util:assert\b/.test(line)) {
      insideAssertInput = true;
      continue;
    }
    if (!insideAssertInput) continue;

    const match = line.match(/condition:\s*\$\{\{\s*(.*?)\s*\}\}\s*$/);
    if (match) {
      conditions.push(match[1]);
      insideAssertInput = false;
      continue;
    }
    if (/^\s*- id:/.test(line)) {
      insideAssertInput = false;
    }
  }

  return conditions;
}

function extractFirstStep(templateSource: string): string {
  const stepsIndex = templateSource.indexOf('\n  steps:\n');
  expect(stepsIndex).toBeGreaterThanOrEqual(0);

  const stepsSource = templateSource.slice(stepsIndex);
  const firstStepMatch = stepsSource.match(
    /\n    - id:[\s\S]*?(?=\n    - id:)/,
  );
  expect(firstStepMatch).not.toBeNull();

  return firstStepMatch?.[0] ?? '';
}

type ListFilesOptions = {
  fileName?: string;
  ignoredDirectories?: ReadonlySet<string>;
};

function listFiles(rootPath: string, options: ListFilesOptions = {}): string[] {
  const entries = fs.readdirSync(rootPath, { withFileTypes: true });
  const files: string[] = [];

  for (const entry of entries) {
    const entryPath = path.join(rootPath, entry.name);
    if (entry.isDirectory()) {
      if (!options.ignoredDirectories?.has(entry.name)) {
        files.push(...listFiles(entryPath, options));
      }
    } else if (
      entry.isFile() &&
      (!options.fileName || entry.name === options.fileName)
    ) {
      files.push(entryPath);
    }
  }

  return files;
}

function listRepoCatalogInfoFiles(rootPath: string): string[] {
  return listFiles(rootPath, {
    fileName: 'catalog-info.yaml',
    ignoredDirectories: ignoredRepoSearchDirectories,
  });
}
