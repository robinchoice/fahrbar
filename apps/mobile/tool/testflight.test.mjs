import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

// Exercise the real CLI with an ephemeral signing key and no network or real delays.
const bootstrap = `
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { readFileSync } from 'node:fs';
const scenario = JSON.parse(process.env.SCENARIO);
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
Object.assign(process.env, {
  ASC_KEY_ID: 'test-key', ASC_ISSUER_ID: 'test-issuer',
  ASC_KEY_P8: Buffer.from(privateKey.export({ type: 'pkcs8', format: 'pem' })).toString('base64'),
  ASC_BUNDLE_ID: 'org.pleasance.test', TESTFLIGHT_INTERNAL_GROUP: 'Internal',
  TESTFLIGHT_EXTERNAL_GROUP: 'External',
});
let clock = 1_000_000;
Date.now = () => clock;
globalThis.setTimeout = (resolve, delay) => { clock += delay; resolve(); };
const build = { id: 'build-42', attributes: { processingState: 'VALID' } };
const writes = [];
let polls = 0;
let internalChecks = 0;
let detailChecks = 0;
globalThis.fetch = async (url, options) => {
  const jwt = options.headers.authorization.slice(7).split('.');
  assert.equal(JSON.parse(Buffer.from(jwt[1], 'base64url')).iss, 'test-issuer');
  assert(verify('sha256', Buffer.from(jwt.slice(0, 2).join('.')), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(jwt[2], 'base64url')));
  const path = new URL(url).pathname.replace('/v1', '');
  const query = new URL(url).searchParams;
  let data;
  if (scenario.apiFailure) return new Response('Denied', { status: 403 });
  if (options.method === 'POST') {
    writes.push({ path, body: JSON.parse(options.body) });
    console.log('WRITE ' + JSON.stringify(writes.at(-1)));
    return new Response(null, { status: 204 });
  }
  if (path === '/apps') {
    assert.equal(query.get('filter[bundleId]'), 'org.pleasance.test');
    data = scenario.noApp ? [] : [{ id: 'app' }];
  } else if (path === '/apps/app/betaGroups') {
    data = [
      { id: 'internal', attributes: { name: 'Internal', isInternalGroup: !scenario.wrongInternalType, hasAccessToAllBuilds: !scenario.noAutomatic } },
      { id: 'external', attributes: { name: 'External', isInternalGroup: !!scenario.wrongExternalType } },
    ].filter(group => !scenario.noGroup || group.id !== 'external');
  } else if (path === '/builds') {
    assert.equal(query.get('filter[app]'), 'app');
    assert.equal(query.get('filter[version]'), '42');
    const expectedVersion = readFileSync('../pubspec.yaml', 'utf8').split('version: ')[1].split(/[+\\s]/)[0];
    assert.equal(query.get('filter[preReleaseVersion.version]'), expectedVersion, 'must exclude other marketing versions with the same build number');
    assert.equal(query.get('filter[preReleaseVersion.platform]'), 'IOS');
    const group = query.get('filter[betaGroups]');
    if (group === 'internal') {
      internalChecks++;
      data = scenario.noInternalBuild || (scenario.delayed && internalChecks === 1) ? [] : [build];
    } else if (group === 'external') {
      data = scenario.assigned ? [build] : [];
    } else {
      polls++;
      data = scenario.noBuild || (scenario.delayed && polls === 1) ? [] : [{ ...build, attributes: { processingState: scenario.invalid ? 'INVALID' : scenario.delayed && polls === 2 ? 'PROCESSING' : 'VALID' } }];
    }
  } else if (path === '/builds/build-42/buildBetaDetail') {
    detailChecks++;
    data = { attributes: { internalBuildState: scenario.waitingInternal && detailChecks === 1 ? 'IN_EXPORT_COMPLIANCE_REVIEW' : scenario.internalState || 'IN_BETA_TESTING', externalBuildState: scenario.reviewState || 'READY_FOR_BETA_SUBMISSION' } };
  } else {
    throw new Error('Unexpected request: ' + url);
  }
  return Response.json({ data });
};
process.argv = ['node', 'testflight.mjs', ...(scenario.release ? ['--release'] : []), '42'];
await import('./testflight.mjs');
console.log('POLLS ' + polls);
`;

function run(scenario) {
  const result = spawnSync(process.execPath, ['--input-type=module', '-e', bootstrap], {
    cwd: import.meta.dirname,
    env: { ...process.env, SCENARIO: JSON.stringify(scenario) },
    encoding: 'utf8',
    timeout: 10_000,
  });
  assert.ifError(result.error);
  return {
    ...result,
    writes: result.stdout
      .split('\n')
      .filter((line) => line.startsWith('WRITE '))
      .map((line) => JSON.parse(line.slice(6))),
  };
}

test('manual build waits for processing and internal visibility without external writes', () => {
  const result = run({ delayed: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, []);
  assert.match(result.stdout, /POLLS 4/);
});

test('release assigns the exact uploaded build and submits it for review', () => {
  const result = run({ release: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, [
    { path: '/betaGroups/external/relationships/builds', body: { data: [{ type: 'builds', id: 'build-42' }] } },
    {
      path: '/betaAppReviewSubmissions',
      body: {
        data: {
          type: 'betaAppReviewSubmissions',
          relationships: { build: { data: { type: 'builds', id: 'build-42' } } },
        },
      },
    },
  ]);
});

test('waits for internal export compliance review to finish', () => {
  const result = run({ waitingInternal: true });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /POLLS 2/);
  assert.deepEqual(result.writes, []);
});

test('retry after assignment only submits the pending review', () => {
  const result = run({ release: true, assigned: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(
    result.writes.map((write) => write.path),
    ['/betaAppReviewSubmissions'],
  );
});

for (const reviewState of [
  'WAITING_FOR_BETA_REVIEW',
  'IN_BETA_REVIEW',
  'BETA_APPROVED',
  'READY_FOR_BETA_TESTING',
  'IN_BETA_TESTING',
]) {
  test(`retry with ${reviewState} does not assign or submit again`, () => {
    const result = run({ release: true, assigned: true, reviewState });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(result.writes, []);
  });
}

for (const [scenario, error] of [
  [{ noApp: true }, /App .* not found/],
  [{ release: true, noGroup: true }, /must exist and be external/],
  [{ wrongInternalType: true }, /must exist and be internal/],
  [{ release: true, wrongExternalType: true }, /must exist and be external/],
  [{ noAutomatic: true }, /Enable automatic distribution/],
  [{ invalid: true }, /Build 42 is INVALID/],
  [{ internalState: 'MISSING_EXPORT_COMPLIANCE' }, /cannot be tested internally/],
  [{ noBuild: true }, /within an hour/],
  [{ noInternalBuild: true }, /within an hour/],
  [{ apiFailure: true }, /403 Denied/],
]) {
  test(`fails without external writes for ${JSON.stringify(scenario)}`, () => {
    const result = run(scenario);
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, error);
    assert.deepEqual(result.writes, []);
  });
}

test('missing review prerequisites fail instead of reporting a successful release', () => {
  const result = run({ release: true, assigned: true, reviewState: 'MISSING_EXPORT_COMPLIANCE' });
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /cannot be submitted.*MISSING_EXPORT_COMPLIANCE/);
  assert.deepEqual(result.writes, []);
});
