import typescript from '@rollup/plugin-typescript';
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import postcss from 'rollup-plugin-postcss';

export default {
  input: 'src/index.ts',
  output: [
    {
      dir: 'dist',
      entryFileNames: 'cjs/[name].js',
      format: 'cjs',
      exports: 'named',
      sourcemap: true,
    },
    {
      dir: 'dist',
      entryFileNames: 'esm/[name].js',
      format: 'esm',
      exports: 'named',
      sourcemap: true,
    },
  ],
  external: [
    'react',
    'react-dom',
    /^@docusaurus\//
  ],
  plugins: [
    resolve(),
    commonjs(),
    typescript({
      declaration: true,
      declarationDir: 'dist/types',
      rootDir: 'src',
    }),
    postcss(),
  ]
};
