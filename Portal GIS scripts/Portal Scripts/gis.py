from urllib.parse import urlparse
import arcgis.gis as Portal
from <config-lib> import config

#NOTES:
# 
# Use profile manager to save persistent portal logins on the server, so not logging every time this class is instantiated?
##This method can rid us of secrets files
#
# Can assign item id to upload, but must not be used, so need to delete the previous item with that id first. How do we determine the id? Configged?
#
# Python version: 3.x


class GIS(object):
	"""
    A class used for a gis object

    ...

    Attributes
    ----------
    portal : GIS
        the current GIS portal connection instance
    connUser : str
        the current username for the GIS portal connection

    Methods
    -------
    checkProfile(username)
        Check if a profile already exists for a given username. Returns Boolean.
    """
	def __init__(self,nameOrConn="",url=config.getPortalUrl(config.TARGET_ENV), password="", profileName=None): #if url is not passed in, use the one from the environment config
		"""
		Parameters
        ----------
        nameOrConn : str
            A username or connection string. Username will be parsed from connection string, if passed
        url : str
            The url for the gis portal connection. Default will retreive this from the current environment config file
        password : str
            The password for the gis portal connection
		profileName: str
			A way to pass in a profile name (to match the config file) - will default to username if nothing passed
		"""
		if nameOrConn == "":
			raise Exception("Missing connection or username parameters")

		try:
			#automatically parse out username from a valid connection string or file path, path detected if it has the format server@database@user.sde
			username = nameOrConn.split('@')[1].split('.')[0]
		except IndexError:
			#if not an connection string or file path, assume the parameter is passing in a username			
			username = nameOrConn
		finally:
		#check if username exists as a profile, if password is not passed in, see if config can get it
			if password == "":
				password = config.getPassword(username)
			if profileName is None:
						profileName = username
			if Portal.checkProfile(profileName):
				self.portal = Portal.GIS(profile=profileName)
			else:
				# If profile doesn't exist then make one
				try:
					self.portal = Portal.GIS(url, username, password, profile=profileName)
				except Exception:
					raise Exception("Unable to connect to portal with username '{0}'".format(username))
			self.connUser = username
            self.url = self.portal.url

	def sharePortalItems(self,name,share_group):
		if isinstance(share_group, str):
			share_group = None if share_group == 'None' or share_group == '' else share_group.split(',') 
		shareArgs = [False,False,None]
		connUser_content = self.connUser.items()
		for item in connUser_content:
			if name == item.title:
				for group in share_group:
					if group in ['Everyone', 'Public']:
						shareArgs[0]=True
					elif group == "Org":
						shareArgs[1]=True
					else:
						shareArgs[2].append(group) 
				item.share(*shareArgs)

	def getUsers(self,name): #Pass in None to return all users
		users = self.portal.users.search(name) #pylint: disable=no-member
		return users

	def getEnv(self):
		try:
			return (urlparse(self.url).netloc).split(".")[0].split('-')[1]
		except KeyError:
			return "prod"
	@classmethod
	def checkProfile(cls,name):
		if name in Portal.ProfileManager().list(): #pylint: disable=no-value-for-parameter
			return True
		else:
			return False
	
	@classmethod
	def delProfile(cls,name):
		Portal.ProfileManager().delete(name)

	@classmethod
	def updateProfile(cls,name,uname = None,pwd = None):
		if uname is None:
			uname = config.getUsername(name)
		if pwd is None:
			pwd = config.getPassword(name)
		Portal.ProfileManager().update(name,username=uname,password=pwd)


