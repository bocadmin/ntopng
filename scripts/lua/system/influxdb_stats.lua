--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
active_page = "system_stats"

require "lua_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local system_scripts = require("system_scripts_utils")
require("graph_utils")
require("alert_utils")

if not isAllowedSystemInterface() or (ts_utils.getDriverName() ~= "influxdb") then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local probe = system_scripts.getSystemProbe("influxdb")
local page = _GET["page"] or "overview"
local url = system_scripts.getPageScriptPath(probe) .. "?ifid=" .. getInterfaceId(ifname)
system_schemas = system_scripts.getAdditionalTimeseries("influxdb")

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. "InfluxDB" .. "</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

if(page == "historical") then
  print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
else
  print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

if(isAdministrator() and system_scripts.hasAlerts({entity = alertEntity("influx_db")})) then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\">")
   else
      print("\n<li><a href=\""..url.."&page=alerts\">")
   end

   print("<i class=\"fa fa-warning fa-lg\"></i></a>")
   print("</li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>

   ]]

-- #######################################################

if(page == "overview") then
    print("<table class=\"table table-bordered table-striped\">\n")

    print("<tr><th nowrap width='20%'>".. i18n("traffic_recording.storage_utilization") .."</th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")
    print("<tr><th nowrap>".. i18n("about.ram_memory") .."</th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-memory\"></span></td></tr>\n")

    if(probe ~= nil) then
       local stats = probe.getExportStats()
       print("<tr><th nowrap>".. i18n("system_stats.exported_points") .."</th><td><span id=\"influxdb-exported-points\">".. formatValue(stats.points_exported) .."</span></td></tr>\n")
       print("<tr><th nowrap>".. i18n("system_stats.dropped_points") .."</th><td><span id=\"influxdb-dropped-points\">".. formatValue(stats.points_dropped) .."</span></td></tr>\n")
       print("<tr><th nowrap>".. i18n("system_stats.export_retries") .."</th><td><span id=\"influxdb-export-retries\">".. formatValue(stats.export_retries) .."</span></td></tr>\n")
       print("<tr><th nowrap>".. i18n("system_stats.export_failures") .."</th><td><span id=\"influxdb-export-failures\">".. formatValue(stats.export_failures) .."</span></td></tr>\n")
    end

    print("<tr><th nowrap>".. i18n("system_stats.series_cardinality") .." <a href=\"https://docs.influxdata.com/influxdb/v1.7/concepts/glossary/#series-cardinality\"><i class='fa fa-external-link '></i></a></th><td><img class=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-series\"></span><i id=\"high-cardinality-warn\" class=\"fa fa-warning fa-lg\" title=\"".. i18n("system_stats.high_series_cardinality") .."\" style=\"color: orange; display:none\"></td></i></tr>\n")
    print[[<script>

 var last_db_bytes, last_memory, last_num_series;
 var last_exported_points, last_dropped_points;
 var last_export_retries, last_export_failures;

 function refreshInfluxStats() {
  $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
     $(".influxdb-info-load").hide();
     if(typeof info.db_bytes !== "undefined") {
       $("#influxdb-info-text").html(bytesToVolume(info.db_bytes) + " ");
       if(typeof last_db_bytes !== "undefined")
         $("#influxdb-info-text").append(drawTrend(info.db_bytes, last_db_bytes));
       last_db_bytes = info.db_bytes;
     }
     if(typeof info.memory !== "undefined") {
       $("#influxdb-info-memory").html(bytesToVolume(info.memory) + " ");
       if(typeof last_memory !== "undefined")
         $("#influxdb-info-memory").append(drawTrend(info.memory, last_memory));
       last_memory = info.memory;
     }
     if(typeof info.num_series !== "undefined") {
       $("#influxdb-info-series").html(addCommas(info.num_series) + " ");
       if(typeof last_num_series !== "undefined")
         $("#influxdb-info-series").append(drawTrend(info.num_series, last_num_series));
       last_num_series = info.num_series;
     }
     if(typeof info.points_exported !== "undefined") {
       $("#influxdb-exported-points").html(addCommas(info.points_exported) + " ");
       if(typeof last_exported_points !== "undefined")
         $("#influxdb-exported-points").append(drawTrend(info.points_exported, last_exported_points));
       last_exported_points = info.points_exported;
     }
     if(typeof info.points_dropped !== "undefined") {
       $("#influxdb-dropped-points").html(addCommas(info.points_dropped) + " ");
       if(typeof last_dropped_points !== "undefined")
         $("#influxdb-dropped-points").append(drawTrend(info.points_dropped, last_dropped_points, " style=\"color: #B94A48;\""));
       last_dropped_points = info.points_dropped;
     }
     if(typeof info.export_retries !== "undefined") {
       $("#influxdb-export-retries").html(addCommas(info.export_retries) + " ");
       if(typeof last_export_retries !== "undefined")
         $("#influxdb-export-retries").append(drawTrend(info.export_retries, last_export_retries));
       last_export_retries = info.export_retries;
     }
     if(typeof info.export_failures !== "undefined") {
       $("#influxdb-export-failures").html(addCommas(info.export_failures) + " ");
       if(typeof last_export_failures !== "undefined")
         $("#influxdb-export-failures").append(drawTrend(info.export_failures, last_export_failures, " style=\"color: #B94A48;\""));
       last_export_failures = info.export_failures;
     }

     if(info.num_series >= 950000)
       $("#high-cardinality-warn").show();
  }).fail(function() {
     $(".influxdb-info-load").hide();
  });
 }

setInterval(refreshInfluxStats, 5000);
refreshInfluxStats();
 </script>
 ]]

   print("</table>\n")
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "influxdb:storage_size"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {}
   url = url.."&page=historical"

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = system_schemas,
   })
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   local influxdb = ts_utils.getQueryDriver()
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity"] = alertEntity("influx_db")

   drawAlerts({hide_filters = true})

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")