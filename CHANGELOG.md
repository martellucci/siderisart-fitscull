# Changelog

## 1.4.0 — 2026-10-31

- Cambio di tipo dei frame tra Light, Dark e Flat, per le serie salvate col tipo sbagliato (es. dark ripresi con
  l'ASIAIR rimasto su Light). Il file convertito è una **copia** nella stessa cartella; l'originale non viene
  toccato.
  - Nella copia cambiano solo IMAGETYP (e FRAME, se c'è), con lo stesso stile di maiuscole (`'Light'` →
    `'Dark'`, `'LIGHT'` → `'DARK'`), e il tipo nel nome: `Light_M31_120.0s_…_0001.fit` →
    `Dark_M31_120.0s_…_0001.fit`. Resto dell'header e dati identici byte per byte; se il nome non contiene il
    tipo, il nuovo tipo va davanti (`Dark_…`). Senza IMAGETYP la card viene aggiunta; un eventuale CHECKSUM
    viene tolto perché non sarebbe più valido (DATASUM resta).
  - Non sovrascrive mai: se esiste già un file col nuovo nome, quel file viene saltato e segnalato.
  - Singolo file: ⇧C (menù Review → Convert Frame Type…) sul file in esame, conferma con la scelta del tipo di
    arrivo.
  - Cartella intera: File → Convert Frame Type in Folder… sceglie una cartella qualsiasi, poi tipo di partenza e
    di arrivo; si convertono solo i file del tipo di partenza, gli altri restano come sono.
  - Se la cartella è quella aperta, la lista mostra subito le nuove copie, tenendo selezione, analisi e scarti.
  - Bias e Dark flat esclusi.

## 1.3.0 — 2026-10-21

- Tabella a sinistra ordinabile cliccando le intestazioni (#, Time, Exp, Bkg, FWHM″, ★, Ecc, Status): primo clic
  crescente, secondo decrescente. I frame non ancora analizzati restano in fondo in entrambi i versi, a parità di
  valore vale l'ordine di ripresa; Status crescente = ✓, ⚠︎, scartati, errori. Le frecce seguono l'ordine della
  tabella. Tolto il menù "Sort" della barra, sostituito dalle intestazioni.
- La tabella scorre da sola per tenere in vista il frame selezionato: navigando con le frecce, cliccando una
  colonna dei grafici e dopo un riordino.
- Icona su ogni grafico della serie per ordinarne le colonne: ordine di ripresa → crescente → decrescente.
  Ogni grafico ha il suo ordine, che resta passando da un frame all'altro; frame corrente sempre in azzurro.
- STATISTICS e STARS affiancate nella colonna di destra, per lasciare spazio ai grafici; tornano una sotto
  l'altra quando non ci stanno (camere a colori con la colonna stretta).

## 1.2.0 — 2026-10-17

- Grafici della serie nella colonna di destra, in stile PixInsight, sotto statistiche e stelle: Stars,
  Background, FWHM ed Eccentricity, una colonna per light dello **stesso filtro** del frame selezionato, in ordine
  di ripresa. Frame corrente in azzurro (con il suo valore accanto al titolo), scartati in rosso, mediana
  tratteggiata con il valore; clic su una colonna = apre quel frame.
- Segnalazioni ⚠︎ calcolate sulle mediane **per filtro** (tipo + filtro): con L, R, G, B e Ha nella stessa
  cartella ogni frame si confronta solo con quelli del suo filtro.
- FITS Header in una finestra separata (pulsante "FITS Header…" nella sezione FILE, o menù Window), che segue il
  file selezionato; la sezione è uscita dalla colonna di destra, ora larga almeno 300 punti.

## 1.1.0 — 2026-10-13

- Finestra **Settings** (FitsCull → Settings…, ⌘,) per le segnalazioni: ogni regola (fondo, stelle, FWHM,
  eccentricità) si attiva o disattiva e ha i suoi valori; "Restore Defaults" riporta quelli della 1.0.0.
  Le impostazioni sono salvate nelle preferenze e ricalcolano subito le segnalazioni della sessione aperta.
- Interfaccia interamente in inglese: menù (Review, Open Folder…), barre, inspector, grafici, avvisi,
  segnalazioni, messaggi d'errore e output di `fcanalyze`.
- Cartella di ripiego per i volumi senza Cestino rinominata da `_scartati/` a `_rejected/`.

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
