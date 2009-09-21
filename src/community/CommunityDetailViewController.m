/*
 File: CommunityDetailViewController.m
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
#import "CDetailHeaderViewController.h"
#import "CommunityDetailData.h"
#import "CommunityDetailViewController.h"
#import "CommunityItem.h"
#import "ComposeMessageViewController.h"
#import "CustomTableCell.h"
#import "MyGovUserData.h"
#import "TableDataManager.h"

#define COMMENT_HTML_HDR  @" \
<html> \
	<head> \
		<title>User Comments!</title> \
		<meta name=\"viewport\" content=\"300, initial-scale=1.0\"> \
		<script type=\"text/javascript\"> \
			function endcommenttouch(e) { \
				e.preventDefault(); \
				var ypos = window.pageYOffset; \
				document.location='http://touchend/'+ypos; \
			} \
			function hookTouchEvents() { \
				document.addEventListener(\"touchend\", endcommenttouch, true); \
			} \
		</script> \
		<style> \
		div.comment { \
			font-size: 1em; \
			border-left: 5px solid #444; \
			margin-top: 0.7em; \
			margin-left: 0.5em; \
			margin-bottom: 1em; \
			padding-left: 0.5em; \
		} \
		div.header { \
			border-top: 2px solid #222; \
			padding-top: 0.2em; \
			font-size: 1.2em; \
		} \
		div.subtitle { \
			font-size: 0.8em; \
			margin-top: 0.1em; \
			margin-left: 0.5em; \
			margin-right: 0.5em; \
			padding: 0.1em; \
			color: #fe6; \
		} \
		</style> \
	</head> \
	<body style=\"background: #000; color: #fff\"> \
"

#define COMMENT_HTML_FMT @" \
		<div class=\"header\">%@</div> \
		<div class=\"subtitle\">%@</div> \
		<div class=\"comment\">%@</div> \
"

#define COMMENT_HTML_END @" \
	</body> \
</html> \
"


@interface CommunityDetailViewController (private)
	- (void)reloadItemData;
	- (NSString *)formatItemComments;
	- (CGFloat)heightForFeedbackText;
	- (void)addItemComment;
	- (void)userWantsToAttend;
	- (void)attendCurrentEvent;
	- (void)addCurrentEventToCalendar;
@end


@implementation CommunityDetailViewController

@synthesize m_item;


enum
{
	eCDV_AlertShouldAttend  = 1,
	eCDV_AlertAddToCalendar = 2,
};


- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	[m_item release];
	
	[m_data release];
	
	[super dealloc];
}


- (id) init
{
	if ( self = [super init] )
	{
		self.title = @"Community Item"; // this will be updated later...
		m_item = nil;
		m_data = nil;
		//m_tableView = nil;
		m_webView = nil;
		m_itemLabel = nil;
		m_alertSheetUsed = eCDV_AlertShouldAttend;
	}
	return self;
}


- (void)setItem:(CommunityItem *)item
{
	[m_item release];
	m_item = [item retain];
	
	if ( nil == m_data )
	{
		m_data = [[CommunityDetailData alloc] init];
	}
	[m_data setItem:m_item];
	
	switch ( m_item.m_type )
	{
		case eCommunity_Event:
		{
			self.title = @"Event";
		}
			break;
		
		case eCommunity_Chatter:
		{
			MyGovUserData *mgud = [myGovAppDelegate sharedUserData];
			MyGovUser *user = [mgud userFromUsername:m_item.m_creator];
			NSString *uname;
			if ( nil == user || nil == user.m_username )
			{
				uname = @"??";
			}
			else
			{
				uname = user.m_username;
			}
			self.title = [NSString stringWithFormat:@"%@ says...",uname];
		}
			break;
	}
	
	UILabel *titleView = [[[UILabel alloc] initWithFrame:CGRectMake(0,0,240,32)] autorelease];
	titleView.backgroundColor = [UIColor clearColor];
	titleView.textColor = [UIColor whiteColor];
	titleView.font = [UIFont boldSystemFontOfSize:16.0f];
	titleView.textAlignment = UITextAlignmentCenter;
	titleView.adjustsFontSizeToFitWidth = YES;
	titleView.text = self.title;
	self.navigationItem.titleView = titleView;
	
	[self reloadItemData];
}


- (void)loadView
{
	if ( eCommunity_Event == [m_item m_type] )
	{
		// 
		// XXX - check to see if the user is already attending!!
		// 
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
													  initWithTitle:@"I'm Coming!"
													  style:UIBarButtonItemStyleDone
													  target:self 
													  action:@selector(userWantsToAttend)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
												  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
												  target:self 
												  action:@selector(addItemComment)];
	}

	UIScrollView *myView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,320,565)];
	myView.userInteractionEnabled = YES;
	[myView setDelegate:self];
	
	// 
	// The header view loads up the user / event / chatter image
	// and holds a title, and URL links
	CGRect hframe = CGRectMake(0,0,320,165);
	CDetailHeaderViewController *hdrViewCtrl;
	hdrViewCtrl = [[CDetailHeaderViewController alloc] initWithNibName:@"CDetailHeaderView" bundle:nil ];
	[hdrViewCtrl.view setFrame:hframe];
	[hdrViewCtrl setItem:m_item];
//	self.tableView.tableHeaderView = hdrViewCtrl.view;
//	self.tableView.tableHeaderView.userInteractionEnabled = YES;
	[myView addSubview:hdrViewCtrl.view];
	[hdrViewCtrl release];
	
	m_itemLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,165,300,40)];
	m_itemLabel.backgroundColor = [UIColor clearColor];
	m_itemLabel.textColor = [UIColor grayColor];
	m_itemLabel.font = [UIFont systemFontOfSize:16.0f];
	m_itemLabel.textAlignment = UITextAlignmentCenter;
	m_itemLabel.lineBreakMode = UILineBreakModeWordWrap;
	m_itemLabel.numberOfLines = 0;
	[myView addSubview:m_itemLabel];
	
	m_webView = [[UIWebView alloc] initWithFrame:CGRectMake(10,205,300,380)];
	m_webView.backgroundColor = [UIColor clearColor];
	[m_webView setDelegate:self];
	m_webView.userInteractionEnabled = YES;
	
	// HACK alert: try to prevent rubberbanding in the UIWebView
	id maybeAScrollView = [[m_webView subviews] objectAtIndex:0];
	if ( [maybeAScrollView respondsToSelector:@selector(setAllowsRubberBanding:)] )
	{
		[maybeAScrollView performSelector:@selector(setAllowsRubberBanding:) withObject:(id)(NO)];
	}
	
	[myView addSubview:m_webView];
	
	myView.backgroundColor = [UIColor blackColor];
	self.view = myView;
	[myView release];
	
	[self reloadItemData];
}


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


#pragma mark UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGPoint ofst = scrollView.contentOffset;
	if ( ofst.y >= m_webView.frame.origin.y )
	{
		[scrollView setContentOffset:CGPointMake(0,m_webView.frame.origin.y)];
		[scrollView setScrollEnabled:NO];
	}
}

#pragma mark UIWebViewDelegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request 
									 navigationType:(UIWebViewNavigationType)navigationType
{
	if ( [request.URL.host isEqualToString:@"touchend"] )
	{
		NSInteger ypos = [[[request.URL relativePath] lastPathComponent] integerValue];
		if ( ypos <= 7 )
		{
			UIScrollView *sv = (UIScrollView *)(self.view);
			[sv setScrollEnabled:YES];
			[sv setContentOffset:CGPointMake(0,m_webView.frame.origin.y-2-ypos)];
		}
		return NO;
	}
	return YES;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[webView stringByEvaluatingJavaScriptFromString:@"hookTouchEvents();"];
}


#pragma mark CommunityDetailViewController Private

/*
- (void)deselectRow:(id)sender
{
	// de-select the currently selected row
	// (so the user can go back to the same legislator)
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}
*/


- (void)reloadItemData
{
	if ( nil == m_item ) return;

	CGFloat pos = 165.0f;
	
	// adjust frame to fit _all_ of the text :-)
	CGFloat commentTxtHeight = [self heightForFeedbackText];
	[m_itemLabel setFrame:CGRectMake( 10.0f, pos, 300.0f, commentTxtHeight )];
	m_itemLabel.text = m_item.m_text;
	
	pos += commentTxtHeight;
	
	// resize the comment view and reload it's data
	[m_webView setFrame:CGRectMake( 10.0f, pos, 300.0f, 380.0f)];

	NSString *htmlStr = [self formatItemComments];
	[m_webView loadHTMLString:htmlStr 
					  baseURL:nil ];
	/*
	[m_webView loadRequest:[[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"http://www.google.com/"]]];
	 */
	pos += 380.0f;
	m_webView.userInteractionEnabled=YES;
	
	[(UIScrollView *)(self.view) setContentSize:CGSizeMake(320.0f,pos)];
	
	[self.view setNeedsDisplay];
}


- (NSString *)formatItemComments
{
	NSMutableString *html = [[[NSMutableString alloc] initWithString:COMMENT_HTML_HDR] autorelease];
	
	NSDateFormatter *dateFmt = [[[NSDateFormatter alloc] init] autorelease];
	[dateFmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	
	// Add all the comments!
	NSArray *commentArray = [m_item comments];
	NSEnumerator *cmntEnum = [commentArray objectEnumerator];
	CommunityComment *cmnt;
	while ( cmnt = [cmntEnum nextObject] )
	{
		
		NSString *dateStr = (cmnt.m_date ? [dateFmt stringFromDate:cmnt.m_date] : @"some unspecified date/time!");
		MyGovUser *user = [[myGovAppDelegate sharedUserData] userFromUsername:cmnt.m_creator];
		
		NSString *subtitle = [NSString stringWithFormat:@"Posted by <b>%@</b> on %@",[user m_username],dateStr];
		[html appendFormat:COMMENT_HTML_FMT, cmnt.m_title, subtitle, cmnt.m_text];
	}
	
	[html appendString:COMMENT_HTML_END];
	return html;
}


- (CGFloat)heightForFeedbackText
{
	NSString *txt = m_item.m_text;
	
	CGSize txtSz = [txt sizeWithFont:[UIFont systemFontOfSize:16.0f] 
				   constrainedToSize:CGSizeMake(300.0f,800.0f)
					   lineBreakMode:UILineBreakModeWordWrap];
	
	return txtSz.height + 14.0f; // with some padding...
}


- (void)addItemComment
{
	// create a new feedback item!
	MessageData *msg = [[MessageData alloc] init];
	msg.m_transport = eMT_MyGovUserComment;
	msg.m_to = @"MyGovernment Community";
	msg.m_subject = [NSString stringWithFormat:@"Re: %@",m_item.m_title];
	msg.m_body = @" ";
	msg.m_appURL = m_item.m_mygovURL;
	msg.m_appURLTitle = m_item.m_mygovURLTitle;
	msg.m_webURL = m_item.m_webURL;
	msg.m_webURLTitle = m_item.m_webURLTitle;
	msg.m_communityThreadID = m_item.m_id;
	
	// display the message composer
	ComposeMessageViewController *cmvc = [ComposeMessageViewController sharedComposer];
	[cmvc display:msg fromParent:self];
	
	//[self.tableView reloadData];
	[self reloadItemData];
}


- (void)userWantsToAttend
{
	
	UIAlertView *alert = [[UIAlertView alloc] 
								initWithTitle:[NSString stringWithFormat:@"Do you plan on attending %@?",[m_item m_title]]
									  message:@""
									 delegate:self
							cancelButtonTitle:@"No"
							otherButtonTitles:@"Yes",nil];
	
	m_alertSheetUsed = eCDV_AlertShouldAttend;
	[alert show];
}


- (void)attendCurrentEvent
{
	// XXX - 
	// XXX - actually mark the current user as attending this event!
	// XXX - 
	
	UIAlertView *alert = [[UIAlertView alloc] 
						  initWithTitle:[NSString stringWithFormat:@"Would you like to add %@ to your calendar?",[m_item m_title]]
						  message:@""
						  delegate:self
						  cancelButtonTitle:@"No"
						  otherButtonTitles:@"Yes",nil];
	
	m_alertSheetUsed = eCDV_AlertAddToCalendar;
	[alert show];
}


- (void)addCurrentEventToCalendar
{
	// XXX - 
	// XXX - add the current event to a user's calendar!
	// XXX - 
	
}


#pragma mark UIAlertViewDelegate Methods


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ( eCDV_AlertAddToCalendar == m_alertSheetUsed )
	{
		switch ( buttonIndex )
		{
			default:
			case 0: // no action
				break;
				
			case 1: // add the current event to the user's calendar!
				[self addCurrentEventToCalendar];
				break;
		}
	}
	else if ( eCDV_AlertShouldAttend == m_alertSheetUsed )
	{
		switch ( buttonIndex )
		{
			default:
			case 0: // doesn't want to attent...
				break;
			
			case 1: // wants to attend!
				[self attendCurrentEvent];
				break;
		}
	}
}


#pragma mark Table view methods

/**
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return [m_data numberOfSections];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	
	if ( nil ==  m_item ) return 0;
	
	return [m_data numberOfRowsInSection:section];
}



- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if ( 0 == section )
	{
		if ( eCommunity_Chatter == m_item.m_type )
		{
			return [self heightForFeedbackText];
		}
		else
		{
			return 0.0f;
		}
	}
	else
	{
		return 35.0f;
	}
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	CGRect lblFrame = CGRectMake(0.0f, 0.0f, 320.0f, 40.0f);
	UILabel *sectionLabel = [[[UILabel alloc] initWithFrame:lblFrame] autorelease];
	
	NSString *lblText = [m_data titleForSection:section];
	
	if ( 0 == section )
	{
		if ( eCommunity_Chatter == m_item.m_type )
		{
			lblText = m_item.m_text;
		}
		
		sectionLabel.backgroundColor = [UIColor clearColor];
		sectionLabel.textColor = [UIColor grayColor];
		sectionLabel.font = [UIFont systemFontOfSize:16.0f];
		sectionLabel.textAlignment = UITextAlignmentCenter;
		sectionLabel.lineBreakMode = UILineBreakModeWordWrap;
		sectionLabel.numberOfLines = 0;
		
		// adjust frame to fit _all_ of the text :-)
		CGFloat cellHeight = [self heightForFeedbackText];
		[sectionLabel setFrame:CGRectMake( 10.0f, 0.0f, 300.0f, cellHeight )];
	}
	else
	{
		sectionLabel.backgroundColor = [UIColor clearColor];
		sectionLabel.textColor = [UIColor whiteColor];
		sectionLabel.font = [UIFont boldSystemFontOfSize:18.0f];
		sectionLabel.textAlignment = UITextAlignmentLeft;
		sectionLabel.adjustsFontSizeToFitWidth = YES;
	}
	
	[sectionLabel setText:lblText];
	
	return sectionLabel;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [m_data heightForDataAtIndexPath:indexPath];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"CommunityDetailCell";
	
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
*/

@end

