#!/usr/bin/env bash
# Test suite for shell-risk. Run from the repo root: bash tests/test.sh
cd "$(dirname "$0")/.." || exit 2
BIN=bin/shell-risk
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# rules_for 'script text' -> sorted rule ids found
rules_for() {
  printf '%s\n' "$1" > "$T/x.sh"
  "$BIN" "$T/x.sh" --tsv | awk -F'\t' 'NR>1{print $2}' | sort | tr '\n' ' ' | sed 's/ $//'
}
expect() { # name text expected-rules
  local got; got=$(rules_for "$2")
  if [ "$got" = "$3" ]; then ok; else bad "$1 (got '$got', want '$3')"; fi
}
NOSET=$'set -eu\n'

expect "clean script" "${NOSET}echo hello" ""
expect "curl pipe bash" "${NOSET}curl -s https://x.test/i | bash" "SHL001"
expect "wget pipe sh" "${NOSET}wget -qO- https://x.test/i | sh" "SHL001"
expect "curl pipe sudo bash" "${NOSET}curl -s https://x.test/i | sudo bash" "SHL001"
expect "curl to file is fine" "${NOSET}curl -s https://x.test/i -o /usr/bin/x" ""
expect "curl pipe jq is fine" "${NOSET}curl -s https://x.test/i | jq ." ""
expect "eval with var" "${NOSET}"'eval "$CMD"' "SHL002"
expect "eval with subst" "${NOSET}"'eval $(ssh-agent)' "SHL002"
expect "eval literal is fine" "${NOSET}eval ls" ""
expect "word containing eval" "${NOSET}"'retrieval "$x"' ""
expect "chmod 777" "${NOSET}chmod 777 /srv" "SHL003"
expect "chmod -R 777" "${NOSET}chmod -R 777 /srv" "SHL003"
expect "chmod a+rwx" "${NOSET}chmod a+rwx f" "SHL003"
expect "chmod o+w" "${NOSET}chmod o+w f" "SHL003"
expect "chmod 755 fine" "${NOSET}chmod 755 f" ""
expect "chmod 0777" "${NOSET}chmod 0777 f" "SHL003"
expect "rm -rf var" "${NOSET}"'rm -rf $DIR/' "SHL004"
expect "rm -rf braces" "${NOSET}"'rm -rf ${DIR}/x' "SHL004"
expect "rm -rf bare quoted var is harmless when empty" "${NOSET}"'rm -rf "$DIR"' ""
expect "rm -rf quoted var with slash" "${NOSET}"'rm -rf "$DIR"/*' "SHL004"
expect "rm -rf guarded" "${NOSET}"'rm -rf "${DIR:?}/x"' ""
expect "rm -rf guarded" "${NOSET}"'rm -rf "${DIR:?}/x"' ""
expect "rm -f var is not recursive" "${NOSET}"'rm -f $FILE' ""
expect "rm -rf literal dir" "${NOSET}rm -rf /var/cache/app" ""
expect "rm -rf /" "${NOSET}rm -rf /" "SHL012"
expect "rm -rf /*" "${NOSET}rm -rf /*" "SHL012"
expect "no-preserve-root" "${NOSET}rm -rf --no-preserve-root /" "SHL012"
expect "tmp redirect" "${NOSET}"'echo x > /tmp/out.txt' "SHL005"
expect "tmp append" "${NOSET}"'echo x >> /tmp/out.txt' "SHL005"
expect "tmp with pid" "${NOSET}"'echo x > /tmp/out.$$' ""
expect "mktemp line" "${NOSET}"'f=$(mktemp /tmp/x.XXXX); echo x > /tmp/a' ""
expect "curl -k" "${NOSET}curl -k https://x" "SHL006"
expect "curl -sk" "${NOSET}curl -sk https://x" "SHL006"
expect "curl --insecure" "${NOSET}curl --insecure https://x" "SHL006"
expect "wget no-check" "${NOSET}wget --no-check-certificate https://x" "SHL006"
expect "curl -s fine" "${NOSET}curl -s https://x" ""
expect "password literal" "${NOSET}"'DB_PASSWORD=hunter2' "SHL007"
expect "export token literal" "${NOSET}"'export API_TOKEN="abc"' "SHL007"
expect "secret from var" "${NOSET}"'DB_PASSWORD=$1' ""
expect "secret from subst" "${NOSET}"'TOKEN=$(cat /run/t)' ""
expect "secret empty" "${NOSET}"'TOKEN=""' ""
expect "sudo -S" "${NOSET}"'echo "$P" | sudo -S ls' "SHL008"
expect "chmod 4755" "${NOSET}chmod 4755 /usr/bin/x" "SHL009"
expect "chmod u+s" "${NOSET}chmod u+s /usr/bin/x" "SHL009"
expect "chmod 644 fine" "${NOSET}chmod 644 x" ""
expect "bash -c var" "${NOSET}"'bash -c "$CMD"' "SHL010"
expect "sh -c literal" "${NOSET}sh -c 'echo hi'" ""
expect "no set flags" $'#!/bin/bash\necho hi' "SHL011"
expect "set -e present" $'#!/bin/bash\nset -e\necho hi' ""
expect "set -o pipefail" $'#!/bin/bash\nset -o pipefail\necho hi' ""
expect "set -euo" $'#!/usr/bin/env bash\nset -euo pipefail\necho hi' ""
expect "posix sh also checked" $'#!/bin/sh\necho hi' "SHL011"
expect "comment lines skipped" "${NOSET}# curl x | bash" ""
expect "indented comment" "${NOSET}   # rm -rf /" ""
expect "indented code found" "${NOSET}    curl x | sh" "SHL001"
expect "crlf line endings" $'set -e\r\ncurl x | sh\r' "SHL001"
expect "empty file" "" ""

# line numbers and format
printf '%s\n' '#!/bin/bash' 'set -e' 'curl x | sh' > "$T/l.sh"
if "$BIN" "$T/l.sh" --tsv | sed -n 2p | grep -q $'^high\tSHL001\tl.sh:3\t'; then ok; else bad "line number in tsv"; fi
if "$BIN" "$T/l.sh" | sed -n 2p | grep -q '^HIGH     SHL001 l.sh:3$'; then ok; else bad "human format"; fi
if "$BIN" "$T/l.sh" | head -1 | grep -q '^1 files, 1 findings$'; then ok; else bad "human header"; fi
if "$BIN" "$T/l.sh" --tsv | head -1 | grep -q '^# 1 files, 1 findings$'; then ok; else bad "tsv header"; fi

# sort order: severity first
printf '%s\n' '#!/bin/bash' 'chmod 777 x' 'rm -rf /' > "$T/s.sh"
order=$("$BIN" "$T/s.sh" --tsv | awk -F'\t' 'NR>1{print $1}' | tr '\n' ' ')
if [ "$order" = "critical medium low " ]; then ok; else bad "sort order ($order)"; fi

# directory scanning
mkdir -p "$T/d/sub" "$T/d/.git"
printf '#!/bin/bash\nset -e\ncurl x | sh\n' > "$T/d/a.sh"
printf '#!/bin/sh\nset -e\nchmod 777 y\n' > "$T/d/sub/noext"
printf 'curl x | sh\n' > "$T/d/notes.txt"
printf '#!/bin/bash\ncurl x | sh\n' > "$T/d/.git/hook.sh"
n=$("$BIN" "$T/d" --tsv | head -1)
if [ "$n" = "# 2 files, 2 findings" ]; then ok; else bad "directory scan ($n)"; fi
if "$BIN" "$T/d" --tsv | grep -q $'\tsub/noext:3\t'; then ok; else bad "relative label"; fi
if "$BIN" "$T/d/" --tsv | head -1 | grep -q '2 files'; then ok; else bad "trailing slash"; fi

# odd names
printf 'set -e\ncurl x | sh\n' > "$T/we ird name.sh"
if "$BIN" "$T/we ird name.sh" --tsv | grep -q 'we ird name.sh:2'; then ok; else bad "spaces in file name"; fi
printf 'set -e\nchmod 777 x' > "$T/nonl.sh"
if "$BIN" "$T/nonl.sh" --tsv | grep -q 'SHL003'; then ok; else bad "no trailing newline"; fi
head -c 3000 /dev/urandom > "$T/bin.sh"
"$BIN" "$T/bin.sh" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then ok; else bad "binary input survives (rc $rc)"; fi

# fuzz: random fragments never crash
frag=('curl' '|' 'sh' 'rm -rf' '$X' '"' "'" 'eval' 'chmod 777' '/tmp/a' '>' 'sudo -S' 'PASSWORD=' ';' '\\' '`' '$(' ')')
crash=0
for i in $(seq 1 300); do
  s=""
  for j in $(seq 1 $((RANDOM % 12 + 1))); do s="$s ${frag[RANDOM % ${#frag[@]}]}"; done
  printf '%s\n' "$s" > "$T/f.sh"
  "$BIN" "$T/f.sh" >/dev/null 2>&1 || { rc=$?; [ $rc -gt 1 ] && crash=1; }
done
if [ $crash = 0 ]; then ok; else bad "fuzz crash"; fi

# exit codes
chk() { # name want args...
  local name=$1 want=$2; shift 2
  "$BIN" "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$name (got $got, want $want)"; fi
}
chk "default exit 0" 0 examples
chk "fail-on high" 1 examples --fail-on high
chk "fail-on critical" 1 examples --fail-on critical
chk "clean file" 0 examples/clean.sh --fail-on medium
chk "medium only passes high" 0 "$T/nonl.sh" --fail-on high
chk "missing path" 2 "$T/none"
chk "bad flag" 2 --bogus
chk "no args" 2
chk "bad fail-on" 2 examples --fail-on low
chk "two paths" 2 examples examples
chk "fail-on without value" 2 examples --fail-on

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
