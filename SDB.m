//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/sdb
//

#import "SDB.h"
#import "XMLElement.h"
#import "NSData+.h"

static NSString*  kSDBEndpoint    = @"sdb.amazonaws.com";
static NSString*  kSDBVersion     = @"2009-04-15";
static NSString*  kSDBSigVersion  = @"2";
static NSString*  kSDBSigMethod   = @"HmacSHA1";

       NSString*  SDBErrorDomain = @"com.makesay.SDB.ErrorDomain";
static NSInteger  SDBErrorStringToCode(NSString* errorString);
static NSArray*   SDBErrorMap();


@interface SDB ()
@property (readwrite) NSString*   key;
@property (readwrite) NSString*   secret;
@end

@interface SDBChangeSet ()
@property NSMutableArray*   changes;
@end

@class SDBOp;
typedef void(^SDBOpDone)(SDBOp* op, NSError* error);

@interface SDBOp : NSObject <NSURLConnectionDelegate>
@property        NSString*          action;
@property        NSError*           error;
@property        NSDictionary*      parameters;
@property        SDB*               sdb;
@property        NSDate*            timestamp;
@property        NSURLConnection*   connection;
@property        NSURLResponse*     response;
@property        NSMutableData*     responseData;
@property        XMLElement*        responseRoot;
@property (copy) SDBOpDone          whenDone;
+ (SDBOp*)opWithSDB:(SDB*)sdb action:(NSString*)action parameters:(NSDictionary*)parameters;
- (void)run:(SDBOpDone)block;
@end


@implementation SDB

+ (SDB*)sdbWithKey:(NSString*)key secret:(NSString*)secret
{
  return [[SDB alloc] initWithKey:key secret:secret];
}

- (id)initWithKey:(NSString*)key secret:(NSString*)secret
{
  if(!(self = [super init])) return nil;
  self.key = key;
  self.secret = secret;
  return self;
}

#pragma mark -

- (void)createDomain:(NSString*)domain whenDone:(SDBCreateDomainDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"CreateDomain" parameters:params];
  [operation run:^(SDBOp* op, NSError* error) {
    block(error);
  }];
}

- (void)deleteDomain:(NSString*)domain whenDone:(SDBDeleteDomainDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"DeleteDomain" parameters:params];
  [operation run:^(SDBOp* op, NSError* error) {
    block(error);
  }];
}

- (void)domainMetadata:(NSString*)domain whenDone:(SDBDomainMetadataDone)block;
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"DomainMetadata" parameters:params];
  [operation run:^(SDBOp* op, NSError* error)
  {
    NSDictionary*   metadata;
    XMLElement*     result;
    NSDate*         timestamp;

    if(error){ block(nil, error); return; }
    
    // Example:
    // <DomainMetadataResponse>
    //   <DomainMetadataResult>
    //     <ItemCount>195078</ItemCount>
    //     <ItemNamesSizeBytes>2586634</ItemNamesSizeBytes>
    //     <AttributeNameCount >12</AttributeNameCount >
    //     <AttributeNamesSizeBytes>120</AttributeNamesSizeBytes>
    //     <AttributeValueCount>3690416</AttributeValueCount>
    //     <AttributeValuesSizeBytes>50149756</AttributeValuesSizeBytes>
    //     <Timestamp>1225486466</Timestamp>
    //   </DomainMetadataResult>
    //   <ResponseMetadata>
    //     <RequestId>b1e8f1f7-42e9-494c-ad09-2674e557526d</RequestId>
    //     <BoxUsage>0.0000219907</BoxUsage>
    //   </ResponseMetadata>
    // </DomainMetadataResponse>
    
    result = [op.responseRoot find:@"DomainMetadataResult"];
    timestamp = [NSDate dateWithTimeIntervalSince1970:[result find:@"Timestamp"].cdata.doubleValue];
    metadata = @{@"ItemCount": @([result find:@"ItemCount"].cdata.integerValue),
                 @"ItemNamesSizeBytes": @([result find:@"ItemNamesSizeBytes"].cdata.integerValue),
                 @"AttributeNameCount": @([result find:@"AttributeNameCount"].cdata.integerValue),
                 @"AttributeNameSizeBytes": @([result find:@"AttributeNameSizeBytes"].cdata.integerValue),
                 @"AttributeValueCount": @([result find:@"AttributeValueCount"].cdata.integerValue),
                 @"AttributeValuesSizeBytes": @([result find:@"AttributeValuesSizeBytes"].cdata.integerValue),
                 @"Timestamp": timestamp};
    block(metadata, nil);
  }];
}

- (void)listDomains:(SDBListDomainsDone)block
{
  SDBOp*          operation;
  
  operation = [SDBOp opWithSDB:self action:@"ListDomains" parameters:nil];
  [operation run:^(SDBOp* op, NSError* error)
  {
    NSMutableArray*   domainNames;
    
    if(error){ block(nil, error); return; }
    
    // Example:
    // <ListDomainsResponse>
    //   <ListDomainsResult>
    //     <DomainName>Domain1-200706011651</DomainName>
    //     <DomainName>Domain2-200706011652</DomainName>
    //     <NextToken>TWV0ZXJpbmdUZXN0RG9tYWluMS0yMDA3MDYwMTE2NTY=</NextToken>
    //   </ListDomainsResult>
    //   <ResponseMetadata>
    //     <RequestId>eb13162f-1b95-4511-8b12-489b86acfd28</RequestId>
    //     <BoxUsage>0.0000219907</BoxUsage>
    //   </ResponseMetadata>
    // </ListDomainsResponse>
    
    domainNames = [NSMutableArray array];
    [op.responseRoot find:@"ListDomainsResult.DomainName" forEach:^(XMLElement* element) {
      [domainNames addObject:element.cdata];
    }];
    block(domainNames, nil);
  }];
}

#pragma mark -

- (void)getAttributes:(NSString*)domain item:(NSString*)item whenDone:(SDBGetAttributesDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain, @"ItemName": item, @"ConsistentRead": @"true"};
  operation = [SDBOp opWithSDB:self action:@"GetAttributes" parameters:params];
  [operation run:^(SDBOp *op, NSError *error)
  {
    NSMutableDictionary*  attributes;
    
    if(error){ block(nil, error); return; }
    
    // Example:
    // <GetAttributesResponse>
    //   <GetAttributesResult>
    //     <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    //     <Attribute><Name>Color</Name><Value>Red</Value></Attribute>
    //     <Attribute><Name>Size</Name><Value>Med</Value></Attribute>
    //     <Attribute><Name>Price</Name><Value>14</Value></Attribute>
    //   </GetAttributesResult>
    // <ResponseMetadata>
    // <RequestId>b1e8f1f7-42e9-494c-ad09-2674e557526d</RequestId>
    //   <BoxUsage>0.0000219907</BoxUsage>
    //   </ResponseMetadata>
    // </GetAttributesResponse>
    
    attributes = [NSMutableDictionary dictionary];
    [op.responseRoot find:@"GetAttributesResult.Attribute" forEach:^(XMLElement* element) {
      NSString* name  = [element find:@"Name"].cdata;
      NSString* value = [element find:@"Value"].cdata;
      if(!attributes[name]) attributes[name] = [NSMutableArray array];
      [attributes[name] addObject:value];
    }];
    block(attributes, nil);
  }];
}

- (void)select:(NSString*)expression whenDone:(SDBSelectDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"SelectExpression": expression};
  operation = [SDBOp opWithSDB:self action:@"Select" parameters:params];
  [operation run:^(SDBOp *op, NSError *error)
  {
    NSMutableDictionary*  items;
    
    if(error){ block(nil, error); return; };
    
    // Example:
    // <SelectResponse>
    //   <SelectResult>
    //     <Item>
    //       <Name>Item_03</Name>
    //       <Attribute><Name>Category</Name><Value>Clothes</Value></Attribute>
    //       <Attribute><Name>Name</Name><Value>Sweatpants</Value></Attribute>
    //       <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    //       <Attribute><Name>Color</Name><Value>Yellow</Value></Attribute>
    //     </Item>
    //     <Item>
    //       <Name>Item_06</Name>
    //       <Attribute><Name>Category</Name><Value>Motorcycle Parts</Value></Attribute>
    //       <Attribute><Name>Name</Name><Value>Fender Eliminator</Value></Attribute>
    //       <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    //     </Item>
    //   </SelectResult>
    // </SelectResponse>
    
    
    items = [NSMutableDictionary dictionary];
    
    [op.responseRoot find:@"SelectResult.Item" forEach:^(XMLElement* item) {
      NSString* itemName = [item find:@"Name"].cdata;
      items[itemName] = [NSMutableDictionary dictionary];
      
      [item find:@"Attribute" forEach:^(XMLElement* attribute) {
        NSString* attrName  = [attribute find:@"Name"].cdata;
        NSString* attrValue = [attribute find:@"Value"].cdata;
        NSString* attrSet   = [attrName stringByAppendingString:@"Set"];
        NSString* values;
        
        if(!items[itemName][attrSet]) items[itemName][attrSet] = [NSMutableArray array];
        [(NSMutableArray*)items[itemName][attrSet] addObject:attrValue];
        values = [(NSArray*)items[itemName][attrSet] componentsJoinedByString:@", "];
        items[itemName][attrName] = values;
      }];
    }];
    block(items, nil);
  }];
}

- (void)putAttributes:(NSString*)domain item:(NSString*)item
              changes:(SDBChangeSet*)changeSet
             whenDone:(SDBWriteChangesDone)block
{
  SDBOp*                  operation;
  NSMutableDictionary*    params;
  int                     attrIndex = 1;
  
  // Construct Params from ChangeSet
  params = [NSMutableDictionary dictionary];
  params[@"DomainName"] = domain;
  params[@"ItemName"] = item;
  for(NSDictionary* change in changeSet.changes) {
    params[[NSString stringWithFormat:@"Attribute.%d.Name", attrIndex]] = change[@"name"];
    params[[NSString stringWithFormat:@"Attribute.%d.Value", attrIndex]] = change[@"value"];
    if([(NSNumber*)change[@"replace"] boolValue])
      params[[NSString stringWithFormat:@"Attribute.%d.Replace", attrIndex]] = @"true";
     attrIndex++;
  }
  
  operation = [SDBOp opWithSDB:self action:@"PutAttributes" parameters:params];
  [operation run:^(SDBOp* op, NSError* error) {
    block(error);
  }];
}

#pragma mark -

- (void)operationDone:(SDBOp*)operation error:(NSError*)error
{
  NSLog(@"SDB Operation Done");
}

@end

@implementation SDBOp

+ (SDBOp*)opWithSDB:(SDB*)inSDB action:(NSString*)inAction parameters:(NSDictionary*)inParameters
{
  return [[SDBOp alloc] initWithSDB:inSDB action:inAction parameters:inParameters];
}

- (id)initWithSDB:(SDB*)sdb action:(NSString*)action parameters:(NSDictionary*)parameters
{
  if(!(self = [super init])) return nil;
  self.sdb = sdb;
  self.action = action;
  self.parameters = parameters;
  self.responseData = [NSMutableData data];
  return self;
}

- (void)run:(SDBOpDone)block
{
  NSString*               remoteURI;
  NSMutableURLRequest*    request;
  NSDictionary*           paramsBasic;
  NSMutableDictionary*    allParams;
  NSString*               signature;
  NSString*               timeString;
  
  // Create HTTP Request
  remoteURI = [NSString stringWithFormat:@"http://%@/", kSDBEndpoint];
  request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:remoteURI]
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                timeoutInterval:60.0];
  
  // Setup HTTP Request
  [request setHTTPMethod:@"POST"];
  [request setValue:@"CloudSDB/1.0" forHTTPHeaderField:@"User-Agent"];
  
  // Get Formatted Time
  self.timestamp = [NSDate dateWithTimeIntervalSinceNow:0];
  timeString = [self timestampGMTString];
    
  // Construct Parameter Disctionaries
  allParams   = [NSMutableDictionary dictionary];
  paramsBasic = @{@"Action": self.action,
                 @"AWSAccessKeyId": self.sdb.key,
                 @"Version": kSDBVersion,
                 @"SignatureVersion": kSDBSigVersion,
                 @"SignatureMethod": kSDBSigMethod,
                 @"Timestamp": timeString};
  [allParams addEntriesFromDictionary:paramsBasic];
  [allParams addEntriesFromDictionary:self.parameters];
  NSLog(@"All Params: %@", allParams);
  
  // Add Signature to Parameters
  signature = [self generateSig:allParams];
  allParams[@"Signature"] = signature;
  
  // Set HTTP POST Body to Parameters
  [request setHTTPBody:[[self postEncodedString:allParams]
                        dataUsingEncoding:NSUTF8StringEncoding]];
  
  // Save Block for Callback
  self.whenDone = block;
  
  // Start our connection
  self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark -

- (NSString*)timestampGMTString
{
  NSDateFormatter*  gmtFormat;
  
  gmtFormat = [[NSDateFormatter alloc] init];
  [gmtFormat setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss'Z'"];
  [gmtFormat setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
  return [gmtFormat stringFromDate:self.timestamp];
}

- (NSString*)generateSig:(NSDictionary*)params
{
  NSString*   stringToSign;
  NSString*   queryString;
  NSData*     digest;
  NSString*   signature;
  
  // Generate String to Sign
  queryString = [self postEncodedString:params];
  stringToSign = [NSString stringWithFormat:@"POST\n%@\n/\n%@",
                  kSDBEndpoint, queryString];
  
  // Generate Hash
  digest = [[stringToSign dataUsingEncoding:NSUTF8StringEncoding] sha1HMacWithKey:self.sdb.secret];
  signature = [digest base64];
  return signature;
}

- (NSString*)postEncodedString:(NSDictionary*)dict
{
  NSMutableString*	encodedString;
  NSArray*          sortedKeys;
  NSObject*         enumKey;
  NSObject*         enumValue;
  CFStringRef       escapedKey;
  CFStringRef       escapedValue;
  
  // Loop Over Keys and Encode
  encodedString = [NSMutableString string];
  sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
  for(enumKey in sortedKeys) {
    
    // Key and Value
    enumValue = dict[enumKey];
    if(![enumKey isKindOfClass:[NSString class]]) continue;
    if(![enumValue isKindOfClass:[NSString class]]) continue;
    
    // URL Encoded Key and Value
    escapedKey = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)enumKey, NULL,
                                                         (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                         kCFStringEncodingUTF8);
    escapedValue = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)enumValue, NULL,
                                                         (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                         kCFStringEncodingUTF8);

    // Append to Output
    [encodedString appendFormat:@"%@=%@&", escapedKey, escapedValue];
    CFRelease(escapedKey);
    CFRelease(escapedValue);
  }
  
  // Delete Trailing &
  if(encodedString.length)
    [encodedString deleteCharactersInRange:NSMakeRange(encodedString.length - 1, 1)];
  return encodedString;
}  

#pragma mark - NSURLConnection Delegate

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)inResponse
{
	// Check that the response object is an http response object
  if(![inResponse isMemberOfClass:[NSHTTPURLResponse class]])
    NSLog(@"SDBOp Error: Expected response of class NSHTTPURLResponse");
  
  // This method is called when the server has determined that it
	// has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a 
	// redirect, so each time we reset the data.
	self.responseData.length = 0;
	self.response = inResponse;
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
	// Accumulate Additional Data
	[self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)error
{	
  // Wrap Up Connection
  self.connection = nil;
  self.response = nil;
  self.responseData = nil;
  
  // Record Error
  self.error = error;
  
  // Tell SDB
  self.whenDone(self, self.error);
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
  NSError*      parseError;
  XMLElement*   errors;
  
  // Create responseRoot
  self.responseRoot = [XMLElement rootWithData:self.responseData error:&parseError];
  if(parseError){ self.error = parseError; }
  
  // Look for Errors in response XML
  // TODO: Store and report all errors, not just first
  // Example: <?xml version="1.0"?>
  // <Response>
  //   <Errors>
  //     <Error>
  //       <Code>MissingParameter</Code>
  //       <Message>The request must contain the parameter DomainName</Message>
  //       <BoxUsage>0.0055590278</BoxUsage>
  //     </Error>
  //   </Errors>
  //   <RequestID>07a9910f-fb82-4d4b-762c-d6bb4f6c0f5a</RequestID>
  // </Response>
  
  if([self.responseRoot.name isEqual:@"Errors"]) {
    NSString*       errorCode;
    NSString*       errorMessage;
    NSDictionary*   errorInfo;
    NSInteger       errorInteger;
    
    errorCode     = [errors find:@"Error.Code"].cdata;
    errorMessage  = [errors find:@"Error.Message"].cdata;
    errorInfo     = @{NSLocalizedDescriptionKey: errorMessage};
    errorInteger  = SDBErrorStringToCode(errorCode);
    self.error    = [NSError errorWithDomain:SDBErrorDomain code:errorInteger userInfo:errorInfo];
  }
  
  // Wrap Up Connection
  self.connection = nil;
  self.response = nil;
  self.responseData = nil;
	
  // Tell SDB
  self.whenDone(self, self.error);
}

@end

@implementation SDBChangeSet

@synthesize changes;

- (id)init
{
  if(!(self = [super init])) return nil;
  self.changes = [NSMutableArray array];
  return self;
}


- (void)setAttribute:(NSString*)attr value:(NSString*)value
{
  NSDictionary*   setChange;
  
  setChange = @{@"name": attr,
               @"value": value,
               @"replace": @YES};
  [self.changes addObject:setChange];
}

- (void)addAttribute:(NSString*)attr value:(NSString*)value
{
  NSDictionary*   addChange;
  
  addChange = @{@"name": attr,
               @"value": value,
               @"replace": @NO};
  [self.changes addObject:addChange];
}

- (NSString*)description
{
  NSMutableString*  desc;
  
  desc = [NSMutableString stringWithString:@"SDBChangeSet [\n"];
  for(NSDictionary* change in self.changes)
    [desc appendFormat:@" %@ %@: %@,", [(NSNumber*)change[@"replace"] boolValue] ? @"set" : @"add",
     change[@"name"], change[@"value"]];
  [desc appendString:@"\n]\n"];
  return desc;
}

@end

NSString* SDBErrorCodeToString(NSInteger errorCode)
{
  return SDBErrorMap()[errorCode];
}
                     
NSInteger SDBErrorStringToCode(NSString* errorString)
{
  return [SDBErrorMap() indexOfObject:errorString];
}

NSArray* SDBErrorMap()
{
  static NSArray*   sSDBErrorMap = nil;
  
  if(!sSDBErrorMap)
    sSDBErrorMap = @[@"AccessFailure",
                    @"AttributeDoesNotExist",
                    @"AuthFailure",
                    @"AuthMissingFailure",
                    @"ConditionalCheckFailed",
                    @"ConditionalCheckFailed",
                    @"ExistsAndExpectedValue",
                    @"FeatureDeprecated",
                    @"IncompleteExpectedExpression",
                    @"InternalError",
                    @"InvalidAction",
                    @"InvalidHTTPAuthHeader",
                    @"InvalidHttpRequest",
                    @"InvalidLiteral",
                    @"InvalidNextToken",
                    @"InvalidNumberPredicates",
                    @"InvalidNumberValueTests",
                    @"InvalidParameterCombination",
                    @"InvalidParameterValue",
                    @"InvalidQueryExpression",
                    @"InvalidResponseGroups",
                    @"InvalidService",
                    @"InvalidSortExpression",
                    @"InvalidURI",
                    @"InvalidWSAddressingProperty",
                    @"InvalidWSDLVersion",
                    @"MissingAction",
                    @"MissingParameter",
                    @"MissingWSAddressingProperty",
                    @"MultipleExistsConditions",
                    @"MultipleExpectedNames",
                    @"MultipleExpectedValues",
                    @"MultiValuedAttribute",
                    @"NoSuchDomain",
                    @"NoSuchVersion",
                    @"NotYetImplemented",
                    @"NumberDomainsExceeded",
                    @"NumberDomainAttributesExceeded",
                    @"NumberDomainBytesExceeded",
                    @"NumberItemAttributesExceeded",
                    @"NumberSubmittedAttributesExceeded",
                    @"NumberSubmittedItemsExceeded",
                    @"RequestExpired",
                    @"QueryTimeout",
                    @"ServiceUnavailable",
                    @"TooManyRequestedAttributes",
                    @"UnsupportedHttpVerb",
                    @"UnsupportedNextToken",
                    @"URITooLongError"];
  return sSDBErrorMap;
}
