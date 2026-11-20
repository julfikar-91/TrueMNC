#!/usr/bin/env bash

CMD="$1"
ARG="$2"

if [ "$CMD" = "flutter" ]; then
  TARGET="${ARG:-lib}"
  flutter analyze --no-pub "$TARGET" 2>&1 | tail -20
  flutter test "$TARGET" 2>&1 | tail -20
elif [ "$CMD" = "functions" ]; then
  cd functions && npx tsc --noEmit 2>&1 | tail -20
  if command -v jest >/dev/null 2>&1 || [ -f "node_modules/.bin/jest" ]; then
    npx jest "$ARG" 2>&1 | tail -20
  else
    npm run test:ai 2>&1 | tail -20
  fi
elif [ "$CMD" = "rules" ]; then
  cd functions && npm run test:rules 2>&1 | tail -25
else
  echo "Usage: ./scripts/check.sh {flutter <path>|functions <pattern>|rules}"
  exit 1
fi
