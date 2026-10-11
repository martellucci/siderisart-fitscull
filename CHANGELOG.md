# Changelog

## 1.0.0 — 2026-10-11

Prima versione completa (branch `fitscull-v1`). Documento di progetto: `docs/superpowers/specs/2026-10-11-fitscull-design.md`; validazione: `docs/validation-2026-10-11.md`.

### Funzioni

- Apertura di una cartella di FITS (disco locale, esterno o NAS), ordinamento per data di ripresa, filtro per tipo (Light, Dark, Flat, Bias, Dark flat).
- Analisi in background (3 file in parallelo, prima il corrente e i vicini) con memoria dei risultati su disco.
- Statistiche per canale: minimo, massimo, media, mediana, σ, rumore (MAD), pixel saturi.
- Metriche stellari per i light: numero di stelle, FWHM (px e ″), HFR, eccentricità.
- Anteprima stretchata automatica (come l'STF di PixInsight), canali collegati o separati, istogramma, header completo.
- Barra sotto l'immagine: navigazione (primo, precedente, posizione, successivo, ultimo), zoom Adatta / 50% / 100% reale, Scarta / Ripristina, cestino del file corrente.
- Vista Sessione: grafici di FWHM, stelle, fondo ed eccentricità nel tempo, soglie manuali e "Segna fuori soglia".
- Segnalazioni tolleranti: fondo > 3000 ADU e +30% della sessione; stelle < 50% della mediana; FWHM > mediana + 25%; eccentricità > 0,75.
- Cestino con conferma (file corrente ⌘⌫, tutti gli scartati ⇧⌘⌫); sui volumi senza Cestino ripiego in `_scartati/` o eliminazione definitiva con doppia conferma.
- `fcanalyze`: tabella delle metriche e dei tempi da riga di comando.

### Modifiche rispetto al piano iniziale

- Momenti stellari pesati con gaussiana adattiva (i momenti non pesati davano eccentricità falsate dal rumore).
- Lettura dei file non mappata in memoria sui volumi di rete (evita crash se il NAS si scollega).
- Selezione riportata al primo file visibile quando il filtro Tipo la nasconde (evitava ricaricamenti continui).
- Nessuna metrica stellare per dark, flat, bias e dark flat; cache passata a `metrics-v2.json`.
- Barra di navigazione e zoom 50% / 100% reale; cestino del file corrente con conferma; scorciatoia degli scartati spostata su ⇧⌘⌫.
- Anteprime dei file mono ridotte 2×2 (zoom 50% corretto, ~26 MB per anteprima).
- Soglie di segnalazione tarate sul confronto con PixInsight: eccentricità 0,6 → 0,75; FWHM mediana + 2σ → mediana + 25%; fondo anche > 3000 ADU.
- Scala in ″/px calcolata senza moltiplicare per il binning (XPIXSZ lo include già).
