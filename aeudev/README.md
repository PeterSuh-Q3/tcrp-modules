# MSHELL Manager installer

The loader stores the fixed MSHELL Manager SPK in `/addons`. During `on_os_load`,
this addon installs a one-shot DSM rc.d bootstrapper. It verifies whether the
`MshellManager` package already exists and installs the pinned public SPK only
when it is absent.

The package manager is intentionally never invoked from Junior/initrd.
