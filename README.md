# Managing ArcGIS Pro binary files (ArcPro Project SRC Management)
   *Note that this only applies to ArcGIS Pro*

   Binary files cannot be diffed in git, but if a service is changed, it can be exported to a file with a json that can.

   The GIS binary files are in the *Services* folder, and each one should have a corresponding export file (`servicename`-export.mapx). This file is for **diffing only** and **should not be updated directly** (this is ESRI's own recommendation). This file is regenerated on every commit containing a changed binary (.aprx) file unless `--no-verify` is specified. 

   ## To set up this functionality

   1. Create a link between `.githooks/pre-commit` and `.git/hooks/pre-commit`
   2. Follow the directions in `.githooks/aprx-diff` and copy the code lines into your `.git/config file` under the `[alias]` section

   ## Explanation
   
   This binary diff process will trigger one of two ways:
   1. On every commit, granted that githooks are not bypassed
   2. Manually, with the `git aprx-diff <file>` alias, provided this alias was added in step 2 above. `<file>` is the file to diff.

   On a commit, the script will look for staged files with the extension aprx, or will use the passed in file if run via alias. It will compare the file hash to the hash stored in `.git\GIS_SERVICE_HASH`. This hash is regenerated every time the process is run. If the hash is different, the script will execute a python code to export the <u>first</u> map object in the project file (we are assuming there will only be one map for each service). After the map is exported, a hash will be checked against the map export as will (stored in `.git\GIS_SERVICE_EXPORT_HASH`), as some binary changes do not affect the map at all and an export is not needed.

   If there is no export existing for this file, one will be exported regardless of the hash.

   To clear the hash and force a fresh export, delete the hash files or run `git clear-aprx-diff`.
   
   **Please note:** There is odd behavior when commiting through VSCode GUI. this works best through command line commits.
   
   #TODO: Need to replace all the UAC workarounf stuff with runas