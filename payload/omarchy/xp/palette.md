# Windows XP palette, sampled

Every value here was read from Microsoft's own files, not remembered. Two kinds
of source, cited per value:

- **px** — a pixel read with ImageMagick (`magick FILE -format '%[hex:p{x,y}]' info:`)
  from the visual-style bitmaps under `assets/graphics/` (pixel-exact; these are
  what XP itself tiles/stretches) or from a reference screenshot in
  `assets/reference/`.
- **ini** — the value authored in the scheme's style sheet
  (`assets/graphics/<style>/TEXTFILE/NORMAL<SCHEME>_INI.bin`, UTF-16LE; read with
  `iconv -f utf-16le`) or XP's default registry (`assets/reference/hivedef.inf`).

Bitmap prefixes: `luna/BITMAP/BLUE_*` = Luna Blue, `HOMESTEAD_*` = Olive Green,
`METALLIC_*` = Silver, `royale/BITMAP/ROYALE_*`, `zune/BITMAP/DEFAULT_*`.
Gradients are listed **top row first, one entry per pixel row** at 96 dpi
(`#RRGGBB×n` = n identical rows), so they can be reproduced 1:1 or turned into
`GradientStop`s by row/height. A `BorderImage` over the bitmap itself (with the
INI's `SizingMargins`) is more faithful than any gradient.

**Cross-check.** The Luna Blue, Olive and Silver taskbar columns below were also
read from real XP x64 screenshots at 1:1
(`reference/taskbar-*-1920x974.png`, column x=1000, rows 944–973) and match the
bitmaps row for row; the tray fills (`#0D8DEA`, `#EAE2B2`, `#CBCCDA` at
x=1900,y=958) match too. Royale and Zune only have downscaled 640x480 captures
(`reference/desktop-{royale,zune}.png`); their inactive-caption and taskbar ramps
agree in direction and range with the bitmaps.

**Caution.** The Royale and Zune INIs contain copy-pasted Luna `FillColorHint`s
(Zune's say "blue"); for those two schemes trust the pixel columns, not the hints.

## Common to all schemes

| Element | Value | Source |
|---|---|---|
| Tooltip / balloon fill | `#FFFFE1` | ini: `hivedef.inf` `HKCU\Control Panel\Colors InfoWindow = 255 255 225` |
| Tooltip / balloon text | `#000000` | ini: `hivedef.inf` `InfoText = 0 0 0` (border is 1px black — standard XP, not stored as a colour) |
| Clock font | Tahoma 8 pt | ini: `[TrayNotify::Clock] Font` (all five) |
| Start label font | Franklin Gothic Medium 14, *italic*, white, 2,2 continuous shadow | ini: `[Start::Button]` (not Trebuchet bold) |
| Start menu user name | Franklin Gothic Medium 14, white | ini: `[StartPanel.UserPane]` |
| Window client | `#FFFFFF` | ini: `[SysMetrics] Window` |
| Transparency keys | `#FF00FF` (most bitmaps), `#FF0000` (tray, where `TransparentColor = 255 0 0`) | ini / px |

## Luna Blue

| Element | Value | Source |
|---|---|---|
| Title bar active | `#0054E3` → `#3D95FF` | ini: `ActiveCaption`, `GradientActiveCaption` |
| Title bar inactive | `#7A96DF` → `#9DB9EB`; text `#D8E4F8` | ini: `InactiveCaption`, `GradientInactiveCaption`, `InactiveCaptionText` |
| Caption text | `#FFFFFF`, shadow `#0A1883` offset 1,1 | ini: `CaptionText`, `[Window] TextShadowColor` |
| Taskbar | see column; average `#245EDC` | px `BLUE_TASKBARBACKGROUND` x=25; ini hint |
| Start button | normal ≈ `#4A9949` avg, ramp below; text shadow `#454C10` | px `BLUE_STARTBUTTON` x=49; ini |
| Window face | `#ECE9D8` | ini: `Btnface`, `[globals] EdgeFillColor` |
| 3D edges | light `#F1EFE2`, highlight `#FFFFFF`, shadow `#ACA899`, dark shadow `#716F64` | ini: `[globals] Edge*Color` |
| Window frame (left, outer→inner) | active `#0019CF #0831D9 #1254E7 #166AEE #0855DD`; inactive `#5B68CD #7480DC #7589DE #758CDD #758CDC` | px `BLUE_FRAMELEFT` y=15 / y=46 |
| Window frame (bottom, top→bottom) | active `#0048F1 #003DDD #002EBF #001EA0 #00138C`; inactive `#7586DC #7587DD #7382D9 #6D74CD #4F53BC` | px `BLUE_FRAMEBOTTOM` x=24 |
| Close button | fill `#E55F3B` (hint `#E45D3D`), 1px border `#FFFFFF`; hot `#FF836E`; pressed `#C2401D`; inactive `#AF748B` | px `BLUE_CLOSEBUTTON` (10,10) of frames 0/1/2/4; ini hint |
| Notification area | `#0D8DEA` body; left divider `#0A2E52` then highlight `#22BCE6` | px `BLUE_TASKBARTRAY` x=60 / row y=14 x=9–10; ini hint `13 141 234` |
| Clock text | `#FFFFFF` | ini `[TrayNotify::Clock]` |
| Start menu header | see column; avg `#1F71D8`; name shadow `#09428B` | px `BLUE_STARTUSERPANEL` x=60; ini |
| Start menu left column | `#FFFFFF`; text `#373738`, hot `#3070D0`, captions `#808080` | ini `[StartPanel.ProgList]` |
| Start menu right column | `#D3E5FA` (left edge `#95BDEE`); text `#0A246A`, hot `#5096F8` | px `BLUE_STARTPANELPLACESBACKGROUND` y=3, same in `reference/start-menu-luna-blue.png` (200,200); ini |
| Start menu footer | `#438BE3` → `#0C56C0` (column below) | px `BLUE_STARTPANELLOGOFFBACKGROUND` x=48 |
| Selection highlight | `#316AC5` | ini `Highlight` |
| Desktop background | `#004E98` | ini `Background` |

```
caption active  (29 rows): #0059E8 #3D95FF #2B90FF #016CFE #0365F1 #005CE9 #0058E6 #0053E1×3 #0055E5 #0051E5 #0055E5×2 #0055EA×2 #0058EE #0058F3 #005AF5 #0060F9 #0060FC #0065FD #026AFE×3 #0065FD #0060F9 #0046E0 #0143CF
caption inactive(29 rows): #688DE0 #98B2E8 #9BB7EA #8AACE7 #7EA2E4 #7B9AE1 #7999DE #7996DE #7895DD #7996DE #7A96DF×2 #7A96E0 #7B97E0×2 #7B99E1 #7D9BE3×2 #7E9DE5 #7FA2E6 #80A5E7 #81A7E8 #82A9E9×2 #81A7E8 #80A5E7 #7E9DE5 #7A93DF×2
taskbar         (28 rows): #3168D5 #3888E9 #4993E6 #307BE5 #286ADD #245DD7 #2359D6 #2257D5×2 #2257D6 #2157D7 #2259D7 #225AD9 #235BD9 #235CDB #245DDB #245EDC #255FDC #2660DD #2661DD #2662DF×2 #2663E0×2 #2561DE #235BD9 #1E50C4 #1941A5
start normal    (rows 0-30): #3B7C3B #5FA15F #8EBF8F #88BD88 #78B478 #67AC67 #58A359 #4FA050 #4A9E49 #469E46 #459E45 #45A045 #44A245 #43A342 #43A443 #44A944 #45AC45 #45AE45 #45B245 #45B545 #45B746 #47B847×2 #49B949 #47B748 #46B346 #44AD44 #41A441 #3D983D #358335 #2B7139
start hot       (rows 0-30): #228928 #59AF59 #88CB89 #88CC88 #78C677 #65BF65 #58B858 #4EB54E #49B34A #47B346 #45B445 #44B644×2 #44B844 #44BB43 #45BD45 #47C247 #47C547 #4AC849 #4ACA4A #49CF49×2 #4CCE4D #4DCE4D #4CCD4D #4AC94A #48C348 #46BA45 #40AC40 #3A9C3A #30863B
start pressed   (rows 0-30): #09420B #265C26 #3F6E3F #3E7A3E #348234 #2B872B #238623 #1D831D #1C831C #1B841B #1A851A×2 #188618 #178817 #188818 #188B18 #188C18 #168E16 #169016×2 #169316 #179417 #179617 #199719 #1A981A #1E9B1E #249C24 #279B27 #279627 #257E25 #115E11
close (frame 0) : #FFFFFF #E45F3E #E8795F #E97C62 #E76F54 #E46446 #E45F40 #E45D3D #E35C3A #E45E3A #E55F3B #E6623C #E7653D #E7653C #E7643B #E76238 #E65D32 #E2552A #D2451E #AE3110 #FFFFFF
tray            (28 rows): #095BC9 #16ADF0 #19B9F3 #149EED #1399EB #1290E8×2 #1290E9×2 #118FE9 #0F8EEA #118FE9 #0F8EEA #0D8DEA×4 #0D90EB #0D93ED #0D96EE #0D9AEF #0D9DF1 #0E9FF1 #0F9EEF #119AEA #1393E5 #157FDB #095BC9
start header    (63 rows): #225CC5 #67A2E7 #75ABE8 #397FD9 #1A69D2 #1666CF #1464CD #1162CC #1061CC #0E60CB #0D60CB #0C5FCB×2 #0D60CB×2 #0E60CB #0E61CC #0F61CC #1062CD #1063CD #1164CE #1265CE #1466CF #1567CF #1668D0 #1769D0 #186AD1 #196AD1 #1A6BD2 #1A6CD2 #1B6CD3 #1B6DD4 #1C6ED5 #1D6FD6 #1E70D7 #1F71D8 #2072D9 #2173DA #2374DB #2476DB #2577DC #2778DD #2879DE #297ADF #2A7BDF #2C7CE0 #2D7EE1 #2F7FE2 #3080E3 #3282E4 #3383E5 #3585E5 #3686E6 #3887E7 #3988E7 #3B89E7 #3D8AE8 #3F8AE8 #408CE8 #428EEA #448FEA #4690EA #4792EC
start footer    (39 rows): #438BE3 #428AE3×2 #438BE4 #418AE5 #408AE3 #3E89E4 #3C87E3 #3A86E3 #3885E4 #3683E4 #3481E3 #3280E3 #307FE3×2 #2D7DE2 #2A7BE2 #2778E1 #2577DF #2375E0 #2274DE #2073DE #1F72DB #1D70DC #1B6FDC #196DDB #186DDB #176CDA #166AD9 #166AD7 #1568D6 #1367D5 #1266D3 #1164D1×2 #1062CF #0F60CC #0D5BC7 #0C56C0
```

## Olive Green (`HOMESTEAD`)

| Element | Value | Source |
|---|---|---|
| Title bar active | `#8BA169` → `#C6D2A2` | ini `ActiveCaption`, `GradientActiveCaption` |
| Title bar inactive | `#D4D6BA` → `#D4D6BA`; text `#FFFFFF` | ini |
| Caption text | `#FFFFFF` | ini |
| Taskbar | see column (30 rows) | px `HOMESTEAD_TASKBARBACKGROUND` x=25 |
| Start button | olive-green, avg `#7D9760` | px `HOMESTEAD_STARTBUTTON` x=49; ini hint `125 151 96` |
| Window face | `#ECE9D8` | ini `Btnface` |
| Window frame (left) | active `#758D5E #8BA169 #ABBD85 #ABBD85 #A4B27F`; inactive `#C8D0B7 #D0D6BD #DBDFC5 #E0E2C8 #D6D8BE` | px `HOMESTEAD_FRAMELEFT` y=15 / y=46 |
| Window frame (bottom) | active `#CBD798 #BDC891 #A3AE7E #899B6D #5E764F`; inactive `#DEE3C5 #D8DCC2 #CBCFB9 #BFC3B0 #B6BDAB` | px `HOMESTEAD_FRAMEBOTTOM` x=24 |
| Close button | fill `#D56F4A`, border `#FFFFFF`; hot `#F18557`; pressed `#B94F26`; inactive `#BD9A9B` | px `HOMESTEAD_CLOSEBUTTON` |
| Notification area | `#EAE2B2`; left divider `#968B4B` then `#F9F0B8` | px `HOMESTEAD_TASKBARTRAY`; matches screenshot |
| Clock text | `#41400A` | ini `[TrayNotify::Clock]`; screenshot glyph pixels `#41400A` |
| Start menu header | see column, avg `#B7C793` | px `HOMESTEAD_STARTUSERPANEL` x=60; ini hint |
| Start menu left column | `#FFFFFF`; hot `#859066` | ini `[StartPanel.ProgList]` |
| Start menu right column | `#F3F1E4` (left edge `#CCA467`); text `#545F38` | px `HOMESTEAD_STARTPANELPLACESBACKGROUND`; ini |
| Start menu footer | `#D9E2B4` → `#A2AF7B` | px `HOMESTEAD_STARTPANELLOGOFFBACKGROUND` x=48 |
| Selection highlight | `#93A070` | ini |
| Desktop background | `#9DACBD` | ini |

```
caption active  : #8BA169 #E9F2C7 #E0E7B8 #BFCB92 #B8C58D #AFBC84 #AAB883 #A7B580×3 #AAB883×4 #ADBD85×2 #B0C088 #B3C48B #B5C68D #BAC88E #BBC98F×2 #C2CD95×3 #BBC98F #BAC88E #A3B27F #96A867
caption inactive: #D6D8BB #F1F1DA #EDEBD3 #DFE0C2 #DBDCBF #D6D8BB #D4D7BB #D3D6BA×3 #D4D7BB×4 #D6D9BC×2 #D7DBBD #D8DCBE #DADDBF #DCDEC0 #DDDFC1×2 #E0E1C3×3 #DDDFC1 #DCDEC0 #D0D5B9 #CBCEB6
taskbar (30)    : #8BA169 #EAF5C9 #E0E7B8 #C2CD95 #B8C58D #AFBC84 #AAB883 #A8B680×3 #AAB883×5 #ADBD85×2 #B0C088 #B4C48B #B5C68D #BAC88E #BBC88F #C2CD95×4 #BBC98F×2 #A7B680 #96A867
start normal    : #2B5B22 #8EA970 #B4C58C #D2DDA7 #E5EBB9 #EEF1C0 #E3E8B7 #D2D9A5 #BDCB94 #B2C08A #AABA83 #A4B57E #9DAF78 #95A972 #8CA26C #869B66 #829A63 #7C9760 #79925C #728E55 #6A8A51 #63854C #5A8045 #557D43 #527D43 #518145 #528446 #5A8B52 #639661 #72A36F #36522B
close (frame 0) : #FFFFFF #D56F4D #DB876C #DC896E #DA7D61 #D57354 #D46E4E #D56D4C #D36B49 #D46E49 #D56F4A #D6714B #D7744C #D7734B×2 #D67048 #D56C42 #D0653A #C1552E #9F3F1E #FFFFFF
tray            : #B3A868 #FFFDE9 #FCF7D9 #F2E5B1 #EAE2B2×20 #E4D9AB #DDCEA4 #D6C187 #D0BC89
start header    : #B6C99E #E6F1CB #EDF4D3 #CFDEB3 #BDCE9A #B4C593 #B0C28F #AEC08C #ADBF8B #ADBE8A×2 #AEBD89×2 #ADBE8A #ACBE8A×2 #ADBF8B×2 #AEC08C … (lightening steadily) … #D9E9BB #DBEBBD #DDECBF #DDEDC0
start footer    : #D9E2B4×6 #D7E0B0×2 #D5DDAF×2 #D5DCAB×2 #D2DAA8 #D1D9A7×2 #CFD8A3 #CDD9A1 #CAD49F #C8D29D #C5D29D #C6CF9A #C4D098 #C2CE96 #C1CE95 #BFCD93 #C0CD92 #BFCB90 #BCC890×2 #BAC78E #B8C68C #B8C48A #B6C38A #B3C087×2 #B1BE85 #AFBC84 #AAB77F #A2AF7B
```

## Silver (`METALLIC`)

| Element | Value | Source |
|---|---|---|
| Title bar active | `#C0C0C0` → `#C8C8C8` (ini); real ramp is a light chrome: `#A8A7BF` → `#FFFFFF` | ini; px `METALLIC_FRAMECAPTION` |
| Title bar inactive | `#FFFFFF` → `#EEEFF7`; text `#A2A1A1` | ini |
| Caption text | **`#0E1010` (near-black)** — Silver is the only scheme with dark title text | ini `CaptionText = 14 16 16` |
| Taskbar | see column (30 rows): dark rim, white highlight, then `#9A99B1` → `#ECEBEC` | px `METALLIC_TASKBARBACKGROUND`; matches screenshot |
| Start button | green (same family as Luna), avg `#4A9949` | px `METALLIC_STARTBUTTON`; ini hint |
| Window face | `#E0DFE3` | ini `Btnface` |
| Window frame (left) | active `#66667E #FBFCFD #FBFCFD #A8A9BB #66667E`; inactive `#C9C9D7 #FDFFFC #FDFFFC #E6E9E4 #C9C9D7` | px `METALLIC_FRAMELEFT` y=15 / y=46 |
| Window frame (bottom) | active `#66667E #A8A9BB #A8A9BB #FBFCFD #66667E`; inactive `#C9C9D7 #EAEDF5 #EAEDF5 #FBFCFD #C9C9D7` | px `METALLIC_FRAMEBOTTOM` |
| Close button | fill `#E06A68`, border `#A63944`; hot `#FB806B`; pressed `#FD7E66`; inactive `#E3AEAD` | px `METALLIC_CLOSEBUTTON` |
| Notification area | `#CBCCDA`; left divider `#58596D` then `#D7D8DA` | px `METALLIC_TASKBARTRAY`; matches screenshot |
| Clock text | `#000000` | ini; screenshot |
| Start menu header | `#A8A7BF` → `#FFFFFF` (light chrome), avg `#CECEDB` | px `METALLIC_STARTUSERPANEL` x=105; ini hint |
| Start menu left column | `#FFFFFF`; hot `#3070D0` | ini |
| Start menu right column | `#E2E7EB` → `#E9E6EE` (left edge `#B4BDC7`); text `#0A246A` | px `METALLIC_STARTPANELPLACESBACKGROUND` y=3; ini |
| Start menu footer | `#E6E6EC` → `#A8A7BF` | px `METALLIC_STARTPANELLOGOFFBACKGROUND` x=107 |
| Selection highlight | `#B2B4BF` | ini |
| Desktop background | `#585768` | ini |

```
caption active  : #66667E #A8A7BF #FFFFFF #D7D8E2 #BCBCCF #A8A7BF #A4A3BE #ACABC4 #AFAEC7 #B1B3C8 #B4B6C7 #B7B8C9 #BABCCB #BEC0CE #C2C4D2 #C4C7D4 #CBCDD8 #D0D2DC #D5D8E1 #DCDEE5 #E3E5EA #EAEBEF #F0F1F4 #F7F7F9 #FBFCFD #FFFFFF #E4E3E3 #BCBDCD #777792
caption inactive: #BABAC5 #ECEEF5 #FFFFFF #ECEEF5 #E4E5ED #D7D7E3×2 #D9D9E5 #DBDDE6 #DCDDE8 #DEE0E6 #DEDFEA #E3E6E8 #E4E5ED #E6E8ED #E8E9F1 #EEEEEE #EDF0F3 #F4F3F5 #F6F6F6 #F8F8F9 #FAFAFB #FBFBFC #FCFCFD #FEFDFE #FFFFFF #FDFFFC #EAEDF5 #CCCBD9
taskbar (30)    : #7D7E99 #DADCE8 #FFFFFF #DADCE8 #B3B6C5 #9A99B1×2 #9E9DB6 #A2A5B8 #A3A5BC #A8ABB8 #A8A9BF #B1B7BB #B3B6C5 #B8BCC5 #BBBDCD #C6C6C7 #C4CBD1 #D2D1D5 #D7D7D7 #DBDBDC #DFDFE1 #E1E0E3 #E3E2E4 #E6E4E6 #E9E8E8 #ECEBEC #E4EFE3 #BFC4D4 #83829D
start normal    : #0A760D #89CD70 #9EDB7E #B2E98F #CAEBB2 #EBEBEE #D1ECBB #C7E9A8 #BBE39C #A7D789 #93C977 #79BA62 #65AA53 #5BA34B #5BA14B #5AA14B #5DA14C #5CA14C #5CA14A #55A146 #499A3A #3C9430 #2B8F28 #248F28 #258E2A #279130 #2A983B #349D4E #39A75F #43B471 #1D641D
close (frame 0) : #A63944 #F9E9B6 #F2B89E #EDB49B #EB988B #E97E78 #E4746F #E4706E #E36C6C #E06C69 #E06A68 #DE6767 #DC6565 #D96162 #D65F63 #D45C5F #D05A5F #CD595E #C6555C #AA3C55 #A63944
tray            : #FFFFFF #FEFEFF #FFFFFF #FEFEFE #F8F9FA #F4F4F7 #EEEEF3 #E8E8EE #E1E1EA #DADBE5 #D5D6E1 #CFD0DF #CCCDDB #CBCCDA×7 #C8CAD8 #C5C6D6 #C1C3D2 #BCBFCF #B4B6CB #A8ABC0 #888BA3 #61637C
```

## Royale

| Element | Value | Source |
|---|---|---|
| Title bar active | `#335EA8` → `#70B1EB` (ini). The bitmap runs **light at top to dark at bottom**: `#99C6F1` → `#2C55B1` | ini; px `ROYALE_FRAMECAPTION` |
| Title bar inactive | `#6FA1D9` → `#83B7E3`; text `#FFFFFF`; bitmap runs dark → light `#4F74B7` → `#90C3E6` | ini; px |
| Caption text | `#FFFFFF` | ini |
| Taskbar | glassy: `#99C6F1` top → `#2C55B1` bottom, rim `#2A4DAB`/`#254394` | px `ROYALE_TASKBARBACKGROUND` x=25 |
| Start button | green, more saturated than Luna; normal mid `#0F9317` → `#0BC911`, hot `#1DEB2B`, pressed `#025604` | px `ROYALE_STARTBUTTON` x=49 |
| Window face | `#EBE9ED` | ini `Btnface` |
| Window frame (left) | active `#3262BD #84B0DF #5E89CB #5E89CB #254394`; inactive `#579CE2 #97C4E9 #82BFEC #82BFEC #69A1EB` | px `ROYALE_FRAMELEFT` y=15 / y=46 |
| Window frame (bottom) | active `#254394 #5E89CB #5E89CB #84B0DF #3262BD`; inactive `#69A1EB #82BFEC #82BFEC #97C4E9 #579CE2` | px `ROYALE_FRAMEBOTTOM` |
| Close button | fill `#C55036` (glossy: top half `#D78F7E`→`#CF7B67`, bottom `#C35138`→`#EEC4B9`), border `#3D68A8`; hot `#C55036` (glow differs elsewhere); pressed `#9A3131`; inactive `#4584D0` | px `ROYALE_CLOSEBUTTON` |
| Notification area | light glass `#FBFDFF` → `#5086C9`, mid `#ADC7EB` | px `ROYALE_TASKBARTRAY` x=60 / row y=14 |
| Clock text | `#000000` | ini |
| Start menu header | pale `#EEF6FA` → `#3D57A2` | px `ROYALE_STARTUSERPANEL` x=60 |
| Start menu left column | **dark navy `#10377C`**, text `#FFFFFF`, captions `#8FB6E3` | px `reference/start-menu-royale.png` (20,200) and (60,300); ini `[StartPanel.ProgList]` text (its fill hint is a stale Luna copy) |
| Start menu right column | `#5373BF`; text `#FFFFFF` | px `ROYALE_STARTPANELPLACESBACKGROUND` y=3, same in `reference/start-menu-royale.png` (200,200); ini |
| Start menu footer | `#76A1DE` → `#3F66BC` | px `ROYALE_STARTPANELLOGOFFBACKGROUND` x=48 |
| Selection highlight | `#335EA8` | ini |
| Desktop background | `#000040` | ini |

```
caption active  : #2A4DAB #99C6F1 #83C2ED #80BEED #7BBBEB #76B8EC #72B3E9 #70B1EB #6DAAE9 #68A5E8 #64A3EA #609EE7 #5A98E1 #5593DE #3980D2 #3A7CD0 #3779CD #3677C9 #3472C5 #376FC2 #3369C1 #3367BD #3261BB #315FB7 #305BB7 #2E57B1 #2C55B1×2 #254394
caption inactive: #4D73C3 #85B3E3 #4F74B7 #5175B7 #5379BC #537CBC #547DBE #5580C0 #5582C2 #5886C3 #5688C5 #588CC8 #598ECB #5C91CE #5B92CF #6FA1D9 #72A4DB #77A9E0 #7AADE3 #7DAFE1 #80B2E2 #83B7E3 #83B7E2 #87BCE5 #8BBEE4 #8EC0E6 #90C3E6×2 #79A6E3
taskbar (30)    : #2A4DAB #99C6F1 #83C2ED×2 #83C1ED #7EBCED #78B6EC #72AFEA #6DABE9 #69A6E8 #64A2E5 #5F9EE4 #5B99E1 #5795DF×3 #397DD0 #397ACE #3677C9 #3771C4 #346DC3 #3367BD #3261BB #315FB7 #305BB7 #2E57B1 #2C55B1×3 #254394
start normal    : #3B5B7E #EDF6F1 #BADEC0 #84C48D #81C38A #78BF7F #6CBB71 #60B763 #58B559 #53B256 #52B256 #4EB054 #4CAE52 #47AC4E #43AB4B #41A949 #0F9317 #0F9218 #109218 #12941D #159A20 #129F1F #11A720 #11AE19 #11B619 #11BE19 #0FC216 #0BC611 #09C90E #10CB17 #0BC911
close (frame 0) : #4D73C3 #E7AA9B #D78F7E #D48C7A #D98674 #CC8876 #CE8371 #CF7F6C #CF7B67 #C35138 #C55036 #C65035 #C74F32 #CC593D #D3664C #DA755D #E3886B #E8967E #EAA592 #EEC4B9 #285B94
tray            : #3E647E #FBFDFF #F5FAFF #F1F7FF #ECF4FF #E6F0FF #E2EDFE #DFEBFD #DCE8FB #D7E6FA #D3E2F7 #CEDFF5 #CADBF3 #C4D5F1 #ADC7EB #A1BFE5 #9CBAE3 #96B5E0 #8DB1DE #86ABDB #81A7D8 #7AA2D6 #759ED3 #6D98D1 #6392CF #5A8BCC #5086C9 #7498C5
start header    : #2A4DAB #EEF6FA #D7E9F5 #D8E8F5 #D6E7F3 #D4E6F3×2 … (darkening steadily) … #3D5DB0 #3F5DB1 #3D58A5 #3D57A2 #3E59A1 #4465B4 #4C7BBC
```

## Zune (`DEFAULT`)

| Element | Value | Source |
|---|---|---|
| Title bar active | `#343434` → `#747474` (ini). Bitmap: `#858585` highlight row then `#6F6F6F` → `#292929` | ini; px `DEFAULT_FRAMECAPTION` |
| Title bar inactive | `#747474` → `#C8C8C8` (ini); bitmap `#272727` → `#4C4C4C`; text `#F4F4F4` | ini; px |
| Caption text | `#FFFFFF` | ini |
| Taskbar | identical ramp to the active caption: `#252525` rim, `#858585`, `#6F6F6F` → `#292929`, `#1B1B1B` | px `DEFAULT_TASKBARBACKGROUND` x=25 |
| Start button | **orange**: normal `#FFB586` → `#E37633` (top half) / `#B94C09` → `#DA6D2A` (bottom half), rim `#4E1F01`; hot up to `#FFF6EF`/`#FF924F`; pressed `#DA6D2A`→`#803201` | px `DEFAULT_STARTBUTTON` (99x90, 3×30) x=49 |
| Window face | `#E2E2E2` | ini `Btnface` |
| Window frame (left, 4px) | active `#1B1B1B #858585 #292929 #292929`; inactive `#1B1B1B #555555 #4C4C4C #4C4C4C` | px `DEFAULT_FRAMELEFT` y=15 / y=46 |
| Window frame (bottom) | active `#1B1B1B #292929 #292929 #858585 #1B1B1B`; inactive `#393939 #4C4C4C #4C4C4C #555555 #252525` | px `DEFAULT_FRAMEBOTTOM` |
| Close button | fill `#DE3518` (glossy: top `#D58471`→`#E46848`, bottom `#E03719`→`#F4AF9F`), border `#434343`/`#222222`; hot `#F93E00`; pressed `#9B1602`; inactive `#474747` | px `DEFAULT_CLOSEBUTTON` |
| Notification area | `#5F5F5F` → `#101010`; left divider `#000000` then `#2F2F2F` | px `DEFAULT_TASKBARTRAY` |
| Clock text | `#FFFFFF` | ini |
| Start menu header | `#575757` → `#080808` → `#131313` | px `DEFAULT_STARTUSERPANEL` x=60 |
| Start menu left column | **dark grey `#2F2F2F`**, text `#FFFFFF`, captions `#B2BCC0` | px `reference/desktop-zune.png` (40,380) (downscaled capture); ini text (fill hint is a stale Luna copy) |
| Start menu right column | `#666666`; text `#FFFFFF` | px `DEFAULT_STARTPANELPLACESBACKGROUND` y=3, same in `reference/desktop-zune.png` (130,380); ini |
| Start menu footer | `#575757` → `#131313` | px `DEFAULT_STARTPANELLOGOFFBACKGROUND` x=48 |
| Selection highlight | `#BEBEBE` | ini |
| Desktop background | `#1A1A1A` | ini |

```
caption active  : #252525 #858585 #6F6F6F #6C6C6C #6A6A6A×2 #656565×2 #636363 #606060 #5E5E5E #5B5B5B #565656 #545454 #3D3D3D×2 #3B3B3B #383838 #363636×2 #343434 #323232 #303030 #2E2E2E #2D2D2D #2B2B2B #292929×2 #1B1B1B
caption inactive: #252525 #555555 #272727×2 #282828 #292929×2 #2A2A2A #2B2B2B #2C2C2C #2D2D2D #2E2E2E #343434 #393939 #3B3B3B #3E3E3E #404040 #424242 #454545 #464646 #474747 #484848 #494949 #4A4A4A #4B4B4B #4C4C4C×3 #393939
start normal    : #4E1F01 #FFDAC3 #FFB586 #FFB180 #FFAC78 #FFA56D #FFA065 #FF995A #FF9452 #FB8E4B #F68946 #F18441 #EC7F3C #E77A37 #E37633 #B94C09 #B64906 #B74A07 #B94C09 #BB4E0B #BE510E #C15411 #C55815 #C95C19 #CC5F1C #D06320 #D46724 #D76A27 #DA6D2A #622601
close (frame 0) : #434343 #F08F78 #D58471 #D3816D #D87A67 #E47459 #E47155 #E46A4F #E46848 #E03719 #DE3518 #DC3818 #DB3918 #E6401C #E74B25 #E95D38 #E27152 #E77F65 #E88F7A #F4AF9F #222222
```

## Boot screen palette (Plymouth)

ntoskrnl's boot bitmaps have a zeroed palette; these are the colours XP shows,
recovered by voting every pixel of `graphics/ntoskrnl/BITMAP/1.bmp` against the
real capture `reference/boot-screen-xp-professional.png` (16-colour PNG). Agreement
per index is shown; disagreements are the progress-bar animation and the edition
overlay drawn at boot.

| Index | Colour | Agreement | Used by |
|---|---|---|---|
| 0 | `#000000` | 290482/292981 | background |
| 1 | `#000000` | 547/547 | |
| 2 | `#404040` | 695/695 | grey progress segment (bitmap 4) |
| 3 | `#2838C7` | 551/551 | **blue progress segment** (bitmap 8, dark) |
| 4 | `#4F5F00` | 546/546 | flag green (dark) |
| 5 | `#A83007` | 653/653 | flag red (dark) |
| 6 | `#777777` | 497/497 | trough / grey segment |
| 7 | `#808800` | 906/906 | flag yellow-green |
| 8 | `#5878EF` | 602/602 | **blue progress segment** (mid) |
| 9 | `#E8671F` | 1336/1336 | flag orange, "xp" |
| 10 | `#879FF0` | 589/589 | **blue progress segment** (light) |
| 11 | `#87D000` | 1038/1038 | flag green |
| 12 | `#E7B018` | 1470/1470 | flag yellow |
| 13 | `#B0B0B0` | 922/922 | trough / grey segment |
| 14 | `#EFEFEF` | 3390/3867 | "Windows", "Microsoft", copyright text |
| 15 | **unknown** (set to `#FFFFFF` in `graphics/boot/`) | unused by bitmap 1 | the only colour of "It is now safe to turn off your computer." (bitmap 3) |

Index 15 needs a real capture of the safe-to-turn-off screen to settle; until
then the text colour is an assumption, not a measurement.
