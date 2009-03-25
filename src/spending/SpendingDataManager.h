//
//  SpendingDataManager.h
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/18/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PlaceSpendingData;


typedef enum
{
	eSpendingSortDate,
	eSpendingSortAgency,
	eSpendingSortContractor,
	eSpendingSortCategory,
	eSpendingSortDollars,
} SpendingSortMethod;


typedef enum
{
	eSpendingDetailSummary,
	eSpendingDetailLow,
	eSpendingDetailMed,
	eSpendingDetailHigh,
	eSpendingDetailComplete,
} SpendingDetail;

// 
// Top 100 Contractors for 2009:
// http://www.usaspending.gov/fpds/fpds.php?fiscal_year=2009&sortby=f&datype=T&reptype=r&database=fpds&detail=0&max_records=100
// 

@interface SpendingDataManager : NSObject 
{
	BOOL isDataAvailable;
	BOOL isBusy;
	
@private
	NSMutableDictionary *m_districtSpendingSummary;
	NSMutableDictionary *m_stateSpendingSummary;
	NSMutableDictionary *m_contractorSpendingSummary;
	
	NSOperationQueue *m_downloadOperations;
	NSTimer *m_timer;
	BOOL m_shouldStopDownloads;
	NSUInteger m_downloadsInFlight;
	
	id  m_notifyTarget;
	SEL m_notifySelector;
}

@property (readonly) BOOL isDataAvailable;
@property (readonly) BOOL isBusy;

+ (NSString *)dataCachePath;
+ (NSURL *)getURLForDistrict:(NSString *)district forYear:(NSInteger)year withDetail:(SpendingDetail)detail sortedBy:(SpendingSortMethod)order;
+ (NSURL *)getURLForState:(NSString *)state forYear:(NSInteger)year withDetail:(SpendingDetail)detail sortedBy:(SpendingSortMethod)order;


- (void)setNotifyTarget:(id)target withSelector:(SEL)sel;

- (void)cancelAllDownloads;

- (NSArray *)congressionalDistricts;
- (NSInteger)numDistrictsInState:(NSString *)state;

- (PlaceSpendingData *)getDistrictData:(NSString *)district andWaitForDownload:(BOOL)yesOrNo;
- (PlaceSpendingData *)getStateData:(NSString *)state andWaitForDownload:(BOOL)yesOrNo;

// -(ContractorSpendingData *)getContractorData:(NSString *)contractor andWaitForDownload:(BOOL)yesOrNo;

@end
