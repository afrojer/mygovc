//
//  DataProviders.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import "myGovAppDelegate.h"
#import "DataProviders.h"
#import "CongressDataManager.h"
#import "LegislatorContainer.h"


@implementation DataProviders

// 
// API Keys
// 
static NSString *kOpenCongress_APIKey = @"32aea132a66093e9bf9ebe9fc2e2a4c66b888777";
static NSString *kSunlight_APIKey = @"345973d49743956706bb04030ee5713b";
//static NSString *kPVS_APIKey = @"e9c18da5999464958518614cfa7c6e1c";


// 
// OpenCongress.org 
// 
static NSString *kOpenCongress_BillsXMLFmt = @"http://www.opencongress.org/api/bills?key=%@&congress=%d";
static NSString *kOpenCongress_PersonXMLFmt = @"http://www.opencongress.org/api/people?key=%@&state=%@&first_name=%@&last_name=%@";

// 
// SunlightLabs 
// 
static NSString *kSunlight_getListXML = @"http://services.sunlightlabs.com/api/legislators.getList.xml";

// 
// govtrack.us
// 
static NSString *kGovtrack_dataDir = @"http://www.govtrack.us/data/us/";
static NSString *kGovtrack_committeeListXMLFmt = @"http://www.govtrack.us/data/us/%d/committees.xml";
static NSString *kGovtrack_latLongFmt = @"http://www.govtrack.us/perl/district-lookup.cgi?lat=%f&long=%f";

// 
// USASpending.gov
// 
static NSString *kUSASpending_fpdsURL = @"http://www.usaspending.gov/fpds/fpds.php?database=fpds&reptype=r";

static NSString *kUSASpending_DataTypeXML = @"&datype=X";
static NSString *kUSASpending_DataTypeHTML = @"&datype=T";

static NSString *kUSASpending_DetailLevel_Summary = @"&detail=-1";
static NSString *kUSASpending_DetailLevel_Low = @"&detail=0";
static NSString *kUSASpending_DetailLevel_Medium = @"&detail=1";
static NSString *kUSASpending_DetailLevel_High = @"&detail=2";
static NSString *kUSASpending_DetailLevel_Complete = @"&detail=4";

static NSString *kUSASpending_SortByContractor = @"&sortby=r";
static NSString *kUSASpending_SortByDollars = @"&sortby=f";
static NSString *kUSASpending_SortByContractingAgency = @"&sortby=g";
static NSString *kUSASpending_SortByCategory = @"&sortby=p";
static NSString *kUSASpending_SortByDate = @"&sortby=d";

static NSString *kUSASpending_FiscalYearKey = @"&fiscal_year";
static NSString *kUSASpending_DistrictKey = @"&pop_cd2";
static NSString *kUSASpending_StateKey = @"&stateCode";
static NSString *kUSASpending_MaxRecordsKey = @"&max_records";
static NSString *kUSASpending_ContractorKey = @"&company_name";

static NSString *kUSASpending_SearchAppendKey = @"&mustrn=y";



+ (NSString *)OpenCongress_APIKey
{
	return kOpenCongress_APIKey;
}


+ (NSString *)OpenCongress_BillsURL
{
	NSString *urlStr = [[[NSString alloc] initWithFormat:kOpenCongress_BillsXMLFmt,
											kOpenCongress_APIKey,
											[[myGovAppDelegate sharedCongressData] currentCongressSession]
						] autorelease];
	return urlStr;
}


+ (NSString *)OpenCongress_PersonURL:(LegislatorContainer *)person
{
	NSString *urlStr = [[[NSString alloc] initWithFormat:kOpenCongress_PersonXMLFmt,
											kOpenCongress_APIKey,
											[person state],
											[person firstname],
											[person lastname]
						 ] autorelease];
	return urlStr;
}


+ (NSString *)SunlightLabs_APIKey
{
	return kSunlight_APIKey;
}


+ (NSString *)SunlightLabs_LegislatorListURL
{
	NSString *urlStr = [[[NSString alloc] initWithFormat:@"%@?apikey=%@",
											kSunlight_getListXML,
											kSunlight_APIKey
						] autorelease];
	return urlStr;
}


+ (NSString *)Govtrack_DataDirURL
{
	return kGovtrack_dataDir;
}


+ (NSString *)Govtrack_CommitteeURL:(NSInteger)congressSession
{
	NSString *urlStr = [[[NSString alloc] initWithFormat:kGovtrack_committeeListXMLFmt,
											congressSession
						] autorelease];
	return urlStr;
}


+ (NSString *)Govtrack_DistrictURLFromLocation:(CLLocation *)latLong
{
	NSString *urlStr = [[[NSString alloc] initWithFormat:kGovtrack_latLongFmt,
											latLong.coordinate.latitude,
											latLong.coordinate.longitude
						] autorelease];
	return urlStr;
}

+ (NSString *)USASpending_fpdsURL
{
	return kUSASpending_fpdsURL;
}


+ (NSString *)USASpending_districtURL:(NSString *)district 
							  forYear:(NSInteger)year 
						   withDetail:(SpendingDetail)detail 
							 sortedBy:(SpendingSortMethod)order 
							   xmlURL:(BOOL)xmldata
{
	NSString *sortStr;
	switch ( order )
	{
		case eSpendingSortDate:
			sortStr = kUSASpending_SortByDate;
			break;
		case eSpendingSortAgency:
			sortStr = kUSASpending_SortByContractingAgency;
			break;
		case eSpendingSortContractor:
			sortStr = kUSASpending_SortByContractor;
			break;
		case eSpendingSortCategory:
			sortStr = kUSASpending_SortByCategory;
			break;
		default:
		case eSpendingSortDollars:
			sortStr = kUSASpending_SortByDollars;
			break;
	}
	
	NSString *detailStr;
	switch ( detail )
	{
		default:
		case eSpendingDetailSummary:
			detailStr = kUSASpending_DetailLevel_Summary;
			break;
		case eSpendingDetailLow:
			detailStr = kUSASpending_DetailLevel_Low;
			break;
		case eSpendingDetailMed:
			detailStr = kUSASpending_DetailLevel_Medium;
			break;
		case eSpendingDetailHigh:
			detailStr = kUSASpending_DetailLevel_High;
			break;
		case eSpendingDetailComplete:
			detailStr = kUSASpending_DetailLevel_Complete;
			break;
	}
	
	NSMutableString *urlStr = [[[NSMutableString alloc] initWithString:kUSASpending_fpdsURL] autorelease];
	[urlStr appendFormat:@"%@%@=%@%@=%0d%@%@",
							(xmldata ? kUSASpending_DataTypeXML : kUSASpending_DataTypeHTML),
							kUSASpending_DistrictKey,district,
							kUSASpending_FiscalYearKey,year,
							sortStr,
							detailStr
	];
	return (NSString *)urlStr;
}


+ (NSString *)USASpending_stateURL:(NSString *)state 
						   forYear:(NSInteger)year 
						withDetail:(SpendingDetail)detail 
						  sortedBy:(SpendingSortMethod)order 
							xmlURL:(BOOL)xmldata
{
	NSString *sortStr;
	switch ( order )
	{
		case eSpendingSortDate:
			sortStr = kUSASpending_SortByDate;
			break;
		case eSpendingSortAgency:
			sortStr = kUSASpending_SortByContractingAgency;
			break;
		case eSpendingSortContractor:
			sortStr = kUSASpending_SortByContractor;
			break;
		case eSpendingSortCategory:
			sortStr = kUSASpending_SortByCategory;
			break;
		default:
		case eSpendingSortDollars:
			sortStr = kUSASpending_SortByDollars;
			break;
	}
	
	NSString *detailStr;
	switch ( detail )
	{
		default:
		case eSpendingDetailSummary:
			detailStr = kUSASpending_DetailLevel_Summary;
			break;
		case eSpendingDetailLow:
			detailStr = kUSASpending_DetailLevel_Low;
			break;
		case eSpendingDetailMed:
			detailStr = kUSASpending_DetailLevel_Medium;
			break;
		case eSpendingDetailHigh:
			detailStr = kUSASpending_DetailLevel_High;
			break;
		case eSpendingDetailComplete:
			detailStr = kUSASpending_DetailLevel_Complete;
			break;
	}
	
	NSMutableString *urlStr = [[[NSMutableString alloc] initWithString:kUSASpending_fpdsURL] autorelease];
	[urlStr appendFormat:@"%@%@=%@%@=%0d%@%@",
							(xmldata ? kUSASpending_DataTypeXML : kUSASpending_DataTypeHTML),
							kUSASpending_StateKey,state,
							kUSASpending_FiscalYearKey,year,
							sortStr,
							detailStr
	];
	return (NSString *)urlStr;
}


+ (NSString *)USASpending_topContractorURL:(NSInteger)year 
						 maxNumContractors:(NSInteger)maxRecords 
								withDetail:(SpendingDetail)detail 
								  sortedBy:(SpendingSortMethod)order 
									xmlURL:(BOOL)xmldata
{
	NSString *sortStr;
	switch ( order )
	{
		case eSpendingSortDate:
			sortStr = kUSASpending_SortByDate;
			break;
		case eSpendingSortAgency:
			sortStr = kUSASpending_SortByContractingAgency;
			break;
		case eSpendingSortContractor:
			sortStr = kUSASpending_SortByContractor;
			break;
		case eSpendingSortCategory:
			sortStr = kUSASpending_SortByCategory;
			break;
		default:
		case eSpendingSortDollars:
			sortStr = kUSASpending_SortByDollars;
			break;
	}
	
	NSString *detailStr;
	switch ( detail )
	{
		default:
		case eSpendingDetailSummary:
			detailStr = kUSASpending_DetailLevel_Summary;
			break;
		case eSpendingDetailLow:
			detailStr = kUSASpending_DetailLevel_Low;
			break;
		case eSpendingDetailMed:
			detailStr = kUSASpending_DetailLevel_Medium;
			break;
		case eSpendingDetailHigh:
			detailStr = kUSASpending_DetailLevel_High;
			break;
		case eSpendingDetailComplete:
			detailStr = kUSASpending_DetailLevel_Complete;
			break;
	}
	
	NSMutableString *urlStr = [[[NSMutableString alloc] initWithString:kUSASpending_fpdsURL] autorelease];
	[urlStr appendFormat:@"%@%@=%0d%@=%0d%@%@",
							(xmldata ? kUSASpending_DataTypeXML : kUSASpending_DataTypeHTML),
							kUSASpending_MaxRecordsKey,maxRecords,
							kUSASpending_FiscalYearKey,year,
							detailStr,
							sortStr
	];
	return (NSString *)urlStr;
}


+ (NSString *)USASpending_contractorSearchURL:(NSString *)companyName 
									  forYear:(NSInteger)year 
								   withDetail:(SpendingDetail)detail 
									 sortedBy:(SpendingSortMethod)order 
									   xmlURL:(BOOL)xmldata
{
	NSString *sortStr;
	switch ( order )
	{
		case eSpendingSortDate:
			sortStr = kUSASpending_SortByDate;
			break;
		case eSpendingSortAgency:
			sortStr = kUSASpending_SortByContractingAgency;
			break;
		case eSpendingSortContractor:
			sortStr = kUSASpending_SortByContractor;
			break;
		case eSpendingSortCategory:
			sortStr = kUSASpending_SortByCategory;
			break;
		default:
		case eSpendingSortDollars:
			sortStr = kUSASpending_SortByDollars;
			break;
	}
	
	NSString *detailStr;
	switch ( detail )
	{
		default:
		case eSpendingDetailSummary:
			detailStr = kUSASpending_DetailLevel_Summary;
			break;
		case eSpendingDetailLow:
			detailStr = kUSASpending_DetailLevel_Low;
			break;
		case eSpendingDetailMed:
			detailStr = kUSASpending_DetailLevel_Medium;
			break;
		case eSpendingDetailHigh:
			detailStr = kUSASpending_DetailLevel_High;
			break;
		case eSpendingDetailComplete:
			detailStr = kUSASpending_DetailLevel_Complete;
			break;
	}
	
	NSMutableString *urlStr = [[[NSMutableString alloc] initWithString:kUSASpending_fpdsURL] autorelease];
	[urlStr appendFormat:@"%@%@=%0d%@=%@%@%@%@",
				(xmldata ? kUSASpending_DataTypeXML : kUSASpending_DataTypeHTML),
				kUSASpending_FiscalYearKey,year,
				kUSASpending_ContractorKey,[companyName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
				detailStr,
				kUSASpending_SearchAppendKey,
				sortStr
	 ];
	return (NSString *)urlStr;
}


@end
