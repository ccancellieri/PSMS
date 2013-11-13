#!/bin/bash

# example
# ./run.sh ../GPX\ files_\ Benin_Bensekou\ 21-10-2013/

if [ -Z $2 ]; then
	IMPORTER=`pwd`"/gpxImporter.sql"
fi
psql -d gis -U postgres -f ${IMPORTER}
cd "$1"
for i in `ls *.gpx`; do
	echo "Processing $i"
	ogr2ogr -update -overwrite -f postgresql PG:"dbname='gis' host='168.202.25.219' port='5432' user='postgres' password='postgres'" $i;
	if [ ! $? -eq 0 ]; then
		echo "Error on file: $i"
	else
		psql -d gis -U postgres -c "SELECT * FROM gpxImporter(false);"
	fi
#	ogr2ogr -f postgresql -update -append PG:"dbname='gis' host='168.202.25.219' port='5432' user='postgres' password='postgres'" $i;
#	ogr2ogr -lco TEMPORARY=YES  -f PGDump $i.sql $i;
#	ogr2ogr -lco TEMPORARY=YES -lco PG_USE_COPY=YES -lco DROP_TABLE=NO -lco CREATE_TABLE=NO -f PGDump $i.sql $i;
#	ogr2ogr -append -lco PG_USE_COPY=YES -f PGDump $i.sql $i;
#	psql -d gis -U postgres -f $i.sql;
	
#	read -p "File $i processed, press [Enter]"
done
# refresh materialized views
psql -d gis -U postgres -c "SELECT * FROM gpxImporter(true);"
