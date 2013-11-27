<#assign stop=999999999999999 >
<#assign index=0 >
<kml xmlns="http://earth.google.com/kml/2.0">
<Folder>
	<name>NAME</name>
	<description>DESC</description>
	<Style id="highlightPlacemark">
      <IconStyle>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/red-stars.png</href>
        </Icon>
      </IconStyle>
    </Style>
    <Style id="normalPlacemark">
      <IconStyle>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/wht-blank.png</href>
        </Icon>
      </IconStyle>
    </Style>
    <StyleMap id="exampleStyleMap">
      <Pair>
        <key>normal</key>
        <styleUrl>#normalPlacemark</styleUrl>
      </Pair>
      <Pair>
        <key>highlight</key>
        <styleUrl>#highlightPlacemark</styleUrl>
      </Pair>
    </StyleMap>
	<#list 1..stop as condition>
		<#if model.hasNext()>
			<#assign index = index + 1 >
			<#assign feature = model.next() >
			<Placemark>
				<name>Feature_${index}</name>
				<styleUrl>#exampleStyleMap</styleUrl>
				<description>
					<![CDATA[
					<h1>Feature N. ${index}</h1>
					<#list feature.getProperties() as property>
						<ul>
							<li>
								<p><font color="green">Property <b>${property.getName()}</b> has value <b>${property.getValue()}</b></font></p>
							</li>
						</ul>
					</#list>
					]]>
				</description>
				<#assign geometry=feature.getProperty("geometry") >
			<#if geometry.getType().getBinding()?ends_with("Point")>
				<Point>
					<coordinates>${geometry.getValue()?substring(7,geometry.getValue()?index_of(")"))?replace(" ",",")}</coordinates>
				</Point>
			<#else>
				<!-- FAKE GEOM TO BUILD VALID KML -->
				<Point>
					<coordinates>0,0,0</coordinates>
				</Point>
			</#if>
			
			</Placemark>
			<#-- list feature.getProperties() as property>
			    ${index}. NAME=${property.getName()} VALUE=${property.getValue()}
			</#list -->
		<#else>
			<#break>
		</#if>
	</#list>
</Folder>
</kml>
