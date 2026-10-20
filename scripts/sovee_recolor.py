"""Recolore cores (hex/rgba) pra paleta SOVEE por família de matiz."""
import colorsys, re, sys

def remap(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r/255, g/255, b/255)
    H = h*360
    if l > 0.97:                                      # branco puro (estrelas, brilhos) -> creme claro
        H, s, l = 52, 0.9, 0.93
    elif s < 0.14 or (l > 0.9 and s < 0.5):           # neutros
        if l > 0.88:   H, s = 46, max(s, 0.62)       # brancos -> creme
        elif l > 0.45: H, s = 32, min(s+0.05, 0.12)  # cinzas claros -> pedra quente
        else:          H, s = 228, min(s, 0.12)       # escuros -> grafite azulado
    elif 185 <= H <= 265 and l > 0.3:                 # azuis claros (Terra, visor) -> azul de luar
        H, s = 215, min(s*0.6, 0.4)
    elif 185 <= H <= 265:                             # céu escuro -> grafite azulado
        H, s = 226, s*0.42
    elif H < 28 or H >= 340:                          # vermelhos -> terracota
        H, s = 22, min(s, 0.66)
    elif H < 62:                                      # laranja/amarelo -> âmbar
        H, s = 33, min(s, 0.86)
    elif 62 <= H < 185:                               # verdes -> sage/floresta
        H, s = 145, s*0.5
    r2, g2, b2 = colorsys.hls_to_rgb(H/360, l, s)
    return round(r2*255), round(g2*255), round(b2*255)

def hexsub(m):
    t = m.group(1)
    if len(t) == 3: t = ''.join(c*2 for c in t)
    r, g, b = (int(t[i:i+2], 16) for i in (0, 2, 4))
    return '#%02x%02x%02x' % remap(r, g, b)

def rgbasub(m):
    r, g, b = (int(x) for x in m.group(2, 3, 4))
    r, g, b = remap(r, g, b)
    return f'{m.group(1)}({r},{g},{b}{m.group(5)})'

def swiftsub(m):
    t = m.group(1)
    r, g, b = (int(t[i:i+2], 16) for i in (0, 2, 4))
    return '0x%02X%02X%02X' % remap(r, g, b)

def recolor(text, swift=False):
    if swift:
        return re.sub(r'0x([0-9A-Fa-f]{6})\b', swiftsub, text)
    text = re.sub(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b(?![0-9a-fA-F])', hexsub, text)
    text = re.sub(r'(rgba?)\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,[^)]*)?\)', lambda m: rgbasub(type('M',(object,),{'group':lambda self,*i: (m.group(*i) if len(i)>1 else (m.group(i[0]) or ''))})()), text)
    return text

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    open(dst, 'w').write(recolor(open(src).read(), swift=src.endswith('.swift')))
