-- DROP FUNCTION gpxImporter();
CREATE OR REPLACE FUNCTION gpxImporter() RETURNS boolean AS
$BODY$
DECLARE
  isArea boolean;
  isPlot boolean;
BEGIN

BEGIN
	IF (NOT EXISTS (SELECT name from tracks LIMIT 1)) THEN
		return false;
	END IF;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Table "tracks" does not exists.';	
	return false;
END;

BEGIN
	SELECT count(*) INTO isArea FROM pg_class WHERE relname='area' and relkind='r';
	IF (isArea) THEN
		-- INSERT NEW ROWS
		INSERT INTO area (area_id, hectares,wkb_geometry)
		SELECT name, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,wkb_geometry
			FROM tracks
			WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+$'
				AND
				name NOT IN (SELECT area_id FROM area);
		-- UPDATE EXISTING ROWS
		UPDATE area SET
			area_id = tracks.name,
			hectares = st_area(ST_Transform(ST_ConvexHull(tracks.wkb_geometry),3857))/10000,
			wkb_geometry = tracks.wkb_geometry
		FROM tracks
		WHERE tracks.name=area_id;
		
	END IF;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Table "area" does not exists: creating it.';
	--DROP TABLE IF EXISTS area CASCADE;
	CREATE TABLE area (area_id, hectares,wkb_geometry)
	AS
	(SELECT name, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,wkb_geometry FROM tracks WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+$');

	ALTER TABLE area
	  ADD CONSTRAINT area_id PRIMARY KEY (area_id);
	  
	CREATE INDEX area_geom_idx
	  ON area USING gist (wkb_geometry);
	  
	CREATE INDEX area_idx
	   ON area USING hash (area_id varchar_ops);
END;

BEGIN
	SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot' and relkind='r';
	IF (isPlot) THEN
		-- INSERT NEW ROWS
		INSERT INTO plot (area_id, plot_id, hectares,wkb_geometry)
		SELECT SUBSTRING(name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'), name , st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,wkb_geometry
			FROM tracks 
			WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+-[0-9]+$'
				AND
				name NOT IN (SELECT plot_id FROM plot);
		-- UPDATE EXISTING ROWS
		UPDATE plot SET
			area_id = SUBSTRING(tracks.name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'),
			plot_id = tracks.name,
			hectares = st_area(ST_Transform(ST_ConvexHull(tracks.wkb_geometry),3857))/10000,
			wkb_geometry = tracks.wkb_geometry
		FROM tracks
		WHERE tracks.name=plot_id;
	END IF;
	
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'Table "plot" does not exists: creating it.';

	--DROP TABLE IF EXISTS plot CASCADE;
	CREATE TABLE plot (area_id, plot_id, hectares,wkb_geometry)
	AS
	(SELECT SUBSTRING(name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'), name , st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,wkb_geometry FROM tracks WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+-[0-9]+$');

	ALTER TABLE plot
	  ADD CONSTRAINT plot_id PRIMARY KEY (plot_id);
	  
	CREATE INDEX plot_geom_idx
	  ON plot USING gist (wkb_geometry);
	  
	CREATE INDEX plot_area_idx
	   ON plot USING hash (area_id varchar_ops);
	   
	CREATE INDEX plot_idx
	   ON plot USING hash (plot_id varchar_ops);
END;

BEGIN
	IF (EXISTS (SELECT area_id FROM summary LIMIT 1)) THEN
	END IF;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'View "summary" does not exists: creating it.';
	CREATE OR REPLACE VIEW summary
		AS
		SELECT a.area_id, a.hectares, sum(p.hectares) AS plot_sum, (a.hectares-sum(p.hectares)) AS difference
		-- OVER (PARTITION BY a.area_id) AS plot_sum
		FROM area a join plot p ON a.area_id=p.area_id
		GROUP BY (a.area_id);
END;

return true;

END
$BODY$
LANGUAGE 'plpgsql' ;

-- SELECT * FROM gpxImporter();
