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

## References ##

Even though this works with [ledger][] 3, the [timelog][] format is only referenced in the [ledger][] v2 documents.  Here are a few resources about the [timelog][] format:

- [Using timeclock to record billable time][timelog]
- [timelog files][htl] - from the [hledger][] project

[ledger]: http://ledger-cli.org
[timelog]: http://ledger-cli.org/2.6/ledger.html#Using-timeclock-to-record-billable-time
[htl]: http://hledger.org/MANUAL.html#timelog-files
[hledger]: http://hledger.org/

