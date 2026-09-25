"""ship-watch.py <worker-pid> <ship> <jar> <minutes>: every 10 s, the
worker's CPU share over a quiet window (from /proc deltas, not ps), the
orrery instance's bang, and whether the version route answers and how
fast. A spin shows as the CPU pinned and the route dead; a parked fiber
as a dead route with the CPU near 0. See the README, Development."""
import sys, time, json, os, subprocess
pid, host, jar, minutes = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
tck = os.sysconf('SC_CLK_TCK')
def ticks():
    f = open(f'/proc/{pid}/stat').read().rsplit(')', 1)[1].split()
    return int(f[11]) + int(f[12])
def get(url, t=20):
    t0 = time.time()
    r = subprocess.run(['curl', '-s', '-m', str(t), '-b', jar, '-w', '\n%{http_code}', url], capture_output=True, text=True).stdout
    body, _, code = r.rpartition('\n')
    return code, body, time.time() - t0
end = time.time() + minutes * 60
while time.time() < end:
    #  the CPU of a quiet window, the probes below left out: ?info=1
    #  alone costs the worker seconds
    prev, pt = ticks(), time.time()
    time.sleep(10)
    now, nt = ticks(), time.time()
    cpu = 100.0 * (now - prev) / tck / (nt - pt)
    code, body, secs = get(host + '/apps/orrery/api/version')
    bc, bb, _ = get(host + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app?info=1', 30)
    try: bang = json.loads(bb).get('bang')
    except Exception: bang = '?'
    print(f'{time.strftime("%H:%M:%S")} cpu {cpu:5.1f}%  version {code} {body[:20]} ({secs:.1f}s)  bang {bang}', flush=True)
