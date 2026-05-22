import fs from 'node:fs';
import path from 'node:path';

// nunjucks ships no TypeScript types; this is a test-only import.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const nunjucks = require('nunjucks') as {
  configure: (opts: object) => { renderString: (str: string, ctx: object) => string };
};

const repoRoot = path.resolve(__dirname, '../../../../');
const repoSlug = 'Itamar-Ratson/backstage-k8s-full';
const repoUrl = `https://github.com/${repoSlug}`;
const catalogInfoPath = 'catalog-info.yaml';
const chartTemplatePath = 'templates/application/template.yaml';
const decommissionTemplatePath = 'templates/decommission-component/template.yaml';
const chartCatalogPath = 'templates/application/skeleton/catalog-info.yaml.njk';
const readmePath = 'README.md';

function readRepoFile(relativePath: string) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

function expectFileToContain(relativePath: string, snippets: readonly string[]) {
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
          `target: ${repoUrl}/blob/main/templates/application/template.yaml`,
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
          'targetPath: deploy/dev',
        ],
      },
      {
        path: chartCatalogPath,
        snippets: [
          'lifecycle: experimental',
          'backstage.io/kubernetes-id: ${{ values.name }}',
          `backstage.io/source-paths: '["charts/workloads/\${{ values.name }}","deploy/dev/\${{ values.name }}.yaml"]'`,
          `github.com/project-slug: ${repoSlug}`,
          `backstage.io/source-location: url:${repoUrl}/tree/main/charts/workloads/` +
            '${{ values.name }}/',
        ],
      },
    ] as const;

    for (const { path: relativePath, snippets } of fileExpectations) {
      expectFileToContain(relativePath, snippets);
    }

    const readme = readRepoFile(readmePath);
    const templateSection = '**Add the application scaffolder template**';
    const techDocsSection = '**Set up TechDocs**';
    expect(readme).toContain(templateSection);
    expect(readme.indexOf(templateSection)).toBeLessThan(readme.indexOf(techDocsSection));
  });
});

describe('generic decommission component template contract', () => {
  it('registers the template and documents the decommission flow', () => {
    const fileExpectations = [
      {
        path: catalogInfoPath,
        snippets: [
          'kind: Location',
          `target: ${repoUrl}/blob/main/templates/decommission-component/template.yaml`,
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
          "backstage.io/source-paths",
          'steps.collectFilesToDelete.output.files',
          'ArgoCD will detect the removal and prune the running resources within ~3 minutes.',
          'draft: false',
        ],
      },
      {
        path: chartCatalogPath,
        snippets: [
          'backstage.io/managed-by-template: application',
          `backstage.io/source-paths: '["charts/workloads/\${{ values.name }}","deploy/dev/\${{ values.name }}.yaml"]'`,
        ],
      },
    ] as const;

    for (const { path: relativePath, snippets } of fileExpectations) {
      expectFileToContain(relativePath, snippets);
    }

    const readme = readRepoFile(readmePath);
    const templateSection = '**Add the application scaffolder template**';
    const decommissionSection = '**Decommission a scaffolded application**';
    const techDocsSection = '**Set up TechDocs**';
    expect(readme).toContain(decommissionSection);
    expect(readme.indexOf(templateSection)).toBeLessThan(
      readme.indexOf(decommissionSection),
    );
    expect(readme.indexOf(decommissionSection)).toBeLessThan(
      readme.indexOf(techDocsSection),
    );
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
                  'backstage.io/source-paths':
                    '["charts/workloads/test-01","deploy/dev/test-01.yaml"]',
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
