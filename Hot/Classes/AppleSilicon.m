/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2021 Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @file        AppleSilicon.m
 * @copyright   (c) 2021, Jean-David Gadina - www.xs-labs.com
 */

/*******************************************************************************
 * LICENSE NOTICE
 *
 * The private IOKit calls used in the following code have been derived
 * from the https://github.com/fermion-star/apple_sensors project, which itself
 * has been derived from the https://github.com/freedomtan/sensors project,
 * by Koan-Sin Tan. As this might be considered as a derivative work, here are
 * the original license terms:
 *
 * BSD 3-Clause License
 *
 * Copyright (c) 2016-2018, "freedom" Koan-Sin Tan
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * - Neither the name of the copyright holder nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************/

#import "AppleSilicon.h"
#import "IOHID.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

#define IOHIDEventFieldBaseTemperature IOHIDEventTypeTemperature << 16

static IOHIDEventSystemClientRef client = nil;
static NSMutableArray * services = nil;

NSDictionary< NSString *, NSNumber * > * ReadM1Sensors( void )
{
    if( client == nil )
    {
        client = IOHIDEventSystemClientCreate( kCFAllocatorDefault );
        NSCAssert(client != nil, @"NSCAssert: client was nil.");
        
        NSDictionary * filter =
        @{
            @"PrimaryUsagePage" : [ NSNumber numberWithLongLong: IOHIDPageAppleVendor ],
            @"PrimaryUsage"     : [ NSNumber numberWithLongLong: IOHIDUsageAppleVendorTemperatureSensor ]
        };
        NSCAssert(filter != nil, @"NSCAssert: filter was nil.");
        
        IOHIDEventSystemClientSetMatching( client, ( __bridge CFDictionaryRef )filter );
        
        NSArray                                       * servicesArr = CFBridgingRelease( IOHIDEventSystemClientCopyServices( client ) );
        NSCAssert(servicesArr != nil, @"NSCAssert: servicesArr was nil.");
        
        // pre-filter the sensor list and only add sensors that contains "ACC" in name (like pACC and eACC that are the CPU cores)
        for( id o in servicesArr )
        {
            IOHIDServiceClientRef service = ( __bridge IOHIDServiceClientRef )o;
            NSString            * name    = CFBridgingRelease( IOHIDServiceClientCopyProperty( service, CFSTR( "Product" ) ) );
            CFTypeRef             event   = IOHIDServiceClientCopyEvent( service, IOHIDEventTypeTemperature, 0, 0 );
            
            if( name != nil && event != nil )
            {

                NSRange isRange = [name rangeOfString:@"ACC" options:NSCaseInsensitiveSearch];
                if (isRange.location != NSNotFound)
                {
                    if (services == nil)
                    {
                        services = [[NSMutableArray alloc] init];
                        NSCAssert(services != nil, @"NSCAssert: services was nil.");
                    }
                    [services addObject:o];
                }
            }
            
            if( event != nil )
            {
                CFRelease( event );
            }
        }
    }
    
    NSMutableDictionary< NSString *, NSNumber * > * values   = [ NSMutableDictionary new ];
    NSCAssert(values != nil, @"NSCAssert: values was nil.");
    
    for( id o in services )
    {
        IOHIDServiceClientRef service = ( __bridge IOHIDServiceClientRef )o;
        NSString            * name    = CFBridgingRelease( IOHIDServiceClientCopyProperty( service, CFSTR( "Product" ) ) );
        CFTypeRef             event   = IOHIDServiceClientCopyEvent( service, IOHIDEventTypeTemperature, 0, 0 );
        
        if( name != nil && event != nil )
        {
            values[ name ] = [ NSNumber numberWithDouble: IOHIDEventGetFloatValue( event, IOHIDEventFieldBaseTemperature ) ];
        }
        
        if( event != nil )
        {
            CFRelease( event );
        }
    }
    
    return [ values copy ];
}
