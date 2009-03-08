//
//  CongressViewController.m
//  myGov
//
//  Created by Jeremy C. Andrus on 2/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "CongressViewController.h"
#import "CongressDataManager.h"
#import "LegislatorContainer.h"


// "hidden" API feature to show a progress indicator
@interface UIProgressHUD : NSObject
	- (void) show:(BOOL)yesOrNo;
	- (UIProgressHUD *) initWithWindow:(UIView *)window;
	- (void) setText:(NSString *)theText;
@end


@interface CongressViewController (private)
	- (void) congressSwitch: (id)sender;
	- (void) reloadCongressData;
	- (void) updateHUDText;
	- (void) killHUD;
@end


@implementation CongressViewController

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
    [super dealloc];
}

- (void)viewDidLoad
{
	m_HUD = [[UIProgressHUD alloc] initWithWindow:self.tableView];
	m_HUDTxt = [[NSString alloc] initWithString:@"Loading..."];
	m_shouldKillHUD = NO;
	
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
	m_segmentCtrl.tintColor = [[UIColor alloc] initWithHue:0.0 saturation:0.0 brightness:0.45 alpha:1.0];
	
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
	// XXX - Add a "location" button
	// 
	/*
	 UIButton* modalViewButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	 [modalViewButton addTarget:self action:@selector(modalViewAction:) forControlEvents:UIControlEventTouchUpInside];
	 UIBarButtonItem *modalButton = [[UIBarButtonItem alloc] initWithCustomView:modalViewButton];
	 self.navigationItem.leftBarButtonItem = modalButton;
	 [modalViewButton release];
	 */
	
	[super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated 
{
	if ( nil == m_data )
	{
		m_data = [[CongressDataManager alloc] init];
		[m_data setNotifyTarget:self withSelector:@selector(dataManagerCallback:)];
	}
	
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
		[self performSelector:@selector(updateHUDText) withObject:nil];
	}
	
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
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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


// method called by our data manager when something interesting happens
- (void)dataManagerCallback:(id)message
{
	NSString *msg = message;
	if ( [m_data isDataAvailable] )
	{
		[self.tableView reloadData];
		NSUInteger idx[2] = {0,0};
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathWithIndexes:idx length:2] atScrollPosition:UITableViewScrollPositionTop animated:NO];
	
		self.tableView.userInteractionEnabled = YES;
		
		m_shouldKillHUD = YES;
		[self performSelector:@selector(killHUD) withObject:nil];
	}
	else
	{
		// something interesting must have happened,
		// update the user with some progress
		self.tableView.userInteractionEnabled = NO;
		[m_HUDTxt release];
		m_HUDTxt = [msg retain];
		[self performSelector:@selector(updateHUDText) withObject:nil];
	}
}


- (void)updateHUDText
{
	NSLog( @"updateHUDText: %@",m_HUDTxt );
	
	if ( nil != m_HUD ) [m_HUD show:NO];
	if ( m_shouldKillHUD ) 
	{
		NSLog( @"updateHUDText quitting early - shouldKillHUD!" );
		return;
	}
	
	[m_HUD release];
	
	m_HUD = [[UIProgressHUD alloc] initWithWindow:self.tableView];
	[m_HUD setText:m_HUDTxt];
	[m_HUD show:YES];
	
	[self.tableView setNeedsDisplay];
}


- (void)killHUD
{
	NSLog( @"killHUD" );
	[m_HUD show:NO];
	[m_HUD release];
	m_HUD = nil;
}


// wipe our device cache and re-download all congress personnel data
// (see UIActionSheetDelegate method for actual work)
- (void) reloadCongressData
{
	// pop up an alert asking the user if this is what they really want
	UIActionSheet *reloadAlert =
	[[UIActionSheet alloc] initWithTitle:@"Re-Download congress data? This may take some time..."
						   delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
					       otherButtonTitles:@"Download",nil,nil,nil,nil];
	
	// use the same style as the nav bar
	reloadAlert.actionSheetStyle = self.navigationController.navigationBar.barStyle;
	
	[reloadAlert showInView:self.view];
	[reloadAlert release];
}


#pragma mark UIActionSheetDelegate methods


// action sheet callback: maybe start a re-download on congress data
- (void)actionSheet:(UIActionSheet *)modalView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (buttonIndex)
	{
		case 0:
		{
			// start a download: first wipe out the local data store
			m_shouldKillHUD = NO;
			[m_data updateCongressData];
			// XXX - put up a view of some sort showing progress...
			break;
		}
		default:
			break;
	}
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	if ( [m_data isDataAvailable] )
	{
		return [[m_data states] count];
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
		// 50 index points is too many - cut it in half by simple
		// NULL-ing out every odd entry title
		NSMutableArray * tmpArray = [[[NSMutableArray alloc] initWithArray:[m_data states]] autorelease];
		NSUInteger numStates = [tmpArray count];
		
		for ( NSUInteger st = 0; st < numStates; ++st )
		{
			if ( ((st+1) % 2) || !((st+1) % 3) )
			{
				[tmpArray replaceObjectAtIndex:st withObject:[[[NSString alloc] initWithString:@"  "] autorelease] ];
			}
		}
		
		return tmpArray; //[m_data states];
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
		// XXX - get full state name?
		return [[m_data states] objectAtIndex:section];
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
		NSString *state = [[m_data states] objectAtIndex:section];
		switch (m_selectedChamber) 
		{
			default:
			case eCongressChamberHouse:
				return [[m_data houseMembersInState:state] count];
			case eCongressChamberSenate:
				return [[m_data senateMembersInState:state] count];
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

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if ( cell == nil ) 
	{
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
	}
	
	NSString *state = [[m_data states] objectAtIndex:indexPath.section];
	LegislatorContainer *legislator;
	if ( eCongressChamberHouse == m_selectedChamber ) 
	{
		legislator = [[m_data houseMembersInState:state] objectAtIndex:indexPath.row];
	}
	else
	{
		legislator = [[m_data senateMembersInState:state] objectAtIndex:indexPath.row];
	}
	
	if ( nil == legislator ) 
	{
		cell.text = [[[NSString alloc] initWithString:@"??"] autorelease];
		return cell;
	}
	
	// Set up the cell...
	NSString *lbl = [[NSString alloc] initWithFormat:@"%@. %@ %@ %@ (%@)",
											[legislator title],
											[legislator firstname],
											([legislator middlename] ? [legislator middlename] : @""),
											[legislator lastname],
											[legislator party]
					 ];
	cell.text = lbl;
	[lbl release];
	
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
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

