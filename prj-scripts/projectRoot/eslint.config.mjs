import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import unusedImports from 'eslint-plugin-unused-imports'

const defaultCodeStyle = {
  files: ['**/*.{ts,tsx}'],
  languageOptions: {
    ecmaVersion: 'latest',
    globals: {
      ...globals.browser,
      ...globals.node
    }
  },
  plugins: {
    'unused-imports': unusedImports
  },
  rules: {
    'max-depth': ['error', 2],
    'padding-line-between-statements': [
      'error',
      { blankLine: 'always', prev: '*', next: 'return' },
      { blankLine: 'always', prev: '*', next: 'if' },
      { blankLine: 'always', prev: 'function', next: '*' },
      { blankLine: 'always', prev: '*', next: 'function' }
    ],
    'no-restricted-syntax': [
      'error',
      {
        selector: 'TSInterfaceDeclaration',
        message: 'Interface 대신 type 을 사용하세요.'
      },
      {
        selector: 'VariableDeclaration[kind="let"]',
        message: 'let 대신 const 를 사용하세요.'
      },
      {
        selector: 'VariableDeclaration[kind="var"]',
        message: 'var 대신 const 를 사용하세요.'
      },
      {
        selector: 'SwitchStatement',
        message: 'switch 대신 if 를 사용하세요.'
      },
      {
        selector: 'ConditionalExpression',
        message: '삼항 연산자 대신 if 를 사용하세요.'
      },
      {
        selector: 'IfStatement[alternate]',
        message: 'else 대신 early return 을 사용하세요.'
      },
      {
        selector: 'ForStatement',
        message:
          'for 루프 대신 배열 메서드(map, filter, reduce 등)를 사용하세요.'
      },
      {
        selector: 'WhileStatement',
        message: 'while 루프 대신 배열 메서드나 재귀를 사용하세요.'
      },
      {
        selector: 'DoWhileStatement',
        message: 'do-while 루프 대신 배열 메서드나 재귀를 사용하세요.'
      },
      {
        selector: 'ForInStatement',
        message:
          'for-in 루프 대신 Object.keys(), Object.values(), Object.entries()를 사용하세요.'
      },
      {
        selector: 'ForOfStatement',
        message: 'for-of 루프 대신 배열 메서드를 사용하세요.'
      },
      {
        selector: 'CallExpression[callee.property.name="push"]',
        message:
          'push() 대신 concat() 또는 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="pop"]',
        message: 'pop() 대신 slice() 메소드를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="shift"]',
        message: 'shift() 대신 slice() 메소드를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="unshift"]',
        message:
          'unshift() 대신 concat() 또는 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="splice"]',
        message:
          'splice() 대신 slice() 및 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="reverse"]',
        message:
          'reverse() 대신 [...array].reverse()를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="fill"]',
        message: 'fill() 대신 map()을 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="copyWithin"]',
        message: 'copyWithin() 대신 map()을 사용하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="assign"]',
        message:
          'Object.assign() 대신 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="defineProperty"]',
        message:
          'Object.defineProperty() 대신 새 객체를 생성하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="defineProperties"]',
        message:
          'Object.defineProperties() 대신 새 객체를 생성하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="setPrototypeOf"]',
        message:
          'Object.setPrototypeOf() 대신 Object.create()를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'UnaryExpression[operator="delete"]',
        message:
          'delete 연산자 대신 새 객체를 생성하고 원하는 속성만 포함하세요. (부수효과 방지)'
      },
      {
        selector:
          'AssignmentExpression[left.type="Identifier"][left.name=/^(params?|args?|arguments|prop|props|parameter|parameters)$/]',
        message:
          '함수 파라미터는 직접 수정하지 마세요. 새 변수를 만들어 사용하세요.'
      },
      {
        selector:
          'AssignmentExpression[left.type="MemberExpression"][left.object.name=/^(params?|args?|arguments|prop|props|parameter|parameters)$/]',
        message:
          '함수 파라미터의 속성은 직접 수정하지 마세요. 객체를 복사하여 사용하세요.'
      },
      {
        selector:
          'FunctionDeclaration > BlockStatement > ExpressionStatement > AssignmentExpression[left.type="Identifier"]',
        message:
          '함수 내에서 파라미터를 재할당하지 마세요. 새 변수를 만들어 사용하세요.'
      },
      {
        selector:
          'ArrowFunctionExpression > BlockStatement > ExpressionStatement > AssignmentExpression[left.type="Identifier"]',
        message:
          '함수 내에서 파라미터를 재할당하지 마세요. 새 변수를 만들어 사용하세요.'
      }
    ],
    'no-unused-vars': 'off',
    'unused-imports/no-unused-imports': 'error',
    'unused-imports/no-unused-vars': [
      'warn',
      {
        vars: 'all',
        varsIgnorePattern: '^_',
        args: 'after-used',
        argsIgnorePattern: '^_'
      }
    ],
    'no-param-reassign': ['error', { props: true }],
    'no-shadow': 'off', // 기본 ESLint 규칙은 비활성화
    '@typescript-eslint/no-shadow': [
      'error',
      {
        builtinGlobals: true,
        hoist: 'all',
        allow: [] // 예외를 허용하고 싶은 변수 이름들
      }
    ]
  }
}

export default tseslint.config(defaultCodeStyle, {
  extends: [js.configs.recommended, ...tseslint.configs.recommended],
  files: ['**/*.{ts,tsx}'],
  languageOptions: {
    ecmaVersion: 'latest',
    globals: globals.browser
  }
})