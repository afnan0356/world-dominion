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
| Statistics (`statistics.json`) | 242 | 0 |
| — Population | 241 | 1 |
| — GDP (current US$ as the source states it) | 241 | 1 |
| — Area (derived from the outline) | 241 | 1 |

## Empty fields

A field is listed here when the dataset itself has no value for it. The game shows these as "Not recorded in source" rather than filling them in.

| Field | Records where it is empty |
| --- | --- |
| GDP | 1 |
| ISO alpha-2 | 5 |
| ISO alpha-3 | 6 |
| area | 1 |
| capital | 46 |
| population | 1 |

## Future sections

`statistics.json` exists because a real, licensed source file provides population and GDP for these records, and the outline provides the area. Its values are Natural Earth's own estimates with the year the source records them for; they are baseline reference data for the 2026 scenario start and are **not live**. See [STATISTICS_REPORT.md](STATISTICS_REPORT.md) for the source, the matching and every rejected value.

Economy, politics, military and society files do **not** exist for any record, because no sourced data for them has been collected. When a system ships real data, its file appears in these folders with its own schema version and source block, and a column appears in the table below — not before.

## Every record

| Record | ID | Polygons | Points | Capital | Population | GDP | Area | Empty fields |
| --- | --- | ---: | ---: | --- | :---: | :---: | :---: | --- |
| Afghanistan | `AFG` | 1 | 410 | yes | yes | yes | yes | — |
| Albania | `ALB` | 1 | 113 | yes | yes | yes | yes | — |
| Algeria | `DZA` | 1 | 381 | yes | yes | yes | yes | — |
| American Samoa | `ASM` | 1 | 8 | no | yes | yes | yes | capital |
| Andorra | `AND` | 1 | 19 | yes | yes | yes | yes | — |
| Angola | `AGO` | 2 | 338 | yes | yes | yes | yes | — |
| Anguilla | `AIA` | 1 | 6 | no | yes | yes | yes | capital |
| Antarctica | `ATA` | 108 | 4923 | no | yes | yes | yes | capital |
| Antigua and Barb. | `ATG` | 2 | 22 | yes | yes | yes | yes | — |
| Argentina | `ARG` | 4 | 1039 | yes | yes | yes | yes | — |
| Armenia | `ARM` | 2 | 146 | yes | yes | yes | yes | — |
| Aruba | `ABW` | 1 | 10 | no | yes | yes | yes | capital |
| Ashmore and Cartier Is. | `ATC` | 1 | 5 | no | yes | yes | yes | ISO alpha-2, ISO alpha-3, capital |
| Australia | `AUS` | 42 | 1799 | yes | yes | yes | yes | — |
| Austria | `AUT` | 1 | 272 | yes | yes | yes | yes | — |
| Azerbaijan | `AZE` | 3 | 264 | yes | yes | yes | yes | — |
| Bahamas | `BHS` | 15 | 268 | yes | yes | yes | yes | — |
| Bahrain | `BHR` | 1 | 13 | yes | yes | yes | yes | — |
| Bangladesh | `BGD` | 7 | 384 | yes | yes | yes | yes | — |
| Barbados | `BRB` | 1 | 9 | yes | yes | yes | yes | — |
| Belarus | `BLR` | 1 | 321 | yes | yes | yes | yes | — |
| Belgium | `BEL` | 1 | 163 | yes | yes | yes | yes | — |
| Belize | `BLZ` | 3 | 65 | yes | yes | yes | yes | — |
| Benin | `BEN` | 1 | 147 | yes | yes | yes | yes | — |
| Bermuda | `BMU` | 1 | 8 | yes | yes | yes | yes | — |
| Bhutan | `BTN` | 1 | 100 | yes | yes | yes | yes | — |
| Bolivia | `BOL` | 1 | 417 | yes | yes | yes | yes | — |
| Bosnia and Herz. | `BIH` | 1 | 146 | yes | yes | yes | yes | — |
| Botswana | `BWA` | 1 | 221 | yes | yes | yes | yes | — |
| Br. Indian Ocean Ter. | `IOT` | 1 | 17 | no | yes | yes | yes | capital |
| Brazil | `BRA` | 17 | 1885 | yes | yes | yes | yes | — |
| British Virgin Is. | `VGB` | 3 | 23 | no | yes | yes | yes | capital |
| Brunei | `BRN` | 2 | 56 | yes | yes | yes | yes | — |
| Bulgaria | `BGR` | 1 | 179 | yes | yes | yes | yes | — |
| Burkina Faso | `BFA` | 1 | 253 | yes | yes | yes | yes | — |
| Burundi | `BDI` | 1 | 78 | yes | yes | yes | yes | — |
| Cabo Verde | `CPV` | 8 | 87 | yes | yes | yes | yes | — |
| Cambodia | `KHM` | 3 | 221 | yes | yes | yes | yes | — |
| Cameroon | `CMR` | 1 | 350 | yes | yes | yes | yes | — |
| Canada | `CAN` | 141 | 11572 | yes | yes | yes | yes | — |
| Cayman Is. | `CYM` | 3 | 36 | no | yes | yes | yes | capital |
| Central African Rep. | `CAF` | 1 | 324 | yes | yes | yes | yes | — |
| Chad | `TCD` | 1 | 291 | yes | yes | yes | yes | — |
| Chile | `CHL` | 31 | 2006 | yes | yes | yes | yes | — |
| China | `CHN` | 13 | 2662 | yes | yes | yes | yes | — |
| Colombia | `COL` | 2 | 623 | yes | yes | yes | yes | — |
| Comoros | `COM` | 3 | 35 | yes | yes | yes | yes | — |
| Congo | `COG` | 1 | 323 | yes | yes | yes | yes | — |
| Cook Is. | `COK` | 1 | 11 | no | yes | yes | yes | capital |
| Costa Rica | `CRI` | 1 | 133 | yes | yes | yes | yes | — |
| Croatia | `HRV` | 13 | 374 | yes | yes | yes | yes | — |
| Cuba | `CUB` | 7 | 305 | yes | yes | yes | yes | — |
| Curaçao | `CUW` | 1 | 10 | no | yes | yes | yes | capital |
| Cyprus | `CYP` | 1 | 56 | yes | yes | yes | yes | — |
| Czechia | `CZE` | 1 | 240 | yes | yes | yes | yes | — |
| Côte d'Ivoire | `CIV` | 2 | 294 | yes | yes | yes | yes | — |
| Dem. Rep. Congo | `COD` | 1 | 608 | yes | yes | yes | yes | — |
| Denmark | `DNK` | 12 | 297 | yes | yes | yes | yes | — |
| Djibouti | `DJI` | 1 | 56 | yes | yes | yes | yes | — |
| Dominica | `DMA` | 1 | 10 | yes | yes | yes | yes | — |
| Dominican Rep. | `DOM` | 1 | 112 | yes | yes | yes | yes | — |
| Ecuador | `ECU` | 9 | 347 | yes | yes | yes | yes | — |
| Egypt | `EGY` | 1 | 253 | yes | yes | yes | yes | — |
| El Salvador | `SLV` | 1 | 74 | yes | yes | yes | yes | — |
| Eq. Guinea | `GNQ` | 2 | 67 | yes | yes | yes | yes | — |
| Eritrea | `ERI` | 3 | 192 | yes | yes | yes | yes | — |
| Estonia | `EST` | 4 | 195 | yes | yes | yes | yes | — |
| Ethiopia | `ETH` | 1 | 302 | yes | yes | yes | yes | — |
| Faeroe Is. | `FRO` | 5 | 63 | no | yes | yes | yes | capital |
| Falkland Is. | `FLK` | 6 | 149 | no | yes | yes | yes | capital |
| Fiji | `FJI` | 21 | 279 | yes | yes | yes | yes | — |
| Finland | `FIN` | 8 | 519 | yes | yes | yes | yes | — |
| Fr. Polynesia | `PYF` | 21 | 185 | no | yes | yes | yes | capital |
| Fr. S. Antarctic Lands | `ATF` | 3 | 119 | no | yes | yes | yes | capital |
| France | `FRA` | 10 | 817 | yes | yes | yes | yes | — |
| Gabon | `GAB` | 1 | 271 | yes | yes | yes | yes | — |
| Gambia | `GMB` | 1 | 73 | yes | yes | yes | yes | — |
| Georgia | `GEO` | 1 | 164 | yes | yes | yes | yes | — |
| Germany | `DEU` | 6 | 561 | yes | yes | yes | yes | — |
| Ghana | `GHA` | 1 | 213 | yes | yes | yes | yes | — |
| Greece | `GRC` | 40 | 923 | yes | yes | yes | yes | — |
| Greenland | `GRL` | 17 | 2240 | no | yes | yes | yes | capital |
| Grenada | `GRD` | 1 | 9 | yes | yes | yes | yes | — |
| Guam | `GUM` | 1 | 12 | no | yes | yes | yes | capital |
| Guatemala | `GTM` | 1 | 115 | yes | yes | yes | yes | — |
| Guernsey | `GGY` | 1 | 7 | no | yes | yes | yes | capital |
| Guinea | `GIN` | 1 | 348 | yes | yes | yes | yes | — |
| Guinea-Bissau | `GNB` | 7 | 155 | yes | yes | yes | yes | — |
| Guyana | `GUY` | 1 | 287 | yes | yes | yes | yes | — |
| Haiti | `HTI` | 3 | 112 | yes | yes | yes | yes | — |
| Heard I. and McDonald Is. | `HMD` | 1 | 15 | no | yes | yes | yes | capital |
| Honduras | `HND` | 3 | 207 | yes | yes | yes | yes | — |
| Hong Kong | `HKG` | 3 | 39 | no | yes | yes | yes | capital |
| Hungary | `HUN` | 1 | 213 | yes | yes | yes | yes | — |
| Iceland | `ISL` | 1 | 453 | yes | yes | yes | yes | — |
| India | `IND` | 14 | 1518 | yes | yes | yes | yes | — |
| Indian Ocean Ter. | `IOA` | 3 | 34 | no | yes | yes | yes | ISO alpha-2, ISO alpha-3, capital |
| Indonesia | `IDN` | 133 | 3717 | yes | yes | yes | yes | — |
| Iran | `IRN` | 2 | 605 | yes | yes | yes | yes | — |
| Iraq | `IRQ` | 1 | 233 | yes | yes | yes | yes | — |
| Ireland | `IRL` | 2 | 315 | yes | yes | yes | yes | — |
| Isle of Man | `IMN` | 1 | 15 | no | yes | yes | yes | capital |
| Israel | `ISR` | 1 | 105 | yes | yes | yes | yes | — |
| Italy | `ITA` | 8 | 608 | yes | yes | yes | yes | — |
| Jamaica | `JAM` | 1 | 48 | yes | yes | yes | yes | — |
| Japan | `JPN` | 34 | 1097 | yes | yes | yes | yes | — |
| Jersey | `JEY` | 1 | 9 | no | yes | yes | yes | capital |
| Jordan | `JOR` | 1 | 95 | yes | yes | yes | yes | — |
| Kazakhstan | `KAZ` | 4 | 1140 | yes | yes | yes | yes | — |
| Kenya | `KEN` | 2 | 225 | yes | yes | yes | yes | — |
| Kiribati | `KIR` | 19 | 212 | yes | yes | yes | yes | — |
| Kosovo | `KOS` | 1 | 71 | yes | yes | yes | yes | ISO alpha-3 |
| Kuwait | `KWT` | 2 | 67 | yes | yes | yes | yes | — |
| Kyrgyzstan | `KGZ` | 1 | 388 | yes | yes | yes | yes | — |
| Laos | `LAO` | 1 | 390 | yes | yes | yes | yes | — |
| Latvia | `LVA` | 1 | 140 | yes | yes | yes | yes | — |
| Lebanon | `LBN` | 1 | 62 | yes | yes | yes | yes | — |
| Lesotho | `LSO` | 1 | 77 | yes | yes | yes | yes | — |
| Liberia | `LBR` | 1 | 139 | yes | yes | yes | yes | — |
| Libya | `LBY` | 1 | 255 | yes | yes | yes | yes | — |
| Liechtenstein | `LIE` | 1 | 15 | yes | yes | yes | yes | — |
| Lithuania | `LTU` | 2 | 155 | yes | yes | yes | yes | — |
| Luxembourg | `LUX` | 1 | 46 | yes | yes | yes | yes | — |
| Macao | `MAC` | 1 | 9 | no | yes | yes | yes | capital |
| Madagascar | `MDG` | 3 | 266 | yes | yes | yes | yes | — |
| Malawi | `MWI` | 3 | 245 | yes | yes | yes | yes | — |
| Malaysia | `MYS` | 9 | 509 | yes | yes | yes | yes | — |
| Maldives | `MDV` | 2 | 22 | yes | yes | yes | yes | — |
| Mali | `MLI` | 1 | 474 | yes | yes | yes | yes | — |
| Malta | `MLT` | 2 | 16 | yes | yes | yes | yes | — |
| Marshall Is. | `MHL` | 5 | 47 | yes | yes | yes | yes | — |
| Mauritania | `MRT` | 2 | 321 | yes | yes | yes | yes | — |
| Mauritius | `MUS` | 1 | 19 | yes | yes | yes | yes | — |
| Mexico | `MEX` | 16 | 1012 | yes | yes | yes | yes | — |
| Micronesia | `FSM` | 5 | 49 | yes | yes | yes | yes | — |
| Moldova | `MDA` | 1 | 149 | yes | yes | yes | yes | — |
| Monaco | `MCO` | 1 | 7 | yes | yes | yes | yes | — |
| Mongolia | `MNG` | 1 | 736 | yes | yes | yes | yes | — |
| Montenegro | `MNE` | 1 | 92 | yes | yes | yes | yes | — |
| Montserrat | `MSR` | 1 | 7 | no | yes | yes | yes | capital |
| Morocco | `MAR` | 1 | 366 | yes | yes | yes | yes | — |
| Mozambique | `MOZ` | 1 | 469 | yes | yes | yes | yes | — |
| Myanmar | `MMR` | 19 | 842 | yes | yes | yes | yes | — |
| N. Cyprus | `CYN` | 1 | 44 | no | yes | yes | yes | ISO alpha-2, ISO alpha-3, capital |
| N. Mariana Is. | `MNP` | 6 | 46 | no | yes | yes | yes | capital |
| Namibia | `NAM` | 1 | 235 | yes | yes | yes | yes | — |
| Nauru | `NRU` | 1 | 8 | no | yes | yes | yes | capital |
| Nepal | `NPL` | 1 | 202 | yes | yes | yes | yes | — |
| Netherlands | `NLD` | 12 | 261 | yes | yes | yes | yes | — |
| New Caledonia | `NCL` | 6 | 127 | no | yes | yes | yes | capital |
| New Zealand | `NZL` | 13 | 775 | yes | yes | yes | yes | — |
| Nicaragua | `NIC` | 1 | 176 | yes | yes | yes | yes | — |
| Niger | `NER` | 1 | 254 | yes | yes | yes | yes | — |
| Nigeria | `NGA` | 2 | 364 | yes | yes | yes | yes | — |
| Niue | `NIU` | 1 | 8 | no | yes | yes | yes | capital |
| Norfolk Island | `NFK` | 1 | 25 | no | yes | yes | yes | capital |
| North Korea | `PRK` | 2 | 257 | yes | yes | yes | yes | — |
| North Macedonia | `MKD` | 1 | 80 | yes | yes | yes | yes | — |
| Norway | `NOR` | 32 | 1985 | yes | yes | yes | yes | — |
| Oman | `OMN` | 4 | 243 | yes | yes | yes | yes | — |
| Pakistan | `PAK` | 1 | 571 | yes | yes | yes | yes | — |
| Palau | `PLW` | 2 | 21 | yes | yes | yes | yes | — |
| Palestine | `PSE` | 2 | 50 | no | yes | yes | yes | capital |
| Panama | `PAN` | 5 | 246 | yes | yes | yes | yes | — |
| Papua New Guinea | `PNG` | 26 | 766 | yes | yes | yes | yes | — |
| Paraguay | `PRY` | 1 | 257 | yes | yes | yes | yes | — |
| Peru | `PER` | 1 | 588 | yes | yes | yes | yes | — |
| Philippines | `PHL` | 48 | 1238 | yes | yes | yes | yes | — |
| Pitcairn Is. | `PCN` | 1 | 9 | no | yes | yes | yes | capital |
| Poland | `POL` | 1 | 316 | yes | yes | yes | yes | — |
| Portugal | `PRT` | 9 | 265 | yes | yes | yes | yes | — |
| Puerto Rico | `PRI` | 3 | 69 | no | yes | yes | yes | capital |
| Qatar | `QAT` | 1 | 34 | yes | yes | yes | yes | — |
| Romania | `ROU` | 1 | 274 | yes | yes | yes | yes | — |
| Russia | `RUS` | 101 | 7450 | yes | yes | yes | yes | — |
| Rwanda | `RWA` | 1 | 83 | yes | yes | yes | yes | — |
| S. Geo. and the Is. | `SGS` | 2 | 63 | no | yes | yes | yes | capital |
| S. Sudan | `SSD` | 1 | 325 | no | yes | yes | yes | capital |
| Saint Helena | `SHN` | 2 | 18 | no | yes | yes | yes | capital |
| Saint Lucia | `LCA` | 1 | 10 | yes | yes | yes | yes | — |
| Samoa | `WSM` | 2 | 27 | yes | yes | yes | yes | — |
| San Marino | `SMR` | 1 | 7 | yes | yes | yes | yes | — |
| Saudi Arabia | `SAU` | 4 | 436 | yes | yes | yes | yes | — |
| Senegal | `SEN` | 1 | 243 | yes | yes | yes | yes | — |
| Serbia | `SRB` | 1 | 267 | yes | yes | yes | yes | — |
| Seychelles | `SYC` | 1 | 8 | yes | yes | yes | yes | — |
| Siachen Glacier | `KAS` | 1 | 21 | no | yes | yes | yes | ISO alpha-2, ISO alpha-3, capital |
| Sierra Leone | `SLE` | 2 | 126 | yes | yes | yes | yes | — |
| Singapore | `SGP` | 1 | 9 | yes | yes | yes | yes | — |
| Sint Maarten | `SXM` | 1 | 7 | no | yes | yes | yes | capital |
| Slovakia | `SVK` | 1 | 145 | yes | yes | yes | yes | — |
| Slovenia | `SVN` | 1 | 132 | yes | yes | yes | yes | — |
| Solomon Is. | `SLB` | 21 | 335 | yes | yes | yes | yes | — |
| Somalia | `SOM` | 1 | 143 | yes | **no** | yes | yes | population |
| Somaliland | `SOL` | 1 | 79 | yes | yes | yes | yes | ISO alpha-2, ISO alpha-3 |
| South Africa | `ZAF` | 2 | 442 | yes | yes | yes | yes | — |
| South Korea | `KOR` | 11 | 260 | yes | yes | yes | yes | — |
| Spain | `ESP` | 12 | 538 | yes | yes | yes | yes | — |
| Sri Lanka | `LKA` | 3 | 92 | yes | yes | yes | yes | — |
| St-Barthélemy | `BLM` | 1 | 11 | no | yes | yes | yes | capital |
| St-Martin | `MAF` | 1 | 7 | no | yes | yes | yes | capital |
| St. Kitts and Nevis | `KNA` | 2 | 20 | yes | yes | yes | yes | — |
| St. Pierre and Miquelon | `SPM` | 2 | 24 | no | yes | yes | yes | capital |
| St. Vin. and Gren. | `VCT` | 3 | 49 | yes | yes | yes | yes | — |
| Sudan | `SDN` | 1 | 445 | yes | yes | yes | yes | — |
| Suriname | `SUR` | 1 | 184 | yes | yes | yes | yes | — |
| Sweden | `SWE` | 6 | 593 | yes | yes | yes | yes | — |
| Switzerland | `CHE` | 1 | 187 | yes | yes | yes | yes | — |
| Syria | `SYR` | 1 | 173 | yes | yes | yes | yes | — |
| São Tomé and Principe | `STP` | 2 | 22 | yes | yes | yes | yes | — |
| Taiwan | `TWN` | 2 | 67 | yes | yes | yes | yes | — |
| Tajikistan | `TJK` | 3 | 369 | yes | yes | yes | yes | — |
| Tanzania | `TZA` | 4 | 376 | yes | yes | yes | yes | — |
| Thailand | `THA` | 10 | 578 | yes | yes | yes | yes | — |
| Timor-Leste | `TLS` | 3 | 70 | yes | yes | yes | yes | — |
| Togo | `TGO` | 1 | 130 | yes | yes | yes | yes | — |
| Tonga | `TON` | 3 | 32 | yes | yes | yes | yes | — |
| Trinidad and Tobago | `TTO` | 2 | 38 | yes | yes | yes | yes | — |
| Tunisia | `TUN` | 3 | 186 | yes | yes | yes | yes | — |
| Turkey | `TUR` | 3 | 562 | yes | yes | yes | yes | — |
| Turkmenistan | `TKM` | 2 | 433 | yes | yes | yes | yes | — |
| Turks and Caicos Is. | `TCA` | 3 | 29 | no | yes | yes | yes | capital |
| Tuvalu | `TUV` | 1 | 10 | yes | yes | yes | yes | — |
| U.S. Virgin Is. | `VIR` | 3 | 19 | no | yes | yes | yes | capital |
| Uganda | `UGA` | 1 | 179 | yes | yes | yes | yes | — |
| Ukraine | `UKR` | 2 | 635 | yes | yes | yes | yes | — |
| United Arab Emirates | `ARE` | 5 | 183 | yes | yes | yes | yes | — |
| United Kingdom | `GBR` | 23 | 986 | yes | yes | yes | yes | — |
| United States of America | `USA` | 127 | 5749 | yes | yes | yes | yes | — |
| Uruguay | `URY` | 1 | 143 | yes | yes | yes | yes | — |
| Uzbekistan | `UZB` | 3 | 584 | yes | yes | yes | yes | — |
| Vanuatu | `VUT` | 14 | 186 | yes | yes | yes | yes | — |
| Vatican | `VAT` | 1 | 5 | yes | yes | **no** | **no** | GDP, area |
| Venezuela | `VEN` | 5 | 567 | yes | yes | yes | yes | — |
| Vietnam | `VNM` | 8 | 613 | yes | yes | yes | yes | — |
| W. Sahara | `ESH` | 1 | 227 | no | yes | yes | yes | capital |
| Wallis and Futuna Is. | `WLF` | 2 | 16 | no | yes | yes | yes | capital |
| Yemen | `YEM` | 5 | 225 | yes | yes | yes | yes | — |
| Zambia | `ZMB` | 1 | 376 | yes | yes | yes | yes | — |
| Zimbabwe | `ZWE` | 1 | 169 | yes | yes | yes | yes | — |
| eSwatini | `SWZ` | 1 | 38 | yes | yes | yes | yes | — |
| Åland | `ALA` | 3 | 52 | no | yes | yes | yes | capital |
