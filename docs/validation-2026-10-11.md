# FitsCull v1 — Validazione su dati reali (2026-10-11)

Confronto tra FitsCull e PixInsight 1.9.5 sugli stessi file. Misure PixInsight eseguite dall'utente con lo script **FWHMEccentricity 1.5.3** (Model function Moffat4, Star detection sensitivity 0,50, Upper limit 1,000) e con *Statistics*.

## Fondo (media e mediana)

Coincide con PixInsight (verifica dell'utente). Tolleranza della spec: ±1%. ✓

## FWHM, eccentricità, numero di stelle — light mono L (ZWO ASI2600MM)

Per i file mono FitsCull misura a piena risoluzione: i "px" sono pixel del sensore, come in PixInsight.

### Serie A — due light (prime prove)

| | PixInsight FWHM | FitsCull FWHM | Diff. | PI ecc. | FC ecc. | PI stelle | FC stelle |
|---|---|---|---|---|---|---|---|
| Image01 | 2,604 px | 2,87 px (4,02″) | +10% | 0,406 | 0,43 | 4644 | 6160 |
| Image02 | 2,522 px | 2,79 px (3,91″) | +11% | 0,356 | 0,40 | 5492 | 7249 |

Andamento Image01 → Image02: FWHM −3,1% (PI) / −2,8% (FC); stelle +18% / +18%; eccentricità in calo in entrambi.

### Serie B — LDN 1355, L, 300 s, gain 100, 554 mm, 1,40″/px

| File | PixInsight FWHM | FitsCull FWHM | Diff. | PI ecc. | FC ecc. | PI stelle | FC stelle |
|---|---|---|---|---|---|---|---|
| …_0001 | 2,851 px | 3,13 px (4,39″) | +9,8% | 0,382 | 0,42 | 4842 | 6789 |
| …_0002 | 3,088 px | 3,37 px (4,72″) | +9,1% | 0,377 | 0,41 | 5127 | 7094 |
| …_0003 | 2,903 px | 3,18 px (4,46″) | +9,5% | 0,361 | 0,39 | 5686 | 7506 |

Andamento: 0001 → 0002 FWHM +8,3% (PI) / +7,7% (FC); 0002 → 0003 −6,0% / −5,6%. Stesso ordine dei frame (0001 migliore, poi 0003, poi 0002). Scala verificata: 206,265 × 3,76 / 554 = 1,40″/px.

### Esito

| Metrica | Tolleranza | Esito |
|---|---|---|
| FWHM | ±15% | ✓ +9,1…+11%, scostamento costante e nello stesso verso |
| Eccentricità | — | +6…+12% costante → soglia di segnalazione fissata a 0,75 (≈ 0,68–0,69 in PixInsight) |
| Numero stelle | stesso andamento | ✓ andamento coerente; valore assoluto +32…+40% |

Causa dello scostamento sistematico della FWHM: PixInsight adatta un profilo Moffat, FitsCull usa momenti secondi pesati che presuppongono un profilo gaussiano; le "ali" delle stelle reali danno una FWHM leggermente maggiore. Per la selezione dei frame conta il confronto relativo, che coincide.

Conseguenza sulle segnalazioni (scelta dell'utente): "FWHM alta" solo oltre la mediana di sessione + 25% — con la regola iniziale (mediana + 2σ, di fatto ≈ +10%) il file 0003 risultava segnalato pur essendo solo l'1,8% peggiore dello 0001 in PixInsight.

## Controllo incrociato della FWHM (file a colori ASI2600MC)

Su tre light a colori, tre misure indipendenti in pixel del sensore: FitsCull a metà risoluzione (×2), FitsCull a piena risoluzione e misura diretta senza modelli (diametro dell'area sopra metà picco, ≈ 400 stelle luminose).

| File | Metà ris. ×2 | Piena ris. | Diretta |
|---|---|---|---|
| M 42 (1,88″/px) | 4,25 px | 4,29 px | 4,07 px |
| NGC 7023 (0,97″/px) | 4,03 px | 3,94 px | 4,07 px |
| M 31 (1,88″/px) | 3,38 px | 3,25 px | 2,99 px |

Le misure concordano entro il 5–13%: l'analisi a metà risoluzione dei file a colori non introduce errori. Nota: FWHMEccentricity su un file CFA **non debayerizzato** dà valori circa dimezzati e non è confrontabile.

## Tempi (release, Apple Silicon)

| Operazione | Tempo |
|---|---|
| Analisi completa, file a colori ASI2600MC (50 MB, da cache disco) | 0,21–0,32 s/file |
| Zoom 100% (lettura + ricostruzione colore ≈ 0,4 s, stretch ≈ 0,35 s) | ≈ 0,75 s |
| File mono ASI2600MM | giudicato "ottimo" dall'utente; da misurare con `fcanalyze` |

## Verifiche funzionali eseguite dall'utente

- Velocità di navigazione e leggibilità dell'interfaccia: ottime.
- NAS senza Cestino: ripiego "Cestino non disponibile" → `_scartati/` funzionante.
- Flat e dark senza metriche stellari.
- Memoria dei calcoli: riapertura della cartella immediata.
