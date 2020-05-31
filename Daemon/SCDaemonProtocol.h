//
//  SCDaemonProtocol.h
//  selfcontrold
//
//  Created by Charlie Stigler on 5/30/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SCDaemonProtocol <NSObject>

- (BOOL) install;

- (BOOL) checkup;

- (BOOL) getVersion;

@end

NS_ASSUME_NONNULL_END
