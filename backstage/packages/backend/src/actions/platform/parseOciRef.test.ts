import type { ActionContext } from '@backstage/plugin-scaffolder-node';

import { createParseOciRefAction } from './parseOciRef';

type ParseOciRefInput = {
  ref: string;
};

type ParseOciRefOutput = {
  chart: string;
  repository: string;
  version: string;
};

async function parseRef(ref: string) {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    input: { ref },
    output: (name: string, value: unknown) => {
      outputs[name] = value;
    },
  } as ActionContext<ParseOciRefInput, ParseOciRefOutput>;

  await createParseOciRefAction().handler(ctx);

  return outputs;
}

describe('createParseOciRefAction', () => {
  it('parses a reference with an oci prefix', async () => {
    await expect(
      parseRef('oci://ghcr.io/kagent-dev/kagent/helm/kagent:0.9.4'),
    ).resolves.toEqual({
      chart: 'kagent',
      repository: 'oci://ghcr.io/kagent-dev/kagent/helm',
      version: '0.9.4',
    });
  });

  it('parses a reference without an oci prefix', async () => {
    await expect(
      parseRef('ghcr.io/kagent-dev/kagent/helm/kagent:0.9.4'),
    ).resolves.toEqual({
      chart: 'kagent',
      repository: 'oci://ghcr.io/kagent-dev/kagent/helm',
      version: '0.9.4',
    });
  });

  it('parses a registry with a port right-to-left', async () => {
    await expect(parseRef('localhost:5000/charts/foo:1.0')).resolves.toEqual({
      chart: 'foo',
      repository: 'oci://localhost:5000/charts',
      version: '1.0',
    });
  });

  it('rejects a reference with no version separator in the suffix', async () => {
    await expect(
      parseRef('ghcr.io/kagent-dev/kagent/helm/kagent'),
    ).rejects.toThrow(
      'OCI chart reference must include a chart version after the chart name',
    );
  });

  it('rejects a reference with no chart segment', async () => {
    await expect(parseRef('ghcr.io')).rejects.toThrow(
      'OCI chart reference must include a registry path and chart name',
    );
  });

  it('rejects an empty reference', async () => {
    await expect(parseRef('')).rejects.toThrow(
      'OCI chart reference is required',
    );
  });
});
