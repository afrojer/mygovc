//
//  CommunityItemVTabelCell.m
//  myGovernment
//
//  Created by Wesley Morgan on 2/28/09.
//  Copyright 2009 U.S. PIRG. All rights reserved.
//

#import "CommunityItem.h"
#import "CommunityItemTableCell.h"


@interface CommunityItemTableCell (private)
	- (void)updateLayout;
@end


@implementation CommunityItemTableCell

@synthesize m_item;

enum
{
	eTAG_DETAIL     = 999,
	eTAG_TITLE      = 998,
};

static const CGFloat S_CELL_HOFFSET = 7.0f;
static const CGFloat S_CELL_VOFFSET = 2.0f;
static const CGFloat S_TABLE_TITLE_WIDTH = 20.0f;
static const CGFloat S_PLACE_TEXT_WIDTH = 120.0f;


+ (CGFloat)getCellHeightForItem:(CommunityItem *)item
{
/**
	NSString *descrip = bill.m_title;
	CGSize descripSz = [descrip sizeWithFont:D_DESCRIP_FONT 
						   constrainedToSize:CGSizeMake(320.0f - (3.0f*S_CELL_HPADDING) - 32.0f,S_DESCRIP_HEIGHT + S_ROW_HEIGHT) 
							   lineBreakMode:UILineBreakModeWordWrap];
	
	CGFloat height = S_ROW_HEIGHT + S_CELL_VPADDING + // bill number + sponsor
	descripSz.height + S_CELL_VPADDING + // bill title/descrip
	S_ROW_HEIGHT + S_CELL_VPADDING;   // status
	return height;
**/
	return 40.0f;
}



- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)identifier
{
	if ( self = [super initWithFrame:frame reuseIdentifier:identifier] ) 
	{
		m_item = nil;
		self.selectionStyle = UITableViewCellSelectionStyleGray;
		
		// 
		// Detail button (next to table index)
		// 
		UIButton *detail = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
		[detail setTag:eTAG_DETAIL];
		[self addSubview:detail];
		
		UILabel *titleView = [[UILabel alloc] initWithFrame:CGRectZero];
		titleView.backgroundColor = [UIColor clearColor];
		titleView.textColor = [UIColor blackColor];
		titleView.font = [UIFont boldSystemFontOfSize:18.0f];
		titleView.textAlignment = UITextAlignmentLeft;
		titleView.adjustsFontSizeToFitWidth = YES;
		[titleView setTag:eTAG_TITLE];
		[self addSubview:titleView];
		[titleView release];
		
	}
	return self;
}


- (void)dealloc 
{
	[m_item release];
	[super dealloc];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated 
{
	[super setSelected:selected animated:animated];

/**
	UILabel *billNumView = (UILabel *)[self viewWithTag:eTAG_BILLNUM];
	[billNumView setHighlighted:selected];
**/
}


- (void)setDetailTarget:(id)target andSelector:(SEL)selector
{
	UIButton *detail = (UIButton *)[self viewWithTag:eTAG_DETAIL];
	
	// set delegate for detail button press!
	[detail addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
}


- (void)setCommunityItem:(CommunityItem *)newItem 
{
	if ( m_item != newItem ) 
	{
		[m_item release];
		m_item = [newItem retain];
	}
	[self updateLayout];
	[self setNeedsDisplay];
}


#pragma mark CommunityItemTableCell Private 


- (void)updateLayout
{
	// 
	// Do something dumb for now... 
	// 
	
	UIButton *detailButton = (UIButton *)[self viewWithTag:eTAG_DETAIL];
	CGRect detailRect = CGRectMake( 320.0f - CGRectGetWidth(detailButton.frame),
								   0.0f + (40.0f - CGRectGetHeight(detailButton.frame))/2.0f,
								   CGRectGetWidth(detailButton.frame),
								   CGRectGetHeight(detailButton.frame) );
	[detailButton setFrame:detailRect];
	
	UILabel *titleView = (UILabel *)[self viewWithTag:eTAG_TITLE];
	[titleView setFrame:CGRectMake(7.0f, 7.0f, 280.0f, 30.0f)];
	titleView.text = m_item.m_title;
	
	//[self setImage:m_item.m_image];
}


@end
