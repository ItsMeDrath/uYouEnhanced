#import "uYouPlus.h"
#import "RootOptionsController.h"

// Tweak's bundle for Localizations support - @PoomSmart - https://github.com/PoomSmart/YouPiP/commit/aea2473f64c75d73cab713e1e2d5d0a77675024f
NSBundle *uYouPlusBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
 	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"uYouPlus" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/uYouPlus.bundle")];
    });
    return bundle;
}
NSBundle *tweakBundle = uYouPlusBundle();

// Keychain fix
static NSString *accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

# pragma mark - Tweaks

// Activate FLEX
%hook YTAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    BOOL didFinishLaunching = %orig;

    if (IS_ENABLED(@"flex_enabled")) {
        [[%c(FLEXManager) performSelector:@selector(sharedManager)] performSelector:@selector(showExplorer)];
    }

    return didFinishLaunching;
}
- (void)appWillResignActive:(id)arg1 {
    %orig;
         if (IS_ENABLED(@"flex_enabled")) {
        [[%c(FLEXManager) performSelector:@selector(sharedManager)] performSelector:@selector(showExplorer)];
    }
}
%end

// Hide YouTube Logo - @dayanch96
%group gHideYouTubeLogo
%hook YTHeaderLogoController
- (YTHeaderLogoController *)init {
    return NULL;
}
%end
%hook YTNavigationBarTitleView
- (void)layoutSubviews {
    %orig;
    if (self.subviews.count > 1 && [self.subviews[1].accessibilityIdentifier isEqualToString:@"id.yoodle.logo"]) {
        self.subviews[1].hidden = YES;
    }
}
%end
%end

%group gCenterYouTubeLogo
%hook YTNavigationBarTitleView
- (void)setShouldCenterNavBarTitleView:(BOOL)center {
    %orig(YES);
}
- (BOOL)shouldCenterNavBarTitleView {
    return YES;
}
- (void)alignCustomViewToCenterOfWindow {
}
%end
%end

// YouTube Premium Logo - @arichorn - this doesn't always function
%group gPremiumYouTubeLogo
%hook YTHeaderLogoController
- (void)setPremiumLogo:(BOOL)isPremiumLogo {
    isPremiumLogo = YES;
    %orig;
}
- (BOOL)isPremiumLogo {
    return YES;
}
- (void)setTopbarLogoRenderer:(id)renderer {
}
%end

// Workaround: fix YouTube Premium Logo not working on v18.35.4 or above.
%hook YTVersionUtils // Working Version for Premium Logo
+ (NSString *)appVersion { return @"18.34.5"; }
%end

%hook YTSettingsCell // Remove v18.34.5 Version Number - @Dayanch96
- (void)setDetailText:(id)arg1 {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = infoDictionary[@"CFBundleShortVersionString"];

    if ([arg1 isEqualToString:@"18.34.5"]) {
        arg1 = appVersion;
    } %orig(arg1);
}
%end
%end

// IAmYouTube - https://github.com/PoomSmart/IAmYouTube/
%hook YTVersionUtils
+ (NSString *)appName { return YT_NAME; }
+ (NSString *)appID { return YT_BUNDLE_ID; }
%end

%hook GCKBUtils
+ (NSString *)appIdentifier { return YT_BUNDLE_ID; }
%end

%hook GPCDeviceInfo
+ (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook OGLBundle
+ (NSString *)shortAppName { return YT_NAME; }
%end

%hook GVROverlayView
+ (NSString *)appName { return YT_NAME; }
%end

%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook APMAEU
+ (BOOL)isFAS { return YES; }
%end

%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore { return YES; }
%end

%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)supportedAccountServices {
    self = %orig;
    [self setValue:YT_NAME forKey:@"_shortAppName"];
    [self setValue:YT_BUNDLE_ID forKey:@"_applicationIdentifier"];
    return self;
}
%end

%hook NSBundle
- (NSString *)bundleIdentifier {
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info info = {0};
    if (dladdr((void *)[address[2] longLongValue], &info) == 0)
        return %orig;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    if ([path hasPrefix:NSBundle.mainBundle.bundlePath])
        return YT_BUNDLE_ID;
    return %orig;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CFBundleIdentifier"])
        return YT_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return YT_NAME;
    return %orig;
}
// Fix Google Sign in by @PoomSmart & @level3tjg (qnblackcat/uYouPlus#684)
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *info = %orig.mutableCopy;
    NSString *altBundleIdentifier = info[@"ALTBundleIdentifier"];
    if (altBundleIdentifier) info[@"CFBundleIdentifier"] = altBundleIdentifier;
    return info;
}
%end

// Fix login for YouTube 18.13.2 and higher - @BandarHL
%hook SSOKeychainHelper
+ (NSString *)accessGroup {
    return accessGroupID();
}
+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix login for YouTube 17.33.2 and higher - @BandarHL
// https://gist.github.com/BandarHL/492d50de46875f9ac7a056aad084ac10
%hook SSOKeychainCore
+ (NSString *)accessGroup {
    return accessGroupID();
}

+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix App Group Directory by move it to document directory
%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier != nil) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        return [documentsURL URLByAppendingPathComponent:@"AppGroup"];
    }
    return %orig(groupIdentifier);
}
%end

// Remove App Rating Prompt in YouTube (for Sideloaded - iOS 14+) - @arichornlover
%hook SKStoreReviewController
+ (void)requestReview { }
%end

// YTMiniPlayerEnabler: https://github.com/level3tjg/YTMiniplayerEnabler/
%hook YTWatchMiniBarViewController
- (void)updateMiniBarPlayerStateFromRenderer {
    if (IS_ENABLED(@"ytMiniPlayer_enabled")) {}
    else { return %orig; }
}
%end

// YTNoHoverCards: https://github.com/level3tjg/YTNoHoverCards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)hidden {
    if (IS_ENABLED(@"hideHoverCards_enabled"))
        hidden = YES;
    %orig;
}
%end

// YTClassicVideoQuality: https://github.com/PoomSmart/YTClassicVideoQuality
%hook YTIMediaQualitySettingsHotConfig

%new(B@:) - (BOOL)enableQuickMenuVideoQualitySettings { return NO; }

%end

// %hook YTVideoQualitySwitchControllerFactory
// - (id)videoQualitySwitchControllerWithParentResponder:(id)responder {
//     Class originalClass = %c(YTVideoQualitySwitchOriginalController);
//     return originalClass ? [[originalClass alloc] initWithParentResponder:responder] : %orig;
// }
// %end

// A/B flags
%hook YTColdConfig 
- (BOOL)respectDeviceCaptionSetting { return NO; } // YouRememberCaption: https://poomsmart.github.io/repo/depictions/youremembercaption.html
- (BOOL)isLandscapeEngagementPanelSwipeRightToDismissEnabled { return YES; } // Swipe right to dismiss the right panel in fullscreen mode
%end

// NOYTPremium - https://github.com/PoomSmart/NoYTPremium/
%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1 { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1 { return NO; }
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial { return YES; }
%end

%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

%hook YTIOfflineabilityFormat
%new
- (int)availabilityType { return 1; }
%new
- (BOOL)savedSettingShouldExpire { return NO; }
%end

// YTShortsProgress - https://github.com/PoomSmart/YTShortsProgress/
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return YES; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return YES; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return YES; }
%end

// YTNoTracking - @arichorn - https://github.com/arichorn/YTNoTracking/
%hook UIApplication
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSString *originalURLString = [url absoluteString];
    NSString *modifiedURLString = originalURLString;
    if ([modifiedURLString isEqualToString:originalURLString]) {
        modifiedURLString = [modifiedURLString stringByReplacingOccurrencesOfString:@"&si=[a-zA-Z0-9_-]+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, modifiedURLString.length)];
    }
    NSURL *modifiedURL = [NSURL URLWithString:modifiedURLString];
    BOOL result = %orig(application, modifiedURL, options);
    return result;
}
%end

%hook YTICompactLinkRenderer
+ (BOOL)hasTrackingParams {
    return NO;
}
%end

%hook YTIReelPlayerOverlayRenderer
+ (BOOL)hasTrackingParams {
    return NO;
}
%end

%hook YTIShareTargetServiceUpdateRenderer
+ (BOOL)hasTrackingParams {
    return NO;
}
%end

// YTNoPaidPromo: https://github.com/PoomSmart/YTNoPaidPromo
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IS_ENABLED(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"] && IS_ENABLED(@"hidePaidPromotionCard_enabled")) return;
    %orig;
}
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IS_ENABLED(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
%end

// Fix LowContrastMode - @arichorn
%group gFixLowContrastMode
%hook YTVersionUtils // Supported LowContrastMode Version
+ (NSString *)appVersion { return @"17.38.10"; }
%end

%hook YTSettingsCell // Remove v17.38.10 Version Number - @Dayanch96
- (void)setDetailText:(id)arg1 {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = infoDictionary[@"CFBundleShortVersionString"];

    if ([arg1 isEqualToString:@"17.38.10"]) {
        arg1 = appVersion;
    } %orig(arg1);
}
%end
%end

// Disable Modern/Rounded Buttons (_ASDisplayView not included) - @arichorn
%group gDisableModernButtons 
%hook YTQTMButton // Disable Modern/Rounded Buttons
+ (BOOL)buttonModernizationEnabled { return NO; }
%end
%end

// Disable Rounded Hints with no Rounded Corners - @arichorn
%group gDisableRoundedHints
%hook YTBubbleHintView // Disable Modern/Rounded Hints
+ (BOOL)modernRoundedCornersEnabled { return NO; }
%end
%end

// Disable Modern Flags - @arichorn
%group gDisableModernFlags
%hook YTColdConfig
// Disable Modern Content
- (BOOL)creatorClientConfigEnableStudioModernizedMdeThumbnailPickerForClient { return NO; }
- (BOOL)cxClientEnableModernizedActionSheet { return NO; }
- (BOOL)enableClientShortsSheetsModernization { return NO; }
- (BOOL)enableTimestampModernizationForNative { return NO; }
- (BOOL)modernizeElementsTextColor { return NO; }
- (BOOL)modernizeElementsBgColor { return NO; }
- (BOOL)modernizeCollectionLockups { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernButtonsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableModernTabsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableEpUxUpdates { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableSheetsUxUpdates { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableSnackbarModernization { return NO; }
// Disable Rounded Content
- (BOOL)iosDownloadsPageRoundedThumbs { return NO; }
- (BOOL)iosRoundedSearchBarSuggestZeroPadding { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedDialogForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNativeLongTail { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedTimestampForNative { return NO; }
// Disable Optional Content
- (BOOL)elementsClientIosElementsEnableLayoutUpdateForIob { return NO; }
- (BOOL)supportElementsInMenuItemSupportedRenderers { return NO; }
- (BOOL)isNewRadioButtonStyleEnabled { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableButtonSentenceCasingForNative { return NO; }
- (BOOL)mainAppCoreClientEnableClientYouTab { return NO; }
- (BOOL)mainAppCoreClientEnableClientYouLatency { return NO; }
- (BOOL)mainAppCoreClientEnableClientYouTabTablet { return NO; }
%end

%hook YTHotConfig
- (BOOL)liveChatIosUseModernRotationDetection { return NO; } // Disable Modern Content (YTHotConfig)
- (BOOL)liveChatModernizeClassicElementizeTextMessage { return NO; }
- (BOOL)iosShouldRepositionChannelBar { return NO; }
- (BOOL)enableElementRendererOnChannelCreation { return NO; }
%end
%end

// Disable Ambient Mode in Fullscreen - @arichorn
%group gDisableAmbientMode
%hook YTCinematicContainerView
- (BOOL)watchFullScreenCinematicSupported {
    return NO;
}
- (BOOL)watchFullScreenCinematicEnabled {
    return NO;
}
%end
%hook YTColdConfig
- (BOOL)disableCinematicForLowPowerMode { return NO; }
- (BOOL)enableCinematicContainer { return NO; }
- (BOOL)enableCinematicContainerOnClient { return NO; }
- (BOOL)enableCinematicContainerOnTablet { return NO; }
- (BOOL)enableTurnOffCinematicForFrameWithBlackBars { return YES; }
- (BOOL)enableTurnOffCinematicForVideoWithBlackBars { return YES; }
- (BOOL)iosCinematicContainerClientImprovement { return NO; }
- (BOOL)iosEnableGhostCardInlineTitleCinematicContainerFix { return NO; }
- (BOOL)iosUseFineScrubberMosaicStoreForCinematic { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylists { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylistsPostMvp { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicTablets { return NO; }
- (BOOL)iosEnableFullScreenAmbientMode { return NO; }
%end
%end

// Hide YouTube Heatwaves in Video Player (YouTube v17.19.2-latest) - @level3tjg - https://www.reddit.com/r/jailbreak/comments/v29yvk/
%group gHideHeatwaves
%hook YTInlinePlayerBarContainerView
- (BOOL)canShowHeatwave { return NO; }
%end
%end

// YTNoSuggestedVideo - https://github.com/bhackel/YTNoSuggestedVideo
%hook YTMainAppVideoPlayerOverlayViewController
- (bool)shouldShowAutonavEndscreen {
    if (IS_ENABLED(@"noSuggestedVideo_enabled")) {
        return false;
    }
    return %orig;
}
%end

# pragma mark - Hide Notification Button && SponsorBlock Button && uYouPlus Button
%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(@"hideNotificationButton_enabled")) {
        self.notificationButton.hidden = YES;
    }
    if (IS_ENABLED(@"hideSponsorBlockButton_enabled")) { 
        self.sponsorBlockButton.hidden = YES;
        self.sponsorBlockButton.frame = CGRectZero;
    }
    if (IS_ENABLED(@"hideuYouPlusButton_enabled")) { 
        self.uYouPlusButton.hidden = YES;
        self.uYouPlusButton.frame = CGRectZero;
    }
}
%end

# pragma mark - uYouPlus
// Video Player Options
// Skips content warning before playing *some videos - @PoomSmart
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { [self confirmAlertDidPressConfirm]; }
%end

// Portrait Fullscreen - @Dayanch96
%group gPortraitFullscreen
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
%end
%end

// Disable snap to chapter
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(@"snapToChapter_enabled")) {
        self.enableSnapToChapter = NO;
    }
}
%end

// Disable Pinch to zoom
%hook YTColdConfig
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig {
    return IS_ENABLED(@"pinchToZoom_enabled") ? NO : %orig;
}
%end

// YTStockVolumeHUD - https://github.com/lilacvibes/YTStockVolumeHUD
%group gStockVolumeHUD
%hook YTVolumeBarView
- (void)volumeChanged:(id)arg1 {
        %orig(nil);
}
%end

%hook UIApplication 
- (void)setSystemVolumeHUDEnabled:(BOOL)arg1 forAudioCategory:(id)arg2 {
        %orig(true, arg2);
}
%end
%end

%hook YTColdConfig
- (BOOL)speedMasterArm2FastForwardWithoutSeekBySliding {
    return IS_ENABLED(@"slideToSeek_enabled") ? NO : %orig;
}
%end

// Disable double tap to seek
%hook YTDoubleTapToSeekController
- (void)enableDoubleTapToSeek:(BOOL)arg1 {
    return IS_ENABLED(@"doubleTapToSeek_disabled") ? %orig(NO) : %orig;
}
%end

// Hide double tap to seek overlay - @arichornlover
%hook YTInlinePlayerDoubleTapIndicatorView
- (CGFloat)circleRadius {
    if (IS_ENABLED(@"hideDoubleTapToSeekOverlay_enabled")) {
        return 0;
    }
    return %orig;
}
%end

// Video Controls Overlay Options
// Hide CC / Hide Autoplay switch / Hide YTMusic Button / Enable Share Button / Enable Save to Playlist Button
%hook YTMainAppControlsOverlayView
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { // hide CC button
    return IS_ENABLED(@"hideCC_enabled") ? %orig(NO) : %orig;
}
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { // hide Autoplay
    if (IS_ENABLED(@"hideAutoplaySwitch_enabled")) {}
    else { return %orig; }
}
- (void)setYoutubeMusicButton:(id)arg1 {
    if (IS_ENABLED(@"hideYTMusicButton_enabled")) {
    } else {
        %orig(arg1);
    }
}
- (void)setShareButtonAvailable:(BOOL)arg1 {
    if (IS_ENABLED(@"enableShareButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
- (void)setAddToButtonAvailable:(BOOL)arg1 {
    if (IS_ENABLED(@"enableSaveToButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
%end

// Hide Video Player Collapse Button - @arichornlover
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
    %orig; 
    if (IS_ENABLED(@"disableCollapseButton_enabled")) {  
        if (self.watchCollapseButton) {
            [self.watchCollapseButton removeFromSuperview];
        }
    }
}
- (BOOL)watchCollapseButtonHidden {
    if (IS_ENABLED(@"disableCollapseButton_enabled")) {
        return YES;
    } else {
        return %orig;
    }
}
- (void)setWatchCollapseButtonAvailable:(BOOL)available {
    if (IS_ENABLED(@"disableCollapseButton_enabled")) {
    } else {
        %orig(available);
    }
}
%end

// Hide Fullscreen Button - @arichornlover
%hook YTInlinePlayerBarContainerView
- (void)layoutSubviews {
    %orig; 
    if (IS_ENABLED(@"disableFullscreenButton_enabled")) {
        if (self.exitFullscreenButton) {
            [self.exitFullscreenButton removeFromSuperview];
            self.exitFullscreenButton.frame = CGRectZero;
        }
        if (self.enterFullscreenButton) {
            [self.enterFullscreenButton removeFromSuperview];
            self.enterFullscreenButton.frame = CGRectZero;
        }
        self.fullscreenButtonDisabled = YES;
    }
}
%end

// Hide HUD Messages
%hook YTHUDMessageView
- (id)initWithMessage:(id)arg1 dismissHandler:(id)arg2 {
    return IS_ENABLED(@"hideHUD_enabled") ? nil : %orig;
}
%end

// Hide Channel Watermark
%hook YTColdConfig
- (BOOL)iosEnableFeaturedChannelWatermarkOverlayFix {
    return IS_ENABLED(@"hideChannelWatermark_enabled") ? NO : %orig;
}
%end
// Hide Channel Watermark (for Old YouTube Versions / Backwards Compatibility)
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark {
    if (IS_ENABLED(@"hideChannelWatermark_enabled")) {}
    else { return %orig; }
}
%end

%group gHidePreviousAndNextButton
%hook YTColdConfig
- (BOOL)removeNextPaddleForAllVideos { 
    return YES; 
}
- (BOOL)removePreviousPaddleForAllVideos { 
    return YES; 
}
%end
%end

// Hide Dark Overlay Background
%group gHideOverlayDarkBackground
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 {
    %orig(NO, arg2);
}
%end
%end

// Replace Next & Previous button with Fast forward & Rewind button
// %group gReplacePreviousAndNextButton
// %hook YTColdConfig
// - (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return YES; }
// - (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return YES; }
// %end
// %end

// Hide Shadow Overlay Buttons (Play/Pause, Next, previous, Fast forward & Rewind buttons)
%group gHideVideoPlayerShadowOverlayButtons
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekBackwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekForwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTPlaybackButton *>(self, "_playPauseButton").backgroundColor = nil;
}
%end
%end

// Bring back the Red Progress Bar and Gray Buffer Progress
%group gRedProgressBar
%hook YTInlinePlayerBarContainerView
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end

%hook YTSegmentableInlinePlayerBarView
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.50];
}
%end
%end

// Disable the right panel in fullscreen mode
%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return IS_ENABLED(@"hideRightPanel_enabled") ? NO : %orig;
}
%end

// Shorts Controls Overlay Options
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if ((IS_ENABLED(@"hideBuySuperThanks_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.suggested_action"])) { 
        self.hidden = YES; 
    }

// Hide Header Links under Channel Profile - @arichorn
    if ((IS_ENABLED(@"hideChannelHeaderLinks_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"eml.channel_header_links"])) {
        self.hidden = YES;
        self.opaque = YES;
        self.userInteractionEnabled = NO;
        [self sizeToFit];
        [self setNeedsLayout];
        [self removeFromSuperview];
    }

// Completely Remove the Comment Section under the Video Player - @arichorn
    if ((IS_ENABLED(@"hideCommentSection_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"id.ui.comments_entry_point_teaser"] 
    || [self.accessibilityIdentifier isEqualToString:@"id.ui.comments_entry_point_simplebox"] 
    || [self.accessibilityIdentifier isEqualToString:@"id.ui.video_metadata_carousel"] 
    || [self.accessibilityIdentifier isEqualToString:@"id.ui.carousel_header"])) {
        self.hidden = YES;
        self.opaque = YES;
        self.userInteractionEnabled = NO;
        CGRect bounds = self.frame;
        bounds.size.height = 0;
        self.frame = bounds;
        [self setNeedsLayout];
        [self removeFromSuperview];
    }

// Hide the Comment Section Previews under the Video Player - @arichorn
    if ((IS_ENABLED(@"hidePreviewCommentSection_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"id.ui.comments_entry_point_teaser"])) {
        self.hidden = YES;
        self.opaque = YES;
        self.userInteractionEnabled = NO;
        CGRect bounds = self.frame;
        bounds.size.height = 0;
        self.frame = bounds;
        [self setNeedsLayout];
        [self removeFromSuperview];
    }
}
%end

%hook YTReelWatchRootViewController
- (void)setPausedStateCarouselView {
    if (IS_ENABLED(@"hideSubscriptions_enabled")) {}
    else { return %orig; }
}
%end

%hook YTShortsStartupCoordinator
- (id)evaluateResumeToShorts { 
    return IS_ENABLED(@"disableResumeToShorts_enabled") ? nil : %orig;
}
%end

// Hide Shorts Cells - @PoomSmart & @iCrazeiOS
%hook YTIElementRenderer
- (NSData *)elementData {
        NSString *description = [self description];
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"removeShortsCell"]) { // uYou (Hide Shorts Cells)
        if ([description containsString:@"shorts_shelf.eml"] ||
            [description containsString:@"#shorts"] ||
            [description containsString:@"shorts_video_cell.eml"] ||
            [description containsString:@"6Shorts"]) {
            if (![description containsString:@"history*"]) {
                return nil;
            }
        }
    }
// Hide Community Posts - @michael-winay & @arichorn
    if (IS_ENABLED(@"hideCommunityPosts_enabled")) {
        if ([description containsString:@"post_base_wrapper.eml"]) {
            return nil;
        }
    }
    return %orig;
}
%end

/* Deprecated Code - Loads indefinitely on newer YouTube Versions
// Hide Community Posts - @michael-winay & @arichorn
%hook YTAsyncCollectionView
- (id)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;
    
    if ([cell isKindOfClass:objc_lookUpClass("_ASCollectionViewCell")]) {
        _ASCollectionViewCell *cell = %orig;
        if ([cell respondsToSelector:@selector(node)]) {
            NSString *idToRemove = [[cell node] accessibilityIdentifier];
            if (IsEnabled(@"hideCommunityPosts_enabled")) {
                if ([idToRemove rangeOfString:@"id.ui.backstage.post"].location != NSNotFound) {
                    [self removeShortsAndFeaturesAdsAtIndexPath:indexPath];
                }
            }
        }
    }
    return cell;
}
%new
- (void)removeShortsAndFeaturesAdsAtIndexPath:(NSIndexPath *)indexPath {
    [self deleteItemsAtIndexPaths:@[indexPath]];
}
%end
*/

// Red Subscribe Button - @arichorn
%hook ELMContainerNode
- (void)setBackgroundColor:(id)color {
    NSString *description = [self description];
    if (IS_ENABLED(@"redSubscribeButton_enabled")) {
        if ([description containsString:@"eml.compact_subscribe_button"]) {
            color = [UIColor redColor];
        }
    }
// Hide the Button Containers under the Video Player - 17.x.x and up - @arichorn
    if (IS_ENABLED(@"hideButtonContainers_enabled")) {
        if ([description containsString:@"id.video.like.button"] ||
            [description containsString:@"id.video.dislike.button"] ||
            [description containsString:@"id.video.share.button"] ||
            [description containsString:@"id.video.remix.button"] ||
            [description containsString:@"id.ui.add_to.offline.button"]) {
            color = [UIColor clearColor];
        }
    }
    %orig(color);
}
%end

// uYouPlus Button in Navigation Bar (for Clear Cache and Color Options) - @arichornlover
%hook YTRightNavigationButtons
%property (retain, nonatomic) YTQTMButton *uYouPlusButton;
- (NSMutableArray *)buttons {
	NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"uYouPlus" ofType:@"bundle"];
    NSString *uYouPlusMainSettingsPath;
    if (tweakBundlePath) {
        NSBundle *tweakBundle = [NSBundle bundleWithPath:tweakBundlePath];
	uYouPlusMainSettingsPath = [tweakBundle pathForResource:@"uYouPlus_logo_main" ofType:@"png"];
    } else {
        uYouPlusMainSettingsPath = ROOT_PATH_NS(@"/Localizations/uYouPlus.bundle/uYouPlus_logo_main.png");
    }
    NSMutableArray *retVal = %orig.mutableCopy;
    [self.uYouPlusButton removeFromSuperview];
    [self addSubview:self.uYouPlusButton];
    if (!self.uYouPlusButton) {
        self.uYouPlusButton = [%c(YTQTMButton) iconButton];
        [self.uYouPlusButton enableNewTouchFeedback];
        self.uYouPlusButton.frame = CGRectMake(0, 0, 40, 40);
        
        if ([%c(YTPageStyleController) pageStyle] == 0) {
            UIImage *setButtonMode = [UIImage imageWithContentsOfFile:uYouPlusMainSettingsPath];
            setButtonMode = [setButtonMode imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.uYouPlusButton setImage:setButtonMode forState:UIControlStateNormal];
            [self.uYouPlusButton setTintColor:UIColor.blackColor];
        }
        else if ([%c(YTPageStyleController) pageStyle] == 1) {
            UIImage *setButtonMode = [UIImage imageWithContentsOfFile:uYouPlusMainSettingsPath];
            setButtonMode = [setButtonMode imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.uYouPlusButton setImage:setButtonMode forState:UIControlStateNormal];
            [self.uYouPlusButton setTintColor:UIColor.whiteColor];
        }
        
        [self.uYouPlusButton addTarget:self action:@selector(uYouPlusRootOptionsAction) forControlEvents:UIControlEventTouchUpInside];
        [retVal insertObject:self.uYouPlusButton atIndex:0];
    }
    return retVal;
}
- (NSMutableArray *)visibleButtons {
    NSMutableArray *retVal = %orig.mutableCopy;
    [self setLeadingPadding:+10];
    if (self.uYouPlusButton) {
        [self.uYouPlusButton removeFromSuperview];
        [self addSubview:self.uYouPlusButton];
        [retVal insertObject:self.uYouPlusButton atIndex:0];
    }
    return retVal;
}
%new;
- (void)uYouPlusRootOptionsAction {
    UINavigationController *rootOptionsControllerView = [[UINavigationController alloc] initWithRootViewController:[[RootOptionsController alloc] init]];
    [rootOptionsControllerView setModalPresentationStyle:UIModalPresentationFullScreen];
    
    [self._viewControllerForAncestor presentViewController:rootOptionsControllerView animated:YES completion:nil];
}
%end

// Hide the (Connect / Save) Buttons under the Video Player - 17.x.x and up - @PoomSmart (inspired by @arichornlover)
%hook _ASDisplayView
- (void)layoutSubviews {
    %orig;
    BOOL hideConnectButton = IS_ENABLED(@"hideConnectButton_enabled");
//    BOOL hideShareButton = IS_ENABLED(@"hideShareButton_enabled"); // OLD
//    BOOL hideRemixButton = IS_ENABLED(@"hideRemixButton_enabled"); // OLD
//    BOOL hideThanksButton = IS_ENABLED(@"hideThanksButton_enabled"); // OLD
//    BOOL hideAddToOfflineButton = IS_ENABLED(@"hideAddToOfflineButton_enabled"); // OLD
//    BOOL hideClipButton = IS_ENABLED(@"hideClipButton_enabled"); // OLD
    BOOL hideSaveToPlaylistButton = IS_ENABLED(@"hideSaveToPlaylistButton_enabled");

    for (UIView *subview in self.subviews) {
        if ([subview.accessibilityLabel isEqualToString:@"connect account"]) {
            subview.hidden = hideConnectButton;
 //         subview.frame = hideConnectButton ? CGRectZero : subview.frame;
        } else if ([subview.accessibilityLabel isEqualToString:@"Save to playlist"]) {
            subview.hidden = hideSaveToPlaylistButton;
 //         subview.frame = hideSaveToPlaylistButton ? CGRectZero : subview.frame;
        }
    }
}
%end

static BOOL findCell(ASNodeController *nodeController, NSArray <NSString *> *identifiers) {
    for (id child in [nodeController children]) {
        if ([child isKindOfClass:%c(ELMNodeController)]) {
            NSArray <ELMComponent *> *elmChildren = [(ELMNodeController *)child children];
            for (ELMComponent *elmChild in elmChildren) {
                for (NSString *identifier in identifiers) {
                    if ([[elmChild description] containsString:identifier])
                        return YES;
                }
            }
        }

        if ([child isKindOfClass:%c(ASNodeController)]) {
            ASDisplayNode *childNode = ((ASNodeController *)child).node; // ELMContainerNode
            NSArray *yogaChildren = childNode.yogaChildren;
            for (ASDisplayNode *displayNode in yogaChildren) {
                if ([identifiers containsObject:displayNode.accessibilityIdentifier])
                    return YES;
            }

            return findCell(child, identifiers);
        }

        return NO;
    }
    return NO;
}

%hook ASCollectionView

- (CGSize)sizeForElement:(ASCollectionElement *)element {
    if ([self.accessibilityIdentifier isEqualToString:@"id.video.scrollable_action_bar"]) {
        ASCellNode *node = [element node];
        ASNodeController *nodeController = [node controller];
        if (IS_ENABLED(@"hideShareButton_enabled") && findCell(nodeController, @[@"id.video.share.button"])) {
            return CGSizeZero;
        }

        if (IS_ENABLED(@"hideRemixButton_enabled") && findCell(nodeController, @[@"id.video.remix.button"])) {
            return CGSizeZero;
        }

        if (IS_ENABLED(@"hideThanksButton_enabled") && findCell(nodeController, @[@"thanks_button.eml"])) {
            return CGSizeZero;
        }

        if (IS_ENABLED(@"hideClipButton_enabled") && findCell(nodeController, @[@"clip_button.eml"])) {
            return CGSizeZero;
        }

        if (IS_ENABLED(@"hideDownloadButton_enabled") && findCell(nodeController, @[@"id.ui.add_to.offline.button"])) {
            return CGSizeZero;
        }

        if (IS_ENABLED(@"hideCommentSection_enabled") && findCell(nodeController, @[@"id.ui.carousel_header"])) {
            return CGSizeZero;
        }
    }
    return %orig;
}

%end

// App Settings Overlay Options
%group gDisableAccountSection
%hook YTSettingsSectionItemManager
- (void)updateAccountSwitcherSectionWithEntry:(id)arg1 {} // Account
%end
%end

%group gDisableAutoplaySection
%hook YTSettingsSectionItemManager
- (void)updateAutoplaySectionWithEntry:(id)arg1 {} // Autoplay
%end
%end

%group gDisableTryNewFeaturesSection
%hook YTSettingsSectionItemManager
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {} // Try new features
%end
%end

%group gDisableVideoQualityPreferencesSection
%hook YTSettingsSectionItemManager
- (void)updateVideoQualitySectionWithEntry:(id)arg1 {} // Video quality preferences
%end
%end

%group gDisableNotificationsSection
%hook YTSettingsSectionItemManager
- (void)updateNotificationSectionWithEntry:(id)arg1 {} // Notifications
%end
%end

%group gDisableManageAllHistorySection
%hook YTSettingsSectionItemManager
- (void)updateHistorySectionWithEntry:(id)arg1 {} // Manage all history
%end
%end

%group gDisableYourDataInYouTubeSection
%hook YTSettingsSectionItemManager
- (void)updateYourDataSectionWithEntry:(id)arg1 {} // Your data in YouTube
%end
%end

%group gDisablePrivacySection
%hook YTSettingsSectionItemManager
- (void)updatePrivacySectionWithEntry:(id)arg1 {} // Privacy
%end
%end

%group gDisableLiveChatSection
%hook YTSettingsSectionItemManager
- (void)updateLiveChatSectionWithEntry:(id)arg1 {} // Live chat
%end
%end

// Miscellaneous
// YT startup animation
%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnableStartupAnimation {
    return IS_ENABLED(@"ytStartupAnimation_enabled") ? YES : NO;
}
%end

// %hook YTSectionListViewController
// - (void)loadWithModel:(YTISectionListRenderer *)model {
//     NSMutableArray <YTISectionListSupportedRenderers *> *contentsArray = model.contentsArray;
//     NSIndexSet *removeIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTISectionListSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
//         YTIItemSectionRenderer *sectionRenderer = renderers.itemSectionRenderer;
//         YTIItemSectionSupportedRenderers *firstObject = [sectionRenderer.contentsArray firstObject];
//         return firstObject.hasPromotedVideoRenderer || firstObject.hasCompactPromotedVideoRenderer || firstObject.hasPromotedVideoInlineMutedRenderer;
//     }];
//     [contentsArray removeObjectsAtIndexes:removeIndexes];
//     %orig;
// }
// %end

// Disable hints - https://github.com/LillieH001/YouTube-Reborn/blob/v4/
%group gDisableHints
%hook YTSettings
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTUserDefaults
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%end

// Stick Navigation bar
%group gStickNavigationBar
%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return YES; } 
%end
%end

// Hide the Chip Bar (Upper Bar) in Home feed
%group gHideChipBar
%hook YTMySubsFilterHeaderView 
- (void)setChipFilterView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)setFeedHeaderScrollMode:(int)arg1 { %orig(0); }
%end

// Hide the chip bar under the video player?
// %hook YTChipCloudCell // 
// - (void)didMoveToWindow {
//     %orig;
//     self.hidden = YES;
// }
// %end
%end

// Remove “Play next in queue” from the menu (@PoomSmart) - qnblackcat/uYouPlus#1138
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    return IS_ENABLED(@"hidePlayNextInQueue_enabled") && renderer.icon.iconType == 251 ? NO : %orig;
}
%end

// Hide the Videos under the Video Player - @Dayanch96
%group gNoRelatedWatchNexts
%hook YTWatchNextResultsViewController
- (void)setVisibleSections:(NSInteger)arg1 {
    arg1 = 1;
    %orig(arg1);
}
%end
%end

// Hide Videos in Fullscreen - @arichorn
%group gNoVideosInFullscreen
%hook YTFullScreenEngagementOverlayView
- (void)setRelatedVideosView:(id)view {
}
- (void)updateRelatedVideosViewSafeAreaInsets {
}
- (id)relatedVideosView {
    return nil;
}
%end

%hook YTFullScreenEngagementOverlayController
- (void)setRelatedVideosVisible:(BOOL)visible {
}
- (BOOL)relatedVideosPeekingEnabled {
    return NO;
}
%end
%end

// iPhone Layout - @LillieH1000 & @arichorn
%group giPhoneLayout
%hook UIDevice
- (long long)userInterfaceIdiom {
    return NO;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return YES;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return NO;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return NO;
} 
%end
%end

// Hide Indicators - @Dayanch96 & @arichorn
%group gHideSubscriptionsNotificationBadge
%hook YTPivotBarIndicatorView
- (void)didMoveToWindow {
    [self setHidden:YES];
    %orig();
}
- (void)setFillColor:(id)arg1 {
    %orig([UIColor clearColor]);
}
- (void)setBorderColor:(id)arg1 {
    %orig([UIColor clearColor]);
}
%end
%end

# pragma mark - ctor
%ctor {
    // Load uYou first so its functions are available for hooks.
    // dlopen([[NSString stringWithFormat:@"%@/Frameworks/uYou.dylib", [[NSBundle mainBundle] bundlePath]] UTF8String], RTLD_LAZY);

    %init;
    if (IS_ENABLED(@"hideYouTubeLogo_enabled")) {
        %init(gHideYouTubeLogo);
    }
    if (IS_ENABLED(@"centerYouTubeLogo_enabled")) {
        %init(gCenterYouTubeLogo);
    }
    if (IS_ENABLED(@"premiumYouTubeLogo_enabled")) {
        %init(gPremiumYouTubeLogo);
    }
    if (IS_ENABLED(@"hideSubscriptionsNotificationBadge_enabled")) {
        %init(gHideSubscriptionsNotificationBadge);
    }
    if (IS_ENABLED(@"hidePreviousAndNextButton_enabled")) {
        %init(gHidePreviousAndNextButton);
    }
    if (IS_ENABLED(@"hideOverlayDarkBackground_enabled")) {
        %init(gHideOverlayDarkBackground);
    }
    if (IS_ENABLED(@"hideVideoPlayerShadowOverlayButtons_enabled")) {
        %init(gHideVideoPlayerShadowOverlayButtons);
    }
    if (IS_ENABLED(@"disableHints_enabled")) {
        %init(gDisableHints);
    }
    if (IS_ENABLED(@"redProgressBar_enabled")) {
        %init(gRedProgressBar);
    }
    if (IS_ENABLED(@"stickNavigationBar_enabled")) {
        %init(gStickNavigationBar);
    }
    if (IS_ENABLED(@"hideChipBar_enabled")) {
        %init(gHideChipBar);
    }
    if (IS_ENABLED(@"portraitFullscreen_enabled")) {
        %init(gPortraitFullscreen);
    }
    if (IS_ENABLED(@"iPhoneLayout_enabled") && (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)) {
        %init(giPhoneLayout);
    }
    if (IS_ENABLED(@"stockVolumeHUD_enabled")) {
        %init(gStockVolumeHUD);
    }
    if (IS_ENABLED(@"hideHeatwaves_enabled")) {
        %init(gHideHeatwaves);
    }
    if (IS_ENABLED(@"noRelatedWatchNexts_enabled")) {
        %init(gNoRelatedWatchNexts);
    }
    if (IS_ENABLED(@"noVideosInFullscreen_enabled")) {
        %init(gNoVideosInFullscreen);
    }
    if (IS_ENABLED(@"fixLowContrastMode_enabled")) {
        %init(gFixLowContrastMode);
    }
    if (IS_ENABLED(@"disableModernButtons_enabled")) {
        %init(gDisableModernButtons);
    }
    if (IS_ENABLED(@"disableRoundedHints_enabled")) {
        %init(gDisableRoundedHints);
    }
    if (IS_ENABLED(@"disableModernFlags_enabled")) {
        %init(gDisableModernFlags);
    }
    if (IS_ENABLED(@"disableAmbientMode_enabled")) {
        %init(gDisableAmbientMode);
    }
    if (IS_ENABLED(@"disableAccountSection_enabled")) {
        %init(gDisableAccountSection);
    }
    if (IS_ENABLED(@"disableAutoplaySection_enabled")) {
        %init(gDisableAutoplaySection);
    }
    if (IS_ENABLED(@"disableTryNewFeaturesSection_enabled")) {
        %init(gDisableTryNewFeaturesSection);
    }
    if (IS_ENABLED(@"disableVideoQualityPreferencesSection_enabled")) {
        %init(gDisableVideoQualityPreferencesSection);
    }
    if (IS_ENABLED(@"disableNotificationsSection_enabled")) {
        %init(gDisableNotificationsSection);
    }
    if (IS_ENABLED(@"disableManageAllHistorySection_enabled")) {
        %init(gDisableManageAllHistorySection);
    }
    if (IS_ENABLED(@"disableYourDataInYouTubeSection_enabled")) {
        %init(gDisableYourDataInYouTubeSection);
    }
    if (IS_ENABLED(@"disablePrivacySection_enabled")) {
        %init(gDisablePrivacySection);
    }
    if (IS_ENABLED(@"disableLiveChatSection_enabled")) {
        %init(gDisableLiveChatSection);
    }

    // YTNoModernUI - @arichorn
    BOOL ytNoModernUIEnabled = IS_ENABLED(@"ytNoModernUI_enabled");
    if (ytNoModernUIEnabled) {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:NO forKey:@"enableVersionSpoofer_enabled"];
    [userDefaults setBool:NO forKey:@"premiumYouTubeLogo_enabled"];
    } else {
    BOOL enableVersionSpooferEnabled = IS_ENABLED(@"enableVersionSpoofer_enabled");
    BOOL premiumYouTubeLogoEnabled = IS_ENABLED(@"premiumYouTubeLogo_enabled");

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:enableVersionSpooferEnabled forKey:@"enableVersionSpoofer_enabled"];
    [userDefaults setBool:premiumYouTubeLogoEnabled forKey:@"premiumYouTubeLogo_enabled"];
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"fixLowContrastMode_enabled"] forKey:@"fixLowContrastMode_enabled"];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"disableModernButtons_enabled"] forKey:@"disableModernButtons_enabled"];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"disableRoundedHints_enabled"] forKey:@"disableRoundedHints_enabled"];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"disableModernFlags_enabled"] forKey:@"disableModernFlags_enabled"];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"disableAmbientMode_enabled"] forKey:@"disableAmbientMode_enabled"];
    [userDefaults setBool:ytNoModernUIEnabled ? ytNoModernUIEnabled : [userDefaults boolForKey:@"redProgressBar_enabled"] forKey:@"redProgressBar_enabled"];

    // Change the default value of some options
    NSArray *allKeys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
    if (![allKeys containsObject:@"hidePlayNextInQueue_enabled"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hidePlayNextInQueue_enabled"];
    }
    if (![allKeys containsObject:@"relatedVideosAtTheEndOfYTVideos"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"relatedVideosAtTheEndOfYTVideos"]; 
    }
    if (![allKeys containsObject:@"shortsProgressBar"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shortsProgressBar"]; 
    }
    if (![allKeys containsObject:@"RYD-ENABLED"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RYD-ENABLED"]; 
    }
    if (![allKeys containsObject:@"YouPiPEnabled"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"YouPiPEnabled"]; 
    }
}
