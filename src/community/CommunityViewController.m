/*
 File: CommunityViewController.m
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

#import "myGovAppDelegate.h"
#import "myGovCompileOptions.h"
#import "CommunityDataManager.h"
#import "CommunityDetailViewController.h"
#import "CommunityItem.h"
#import "CommunityItemTableCell.h"
#import "CommunityViewController.h"
#import "ComposeMessageViewController.h"
#import "MyGovUserData.h"
#import "ProgressOverlayViewController.h"


@interface CommunityViewController (private)
	- (void)dataManagerCallback:(NSString *)msg;
	- (void)communityItemTypeSwitch:(id)sender;
	- (void)deselectRow:(id)sender;
	- (void)setEditDoneButtonInNavBar;
	- (void)setReloadButtonInNavBar;
	- (void)setActivityViewInNavBar;
	- (void)finishEditing;
@end

enum
{
	eAlertType_General = 0,
	eAlertType_ReloadQuestion = 1,
	eAlertType_ChooseCommunityAction = 2,
};


@implementation CommunityViewController


- (void)dealloc 
{
	[m_data release];
	[m_HUD release];
	[super dealloc];
}


- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)viewDidLoad 
{
	[super viewDidLoad];
	
	m_data = [[myGovAppDelegate sharedCommunityData] retain];
	[m_data setNotifyTarget:self withSelector:@selector(dataManagerCallback:)];
	
	m_HUD = nil; // XXX - replace this view a UITableHeaderView that indicates status!
	/*
	m_HUD = [[ProgressOverlayViewController alloc] initWithWindow:self.tableView];
	[m_HUD show:NO];
	[m_HUD setText:[m_data currentStatusMessage] andIndicateProgress:YES];
	*/
	
	m_alertViewFunction = eAlertType_General;
	m_timer = nil;
	
	self.tableView.separatorColor = [UIColor blackColor];
	m_selectedItemType = eCommunity_Chatter;
	
/* Leave this off for now - maybe in the next release...
 
	// create a search bar which will be used as our table's header view
	UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
	searchBar.delegate = self;
	searchBar.prompt = @"";
	searchBar.placeholder = @"Search Chatter...";
	searchBar.autocorrectionType = UITextAutocorrectionTypeYes;
	searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	searchBar.barStyle = UIBarStyleBlackOpaque;
	searchBar.showsCancelButton = YES;
	
	self.tableView.tableHeaderView = searchBar;
	self.tableView.tableHeaderView.userInteractionEnabled = YES;
*/
	
	// Create a new segment control and place it in 
	// the NavigationController's title area
}


- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
	
	[m_data setNotifyTarget:self withSelector:@selector(dataManagerCallback:)];
	
	[self performSelector:@selector(deselectRow:) withObject:nil afterDelay:0.5f];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if ( ![m_data isDataAvailable] )
	{
		if ( ![m_data isBusy] )
		{
			[m_data loadData];
		}
		[m_HUD show:YES];
		[m_HUD setText:[m_data currentStatusMessage] andIndicateProgress:YES];
	}
	else
	{
		[m_HUD show:NO];
	}
	
	if ( nil != self.navigationController.tabBarItem.badgeValue )
	{	
		// start a timer which will set the badge value to nil
		if ( nil == m_timer )
		{
			m_timer = [NSTimer timerWithTimeInterval:3.1 target:self selector:@selector(timerFireMethod:) userInfo:nil repeats:NO];
			[[NSRunLoop mainRunLoop] addTimer:m_timer forMode:NSDefaultRunLoopMode];
		}
	}
	
	[self.tableView setNeedsDisplay];
}


- (void)viewWillDisappear:(BOOL)animated 
{
	[super viewWillDisappear:animated];
	
	if ( nil != m_timer )
	{
		[m_timer invalidate];
		m_timer = nil;
	}
}

/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	MYGOV_SHOULD_SUPPORT_ROTATION(toInterfaceOrientation);
}


- (void)showCommunityDetail:(id)sender
{
	UIButton *button = (UIButton *)sender;
	if ( nil == button ) return;
	
	CommunityItemTableCell *tcell = (CommunityItemTableCell *)[button superview];
	if ( nil == tcell ) return;
	
	// mark this item as non-new once the user has viewed it!
	[tcell m_item].m_uiStatus = eCommunityItem_Old;
	
	CommunityDetailViewController *cdView = [[CommunityDetailViewController alloc] init];
	[cdView setItem:[tcell m_item]];
	[self.navigationController pushViewController:cdView animated:YES];
	[cdView release];
	
	[self.tableView reloadData];
}


- (NSString *)areaName
{
	return @"community";
}


- (NSString *)getURLStateParms
{
	return @"";
}


- (void)handleURLParms:(NSString *)parms
{
}


#pragma mark CommunityViewController Private


- (void)dataManagerCallback:(NSString *)msg
{
	NSRange endTypeRange = {0, 3};
	NSRange msgTypeRange = {0, 5};
	if ( [msg length] >= msgTypeRange.length &&
		 NSOrderedSame == [msg compare:@"ERR: " options:NSCaseInsensitiveSearch range:msgTypeRange] )
	{
		// pop up an alert dialog to let the user know that an error has occurred!
		NSString *errMsg = ([msg length] > msgTypeRange.length) ? [msg substringFromIndex:msgTypeRange.length-1] : @"Unknown Error";
		m_alertViewFunction = eAlertType_General;
		UIAlertView *alert = [[UIAlertView alloc] 
										initWithTitle:@"Community Data Error"
											  message:errMsg
											 delegate:self
									cancelButtonTitle:nil
									otherButtonTitles:@"OK",nil];
		[alert show];
		if ( ![self isEditing] )
		{
			[self setReloadButtonInNavBar];
		}
	}
	else if ( [m_data isDataAvailable] ||
			  ([msg length] >= endTypeRange.length && NSOrderedSame == [msg compare:@"END" options:NSCaseInsensitiveSearch range:endTypeRange])
			 )
	{
		[m_HUD show:NO];
		[self.tableView setUserInteractionEnabled:YES];
		
		if ( ![self isEditing] )
		{
			[self.tableView reloadData];
			[self setReloadButtonInNavBar];
		}
		// if we have a view controller currently showing, send it 
		// a data-reload notice as well!
		// (only do this if the status message is an ITEM: update)
		if ( [self.navigationController.visibleViewController isKindOfClass:[CommunityDetailViewController class]] )
		{
			if ( [msg length] > 6 && NSOrderedSame == [msg compare:@"ITEM:" options:NSCaseInsensitiveSearch range:(NSRange){0,5}] )
			{
				NSString *itemIdStr = [msg substringFromIndex:5];
				CommunityDetailViewController * cdetails = (CommunityDetailViewController *)(self.navigationController.visibleViewController);
				if ( [cdetails.m_item.m_id isEqualToString:itemIdStr] )
				{
					[cdetails updateItem];
				}
			}
		}
		
		// set the tab bar badge if we have any new items!
		if ( m_data.m_numNewItems > 0 )
		{
			self.navigationController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d",m_data.m_numNewItems];
		}
	}
	else
	{
		// display the status text
		[m_HUD setText:[m_data currentStatusMessage] andIndicateProgress:YES];
		[m_HUD show:YES];
		[self.tableView setUserInteractionEnabled:NO];
	}
}


- (void)timerFireMethod:(NSTimer *)timer
{
	if ( timer != m_timer ) return;
	
	[m_timer invalidate];
	
	self.navigationController.tabBarItem.badgeValue = nil;
	
	m_timer = nil;
}


- (void)communityItemTypeSwitch:(id)sender
{
	UISearchBar *searchBar = (UISearchBar *)self.tableView.tableHeaderView;
	
	switch ( [sender selectedSegmentIndex] )
	{
		default:
		case 0:
			// This is the chatter (feedback) list
			m_selectedItemType = eCommunity_Chatter;
			searchBar.placeholder = @"Search Chatter...";
			break;
			
		case 1:
			// This is the event list
			m_selectedItemType = eCommunity_Event;
			searchBar.placeholder = @"Search Events...";
			break;
	}
	if ( [m_data isDataAvailable] ) 
	{
		[self.tableView reloadData];
		if ( [m_data numberOfRowsInSection:0 forType:m_selectedItemType] > 0 ) 
		{
			NSUInteger idx[2] = {0,0};
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		}
		self.tableView.userInteractionEnabled = YES;
	}
}


- (IBAction)chooseCommunityAction
{
/* Save this for another release when I can think through it a little better...
	m_alertViewFunction = eAlertType_ChooseCommunityAction;
	UIAlertView *alert = [[UIAlertView alloc] 
						  initWithTitle:@"myGovernment Community"
						  message:@"Would you like to:"
						  delegate:self
						  cancelButtonTitle:@"Cancel"
						  otherButtonTitles:@"Write a comment!",@"Remove Posts",nil];
	[alert show];
*/
}


- (IBAction)reloadCommunityItems
{
	// ask the user if they want to kill
	// their local data store!
	m_alertViewFunction = eAlertType_ReloadQuestion;
	UIAlertView *alert = [[UIAlertView alloc] 
						  initWithTitle:@"Reload Community Chatter"
						  message:@"Do you want to remove cached comments?"
						  delegate:self
						  cancelButtonTitle:@"Cancel"
						  otherButtonTitles:@"Yes",@"No",nil];
	[alert show];
	
	[self setActivityViewInNavBar];
}


- (IBAction)composeNewCommunityItem
{
	switch ( m_selectedItemType )
	{
		default:
			break;
		
		case eCommunity_Chatter:
		{
			// create a new feedback item!
			MessageData *msg = [[MessageData alloc] init];
			msg.m_transport = eMT_MyGov;
			msg.m_to = @"MyGovernment Community";
			msg.m_subject = @" ";
			msg.m_body = @" ";
			msg.m_communityThreadID = nil;
			
			// display the message composer
			ComposeMessageViewController *cmvc = [ComposeMessageViewController sharedComposer];
			[cmvc display:msg fromParent:self];
		}
			break;
			
		case eCommunity_Event:
		{
			NSString *title = @"New Community Event";
			m_alertViewFunction = eAlertType_General;
			UIAlertView *alert = [[UIAlertView alloc] 
								  initWithTitle:title
								  message:@"This action is temporarily disabled..."
								  delegate:self
								  cancelButtonTitle:nil
								  otherButtonTitles:@"OK",nil];
			[alert show];
		}
			break;
	}
}


- (void) deselectRow:(id)sender
{
	// de-select the currently selected row
	// (so the user can go back to the same row)
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
	[self.tableView reloadData];
}


- (void)setEditDoneButtonInNavBar
{
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
											  initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
																   target:self 
											                       action:@selector(finishEditing)];
}


- (void)setReloadButtonInNavBar
{
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
											 initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
											 target:self 
											 action:@selector(reloadCommunityItems)];
}


- (void)setActivityViewInNavBar
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 32.0f)];
	UIActivityIndicatorView *aiView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	//aiView.hidesWhenStopped = YES;
	[aiView setFrame:CGRectMake(12.0f, 6.0f, 20.0f, 20.0f)];
	[view addSubview:aiView];
	[aiView startAnimating];
	
	//UIBarButtonItem *locBarButton = [[UIBarButtonItem alloc] initWithCustomView:aiView];
	UIBarButtonItem *locBarButton = [[UIBarButtonItem alloc] 
									 initWithBarButtonSystemItem:UIBarButtonSystemItemStop
									 target:nil action:nil];
	locBarButton.customView = view;
	locBarButton.style = UIBarButtonItemStyleBordered;
	locBarButton.target = nil;
	self.navigationItem.rightBarButtonItem = locBarButton;
	
	[self.navigationController.navigationBar setNeedsDisplay];
	
	[view release];
	[aiView release];
	[locBarButton release];
}


- (void)finishEditing
{
	[self.tableView setEditing:NO animated:YES];
	[self setReloadButtonInNavBar];
	[self.tableView reloadData];
}


#pragma mark UIAlertViewDelegate Methods


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	switch ( m_alertViewFunction )
	{
		default:
		case eAlertType_General:
			break;
		
		case eAlertType_ReloadQuestion:
			switch ( buttonIndex )
			{
				default:
				case 0: // CANCEL
					[self setReloadButtonInNavBar];
					break;
				
				case 1: // YES: Please remove local cache
					[m_data purgeAllItemsFromCacheAndMemory];
					// fall-through to begin the data re-load!
					
				case 2: // NO: don't remove local cache
					[m_data loadData];
					break;
			}
			break;
		
		case eAlertType_ChooseCommunityAction:
			switch ( buttonIndex )
			{
				default:
				case 0:
					break;
				case 1: // Compose a new message
					[self composeNewCommunityItem];
					break;
				case 2: // Edit community posts
					[self.tableView setEditing:YES animated:YES];
					[self.tableView reloadData];
					[self setEditDoneButtonInNavBar];
					break;
			}
			break;
	}
	m_alertViewFunction = eAlertType_General;
}


#pragma mark UIActionSheetDelegate methods


// action sheet callback: maybe start a re-download on congress data
- (void)actionSheet:(UIActionSheet *)modalView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	
	CommunityItem *item = [m_data itemForIndexPath:[self.tableView indexPathForSelectedRow] 
										   andType:m_selectedItemType];
	if ( nil == item )
	{
		goto deselect_and_return;
	}
	
	// use currently selected legislator to perfom the following action:
	switch ( buttonIndex )
	{
/*
		// View User Info
		case 0:
		{
			// XXX - not ready for this yet...
			m_alertViewFunction = eAlertType_General;
			UIAlertView *alert = [[UIAlertView alloc] 
								  initWithTitle:[[[myGovAppDelegate sharedUserData] userFromID:item.m_creator] m_username]
								  message:@"User info view is currently disabled"
								  delegate:self
								  cancelButtonTitle:nil
								  otherButtonTitles:@"OK",nil];
			[alert show];
		}
			break;
*/
		// Reply/comment on this event or piece of chatter (feedback)
		case 0:
		{
			MessageData *msg = [[MessageData alloc] init];
			msg.m_transport = eMT_MyGovUserComment;
			msg.m_to = @"MyGovernment Community";
			msg.m_subject = [NSString stringWithFormat:@"Re: %@",[item m_title]];
			msg.m_body = @" "; //[item m_title];
			msg.m_communityThreadID = [item m_id];
			msg.m_appURL = [item m_mygovURL];
			msg.m_appURLTitle = [item m_mygovURLTitle];
			msg.m_webURL = [item m_webURL];
			msg.m_webURLTitle = [item m_webURLTitle];
			
			// display the message composer
			ComposeMessageViewController *cmvc = [ComposeMessageViewController sharedComposer];
			[cmvc display:msg fromParent:self];
		}
			break;
			
		default:
			break;
	}
	
	// deselect the selected row 
deselect_and_return:
	[self performSelector:@selector(deselectRow:) withObject:nil afterDelay:0.5f];
}


#pragma mark UISearchBarDelegate methods


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
}


- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
	searchBar.text = @"";
	[searchBar resignFirstResponder];
}


#pragma mark Table view methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return [m_data numberOfSectionsForType:m_selectedItemType];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	//NSLog(@"Number of rows in community table view: %d", [displayList count]);
	return [m_data numberOfRowsInSection:section forType:m_selectedItemType];
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [m_data heightForDataAtIndexPath:indexPath forType:m_selectedItemType];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"CommunityCell";
	
	CommunityItemTableCell *cell = (CommunityItemTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if ( nil == cell ) 
	{
		cell = [[[CommunityItemTableCell alloc] initWithFrame:CGRectZero
											  reuseIdentifier:CellIdentifier] autorelease];
		
		[cell setDetailTarget:self andSelector:@selector(showCommunityDetail:)];
	}	
	
	// Set up the cell...
	[cell setCommunityItem:[m_data itemForIndexPath:indexPath andType:m_selectedItemType]];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Navigate directly to the detail view for a comment - no more action sheet...
	CommunityItem *item = [m_data itemForIndexPath:indexPath andType:m_selectedItemType];
	if ( nil == item ) return;
	
	CommunityDetailViewController *cdView = [[CommunityDetailViewController alloc] init];
	[cdView setItem:item];
	[self.navigationController pushViewController:cdView animated:YES];
	[cdView release];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// the only editing style I support is DELETE
	return UITableViewCellEditingStyleDelete;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Return NO if you do not want the specified item to be editable.
	return YES;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
											forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ( UITableViewCellEditingStyleDelete == editingStyle )
	{
		[m_data removeCommunityItem:[m_data itemForIndexPath:indexPath andType:m_selectedItemType]];
		
		NSArray *idxPathArray = [NSArray arrayWithObjects:indexPath,nil];
		
		[self.tableView deleteRowsAtIndexPaths:idxPathArray withRowAnimation:UITableViewRowAnimationFade];
	}
}


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		// Delete the row from the data source
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
	}   
	else if (editingStyle == UITableViewCellEditingStyleInsert) {
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
	}   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


@end

