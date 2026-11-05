# Which countries you can start a campaign as

## The short version

Of the **242** records in the world atlas, **206** can be chosen as a starting nation and **36** cannot, in this version of the game.

Every record can still be searched, tapped on the map and read in the country dossier. The rule only decides who you can *play as* when you start a new campaign.

## The rule

A record can be a starting nation when its **source classification** (the `type` field from the Natural Earth dataset) is one of:

* `Sovereign country`
* `Country`
* `Sovereignty`

Everything else shows this message when selected: *"Not available as a starting nation in this version."*

This is written in the dataset's own classification values. It does not name any individual place, and it says nothing about whether a place is real, recognised or important — only that this version does not let you play as it.

**This rule is a default for the owner to review, not a final decision.** It is stored in one file, `data/world/start_eligibility.json`. To allow more records, add their `type` value to `eligible_types` in that file; to allow fewer, remove one. No code changes are needed, and validation will follow immediately.

> This is a default rule for the project owner to review, not a final decision. It is written in Natural Earth's own TYPE values and names no individual place. Edit eligible_types to allow more or fewer records; nothing else in the code needs to change.

## Eligible starting nations

| Stable ID | Name | Source type | Region |
| --- | --- | --- | --- |
| `AFG` | Afghanistan | `Sovereign country` | Asia |
| `ALB` | Albania | `Sovereign country` | Europe |
| `DZA` | Algeria | `Sovereign country` | Africa |
| `AND` | Andorra | `Sovereign country` | Europe |
| `AGO` | Angola | `Sovereign country` | Africa |
| `ATG` | Antigua and Barb. | `Sovereign country` | North America |
| `ARG` | Argentina | `Sovereign country` | South America |
| `ARM` | Armenia | `Sovereign country` | Asia |
| `ABW` | Aruba | `Country` | North America |
| `AUS` | Australia | `Country` | Oceania |
| `AUT` | Austria | `Sovereign country` | Europe |
| `AZE` | Azerbaijan | `Sovereign country` | Asia |
| `BHS` | Bahamas | `Sovereign country` | North America |
| `BHR` | Bahrain | `Sovereign country` | Asia |
| `BGD` | Bangladesh | `Sovereign country` | Asia |
| `BRB` | Barbados | `Sovereign country` | North America |
| `BLR` | Belarus | `Sovereign country` | Europe |
| `BEL` | Belgium | `Sovereign country` | Europe |
| `BLZ` | Belize | `Sovereign country` | North America |
| `BEN` | Benin | `Sovereign country` | Africa |
| `BTN` | Bhutan | `Sovereign country` | Asia |
| `BOL` | Bolivia | `Sovereign country` | South America |
| `BIH` | Bosnia and Herz. | `Sovereign country` | Europe |
| `BWA` | Botswana | `Sovereign country` | Africa |
| `BRA` | Brazil | `Sovereign country` | South America |
| `BRN` | Brunei | `Sovereign country` | Asia |
| `BGR` | Bulgaria | `Sovereign country` | Europe |
| `BFA` | Burkina Faso | `Sovereign country` | Africa |
| `BDI` | Burundi | `Sovereign country` | Africa |
| `CPV` | Cabo Verde | `Sovereign country` | Africa |
| `KHM` | Cambodia | `Sovereign country` | Asia |
| `CMR` | Cameroon | `Sovereign country` | Africa |
| `CAN` | Canada | `Sovereign country` | North America |
| `CAF` | Central African Rep. | `Sovereign country` | Africa |
| `TCD` | Chad | `Sovereign country` | Africa |
| `CHL` | Chile | `Sovereign country` | South America |
| `CHN` | China | `Country` | Asia |
| `COL` | Colombia | `Sovereign country` | South America |
| `COM` | Comoros | `Sovereign country` | Africa |
| `COG` | Congo | `Sovereign country` | Africa |
| `CRI` | Costa Rica | `Sovereign country` | North America |
| `HRV` | Croatia | `Sovereign country` | Europe |
| `CUB` | Cuba | `Sovereignty` | North America |
| `CUW` | Curaçao | `Country` | North America |
| `CYP` | Cyprus | `Sovereign country` | Asia |
| `CZE` | Czechia | `Sovereign country` | Europe |
| `CIV` | Côte d'Ivoire | `Sovereign country` | Africa |
| `COD` | Dem. Rep. Congo | `Sovereign country` | Africa |
| `DNK` | Denmark | `Country` | Europe |
| `DJI` | Djibouti | `Sovereign country` | Africa |
| `DMA` | Dominica | `Sovereign country` | North America |
| `DOM` | Dominican Rep. | `Sovereign country` | North America |
| `ECU` | Ecuador | `Sovereign country` | South America |
| `EGY` | Egypt | `Sovereign country` | Africa |
| `SLV` | El Salvador | `Sovereign country` | North America |
| `GNQ` | Eq. Guinea | `Sovereign country` | Africa |
| `ERI` | Eritrea | `Sovereign country` | Africa |
| `EST` | Estonia | `Sovereign country` | Europe |
| `ETH` | Ethiopia | `Sovereign country` | Africa |
| `FJI` | Fiji | `Sovereign country` | Oceania |
| `FIN` | Finland | `Country` | Europe |
| `FRA` | France | `Country` | Europe |
| `GAB` | Gabon | `Sovereign country` | Africa |
| `GMB` | Gambia | `Sovereign country` | Africa |
| `GEO` | Georgia | `Sovereign country` | Asia |
| `DEU` | Germany | `Sovereign country` | Europe |
| `GHA` | Ghana | `Sovereign country` | Africa |
| `GRC` | Greece | `Sovereign country` | Europe |
| `GRL` | Greenland | `Country` | North America |
| `GRD` | Grenada | `Sovereign country` | North America |
| `GTM` | Guatemala | `Sovereign country` | North America |
| `GGY` | Guernsey | `Country` | Europe |
| `GIN` | Guinea | `Sovereign country` | Africa |
| `GNB` | Guinea-Bissau | `Sovereign country` | Africa |
| `GUY` | Guyana | `Sovereign country` | South America |
| `HTI` | Haiti | `Sovereign country` | North America |
| `HND` | Honduras | `Sovereign country` | North America |
| `HKG` | Hong Kong | `Country` | Asia |
| `HUN` | Hungary | `Sovereign country` | Europe |
| `ISL` | Iceland | `Sovereign country` | Europe |
| `IND` | India | `Sovereign country` | Asia |
| `IDN` | Indonesia | `Sovereign country` | Asia |
| `IRN` | Iran | `Sovereign country` | Asia |
| `IRQ` | Iraq | `Sovereign country` | Asia |
| `IRL` | Ireland | `Sovereign country` | Europe |
| `IMN` | Isle of Man | `Country` | Europe |
| `ITA` | Italy | `Sovereign country` | Europe |
| `JAM` | Jamaica | `Sovereign country` | North America |
| `JPN` | Japan | `Sovereign country` | Asia |
| `JEY` | Jersey | `Country` | Europe |
| `JOR` | Jordan | `Sovereign country` | Asia |
| `KAZ` | Kazakhstan | `Sovereignty` | Asia |
| `KEN` | Kenya | `Sovereign country` | Africa |
| `KIR` | Kiribati | `Sovereign country` | Oceania |
| `KWT` | Kuwait | `Sovereign country` | Asia |
| `KGZ` | Kyrgyzstan | `Sovereign country` | Asia |
| `LAO` | Laos | `Sovereign country` | Asia |
| `LVA` | Latvia | `Sovereign country` | Europe |
| `LBN` | Lebanon | `Sovereign country` | Asia |
| `LSO` | Lesotho | `Sovereign country` | Africa |
| `LBR` | Liberia | `Sovereign country` | Africa |
| `LBY` | Libya | `Sovereign country` | Africa |
| `LIE` | Liechtenstein | `Sovereign country` | Europe |
| `LTU` | Lithuania | `Sovereign country` | Europe |
| `LUX` | Luxembourg | `Sovereign country` | Europe |
| `MAC` | Macao | `Country` | Asia |
| `MDG` | Madagascar | `Sovereign country` | Africa |
| `MWI` | Malawi | `Sovereign country` | Africa |
| `MYS` | Malaysia | `Sovereign country` | Asia |
| `MDV` | Maldives | `Sovereign country` | Seven seas (open ocean) |
| `MLI` | Mali | `Sovereign country` | Africa |
| `MLT` | Malta | `Sovereign country` | Europe |
| `MHL` | Marshall Is. | `Sovereign country` | Oceania |
| `MRT` | Mauritania | `Sovereign country` | Africa |
| `MUS` | Mauritius | `Sovereign country` | Seven seas (open ocean) |
| `MEX` | Mexico | `Sovereign country` | North America |
| `FSM` | Micronesia | `Sovereign country` | Oceania |
| `MDA` | Moldova | `Sovereign country` | Europe |
| `MCO` | Monaco | `Sovereign country` | Europe |
| `MNG` | Mongolia | `Sovereign country` | Asia |
| `MNE` | Montenegro | `Sovereign country` | Europe |
| `MAR` | Morocco | `Sovereign country` | Africa |
| `MOZ` | Mozambique | `Sovereign country` | Africa |
| `MMR` | Myanmar | `Sovereign country` | Asia |
| `CYN` | N. Cyprus | `Sovereign country` | Asia |
| `NAM` | Namibia | `Sovereign country` | Africa |
| `NRU` | Nauru | `Sovereign country` | Oceania |
| `NPL` | Nepal | `Sovereign country` | Asia |
| `NLD` | Netherlands | `Country` | Europe |
| `NZL` | New Zealand | `Country` | Oceania |
| `NIC` | Nicaragua | `Sovereign country` | North America |
| `NER` | Niger | `Sovereign country` | Africa |
| `NGA` | Nigeria | `Sovereign country` | Africa |
| `PRK` | North Korea | `Sovereign country` | Asia |
| `MKD` | North Macedonia | `Sovereign country` | Europe |
| `NOR` | Norway | `Sovereign country` | Europe |
| `OMN` | Oman | `Sovereign country` | Asia |
| `PAK` | Pakistan | `Sovereign country` | Asia |
| `PLW` | Palau | `Sovereign country` | Oceania |
| `PAN` | Panama | `Sovereign country` | North America |
| `PNG` | Papua New Guinea | `Sovereign country` | Oceania |
| `PRY` | Paraguay | `Sovereign country` | South America |
| `PER` | Peru | `Sovereign country` | South America |
| `PHL` | Philippines | `Sovereign country` | Asia |
| `POL` | Poland | `Sovereign country` | Europe |
| `PRT` | Portugal | `Sovereign country` | Europe |
| `QAT` | Qatar | `Sovereign country` | Asia |
| `ROU` | Romania | `Sovereign country` | Europe |
| `RUS` | Russia | `Sovereign country` | Europe |
| `RWA` | Rwanda | `Sovereign country` | Africa |
| `SSD` | S. Sudan | `Sovereign country` | Africa |
| `LCA` | Saint Lucia | `Sovereign country` | North America |
| `WSM` | Samoa | `Sovereign country` | Oceania |
| `SMR` | San Marino | `Sovereign country` | Europe |
| `SAU` | Saudi Arabia | `Sovereign country` | Asia |
| `SEN` | Senegal | `Sovereign country` | Africa |
| `SRB` | Serbia | `Sovereign country` | Europe |
| `SYC` | Seychelles | `Sovereign country` | Seven seas (open ocean) |
| `SLE` | Sierra Leone | `Sovereign country` | Africa |
| `SGP` | Singapore | `Sovereign country` | Asia |
| `SXM` | Sint Maarten | `Country` | North America |
| `SVK` | Slovakia | `Sovereign country` | Europe |
| `SVN` | Slovenia | `Sovereign country` | Europe |
| `SLB` | Solomon Is. | `Sovereign country` | Oceania |
| `SOM` | Somalia | `Sovereign country` | Africa |
| `SOL` | Somaliland | `Sovereign country` | Africa |
| `ZAF` | South Africa | `Sovereign country` | Africa |
| `KOR` | South Korea | `Sovereign country` | Asia |
| `ESP` | Spain | `Sovereign country` | Europe |
| `LKA` | Sri Lanka | `Sovereign country` | Asia |
| `KNA` | St. Kitts and Nevis | `Sovereign country` | North America |
| `VCT` | St. Vin. and Gren. | `Sovereign country` | North America |
| `SDN` | Sudan | `Sovereign country` | Africa |
| `SUR` | Suriname | `Sovereign country` | South America |
| `SWE` | Sweden | `Sovereign country` | Europe |
| `CHE` | Switzerland | `Sovereign country` | Europe |
| `SYR` | Syria | `Sovereign country` | Asia |
| `STP` | São Tomé and Principe | `Sovereign country` | Africa |
| `TWN` | Taiwan | `Sovereign country` | Asia |
| `TJK` | Tajikistan | `Sovereign country` | Asia |
| `TZA` | Tanzania | `Sovereign country` | Africa |
| `THA` | Thailand | `Sovereign country` | Asia |
| `TLS` | Timor-Leste | `Sovereign country` | Asia |
| `TGO` | Togo | `Sovereign country` | Africa |
| `TON` | Tonga | `Sovereign country` | Oceania |
| `TTO` | Trinidad and Tobago | `Sovereign country` | North America |
| `TUN` | Tunisia | `Sovereign country` | Africa |
| `TUR` | Turkey | `Sovereign country` | Asia |
| `TKM` | Turkmenistan | `Sovereign country` | Asia |
| `TUV` | Tuvalu | `Sovereign country` | Oceania |
| `UGA` | Uganda | `Sovereign country` | Africa |
| `UKR` | Ukraine | `Sovereign country` | Europe |
| `ARE` | United Arab Emirates | `Sovereign country` | Asia |
| `GBR` | United Kingdom | `Country` | Europe |
| `USA` | United States of America | `Country` | North America |
| `URY` | Uruguay | `Sovereign country` | South America |
| `UZB` | Uzbekistan | `Sovereign country` | Asia |
| `VUT` | Vanuatu | `Sovereign country` | Oceania |
| `VAT` | Vatican | `Sovereign country` | Europe |
| `VEN` | Venezuela | `Sovereign country` | South America |
| `VNM` | Vietnam | `Sovereign country` | Asia |
| `YEM` | Yemen | `Sovereign country` | Asia |
| `ZMB` | Zambia | `Sovereign country` | Africa |
| `ZWE` | Zimbabwe | `Sovereign country` | Africa |
| `SWZ` | eSwatini | `Sovereign country` | Africa |
| `ALA` | Åland | `Country` | Europe |

## Not eligible in this version

| Stable ID | Name | Source type | Region |
| --- | --- | --- | --- |
| `ASM` | American Samoa | `Dependency` | Oceania |
| `AIA` | Anguilla | `Dependency` | North America |
| `ATA` | Antarctica | `Indeterminate` | Antarctica |
| `ATC` | Ashmore and Cartier Is. | `Dependency` | Oceania |
| `BMU` | Bermuda | `Dependency` | North America |
| `IOT` | Br. Indian Ocean Ter. | `Disputed` | Seven seas (open ocean) |
| `VGB` | British Virgin Is. | `Dependency` | North America |
| `CYM` | Cayman Is. | `Dependency` | North America |
| `COK` | Cook Is. | `Dependency` | Oceania |
| `FRO` | Faeroe Is. | `Dependency` | Europe |
| `FLK` | Falkland Is. | `Disputed` | South America |
| `PYF` | Fr. Polynesia | `Dependency` | Oceania |
| `ATF` | Fr. S. Antarctic Lands | `Dependency` | Seven seas (open ocean) |
| `GUM` | Guam | `Dependency` | Oceania |
| `HMD` | Heard I. and McDonald Is. | `Dependency` | Seven seas (open ocean) |
| `IOA` | Indian Ocean Ter. | `Dependency` | Asia |
| `ISR` | Israel | `Disputed` | Asia |
| `KOS` | Kosovo | `Disputed` | Europe |
| `MSR` | Montserrat | `Dependency` | North America |
| `MNP` | N. Mariana Is. | `Dependency` | Oceania |
| `NCL` | New Caledonia | `Dependency` | Oceania |
| `NIU` | Niue | `Dependency` | Oceania |
| `NFK` | Norfolk Island | `Dependency` | Oceania |
| `PSE` | Palestine | `Indeterminate` | Asia |
| `PCN` | Pitcairn Is. | `Dependency` | Oceania |
| `PRI` | Puerto Rico | `Dependency` | North America |
| `SGS` | S. Geo. and the Is. | `Dependency` | Seven seas (open ocean) |
| `SHN` | Saint Helena | `Dependency` | Seven seas (open ocean) |
| `KAS` | Siachen Glacier | `Indeterminate` | Asia |
| `BLM` | St-Barthélemy | `Dependency` | North America |
| `MAF` | St-Martin | `Dependency` | North America |
| `SPM` | St. Pierre and Miquelon | `Dependency` | North America |
| `TCA` | Turks and Caicos Is. | `Dependency` | North America |
| `VIR` | U.S. Virgin Is. | `Dependency` | North America |
| `ESH` | W. Sahara | `Indeterminate` | Africa |
| `WLF` | Wallis and Futuna Is. | `Dependency` | Oceania |

## Keeping this page honest

```bash
python3 tools/report_policies.py          # regenerate this file and DISPUTED_TERRITORIES.md
python3 tools/report_policies.py --check  # CI: fail when either file is stale
```
