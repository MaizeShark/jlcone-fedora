# jlcone-fedora
## Install (Fedora)

Unofficial dnf repository that repackages the official JLCONE `.deb` as a signed RPM.
It is checked daily and only rebuilt when JLCPCB publishes a new version.

```sh
sudo curl -fLo /etc/yum.repos.d/jlcone.repo https://maizeshark.github.io/jlcone-fedora/jlcone.repo
sudo dnf install jlcone
```

Updates then arrive with `dnf upgrade`. The in-app updater does not work on Fedora (it needs `dpkg`/`apt`).

To build locally instead: `./build-rpm.sh [output-dir]`.

Signing key fingerprint: see `RPM-GPG-KEY-jlcone`.
