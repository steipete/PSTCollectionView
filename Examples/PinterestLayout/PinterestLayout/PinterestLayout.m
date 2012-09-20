
/*
     File: PinterestLayout.m
 Abstract: 
 
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 
 WWDC 2012 License
 
 NOTE: This Apple Software was supplied by Apple as part of a WWDC 2012
 Session. Please refer to the applicable WWDC 2012 Session for further
 information.
 
 IMPORTANT: This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a non-exclusive license, under
 Apple's copyrights in this original Apple software (the "Apple
 Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "PinterestLayout.h"
#import "PSCollectionViewCell.h"
#import "PSBroView.h"

#define kMargin 8.0
#define ITEM_SIZE 70

@interface PinterestLayout()

@property (nonatomic, assign, readwrite) CGFloat colWidth;
@property (nonatomic, assign, readwrite) NSInteger numCols;
@property (nonatomic, assign, readwrite) CGFloat totalHeight;
@property (nonatomic, assign) UIInterfaceOrientation orientation;
@property (nonatomic, strong) NSMutableDictionary *indexToRectMap;

@end

@implementation PinterestLayout

-(void)prepareLayout
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [super prepareLayout];
    
    // demo?
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.numColsPortrait = 4;
        self.numColsLandscape = 5;
    } else {
        self.numColsPortrait = 2;
        self.numColsLandscape = 3;
    }
        
    CGSize size = self.collectionView.frame.size;
    self.orientation = [UIApplication sharedApplication].statusBarOrientation;
    self.numCols = UIInterfaceOrientationIsPortrait(self.orientation) ? self.numColsPortrait : self.numColsLandscape;
    
    NSLog(@"self.numCols= %d", self.numCols);
    
    _cellCount = [[self collectionView] numberOfItemsInSection:0];
    _center = CGPointMake(size.width / 2.0, size.height / 2.0);
    _radius = MIN(size.width, size.height) / 2.5;
    
    _totalHeight = 0.0;
    CGFloat top = kMargin;

    if (_cellCount > 0) {
        
        self.indexToRectMap = [NSMutableDictionary dictionary];

        // This array determines the last height offset on a column
        NSMutableArray *colOffsets = [NSMutableArray arrayWithCapacity:self.numCols];
        for (int i = 0; i < self.numCols; i++) {
            [colOffsets addObject:@(top)];
        }
        
        // Calculate index to rect mapping
        self.colWidth = floorf((self.collectionView.frame.size.width - kMargin * (self.numCols + 1)) / self.numCols);
        for (NSInteger i = 0; i < _cellCount; i++) {
            
            // Find the shortest column
            NSInteger col = 0;
            CGFloat minHeight = [[colOffsets objectAtIndex:col] floatValue];
            for (int i = 1; i < [colOffsets count]; i++) {
                CGFloat colHeight = [[colOffsets objectAtIndex:i] floatValue];
                
                if (colHeight < minHeight) {
                    col = i;
                    minHeight = colHeight;
                }
            }
            
            NSLog(@"colOffsets = %@", colOffsets);
            
            CGFloat left = kMargin + (col * kMargin) + (col * self.colWidth);
            CGFloat top = [[colOffsets objectAtIndex:col] floatValue];
            CGFloat colHeight = [self heightForViewAtIndex:i];
            if (colHeight == 0) {
                colHeight = self.colWidth;
            }
            
            if (top != top) {
                // NaN
            }
            
            CGRect viewRect = CGRectMake(left, top, self.colWidth, colHeight);
            
            // Add to index rect map
            [self.indexToRectMap setObject:NSStringFromCGRect(viewRect) forKey:@(i)];
            
            // Update the last height offset for this column
            CGFloat test = top + colHeight + kMargin;
            
            if (test != test) {
                // NaN
            }
            [colOffsets replaceObjectAtIndex:col withObject:[NSNumber numberWithFloat:test]];
        }
        
        for (NSNumber *colHeight in colOffsets) {
            _totalHeight = (_totalHeight < [colHeight floatValue]) ? [colHeight floatValue] : _totalHeight;
        }
    }

}

-(CGSize)collectionViewContentSize
{
    return CGSizeMake(self.collectionView.frame.size.width, _totalHeight);
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path
{
    UICollectionViewLayoutAttributes* attributes = (UICollectionViewLayoutAttributes*)[PSTCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
    attributes.frame = CGRectFromString([self.indexToRectMap objectForKey:@(path.item)]);
    NSLog(@"attributes.frame = %@", [self.indexToRectMap objectForKey:@(path.item)]);
    return attributes;
}

-(NSArray*)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray* attributes = [NSMutableArray array];
    for (NSInteger i=0 ; i < self.cellCount; i++) {
        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        [attributes addObject:[self layoutAttributesForItemAtIndexPath:indexPath]];
    }    
    return attributes;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForInsertedItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    UICollectionViewLayoutAttributes* attributes = (UICollectionViewLayoutAttributes *)[self layoutAttributesForItemAtIndexPath:itemIndexPath];
    attributes.alpha = 0.0;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDeletedItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    UICollectionViewLayoutAttributes* attributes = (UICollectionViewLayoutAttributes *)[self layoutAttributesForItemAtIndexPath:itemIndexPath];
    attributes.alpha = 0.0;
    return attributes;
}

- (CGFloat)heightForViewAtIndex:(NSInteger)index {
    //PSCollectionViewCell* cell = (PSCollectionViewCell* )[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
    //return [PSBroView heightForViewWithObject:cell.object inColumnWidth:self.colWidth];
    
    return 100.0f +round(arc4random()/1000000000*50.0f);
}


@end
