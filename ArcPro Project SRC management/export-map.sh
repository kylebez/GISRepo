#!/bin/sh
# Export the aprx files to mapx
create_hashFile () {
	if ! [ -f "$1" ]; then
	> $1
	fi
}
check_and_update_hashfile () {
	#see if hash is actually different, by comparing it to a previously recorded hash
	#if hash is different, the file has been changed since last export
	shaline=$(sha1sum $1)
	sha=$(echo "$1" | awk -F' ' '{print $1}')
	if ! grep -Fq $sha $2; then
		#remove any lines already existing for the file in question
		lines=$(grep -v "$(basename $1)" $2)
		$lines > $2
		echo $shaline >> $2
		return 0
	else 
		return 1
	fi
}
if [ -z "$1" ] || [ "${1##*.}" ==  "arprx" ]; then
    echo "No aprx file provided"
    exit 1
fi
f=$1
gitDir=$(git rev-parse --git-dir)
#File markers to record the hash of the binary and export, respectively 
serviceHashFile=$gitDir/GIS_SERVICE_HASH
exportHashFile=$gitDir/GIS_SERVICE_EXPORT_HASH
create_hashFile $serviceHashFile
create_hashFile $exportHashFile
if ! [ -f $f ]; then
	echo "$f: No file found"
	exit 1
fi
mapxf="$(echo ${f%.*}'-export.mapx')" #put the exported mapx file in the same location as the aprx file
check_and_update_hashfile $f $serviceHashFile
if [ $? -eq 0 ] || ! [ -f $mapxf ]; then
	echo "aprx has been changed or has no export, exporting to non-binary for diffing"
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
	#check if the export is any different - sometimes a binary can change but the map does not
	check_and_update_hashfile $mapxf $exportHashFile
	if [ $? -eq 0 ]; then
		# Add the exported mapx to the commit if it is different
		git add $mapxf
	fi
	exit 0
else
	echo "Aprx file has no change from previous map export."
	exit 9
fi

