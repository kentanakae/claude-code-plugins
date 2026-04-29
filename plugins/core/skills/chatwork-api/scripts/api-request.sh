#!/usr/bin/env bash
# Chatwork API request helper.
#
# Usage:
#   api-request.sh <METHOD> <PATH> [key=value | key@file | -curl-opt [val] ...]
#
# Examples:
#   api-request.sh GET  /me
#   api-request.sh GET  /rooms force=1
#   api-request.sh POST /rooms/123/messages body="[To:456] テスト [info]例[/info]"
#   api-request.sh POST /rooms/123/messages body@/tmp/long-body.txt
#   api-request.sh POST /rooms/123/files -F file=@./report.pdf -F message_ids=456
#
# Token: read from CHATWORK_API_TOKEN. Passed via curl -K (process
# substitution) so the value never appears in argv.
#
# Encoding: positional args of the form key=value or key@file are sent via
# --data-urlencode (URL-encoded once). Pass the literal string you want
# stored — do not pre-encode. For multipart uploads (POST /rooms/{id}/files),
# use raw -F flags. For value-taking curl flags (-F, -H, -d, -X, -o, -T,
# -K, --form, --header, --data, --request, --output, --upload-file,
# --config, --url), the wrapper consumes the next argv as the value.

set -euo pipefail

if [ -z "${CHATWORK_API_TOKEN:-}" ]; then
  cat >&2 <<'EOF'
error: CHATWORK_API_TOKEN is not set.
       Set it before retrying:
           export CHATWORK_API_TOKEN=<your_chatwork_api_token>
       NOTE: do not echo, print, or paste the token value into chat.
EOF
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "usage: api-request.sh <METHOD> <PATH> [key=value | key@file | -curl-opt ...]" >&2
  exit 64
fi

method="$1"; shift
path="$1"; shift

case "$path" in
  /*) ;;
  *) echo "path must start with '/', got: $path" >&2; exit 64 ;;
esac

args=(-sSf -X "$method")
[ "$method" = GET ] && args+=(-G)

expect_value=0
for a in "$@"; do
  if [ "$expect_value" = 1 ]; then
    args+=("$a")
    expect_value=0
    continue
  fi
  case "$a" in
    -F|--form|--form-string|-H|--header|-d|--data|--data-raw|--data-binary|--data-urlencode|-X|--request|-o|--output|-T|--upload-file|-K|--config|--url)
      args+=("$a"); expect_value=1 ;;
    --*=*|-*)
      args+=("$a") ;;
    *=*|*@*)
      args+=(--data-urlencode "$a") ;;
    *)
      echo "unrecognized arg: $a (expected key=value, key@file, or -curl-opt)" >&2
      exit 64 ;;
  esac
done

if [ "$expect_value" = 1 ]; then
  echo "missing value for last flag" >&2
  exit 64
fi

exec curl "${args[@]}" \
  -K <(printf 'header = "X-ChatWorkToken: %s"\n' "$CHATWORK_API_TOKEN") \
  "https://api.chatwork.com/v2${path}"
