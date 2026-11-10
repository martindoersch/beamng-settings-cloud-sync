# Generates the app graphic for the repository page (v0.6: pause menu, profiles, sync status, undo, shared key bindings, restore mods)
# Usage: python3 make_app_svg.py v0.6/svg  → v0.6/svg/2_app_en.svg; earlier versions are in git history
# PNG: render the SVG at 1920×1080, e.g. Chrome headless (see docs/NOTES.md)
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

C = [('Pause menu, app or radial menu', ['ESC > Mods > Settings Cloud Sync –', 'the UI app is optional']),
     ('Profiles per machine', ['Add, rename, delete – each machine', 'keeps its own graphics settings']),
     ('Sync status and undo', ['Green means it is in the cloud backup;', 'undo puts your old settings back']),
     ('Shared key bindings, auto-sync', ['Same controls in every profile,', 'restored and saved by itself']),
     ('Restore your mods', ['One click subscribes your repository', 'mods again in a fresh cloud session'])]

def small_button(x, y, w, label):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="48" rx="10" fill="#e8edf2"/>'
            + text(x + w / 2, y + 33, label, 26, True, DARK, 'middle'))

def svg():
    p = ['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">',
         '<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1d3b5c"/>'
         '<stop offset="1" stop-color="#0f1c2b"/></linearGradient></defs>',
         '<rect width="1920" height="1080" fill="url(#bg)"/>',
         text(120, 120, 'Pause menu or UI app', 72, True),
         text(120, 176, 'Set it up once – then it works by itself, on PC and in cloud gaming', 32, False, GREY),
         # App window (the UI is English, as in the game)
         '<rect x="120" y="214" width="740" height="846" rx="16" fill="#05080c" fill-opacity="0.8" stroke="#ffffff" stroke-opacity="0.2" stroke-width="2"/>',
         text(152, 274, 'Settings Cloud Sync', 32, True), text(472, 274, 'v0.6', 22, False, GREY),
         '<rect x="776" y="238" width="56" height="48" rx="10" fill="#e8edf2"/>',
         f'<line x1="792" y1="262" x2="816" y2="262" stroke="{DARK}" stroke-width="5" stroke-linecap="round"/>',
         # Profile row: selection, Add, Rename, Delete
         text(152, 342, 'Profile', 28),
         '<rect x="252" y="308" width="210" height="50" rx="8" fill="#1a2533" stroke="#ffffff" stroke-opacity="0.35" stroke-width="2"/>',
         text(268, 342, 'Boosteroid', 28),
         '<polygon points="432,326 450,326 441,340" fill="#ffffff"/>',
         small_button(476, 309, 90, 'Add'), small_button(578, 309, 126, 'Rename'), small_button(716, 309, 112, 'Delete'),
         '<line x1="152" y1="380" x2="828" y2="380" stroke="#ffffff" stroke-opacity="0.15" stroke-width="2"/>',
         checkbox(152, 396), text(216, 430, 'Controls & key bindings', 28),
         text(216, 464, 'shared by all profiles, 1 file, 2026-11-10 20:15', 24, False, GREY),
         checkbox(152, 482), text(216, 516, 'Other settings (graphics, UI layouts etc.)', 28),
         text(216, 550, '8 files, 2026-11-10 20:15', 24, False, GREY),
         button(152, 572, 170, 'Export'), button(338, 572, 170, 'Import'), button(524, 572, 230, 'Undo import'),
         # Sync status, current backup and history
         text(152, 672, '✔ In sync with the cloud backup', 28, True, '#a5d6a7'),
         text(152, 710, 'Current: 2026-11-10 20:15 · Boosteroid PC (9 files)', 24, False, GREY),
         text(152, 764, 'Older', 28),
         '<rect x="236" y="730" width="420" height="50" rx="8" fill="#1a2533" stroke="#ffffff" stroke-opacity="0.35" stroke-width="2"/>',
         text(252, 763, '2026-11-09 19:49 · unknown PC', 24),
         '<polygon points="626,748 644,748 635,762" fill="#ffffff"/>',
         '<rect x="672" y="730" width="156" height="50" rx="10" fill="#e8edf2"/>',
         text(750, 765, 'Restore', 28, True, DARK, 'middle'),
         '<line x1="152" y1="800" x2="828" y2="800" stroke="#ffffff" stroke-opacity="0.15" stroke-width="2"/>',
         checkbox(152, 816), text(216, 850, 'Auto-import at game start', 28),
         checkbox(152, 870), text(216, 904, 'Auto-export changes', 28),
         checkbox(152, 924), text(216, 958, 'Share key bindings across profiles', 28),
         button(152, 984, 330, 'Restore mods (4)'),
         ]
    rows = [(262, 290), (333, 448), (660, 606), (900, 764), (1012, 922)]
    for i, ((fromY, cy), (title, lines)) in enumerate(zip(rows, C), 1):
        p.append(callout(i, fromY, cy, title, lines))
    p.append('</svg>')
    return ''.join(p)

outdir = sys.argv[1]
with open(os.path.join(outdir, '2_app_en.svg'), 'w') as f:
    f.write(svg())
