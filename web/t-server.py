#!/usr/bin/env python3
"""
t-server.py — standalone web API for the t timeclock codeblock widget.

Serves /api/t/* endpoints on localhost:5001 (configurable).
Run alongside any markdown viewer that supports custom code fences.

Usage:
    python3 t-server.py [--port 5001] [--host 127.0.0.1]

Then in any note:
    ```t
    today
    ```

With nb-web: the endpoints are already built in — you don't need this server.
"""

import os, sys, re
from datetime import datetime
from pathlib import Path

try:
    from flask import Flask, jsonify, request
    from flask_cors import CORS
except ImportError:
    sys.exit("pip install flask flask-cors")

app = Flask(__name__)
CORS(app)   # allow any local markdown viewer to call the API


# ---------------------------------------------------------------------------
# Timeclock helpers
# ---------------------------------------------------------------------------

def _tc_file() -> Path:
    rc = Path.home() / '.task/config/timelog.rc'
    default = Path.home() / '.task/time/tw.timeclock'
    if rc.exists():
        for line in rc.read_text().splitlines():
            if line.startswith('timelog.file'):
                val = line.split('=', 1)[1].strip()
                return Path(os.path.expanduser(val))
    return default


def _parse_status(tc: Path) -> dict:
    if not tc.exists():
        return {'state': 'none'}
    last_i = last_o = last_kind = None
    for line in tc.read_text().splitlines():
        if line.startswith('i '):
            last_i = line; last_kind = 'i'
        elif line.startswith('o '):
            last_o = line; last_kind = 'o'
    if last_kind is None:
        return {'state': 'none'}
    parts_i = (last_i or '').split()
    account = parts_i[3] if len(parts_i) > 3 else ''
    desc    = ' '.join(parts_i[4:]).split(';')[0].strip() if len(parts_i) > 4 else ''
    if last_kind == 'i':
        try:
            start   = datetime.strptime(f"{parts_i[1]} {parts_i[2]}", '%Y/%m/%d %H:%M:%S')
            elapsed = max(0, int((datetime.now() - start).total_seconds()))
        except Exception:
            elapsed = 0
        return {'state': 'in', 'account': account, 'desc': desc,
                'since': parts_i[2] if len(parts_i) > 2 else '',
                'elapsed_seconds': elapsed}
    else:
        out_parts = (last_o or '').split()
        return {'state': 'out', 'account': account,
                'last_out': out_parts[2] if len(out_parts) > 2 else ''}


def _parse_report(tc: Path, period: str) -> dict:
    from datetime import date, timedelta
    if not tc.exists():
        return {'rows': [], 'total_seconds': 0}
    today = date.today()
    if period in ('today', ''):
        cutoff = datetime(today.year, today.month, today.day)
    elif period in ('thisweek', 'week'):
        ws = today - timedelta(days=today.weekday())
        cutoff = datetime(ws.year, ws.month, ws.day)
    elif period in ('thismonth', 'month'):
        cutoff = datetime(today.year, today.month, 1)
    else:
        cutoff = datetime(today.year, today.month, today.day)

    by_account: dict = {}
    last_i = None
    for line in tc.read_text().splitlines():
        if line.startswith('i '):
            parts = line.split()
            try:
                dt = datetime.strptime(f"{parts[1]} {parts[2]}", '%Y/%m/%d %H:%M:%S')
                last_i = {'dt': dt, 'account': parts[3] if len(parts) > 3 else 'unknown'}
            except Exception:
                last_i = None
        elif line.startswith('o ') and last_i:
            parts = line.split()
            try:
                dt_out = datetime.strptime(f"{parts[1]} {parts[2]}", '%Y/%m/%d %H:%M:%S')
                if last_i['dt'] >= cutoff or dt_out > cutoff:
                    start = max(last_i['dt'], cutoff)
                    secs  = max(0, int((dt_out - start).total_seconds()))
                    acct  = last_i['account']
                    by_account[acct] = by_account.get(acct, 0) + secs
                last_i = None
            except Exception:
                last_i = None
    if last_i and last_i['dt'] >= cutoff:
        secs = max(0, int((datetime.now() - max(last_i['dt'], cutoff)).total_seconds()))
        by_account[last_i['account']] = by_account.get(last_i['account'], 0) + secs

    rows = sorted([{'account': k, 'seconds': v} for k, v in by_account.items()],
                  key=lambda r: r['account'])
    return {'rows': rows, 'total_seconds': sum(r['seconds'] for r in rows)}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route('/api/t/status')
def api_status():
    return jsonify(_parse_status(_tc_file()))

@app.route('/api/t/report')
def api_report():
    return jsonify(_parse_report(_tc_file(), request.args.get('period', 'today')))

@app.route('/api/t/accounts')
def api_accounts():
    tc = _tc_file()
    if not tc.exists():
        return jsonify({'accounts': []})
    accounts = sorted({l.split()[3] for l in tc.read_text().splitlines()
                       if l.startswith('i ') and len(l.split()) > 3})
    return jsonify({'accounts': accounts})

@app.route('/api/t/in', methods=['POST'])
def api_in():
    data    = request.get_json(silent=True) or {}
    account = data.get('account', '').strip()
    desc    = data.get('desc', '').strip()
    if not account:
        return jsonify({'success': False, 'error': 'account required'}), 400
    tc = _tc_file()
    tc.parent.mkdir(parents=True, exist_ok=True)
    if not tc.exists():
        tc.touch()
    status = _parse_status(tc)
    now_str = datetime.now().strftime('%Y/%m/%d %H:%M:%S')
    if status['state'] == 'in':
        if status['account'] == account:
            return jsonify({'success': False, 'error': f'Already clocked in to {account}'}), 409
        with open(tc, 'a') as f:
            f.write(f'o {now_str}\n')
    entry = f'i {now_str} {account}' + (f'  {desc}' if desc else '')
    with open(tc, 'a') as f:
        f.write(f'\n{entry}\n')
    return jsonify({'success': True})

@app.route('/api/t/out', methods=['POST'])
def api_out():
    tc = _tc_file()
    if _parse_status(tc).get('state') != 'in':
        return jsonify({'success': False, 'error': 'Not clocked in'}), 409
    with open(tc, 'a') as f:
        f.write(f'o {datetime.now().strftime("%Y/%m/%d %H:%M:%S")}\n')
    return jsonify({'success': True})


# ---------------------------------------------------------------------------
# Serve the widget assets
# ---------------------------------------------------------------------------

@app.route('/t-block.js')
def serve_js():
    p = Path(__file__).parent / 't-block.js'
    return p.read_text(), 200, {'Content-Type': 'application/javascript'}

@app.route('/t-block.css')
def serve_css():
    p = Path(__file__).parent / 't-block.css'
    return p.read_text(), 200, {'Content-Type': 'text/css'}


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description='t timeclock web API server')
    ap.add_argument('--port', type=int, default=5001)
    ap.add_argument('--host', default='127.0.0.1')
    args = ap.parse_args()
    print(f't-server running on http://{args.host}:{args.port}')
    app.run(host=args.host, port=args.port)
