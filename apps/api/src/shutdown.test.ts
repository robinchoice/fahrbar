import { beforeAll, expect, test } from 'bun:test';
import { migrateDb } from '@app/db';

beforeAll(() => migrateDb(process.env.DATABASE_URL));

const appModule = JSON.stringify(`${import.meta.dir}/app.ts`);

// Signals and module mocks stay in isolated child processes.
function start(entry: 'index' | 'worker', setup: string, env: Record<string, string> = {}) {
  const child = Bun.spawn(
    [
      process.execPath,
      '--eval',
      `import { mock } from 'bun:test'; ${setup}
      await import(${JSON.stringify(`${import.meta.dir}/${entry}.ts`)});`,
    ],
    {
      env: {
        ...process.env,
        APP_URL: 'http://localhost',
        PORT: '0',
        SMTP_HOST: '',
        SENTRY_DSN: '',
        NODE_ENV: 'test',
        ...env,
      },
      stdout: 'pipe',
      stderr: 'pipe',
    },
  );
  const lines = child.stdout.pipeThrough(new TextDecoderStream()).getReader();
  let output = '';
  async function until(marker: string) {
    while (!output.includes(marker)) {
      const { value, done } = await lines.read();
      if (done) throw new Error(`Child exited before ${marker}: ${output}\n${await child.stderr.text()}`);
      output += value;
    }
    return output;
  }
  return { child, until };
}

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  test(`API drains an active database request on ${signal}`, async () => {
    const { child, until } = start(
      'index',
      `mock.module(${appModule}, () => ({
      createApp: (db) => ({ fetch: async () => {
        console.log('request-started');
        await db.execute('select pg_sleep(0.3)');
        return new Response('complete');
      } })
    }));`,
    );
    try {
      const output = await until('API listening on port ');
      const port = output.match(/API listening on port (\d+)/)![1];
      const response = fetch(`http://localhost:${port}`).then((res) => res.text());
      await until('request-started');
      child.kill(signal);
      expect(await response).toBe('complete');
      expect(await child.exited).toBe(0);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
    }
  }, 30_000);

  test(`API finishes startup before closing on ${signal}`, async () => {
    const { child, until } = start(
      'index',
      `const original = await import('@app/db');
      const { createDb: originalCreateDb, migrateDb: originalMigrateDb } = original;
      mock.module('@app/db', () => ({ ...original, migrateDb: async (url) => {
        console.log('migration-started');
        await Bun.sleep(300);
        await originalMigrateDb(url);
        console.log('migration-finished');
      } }));`,
    );
    try {
      await until('migration-started');
      child.kill(signal);
      await until('migration-finished');
      expect(await child.exited).toBe(0);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
    }
  }, 30_000);

  test(`worker finishes its database transaction on ${signal}`, async () => {
    const { child, until } = start(
      'worker',
      `const original = await import('@app/db');
      const { createDb: originalCreateDb, migrateDb: originalMigrateDb } = original;
      mock.module('@app/db', () => ({ ...original, createDb: (url) => {
        const db = originalCreateDb(url);
        return new Proxy(db, { get(target, property) {
          if (property === 'insert') return () => ({ values: () => ({ onConflictDoNothing: async () => {
            await db.transaction(async (tx) => {
              console.log('purge-started');
              await tx.execute('select pg_sleep(0.3)');
            });
            console.log('purge-committed');
          } }) });
          return Reflect.get(target, property);
        } });
      } }));`,
    );
    try {
      await until('purge-started');
      child.kill(signal);
      await until('purge-committed');
      expect(await child.exited).toBe(0);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
    }
  }, 30_000);

  test(`worker interrupts its idle pause on ${signal}`, async () => {
    const { child, until } = start(
      'worker',
      `const original = await import('@app/db');
      const { createDb: originalCreateDb, migrateDb: originalMigrateDb } = original;
      mock.module('@app/db', () => ({ ...original, createDb: (url) => {
        const db = originalCreateDb(url);
        return new Proxy(db, { get(target, property) {
          if (property === 'update') return () => ({ set: () => ({ where: () => ({ returning: async () => {
            console.log('idle');
            return [];
          } }) }) });
          return Reflect.get(target, property);
        } });
      } }));`,
    );
    try {
      await until('idle');
      const before = performance.now();
      child.kill(signal);
      expect(await child.exited).toBe(0);
      expect(performance.now() - before).toBeLessThan(1000);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
    }
  }, 30_000);
}

test('SMTP times out and records the failure before worker shutdown', async () => {
  const command = Promise.withResolvers<void>();
  const smtp = Bun.listen({
    hostname: '127.0.0.1',
    port: 0,
    socket: {
      open(socket) {
        socket.write('220 localhost SMTP\r\n');
      },
      data() {
        command.resolve();
      },
    },
  });
  const { child, until } = start(
    'worker',
    `
    const { sendMail } = await import(${JSON.stringify(`${import.meta.dir}/lib/mail.ts`)});
    const original = await import('@app/db');
    const { createDb: originalCreateDb } = original;
    mock.module('@app/db', () => ({ ...original, createDb: (url) => {
      const db = originalCreateDb(url);
      return new Proxy(db, { get(target, property) {
        if (property === 'insert') return () => ({ values: () => ({ onConflictDoNothing: async () => {
          await db.transaction(async (tx) => {
            try {
              await sendMail({ to: 'shutdown-test@example.com', subject: 'test', text: 'test' });
            } catch {
              await tx.execute('select 1');
              console.log('delivery-failure-recorded');
              return;
            }
            throw new Error('The SMTP server must time out');
          });
        } }) });
        return Reflect.get(target, property);
      } });
    } }));`,
    { SMTP_HOST: '127.0.0.1', SMTP_PORT: String(smtp.port), SMTP_USER: '', SMTP_PASS: '' },
  );
  try {
    await command.promise;
    child.kill('SIGTERM');
    await until('delivery-failure-recorded');
    expect(await child.exited).toBe(0);
  } finally {
    child.kill('SIGKILL');
    await child.exited;
    smtp.stop(true);
  }
}, 45_000);
