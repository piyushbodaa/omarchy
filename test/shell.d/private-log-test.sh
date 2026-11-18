#!/bin/bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
export TMPDIR="$sandbox/tmp"
mkdir "$TMPDIR" "$sandbox/bin"
export PATH="$sandbox/bin:$PATH"
umask 022

cat >"$sandbox/bin/curl" <<'STUB'
#!/bin/bash
set -eu
for arg in "$@"; do
  if [[ $arg == file=@* ]]; then
    file=${arg#file=@}
    [[ ${file%/*} == "$TMPDIR"/* ]]
    [[ $(stat -c %a "${file%/*}") == 700 ]]
    grep -qx 'fixture journal entry' "$file"
    echo 'local-upload-fixture'
    exit 0
  fi
done
exit 1
STUB
cat >"$sandbox/bin/journalctl" <<'STUB'
#!/bin/bash
echo 'fixture journal entry'
STUB
for command in pacman inxi expac fastfetch; do
  ln -s /usr/bin/true "$sandbox/bin/$command"
done
ln -s /usr/bin/false "$sandbox/bin/omarchy-cmd-present"
chmod +x "$sandbox/bin/curl" "$sandbox/bin/journalctl"
"$ROOT/bin/omarchy-upload-log" this-boot | grep -q 'local-upload-fixture'
[[ -z $(ls -A "$TMPDIR") ]] || fail "upload left a temporary log"
"$ROOT/bin/omarchy-debug" --print --no-sudo >"$sandbox/report"
grep -qx 'fixture journal entry' "$sandbox/report" || fail "printed report lost the journal"
[[ -z $(ls -A "$TMPDIR") ]] || fail "debug left a temporary log"
pass "diagnostic reports use private staging and clean it up"
