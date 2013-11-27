package it.geosolutions.gis;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.util.HashMap;
import java.util.Map;

import org.geotools.data.DataStore;
import org.geotools.data.FeatureWriter;
import org.geotools.data.Transaction;
import org.geotools.feature.FeatureIterator;
import org.geotools.geojson.feature.FeatureJSON;
import org.geotools.geojson.geom.GeometryJSON;
import org.opengis.feature.GeometryAttribute;
import org.opengis.feature.simple.SimpleFeature;
import org.opengis.feature.simple.SimpleFeatureType;
import org.opengis.geometry.primitive.Point;

import freemarker.template.Configuration;
import freemarker.template.Template;
import freemarker.template.TemplateException;

public class Tool {

    static {
        // Setting the system-wide default at startup time
        System.setProperty("org.geotools.referencing.forceXY", "true");
    }
    
    public static void main(String[] args) {

        // Freemarker configuration object
        Configuration cfg = new Configuration();

        // source input
        InputStream input = null;
        SimpleFeatureType featureType = null;
        try {

            // TODO load input from REST call
            input = new FileInputStream("src/main/resources/source.json");

            // Load template from source folder
            Template template = cfg.getTemplate("src/main/resources/template.ftl");

            // Build the data-model
            Map<String, Object> data = new HashMap<String, Object>();
            data.put("model", geoJSON(input, featureType));
            data.put("tool", new Tool());

            // // Console output
            // Writer out = new OutputStreamWriter(System.out);
            // template.process(data, out);
            // out.flush();

            // File output
            Writer file = new FileWriter(new File("src/main/resources/KML.kml"));
            template.process(data, file);
            file.flush();
            file.close();

        } catch (IOException e) {
            e.printStackTrace();
        } catch (TemplateException e) {
            e.printStackTrace();
        }
    }

    public static double getOrdinate(int dimension, SimpleFeature feature) {
        GeometryAttribute geom = feature.getDefaultGeometryProperty();
        if (geom.getType().getBinding().isAssignableFrom(com.vividsolutions.jts.geom.Point.class)) {
            com.vividsolutions.jts.geom.Point p=(com.vividsolutions.jts.geom.Point)feature.getDefaultGeometry();
            if (dimension==0)
                    return p.getX();
            else if (dimension==1)
                    return p.getY();
            else 
                throw new IllegalArgumentException();
        } else {
            throw new UnsupportedOperationException("Not iet implemented");
        }
    }

    public static FeatureIterator<SimpleFeature> geoJSON(final InputStream input,
            SimpleFeatureType featureType) throws IOException {

        final FeatureJSON fjson = new FeatureJSON(new GeometryJSON(15));

        if (featureType != null) {
            fjson.setFeatureType(featureType);
        }

        final FeatureIterator<SimpleFeature> jsonIt = fjson.streamFeatureCollection(input);

        if (!jsonIt.hasNext()) {
            return null;
        } else {
            return jsonIt;
        }

    }

    public static void geoJSON2DataStore(final InputStream input, SimpleFeatureType featureType,
            final DataStore dataStore) throws IOException {

        FeatureJSON fjson = new FeatureJSON(new GeometryJSON(15));

        if (featureType != null) {
            fjson.setFeatureType(featureType);
        }

        FeatureIterator<SimpleFeature> jsonIt = fjson.streamFeatureCollection(input);

        if (!jsonIt.hasNext()) {
            throw new IllegalArgumentException("Cannot read input. GeoJSON stream is empty");
        }

        FeatureWriter<SimpleFeatureType, SimpleFeature> writer = null;

        try {
            // use feature type of first feature, if not supplied
            SimpleFeature firstFeature = jsonIt.next();
            if (featureType == null) {
                featureType = firstFeature.getFeatureType();
            }

            dataStore.createSchema(featureType);

            writer = dataStore.getFeatureWriterAppend(dataStore.getTypeNames()[0],
                    Transaction.AUTO_COMMIT);

            addFeature(firstFeature, writer);

            while (jsonIt.hasNext()) {
                SimpleFeature feature = jsonIt.next();
                addFeature(feature, writer);
            }
        } finally {
            if (writer != null) {
                writer.close();
            }
        }
    }

    // public static String get(SimpleFeature feature){
    // feature.getAttributes();
    // return ((Point)feature.getDefaultGeometryProperty().getValue()).getCentroid().;
    // }

    private static void addFeature(SimpleFeature feature,
            FeatureWriter<SimpleFeatureType, SimpleFeature> writer) throws IOException {

        SimpleFeature toWrite = writer.next();
        for (int i = 0; i < toWrite.getType().getAttributeCount(); i++) {
            String name = toWrite.getType().getDescriptor(i).getLocalName();
            toWrite.setAttribute(name, feature.getAttribute(name));
        }

        // copy over the user data
        if (feature.getUserData().size() > 0) {
            toWrite.getUserData().putAll(feature.getUserData());
        }

        // perform the write
        writer.write();
    }

}
