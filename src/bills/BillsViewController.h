//
//  BillsViewController.h
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CongressDataManager.h"

@class BillsDataManager;
@class ProgressOverlayViewController;


@interface BillsViewController : UITableViewController <UISearchBarDelegate, UIActionSheetDelegate, UIAlertViewDelegate>
{
@private
	BillsDataManager *m_data;
	BillsDataManager *m_shadowData;
	
	NSString *m_initialSearchString;
	NSIndexPath *m_initialIndexPath;
	NSString *m_initialBillID;
	
	UISegmentedControl *m_segmentCtrl;
	CongressChamber m_selectedChamber;
	
	NSString *m_HUDTxt;
	ProgressOverlayViewController *m_HUD;
}

- (NSString *)areaName;
- (void)handleURLParms:(NSString *)parms;

- (void)showBillDetail:(id)sender;

@end
