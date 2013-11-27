package it.geosolutions.gis.util;

import java.io.File;
import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

import org.geotools.data.DefaultTransaction;
import org.geotools.data.FileDataStore;
import org.geotools.data.FileDataStoreFinder;
import org.geotools.data.Transaction;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureSource;
import org.geotools.data.simple.SimpleFeatureStore;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.grid.Grids;
import org.opengis.feature.simple.SimpleFeature;
import org.opengis.referencing.crs.CoordinateReferenceSystem;

import com.vividsolutions.jts.geom.Geometry;

public class ShapefileUtils {

	public static CoordinateReferenceSystem getCRS(String shapefilePath) throws Exception {
		
		File shapefile = new File(shapefilePath);
		if (!shapefile.exists())
			throw new Exception(shapefile.getAbsolutePath() + " not found.");
		
		FileDataStore store = FileDataStoreFinder.getDataStore(shapefile);
		SimpleFeatureSource source = store.getFeatureSource();
		
		return source.getInfo().getCRS();
	}
	
	public static ReferencedEnvelope getReferencedEnvelope(String shapefilePath) throws Exception {
		
		File shapefile = new File(shapefilePath);
		if (!shapefile.exists())
			throw new Exception(shapefile.getAbsolutePath() + " not found.");
		
		FileDataStore store = FileDataStoreFinder.getDataStore(shapefile);
		SimpleFeatureSource source = store.getFeatureSource();
		
		return source.getBounds();
	}
	
	public static void createSquareGridShapefile(String srcShapefilePath, String dstShapefilePath, double gridSideLen) throws Exception {
		ReferencedEnvelope gridBounds = getGridReferencedEnvelope(srcShapefilePath, gridSideLen);
		SimpleFeatureSource gridFeatureSource = Grids.createSquareGrid(gridBounds, gridSideLen);
		writeShapefile(dstShapefilePath, gridFeatureSource.getFeatures());
	}
	
	public static ReferencedEnvelope getGridReferencedEnvelope(String shapefilePath, double sideLen) throws Exception {
		
		ReferencedEnvelope srcEnvelope = ShapefileUtils.getReferencedEnvelope(shapefilePath);
		CoordinateReferenceSystem srcCRS = srcEnvelope.getCoordinateReferenceSystem();
		
		double xLen = srcEnvelope.getWidth();
		double yLen = srcEnvelope.getHeight();
		double xCenter = srcEnvelope.getMinX() + (xLen/2D);
		double yCenter = srcEnvelope.getMinY() + (yLen/2D);
		
		long nxSquare = ((long) (xLen/sideLen)) + 1L;
		long nySquare = ((long) (yLen/sideLen)) + 1L;
		 
		double xMin = xCenter - ((nxSquare*sideLen)/2D);
		double yMin = yCenter - ((nySquare*sideLen)/2D);
		double xMax = xMin + (nxSquare*sideLen);
		double yMax = yMin + (nySquare*sideLen);
				
		return new ReferencedEnvelope(xMin, xMax, yMin, yMax, srcCRS);
	}
	
	public static Geometry getGeometryAtIndex(String shapefilePath, int index) throws Exception {
		File shapefile = new File(shapefilePath);
		if (!shapefile.exists())
			throw new Exception(shapefile.getAbsolutePath() + " not found.");
		
		FileDataStore store = FileDataStoreFinder.getDataStore(shapefile);
		SimpleFeatureSource source = store.getFeatureSource();
		
		if (!(index < source.getFeatures().size())) return null;
		
		SimpleFeature simpleFeature = (SimpleFeature) source.getFeatures().toArray()[index];
		return (Geometry) simpleFeature.getDefaultGeometry();
	}
	
	public static void writeShapefile(String shpPathName, SimpleFeatureCollection featureCollection) throws Exception {
		File shapefile = new File(shpPathName);
	    if (!shapefile.exists())
	    	shapefile.createNewFile();
	    
        Map<String, Serializable> params = new HashMap<String, Serializable>();
        params.put("url", shapefile.toURI().toURL());
        params.put("create spatial index", Boolean.TRUE);
        
        ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
        ShapefileDataStore newDataStore = (ShapefileDataStore) dataStoreFactory.createNewDataStore(params);
        newDataStore.createSchema(featureCollection.getSchema());
        
        String typeName = newDataStore.getTypeNames()[0];
        SimpleFeatureSource featureSource = newDataStore.getFeatureSource(typeName);
        
        if (featureSource instanceof SimpleFeatureStore) {
            SimpleFeatureStore featureStore = (SimpleFeatureStore) featureSource;
            
            Transaction transaction = new DefaultTransaction("create");
            featureStore.setTransaction(transaction);
            
            try {
                featureStore.addFeatures(featureCollection);
                transaction.commit();

            } catch (Exception problem) {
                problem.printStackTrace();
                transaction.rollback();

            } finally {
                transaction.close();
            }

        } else {
            throw new Exception(typeName + " does not support read/write access");
        }
	}
}
