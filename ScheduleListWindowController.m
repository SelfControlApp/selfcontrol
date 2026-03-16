//
//  ScheduleListWindowController.m
//  SelfControl
//
//  Window controller for managing recurring scheduled blocks.
//

#import "ScheduleListWindowController.h"
#import "SCScheduleManager.h"
#import "SCSchedule.h"

// Tag constants for day checkboxes in the edit sheet
static const NSInteger kDayCheckboxTagBase = 100;

@interface ScheduleListWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSMutableArray<SCSchedule *> *schedules;

// Edit sheet controls
@property (nonatomic, strong) NSWindow *editSheet;
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSArray<NSButton *> *dayCheckboxes;
@property (nonatomic, strong) NSDatePicker *timePicker;
@property (nonatomic, strong) NSTextField *durationField;
@property (nonatomic, strong) NSTextField *blocklistField;
@property (nonatomic, strong) SCSchedule *editingSchedule; // nil = adding new
@end

@implementation ScheduleListWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 400)
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Scheduled Blocks";
    window.minSize = NSMakeSize(500, 300);

    if (self = [super initWithWindow:window]) {
        [self setupUI];
        [self reloadSchedules];
    }
    return self;
}

- (void)setupUI {
    NSView *contentView = self.window.contentView;

    // Scroll view + table view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 44, 640, 356)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 24;

    NSTableColumn *enabledCol = [[NSTableColumn alloc] initWithIdentifier:@"enabled"];
    enabledCol.title = @"On";
    enabledCol.width = 30;
    enabledCol.minWidth = 30;
    enabledCol.maxWidth = 30;
    [_tableView addTableColumn:enabledCol];

    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameCol.title = @"Name";
    nameCol.width = 150;
    [_tableView addTableColumn:nameCol];

    NSTableColumn *daysCol = [[NSTableColumn alloc] initWithIdentifier:@"days"];
    daysCol.title = @"Days";
    daysCol.width = 180;
    [_tableView addTableColumn:daysCol];

    NSTableColumn *timeCol = [[NSTableColumn alloc] initWithIdentifier:@"time"];
    timeCol.title = @"Time";
    timeCol.width = 70;
    [_tableView addTableColumn:timeCol];

    NSTableColumn *durationCol = [[NSTableColumn alloc] initWithIdentifier:@"duration"];
    durationCol.title = @"Duration";
    durationCol.width = 80;
    [_tableView addTableColumn:durationCol];

    scrollView.documentView = _tableView;
    [contentView addSubview:scrollView];

    // Button bar at bottom
    NSButton *addButton = [NSButton buttonWithTitle:@"Add" target:self action:@selector(addSchedule:)];
    addButton.frame = NSMakeRect(10, 10, 80, 24);
    addButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [contentView addSubview:addButton];

    NSButton *editButton = [NSButton buttonWithTitle:@"Edit" target:self action:@selector(editSchedule:)];
    editButton.frame = NSMakeRect(100, 10, 80, 24);
    editButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [contentView addSubview:editButton];

    NSButton *removeButton = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeSchedule:)];
    removeButton.frame = NSMakeRect(190, 10, 80, 24);
    removeButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [contentView addSubview:removeButton];
}

- (void)reloadSchedules {
    self.schedules = [[[SCScheduleManager sharedManager] allSchedules] mutableCopy];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addSchedule:(id)sender {
    self.editingSchedule = nil;
    [self showEditSheet];
}

- (void)editSchedule:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || (NSUInteger)row >= self.schedules.count) return;
    self.editingSchedule = self.schedules[(NSUInteger)row];
    [self showEditSheet];
}

- (void)removeSchedule:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || (NSUInteger)row >= self.schedules.count) return;

    SCSchedule *schedule = self.schedules[(NSUInteger)row];
    [[SCScheduleManager sharedManager] removeSchedule:schedule];
    [[SCScheduleManager sharedManager] syncAllLaunchdAgents];
    [self reloadSchedules];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.schedules.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= self.schedules.count) return nil;
    SCSchedule *schedule = self.schedules[(NSUInteger)row];
    NSString *ident = tableColumn.identifier;

    if ([ident isEqualToString:@"enabled"]) {
        return @(schedule.enabled);
    } else if ([ident isEqualToString:@"name"]) {
        return schedule.name;
    } else if ([ident isEqualToString:@"days"]) {
        return [self daysSummaryForSchedule:schedule];
    } else if ([ident isEqualToString:@"time"]) {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)schedule.hour, (long)schedule.minute];
    } else if ([ident isEqualToString:@"duration"]) {
        if (schedule.durationMinutes >= 60) {
            NSInteger hours = schedule.durationMinutes / 60;
            NSInteger mins = schedule.durationMinutes % 60;
            if (mins > 0) {
                return [NSString stringWithFormat:@"%ldh %ldm", (long)hours, (long)mins];
            }
            return [NSString stringWithFormat:@"%ldh", (long)hours];
        }
        return [NSString stringWithFormat:@"%ldm", (long)schedule.durationMinutes];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= self.schedules.count) return;
    SCSchedule *schedule = self.schedules[(NSUInteger)row];

    if ([tableColumn.identifier isEqualToString:@"enabled"]) {
        schedule.enabled = [object boolValue];
        [[SCScheduleManager sharedManager] updateSchedule:schedule];
        [[SCScheduleManager sharedManager] syncAllLaunchdAgents];
        [self reloadSchedules];
    }
}

#pragma mark - NSTableViewDelegate

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tableColumn.identifier isEqualToString:@"enabled"]) {
        NSButtonCell *cell = [[NSButtonCell alloc] init];
        [cell setButtonType:NSButtonTypeSwitch];
        [cell setTitle:@""];
        return cell;
    }
    return nil; // use default text cell
}

#pragma mark - Edit Sheet

- (void)showEditSheet {
    NSWindow *sheet = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 320)
                                                  styleMask:(NSWindowStyleMaskTitled)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    sheet.title = self.editingSchedule ? @"Edit Schedule" : @"New Schedule";
    self.editSheet = sheet;

    NSView *content = sheet.contentView;
    CGFloat y = 280;
    CGFloat labelW = 80;
    CGFloat fieldX = 90;

    // Name
    [self addLabel:@"Name:" at:NSMakePoint(10, y) inView:content width:labelW];
    _nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, y, 330, 22)];
    [content addSubview:_nameField];

    // Days
    y -= 36;
    [self addLabel:@"Days:" at:NSMakePoint(10, y) inView:content width:labelW];
    NSArray *dayNames = @[@"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat"];
    NSMutableArray *checkboxes = [NSMutableArray array];
    for (NSUInteger i = 0; i < 7; i++) {
        NSButton *cb = [NSButton checkboxWithTitle:dayNames[i] target:nil action:nil];
        cb.frame = NSMakeRect(fieldX + (CGFloat)i * 48, y, 46, 22);
        cb.tag = kDayCheckboxTagBase + (NSInteger)i;
        [content addSubview:cb];
        [checkboxes addObject:cb];
    }
    _dayCheckboxes = [checkboxes copy];

    // Time
    y -= 36;
    [self addLabel:@"Time:" at:NSMakePoint(10, y) inView:content width:labelW];
    _timePicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(fieldX, y, 100, 22)];
    _timePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    _timePicker.datePickerElements = NSDatePickerElementFlagHourMinute;
    // Set a default date with the desired hour/minute
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    comps.hour = 9;
    comps.minute = 0;
    comps.year = 2025;
    comps.month = 1;
    comps.day = 1;
    _timePicker.dateValue = [cal dateFromComponents:comps];
    [content addSubview:_timePicker];

    // Duration
    y -= 36;
    [self addLabel:@"Duration:" at:NSMakePoint(10, y) inView:content width:labelW];
    _durationField = [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, y, 80, 22)];
    _durationField.placeholderString = @"minutes";
    [content addSubview:_durationField];
    NSTextField *minLabel = [NSTextField labelWithString:@"minutes"];
    minLabel.frame = NSMakeRect(fieldX + 86, y, 60, 22);
    [content addSubview:minLabel];

    // Blocklist
    y -= 36;
    [self addLabel:@"Blocklist:" at:NSMakePoint(10, y) inView:content width:labelW];
    _blocklistField = [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, y - 60, 330, 80)];
    _blocklistField.placeholderString = @"Enter domains, one per line (e.g. facebook.com)";
    [content addSubview:_blocklistField];

    // Buttons
    NSButton *cancelBtn = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelEditSheet:)];
    cancelBtn.frame = NSMakeRect(260, 10, 80, 30);
    cancelBtn.keyEquivalent = @"\033"; // Escape
    [content addSubview:cancelBtn];

    NSButton *saveBtn = [NSButton buttonWithTitle:@"Save" target:self action:@selector(saveEditSheet:)];
    saveBtn.frame = NSMakeRect(350, 10, 80, 30);
    saveBtn.keyEquivalent = @"\r"; // Enter
    [content addSubview:saveBtn];

    // Populate if editing
    if (self.editingSchedule) {
        _nameField.stringValue = self.editingSchedule.name ?: @"";
        for (NSNumber *day in self.editingSchedule.weekdays) {
            NSInteger idx = [day integerValue];
            if (idx >= 0 && idx < 7) {
                _dayCheckboxes[(NSUInteger)idx].state = NSControlStateValueOn;
            }
        }
        NSDateComponents *timeComps = [[NSDateComponents alloc] init];
        timeComps.hour = self.editingSchedule.hour;
        timeComps.minute = self.editingSchedule.minute;
        timeComps.year = 2025;
        timeComps.month = 1;
        timeComps.day = 1;
        _timePicker.dateValue = [cal dateFromComponents:timeComps];
        _durationField.integerValue = self.editingSchedule.durationMinutes;
        _blocklistField.stringValue = [self.editingSchedule.blocklist componentsJoinedByString:@"\n"];
    } else {
        _durationField.integerValue = 60;
    }

    [self.window beginSheet:sheet completionHandler:nil];
}

- (void)addLabel:(NSString *)text at:(NSPoint)origin inView:(NSView *)view width:(CGFloat)width {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = NSMakeRect(origin.x, origin.y, width, 22);
    label.alignment = NSTextAlignmentRight;
    [view addSubview:label];
}

- (void)cancelEditSheet:(id)sender {
    [self.window endSheet:self.editSheet];
    self.editSheet = nil;
    self.editingSchedule = nil;
}

- (void)saveEditSheet:(id)sender {
    SCSchedule *schedule = self.editingSchedule ?: [[SCSchedule alloc] init];

    schedule.name = _nameField.stringValue;

    // Collect selected weekdays
    NSMutableArray<NSNumber *> *days = [NSMutableArray array];
    for (NSUInteger i = 0; i < 7; i++) {
        if (_dayCheckboxes[i].state == NSControlStateValueOn) {
            [days addObject:@(i)];
        }
    }
    schedule.weekdays = days;

    // Extract hour and minute from the date picker
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:_timePicker.dateValue];
    schedule.hour = comps.hour;
    schedule.minute = comps.minute;

    schedule.durationMinutes = MAX(_durationField.integerValue, 1);

    // Parse blocklist: split by newlines and commas, trim whitespace
    NSString *raw = _blocklistField.stringValue;
    NSMutableArray<NSString *> *entries = [NSMutableArray array];
    for (NSString *line in [raw componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            [entries addObject:trimmed];
        }
    }
    schedule.blocklist = entries;

    if (self.editingSchedule) {
        [[SCScheduleManager sharedManager] updateSchedule:schedule];
    } else {
        schedule.enabled = YES;
        [[SCScheduleManager sharedManager] addSchedule:schedule];
    }

    [[SCScheduleManager sharedManager] syncAllLaunchdAgents];

    [self.window endSheet:self.editSheet];
    self.editSheet = nil;
    self.editingSchedule = nil;
    [self reloadSchedules];
}

#pragma mark - Helpers

- (NSString *)daysSummaryForSchedule:(SCSchedule *)schedule {
    if (schedule.weekdays.count == 0) return @"Daily";
    if (schedule.weekdays.count == 7) return @"Every day";

    // Check for weekdays (Mon-Fri)
    NSSet *weekdaySet = [NSSet setWithArray:schedule.weekdays];
    NSSet *monFri = [NSSet setWithArray:@[@1, @2, @3, @4, @5]];
    if ([weekdaySet isEqualToSet:monFri]) return @"Weekdays";

    NSSet *satSun = [NSSet setWithArray:@[@0, @6]];
    if ([weekdaySet isEqualToSet:satSun]) return @"Weekends";

    NSArray *abbrevs = @[@"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat"];
    NSMutableArray *names = [NSMutableArray array];
    // Sort weekdays for display
    NSArray *sorted = [schedule.weekdays sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *day in sorted) {
        NSUInteger idx = [day unsignedIntegerValue];
        if (idx < 7) {
            [names addObject:abbrevs[idx]];
        }
    }
    return [names componentsJoinedByString:@", "];
}

@end
