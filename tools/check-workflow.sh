#!/usr/bin/env bash
# Parses .github/workflows/*.yml and syntax-checks every `run:` block with
# /bin/bash, which is bash 3.2 on macOS and on the GitHub macOS runners alike.
#
# Why this exists: a shell that is not 3.2 accepts constructions 3.2 rejects,
# and the difference surfaces as a failed release rather than a failed check.
# Measured 2026-09-21: `--notes "$(cat <<NOTES … NOTES)"` parses under bash 5
# and fails under 3.2 at the first apostrophe in the heredoc body
# ("unexpected EOF while looking for matching `''"), which cost a release run.
#
#   0  every block parses
#   1  a block does not
#   2  the check could not run
set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "check-workflow: python3 is missing" >&2; exit 2; }
[ -d .github/workflows ] || { echo "check-workflow: no .github/workflows — run from the repo root" >&2; exit 2; }

python3 - "$@" <<'PY'
import glob, subprocess, sys, tempfile, os

try:
    import yaml
except ImportError:
    print("check-workflow: PyYAML is missing", file=sys.stderr)
    sys.exit(2)

failed = False
checked = 0
for path in sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml")):
    try:
        doc = yaml.safe_load(open(path))
    except yaml.YAMLError as exc:
        print(f"{path}: not valid YAML — {exc}")
        failed = True
        continue
    for job_name, job in (doc.get("jobs") or {}).items():
        for step in job.get("steps") or []:
            script = step.get("run")
            if not script:
                continue
            checked += 1
            # A composite `shell:` other than bash is not ours to judge.
            if step.get("shell", "bash").split()[0] not in ("bash", "sh"):
                continue
            tmp = tempfile.mktemp(suffix=".sh")
            with open(tmp, "w") as fh:
                fh.write(script)
            result = subprocess.run(["/bin/bash", "-n", tmp], capture_output=True, text=True)
            os.unlink(tmp)
            if result.returncode != 0:
                name = step.get("name", "<unnamed step>")
                detail = result.stderr.strip().split(":", 1)[-1].strip()
                print(f"{path}: job {job_name}, step \"{name}\": {detail}")
                failed = True

print(f"check-workflow: {checked} run blocks checked against {subprocess.run(['/bin/bash','-c','echo $BASH_VERSION'], capture_output=True, text=True).stdout.strip()}")
sys.exit(1 if failed else 0)
PY
