#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

#include <unistd.h>

// Declarations from other IOKit source code
typedef struct __IOHIDEvent* IOHIDEventRef;
typedef struct __IOHIDServiceClient* IOHIDServiceClientRef;
typedef double IOHIDFloat;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
CFStringRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);
// end of borrowed declarations

NSDictionary* matching(int page, int usage)
{
    NSDictionary* dict = @ {
        @"PrimaryUsagePage" : [NSNumber numberWithInt:page],
        @"PrimaryUsage" : [NSNumber numberWithInt:usage],
    };
    return dict;
}

NSArray* getProductNames(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (__bridge NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        NSString* name = (NSString*)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product");
        if (name) {
            [array addObject:name];
        } else {
            [array addObject:@"noname"];
        }
    }
    return array;
}

// from IOHIDFamily/IOHIDEventTypes.h
// e.g., https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-701.60.2/IOHIDFamily/IOHIDEventTypes.h.auto.html

#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventTypePower 25

NSArray* getPowerValues(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypePower, 0, 0);

        NSNumber* value;
        double temp = 0.0;
        if (event != 0) {
            temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypePower)) / 1000.0;
        }
        value = [NSNumber numberWithDouble:temp];
        [array addObject:value];
    }
    return array;
}

NSArray* getThermalValues(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (__bridge NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];

    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypeTemperature, 0, 0);

        NSNumber* value;
        double temp = 0.0;
        if (event != 0) {
            temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        }
        value = [NSNumber numberWithDouble:temp];
        [array addObject:value];
    }
    return array;
}

void dumpValues(NSArray* values)
{
    int count = [values count];
    for (int i = 0; i < count; i++) {
        if (i > 0)
            printf(", ");
        printf("%lf", [values[i] doubleValue]);
    }
}

void dumpNames(NSArray* names, NSString* cat)
{
    int count = [names count];
    for (int i = 0; i < count; i++) {
        if (i > 0)
            printf(", ");
        printf("%s (%s)", [names[i] UTF8String], [cat UTF8String]);
    }
}

void usage()
{
    printf("-c: show current meter values\n"
           "-v: show voltage meter values\n");
    return;
}

int main(int argc, char* argv[])
{

    bool voltage_show = false, current_show = false, temperature_show = true;
    int ch;

    while ((ch = getopt(argc, argv, "cv")) != -1) {
        switch (ch) {
        case 'v':
            voltage_show = true;
            break;
        case 'c':
            current_show = true;
            break;
        default:
            usage();
            exit(-1);
        }
    }
    argc -= optind;
    argv += optind;

    //  Primary Usage Page:
    //    kHIDPage_AppleVendor                        = 0xff00,
    //    kHIDPage_AppleVendorTemperatureSensor       = 0xff05,
    //    kHIDPage_AppleVendorPowerSensor             = 0xff08,
    //
    //  Primary Usage:
    //    kHIDUsage_AppleVendor_TemperatureSensor     = 0x0005,
    //    kHIDUsage_AppleVendorPowerSensor_Current    = 0x0002,
    //    kHIDUsage_AppleVendorPowerSensor_Voltage    = 0x0003,
    // See IOHIDFamily/AppleHIDUsageTables.h for more information
    // https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-701.60.2/IOHIDFamily/AppleHIDUsageTables.h.auto.html

    NSDictionary* currentSensors = matching(0xff08, 2);
    NSDictionary* voltageSensors = matching(0xff08, 3);
    NSDictionary* thermalSensors = matching(0xff00, 5);

    NSArray* currentNames = getProductNames(currentSensors);
    NSArray* voltageNames = getProductNames(voltageSensors);
    NSArray* thermalNames = getProductNames(thermalSensors);

    if (voltage_show)
        dumpNames(voltageNames, @"V");
    if (current_show)
        dumpNames(currentNames, @"A");
    if (temperature_show)
        dumpNames(thermalNames, @"°C");
    printf("\n");

    while (1) {
        NSArray* currentValues = getPowerValues(currentSensors);
        NSArray* voltageValues = getPowerValues(voltageSensors);
        NSArray* thermalValues = getThermalValues(thermalSensors);

        if (voltage_show)
            dumpValues(voltageValues);
        if (current_show)
            dumpValues(currentValues);
        if (temperature_show)
            dumpValues(thermalValues);
        printf("\n");

        CFRelease(currentValues);
        CFRelease(voltageValues);
        CFRelease(thermalValues);

        // sleep 1 second
        usleep(1000000);
    }

    return 0;
}
