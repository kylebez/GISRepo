#Python 3 GIS Setup#


1.	Allow the following urls to get through any firewalls, otherwise the conda install may fail and/or the environments can’t be maintained and may have issues:
https://conda.anaconda.org
https://repo.anaconda.com
others as needed

1.	Open a PowerShell as Admin and run:
<LOCATION>\python3_GIS_SETUP.ps1 <full path of desired new gis python environment> <path to custom library folder> <log file path> - log file path is defaulted to the containing folder of python3_GIS_SETUP

2.	The script will pause at certain moments and allow to choose between continuing, retrying the previous operation, or aborting the script. This can be used to respond to any errors that are output in the conda operations. 

3.	python3_GIS_SETUP.ps1 script does the following:
	1.	clone the default arcgispro-py3 environment to the new nng-py3 environment
	2.	install dependencies found in config
	3.	create resource file for activating the correct environment when running scripts
	4.	create the symbolic link to any custom libarariesfound in config in the site-packages folder in the new python3 environment
	5.	create the symbolic link to the new python3 environment in the ...Python\envs folder
	6.	set new python3 environment as the active one
	7.	add custom library folder to ArcGISPro.pth file in the site-packages folder of the arcgispro-py3 environment (necessary for toolbox tools to work when running through the pro runtime)
	8.	Some of the above commands require elevation and the script will prompt you for admin (s_account) credentials if needed.
4.	To confirm the new environment is installed 
	1.	Open Python Command Prompt (Start → ArcGIS → Python Command Prompt) and run:
	conda info -e
	2.	The new python environment should be listed

Development Environment Setup
1.	Read the Python Deployment Workflow sections
2.	Open the Python Command Prompt (should have been installed with ArcGIS Pro)
3.	Run python3_GIS_SETUP.ps1 NOT as admin
Set up VS Code:
In settings:
"python.pythonPath": "<path to new env\\python.exe"
"python.condaPath": "%PROGRAMFILES%\\ArcGIS\\Pro\\bin\\Python\\Scripts\\conda.exe”
Need to change shell to cmd because psh doesn’t support conda environments:
"terminal.integrated.shell.windows" : "Command Prompt"  - for older vs code versions
"terminal.integrated.defaultProfile.windows" : "Command Prompt"

Python 3 environment maintenance
To remove and reinstall:
Run python3_GIS_SETUP.ps1 again, passing the same parameters as installed environment

