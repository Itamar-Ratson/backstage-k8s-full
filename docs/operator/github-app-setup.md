# GitHub App Setup

Create one GitHub App per environment. For local development, a user-owned App is usually simplest because it does not require organization administrator approval. Use an organization-owned App when the repositories Backstage reads from live under an organization and the org already has an owner available to approve installation.

This App is used for both Backstage automation and GitHub sign-in:

- Catalog discovery reads `catalog-info.yaml` files.
- Scaffolder actions create branches and pull requests.
- The GitHub auth provider uses the App OAuth client for user sign-in.

## Create The App

1. Open GitHub Developer settings:
   - User App: `Settings` -> `Developer settings` -> `GitHub Apps` -> `New GitHub App`
   - Organization App: organization `Settings` -> `Developer settings` -> `GitHub Apps` -> `New GitHub App`
2. Set a clear name, such as `backstage-dev-<your-name>`.
3. Set the homepage URL to this repository or to `http://backstage.localtest.me`.
4. Set the callback URL exactly to:

```text
http://backstage.localtest.me/api/auth/github/handler/frame
```

5. Disable webhook delivery for the local KinD setup unless you have a public tunnel configured. ArgoCD polling is enough for this repo.

## Permissions

Configure these repository permissions:

- Contents: Read and write
- Pull requests: Read and write
- Commit statuses: Read
- Workflows: Read and write
- Metadata: Read

| Permission | Scope | Why Backstage needs it |
|------------|-------|------------------------|
| Contents | Read and write | Read catalog files and publish scaffolded repository changes |
| Pull requests | Read and write | Open and update pull requests from scaffolder templates |
| Commit statuses | Read | Let catalog discovery preflight repository access without failing on status checks |
| Workflows | Read and write | Publish scaffolded changes that include workflow files |
| Metadata | Read | Required by GitHub and granted automatically |

No organization permissions are required for the local dev flow.

## Install The App

After creating the App, install it on the repositories Backstage should read from and write to. For this repo, select only `Itamar-Ratson/backstage-k8s-full` unless you intentionally want Backstage catalog discovery to scan additional repositories.

If the App is organization-owned, an organization owner may need to approve the installation before it becomes usable.

## Generate The Private Key

On the App settings page:

1. Open `Private keys`.
2. Click `Generate a private key`.
3. Download the `.pem` file.
4. Store it outside the repository.

The `.pem` file contains the signing key Backstage uses to mint short-lived installation tokens. It must not be committed.

## Map Values To Terraform

Copy the App fields into `terraform/terraform.tfvars`:

| tfvars key | GitHub App UI source |
|------------|----------------------|
| `APP_ID` | App settings page, `App ID` |
| `CLIENT_ID` | App settings page, `Client ID` |
| `CLIENT_SECRET` | Generate under `Client secrets`, then copy the value immediately |
| `PRIVATE_KEY` | Full PEM body from the downloaded `.pem` file, including the begin/end lines |

Use a multi-line string for `PRIVATE_KEY`:

```hcl
PRIVATE_KEY = <<EOT
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
EOT
```

`terraform.tfvars` and downloaded `.pem` private keys are local credentials. They are gitignored and must not be committed.

## Verify The Inputs

Before running Terraform, confirm that:

- The App is installed on every repository Backstage needs.
- The callback URL matches the dev URL exactly.
- The private key in `terraform.tfvars` includes the full PEM body.
- `terraform/terraform.tfvars` is not staged in Git.
