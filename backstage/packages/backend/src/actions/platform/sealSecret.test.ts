import { ConfigReader } from '@backstage/config';
import type { ActionContext } from '@backstage/plugin-scaffolder-node';
import { constants, privateDecrypt, X509Certificate } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import YAML from 'yaml';

import {
  buildSealedSecretManifest,
  createSealSecretAction,
  fetchCert,
  sealValue,
} from './sealSecret';

type SealSecretInput = {
  controllerUrl?: string;
  namespace: string;
  name: string;
  keys?: Record<string, string> | SecretFormRow[];
  writePath: string;
};

type SecretFormRow = {
  envVar: string;
  value: string;
};

type TestCert = {
  cert: X509Certificate;
  certPem: string;
  privateKeyPem: string;
};

async function createTestCertificate(): Promise<TestCert> {
  const workDir = await fs.mkdtemp(path.join(os.tmpdir(), 'seal-secret-cert-'));
  const keyPath = path.join(workDir, 'tls.key');
  const certPath = path.join(workDir, 'tls.crt');

  execFileSync(
    'openssl',
    [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '1',
      '-nodes',
      '-subj',
      '/CN=sealed-secrets-test',
    ],
    { stdio: 'ignore' },
  );

  const [certPem, privateKeyPem] = await Promise.all([
    fs.readFile(certPath, 'utf8'),
    fs.readFile(keyPath, 'utf8'),
  ]);

  return {
    cert: new X509Certificate(certPem),
    certPem,
    privateKeyPem,
  };
}

function decryptValue(
  privateKeyPem: string,
  namespace: string,
  name: string,
  encryptedValue: string,
) {
  return privateDecrypt(
    {
      key: privateKeyPem,
      padding: constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: 'sha256',
      oaepLabel: Buffer.from(`${namespace}/${name}`),
    },
    Buffer.from(encryptedValue, 'base64'),
  ).toString('utf8');
}

function createLoggerSpy() {
  return {
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
    child: jest.fn(),
  };
}

function allLoggerCalls(logger: ReturnType<typeof createLoggerSpy>) {
  return Object.values(logger).flatMap(fn => fn.mock.calls);
}

function expectNoPlaintextLogged(
  logger: ReturnType<typeof createLoggerSpy>,
  plaintextValues: string[],
) {
  const calls = allLoggerCalls(logger).map(call => JSON.stringify(call));

  for (const value of plaintextValues) {
    if (value) {
      expect(calls.some(call => call.includes(value))).toBe(false);
    }
  }
}

async function runAction(input: SealSecretInput, certPem: string) {
  const workspacePath = await fs.mkdtemp(
    path.join(os.tmpdir(), 'seal-secret-'),
  );
  const logger = createLoggerSpy();
  const fetchSpy = jest
    .spyOn(global, 'fetch')
    .mockResolvedValue(new Response(certPem));
  const ctx = {
    input,
    workspacePath,
    logger,
  } as unknown as ActionContext<SealSecretInput, { [key: string]: any }>;

  await createSealSecretAction({
    config: new ConfigReader({
      platform: {
        sealedSecrets: {
          controllerUrl: 'http://sealed-secrets.test:8080',
        },
      },
    }),
  }).handler(ctx);

  return { fetchSpy, logger, workspacePath };
}

describe('sealValue', () => {
  it.each([
    ['short value', 'secret'],
    ['long value', 'a'.repeat(128)],
    ['unicode value', 'sikrit-日本語-🔒'],
    ['empty string', ''],
  ])('round-trips a %s', async (_name, plaintext) => {
    const { cert, privateKeyPem } = await createTestCertificate();

    const encryptedValue = sealValue(
      cert,
      'demo-namespace',
      'demo-secret',
      'TOKEN',
      plaintext,
    );

    expect(
      decryptValue(
        privateKeyPem,
        'demo-namespace',
        'demo-secret',
        encryptedValue,
      ),
    ).toBe(plaintext);
  });
});

describe('fetchCert', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('fetches and parses the controller public certificate', async () => {
    const { certPem } = await createTestCertificate();
    const fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(new Response(certPem));

    const cert = await fetchCert('http://sealed-secrets.test:8080');

    expect(cert).toBeInstanceOf(X509Certificate);
    expect(fetchSpy).toHaveBeenCalledWith(
      'http://sealed-secrets.test:8080/v1/cert.pem',
    );
  });
});

describe('buildSealedSecretManifest', () => {
  it('renders the expected SealedSecret shape', () => {
    const manifest = buildSealedSecretManifest('demo', 'api-token', {
      TOKEN: 'encrypted-token',
      PASSWORD: 'encrypted-password',
    });

    expect(
      manifest.startsWith(
        '# Static SealedSecret manifest; not Helm-templated.\n',
      ),
    ).toBe(true);
    expect(YAML.parse(manifest)).toEqual({
      apiVersion: 'bitnami.com/v1alpha1',
      kind: 'SealedSecret',
      metadata: {
        namespace: 'demo',
        name: 'api-token',
      },
      spec: {
        encryptedData: {
          TOKEN: 'encrypted-token',
          PASSWORD: 'encrypted-password',
        },
      },
    });
  });
});

describe('createSealSecretAction', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it.each([
    ['empty', {}],
    ['undefined', undefined],
  ])('does not write a file for %s keys', async (_name, keys) => {
    const { certPem } = await createTestCertificate();
    const { fetchSpy, logger, workspacePath } = await runAction(
      {
        namespace: 'demo',
        name: 'api-token',
        keys,
        writePath: 'deploy/sealed-secret.yaml',
      },
      certPem,
    );

    await expect(
      fs.stat(path.join(workspacePath, 'deploy/sealed-secret.yaml')),
    ).rejects.toThrow();
    expect(fetchSpy).not.toHaveBeenCalled();
    expectNoPlaintextLogged(logger, []);
  });

  it('writes one encryptedData entry for a single key', async () => {
    const { certPem } = await createTestCertificate();
    const plaintext = 'top-secret-token';
    const { logger, workspacePath } = await runAction(
      {
        namespace: 'demo',
        name: 'api-token',
        keys: { TOKEN: plaintext },
        writePath: 'deploy/sealed-secret.yaml',
      },
      certPem,
    );

    const manifest = YAML.parse(
      await fs.readFile(
        path.join(workspacePath, 'deploy/sealed-secret.yaml'),
        'utf8',
      ),
    );

    expect(Object.keys(manifest.spec.encryptedData)).toEqual(['TOKEN']);
    expect(manifest.spec.encryptedData.TOKEN).not.toContain(plaintext);
    expectNoPlaintextLogged(logger, [plaintext]);
  });

  it('writes all encryptedData entries for multiple keys', async () => {
    const { certPem } = await createTestCertificate();
    const values = {
      TOKEN: 'top-secret-token',
      PASSWORD: 'top-secret-password',
    };
    const { logger, workspacePath } = await runAction(
      {
        controllerUrl: 'http://sealed-secrets.override:8080',
        namespace: 'demo',
        name: 'api-token',
        keys: values,
        writePath: 'deploy/sealed-secret.yaml',
      },
      certPem,
    );

    const manifest = YAML.parse(
      await fs.readFile(
        path.join(workspacePath, 'deploy/sealed-secret.yaml'),
        'utf8',
      ),
    );

    expect(Object.keys(manifest.spec.encryptedData).sort()).toEqual([
      'PASSWORD',
      'TOKEN',
    ]);
    expectNoPlaintextLogged(logger, Object.values(values));
  });

  it('accepts scaffolder form secret rows', async () => {
    const { certPem } = await createTestCertificate();
    const values: SecretFormRow[] = [
      { envVar: 'GROQ_API_KEY', value: 'groq-secret-value' },
      { envVar: 'MODEL_TOKEN', value: 'model-secret-value' },
    ];
    const { logger, workspacePath } = await runAction(
      {
        namespace: 'kagent',
        name: 'kagent-secrets',
        keys: values,
        writePath: 'charts/workloads/kagent/templates/sealed-secret.yaml',
      },
      certPem,
    );

    const manifestPath = path.join(
      workspacePath,
      'charts/workloads/kagent/templates/sealed-secret.yaml',
    );
    const manifest = YAML.parse(await fs.readFile(manifestPath, 'utf8'));

    expect(manifest.metadata).toEqual({
      namespace: 'kagent',
      name: 'kagent-secrets',
    });
    expect(Object.keys(manifest.spec.encryptedData).sort()).toEqual([
      'GROQ_API_KEY',
      'MODEL_TOKEN',
    ]);
    expectNoPlaintextLogged(
      logger,
      values.map(secret => secret.value),
    );
  });
});
