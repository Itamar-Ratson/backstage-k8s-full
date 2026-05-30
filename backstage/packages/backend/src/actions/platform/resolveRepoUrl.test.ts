import { ConfigReader } from '@backstage/config';
import type { ActionContext } from '@backstage/plugin-scaffolder-node';

import { createResolveRepoUrlAction } from './resolveRepoUrl';

type ResolveRepoUrlOutput = {
  repoUrl: string;
  imageRepositoryBase: string;
};

function createActionContext() {
  const outputs: Record<string, unknown> = {};
  const ctx = {
    output: (name: string, value: unknown) => {
      outputs[name] = value;
    },
  } as ActionContext<{}, ResolveRepoUrlOutput>;
  return { ctx, outputs };
}

describe('createResolveRepoUrlAction', () => {
  it('returns repository and image defaults from platform identity config', async () => {
    const action = createResolveRepoUrlAction({
      config: new ConfigReader({
        platform: {
          githubOwner: 'acme',
          githubRepo: 'platform',
          ghcrBase: 'ghcr.io/acme/platform',
        },
      }),
    });
    const { ctx, outputs } = createActionContext();

    await action.handler(ctx);

    expect(outputs).toEqual({
      repoUrl: 'github.com?owner=acme&repo=platform',
      imageRepositoryBase: 'ghcr.io/acme/platform',
    });
  });

  it('fails clearly when platform identity config is missing', async () => {
    const action = createResolveRepoUrlAction({
      config: new ConfigReader({ platform: { githubOwner: 'acme' } }),
    });
    const { ctx } = createActionContext();

    await expect(action.handler(ctx)).rejects.toThrow(
      'Missing required platform identity config value platform.githubRepo',
    );
  });
});
