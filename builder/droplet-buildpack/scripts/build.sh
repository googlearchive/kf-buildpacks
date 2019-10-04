#!/usr/bin/env bash

set -eux

rootpath=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p $rootpath/lib

BPALC_URL=https://github.com/cloudfoundry/buildpackapplifecycle
BPALC_COMMIT=f22d009281fd0ce6ba15c088715a342e9bf4355d
BPALC_SHA256=47fa78c1a1ff41048b8183a923d653494b63d6063d6cd8ccd885f7ace5f82606

tempdir=$(mktemp -d)
pushd $tempdir
curl -LJo bpalc.tar.gz $BPALC_URL/archive/$BPALC_COMMIT.tar.gz
[ "$BPALC_SHA256" = "$(cat bpalc.tar.gz | sha256sum | cut -d' ' -f1)" ]
tar xfz bpalc.tar.gz
# export GOPATH=$tempdir
mkdir -p src/code.cloudfoundry.org
mv buildpackapplifecycle-$BPALC_COMMIT src/code.cloudfoundry.org/buildpackapplifecycle
pushd src/code.cloudfoundry.org/buildpackapplifecycle
go mod init
go build -o $rootpath/lib/builder ./builder/
go build -o $rootpath/lib/launcher ./launcher/
popd
popd

