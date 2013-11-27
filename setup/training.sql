CREATE TABLE training
(
  store_name character varying,
  site_name character varying,
  site_number character varying,
  latitude character varying,
  longitude character varying,
  altitude character varying,
  gatewidth character varying,
  ownername character varying,
  comments character varying,
  countrygeofeature_id character varying,
  adm1geofeature_id character varying,
  adm2geofeature_id character varying
)
WITH (
  OIDS=FALSE
);
ALTER TABLE training
  OWNER TO postgres;

COPY training FROM 'storeData-psmsTraining.csv' DELIMITER ',' CSV;
delete FROM training where store_name='store_name'

-- select *from training where latitude<>'' AND longitude<>''
CREATE TABLE
	psms_training 
AS 
SELECT 
	store_name,
	site_name,
	site_number,
	ST_SetSRID(ST_MakePoint(cast (longitude as double precision), cast (latitude as double precision)), 4326) as the_geom,
	altitude,
	gatewidth,
	ownername,
	comments,
	countrygeofeature_id,
	adm1geofeature_id,
	adm2geofeature_id
FROM 
	training
WHERE
	latitude<>'' AND longitude<>''
;

select * from gis.public.psms_training
