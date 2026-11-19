module.exports = {
  root: true,
  env: { es2022: true, node: true },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: { project: ["tsconfig.json"], sourceType: "module" },
  plugins: ["@typescript-eslint"],
  ignorePatterns: ["/lib/**/*", ".eslintrc.js"],
  rules: {
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/explicit-function-return-type": "off",
    "no-console": "off",
    "max-len": ["warn", { code: 120 }],
  },
};
