package it.geosolutions.gis;

import it.geosolutions.gis.util.ShapefileUtils;

import java.io.File;

import org.geotools.data.FileDataStore;
import org.geotools.data.FileDataStoreFinder;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.geotools.feature.DefaultFeatureCollection;
import org.opengis.feature.simple.SimpleFeature;
import org.opengis.feature.simple.SimpleFeatureType;

public class Test {

	public static void main(String[] args) throws Exception {
		String srcShapefilePath = "src/main/resources/G2013_2012_0.shp";
		String dstShapefilePath = "src/main/resources/test.shp";
		String attributeName = "ADM0_CODE";
		Object attributeValue = 5;
		
		File shapefile = new File(srcShapefilePath);
		if (!shapefile.exists())
			throw new Exception(shapefile.getAbsolutePath() + " not found.");
		
		FileDataStore store = FileDataStoreFinder.getDataStore(shapefile);
		SimpleFeatureType featureType = store.getSchema();
		SimpleFeatureSource featureSource = store.getFeatureSource();
		SimpleFeatureCollection featureCollection = featureSource.getFeatures();
		DefaultFeatureCollection dstFeatures = new DefaultFeatureCollection(null,null);

		SimpleFeatureIterator iterator = featureCollection.features();

		while (iterator.hasNext()) {
			SimpleFeature feature = iterator.next();
			Object value = feature.getAttribute(attributeName);
			if (value.equals(attributeValue)) {
//				feature.toString();
				dstFeatures.add(feature);
			}

		}
		iterator.close();
		ShapefileUtils.writeShapefile(dstShapefilePath, dstFeatures.collection());
		
		System.out.println("done!");
	}
}
