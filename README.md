# FitsCull

Visualizzatore rapido di FITS astrofotografici per macOS: anteprima stretchata, statistiche,
metriche stellari (numero, FWHM, HFR, eccentricità), vista Sessione e scarto nel Cestino.

## Comandi

| Comando | Cosa fa |
|---|---|
| `scripts/test.sh` | Esegue i test |
| `swift run FitsCull` | Avvia l'app in sviluppo |
| `scripts/build-app.sh` | Crea `FitsCull.app` e la installa in `/Volumes/Dati2/applicazioni` |
| `swift run -c release fcanalyze <cartella>` | Tabella delle metriche e tempi per file |

## Tastiera

←/→ o ↑/↓ naviga · Inizio/Fine primo/ultimo · X scarta/ripristina · Spazio Adatta/100% · ⌘0 Adatta ·
S stretch · L canali collegati/separati · ⌘⌫ file corrente nel Cestino · ⇧⌘⌫ tutti gli scartati nel Cestino ·
⌘O apri cartella · ⌘1/⌘2 Revisione/Sessione

Toolchain: Command Line Tools for Xcode 26.6 (Xcode non richiesto).
