#!/usr/bin/env bash
set -euo pipefail

if [[ "$(git rev-parse HEAD)" != "$VALIDATED_SHA" ]]; then
  echo '::error::The checked-out commit is not the validated commit.'
  exit 1
fi

for name in HOSTINGER_HOST HOSTINGER_PORT HOSTINGER_USER HOSTINGER_DEPLOY_PATH; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::$name is not configured."
    exit 1
  fi
done

ssh=(
  ssh
  -i "$HOME/.ssh/hostinger_deploy"
  -p "$HOSTINGER_PORT"
  "$HOSTINGER_USER@$HOSTINGER_HOST"
)

"${ssh[@]}" bash -s -- "$HOSTINGER_DEPLOY_PATH" "$VALIDATED_SHA" <<'REMOTE'
set -euo pipefail
deploy_path=$1
validated_sha=$2

cd "$deploy_path"
git fetch --no-tags https://github.com/schnuartz-ai/verify-clavastack.git main
test "$(git rev-parse FETCH_HEAD)" = "$validated_sha"
git checkout -B main "$validated_sha"
git reset --hard "$validated_sha"

printf '{"repository":"schnuartz-ai/verify-clavastack","source_sha":"%s"}\n' \
  "$validated_sha" > deployment.json
test "$(git rev-parse HEAD)" = "$validated_sha"
REMOTE

deployed_sha=$(curl --fail --show-error --silent --retry 5 \
  "https://verify.clavastack.com/deployment.json?sha=$VALIDATED_SHA" |
  jq -r .source_sha)
test "$deployed_sha" = "$VALIDATED_SHA"

echo "Hostinger deployed and verified $VALIDATED_SHA" >> "$GITHUB_STEP_SUMMARY"
