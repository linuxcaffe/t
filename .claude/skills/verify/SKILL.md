---
name: verify
description: How to test changes to t (the timeclock/timedot script) — no test suite; drive it against a throwaway HOME.
---

# Verifying t

There is no test suite. `t` reads everything from `$HOME/.task/config/timelog.rc`
and writes under `$HOME/.task/time/`, so point `HOME` at a scratch dir and run it.
Never test against the real `~/.task/time/` files.

```bash
S=<scratchpad>/h; rm -rf "$S"; mkdir -p "$S/.task/config"
cat > "$S/.task/config/timelog.rc" <<'EOF'
timelog.dot-alias.dog  = home:dog-walk 20m
timelog.dot-alias.meds = health:meds 5m ; morning dose
timelog.dot-alias.read = leisure:reading
EOF
r(){ echo "\$ t $*"; HOME=$S ./t "$@"; echo "  [rc=$?]"; }

r . dog; r . dog 40m with rex; r . meds; r . read      # read: must ask for a time
r . walk 30m a comment; r . i work:client 2.5h
r . blance                                             # typo: refused, nothing logged
r . aliases; r . b
r log 5 work; r                                        # timeclock side
cat "$S/.task/time/tw.timedot" "$S/.task/time/tw.timeclock"
hledger -f "$S/.task/time/tw.timedot" bal              # file must parse
```

Things to check:

- **The written file, not just the echo.** A doubled `; ;` once showed only in the echo.
- **Dates near midnight.** With `timelog.tz` unset, the stamps must match `date` (local
  time). Then set `timelog.tz = Asia/Tokyo` and check that the stamps shift.
- `bash -n t` before running anything.

After changing `t` or `README.md`, bump `VERSION` in `t` and `version=` in `t.meta`, and refresh
`checksums=` in `t.meta` (sha256 of `t`, then `README.md`).
