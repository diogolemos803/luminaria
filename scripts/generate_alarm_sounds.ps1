# Gera os sons de despertador (Luminaria/alarm_*.wav) sem depender de Python/pacotes
# externos - so .NET (System.IO/System.Math), ja disponivel no Windows.
#
# Dois estilos aqui: "Alvorada" (tons puros, arpejo) e os sons de natureza (ondas do
# mar / chuva / passarinhos), sintetizados a partir de ruido branco filtrado - a mesma
# tecnica que apps de despertador confortavel (Sleep Cycle, Pillow etc.) usam de verdade
# pra esse tipo de som, só que aqui 100% gerado por codigo em vez de gravacao baixada
# (sem risco de licenciamento pra publicar na App Store).
#
# Formato: PCM 16-bit, mono, 44.1kHz - mesma convencao ja usada em silence_loop.wav e
# alarm_tone.wav. Rodar uma vez localmente e commitar o resultado:
#   powershell -File scripts/generate_alarm_sounds.ps1

$ErrorActionPreference = "Stop"
$SampleRate = 44100

function Write-Wav {
    param(
        [string]$Path,
        [double[]]$Samples,
        [int]$SampleRate = 44100
    )
    $numSamples = $Samples.Length
    $byteRate = $SampleRate * 2
    $dataSize = $numSamples * 2
    $fileSize = 36 + $dataSize

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $bw.Write([int32]$fileSize)
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))

        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $bw.Write([int32]16)
        $bw.Write([int16]1)      # PCM
        $bw.Write([int16]1)      # mono
        $bw.Write([int32]$SampleRate)
        $bw.Write([int32]$byteRate)
        $bw.Write([int16]2)      # block align
        $bw.Write([int16]16)     # bits per sample

        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $bw.Write([int32]$dataSize)
        foreach ($s in $Samples) {
            $clamped = [Math]::Max(-1.0, [Math]::Min(1.0, $s))
            $bw.Write([int16][Math]::Round($clamped * 32767))
        }
        $bw.Flush()
    }
    finally {
        $bw.Close()
        $fs.Close()
    }
}

function Get-Envelope {
    param([int]$i, [int]$n, [int]$attack, [int]$release)
    if ($i -lt $attack) {
        return 0.5 - 0.5 * [Math]::Cos([Math]::PI * $i / $attack)
    }
    elseif ($i -gt ($n - $release)) {
        $remaining = $n - $i
        return 0.5 - 0.5 * [Math]::Cos([Math]::PI * $remaining / $release)
    }
    else {
        return 1.0
    }
}

# Nota "comum": ataque/liberacao suaves em cosseno, sem clique nas bordas.
function New-Note {
    param(
        [double]$Freq,
        [double]$Duration,
        [double]$Amplitude = 0.6,
        [double]$AttackRatio = 0.15,
        [double]$ReleaseRatio = 0.5
    )
    $n = [int]($SampleRate * $Duration)
    $attack = [Math]::Max(1, [int]($n * $AttackRatio))
    $release = [Math]::Max(1, [int]($n * $ReleaseRatio))
    $samples = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $env = Get-Envelope -i $i -n $n -attack $attack -release $release
        $t = $i / $SampleRate
        $samples[$i] = $Amplitude * $env * [Math]::Sin(2 * [Math]::PI * $Freq * $t)
    }
    return ,$samples
}

# Mistura trilhas com offsets diferentes (pra notas que se sobrepoem) e
# normaliza pra evitar clipping, deixando uma margem de headroom.
function Mix-Tracks {
    param([array]$Tracks)
    $length = 0
    foreach ($tr in $Tracks) {
        $end = $tr.Offset + $tr.Samples.Length
        if ($end -gt $length) { $length = $end }
    }
    $buffer = New-Object double[] $length
    foreach ($tr in $Tracks) {
        for ($i = 0; $i -lt $tr.Samples.Length; $i++) {
            $buffer[$tr.Offset + $i] += $tr.Samples[$i]
        }
    }
    $peak = 0.0
    foreach ($v in $buffer) {
        $av = [Math]::Abs($v)
        if ($av -gt $peak) { $peak = $av }
    }
    if ($peak -lt 1.0) { $peak = 1.0 }
    for ($i = 0; $i -lt $buffer.Length; $i++) {
        $buffer[$i] = ($buffer[$i] / $peak) * 0.9
    }
    return , $buffer
}

# "Alvorada" - arpejo pentatonico ascendente e lento, cada nota um pouco mais
# clara que a anterior, lembrando um amanhecer gradual.
function New-Alvorada {
    $notes = @(261.63, 293.66, 329.63, 392.00, 440.00)
    $dur = 0.6
    $step = 0.42
    $tracks = @()
    for ($idx = 0; $idx -lt $notes.Length; $idx++) {
        $amp = 0.3 + 0.05 * $idx
        $samples = New-Note -Freq $notes[$idx] -Duration $dur -Amplitude $amp -AttackRatio 0.25 -ReleaseRatio 0.6
        $offset = [int]($SampleRate * $step * $idx)
        $tracks += , @{ Offset = $offset; Samples = $samples }
    }
    return Mix-Tracks -Tracks $tracks
}

# --- Sons de natureza: ruido branco filtrado, não tons puros ---------------------

function New-WhiteNoise {
    param([double]$Duration, [System.Random]$Rng)
    $n = [int]($SampleRate * $Duration)
    $samples = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $samples[$i] = ($Rng.NextDouble() * 2.0) - 1.0
    }
    return , $samples
}

# Filtro passa-baixa de um polo (IIR): quanto menor o Alpha, mais grave/suave o
# resultado (bom pra "mar"); Alpha maior deixa mais "chiado" (bom pra "chuva").
function Apply-LowPass {
    param([double[]]$Samples, [double]$Alpha)
    $n = $Samples.Length
    $output = New-Object double[] $n
    $prev = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $prev = $prev + $Alpha * ($Samples[$i] - $prev)
        $output[$i] = $prev
    }
    return , $output
}

# Normaliza pro pico alvo — os sons de natureza precisam ser BEM mais fortes que os
# tons calmos antigos (0.3-0.6 de amplitude) pra funcionar de verdade como despertador.
function Normalize-Samples {
    param([double[]]$Samples, [double]$Target = 0.92)
    $peak = 0.0
    foreach ($v in $Samples) {
        $av = [Math]::Abs($v)
        if ($av -gt $peak) { $peak = $av }
    }
    if ($peak -lt 0.0001) { $peak = 1.0 }
    $scale = $Target / $peak
    for ($i = 0; $i -lt $Samples.Length; $i++) {
        $Samples[$i] = $Samples[$i] * $scale
    }
    return , $Samples
}

# "Ondas do mar" - ruido filtrado (grave, sem chiado agudo) com 3 "ondas" de amplitude
# ao longo do loop. Começa e termina em silêncio (fade global em seno) pra não estalar
# na hora de repetir o loop.
function New-OceanWaves {
    $rng = New-Object System.Random(42)
    $duration = 6.0
    $n = [int]($SampleRate * $duration)
    $noise = New-WhiteNoise -Duration $duration -Rng $rng
    $filtered = Apply-LowPass -Samples $noise -Alpha 0.05
    $filtered = Apply-LowPass -Samples $filtered -Alpha 0.05

    $samples = New-Object double[] $n
    $waveCount = 3
    for ($i = 0; $i -lt $n; $i++) {
        $phase = $i / $n
        $globalFade = [Math]::Sin([Math]::PI * $phase)
        $waveEnvelope = 0.35 + 0.65 * (0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $waveCount * $phase - [Math]::PI / 2))
        $samples[$i] = $filtered[$i] * $globalFade * $waveEnvelope
    }
    return Normalize-Samples -Samples $samples -Target 0.92
}

# "Chuva" - ruido mais chiado (menos filtrado) e constante, com "gotas" individuais
# (estalos curtos com decaimento rápido) espalhadas por cima pra dar textura real.
function New-Rain {
    $rng = New-Object System.Random(7)
    $duration = 5.0
    $n = [int]($SampleRate * $duration)
    $noise = New-WhiteNoise -Duration $duration -Rng $rng
    $hiss = Apply-LowPass -Samples $noise -Alpha 0.35

    $samples = New-Object double[] $n
    $fadeSamples = [int]($SampleRate * 0.3)
    for ($i = 0; $i -lt $n; $i++) {
        $fade = 1.0
        if ($i -lt $fadeSamples) { $fade = $i / $fadeSamples }
        elseif ($i -gt ($n - $fadeSamples)) { $fade = ($n - $i) / $fadeSamples }
        $samples[$i] = $hiss[$i] * $fade * 0.55
    }

    $dropletCount = 40
    $usableStart = $fadeSamples / $SampleRate
    $usableSpan = $duration - (2 * $usableStart)
    for ($d = 0; $d -lt $dropletCount; $d++) {
        $startSample = [int](($usableStart + $rng.NextDouble() * $usableSpan) * $SampleRate)
        $dropletLength = [int]($SampleRate * (0.02 + $rng.NextDouble() * 0.03))
        $dropletAmp = 0.3 + $rng.NextDouble() * 0.35
        for ($j = 0; $j -lt $dropletLength; $j++) {
            $idx = $startSample + $j
            if ($idx -ge $n) { break }
            $decay = [Math]::Exp(-6.0 * $j / $dropletLength)
            $samples[$idx] += (($rng.NextDouble() * 2.0) - 1.0) * $decay * $dropletAmp
        }
    }

    return Normalize-Samples -Samples $samples -Target 0.9
}

# "Passarinhos ao amanhecer" - fundo bem suave de ar externo (ruido bem filtrado, bem
# baixo) com pequenos "chirps" (glissandos curtos, timbre agudo de passaro) espalhados
# em cima, cada um com 2-4 notas rapidas.
function New-Birds {
    $rng = New-Object System.Random(99)
    $duration = 7.0
    $n = [int]($SampleRate * $duration)
    $samples = New-Object double[] $n

    $noise = New-WhiteNoise -Duration $duration -Rng $rng
    $ambience = Apply-LowPass -Samples $noise -Alpha 0.03
    $fadeSamples = [int]($SampleRate * 0.4)
    for ($i = 0; $i -lt $n; $i++) {
        $fade = 1.0
        if ($i -lt $fadeSamples) { $fade = $i / $fadeSamples }
        elseif ($i -gt ($n - $fadeSamples)) { $fade = ($n - $i) / $fadeSamples }
        $samples[$i] = $ambience[$i] * $fade * 0.12
    }

    $chirpCount = 10
    $baseFreqs = @(2200.0, 2800.0, 3400.0, 4000.0)
    $usableStart = $fadeSamples / $SampleRate
    $usableSpan = $duration - (2 * $usableStart) - 0.4
    for ($c = 0; $c -lt $chirpCount; $c++) {
        $startSample = [int](($usableStart + $rng.NextDouble() * $usableSpan) * $SampleRate)
        $freqBase = $baseFreqs[$rng.Next(0, $baseFreqs.Length)]
        $noteCount = 2 + $rng.Next(0, 3)
        $noteLength = [int]($SampleRate * 0.06)
        $gap = [int]($SampleRate * 0.03)
        $cursor = $startSample
        for ($note = 0; $note -lt $noteCount; $note++) {
            $freq = $freqBase * (1.0 + (($rng.NextDouble() - 0.5) * 0.3))
            for ($j = 0; $j -lt $noteLength; $j++) {
                $idx = $cursor + $j
                if ($idx -ge $n) { break }
                $env = [Math]::Sin([Math]::PI * $j / $noteLength)
                $glide = $freq * (1.0 + (0.5 * ($j / $noteLength)))
                $t = $j / $SampleRate
                $samples[$idx] += [Math]::Sin(2 * [Math]::PI * $glide * $t) * $env * 0.5
            }
            $cursor += $noteLength + $gap
        }
    }

    return Normalize-Samples -Samples $samples -Target 0.85
}

$outDir = Join-Path $PSScriptRoot "..\Luminaria"

Write-Host "Gerando alarm_alvorada.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_alvorada.wav") -Samples (New-Alvorada) -SampleRate $SampleRate

Write-Host "Gerando alarm_ondas.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_ondas.wav") -Samples (New-OceanWaves) -SampleRate $SampleRate

Write-Host "Gerando alarm_chuva.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_chuva.wav") -Samples (New-Rain) -SampleRate $SampleRate

Write-Host "Gerando alarm_passaros.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_passaros.wav") -Samples (New-Birds) -SampleRate $SampleRate

Write-Host "Pronto."
