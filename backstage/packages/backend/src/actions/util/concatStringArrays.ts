import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

const concatStringArraysActionId = 'util:concatStringArrays';

export function createConcatStringArraysAction() {
  return createTemplateAction({
    id: concatStringArraysActionId,
    description: 'Concatenates string arrays into one flat string array.',
    schema: {
      input: {
        arrays: z =>
          z
            .array(z.array(z.string()))
            .describe('String arrays to concatenate in order.'),
      },
      output: {
        files: z => z.array(z.string()).describe('Flat string array.'),
        count: z => z.number().describe('Number of strings.'),
      },
    },
    async handler(ctx) {
      const files = ctx.input.arrays.flat();

      ctx.output('files', files);
      ctx.output('count', files.length);
    },
  });
}
