# FitsCull 1.1.0

**[English](#english) · [Italiano](#italiano)**

---

## English

A fast macOS viewer for astrophotography FITS files: step through an imaging session, assess every frame
and move the bad ones to the Trash.

- Automatic stretched preview (like PixInsight's STF), Fit / 50% / true 100% zoom.
- Per-channel statistics: median, mean, σ, noise, minimum, maximum, saturated pixels.
- Star metrics for lights: star count, FWHM (px and ″), HFR, eccentricity.
- Flags for frames that stand out from the session, with thresholds you can change in Settings (⌘,);
  Session view with charts and manual thresholds.
- Trash with confirmation, falling back to a `_rejected/` folder on NAS volumes without a Trash.

Cameras: mono (e.g. ZWO ASI2600MM) and Bayer-matrix colour. ASIAIR and N.I.N.A. headers.
Uncompressed 2-D FITS (BITPIX 8/16/32/−32).

### Build and commands

| Command | What it does |
|---|---|
| `scripts/build-app.sh [destination]` | Builds `FitsCull.app` and installs it in the destination folder (default `/Volumes/Dati2/applicazioni`) |
| `scripts/test.sh` | Runs the tests (103) |
| `swift run FitsCull` | Runs the app in development |
| `swift run -c release fcanalyze <folder or file>` | Table of metrics and timings per file |

The app is ad-hoc signed: the first time, right-click it → Open.

### Keyboard

←/→ or ↑/↓ navigate · Home/End first/last · X reject/restore · Space Fit/100% · ⌘0 Fit ·
S stretch · L linked/separate channels · ⌘⌫ current file to Trash · ⇧⌘⌫ all rejected to Trash ·
⌘O open folder · ⌘1/⌘2 Review/Session · ⌘, Settings

### Flags

| Flag | When (defaults) |
|---|---|
| high background | background > 3000 ADU **and** more than 30% above the session median |
| few stars | stars < 50% of the session median |
| high FWHM | FWHM > session median + 25% |
| elongated stars | eccentricity > 0.75 (≈ 0.68–0.69 in PixInsight) |

In **FitsCull → Settings… (⌘,)** each rule can be turned off and each value changed; "Restore Defaults"
brings back the values above. Settings are saved and apply immediately to the open session.
Flags never reject anything on their own. Darks, flats and biases have no star metrics.

### Accuracy

Validated on mono L lights against PixInsight (FWHMEccentricity, Moffat4): background matches; FWHM is
consistently 9–11% higher, with the same frame ranking. Details in `docs/validation-2026-10-11.md`
(in Italian).

### Documentation (in Italian)

- `docs/superpowers/specs/2026-10-11-fitscull-design.md` — design document (final v1 state, future work)
- `docs/validation-2026-10-11.md` — comparison with PixInsight and timings
- `docs/superpowers/plans/2026-10-11-fitscull-v1.md` — implementation plan (historical)
- `CHANGELOG.md` — changes

Toolchain: Command Line Tools for Xcode 26.6, Swift 6.3 (Xcode not required).

License: MIT — see `LICENSE`.

---

## Italiano

Visualizzatore rapido di FITS astrofotografici per macOS, per scorrere una sessione di ripresa, valutare
ogni frame e spostare nel Cestino quelli da scartare. Interfaccia in inglese.

- Anteprima stretchata automatica (come l'STF di PixInsight), zoom Fit / 50% / 100% reale.
- Statistiche per canale: mediana, media, σ, rumore, minimo, massimo, pixel saturi.
- Metriche stellari per i light: numero di stelle, FWHM (px e ″), HFR, eccentricità.
- Segnalazioni dei frame anomali rispetto alla sessione, soglie modificabili in Settings (⌘,);
  vista Session con grafici e soglie manuali.
- Cestino con conferma, con ripiego in `_rejected/` sui NAS senza Cestino.

Camere: mono (es. ZWO ASI2600MM) e a colori con matrice Bayer. Header ASIAIR e N.I.N.A.
FITS non compressi a 2 dimensioni (BITPIX 8/16/32/−32).

### Installazione e comandi

| Comando | Cosa fa |
|---|---|
| `scripts/build-app.sh [destinazione]` | Crea `FitsCull.app` e la installa nella cartella indicata (predefinita `/Volumes/Dati2/applicazioni`) |
| `scripts/test.sh` | Esegue i test (103) |
| `swift run FitsCull` | Avvia l'app in sviluppo |
| `swift run -c release fcanalyze <cartella o file>` | Tabella delle metriche e dei tempi per file |

Al primo avvio dell'app installata: clic destro → Apri (firma ad-hoc).

### Tastiera

←/→ o ↑/↓ naviga · Inizio/Fine primo/ultimo · X scarta/ripristina · Spazio Fit/100% · ⌘0 Fit ·
S stretch · L canali collegati/separati · ⌘⌫ file corrente nel Cestino · ⇧⌘⌫ tutti gli scartati nel Cestino ·
⌘O apri cartella · ⌘1/⌘2 Review/Session · ⌘, Settings

### Segnalazioni

| Segnalazione | Quando (valori predefiniti) |
|---|---|
| high background | fondo > 3000 ADU **e** oltre +30% della mediana di sessione |
| few stars | stelle < 50% della mediana di sessione |
| high FWHM | FWHM > mediana di sessione + 25% |
| elongated stars | eccentricità > 0,75 (≈ 0,68–0,69 in PixInsight) |

In **FitsCull → Settings… (⌘,)** ogni regola si può disattivare e ogni valore modificare; "Restore Defaults"
riporta i valori della tabella. Le impostazioni restano salvate e si applicano subito alla sessione aperta.
Le segnalazioni non scartano nulla. Dark, flat e bias non hanno metriche stellari.

### Precisione

Validata su light mono L contro PixInsight (FWHMEccentricity, Moffat4): fondo coincidente; FWHM +9…+11%
in modo costante, con lo stesso ordine dei frame. Dettagli in `docs/validation-2026-10-11.md`.

### Documentazione

- `docs/superpowers/specs/2026-10-11-fitscull-design.md` — documento di progetto (stato finale v1, lavori futuri)
- `docs/validation-2026-10-11.md` — confronto con PixInsight e tempi
- `docs/superpowers/plans/2026-10-11-fitscull-v1.md` — piano di implementazione (storico)
- `CHANGELOG.md` — modifiche

Toolchain: Command Line Tools for Xcode 26.6, Swift 6.3 (Xcode non richiesto).

Licenza: MIT — vedi `LICENSE`.
