//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 shaydes.dsgn
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//  SDFCalendarOSXCalendarViewController.m
//  SDFCalendarOSX
//
//  Created by Trent Milton on 14/05/2014.
//  Copyright (c) 2014 shaydes.dsgn. All rights reserved.
//

#import "SDFCalendarOSXCalendarViewController.h"
#import "SDFCalendarOSXConstants.h"
#import "SDFCalendarOSXMonthView.h"
#import "DateTools.h"

static NSString *kSDFCalendarOSXCalendarDayNibName = @"SDFCalendarOSXCalendarDay";
static NSColor *kSDFCalendarOSXHeaderBackgroundColour;
static NSColor *kSDFCalendarOSXHeaderLabelColour;
static NSFont *kSDFCalendarOSXHeaderFont;
static NSColor *kSDFCalendarOSXMonthDayNamesBackgroundColour;
static NSColor *kSDFCalendarOSXMonthDayNamesLabelColour;
static NSFont *kSDFCalendarOSXMonthDayNamesFont;

@interface SDFCalendarOSXCalendarViewController ()

@property (nonatomic, strong) NSMutableArray *dayVCs;
@property (nonatomic, strong) NSDate *currentMonthDate;
@property (nonatomic, strong) NSArray *dayEventDates;
@property (nonatomic, strong) NSDate *selectedDate;

@end

@implementation SDFCalendarOSXCalendarViewController

+ (void)setCalendarDayNibName:(NSString *)nibName
{
	kSDFCalendarOSXCalendarDayNibName = nibName;
}

+ (void)setHeaderBackgroundColour:(NSColor *)colour
{
	kSDFCalendarOSXHeaderBackgroundColour = colour;
}

+ (void)setHeaderLabelColour:(NSColor *)colour
{
	kSDFCalendarOSXHeaderLabelColour = colour;
}

+ (void)setHeaderFontAndSize:(NSFont *)font
{
	kSDFCalendarOSXHeaderFont = font;
}

+ (void)setMonthDayNamesBackgroundColour:(NSColor *)colour
{
	kSDFCalendarOSXMonthDayNamesBackgroundColour = colour;
}

+ (void)setMonthDayNamesLabelColour:(NSColor *)colour
{
	kSDFCalendarOSXMonthDayNamesLabelColour = colour;
}

+ (void)setMonthDayNamesFont:(NSFont *)font
{
	kSDFCalendarOSXMonthDayNamesFont = font;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
	}
	return self;
}

- (void)awakeFromNib
{

	// Background
	self.view.wantsLayer = YES;
    // User header for background if available
	self.view.layer.backgroundColor = kSDFCalendarOSXHeaderBackgroundColour ? kSDFCalendarOSXHeaderBackgroundColour.CGColor : [NSColor grayColor].CGColor;

	self.currentMonthDate = [self startOfMonthDate:[NSDate new]];

	// Customisation
	if (self.headerView) {
		if (kSDFCalendarOSXHeaderBackgroundColour) {
			[self.headerView setBackgroundColour:kSDFCalendarOSXHeaderBackgroundColour];
		}
		if (kSDFCalendarOSXHeaderLabelColour) {
			self.yearLabel.textColor = kSDFCalendarOSXHeaderLabelColour;
			self.monthLabel.textColor = kSDFCalendarOSXHeaderLabelColour;
		}
		if (kSDFCalendarOSXHeaderFont) {
			self.yearLabel.font = kSDFCalendarOSXHeaderFont;
			self.monthLabel.font = kSDFCalendarOSXHeaderFont;
		}
	}

	if (self.monthDayNamesView) {
		if (kSDFCalendarOSXMonthDayNamesBackgroundColour) {
			[self.monthDayNamesView setBackgroundColour:kSDFCalendarOSXMonthDayNamesBackgroundColour];
		}
		for (id sv in self.monthDayNamesView.subviews) {
			if ([sv isKindOfClass:[NSTextField class]]) {
				if (kSDFCalendarOSXMonthDayNamesLabelColour) {
					((NSTextView *)sv).textColor = kSDFCalendarOSXMonthDayNamesLabelColour;
				}
				if (kSDFCalendarOSXMonthDayNamesFont) {
					((NSTextView *)sv).font = kSDFCalendarOSXMonthDayNamesFont;
				}
			}
		}
	}

	[self setupMonth];
}

- (void)setupMonth
{
	// Some warnings to make sure the below works as expected
	NSAssert((int)self.monthView.frame.size.width % (int)kSDFCalendarOSXGrid.x == 0, @"SDFCalendarOSXMonthView width must be a multiple of kSDFCalendarOSXGrid.x");
	NSAssert((int)self.monthView.frame.size.height % (int)kSDFCalendarOSXGrid.y == 0, @"SDFCalendarOSXMonthView height must be a multiple of kSDFCalendarOSXGrid.y");

	BOOL firstRun = !self.dayVCs;
	if (firstRun) {
		self.dayVCs = [NSMutableArray new];
	}

	// We need to get the starting day for the grid
	// Work out what the first day of the month was in terms of the weekday
	// Reset to midnight so the dates look nice on debug printout
	NSDate *som = [self.currentMonthDate dateBySubtractingDays:self.currentMonthDate.day - 1];
	// What is the start of month day of the week (Sunday = 0)
	NSInteger somdow = som.weekday;
	if (somdow == 1) {
		somdow = 8;
	}
	// Whatever it is is how far we want to go back from the start of the month to show on the first grid entry
	NSDate *currentGridDate = [som dateBySubtractingDays:somdow - 1];

	// Fill the month view with as a kSDFCalendarOSXGrid
	// Load them into the view from the top left then shift across right. Move down and repeat from left to right until we reach the bottom right.
	CGSize daySize = CGSizeMake(self.monthView.frame.size.width / kSDFCalendarOSXGrid.x, self.monthView.frame.size.height / kSDFCalendarOSXGrid.y);
	int i = 0;
	for (int y = 1; y <= kSDFCalendarOSXGrid.y; y++) {
		for (int x = 0; x < kSDFCalendarOSXGrid.x; x++) {
			SDFCalendarOSXDayViewController *dvc;
			// Only make a new VC when first run
			if (firstRun) {
				dvc = [[SDFCalendarOSXDayViewController alloc] initWithNibName:kSDFCalendarOSXCalendarDayNibName bundle:nil];
				dvc.delegate = self;
			} else {
				dvc = [self.dayVCs objectAtIndex:i];
			}

			dvc.date = [currentGridDate copy];
			dvc.currentMonth = currentGridDate.month == self.currentMonthDate.month;

			// Day events highlight
			BOOL match = NO;
			for (NSDate *d in self.dayEventDates) {
				// Ignore milliseconds
				if ((int)d.timeIntervalSince1970 == (int)dvc.date.timeIntervalSince1970) {
					match = YES;
				}
			}
			dvc.hasDayEvents = match;

			CGRect dayRect = dvc.view.frame;

			// Set the size to ensure that it is 1/kSDFCalendarOSXGrid.x the width of the month view and 1/kSDFCalendarOSXGrid.y it's height. Creating a kSDFCalendarOSXGrid.
			dayRect.size = daySize;

			// Work out it's position
			CGFloat dayX = daySize.width * x;
			CGFloat dayY = self.monthView.frame.size.height - daySize.height * y;
			dayRect.origin = CGPointMake(dayX, dayY);
			// Finally set it back to the frame
			dvc.view.frame = dayRect;

			if (firstRun) {
				[self.monthView addSubview:dvc.view];
				[self.dayVCs addObject:dvc];
			} else {
				[dvc setup];
			}

			BOOL noCurrentDaySetAndToday = !self.selectedDate && [currentGridDate isToday];
			BOOL currentDaySetAndDateMatches = self.selectedDate && [self.selectedDate isEqualToDate:currentGridDate];
			if (noCurrentDaySetAndToday || currentDaySetAndDateMatches) {
				[dvc select];
			} else {
				[dvc deselect];
			}

			currentGridDate = [currentGridDate dateByAddingDays:1];

			i++;
		}
	}

	// Month / Year labels
	self.monthLabel.stringValue = [self.currentMonthDate formattedDateWithFormat:@"MMMM"];
	self.yearLabel.stringValue = @(self.currentMonthDate.year).stringValue;
}

#pragma mark - Actions

- (IBAction)previousMonth:(id)sender
{
	self.currentMonthDate = [self.currentMonthDate dateBySubtractingMonths:1];
	[self setupMonth];
}

- (IBAction)nextMonth:(id)sender
{
	self.currentMonthDate = [self.currentMonthDate dateByAddingMonths:1];
	[self setupMonth];
}

#pragma mark - SDFCalendarOSXDaySelectionDelegate

- (void)sdfCalendarOSXDaySelected:(SDFCalendarOSXDayViewController *)dayViewController
{
	self.selectedDate = [dayViewController.date copy];

	if (!dayViewController.currentMonth) {
		self.currentMonthDate = [self startOfMonthDate:dayViewController.date];
	}

	[self setupMonth];
	if (self.delegate && [self.delegate respondsToSelector:@selector(sdfCalendarOSXCalendarDateSelected:)]) {
		[self.delegate sdfCalendarOSXCalendarDateSelected:[self.selectedDate copy]];
	}
}

#pragma mark - Public

- (void)highlightDayEventsForDates:(NSArray *)dates
{
	self.dayEventDates = dates;
	// We only want this called after initial launch, so before that rely on the nib loading to handle this
	if (self.dayVCs.count > 0) {
		[self setupMonth];
	}
}

#pragma mark - Private

- (NSDate *)startOfMonthDate:(NSDate *)date
{
	NSDate *tempDate = [date copy];
	tempDate = [tempDate dateBySubtractingDays:tempDate.day - 1];
	tempDate = [self startOfDayDate:tempDate];
	return tempDate;
}

- (NSDate *)startOfDayDate:(NSDate *)date
{
	NSDate *tempDate = [date copy];
	tempDate = [tempDate dateBySubtractingHours:tempDate.hour];
	tempDate = [tempDate dateBySubtractingMinutes:tempDate.minute];
	tempDate = [tempDate dateBySubtractingSeconds:tempDate.second];
	return tempDate;
}

@end
