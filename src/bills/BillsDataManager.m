//
//  BillsDataManager.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "myGovAppDelegate.h"
#import "DataProviders.h"

#import "BillContainer.h"
#import "BillsDataManager.h"
#import "BillSummaryXMLParser.h"
#import "CongressDataManager.h"
#import "XMLParserOperation.h"


@interface BillsDataManager (private)
	- (void)beginBillSummaryDownload;
	- (void)writeBillDataDataToCache:(id)sender;
	- (void)readBillDataFromCache:(id)sender;
	- (void)setStatus:(NSString *)status;
	- (void)addNewBill:(BillContainer *)bill;
	- (void)clearData;
@end



@implementation BillsDataManager

@synthesize isDataAvailable;
@synthesize isBusy;

+ (NSString *)dataCachePath
{
	NSString *congressDataPath = [[myGovAppDelegate sharedAppCacheDir] stringByAppendingPathComponent:@"bills"];
	return congressDataPath;
}


+ (NSString *)billDataCacheFile
{
	NSString *dataPath = [[BillsDataManager dataCachePath] stringByAppendingPathComponent:@"data"];
	NSString *billDataPath = [dataPath stringByAppendingPathComponent:@"bills.cache"];
	return billDataPath;
}


- (id)init
{
	if ( self = [super init] )
	{
		isDataAvailable = NO;
		isBusy = NO;
		
		m_currentStatusMessage = [[NSMutableString alloc] init];
		
		m_notifyTarget = nil;
		m_notifySelector = nil;
		
		// initialize data arrays...
		m_houseSections = [[NSMutableArray alloc] initWithCapacity:12];
		m_houseBills = [[NSMutableDictionary alloc] initWithCapacity:12];
		m_senateSections = [[NSMutableArray alloc] initWithCapacity:12];
		m_senateBills = [[NSMutableDictionary alloc] initWithCapacity:12];
		
		m_xmlParser = nil;
		m_timer = nil;
	}
	return self;
}


- (void)dealloc
{
	isDataAvailable = NO;
	isBusy = NO;
	
	[m_xmlParser abort];
	[m_xmlParser release];
	
	[m_notifyTarget release];
	[m_houseSections release];
	[m_houseBills release];
	[m_senateSections release];
	[m_senateBills release];
	
	[m_currentStatusMessage release];
	[super dealloc];
}


- (void)setNotifyTarget:(id)target withSelector:(SEL)sel
{
	[m_notifyTarget release];
	m_notifyTarget = [target retain];
	m_notifySelector = sel;
}


- (NSString *)currentStatusMessage
{
	return m_currentStatusMessage;
}


- (void)loadData
{
	NSString *cachePath = [BillsDataManager billDataCacheFile];
	NSString *dataPath = [[BillsDataManager dataCachePath] stringByAppendingPathComponent:@"data"];
	
	BOOL shouldReDownload = NO;
	
	// check to see if we should re-load the data!
	NSString *shouldReload = [[NSUserDefaults standardUserDefaults] objectForKey:@"mygov_autoreload_bills"];
	if ( [shouldReload isEqualToString:@"YES"] )
	{
		// the user wants us to auto-update:
		// do so once every day
		
		NSString *lastUpdatePath = [dataPath stringByAppendingPathComponent:@"lastUpdate"];
		NSString *lastUpdate = [NSString stringWithContentsOfFile:lastUpdatePath];
		CGFloat updateTimeInterval = [lastUpdate floatValue];
		CGFloat now = (CGFloat)[[NSDate date] timeIntervalSinceReferenceDate];
		if ( (now - updateTimeInterval) > 86400 ) // this will still be true if the file wasn't found :-)
		{
			shouldReDownload = YES;
		}
	}
	
	if ( shouldReDownload || ![[NSFileManager defaultManager] fileExistsAtPath:cachePath] )
	{
		// we need to start a data download!
		[self beginBillSummaryDownload];
	}
	else
	{
		// data is available - read disk data into memory (via a worker thread)
		NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
																			selector:@selector(readBillDataFromCache:) 
																			  object:self];
		
		// Add the operation to the internal operation queue managed by the application delegate.
		[[[myGovAppDelegate sharedAppDelegate] m_operationQueue] addOperation:theOp];
		
		[theOp release];
	}
}


- (void)loadDataByDownload
{
	[self clearData];
	[self beginBillSummaryDownload];
}


- (NSInteger)totalBills
{
	return ([self houseBills] + [self senateBills]);
}


- (NSInteger)houseBills
{
	NSInteger numBills = 0;
	
	NSEnumerator *henum = [m_houseBills objectEnumerator];
	id obj;
	while ( obj = [henum nextObject] )
	{
		numBills += [obj count];
	}
	
	return numBills;
}


- (NSInteger)houseBillSections
{
	return [m_houseSections count];
}


- (NSInteger)houseBillsInSection:(NSInteger)section
{
	if ( section >= [m_houseSections count] ) return 0;
	return [[m_houseBills objectForKey:[m_houseSections objectAtIndex:section]] count];
}


- (NSString *)houseSectionTitle:(NSInteger)section
{
	if ( section >= [m_houseSections count] ) return nil;
	
	NSNumber *key = [m_houseSections objectAtIndex:section];
	NSInteger year = 3000 - ([key integerValue] >> 5);
	NSInteger month = 12 - ([key integerValue] & 0x1F);
	{
		// return the name of the month in which these 
		// bills were last acted upon
		
		NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
		
		NSString *title = [NSString stringWithFormat:@"%@ %4d",
										[[dateFmt monthSymbols] objectAtIndex:(month-1)],
										year
						   ];
		return title;
	}
}


- (BillContainer *)houseBillAtIndexPath:(NSIndexPath *)indexPath
{
	if ( indexPath.section >= [m_houseSections count] ) return nil;
	
	NSArray *monthBills = [m_houseBills objectForKey:[m_houseSections objectAtIndex:indexPath.section]];
	if ( indexPath.row >= [monthBills count] ) return nil;
	
	return [monthBills objectAtIndex:indexPath.row];
}


- (NSInteger)senateBills
{
	NSInteger numBills = 0;
	
	NSEnumerator *henum = [m_senateBills objectEnumerator];
	id obj;
	while ( obj = [henum nextObject] )
	{
		numBills += [obj count];
	}
	
	return numBills;
}


- (NSInteger)senateBillSections
{
	return [m_senateSections count];
}


- (NSInteger)senateBillsInSection:(NSInteger)section
{
	if ( section >= [m_senateSections count] ) return 0;
	return [[m_senateBills objectForKey:[m_senateSections objectAtIndex:section]] count];
}


- (NSString *)senateSectionTitle:(NSInteger)section
{
	if ( section >= [m_senateSections count] ) return nil;
	
	NSNumber *key = [m_senateSections objectAtIndex:section];
	NSInteger year = 3000 - ([key integerValue] >> 5);
	NSInteger month = 12 - ([key integerValue] & 0x1F);
	{
		// return the name of the month in which these 
		// bills were last acted upon
		
		NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
		
		NSString *title = [NSString stringWithFormat:@"%@ %4d",
						   [[dateFmt monthSymbols] objectAtIndex:(month-1)],
						   year
						   ];
		return title;
	}
}


- (BillContainer *)senateBillAtIndexPath:(NSIndexPath *)indexPath
{
	if ( indexPath.section >= [m_senateSections count] ) return nil;
	
	NSArray *monthBills = [m_senateBills objectForKey:[m_senateSections objectAtIndex:indexPath.section]];
	if ( indexPath.row >= [monthBills count] ) return nil;
	
	return [monthBills objectAtIndex:indexPath.row];
}


#pragma BillsDataManager Private 


- (void)beginBillSummaryDownload
{
	isDataAvailable = NO;
	isBusy = YES;
	
	// make sure we have congress data before downloading bill data - 
	// this ensures that we grab the right congressional session!
	if ( ![[myGovAppDelegate sharedCongressData] isDataAvailable] )
	{
		[self setStatus:@"Waiting for congress data..."];
		
		// start a timer that will periodically check to see if
		// congressional data is ready... no this is not the most
		// efficient way of doing this...
		if ( nil == m_timer )
		{
			m_timer = [NSTimer timerWithTimeInterval:0.75 target:self selector:@selector(timerFireMethod:) userInfo:nil repeats:YES];
			[[NSRunLoop mainRunLoop] addTimer:m_timer forMode:NSDefaultRunLoopMode];
		}
		return;
	}
	
	[self setStatus:@"Preparing Bill Download..."];
	
	NSString *xmlURL = [DataProviders OpenCongress_BillsURL];
	
	if ( nil != m_xmlParser )
	{
		// abort any previous attempt at parsing/downloading
		[m_xmlParser abort];
	}
	else
	{
		m_xmlParser = [[XMLParserOperation alloc] initWithOpDelegate:self];
	}
	m_xmlParser.m_opDelegate = self;
	
	BillSummaryXMLParser *bsxp = [[BillSummaryXMLParser alloc] initWithBillsData:self];
	[bsxp setNotifyTarget:m_notifyTarget andSelector:m_notifySelector];
	
	[m_xmlParser parseXML:[NSURL URLWithString:xmlURL] withParserDelegate:bsxp];
	[bsxp release];
}


- (void)writeBillDataDataToCache:(id)sender
{	
	NSString *dataPath = [[BillsDataManager dataCachePath] stringByAppendingPathComponent:@"data"];
	
	// make sure the directoy exists!
	[[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
	NSString *billDataPath = [BillsDataManager billDataCacheFile]; 
	NSLog( @"BillsDataManager: writing bill cache to: %@",billDataPath );
	
	NSMutableArray *billData = [[NSMutableArray alloc] initWithCapacity:([m_houseBills count] + [m_senateBills count])];
	
	// gather house bill data
	NSEnumerator *e = [m_houseBills objectEnumerator];
	id monthArray;
	while ( monthArray = [e nextObject] )
	{
		NSEnumerator *me = [monthArray objectEnumerator];
		id bc;
		while ( bc = [me nextObject] )
		{
			NSDictionary *billDict = [bc getBillDictionaryForCache];
			[billData addObject:billDict];
		}
	}
	
	// Gather senate bill data
	e = [m_senateBills objectEnumerator];
	while ( monthArray = [e nextObject] )
	{
		NSEnumerator *me = [monthArray objectEnumerator];
		id bc;
		while ( bc = [me nextObject] )
		{
			NSDictionary *billDict = [bc getBillDictionaryForCache];
			[billData addObject:billDict];
		}
	}
	
	BOOL success = [billData writeToFile:billDataPath atomically:YES];
	if ( !success )
	{
		NSLog( @"BillsDataManager: error writing bill data to cache!" );
	}
	else
	{
		// write out the current date to a file to indicate the last time
		// we updated this database
		NSString *lastUpdatePath = [dataPath stringByAppendingPathComponent:@"lastUpdate"];
		NSString *lastUpdate = [NSString stringWithFormat:@"%0f",[[NSDate date] timeIntervalSinceReferenceDate]];
		success = [lastUpdate writeToFile:lastUpdatePath atomically:YES encoding:NSMacOSRomanStringEncoding error:NULL];
	}
	
	// not busy any more!
	isBusy = NO;
}


- (void)readBillDataFromCache:(id)sender
{
	if ( isBusy ) return;
	
	// we're in a worker thread, so we can block like this:
	// wait until the congressional data loads!
	while ( ![[myGovAppDelegate sharedCongressData] isDataAvailable] )
	{
		[NSThread sleepForTimeInterval:0.5f];
	}
	
	isBusy = YES;
	[self setStatus:@"Reading Cached Bills..."];
	
	NSString *billDataPath = [BillsDataManager billDataCacheFile];
	NSLog( @"BillsDataManager: reading bill cache from: %@", billDataPath );
	
	NSArray *billData = [NSArray arrayWithContentsOfFile:billDataPath];
	if ( nil == billData )
	{
		NSLog( @"BillsDataManager: error reading cached data from file: starting re-download of data!" );
		isBusy = NO;
		isDataAvailable = NO;
		[self beginBillSummaryDownload];
		return;
	}
	
	// remove any current data 
	[self clearData];
	
	NSEnumerator *e = [billData objectEnumerator];
	id billDict;
	while ( billDict = [e nextObject] )
	{
		BillContainer *bc = [[BillContainer alloc] initWithDictionary:billDict];
		if ( nil != bc )
		{
			[self addNewBill:bc];
			[bc release];
		}
	}
	
	isBusy = NO;
	isDataAvailable = YES;
	
	[self setStatus:@"Finished."];
}


- (void)setStatus:(NSString *)status
{
	[m_currentStatusMessage setString:status];
	if ( nil != m_notifyTarget )
	{
		[m_notifyTarget performSelector:m_notifySelector withObject:m_currentStatusMessage];
	}
}


- (void)addNewBill:(BillContainer *)bill
{
	NSMutableDictionary *chamberDict;
	NSMutableArray *chamberSections;
	switch ( bill.m_type ) 
	{
		default:
		case eBillType_h:
		case eBillType_hj:
		case eBillType_hc:
		case eBillType_hr:
			chamberDict = m_houseBills;
			chamberSections = m_houseSections;
			break;
		case eBillType_s:
		case eBillType_sj:
		case eBillType_sc:
		case eBillType_sr:
			chamberDict = m_senateBills;
			chamberSections = m_senateSections;
			break;
	}
	
	NSInteger yearMonth = NSYearCalendarUnit | NSMonthCalendarUnit;
	NSDateComponents *keyComp = [[NSCalendar currentCalendar] components:yearMonth fromDate:[bill lastActionDate]];
	
	NSInteger keyVal = ((3000 - [keyComp year]) << 5) | ((12 - [keyComp month]) & 0x1F);
	NSNumber *key = [NSNumber numberWithInt:keyVal];
	NSMutableArray *monthArray = [chamberDict objectForKey:key];
	if ( nil == monthArray )
	{
		// This is a new month - add it to the dictionary, and update our section list
		monthArray = [[NSMutableArray alloc] initWithCapacity:20];
		[chamberDict setValue:monthArray forKey:(id)key];
		[chamberSections addObject:key];
		[chamberSections sortUsingSelector:@selector(compare:)];
	}
	else
	{
		[monthArray retain];
	}
	
	[monthArray addObject:bill];
	[monthArray sortUsingSelector:@selector(lastActionDateCompare:)];
	
	[monthArray release];
}


- (void)clearData
{
	[m_houseSections release];
	[m_houseBills release];
	[m_senateSections release];
	[m_senateBills release];
	
	m_houseSections = [[NSMutableArray alloc] initWithCapacity:12];
	m_houseBills = [[NSMutableDictionary alloc] initWithCapacity:12];
	m_senateSections = [[NSMutableArray alloc] initWithCapacity:12];
	m_senateBills = [[NSMutableDictionary alloc] initWithCapacity:12];
}


- (void)timerFireMethod:(NSTimer *)timer
{
	if ( timer != m_timer ) return;
	
	CongressDataManager *cdm = [myGovAppDelegate sharedCongressData];
	if ( (nil != cdm) && ([cdm isDataAvailable]) )
	{
		// stop this timer, and start downloading some spending data!
		[timer invalidate];
		m_timer = nil;
		
		[self beginBillSummaryDownload];
	}
}


#pragma mark XMLParserOperationDelegate Methods


- (void)xmlParseOpStarted:(XMLParserOperation *)parseOp
{
	[self setStatus:@"Downloading Bill Data..."];
	NSLog( @"BillsDataManager started XML download..." );
}


- (void)xmlParseOp:(XMLParserOperation *)parseOp endedWith:(BOOL)success
{
	isDataAvailable = success;
	
	[self setStatus:@"Finished."];
	
	NSLog( @"BillsDataManager XML parsing ended %@", (success ? @"successfully." : @" in failure!") );
	
	if ( isDataAvailable )
	{
		// archive the bill summary data !
		isBusy = YES; // we're writing the cache!
		
		// kick off the caching of this data
		NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
																	  selector:@selector(writeBillDataDataToCache:) object:self];
		
		// Add the operation to the internal operation queue managed by the application delegate.
		[[[myGovAppDelegate sharedAppDelegate] m_operationQueue] addOperation:theOp];
		
		[theOp release];
	}
	else
	{
		isBusy = NO;
	}
	
}


@end
