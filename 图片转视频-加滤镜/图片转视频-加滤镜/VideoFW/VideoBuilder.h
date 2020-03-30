#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>

typedef void(^VideoBuildCompletion) (NSString *videoPath);

@interface VideoBuilder : NSObject

- (void)makeVideoWithImage:(NSArray *)images
                     audio:(NSString *)audioFile
                completion:(VideoBuildCompletion)completion;

@end
