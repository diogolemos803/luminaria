/*
 * Zleepy Lamp — firmware do protótipo eletrônico
 * Arduino Nano (ATmega328P, clone CH340)
 *
 * Um toque no sensor capacitivo avança um ciclo de estados:
 *   DESLIGADO -> AMBAR -> LARANJA -> LARANJA2 -> VERMELHO -> DESLIGADO -> ...
 * (LARANJA e LARANJA2 são dois pontos intermediários de mistura âmbar+vermelho,
 * o segundo mais próximo do VERMELHO puro.)
 * Cada transição é um crossfade suave (nunca um salto seco de brilho).
 * Depois de chegar em VERMELHO, se ninguém tocar em TEMPO_AUTO_OFF_MS, a luz
 * apaga sozinha (fade out) — a luminária "acompanha" a pessoa até ela dormir.
 *
 * Sem bibliotecas externas: só Arduino.h. Sem delay() no loop principal —
 * tudo baseado em millis() pra manter o toque sempre responsivo durante os fades.
 */

// ======================= CONFIGURAÇÃO (ajuste aqui) =======================

// --- Pinos ---
const uint8_t PIN_PWM_AMBAR    = 9;   // Timer1, PWM por hardware -> canal L1 do D4184 (fita âmbar)
const uint8_t PIN_PWM_VERMELHO = 10;  // Timer1, PWM por hardware -> canal L2 do D4184 (fita vermelha)
const uint8_t PIN_TOUCH        = 2;   // Saída digital do TTP223 -> INT0

// --- Brilhos por estado (0-255), definidos independentemente por estado ---
// Estado ÂMBAR (passo 1): mantido como estava.
const uint8_t BRILHO_AMBAR_ESTADO1 = 200;  // canal âmbar no estado ÂMBAR puro

// Estado LARANJA (passo 2): a fita vermelha é opticamente mais forte que a
// âmbar no mesmo PWM — em 50% ela dominava a mistura e o resultado ficava rosa
// em vez de laranja. Por isso o vermelho aqui fica bem mais baixo que o âmbar,
// não numa proporção 1:1. Ponto de partida pra calibrar na bancada: se ainda
// ficar rosado, baixe mais (ex: 15-20%); se ficar só âmbar sem nenhum tom
// alaranjado visível, suba um pouco.
const uint8_t BRILHO_AMBAR_ESTADO2    = 190;
const uint8_t BRILHO_VERMELHO_ESTADO2 = 64;  // 25% de intensidade (255 * 0.25, arredondado)

// Estado LARANJA2 (passo 3, novo): ponto intermediário entre LARANJA e VERMELHO,
// com o vermelho já mais presente na mistura.
const uint8_t BRILHO_AMBAR_ESTADO3    = 140; // âmbar reduzido em relação ao LARANJA
const uint8_t BRILHO_VERMELHO_ESTADO3 = 120; // vermelho mais presente que no LARANJA

// Estado VERMELHO (passo 4): vermelho puro.
const uint8_t BRILHO_VERMELHO_ESTADO4 = 70;

// --- Tempos de transição/timers ---
const uint16_t TEMPO_FADE_MS       = 750;        // duração do crossfade entre estados (600-900ms pedido)
const uint32_t TEMPO_AUTO_OFF_MS   = 45UL * 60UL * 1000UL; // 45 minutos parado em VERMELHO -> apaga sozinho
const uint16_t TEMPO_DEBOUNCE_MS   = 300;        // ignora novos toques por esse tempo após um toque válido

// --- Serial (debug de bancada) ---
const uint32_t SERIAL_BAUD = 9600;

// ======================= MÁQUINA DE ESTADOS =======================

enum EstadoLuz {
  ESTADO_DESLIGADO = 0,
  ESTADO_AMBAR,
  ESTADO_LARANJA,
  ESTADO_LARANJA2,
  ESTADO_VERMELHO
};

EstadoLuz estadoAtual = ESTADO_DESLIGADO;

// Brilho-alvo (0-255) de cada canal para cada estado da máquina — cada estado
// tem seus próprios valores independentes (ver constantes BRILHO_*_ESTADO* acima).
void brilhoAlvoParaEstado(EstadoLuz estado, uint8_t &alvoAmbar, uint8_t &alvoVermelho) {
  switch (estado) {
    case ESTADO_DESLIGADO:
      alvoAmbar = 0;
      alvoVermelho = 0;
      break;
    case ESTADO_AMBAR:
      alvoAmbar = BRILHO_AMBAR_ESTADO1;
      alvoVermelho = 0;
      break;
    case ESTADO_LARANJA:
      alvoAmbar = BRILHO_AMBAR_ESTADO2;
      alvoVermelho = BRILHO_VERMELHO_ESTADO2;
      break;
    case ESTADO_LARANJA2:
      alvoAmbar = BRILHO_AMBAR_ESTADO3;
      alvoVermelho = BRILHO_VERMELHO_ESTADO3;
      break;
    case ESTADO_VERMELHO:
      alvoAmbar = 0;
      alvoVermelho = BRILHO_VERMELHO_ESTADO4;
      break;
  }
}

const char *nomeEstado(EstadoLuz estado) {
  switch (estado) {
    case ESTADO_DESLIGADO: return "DESLIGADO";
    case ESTADO_AMBAR:     return "AMBAR";
    case ESTADO_LARANJA:   return "LARANJA";
    case ESTADO_LARANJA2:  return "LARANJA2";
    case ESTADO_VERMELHO:  return "VERMELHO";
  }
  return "?";
}

// ======================= ESTADO DO FADE (crossfade não-bloqueante) =======================

bool emFade = false;              // true enquanto uma transição de crossfade está em andamento
uint32_t fadeInicioMs = 0;        // millis() em que o fade atual começou

// Brilho de cada canal no instante em que o fade começou (ponto de partida da interpolação).
// Começar do brilho REAL atual (não do alvo do estado anterior) garante que um toque no meio
// de um fade em andamento já reage imediatamente, sem esperar o fade anterior terminar.
uint8_t fadeOrigemAmbar = 0;
uint8_t fadeOrigemVermelho = 0;

// Brilho-alvo do canal para o novo estado (ponto de chegada da interpolação).
uint8_t fadeAlvoAmbar = 0;
uint8_t fadeAlvoVermelho = 0;

// Brilho atualmente aplicado nos pinos PWM — fonte da verdade do "onde a luz está agora",
// usada como origem se um novo toque interromper um fade em andamento.
uint8_t brilhoAtualAmbar = 0;
uint8_t brilhoAtualVermelho = 0;

// Interpola linearmente entre origem e alvo com base no tempo decorrido do fade.
uint8_t interpola(uint8_t origem, uint8_t alvo, float progresso) {
  float valor = origem + (float)((int)alvo - (int)origem) * progresso;
  if (valor < 0) valor = 0;
  if (valor > 255) valor = 255;
  return (uint8_t)(valor + 0.5f);
}

// Inicia (ou reinicia) um crossfade rumo ao estado informado, partindo do brilho real atual.
void iniciarFadeParaEstado(EstadoLuz novoEstado) {
  brilhoAlvoParaEstado(novoEstado, fadeAlvoAmbar, fadeAlvoVermelho);

  fadeOrigemAmbar = brilhoAtualAmbar;
  fadeOrigemVermelho = brilhoAtualVermelho;

  fadeInicioMs = millis();
  emFade = true;
}

// Deve ser chamada a cada loop() — avança o crossfade em andamento sem bloquear.
void atualizarFade() {
  if (!emFade) return;

  uint32_t decorrido = millis() - fadeInicioMs;

  if (decorrido >= TEMPO_FADE_MS) {
    // Fade concluído: crava exatamente no alvo, sem erro de arredondamento.
    brilhoAtualAmbar = fadeAlvoAmbar;
    brilhoAtualVermelho = fadeAlvoVermelho;
    emFade = false;
  } else {
    float progresso = (float)decorrido / (float)TEMPO_FADE_MS;
    brilhoAtualAmbar = interpola(fadeOrigemAmbar, fadeAlvoAmbar, progresso);
    brilhoAtualVermelho = interpola(fadeOrigemVermelho, fadeAlvoVermelho, progresso);
  }

  analogWrite(PIN_PWM_AMBAR, brilhoAtualAmbar);
  analogWrite(PIN_PWM_VERMELHO, brilhoAtualVermelho);
}

// ======================= TOUCH (debounce por tempo + borda de subida) =======================

bool touchEstadoAnterior = LOW;   // último nível lido do TTP223, pra detectar borda de subida
uint32_t ultimoToqueValidoMs = 0; // millis() do último toque aceito, base do debounce

// Retorna true no instante em que um toque NOVO e válido é detectado (uma única vez por toque).
bool lerToqueValido() {
  bool leituraAtual = digitalRead(PIN_TOUCH);
  bool bordaDeSubida = (leituraAtual == HIGH && touchEstadoAnterior == LOW);
  touchEstadoAnterior = leituraAtual;

  if (!bordaDeSubida) return false;

  uint32_t agora = millis();
  if (agora - ultimoToqueValidoMs < TEMPO_DEBOUNCE_MS) {
    // Toque ignorado: ainda dentro da janela de debounce do toque anterior.
    return false;
  }

  ultimoToqueValidoMs = agora;
  return true;
}

// ======================= AUTO-OFF =======================

uint32_t vermelhoDesdeMs = 0;    // millis() em que o estado VERMELHO foi atingido
bool contandoAutoOff = false;    // true enquanto o cronômetro de auto-off está rodando

void iniciarContagemAutoOff() {
  vermelhoDesdeMs = millis();
  contandoAutoOff = true;
}

void pararContagemAutoOff() {
  contandoAutoOff = false;
}

void verificarAutoOff() {
  if (!contandoAutoOff) return;
  if (millis() - vermelhoDesdeMs < TEMPO_AUTO_OFF_MS) return;

  contandoAutoOff = false;
  Serial.println(F("Auto-off: 45 min sem toque em VERMELHO, apagando sozinho."));
  estadoAtual = ESTADO_DESLIGADO;
  iniciarFadeParaEstado(estadoAtual);
}

// ======================= AVANÇO DE ESTADO =======================

void avancarEstado() {
  switch (estadoAtual) {
    case ESTADO_DESLIGADO: estadoAtual = ESTADO_AMBAR;     break;
    case ESTADO_AMBAR:     estadoAtual = ESTADO_LARANJA;   break;
    case ESTADO_LARANJA:   estadoAtual = ESTADO_LARANJA2;  break;
    case ESTADO_LARANJA2:  estadoAtual = ESTADO_VERMELHO;  break;
    case ESTADO_VERMELHO:  estadoAtual = ESTADO_DESLIGADO; break;
  }

  Serial.print(F("Toque detectado -> novo estado: "));
  Serial.println(nomeEstado(estadoAtual));

  // O fade começa imediatamente ao detectar o toque: feedback tátil-visual instantâneo.
  iniciarFadeParaEstado(estadoAtual);

  // O cronômetro de auto-off só corre enquanto a luz está parada em VERMELHO;
  // qualquer outro estado zera/desliga a contagem.
  if (estadoAtual == ESTADO_VERMELHO) {
    iniciarContagemAutoOff();
  } else {
    pararContagemAutoOff();
  }
}

// ======================= SETUP / LOOP =======================

void setup() {
  pinMode(PIN_PWM_AMBAR, OUTPUT);
  pinMode(PIN_PWM_VERMELHO, OUTPUT);
  pinMode(PIN_TOUCH, INPUT);

  analogWrite(PIN_PWM_AMBAR, 0);
  analogWrite(PIN_PWM_VERMELHO, 0);

  Serial.begin(SERIAL_BAUD);
  Serial.println(F("Zleepy Lamp — firmware iniciado."));
  Serial.println(F("Estado inicial: DESLIGADO"));
}

void loop() {
  if (lerToqueValido()) {
    avancarEstado();
  }

  atualizarFade();
  verificarAutoOff();
}
