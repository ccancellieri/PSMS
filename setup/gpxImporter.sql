-- DROP FUNCTION gpxImporter();
CREATE OR REPLACE FUNCTION gpxImporter(autoRefresh boolean DEFAULT false) RETURNS boolean AS
$BODY$
DECLARE
  isArea boolean;
  isPlot boolean;
  isSummary boolean;
  concave_percent float := 0.5;
  data_area_regex varchar:='^.{3,3}-[0-9]+-[0-9]+-[0-9]+$';
  data_plot_regex varchar:='^.{3,3}-[0-9]+-[0-9]+-[0-9]+-[0-9]+$';
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

SELECT count(*) INTO isArea FROM pg_class WHERE relname='data_area' and relkind='r';
IF (isArea) THEN
	-- INSERT NEW ROWS
	INSERT INTO data_area (fid, area_id, wkb_geometry)
	SELECT nextval('fid_data_area'), name, wkb_geometry
		FROM tracks
		WHERE name ~ data_area_regex
			AND
			name NOT IN (SELECT area_id FROM data_area);
	-- UPDATE EXISTING ROWS
	UPDATE data_area SET
		fid = data_area.fid,
		area_id = tracks.name,
		wkb_geometry = tracks.wkb_geometry
	FROM tracks
	WHERE tracks.name=area_id;
ELSE
	RAISE NOTICE 'Table "data_area" does not exists: creating it.';

	CREATE SEQUENCE fid_data_area
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;  
	
	--DROP TABLE IF EXISTS area CASCADE;
	CREATE TABLE data_area (fid, area_id, wkb_geometry)
	AS
	(SELECT nextval('fid_data_area'), name, wkb_geometry FROM tracks WHERE name ~ data_area_regex);

	ALTER TABLE data_area
	  ADD CONSTRAINT data_area_id PRIMARY KEY (fid);
	  
	CREATE INDEX data_area_geom_idx
	  ON area USING gist (wkb_geometry);
	  
	CREATE INDEX data_area_idx
	   ON area USING hash (area_id varchar_ops);

END IF;

SELECT count(*) INTO isPlot FROM pg_class WHERE relname='data_plot' and relkind='r';
IF (isPlot) THEN
	-- INSERT NEW ROWS
	INSERT INTO data_plot (fid, area_id, plot_id, wkb_geometry)
		SELECT nextval('fid_data_plot'), SUBSTRING(name, data_area_regex), name, wkb_geometry
		FROM tracks 
		WHERE name ~ data_plot_regex
			AND
			name NOT IN (SELECT plot_id FROM data_plot);
	-- UPDATE EXISTING ROWS
	UPDATE data_plot SET
		fid = data_plot.fid,
		area_id = SUBSTRING(tracks.name, data_area_regex),
		plot_id = tracks.name,
		wkb_geometry = tracks.wkb_geometry
	FROM tracks
	WHERE tracks.name=plot_id;
ELSE
	RAISE NOTICE 'Table "data_plot" does not exists: creating it.';

	CREATE SEQUENCE fid_data_plot
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;

	--DROP TABLE IF EXISTS plot CASCADE;
	CREATE TABLE data_plot (fid, area_id, plot_id, wkb_geometry)
	AS
	(SELECT nextval('fid_data_plot'), SUBSTRING(name, data_area_regex), name, wkb_geometry FROM tracks WHERE name ~ data_plot_regex);

	ALTER TABLE data_plot
	  ADD CONSTRAINT data_plot_id PRIMARY KEY (fid);
	  
	CREATE INDEX data_plot_geom_idx
	  ON plot USING gist (wkb_geometry);
	  
	CREATE INDEX data_plot_area_idx
	   ON plot USING hash (area_id varchar_ops);
	   
	CREATE INDEX data_plot_idx
	   ON plot USING hash (plot_id varchar_ops);

END IF;

-- AREA CONCAVE
-- SELECT count(*) FROM pg_class WHERE relname='area_concave';
SELECT count(*) INTO isArea FROM pg_class WHERE relname='area_concave' and relkind='m';
IF (isArea=false) THEN
	-- DROP MATERIALIZED VIEW area_concave;
	RAISE NOTICE 'View "area_concave" does not exists: creating it.';
	CREATE MATERIALIZED VIEW area_concave (fid, area_id, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, st_area(ST_Transform(ST_ConcaveHull(wkb_geometry, 0.5),3857))/10000 AS hectares, ST_ConcaveHull(wkb_geometry, 0.5) AS wkb_geometry FROM data_area;
ELSIF (autoRefresh) THEN
	REFRESH MATERIALIZED VIEW area_concave;
END IF;

-- AREA CONVEX
SELECT count(*) INTO isArea FROM pg_class WHERE relname='area_convex' and relkind='m';
IF (isArea=false) THEN
	-- DROP MATERIALIZED VIEW area_convex;
	RAISE NOTICE 'View "area_convex" does not exists: creating it.';
	CREATE MATERIALIZED VIEW area_convex (fid, area_id, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 AS hectares, ST_ConvexHull(wkb_geometry) AS wkb_geometry FROM data_area;
ELSIF (autoRefresh) THEN
	REFRESH MATERIALIZED VIEW area_convex;
END IF;

-- PLOT CONCAVE
-- SELECT count(*) FROM pg_class WHERE relname='plot_concave' and relkind='m';
SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot_concave' and relkind='m';
IF (isPlot=false) THEN
	-- DROP MATERIALIZED VIEW plot_concave;
	RAISE NOTICE 'View "plot_concave" does not exists: creating it.';
	CREATE MATERIALIZED VIEW plot_concave (fid, area_id, plot_id, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, plot_id, st_area(ST_Transform(ST_ConcaveHull(wkb_geometry, 0.5),3857))/10000 AS hectares, ST_ConcaveHull(wkb_geometry, 0.5) AS wkb_geometry FROM data_plot;
ELSIF (autoRefresh) THEN
	REFRESH MATERIALIZED VIEW plot_concave;
END IF;

-- PLOT CONVEX
SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot_convex' and relkind='m';
IF (isPlot=false) THEN
	-- DROP MATERIALIZED VIEW plot_convex;
	RAISE NOTICE 'View "plot_convex" does not exists: creating it.';
	CREATE MATERIALIZED VIEW plot_convex (fid, area_id, plot_id, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, plot_id, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 AS hectares, ST_ConvexHull(wkb_geometry) AS wkb_geometry FROM data_plot;
ELSIF (autoRefresh) THEN
	REFRESH MATERIALIZED VIEW plot_convex;
END IF;

-- SUMMARY
SELECT count(*) INTO isSummary FROM pg_class WHERE relname='plot' and relkind='r';
-- IF (isSummary=false) THEN
IF (false) THEN
	RAISE NOTICE 'View "summary" does not exists: creating it.';
	CREATE MATERIALIZED VIEW summary
		AS
		SELECT a.area_id, a.hectares, sum(p.hectares) OVER (PARTITION BY a.area_id) AS plot_sum, (a.hectares-(sum(p.hectares) OVER (PARTITION BY a.area_id))) AS difference
		
		FROM area a join plot p ON a.area_id=p.area_id;
		-- GROUP BY (a.area_id);
END IF;

return true;

END
$BODY$
LANGUAGE 'plpgsql' ;

-- SELECT * FROM gpxImporter();
-- SELECT * from Tracks LIMIT 1
-- SELECT st_area(ST_Transform(ST_ConcaveHull(wkb_geometry,0.5,false),3857))/10000,st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 from Tracks WHERE ogc_fid=1
-- SELECT st_area(ST_Transform(ST_ConcaveHull(wkb_geometry,0.1,true),3857))/10000,st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 from Tracks WHERE ogc_fid=1
