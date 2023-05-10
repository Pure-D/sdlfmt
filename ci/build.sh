set -e
set -x

dub build --compiler=ldc2 --build=$BUILD --arch=$ARCH
strip sdlfmt
if [ "$CROSS" = 1 ]; then
	ls sdlfmt
else
	./sdlfmt --help
fi

tar cfJ sdlfmt.tar.xz sdlfmt
