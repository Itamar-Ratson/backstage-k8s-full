# Medium publishing checklist

Draft: `post.md`. Not part of TechDocs (excluded via `exclude_docs` in the root `mkdocs.yaml`).

## Publish steps

1. Copy `post.md` into Medium's editor (paste as markdown works for headers, bold, and code fences; verify code blocks kept their language highlighting - set manually if not).
2. Title and subtitle are the H1 and the italic line under it; Medium wants them in its own title/subtitle fields - cut them from the body after pasting.
3. Upload images from `assets/` at each `![...]` placeholder, then delete the placeholder lines:
   - `backstage-hero.gif` - hero, directly under the subtitle
   - `entity-model.png` - catalog section
   - `catalog-component-relations.png` - catalog section
   - `scaffolder-new-application-form.png` - scaffolder section
   - `deployment-architecture.png` - production section
4. The `---` horizontal rules paste as Medium section separators - keep them.
5. Suggested tags: Backstage, Platform Engineering, DevOps, Kubernetes, Developer Experience.

## Regenerating diagrams

Sources are the `.mmd` files in `assets/`. Export:

```bash
npx -y @mermaid-js/mermaid-cli -i assets/entity-model.mmd -o assets/entity-model.png -w 1400 -s 2 -b white
npx -y @mermaid-js/mermaid-cli -i assets/deployment-architecture.mmd -o assets/deployment-architecture.png -w 1800 -s 2 -b white
```

## Link pinning

All repo links in the post are pinned to commit `fd482225f8f210445d3d541e97c6321b815fa598`. If the post is revised much later, re-pin to a current commit and re-verify the quoted snippets still match the files.
