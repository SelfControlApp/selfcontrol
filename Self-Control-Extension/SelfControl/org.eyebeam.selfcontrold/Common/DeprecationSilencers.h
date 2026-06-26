//
//  DeprecationSilencers.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#ifndef DeprecationSilencers_h
#define DeprecationSilencers_h

// great idea taken from this guy: https://stackoverflow.com/a/26564750

#define SILENCE_DEPRECATION(expr)                                   \
do {                                                                \
_Pragma("clang diagnostic push")                                    \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")   \
expr;                                                               \
_Pragma("clang diagnostic pop")                                     \
} while(0)

#define SILENCE_OSX10_10_DEPRECATION(expr) SILENCE_DEPRECATION(expr)

#endif /* DeprecationSilencers_h */
