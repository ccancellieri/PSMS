wget http://download.osgeo.org/gdal/1.10.1/gdal1101.zip
unzip gdal1101.zip

LTFLAGS=--tag=gpp ./configure
make -j8
make install
