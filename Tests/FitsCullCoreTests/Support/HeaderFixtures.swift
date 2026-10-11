import Foundation

/// Righe reali (abbreviate) degli header dei file dell'utente.
enum HeaderFixtures {
    static let asiair: [String] = [
        "SIMPLE  =                    T / file does conform to FITS standard",
        "BITPIX  =                   16 / number of bits per data pixel",
        "NAXIS   =                    2 / number of data axes",
        "NAXIS1  =                 6248 / length of data axis 1",
        "NAXIS2  =                 4176 / length of data axis 2",
        "BZERO   =                32768 / offset data range to that of unsigned short",
        "OFFSET  =                   50 / camera offset",
        "FOCALLEN=                  412 / Focal length of telescope in mm",
        "SET-TEMP=                  -20 / CCD temperature setpoint in degrees C",
        "XBINNING=                    1 / Camera X Bin",
        "XPIXSZ  =     3.75999999046326 / pixel size in microns (with binning)",
        "IMAGETYP= 'Light   '           / Type of image",
        "EXPOSURE=                 120. / Exposure time in seconds",
        "EXPTIME =                 120. / Exposure time in seconds",
        "CCD-TEMP=    -20.1000003814697 / sensor temperature in C",
        "DATE-OBS= '2025-12-12T21:36:14.004013' / Image exposure start time",
        "INSTRUME= 'ZWO ASI2600MC Pro'  / Camera model",
        "BAYERPAT= 'RGGB    '           / Bayer pattern",
        "GAIN    =                  100 / Gain Value",
        "OBJECT  = 'M 42    '           / name or catalog number of object being imaged",
    ]

    static let nina: [String] = [
        "SIMPLE  =                    T / C# FITS",
        "BITPIX  =                   16",
        "NAXIS   =                    2 / Dimensionality",
        "NAXIS1  =                 6248",
        "NAXIS2  =                 4176",
        "BZERO   =                32768",
        "IMAGETYP= 'DARK'               / Type of exposure",
        "EXPOSURE=                300.0 / [s] Exposure duration",
        "EXPTIME =                300.0 / [s] Exposure duration",
        "DATE-OBS= '2026-03-20T17:25:01.3361782' / Time of observation (UTC)",
        "XBINNING=                    1 / X axis binning factor",
        "GAIN    =                  100 / Sensor gain",
        "OFFSET  =                   50 / Sensor gain offset",
        "XPIXSZ  =                 3.76 / [um] Pixel X axis size",
        "INSTRUME= 'ZWO ASI2600MC Pro'  / Imaging instrument name",
        "SET-TEMP=                -10.0 / [degC] CCD temperature setpoint",
        "CCD-TEMP=                -10.0 / [degC] CCD temperature",
        "BAYERPAT= 'RGGB'               / Sensor Bayer pattern",
        "FOCALLEN=                800.0 / [mm] Focal length",
        "AIRMASS =     1.58937310257203 / Airmass at frame center (Gueymard 1993)",
        "ROWORDER= 'TOP-DOWN'           / FITS Image Orientation",
    ]

    static func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }
}
