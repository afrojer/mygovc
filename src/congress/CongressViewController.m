//
//  CongressViewController.m
//  myGov
//
//  Created by Jeremy C. Andrus on 2/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "myGovAppDelegate.h"

#import "CongressDataManager.h"
#import "CongressViewController.h"
#import "LegislatorContainer.h"
#import "LegislatorNameCell.h"
#import "LegislatorViewController.h"
#import "ProgressOverlayViewController.h"
#import "StateAbbreviations.h"


@interface CongressViewController (private)
	- (void)setLocationButtonInNavBar;
	- (void)setActivityViewInNavBar;
	- (void)congressSwitch: (id)sender;
	- (void)reloadCongressData;
	- (void)deselectRow:(id)sender;
	-(void)findLocalLegislators:(id)sender;
@end

enum
{
	eTAG_ACTIVITY = 999,
};

@implementation CongressViewController

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	[m_data release];
	[m_locationManager release];
	[m_currentLocation release];
    [super dealloc];
}


- (void)viewDidLoad
{
	self.title = @"Congress";
	
	self.tableView.autoresizesSubviews = YES;
	self.tableView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
	self.tableView.rowHeight = 50.0f;
	
	m_data = [[myGovAppDelegate sharedCongressData] retain];
	[m_data setNotifyTarget:self withSelector:@selector(dataManagerCallback:)];
	
	m_searchResultsTitle = @"Search Results";
	
	m_locationManager = nil;
	m_currentLocation = nil;
	
	m_actionType = eActionReload;
	
	m_HUD = [[ProgressOverlayViewController alloc] initWithWindow:self.tableView];
	[m_HUD show:NO];
	[m_HUD setText:@"Loading..." andIndicateProgress:YES];
	
	// Create a new segment control and place it in 
	// the NavigationController's title area
	NSArray *buttonNames = [NSArray arrayWithObjects:@"House", @"Senate", nil];
	m_segmentCtrl = [[UISegmentedControl alloc] initWithItems:buttonNames];
	
	// default styles
	m_segmentCtrl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	m_segmentCtrl.segmentedControlStyle = UISegmentedControlStyleBar;
	m_segmentCtrl.selectedSegmentIndex = 0; // Default to the "House"
	m_selectedChamber = eCongressChamberHouse;
	m_segmentCtrl.frame = CGRectMake(0,0,200,30);
	// saturation of 0.0 means black/white
	m_segmentCtrl.tintColor = [UIColor darkGrayColor];
	
	// add ourself as the target
	[m_segmentCtrl addTarget:self action:@selector(congressSwitch:) forControlEvents:UIControlEventValueChanged];
	
	// add the buttons to the navigation bar
	self.navigationItem.titleView = m_segmentCtrl;
	[m_segmentCtrl release];
	
	// 
	// Add a "refresh" button which will wipe out the on-device cache and 
	// re-download congress data
	// 
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
											   initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
											   target:self 
											   action:@selector(reloadCongressData)] autorelease];
	
	// 
	// Add a "location" button which will be used to find senators/representatives
	// which represent a users current district
	// 
	[self setLocationButtonInNavBar];
	
	// create a search bar which will be used as our table's header view
	UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 50.0f)];
	searchBar.delegate = self;
	searchBar.prompt = @"";
	searchBar.placeholder = @"Search for legislator...";
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	searchBar.barStyle = UIBarStyleBlackOpaque;
	searchBar.showsCancelButton = YES;
	
	self.tableView.tableHeaderView = searchBar;
	self.tableView.tableHeaderView.userInteractionEnabled = YES;
	
	[super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated 
{
	[m_data setNotifyTarget:self withSelector:@selector(dataManagerCallback:)];
	
	if ( ![m_data isDataAvailable] )
	{
		self.tableView.userInteractionEnabled = NO;
	}
		
    [super viewWillAppear:animated];
}


- (void)viewDidAppear:(BOOL)animated 
{
	if ( [m_data isDataAvailable] )
	{
		self.tableView.userInteractionEnabled = YES;
	}
	else
	{
		[m_HUD show:YES]; // with whatever text is there...
		[m_HUD setText:m_HUD.m_label.text andIndicateProgress:YES];
	}
	
	// de-select the currently selected row
	// (so the user can go back to the same legislator)
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
	
	[super viewDidAppear:animated];
}

/*
- (void)viewWillDisappear:(BOOL)animated 
{
	[super viewWillDisappear:animated];
}
*/

/*
- (void)viewDidDisappear:(BOOL)animated 
{
	[super viewDidDisappear:animated];
}
*/


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Return YES for supported orientations
    return YES; // (interfaceOrientation == UIInterfaceOrientationPortrait);
}


// method called by our data manager when something interesting happens
- (void)dataManagerCallback:(id)message
{
	NSString *msg = message;
	
	NSLog( @"dataManagerCallback: %@",msg );
	
	NSRange msgTypeRange = {0, 5};
	if ( NSOrderedSame == [msg compare:@"ERROR" options:NSCaseInsensitiveSearch range:msgTypeRange] )
	{
		// crap! an error occurred in the parsing/downloading: give the user
		// an error message and leave it there...
		[self setLocationButtonInNavBar];
		self.tableView.userInteractionEnabled = NO;
		NSString *txt = [[[NSString alloc] initWithFormat:@"Error loading data%@",
											([msg length] <= 6 ? @"!" : 
											 [NSString stringWithFormat:@": \n%@",[msg substringFromIndex:6]])
						] autorelease];
		
		[m_HUD show:YES];
		[m_HUD setText:txt andIndicateProgress:NO];
	}
	else if ( NSOrderedSame == [msg compare:@"LOCTN" options:NSCaseInsensitiveSearch range:msgTypeRange] )
	{
		m_selectedChamber = eCongressSearchResults;
		[self setLocationButtonInNavBar];
		[self.tableView reloadData];
		NSUInteger idx[2] = {0,0};
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		[m_HUD show:NO];
		self.tableView.userInteractionEnabled = YES;
	}
	else if ( [m_data isDataAvailable] )
	{
		[self.tableView reloadData];
		NSUInteger idx[2] = {0,0};
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		[m_HUD show:NO];
		self.tableView.userInteractionEnabled = YES;
	}
	else
	{
		// something interesting must have happened,
		// update the user with some progress
		self.tableView.userInteractionEnabled = NO;
		[m_HUD show:YES];
		[m_HUD setText:msg andIndicateProgress:YES];
		[self.tableView setNeedsDisplay];
	}
}


- (void)showLegislatorDetail:(id)sender
{
	UIButton *button = (UIButton *)sender;
	if ( nil == button ) return;
	
	LegislatorNameCell *sdr = (LegislatorNameCell *)[button superview];
	if ( nil == sdr ) return;
	
	LegislatorViewController *legViewCtrl = [[LegislatorViewController alloc] init];
	[legViewCtrl setLegislator:[sdr m_legislator]];
	[self.navigationController pushViewController:legViewCtrl animated:YES];
	[legViewCtrl release];
}


#pragma mark CongressViewController Private


- (void)setLocationButtonInNavBar
{
	UIImage *locImg = [UIImage imageWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"location_overlay.png"]];
	UIBarButtonItem *locBarButton = [[UIBarButtonItem alloc] 
									  initWithImage:locImg 
									  style:UIBarButtonItemStylePlain 
									  target:self 
									  action:@selector(findLocalLegislators:)];
	self.navigationItem.leftBarButtonItem = locBarButton;
	[locBarButton release];
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
	self.navigationItem.leftBarButtonItem = locBarButton;
	
	[self.navigationController.navigationBar setNeedsDisplay];
	
	[view release];
	[aiView release];
	[locBarButton release];
}


// Switch the table data source between House and Senate
- (void)congressSwitch: (id)sender
{
	switch ( [sender selectedSegmentIndex] )
	{
		default:
		case 0:
			// This is the House!
			m_selectedChamber = eCongressChamberHouse;
			break;
			
		case 1:
			// This is the Senate!
			m_selectedChamber = eCongressChamberSenate;
			break;
	}
	if ( [m_data isDataAvailable] ) 
	{
		[self.tableView reloadData];
		NSUInteger idx[2] = {0,0};
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
		self.tableView.userInteractionEnabled = YES;
	}
}


// wipe our device cache and re-download all congress personnel data
// (see UIActionSheetDelegate method for actual work)
- (void) reloadCongressData
{
	// don't start another re-load while one is apparently already in progress!
	if ( [m_data isBusy] ) return;
	
	// pop up an alert asking the user if this is what they really want
	m_actionType = eActionReload;
	UIActionSheet *reloadAlert =
	[[UIActionSheet alloc] initWithTitle:@"Re-Download congress data?\nWARNING: This may take some time..."
						   delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
					       otherButtonTitles:@"Download",nil,nil,nil,nil];
	
	// use the same style as the nav bar
	reloadAlert.actionSheetStyle = self.navigationController.navigationBar.barStyle;
	
	[reloadAlert showInView:self.view];
	[reloadAlert release];
}


- (void) deselectRow:(id)sender
{
	// de-select the currently selected row
	// (so the user can go back to the same legislator)
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}


-(void)findLocalLegislators:(id)sender
{
	// XXX - lookup legislators in current district using location services
	// plus govtrack district data
	NSLog( @"CongressViewController: finding local legislators..." );
	
	if ( nil == m_locationManager )
	{
		m_locationManager = [[CLLocationManager alloc] init];
		m_locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
		m_locationManager.distanceFilter = 100.0;
		m_locationManager.delegate = self;
	}
	
	if ( !m_locationManager.locationServicesEnabled )
	{
		// XXX - alert user of failure?!
	}
	else
	{
		[self setActivityViewInNavBar];
		m_searchResultsTitle = @"Local Legislators";
		
		[m_locationManager startUpdatingLocation];
	}
}


#pragma mark CLLocationManagerDelegate methods


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	if ( signbit(newLocation.horizontalAccuracy) )
	{
		// Negative accuracy means an invalid or unavailable measurement
		// XXX - stop activity wheel, and notify user of failure?
	} 
	else 
	{
		[m_data setSearchLocation:newLocation];
    }
}


- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	[self setLocationButtonInNavBar];
	
	// XXX - notify user of error?
}


#pragma mark UISearchBarDelegate methods


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	m_searchResultsTitle = @"Search Results";
	
	if ( [searchText length] == 0 )
	{
		[searchBar resignFirstResponder];
		switch ( [m_segmentCtrl selectedSegmentIndex] )
		{
			default:
			case 0:
				m_selectedChamber = eCongressChamberHouse;
				break;
			case 1:
				m_selectedChamber = eCongressChamberSenate;
				break;
		}
		[self.tableView reloadData];
	}
	else
	{
		m_selectedChamber = eCongressSearchResults;
		[m_data setSearchString:searchText];
	}
	
	[self.tableView reloadData];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
	m_selectedChamber = eCongressSearchResults;
	[self.tableView reloadData];
}


- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	
	switch ( [m_segmentCtrl selectedSegmentIndex] )
	{
		default:
		case 0:
			m_selectedChamber = eCongressChamberHouse;
			break;
		case 1:
			m_selectedChamber = eCongressChamberSenate;
			break;
	}
	
	[self.tableView reloadData];
}


#pragma mark UIActionSheetDelegate methods


// action sheet callback: maybe start a re-download on congress data
- (void)actionSheet:(UIActionSheet *)modalView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if ( eActionContact == m_actionType )
	{
		// use currently selected legislator to perfom the following action:
		switch ( buttonIndex )
		{
			case 0:
				// XXX - email!
			case 1:
				// XXX - Call
			case 2:
				// XXX - Tweet
			default:
				break;
		}
		// deselect the selected row (after we've used it to get phone/email/twitter)
		[self performSelector:@selector(deselectRow:) withObject:nil afterDelay:0.5f];
	}
	else if ( eActionReload == m_actionType )
	{
		switch ( buttonIndex )
		{
			case 0:
			{
				// don't start another download if the data store is busy!
				if ( ![m_data isBusy] ) 
				{
					// scroll to the top of the table so that our progress HUD
					// is displayed properly
					NSUInteger idx[2] = {0,0};
					[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
					
					// start a data download/update: this destroys the current data cache
					[m_data updateCongressData];
				}
				break;
			}
			default:
				break;
		}
	}
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if ( [m_data isDataAvailable] )
	{
		switch ( m_selectedChamber )
		{
			case eCongressSearchResults:
				return 1;
			
			default:
				return [[StateAbbreviations abbrList] count]; // [[m_data states] count];
		}
	}
	else
	{
		return 1;
	}
}


- (NSArray *)sectionIndexTitlesForTableView: (UITableView *)tableView
{
	if ( [m_data isDataAvailable] )
	{
		switch ( m_selectedChamber )
		{
			case eCongressSearchResults:
				return nil;
			default:
				return [StateAbbreviations abbrTableIndexList];
		}
	}
	else
	{
		return nil;
	}
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if ( [m_data isDataAvailable] )
	{
		switch ( m_selectedChamber )
		{
			case eCongressSearchResults:
				return m_searchResultsTitle;
			default:
				// get full state name
				return [[StateAbbreviations nameList] objectAtIndex:section];
		}
	}
	else
	{
		return nil;
	}
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if ( [m_data isDataAvailable] )
	{
		//NSString *state = [[m_data states] objectAtIndex:section];
		NSString *state = [[StateAbbreviations abbrList] objectAtIndex:section];
		switch (m_selectedChamber) 
		{
			default:
			case eCongressChamberHouse:
				return [[m_data houseMembersInState:state] count];
			case eCongressChamberSenate:
				return [[m_data senateMembersInState:state] count];
			case eCongressSearchResults:
				return [[m_data searchResultsArray] count];
		}
	}
	else
	{
		return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    
	static NSString *CellIdentifier = @"CongressCell";

	LegislatorNameCell *cell = (LegislatorNameCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if ( cell == nil ) 
	{
		cell = [[[LegislatorNameCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier detailTarget:self detailSelector:@selector(showLegislatorDetail:)] autorelease];
	}
	
	if ( ![m_data isDataAvailable] ) return cell;
	
	//NSString *state = [[m_data states] objectAtIndex:indexPath.section];
	NSString *state = [[StateAbbreviations abbrList] objectAtIndex:indexPath.section];
	LegislatorContainer *legislator;
	switch ( m_selectedChamber )
	{
		case eCongressChamberHouse:
			legislator = [[m_data houseMembersInState:state] objectAtIndex:indexPath.row];
			break;
		case eCongressChamberSenate:
			legislator = [[m_data senateMembersInState:state] objectAtIndex:indexPath.row];
			break;
		case eCongressSearchResults:
			legislator = [[m_data searchResultsArray] objectAtIndex:indexPath.row];
			break;
		default:
			legislator = nil;
			break;
	}
	
	if ( nil == legislator ) 
	{
		return cell;
	}
	
	// Set up the cell...
	[cell setInfoFromLegislator:legislator];
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	//NSString *state = [[m_data states] objectAtIndex:indexPath.section];
	NSString *state = [[StateAbbreviations abbrList] objectAtIndex:indexPath.section];
	LegislatorContainer *legislator;
	switch ( m_selectedChamber )
	{
		case eCongressChamberHouse:
			legislator = [[m_data houseMembersInState:state] objectAtIndex:indexPath.row];
			break;
		case eCongressChamberSenate:
			legislator = [[m_data senateMembersInState:state] objectAtIndex:indexPath.row];
			break;
		case eCongressSearchResults:
			legislator = [[m_data searchResultsArray] objectAtIndex:indexPath.row];
			break;
		default:
			legislator = nil;
			break;
	}
	
	// no legislator here...
	if ( nil == legislator )
	{
		[self performSelector:@selector(deselectRow:) withObject:nil afterDelay:0.5f];
		return;
	}
	
	// pop up an alert asking the user if this is what they really want
	m_actionType = eActionContact;
	UIActionSheet *contactAlert =
	[[UIActionSheet alloc] initWithTitle:[legislator shortName]
							delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
							otherButtonTitles:@"Email",@"Call",@"Tweet",nil,nil];
	
	// use the same style as the nav bar
	contactAlert.actionSheetStyle = self.navigationController.navigationBar.barStyle;
	
	[contactAlert showInView:self.view];
	[contactAlert release];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


@end

