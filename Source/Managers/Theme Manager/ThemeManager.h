//
//  ThemeManager.h
//  xkcd Open Source
//
//  Created by Mike on 5/15/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString * const kXKCDFontName = @"xkcd-Regular";

static NSString * const kDefaultLoadingImageName = @"loading";
static NSString * const kRandomImageName1 = @"r1";
static NSString * const kRandomImageName2 = @"r2";
static NSString * const kRandomImageName3 = @"r3";
static NSString * const kRandomImageName4 = @"r4";
static NSString * const kRandomImageName5 = @"r5";
static NSString * const kRandomImageName6 = @"r6";
static NSString * const kDefaultRandomImageName = @"r1";
static NSString * const kDefaultBackImageName = @"back";
static NSString * const kDefaultFavoriteImageName = @"favorite";

static CGFloat const kDefaultXKCDTitleFontSize = 22.0;
static CGFloat const kDefaultSearchBarFontSize = 12.0;

static CGFloat const kDefaultCornerRadius = 7.0;
static CGFloat const kDefaultBorderWidth = 1.25;

static CGFloat const kDefaultParallaxValue = 10.0;

@interface ThemeManager : NSObject

+ (void)setupTheme;

+ (UIFont *)xkcdFontWithSize:(CGFloat)size;

+ (UIColor *)xkcdLightBlue;
+ (UIColor *)comicViewedColor;

+ (UIImage *)loadingImage;
+ (UIImage *)randomImage;
+ (UIImage *)backImage;
+ (UIImage *)favoriteImage;

+ (void)addBorderToLayer:(CALayer *)layer radius:(CGFloat)radius color:(UIColor *)color;
+ (void)addShadowToLayer:(CALayer *)layer radius:(CGFloat)radius opacity:(CGFloat)opacity;

+ (void)addParallaxToView:(UIView *)view;

@end
