import Foundation

// CENÁRIOS DA LÂMPADA — MODO TESTE (2026-11-06, pedido do dono: "algo como a Philips Hue
// faz com os cenários", começando pela fogueira). Só bytes e contas, sem SwiftUI.
//
// Quem anima é a própria lâmpada (comando 0x09), não o celular: assim a luz continua fluida
// com a tela bloqueada ou o app fechado, como os cenários dinâmicos da Hue. As fórmulas
// abaixo são a REFERÊNCIA pro firmware — a lâmpada simulada e a prévia da tela usam
// exatamente estas funções, então o que se vê no app é o que a lâmpada deve fazer.
//
// Só existem as fitas âmbar e vermelha: os cenários vivem no espectro amarelo → vermelho
// (fogo, vela, brasa, entardecer). Pra tirar o teste: apagar este arquivo, o link em
// Packages/SoveeCore, os testes `LampSceneTests`, o caso `.scenes` em `LampView` e o
// `.scene` do `LampManager`/simulada.

enum LampScenesFlag {
    static let key = "com.luminaria.experiment.lampScenes"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: key) }
}

enum LampScene: UInt8, CaseIterable, Identifiable {
    case fogueira = 1
    case vela = 2
    case brasa = 3
    case entardecer = 4

    var id: UInt8 { rawValue }

    var name: String {
        switch self {
        case .fogueira: return "Fogueira"
        case .vela: return "Vela"
        case .brasa: return "Brasa"
        case .entardecer: return "Entardecer"
        }
    }

    var symbol: String {
        switch self {
        case .fogueira: return "flame.fill"
        case .vela: return "flame"
        case .brasa: return "circle.hexagongrid.fill"
        case .entardecer: return "sunset.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .fogueira: return "Chama viva, laranja com estalos"
        case .vela: return "Amarela, quase parada, tremendo de leve"
        case .brasa: return "Vermelha, respirando devagar"
        case .entardecer: return "Passeia entre amarelo e vermelho, bem lento"
        }
    }

    /// (mistura 0 = amarelo … 1 = vermelho, brilho 0–1) no instante `t` (segundos desde o
    /// começo do cenário), antes da escala de brilho escolhida pela pessoa.
    func sample(at t: Double) -> (mix: Double, brightness: Double) {
        let n = SceneNoise.self
        switch self {
        case .fogueira:
            // Três camadas de ruído: respiração lenta da chama, ondulação e cintilação
            // rápida. Quando a chama baixa ela avermelha, quando sobe ela amarela. De vez
            // em quando um "estalo" (subida rápida) e uma sombra (queda curta).
            let slow = n.value(t * 0.23, seed: 11)
            let mid = n.value(t * 1.6, seed: 23)
            let fast = n.value(t * 8.5, seed: 37)
            var b = 0.42 + 0.30 * mid + 0.14 * fast + 0.14 * slow
            let pop = n.value(t * 0.9, seed: 51)
            if pop > 0.82 { b += (pop - 0.82) * 1.6 }
            let shadow = n.value(t * 0.7, seed: 67)
            if shadow < 0.14 { b -= (0.14 - shadow) * 1.8 }
            b = clamp(b, 0.18, 1)
            let mix = clamp(0.62 - 0.38 * b + 0.06 * (fast - 0.5), 0.12, 0.85)
            return (mix, b)
        case .vela:
            let mid = n.value(t * 1.9, seed: 71)
            let fast = n.value(t * 6.5, seed: 83)
            let b = clamp(0.78 + 0.12 * (mid - 0.5) + 0.07 * (fast - 0.5), 0.55, 0.95)
            let mix = clamp(0.10 + 0.08 * n.value(t * 0.4, seed: 97), 0, 0.3)
            return (mix, b)
        case .brasa:
            let breath = 0.5 + 0.5 * sin(2 * Double.pi * t / 7.5)
            let b = clamp(0.22 + 0.30 * breath + 0.10 * (n.value(t * 0.9, seed: 101) - 0.5), 0.12, 0.7)
            let mix = clamp(0.82 + 0.12 * (n.value(t * 0.3, seed: 113) - 0.5), 0.6, 1)
            return (mix, b)
        case .entardecer:
            let mix = clamp(0.15 + 0.7 * n.value(t * 0.035, seed: 127), 0, 1)
            let b = clamp(0.55 + 0.3 * n.value(t * 0.05, seed: 131), 0.3, 0.9)
            return (mix, b)
        }
    }

    /// Cor que a lâmpada mostra em `t`, já com a escala de brilho (1–255) e o limitador.
    func color(at t: Double, brightness: UInt8) -> LampColor {
        let s = sample(at: t)
        return LampColor(mix: s.mix, brightness: s.brightness * Double(max(brightness, 1)) / 255)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
}

/// Ruído de valor 1D: um número aleatório "fixo" em cada inteiro (hash) e uma curva suave
/// entre eles (smoothstep). Determinístico e barato — dá pra rodar a 50 Hz num ESP32.
enum SceneNoise {
    /// 0–1 a partir de um inteiro (hash de 32 bits, sem estado).
    static func hash(_ i: Int, seed: UInt32) -> Double {
        var x = UInt32(truncatingIfNeeded: i) &* 0x9E37_79B1 &+ seed &* 0x85EB_CA6B
        x ^= x >> 15
        x = x &* 0x2C1B_3C6D
        x ^= x >> 12
        x = x &* 0x297A_2D39
        x ^= x >> 15
        return Double(x) / Double(UInt32.max)
    }

    /// 0–1, contínuo em `x`.
    static func value(_ x: Double, seed: UInt32) -> Double {
        let i = floor(x)
        let f = x - i
        let u = f * f * (3 - 2 * f)
        let a = hash(Int(i), seed: seed)
        let b = hash(Int(i) + 1, seed: seed)
        return a + (b - a) * u
    }
}
