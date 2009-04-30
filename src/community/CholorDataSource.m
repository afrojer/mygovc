//
//  CholorDataSource.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/29/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import "CholorDataSource.h"
#import "DataProviders.h"

@interface CholorDataSource (private)
	- (BOOL)validResponse:(NSString *)postResponse;
@end


@implementation CholorDataSource

+ (NSString *)postStringFromDictionary:(NSDictionary *)dict
{
	NSMutableString *postStr = [[[NSMutableString alloc] init] autorelease];
	
	NSEnumerator *keyEnum = [dict keyEnumerator];
	NSString *key;
	while ( key = [keyEnum nextObject] )
	{
		id obj = [dict objectForKey:key];
		NSString *valStr = nil;
		
		// NSString objects
		if ( [obj isKindOfClass:[NSString class]] )
		{
			valStr = (NSString *)obj;
		}
		// NSNumber objects
		else if ( [obj isKindOfClass:[NSNumber class]] )
		{
			valStr = [obj stringValue];
		}
		else if ( [obj isKindOfClass:[NSArray class]] )
		{
			// compile the array string
			if ( [obj count] > 0 )
			{
				NSMutableString *arrayStr = [[[NSMutableString alloc] init] autorelease];
				NSString *arrayAmp = @"";
				NSEnumerator *arrayEnum = [obj objectEnumerator];
				id arrayObj;
				while ( arrayObj = [arrayEnum nextObject] )
				{
					if ( [arrayObj isKindOfClass:[NSNumber class]] )
					{
						[arrayStr appendFormat:@"%@%@[]=%@",arrayAmp, key, [arrayObj stringValue]];
						arrayAmp = @"&"; // empty the first time through - set to ampersand when we need it!
					}
					else if ( [arrayObj isKindOfClass:[NSString class]] )
					{
						NSString *str = [arrayObj stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
						[arrayStr appendFormat:@"%@%@[]=%@", arrayAmp, key, str];
						arrayAmp = @"&"; // empty the first time through - set to ampersand when we need it!
					}
					//  - ignore this element: no nested arrays/dictionaries
				}
				
				if ( [arrayStr length] > 0 )
				{
					// XXX - do I need to [retain] this?!
					valStr = arrayStr;
					key = @""; // mash!
				}
			}
		}
		else
		{
			// no NSDictionary support!
			NSLog( @"Ignoring unsupported PList object '%@' in dictionary...", key );
		}
		
		if ( nil != valStr )
		{
			NSString *amp = @"";
			if ( 0 != [postStr length] )
			{
				amp = @"&";
			}
			if ( [key length] > 0 )
			{
				valStr = [valStr stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
				[postStr appendFormat:@"%@%@=%@", amp, key, valStr];
			}
			else
			{
				// just use the 'valStr' for arrays :-)
				[postStr appendString:valStr];
			}
		}
	}
	
	return postStr; //[postStr stringByAddingPercentEscapesUsingEncoding:NSMacOSRomanStringEncoding];
}


- (id)init
{
	if ( self = [super init] )
	{
		m_isBusy = NO;
	}
	return self;
}


- (void)dealloc
{
	[super dealloc];
}


- (BOOL)validateUsername:(NSString *)username 
			 andPassword:(NSString *)password
{
	// all users are valid :-)
	return TRUE;
}


- (BOOL)addNewUser:(MyGovUser *)newUser
	  withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	// oh, that was successful alright!
	return TRUE;
}


- (BOOL)downloadItemsOfType:(CommunityItemType)type 
			   notOlderThan:(NSDate *)startDate 
			   withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	NSURL *cholorURL = [NSURL URLWithString:[DataProviders Cholor_DownloadURLFor:type]];
	
	NSString *postStr = [NSString stringWithFormat:@"date=%0d",(NSInteger)[startDate timeIntervalSinceReferenceDate]];
	NSData *postData = [NSData dataWithBytes:[postStr UTF8String] length:[postStr length]];
	
	NSMutableURLRequest *theRequest = [[NSMutableURLRequest alloc] initWithURL:cholorURL];
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:postData];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
	[theRequest setTimeoutInterval:10.0f]; // 10 second timeout
	
	NSURLResponse *theResponse = nil;
	NSError *err = nil;
	NSData *retVal = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&err];
	
	[theRequest release];
	
	if ( nil == retVal ) return FALSE;
	
	NSString *errString = nil;
	NSPropertyListFormat plistFmt;
	NSArray *plistArray = [NSPropertyListSerialization propertyListFromData:retVal 
														   mutabilityOption:NSPropertyListImmutable 
																	 format:&plistFmt 
														   errorDescription:&errString];
	
	if ( [plistArray count] < 1 )
	{
		return FALSE;
	}
	
	// run through each array item, create a CommunityItem object
	// and let our delegate know about it!
	NSEnumerator *plEnum = [plistArray objectEnumerator];
	NSDictionary *objDict;
	while ( objDict = [plEnum nextObject] )
	{
		CommunityItem *item = [[[CommunityItem alloc] initFromPlistDictionary:objDict] autorelease];
		if ( nil != item )
		{
			[delegateOrNil communityDataSource:self newCommunityItemArrived:item];
		}
	}
	
	return TRUE;
}


- (BOOL)submitCommunityItem:(CommunityItem *)item 
			   withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	// create an NSURLRequest object from the community item
	// to perform a POST-style HTTP request
	NSURL *cholorURL = [NSURL URLWithString:[DataProviders Cholor_CommunityItemPOSTURL]];
	
	NSString *itemStr = [CholorDataSource postStringFromDictionary:[item writeItemToPlistDictionary]];
	NSData *itemAsPostData = [NSData dataWithBytes:[itemStr UTF8String] length:[itemStr length]];
	
	NSMutableURLRequest *theRequest = [[NSMutableURLRequest alloc] initWithURL:cholorURL];
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:itemAsPostData];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
	[theRequest setTimeoutInterval:10.0f]; // 10 second timeout
	
	NSURLResponse *theResponse = nil;
	NSError *err = nil;
	NSData *retVal = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&err];
	NSString *response = [[[NSString alloc] initWithData:retVal encoding:NSMacOSRomanStringEncoding] autorelease];
	
	[theRequest release];
	
	// check string response to indicate success / failure
	return [self validResponse:response];
}


- (BOOL)submitCommunityComment:(CommunityComment *)comment 
				  withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	// create an NSURLRequest object from the community comment
	// to perform a POST-style HTTP request
	NSURL *cholorURL = [NSURL URLWithString:[DataProviders Cholor_CommunityCommentPOSTURL]];
	
	NSString *itemStr = [CholorDataSource postStringFromDictionary:[comment writeToPlistDict]];
	NSData *itemAsPostData = [NSData dataWithBytes:[itemStr UTF8String] length:[itemStr length]];
	
	NSMutableURLRequest *theRequest = [[NSMutableURLRequest alloc] initWithURL:cholorURL];
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:itemAsPostData];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
	[theRequest setTimeoutInterval:10.0f]; // 10 second timeout
	
	NSURLResponse *theResponse = nil;
	NSError *err = nil;
	NSData *retVal = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&err];
	NSString *response = [[[NSString alloc] initWithData:retVal encoding:NSMacOSRomanStringEncoding] autorelease];
	
	[theRequest release];
	
	// check string response to indicate success / failure
	return [self validResponse:response];
}


- (BOOL)updateItemOfType:(CommunityItemType)type 
			  withItemID:(NSInteger)itemID 
			 andDelegate:(id<CommunityDataSourceDelegate>)delegatOrNil
{
	NSURL *cholorURL = [NSURL URLWithString:[DataProviders Cholor_DownloadURLFor:type]];
	
	NSString *postStr = [NSString stringWithFormat:@"date=%0d&id=%d",0,itemID];
	NSData *postData = [NSData dataWithBytes:[postStr UTF8String] length:[postStr length]];
	
	NSMutableURLRequest *theRequest = [[NSMutableURLRequest alloc] initWithURL:cholorURL];
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:postData];
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
	[theRequest setTimeoutInterval:10.0f]; // 10 second timeout
	
	NSURLResponse *theResponse = nil;
	NSError *err = nil;
	NSData *retVal = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&err];
	
	[theRequest release];
	
	if ( nil == retVal ) return FALSE;
	
	NSString *errString = nil;
	NSPropertyListFormat plistFmt;
	NSArray *plistArray = [NSPropertyListSerialization propertyListFromData:retVal 
														   mutabilityOption:NSPropertyListImmutable 
																	 format:&plistFmt 
														   errorDescription:&errString];
	
	if ( [plistArray count] < 1 )
	{
		return FALSE;
	}
	
	if ( [plistArray count] > 1 )
	{
		NSLog( @"More than 1 item was downloaded for update (this is a server issue)" );
	}
	
	// just grab the first (and hopefully only) item
	CommunityItem *item = [[CommunityItem alloc] initFromPlistDictionary:[plistArray objectAtIndex:0]];
	if ( nil != item )
	{
		[delegatOrNil communityDataSource:self newCommunityItemArrived:item];
		[item release];
	}
	
	return TRUE;
}


- (BOOL)searchForItemsWithType:(CommunityItemType)type 
			  usingQueryString:(NSString *)query 
				  withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	return FALSE;
}


- (BOOL)searchForItemsWithType:(CommunityItemType)type 
						nearBy:(CLLocation *)location 
				  withDelegate:(id<CommunityDataSourceDelegate>)delegateOrNil
{
	return FALSE;
}


#pragma mark CholorDataSource Private


- (BOOL)validResponse:(NSString *)postResponse
{
	// 
	// by looking for the success response in a more loose way
	// I can be more tolerent of server-side errors which produce 
	// warning output
	// 
	
	NSRange range = [postResponse rangeOfString:[DataProviders Cholor_CommunityItemPOSTSucess]];
	
	// we found the string if the length is greater than 0
	if ( range.length > 0 ) return TRUE;
	
	return FALSE;
}


@end
