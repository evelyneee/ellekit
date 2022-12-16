
## ElleKit setup

- turn off sip
- enable arm64e 
    - `sudo nvram boot-args=-arm64e_preview_abi`
- reboot
- make tweak directory in ~/.tweaks
- copy tweaks into it
- put libinjector and libsubtrate in `/usr/local/lib`
- enable injection
    - `launchctl setenv DYLD_INSERT_LIBRARIES "/usr/local/lib/libinjector.dylib"`
- optional: for Dock injection, kill Dock
    - `killall Dock`
