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

SELECT count(*) INTO isArea FROM pg_class WHERE relname='area' and relkind='r';
IF (isArea) THEN
	-- INSERT NEW ROWS
	INSERT INTO area (fid, area_id, hectares,wkb_geometry)
	SELECT nextval('fid_area'), name, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,ST_ConvexHull(wkb_geometry)
		FROM tracks
		WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+$'
			AND
			name NOT IN (SELECT area_id FROM area);
	-- UPDATE EXISTING ROWS
	UPDATE area SET
		fid = area.fid,
		area_id = tracks.name,
		hectares = st_area(ST_Transform(ST_ConvexHull(tracks.wkb_geometry),3857))/10000,
		wkb_geometry = ST_ConvexHull(tracks.wkb_geometry)
	FROM tracks
	WHERE tracks.name=area_id;
ELSE
	RAISE NOTICE 'Table "area" does not exists: creating it.';

	CREATE SEQUENCE fid_area
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;  
	
	--DROP TABLE IF EXISTS area CASCADE;
	CREATE TABLE area (fid, area_id, hectares,wkb_geometry)
	AS
	(SELECT nextval('fid_area'), name, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,ST_ConvexHull(wkb_geometry) FROM tracks WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+$');

	ALTER TABLE area
	  ADD CONSTRAINT area_id PRIMARY KEY (fid);
	  
	CREATE INDEX area_geom_idx
	  ON area USING gist (wkb_geometry);
	  
	CREATE INDEX area_idx
	   ON area USING hash (area_id varchar_ops);

END IF;

SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot' and relkind='r';
IF (isPlot) THEN
	-- INSERT NEW ROWS
	INSERT INTO plot (fid, area_id, plot_id, hectares,wkb_geometry)
	SELECT nextval('fid_plot'), SUBSTRING(name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'), name , st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,ST_ConvexHull(wkb_geometry)
		FROM tracks 
		WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+-[0-9]+$'
			AND
			name NOT IN (SELECT plot_id FROM plot);
	-- UPDATE EXISTING ROWS
	UPDATE plot SET
		fid = plot.fid,
		area_id = SUBSTRING(tracks.name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'),
		plot_id = tracks.name,
		hectares = st_area(ST_Transform(ST_ConvexHull(tracks.wkb_geometry),3857))/10000,
		wkb_geometry = ST_ConvexHull(tracks.wkb_geometry)
	FROM tracks
	WHERE tracks.name=plot_id;
ELSE
	RAISE NOTICE 'Table "plot" does not exists: creating it.';

	CREATE SEQUENCE fid_plot
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;

	--DROP TABLE IF EXISTS plot CASCADE;
	CREATE TABLE plot (fid, area_id, plot_id, hectares,wkb_geometry)
	AS
	(SELECT nextval('fid_plot'), SUBSTRING(name, '^.{3,3}-[0-9]+-[0-9]+-[0-9]+'), name , st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000,ST_ConvexHull(wkb_geometry) FROM tracks WHERE name ~ '^.{3,3}-[0-9]+-[0-9]+-[0-9]+-[0-9]+$');

	ALTER TABLE plot
	  ADD CONSTRAINT plot_id PRIMARY KEY (fid);
	  
	CREATE INDEX plot_geom_idx
	  ON plot USING gist (wkb_geometry);
	  
	CREATE INDEX plot_area_idx
	   ON plot USING hash (area_id varchar_ops);
	   
	CREATE INDEX plot_idx
	   ON plot USING hash (plot_id varchar_ops);

	
END IF;
	

BEGIN
	IF (EXISTS (SELECT area_id FROM summary LIMIT 1)) THEN
	END IF;
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'View "summary" does not exists: creating it.';
	CREATE OR REPLACE VIEW summary
		AS
		SELECT a.area_id, a.hectares, sum(p.hectares) OVER (PARTITION BY a.area_id) AS plot_sum, (a.hectares-(sum(p.hectares) OVER (PARTITION BY a.area_id))) AS difference
		
		FROM area a join plot p ON a.area_id=p.area_id;
		-- GROUP BY (a.area_id);
END;

return true;

END
$BODY$
LANGUAGE 'plpgsql' ;

-- SELECT * FROM gpxImporter();
