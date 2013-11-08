createdb $1
createlang plpgsql $1
cd $2
psql -d $1 -f postgis.sql
psql -d $1 -f spatial_ref_sys.sql
psql -d $1 -f postgis_comments.sql
psql -d $1 -f raster_comments.sql
psql -d $1 -f postgis_comments.sql
psql -d $1 -f topology/topology_comments.sql
psql -d $1 -f legacy.sql
