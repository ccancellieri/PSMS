-- drop view BEN;
create or replace view BEN as select name,st_area(ST_Transform(ST_ConvexHull(wkb_geometry),3857))/10000 hectares from public.tracks;

