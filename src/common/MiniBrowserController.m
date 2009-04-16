//
//  MiniBrowserController.m
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/6/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MiniBrowserController.h"

@interface MiniBrowserController (private)
	- (void)enableBackButton:(BOOL)enable;
	- (void)enableFwdButton:(BOOL)enable;
@end

enum
{
	eTAG_BACK    = 999,
	eTAG_RELOAD  = 998,
	eTAG_FORWARD = 997,
	eTAG_CLOSE   = 996,
	eTAG_STOP    = 995,
};


@implementation MiniBrowserController

@synthesize m_toolBar, m_webView, m_shouldStopLoadingOnHide;
@synthesize m_backButton, m_reloadButton, m_fwdButton;

static MiniBrowserController *s_browser = NULL;


+ (MiniBrowserController *)sharedBrowser
{
	return [self sharedBrowserWithURL:nil];
}


+ (MiniBrowserController *)sharedBrowserWithURL:(NSURL *)urlOrNil
{
	if ( NULL == s_browser )
	{
		s_browser = [[MiniBrowserController alloc] initWithNibName:@"MiniBrowserView" bundle:nil];
		s_browser.m_webView.detectsPhoneNumbers = YES;
		s_browser.m_webView.scalesPageToFit = YES;
		[s_browser.view setNeedsDisplay];
	}
	
	if ( nil != urlOrNil )
	{
		[s_browser loadURL:urlOrNil];
	}
	
	// let the caller take care of making this window visible...
	
	return s_browser;
}


// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) 
	{
		m_shouldStopLoadingOnHide = YES;
		m_loadingInterrupted = NO;
		m_urlToLoad = nil;
		m_activity = nil;
		m_parentCtrl = nil;
		m_shouldDisplayOnViewLoad = NO;
		m_normalItemList = nil;
		m_loadingItemList = nil;
		[self enableBackButton:NO];
		[self enableFwdButton:NO];
	}
	return self;
}


- (void)didReceiveMemoryWarning 
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	[m_urlToLoad release];
	[m_normalItemList release];
	[m_loadingItemList release];
	[super dealloc];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
	[super viewDidLoad];
	
	CGRect actFrame = CGRectMake( CGRectGetWidth(self.m_webView.frame)/2.0f - 16.0f,
								 CGRectGetHeight(self.m_webView.frame)/2.0f - 16.0f,
								 32.0f, 32.0f
								 );
	m_activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	[m_activity setFrame:actFrame];
	m_activity.hidesWhenStopped = YES;
	[self.m_webView addSubview:m_activity];
	[m_activity release];
	[m_activity stopAnimating];
	
	// get the current list of buttons
	m_normalItemList = [[NSArray alloc] initWithArray:m_toolBar.items];
	
	// generate a list of buttons to display while loading
	// (this enables a stop button)
	{
		NSMutableArray *tmpArray = [[NSMutableArray alloc] initWithCapacity:[m_normalItemList count]];
		NSEnumerator *e = [m_toolBar.items objectEnumerator];
		id bbi;
		while ( bbi = [e nextObject] )
		{
			UIBarButtonItem *button = (UIBarButtonItem *)bbi;
			if ( eTAG_RELOAD == [button tag] )
			{
				UIBarButtonItem *stopButton = [[UIBarButtonItem alloc] 
													initWithBarButtonSystemItem:UIBarButtonSystemItemStop 
													target:self action:@selector(refreshButtonPressed:)];
				[stopButton setTag:eTAG_STOP];
				[tmpArray addObject:stopButton];
				[stopButton release];
			}
			else
			{
				[tmpArray addObject:bbi];
			}
		}
		m_loadingItemList = (NSArray *)tmpArray;
	}
	
	if ( m_shouldDisplayOnViewLoad )
	{
		m_shouldDisplayOnViewLoad = NO;
		[m_parentCtrl presentModalViewController:self animated:YES];
	}
}



- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if ( nil != m_urlToLoad )
	{
		[self loadURL:m_urlToLoad];
		[m_urlToLoad release]; m_urlToLoad = nil;
	}
	else if ( m_loadingInterrupted )
	{
		[m_webView reload];
	}
	m_loadingInterrupted = NO;
}


- (void)viewDidAppear:(BOOL)animated 
{
	[super viewDidAppear:animated];
	
	[self enableBackButton:m_webView.canGoBack];
	[self enableFwdButton:m_webView.canGoForward];
}


- (void)viewWillDisappear:(BOOL)animated 
{
	if ( m_shouldStopLoadingOnHide )
	{
		if ( m_webView.loading )
		{
			m_loadingInterrupted = YES;
		}
		[self stopLoading];
	}
	
	[super viewWillDisappear:animated];
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return YES;
}


- (void)display:(id)parentController
{
	m_parentCtrl = parentController;
	if ( nil != m_webView )
	{
		[m_parentCtrl presentModalViewController:self animated:YES];
	}
	else
	{
		m_shouldDisplayOnViewLoad = YES;
		[self.view setNeedsDisplay];
	}
}


- (IBAction)closeButtonPressed:(id)button
{
	// dismiss the view
	[m_parentCtrl dismissModalViewControllerAnimated:YES];
}


- (IBAction)backButtonPressed:(id)button
{
	if ( m_webView.canGoBack ) [m_webView goBack];
}


- (IBAction)fwdButtonPressed:(id)button
{
	if ( m_webView.canGoForward ) [m_webView goForward];
}


- (IBAction)refreshButtonPressed:(id)button
{
	if ( m_webView.loading )
	{
		[self stopLoading];
	}
	else 
	{
		[m_webView reload];
	}
}


- (void)loadURL:(NSURL *)url
{
	if ( nil == url ) return;
	
	m_loadingInterrupted = NO;
	
	// cancel any transaction currently taking place
	if ( m_webView.loading ) [m_webView stopLoading];
	
	if ( nil != m_webView )
	{
		[m_webView loadRequest:[NSURLRequest requestWithURL:url]];
	}
	else
	{
		// do it this goofy way just in case (url == m_urlToLoad)
		[url retain];
		[m_urlToLoad release];
		m_urlToLoad = [[NSURL alloc] initWithString:[url absoluteString]];
		[url release];
	}
}


- (void)stopLoading
{
	if ( m_webView.loading )
	{
		[m_webView stopLoading];
		[m_activity stopAnimating];
	}
}


#pragma mark MiniBrowserController Private


- (void)enableBackButton:(BOOL)enable
{
	[m_backButton setEnabled:enable];
}


- (void)enableFwdButton:(BOOL)enable
{
	[m_fwdButton setEnabled:enable];
}


#pragma mark UIWebViewDelegate Methods 


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	// notify of an error?
	[m_toolBar setItems:m_normalItemList animated:NO];
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	[m_toolBar setItems:m_loadingItemList animated:NO];
	
	[m_activity startAnimating];
	
	// always start loading - we're not real restrictive here...
	return YES;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[m_toolBar setItems:m_normalItemList animated:NO];
	[m_activity stopAnimating];
	[self enableBackButton:m_webView.canGoBack];
	[self enableFwdButton:m_webView.canGoForward];
	
	// set the navigation bar title based on URL
	NSArray *urlComponents = [[[webView.request URL] absoluteString] componentsSeparatedByString:@"/"];
	if ( [urlComponents count] > 0 )
	{
		NSString *str = [urlComponents objectAtIndex:([urlComponents count]-1)];
		NSRange dot = [str rangeOfString:@"."];
		if ( dot.length > 0 )
		{
			self.title = [str substringToIndex:dot.location];
		}
		else
		{
			self.title = str;
		}
	}
	else
	{
		self.title = @"...";
	}
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[m_activity startAnimating];
	self.title = @"loading...";
}


- (void)webView:(UIWebView *)webView 
		decidePolicyForNavigationAction:(NSDictionary *)actionInformation 
		request:(NSURLRequest *)request 
		frame:(WebFrame *)frame 
		decisionListener:(id)listener
{
	// XXX - ?!?!
	return;
}


@end
