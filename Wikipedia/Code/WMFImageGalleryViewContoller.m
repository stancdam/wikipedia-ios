
#import "WMFImageGalleryViewContoller.h"
#import "MWKArticle.h"
#import "MWKImageList.h"
#import "MWKImage.h"
#import "MWKImageInfo.h"
#import "MWKDataStore.h"
#import "NSArray+WMFLayoutDirectionUtilities.h"
#import "Wikipedia-Swift.h"
#import "UIImage+WMFStyle.h"
#import "UIColor+WMFStyle.h"
#import "MWKImageInfoFetcher+PicOfTheDayInfo.h"
#import "UIViewController+WMFOpenExternalUrl.h"
#import "WMFImageGalleryDetailOverlayView.h"
#import "UIView+WMFDefaultNib.h"

@import FLAnimatedImage;

NS_ASSUME_NONNULL_BEGIN

@interface WMFGalleryImage : NSObject <NYTPhoto>

//used to fetch imageInfo
@property (nonatomic, strong, nullable) NSDate* potdDate;

//set to display a thumbnail during download
@property (nonatomic, strong, nullable) MWKImage* thumbnailImageObject;

//set to display a thumbnail during download
@property (nonatomic, strong, nullable) MWKImageInfo* thumbnailImageInfo;

//used to fetch the full size image
@property (nonatomic, strong, nullable) MWKImage* imageObject;

//used for metadaata
@property (nonatomic, strong, nullable) MWKImageInfo* imageInfo;

@end

@implementation WMFGalleryImage

+ (NSArray<WMFGalleryImage*>*)galleryImagesWithImageObjects:(NSArray<MWKImage*>*)imageObjects {
    return [imageObjects bk_map:^id (MWKImage* obj) {
        return [[WMFGalleryImage alloc] initWithImage:obj];
    }];
}

+ (NSArray<WMFGalleryImage*>*)galleryImagesWithDates:(NSArray<NSDate*>*)dates {
    return [dates bk_map:^id (NSDate* obj) {
        return [[WMFGalleryImage alloc] initWithPOTDDate:obj];
    }];
}

- (instancetype)initWithImage:(MWKImage*)imageObject {
    self = [super init];
    if (self) {
        self.imageObject = imageObject;
    }
    return self;
}

- (instancetype)initWithThumbnailImageInfo:(MWKImageInfo*)imageInfo {
    self = [super init];
    if (self) {
        self.thumbnailImageInfo = imageInfo;
    }
    return self;
}

- (instancetype)initWithPOTDDate:(NSDate*)date {
    self = [super init];
    if (self) {
        self.potdDate = date;
    }
    return self;
}

- (nullable UIImage*)placeholderImage {
    NSURL* url = [self thumbnailImageURL];
    if (url) {
        return [[WMFImageController sharedInstance] syncCachedImageWithURL:url];
    } else {
        return nil;
    }
}

- (nullable NSURL*)thumbnailImageURL {
    if (self.thumbnailImageObject) {
        return self.thumbnailImageObject.sourceURL;
    } else if (self.thumbnailImageInfo) {
        return self.thumbnailImageInfo.imageThumbURL;
    } else {
        return nil;
    }
}

- (nullable UIImage*)image {
    NSURL* url = [self imageURL];
    if (url) {
        return [[WMFImageController sharedInstance] syncCachedImageWithURL:url];
    } else {
        return nil;
    }
}

- (nullable UIImage*)memoryCachedImage {
    NSURL* url = [self imageURL];
    if (url) {
        return [[WMFImageController sharedInstance] cachedImageInMemoryWithURL:url];
    } else {
        return nil;
    }
}

- (nullable NSURL*)imageURL {
    if (self.imageObject) {
        return self.imageObject.sourceURL;
    } else if (self.imageInfo) {
        return self.imageInfo.imageThumbURL;
    } else {
        return nil;
    }
}

- (nullable NSData*)imageData {
    return nil;
}

- (nullable NSAttributedString*)attributedCaptionTitle {
    return nil;
}

- (nullable NSAttributedString*)attributedCaptionSummary {
    if (self.imageInfo.imageDescription) {
        return [[NSAttributedString alloc] initWithString:[self.imageInfo imageDescription]];
    } else if (self.thumbnailImageInfo.imageDescription) {
        return [[NSAttributedString alloc] initWithString:[self.thumbnailImageInfo imageDescription]];
    } else {
        return nil;
    }
}

- (nullable NSAttributedString*)attributedCaptionCredit {
    if (self.imageInfo.owner) {
        return [[NSAttributedString alloc] initWithString:[self.imageInfo owner]];
    } else if (self.thumbnailImageInfo.owner) {
        return [[NSAttributedString alloc] initWithString:[self.thumbnailImageInfo owner]];
    } else {
        return nil;
    }
}

@end

@protocol WMFExposedDataSource <NYTPhotosViewControllerDataSource>

/**
 *  Exposing a private property of the data source
 *  In order to guarantee its existence, we assert photos
 *  on init in the VC
 */
@property (nonatomic, copy, readonly) NSArray* photos;

@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"


@interface WMFImageGalleryViewContoller ()<NYTPhotosViewControllerDelegate>

@property (nonatomic, strong, readonly) NSArray<WMFGalleryImage*>* photos;

@property (nonatomic, readonly) id <WMFExposedDataSource> dataSource;

- (void)updateOverlayInformation;

@property(nonatomic, assign) BOOL overlayViewHidden;

- (NYTPhotoViewController*)currentPhotoViewController;

- (UIImageView*)currentImageView;

@end


@implementation WMFImageGalleryViewContoller

@dynamic dataSource;

- (instancetype)initWithPhotos:(nullable NSArray<id<NYTPhoto> >*)photos initialPhoto:(nullable id<NYTPhoto>)initialPhoto delegate:(nullable id<NYTPhotosViewControllerDelegate>)delegate {
    self = [super initWithPhotos:photos initialPhoto:initialPhoto delegate:self];
    if (self) {
        /**
         *  We are performing the following asserts to ensure that the
         *  implmentation of of NYTPhotosViewController does not change.
         *  We exposed these properties and methods via a category
         *  in lieu of subclassing. (and then maintaining a seperate fork)
         */
        NSParameterAssert(self.dataSource);
        NSParameterAssert(self.photos);
        NSAssert([self respondsToSelector:@selector(updateOverlayInformation)], @"NYTPhoto implementation changed!");
        NSAssert([self respondsToSelector:@selector(currentPhotoViewController)], @"NYTPhoto implementation changed!");
        NSAssert([self respondsToSelector:@selector(currentImageView)], @"NYTPhoto implementation changed!");

        UIBarButtonItem* share = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share"] style:UIBarButtonItemStylePlain target:self action:@selector(didTapShareButton)];
        share.tintColor         = [UIColor whiteColor];
        self.rightBarButtonItem = share;

        UIBarButtonItem* close = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"close"] style:UIBarButtonItemStylePlain target:self action:@selector(didTapCloseButton)];
        close.tintColor        = [UIColor whiteColor];
        self.leftBarButtonItem = close;
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)setOverlayViewHidden:(BOOL)overlayViewHidden {
    if (overlayViewHidden) {
        [self.overlayView removeFromSuperview];
    } else {
        [self.view addSubview:self.overlayView];
    }
}

- (BOOL)overlayViewHidden {
    return [self.overlayView superview] == nil;
}

- (UIImageView*)currentImageView {
    return [self currentPhotoViewController].scalingImageView.imageView;
}

- (NSArray<WMFGalleryImage*>*)photos {
    return [(id < WMFExposedDataSource >)self.dataSource photos];
}

- (NSUInteger)indexOfCurrentImage {
    return [self indexOfPhoto:self.currentlyDisplayedPhoto];
}

- (MWKImage*)imageForPhoto:(id<NYTPhoto>)photo {
    return [(WMFGalleryImage*)photo imageObject] ? : [(WMFGalleryImage*)photo thumbnailImageObject];
}

- (MWKImageInfo*)imageInfoForPhoto:(id<NYTPhoto>)photo {
    return [(WMFGalleryImage*)photo imageInfo] ? : [(WMFGalleryImage*)photo thumbnailImageInfo];
}

- (MWKImage*)currentImage {
    return [self imageForPhoto:[self photoAtIndex:[self indexOfCurrentImage]]];
}

- (MWKImageInfo*)currentImageInfo {
    return [self imageInfoForPhoto:[self photoAtIndex:[self indexOfCurrentImage]]];
}

- (NSUInteger)indexOfPhoto:(id<NYTPhoto>)photo {
    return [self.photos indexOfObject:photo];
}

- (id<NYTPhoto>)photoAtIndex:(NSUInteger)index {
    if (index > self.photos.count) {
        return nil;
    }
    return self.photos[index];
}

- (void)showImageAtIndex:(NSUInteger)index animated:(BOOL)animated {
    id<NYTPhoto> photo = [self photoAtIndex:index];
    [self displayPhoto:photo animated:animated];
}

#pragma mark - Actions

- (void)didTapCloseButton {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)didTapShareButton {
    WMFGalleryImage* image = self.currentlyDisplayedPhoto;
    MWKImageInfo* info     = image.imageInfo ? : image.thumbnailImageInfo;
    NSURL* url             = [image imageURL] ? : [image thumbnailImageURL];

    @weakify(self);
    [[WMFImageController sharedInstance] fetchImageWithURL:url].then(^(WMFImageDownload* _Nullable download){
        @strongify(self);

        NSMutableArray* items = [NSMutableArray array];

        WMFImageTextActivitySource* textSource = [[WMFImageTextActivitySource alloc] initWithInfo:info];
        [items addObject:textSource];

        WMFImageURLActivitySource* imageSource = [[WMFImageURLActivitySource alloc] initWithInfo:info];
        [items addObject:imageSource];

        if (download.image) {
            [items addObject:download.image];
        }

        UIActivityViewController* vc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        vc.excludedActivityTypes = @[UIActivityTypeAddToReadingList];
        UIPopoverPresentationController* presenter = [vc popoverPresentationController];
        presenter.barButtonItem = self.rightBarButtonItem;
        [self presentViewController:vc animated:YES completion:NULL];
    }).catch(^(NSError* error){
        [[WMFAlertManager sharedInstance] showErrorAlert:error sticky:NO dismissPreviousAlerts:NO tapCallBack:NULL];
    });
}

- (void)didTapInfoButton {
    WMFGalleryImage* image = self.currentlyDisplayedPhoto;
    MWKImageInfo* info     = image.imageInfo ? : image.thumbnailImageInfo;
    [self wmf_openExternalUrl:info.filePageURL];
}

#pragma mark NYTPhotosViewControllerDelegate

- (UIView * _Nullable)photosViewController:(NYTPhotosViewController *)photosViewController referenceViewForPhoto:(id <NYTPhoto>)photo{
    return nil; //TODO: remove this and re-enable animations when tickets for fixing anmimations are addressed
    return [self.referenceViewDelegate referenceViewForImageController:self];
}


- (NSString* _Nullable)photosViewController:(NYTPhotosViewController*)photosViewController titleForPhoto:(id <NYTPhoto>)photo atIndex:(NSUInteger)photoIndex totalPhotoCount:(NSUInteger)totalPhotoCount {
    return @"";
}

- (UIView* _Nullable)photosViewController:(NYTPhotosViewController*)photosViewController captionViewForPhoto:(id <NYTPhoto>)photo {
    MWKImageInfo* imageInfo = [self imageInfoForPhoto:photo];
    
    if(!imageInfo){
        return nil;
    }
    
    WMFImageGalleryDetailOverlayView* caption = [WMFImageGalleryDetailOverlayView wmf_viewFromClassNib];
    
    caption.imageDescription =
    [imageInfo.imageDescription stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSString* ownerOrFallback = imageInfo.owner ?
    [imageInfo.owner stringByTrimmingCharactersInSet : [NSCharacterSet whitespaceAndNewlineCharacterSet]]
    : MWLocalizedString(@"image-gallery-unknown-owner", nil);
    
    [caption setLicense:imageInfo.license owner:ownerOrFallback];
    
    caption.ownerTapCallback = ^{
        [self wmf_openExternalUrl:imageInfo.license.URL];
    };
    caption.infoTapCallback = ^{
        [self wmf_openExternalUrl:imageInfo.filePageURL];
    };
    
    return caption;
}

@end


#pragma clang diagnostic pop

@interface WMFArticleImageGalleryViewContoller ()

@property (nonatomic, strong) WMFImageInfoController* infoController;

@end

@implementation WMFArticleImageGalleryViewContoller

- (instancetype)initWithArticle:(MWKArticle*)article {
    return [self initWithArticle:article selectedImage:nil];
}

- (instancetype)initWithArticle:(MWKArticle*)article selectedImage:(nullable MWKImage*)image {
    NSParameterAssert(article);
    NSParameterAssert(article.dataStore);

    NSArray* items = [article.images imagesForDisplayInGallery];

    if ([[NSProcessInfo processInfo] wmf_isOperatingSystemVersionLessThan9_0_0]) {
        items = [items wmf_reverseArrayIfApplicationIsRTL];
    }

    NSArray<WMFGalleryImage*>* galleryImages = [WMFGalleryImage galleryImagesWithImageObjects:items];

    WMFGalleryImage* selected = nil;
    if (image) {
        selected = [[self class] galleryImageWithImage:image inGalleryImages:galleryImages];
    }

    self = [super initWithPhotos:galleryImages initialPhoto:selected delegate:nil];
    if (self) {
        self.infoController = [[WMFImageInfoController alloc] initWithDataStore:article.dataStore batchSize:50];
        [self.infoController setUniqueArticleImages:items forTitle:article.title];
        [self.photos enumerateObjectsUsingBlock:^(WMFGalleryImage* _Nonnull obj, NSUInteger idx, BOOL* _Nonnull stop) {
            obj.imageInfo = [self.infoController infoForImage:obj.imageObject];
        }];
        self.infoController.delegate = self;
    }

    return self;
}

+ (nullable WMFGalleryImage*)galleryImageWithImage:(MWKImage*)image inGalleryImages:(NSArray<WMFGalleryImage*>*)images {
    NSUInteger index = [self indexOfImage:image inGalleryImages:images];
    if (index > images.count) {
        return nil;
    }
    return images[index];
}

+ (NSUInteger)indexOfImage:(MWKImage*)image inGalleryImages:(NSArray<WMFGalleryImage*>*)images {
    return [images
            indexOfObjectPassingTest:^BOOL (WMFGalleryImage* anImage, NSUInteger _, BOOL* stop) {
        if ([anImage.imageObject isEqualToImage:image] || [anImage.imageObject isVariantOfImage:image]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
}

- (NSUInteger)indexOfImage:(MWKImage*)image {
    return [[self class] indexOfImage:image inGalleryImages:self.photos];
}

#pragma mark - UIViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.currentlyDisplayedPhoto) {
        [self fetchCurrentImageInfo];
    }
}

#pragma mark - Fetch

- (void)fetchCurrentImageInfo {
    [self fetchImageInfoForGalleryImage:self.currentlyDisplayedPhoto];
}

- (void)fetchImageInfoForGalleryImage:(WMFGalleryImage*)galleryImage {
    [self.infoController fetchBatchContainingIndex:[self indexOfPhoto:galleryImage]];
}

#pragma mark NYTPhotosViewControllerDelegate

- (void)photosViewController:(NYTPhotosViewController *)photosViewController didNavigateToPhoto:(id <NYTPhoto>)photo atIndex:(NSUInteger)photoIndex{
    WMFGalleryImage* galleryImage = (WMFGalleryImage*)photo;
    [self fetchImageInfoForGalleryImage:galleryImage];
    if (![galleryImage memoryCachedImage]) {
        @weakify(self);
        [[WMFImageController sharedInstance] fetchImageWithURL:galleryImage.imageURL].then(^(WMFImageDownload* download) {
            @strongify(self);
            [self updateImageForPhoto:galleryImage];
        })
        .catch(^(NSError* error) {
            //show error
        });
    }
}


#pragma mark - WMFImageInfoControllerDelegate

- (void)imageInfoController:(WMFImageInfoController*)controller didFetchBatch:(NSRange)range {
    NSIndexSet* fetchedIndexes = [NSIndexSet indexSetWithIndexesInRange:range];

    [self.photos enumerateObjectsAtIndexes:fetchedIndexes options:0 usingBlock:^(WMFGalleryImage* _Nonnull obj, NSUInteger idx, BOOL* _Nonnull stop) {
        obj.imageInfo = [controller infoForImage:obj.imageObject];
    }];

    [self updateOverlayInformation];
}

- (void)imageInfoController:(WMFImageInfoController*)controller
         failedToFetchBatch:(NSRange)range
                      error:(NSError*)error {
    [[WMFAlertManager sharedInstance] showErrorAlert:error sticky:NO dismissPreviousAlerts:NO tapCallBack:NULL];
    //display error image?
}

#pragma mark - Accessibility

- (BOOL)accessibilityPerformEscape {
    [self dismissViewControllerAnimated:YES completion:NULL];
    return YES;
}

@end


@interface WMFPOTDImageGalleryViewContoller ()

@property (nonatomic, strong) MWKImageInfoFetcher* infoFetcher;

@end

@implementation WMFPOTDImageGalleryViewContoller

- (instancetype)initWithDates:(NSArray<NSDate*>*)imageDates selectedImageInfo:(nullable MWKImageInfo*)imageInfo {
    NSParameterAssert(imageDates);
    NSArray* items                           = imageDates;
    NSArray<WMFGalleryImage*>* galleryImages = [WMFGalleryImage galleryImagesWithDates:items];

    WMFGalleryImage* selected = nil;
    if (imageInfo) {
        selected                    = [galleryImages firstObject];
        selected.thumbnailImageInfo = imageInfo;
    }

    if ([[NSProcessInfo processInfo] wmf_isOperatingSystemVersionLessThan9_0_0]) {
        galleryImages = [galleryImages wmf_reverseArrayIfApplicationIsRTL];
    }

    self = [super initWithPhotos:galleryImages initialPhoto:selected delegate:nil];
    if (self) {
        self.infoFetcher = [[MWKImageInfoFetcher alloc] init];
    }

    return self;
}

#pragma mark - UIViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.currentlyDisplayedPhoto) {
        [self fetchCurrentImageInfo];
    }
}

#pragma mark - Fetch

- (void)fetchCurrentImageInfo {
    [self fetchImageInfoForGalleryImage:(WMFGalleryImage*)self.currentlyDisplayedPhoto];
}

- (nullable WMFGalleryImage*)galleryImageAtIndex:(NSUInteger)index {
    if (index > self.photos.count) {
        return nil;
    }
    return self.photos[index];
}

- (void)fetchImageInfoForIndex:(NSUInteger)index {
    WMFGalleryImage* galleryImage = [self galleryImageAtIndex:index];
    [self fetchImageInfoForGalleryImage:galleryImage];
}

- (void)fetchImageInfoForGalleryImage:(WMFGalleryImage*)galleryImage {
    NSDate* date = [galleryImage potdDate];

    @weakify(self);
    [self.infoFetcher fetchPicOfTheDayGalleryInfoForDate:date
                                        metadataLanguage:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]]
    .then(^(MWKImageInfo* info) {
        @strongify(self);
        galleryImage.imageInfo = info;
        [self fetchImageForGalleryImage:galleryImage];
    })
    .catch(^(NSError* error) {
        //show error
    });
}

- (void)fetchImageForGalleryImage:(WMFGalleryImage*)galleryImage {
    @weakify(self);
    [[WMFImageController sharedInstance] fetchImageWithURL:galleryImage.imageURL].then(^(WMFImageDownload* download) {
        @strongify(self);
        [self updateImageForPhoto:galleryImage];
    })
    .catch(^(NSError* error) {
        //show error
    });
}

#pragma mark NYTPhotosViewControllerDelegate

- (void)photosViewController:(NYTPhotosViewController *)photosViewController didNavigateToPhoto:(id <NYTPhoto>)photo atIndex:(NSUInteger)photoIndex{
    WMFGalleryImage* galleryImage = (WMFGalleryImage*)photo;
    if (![galleryImage imageURL]) {
        [self fetchImageInfoForGalleryImage:galleryImage];
    } else if (![galleryImage memoryCachedImage]) {
        [self fetchImageForGalleryImage:galleryImage];
    }
}


@end


NS_ASSUME_NONNULL_END
