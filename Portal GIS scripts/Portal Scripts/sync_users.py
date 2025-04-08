from arcgis import GIS
from portal_scripts.gis import GIS
import json
import sys

# This script has methods to manage user syncing between our GIS portals in every environment, based on the prod users and their permissions
#NOTE: This will only work on the prod environment, after all passwords have been initialized with storeLoginPasswords.py or other method

def createAdminUName(e):
	return "{0}_gis_portal".format(e)

def syncUsersBetweenPortalEnvs():
	try:
		prodPortal = GIS(config.getUsername(createAdminUName("dev")))
	except Exception:
		raise Exception("Error connecting to the prod portal")
	prodUsers = prodPortal.getUsers('!esri_* & !gisadmin*')

	# Get lower environment portals
	lowerPortals = [GIS(createAdminUName(k),v) for (k,v) in dict(filter(lambda k: k!='prod',config.PORTAL_URLS.items())).items()]

	for prodUser in prodUsers:
		for portal in lowerPortals:		
			envUser = portal.getUsers(prodUser.username)
			# See if username matches on lower environments, as well as full name, and if it is an enterprise login (provider)
			if envUser is None:
				print(envUser+"is not on env: ")
			elif envUser.fullName == prodUser.fullName and envUser.provider == 'enterprise':
						
				# report user level
				try:
					if envUser.level != prodUser.level:
						print(envUser+"has a different level on prod");
						#envUser.update_level(prodUser.level)
				except:
					print("Failed to assign user {0} to appropriate level".format(envUser))

				# report active status
				if prodUser.disabled and not envUser.disabled:
					print(envUser+"is disabled on prod");
					#envUser.disable()
				elif not prodUser.disabled and envUser.disabled:
					print(envUser+"is enabled on prod");
					#envUser.enable()

				# report user roles
				if envUser.role != prodUser.role:
					try:
						print(envUser+"has different rol on prod")
						#envUser.update_role(prodUser.role)
					except:
						print("Failed to assign role to user {0}".format(envUser))
				
				# Check that roles have the same permissions in each environment
				envPriv, prodPriv = envUser.privileges, prodUser.privileges
				if json.dumps(json.loads(envPriv),sort_keys=True) != json.dumps(json.loads(prodPriv),sort_keys=True):
					print("Privileges do not match for {0} on {1}".format(envUser,portal.url))
					print("/n")
					print(envPriv)
					print("/n PROD /n")
					print(prodPriv)

if __name__ == "__main__":
	syncUsersBetweenPortalEnvs()
