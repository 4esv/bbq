#!/usr/bin/env python3
"""compare.py — side-by-side BQN vs Python on identical deterministic inputs.

Run from: /Users/axel/Code/projects/bbq/main
  python3 _verification/compare.py
"""
import subprocess, tempfile, os, math
import numpy as np
from scipy import stats as sc
import pandas as pd

ENG = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "engine"))

def bqn(code):
    """Write code to temp .bqn file in engine dir, run, return stdout."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.bqn', dir=ENG,
                                     delete=False, encoding='utf-8') as f:
        f.write(code); fname = f.name
    try:
        r = subprocess.run(['bqn', fname], capture_output=True, text=True, cwd=ENG)
        if r.returncode != 0:
            return f"ERR:{r.stderr.strip()[:60]}"
        return r.stdout.strip()
    finally:
        os.unlink(fname)

def parse(s):
    s = s.strip().split('\n')[0].split(' ')[0].replace('¯', '-')
    try: return float(s)
    except: return None

def arr(a):
    """numpy array → BQN stranded literal."""
    parts = []
    for x in np.asarray(a).flat:
        x = round(float(x), 10)
        parts.append(f"¯{abs(x)}" if x < 0 else str(x))
    return "‿".join(parts)

# ── Deterministic 25-bar inputs ───────────────────────────────────────────────

R = np.array([0.01,-0.02,0.03,-0.01,0.02,-0.015,0.025,-0.005,
              0.01,-0.02,0.015,-0.01,0.02,-0.025,0.01,0.005,
             -0.01,0.02,-0.015,0.01,0.005,-0.01,0.02,-0.015,0.01])

B = np.array([0.008,-0.015,0.025,-0.008,0.018,-0.012,0.022,-0.004,
              0.008,-0.018,0.012,-0.009,0.017,-0.022,0.009,0.004,
             -0.009,0.018,-0.013,0.009,0.004,-0.009,0.018,-0.013,0.009])

rs, bs = arr(R), arr(B)
rows = []

def check(name, py_val, bqn_code, tol=1e-4):
    raw  = bqn(bqn_code)
    bv   = parse(raw)
    pf   = float(py_val)
    py_s = f"{pf:+.6f}"
    bqn_s = f"{bv:+.6f}" if bv is not None else raw[:14]
    if bv is not None:
        ok = "✓" if abs(pf - bv) < tol else "✗ MISMATCH"
    else:
        ok = "? ERR"
    rows.append((name, py_s, bqn_s, ok))

# ══ roll.bqn ══════════════════════════════════════════════════════════════════
n = 5
sr = pd.Series(R); sb = pd.Series(B)

check("RSharpe[5] last",
    float((sr.rolling(n).mean() / sr.rolling(n).std(ddof=1) * math.sqrt(252)).iloc[-1]),
    f"roll←•Import\"roll.bqn\"\n•Out •Fmt ¯1⊑{n} roll.RSharpe {rs}")

check("RVol[5] last",
    float(sr.rolling(n).std(ddof=1).iloc[-1] * math.sqrt(252)),
    f"roll←•Import\"roll.bqn\"\n•Out •Fmt ¯1⊑{n} roll.RVol {rs}")

check("RBeta[5] last",
    float((sr.rolling(n).cov(sb) / sb.rolling(n).var(ddof=1)).iloc[-1]),
    f"roll←•Import\"roll.bqn\"\n•Out •Fmt ¯1⊑{n}‿({bs}) roll.RBeta {rs}")

def cagr(r): return (np.prod(1+r))**(252/len(r)) - 1
c = np.cov(R, B, ddof=1)[0,1]; v = np.var(B, ddof=1)
check("Alpha(rf=0)",
    cagr(R) - (c/v) * (cagr(B) - 0),
    f"roll←•Import\"roll.bqn\"\n•Out •Fmt ({bs})‿0 roll.Alpha {rs}")

d = R - B
check("IR",
    float(np.mean(d) / np.std(d, ddof=1) * math.sqrt(252)),
    f"roll←•Import\"roll.bqn\"\n•Out •Fmt ({bs}) roll.IR {rs}")

# Drawdowns: returns [0.1, -0.2, 0.05] → one episode, depth near -0.2
_ep = np.cumprod(1 + np.array([0.1, -0.2, 0.05]))
check("Drawdowns depth[0]",
    float(min(_ep / np.maximum.accumulate(_ep) - 1)),
    "roll←•Import\"roll.bqn\"\n"
    "ep←roll.Drawdowns 0.1‿¯0.2‿0.05\n"
    "•Out •Fmt ⊑ep.depth")

# ══ risk.bqn ══════════════════════════════════════════════════════════════════
SIG = np.ones(25); ss = arr(SIG)

check("VolTarget@bar20",
    1.0 * 0.2 / (np.std(R[:21], ddof=1) * math.sqrt(252)),
    f"risk←•Import\"risk.bqn\"\n•Out •Fmt 20⊑0.2 risk.VolTarget ({ss})‿({rs})")

check("KellyFrac(f=0.5)",
    float(np.clip(0.5 * np.mean(R) / np.var(R, ddof=1), -1, 1)),
    f"risk←•Import\"risk.bqn\"\n•Out •Fmt 0.5 risk.KellyFrac {rs}")

check("MaxPos cap=1 on ¯2",
    -1.0,
    "risk←•Import\"risk.bqn\"\n•Out •Fmt ⊑ 1 risk.MaxPos ¯2‿¯0.5‿0‿0.5‿2")

# DDControl: threshold -5%, R has early losses → check some zeros appear
eq = np.cumprod(1 + R); dd = (eq - np.maximum.accumulate(eq)) / np.maximum.accumulate(eq)
py_ddc_zeros = int((R * (dd >= -0.05) == 0).sum())  # bars with zero due to dd or flat
check("DDControl zeros≥0",
    float((dd < -0.05).sum()),
    f"risk←•Import\"risk.bqn\"\n"
    f"pos←25⥊1\n"
    f"ddc←¯0.05 risk.DDControl pos‿({rs})\n"
    f"•Out •Fmt +´ ddc=0")

# ══ ovf.bqn ══════════════════════════════════════════════════════════════════

check("PhiInv(0.5)=0",
    float(sc.norm.ppf(0.5)),
    "opt←•Import\"opt.bqn\"\n•Out •Fmt opt.PhiInv 0.5", tol=1e-5)

check("PhiInv(0.975)≈1.96",
    float(sc.norm.ppf(0.975)),
    "opt←•Import\"opt.bqn\"\n•Out •Fmt opt.PhiInv 0.975", tol=1e-4)

check("Phi(PhiInv(0.1))=0.1",
    0.1,
    "opt←•Import\"opt.bqn\"\n•Out •Fmt opt.Phi opt.PhiInv 0.1", tol=1e-5)

# DSR: non-degenerate case — sk=0.5, ku=2 (excess kurtosis), so v>0
sr_v, sk_v, ku_v, T_v, n_v = 0.10, 0.5, 2.0, 252, 10
eu = 0.5772156649
a_ = (1-eu) * sc.norm.ppf(1 - 1/n_v)
b_ = eu     * sc.norm.ppf(1 - 1/(n_v * math.e))
sr_star = (a_ + b_) * math.sqrt(1/(T_v - 1))
sig_sr  = math.sqrt(max(0, (1 - sk_v*sr_v + (ku_v-1)/4*sr_v**2) / (T_v - 1)))
py_dsr  = float(sc.norm.cdf((sr_v - sr_star) / max(sig_sr, 1e-10)))

check(f"DSR(SR=0.1,sk=0.5,ku=2,n={n_v})", py_dsr,
    f"ovf←•Import\"ovf.bqn\"\n•Out •Fmt {n_v} ovf.DSR {sr_v}‿{sk_v}‿{ku_v}‿{T_v}")

# HHI: [0.01, 0.01, 0.02] → (0.25,0.25,0.5)^2 summed = 0.375
h = np.array([0.01, 0.01, 0.02])
check("HHI([0.01,0.01,0.02])=0.375",
    float(np.sum((h / h.sum())**2)),
    "ovf←•Import\"ovf.bqn\"\n•Out •Fmt ovf.HHI 0.01‿0.01‿0.02", tol=1e-6)

# TrialCorrect BH: p=[0.001,0.01,0.05,0.1,0.3] α=0.05
# BH: sorted crits = k/5×0.05 = [0.01,0.02,0.03,0.04,0.05]
# p[0]=0.001 ≤ 0.01 ✓, p[1]=0.01 ≤ 0.02 ✓, p[2]=0.05 > 0.03 ✗ → reject first 2
from scipy.stats import false_discovery_control
rej = false_discovery_control(np.array([0.001,0.01,0.05,0.1,0.3])) <= 0.05
tc_code = ("ovf←•Import\"ovf.bqn\"\n"
           "rej←5‿0.05 ovf.TrialCorrect 0.001‿0.01‿0.05‿0.1‿0.3\n")
check("TrialCorrect p=0.001 → 1",
    float(int(rej[0])), tc_code + "•Out •Fmt ⊑rej",          tol=0.01)
check("TrialCorrect p=0.01  → 1",
    float(int(rej[1])), tc_code + "•Out •Fmt 1⊑rej",         tol=0.01)
check("TrialCorrect p=0.05  → 0",
    float(int(rej[2])), tc_code + "•Out •Fmt 2⊑rej",         tol=0.01)

# ══ exec.bqn ══════════════════════════════════════════════════════════════════

# Slippage: 0→1 at bar 0, hold, adv_frac=0.1, vol=1e6
pe = np.array([0.,1.,1.,1.,1.]); ve = np.ones(5) * 1e6
de = np.abs(np.diff(np.concatenate([[0.], pe])))
check("Slippage(0→1 entry)",
    float(np.sum(0.1 * np.sqrt(de / (0.1 * ve + 1e-10)))),
    "exec←•Import\"exec.bqn\"\n"
    "p←0‿1‿1‿1‿1\nv←1e6‿1e6‿1e6‿1e6‿1e6\n"
    "•Out •Fmt +´ 0.1‿0.1 exec.Slippage p‿v")

# RunOHLC: all-long, open=[100,101,102,100,103]
o = np.array([100.,101.,102.,100.,103.])
check("RunOHLC mean return",
    float(np.mean(np.ones(4) * np.diff(o) / o[:-1])),
    "bt←•Import\"bt.bqn\"\n"
    "o←100‿101‿102‿100‿103\n"
    "d←{dates⇐\"a\"‿\"b\"‿\"c\"‿\"d\"‿\"e\","
    " close⇐o, high⇐o+1, low⇐o-1, open⇐o, vol⇐1e6‿1e6‿1e6‿1e6‿1e6}\n"
    "p←1‿1‿1‿1‿1\nr←p bt.RunOHLC d\n"
    "•Out •Fmt (+´r)÷≠r")

# StopLoss: enter bar1 open=100, stop=2%→98, low[2]=97 → triggered at bar 2
pos_sl = np.array([0.,1.,1.,1.,1.])
op_sl  = np.array([99.,100.,100.,100.,100.])
lo_sl  = np.array([98., 99., 97., 99., 99.])
cl_sl  = np.array([99.5,100.5,99.5,100.5,100.5])

def sl_ref(pos, op, lo, cl, pct):
    mod = (cl - op) / op; trig = np.zeros(len(pos), int); entry = 0.
    for i in range(len(pos)):
        if pos[i] > 0:
            if i == 0 or pos[i-1] == 0: entry = op[i]
            sp = entry * (1 - pct)
            if lo[i] < sp: trig[i]=1; mod[i]=(sp-op[i])/op[i]; entry=0.
        else: entry = 0.
    return trig.sum(), float((pos * mod).mean())

sl_n, sl_ret = sl_ref(pos_sl, op_sl, lo_sl, cl_sl, 0.02)

sl_setup = ("exec←•Import\"exec.bqn\"\n"
            "op←99‿100‿100‿100‿100\n"
            "lo←98‿99‿97‿99‿99\n"
            "cl←99.5‿100.5‿99.5‿100.5‿100.5\n"
            "d←{dates⇐\"a\"‿\"b\"‿\"c\"‿\"d\"‿\"e\","
            " close⇐cl, high⇐op+1, low⇐lo, open⇐op, vol⇐1e6‿1e6‿1e6‿1e6‿1e6}\n"
            "pos2←0‿1‿1‿1‿1\n"
            "r←0.02 exec.StopLoss pos2‿d\n")

check("StopLoss triggered=1",
    float(sl_n), sl_setup + "•Out •Fmt +´r.triggered",   tol=0.01)
check("StopLoss mean ret",
    sl_ret,      sl_setup + "•Out •Fmt (+´r.ret)÷≠r.ret")

# ══ uni.bqn ══════════════════════════════════════════════════════════════════

# 2-bar × 3-asset matrix
M = np.array([[1.,3.,2.],[5.,1.,4.]])

# XRank row 0: [1,3,2] → double-grade → [0,2,1], element[1] = 2
check("XRank[r0,c1]=2",
    float(np.argsort(np.argsort(M[0]))[1]),
    "uni←•Import\"uni.bqn\"\nm←2‿3⥊1‿3‿2‿5‿1‿4\n•Out •Fmt 1⊑0⊏uni.XRank m",
    tol=0.01)

# XScore row 0 sum ≈ 0 (mean-centered)
xsc = (M - M.mean(1, keepdims=True)) / (M.std(1, keepdims=True) + 1e-10)
check("XScore row0 sum≈0",
    float(xsc[0].sum()),
    "uni←•Import\"uni.bqn\"\nm←2‿3⥊1‿3‿2‿5‿1‿4\n•Out •Fmt +´0⊏uni.XScore m",
    tol=1e-8)

# XWeight row 0 abs-sum = 1
check("XWeight row0 |sum|=1",
    1.0,
    "uni←•Import\"uni.bqn\"\nm←2‿3⥊1‿3‿2‿5‿1‿4\n•Out •Fmt +´|0⊏uni.XWeight m",
    tol=1e-8)

# TopN n=1 row 0: [1,3,2] → long idx1(val=3), short idx0(val=1) → row sum = 0
check("TopN(1) row0 sum=0",
    0.0,
    "uni←•Import\"uni.bqn\"\nm←2‿3⥊1‿3‿2‿5‿1‿4\n•Out •Fmt +´0⊏1 uni.TopN m",
    tol=1e-8)

# LongOnly row 0: [1,3,2] all positive → [1/6, 3/6, 2/6], first element = 1/6
lo0 = np.maximum(M[0], 0); lo0 = lo0 / lo0.sum()
check("LongOnly row0[0]=1/6",
    float(lo0[0]),
    "uni←•Import\"uni.bqn\"\nm←2‿3⥊1‿3‿2‿5‿1‿4\n•Out •Fmt ⊑0⊏uni.LongOnly m",
    tol=1e-6)

# AlignDates: two namespaces of length 7 and 10 → min=7
check("AlignDates min length",
    7.0,
    "bt←•Import\"bt.bqn\"\n"
    "Mk←{n←𝕩 ⋄ p←100+↕n ⋄ {dates⇐•Fmt¨↕n,close⇐p,high⇐p+1,low⇐p-1,open⇐p+0.5,vol⇐1000⥊˜n}}\n"
    "al←bt.AlignDates ⟨Mk 7, Mk 10⟩\n"
    "•Out •Fmt ≠(⊑al).close",
    tol=0.01)

# ══ Print table ═══════════════════════════════════════════════════════════════

W = 30
print()
print(f"  {'Function':<{W}}  {'Python':>12}  {'BQN':>12}  Match")
print(f"  {'─'*(W+32)}")

sections = [
    ("roll.bqn",  ["RSharpe[5] last","RVol[5] last","RBeta[5] last",
                   "Alpha(rf=0)","IR","Drawdowns depth[0]"]),
    ("risk.bqn",  ["VolTarget@bar20","KellyFrac(f=0.5)",
                   "MaxPos cap=1 on ¯2","DDControl zeros≥0"]),
    ("ovf.bqn",   ["PhiInv(0.5)=0","PhiInv(0.975)≈1.96","Phi(PhiInv(0.1))=0.1",
                   f"DSR(SR=0.1,sk=0.5,ku=2,n={n_v})",
                   "HHI([0.01,0.01,0.02])=0.375",
                   "TrialCorrect p=0.001 → 1","TrialCorrect p=0.01  → 1",
                   "TrialCorrect p=0.05  → 0"]),
    ("exec.bqn",  ["Slippage(0→1 entry)","RunOHLC mean return",
                   "StopLoss triggered=1","StopLoss mean ret"]),
    ("uni.bqn",   ["XRank[r0,c1]=2","XScore row0 sum≈0","XWeight row0 |sum|=1",
                   "TopN(1) row0 sum=0","LongOnly row0[0]=1/6",
                   "AlignDates min length"]),
]

row_map = {name: (py_s, bqn_s, ok) for name, py_s, bqn_s, ok in rows}

for mod, names in sections:
    print(f"\n  ── {mod}")
    for name in names:
        py_s, bqn_s, ok = row_map.get(name, ("?","?","?"))
        print(f"  {name:<{W}}  {py_s:>12}  {bqn_s:>12}  {ok}")

print()
n_ok  = sum(1 for *_, ok in rows if ok == "✓")
n_bad = sum(1 for *_, ok in rows if "MISMATCH" in ok)
n_err = sum(1 for *_, ok in rows if ok.startswith("?"))
print(f"  {n_ok}/{len(rows)} match  |  {n_bad} mismatch  |  {n_err} error\n")
