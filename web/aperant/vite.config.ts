import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

const APERANT_DESKTOP = resolve(__dirname, '../../tools/aperant/apps/desktop');

const SHIMS_DIR = resolve(__dirname, 'shims');
const MOCKS_DIR = resolve(APERANT_DESKTOP, 'src/renderer/lib/mocks');

/**
 * Strip the Electron CSP meta tag and replace with a permissive web CSP.
 */
function webCspPlugin(): Plugin {
  return {
    name: 'web-csp',
    transformIndexHtml(html) {
      return html.replace(
        /<meta http-equiv="Content-Security-Policy"[^>]*\/?\s*>/,
        `<meta http-equiv="Content-Security-Policy" content="default-src 'self' https: data: blob: 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https: wss: ws:; img-src 'self' data: blob: https:; font-src 'self' https://fonts.gstatic.com" />`
      );
    },
  };
}

/**
 * Replace Aperant browser mocks with web API-backed implementations.
 * Intercepts resolved module IDs pointing to the original mock files.
 */
function webMockReplacerPlugin(): Plugin {
  const replacements: Record<string, string> = {
    [resolve(MOCKS_DIR, 'settings-mock.ts')]: resolve(SHIMS_DIR, 'settings-mock.ts'),
    [resolve(MOCKS_DIR, 'project-mock.ts')]: resolve(SHIMS_DIR, 'project-mock.ts'),
    [resolve(MOCKS_DIR, 'mock-data.ts')]: resolve(SHIMS_DIR, 'mock-data.ts'),
  };

  return {
    name: 'web-mock-replacer',
    enforce: 'pre',
    resolveId(source, importer) {
      if (!importer) return null;

      // Replace the entire browser-mock.ts with our web version
      if (source.includes('./lib/browser-mock') && importer.includes('main.tsx')) {
        return resolve(SHIMS_DIR, 'browser-mock.ts');
      }
      if (source.includes('browser-mock') && importer.includes('/renderer/')) {
        return resolve(SHIMS_DIR, 'browser-mock.ts');
      }

      // Replace individual mock files
      if (source.includes('settings-mock') && (importer.includes('/mocks/') || importer.includes('/shims/'))) {
        return resolve(SHIMS_DIR, 'settings-mock.ts');
      }
      if (source.includes('project-mock') && (importer.includes('/mocks/') || importer.includes('/shims/'))) {
        return resolve(SHIMS_DIR, 'project-mock.ts');
      }
      if (source.includes('mock-data') && (importer.includes('/mocks/') || importer.includes('/shims/'))) {
        return resolve(SHIMS_DIR, 'mock-data.ts');
      }
      return null;
    },
  };
}

export default defineConfig({
  plugins: [webMockReplacerPlugin(), react(), webCspPlugin()],
  root: resolve(APERANT_DESKTOP, 'src/renderer'),
  publicDir: resolve(__dirname, 'public'),

  resolve: {
    alias: {
      '@': resolve(APERANT_DESKTOP, 'src/renderer'),
      '@shared': resolve(APERANT_DESKTOP, 'src/shared'),
      '@features': resolve(APERANT_DESKTOP, 'src/renderer/features'),
      '@components': resolve(APERANT_DESKTOP, 'src/renderer/shared/components'),
      '@hooks': resolve(APERANT_DESKTOP, 'src/renderer/shared/hooks'),
      '@lib': resolve(APERANT_DESKTOP, 'src/renderer/shared/lib'),
      // Redirect Sentry to a no-op in web mode
      '@sentry/electron/renderer': resolve(__dirname, 'shims/sentry-noop.ts'),
      // Mock modules are replaced by webMockReplacerPlugin above
    },
  },

  define: {
    '__SENTRY_DSN__': JSON.stringify(''),
    '__SENTRY_TRACES_SAMPLE_RATE__': JSON.stringify('0'),
    '__SENTRY_PROFILES_SAMPLE_RATE__': JSON.stringify('0'),
  },

  build: {
    outDir: resolve(__dirname, 'dist'),
    emptyOutDir: true,
  },

  server: {
    port: 5180,
    proxy: {
      '/api': {
        target: 'http://localhost:5181',
        changeOrigin: true,
      },
      '/ws': {
        target: 'ws://localhost:5181',
        ws: true,
      },
    },
  },
});
