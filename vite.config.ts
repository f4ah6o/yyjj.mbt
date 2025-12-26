import { defineConfig } from 'vite';
import moonbit from 'vite-plugin-moonbit';

export default defineConfig({
  plugins: [
    moonbit({
      target: "js",
      watch: true
    })
  ]
});
