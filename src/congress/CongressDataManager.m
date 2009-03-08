//
//  CongressDataManager.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import <Foundation/NSXMLParser.h>
#import "CongressDataManager.h"
#import "LegislatorContainer.h"
#import "XMLParserOperation.h"
#import "myGovAppDelegate.h"


@interface CongressDataManager (private)
	- (void)destroyDataCache;
	- (void)beginDataDownload;
	- (void)initFromDisk:(id)sender;
	- (NSString *)dataCachePath;
	- (void)addLegislatorToInMemoryCache:(id)legislator release:(BOOL)flag;
@end


@implementation CongressDataManager

@synthesize isDataAvailable;

static NSString *kSunlight_APIKey = @"345973d49743956706bb04030ee5713b";
static NSString *kPVS_APIKey = @"e9c18da5999464958518614cfa7c6e1c";
static NSString *kSunlight_getListXML = @"http://services.sunlightlabs.com/api/legislators.getList.xml";


- (id)init
{
	if ( self = [super init] )
	{
		isDataAvailable = NO;
		
		m_notifyTarget = nil;
		m_xmlParser = nil;
		
		// initialize states/house/senate arrays
		m_states = [[NSMutableArray alloc] initWithCapacity:50];
		m_house = [[NSMutableDictionary alloc] initWithCapacity:50];
		m_senate = [[NSMutableDictionary alloc] initWithCapacity:50];
		
		// check to see if we have congress data previously cached on this 
		// device - if we don't then we'll have to go fetch it!
		NSString *congressDataValidPath = [[self dataCachePath] stringByAppendingPathComponent:@"dataComplete"];
		if ( ![[NSFileManager defaultManager] fileExistsAtPath:congressDataValidPath] )
		{
			// we need to start a data download!
			[self beginDataDownload];
		}
		else
		{
			// data is available - read disk data into memory (via a worker thread)
			NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
																		  selector:@selector(initFromDisk:) object:self];
			
			// Add the operation to the internal operation queue managed by the application delegate.
			[[[myGovAppDelegate sharedAppDelegate] m_operationQueue] addOperation:theOp];
			
			[theOp release];
		}
	}
	return self;
}


- (void)dealloc
{
	isDataAvailable = NO;
	[m_states release];
	[m_house release];
	[m_senate release];
	[m_xmlParser release];
	if ( nil != m_notifyTarget ) [m_notifyTarget release];
	[super dealloc];
}


- (void)setNotifyTarget:(id)target withSelector:(SEL)sel
{
	m_notifyTarget = [target retain];
	m_notifySelector = sel;
}


- (NSArray *)states
{
	return (NSArray *)m_states;
}


- (NSArray *)houseMembersInState:(NSString *)state
{
	return (NSArray *)[m_house objectForKey:state];
}


- (NSArray *)senateMembersInState:(NSString *)state
{
	return (NSArray *)[m_senate objectForKey:state];
}


- (void)writeLegislatorDataToCache:(id)sender
{
	NSString *congressDataPath = [[self dataCachePath] stringByAppendingPathComponent:@"data"];
	
	// make sure the directoy exists!
	[[NSFileManager defaultManager] createDirectoryAtPath:congressDataPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	NSString *path;
	NSString *state;
	
	// write out representative data
	for ( state in m_house )
	{
		// make sure state directory exists!
		NSString *stateDir = [congressDataPath stringByAppendingPathComponent:state];
		[[NSFileManager defaultManager] createDirectoryAtPath:stateDir withIntermediateDirectories:YES attributes:nil error:NULL];
		
		NSArray *reps = [m_house objectForKey:state];
		for ( id legislator in reps )
		{
			// congress/data/[STATE]/r_[ID].cache
			path = [stateDir stringByAppendingPathComponent:[NSString stringWithFormat:@"r_%@.cache",[legislator votesmart_id]]];
			[legislator writeRecordToFile:path];
		}
	}
	
	// write out senate data
	for ( state in m_senate )
	{
		// make sure state directory exists!
		NSString *stateDir = [congressDataPath stringByAppendingPathComponent:state];
		[[NSFileManager defaultManager] createDirectoryAtPath:stateDir withIntermediateDirectories:YES attributes:nil error:NULL];
		
		NSArray *senators = [m_senate objectForKey:state];
		for ( id legislator in senators )
		{
			// congress/data/[STATE]/s_[ID].cache
			path = [stateDir stringByAppendingPathComponent:[NSString stringWithFormat:@"s_%@.cache",[legislator votesmart_id]]];
			[legislator writeRecordToFile:path];
		}
	}
	
	// create a file named 'dataComplete' to indicate we've
	// written out all of our congressional data
	path = [NSString stringWithFormat:@"%@Complete",congressDataPath];
	BOOL success = [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData dataWithBytes:"1" length:1] attributes:nil];
	if ( !success )
	{
		// XXX what to do?
	}
}


- (void)updateCongressData
{
	isDataAvailable = NO;
	
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Removing Cached Congress Data..."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	
	[self destroyDataCache];
	
	[m_states release];
	[m_house release];
	[m_senate release];
	m_states = [[NSMutableArray alloc] initWithCapacity:50];
	m_house = [[NSMutableDictionary alloc] initWithCapacity:50];
	m_senate = [[NSMutableDictionary alloc] initWithCapacity:50];
	
	[self beginDataDownload];
}


- (void)destroyDataCache
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:[self dataCachePath] error:NULL];
	// XXX - do something on failure ?!
}


- (void)beginDataDownload
{
	isDataAvailable = NO;
	
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Downloading Congress Data..."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	
	NSString *xmlURL = [[NSString alloc] initWithFormat:@"%@?apikey=%@",kSunlight_getListXML,kSunlight_APIKey];
	
	if ( nil != m_xmlParser )
	{
		[m_xmlParser abort];
	}
	else
	{
		m_xmlParser = [[XMLParserOperation alloc] initWithOpDelegate:self];
	}
	
	[m_xmlParser parseXML:[NSURL URLWithString:xmlURL] withParserDelegate:self];
}


- (void)initFromDisk:(id)sender
{
	isDataAvailable = NO;
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Reading cached data..."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	
	NSString *congressDataPath = [[self dataCachePath] stringByAppendingPathComponent:@"data"];
	
	// read data from /Library/Caches/congress/...
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:congressDataPath];
	NSString *file;
	BOOL isDir;
	while ( file = [dirEnum nextObject] ) 
	{
		if ( [[file pathExtension] isEqualToString: @"cache"] ) 
		{
			m_currentLegislator = [[LegislatorContainer alloc] initFromFile:[congressDataPath stringByAppendingPathComponent:file]];
			[self addLegislatorToInMemoryCache:m_currentLegislator release:YES];
		}
		else if ( [fileManager fileExistsAtPath:[congressDataPath stringByAppendingPathComponent:file] isDirectory:&isDir] && isDir )
		{
			// directory entries are state names :-)
			//file = [file lastPathComponent];
			if ( ![m_states containsObject:file] )
			{
				[m_states addObject:file];
			}
			[m_states sortUsingSelector:@selector(caseInsensitiveCompare:)];
		}
	}
	
	isDataAvailable = YES;
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Finished."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	else
	{
		NSLog( @"CongressDataManager cached data parsing complete." );
	}
}


- (NSString *)dataCachePath
{
	NSString *congressDataPath = [[myGovAppDelegate sharedAppCacheDir] stringByAppendingPathComponent:@"/congress"];
	return congressDataPath;
}


- (void)xmlParseOpStarted:(XMLParserOperation *)parseOp
{
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Downloading Congress Data..."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	NSLog( @"CongessDataManager started XML parsing..." );
}


- (void)xmlParseOp:(XMLParserOperation *)parseOp endedWith:(BOOL)success
{
	isDataAvailable = success;
	if ( nil != m_notifyTarget )
	{
		NSString *message = [[[NSString alloc] initWithString:@"Finished..."] autorelease];
		[m_notifyTarget performSelector:m_notifySelector withObject:message];
	}
	else
	{
		NSLog( @"CongressDataManager XML parsing ended %@", (success ? @"successfully." : @" in failure!") );
	}
	
	if ( isDataAvailable )
	{
		// kick off the caching of this data
		NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
																	  selector:@selector(writeLegislatorDataToCache:) object:self];
		
		// Add the operation to the internal operation queue managed by the application delegate.
		[[[myGovAppDelegate sharedAppDelegate] m_operationQueue] addOperation:theOp];
		
		[theOp release];
	}
}


static NSString *kName_Response = @"response";
static NSString *kName_Legislator = @"legislator";
static NSString *kName_State = @"state";
static NSString *kTitleValue_Senator = @"Sen";


- (void)addLegislatorToInMemoryCache:(id)legislator release:(BOOL)flag
{
	LegislatorContainer *lc = legislator;
	
	// add this legislator to an appropriate array
	NSMutableArray *stateArray;
	if ( [[lc title] isEqualToString:kTitleValue_Senator] )
	{
		stateArray = [m_senate objectForKey:[lc state]];
		if ( nil == stateArray ) 
		{
			stateArray = [[NSMutableArray alloc] initWithCapacity:2];
			[m_senate setValue:stateArray forKey:[lc state]];
		}
		else
		{
			[stateArray retain];
		}
	}
	else
	{
		stateArray = [m_house objectForKey:[lc state]];
		if ( nil == stateArray ) 
		{
			stateArray = [[NSMutableArray alloc] initWithCapacity:8];
			[m_house setValue:stateArray forKey:[lc state]];
		}
		else
		{
			[stateArray retain];
		}
	}
	[stateArray addObject:lc];
	[stateArray release];
	
	if ( flag ) [lc release];
}


#pragma mark XMLParser Delegate Methods


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *) qualifiedName attributes:(NSDictionary *)attributeDict 
{
	if ( [elementName isEqualToString:kName_Response] )
	{
		if ( nil != m_notifyTarget )
		{
			NSString *message = [[[NSString alloc] initWithString:@"Parsing data..."] autorelease];
			[m_notifyTarget performSelector:m_notifySelector withObject:message];
		}
	}
    else if ( [elementName isEqualToString:kName_Legislator] ) 
	{
		parsingLegislator = YES;
		
		// alloc a new Legislator 
		m_currentLegislator = [[LegislatorContainer alloc] init];
    } 
	else if ( parsingLegislator ) 
	{
		m_currentString = [[NSMutableString alloc] initWithString:@""];
        storingCharacters = YES;
    }
	else
	{
		storingCharacters = NO;
		parsingLegislator = NO;
	}
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
	storingCharacters = NO;
	if ( [elementName isEqualToString:kName_Legislator] ) 
	{
		parsingLegislator = NO;
		[self addLegislatorToInMemoryCache:m_currentLegislator release:YES];
	}
	else if ( parsingLegislator )
	{
		[m_currentLegislator addKey:elementName withValue:m_currentString];
		
		// Build a dynamic list of states :-)
		if ( [elementName isEqualToString:kName_State] )
		{
			if ( ![m_states containsObject:m_currentString] )
			{
				[m_states addObject:m_currentString];
				
				/*
				// Add this state to our house/senate state dictionaries
				if ( nil == [m_house objectForKey:m_currentString] )
				{
					[m_house setValue:[[NSMutableArray alloc] initWithCapacity:8] forKey:m_currentString];
				}
				if ( nil == [m_senate objectForKey:m_currentString] )
				{
					[m_senate setValue:[[NSMutableArray alloc] initWithCapacity:2] forKey:m_currentString];
				}
				*/
			}
			[m_states sortUsingSelector:@selector(caseInsensitiveCompare:)];
		}
		
		[m_currentString release];
	}
	else
	{
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
    if ( storingCharacters ) [m_currentString appendString:string];
}


// XXX - handle XML parse errors in some sort of graceful way...
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError 
{
	parsingLegislator = NO;
	storingCharacters = NO;
	[m_currentLegislator release];
	[m_currentString setString:@""];
}


- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validError 
{
	parsingLegislator = NO;
	storingCharacters = NO;
	[m_currentLegislator release];
	[m_currentString setString:@""];
}


/*
– (void)parserDidStartDocument:(NSXMLParser *)parser
{
}

– (void)parserDidEndDocument:(NSXMLParser *)parser
{
}


– (void)parser:(NSXMLParser *)parser didStartMappingPrefix:(NSString *)prefix toURI:(NSString *)namespaceURI
{
}

– (void)parser:(NSXMLParser *)parser didEndMappingPrefix:(NSString *)prefix
{
}

– (void)parser:(NSXMLParser *)parser resolveExternalEntityName:(NSString *)entityName systemID:(NSString *)systemID
{
}

– (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
}


– (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
}

– (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
}

– (void)parser:(NSXMLParser *)parser foundProcessingInstructionWithTarget:(NSString *)target data:(NSString *)data
{
}

– (void)parser:(NSXMLParser *)parser foundComment:(NSString *)comment
{
}

– (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
}
*/

@end
