## Manual RBAC Demo

After changing frontend code or pulling a new image tag, wait for ArgoCD to sync the updated `deploy/dev/backstage.yaml` value.

Then verify the end-to-end flow:

1. Visit <http://backstage.localtest.me>.
2. Confirm both Guest and GitHub sign-in buttons are visible.
3. Sign in with GitHub.
4. Open `/rbac` and confirm the `viewer` and `platform-admin` roles are listed.
5. Sign out.
6. Sign in as guest.
7. Open a scaffolder template and attempt to create it.
8. Confirm execution is denied by the permission framework.
