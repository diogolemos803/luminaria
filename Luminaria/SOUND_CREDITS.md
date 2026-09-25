# Créditos dos sons do despertador

Gravações reais baixadas do [Wikimedia Commons](https://commons.wikimedia.org) em
2026-09-25, todas em **CC0** ou **domínio público**: permitem uso comercial (inclusive
na App Store), sem pagamento e sem exigir atribuição. Os créditos ficam aqui mesmo assim,
por respeito aos autores e pra rastrear a origem de cada arquivo.

Cada arquivo do app é um trecho de 20s da gravação original, convertido pra mono
44,1 kHz 16-bit, com entrada/saída suaves e volume normalizado
(`scripts/transcode_recordings.ps1` + `scripts/process_alarm_recordings.js`). Os
originais ficam em `Assets/sons_originais/`, fora do git.

| Arquivo no app | Nome no app | Gravação original | Autor | Licença |
|---|---|---|---|---|
| `alarm_passaros_acordando.wav` | Pássaros acordando | [Réveil des oiseaux.ogg](https://commons.wikimedia.org/wiki/File:R%C3%A9veil_des_oiseaux.ogg) | Joseph Sardin | CC0 |
| `alarm_rouxinol.wav` | Rouxinol | [Nachtigall.ogg](https://commons.wikimedia.org/wiki/File:Nachtigall.ogg) | Membeth | CC0 |
| `alarm_melros.wav` | Melros de manhã | [Reggelirigók.ogg](https://commons.wikimedia.org/wiki/File:Reggelirig%C3%B3k.ogg) | Ödönke | Domínio público |
| `alarm_brisa_passaros.wav` | Brisa com pássaros | [Gentle breeze and birds singing.ogg](https://commons.wikimedia.org/wiki/File:Gentle_breeze_and_birds_singing.ogg) | ezwa | Domínio público |
| `alarm_ondas_praia.wav` | Ondas na praia | [Ocean Waves on a Tropical Beach.ogg](https://commons.wikimedia.org/wiki/File:Ocean_Waves_on_a_Tropical_Beach.ogg) | Jarrod Stanley | CC0 |
| `alarm_ondas_mar.wav` | Ondas do mar | [Waves.ogg](https://commons.wikimedia.org/wiki/File:Waves.ogg) | Dsw4 | Domínio público |
| `alarm_praia_pedrinhas.wav` | Praia de pedrinhas | [On a pebble beach.ogg](https://commons.wikimedia.org/wiki/File:On_a_pebble_beach.ogg) | earthcalling | Domínio público |
| `alarm_riacho.wav` | Riacho | [2024-07-26 Molln (Oberösterreich) Bachlauf plätschert (Krumme Steyerling bei Piesslingerstraße).wav](https://commons.wikimedia.org/wiki/File:2024-07-26_Molln_(Ober%C3%B6sterreich)_Bachlauf_pl%C3%A4tschert_(Krumme_Steyerling_bei_Piesslingerstra%C3%9Fe).wav) | DrTrumpet | CC0 |
| `alarm_fio_dagua.wav` | Fio d'água | [363120 fractalstudios water-trickle.wav](https://commons.wikimedia.org/wiki/File:363120_fractalstudios_water-trickle.wav) | FractalStudios | CC0 |
| `alarm_chuva_leve.wav` | Chuva leve | [Light Rain Distant Thunder July 5th 2016.wav](https://commons.wikimedia.org/wiki/File:Light_Rain_Distant_Thunder_July_5th_2016.wav) | kvgarlic | CC0 |
| `alarm_noite_campo.wav` | Noite no campo | [Country night noise.ogg](https://commons.wikimedia.org/wiki/File:Country_night_noise.ogg) | hc | Domínio público |
| `alarm_sinos_koshi.wav` | Sinos de vento Koshi | [Windglockenspiel.Koshi.ogg](https://commons.wikimedia.org/wiki/File:Windglockenspiel.Koshi.ogg) | Membeth | CC0 |
| `alarm_sinos_vento.wav` | Sinos de vento | [Windchime.ogg](https://commons.wikimedia.org/wiki/File:Windchime.ogg) | stephan (pdsounds.org) | Domínio público |
| `alarm_sininhos.wav` | Sininhos | [Soothing jingling little bells ambience.ogg](https://commons.wikimedia.org/wiki/File:Soothing_jingling_little_bells_ambience.ogg) | stephan | Domínio público |
| `alarm_sinos_tubulares.wav` | Sinos tubulares | [415061 gsb1039 clock-chime-tubebells-handbells-vibes.wav](https://commons.wikimedia.org/wiki/File:415061_gsb1039_clock-chime-tubebells-handbells-vibes.wav) | gsb1039 | CC0 |
| `alarm_ceramica.wav` | Cerâmica tilintando | [Chiming pottery.ogg](https://commons.wikimedia.org/wiki/File:Chiming_pottery.ogg) | stephan | Domínio público |
| `alarm_tigela.wav` | Tigela tibetana | [SingingBowl1.ogg](https://commons.wikimedia.org/wiki/File:SingingBowl1.ogg) | BambooBeast | Domínio público |
| `alarm_caixinha.wav` | Caixinha de música | [Komiku - 46 - Merfolk Music Box.ogg](https://commons.wikimedia.org/wiki/File:Komiku_-_46_-_Merfolk_Music_Box.ogg) | Komiku | CC0 |
| `alarm_cancao_ninar.wav` | Canção de ninar | [Lullaby wound up clock guten abend gute nacht.ogg](https://commons.wikimedia.org/wiki/File:Lullaby_wound_up_clock_guten_abend_gute_nacht.ogg) | stephan | Domínio público |

Sons sintetizados pelo próprio projeto (`scripts/generate_alarm_sounds.ps1`), sem
terceiros: `alarm_alvorada.wav` (Alvorada), `alarm_tone.wav` (Sirene clássica) e
`silence_loop.wav`.
