import baseConfig from '../playwright.config';
import { deepMerge } from '../lib/util';
import { defineConfig } from '@playwright/test';

export default defineConfig(
  deepMerge(baseConfig, {
    use: {
      baseURL: baseConfig.use.baseURL || 'http://localhost:3000',
    },
  })
);
