import type { Config } from '@backstage/config';
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

const actionId = 'platform:resolve-repo-url';

type Options = {
  config: Config;
};

type PlatformIdentity = {
  githubOwner: string;
  githubRepo: string;
  ghcrBase: string;
};

function readRequiredPlatformConfig(config: Config, key: string): string {
  const path = `platform.${key}`;
  const value = config.getOptionalString(path);

  if (!value) {
    throw new Error(`Missing required platform identity config value ${path}`);
  }

  return value;
}

function readPlatformIdentity(config: Config): PlatformIdentity {
  return {
    githubOwner: readRequiredPlatformConfig(config, 'githubOwner'),
    githubRepo: readRequiredPlatformConfig(config, 'githubRepo'),
    ghcrBase: readRequiredPlatformConfig(config, 'ghcrBase'),
  };
}

export function createResolveRepoUrlAction(options: Options) {
  return createTemplateAction({
    id: actionId,
    description: 'Resolves this platform repository and image defaults.',
    schema: {
      input: {},
      output: {
        repoUrl: z => z.string(),
        imageRepositoryBase: z => z.string(),
      },
    },
    async handler(ctx) {
      const { githubOwner, githubRepo, ghcrBase } = readPlatformIdentity(
        options.config,
      );

      ctx.output(
        'repoUrl',
        `github.com?owner=${githubOwner}&repo=${githubRepo}`,
      );
      ctx.output('imageRepositoryBase', ghcrBase);
    },
  });
}
