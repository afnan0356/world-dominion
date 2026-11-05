# Data completeness

**Generated from `data/world/countries/` by `tools/report_data_completeness.py`.** Do not edit by hand: CI regenerates it and fails if the committed copy differs.

## How to read this page

Every record has its own folder (see [COUNTRY_FOLDER_GUIDE.md](COUNTRY_FOLDER_GUIDE.md)). A record's folder always holds its identity, its geometry and its source block. A capital is only present when the dataset has one — the file is absent rather than filled with a placeholder. Nothing else is collected yet, so nothing else appears here.

There is deliberately **no completeness score**. A percentage would suggest that the sections are comparable and that the missing parts are equal, and neither is true.

## Totals

| Section | Records with it | Records without it |
| --- | --- | --- |
| Identity (`identity.json`) | 242 | 0 |
| Geometry (`geometry.json`) | 242 | 0 |
| Capital (`capital.json`) | 196 | 46 |
| Sources (`sources.json`) | 242 | 0 |

## Empty fields

A field is listed here when the dataset itself has no value for it. The game shows these as "Not recorded in source" rather than filling them in.

| Field | Records where it is empty |
| --- | --- |
| ISO alpha-2 | 9 |
| ISO alpha-3 | 8 |
| capital | 46 |

## Future sections

Economy, politics, military and demographics files do **not** exist for any record, because no sourced data for them has been collected. When a system ships real data, its file appears in these folders with its own schema version and source block, and a column appears in the table below — not before.

## Every record

| Record | ID | Polygons | Points | Capital | Empty fields |
| --- | --- | ---: | ---: | --- | --- |
| Afghanistan | `AFG` | 1 | 410 | yes | — |
| Albania | `ALB` | 1 | 113 | yes | — |
| Algeria | `DZA` | 1 | 381 | yes | — |
| American Samoa | `ASM` | 1 | 8 | no | capital |
| Andorra | `AND` | 1 | 19 | yes | — |
| Angola | `AGO` | 2 | 338 | yes | — |
| Anguilla | `AIA` | 1 | 6 | no | capital |
| Antarctica | `ATA` | 108 | 4923 | no | capital |
| Antigua and Barb. | `ATG` | 2 | 22 | yes | — |
| Argentina | `ARG` | 4 | 1039 | yes | — |
| Armenia | `ARM` | 2 | 146 | yes | — |
| Aruba | `ABW` | 1 | 10 | no | capital |
| Ashmore and Cartier Is. | `ATC` | 1 | 5 | no | ISO alpha-2, ISO alpha-3, capital |
| Australia | `AUS` | 42 | 1799 | yes | — |
| Austria | `AUT` | 1 | 272 | yes | — |
| Azerbaijan | `AZE` | 3 | 264 | yes | — |
| Bahamas | `BHS` | 15 | 268 | yes | — |
| Bahrain | `BHR` | 1 | 13 | yes | — |
| Bangladesh | `BGD` | 7 | 384 | yes | — |
| Barbados | `BRB` | 1 | 9 | yes | — |
| Belarus | `BLR` | 1 | 321 | yes | — |
| Belgium | `BEL` | 1 | 163 | yes | — |
| Belize | `BLZ` | 3 | 65 | yes | — |
| Benin | `BEN` | 1 | 147 | yes | — |
| Bermuda | `BMU` | 1 | 8 | yes | — |
| Bhutan | `BTN` | 1 | 100 | yes | — |
| Bolivia | `BOL` | 1 | 417 | yes | — |
| Bosnia and Herz. | `BIH` | 1 | 146 | yes | — |
| Botswana | `BWA` | 1 | 221 | yes | — |
| Br. Indian Ocean Ter. | `IOT` | 1 | 17 | no | capital |
| Brazil | `BRA` | 17 | 1885 | yes | — |
| British Virgin Is. | `VGB` | 3 | 23 | no | capital |
| Brunei | `BRN` | 2 | 56 | yes | — |
| Bulgaria | `BGR` | 1 | 179 | yes | — |
| Burkina Faso | `BFA` | 1 | 253 | yes | — |
| Burundi | `BDI` | 1 | 78 | yes | — |
| Cabo Verde | `CPV` | 8 | 87 | yes | — |
| Cambodia | `KHM` | 3 | 221 | yes | — |
| Cameroon | `CMR` | 1 | 350 | yes | — |
| Canada | `CAN` | 141 | 11572 | yes | — |
| Cayman Is. | `CYM` | 3 | 36 | no | capital |
| Central African Rep. | `CAF` | 1 | 324 | yes | — |
| Chad | `TCD` | 1 | 291 | yes | — |
| Chile | `CHL` | 31 | 2006 | yes | — |
| China | `CHN` | 13 | 2662 | yes | — |
| Colombia | `COL` | 2 | 623 | yes | — |
| Comoros | `COM` | 3 | 35 | yes | — |
| Congo | `COG` | 1 | 323 | yes | — |
| Cook Is. | `COK` | 1 | 11 | no | capital |
| Costa Rica | `CRI` | 1 | 133 | yes | — |
| Croatia | `HRV` | 13 | 374 | yes | — |
| Cuba | `CUB` | 7 | 305 | yes | — |
| Curaçao | `CUW` | 1 | 10 | no | capital |
| Cyprus | `CYP` | 1 | 56 | yes | — |
| Czechia | `CZE` | 1 | 240 | yes | — |
| Côte d'Ivoire | `CIV` | 2 | 294 | yes | — |
| Dem. Rep. Congo | `COD` | 1 | 608 | yes | — |
| Denmark | `DNK` | 12 | 297 | yes | — |
| Djibouti | `DJI` | 1 | 56 | yes | — |
| Dominica | `DMA` | 1 | 10 | yes | — |
| Dominican Rep. | `DOM` | 1 | 112 | yes | — |
| Ecuador | `ECU` | 9 | 347 | yes | — |
| Egypt | `EGY` | 1 | 253 | yes | — |
| El Salvador | `SLV` | 1 | 74 | yes | — |
| Eq. Guinea | `GNQ` | 2 | 67 | yes | — |
| Eritrea | `ERI` | 3 | 192 | yes | — |
| Estonia | `EST` | 4 | 195 | yes | — |
| Ethiopia | `ETH` | 1 | 302 | yes | — |
| Faeroe Is. | `FRO` | 5 | 63 | no | capital |
| Falkland Is. | `FLK` | 6 | 149 | no | capital |
| Fiji | `FJI` | 21 | 279 | yes | — |
| Finland | `FIN` | 8 | 519 | yes | — |
| Fr. Polynesia | `PYF` | 21 | 185 | no | capital |
| Fr. S. Antarctic Lands | `ATF` | 3 | 119 | no | capital |
| France | `FRA` | 10 | 817 | yes | ISO alpha-2, ISO alpha-3 |
| Gabon | `GAB` | 1 | 271 | yes | — |
| Gambia | `GMB` | 1 | 73 | yes | — |
| Georgia | `GEO` | 1 | 164 | yes | — |
| Germany | `DEU` | 6 | 561 | yes | — |
| Ghana | `GHA` | 1 | 213 | yes | — |
| Greece | `GRC` | 40 | 923 | yes | — |
| Greenland | `GRL` | 17 | 2240 | no | capital |
| Grenada | `GRD` | 1 | 9 | yes | — |
| Guam | `GUM` | 1 | 12 | no | capital |
| Guatemala | `GTM` | 1 | 115 | yes | — |
| Guernsey | `GGY` | 1 | 7 | no | capital |
| Guinea | `GIN` | 1 | 348 | yes | — |
| Guinea-Bissau | `GNB` | 7 | 155 | yes | — |
| Guyana | `GUY` | 1 | 287 | yes | — |
| Haiti | `HTI` | 3 | 112 | yes | — |
| Heard I. and McDonald Is. | `HMD` | 1 | 15 | no | capital |
| Honduras | `HND` | 3 | 207 | yes | — |
| Hong Kong | `HKG` | 3 | 39 | no | capital |
| Hungary | `HUN` | 1 | 213 | yes | — |
| Iceland | `ISL` | 1 | 453 | yes | — |
| India | `IND` | 14 | 1518 | yes | — |
| Indian Ocean Ter. | `IOA` | 3 | 34 | no | ISO alpha-2, ISO alpha-3, capital |
| Indonesia | `IDN` | 133 | 3717 | yes | — |
| Iran | `IRN` | 2 | 605 | yes | — |
| Iraq | `IRQ` | 1 | 233 | yes | — |
| Ireland | `IRL` | 2 | 315 | yes | — |
| Isle of Man | `IMN` | 1 | 15 | no | capital |
| Israel | `ISR` | 1 | 105 | yes | — |
| Italy | `ITA` | 8 | 608 | yes | — |
| Jamaica | `JAM` | 1 | 48 | yes | — |
| Japan | `JPN` | 34 | 1097 | yes | — |
| Jersey | `JEY` | 1 | 9 | no | capital |
| Jordan | `JOR` | 1 | 95 | yes | — |
| Kazakhstan | `KAZ` | 4 | 1140 | yes | — |
| Kenya | `KEN` | 2 | 225 | yes | — |
| Kiribati | `KIR` | 19 | 212 | yes | — |
| Kosovo | `KOS` | 1 | 71 | yes | ISO alpha-2, ISO alpha-3 |
| Kuwait | `KWT` | 2 | 67 | yes | — |
| Kyrgyzstan | `KGZ` | 1 | 388 | yes | — |
| Laos | `LAO` | 1 | 390 | yes | — |
| Latvia | `LVA` | 1 | 140 | yes | — |
| Lebanon | `LBN` | 1 | 62 | yes | — |
| Lesotho | `LSO` | 1 | 77 | yes | — |
| Liberia | `LBR` | 1 | 139 | yes | — |
| Libya | `LBY` | 1 | 255 | yes | — |
| Liechtenstein | `LIE` | 1 | 15 | yes | — |
| Lithuania | `LTU` | 2 | 155 | yes | — |
| Luxembourg | `LUX` | 1 | 46 | yes | — |
| Macao | `MAC` | 1 | 9 | no | capital |
| Madagascar | `MDG` | 3 | 266 | yes | — |
| Malawi | `MWI` | 3 | 245 | yes | — |
| Malaysia | `MYS` | 9 | 509 | yes | — |
| Maldives | `MDV` | 2 | 22 | yes | — |
| Mali | `MLI` | 1 | 474 | yes | — |
| Malta | `MLT` | 2 | 16 | yes | — |
| Marshall Is. | `MHL` | 5 | 47 | yes | — |
| Mauritania | `MRT` | 2 | 321 | yes | — |
| Mauritius | `MUS` | 1 | 19 | yes | — |
| Mexico | `MEX` | 16 | 1012 | yes | — |
| Micronesia | `FSM` | 5 | 49 | yes | — |
| Moldova | `MDA` | 1 | 149 | yes | — |
| Monaco | `MCO` | 1 | 7 | yes | — |
| Mongolia | `MNG` | 1 | 736 | yes | — |
| Montenegro | `MNE` | 1 | 92 | yes | — |
| Montserrat | `MSR` | 1 | 7 | no | capital |
| Morocco | `MAR` | 1 | 366 | yes | — |
| Mozambique | `MOZ` | 1 | 469 | yes | — |
| Myanmar | `MMR` | 19 | 842 | yes | — |
| N. Cyprus | `CYN` | 1 | 44 | no | ISO alpha-2, ISO alpha-3, capital |
| N. Mariana Is. | `MNP` | 6 | 46 | no | capital |
| Namibia | `NAM` | 1 | 235 | yes | — |
| Nauru | `NRU` | 1 | 8 | no | capital |
| Nepal | `NPL` | 1 | 202 | yes | — |
| Netherlands | `NLD` | 12 | 261 | yes | — |
| New Caledonia | `NCL` | 6 | 127 | no | capital |
| New Zealand | `NZL` | 13 | 775 | yes | — |
| Nicaragua | `NIC` | 1 | 176 | yes | — |
| Niger | `NER` | 1 | 254 | yes | — |
| Nigeria | `NGA` | 2 | 364 | yes | — |
| Niue | `NIU` | 1 | 8 | no | capital |
| Norfolk Island | `NFK` | 1 | 25 | no | capital |
| North Korea | `PRK` | 2 | 257 | yes | — |
| North Macedonia | `MKD` | 1 | 80 | yes | — |
| Norway | `NOR` | 32 | 1985 | yes | ISO alpha-2, ISO alpha-3 |
| Oman | `OMN` | 4 | 243 | yes | — |
| Pakistan | `PAK` | 1 | 571 | yes | — |
| Palau | `PLW` | 2 | 21 | yes | — |
| Palestine | `PSE` | 2 | 50 | no | capital |
| Panama | `PAN` | 5 | 246 | yes | — |
| Papua New Guinea | `PNG` | 26 | 766 | yes | — |
| Paraguay | `PRY` | 1 | 257 | yes | — |
| Peru | `PER` | 1 | 588 | yes | — |
| Philippines | `PHL` | 48 | 1238 | yes | — |
| Pitcairn Is. | `PCN` | 1 | 9 | no | capital |
| Poland | `POL` | 1 | 316 | yes | — |
| Portugal | `PRT` | 9 | 265 | yes | — |
| Puerto Rico | `PRI` | 3 | 69 | no | capital |
| Qatar | `QAT` | 1 | 34 | yes | — |
| Romania | `ROU` | 1 | 274 | yes | — |
| Russia | `RUS` | 101 | 7450 | yes | — |
| Rwanda | `RWA` | 1 | 83 | yes | — |
| S. Geo. and the Is. | `SGS` | 2 | 63 | no | capital |
| S. Sudan | `SSD` | 1 | 325 | no | capital |
| Saint Helena | `SHN` | 2 | 18 | no | capital |
| Saint Lucia | `LCA` | 1 | 10 | yes | — |
| Samoa | `WSM` | 2 | 27 | yes | — |
| San Marino | `SMR` | 1 | 7 | yes | — |
| Saudi Arabia | `SAU` | 4 | 436 | yes | — |
| Senegal | `SEN` | 1 | 243 | yes | — |
| Serbia | `SRB` | 1 | 267 | yes | — |
| Seychelles | `SYC` | 1 | 8 | yes | — |
| Siachen Glacier | `KAS` | 1 | 21 | no | ISO alpha-2, ISO alpha-3, capital |
| Sierra Leone | `SLE` | 2 | 126 | yes | — |
| Singapore | `SGP` | 1 | 9 | yes | — |
| Sint Maarten | `SXM` | 1 | 7 | no | capital |
| Slovakia | `SVK` | 1 | 145 | yes | — |
| Slovenia | `SVN` | 1 | 132 | yes | — |
| Solomon Is. | `SLB` | 21 | 335 | yes | — |
| Somalia | `SOM` | 1 | 143 | yes | — |
| Somaliland | `SOL` | 1 | 79 | yes | ISO alpha-2, ISO alpha-3 |
| South Africa | `ZAF` | 2 | 442 | yes | — |
| South Korea | `KOR` | 11 | 260 | yes | — |
| Spain | `ESP` | 12 | 538 | yes | — |
| Sri Lanka | `LKA` | 3 | 92 | yes | — |
| St-Barthélemy | `BLM` | 1 | 11 | no | capital |
| St-Martin | `MAF` | 1 | 7 | no | capital |
| St. Kitts and Nevis | `KNA` | 2 | 20 | yes | — |
| St. Pierre and Miquelon | `SPM` | 2 | 24 | no | capital |
| St. Vin. and Gren. | `VCT` | 3 | 49 | yes | — |
| Sudan | `SDN` | 1 | 445 | yes | — |
| Suriname | `SUR` | 1 | 184 | yes | — |
| Sweden | `SWE` | 6 | 593 | yes | — |
| Switzerland | `CHE` | 1 | 187 | yes | — |
| Syria | `SYR` | 1 | 173 | yes | — |
| São Tomé and Principe | `STP` | 2 | 22 | yes | — |
| Taiwan | `TWN` | 2 | 67 | yes | ISO alpha-2 |
| Tajikistan | `TJK` | 3 | 369 | yes | — |
| Tanzania | `TZA` | 4 | 376 | yes | — |
| Thailand | `THA` | 10 | 578 | yes | — |
| Timor-Leste | `TLS` | 3 | 70 | yes | — |
| Togo | `TGO` | 1 | 130 | yes | — |
| Tonga | `TON` | 3 | 32 | yes | — |
| Trinidad and Tobago | `TTO` | 2 | 38 | yes | — |
| Tunisia | `TUN` | 3 | 186 | yes | — |
| Turkey | `TUR` | 3 | 562 | yes | — |
| Turkmenistan | `TKM` | 2 | 433 | yes | — |
| Turks and Caicos Is. | `TCA` | 3 | 29 | no | capital |
| Tuvalu | `TUV` | 1 | 10 | yes | — |
| U.S. Virgin Is. | `VIR` | 3 | 19 | no | capital |
| Uganda | `UGA` | 1 | 179 | yes | — |
| Ukraine | `UKR` | 2 | 635 | yes | — |
| United Arab Emirates | `ARE` | 5 | 183 | yes | — |
| United Kingdom | `GBR` | 23 | 986 | yes | — |
| United States of America | `USA` | 127 | 5749 | yes | — |
| Uruguay | `URY` | 1 | 143 | yes | — |
| Uzbekistan | `UZB` | 3 | 584 | yes | — |
| Vanuatu | `VUT` | 14 | 186 | yes | — |
| Vatican | `VAT` | 1 | 5 | yes | — |
| Venezuela | `VEN` | 5 | 567 | yes | — |
| Vietnam | `VNM` | 8 | 613 | yes | — |
| W. Sahara | `ESH` | 1 | 227 | no | capital |
| Wallis and Futuna Is. | `WLF` | 2 | 16 | no | capital |
| Yemen | `YEM` | 5 | 225 | yes | — |
| Zambia | `ZMB` | 1 | 376 | yes | — |
| Zimbabwe | `ZWE` | 1 | 169 | yes | — |
| eSwatini | `SWZ` | 1 | 38 | yes | — |
| Åland | `ALA` | 3 | 52 | no | capital |
