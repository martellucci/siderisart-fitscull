# FitsCull 1.1.0

Visualizzatore rapido di FITS astrofotografici per macOS, per scorrere una sessione di ripresa, valutare
ogni frame e spostare nel Cestino quelli da scartare. Interfaccia in inglese.

- Anteprima stretchata automatica (come l'STF di PixInsight), zoom Fit / 50% / 100% reale.
- Statistiche per canale: mediana, media, σ, rumore, minimo, massimo, pixel saturi.
- Metriche stellari per i light: numero di stelle, FWHM (px e ″), HFR, eccentricità.
- Segnalazioni dei frame anomali rispetto alla sessione, soglie modificabili in Settings (⌘,), vista Session con grafici e soglie.
- Cestino con conferma, con ripiego in `_rejected/` sui NAS senza Cestino.

Camere: mono (es. ZWO ASI2600MM) e a colori con matrice Bayer. Header ASIAIR e N.I.N.A.
FITS non compressi a 2 dimensioni (BITPIX 8/16/32/−32).

## Installazione e comandi

| Comando | Cosa fa |
|---|---|
| `scripts/build-app.sh` | Crea `FitsCull.app` e la installa in `/Volumes/Dati2/applicazioni` |
| `scripts/test.sh` | Esegue i test (103) |
| `swift run FitsCull` | Avvia l'app in sviluppo |
| `swift run -c release fcanalyze <cartella o file>` | Tabella delle metriche e dei tempi per file |

Al primo avvio dell'app installata: clic destro → Apri (firma ad-hoc).

## Tastiera

←/→ o ↑/↓ naviga · Inizio/Fine primo/ultimo · X scarta/ripristina · Spazio Fit/100% · ⌘0 Fit ·
S stretch · L canali collegati/separati · ⌘⌫ file corrente nel Cestino · ⇧⌘⌫ tutti gli scartati nel Cestino ·
⌘O apri cartella · ⌘1/⌘2 Review/Session · ⌘, Settings

## Segnalazioni

| Segnalazione | Quando (valori predefiniti) |
|---|---|
| high background | fondo > 3000 ADU **e** oltre +30% della mediana di sessione |
| few stars | stelle < 50% della mediana di sessione |
| high FWHM | FWHM > mediana di sessione + 25% |
| elongated stars | eccentricità > 0,75 (≈ 0,68–0,69 in PixInsight) |

In **FitsCull → Settings… (⌘,)** ogni regola si può disattivare e ogni valore modificare; "Restore Defaults"
riporta i valori della tabella. Le impostazioni restano salvate e si applicano subito alla sessione aperta.
Le segnalazioni non scartano nulla. Dark, flat e bias non hanno metriche stellari.

## Precisione

Validata su light mono L contro PixInsight (FWHMEccentricity, Moffat4): fondo coincidente; FWHM +9…+11%
in modo costante, con lo stesso ordine dei frame. Dettagli in `docs/validation-2026-10-11.md`.

## Documentazione

- `docs/superpowers/specs/2026-10-11-fitscull-design.md` — documento di progetto (stato finale v1, lavori futuri)
- `docs/validation-2026-10-11.md` — confronto con PixInsight e tempi
- `docs/superpowers/plans/2026-10-11-fitscull-v1.md` — piano di implementazione (storico)
- `CHANGELOG.md` — modifiche

Toolchain: Command Line Tools for Xcode 26.6, Swift 6.3 (Xcode non richiesto).
