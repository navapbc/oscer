import baseConfig from '../playwright.config';
import { deepMerge } from '../lib/util';
import { defineConfig } from '@playwright/test';
import path from 'path';

export default defineConfig(
  deepMerge(baseConfig, {
    timeout: 60000,
    testDir: path.join(__dirname, 'tests'),
    use: {
      baseURL: baseConfig.use.baseURL || 'http://localhost:3000',
    },
  })
);
