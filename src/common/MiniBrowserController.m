/*
 File: MiniBrowserController.m
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
#import "MiniBrowserController.h"

@interface MiniBrowserController (private)
	- (void)animate;
	- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void *)context;
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
@synthesize m_shouldUseParentsView;

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
		//s_browser.m_webView.detectsPhoneNumbers = YES;
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
		m_urlRequestToLoad = nil;
		m_activity = nil;
		m_loadingLabel = nil;
		m_parentCtrl = nil;
		m_shouldUseParentsView = NO;
		m_shouldDisplayOnViewLoad = NO;
		m_normalItemList = nil;
		m_loadingItemList = nil;
		m_authCallback = nil;
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
	[m_urlRequestToLoad release];
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
	CGRect lblFrame = CGRectMake( CGRectGetMaxX(actFrame) + 6.0f,
								  CGRectGetMinY(actFrame) - 4.0f,
								  120.0f, 40.0f
	                            );
	m_activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	[m_activity setFrame:actFrame];
	m_activity.hidesWhenStopped = YES;
	[self.m_webView addSubview:m_activity];
	[m_activity release];
	[m_activity stopAnimating];
	
	m_loadingLabel = [[UILabel alloc] init];
	[m_loadingLabel setFrame:lblFrame];
	//m_loadingLabel.backgroundColor = [UIColor colorWithRed:0.55f green:0.55f blue:0.55f alpha:0.40f];
	m_loadingLabel.backgroundColor = [UIColor clearColor];
	m_loadingLabel.highlightedTextColor = [UIColor darkGrayColor];
	m_loadingLabel.textColor = [UIColor blackColor];
	m_loadingLabel.font = [UIFont boldSystemFontOfSize:14.0f];
	m_loadingLabel.textAlignment = UITextAlignmentLeft;
	m_loadingLabel.adjustsFontSizeToFitWidth = YES;
	m_loadingLabel.text = @"Loading...";
	[self.m_webView addSubview:m_loadingLabel];
	[m_loadingLabel release];
	[m_loadingLabel setHidden:YES];
	
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
}


- (void)viewDidAppear:(BOOL)animated 
{
	[super viewDidAppear:animated];
	
	if ( nil != m_urlRequestToLoad )
	{
		[self LoadRequest:m_urlRequestToLoad];
		[m_urlRequestToLoad release]; m_urlRequestToLoad = nil;
	}
	else if ( m_loadingInterrupted )
	{
		[m_webView reload];
	}
	m_loadingInterrupted = NO;
	
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
	
	[[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
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
	m_authCallback = nil;
	if ( nil != m_webView )
	{
		//[m_parentCtrl presentModalViewController:self animated:NO];
		[self animate];
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
	//[m_parentCtrl dismissModalViewControllerAnimated:YES];
	[self animate];
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
	
	if ( [self.view isHidden] )
	{
		[m_urlRequestToLoad release];
		m_urlRequestToLoad = [[NSURLRequest alloc] initWithURL:url];
	}
	else
	{
		[m_webView loadRequest:[NSURLRequest requestWithURL:url]];
	}
}


- (void)LoadRequest:(NSURLRequest *)urlRequest
{
	m_loadingInterrupted = NO;
	
	// cancel any transaction currently taking place
	if ( m_webView.loading ) [m_webView stopLoading];
	
	if ( [self.view isHidden] )
	{
		// do it this goofy way just in case (url == m_urlRequestToLoad)
		[urlRequest retain];
		[m_urlRequestToLoad release];
		m_urlRequestToLoad = [[NSURLRequest alloc] initWithURL:[urlRequest URL]];
		[urlRequest release];
	}
	else
	{
		[m_webView loadRequest:urlRequest];
	}
}


- (void)stopLoading
{
	if ( m_webView.loading )
	{
		[m_webView stopLoading];
		[m_activity stopAnimating];
		[m_loadingLabel setHidden:YES];
	}
}


- (void)setAuthCallback:(SEL)callback
{
	m_authCallback = callback;
}


- (void)authCompleteCallback
{
	// remove ourself from the view stack
	// once authentication is complete
	if ( [self.view superview] )
	{
		[self animate];
	}
	
	// do the auth-callback if requested
	if ( nil != m_authCallback )
	{
		if ( [m_parentCtrl respondsToSelector:m_authCallback] )
		{
			[m_parentCtrl performSelector:m_authCallback];
		}
	}
}


#pragma mark MiniBrowserController Private

- (void)animate
{
	
	UIView *topView;
	if ( m_shouldUseParentsView )
	{
		topView = [m_parentCtrl view];
		if ( nil == topView )
		{
			topView = [[myGovAppDelegate sharedAppDelegate] topView];
		}
	}
	else
	{
		topView = [[myGovAppDelegate sharedAppDelegate] topView];
	}
	
	m_shouldUseParentsView = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5f];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationFinished:finished:context:)];
	
	if ( [self.view superview] )
	{
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:topView cache:NO];
		[self.view removeFromSuperview];
		/*
		if ( [myGovAppDelegate OSVersion] >= 3.0 )
		{
			[[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
		}
		*/
	}
	else
	{
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:topView cache:NO];
		[topView addSubview:self.view];
		[self.view setFrame:CGRectMake(0.0f,20.0f,320.0f,460.0f)];
		/*
		if ( [myGovAppDelegate OSVersion] >= 3.0 )
		{
			[self.view setFrame:CGRectMake(0.0f,0.0f,320.0f,480.0f)];
			[[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];
		}
		else
		{
			[self.view setFrame:CGRectMake(0.0f,0.0f,320.0f,460.0f)];
		}
		*/
	}
	
	[UIView commitAnimations];
}

- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void *)context
{
}


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
	[m_loadingLabel setHidden:NO];
	[m_webView setAlpha:0.75f];
	
	// always start loading - we're not real restrictive here...
	return YES;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[m_toolBar setItems:m_normalItemList animated:NO];
	[m_activity stopAnimating];
	[m_loadingLabel setHidden:YES];
	[m_webView setAlpha:1.0f];
	
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
	[m_loadingLabel setHidden:NO];
	[m_webView setAlpha:0.75f];
	
	self.title = @"loading...";
}


@end
