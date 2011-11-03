require "util"

header = [[
<html xmlns="http://www.w3.org/1999/xhtml"> 
<head>
	<link rel="stylesheet" href="theme/default/style.css" type="text/css" />
	
	<style type="text/css">
		body, html {
			margin: 0; padding: 0;
		}
		#map {
		float: left;
		width: 80%;
		  
		box-sizing:border-box;
		
		}
		#infobox {
		box-sizing:border-box;
		width: 20%;
		vertical-align: top;	
		float: right;
		padding: 1em;
		}
		body {
		font:80%/100% 'helvetica neue',sans-serif,'arial';
		color: #666;
		}
		h2 {
			margin: 0 0 1em;
			color: #f60;
		} 
		li {
			margin-bottom: 0.5em;
		}
		ul {
			padding-left: 2em;
		}
		.olPopup p { margin:0px; }
	</style>
	
	<title>Openstreetmap Openlayers Example</title>
	
	<script src="http://maps.burningsilicon.net/OpenLayers-2.8/OpenLayers.js"></script>
	<script src="http://maps.burningsilicon.net/OpenLayers-2.8/cloudmade.js"></script>
	<script src="http://maps.burningsilicon.net/OpenLayers-2.8/OpenStreetMap.js"></script>
	
	<script type="text/javascript">
		var map;
		
		OpenLayers.Control.Click = OpenLayers.Class(OpenLayers.Control);
		
		function init()
		{
			map = new OpenLayers.Map ("map", {
			controls:[
			new OpenLayers.Control.Navigation(),
			new OpenLayers.Control.PanZoomBar(),
			new OpenLayers.Control.LayerSwitcher(),
			new OpenLayers.Control.Attribution(),
			new OpenLayers.Control.Permalink(),
			new OpenLayers.Control.ScaleLine(),
			new OpenLayers.Control.OverviewMap(),
			new OpenLayers.Control.MousePosition()],
			maxResolution: 156543.0399,
			numZoomLevels: 19,
			units: 'm',
			projection: new OpenLayers.Projection("EPSG:900913"),
			displayProjection: new OpenLayers.Projection("EPSG:4326")
			} );

			var layerMapnik = new OpenLayers.Layer.OSM.Mapnik("Mapnik", {opacity: 0.5});
			map.addLayer(layerMapnik);	
			
			var center = new OpenLayers.LonLat(153.02775, -27.47558).transform(new OpenLayers.Projection("EPSG:4326"), map.getProjectionObject());
			
			var zoom = 11
			map.setCenter(center, zoom);
			
			vectorLayer = new OpenLayers.Layer.GML("KML", 'mesh.kml',
			{
				projection: new OpenLayers.Projection("EPSG:4326"),
				eventListeners: { 'loadend': kmlLoaded },
				format: OpenLayers.Format.KML, 
				formatOptions: {
					style: {strokeColor: "green", strokeWidth: 5, strokeOpacity: 0.5},
					extractStyles: true, 
					maxDepth: 2,
					extractAttributes: true
				}
			});
				
			map.addLayer(vectorLayer);
		
			selectControl = new OpenLayers.Control.SelectFeature(map.layers[1],
				{onSelect: onFeatureSelect, onUnselect: onFeatureUnselect});
			map.addControl(selectControl);
			selectControl.activate();
			
			var click = new OpenLayers.Control.Click();
        		map.addControl(click);
		        click.activate();
		}
		
		function onPopupClose(evt) 
		{
			selectControl.unselect(selectedFeature);
		}
			
		function onFeatureSelect(feature) 
		{
			selectedFeature = feature;
			popup = new OpenLayers.Popup.FramedCloud("chicken", 
			feature.geometry.getBounds().getCenterLonLat(),
			new OpenLayers.Size(100,150),
			"<div style='font-size:.8em'><b>Name:</b>"+feature.attributes.name+"<br><b>Description:</b>"+feature.attributes.description+"</div>",
			null, true, onPopupClose);
			feature.popup = popup;
			map.addPopup(popup);
		}
		
		function onFeatureUnselect(feature) 
			{
			map.removePopup(feature.popup);
			feature.popup.destroy();
			feature.popup = null;
			}
		
		function kmlLoaded()
			{
			map.zoomToExtent(vectorLayer.getDataExtent());
			}
			
	</script>
</head>

<body onload="init()">
	<div id="map"></div>
	<div id="infobox">
		<h2>Unknown nodes</h2>
		<ul>
]]

footer = [[
		</ul>
	</div>
</body>
]]

function make_map_html (prefix, nodelist)
	local list = {}
	for i, node in pairs(nodelist:get()) do
		table.insert(list, "<li>" .. node.id .. "</li>")
	end

	write_file(prefix .. "mesh.html", {header, table.concat(list, "\n"), footer})
end
