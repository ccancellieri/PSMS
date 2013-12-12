package it.geosolutions.gis.utils;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;
import it.geosolutions.gis.Tool;

import java.io.File;
import java.net.MalformedURLException;

import org.junit.After;
import org.junit.Test;

public class ToolTest {
    private File outFile;

    @Test
    public void test() {
        String url = "http://168.202.25.219:8080/geoserver/PSMS/wfs?version=1.1.0&request=GetFeature" +
        		"&typeName=PSMS:psms_training" +
        		"&maxfeatures=1" +
        		"&outputFormat=application/json";
        String ftl = "src/main/resources/template.ftl";
        String out = "src/main/resources/KML.kml";
        outFile=new File(out);
        try {
            Tool.main(new String[]{url, ftl, out});
            
            assertTrue(outFile.exists());
        } catch (MalformedURLException e) {
            e.printStackTrace();
            fail(e.getLocalizedMessage());
            
        }
    }
    
    @After
    public void after(){
        if (outFile!=null)
            outFile.delete();
    }

}
