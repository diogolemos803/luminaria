# Gera os sons de despertador calmos (Luminaria/alarm_*.wav) sem depender de
# Python/pacotes externos - so .NET (System.IO/System.Math), ja disponivel no Windows.
#
# Formato: PCM 16-bit, mono, 44.1kHz - mesma convencao ja usada em silence_loop.wav
# e alarm_tone.wav. Rodar uma vez localmente e commitar o resultado:
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

# Nota "sino": ataque quase instantaneo, decaimento exponencial suave + leve
# harmonico (2x a frequencia) pra dar corpo de sino em vez de tom puro.
function New-BellNote {
    param(
        [double]$Freq,
        [double]$Duration,
        [double]$Amplitude = 0.6
    )
    $n = [int]($SampleRate * $Duration)
    $attack = [Math]::Max(1, [int]($n * 0.02))
    $samples = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        if ($i -lt $attack) {
            $env = 0.5 - 0.5 * [Math]::Cos([Math]::PI * $i / $attack)
        }
        else {
            $decayI = $i - $attack
            $decayN = [Math]::Max(1, $n - $attack)
            $env = [Math]::Exp(-3.0 * $decayI / $decayN)
        }
        $t = $i / $SampleRate
        $samples[$i] = $Amplitude * $env * ([Math]::Sin(2 * [Math]::PI * $Freq * $t) + 0.3 * [Math]::Sin(2 * [Math]::PI * $Freq * 2.0 * $t))
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
    return ,$buffer
}

# "Carrilhao suave" - acorde maior (Do5-Mi5-Sol5) tocado como sino, com leve
# atraso entre as notas (efeito de carrilhao/sininhos), sem estridencia.
function New-Carrilhao {
    $notes = @(523.25, 659.25, 783.99)
    $dur = 1.6
    $step = 0.28
    $tracks = @()
    for ($idx = 0; $idx -lt $notes.Length; $idx++) {
        $samples = New-BellNote -Freq $notes[$idx] -Duration $dur -Amplitude 0.5
        $offset = [int]($SampleRate * $step * $idx)
        $tracks += , @{ Offset = $offset; Samples = $samples }
    }
    return Mix-Tracks -Tracks $tracks
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

# "Respiracao" - tom sustentado grave com modulacao lenta de amplitude (~0.25Hz),
# simulando o ritmo de uma respiracao calma.
function New-Respiracao {
    $duration = 4.0
    $freq = 220.0
    $n = [int]($SampleRate * $duration)
    $attack = [int]($SampleRate * 0.5)
    $release = [int]($SampleRate * 1.0)
    $lfoFreq = 0.25
    $samples = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $SampleRate
        $env = Get-Envelope -i $i -n $n -attack $attack -release $release
        $lfo = 0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * $lfoFreq * $t - [Math]::PI / 2)
        $breathAmp = 0.25 + 0.35 * $lfo
        $samples[$i] = $env * $breathAmp * [Math]::Sin(2 * [Math]::PI * $freq * $t)
    }
    return , $samples
}

$outDir = Join-Path $PSScriptRoot "..\Luminaria"

Write-Host "Gerando alarm_carrilhao.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_carrilhao.wav") -Samples (New-Carrilhao) -SampleRate $SampleRate

Write-Host "Gerando alarm_alvorada.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_alvorada.wav") -Samples (New-Alvorada) -SampleRate $SampleRate

Write-Host "Gerando alarm_respiracao.wav..."
Write-Wav -Path (Join-Path $outDir "alarm_respiracao.wav") -Samples (New-Respiracao) -SampleRate $SampleRate

Write-Host "Pronto."
