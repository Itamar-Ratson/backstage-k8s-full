import { createParseJsonArrayAction } from './parseJsonArray';

function createActionContext(value: string) {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    input: { value },
    output: (name: string, outputValue: unknown) => {
      outputs[name] = outputValue;
    },
  } as any;
  return { ctx, outputs };
}

describe('createParseJsonArrayAction', () => {
  const action = createParseJsonArrayAction();

  it('parses a JSON string array', async () => {
    const { ctx, outputs } = createActionContext(
      '["charts/workloads/demo","deploy/dev/demo.yaml"]',
    );

    await action.handler(ctx);

    expect(outputs.items).toEqual([
      'charts/workloads/demo',
      'deploy/dev/demo.yaml',
    ]);
    expect(outputs.count).toBe(2);
  });

  it('rejects invalid JSON', async () => {
    const { ctx } = createActionContext('not-json');

    await expect(action.handler(ctx)).rejects.toThrow(/parsing failed/);
  });

  it('rejects arrays with non-string values', async () => {
    const { ctx } = createActionContext('["ok",42]');

    await expect(action.handler(ctx)).rejects.toThrow(/string array/);
  });
});
