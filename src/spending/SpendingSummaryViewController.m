//
//  SpendingSummaryViewController.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import "ContractorSpendingData.h"
#import "CustomTableCell.h"
#import "PlaceSpendingData.h"
#import "SpendingSummaryData.h"
#import "SpendingSummaryViewController.h"


@interface SpendingSummaryViewController (private)
	- (void)deselectRow:(id)sender;
@end



@implementation SpendingSummaryViewController

@synthesize m_placeData, m_contractorData;

- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	[m_placeData release];
	[m_contractorData release];
	
	[m_data release];
	
	[super dealloc];
}


- (id) init
{
	if ( self = [super init] )
	{
		self.title = @"Spending Summary"; // this will be updated later...
		m_placeData = nil;
		m_contractorData = nil;
		m_data = nil;
	}
	return self;
}


- (void)setPlaceData:(PlaceSpendingData *)data
{
	[m_contractorData release]; m_contractorData = nil;
	[m_placeData release];
	m_placeData = [data retain];
	
	if ( nil == m_data )
	{
		m_data = [[SpendingSummaryData alloc] init];
	}
	[m_data setPlaceData:m_placeData];
	
	self.title = [data placeDescrip];
	[self.tableView reloadData];
}


- (void)setContractorData:(ContractorInfo *)data
{
	[m_placeData release]; m_placeData = nil;
	[m_contractorData release];
	m_contractorData = [data retain];
	
	if ( nil == m_data )
	{
		m_data = [[SpendingSummaryData alloc] init];
	}
	[m_data setContractorData:m_contractorData];
	
	self.title = m_contractorData.m_parentCompany;
	[self.tableView reloadData];
}


- (void)loadView
{
	m_tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStyleGrouped];
	m_tableView.delegate = self;
	m_tableView.dataSource = self;
	
	self.view = m_tableView;
	[m_tableView release];
	
	//m_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	m_tableView.separatorColor = [UIColor blackColor];
	m_tableView.backgroundColor = [UIColor blackColor];
	
	/*
	 // XXX - set tableHeaderView to a custom UIView which has legislator
	 //       photo, name, major info (party, state, district), add to contacts link
	 // m_tableView.tableHeaderView = headerView;
	 CGRect hframe = CGRectMake(0,0,320,150);
	 m_headerViewCtrl = [[LegislatorHeaderViewController alloc] initWithNibName:@"LegislatorHeaderView" bundle:nil ];
	 [m_headerViewCtrl.view setFrame:hframe];
	 [m_headerViewCtrl setLegislator:m_legislator];
	 [m_headerViewCtrl setNavController:self];
	 m_tableView.tableHeaderView = m_headerViewCtrl.view;
	 m_tableView.tableHeaderView.userInteractionEnabled = YES;
	 */
}


/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
    }
    return self;
}
*/

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return YES;
}


#pragma mark SpendingSummaryViewController Private


- (void)deselectRow:(id)sender
{
	// de-select the currently selected row
	// (so the user can go back to the same legislator)
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}


#pragma mark Table view methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return [m_data numberOfSections];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	
	if ( nil ==  m_placeData && nil == m_contractorData ) return 0;
	
	return [m_data numberOfRowsInSection:section];
}



- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 35.0f;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	CGRect lblFrame = CGRectMake(0.0f, 0.0f, 320.0f, 40.0f);
	UILabel *sectionLabel = [[[UILabel alloc] initWithFrame:lblFrame] autorelease];
	sectionLabel.backgroundColor = [UIColor clearColor];
	sectionLabel.textColor = [UIColor whiteColor];
	sectionLabel.font = [UIFont boldSystemFontOfSize:18.0f];
	sectionLabel.textAlignment = UITextAlignmentLeft;
	sectionLabel.adjustsFontSizeToFitWidth = YES;
	
	[sectionLabel setText:[m_data titleForSection:section]];
	
	return sectionLabel;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [m_data heightForDataAtIndexPath:indexPath];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"SpendingSummaryInfoCell";
	
	CustomTableCell *cell = (CustomTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if ( nil == cell )
	{
		cell = [[[CustomTableCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
	}
	
	TableRowData *rd = [m_data dataAtIndexPath:indexPath];
	[cell setRowData:rd];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// perform a custom action based on the section/row
	// i.e. make a phone call, send an email, view a map, etc.
	[m_data performActionForIndex:indexPath withParent:self];
	
	[self performSelector:@selector(deselectRow:) withObject:nil afterDelay:0.5f];
}


@end

