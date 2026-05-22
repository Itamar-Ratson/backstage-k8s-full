import { createTemplateAction } from '@backstage/plugin-scaffolder-node';

const parseJsonArrayActionId = 'util:parseJsonArray';

function isNonEmptyStringArray(value: unknown): value is string[] {
  return (
    Array.isArray(value) &&
    value.length > 0 &&
    value.every(item => typeof item === 'string' && item.length > 0)
  );
}

export function createParseJsonArrayAction() {
  return createTemplateAction({
    id: parseJsonArrayActionId,
    description: 'Parses a JSON-encoded string array.',
    schema: {
      input: {
        value: z => z.string().describe('JSON string to parse.'),
      },
      output: {
        items: z => z.array(z.string()).describe('Parsed string items.'),
        count: z => z.number().describe('Number of parsed items.'),
      },
    },
    async handler(ctx) {
      let parsed: unknown;

      try {
        parsed = JSON.parse(ctx.input.value);
      } catch (error) {
        throw new Error(
          `Expected a JSON-encoded string array, but parsing failed: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }

      if (!isNonEmptyStringArray(parsed)) {
        throw new Error('Expected a JSON-encoded non-empty string array.');
      }

      ctx.output('items', parsed);
      ctx.output('count', parsed.length);
    },
  });
}
