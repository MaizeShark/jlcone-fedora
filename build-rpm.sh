#!/usr/bin/env bash
# Build an RPM of JLCONE (JLCPCB desktop client) from the official .deb.
# The download URL is resolved via the same API the https://jlcone.com/download page uses.
# Requires: curl, jq, ar (binutils), tar, xz, rpmbuild (rpm-build)
set -euo pipefail

API="https://jlcone.com/api/overseas-core-platform/baseDataConfig/checkUpdate"
OUT="${1:-$PWD}"

for t in curl jq ar tar rpmbuild; do
  command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo ">> Resolving latest Linux .deb"
resp=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d '{"platform":"linux","versionCode":"0"}' "$API")
url=$(jq -er '.data.updateUrl' <<<"$resp")
version=$(jq -er '.data.versionCode' <<<"$resp")
echo "   $version -> $url"

echo ">> Downloading"
curl -fL --progress-bar -o "$work/jlcone.deb" "$url"

echo ">> Extracting"
root="$work/root"
mkdir -p "$root"
(cd "$work" && ar x jlcone.deb)
tar -xf "$work"/data.tar.* -C "$root"

# Fix up the sandbox helper permissions (Electron needs it setuid root)
chmod 4755 "$root/opt/JLCONE/chrome-sandbox"

# Expose the binary on PATH
mkdir -p "$root/usr/bin"
ln -sf /opt/JLCONE/jlcone "$root/usr/bin/jlcone"

cat >"$work/jlcone.spec" <<EOF
%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
AutoReqProv: no

Name:       jlcone
Version:    $version
Release:    1%{?dist}
Summary:    JLCONE - JLCPCB Desktop Client
License:    ISC
URL:        https://www.jlcpcb.com
ExclusiveArch: x86_64
Requires:   gtk3, libnotify, nss, libXScrnSaver, libXtst, xdg-utils, at-spi2-core, libuuid, libsecret, libdrm, mesa-libgbm, alsa-lib
Recommends: libappindicator-gtk3

%description
JLCONE - JLCPCB Desktop Client (repackaged from the official .deb).

%install
mkdir -p %{buildroot}
cp -a $root/. %{buildroot}/

%files
/opt/JLCONE
/usr/bin/jlcone
/usr/share/*

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') Repack <noreply@localhost> - $version-1
- Repackaged from official .deb
EOF

echo ">> Building RPM"
rpmbuild -bb --define "_topdir $work/rpmbuild" --define "_rpmdir $OUT" "$work/jlcone.spec" >"$work/rpmbuild.log" 2>&1 || { cat "$work/rpmbuild.log" >&2; exit 1; }

rpm=$(find "$OUT" -name "jlcone-$version-*.rpm" -newer "$work/jlcone.deb" | head -1)
echo ">> Done: $rpm"
echo "   Install with: sudo dnf install $rpm"
