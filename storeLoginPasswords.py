import keyring
import getpass
try:
	from arcnng3.toolboxes.tools import config
except ImportError:
	print("Need to run after custom environment is built, activated, and the configuration library (arcnng3) is available")
from arcnng3.portal_scripts.nngis import NNGIS
from arcnng3 import utils

# Moved all usernames to config.py, this script takes that and asks for passwords and then puts them into OS cred store
# Used to instantiate passwords on servers and the like
#
# NOTE: Requires arcnng3 library found in ArcGISTools repository
#
# Python version 3.x

noUpdate = False
def doAllServices():
	for s in services:
		setPasswordForService(s)
	return

def setPasswordForService(s):
	n = config.getUsername(s)
	try:
		if keyring.get_password(s,n) is None:
			if "gis_portal" in s: #If it has gis_admin in the name, it should be a portal
				isPortal = True
				if NNGIS.checkProfile(s):
					managePassword(s,n,isPortal)
					return
			else:
				isPortal = False
			pword = passwordPrompt(s, n)
			if isPortal:
				print("This is a GIS portal, trying to connect")
				try:
					NNGIS(n, url = config.getPortalUrl(s.split("_")[0]), password = pword, profileName=s)
					print("Success")
				except Exception as e:
					print(e)
					print("No portal, setting up general credential")
			else:
				keyring.set_password(s,n,pword)
		else:
			managePassword(s,n)
	except keyring.errors.PasswordSetError:
		raise Exception("Unable to set password")

def managePassword(service, name, isPortal = False):
	print("\n{0} already set with a password".format(service))
	global noUpdate
	if noUpdate:
		return
	u = input("Next action? (u) for update, (r) for remove, (n) for do nothing, or (x) for do not ask again)").lower()
	if u == 'x':
		noUpdate = True
	if u == 'u':
		pword = passwordPrompt(service, name)
		if isPortal:
				NNGIS.updateProfile(service,pwd=pword)
		else:
			keyring.set_password(service,name,pword)
	if u == 'r':
		if isPortal:
			NNGIS.delProfile(service)
		else:
			config.delPassword(service)
	if isPortal:
		pass

def passwordPrompt(service,name):
	ipt = ''
	while ipt != 'y':
		pw = getpass.getpass("\nSet the password for ({0})/{1}: ".format(service,name))
		ipt = input("Password is "+str(len(pw))+' characters?').lower() #Check to see if password was copied in correctly
	return pw

utils.initKeyringBackend()
services = sorted(config.LOGINS.keys())
print("Available services for configuration:")
for l in services:
	print(l)
i = input("\nDefine credentials for what service? (Use 'all' to define for all listed) ").lower()
if i == 'all':
	doAllServices()
else:
	setPasswordForService(i)
print("\nPassword set complete")