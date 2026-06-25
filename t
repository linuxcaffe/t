#!/usr/bin/env bash
###############################################################################
#  t — timelog utility for hledger timeclock files              v1.1.0
#  see: github.com/linuxcaffe/t/
#
#  Config: ~/.task/config/timelog.rc
#    timelog.file       = ~/.task/time/tw.timeclock
#    timelog.tz         = America/Toronto
#    timelog.ledger_bin = hledger
#    timelog.editor     = vi
###############################################################################
#  Prefix "." to use timedot format:  t . i account 1.5h
#    timelog.timedot_file = ~/.task/time/tw.timedot
###############################################################################

VERSION="1.2.0"

# --- Colours -----------------------------------------------------------------
red='\e[0;91m'; green='\e[0;92m'; blue='\e[0;94m'; reset='\e[0m'

# --- Config ------------------------------------------------------------------
rc="${HOME}/.task/config/timelog.rc"

get_config() {
    local key="$1" default="${2:-}"
    [[ -f "$rc" ]] || { printf '%s' "$default"; return; }
    local val
    val=$(grep -m1 "^timelog\.${key}[[:space:]]*=" "$rc" 2>/dev/null \
          | cut -d= -f2- | sed 's/^[[:space:]]*//')
    printf '%s' "${val:-$default}"
}

_expand() { printf '%s' "${1/#\~/$HOME}"; }

tc_file=$(_expand "$(get_config file "${HOME}/.task/time/tw.timeclock")")
tz=$(get_config tz "$(date +%Z)")
LEDGER=$(get_config ledger_bin hledger)
EDITOR_BIN=$(get_config editor "${EDITOR:-vi}")

# $TIMELOG env var overrides config (backwards compat)
[[ -n "${TIMELOG:-}" ]] && tc_file="$TIMELOG"

td_file=$(_expand "$(get_config timedot_file "$(dirname "$tc_file")/tw.timedot")")

# --- Helpers -----------------------------------------------------------------

tc_now()    { TZ="$tz" date "+%Y/%m/%d %H:%M:%S"; }

tc_status() {
    # Returns "i" if clocked in, "o" if out, "" if no entries
    [[ -f "$tc_file" ]] || { printf ''; return; }
    grep -E '^[io] ' "$tc_file" | tail -1 | cut -c1
}

tc_last_i_field() {
    # Get field N from the last "i" line (4=account, 5+=desc)
    local n="$1"
    grep '^i ' "$tc_file" 2>/dev/null | tail -1 | awk -v n="$n" '{print $n}'
}

tc_ledger() { "$LEDGER" -f "$tc_file" "$@"; }

_ensure_file() {
    mkdir -p "$(dirname "$tc_file")"
    [[ -f "$tc_file" ]] || touch "$tc_file"
}

# --- Commands ----------------------------------------------------------------

t_status() {
    local status; status=$(tc_status)
    local account; account=$(tc_last_i_field 4)

    if [[ "$status" == "i" ]]; then
        local in_line; in_line=$(grep '^i ' "$tc_file" | tail -1)
        local in_dt;   in_dt=$(awk '{print $2, $3}' <<< "$in_line")
        local desc;    desc=$(cut -d' ' -f5- <<< "$in_line" | sed 's/[[:space:]]*;.*$//')

        local elapsed_str=""
        local start_epoch; start_epoch=$(date -d "$in_dt" +%s 2>/dev/null)
        if [[ -n "$start_epoch" ]] && (( start_epoch > 0 )); then
            local elapsed_s=$(( $(date +%s) - start_epoch ))
            local h=$(( elapsed_s / 3600 ))
            local m=$(( (elapsed_s % 3600) / 60 ))
            elapsed_str="  (${h}h$(printf '%02d' $m)m elapsed)"
        fi

        printf "${green}IN${reset}  ${blue}%s${reset}%s\n" "$account" "${desc:+  $desc}"
        printf "    since %s%s\n" "${in_dt#* }" "$elapsed_str"

    elif [[ "$status" == "o" ]]; then
        local out_time; out_time=$(grep '^o ' "$tc_file" | tail -1 | awk '{print $3}')
        printf "${red}OUT${reset}  last: ${blue}%s${reset}  at %s\n" "$account" "$out_time"
    else
        printf "${blue}No timelog entries${reset}\nFile: %s\n" "$tc_file"
    fi
}

t_in() {
    local account="${1:-}" desc="${2:-}"
    local status; status=$(tc_status)
    local last_account; last_account=$(tc_last_i_field 4)

    # Default to last used account
    [[ -z "$account" ]] && account="$last_account"

    if [[ "$status" == "i" ]]; then
        local cur_account; cur_account=$(tc_last_i_field 4)
        if [[ "$account" == "$cur_account" || -z "$account" ]]; then
            local cur_desc; cur_desc=$(grep '^i ' "$tc_file" | tail -1 \
                | cut -d' ' -f5- | sed 's/[[:space:]]*;.*$//')
            printf "${blue}Already clocked ${green}IN${reset} to ${blue}%s${reset}%s\n" \
                "$cur_account" "${cur_desc:+  $cur_desc}"
            return 0
        fi
        # Different account — offer to switch
        printf "${blue}Clocked ${green}IN${reset} to ${blue}%s${reset}\n" "$cur_account"
        read -rn1 -p "$(printf "Switch to ${blue}%s${reset}? [Y/n] " "$account")" reply; echo
        [[ "$reply" =~ ^[Nn]$ ]] && { printf "${blue}OK${reset}\n"; return 0; }
        t_out
        echo
    fi

    [[ -z "$account" ]] && { printf "${blue}Specify an account${reset}\n" >&2; return 1; }

    _ensure_file
    local entry="i $(tc_now) $account"
    [[ -n "$desc" ]] && entry+="  $desc"
    { printf '\n'; printf '%s\n' "$entry"; } >> "$tc_file"
    printf "${green}CLOCKED IN${reset} to ${blue}%s${reset}%s at %s\n" \
        "$account" "${desc:+  $desc}" "$(date '+%r')"
}

t_out() {
    local comment="${*:-}"
    local status; status=$(tc_status)
    if [[ "$status" != "i" ]]; then
        printf "${blue}Not clocked ${green}IN${reset}\n" >&2; return 1
    fi

    local account; account=$(tc_last_i_field 4)
    local desc;    desc=$(grep '^i ' "$tc_file" | tail -1 \
        | cut -d' ' -f5- | sed 's/[[:space:]]*;.*$//')

    local entry="o $(tc_now)"
    [[ -n "$comment" ]] && entry+="  ; $comment"
    printf '%s\n' "$entry" >> "$tc_file"
    printf "${red}CLOCKED OUT${reset} of ${blue}%s${reset}%s at %s\n" \
        "$account" "${desc:+  $desc}" "$(date '+%r')"
}

t_comment() {
    local comment="${*:-}"
    [[ -z "$comment" ]] && read -e -p "Comment: " comment
    [[ -z "$comment" ]] && return 0
    local ts; ts=$(date "+%H:%M:%S")
    printf '; %s -- %s\n' "$ts" "$comment" >> "$tc_file"
    printf "${blue}Comment added${reset} at %s\n" "$ts"
}

t_log() {
    # Record a completed interval ending now
    # Usage: t log <minutes> [account] [desc]
    local minutes="${1:-}"; shift
    local account="${1:-}"; shift
    local desc="${*:-}"

    [[ "$minutes" =~ ^[0-9]+$ ]] || {
        printf 'Usage: t log <minutes> [account] [desc]\n' >&2
        printf '  Records <minutes> of work ending now\n' >&2
        return 1
    }

    [[ -z "$account" ]] && account=$(tc_last_i_field 4)
    [[ -z "$account" ]] && { printf 'Specify an account\n' >&2; return 1; }

    _ensure_file
    local stopped; stopped=$(tc_now)
    local started; started=$(TZ="$tz" date -d "-${minutes} minutes" "+%Y/%m/%d %H:%M:%S")

    local entry="i $started $account"
    [[ -n "$desc" ]] && entry+="  $desc"
    { printf '\n'; printf '%s\n' "$entry"; printf 'o %s\n' "$stopped"; printf '\n'; } >> "$tc_file"
    printf "${green}Logged${reset} %sm to ${blue}%s${reset}%s\n" \
        "$minutes" "$account" "${desc:+  $desc}"
}

t_accounts() { grep '^i ' "$tc_file" 2>/dev/null | awk '{print $4}' | sort -u; }

t_cur() {
    [[ "$(tc_status)" == "i" ]] && tc_last_i_field 4
}

t_last() {
    local n="${1:-1}"
    awk '/^i / { last=$4 } /^o / { print last }' "$tc_file" 2>/dev/null \
        | tail -n "$n" | head -1
}

t_ui() {
    command -v hledger-ui &>/dev/null \
        && hledger-ui -f "$tc_file" "$@" \
        || { printf 'hledger-ui not found\n' >&2; return 1; }
}

t_web() {
    command -v hledger-web &>/dev/null \
        && hledger-web -f "$tc_file" "$@" \
        || { printf 'hledger-web not found\n' >&2; return 1; }
}

t_zip() {
    local dir; dir=$(dirname "$tc_file")
    local ts;  ts=$(date "+%Y%m%d_%H%M%S")
    local bak="${dir}/tw.${ts}.timeclock.bak"
    cp "$tc_file" "$bak" && printf "Backup: %s\n" "$bak"
}

t_version() {
    local lv; lv=$("$LEDGER" --version 2>/dev/null | head -1 || printf '%s (not found)' "$LEDGER")
    printf "t %s\nconfig:  %s\ntimelog: %s\ntimedot: %s\nledger:  %s\n" \
        "$VERSION" "$rc" "$tc_file" "$td_file" "$lv"
}

t_help() {
    cat << EOF
Usage: t [action] [args]                              "t" is for timelog

  Clock:
    i|in  [account] [desc]     clock in  (switches if already clocked in)
    o|out [comment]            clock out
    l|log <min> [acct] [desc]  record <min> minutes of work ending now

  Status & info:
    (no args)|s|status         show current status + elapsed time
    a|accounts                 list accounts used
    cur                        current account (for prompts/scripts)
    last [n]  / last^^^^^      nth-last completed account (^ = 2nd-last etc)

  Reports (extra args passed through to hledger):
    b|bal   [args]    balance report
    r|reg   [args]    register report
    p|print [args]    print entries
    stats             file stats
    td|today          balance today
    yd|yesterday      balance yesterday
    yd^               balance 2 days ago
    tw|thisweek       balance this week
    lw|lastweek       balance last week
    tm|thismonth      balance this month
    lm|lastmonth      balance last month

  File:
    e|edit            open timelog in \$EDITOR
    f|file            show timelog path
    g|grep  [args]    grep timelog
    t|tail  [n]       tail timelog (default: 20 lines)
    head    [n]       head timelog (default: 20 lines)
    less              page through timelog
    c|comment [text]  add timestamped comment

  Tools:
    u|ui    [args]    open in hledger-ui
    w|web   [args]    open in hledger-web
    z|zip             backup timelog with timestamp
    v|version         show version and config paths
    h|help            this help

  Timedot mode:  prefix any command with "."
    t . i account time [comment]   log time in timedot format
    t . b                          balance report on timedot file
    t . help                       timedot mode help

  Config: ~/.task/config/timelog.rc
    timelog.file         = ~/.task/time/tw.timeclock
    timelog.timedot_file = ~/.task/time/tw.timedot
    timelog.tz           = America/Toronto
    timelog.ledger_bin   = hledger
    timelog.editor       = vi    (defaults to \$EDITOR)
EOF
}

# --- Timedot helpers ---------------------------------------------------------

td_now()        { TZ="$tz" date "+%Y/%m/%d"; }
td_ledger()     { "$LEDGER" -f "$td_file" "$@"; }

_ensure_td_file() {
    mkdir -p "$(dirname "$td_file")"
    [[ -f "$td_file" ]] || touch "$td_file"
}

td_last_date() {
    [[ -f "$td_file" ]] || { printf ''; return; }
    grep -E '^[0-9]{4}/[0-9]{2}/[0-9]{2}' "$td_file" | tail -1
}

td_last_account() {
    [[ -f "$td_file" ]] || { printf ''; return; }
    grep -E '^[^;#*/[:space:]].*  +[0-9. ]' "$td_file" | tail -1 | sed 's/  .*//'
}

td_accounts() {
    [[ -f "$td_file" ]] || return
    grep -E '^[^;#*/[:space:]].*  +[0-9. ]' "$td_file" | sed 's/  .*//' | sort -u
}

# --- Timedot commands --------------------------------------------------------

t_dot_status() {
    if [[ ! -f "$td_file" ]]; then
        printf "${blue}No timedot entries${reset}\nFile: %s\n" "$td_file"; return
    fi
    local last_date; last_date=$(td_last_date)
    local last_entry; last_entry=$(grep -E '^[^;#*/[:space:]].*  +[0-9. ]' "$td_file" | tail -1)
    if [[ -n "$last_entry" ]]; then
        printf "${blue}Last:${reset}  ${blue}%s${reset}\n    on %s\n" "$last_entry" "$last_date"
    else
        printf "${blue}No timedot entries yet${reset}\n"
    fi
    printf "File: %s\n" "$td_file"
}

t_dot_in() {
    local account="${1:-}" time="${2:-}"; shift 2 2>/dev/null || true
    local comment="${*:-}"

    [[ -z "$account" ]] && { printf 'Specify an account\n' >&2; return 1; }
    [[ -z "$time" ]]    && { printf 'Specify a time (e.g. 1.5h  ....  90m)\n' >&2; return 1; }

    _ensure_td_file
    local today; today=$(td_now)
    local last_date; last_date=$(td_last_date)

    local entry="${account}  ${time}"
    [[ -n "$comment" ]] && entry+="    ; ${comment#; }"

    if [[ "$last_date" == "$today" ]]; then
        printf '%s\n' "$entry" >> "$td_file"
    else
        { printf '\n%s\n%s\n' "$today" "$entry"; } >> "$td_file"
    fi
    printf "${green}LOGGED${reset}  ${blue}%s${reset}  %s%s\n" \
        "$account" "$time" "${comment:+  ; $comment}"
}

t_dot_log() {
    local minutes="${1:-}"; shift
    local account="${1:-}"; shift
    local desc="${*:-}"

    [[ "$minutes" =~ ^[0-9]+$ ]] || {
        printf 'Usage: t . log <minutes> [account] [desc]\n' >&2; return 1
    }
    [[ -z "$account" ]] && account=$(td_last_account)
    [[ -z "$account" ]] && { printf 'Specify an account\n' >&2; return 1; }

    # Convert minutes to decimal hours, trimming unnecessary zeros
    local hrs; hrs=$(awk "BEGIN { printf \"%.2f\", $minutes/60 }" \
        | sed 's/\.00$//' | sed 's/\(\.[0-9]\)0$/\1/')
    t_dot_in "$account" "${hrs}h" "$desc"
}

t_dot_comment() {
    local comment="${*:-}"
    [[ -z "$comment" ]] && read -e -p "Comment: " comment
    [[ -z "$comment" ]] && return 0
    _ensure_td_file
    local ts; ts=$(date "+%H:%M:%S")
    printf '; %s -- %s\n' "$ts" "$comment" >> "$td_file"
    printf "${blue}Comment added${reset} at %s\n" "$ts"
}

t_dot_zip() {
    local dir; dir=$(dirname "$td_file")
    local ts;  ts=$(date "+%Y%m%d_%H%M%S")
    local bak="${dir}/tw.${ts}.timedot.bak"
    cp "$td_file" "$bak" && printf "Backup: %s\n" "$bak"
}

t_dot_help() {
    cat << EOF
Usage: t . [action] [args]                      "t ." is for timedot

  Entry:
    i|in  account time [comment]    log time  (e.g. t . i work:client 2.5h)
    l|log <min> [acct] [desc]       log <minutes> of work (converts to decimal h)
    c|comment [text]                add timestamped comment

  Status & info:
    (no args)|s|status              show last entry + file path
    a|accounts                      list accounts used
    cur                             last-used account (for scripts/prompts)

  Reports (extra args passed to hledger):
    b|bal   [args]    balance report
    r|reg   [args]    register report
    p|print [args]    print entries
    stats             file stats
    td|today          balance today
    yd|yesterday      balance yesterday
    yd^               balance 2 days ago
    tw|thisweek       balance this week
    lw|lastweek       balance last week
    tm|thismonth      balance this month
    lm|lastmonth      balance last month

  File:
    e|edit            open timedot file in \$EDITOR
    f|file            show timedot file path
    g|grep  [args]    grep timedot file
    t|tail  [n]       tail timedot file (default: 20 lines)
    head    [n]       head timedot file (default: 20 lines)
    less              page through timedot file
    u|ui    [args]    open in hledger-ui
    w|web   [args]    open in hledger-web
    z|zip             backup timedot file with timestamp
    h|help            this help

  Time formats:  ....  (dots, each = 15min)   1.5h   90m   1.5 (decimal h)
  Account/time separator: 2+ spaces  →  account  1.5h

  Config: ~/.task/config/timelog.rc
    timelog.timedot_file = ~/.task/time/tw.timedot
EOF
}

# --- Dispatch ----------------------------------------------------------------

action="${1:-}"; [[ -n "${1:-}" ]] && shift

case "$action" in
    ""|status|s)    t_status;;
    in|i)           t_in "$@";;
    out|o)          t_out "$@";;
    comment|c)      t_comment "$@";;
    log|l)          t_log "$@";;
    accounts|a)     t_accounts;;
    bal|b)          tc_ledger bal "$@";;
    reg|r)          tc_ledger reg "$@";;
    print|p)        tc_ledger print "$@";;
    stats)          tc_ledger stats "$@";;
    today|td)       tc_ledger bal -p today "$@";;
    yesterday|yd)   tc_ledger bal -p yesterday "$@";;
    yd^)            tc_ledger bal -p "2 days ago" "$@";;
    thisweek|tw)    tc_ledger bal -p "this week" "$@";;
    lastweek|lw)    tc_ledger bal -p "last week" "$@";;
    thismonth|tm)   tc_ledger bal -p "this month" "$@";;
    lastmonth|lm)   tc_ledger bal -p "last month" "$@";;
    cur)            t_cur;;
    last)           t_last "${1:-1}";;
    last^)          t_last 2;;
    last^^)         t_last 3;;
    last^^^)        t_last 4;;
    last^^^^)       t_last 5;;
    last^^^^^)      t_last 6;;
    edit|e)         "$EDITOR_BIN" "$tc_file";;
    file|f)         printf '%s\n' "$tc_file";;
    grep|g)         grep "$@" "$tc_file";;
    head)           if [[ $# -gt 0 ]]; then head "$@" "$tc_file"; else head -20 "$tc_file"; fi;;
    tail|t)         if [[ $# -gt 0 ]]; then tail "$@" "$tc_file"; else tail -20 "$tc_file"; fi;;
    less)           less "$tc_file";;
    ui|u)           t_ui "$@";;
    web|w)          t_web "$@";;
    zip|z)          t_zip;;
    version|v)      t_version;;
    help|h|--help)  t_help;;
    ".")
        dot_action="${1:-}"; [[ -n "${1:-}" ]] && shift
        case "$dot_action" in
            ""|status|s)    t_dot_status;;
            in|i)           t_dot_in "$@";;
            out|o)          printf 'No clock-out in timedot mode — use: t . i account time\n' >&2; exit 1;;
            log|l)          t_dot_log "$@";;
            comment|c)      t_dot_comment "$@";;
            accounts|a)     td_accounts;;
            bal|b)          td_ledger bal "$@";;
            reg|r)          td_ledger reg "$@";;
            print|p)        td_ledger print "$@";;
            stats)          td_ledger stats "$@";;
            today|td)       td_ledger bal -p today "$@";;
            yesterday|yd)   td_ledger bal -p yesterday "$@";;
            yd^)            td_ledger bal -p "2 days ago" "$@";;
            thisweek|tw)    td_ledger bal -p "this week" "$@";;
            lastweek|lw)    td_ledger bal -p "last week" "$@";;
            thismonth|tm)   td_ledger bal -p "this month" "$@";;
            lastmonth|lm)   td_ledger bal -p "last month" "$@";;
            cur)            td_last_account;;
            edit|e)         "$EDITOR_BIN" "$td_file";;
            file|f)         printf '%s\n' "$td_file";;
            grep|g)         grep "$@" "$td_file";;
            head)           if [[ $# -gt 0 ]]; then head "$@" "$td_file"; else head -20 "$td_file"; fi;;
            tail|t)         if [[ $# -gt 0 ]]; then tail "$@" "$td_file"; else tail -20 "$td_file"; fi;;
            less)           less "$td_file";;
            ui|u)           command -v hledger-ui &>/dev/null && hledger-ui -f "$td_file" "$@" || { printf 'hledger-ui not found\n' >&2; exit 1; };;
            web|w)          command -v hledger-web &>/dev/null && hledger-web -f "$td_file" "$@" || { printf 'hledger-web not found\n' >&2; exit 1; };;
            zip|z)          t_dot_zip;;
            version|v)      t_version;;
            help|h|--help)  t_dot_help;;
            *)              printf 'Unknown dot command: %s\n\n' "$dot_action" >&2; t_dot_help; exit 1;;
        esac;;
    *)              printf 'Unknown: %s\n\n' "$action" >&2; t_help; exit 1;;
esac
