import { expect, test } from '@playwright/test';

// Link crawlers run no JavaScript: the server-rendered page must carry the tags
test('the start page links a preview image that exists', async ({ request }) => {
  const html = await (await request.get('/', { headers: { 'accept-language': 'en' } })).text();
  expect(html).toContain('<meta property="og:title" content="');
  const image = html.match(/<meta property="og:image" content="([^"]+)"/)?.[1];
  expect(image).toMatch(/\/og-image-en\.png$/);
  const response = await request.get(image!);
  expect(response.headers()['content-type']).toBe('image/png');
});
