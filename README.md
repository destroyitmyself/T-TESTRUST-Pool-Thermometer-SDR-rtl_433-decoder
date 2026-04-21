# T-TESTRUST-Pool-Thermometer-SDR-rtl_433-decoder

Cheap Amazon wireless pool thermometer. Wanted to record the info, this is just a start.

https://www.amazon.com/Wireless-Pool-Thermometer-Waterproof-Temperature/dp/B0F5VNDLWD/

## What you need

- **RTL-SDR dongle** I used the Nooelec NESDR SMArt v5
- **Windows PC.** Scripts are PowerShell.
- **[rtl_433](https://github.com/merbanan/rtl_433)** installed to `C:\rtl_433`.
- **[Zadig](https://zadig.akeo.ie/)** to swap in the WinUSB driver, one-time.

## Quick start

```powershell
cd C:\rtl_433
.\pool-listen.ps1
```

Within ~50 seconds you'll see:

```
2026-04-20 21:15:38  id=95c0  raw=154   15.4 C /  59.7 F
```

Note your sensor's `id=` value. Once you know it, filter to just that sensor:

```powershell
.\pool-listen.ps1 -SensorId 95c0
```

Screen output only. No file logging. Ctrl+C to stop.

## Protocol

- **Carrier**: 434.1 MHz (not 433.92)
- **Modulation**: OOK Pulse Position Modulation
- **Packet**: 45 bits, sent 8 times per transmission, every ~50 s
- **Pulse width**: 484 us; short gap 1956 us; long gap 3908 us; reset 8784 us

### Packet layout (45 bits, MSB first)

```
IIIIIIII IIIIIIII ...TTTTT TTTT.... ........ CCCCCCCCC
[byte 0] [byte 1] [byte 2] [byte 3] [byte 4] [b5 top]
```

- **Bits 0-15** - 16-bit sensor ID. Constant until batteries are replaced.
- **Bits 16-18** - reserved, always zero.
- **Bits 19-27** - temperature as C x 10, unsigned 9-bit. Confirmed empirically up to 30 C / 86 F; manual rates to 50 C / 122 F.
- **Bits 28-35** - reserved, always zero.
- **Bits 36-44** - 9-bit trailer, likely CRC. Not reverse-engineered.

### Raw flex decoder (non-Windows)

```
rtl_433 -f 434108000 -s 1024000 -R 0 \
  -X 'n=pool,m=OOK_PPM,s=1956,l=3908,g=3928,r=8796,bits>=40' \
  -F json
```

Extract bits 19-27 from the 12-hex `data` field and divide by 10 for C.

## Files

| File | What it does |
|------|--------------|
| `pool-listen.ps1` | The listener. Discovery mode with no args, targeted with `-SensorId`. |

## Credits

Reverse-engineered with [Claude](https://claude.ai) in about an hour, using [rtl_433](https://github.com/merbanan/rtl_433) and [SDR++](https://www.sdrpp.org/).
