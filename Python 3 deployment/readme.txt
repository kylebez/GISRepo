A quick explanation of the files – they reference each other so should all be stored in the same folder:

python3_GIS_SETUP.ps1 is the launcher for the deployment

Run the powershell with the arguments:
<path to python 3 env folder> <path to arcnng3 library> [-logFile <path to log file>]
or
-Name <name of python 3 env> <path to arcnng3 library> [-logFile <path to log file>]

The second parameter set will create the python 3 environment in the default folder (in the Python/envs folder within %ProgramFiles%/<GIS Install Folder>)
Be sure to include the -Name switch

The logFile param is optional and will default to python3setup.log in the containing folder of the script

See the Python 3 GIS Server Setup Wiki for details on running the setup files: https://confluence.nng.i.midamerican.com/display/OAT/Python+3+GIS+Server+Setup
This is documented in the Wiki but basically we need conda to be able to break through carbon black AND possibly the corporate firewall to run these

Potential TO-DO items:
Rename arcnng3 back to arcnng3
Set up a config file to list all the packages we need, so we can easily update any changes across all environments