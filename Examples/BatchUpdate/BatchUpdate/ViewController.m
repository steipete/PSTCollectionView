
/*
     File: ViewController.m
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

#import "ViewController.h"
#import "Cell.h"


static NSInteger count;

@implementation ViewController

-(void)viewDidLoad
{
	[super viewDidLoad];
	
    self.sections = [[NSMutableArray alloc] initWithArray:
                    @[[NSMutableArray array]]];
    
    
    for(NSInteger i=0;i<25;i++)
        [self.sections[0] addObject:@(count++)];
    
    
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self.collectionView addGestureRecognizer:tapRecognizer];
    [self.collectionView registerClass:[Cell class] forCellWithReuseIdentifier:@"MY_CELL"];
    [self.collectionView reloadData];
    self.collectionView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];

    UIButton* button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(5, 10, 120, 50);
    button.tag = 1;
    [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"Insert & Delete" forState:UIControlStateNormal];
    [self.view addSubview:button];

    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(130, 10, 120, 50);
    button.tag = 2;
    [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"Move & Delete" forState:UIControlStateNormal];
    [self.view addSubview:button];

    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(255, 10, 120, 50);
    button.tag = 3;
    [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"Reload & Delete" forState:UIControlStateNormal];
    [self.view addSubview:button];

    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(380, 10, 230, 50);
    button.tag = 4;
    [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"Insert, Move, Reload & Delete" forState:UIControlStateNormal];
    [self.view addSubview:button];

    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(615, 10, 120, 50);
    button.tag = 5;
    [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"Reset" forState:UIControlStateNormal];
    [self.view addSubview:button];
}

-(NSInteger)numberOfSectionsInCollectionView:(PSTCollectionView *)collectionView
{
    return [self.sections count];
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    return [self.sections[section] count];
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    
    
    Cell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"MY_CELL" forIndexPath:indexPath];
    cell.label.text = [NSString stringWithFormat:@"%@", self.sections[indexPath.section][indexPath.item]];
    
    return (PSUICollectionViewCell *)cell;
}

- (void)handleTapGesture:(UITapGestureRecognizer *)sender {
    
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        CGPoint initialPinchPoint = [sender locationInView:self.collectionView];
        NSIndexPath* tappedCellPath = [self.collectionView indexPathForItemAtPoint:initialPinchPoint];
        if (tappedCellPath!=nil)
        {
            [self.sections[tappedCellPath.section] removeObjectAtIndex:tappedCellPath.item];
            [self.collectionView performBatchUpdates:^{
                [self.collectionView deleteItemsAtIndexPaths:@[tappedCellPath]];
                
            } completion:^(BOOL finished)
            {
                NSLog(@"delete finished");
            }];
        }
        else
        {
            NSInteger insertElements = 10;
            NSInteger deleteElements = 10;
            
            NSMutableSet* insertedIndexPaths = [NSMutableSet set];
            NSMutableSet* deletedIndexPaths = [NSMutableSet set];
            
            for(NSInteger i=0;i<deleteElements;i++)
            {
                NSInteger index = rand()%[self.sections[0] count];
                NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];
                
                if([deletedIndexPaths containsObject:indexPath])
                {
                    i--;
                    continue;
                }
                [self.sections[0] removeObjectAtIndex:index];
                [deletedIndexPaths addObject:indexPath];
            }

            for(NSInteger i=0;i<insertElements;i++)
            {
                NSInteger index = rand()%[self.sections[0] count];
                NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];
                if([insertedIndexPaths containsObject:indexPath])
                {
                    i--;
                    continue;
                }
                
                [self.sections[0] insertObject:@(count++)
                                    atIndex:index];
                [insertedIndexPaths addObject:indexPath];
            }

            
            

            [self.collectionView performBatchUpdates:^{
                
                
                [self.collectionView insertItemsAtIndexPaths:[insertedIndexPaths allObjects]];
                [self.collectionView deleteItemsAtIndexPaths:[deletedIndexPaths allObjects]];
                

            } completion:^(BOOL finished)
            {
                NSLog(@"insert finished");
            }];
        }
    }
}

- (void)handleButton:(UIButton *)button
{
    if (button.tag == 5)
    {
        count = 0;

        self.sections = [[NSMutableArray alloc] initWithArray:
                         @[[NSMutableArray array]]];

        for (NSInteger i=0; i<25; i++)
            [self.sections[0] addObject:@(count++)];

        [self.collectionView reloadData];
        return;
    }

    NSLog(@"before update %@", self.sections[0]);

    NSMutableSet* insertedIndexPaths = [NSMutableSet set];
    NSMutableSet* deletedIndexPaths = [NSMutableSet set];
    NSMutableSet* reloadedIndexPaths = [NSMutableSet set];
    NSMutableSet* movedFromIndexPaths = [NSMutableSet set];
    NSMutableSet* movedToIndexPaths = [NSMutableSet set];
    NSMutableArray* moveOperations = [NSMutableArray array];

    NSInteger insertElements = 3;
    NSInteger deleteElements = 3;
    NSInteger reloadElements = 3;
    NSInteger moveElements = 3;

    // delete some items
    for (NSInteger i=0;i<deleteElements;i++)
    {
        NSInteger index = rand()%[self.sections[0] count];
        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];

        if([deletedIndexPaths containsObject:indexPath])
        {
            i--;
            continue;
        }
        [self.sections[0] setObject:@(NSNotFound) atIndex:index];
        [deletedIndexPaths addObject:indexPath];
    }

    NSLog(@"after delete %@", self.sections[0]);

    // reload items
    if (button.tag == 3 || button.tag == 4) {
        for (NSInteger i=0;i<reloadElements;i++)
        {
            NSInteger index = rand()%[self.sections[0] count];
            NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];

            if([reloadedIndexPaths containsObject:indexPath]
               || ([[self.sections[0] objectAtIndex:index] intValue] == NSNotFound))
            {
                i--;
                continue;
            }

            [reloadedIndexPaths addObject:indexPath];
        }
    }

    // move items
    if (button.tag == 2 || button.tag == 4) {
        for (NSInteger i=0;i<moveElements;i++)
        {
            NSInteger fromIndex = rand()%[self.sections[0] count];
            NSInteger toIndex = rand()%([self.sections[0] count] - [deletedIndexPaths count]);

            NSIndexPath* fromIndexPath = [NSIndexPath indexPathForItem:fromIndex inSection:0];
            NSIndexPath* toIndexPath = [NSIndexPath indexPathForItem:toIndex inSection:0];

            NSLog(@"move match %d, %@ %@", fromIndex, [self.sections[0] objectAtIndex:fromIndex], @(NSNotFound));

            if([movedFromIndexPaths containsObject:fromIndexPath]
                   || [reloadedIndexPaths containsObject:fromIndexPath]
                   || [movedToIndexPaths containsObject:toIndexPath]
                || ([[self.sections[0] objectAtIndex:fromIndex] intValue] == NSNotFound))
            {
                i--;
                continue;
            }
            [movedFromIndexPaths addObject:fromIndexPath];
            [movedToIndexPaths addObject:toIndexPath];
            [moveOperations addObject:@[fromIndexPath, toIndexPath]];
        }

        for (NSArray *moveOp in moveOperations)
        {
            NSInteger fromIndex = [(NSIndexPath *)moveOp[0] item];
            NSInteger toIndex = [(NSIndexPath *)moveOp[1] item];

            id object = [self.sections[0] objectAtIndex:fromIndex];
            [self.sections[0] removeObjectAtIndex:fromIndex];
            [self.sections[0] insertObject:object atIndex:toIndex];
        }
    }

    for (NSUInteger i = [self.sections[0] count]; i >= 1; i--)
    {
        if([[self.sections[0] objectAtIndex:i - 1] integerValue] != NSNotFound)
        {
            continue;
        }
        [self.sections[0] removeObjectAtIndex:i - 1];
    }

    NSLog(@"after move %@", self.sections[0]);

    // insert items
    if (button.tag == 1 || button.tag == 4) {
        for(NSInteger i=0;i<insertElements;i++)
        {
            NSInteger index = rand()%[self.sections[0] count];
            NSIndexPath* indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            if([insertedIndexPaths containsObject:indexPath])
            {
                i--;
                continue;
            }

            [self.sections[0] insertObject:@(count++)
                                   atIndex:index];
            [insertedIndexPaths addObject:indexPath];
        }
    }

    [self.collectionView performBatchUpdates:^{
        NSLog(@"inserts %@", insertedIndexPaths);
        NSLog(@"deletes %@", deletedIndexPaths);
        NSLog(@"reloads %@", reloadedIndexPaths);
        NSLog(@"moves %@", moveOperations);
        NSLog(@"expected %@", self.sections[0]);

        [self.collectionView insertItemsAtIndexPaths:[insertedIndexPaths allObjects]];
        [self.collectionView deleteItemsAtIndexPaths:[deletedIndexPaths allObjects]];
        [self.collectionView reloadItemsAtIndexPaths:[reloadedIndexPaths allObjects]];

        for (NSArray *moveOp in moveOperations)
        {
            [self.collectionView moveItemAtIndexPath:moveOp[0] toIndexPath:moveOp[1]];
        }

    } completion:^(BOOL finished)
     {
         NSLog(@"change finished");
     }];
}

@end
