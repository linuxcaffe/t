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
[hledger]: http://hledger.org/

