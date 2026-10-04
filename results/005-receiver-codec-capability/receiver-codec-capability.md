# Experiment 005 Result: Receiver Codec Capability

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max
- Processor count: 10
- Active processor count: 10
- Physical memory: 64.00 GB

## Display Hardware

```text
Graphics/Displays:

    Apple M1 Max:

      Chipset Model: Apple M1 Max
      Type: GPU
      Bus: Built-In
      Total Number of Cores: 32
      Vendor: Apple (0x106b)
      Metal Support: Metal 4
      Displays:
        Color LCD:
          Display Type: Built-in Liquid Retina XDR Display
          Resolution: 3456 x 2234 Retina
          Main Display: Yes
          Mirror: Off
          Online: Yes
          Automatically Adjust Brightness: No
          Connection Type: Internal

```

## Hardware Decode Support

| Codec | FourCC | Hardware Decode Supported |
| --- | --- | --- |
| H.264 / AVC | `avc1` | yes |
| HEVC / H.265 | `hvc1` | yes |
| HEVC with Alpha | `muxa` | yes |
| Apple ProRes 422 Proxy | `apco` | yes |
| Apple ProRes 422 LT | `apcs` | yes |
| Apple ProRes 422 | `apcn` | yes |
| Apple ProRes 422 HQ | `apch` | yes |
| JPEG | `jpeg` | yes |
| AV1 | `av01` | no |

## Available VideoToolbox Encoders

| Codec | FourCC | Encoder | Hardware |
| --- | --- | --- | --- |
| 0x00000018 | `0x00000018` | Apple 24-bit RGB | no |
| 0x00000020 | `0x00000020` | Apple 32-bit ARGB | no |
| apcn | `apcn` | Apple ProRes 422 | no |
| apch | `apch` | Apple ProRes 422 HQ | no |
| apcs | `apcs` | Apple ProRes 422 LT | no |
| apco | `apco` | Apple ProRes 422 Proxy | no |
| ap4h | `ap4h` | Apple ProRes 4444 | no |
| ap4x | `ap4x` | Apple ProRes 4444 XQ | no |
| apcn | `apcn` | AppleProResHW 422 | yes |
| apch | `apch` | AppleProResHW 422 HQ | yes |
| apcs | `apcs` | AppleProResHW 422 LT | yes |
| apco | `apco` | AppleProResHW 422 Proxy | yes |
| ap4h | `ap4h` | AppleProResHW 4444 | yes |
| ap4x | `ap4x` | AppleProResHW 4444 XQ | yes |
| deph | `deph` | Apple Depth (HEVC)-Apple HEVC (HW) | yes |
| deph | `deph` | Apple Depth (HEVC)-Apple HEVC (SW) | no |
| dish | `dish` | Apple Disparity (HEVC)-Apple HEVC (HW) | yes |
| dish | `dish` | Apple Disparity (HEVC)-Apple HEVC (SW) | no |
| h263 | `h263` | Apple H.263 (SW) | no |
| avc1 | `avc1` | Apple H.264 (HW) | yes |
| avc1 | `avc1` | Apple H.264 (SW) | no |
| hvc1 | `hvc1` | Apple HEVC (HW) | yes |
| hvc1 | `hvc1` | Apple HEVC (SW) | no |
| jpeg | `jpeg` | Apple JPEG | no |
| jpeg | `jpeg` | JPEG (HW) | yes |
| muxa | `muxa` | Apple Muxed Alpha-Apple HEVC (HW) | yes |
| muxa | `muxa` | Apple Muxed Alpha-Apple HEVC (SW) | no |

## Interpretation

Run this probe on the actual Viewer iMac. Codec choices should be filtered by hardware decode support on that machine, not by sender-side encode speed alone.
