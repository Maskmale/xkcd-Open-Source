//
//  ComicListViewController.m
//  xkcd Open Source
//
//  Created by Mike on 5/14/15.
//  Copyright (c) 2015 Mike Amaral. All rights reserved.
//

#import "ComicListViewController.h"
#import <UIView+Facade.h>
#import "ThemeManager.h"
#import "LoadingView.h"
#import "Comic.h"
#import "ComicCell.h"
#import "ComicWebViewController.h"
#import "AltView.h"
#import "ComicListPresenter.h"

static NSString * const kComicListTitle = @"xkcd: Open Source";
static NSString * const kComicListFavoritesTitle = @"Favorites";
static NSString * const kComicListUnreadTitle = @"Unread";
static NSString * const kNoSearchResultsMessage = @"No results found...";
static NSString * const kNoFavoritesMessage = @"You have no favorites yet!";

@interface ComicListViewController () <ComicListFlowLayoutDelegate, ComicViewControllerDelegate, UISearchBarDelegate, ComicCellDelegate, ComicListView>

@property (nonatomic, strong) RLMResults *comics;

@property (nonatomic, strong) UIBarButtonItem *searchButton;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *noResultsLabel;

@property (nonatomic, strong) AltView *altView;

@property (nonatomic, strong) ComicListPresenter *presenter;

@end

@implementation ComicListViewController

- (instancetype)init {
    ComicListFlowLayout *comicListLayout = [ComicListFlowLayout new];
    comicListLayout.delegate = self;
    self = [super initWithCollectionViewLayout:comicListLayout];

    if (!self) {
        return nil;
    }

    self.presenter = [[ComicListPresenter alloc] initWithView:self];;
    self.comics = [self.presenter getSavedComicList];
    
    return self;
}


#pragma mark - View life cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = kComicListTitle;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationController.navigationBar.backIndicatorImage = [ThemeManager backImage];
    self.navigationController.navigationBar.backIndicatorTransitionMaskImage = [ThemeManager backImage];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.collectionView.backgroundColor = [ThemeManager xkcdLightBlue];
    [self.collectionView registerClass:[ComicCell class] forCellWithReuseIdentifier:kComicCellReuseIdentifier];

    self.altView = [AltView new];
    self.altView.alpha = 0.0;

    self.searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(toggleSearch)];
    self.navigationItem.leftBarButtonItem = self.searchButton;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"..." style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
    self.searchBar = [UISearchBar new];
    self.searchBar.delegate = self;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;

    self.noResultsLabel = [UILabel new];
    self.noResultsLabel.hidden = YES;
    self.noResultsLabel.text = kNoSearchResultsMessage;
    self.noResultsLabel.font = [ThemeManager xkcdFontWithSize:18];
    self.noResultsLabel.textColor = [UIColor blackColor];
    self.noResultsLabel.textAlignment = NSTextAlignmentCenter;
    [self.collectionView addSubview:self.noResultsLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // If our presenter tells us an initial load is required, disable the navigation buttons
    // and tell it to handle the initial load.
    if ([self.presenter isInitialLoadRequired]) {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        [self.presenter handleInitialLoad];
    }
}


#pragma mark - Layout

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    // Layout the loading view if it's visible.
    if ([LoadingView isVisible]) {
        [LoadingView handleLayoutChanged];
    }

    // Layout the no-results label if it's visible.
    if (!self.noResultsLabel.isHidden) {
        [self.noResultsLabel anchorTopCenterFillingWidthWithLeftAndRightPadding:15 topPadding:15 height:20];
    }
}


#pragma mark - Actions

- (void)showMenu {
    // Cancel searching if we were.
    if (self.presenter.isSearching) {
        [self cancelSearch];
    }

    UIAlertAction *viewAll = [UIAlertAction actionWithTitle:@"View All Comics" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.presenter handleShowAllComics];
    }];

    UIAlertAction *viewUnread = [UIAlertAction actionWithTitle:@"View All Unread" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.presenter toggleUnread];
    }];

    UIAlertAction *toggleFavs = [UIAlertAction actionWithTitle:@"View Favorites" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.presenter toggleFilterFavorites];
    }];

    UIAlertAction *viewRandom = [UIAlertAction actionWithTitle:@"View Random Comic" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showRandomComic];
    }];

    UIAlertAction *viewBookmark = [UIAlertAction actionWithTitle:@"View Bookmarked Comic" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self viewBookmark];
    }];

    UIAlertAction *clearCache = [UIAlertAction actionWithTitle:@"Clear Cache" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self showClearCacheConfirmation];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // Allow them to view all if we're filtering in any way.
    if (self.presenter.isFilteringUnread || self.presenter.isFilteringFavorites) {
        [alertController addAction:viewAll];
    }
    // Allow them to view unread if we're not already.
    if (!self.presenter.isFilteringUnread) {
        [alertController addAction:viewUnread];
    }

    // Allow them to view favorites if we're not already and they have favorites.
    if (!self.presenter.isFilteringFavorites && [self.presenter hasFavorites]) {
        [alertController addAction:toggleFavs];
    }

    [alertController addAction:viewRandom];

    // Allow them to view bookmarked comic if they have one.
    if ([self.presenter bookmarkedComic]) {
        [alertController addAction:viewBookmark];
    }

    // Always allow to clear cache and cancel.
    [alertController addAction:clearCache];
    [alertController addAction:cancel];

    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}

- (void)viewBookmark {
    Comic *bookmarkedComic = [self.presenter bookmarkedComic];
    [self showComic:bookmarkedComic];
}

- (void)showClearCacheConfirmation {
    UIAlertAction *clearCache = [UIAlertAction actionWithTitle:@"Clear Cache" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.presenter handleClearCache];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Are you sure?" message:@"This will set all comics as unread, reset all favorites, and clear your bookmark if you have one set." preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:clearCache];
    [alertController addAction:cancel];

    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}

- (void)showComic:(Comic *)comic {
    ComicViewController *comicVC = [ComicViewController new];
    comicVC.delegate = self;
    comicVC.allowComicNavigation = !self.presenter.isSearching && !self.presenter.isFilteringFavorites;
    comicVC.comic = comic;
    [self.navigationController pushViewController:comicVC animated:YES];
}

- (void)showRandomComic {
    Comic *randomComic = [self.presenter randomComic];
    [self showComic:randomComic];
}


#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.comics.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ComicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kComicCellReuseIdentifier forIndexPath:indexPath];
    cell.comic = self.comics[indexPath.item];
    cell.delegate = self;
    return cell;
}


#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];

    // If we should show this comic as interactive, use the web view controller, otherwise
    // use the normal comic presentation method.
    if ([self.presenter shouldShowComicAsInteractive:comic]) {
        ComicWebViewController *comicWebVC = [ComicWebViewController new];
        comicWebVC.comic = comic;
        [self.navigationController pushViewController:comicWebVC animated:YES];
    } else {
        [self showComic:comic];
    }
}


#pragma mark - Layout delegate

- (CGFloat)collectionView:(UICollectionView *)collectionView relativeHeightForItemAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];
    CGFloat aspectRatio = comic.aspectRatio;
    return 1.0 / aspectRatio;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldBeDoubleColumnAtIndexPath:(NSIndexPath *)indexPath {
    Comic *comic = self.comics[indexPath.item];
    CGFloat aspectRatio = comic.aspectRatio;
    return aspectRatio > 1.0;
}

- (NSUInteger)numberOfColumnsInCollectionView:(UICollectionView *)collectionView {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isLandscape = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation);
    
    if (isPad) {
        return isLandscape ? 6 : 4;
    } else {
        return isLandscape ? 4 : 2;
    }
}


#pragma mark - Comic view controller delegate

- (Comic *)comicViewController:(ComicViewController *)comicViewController comicBeforeCurrentComic:(Comic *)currentComic {
    NSInteger indexOfCurrentComic = [self.comics indexOfObject:currentComic];

    return (indexOfCurrentComic != NSNotFound && indexOfCurrentComic > 0) ? self.comics[indexOfCurrentComic - 1] : nil;
}

- (Comic *)comicViewController:(ComicViewController *)comicViewController comicAfterCurrentComic:(Comic *)currentComic {
    NSInteger indexOfCurrentComic = [self.comics indexOfObject:currentComic];

    return (indexOfCurrentComic != NSNotFound && indexOfCurrentComic + 1 <= self.comics.count - 1) ? self.comics[indexOfCurrentComic + 1] : nil;
}

- (Comic *)comicViewController:(ComicViewController *)comicViewController randomComic:(Comic *)currentComic {
    return [self.presenter randomComic];
}


#pragma mark - Searching and Filtering

- (void)toggleSearch {
    if (!self.presenter.isSearching) {
        [self.presenter handleSearchBegan];

        [self.searchBar becomeFirstResponder];

        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 40.0)];

        UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelSearch)];

        [toolbar setItems:@[spacer, cancel]];
        self.searchBar.inputAccessoryView = toolbar;

        self.navigationItem.titleView = self.searchBar;
    } else {
        [self cancelSearch];
    }
}

- (void)cancelSearch {
    // Clear the search text, dismiss the keyboard, clear the title view, and
    // tell the presenter to cancel.
    self.searchBar.text = nil;
    [self.searchBar resignFirstResponder];

    self.navigationItem.titleView = nil;

    [self.presenter cancelSearch];
}


#pragma mark - Comic cell delegate

- (void)comicCell:(ComicCell *)cell didSelectComicAltWithComic:(Comic *)comic {
    if (!self.altView.isVisible) {
        self.altView.comic = comic;
        [self.altView showInView:self.view];
    } else {
        self.altView.comic = nil;
        [self.altView dismiss];
    }
}


#pragma mark - UISearchBar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];

    // Scroll to the top now that results will be changing.
    [self.collectionView setContentOffset:CGPointZero animated:YES];

    // Tell our presenter to search.
    [self.presenter searchForComicsWithText:searchBar.text];
}


#pragma mark - Comic view protocol

- (void)didStartLoadingComics {
    [LoadingView showInView:self.view];
}

- (void)didFinishLoadingComics {
    [LoadingView handleDoneLoading];

    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)comicListDidChange:(RLMResults *)comicList {
    // Update our data source and reload the collection view.
    self.comics = comicList;
    [self.collectionView reloadData];

    // If we're filtering favorites, update our title
    if (self.presenter.isFilteringFavorites) {
        self.title = kComicListFavoritesTitle;
    } else if (self.presenter.isFilteringUnread) {
        self.title = kComicListUnreadTitle;
    } else if (self.presenter.isSearching) {
        self.noResultsLabel.hidden = self.comics.count > 0;
    } else {
        self.title = kComicListTitle;
    }
}

- (void)didEncounterLoadingError {

}

@end
