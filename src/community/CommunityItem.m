/*
 File: CommunityItem.m
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

#import <CoreLocation/CoreLocation.h>

#import "myGovAppDelegate.h"
#import "CommunityItem.h"
#import "MyGovUserData.h"

static NSString *kCIDateFormat = @"yyyy-MM-dd HH:mm:ss";//@"%Y-%m-%d %H:%M:%S";


@implementation CommunityComment
@synthesize m_id, m_creator, m_date, m_communityItemID, m_title, m_text;

static NSString *kCCKey_ID = @"id";
static NSString *kCCKey_Creator = @"creator";
static NSString *kCCKey_Date = @"creation_date";
static NSString *kCCKey_CommunityItemID = @"communityItemID";
static NSString *kCCKey_Title = @"subject";
static NSString *kCCKey_Text = @"message";


- (id)init
{
	if ( self = [super init] )
	{
		m_id = nil; 
		m_creator = nil; 
		m_communityItemID = nil; 
		m_title = nil; 
		m_text = nil;
		m_localSecondsFromGMT = 0;
	}
	return self;
}


- (id)initWithPlistDict:(NSDictionary *)plistDict
{
	if ( self = [super init] )
	{
		if ( nil == plistDict )	
		{
			m_id = nil; 
			m_creator = nil; 
			m_communityItemID = nil; 
			m_title = nil; 
			m_text = nil;
		}
		else
		{
			self.m_id = [plistDict objectForKey:kCCKey_ID];
			self.m_creator = [plistDict objectForKey:kCCKey_Creator];
			
			NSString *dateStr = [plistDict objectForKey:kCCKey_Date]; // this is in GMT
			if ( nil == dateStr )
			{
				m_date = nil;
			}
			else
			{
				NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
				[dateFmt setDateFormat:kCIDateFormat];
				// chop of the sub-second accuracy :-)
				NSRange dotRange = [dateStr rangeOfString:@"."];
				if ( dotRange.location > 0 && dotRange.length == 1 )
				{
					dateStr = [dateStr substringToIndex:dotRange.location];
				}
				NSDate *tmpDate = [dateFmt dateFromString:dateStr];
				m_localSecondsFromGMT = [[NSTimeZone localTimeZone] secondsFromGMTForDate:tmpDate];
				self.m_date = [tmpDate addTimeInterval:m_localSecondsFromGMT];
			}
			
			self.m_communityItemID = [plistDict objectForKey:kCCKey_CommunityItemID];
			self.m_title = [plistDict objectForKey:kCCKey_Title];
			self.m_text = [[plistDict objectForKey:kCCKey_Text] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		}
	}
	return self;
}


- (NSDictionary *)writeToPlistDict
{
	NSMutableDictionary *plistDict = [[[NSMutableDictionary alloc] init] autorelease];
	
	[plistDict setValue:m_id forKey:kCCKey_ID];
	
	//[plistDict setValue:[NSNumber numberWithInt:m_creator] forKey:kCCKey_Creator];
	[plistDict setValue:m_creator forKey:kCCKey_Creator];
	
	NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
	[dateFmt setDateFormat:kCIDateFormat];
	NSDate *tmpDate = [self.m_date addTimeInterval:-m_localSecondsFromGMT];
	[plistDict setValue:[dateFmt stringFromDate:tmpDate] 
				 forKey:kCCKey_Date];
	
	[plistDict setValue:m_communityItemID forKey:kCCKey_CommunityItemID];
	
	[plistDict setValue:[m_title stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] forKey:kCCKey_Title];
	
	[plistDict setValue:[m_text stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] 
				 forKey:kCCKey_Text];
	
	return (NSDictionary *)plistDict;
}


- (NSComparisonResult)compareCommentByDate:(CommunityComment *)that
{
	// don't allow "top posting": sort in reverse!
	return [m_date compare:[that m_date]];
}

@end 


@interface CommunityItem (private)
	- (void)p_initFromPlistDict:(NSDictionary *)plistDict;
@end


@implementation CommunityItem

@synthesize m_id, m_type;
@synthesize m_image, m_title, m_date;
@synthesize m_creator, m_summary, m_text;
@synthesize m_mygovURLTitle, m_mygovURL;
@synthesize m_webURLTitle, m_webURL;
@synthesize m_eventLocation, m_eventLocDescrip;
@synthesize m_eventDate;

static NSString *kCIKey_ID = @"id";
static NSString *kCIKey_Type = @"type";
static NSString *kCIKey_Image = @"image";
static NSString *kCIKey_Title = @"subject";
static NSString *kCIKey_Date = @"creation_date";
static NSString *kCIKey_Creator = @"creator";
static NSString *kCIKey_Summary = @"summary";
static NSString *kCIKey_Text = @"message";
static NSString *kCIKey_MyGovURLTitle = @"appurl_title";
static NSString *kCIKey_MyGovURL = @"appurl";
static NSString *kCIKey_WebURLTitle = @"exturl_title";
static NSString *kCIKey_WebURL = @"exturl";
static NSString *kCIKey_Comments = @"comments";
static NSString *kCIKey_EventLocation = @"event_location";
static NSString *kCIKey_EventDate = @"event_date";
static NSString *kCIKey_EventAttendees = @"event_attendees";


- (id)init
{
	if ( self = [super init] )
	{
		[self p_initFromPlistDict:nil]; // does all the basic initialization :-)
	}
	
	return self;
}


- (void)dealloc
{
	[m_userComments release];
	[m_eventAttendees release];
	[super dealloc];
}


- (id)initFromPlistDictionary:(NSDictionary *)dict
{
	if ( self = [super init] )
	{
		[self p_initFromPlistDict:dict];
	}
	return self;
}


- (id)initFromFile:(NSString *)fullPath
{
	if ( self = [super init] )
	{
		if ( [[NSFileManager defaultManager] fileExistsAtPath:fullPath] )
		{
			//NSLog( @"Reading %@...", fullPath );
			NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:fullPath];
			[self p_initFromPlistDict:plistDict];
		}
		else
		{
			[self p_initFromPlistDict:nil];
		}
	}
	return self;
}


- (id)initFromURL:(NSURL *)url
{
	if ( self = [super init] )
	{
		// initialize from URL!
		NSDictionary *plistDict = [[NSDictionary alloc] initWithContentsOfURL:url];
		[self p_initFromPlistDict:plistDict];
		[plistDict release];
	}
	return self;
}


- (void)writeItemToFile:(NSString *)fullPath
{	
	//NSLog( @"Writing item '%@' to %@...", m_id, fullPath );
	
	NSDictionary *plistDict = [self writeItemToPlistDictionary];
	BOOL success = [plistDict writeToFile:fullPath atomically:YES];
	
	if ( !success ) NSLog( @"Failed to write '%@' to file!", m_id );
}


- (NSDictionary *)writeItemToPlistDictionary
{
	NSString *urlStr;
	NSEnumerator *objEnum;
	id obj;
	
	NSMutableDictionary *plistDict = [[[NSMutableDictionary alloc] init] autorelease];
	
	[plistDict setValue:m_id forKey:kCIKey_ID];
	
	[plistDict setValue:[NSNumber numberWithInt:(int)m_type] 
				 forKey:kCIKey_Type];
	
	[plistDict setValue:UIImageJPEGRepresentation(m_image,1.0) 
				 forKey:kCIKey_Image];
	
	[plistDict setValue:[m_title stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding]
				 forKey:kCIKey_Title];
	
	NSDateFormatter *dateFmt = [[[NSDateFormatter alloc] init] autorelease];
	[dateFmt setDateFormat:kCIDateFormat];
	NSDate *tmpDate = [self.m_date addTimeInterval:-m_localSecondsFromGMT];
	[plistDict setValue:[dateFmt stringFromDate:tmpDate] 
				 forKey:kCIKey_Date];
	
	/*
	[plistDict setValue:[NSNumber numberWithInt:[m_date timeIntervalSinceReferenceDate]] 
				 forKey:kCIKey_Date];
	*/
	/*
	[plistDict setValue:[NSNumber numberWithInt:m_creator] 
				 forKey:kCIKey_Creator];
	*/
	[plistDict setValue:m_creator forKey:kCIKey_Creator];
	
	[plistDict setValue:[m_summary stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] 
				 forKey:kCIKey_Summary];
	
	[plistDict setValue:[m_text stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] 
				 forKey:kCIKey_Text];
	
	[plistDict setValue:[m_mygovURLTitle stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] 
				 forKey:kCIKey_MyGovURLTitle];
	
	// be extra-careful about URLs...
	urlStr = [[m_mygovURL absoluteString] stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	[plistDict setValue:urlStr
				 forKey:kCIKey_MyGovURL];
	
	[plistDict setValue:[m_webURLTitle stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding] 
				 forKey:kCIKey_WebURLTitle];
	
	// be extra-careful about URLs...
	urlStr = [[m_webURL absoluteString] stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
	urlStr = [urlStr stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	[plistDict setValue:urlStr
				 forKey:kCIKey_WebURL];
	
	// get comments into a nice array
	NSMutableArray *tmpArray = [[NSMutableArray alloc] initWithCapacity:[m_userComments count]];
	objEnum = [m_userComments objectEnumerator];
	while ( obj = [objEnum nextObject] )
	{
		[tmpArray addObject:[obj writeToPlistDict]];
	}
	[plistDict setValue:tmpArray forKey:kCIKey_Comments];
	[tmpArray release];
	
	if ( nil == m_eventLocDescrip ) self.m_eventLocDescrip = @" ";
	
	[plistDict setValue:[NSString stringWithFormat:@"%.f:%.f:%@",
									m_eventLocation.coordinate.latitude,
									m_eventLocation.coordinate.longitude,
									[m_eventLocDescrip stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding]
						] 
				 forKey:kCIKey_EventLocation];
	
	tmpDate = [self.m_eventDate addTimeInterval:-m_localSecondsFromGMT];
	[plistDict setValue:[dateFmt stringFromDate:tmpDate] 
				 forKey:kCIKey_EventDate];
	
	// this is an array of MyGovUser objects
	tmpArray = [[NSMutableArray alloc] initWithCapacity:[m_eventAttendees count]];
	objEnum = [m_eventAttendees objectEnumerator];
	while ( obj = [objEnum nextObject] )
	{
		MyGovUser *user = (MyGovUser *)obj;
		[tmpArray addObject:user.m_username];
	}
	[plistDict setValue:tmpArray forKey:kCIKey_EventAttendees];
	
	return (NSDictionary *)plistDict;
}


- (void)generateUniqueItemID
{
	self.m_id = @"-1"; // unused - the server does this for us now!
	
	/*
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString( kCFAllocatorDefault, uuid );
	
	// set our new ID!
	self.m_id = (NSString *)uuidStr;
	
	CFRelease(uuidStr);
	CFRelease(uuid);
	*/
}


- (void)addComment:(NSString *)comment fromUser:(NSString *)mygovUser withTitle:(NSString *)title
{
	CommunityComment *cc = [[[CommunityComment alloc] init] autorelease];
	cc.m_communityItemID = self.m_id;
	cc.m_text = comment;
	cc.m_title = title;
	cc.m_creator = mygovUser;
	
	[self addComment:cc];
}


- (void)addComment:(CommunityComment *)comment
{
	if ( nil == comment ) return;
	
	if ( nil == m_userComments )
	{
		m_userComments = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	
	[m_userComments setValue:comment forKey:comment.m_id];
}


- (NSArray *)comments
{
	return (NSArray *)[m_userComments allValues];
}


- (NSComparisonResult)compareItemByDate:(CommunityItem *)that
{
	return [[that m_date] compare:m_date];
}


- (void)addEventAttendee:(NSString *)mygovUser
{
	if ( nil == m_eventAttendees )
	{
		m_eventAttendees = [[NSMutableArray alloc] initWithCapacity:2];
	}
	
	MyGovUser *user = [[myGovAppDelegate sharedUserData] userFromUsername:mygovUser];
	if ( nil != user ) [m_eventAttendees addObject:user];
}


- (NSArray *)eventAttendees
{
	return (NSArray *)m_eventAttendees;
}


#pragma mark CommunityItem Private


- (id)copyWithZone:(NSZone *)zone
{
	if ( nil != zone ) return nil;
	CommunityItem *newItem = [[CommunityItem alloc] initFromPlistDictionary:[self writeItemToPlistDictionary]];
	return newItem;
}

- (void)p_initFromPlistDict:(NSDictionary *)plistDict
{
	m_id = nil;
	m_type = eCommunity_Chatter; // default type
	m_image = nil;
	m_title = nil;
	m_date = nil;
	m_creator = nil;
	m_summary = nil;
	m_text = nil;
	m_mygovURLTitle = nil;
	m_mygovURL = nil;
	m_webURLTitle = nil;
	m_webURL = nil;
	m_userComments = nil;
	m_eventLocation = nil;
	m_eventDate = nil;
	m_eventAttendees = nil;
	m_localSecondsFromGMT = 0;
	
	// read file data!
	if ( nil != plistDict )
	{
		self.m_id = [plistDict objectForKey:kCIKey_ID];
		self.m_type = (CommunityItemType)[[plistDict objectForKey:kCIKey_Type] integerValue];
		self.m_image = [UIImage imageWithData:[plistDict objectForKey:kCIKey_Image]];
		
		/*
		NSInteger dateInt = [[plistDict objectForKey:kCIKey_Date] integerValue];
		NSDate *tmpDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:dateInt];
		self.m_date = tmpDate;
		[tmpDate release];
		*/
		NSRange dotRange;
		NSDateFormatter *dateFmt = [[[NSDateFormatter alloc] init] autorelease];
		
		NSString *dateStr = [plistDict objectForKey:kCIKey_Date]; // date in GMT
		if ( nil == dateStr )
		{
			m_date = nil;
		}
		else
		{
			[dateFmt setDateFormat:kCIDateFormat];
			// chop of the sub-second accuracy :-)
			dotRange = [dateStr rangeOfString:@"."];
			if ( dotRange.location > 0 && dotRange.length == 1 )
			{
				dateStr = [dateStr substringToIndex:dotRange.location];
			}
			NSDate *tmpDate = [dateFmt dateFromString:dateStr];
			m_localSecondsFromGMT = [[NSTimeZone localTimeZone] secondsFromGMTForDate:tmpDate];
			self.m_date = [tmpDate addTimeInterval:m_localSecondsFromGMT];
		}
		
		//self.m_creator = [[plistDict objectForKey:kCIKey_Creator] integerValue];
		self.m_creator = [plistDict objectForKey:kCIKey_Creator];
		self.m_title = [[plistDict objectForKey:kCIKey_Title] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		self.m_summary = [[plistDict objectForKey:kCIKey_Summary] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		self.m_text = [[plistDict objectForKey:kCIKey_Text] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		self.m_mygovURLTitle = [[plistDict objectForKey:kCIKey_MyGovURLTitle] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		
		NSString *urlStr = [plistDict objectForKey:kCIKey_MyGovURL];
		if ( [urlStr length] > 0 )
		{
			NSURL *url = [[NSURL alloc] initWithString:[urlStr stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding]];
			self.m_mygovURL = url;
			[url release];
		}
		
		self.m_webURLTitle = [[plistDict objectForKey:kCIKey_WebURLTitle] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
		
		urlStr = [plistDict objectForKey:kCIKey_WebURL];
		if ( [urlStr length] > 0 )
		{
			NSURL *url = [[NSURL alloc] initWithString:[urlStr stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding]];
			self.m_webURL = url;
			[url release];
		}
		
		// parse comments...
		NSArray *tmpArray = [plistDict objectForKey:kCIKey_Comments];
		NSEnumerator *objEnum = [tmpArray objectEnumerator];
		id obj;
		while ( obj = [objEnum nextObject] )
		{
			CommunityComment *comment = [[CommunityComment alloc] initWithPlistDict:obj];
			[self addComment:comment];
			[comment release];
		}
		
		// parse location
		NSString *tmpStr = [plistDict objectForKey:kCIKey_EventLocation];
		tmpArray = [tmpStr componentsSeparatedByString:@":"];
		if ( [tmpArray count] >= 2 )
		{
			CLLocation *tmploc = [[CLLocation alloc] initWithLatitude:[[tmpArray objectAtIndex:0] doubleValue] 
															longitude:[[tmpArray objectAtIndex:1] doubleValue]];
			self.m_eventLocation = tmploc;
			[tmploc release];
			
			m_eventLocDescrip = nil;
			if ( [tmpArray count] > 2 )
			{
				// the last element is the description
				self.m_eventLocDescrip = [[tmpArray objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
			}
		}
		else
		{
			m_eventLocation = nil;
			m_eventLocDescrip = nil;
		}
		
		/*
		tmpDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[[plistDict objectForKey:kCIKey_EventDate] integerValue]];
		self.m_eventDate = tmpDate;
		[tmpDate release];
		*/
		dateStr = [plistDict objectForKey:kCIKey_EventDate];
		if ( nil == dateStr )
		{
			self.m_eventDate = nil;
		}
		else
		{
			dotRange = [dateStr rangeOfString:@"."];
			if ( dotRange.location > 0 && dotRange.length == 1 )
			{
				dateStr = [dateStr substringToIndex:dotRange.location];
			}
			self.m_eventDate = [dateFmt dateFromString:dateStr];
		}
		
		tmpArray = [plistDict objectForKey:kCIKey_EventAttendees];
		objEnum = [tmpArray objectEnumerator];
		while ( obj = [objEnum nextObject] )
		{
			NSString *attendingUser = (NSString *)obj;
			[self addEventAttendee:attendingUser];
		}
		
		// 
		// Make sure we have a summary here
		// 
		if ( nil == m_summary || [m_summary length] < 1 )
		{
			if ( [m_text length] < 120 )
			{
				self.m_summary = m_text;
			}
			else
			{
				self.m_summary = [[m_text substringToIndex:117] stringByAppendingString:@"..."];
			}
		}
		
		//NSLog( @"  initialized %@: '%@'", m_id, m_title );
	}
}


@end
