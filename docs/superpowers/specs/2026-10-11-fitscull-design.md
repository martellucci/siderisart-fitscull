# FitsCull — Documento di progetto (v1)

Data: 2026-10-11 · Stato: **v1.0.0 chiusa** (2026-10-11) · Branch `fitscull-v1`

Questo documento descrive la v1 **come realizzata**. Le decisioni prese durante e dopo l'implementazione sono riassunte in §10 e, in ordine cronologico, in `CHANGELOG.md`.

## 1. Obiettivo

App nativa macOS per **scorrere velocemente una cartella di file FITS astrofotografici**, esaminarli con un'anteprima stretchata e statistiche utili alla selezione, e **spostare nel Cestino i file non idonei**.

Criteri di successo:

- navigazione tra file consecutivi percepita come istantanea (anteprima già pronta grazie al pre-caricamento);
- analisi di un file da 50 MB in meno di 0,5 s da SSD;
- metriche coerenti con PixInsight entro le tolleranze della §9;
- nessun file eliminato senza conferma esplicita.

## 2. Contesto e vincoli

| Voce | Valore |
|---|---|
| Sistema | macOS 26.6, Apple Silicon (arm64) |
| Camera principale | **ZWO ASI2600MM Pro (mono)**, 6248×4176, 16 bit (BITPIX 16, BZERO 32768), filtri (L, …), ~50 MB/file |
| Camere supportate | mono e a colori con matrice Bayer (es. ASI2600MC, usata nello sviluppo iniziale) |
| Software di acquisizione | ZWO ASIAIR Pro, N.I.N.A. 3.x (header con nomi di campo diversi) |
| Posizione dei file | disco interno o esterno, NAS in LAN (SMB) |
| Installazione app | `/Volumes/Dati2/applicazioni/FitsCull.app` |
| Sorgenti | `~/Documents/FitsCull` (repository git) |
| Toolchain | Command Line Tools for Xcode 26.6 (Swift 6.3.3, SDK 26.5) + VS Code con estensione Swift; **Xcode non richiesto** |
| Nota toolchain | I test con Swift Testing richiedono `-F`/`-rpath` verso `/Library/Developer/CommandLineTools/Library/Developer/Frameworks`: inclusi in `scripts/test.sh` |

## 3. Perimetro

**Nella v1**

- Apertura di una cartella singola (non ricorsiva) con file `.fit`, `.fits`, `.fts`.
- FITS non compressi, HDU primaria, `NAXIS = 2`, BITPIX 8/16/32/−32, con BZERO/BSCALE.
- Immagini mono e CFA (Bayer RGGB, BGGR, GRBG, GBRG da `BAYERPAT`).
- Uso principale: frame **light**; dark, flat, bias e dark flat sono letti con statistiche ma **senza metriche stellari**.
- Anteprima stretchata con zoom Adatta / 50% / 100%, statistiche per canale, metriche stellari, vista Sessione, scarto verso il Cestino (singolo o multiplo).

**Escluso dalla v1 (architettura predisposta)**

- XISF.
- Statistiche specifiche per dark e flat (pixel caldi, uniformità).
- FITS compressi (fpack/Rice), cubi a 3 piani, sottocartelle.
- Trascinamento delle soglie direttamente sul grafico; soglie di segnalazione regolabili dall'interfaccia.
- Annullamento in-app dopo lo spostamento nel Cestino (si usa "Ripristina" del Finder).

## 4. Architettura

```
 Cartella (disco / NAS)
        │
        ▼
 ┌──────────────┐   ┌──────────────┐   ┌───────────────┐   ┌──────────────┐
 │ FITSReader   │──▶│ FrameDecoder │──▶│ Statistics    │──▶│              │
 │ header+pixel │   │ colore: 2×2  │   │ per canale    │   │ SessionModel │
 └──────────────┘   │ mono: piena  │   ├───────────────┤   │ elenco file, │
        │           └──────┬───────┘   │ StarDetector  │──▶│ metriche,    │
        ▼                  │           │ (solo light)  │   │ stato ✓/✗    │
 ┌──────────────┐          ▼           └───────────────┘   └──────┬───────┘
 │ FrameMeta    │   ┌──────────────┐   ┌───────────────┐          │
 │ ASIAIR/NINA  │   │ AutoStretch  │──▶│ anteprime     │──────────┤
 │ → campi unici│   │ (tipo STF)   │   │ ±5 file       │          ▼
 └──────────────┘   └──────────────┘   └───────────────┘   Interfaccia SwiftUI
```

Tecnologie: Swift 6, SwiftUI, Swift Charts, Swift Testing. Nessuna dipendenza esterna (i calcoli sono cicli Swift ottimizzati in release; Accelerate non è servito per rispettare i tempi).

### 4.1 Componenti

| Componente | Responsabilità | Ingresso → Uscita |
|---|---|---|
| `FITSReader` | Legge l'header a blocchi da 2880 byte; legge i dati con `Data(contentsOf:options:.mappedIfSafe)` (mappati solo su volumi locali: su un NAS una disconnessione con file mappato farebbe terminare l'app); converte big-endian + BZERO/BSCALE in `Float` | URL → `FITSImage` (header, dimensioni, pixel `[Float]` in ADU, massimo rappresentabile) |
| `FrameMeta` | Normalizza le chiavi dei vari software: `EXPTIME`/`EXPOSURE`, `CCD-TEMP`, `SET-TEMP`, `GAIN`, `OFFSET`, `DATE-OBS`, `OBJECT`, `IMAGETYP`, `BAYERPAT`, `XPIXSZ`, `FOCALLEN`, `XBINNING`, `FILTER`, `AIRMASS`, `INSTRUME`; scala `206,265 × XPIXSZ / FOCALLEN` ″/px (XPIXSZ include già il binning); `ImageType.hasStars` vero solo per light e tipo sconosciuto | header → `FrameMeta` |
| `FrameDecoder` | Colore: superpixel 2×2 (R, media dei due G, B) a metà risoluzione. Mono: piano unico a piena risoluzione. `demosaic`: colore ricostruito a piena risoluzione (bilineare) per lo zoom 100%. `binned2x2`: anteprima dei mono a metà risoluzione. `cfaChannels`: campioni grezzi per colore per le statistiche | `FITSImage` + pattern → `PlanarImage` |
| `Statistics` | Per canale (sotto-piani CFA, G = unione dei due G; mono = L): min, max, media, mediana, σ, rumore = 1,4826·MAD, % saturi (≥ 99,5% del massimo rappresentabile). Mediana e MAD con istogramma a 65 536 classi (O(n)). Fondo cielo = media delle mediane dei canali | piano → `ChannelStats` |
| `StarDetector` | Solo per light/tipo sconosciuto. Luminanza a metà risoluzione (colore) o piena (mono); fondo per tasselli 64×64 interpolato; soglia 5σ; regioni connesse; scarta stelle sature (≥ 95% del massimo sulla luminanza), < 3 px o al bordo. Per ogni stella: centroide, **HFR** interpolato, **FWHM** ed **eccentricità** da momenti secondi pesati con una gaussiana adattiva e correzione analitica del peso (esatta per profili gaussiani). Risultato: numero stelle e mediane | piano + scala → `StarMetrics?` (nil per i file di calibrazione) |
| `AutoStretch` | Come l'AutoSTF di PixInsight: ombre = mediana − 2,8·MAD normalizzato, toni medi per portare la mediana a 0,25; canali collegati / separati; uscita RGBA 8 bit, istogramma visualizzato | `PlanarImage` → `CGImage` |
| `FrameAnalyzer` | Pipeline lettura → metadati → statistiche → stelle; anteprima (sempre a metà risoluzione) e piena risoluzione per lo zoom 100% | URL → `FrameAnalysis` (+ `PreviewSource`) |
| `FolderScanner` | Elenco dei FITS della cartella con header letti (solo i primi blocchi), ordinati per `DATE-OBS` poi nome; i file illeggibili restano in elenco con il motivo | cartella → `[ScannedFrame]` |
| `MetricsCache` | Metriche salvate in `~/Library/Application Support/FitsCull/metrics-v2.json`, chiave percorso + dimensione + data di modifica, thread-safe | `FrameAnalysis` ⇄ JSON |
| `OutlierRules` / `Thresholds` | Segnalazioni rispetto alla sessione (§5.1) e soglie manuali della vista Sessione | analisi → `OutlierFlags` |
| `AnalysisOrder` / `SelectionPolicy` | Ordine di lavoro (file corrente, poi vicini), finestra delle anteprime, navigazione e riconciliazione della selezione col filtro | — |
| `TrashService` | Cestino con `FileManager.trashItem`; ripiego `_scartati/` (senza sovrascrivere) o eliminazione definitiva per i volumi senza Cestino (§6) | URL[] → resoconto per file |
| `SessionModel` (app) | Stato osservabile, analisi in background con 3 lavori in parallelo, anteprime del corrente ±5, piena risoluzione del solo file corrente al 100% | — |

### 4.2 Flusso dei dati

1. ⌘O → scelta cartella → `FolderScanner` legge gli header e ordina i file.
2. `MetricsCache` fornisce subito le metriche già note; gli altri file vengono analizzati in background, prima il file corrente e i vicini.
3. Per ogni file: `FITSReader` → `FrameMeta` + `FrameDecoder` → `Statistics` + `StarDetector` → `SessionModel`; per i vicini anche `AutoStretch` → anteprima.
4. I pixel originali vengono rilasciati subito dopo l'analisi.

## 5. Interfaccia

### 5.1 Vista Revisione (predefinita)

```
┌─ FitsCull ── LDN 1355 ── 124 file · 7 scartati · 6,1 GB ─── [Apri] [Tipo ▾] [Ordina ▾] [Revisione|Sessione]┐
├─────────────────────────────┬─────────────────────────────────┬─────────────────┤
│  #  Ora   Esp Fondo FWHM″ ★ │                                 │ FILE            │
│  1 03:16  300 2933 4.39 6789│      [ anteprima stretchata ]   │ Light_LDN…_0001 │
│▶ 2 03:21  300 2137 4.72 7094│                                 │ Light·300 s·L   │
│  3 03:26  300 1851 4.46 7506│                                 │ 1.40″/px·554 mm │
│ ...                         │                                 │ STATISTICHE     │
│                             ├─────────────────────────────────┤ STELLE          │
│                             │⏮ ◀  2 / 124 ▶ ⏭│Adatta 50% 100%│ ISTOGRAMMA      │
│                             │              ✗ Scarta   🗑      │ [Header FITS ▸] │
├─────────────────────────────┴─────────────────────────────────┴─────────────────┤
│ ←/→ naviga · X scarta · Spazio adatta/100% · ⌘⌫ cestino · S stretch · L canali   │
│                                              [Sposta scartati nel Cestino (7)]   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- Lista a sinistra: #, ora, esposizione, fondo, FWHM″ (in px se la scala non è nota), stelle, eccentricità, stato; ordinamento dal menu "Ordina" (Data / FWHM / Stelle / Fondo).
- **Segnalazioni** (arancione nella lista, ⚠︎ nello stato, riga nel pannello; mai scarto automatico):
  - **fondo alto**: fondo > +30% della mediana di sessione **e** > 3000 ADU;
  - **poche stelle**: stelle < 50% della mediana di sessione;
  - **FWHM alta**: FWHM > mediana di sessione + 25%;
  - **stelle allungate**: eccentricità > 0,75 (soglia fissa; ≈ 0,68–0,69 in PixInsight).
- Pannello destro: dati del file, statistiche per canale, metriche stellari (assenti per i file di calibrazione), istogramma visualizzato, header completo espandibile.
- Barra sotto l'immagine: primo / precedente / posizione / successivo / ultimo; zoom **Adatta**, **50%** (anteprima a metà risoluzione, un pixel per pixel dello schermo, immediato) e **100%** (pixel reali del sensore, colore ricostruito a piena risoluzione solo per il file corrente, ≈ 0,75 s; nel frattempo anteprima ingrandita 2×; lo zoom resta attivo cambiando file); Scarta / Ripristina; cestino del solo file corrente **con conferma**, poi passa al successivo.
- File in errore: messaggio con il motivo e pulsante **Riprova**.

### 5.2 Vista Sessione

Grafici (Swift Charts) di FWHM″, numero stelle, fondo ed eccentricità in funzione dell'ora. Soglie manuali (FWHM max, stelle min, fondo max, eccentricità max) visualizzate come linee; pulsante "Segna fuori soglia" (marca come scartati, non sposta). Clic su un punto → apre quel file in Revisione. Le soglie su stelle, FWHM ed eccentricità non si applicano ai file di calibrazione.

### 5.3 Tastiera

| Tasto | Azione |
|---|---|
| ←/→, ↑/↓ | file precedente / successivo |
| Inizio / Fine | primo / ultimo file |
| X | scarta / ripristina il file corrente |
| Spazio | alterna Adatta / 100% |
| ⌘0 | zoom Adatta |
| S | stretch attivo / disattivo |
| L | canali collegati / separati |
| ⌘⌫ | sposta il file corrente nel Cestino (con conferma) |
| ⇧⌘⌫ | sposta tutti gli scartati nel Cestino (con conferma) |
| ⌘O | apri cartella |
| ⌘1 / ⌘2 | Revisione / Sessione |

## 6. Errori e casi limite

- **Volumi senza Cestino** (tipico delle condivisioni SMB del NAS): dialogo con due scelte: spostare in `_scartati/` nella stessa cartella (predefinita, non sovrascrive), oppure eliminare definitivamente (seconda conferma con numero di file e dimensione). Mai eliminazioni silenziose. Verificato dall'utente sul NAS.
- **File non supportato** (compresso, NAXIS ≠ 2, BITPIX −64, header danneggiato, file troncato): riga in errore con il motivo; gli altri file funzionano.
- **File scomparso / NAS scollegato**: lettura non mappata sui volumi di rete, quindi niente crash; stato "errore" con pulsante Riprova; l'app resta reattiva.
- **Header incompleto** (manca focale o pixel): FWHM mostrata solo in pixel.
- **Cartella vuota o senza FITS**: messaggio esplicito.
- **Selezione nascosta dal filtro Tipo**: la selezione passa al primo file visibile (evita ricaricamenti continui).
- **Memoria**: anteprime a metà risoluzione (~26 MB ciascuna, corrente ±5 ≈ 300 MB); la piena risoluzione è trattenuta solo per il file corrente con zoom 100%.

## 7. Distribuzione

Pacchetto Swift (SwiftPM) in `~/Documents/FitsCull`:

- `FitsCullCore` (libreria): tutto il codice non grafico, interamente testabile;
- `FitsCull` (eseguibile SwiftUI): interfaccia e ciclo di vita dell'app;
- `fcanalyze` (eseguibile da riga di comando): tabella delle metriche e dei tempi per file, per verifiche e confronti;
- `scripts/test.sh`: `swift test` con i flag della toolchain;
- `scripts/build-app.sh`: compilazione release, bundle `FitsCull.app` (`Info.plist` versione 1.0.0, icona `.icns` generata da `scripts/make-icon.sh`), firma ad-hoc, copia in `/Volumes/Dati2/applicazioni/`.

Nessuna distribuzione su App Store. Al primo avvio: clic destro → Apri (firma ad-hoc).

## 8. Test

97 test Swift Testing, eseguibili con `scripts/test.sh`:

- `FITSReader`: FITS sintetici (BITPIX 8/16/32/−32, BZERO/BSCALE), cubi, HDU vuota, BITPIX −64, file troncati, lettura del solo header, lettura non mappata.
- `FrameMeta`: header reali ASIAIR e N.I.N.A., scala, tipi di immagine e `hasStars`.
- `FrameDecoder`: superpixel per i quattro pattern, ricostruzione a piena risoluzione, riduzione 2×2, canali CFA.
- `Statistics` / `RobustStats`: valori noti, valori non finiti, saturi, dati interi estesi.
- `StarDetector`: campi sintetici di gaussiane (numero esatto, FWHM ±5%, eccentricità), fondo con gradiente, campo vuoto, stelle sature, immagini minuscole.
- `FrameAnalyzer`: file a colori, mono, di calibrazione (nessuna metrica stellare), senza tipo, anteprima e piena risoluzione.
- `FolderScanner`, `MetricsCache` (file modificati, NaN, analisi senza stelle, versione v2), `OutlierRules` (tutte le soglie §5.1), `TrashService` (Cestino simulato non disponibile, `_scartati/`, eliminazione), `AnalysisOrder`, `SelectionPolicy`.

## 9. Validazione su dati reali

Risultati completi in `docs/validation-2026-10-11.md`. Sintesi:

| Metrica | Riferimento | Tolleranza | Risultato |
|---|---|---|---|
| Fondo (media, mediana) | PixInsight | ±1% | ✓ coincide (verifica dell'utente) |
| FWHM | PixInsight FWHMEccentricity (Moffat4), 5 light mono L | ±15% | ✓ FitsCull +9,1…+11% in modo costante; stesso ordine e stessi salti tra i frame |
| Eccentricità | idem | — | FitsCull +6…+12% in modo costante (soglia 0,75 tarata di conseguenza) |
| Numero stelle | idem | stesso andamento | ✓ stesso andamento; valore assoluto +32…+40% (criteri di conteggio diversi) |
| Tempo di analisi | — | < 0,5 s/file da SSD | ✓ 0,21–0,32 s/file sui file a colori ASI2600MC; mono giudicato "ottimo" dall'utente, da misurare con `fcanalyze` |
| Zoom 100% | — | — | ≈ 0,75 s (lettura e ricostruzione ≈ 0,4 s + stretch ≈ 0,35 s) |

Nota metodologica: le misure di PixInsight su file **CFA non debayerizzati** non sono confrontabili (FWHM circa dimezzata); per i file a colori usare un Debayer prima del confronto.

## 10. Stato della v1 e lavori futuri

Decisioni prese dopo il piano iniziale (dettagli in `CHANGELOG.md`): metriche stellari solo per i light; barra di navigazione e zoom 50%/100% reale; cestino del file corrente con conferma (⌘⌫) e multiplo su ⇧⌘⌫; anteprime mono ridotte 2×2; soglie di segnalazione tolleranti scelte dall'utente (eccentricità 0,75; FWHM +25%; fondo > 3000 ADU e +30%).

Rinviati alla v2 (non bloccanti):

- S e L rileggono dal disco il file corrente e i vicini (lento sul NAS).
- Il dialogo "Cestino non disponibile" raccoglie anche file falliti per altri motivi e mostra un solo motivo.
- Mediana/MAD a istogramma: errore fino a ≈ ±4% sulla MAD con dati a 16 bit molto estesi.
- Ordinamento cronologico non transitivo con file con e senza data mescolati.
- Valori NAXIS assurdi in header danneggiati possono interrompere l'app.
- "Riprova" non aggiorna dimensione e data del file; manca "Riprova tutti".
- Motivo dell'errore visibile solo come suggerimento nella lista; i FITS compressi senza tipo sono nascosti dal filtro Light.
- Nessuna indicazione dell'unità quando la FWHM ripiega sui pixel.
- Le scorciatoie senza modificatori agiscono anche nei campi delle soglie.
- La cache delle metriche non viene mai ripulita.
- I segni di scarto si perdono senza avviso cambiando cartella o chiudendo l'app.
- Concorrenza fissa a 3; nessun trascinamento col mouse nello zoom.

Idee per la v2: XISF; statistiche per dark e flat; soglie di segnalazione regolabili (anche per filtro); adattamento Moffat per FWHM allineate a PixInsight; misura dei tempi su file mono reali.
