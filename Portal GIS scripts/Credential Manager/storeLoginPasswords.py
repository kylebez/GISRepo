import keyring
import getpass
import os
from <config_lib> import config
from configparser import ConfigParser
from <portal_scripts>.gis import GIS

# Moved all usernames to config.ini, this script takes that and asks for passwords and then puts them into OS cred store
# Used to instantiate passwords on servers and the like
#
# Python version 3.x

noUpdate = False
def doAllServices():
	parser = ConfigParser()
	parser.read(os.path.join(os.path.dirname(config.__file__),"config.ini"))
	for s in services:
		setPasswordForService(s)
	return

def setPasswordForService(s):
	n = config.getUsername(s)
	try:
		if keyring.get_password(s,n) is None:
			if "gis_portal" in s: #If it has gis_portal in the name, it should be a portal
				isPortal = True
				if GIS.checkProfile(s):
					managePassword(s,n,isPortal)
					return
			else:
				isPortal = False
			pword = getpass.getpass("\nSet the password for the {0} service with the username {1}: ".format(s,n))
			if isPortal:
				print("This is a GIS portal, trying to connect")
				try:
					GIS(n, url = config.getPortalUrl(s.split("_")[0]), password = pword, profileName=s)
					print("Success")
				except Exception as e:
					print(e)
					print("No portal, setting up general credential")
			else:
				keyring.set_password(s,n,pword)
		else:
			managePassword(s,n)
	except keyring.errors.PasswordSetError:
		print("Unable to set password")
	return

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
				GIS.updateProfile(service,pwd=pword)
		else:
			keyring.set_password(service,name,pword)
	if u == 'r':
		if isPortal:
			GIS.delProfile(service)
		else:
			config.delPassword(service)
	if isPortal:
		pass

def passwordPrompt(service,name):
	return getpass.getpass("\nSet the password for ({0})/{1}: ".format(service,name))

parser = ConfigParser()
parser.read(os.path.join(os.path.dirname(config.__file__),"config.ini"))
services = sorted(dict(parser.items("logins")).keys())
print("Available services for configuration:")
for l in services:
	print(l)
i = input("\nDefine credentials for what service? (Use 'all' to define for all listed) ").lower()
if i == 'all':
	doAllServices()
else:
	setPasswordForService(i)
print("\nPassword set complete")