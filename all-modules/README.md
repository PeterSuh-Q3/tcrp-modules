Integrated extension driver pack of ARPL_MODULES used for ARPL
(https://github.com/fbelavenuto/arpl-modules) Applied to be usable in TCRP.

like ARPL bromolow | apollolake | broadwell | broadwellnk | v1000 | denverton | Geminilake | r1000 uses 8 platform-specific integrated extension driver packs,

When building the TCRP loader, it must be included as a bundle by default.

Junior automatically detects the device and selectively injects only the necessary driver ko files.
