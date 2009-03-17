//
//  LegislatorContainer.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/2/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import "myGovAppDelegate.h"
#import "LegislatorContainer.h"
#import "CongressDataManager.h"

@interface LegislatorContainer (private)
	- (void)downloadImage:(id)sender;
@end


@implementation LegislatorContainer

static NSString * kField_Title = @"title";
static NSString * kField_FirstName = @"firstname";
static NSString * kField_MiddleName = @"middlename";
static NSString * kField_LastName = @"lastname";
static NSString * kField_NameSuffix = @"name_suffix";
static NSString * kField_Nickname = @"nickname";
static NSString * kField_Party = @"party";
static NSString * kField_State = @"state";
static NSString * kField_District = @"district";
static NSString * kField_InOffice = @"in_office";
static NSString * kField_Gender = @"gender";
static NSString * kField_Phone = @"phone";
static NSString * kField_Fax = @"fax";
static NSString * kField_Website = @"website";
static NSString * kField_Webform = @"webform";
static NSString * kField_Email = @"email";
static NSString * kField_CongressOffice = @"congress_office";
static NSString * kField_BioguideID = @"bioguide_id";
static NSString * kField_VotesmartID = @"votesmart_id";
static NSString * kField_FECID = @"fec_id";
static NSString * kField_GovetrackID = @"govtrack_id";
static NSString * kField_CRPID = @"crp_id";
static NSString * kField_EventfulID = @"eventful_id";
static NSString * kField_CongresspediaURL = @"congresspedia_url";
static NSString * kField_TwitterID = @"twitter_id";
static NSString * kField_YoutubeURL = @"youtube_url";


- (id)init
{
	if ( self = [super init] )
	{
		// initially allocate enough memory for 27 items
		// (the max number of keys provided by sunlightlabs.com)
		m_info = [[NSMutableDictionary alloc] initWithCapacity:27];
		m_filePath = nil;
		m_downloadInProgress = NO;
	}
	
	return self;
}


- (void)dealloc
{
	[m_info release];
	[m_filePath release];
	[super dealloc];
}


// used by parsers (not for general use...)
-(void)addKey:(NSString *)field withValue:(NSString *)value
{
	[m_info setValue:value forKey:field];
}


- (id)initFromFile:(NSString *)path
{
	if ( self = [super init] )
	{
		m_downloadInProgress = NO;
		m_filePath = [path retain];
		m_info = [[NSMutableDictionary alloc] initWithContentsOfFile:m_filePath];
	}
	return self;
}


- (void)writeRecordToFile:(NSString *)path
{
	if ( m_info )
	{
		[m_info writeToFile:path atomically:YES];
	}
}


- (NSComparisonResult)districtCompare:(LegislatorContainer *)aLegislator
{
	NSInteger aDist  = [[aLegislator district] integerValue];
	NSInteger myDist = [[self district] integerValue];
	if ( myDist < aDist ) return NSOrderedAscending;
	if ( myDist > aDist ) return NSOrderedDescending;
	return NSOrderedSame;
}



- (NSString *)title
{
	return [m_info objectForKey:kField_Title];
}

- (NSString *)firstname
{
	return [m_info objectForKey:kField_FirstName];
}

- (NSString *)middlename
{
	return [m_info objectForKey:kField_MiddleName];
}

- (NSString *)lastname
{
	return [m_info objectForKey:kField_LastName];
}

- (NSString *)name_suffix
{
	return [m_info objectForKey:kField_NameSuffix];
}

- (NSString *)nickname
{
	return [m_info objectForKey:kField_Nickname];
}

- (NSString *)party
{
	return [m_info objectForKey:kField_Party];
}

- (NSString *)state
{
	return [m_info objectForKey:kField_State];
}

- (NSString *)district
{
	return [m_info objectForKey:kField_District];
}

- (NSString *)in_office
{
	return [m_info objectForKey:kField_InOffice];
}

- (NSString *)gender
{
	return [m_info objectForKey:kField_Gender];
}

- (NSString *)phone
{
	return [m_info objectForKey:kField_Phone];
}

- (NSString *)fax
{
	return [m_info objectForKey:kField_Fax];
}

- (NSString *)website
{
	return [m_info objectForKey:kField_Website];
}

- (NSString *)webform
{
	return [m_info objectForKey:kField_Webform];
}

- (NSString *)email
{
	return [m_info objectForKey:kField_Email];
}

- (NSString *)congress_office
{
	return [m_info objectForKey:kField_CongressOffice];
}

- (NSString *)bioguide_id
{
	return [m_info objectForKey:kField_BioguideID];
}

- (NSString *)votesmart_id
{
	return [m_info objectForKey:kField_VotesmartID];
}

- (NSString *)fec_id
{
	return [m_info objectForKey:kField_FECID];
}

- (NSString *)govtrack_id
{
	return [m_info objectForKey:kField_GovetrackID];
}

- (NSString *)crp_id
{
	return [m_info objectForKey:kField_CRPID];
}

- (NSString *)eventful_id
{
	return [m_info objectForKey:kField_EventfulID];
}

- (NSString *)congresspedia_url
{
	return [m_info objectForKey:kField_CongresspediaURL];
}

- (NSString *)twitter_id
{
	return [m_info objectForKey:kField_TwitterID];
}

- (NSString *)youtube_url
{
	return [m_info objectForKey:kField_YoutubeURL];
}


- (NSString *)shortName
{
	NSString *nickname = [self nickname];
	NSString *fname = [self firstname];
	NSString *mname = ([nickname length] > 0 ? @"" : [self middlename]);
	NSString *lname = [self lastname];
	NSString *nm = [[[NSString alloc] initWithFormat:@"%@. %@ %@%@%@",
										[self title],
										([nickname length] > 0 ? nickname : fname),
										(mname ? mname : @""),
										(mname ? @" " : @""),lname
					] autorelease];
	return nm;
}


- (NSArray *)committee_data
{
	return [[myGovAppDelegate sharedCongressData] legislatorCommittees:self];
}


- (UIImage *)getImageAndBlock:(BOOL)blockUntilDownloaded withCallbackOrNil:(SEL)sel;
{
	m_imgSel = sel;
	
	// look for photo
	NSString *cache = [[CongressDataManager dataCachePath] stringByAppendingPathComponent:@"photos"];
	NSString *photoPath = [NSString stringWithFormat:@"%@/%@-100px.jpeg",cache,[self govtrack_id]];
	
	UIImage *img = nil;
	
	if ( [[NSFileManager defaultManager] fileExistsAtPath:photoPath] )
	{
		// return an image
		img = [[UIImage alloc] initWithContentsOfFile:photoPath];
		// a nil image will start a new download 
		// (replacing the possibly corrupt one)
	}
	
	if ( nil == img )
	{
		if ( !m_downloadInProgress )
		{
			m_downloadInProgress = YES;
			
			// start image download
			// data is available - read disk data into memory (via a worker thread)
			NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
												selector:@selector(downloadImage:) object:self];
		
			// Add the operation to the internal operation queue managed by the application delegate.
			[[[myGovAppDelegate sharedAppDelegate] m_operationQueue] addOperation:theOp];
			
			[theOp release];
		}
		
		if ( blockUntilDownloaded )
		{
			while ( m_downloadInProgress /* XXX - or timeout! */ )
			{
				[NSThread sleepForTimeInterval:0.1f];
			}
			// recurse!
			return [self getImageAndBlock:blockUntilDownloaded withCallbackOrNil:sel];
		}
	}
	
	return img;
}


- (void)setCallbackObject:(id)obj;
{
	[m_cbObj release];
	m_cbObj = [obj retain];
}


- (void)downloadImage:(id)sender
{
	// download the data
	NSString *photoName = [NSString stringWithFormat:@"%@-100px.jpeg",[self govtrack_id]];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.govtrack.us/data/photos/%@",photoName]];
	NSData *imgData = [NSData dataWithContentsOfURL:url];
	UIImage *img = [UIImage imageWithData:imgData];
	
	// save the data to disk
	NSString *cache = [[CongressDataManager dataCachePath] stringByAppendingPathComponent:@"photos"];
	NSString *photoPath = [cache stringByAppendingPathComponent:photoName];
	
	// don't check the return code - failure here should take care of itself...
	if ( nil != imgData )
	{
		[[NSFileManager defaultManager] createFileAtPath:photoPath contents:imgData attributes:nil];
	}
	
	if ( (nil != m_cbObj) && (nil != m_imgSel) )
	{
		[m_cbObj performSelector:m_imgSel withObject:(nil == imgData ? nil : img)];
	}
	
	m_downloadInProgress = NO;
}


@end
