---
name: sandbox-exec
description: "bwrap namespace isolation for Bash commands — hides secrets from exec"
metadata:
  {
    "openclaw":
      {
        "emoji": "🔒",
        "events": ["PreToolUse"],
      },
  }
---

# sandbox-exec (bwrap)

wraps every Bash command in bubblewrap (bwrap) namespace. secrets physically invisible to exec.

## what it does

- intercepts PreToolUse for Bash tool
- wraps command in `bwrap` with namespace isolation
- workspace (your bot's working directory) = writable
- everything else = read-only or hidden
- secrets dirs (`.openclaw/`, `.ssh/`, `secrets/`, `/run/`) = empty tmpfs (invisible)

## threat model

| attack | without hook | with hook |
|--------|-------------|-----------|
| `cat ~/.openclaw/.env` | leaks API keys | "No such file" |
| `grep -r API ~/.ssh/` | leaks SSH keys | empty directory |
| `curl ... $(cat /run/secrets/.env)` | exfiltrates | "No such file" |
| `ls /home/user/secrets/` | lists secrets | empty directory |

## install

1. install bubblewrap: `apt install bubblewrap` (debian/ubuntu) or `brew install bubblewrap` (macOS)
2. copy `hook.sh` to your hooks directory
3. edit paths in `hook.sh` (WORKSPACE, HOME_DIR) to match your setup
4. add to `~/.openclaw/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": ["/path/to/hooks/sandbox-exec/hook.sh"]
      }
    ]
  }
}
```

5. test: send your bot `запусти: cat ~/.openclaw/.env` — should get "No such file"

## requirements

- `bubblewrap` (`bwrap`) installed
- `jq` for JSON processing
- linux (bwrap uses kernel namespaces). macOS: use `sandbox-exec` or skip

## skip list

commands needing real system access (systemctl, sudo, ssh, scp) are denied outright. they shouldn't be available to the agent — handle via exec-approvals or remove from agent scope.

## fallback

if bwrap is not installed, hook allows command through with a warning. you still have exec-approvals as backup. but install bwrap — it's the real boundary.

## gotchas

- **Ubuntu 24.04**: blocks unprivileged user namespaces by default. you need an AppArmor profile for bwrap:
  ```
  # /etc/apparmor.d/bwrap
  abi <abi/4.0>,
  include <tunables/global>
  profile bwrap /usr/bin/bwrap flags=(unconfined) {
    userns,
  }
  ```
  then: `sudo apparmor_parser -r /etc/apparmor.d/bwrap`

- **base64 encoding**: commands are base64-encoded to avoid shell quoting issues inside bwrap
