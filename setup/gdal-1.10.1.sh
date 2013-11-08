 yum install expat-devel.i686
wget http://download.osgeo.org/gdal/1.10.1/gdal1101.zip
unzip gdal1101.zip

LTFLAGS=--tag=gpp ./configure --with-pg=/usr/pgsql-9.3/bin/pg_config
make -j8
make install
