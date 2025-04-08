import sys
import logging
import argparse
import json
from arcnng.tools import config
from arcnng.portal_scripts.gis import GIS

# This script has methods to manage user syncing between our GIS portals in 
# every environment based on the prod users and their permissions.
# NOTE: This will only work on the prod environment after all passwords have 
# been initialized with storeLoginPasswords.py or other method.

logger = logging.getLogger(__name__)

def compare_privileges(env, source_user, target_user):
	# Check that roles have the same permissions in each environment
	target_priv, source_priv = target_user.privileges, source_user.privileges
	if json.dumps(target_priv,sort_keys=True) != json.dumps(source_priv,sort_keys=True):
		logging.warning(f'{target_user.username}: {env.upper()} privileges do not match {config.TARGET_ENV.upper()}.')
		logging.info(f'{target_user.username} {env.upper()} privileges:\n {target_priv}')
		logging.info(f'{target_user.username} {config.TARGET_ENV.upper()} privileges:\n {source_priv}')

def create_admin_name(e):
	return f'{e}_gis_portal'

def find_non_prod_users(source_portal, target_portals):
	logger.info(f'Lower Environment Users Not in {config.TARGET_ENV.upper()}:')

	for env, target_portal in target_portals.items():
		for target_user in target_portal.users.search():
			if target_user.provider == 'enterprise':
				if(len(source_portal.users.search(target_user.username)) == 0):
					logger.info(f'{target_user.username}: User found in {env.upper()} but not in {config.TARGET_ENV.upper()}.')

def get_license_counts(portal):
	for license in portal.users.license_types:
		if license['maxUsers'] == 0:
			logger.info(f'License type {license["id"]}: No available licenses')
			continue

		counts = [c for c in portal.users.counts('user_type', False) if license['id'] in c.values()]
		assigned = 0 if len(counts) == 0 else counts[0]['count']
		logger.info(f'License type {license["id"]}: {assigned} of {license["maxUsers"]} used')

def get_portals():
	if config.TARGET_ENV != 'prod':
		raise Exception('This must be run from the prod environment.')
	try:
		source_portal = GIS(create_admin_name('prod')).portal
	except:
		raise Exception('Error connecting to the source portal.')

	# Get portals containing users that will be updated
	target_portals = {}
	for k in dict(filter(lambda k: k[0] not in ('external', 'dev', 'prod'), config.PORTAL_URLS.items())):
		target_portals[k] = GIS(create_admin_name(k)).portal
	
	return source_portal, target_portals

def main():
	try:
		# client can turn on file logging by including --log flag
		parser = argparse.ArgumentParser()
		parser.add_argument('--log', action='store_true', help='Turn on logging.')
		args = parser.parse_args()

		start_logging(args.log)
		logger.info('BEGIN USER SYNCHRONIZATION')
		sync_users_between_portals()
	except Exception:
		logging.exception('Something went wrong.')
	finally:
		logger.info('END USER SYNCHRONIZATION')

def start_logging(file_logging):
	stream_handler = logging.StreamHandler(sys.stdout)
	stream_handler.setLevel(logging.INFO)
	handlers = [stream_handler]
	
	if file_logging:
		# file will reside in same location as script.
		log_file = 'sync-portal-users.log'
		handlers.append(logging.FileHandler(log_file))

	logging.basicConfig(
		level=logging.INFO,
		format="%(asctime)s [%(levelname)s] %(message)s",
		handlers=handlers
	)

	# arcgis module pollutes the root log so only allow its errors
	arcgis_logger = logging.getLogger('arcgis')
	arcgis_logger.setLevel(logging.ERROR)

def sync_active_status(source_user, target_user):
	if source_user.disabled and not target_user.disabled:
		target_user.disable()
		logger.info(f'{target_user.username}: User account disabled.')
	elif not source_user.disabled and target_user.disabled:
		target_user.enable()
		logger.info(f'{target_user.username}: User account enabled.')

def sync_user_role(source_user, target_user):
	'''
	Determining 'org_user, 'viewer' and 'data_editor' roles requires 
	checking cryptic internal api values for roleId. If the api values 
	change the generic fallback target_user.role will be safely used.
	'''
	if source_user.roleId != target_user.roleId:
		success = target_user.update_role(source_user.roleId)

		if success:
			if target_user.roleId == 'iAAAAAAAAAAAAAAA':
				role = 'viewer'
			elif target_user.roleId == 'iBBBBBBBBBBBBBBB':
				role = 'data_editor'
			else:
				role = target_user.role

			logger.info(f'{target_user.username}: Role updated to {role}.')
		else: 
			logger.error(f'{target_user.username}: Failed to assign role {source_user.role}. ' + 
				'An org_user could be a user, viewer or data_editor.')

def sync_user_type(source_user, target_user):
	'''
	User types are related to the license assigned to the member, 
	therefore update_license_type() function is used.
	'''
	if source_user.userLicenseTypeId != target_user.userLicenseTypeId:
		result = target_user.update_license_type(source_user.userLicenseTypeId)

		# return can be a bool or dict
		if (isinstance(result, bool)):
			if result:
				logger.info(f'{target_user.username}: Updated User Type from {source_user.userLicenseTypeId} to {target_user.userLicenseTypeId}.')
			else:
				logger.info(f'{target_user.username}: Unable to update User Type due to unknown problem.')
		else:
			logger.error(f'{target_user.username}: Unable to update User Type. {result["results"][0]["error"]["message"]}.')

def sync_users_between_portals():
	source_portal, target_portals = get_portals()
	source_users = source_portal.users.search()

	# Update users in target portals
	for env, target_portal in target_portals.items():
		logging.info(f'Synchronizing {env.upper()}.')
		logging.info(f'{env.upper()} available user licenses:')
		get_license_counts(target_portal)

		logging.info(f'Synchronizing {env.upper()} users...')

		for source_user in source_users:
			target_user = target_portal.users.search(source_user.username)

			if len(target_user) != 1:
				logger.info(f'{source_user.username}: User exists in {config.TARGET_ENV.upper()} but not in {env.upper()}.')
				continue

			target_user = target_user[0]

			if (target_user is not None and 
					target_user.fullName == source_user.fullName and 
					target_user.provider == 'enterprise'):		
				sync_active_status(source_user, target_user)
				sync_user_type(source_user, target_user)
				sync_user_role(source_user, target_user)
				compare_privileges(env, source_user, target_user)

	find_non_prod_users(source_portal, target_portals)

if __name__ == '__main__':
	main()