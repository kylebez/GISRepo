#!/bin/sh

# Export the aprx files to mapx
if [ $# -eq 0 ] || [ "${1##*.}" ==  "arprx" ]; then
    echo "No aprx file provided"
    exit 1
fi
f=$1
serviceFile=$(git rev-parse --git-dir)/GIS_SERVICE_EXPORT #A file marker to record the hash of the export
if ! [ -f "$serviceFile" ]; then
> $serviceFile
fi
if ! [ -f $f ]; then
	echo "$f: No file found"
	exit 1
fi
fshaline=$(sha1sum $f)
fsha=$(echo "$fshaline" | awk -F' ' '{print $1}')
mapxf="$(echo ${f%.*}'-export.mapx')" #put the exported mapx file in the same location as the aprx file
#see if aprx is actually different, by comparing it to a previously recorded hash, if applicable
if ! grep -Fq $fsha $serviceFile; then
	echo "aprx has been changed, exporting to non-binary for diffing"
	#remove any lines already existing for the file
	lines=$(grep -v "$(basename $f)" $serviceFile)
	$lines > $serviceFile
	echo $fshaline >> $serviceFile
	#run python - create temp script file
	cat>export_temp.py <<PYTHON_END
import arcpy
import os
p = arcpy.mp.ArcGISProject("$(echo $f)")
pm = p.listMaps()[0]
if os.path.exists("$mapxf"):
	os.remove("$mapxf")
pm.exportToMAPX("$mapxf")
PYTHON_END
	c:\\Progra~1\\ArcGIS\\Pro\\bin\\Python\\scripts\\propy.bat export_temp.py
	#End python
	rm export_temp.py
	# Add the exported mapx to the commit
	git add $mapxf
	exit 0
else
	echo "Aprx file has no change from previous map export."
	exit 9
fi
