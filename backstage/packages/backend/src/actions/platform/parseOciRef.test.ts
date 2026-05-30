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

function createActionContext(ref: string) {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    input: { ref },
    output: (name: string, value: unknown) => {
      outputs[name] = value;
    },
  } as ActionContext<ParseOciRefInput, ParseOciRefOutput>;
  return { ctx, outputs };
}

describe('createParseOciRefAction', () => {
  it('parses a reference with an oci prefix', async () => {
    const action = createParseOciRefAction();
    const { ctx, outputs } = createActionContext(
      'oci://ghcr.io/kagent-dev/kagent/helm/kagent:0.9.4',
    );

    await action.handler(ctx);

    expect(outputs).toEqual({
      chart: 'kagent',
      repository: 'oci://ghcr.io/kagent-dev/kagent/helm',
      version: '0.9.4',
    });
  });

  it('parses a reference without an oci prefix', async () => {
    const action = createParseOciRefAction();
    const { ctx, outputs } = createActionContext(
      'ghcr.io/kagent-dev/kagent/helm/kagent:0.9.4',
    );

    await action.handler(ctx);

    expect(outputs).toEqual({
      chart: 'kagent',
      repository: 'oci://ghcr.io/kagent-dev/kagent/helm',
      version: '0.9.4',
    });
  });

  it('parses a registry with a port right-to-left', async () => {
    const action = createParseOciRefAction();
    const { ctx, outputs } = createActionContext(
      'localhost:5000/charts/foo:1.0',
    );

    await action.handler(ctx);

    expect(outputs).toEqual({
      chart: 'foo',
      repository: 'oci://localhost:5000/charts',
      version: '1.0',
    });
  });

  it('rejects a reference with no version separator in the suffix', async () => {
    const action = createParseOciRefAction();
    const { ctx } = createActionContext('ghcr.io/kagent-dev/kagent/helm/kagent');

    await expect(action.handler(ctx)).rejects.toThrow(
      'OCI chart reference must include a chart version after the chart name',
    );
  });

  it('rejects a reference with no chart segment', async () => {
    const action = createParseOciRefAction();
    const { ctx } = createActionContext('ghcr.io');

    await expect(action.handler(ctx)).rejects.toThrow(
      'OCI chart reference must include a registry path and chart name',
    );
  });

  it('rejects an empty reference', async () => {
    const action = createParseOciRefAction();
    const { ctx } = createActionContext('');

    await expect(action.handler(ctx)).rejects.toThrow(
      'OCI chart reference is required',
    );
  });
});
