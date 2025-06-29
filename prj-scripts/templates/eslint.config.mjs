import defaultConfig from '$package_scope/eslint'

export default [
  ...defaultConfig,
  {
    ignores: ['build/**', 'node_modules/**', '.react-router']
  }
]