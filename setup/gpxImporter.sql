-- Author: Carlo Cancellieri - GeoSolutions SAS
-- LICENSE: GPL 3 + classpath

-- DROP FUNCTION gpxImporter();
CREATE OR REPLACE FUNCTION gpxImporter(autoRefresh boolean DEFAULT false) RETURNS boolean AS
$BODY$
DECLARE
  isArea boolean;
  isPlot boolean;
  countSize integer;
  isSummary boolean;
  concave_percent float := 0.5;
  data_area_regex varchar:='^.{3,3}-[0-9]+-[0-9]+-[0-9]+$';
  data_plot_area_regex varchar:='^.{3,3}-[0-9]+-[0-9]+-[0-9]+';
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

	-- SELECT count(*) FROM pg_class WHERE relname='area_concave';
	SELECT count(*) INTO countSize FROM pg_class WHERE (relname='area_convex' or relname='area_concave') and relkind='m';
	IF (autoRefresh) THEN
		IF (countSize=2) THEN
			-- AREA CONCAVE
			REFRESH MATERIALIZED VIEW area_concave;
			REFRESH MATERIALIZED VIEW area_convex;
			return true;
		ELSE
			RAISE NOTICE 'Unable to refresh area views';
			return false;
		END IF;
	END IF;
	
	-- INSERT NEW ROWS
	INSERT INTO data_area (fid, area_id, clazz, wkb_geometry)
	SELECT nextval('fid_data_area'), name, 0, ST_LineMerge(wkb_geometry) -- Merge MULTILINESTRING TO LINE
		FROM tracks
		WHERE name ~ data_area_regex
			AND
			name NOT IN (SELECT area_id FROM data_area);
	-- UPDATE EXISTING ROWS
	UPDATE data_area SET
		fid = data_area.fid,
		area_id = tracks.name,
		clazz = 0,
		wkb_geometry = ST_LineMerge(tracks.wkb_geometry) -- Merge MULTILINESTRING TO LINE
	FROM tracks
	WHERE tracks.name=area_id;

	-- CLOSE NOT CLOSED GEOM
	UPDATE data_area
		SET wkb_geometry = ST_AddPoint(wkb_geometry, ST_StartPoint(wkb_geometry))
		WHERE ST_IsClosed(wkb_geometry) = false;
ELSE
	RAISE NOTICE 'Table "data_area" does not exists: creating it.';

	SELECT count(*) INTO isArea FROM pg_class WHERE relname='fid_data_area'  and relkind='S';
	if (isArea) THEN
		DROP SEQUENCE fid_data_area;
	END IF;
	
	CREATE SEQUENCE fid_data_area
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;  
	
	--DROP TABLE IF EXISTS area CASCADE;
	CREATE TABLE data_area (fid, area_id, clazz, wkb_geometry)
	AS
	(SELECT nextval('fid_data_area'), name, 0, ST_LineMerge(tracks.wkb_geometry) -- Merge MULTILINESTRING TO LINE
	 FROM tracks WHERE name ~ data_area_regex);

	ALTER TABLE data_area
	  ADD CONSTRAINT data_area_id PRIMARY KEY (fid);
	  
	CREATE INDEX data_area_geom_idx
		ON data_area USING gist (wkb_geometry);
	  
	CREATE INDEX data_area_idx
		ON data_area USING hash (area_id varchar_ops);

	-- AREA CONCAVE
	-- SELECT count(*) FROM pg_class WHERE relname='area_concave';
	SELECT count(*) INTO isArea FROM pg_class WHERE relname='area_concave' and relkind='m';
	IF (isArea) THEN
		DROP MATERIALIZED VIEW area_concave;
	END IF;			
	CREATE MATERIALIZED VIEW area_concave (fid, area_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, clazz, st_area(ST_Transform(ST_ConcaveHull(wkb_geometry, 0),3857))/10000 AS hectares, ST_ConcaveHull(wkb_geometry, 0.5) AS wkb_geometry FROM data_area;
	

	-- AREA CONVEX
	SELECT count(*) INTO isArea FROM pg_class WHERE relname='area_convex' and relkind='m';
	IF (isArea) THEN
		DROP MATERIALIZED VIEW area_convex;
	END IF;	
	CREATE MATERIALIZED VIEW area_convex (fid, area_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, clazz, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 AS hectares, ST_ConvexHull(wkb_geometry) AS wkb_geometry FROM data_area;

	-- AREA POLYGON
	CREATE OR REPLACE VIEW area_polygon (fid, area_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, clazz, st_area(ST_Transform(ST_MakePolygon(wkb_geometry),3857))/10000 AS hectares, ST_MakePolygon(wkb_geometry) AS wkb_geometry FROM data_area;


END IF;

SELECT count(*) INTO isPlot FROM pg_class WHERE relname='data_plot' and relkind='r';
IF (isPlot) THEN

	IF (autoRefresh) THEN
		-- SELECT count(*) FROM pg_class WHERE relname='plot_concave' and relkind='m';		
		SELECT count(*) INTO countSize FROM pg_class WHERE (relname='plot_convex' or relname='plot_concave') and relkind='m';
		IF (countSize=2) THEN
			REFRESH MATERIALIZED VIEW plot_convex;
			-- PLOT CONCAVE
			REFRESH MATERIALIZED VIEW plot_concave;
			return true;
		ELSE
			RAISE NOTICE 'Unable to refresh plot views';
			return false;
		END IF;
	END IF;
	
	-- INSERT NEW ROWS
	INSERT INTO data_plot (fid, area_id, plot_id, clazz, wkb_geometry)
		SELECT nextval('fid_data_plot'), SUBSTRING(name, data_plot_area_regex), name, 0, ST_LineMerge(tracks.wkb_geometry) -- Merge MULTILINESTRING TO LINE
		FROM tracks 
		WHERE name ~ data_plot_regex
			AND
			name NOT IN (SELECT plot_id FROM data_plot);
			
	-- UPDATE EXISTING ROWS
	UPDATE data_plot SET
		fid = data_plot.fid,
		area_id = SUBSTRING(tracks.name, data_plot_area_regex),
		plot_id = tracks.name,
		clazz = 0,
		wkb_geometry = ST_LineMerge(tracks.wkb_geometry) -- Merge MULTILINESTRING TO LINE
	FROM tracks
	WHERE tracks.name=plot_id;

	-- CLOSE NOT CLOSED GEOM
	UPDATE data_plot
	 	SET wkb_geometry = ST_AddPoint(wkb_geometry, ST_StartPoint(wkb_geometry))
	 	WHERE ST_IsClosed(wkb_geometry) = false;
ELSE
	RAISE NOTICE 'Table "data_plot" does not exists: creating it.';

	SELECT count(*) INTO isPlot FROM pg_class WHERE relname='fid_data_plot'  and relkind='S';
	if (isPlot) THEN
		DROP SEQUENCE fid_data_plot;
	END IF;
	
	CREATE SEQUENCE fid_data_plot
	  INCREMENT 1
	  MINVALUE 1
	  MAXVALUE 9223372036854775807
	  START 1
	  CACHE 1;

	--DROP TABLE IF EXISTS plot CASCADE;
	CREATE TABLE data_plot (fid, area_id, plot_id,  clazz, wkb_geometry)
	AS
	(SELECT nextval('fid_data_plot'), SUBSTRING(name, data_plot_area_regex), name,  0, ST_LineMerge(tracks.wkb_geometry) -- Merge MULTILINESTRING TO LINE
	 FROM tracks WHERE name ~ data_plot_regex);

	ALTER TABLE data_plot
	  ADD CONSTRAINT data_plot_id PRIMARY KEY (fid);
	  
	CREATE INDEX data_plot_geom_idx
		ON data_plot USING gist (wkb_geometry);
	  
	CREATE INDEX data_plot_area_idx
		ON data_plot USING hash (area_id varchar_ops);
	   
	CREATE INDEX data_plot_idx
		ON data_plot USING hash (plot_id varchar_ops);

	
	SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot_concave' and relkind='m';
	IF (isPlot) THEN
		DROP MATERIALIZED VIEW plot_concave;
	END IF;
	CREATE MATERIALIZED VIEW plot_concave (fid, area_id, plot_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, plot_id, clazz, st_area(ST_Transform(ST_ConcaveHull(wkb_geometry, 0),3857))/10000 AS hectares, ST_ConcaveHull(wkb_geometry, 0.5) AS wkb_geometry FROM data_plot;	

	-- PLOT CONVEX
	SELECT count(*) INTO isPlot FROM pg_class WHERE relname='plot_convex' and relkind='m';
	IF (isPlot) THEN
		DROP MATERIALIZED VIEW plot_convex;
	END IF;
	CREATE MATERIALIZED VIEW plot_convex (fid, area_id, plot_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, area_id, plot_id, clazz, st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 AS hectares, ST_ConvexHull(wkb_geometry) AS wkb_geometry FROM data_plot;
	
	CREATE OR REPLACE VIEW plot_polygon (fid, plot_id, area_id, clazz, hectares, wkb_geometry)
	AS
	SELECT fid, plot_id, area_id, clazz, st_area(ST_Transform(ST_MakePolygon(wkb_geometry),3857))/10000 AS hectares, ST_MakePolygon(wkb_geometry) FROM data_plot;

END IF;

-- SUMMARY
-- SELECT count(*) INTO isSummary FROM pg_class WHERE relname='plot' and relkind='r';
-- IF (isSummary=false) THEN
-- IF (false) THEN
-- 	RAISE NOTICE 'View "summary" does not exists: creating it.';
-- 	CREATE MATERIALIZED VIEW summary
-- 		AS
-- 		SELECT a.area_id, a.hectares, sum(p.hectares) OVER (PARTITION BY a.area_id) AS plot_sum, (a.hectares-(sum(p.hectares) OVER (PARTITION BY a.area_id))) AS difference
-- 		
-- 		FROM area a join plot p ON a.area_id=p.area_id;
-- 		-- GROUP BY (a.area_id);
-- END IF;

return true;

END
$BODY$
LANGUAGE 'plpgsql' ;

-- SELECT * FROM gpxImporter(false);

-- SELECT * FROM plot_polygon WHERE ST_isClosed(ST_MakePolygon(ST_AddPoint(ST_LineMerge(wkb_geometry), ST_StartPoint(wkb_geometry))))=true;
-- SELECT * from Tracks LIMIT 1
-- SELECT st_area(ST_Transform(ST_ConcaveHull(wkb_geometry,0.5,false),3857))/10000,st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 from Tracks WHERE ogc_fid=1
-- SELECT st_area(ST_Transform(ST_ConcaveHull(wkb_geometry,0.1,true),3857))/10000,st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 from Tracks WHERE ogc_fid=1
-- select * from plot_concave where area_id='PIA-3-2-1'
-- DROP VIEW plot_polyon;
-- SELECT * FROM data_plot WHERE ST_isClosed(wkb_geometry)=true
-- SELECT * FROM tracks
-- SELECT * FROM area_polygon

-- SELECT wkb_geometry,ST_StartPoint(ST_LineMerge(wkb_geometry)), ST_AddPoint(ST_LineMerge(wkb_geometry), ST_StartPoint(ST_LineMerge(wkb_geometry)))
 -- FROM tracks
 -- WHERE ST_isClosed(ST_MakePolygon(ST_AddPoint(ST_LineMerge(wkb_geometry), ST_StartPoint(wkb_geometry))))=true;
	--ST_geometryType(wkb_geometry)
	--SELECT * FROM data_area
-- SELECT wkb_geometry,ST_StartPoint(ST_LineMerge(tracks.wkb_geometry)),
-- 	ST_AddPoint(ST_LineMerge(wkb_geometry), ST_StartPoint(ST_LineMerge(wkb_geometry))) as line
-- 	FROM tracks