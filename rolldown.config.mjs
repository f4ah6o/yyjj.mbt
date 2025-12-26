import { defineConfig } from 'rolldown';

export default defineConfig({
  input: './target/js/release/build/yyjj.js',
  output: [
    {
      format: 'esm',
      file: './dist/index.mjs',
      sourcemap: true,
      exports: 'named'
    },
    {
      format: 'cjs',
      file: './dist/index.cjs',
      sourcemap: true,
      exports: 'named'
    }
  ],
  external: [
    /^node:/
  ]
});
