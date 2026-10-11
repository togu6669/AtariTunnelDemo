#!/usr/bin/env python3
"""
gen_mod.py — ProTracker .mod generator: C64-disco style (JCH/DRAX/Laxity)
D minor, 150 BPM, speed 6 → 10 rows/s → 6.4 s/pattern × 14 = ~90 s.
Run:  python gen_mod.py
Output: build/music.mod
"""
import struct, math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'music.mod')

# ── Period table (ProTracker, finetune 0) ────────────────────────────────────
PT = {
    'C1':856,'Cs1':808,'D1':762,'Ds1':720,'E1':678,'F1':640,
    'Fs1':604,'G1':570,'Gs1':538,'A1':508,'As1':480,'B1':453,
    'C2':428,'Cs2':404,'D2':381,'Ds2':360,'E2':339,'F2':320,
    'Fs2':302,'G2':285,'Gs2':269,'A2':254,'As2':240,'B2':226,
    'C3':214,'Cs3':202,'D3':190,'Ds3':180,'E3':170,'F3':160,
    'Fs3':151,'G3':143,'Gs3':135,'A3':127,'As3':120,'B3':113,
    'C4':107,'Cs4':101,'D4':95,
}

# ── Waveform generators (returns bytes, 8-bit two's complement) ───────────────
def s8(v): return int(max(-128, min(127, v))) & 0xFF

def sawtooth(n=128):
    return bytes(s8((i / n) * 256 - 128) for i in range(n))

def square(n=128, duty=0.5):
    return bytes(s8(100 if i < n * duty else -100) for i in range(n))

def stab_wave(n=256):
    out = []
    for i in range(n):
        t = i / n
        v = (math.sin(2*math.pi*t)  * 0.50 +
             math.sin(4*math.pi*t)  * 0.30 +
             math.sin(6*math.pi*t)  * 0.12 +
             math.sin(8*math.pi*t)  * 0.08) * math.exp(-5*t) * 100
        out.append(s8(v))
    return bytes(out)

def kick_wave(n=512):
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += (14 * math.exp(-12*t) + 1.5) / n
        out.append(s8(math.sin(2*math.pi*phase) * math.exp(-6*t) * 110))
    return bytes(out)

def hihat_wave(n=64):
    r, out = 0xACE1, []
    for _ in range(n):
        r = ((r >> 1) ^ (0xB400 if r & 1 else 0)) & 0xFFFF
        out.append(s8((r & 0xFF) - 128))
    return bytes(out)

# ── MOD binary helpers ───────────────────────────────────────────────────────
def cell(samp=0, period=0, eff=0, par=0):
    """Encode one 4-byte ProTracker note cell."""
    sh, sl = (samp >> 4) & 0xF, samp & 0xF
    ph, pl = (period >> 8) & 0xF, period & 0xFF
    return bytes([(sh << 4) | ph, pl, (sl << 4) | (eff & 0xF), par & 0xFF])

def samp_hdr(name, data, vol, looping, finetune=0):
    """30-byte sample header."""
    nb    = name.encode()[:22].ljust(22, b'\x00')
    words = len(data) // 2
    ls, ll = (0, words) if looping else (0, 1)
    return nb + struct.pack('>HBBHH', words, finetune & 0xF, vol, ls, ll)

def ch_cells(notes):
    """notes: {row_index: 4-byte cell}.  Returns 256-byte flat channel."""
    out = bytearray(256)
    for row, c in notes.items():
        out[row*4:row*4+4] = c
    return bytes(out)

def pattern(ch0, ch1, ch2, ch3):
    """Interleave 4 channels (256 bytes each) → 1024-byte pattern."""
    data = bytearray()
    for r in range(64):
        for ch in (ch0, ch1, ch2, ch3):
            data += ch[r*4:r*4+4]
    return bytes(data)

# ── Sample IDs (1-based) ─────────────────────────────────────────────────────
BASS, LEAD, STAB, KICK, HAT = 1, 2, 3, 4, 5

def N(s, n, ef=0, pr=0): return cell(s, PT[n], ef, pr)   # note
def FX(ef, pr):           return cell(0, 0, ef, pr)        # effect only

# ── Bass lines (16 entries = 1 bar; None = silent row) ───────────────────────
BA = [PT['D2'],None,PT['D2'],None,PT['F2'],None,PT['F2'],None,
      PT['A2'],None,PT['A2'],None,PT['G2'],None,PT['F2'],None]
BB = [PT['D2'],None,PT['D2'],None,PT['F2'],None,PT['F2'],None,
      PT['G2'],None,PT['G2'],None,PT['A2'],None,PT['A2'],None]
BC = [PT['As2'],None,PT['As2'],None,PT['G2'],None,PT['G2'],None,
      PT['F2'],None,PT['F2'],None,PT['G2'],None,PT['A2'],None]
BD = [PT['D2'],None,PT['D2'],None,PT['A1'],None,PT['A1'],None,
      PT['D2'],None,PT['D2'],None,PT['C2'],None,PT['D2'],None]

def bass_ch(m0, m1, m2, m3):
    d = {}
    for bar, motif in enumerate((m0, m1, m2, m3)):
        for i, p in enumerate(motif):
            if p is not None:
                d[bar*16 + i] = cell(BASS, p)
    return ch_cells(d)

# ── Lead phrases ({row: cell}, 32 rows = 2 bars each) ────────────────────────
LA = {0:N(LEAD,'D3'), 4:N(LEAD,'F3'), 8:N(LEAD,'G3'),12:N(LEAD,'A3'),
     16:N(LEAD,'G3'),20:N(LEAD,'F3'),24:N(LEAD,'E3'),28:N(LEAD,'D3')}
LB = {0:N(LEAD,'A3'), 4:N(LEAD,'As3'),6:N(LEAD,'A3'),10:N(LEAD,'G3'),
     14:N(LEAD,'F3'),18:N(LEAD,'G3'),22:N(LEAD,'A3'),28:N(LEAD,'D3')}
LC = {0:N(LEAD,'F3'), 4:N(LEAD,'G3'), 8:N(LEAD,'A3'),12:N(LEAD,'C4'),
     16:N(LEAD,'As3'),20:N(LEAD,'A3'),24:N(LEAD,'G3'),28:N(LEAD,'F3')}
LD = {0:N(LEAD,'G3'), 4:N(LEAD,'A3'), 8:N(LEAD,'D3'),14:N(LEAD,'F3'),
     18:N(LEAD,'G3'),24:N(LEAD,'A3'),28:N(LEAD,'G3')}
LE = {0:N(LEAD,'D3'),16:N(LEAD,'A3')}   # sparse breakdown

def lead_ch(pa, pb):
    d = dict(pa)
    d.update({r+32: c for r, c in pb.items()})
    return ch_cells(d)

# ── Stab channels ─────────────────────────────────────────────────────────────
def stab_ch(rows, note='F2'):
    return ch_cells({r: N(STAB, note) for r in rows})

S_STD  = [8, 24, 40, 56]              # beats 2 and 4
S_PUSH = [10, 26, 42, 58]             # pushed off-beat
S_DENS = [8, 14, 24, 30, 40, 46, 56, 62]  # dense build

# ── Drum channels ─────────────────────────────────────────────────────────────
K14  = {0,8,16,24,32,40,48,56}        # kick on beats 1 and 3
KVAR = {0,8,20,32,40,52}              # syncopated variation
H4   = set(range(0, 64, 4))           # quarter-note hats
H8   = set(range(0, 64, 2))           # 8th-note hats

def drum_ch(kicks, hats):
    d = {}
    for r in kicks:       d[r] = cell(KICK, PT['A2'])
    for r in hats-kicks:  d[r] = cell(HAT,  PT['A3'])
    return ch_cells(d)

# ── Pattern builders ──────────────────────────────────────────────────────────
def p0_intro():
    # speed=6 in lead ch row 0, BPM=150 in stab ch row 0
    ld = ch_cells({0: FX(0xF,   6)})
    st = ch_cells({0: FX(0xF, 150)})
    return pattern(bass_ch(BA,BA,BB,BB), ld, st, drum_ch(K14, H4))

def p1_main_a():
    return pattern(bass_ch(BA,BA,BB,BD), lead_ch(LA,LB),
                   stab_ch(S_STD),       drum_ch(K14,  H8))

def p2_main_b():
    return pattern(bass_ch(BB,BB,BC,BD), lead_ch(LC,LD),
                   stab_ch(S_PUSH,'As2'), drum_ch(KVAR, H8))

def p3_build():
    return pattern(bass_ch(BA,BC,BB,BD), ch_cells({}),
                   stab_ch(S_DENS,'G2'), drum_ch(K14,  H8))

def p4_breakdown():
    return pattern(bass_ch(BD,BD,BA,BA), lead_ch(LE,LE),
                   ch_cells({}),          drum_ch({0,32}, H4))

def p5_outro():
    return pattern(bass_ch(BA,BB,BA,BA), lead_ch(LA,LB),
                   stab_ch(S_STD),        drum_ch(K14,  H4))

# ── Song arrangement  (14 patterns × 6.4 s ≈ 89.6 s) ────────────────────────
ORDER    = [0,0, 1,1, 2,1, 3,3, 1,2, 1,4, 5,5]
PATTERNS = [p0_intro(), p1_main_a(), p2_main_b(),
            p3_build(),  p4_breakdown(), p5_outro()]

# ── Sample table  (name, pcm-bytes, volume, looping) ─────────────────────────
SAMPLES = [
    ('bass saw',  sawtooth(128),  64, True),
    ('lead sqr',  square(128),    52, True),
    ('stab org',  stab_wave(256), 56, False),
    ('kick drm',  kick_wave(512), 64, False),
    ('hihat nse', hihat_wave(64), 40, False),
]

# ── Write MOD ─────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'wb') as f:
    f.write(b'C64 Disco Ride      ')               # 20-byte title
    for name, data, vol, loop in SAMPLES:
        f.write(samp_hdr(name, data, vol, loop))
    for _ in range(31 - len(SAMPLES)):
        f.write(b'\x00' * 30)                      # pad to 31 sample slots
    f.write(bytes([len(ORDER), 0x7F]))              # song length, restart pos
    f.write(bytes(ORDER + [0] * (128 - len(ORDER))))  # 128-byte order table
    f.write(b'M.K.')                               # 4-channel marker
    for pat in PATTERNS:
        f.write(pat)
    for _, data, *_ in SAMPLES:
        f.write(data)

sz = os.path.getsize(OUT)
print(f'Wrote {OUT}')
print(f'  {sz} bytes | {len(PATTERNS)} unique patterns | {len(ORDER)} in order '
      f'| {len(ORDER)*6.4:.0f} s @ 150 BPM speed 6')
