# FitsCull — Documento di progetto (v1)

Data: 2026-10-11 · Stato: in revisione

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
| Camera principale | ZWO ASI2600MC Pro, 6248×4176, 16 bit (BITPIX 16, BZERO 32768), Bayer RGGB, ~50 MB/file |
| Software di acquisizione | ZWO ASIAIR Pro, N.I.N.A. 3.x (header con nomi di campo diversi) |
| Posizione dei file | disco interno o esterno, NAS in LAN (SMB) |
| Installazione app | `/Volumes/Dati2/applicazioni/FitsCull.app` |
| Sorgenti | `~/Documents/FitsCull` (repository git) |
| Toolchain | Command Line Tools for Xcode 26.6 (Swift 6.3.3, SDK 26.5) + VS Code con estensione Swift; **Xcode non richiesto** |
| Nota toolchain | I test con Swift Testing richiedono `-F`/`-rpath` verso `/Library/Developer/CommandLineTools/Library/Developer/Frameworks`: inclusi negli script |

## 3. Perimetro

**Nella v1**

- Apertura di una cartella singola (non ricorsiva) con file `.fit`, `.fits`, `.fts`.
- FITS non compressi, HDU primaria, `NAXIS = 2`, BITPIX 8/16/32/−32, con BZERO/BSCALE.
- Immagini mono e CFA (Bayer RGGB, BGGR, GRBG, GBRG da `BAYERPAT`).
- Uso principale: frame **light**.
- Anteprima, statistiche per canale, metriche stellari, vista Sessione, scarto verso il Cestino.

**Escluso dalla v1 (architettura predisposta)**

- XISF (nuovo lettore dietro la stessa interfaccia `ImageSource`).
- Statistiche specifiche per dark e flat (pixel caldi, uniformità).
- FITS compressi (fpack/Rice), cubi a 3 piani, sottocartelle.
- Trascinamento delle soglie direttamente sul grafico.
- Annullamento in-app dopo lo spostamento nel Cestino (si usa "Ripristina" del Finder).

## 4. Architettura

```
 Cartella (disco / NAS)
        │
        ▼
 ┌──────────────┐   ┌──────────────┐   ┌───────────────┐   ┌──────────────┐
 │ FITSReader   │──▶│ FrameDecoder │──▶│ Statistics    │──▶│              │
 │ header+pixel │   │ Bayer 2×2 →  │   │ per canale    │   │ SessionStore │
 └──────────────┘   │ RGB metà ris.│   ├───────────────┤   │ elenco file, │
        │           └──────┬───────┘   │ StarDetector  │──▶│ metriche,    │
        ▼                  │           └───────────────┘   │ stato ✓/✗    │
 ┌──────────────┐          ▼                               └──────┬───────┘
 │ FrameMeta    │   ┌──────────────┐   ┌───────────────┐          │
 │ ASIAIR/NINA  │   │ AutoStretch  │──▶│ PreviewCache  │──────────┤
 │ → campi unici│   │ (tipo STF)   │   │ ±5 file       │          ▼
 └──────────────┘   └──────────────┘   └───────────────┘   Interfaccia SwiftUI
```

Tecnologie: Swift 6, SwiftUI, Accelerate (vDSP), Swift Charts, Swift Testing. Nessuna dipendenza esterna.

### 4.1 Componenti

| Componente | Responsabilità | Ingresso → Uscita |
|---|---|---|
| `FITSReader` | Legge l'header a blocchi da 2880 byte, legge i dati con `Data(contentsOf:options:.mappedIfSafe)` (mappati solo su volumi locali: su un NAS una disconnessione con file mappato farebbe terminare l'app), converte big-endian + BZERO/BSCALE in `Float` | URL → `FITSImage` (header grezzo, larghezza, altezza, pixel `[Float]` in ADU) |
| `FrameMeta` | Normalizza le chiavi dei vari software: `EXPTIME`/`EXPOSURE`, `CCD-TEMP`, `SET-TEMP`, `GAIN`, `OFFSET`, `DATE-OBS`, `OBJECT`, `IMAGETYP`, `BAYERPAT`, `XPIXSZ`, `FOCALLEN`, `XBINNING`, `FILTER`, `AIRMASS`; calcola la scala `206,265 × XPIXSZ / FOCALLEN` ″/px (XPIXSZ include già il binning) | header → `FrameMeta` (campi opzionali) |
| `FrameDecoder` | Superpixel 2×2: per ogni cella Bayer R, media dei due G, B → immagine RGB a metà risoluzione; per mono restituisce un solo canale | `FITSImage` + pattern → `PlanarImage` (1 o 3 piani `Float`) |
| `Statistics` | Per canale (dai sotto-piani CFA, G = unione dei due G): min, max, media, mediana, σ, rumore = 1,4826·MAD, % saturi (≥ 99,5% del massimo rappresentabile dal BITPIX dopo BZERO). Fondo cielo = mediana | piano → `ChannelStats` |
| `StarDetector` | Su luminanza a metà risoluzione: fondo per tasselli 64×64 (mediana, interpolato) sottratto; soglia 5σ del rumore; massimi locali + regione connessa; scarta stelle sature, troppo piccole (< 3 px) o al bordo; per ogni stella centroide, flusso, **HFR**, momenti secondi → **FWHM** = 2,3548·√((σx²+σy²)/2) ed **eccentricità** = √(1 − b²/a²). Risultato: numero stelle e mediane di HFR, FWHM (px e ″, scala ×2 per il superpixel), eccentricità | `PlanarImage` + scala → `StarMetrics` |
| `AutoStretch` | Trasferimento di toni medi come l'STF di PixInsight: ombre = mediana − 2,8·MAD normalizzato, toni medi per portare la mediana a 0,25; modalità canali collegati / separati; uscita 8 bit | `PlanarImage` → `CGImage` |
| `AnalysisQueue` | Analizza tutti i file in background con 2–4 operazioni in parallelo (configurabile, prudente per NAS); priorità al file corrente e ai vicini ±3 | elenco URL → aggiornamenti al `SessionStore` |
| `PreviewCache` | Conserva le anteprime `CGImage` per il corrente ±5 file (~26 MB ciascuna, tetto ~300 MB) | — |
| `MetricsCache` | Salva le metriche su disco in `~/Library/Application Support/FitsCull/` con chiave percorso + dimensione + data di modifica; riapertura di una cartella senza ricalcolo | `FrameMetrics` ⇄ JSON |
| `SessionStore` | Stato osservabile: elenco frame, metriche, stato (in attesa / analizzato / errore / scartato), mediane della sessione, regole sui valori anomali | — |
| `TrashService` | Sposta i file scartati con `FileManager.trashItem`; gestisce i volumi senza Cestino (§6) | URL[] → risultato per file |

### 4.2 Flusso dei dati

1. ⌘O → scelta cartella → elenco dei file FITS ordinati per `DATE-OBS` (fallback: nome).
2. `MetricsCache` fornisce subito le metriche già note; gli altri file vanno in `AnalysisQueue`.
3. Per ogni file: `FITSReader` → `FrameMeta` + `FrameDecoder` → `Statistics` + `StarDetector` → `SessionStore`; se il file è vicino a quello corrente anche `AutoStretch` → `PreviewCache`.
4. I pixel originali vengono rilasciati subito dopo l'analisi.

## 5. Interfaccia

### 5.1 Vista Revisione (predefinita)

```
┌─ FitsCull ── Dati2 › 2025-12-12 M42 ────────────────────────────────────────────┐
│ [Apri cartella] [Tipo: Light ▾] [Ordina: Data ▾]   124 file · 7 scartati · 6,1 GB│
├─────────────────────────────┬─────────────────────────────────┬─────────────────┤
│  #  Ora   Fondo FWHM″ ★  Ecc│                                 │ FILE            │
│ 39 22:35  1851 4.0  405 .41 │                                 │ Light_M42_0040  │
│▶40 22:37  1855 3.8  401 .43 │      [ anteprima stretchata ]   │ 120s G100 -20°C │
│ 41 22:39  2604 8.7  121 .71✗│                                 │ 1.88″/px  RGGB  │
│ ...                         │                                 │ STATISTICHE R G B│
│                             │                                 │ ISTOGRAMMA      │
│                             │                                 │ [Header FITS ▸] │
├─────────────────────────────┴─────────────────────────────────┴─────────────────┤
│ ←/→ naviga  X scarta  Spazio 1:1  S stretch  ⌘⌫ sposta scartati nel Cestino (7)  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- Lista a sinistra: tabella ordinabile (#, ora, esposizione, fondo, FWHM″, stelle, eccentricità, stato).
- Valori anomali evidenziati rispetto alla mediana di sessione: fondo > +30%, stelle < −50%, FWHM > mediana + 2σ, eccentricità > 0,6. Solo segnalazione, nessuno scarto automatico.
- Pannello destro: dati del file, statistiche per canale, istogramma, header completo espandibile.
- Barra sotto l'immagine: primo / precedente / posizione "12 / 124" / successivo / ultimo; zoom Adatta, 50% (un pixel dell'anteprima a metà risoluzione per pixel dello schermo) e 100% (pixel reali del sensore, colore ricostruito a piena risoluzione solo per il file corrente, ~0,75 s; nel frattempo anteprima ingrandita 2×); Scarta/Ripristina; cestino del solo file corrente, **con conferma**, poi passa al successivo.
- Metriche stellari solo per light e file senza tipo; per dark, flat, bias e dark flat sono assenti ("–").

### 5.2 Vista Sessione

Grafici (Swift Charts) di FWHM″, numero stelle, fondo ed eccentricità in funzione dell'ora. Soglie impostabili numericamente e visualizzate come linee; pulsante "Segna fuori soglia" (marca come scartati, non sposta). Clic su un punto → apre quel file in Revisione.

### 5.3 Tastiera

| Tasto | Azione |
|---|---|
| ←/→, ↑/↓ | file precedente / successivo |
| X | scarta / ripristina il file corrente |
| Spazio | alterna Adatta / 100% |
| ⌘0 | zoom Adatta |
| Inizio / Fine | primo / ultimo file |
| S | stretch attivo / disattivo |
| L | canali collegati / separati |
| ⌘⌫ | sposta il file corrente nel Cestino (con conferma) |
| ⇧⌘⌫ | sposta tutti gli scartati nel Cestino (con conferma) |
| ⌘O | apri cartella |
| ⌘1 / ⌘2 | Revisione / Sessione |

## 6. Errori e casi limite

- **Volumi senza Cestino** (tipico delle condivisioni SMB del NAS): se `trashItem` fallisce per questo motivo, dialogo con due scelte: spostare in `_scartati/` nella stessa cartella, oppure eliminare definitivamente (seconda conferma con numero di file e dimensione). Mai eliminazioni silenziose.
- **File non supportato** (compresso, NAXIS ≠ 2, BITPIX −64, header danneggiato): riga marcata "non supportato" con il motivo; la navigazione lo mostra ma senza anteprima.
- **File scomparso / NAS scollegato**: stato "errore" con pulsante Riprova; l'app resta reattiva.
- **Header incompleto** (manca focale o pixel): FWHM mostrata solo in pixel.
- **Cartella vuota o senza FITS**: messaggio esplicito.
- **Memoria**: solo `PreviewCache` limitata; nessun buffer full-res trattenuto.

## 7. Distribuzione

Pacchetto Swift (SwiftPM) in `~/Documents/FitsCull`:

- `FitsCullCore` (libreria): tutto il codice non grafico (§4.1 tranne l'interfaccia), interamente testabile;
- `FitsCull` (eseguibile SwiftUI): interfaccia e ciclo di vita dell'app, dipende da `FitsCullCore`;
- `scripts/test.sh`: `swift test` con i flag della toolchain;
- `scripts/build-app.sh`: `swift build -c release`, assemblaggio del bundle `FitsCull.app` (`Info.plist`, icona `.icns` creata con `iconutil`), firma ad-hoc (`codesign -s -`), copia in `/Volumes/Dati2/applicazioni/`.

Nessuna distribuzione su App Store.

## 8. Test

Swift Testing, eseguibili da terminale con `scripts/test.sh`:

- `FITSReader`: FITS sintetici generati nei test (BITPIX 8/16/32/−32, BZERO/BSCALE), header reale ASIAIR e N.I.N.A. come fixture, header danneggiati.
- `FrameMeta`: mappatura delle chiavi dei due software, calcolo scala (ASI2600MC + 412 mm → 1,88″/px).
- `FrameDecoder`: matrici CFA note per tutti e quattro i pattern.
- `Statistics`: array con valori noti (mediana, MAD, saturi).
- `StarDetector`: campi sintetici di gaussiane con numero, FWHM ed eccentricità noti, con rumore; tolleranza ±5% su FWHM, conteggio esatto per stelle ben separate.
- `AutoStretch`: mediana in uscita ≈ 0,25.
- `SessionStore`: regole dei valori anomali.
- `TrashService`: su cartella temporanea; percorso di ripiego simulato.

## 9. Validazione su dati reali

Su almeno 10 light reali della ASI2600MC, confronto con PixInsight:

| Metrica | Riferimento PixInsight | Tolleranza |
|---|---|---|
| Fondo (mediana per canale) | Statistics sui canali CFA | ±1% |
| Rumore | Statistics (MAD × 1,4826) | ±5% |
| FWHM | SubframeSelector | ±15% |
| Numero stelle | SubframeSelector | stesso andamento tra i frame (correlazione), non valore assoluto |
| Tempo di analisi | — | < 0,5 s/file da SSD |
