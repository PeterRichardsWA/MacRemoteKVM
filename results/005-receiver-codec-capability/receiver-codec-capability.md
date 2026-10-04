# Experiment 005 Result: Receiver Codec Capability

## Machine

- Host name: dadimacpro.local
- macOS: Version 15.8 (Build 24H23)
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
- Processor count: 36
- Active processor count: 36
- Physical memory: 128.00 GB

## Display Hardware

```text
Graphics/Displays:

    Radeon Pro Vega 64:

      Chipset Model: Radeon Pro Vega 64
      Type: GPU
      Bus: PCIe
      PCIe Lane Width: x16
      VRAM (Total): 16 GB
      Vendor: AMD (0x1002)
      Device ID: 0x6860
      Revision ID: 0x0000
      ROM Revision: 113-D0500D-114
      VBIOS Version: 113-D05001A1XT-018
      Option ROM Version: 113-D05001A1XT-018
      EFI Driver Version: 01.01.114
      Metal Support: Metal 3
      Displays:
        iMac:
          Display Type: Built-In Retina LCD
          Resolution: Retina 5K (5120 x 2880)
          Framebuffer Depth: 30-Bit Color (ARGB2101010)
          Main Display: Yes
          Mirror: Off
          Online: Yes
          Automatically Adjust Brightness: Yes
          Connection Type: Internal

```

## Hardware Decode Support

| Codec | FourCC | Hardware Decode Supported |
| --- | --- | --- |
| H.264 / AVC | `avc1` | yes |
| HEVC / H.265 | `hvc1` | yes |
| HEVC with Alpha | `muxa` | yes |
| Apple ProRes 422 Proxy | `apco` | no |
| Apple ProRes 422 LT | `apcs` | no |
| Apple ProRes 422 | `apcn` | no |
| Apple ProRes 422 HQ | `apch` | no |
| JPEG | `jpeg` | no |
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
| deph | `deph` | Apple Depth (HEVC)-Apple HEVC (SW) | no |
| dish | `dish` | Apple Disparity (HEVC)-Apple HEVC (SW) | no |
| h263 | `h263` | Apple H.263 (SW) | no |
| avc1 | `avc1` | Apple H.264 (HW) | yes |
| avc1 | `avc1` | Apple H.264 (SW) | no |
| hvc1 | `hvc1` | Apple HEVC (AVE) | yes |
| hvc1 | `hvc1` | Apple HEVC (HW) | yes |
| hvc1 | `hvc1` | Apple HEVC (SW) | no |
| jpeg | `jpeg` | Apple JPEG | no |
| muxa | `muxa` | Apple Muxed Alpha-Apple HEVC (HW) | yes |
| muxa | `muxa` | Apple Muxed Alpha-Apple HEVC (SW) | no |

## Interpretation

Run this probe on the actual Viewer iMac. Codec choices should be filtered by hardware decode support on that machine, not by sender-side encode speed alone.
