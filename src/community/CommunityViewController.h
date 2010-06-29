/*
 File: CommunityViewController.h
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

#import <UIKit/UIKit.h>
#import "CommunityItem.h"

@class CommunityDataManager;
@class ProgressOverlayViewController;


@interface CommunityViewController : UITableViewController <UIAlertViewDelegate, UIActionSheetDelegate, UISearchBarDelegate>
{
@private
	CommunityDataManager *m_data;
	
	UISegmentedControl *m_segmentCtrl;
	CommunityItemType   m_selectedItemType;
	
	ProgressOverlayViewController *m_HUD;
	
	UITabBarItem *m_tbarItem;
	NSTimer *m_timer;
	int m_alertViewFunction;
}

- (void)showCommunityDetail:(id)sender;

- (NSString *)areaName;
- (NSString *)getURLStateParms;
- (void)handleURLParms:(NSString *)parms;

- (IBAction)reloadCommunityItems;
- (IBAction)composeNewCommunityItem;

@end
