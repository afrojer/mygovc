//
//  BillSummaryTableCell.h
//  myGovernment
//
//  Created by Jeremy C. Andrus on 4/2/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BillContainer;

@interface BillSummaryTableCell : UITableViewCell 
{
@private
	BillContainer *m_bill;
	NSRange m_tableRange;
}

@property (readonly) BillContainer *m_bill;
@property (nonatomic) NSRange m_tableRange;

+ (CGFloat)getCellHeightForBill:(BillContainer *)bill;

- (void)setDetailTarget:(id)target andSelector:(SEL)selector;

- (void)setContentFromBill:(BillContainer *)container;


@end
