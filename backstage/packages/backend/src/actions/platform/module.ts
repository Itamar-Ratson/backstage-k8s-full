import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';

import { createResolveRepoUrlAction } from './resolveRepoUrl';

export const scaffolderPlatformActionsModule = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'platform-actions',
  register(env) {
    env.registerInit({
      deps: {
        config: coreServices.rootConfig,
        scaffolder: scaffolderActionsExtensionPoint,
      },
      async init({ config, scaffolder }) {
        scaffolder.addActions(createResolveRepoUrlAction({ config }));
      },
    });
  },
});
