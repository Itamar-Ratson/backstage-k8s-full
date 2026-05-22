import { createBackendModule } from '@backstage/backend-plugin-api';
import { scaffolderActionsExtensionPoint } from '@backstage/plugin-scaffolder-node/alpha';

import { createAssertAction } from './assert';
import { createClassifyPathsAction } from './classifyPaths';
import { createConcatStringArraysAction } from './concatStringArrays';
import { createFilterByAttributeAction } from './filterByAttribute';
import { createParseJsonArrayAction } from './parseJsonArray';

export const scaffolderUtilActionsModule = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'util-actions',
  register(env) {
    env.registerInit({
      deps: {
        scaffolder: scaffolderActionsExtensionPoint,
      },
      async init({ scaffolder }) {
        scaffolder.addActions(
          createAssertAction(),
          createClassifyPathsAction(),
          createConcatStringArraysAction(),
          createFilterByAttributeAction(),
          createParseJsonArrayAction(),
        );
      },
    });
  },
});
