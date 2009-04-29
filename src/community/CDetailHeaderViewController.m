//
//  CDetailHeaderViewController.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 3/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "myGovAppDelegate.h"
#import "CDetailHeaderViewController.h"
#import "CommunityItem.h"
#import "MiniBrowserController.h"


@implementation CDetailHeaderViewController

@synthesize m_name;
@synthesize m_mygovURLTitle;
@synthesize m_webURLTitle;
@synthesize m_img;


- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	[m_item release];
	[super dealloc];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
	m_item = nil;
	[super viewDidLoad];
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return YES;
}


#pragma mark CDetailHeaderViewController interface 


- (IBAction) openMyGovURL:(id)sender
{
	if ( nil == m_item ) return;
	/*
	NSString *urlStr = [NSString stringWithFormat:kBioguideURLFmt,[m_item bioguide_id]];
	
	MiniBrowserController *mbc = [MiniBrowserController sharedBrowserWithURL:[NSURL URLWithString:urlStr]];
	[mbc display:m_navController];
	 */
	[[UIApplication sharedApplication] openURL:m_item.m_mygovURL];
}


- (IBAction)openWebURL:(id)sender
{
	if ( nil == m_item ) return;
	
	MiniBrowserController *mbc = [MiniBrowserController sharedBrowserWithURL:m_item.m_webURL];
	[mbc display:[[myGovAppDelegate sharedAppDelegate] topViewController]];
}


- (void)setItem:(CommunityItem *)item
{
	[m_item release];
	m_item = [item retain];
	
	m_name.text = m_item.m_title;
	m_mygovURLTitle.text = m_item.m_mygovURLTitle;
	m_webURLTitle.text = m_item.m_webURLTitle;
	
	if ( nil == m_item.m_mygovURL )
	{
		// XXX - hide detail disclosure button!
	}
	
	if ( nil == m_item.m_webURL )
	{
		// XXX - hide detail disclosure button!
	}
}



@end
