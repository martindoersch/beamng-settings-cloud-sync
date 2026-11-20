# Generates the feature graphic for the repository page: concept tiles instead of a UI mock-up
# (replaces make_app_svg.py, which drew the UI app up to v0.7; see git history)
# Usage: python3 make_features_svg.py v0.8/svg  → v0.8/svg/2_features_en.svg
# PNG: render the SVG at 1920×1080, e.g. Chrome headless (see docs/NOTES.md)
import sys, os, math

FONT = "'Helvetica Neue', Helvetica, Arial, sans-serif"
WHITE, GREY, ORANGE = '#ffffff', '#a9b8c8', '#ff8a3d'
LINE = f'fill="none" stroke="{WHITE}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"'
ACC = f'fill="none" stroke="{ORANGE}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"'
ACC_THIN = ACC.replace('stroke-width="7"', 'stroke-width="5.5"')

def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def text(x, y, s, size, bold=False, fill=WHITE, anchor='start'):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{"bold" if bold else "normal"}" '
            f'fill="{fill}" text-anchor="{anchor}">{esc(s)}</text>')

# Icons, drawn around (0, 0) in a box of about 160×120
def icon_menu():
    return (f'<rect x="-80" y="-56" width="160" height="112" rx="12" {LINE}/>'
            f'<line x1="-80" y1="-24" x2="80" y2="-24" {LINE}/>'
            f'<line x1="-56" y1="4" x2="40" y2="4" {ACC}/>'
            f'<line x1="-56" y1="30" x2="16" y2="30" {LINE} stroke-opacity="0.6"/>'
            + text(-62, -32, 'ESC', 22, True, WHITE))

def monitor(x, y, w, h):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" {LINE}/>'
            f'<line x1="{x + w / 2}" y1="{y + h}" x2="{x + w / 2}" y2="{y + h + 16}" {LINE}/>'
            f'<line x1="{x + w / 2 - 22}" y1="{y + h + 18}" x2="{x + w / 2 + 22}" y2="{y + h + 18}" {LINE}/>')

def icon_profiles():
    return (monitor(-92, -54, 100, 68) + monitor(-4, -24, 100, 68)
            + f'<circle cx="46" cy="10" r="14" {ACC}/>')

def icon_status():
    return (f'<circle cx="-40" cy="0" r="46" {LINE}/>'
            f'<polyline points="-62,0 -46,16 -18,-14" {ACC}/>'
            f'<path d="M 24 -26 L 56 -26 A 28 28 0 0 1 56 30 L 28 30" {LINE}/>'
            f'<polyline points="38,-42 22,-26 38,-10" {LINE}/>')

def arc_arrow(cx, cy, r, a1, a2, style, back=False, L=13, W=11):
    # Arc from angle a1 to a2 (degrees, clockwise on screen) with an arrowhead at the end, or at the start if back
    pt = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x1, y1), (x2, y2) = pt(a1), pt(a2)
    large = 1 if (a2 - a1) % 360 > 180 else 0
    a, sign = (a1, -1) if back else (a2, 1)
    tx, ty = pt(a)
    dx, dy = -math.sin(math.radians(a)) * sign, math.cos(math.radians(a)) * sign  # direction of travel
    head = f'{tx - L * dx + W * dy:.1f},{ty - L * dy - W * dx:.1f} {tx:.1f},{ty:.1f} {tx - L * dx - W * dy:.1f},{ty - L * dy + W * dx:.1f}'
    return (f'<path d="M {x1:.1f} {y1:.1f} A {r} {r} 0 {large} 1 {x2:.1f} {y2:.1f}" {style}/>'
            f'<polyline points="{head}" {style}/>')

def icon_auto():
    cloud = ('M -50 40 A 30 30 0 0 1 -48 -18 A 46 46 0 0 1 38 -30 A 36 36 0 0 1 52 40 Z')
    return ('<g transform="scale(1.2)">'
            f'<path d="{cloud}" {LINE}/>'
            + arc_arrow(2, 6, 23, 215, 325, ACC_THIN, L=9, W=8) + arc_arrow(2, 6, 23, 35, 145, ACC_THIN, L=9, W=8) + '</g>')

def icon_keys():
    keys = ''.join(f'<rect x="{-80 + i * 42}" y="-50" width="34" height="34" rx="6" {LINE}/>' for i in range(4))
    return (keys + f'<rect x="-80" y="-4" width="34" height="34" rx="6" {LINE}/>'
            f'<rect x="-38" y="-4" width="118" height="34" rx="6" {ACC}/>'
            f'<line x1="-60" y1="56" x2="60" y2="56" {LINE} stroke-opacity="0.6"/>')

def icon_history():
    return (arc_arrow(0, 0, 52, 165, 120, LINE, back=True)
            + f'<polyline points="0,-30 0,0 22,14" {ACC}/>')

TILES = [(icon_menu, 'In the pause menu', ['ESC > Mods > Settings Cloud Sync,', 'all options in one place']),
         (icon_auto, 'Auto-import and export', ['Restored at game start, changes', 'saved by themselves']),
         (icon_status, 'Sync status and undo', ['See at a glance if you are in sync;', 'undo puts your old settings back']),
         (icon_profiles, 'Profiles per machine', ['Each PC keeps its own', 'graphics settings']),
         (icon_keys, 'Shared key bindings', ['Same controls in every profile', '']),
         (icon_history, 'Older backups', ['The last three backups per profile,', 'restore any of them'])]

def tile(x, y, w, h, draw, title, lines):
    cx = x + w / 2
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="18" fill="#ffffff" fill-opacity="0.05" '
           f'stroke="#ffffff" stroke-opacity="0.18" stroke-width="2"/>',
           f'<g transform="translate({cx},{y + 120})">{draw()}</g>',
           text(cx, y + 252, title, 40, True, WHITE, 'middle')]
    for i, l in enumerate(lines):
        if l:
            out.append(text(cx, y + 300 + i * 38, l, 28, False, GREY, 'middle'))
    return ''.join(out)

def svg():
    p = ['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">',
         '<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1d3b5c"/>'
         '<stop offset="1" stop-color="#0f1c2b"/></linearGradient></defs>',
         '<rect width="1920" height="1080" fill="url(#bg)"/>',
         text(120, 120, 'Set it up once', 72, True),
         text(120, 176, 'Then it works by itself, on PC and in cloud gaming', 32, False, GREY)]
    w, h, gap = 540, 380, 30
    for i, (draw, title, lines) in enumerate(TILES):
        x, y = 120 + (i % 3) * (w + gap), 240 + (i // 3) * (h + gap)
        p.append(tile(x, y, w, h, draw, title, lines))
    p.append('</svg>')
    return ''.join(p)

outdir = sys.argv[1]
with open(os.path.join(outdir, '2_features_en.svg'), 'w') as f:
    f.write(svg())
