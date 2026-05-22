# Safety Mechanics

## Eligibility Check

The first step fetches the selected catalog entity with `catalog:fetch`. The next step asserts that the entity was created by the supported template:

```yaml
backstage.io/managed-by-template: application
```

If the annotation is missing or has a different value, the Template stops before reading repository files or opening a pull request. This prevents the flow from deleting arbitrary chart directories for Components that do not follow the scaffolded chart layout.

## Blocking Relations Check

The Template inspects the fetched entity's catalog relations and collects relation targets whose `type` is one of:

- `dependencyOf`
- `hasSubcomponent`
- `apiConsumedBy`
- `apiProvidedBy`

Those relations indicate that another catalog entity still depends on, contains, consumes, or is served by the selected Component. If any matches are found, `assertNoBlockingRelations` fails and reports the blocking entity refs in the error message.

This check is intentionally catalog-based. It catches known Backstage relationships before source removal, but it does not prove that no runtime traffic, dashboards, alerts, or external clients still exist.

## File Discovery And Deletion

After the safety checks pass, the Template fetches the current chart directory from GitHub:

```text
https://github.com/Itamar-Ratson/backstage-k8s-full/tree/main/charts/workloads/<component-name>/
```

It then runs `fs:readdir` recursively against the workspace copy. The `extractChartFilePaths` step uses `util:filterByAttribute` with `extract: path`, which turns the file objects returned by `fs:readdir` into a flat list of repository paths.

That extracted path list is combined with `deploy/dev/<component-name>.yaml` and passed to `publish:github:pull-request` as `filesToDelete`. The workspace copy is deleted before publishing so the pull request is driven by explicit deletions rather than by leaving rendered files in the scaffolder workspace.

## Review Expectations

Before merging the pull request, reviewers should verify:

- The selected Component is the intended workload.
- No blocking relations were reported by the Template.
- The `filesToDelete` list is limited to `charts/workloads/<component-name>/` and `deploy/dev/<component-name>.yaml`.
- The owning team understands that ArgoCD will prune the running release after merge.
- Any non-Helm resources owned by the workload have a separate cleanup path.
