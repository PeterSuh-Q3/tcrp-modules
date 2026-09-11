Integrated extension driver pack of ARPL_MODULES used for ARPL
(https://github.com/fbelavenuto/arpl-modules) Applied to be usable in TCRP.

like ARPL bromolow | apollolake | broadwell | broadwellnk | v1000 | denverton | Geminilake | r1000 uses 8 platform-specific integrated extension driver packs,

When building the TCRP loader, it must be included as a bundle by default.

In Junior, EUDEV automatically detects the device and optionally activates the required module files.

## SDHCI pilot build

`build-sdhci-pilot.sh` builds only the `cqhci`, `sdhci`, `sdhci-pci`, and
`sdhci-pci-data` modules from one extracted DSM GPL `src-*` tree. For the
epyc7002 DSM 7.4 pilot, provide the installed DSM build's `.config` and
`Module.symvers`; the script refuses generic configuration or a missing symbol
table so the replacement modules retain compatible version CRCs.

```sh
cd all-modules
SRC_DIR=../src-epyc7002-7.4 \
DSM_CONFIG=../runtime/.config \
MODULE_SYMVERS=../runtime/Module.symvers \
KREL=5.10.55+ \
./build-sdhci-pilot.sh
```
