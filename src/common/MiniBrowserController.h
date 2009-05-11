//
//  MiniBrowserController.h
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/6/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface MiniBrowserController : UIViewController <UIWebViewDelegate>
{
	IBOutlet UIToolbar *m_toolBar;
	IBOutlet UIWebView *m_webView;
	IBOutlet UIBarButtonItem *m_backButton;
	IBOutlet UIBarButtonItem *m_reloadButton;
	IBOutlet UIBarButtonItem *m_fwdButton;
	
	BOOL m_shouldStopLoadingOnHide;
	BOOL m_shouldUseParentsView;
@private
	BOOL m_loadingInterrupted;
	NSURLRequest *m_urlRequestToLoad;
	
	UIActivityIndicatorView *m_activity;
	UILabel                 *m_loadingLabel;
	
	NSArray *m_normalItemList;
	NSArray *m_loadingItemList;
	
	BOOL m_shouldDisplayOnViewLoad;
	id m_parentCtrl;
	SEL m_authCallback;
}

@property (nonatomic,retain) IBOutlet UIToolbar *m_toolBar;
@property (nonatomic,retain) IBOutlet UIWebView *m_webView;
@property (nonatomic) BOOL m_shouldUseParentsView;
@property (nonatomic) BOOL m_shouldStopLoadingOnHide;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *m_backButton;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *m_reloadButton;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *m_fwdButton;

+ (MiniBrowserController *)sharedBrowser;
+ (MiniBrowserController *)sharedBrowserWithURL:(NSURL *)urlOrNil;

- (void)display:(id)parentController;

- (IBAction)closeButtonPressed:(id)button;
- (IBAction)backButtonPressed:(id)button;
- (IBAction)fwdButtonPressed:(id)button;
- (IBAction)refreshButtonPressed:(id)button;

- (void)loadURL:(NSURL *)url;
- (void)LoadRequest:(NSURLRequest *)urlRequest;
- (void)stopLoading;

- (void)setAuthCallback:(SEL)callback;
- (void)authCompleteCallback;

@end
