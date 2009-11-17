/*
 File: MyGovUserData.m
 Project: myGovernment
 Org: iPhoneFLOSS
 
 Copyright (C) 2009 Jeremy C. Andrus <jeremyandrus@iphonefloss.com>
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 $Id: $
 */

#import "MyGovUserData.h"
#import "CommunityDataManager.h"


@interface MyGovUser (private)
	- (NSString *)getCacheFileName;
@end


@implementation MyGovUser : NSObject 

@synthesize m_username, m_lastUpdated;
@synthesize m_firstname, m_middlename, m_lastname;
@synthesize m_email, m_avatar, m_password;
	// XXX - more info here?!

//static NSString *kMGUKey_ID = @"id";
static NSString *kMGUKey_Username = @"username";
static NSString *kMGUKey_LastUpdated = @"last_update";
static NSString *kMGUKey_FirstName = @"fname";
static NSString *kMGUKey_MiddleName = @"mname";
static NSString *kMGUKey_LastName = @"lname";
//static NSString *kMGUKey_Avatar = @"avatar";

+ (MyGovUser *)systemUser
{
	static MyGovUser *s_systemUser = NULL;
	if ( NULL == s_systemUser )
	{
		s_systemUser = [[MyGovUser alloc] init];
		
		s_systemUser.m_lastUpdated = [NSDate date];
		s_systemUser.m_firstname = @"My";
		s_systemUser.m_lastname = @"Government";
		s_systemUser.m_username = @"anonymous";
		s_systemUser.m_avatar = [UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"personIcon.png"]];
	}
	return s_systemUser;
}


- (void)dealloc
{
	[m_avatar release];
	[super dealloc];
}


- (id)initWithPlistDict:(NSDictionary *)plistDict
{
	if ( self = [super init] )
	{
		if ( nil == plistDict )
		{
			m_username = nil;
			m_lastUpdated = nil;
			m_firstname = nil;
			m_middlename = nil;
			m_lastname = nil;
			m_avatar = nil;
		}
		else
		{
			//self.m_id = [[plistDict objectForKey:kMGUKey_ID] integerValue];
			
			NSDate *tmpDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[[plistDict objectForKey:kMGUKey_LastUpdated] integerValue]];
			self.m_lastUpdated = tmpDate;
			[tmpDate release];
			
			self.m_username = [plistDict objectForKey:kMGUKey_Username];
			self.m_firstname = [plistDict objectForKey:kMGUKey_FirstName];
			self.m_middlename = [plistDict objectForKey:kMGUKey_MiddleName];
			self.m_lastname = [plistDict objectForKey:kMGUKey_LastName];
			
			//self.m_avatar = [UIImage imageWithData:[plistDict objectForKey:kMGUKey_Avatar]];
			self.m_avatar = [UIImage imageWithContentsOfFile:[MyGovUserData userAvatarPath:self.m_username]];
		}
	}
	return self;
}


- (NSDictionary *)writeToPlistDict
{
	NSMutableDictionary *plistDict = [[[NSMutableDictionary alloc] init] autorelease];
	//[plistDict setValue:[NSNumber numberWithInt:m_id] forKey:kMGUKey_ID];
	[plistDict setValue:[NSNumber numberWithInt:[m_lastUpdated timeIntervalSinceReferenceDate]] forKey:kMGUKey_LastUpdated];
	[plistDict setValue:m_username forKey:kMGUKey_Username];
	[plistDict setValue:m_firstname forKey:kMGUKey_FirstName];
	[plistDict setValue:m_middlename forKey:kMGUKey_MiddleName];
	[plistDict setValue:m_lastname forKey:kMGUKey_LastName];
	
	//NSData *imgData = UIImagePNGRepresentation(m_avatar);
	//[plistDict setValue:imgData forKey:kMGUKey_Avatar];
	
	return (NSDictionary *)plistDict;
}

- (NSString *)getCacheFileName
{
	//return [NSString stringWithFormat:@"%0d",m_id];
	return m_username;
}

@end



@implementation MyGovUserData

- (id)init
{
	if ( self = [super self] )
	{
		m_userData = [[NSMutableDictionary alloc] initWithCapacity:16];
	}
	return self;
}


- (void)dealloc
{
	[m_userData release];
	[super dealloc];
}


- (void)setUserInCache:(MyGovUser *)newUser
{
	if ( nil == newUser ) return;
	
	MyGovUser *nu = [[newUser retain] autorelease];
	
	// implicitly clear old data (allocated with autorelease)
	[m_userData setObject:nu forKey:nu.m_username];
	
	// store the new data to a local file
	NSString *fPath = [[MyGovUserData dataCachePath] stringByAppendingPathComponent:[nu getCacheFileName]];
	NSDictionary *userData = [nu writeToPlistDict];
	[userData writeToFile:fPath atomically:YES];
	
	// write the user avatar to disk (if present)
	if ( nil != nu.m_avatar )
	{
		NSData *avatarData = UIImagePNGRepresentation(nu.m_avatar);
		if ( nil != avatarData )
		{
			NSString *avatarPath = [MyGovUserData userAvatarPath:nu.m_username];
			NSString *avatarDir = [avatarPath stringByDeletingLastPathComponent];
			
			// make sure the directory exists!
			[[NSFileManager defaultManager] createDirectoryAtPath:avatarDir withIntermediateDirectories:YES attributes:nil error:NULL];
			
			// write the image
			[[NSFileManager defaultManager] createFileAtPath:avatarPath contents:avatarData attributes:nil];
		}
	}
}


- (MyGovUser *)userFromUsername:(NSString *)username
{
	MyGovUser *user = [m_userData objectForKey:username];
	if ( nil == user )
	{
		// not in memory - try disk
		NSString *fPath = [[MyGovUserData dataCachePath] stringByAppendingPathComponent:username];
		if ( [[NSFileManager defaultManager] fileExistsAtPath:fPath] )
		{
			NSDictionary *userData = [NSDictionary dictionaryWithContentsOfFile:fPath];
			if ( nil != userData )
			{
				user = [[MyGovUser alloc] initWithPlistDict:userData];
				if ( nil == user.m_username )
				{
					[user release]; user = nil;
				}
				else
				{
					// add the user to our in-memory cache so we don't have to touch the disk again :-)
					[m_userData setObject:user forKey:user.m_username];
				}
			}
		}
	}
	if ( nil == user )
	{
		// not in memory or disk - return a "system" user
		return [MyGovUser systemUser];
	}
	return user;
}


- (BOOL)usernameExistsInCache:(NSString *)username
{
	MyGovUser *u = [self userFromUsername:username];
	if ( nil == u ) return FALSE;
	if ( u.m_username == [MyGovUser systemUser].m_username ) return FALSE;
	
	return TRUE;
}


+ (NSString *)dataCachePath
{
	NSString *cachePath = [CommunityDataManager dataCachePath];
	cachePath = [cachePath stringByAppendingPathComponent:@"usercache"];
	return cachePath;
}

+ (NSString *)userAvatarPath:(NSString *)username
{
	NSString *avatarPath = [MyGovUserData dataCachePath];
	avatarPath = [avatarPath stringByAppendingFormat:@"/avatar/%@.png",username];
	return avatarPath;
}


@end
