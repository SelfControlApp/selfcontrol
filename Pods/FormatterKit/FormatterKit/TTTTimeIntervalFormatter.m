// TTTTimeIntervalFormatter.m
//
// Copyright (c) 2011–2015 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TTTTimeIntervalFormatter.h"

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1090)
    #define TTTCalendarUnitYear NSCalendarUnitYear
    #define TTTCalendarUnitMonth NSCalendarUnitMonth
    #define TTTCalendarUnitWeek NSCalendarUnitWeekOfYear
    #define TTTCalendarUnitDay NSCalendarUnitDay
    #define TTTCalendarUnitHour NSCalendarUnitHour
    #define TTTCalendarUnitMinute NSCalendarUnitMinute
    #define TTTCalendarUnitSecond NSCalendarUnitSecond
    #define TTTCalendarUnitWeekday NSCalendarUnitWeekday
    #define TTTDateComponentUndefined NSDateComponentUndefined
#else
    #define TTTCalendarUnitYear NSYearCalendarUnit
    #define TTTCalendarUnitMonth NSMonthCalendarUnit
    #define TTTCalendarUnitWeek NSWeekOfYearCalendarUnit
    #define TTTCalendarUnitDay NSDayCalendarUnit
    #define TTTCalendarUnitHour NSHourCalendarUnit
    #define TTTCalendarUnitMinute NSMinuteCalendarUnit
    #define TTTCalendarUnitSecond NSSecondCalendarUnit
    #define TTTCalendarUnitWeekday NSWeekdayCalendarUnit
    #define TTTDateComponentUndefined NSUndefinedDateComponent
#endif

static inline NSCalendarUnit NSCalendarUnitFromString(NSString *string) {
    if ([string isEqualToString:@"year"]) {
        return TTTCalendarUnitYear;
    } else if ([string isEqualToString:@"month"]) {
        return TTTCalendarUnitMonth;
    } else if ([string isEqualToString:@"weekOfYear"]) {
        return TTTCalendarUnitWeek;
    } else if ([string isEqualToString:@"day"]) {
        return TTTCalendarUnitDay;
    } else if ([string isEqualToString:@"hour"]) {
        return TTTCalendarUnitHour;
    } else if ([string isEqualToString:@"minute"]) {
        return TTTCalendarUnitMinute;
    } else if ([string isEqualToString:@"second"]) {
        return TTTCalendarUnitSecond;
    }

    return TTTDateComponentUndefined;
}

static inline NSComparisonResult NSCalendarUnitCompareSignificance(NSCalendarUnit a, NSCalendarUnit b) {
    if ((a == TTTCalendarUnitWeek) ^ (b == TTTCalendarUnitWeek)) {
        if (a == TTTCalendarUnitWeek) {
            switch (a) {
                case TTTCalendarUnitYear:
                case TTTCalendarUnitMonth:
                    return NSOrderedAscending;
                default:
                    return NSOrderedDescending;
            }
        } else {
            switch (b) {
                case TTTCalendarUnitYear:
                case TTTCalendarUnitMonth:
                    return NSOrderedDescending;
                default:
                    return NSOrderedAscending;
            }
        }
    } else {
        if (a > b) {
            return NSOrderedAscending;
        } else if (a < b) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }
}

@implementation TTTTimeIntervalFormatter
@synthesize locale = _locale;
@synthesize calendar = _calendar;
@synthesize pastDeicticExpression = _pastDeicticExpression;
@synthesize presentDeicticExpression = _presentDeicticExpression;
@synthesize futureDeicticExpression = _futureDeicticExpression;
@synthesize deicticExpressionFormat = _deicticExpressionFormat;
@synthesize suffixExpressionFormat = _suffixExpressionFormat;
@synthesize approximateQualifierFormat = _approximateQualifierFormat;
@synthesize presentTimeIntervalMargin = _presentTimeIntervalMargin;
@synthesize usesAbbreviatedCalendarUnits = _usesAbbreviatedCalendarUnits;
@synthesize usesApproximateQualifier = _usesApproximateQualifier;
@synthesize usesIdiomaticDeicticExpressions = _usesIdiomaticDeicticExpressions;
@synthesize numberOfSignificantUnits = _numberOfSignificantUnits;
@synthesize leastSignificantUnit = _leastSignificantUnit;
@synthesize significantUnits = _significantUnits;

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.locale = [NSLocale currentLocale];
    self.calendar = [NSCalendar currentCalendar];

    self.pastDeicticExpression = NSLocalizedStringFromTable(@"ago", @"FormatterKit", @"Past Deictic Expression");
    self.presentDeicticExpression = NSLocalizedStringFromTable(@"just now", @"FormatterKit", @"Present Deictic Expression");
    self.futureDeicticExpression = NSLocalizedStringFromTable(@"from now", @"FormatterKit", @"Future Deictic Expression");

    self.deicticExpressionFormat = NSLocalizedStringWithDefaultValue(@"Deictic Expression Format String", @"FormatterKit", [NSBundle mainBundle], @"%@ %@", @"Deictic Expression Format (#{Time} #{Ago/From Now}");
    self.approximateQualifierFormat = NSLocalizedStringFromTable(@"about %@", @"FormatterKit", @"Approximate Qualifier Format");
    self.suffixExpressionFormat = NSLocalizedStringWithDefaultValue(@"Suffix Expression Format String", @"FormatterKit", [NSBundle mainBundle], @"%@ %@", @"Suffix Expression Format (#{Time} #{Unit})");

    self.presentTimeIntervalMargin = 1;

    self.significantUnits = TTTCalendarUnitYear | TTTCalendarUnitMonth | TTTCalendarUnitWeek | TTTCalendarUnitDay | TTTCalendarUnitHour | TTTCalendarUnitMinute | TTTCalendarUnitSecond;
    self.numberOfSignificantUnits = 1;
    self.leastSignificantUnit = TTTCalendarUnitSecond;

    return self;
}

- (NSString *)stringForTimeInterval:(NSTimeInterval)seconds {
    NSDate *date = [NSDate date];
    return [self stringForTimeIntervalFromDate:date toDate:[NSDate dateWithTimeInterval:seconds sinceDate:date]];
}

- (NSString *)stringForTimeIntervalFromDate:(NSDate *)startingDate
                                     toDate:(NSDate *)endingDate
{
    NSTimeInterval seconds = [startingDate timeIntervalSinceDate:endingDate];
    if (fabs(seconds) < self.presentTimeIntervalMargin) {
        return self.presentDeicticExpression;
    }

    NSDateComponents *components = [self.calendar components:self.significantUnits fromDate:startingDate toDate:endingDate options:0];

    if (self.usesIdiomaticDeicticExpressions) {
        NSString *idiomaticDeicticExpression = [self localizedIdiomaticDeicticExpressionForComponents:components];
        if (idiomaticDeicticExpression) {
            return idiomaticDeicticExpression;
        }
    }

    NSString *string = nil;
    BOOL isApproximate = NO;
    NSUInteger numberOfUnits = 0;
    for (NSString *unitName in @[@"year", @"month", @"weekOfYear", @"day", @"hour", @"minute", @"second"]) {
        NSCalendarUnit unit = NSCalendarUnitFromString(unitName);
        if ((self.significantUnits & unit) && NSCalendarUnitCompareSignificance(self.leastSignificantUnit, unit) != NSOrderedDescending) {
            NSNumber *number = @(abs((int)[[components valueForKey:unitName] integerValue]));
            if ([number integerValue]) {
                NSString *suffix = [NSString stringWithFormat:self.suffixExpressionFormat, number, [self localizedStringForNumber:[number unsignedIntegerValue] ofCalendarUnit:unit]];
                if (!string) {
                    string = suffix;
                } else if (self.numberOfSignificantUnits == 0 || numberOfUnits < self.numberOfSignificantUnits) {
                    string = [string stringByAppendingFormat:@" %@", suffix];
                } else {
                    isApproximate = YES;
                }

                numberOfUnits++;
            }
        }
    }

    if (string) {
        if (seconds > 0) {
            if ([self.pastDeicticExpression length]) {
                string = [NSString stringWithFormat:self.deicticExpressionFormat, string, self.pastDeicticExpression];
            }
        } else {
            if ([self.futureDeicticExpression length]) {
                string = [NSString stringWithFormat:self.deicticExpressionFormat, string, self.futureDeicticExpression];
            }
        }

        if (isApproximate && self.usesApproximateQualifier) {
            string = [NSString stringWithFormat:self.approximateQualifierFormat, string];
        }
    } else {
        string = self.presentDeicticExpression;
    }

    return string;
}

- (NSString *)localizedStringForNumber:(NSUInteger)number ofCalendarUnit:(NSCalendarUnit)unit {
    BOOL singular = (number == 1);

    if (self.usesAbbreviatedCalendarUnits) {
        switch (unit) {
            case TTTCalendarUnitYear:
                return singular ? NSLocalizedStringFromTable(@"yr", @"FormatterKit", @"Year Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"yrs", @"FormatterKit", @"Year Unit (Plural, Abbreviated)");
            case TTTCalendarUnitMonth:
                return singular ? NSLocalizedStringFromTable(@"mo", @"FormatterKit", @"Month Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"mos", @"FormatterKit", @"Month Unit (Plural, Abbreviated)");
            case TTTCalendarUnitWeek:
                return singular ? NSLocalizedStringFromTable(@"wk", @"FormatterKit", @"Week Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"wks", @"FormatterKit", @"Week Unit (Plural, Abbreviated)");
            case TTTCalendarUnitDay:
                return singular ? NSLocalizedStringFromTable(@"d", @"FormatterKit", @"Day Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"days", @"FormatterKit", @"Day Unit (Plural, Abbreviated)");
            case TTTCalendarUnitHour:
                return singular ? NSLocalizedStringFromTable(@"hr", @"FormatterKit", @"Hour Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"hrs", @"FormatterKit", @"Hour Unit (Plural, Abbreviated)");
            case TTTCalendarUnitMinute:
                return singular ? NSLocalizedStringFromTable(@"min", @"FormatterKit", @"Minute Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"mins", @"FormatterKit", @"Minute Unit (Plural, Abbreviated)");
            case TTTCalendarUnitSecond:
                return singular ? NSLocalizedStringFromTable(@"s", @"FormatterKit", @"Second Unit (Singular, Abbreviated)") : NSLocalizedStringFromTable(@"s", @"FormatterKit", @"Second Unit (Plural, Abbreviated)");
            default:
                return nil;
        }
    } else {
        switch (unit) {
            case TTTCalendarUnitYear:
                return singular ? NSLocalizedStringFromTable(@"year", @"FormatterKit", @"Year Unit (Singular)") : NSLocalizedStringFromTable(@"years", @"FormatterKit", @"Year Unit (Plural)");
            case TTTCalendarUnitMonth:
                return singular ? NSLocalizedStringFromTable(@"month", @"FormatterKit", @"Month Unit (Singular)") : NSLocalizedStringFromTable(@"months", @"FormatterKit", @"Month Unit (Plural)");
            case TTTCalendarUnitWeek:
                return singular ? NSLocalizedStringFromTable(@"week", @"FormatterKit", @"Week Unit (Singular)") : NSLocalizedStringFromTable(@"weeks", @"FormatterKit", @"Week Unit (Plural)");
            case TTTCalendarUnitDay:
                return singular ? NSLocalizedStringFromTable(@"day", @"FormatterKit", @"Day Unit (Singular)") : NSLocalizedStringFromTable(@"days", @"FormatterKit", @"Day Unit (Plural)");
            case TTTCalendarUnitHour:
                return singular ? NSLocalizedStringFromTable(@"hour", @"FormatterKit", @"Hour Unit (Singular)") : NSLocalizedStringFromTable(@"hours", @"FormatterKit", @"Hour Unit (Plural)");
            case TTTCalendarUnitMinute:
                return singular ? NSLocalizedStringFromTable(@"minute", @"FormatterKit", @"Minute Unit (Singular)") : NSLocalizedStringFromTable(@"minutes", @"FormatterKit", @"Minute Unit (Plural)");
            case TTTCalendarUnitSecond:
                return singular ? NSLocalizedStringFromTable(@"second", @"FormatterKit", @"Second Unit (Singular)") : NSLocalizedStringFromTable(@"seconds", @"FormatterKit", @"Second Unit (Plural)");
            default:
                return nil;
        }
    }
}

#pragma mark -

- (NSString *)localizedIdiomaticDeicticExpressionForComponents:(NSDateComponents *)components {
    NSString *languageCode = [self.locale objectForKey:NSLocaleLanguageCode];
    if ([languageCode isEqualToString:@"ca"]) {
        return [self caRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"cs"]) {
        return [self csRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"es"]) {
        return [self esRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"en"]) {
        return [self enRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"fr"]) {
        return [self frRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"it"]) {
        return [self itRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"ja"]) {
        return [self jaRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"nl"]) {
        return [self nlRelativeDateStringForComponents:components];
    } else if ([languageCode isEqualToString:@"pl"]) {
        return [self plRelativeDateStringForComponents:components];
    }

    return nil;
}

- (NSString *)caRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"any passat";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"mes passat";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"setmana passada";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"ahir";
    } else if ([components day] == -2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"abans d'ahir";
    }

    if ([components year] == 1) {
        return @"pròxim any";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"pròxim mes";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"pròxima setmana";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"demà";
    } else if ([components day] == 2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"passat demà";
    }

    return nil;
}

- (NSString *)enRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"last year";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"last month";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"last week";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"yesterday";
    }

    if ([components year] == 1) {
        return @"next year";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"next month";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"next week";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"tomorrow";
    }

    return nil;
}

- (NSString *)esRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"año pasado";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"mes pasado";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"semana pasada";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"ayer";
    } else if ([components day] == -2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"antes de ayer";
    }

    if ([components year] == 1) {
        return @"próximo año";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"próximo mes";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"próxima semana";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"mañana";
    } else if ([components day] == 2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"pasado mañana";
    }

    return nil;
}

- (NSString *)nlRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"vorig jaar";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"vorige maand";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"vorige week";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"gisteren";
    } else if ([components day] == -2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"eergisteren";
    }

    if ([components year] == 1) {
        return @"volgend jaar";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"volgende maand";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"volgende week";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"morgen";
    } else if ([components day] == 2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"overmorgen";
    }

    return nil;
}

- (NSString *)plRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"zeszły rok";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"zeszły miesiąc";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"zeszły tydzień";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"wczoraj";
    } else if ([components day] == -2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"przedwczoraj";
    }

    if ([components year] == 1) {
        return @"przyszły rok";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"przyszły miesiąc";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"przyszły tydzień";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"jutro";
    } else if ([components day] == 2 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"pojutrze";
    }

    return nil;
}

- (NSString *)csRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"minulý rok";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"minulý měsíc";
    } else if ([components weekOfYear] == -1 && [components month] == 0 && [components year] == 0) {
        return @"minulý týden";
    } else if ([components day] == -1 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"včera";
    } else if ([components day] == -2 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"předevčírem";
    }

    if ([components year] == 1) {
        return @"příští rok";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"příští měsíc";
    } else if ([components weekOfYear] == 1 && [components month] == 0 && [components year] == 0) {
        return @"příští týden";
    } else if ([components day] == 1 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"zítra";
    } else if ([components day] == 2 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"pozítří";
    }

    return nil;
}

- (NSString *)jaRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"去年";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"先月";
    } else if ([components weekOfYear] == -1 && [components month] == 0 && [components year] == 0) {
        return @"先週";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"昨日";
    }

    if ([components year] == 1) {
        return @"来年";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"来月";
    } else if ([components weekOfYear] == 1 && [components month] == 0 && [components year] == 0) {
        return @"来週";
    } else if ([components day] == 1 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"明日";
    }

    return nil;
}

- (NSString *)frRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"l'annnée dernière";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"le mois dernier";
    } else if ([components weekOfYear] == -1 && [components month] == 0 && [components year] == 0) {
        return @"la semaine dernière";
    } else if ([components day] == -1 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"hier";
    }

    if ([components year] == 1) {
        return @"l'année prochaine";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"le mois prochain";
    } else if ([components weekOfYear] == 1 && [components month] == 0 && [components year] == 0) {
        return @"la semaine prochaine";
    } else if ([components day] == 1 && [components weekOfYear] == 0 && [components month] == 0 && [components year] == 0) {
        return @"demain";
    }

    return nil;
}

- (NSString *)itRelativeDateStringForComponents:(NSDateComponents *)components {
    if ([components year] == -1) {
        return @"un anno fa";
    } else if ([components month] == -1 && [components year] == 0) {
        return @"un mese fa";
    } else if ([components weekOfYear] == -1 && [components year] == 0 && [components month] == 0) {
        return @"una settimana fa";
    } else if ([components day] == -1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"ieri";
    }

    if ([components year] == 1) {
        return @"l'anno prossimo";
    } else if ([components month] == 1 && [components year] == 0) {
        return @"il mese prossimo";
    } else if ([components weekOfYear] == 1 && [components year] == 0 && [components month] == 0) {
        return @"la prossima settimana";
    } else if ([components day] == 1 && [components year] == 0 && [components month] == 0 && [components weekOfYear] == 0) {
        return @"domani";
    }

    return nil;
}

#pragma mark - NSFormatter

- (NSString *)stringForObjectValue:(id)anObject {
    if (![anObject isKindOfClass:[NSNumber class]]) {
        return nil;
    }

    return [self stringForTimeInterval:[(NSNumber *)anObject doubleValue]];
}

- (BOOL)getObjectValue:(out __unused __autoreleasing id *)obj
             forString:(__unused NSString *)string
      errorDescription:(out NSString *__autoreleasing *)error
{
    *error = NSLocalizedStringFromTable(@"Method Not Implemented", @"FormatterKit", nil);

    return NO;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    TTTTimeIntervalFormatter *formatter = [[[self class] allocWithZone:zone] init];

    formatter.locale = [self.locale copyWithZone:zone];
    formatter.pastDeicticExpression = [self.pastDeicticExpression copyWithZone:zone];
    formatter.presentDeicticExpression = [self.presentDeicticExpression copyWithZone:zone];
    formatter.futureDeicticExpression = [self.futureDeicticExpression copyWithZone:zone];
    formatter.deicticExpressionFormat = [self.deicticExpressionFormat copyWithZone:zone];
    formatter.approximateQualifierFormat = [self.approximateQualifierFormat copyWithZone:zone];
    formatter.presentTimeIntervalMargin = self.presentTimeIntervalMargin;
    formatter.usesAbbreviatedCalendarUnits = self.usesAbbreviatedCalendarUnits;
    formatter.usesApproximateQualifier = self.usesApproximateQualifier;
    formatter.usesIdiomaticDeicticExpressions = self.usesIdiomaticDeicticExpressions;

    return formatter;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    self.locale = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(locale))];
    self.pastDeicticExpression = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(pastDeicticExpression))];
    self.presentDeicticExpression = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(presentDeicticExpression))];
    self.futureDeicticExpression = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(futureDeicticExpression))];
    self.deicticExpressionFormat = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(deicticExpressionFormat))];
    self.approximateQualifierFormat = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(approximateQualifierFormat))];
    self.presentTimeIntervalMargin = [aDecoder decodeDoubleForKey:NSStringFromSelector(@selector(presentTimeIntervalMargin))];
    self.usesAbbreviatedCalendarUnits = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(usesAbbreviatedCalendarUnits))];
    self.usesApproximateQualifier = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(usesApproximateQualifier))];
    self.usesIdiomaticDeicticExpressions = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(usesIdiomaticDeicticExpressions))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:self.locale forKey:NSStringFromSelector(@selector(locale))];
    [aCoder encodeObject:self.pastDeicticExpression forKey:NSStringFromSelector(@selector(pastDeicticExpression))];
    [aCoder encodeObject:self.presentDeicticExpression forKey:NSStringFromSelector(@selector(presentDeicticExpression))];
    [aCoder encodeObject:self.futureDeicticExpression forKey:NSStringFromSelector(@selector(futureDeicticExpression))];
    [aCoder encodeObject:self.deicticExpressionFormat forKey:NSStringFromSelector(@selector(deicticExpressionFormat))];
    [aCoder encodeObject:self.approximateQualifierFormat forKey:NSStringFromSelector(@selector(approximateQualifierFormat))];
    [aCoder encodeDouble:self.presentTimeIntervalMargin forKey:NSStringFromSelector(@selector(presentTimeIntervalMargin))];
    [aCoder encodeBool:self.usesAbbreviatedCalendarUnits forKey:NSStringFromSelector(@selector(usesAbbreviatedCalendarUnits))];
    [aCoder encodeBool:self.usesApproximateQualifier forKey:NSStringFromSelector(@selector(usesApproximateQualifier))];
    [aCoder encodeBool:self.usesIdiomaticDeicticExpressions forKey:NSStringFromSelector(@selector(usesIdiomaticDeicticExpressions))];
}

@end
