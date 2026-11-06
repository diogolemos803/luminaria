# Adendo ao protocolo v2 da lâmpada sovee (2026-11-06)

Texto pra colar na conversa do firmware. Complementa a proposta v2 de 2026-10-18
(rotina de uma vez só, 0x07 apagar devagar, ROUTINE de 12 bytes). Byte 0 do STATE
continua = 2.

## 1. Opcode 0x08 — apagar programado (9 bytes depois do opcode)

`0x08 espera rampa mantém de_âmbar de_vermelho de_brilho para_âmbar para_vermelho para_brilho`

- `espera` 0–120 min: a lâmpada não mexe na luz que estiver durante esse tempo.
- `rampa` 1–120 min: mistura e brilho vão em linha reta de "de" até "para", igual à rotina
  da manhã (cores no brilho máximo, brilho em byte separado; saída = cor interpolada ×
  brilho interpolado; limitador de 160% depois).
- `mantém` 0–240 min: fica em "para" esse tempo e então apaga. Com `para_brilho = 0` já
  termina apagada (ignora `mantém`).
- Fora da faixa → byte 11 do STATE = 3 (fora da faixa), nada muda.
- STATE modo 3 (apagando) durante a espera e a rampa.
- Cancelam: toque, 0x01, 0x02, 0x07, 0x09. Um 0x08 novo substitui o anterior.

A fórmula de referência está em `Luminaria/LampProtocol.swift` → `LampSunset.output`.

## 2. Opcode 0x09 — cenário animado (TESTE, 2 bytes depois do opcode)

`0x09 cenário brilho`

- `cenário`: 1 = fogueira, 2 = vela, 3 = brasa, 4 = entardecer. Outro valor → STATE byte
  11 = 3.
- `brilho` 1–255: escala o cenário inteiro (0 → recusado).
- A lâmpada anima sozinha, a ~50 Hz, sem depender do celular (continua com o app fechado).
- STATE modo 4 (cenário). A cor no STATE é a do instante (notificar ~1 s, como sempre).
- Cancelam: toque, 0x01, 0x02, 0x07, 0x08. Um 0x09 novo troca o cenário (recomeça o
  tempo do zero).

### Fórmulas (portar exatamente; `t` = segundos desde o comando, em float)

Ruído de valor 1D, determinístico:

```
hash(i, seed):  // i inteiro (32 bits), seed uint32 → 0..1
  x = uint32(i) * 0x9E3779B1 + seed * 0x85EBCA6B   (aritmética de 32 bits com estouro)
  x ^= x >> 15;  x *= 0x2C1B3C6D
  x ^= x >> 12;  x *= 0x297A2D39
  x ^= x >> 15
  return x / 4294967295.0

noise(x, seed):
  i = floor(x); f = x - i; u = f*f*(3 - 2*f)
  a = hash(i, seed); b = hash(i + 1, seed)
  return a + (b - a) * u
```

Cada cenário dá (mistura 0 = amarelo … 1 = vermelho, brilho 0–1). Depois:
`cor = cor_cheia(mistura) × brilho × (brilho_do_comando / 255)`, limitador depois —
mesma "cor cheia" do app (canal maior em 255, soma ≤ 408).

```
fogueira:
  slow = noise(t*0.23, 11); mid = noise(t*1.6, 23); fast = noise(t*8.5, 37)
  b = 0.42 + 0.30*mid + 0.14*fast + 0.14*slow
  pop = noise(t*0.9, 51);    if pop > 0.82: b += (pop - 0.82) * 1.6
  shadow = noise(t*0.7, 67); if shadow < 0.14: b -= (0.14 - shadow) * 1.8
  b = clamp(b, 0.18, 1)
  mix = clamp(0.62 - 0.38*b + 0.06*(fast - 0.5), 0.12, 0.85)

vela:
  mid = noise(t*1.9, 71); fast = noise(t*6.5, 83)
  b = clamp(0.78 + 0.12*(mid - 0.5) + 0.07*(fast - 0.5), 0.55, 0.95)
  mix = clamp(0.10 + 0.08*noise(t*0.4, 97), 0, 0.3)

brasa:
  breath = 0.5 + 0.5*sin(2π t / 7.5)
  b = clamp(0.22 + 0.30*breath + 0.10*(noise(t*0.9, 101) - 0.5), 0.12, 0.7)
  mix = clamp(0.82 + 0.12*(noise(t*0.3, 113) - 0.5), 0.6, 1)

entardecer:
  mix = clamp(0.15 + 0.7*noise(t*0.035, 127), 0, 1)
  b = clamp(0.55 + 0.3*noise(t*0.05, 131), 0.3, 0.9)
```

Referência viva: `Luminaria/LampScenes.swift` (o app e a lâmpada simulada usam essas
mesmas funções; os testes garantem que não há saltos entre quadros de 20 ms).

## 3. STATE

- Modo 3 = apagando (0x07 e 0x08). Modo 4 = cenário (novo).
