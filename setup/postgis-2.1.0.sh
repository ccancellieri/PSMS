wget http://download.osgeo.org/postgis/source/postgis-2.1.0.tar.gz
tar -xvzf postgis-2.1.0.tar.gz
cd postgis-2.1.0
yum install proj proj-devel postgresql-devel libxml2 geos-devel
./configure --with-pgconfig=/usr/pgsql-9.3/bin/pg_config
make -j8
