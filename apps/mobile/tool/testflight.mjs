import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const release = args[0] === '--release';
const [number, ...extra] = release ? args.slice(1) : args;
const {
  ASC_KEY_ID: keyId,
  ASC_ISSUER_ID: issuer,
  ASC_KEY_P8: p8,
  ASC_BUNDLE_ID: bundleId,
  TESTFLIGHT_INTERNAL_GROUP: internalName,
  TESTFLIGHT_EXTERNAL_GROUP: externalName,
} = process.env;
if (!number || extra.length || !keyId || !issuer || !p8 || !bundleId || !internalName || (release && !externalName)) {
  throw new Error(
    'Usage: node tool/testflight.mjs [--release] <build number>; configure ASC_* and TESTFLIGHT_* variables (README, Release)',
  );
}
const key = createPrivateKey(Buffer.from(p8, 'base64').toString());

function token() {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${encode({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' })}`;
  return `${unsigned}.${sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}

async function api(method, path, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${token()}`, ...(body && { 'content-type': 'application/json' }) },
    body: body && JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok)
    throw new Error(`App Store Connect ${method} ${path.split('?')[0]}: ${response.status} ${await response.text()}`);
  return response.status === 204 ? null : response.json();
}

const app = (await api('GET', `/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`)).data[0];
if (!app) throw new Error(`App ${bundleId} not found in App Store Connect`);
const allGroups = (await api('GET', `/apps/${app.id}/betaGroups?limit=200`)).data;
function group(name, internal) {
  const match = allGroups.find((candidate) => candidate.attributes.name === name);
  if (!match || match.attributes.isInternalGroup !== internal) {
    throw new Error(`TestFlight group "${name}" must exist and be ${internal ? 'internal' : 'external'}`);
  }
  return match;
}
const internal = group(internalName, true);
const external = release ? group(externalName, false) : null;
// Apple cannot enable automatic distribution for an existing internal group via this API.
if (!internal.attributes.hasAccessToAllBuilds) {
  throw new Error(`Create internal group "${internalName}" with "Enable automatic distribution" in App Store Connect`);
}

const version = readFileSync(new URL('../pubspec.yaml', import.meta.url), 'utf8').match(/^version:\s*([^+\s]+)/m)?.[1];
if (!version) throw new Error('Missing version in pubspec.yaml');
const buildQuery = `/builds?filter[app]=${app.id}&filter[version]=${encodeURIComponent(number)}&filter[preReleaseVersion.version]=${encodeURIComponent(version)}&filter[preReleaseVersion.platform]=IOS`;
let build;
const deadline = Date.now() + 60 * 60_000;
for (;;) {
  build = (await api('GET', `${buildQuery}&limit=1`)).data[0];
  const state = build?.attributes.processingState;
  if (state && state !== 'VALID' && state !== 'PROCESSING') throw new Error(`Build ${number} is ${state}`);
  if (state === 'VALID') {
    const detail = (await api('GET', `/builds/${build.id}/buildBetaDetail`)).data;
    const internalState = detail.attributes.internalBuildState;
    if (
      !['PROCESSING', 'IN_EXPORT_COMPLIANCE_REVIEW', 'READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(
        internalState,
      )
    ) {
      throw new Error(
        `Build ${number} cannot be tested internally: ${internalState}; check TestFlight and export compliance`,
      );
    }
    const assigned = (await api('GET', `${buildQuery}&filter[betaGroups]=${internal.id}`)).data;
    if (internalState === 'IN_BETA_TESTING' && assigned.some((candidate) => candidate.id === build.id)) break;
  }
  if (Date.now() >= deadline)
    throw new Error(`Build ${number} was not processed and distributed internally within an hour`);
  console.log(`Waiting for build ${number} processing and internal distribution …`);
  await new Promise((resolve) => setTimeout(resolve, 60_000));
}
console.log(`Build ${number} is in "${internalName}"`);

if (external) {
  const assigned = (await api('GET', `${buildQuery}&filter[betaGroups]=${external.id}`)).data;
  if (!assigned.some((candidate) => candidate.id === build.id)) {
    await api('POST', `/betaGroups/${external.id}/relationships/builds`, { data: [{ type: 'builds', id: build.id }] });
  }
  console.log(`Build ${number} is in "${externalName}"`);
  const state = (await api('GET', `/builds/${build.id}/buildBetaDetail`)).data.attributes.externalBuildState;
  if (state === 'READY_FOR_BETA_SUBMISSION') {
    await api('POST', '/betaAppReviewSubmissions', {
      data: { type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: build.id } } } },
    });
    console.log(`Build ${number} is submitted for beta review; external availability depends on Apple`);
  } else if (
    [
      'WAITING_FOR_BETA_REVIEW',
      'IN_BETA_REVIEW',
      'BETA_APPROVED',
      'READY_FOR_BETA_TESTING',
      'IN_BETA_TESTING',
    ].includes(state)
  ) {
    console.log(`Build ${number} beta review: ${state}`);
  } else {
    throw new Error(
      `Build ${number} cannot be submitted for beta review: ${state}; check TestFlight metadata and export compliance`,
    );
  }
}
