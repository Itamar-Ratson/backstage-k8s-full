import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

const actionId = 'platform:parse-oci-ref';

function parseOciRef(ref: string) {
  const normalizedRef = ref.trim().replace(/^oci:\/\//, '');

  if (!normalizedRef) {
    throw new Error('OCI chart reference is required');
  }

  const lastSlashIndex = normalizedRef.lastIndexOf('/');
  if (lastSlashIndex < 0) {
    throw new Error(
      'OCI chart reference must include a registry path and chart name',
    );
  }

  const prefix = normalizedRef.slice(0, lastSlashIndex);
  const suffix = normalizedRef.slice(lastSlashIndex + 1);
  const versionSeparatorIndex = suffix.indexOf(':');
  if (versionSeparatorIndex < 0) {
    throw new Error(
      'OCI chart reference must include a chart version after the chart name',
    );
  }

  const chart = suffix.slice(0, versionSeparatorIndex);
  const version = suffix.slice(versionSeparatorIndex + 1);
  if (!prefix || !chart || !version) {
    throw new Error(
      'OCI chart reference must include a registry path, chart name, and version',
    );
  }

  return {
    chart,
    repository: `oci://${prefix}`,
    version,
  };
}

export function createParseOciRefAction() {
  return createTemplateAction({
    id: actionId,
    description: 'Parses a full OCI chart reference into Helm dependency fields.',
    schema: {
      input: {
        ref: z => z.string(),
      },
      output: {
        chart: z => z.string(),
        repository: z => z.string(),
        version: z => z.string(),
      },
    },
    async handler(ctx) {
      const parsed = parseOciRef(ctx.input.ref);

      ctx.output('chart', parsed.chart);
      ctx.output('repository', parsed.repository);
      ctx.output('version', parsed.version);
    },
  });
}
