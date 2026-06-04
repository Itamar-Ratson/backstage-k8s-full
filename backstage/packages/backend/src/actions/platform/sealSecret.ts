import { resolveSafeChildPath } from '@backstage/backend-plugin-api';
import type { Config } from '@backstage/config';
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { constants, publicEncrypt, X509Certificate } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

const actionId = 'platform:sealSecret';
const certPath = '/v1/cert.pem';

type Options = {
  config: Config;
};

function sealingCertUrl(controllerUrl: string): string {
  const baseUrl = controllerUrl.endsWith('/')
    ? controllerUrl
    : `${controllerUrl}/`;

  return new URL(certPath, baseUrl).toString();
}

function readControllerUrl(config: Config): string {
  const value = config.getOptionalString('platform.sealedSecrets.controllerUrl');

  if (!value) {
    throw new Error(
      'Missing required sealed secrets config value platform.sealedSecrets.controllerUrl',
    );
  }

  return value;
}

function yamlScalar(value: string): string {
  return JSON.stringify(value);
}

export async function fetchCert(url: string): Promise<X509Certificate> {
  const urlToFetch = sealingCertUrl(url);
  const response = await fetch(urlToFetch);

  if (!response.ok) {
    throw new Error(
      `Failed to fetch sealed secrets certificate from ${urlToFetch}: HTTP ${response.status}`,
    );
  }

  return new X509Certificate(await response.text());
}

export function sealValue(
  cert: X509Certificate,
  namespace: string,
  name: string,
  key: string,
  value: string,
): string {
  void key;

  return publicEncrypt(
    {
      key: cert.publicKey,
      padding: constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: 'sha256',
      oaepLabel: Buffer.from(`${namespace}/${name}`),
    },
    Buffer.from(value, 'utf8'),
  ).toString('base64');
}

export function buildSealedSecretManifest(
  namespace: string,
  name: string,
  encryptedData: Record<string, string>,
): string {
  const encryptedDataLines = Object.entries(encryptedData)
    .map(([key, value]) => `    ${yamlScalar(key)}: ${yamlScalar(value)}`)
    .join('\n');

  return [
    '# Static SealedSecret manifest; not Helm-templated.',
    'apiVersion: bitnami.com/v1alpha1',
    'kind: SealedSecret',
    'metadata:',
    `  namespace: ${yamlScalar(namespace)}`,
    `  name: ${yamlScalar(name)}`,
    'spec:',
    '  encryptedData:',
    encryptedDataLines,
    '',
  ].join('\n');
}

export function createSealSecretAction(options: Options) {
  return createTemplateAction({
    id: actionId,
    description:
      'Seals plaintext key values into a SealedSecret manifest for the target cluster.',
    schema: {
      input: {
        controllerUrl: z => z.string().optional(),
        namespace: z => z.string().min(1),
        name: z => z.string().min(1),
        keys: z => z.record(z.string(), z.string()).optional(),
        writePath: z => z.string().min(1),
      },
    },
    async handler(ctx) {
      const keys = ctx.input.keys ?? {};
      const entries = Object.entries(keys);

      if (entries.length === 0) {
        return;
      }

      const controllerUrl =
        ctx.input.controllerUrl ?? readControllerUrl(options.config);
      const cert = await fetchCert(controllerUrl);
      const encryptedData = Object.fromEntries(
        entries.map(([key, value]) => [
          key,
          sealValue(cert, ctx.input.namespace, ctx.input.name, key, value),
        ]),
      );
      const manifest = buildSealedSecretManifest(
        ctx.input.namespace,
        ctx.input.name,
        encryptedData,
      );
      const fullWritePath = resolveSafeChildPath(
        ctx.workspacePath,
        ctx.input.writePath,
      );

      await fs.mkdir(path.dirname(fullWritePath), { recursive: true });
      await fs.writeFile(fullWritePath, manifest, 'utf8');
    },
  });
}
