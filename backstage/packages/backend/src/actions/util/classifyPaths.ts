import { resolveSafeChildPath } from '@backstage/backend-plugin-api';
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import fs from 'node:fs/promises';

const classifyPathsActionId = 'fs:classifyPaths';

export function createClassifyPathsAction() {
  return createTemplateAction({
    id: classifyPathsActionId,
    description:
      'Classifies workspace-relative paths as files or directories.',
    supportsDryRun: true,
    schema: {
      input: {
        paths: z =>
          z
            .array(z.string().min(1))
            .describe('Workspace-relative paths to classify.'),
      },
      output: {
        files: z => z.array(z.string()).describe('Paths that are files.'),
        directories: z =>
          z.array(z.string()).describe('Paths that are directories.'),
      },
    },
    async handler(ctx) {
      const files: string[] = [];
      const directories: string[] = [];

      for (const localPath of ctx.input.paths) {
        const fullPath = resolveSafeChildPath(ctx.workspacePath, localPath);
        const stat = await fs.stat(fullPath);

        if (stat.isDirectory()) {
          directories.push(localPath);
        } else if (stat.isFile()) {
          files.push(localPath);
        } else {
          throw new Error(`Source path is not a file or directory: ${localPath}`);
        }
      }

      ctx.output('files', files);
      ctx.output('directories', directories);
    },
  });
}
