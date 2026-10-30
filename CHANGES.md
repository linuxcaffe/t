# CHANGES.md


Sun Nov 21 16:28:50 EST 2021
working on t, 
- changed it from sh to bash
- echo action on in or out
- added "i" and "o"
- allowed following arguments (payee field) 2space separated
- ignore all lines that don't start with "i " or "o "
- reworked use-last-account, if none specified
- prettied prompts

Tue Nov 23 16:58:37 EST 2021
- added timezone variable
- rewrote status function, bind to "T"<no args>

Fri Oct 30 2026 (1.4.0)
- timelog.* in ~/.task/local.rc (per device) wins over timelog.rc
- timelog.include / timelog.timedot_include: more files for reports only
- t version lists them
