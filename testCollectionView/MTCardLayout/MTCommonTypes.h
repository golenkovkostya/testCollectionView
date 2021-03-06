#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MTCardLayoutViewMode) {
    MTCardLayoutViewModeDefault,
    MTCardLayoutViewModePresenting
};

typedef struct
{
    // Insets of the fullscreen card
    UIEdgeInsets presentingInsets;
    
    // Insets of the list
    UIEdgeInsets listingInsets;
    
    // Top flexible inset
    CGFloat flexibleTop;
    
    // height for section header
    CGFloat headerHeight;
    
    // visible height for section bottom card
    CGFloat bottomCardVisibleHeight;
    
    // The visible size of each card in the normal stack
    CGFloat minimumVisibleHeight;
    // The visible size of each card in the bottom stack
    CGFloat stackedVisibleHeight;
    // Max number of card to show at the bottom stack
    NSUInteger maxStackedCards;
    
    // This value is calculated internally
    CGFloat visibleHeight;
} MTCardLayoutMetrics;


typedef struct
{
    /// How much of the pulling is translated into movement on the top. An inheritance of 0 disables this feature (same as bouncesTop)
    CGFloat inheritance;
    
    /// Allows for bouncing when reaching the top
    BOOL bouncesTop;
    
} MTCardLayoutEffects;
