import { createConcatStringArraysAction } from './concatStringArrays';

function createActionContext(arrays: string[][]) {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    input: { arrays },
    output: (name: string, value: unknown) => {
      outputs[name] = value;
    },
  } as any;
  return { ctx, outputs };
}

describe('createConcatStringArraysAction', () => {
  const action = createConcatStringArraysAction();

  it('concatenates arrays in order', async () => {
    const { ctx, outputs } = createActionContext([
      ['charts/workloads/demo/Chart.yaml'],
      ['deploy/dev/demo.yaml'],
    ]);

    await action.handler(ctx);

    expect(outputs.files).toEqual([
      'charts/workloads/demo/Chart.yaml',
      'deploy/dev/demo.yaml',
    ]);
    expect(outputs.count).toBe(2);
  });
});
