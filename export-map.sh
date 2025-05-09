#!/bin/sh
# Export the aprx files to mapx
create_currentHashFile () {
	echo "$(sha1sum $1)" > $2
}
compare_hashfile () {
	compare_hashfile () {
		if cmp -s "$1" "$2"; then
			return 1
		else
			return 0
		fi
	}
}
if [ -z "$1" ] || [ "${1##*.}" ==  "arprx" ]; then
    echo "No aprx file provided"
    exit 1
fi
f=$1
gitDir=$(git rev-parse --git-dir)

#Create files that contain the hash of the current binary and export, respectively
#TODO handle multiple aprx changes (by naming each hash file to the name of the aprx).
mapHashFile=$gitDir/CURRENT_GIS_MAP_HASH
prevMapHashFile=$gitDir/COMMITTED_GIS_MAP_HASH
#If files 
create_currentHashFile $f $mapHashFile
if ! [ -f $f ]; then
	echo "$f: No file found"
	exit 1
fi
mapxf="$(echo ${f%.*}'-export.mapx')" #put the exported mapx file in the same location as the aprx file
compare_hashfile $f $mapHashFile $prevMapHashFile #compare with previous map hash
if [ $? -eq 0 ] || ! [ -f $mapxf ]; then
	echo "aprx has been changed since previously committed and there is no current export. Exporting to mapx for diffing..."
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
	git add $mapxf
	exit 0
else
	exit 9
fi

