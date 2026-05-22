import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createClassifyPathsAction } from './classifyPaths';

function createActionContext(workspacePath: string, paths: string[]) {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    input: { paths },
    workspacePath,
    output: (name: string, value: unknown) => {
      outputs[name] = value;
    },
  } as any;
  return { ctx, outputs };
}

describe('createClassifyPathsAction', () => {
  const action = createClassifyPathsAction();

  it('classifies files and directories in the workspace', async () => {
    const workspacePath = await fs.mkdtemp(
      path.join(os.tmpdir(), 'classify-paths-'),
    );
    await fs.mkdir(path.join(workspacePath, 'charts/workloads/demo'), {
      recursive: true,
    });
    await fs.mkdir(path.join(workspacePath, 'deploy/dev'), {
      recursive: true,
    });
    await fs.writeFile(path.join(workspacePath, 'deploy/dev/demo.yaml'), '');

    const { ctx, outputs } = createActionContext(workspacePath, [
      'charts/workloads/demo',
      'deploy/dev/demo.yaml',
    ]);

    await action.handler(ctx);

    expect(outputs.directories).toEqual(['charts/workloads/demo']);
    expect(outputs.files).toEqual(['deploy/dev/demo.yaml']);
  });
});
