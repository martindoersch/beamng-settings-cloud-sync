# Generates grafik/2_app_{en,de}.svg (v0.5: profiles, history, auto-export, minimize)
import sys, os

FONT = "'Helvetica Neue', Helvetica, Arial, sans-serif"
WHITE, GREY, ACCENT, ORANGE, DARK = '#ffffff', '#a9b8c8', '#5cc8ff', '#ff8a3d', '#0b1220'

def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def text(x, y, s, size, bold=False, fill=WHITE, anchor='start'):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{"bold" if bold else "normal"}" '
            f'fill="{fill}" text-anchor="{anchor}">{esc(s)}</text>')

def checkbox(x, y):
    return (f'<rect x="{x}" y="{y}" width="44" height="44" rx="8" fill="{ACCENT}"/>'
            f'<polyline points="{x+10},{y+22} {x+20},{y+32} {x+36},{y+12}" fill="none" stroke="{DARK}" '
            f'stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')

def button(x, y, w, label):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="56" rx="10" fill="#e8edf2"/>'
            + text(x + w / 2, y + 38, label, 30, True, DARK, 'middle'))

def callout(n, fromY, cy, title, lines):
    out = [f'<polyline points="854,{fromY} 900,{fromY} 930,{cy} 940,{cy}" fill="none" stroke="{ORANGE}" stroke-width="3" stroke-dasharray="8 8"/>',
           f'<circle cx="970" cy="{cy}" r="30" fill="{ORANGE}"/>',
           text(970, cy + 12, str(n), 34, True, WHITE, 'middle'),
           text(1030, cy + 12, title, 40, True)]
    for i, l in enumerate(lines):
        out.append(text(1030, cy + 58 + i * 40, l, 30, False, GREY))
    return ''.join(out)

T = {
    'en': {
        'h1': 'A simple UI app',
        'h2': 'Set it up once – then it works by itself, on PC and in cloud gaming',
        'c': [('Minimize it or use the radial menu', ['Export, import and restore without', 'keeping the app on screen']),
              ('One profile per machine', ['Desktop, laptop, cloud gaming –', 'each keeps its own graphics settings']),
              ('Backup history', ['Your last 3 backups with date and PC –', 'restore one with a click']),
              ('Auto-import and auto-export', ['Restores at game start, saves changes', 'by itself – ideal for cloud gaming'])],
    },
    'de': {
        'h1': 'Eine einfache UI-App',
        'h2': 'Einmal einrichten – dann läuft es von selbst, am PC und beim Cloud-Gaming',
        'c': [('Einklappen oder Radialmenü nutzen', ['Exportieren, importieren, wiederherstellen,', 'ohne dass die App im Bild bleibt']),
              ('Ein Profil pro Rechner', ['Desktop, Laptop, Cloud-Gaming –', 'jeder behält seine eigene Grafik']),
              ('Verlauf der Sicherungen', ['Die letzten 3 Sicherungen mit Datum und PC –', 'per Klick zurückholen']),
              ('Auto-Import und Auto-Export', ['Holt beim Spielstart, sichert Änderungen', 'von selbst – ideal fürs Cloud-Gaming'])],
    },
}

def svg(lang):
    t = T[lang]
    p = ['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">',
         '<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1d3b5c"/>'
         '<stop offset="1" stop-color="#0f1c2b"/></linearGradient></defs>',
         '<rect width="1920" height="1080" fill="url(#bg)"/>',
         text(120, 130, t['h1'], 72, True),
         text(120, 188, t['h2'], 32, False, GREY),
         # App window (the UI stays English in both languages, as in the game)
         '<rect x="120" y="230" width="740" height="800" rx="16" fill="#05080c" fill-opacity="0.8" stroke="#ffffff" stroke-opacity="0.2" stroke-width="2"/>',
         text(152, 292, 'Settings Cloud Sync', 32, True),
         # Minimieren-Button
         '<rect x="776" y="256" width="56" height="48" rx="10" fill="#e8edf2"/>',
         f'<line x1="792" y1="280" x2="816" y2="280" stroke="{DARK}" stroke-width="5" stroke-linecap="round"/>',
         # Profil-Zeile: Auswahl, Eingabefeld, Add
         text(152, 364, 'Profile', 28),
         '<rect x="252" y="330" width="250" height="50" rx="8" fill="#1a2533" stroke="#ffffff" stroke-opacity="0.35" stroke-width="2"/>',
         text(270, 364, 'Boosteroid', 28),
         '<polygon points="470,348 488,348 479,362" fill="#ffffff"/>',
         '<rect x="518" y="330" width="196" height="50" rx="8" fill="#1a2533" stroke="#ffffff" stroke-opacity="0.2" stroke-width="2"/>',
         text(534, 364, 'new profile', 26, False, '#6b7a8c'),
         '<rect x="728" y="330" width="100" height="50" rx="10" fill="#e8edf2"/>',
         text(778, 365, 'Add', 28, True, DARK, 'middle'),
         text(152, 412, 'e.g. one per PC; only this machine switches', 24, False, GREY),
         '<line x1="152" y1="434" x2="828" y2="434" stroke="#ffffff" stroke-opacity="0.15" stroke-width="2"/>',
         checkbox(152, 452), text(216, 486, 'Controls & key bindings', 28),
         text(216, 522, '1 file, 2026-11-09 21:15', 24, False, GREY),
         checkbox(152, 544), text(216, 578, 'Other settings (graphics, UI layouts etc.)', 28),
         text(216, 614, '8 files, 2026-11-09 21:15', 24, False, GREY),
         button(152, 636, 192, 'Export'), button(364, 636, 192, 'Import'),
         # Current backup and history
         text(152, 734, 'Current: 2026-11-09 21:15 · Boosteroid PC (9 files)', 24, False, GREY),
         text(152, 794, 'Older', 28),
         '<rect x="236" y="760" width="420" height="50" rx="8" fill="#1a2533" stroke="#ffffff" stroke-opacity="0.35" stroke-width="2"/>',
         text(252, 793, '2026-11-09 19:49 · unknown PC', 24),
         '<polygon points="626,778 644,778 635,792" fill="#ffffff"/>',
         '<rect x="672" y="760" width="156" height="50" rx="10" fill="#e8edf2"/>',
         text(750, 795, 'Restore', 28, True, DARK, 'middle'),
         '<line x1="152" y1="832" x2="828" y2="832" stroke="#ffffff" stroke-opacity="0.15" stroke-width="2"/>',
         checkbox(152, 850), text(216, 884, 'Auto-import at game start', 28),
         text(216, 918, 'when the cloud backup is newer', 24, False, GREY),
         checkbox(152, 940), text(216, 974, 'Auto-export changes', 28),
         text(216, 1008, 'saves within a minute, after an import or export', 24, False, GREY),
         ]
    rows = [(280, 300), (355, 480), (785, 660), (930, 840)]
    for i, ((fromY, cy), (title, lines)) in enumerate(zip(rows, t['c']), 1):
        p.append(callout(i, fromY, cy, title, lines))
    p.append('</svg>')
    return ''.join(p)

outdir = sys.argv[1]
for lang in ('en', 'de'):
    with open(os.path.join(outdir, f'2_app_{lang}.svg'), 'w') as f:
        f.write(svg(lang))
