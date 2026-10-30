# t #

## Description ##

t is a shell script for working with [ledger][]'s [timelog][] format, based on Justing Harding's fork (https://github.com/justinharding/t) of Chase James's t (https://github.com/nuex/t) incorporating ideas from the tito script and then heavily modified by me.  
```
#!/bin/bash
######################################################## v.0.6.5
#   _             _   _                _               #
#  | |_          | |_(_)_ __ ___   ___| | ___   __ _   #
#  | __|   IS    | __| | '_ ` _ \ / _ \ |/ _ \ / _` |  #
#  | |_    FOR   | |_| | | | | | |  __/ | (_) | (_| |  #
#   \__|          \__|_|_| |_| |_|\___|_|\___/ \__, |  #
#                                              |___/   #
#                                                      #
########################################################
# t is a utility to work with (h)ledger *.timeclock files
# see github.com/linuxcaffe/task-timelog-hook/
```
## Install ##

Download and install the script to a `bin` directory that exists in your `$PATH`. For example, `$HOME/bin`:

    curl --silent -G https://raw.github.com/linuxcaffe/t -o ~/bin/t
    chmod +x ~/bin/t

Set the location of your timelog file:

    export $TIMELOG=$HOME/path/to/my.timeclock

Because this script is designed to work with [task-timelog-hook](https://github.com/linuxcaffe/task-timelog-hook/)
the default location is `$HOME/.task/hooks/task-timelog-hook/task.timeclock`.
but you can can change it, and other settings, but editing the script.

NOTE: althought the term "timelog" is consistent for this process, 
for some reason the recognized file extension _must be_ `*.timeclock`.
So think of the process as timelogging into a timeclock file, ok?

## Usage ##

```
Usage: t<space><action> or t<CR> for status        "t" is for "timelog"
  actions:
     i|in <account:sub> [desc] [-- comment]     td|today - balance today
     o|out [comment]                            yd|yesterday - bal yesterday
     a|accounts - list accounts used            yd^ - balance for 2 days ago
     b|bal - balance report [args]              tw|thisweek - bal for this week
     c|comm - add time-stamped comment          lw|lastweek - bal for last week
  *  d|dot - open timedot file (hledger)        tm|thismonth - bal for this mo
     e|edit - edit timelog file                 lm|lastmonth - bal for last mo
     f|file - show timelog file         _             
     g|grep - grep [args]              | |_     For report args and options see
     h|help - (you're looking at it)   | __|    ledger-cli.org or man ledger 
  *  l|log - record previous event     | |_      or  
     p|print - print [args]             \__|    hledger.org, run hledger<CR>
     r|reg - register [args]                   
     s|stats                                    For user configs edit this file
     t|tail - show end of timelog               For corrections edit timelog 
  *  u|ui - open in hledger-ui                  For more details see README.md
  *  v|version                                  
  *  w|web - open timelog in browser
  *  z|zip - backup files                       Please report issues/fixes to 
      ( * = planned )          https://github.com/linuxcaffe/task-timelog-hook/
```

## Timedot mode (t .) ##

Prefix `.` to log to a separate [timedot][htd] file instead. There's no clock in
or clock out: a dot entry *is* the whole interval, so you go straight to the
account. It doesn't touch the timeclock either, so you can log a quick habit
while a regular timed activity keeps running.

    t . home:dog-walk 20m          # account + time
    t . health:smoke .             # timedot dots, each . = 15min
    t . walk 30m around the block  # anything after the time is a comment

Define **dot-aliases** in `~/.task/config/timelog.rc` for things you log often:

    timelog.dot-alias.dog   = home:dog-walk 20m
    timelog.dot-alias.smoke = health:smoke .
    timelog.dot-alias.read  = leisure:reading

Then:

    t . dog                  # home:dog-walk  20m
    t . dog 40m with rex     # override the time, add a comment
    t . read 1.5h            # aliases without a time need one given
    t . aliases              # list them

Dot subcommands (`b`, `today`, `tail`, …) take priority over alias and account
names. `t . i account time` still works as the explicit form. See `t . help`.

## Several devices ##

When `~/.task` is shared between devices (say with gittw), `timelog.rc` is shared
too. A `timelog.*` line in `~/.task/local.rc`, which each device keeps to itself,
wins over it, so each device can write its own files:

    # ~/.task/local.rc on a phone
    timelog.file         = ~/.nb/mobile/s5.timeclock
    timelog.timedot_file = ~/.nb/mobile/s5.timedot

To see everything in one place, list the other devices' files for reports. `t`
only reads them (`bal`, `reg`, `print`, `today`, `t . b` …), never writes them,
and skips any that aren't there yet:

    # ~/.task/local.rc on the desktop
    timelog.include         = ~/.nb/mobile/s5.timeclock
    timelog.timedot_include = ~/.nb/mobile/s5.timedot

One file per device means two devices never write the same file: clock in and
out on the same device. `t version` lists the files a report reads.

## Web widget (t codeblock) ##

`t` ships a live timer widget for markdown note apps that support custom code
fences. Embed it in any note — including your daily log — and get a real-time
dashboard with one-click clock-in / clock-out:

~~~markdown
```t
today
```
~~~

Renders as an interactive block showing:

- **⏱ IN → account:sub** with a ticking elapsed time (30 s refresh) when clocked in
- **◌ OUT** with the last account and clock-out time when idle
- **[◼ Out]** button to clock out; **[⏱ In]** button with inline account picker to clock in
- A breakdown table of today's time by account (or `thisweek` / `month`)

### Option A — nb-web (integrated) ###

If you use [nb-web](https://github.com/linuxcaffe/nb-web), the widget is built
in. No extra setup needed. The `t` codeblock is one of four live data codeblocks
(alongside `tw`, `hledger`, and `csv`).

### Option B — standalone server ###

Run `web/t-server.py` alongside any markdown viewer that supports custom code
fences and can load external JS:

```bash
cd ~/dev/t/web
pip install flask flask-cors
python3 t-server.py          # listens on http://localhost:5001
```

Then include the widget assets in your viewer:

```html
<link rel="stylesheet" href="http://localhost:5001/t-block.css">
<script type="module">
  import { registerTBlock, renderTBlocks } from 'http://localhost:5001/t-block.js';
  registerTBlock(marked, { apiBase: 'http://localhost:5001' });
  // after parsing markdown, call:
  await renderTBlocks(document.querySelector('.content'));
</script>
```

The server reads your timeclock file path from `~/.task/config/timelog.rc`
(`timelog.file` key) and falls back to `~/.task/time/tw.timeclock`.

### API endpoints ###

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/t/status` | Current state: `{state, account, elapsed_seconds, …}` |
| GET | `/api/t/report?period=today` | Seconds by account for period |
| GET | `/api/t/accounts` | Sorted list of known accounts |
| POST | `/api/t/in` | Body: `{account, desc?}` — clock in (auto-switches) |
| POST | `/api/t/out` | Clock out |

Periods accepted: `today`, `thisweek`, `week`, `thismonth`, `month`.

## References ##

Even though this works with [ledger][] 3, the [timelog][] format is only referenced in the [ledger][] v2 documents.  Here are a few resources about the [timelog][] format:

- [Using timeclock to record billable time][timelog]
- [timelog files][htl] - from the [hledger][] project

[ledger]: http://ledger-cli.org
[timelog]: http://ledger-cli.org/2.6/ledger.html#Using-timeclock-to-record-billable-time
[htl]: http://hledger.org/MANUAL.html#timelog-files
[htd]: https://hledger.org/dev/hledger.html#timedot
[hledger]: http://hledger.org/

