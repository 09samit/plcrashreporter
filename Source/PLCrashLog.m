/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import "PLCrashLog.h"
#import "CrashReporter.h"

#import "crash_report.pb-c.h"

struct _PLCrashLogDecoder {
    Plcrash__CrashReport *crashReport;
};

@interface PLCrashLog (PrivateMethods)

- (Plcrash__CrashReport *) decodeCrashData: (NSData *) data error: (NSError **) outError;

- (PLCrashLogSystemInfo *) extractSystemInfo: (Plcrash__CrashReport__SystemInfo *) systemInfo 
                                       error: (NSError **) outError;

- (PLCrashLogApplicationInfo *) extractApplicationInfo: (Plcrash__CrashReport__ApplicationInfo *) applicationInfo 
                                                 error: (NSError **) outError;

@end

static void populate_nserror (NSError **error, PLCrashReporterError code, NSString *description);


/**
 * Provides decoding of crash logs generated by the PLCrashReporter framework.
 */
@implementation PLCrashLog

@synthesize systemInfo = _systemInfo;
@synthesize applicationInfo = _applicationInfo;

/**
 * Initialize with the provided crash log data. On error, nil will be returned, and
 * an NSError instance will be provided via @a error, if non-NULL.
 *
 * @param encodedData Encoded plcrash crash log.
 * @param outError If an error occurs, this pointer will contain an NSError object
 * indicating why the crash log could not be parsed. If no error occurs, this parameter
 * will be left unmodified. You may specify NULL for this parameter, and no error information
 * will be provided.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLCrashLog class.
 */
- (id) initWithData: (NSData *) encodedData error: (NSError **) outError {
    if ((self = [super init]) == nil) {
        // This shouldn't happen, but we have to fufill our API contract
        populate_nserror(outError, PLCrashReporterErrorUnknown, @"Could not initialize superclass");
        return nil;
    }


    /* Allocate the struct and attempt to parse */
    _decoder = malloc(sizeof(_PLCrashLogDecoder));
    _decoder->crashReport = [self decodeCrashData: encodedData error: outError];

    /* Check if decoding failed. If so, outError has already been populated. */
    if (_decoder->crashReport == NULL) {
        goto error;
    }


    /* System info */
    _systemInfo = [[self extractSystemInfo: _decoder->crashReport->system_info error: outError] retain];
    if (!_systemInfo)
        goto error;

    /* Application info */
    _applicationInfo = [[self extractApplicationInfo: _decoder->crashReport->application_info error: outError] retain];
    if (!_applicationInfo)
        goto error;

    return self;

error:
    [self release];
    return nil;
}

- (void) dealloc {
    /* Free the data objects */
    [_systemInfo release];

    /* Free the decoder state */
    if (_decoder != NULL) {
        if (_decoder->crashReport != NULL) {
            protobuf_c_message_free_unpacked((ProtobufCMessage *) _decoder->crashReport, &protobuf_c_system_allocator);
        }

        free(_decoder);
        _decoder = NULL;
    }

    [super dealloc];
}

@end


/**
 * @internal
 * Private Methods
 */
@implementation PLCrashLog (PrivateMethods)

/**
 * Decode the crash log message.
 *
 * @warning MEMORY WARNING. The caller is responsible for deallocating th ePlcrash__CrashReport instance
 * returned by this method via protobuf_c_message_free_unpacked().
 */
- (Plcrash__CrashReport *) decodeCrashData: (NSData *) data error: (NSError **) outError {
    const struct PLCrashLogFileHeader *header;
    const void *bytes;

    bytes = [data bytes];
    header = bytes;

    /* Verify that the crash log is sufficently large */
    if (sizeof(struct PLCrashLogFileHeader) >= [data length]) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, NSLocalizedString(@"Could not decode truncated crash log",
                                                                                             @"Crash log decoding error message"));
        return NULL;
    }

    /* Check the file magic */
    if (memcmp(header->magic, PLCRASH_LOG_FILE_MAGIC, strlen(PLCRASH_LOG_FILE_MAGIC)) != 0) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid,NSLocalizedString(@"Could not decode invalid crash log header",
                                                                                            @"Crash log decoding error message"));
        return NULL;
    }

    /* Check the version */
    if(header->version != PLCRASH_LOG_FILE_VERSION) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, [NSString stringWithFormat: NSLocalizedString(@"Could not decode unsupported crash report version: %d", 
                                                                                                                         @"Crash log decoding message"), header->version]);
        return NULL;
    }

    Plcrash__CrashReport *crashReport = plcrash__crash_report__unpack(&protobuf_c_system_allocator, [data length] - sizeof(struct PLCrashLogFileHeader), header->data);
    if (crashReport == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, NSLocalizedString(@"An unknown error occured decoding the crash report", 
                                                                                             @"Crash log decoding error message"));
        return NULL;
    }

    return crashReport;
}

/**
 * Extract system information from the crash log. Returns nil on error.
 */
- (PLCrashLogSystemInfo *) extractSystemInfo: (Plcrash__CrashReport__SystemInfo *) systemInfo error: (NSError **) outError {
    NSDate *timestamp = nil;
    
    /* Validate */
    if (systemInfo == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, 
                         NSLocalizedString(@"Crash report is missing System Information section", 
                                           @"Missing sysinfo in crash report"));
        return nil;
    }
    
    if (systemInfo->os_version == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, 
                         NSLocalizedString(@"Crash report is missing System Information OS version field", 
                                           @"Missing sysinfo operating system in crash report"));
        return nil;
    }
    
    /* Set up the timestamp, if available */
    if (systemInfo->timestamp != 0)
        timestamp = [NSDate dateWithTimeIntervalSince1970: systemInfo->timestamp];
    
    /* Done */
    return [[[PLCrashLogSystemInfo alloc] initWithOperatingSystem: systemInfo->operating_system
                                           operatingSystemVersion: [NSString stringWithUTF8String: systemInfo->os_version]
                                                     architecture: systemInfo->architecture
                                                        timestamp: timestamp] autorelease];
}


/**
 * Extract application information from the crash log. Returns nil on error.
 */
- (PLCrashLogApplicationInfo *) extractApplicationInfo: (Plcrash__CrashReport__ApplicationInfo *) applicationInfo 
                                                 error: (NSError **) outError
{    
    /* Validate */
    if (applicationInfo == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, 
                         NSLocalizedString(@"Crash report is missing Application Information section", 
                                           @"Missing appinfo in crash report"));
        return nil;
    }

    /* Identifier available? */
    if (applicationInfo->identifier == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, 
                         NSLocalizedString(@"Crash report is missing Application Information app identifier field", 
                                           @"Missing appinfo operating system in crash report"));
        return nil;
    }

    /* Version available? */
    if (applicationInfo->version == NULL) {
        populate_nserror(outError, PLCrashReporterErrorCrashReportInvalid, 
                         NSLocalizedString(@"Crash report is missing Application Information app version field", 
                                           @"Missing appinfo operating system in crash report"));
        return nil;
    }
    
    /* Done */
    NSString *identifier = [NSString stringWithUTF8String: applicationInfo->identifier];
    NSString *version = [NSString stringWithUTF8String: applicationInfo->version];

    return [[[PLCrashLogApplicationInfo alloc] initWithApplicationIdentifier: identifier
                                                          applicationVersion: version] autorelease];
}

@end

/**
 * @internal
 
 * Populate an NSError instance with the provided information.
 *
 * @param error Error instance to populate. If NULL, this method returns
 * and nothing is modified.
 * @param code The error code corresponding to this error.
 * @param description A localized error description.
 * @param cause The underlying cause, if any. May be nil.
 */
static void populate_nserror (NSError **error, PLCrashReporterError code, NSString *description) {
    NSMutableDictionary *userInfo;
    
    if (error == NULL)
        return;
    
    /* Create the userInfo dictionary */
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                description, NSLocalizedDescriptionKey,
                nil
                ];
    
    *error = [NSError errorWithDomain: PLCrashReporterErrorDomain code: code userInfo: userInfo];
}