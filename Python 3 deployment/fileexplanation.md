A quick explanation of the files – they reference each other so should all be stored in the same folder:

python3_GIS_SETUP.ps1 is the launcher for the deployment

Run the powershell with the arguments:
<path to python 3 env folder> <path to custom library> [-logFile <path to log file>]
or
-Name <name of python 3 env> <path to custom library> [-logFile <path to log file>]

The second parameter set will create the python 3 environment in the default folder (in the Python/envs folder within %ProgramFiles%/<GIS Install Folder>)
Be sure to include the -Name switch

The logFile param is optional and will default to python3setup.log in the containing folder of the script

TO-DO items:
Set up a config file to list all the packages we need, so we can easily update any changes across all environments