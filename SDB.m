//
// Copyright 2013 Aaron Sittig. All rights reserved
// All code is governed by the BSD-style license at
// http://github.com/aaron--/sdb
//

#import "SDB.h"
#import "NSData+.h"
@class SDBOp;

static NSString*    kSDBEndpoint = @"sdb.amazonaws.com";
static NSString*    kSDBVersion = @"2009-04-15";
static NSString*    kSDBSigVersion = @"2";
static NSString*    kSDBSigMethod = @"HmacSHA1";

       NSString*    SDBErrorDomain = @"com.makesay.SDB.ErrorDomain";
static NSInteger    SDBErrorStringToCode(NSString* errorString);
static NSArray*     SDBErrorMap();


@interface SDB ()
@property (readwrite) NSString*             key;
@property (readwrite) NSString*             secret;
@property (nonatomic, strong) NSMutableDictionary*  changes;
- (id)initWithKey:(NSString*)key secret:(NSString*)secret;
- (void)operationDone:(SDBOp*)operation error:(NSError*)error;
@end

@interface SDBChangeSet ()
@property (nonatomic, strong) NSMutableArray*   changes;
@end

typedef void(^SDBOpDone)(SDBOp* op, NSError* error);

@interface SDBOp : NSObject <NSURLConnectionDelegate>
@property (nonatomic, strong) NSString*         action;
@property (nonatomic, strong) NSError*          error;
@property (nonatomic, strong) NSDictionary*     parameters;
@property (nonatomic, weak)   SDB*              sdb;
@property (nonatomic, strong) NSDate*           timestamp;
@property (nonatomic, strong) NSURLConnection*  connection;
@property (nonatomic, strong) NSURLResponse*    response;
@property (nonatomic, strong) NSMutableData*    responseData;
@property (nonatomic, strong) NSXMLDocument*    responseXML;
@property (nonatomic, copy)   SDBOpDone         whenDone;
+ (SDBOp*)opWithSDB:(SDB*)sdb action:(NSString*)action parameters:(NSDictionary*)parameters;
- (id)initWithSDB:(SDB*)sdb action:(NSString*)action parameters:(NSDictionary*)parameters;
- (void)run:(SDBOpDone)block;
- (NSString*)timestampGMTString;
- (NSString*)generateSig:(NSDictionary*)params;
- (NSString*)postEncodedString:(NSDictionary*)dict;
@end

@implementation SDB

@synthesize key;
@synthesize secret;
@synthesize changes;

+ (SDB*)sdbWithKey:(NSString*)key secret:(NSString*)secret
{
  return [[SDB alloc] initWithKey:key secret:secret];
}

- (id)initWithKey:(NSString*)inKey secret:(NSString*)inSecret
{
  if(!(self = [super init])) return nil;
  self.key = inKey;
  self.secret = inSecret;
  self.changes = [NSMutableDictionary dictionary];
  return self;
}


#pragma mark -

- (void)createDomain:(NSString*)domain whenDone:(SDBCreateDomainDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"CreateDomain" parameters:params];
  [operation run:^(SDBOp *op, NSError *error) {
    block(error);
  }];
}

- (void)deleteDomain:(NSString*)domain whenDone:(SDBDeleteDomainDone)block
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"DeleteDomain" parameters:params];
  [operation run:^(SDBOp *op, NSError *error) {
    block(error);
  }];
}

- (void)domainMetadata:(NSString*)domain whenDone:(SDBDomainMetadataDone)block;
{
  SDBOp*          operation;
  NSDictionary*   params;
  
  params = @{@"DomainName": domain};
  operation = [SDBOp opWithSDB:self action:@"DomainMetadata" parameters:params];
  [operation run:^(SDBOp *op, NSError *error)
  {
    NSArray*        elements;
    NSDictionary*   metadata;
    NSXMLElement*   resultNode;
    NSString*       itemCount;
    NSString*       itemNamesSizeBytes;
    NSString*       attrNameCount;
    NSString*       attrNameSizeBytes;
    NSString*       attrValueCount;
    NSString*       attrValueSizeBytes;
    NSString*       timestamp;
    
    if(error){ block(nil, error); return; }
    
  /*<DomainMetadataResponse xmlns="http://sdb.amazonaws.com/doc/2009-04-15/">
    <DomainMetadataResult>
    <ItemCount>195078</ItemCount>
    <ItemNamesSizeBytes>2586634</ItemNamesSizeBytes>
    <AttributeNameCount >12</AttributeNameCount >
    <AttributeNamesSizeBytes>120</AttributeNamesSizeBytes>
    <AttributeValueCount>3690416</AttributeValueCount>
    <AttributeValuesSizeBytes>50149756</AttributeValuesSizeBytes>
    <Timestamp>1225486466</Timestamp>
    </DomainMetadataResult>
    <ResponseMetadata>
    <RequestId>b1e8f1f7-42e9-494c-ad09-2674e557526d</RequestId>
    <BoxUsage>0.0000219907</BoxUsage>
    </ResponseMetadata>
    </DomainMetadataResponse> */
    
    elements = [op.responseXML.rootElement elementsForName:@"DomainMetadataResult"];
    resultNode = elements[0];
    elements = [resultNode elementsForName:@"ItemCount"];
    itemCount = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"ItemNamesSizeBytes"];
    itemNamesSizeBytes = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"AttributeNameCount"];
    attrNameCount = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"AttributeNameSizeBytes"];
    attrNameSizeBytes = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"AttributeValueCount"];
    attrValueCount = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"AttributeValuesSizeBytes"];
    attrValueSizeBytes = [[elements[0] childAtIndex:0] stringValue];
    elements = [resultNode elementsForName:@"Timestamp"];
    timestamp = [[elements[0] childAtIndex:0] stringValue];
    metadata = @{@"ItemCount": @([itemCount integerValue]),
                @"ItemNamesSizeBytes": @([itemNamesSizeBytes integerValue]),
                @"AttributeNameCount": @([attrNameCount integerValue]),
                @"AttributeNameSizeBytes": @([attrNameSizeBytes integerValue]),
                @"AttributeValueCount": @([attrValueCount integerValue]),
                @"AttributeValuesSizeBytes": @([attrValueSizeBytes integerValue]),
                @"Timestamp": [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]]};
    block(metadata, nil);
  }];
}

- (void)listDomains:(SDBListDomainsDone)block
{
  SDBOp*          operation;
  
  operation = [SDBOp opWithSDB:self action:@"ListDomains" parameters:nil];
  [operation run:^(SDBOp* op, NSError* error)
  {
    NSArray*          listDomainsResultArray;
    NSArray*          domainNameArray;
    NSMutableArray*   domainNames;
    
    if(error){ block(nil, error); return; }
    
    listDomainsResultArray = [[op.responseXML rootElement] elementsForName:@"ListDomainsResult"];
    domainNameArray = [listDomainsResultArray[0] elementsForName:@"DomainName"];
    
    domainNames = [NSMutableArray array];
    for(NSXMLElement* domainNameNode in domainNameArray) {
      if([[domainNameNode childAtIndex:0] kind] == NSXMLTextKind)
        [domainNames addObject:[[domainNameNode childAtIndex:0] stringValue]];
    }
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
    NSArray*              elements;
    NSXMLElement*         resultNode;
    NSArray*              names;
    NSArray*              values;
    NSString*             name;
    NSString*             value;
    NSMutableDictionary*  attributes;
    
    if(error){ block(nil, error); return; }
    
  /*<GetAttributesResponse>
    <GetAttributesResult>
    <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    <Attribute><Name>Color</Name><Value>Red</Value></Attribute>
    <Attribute><Name>Size</Name><Value>Med</Value></Attribute>
    <Attribute><Name>Price</Name><Value>14</Value></Attribute>
    </GetAttributesResult>
    <ResponseMetadata>
    <RequestId>b1e8f1f7-42e9-494c-ad09-2674e557526d</RequestId>
    <BoxUsage>0.0000219907</BoxUsage>
    </ResponseMetadata>
    </GetAttributesResponse> */
    
    elements = [op.responseXML.rootElement elementsForName:@"GetAttributesResult"];
    resultNode = elements[0];
    elements = [resultNode elementsForName:@"Attribute"];
    attributes = [NSMutableDictionary dictionary];
    for(NSXMLElement* attribute in elements) {
      names = [attribute elementsForName:@"Name"];
      values = [attribute elementsForName:@"Value"];
      name = [[names[0] childAtIndex:0] stringValue];
      value = [[values[0] childAtIndex:0] stringValue];
      if(!attributes[name])
        attributes[name] = [NSMutableArray array];
      [attributes[name] addObject:value];
    }
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
    NSArray*              elements;
    NSArray*              attributes;
    NSString*             name;
    NSString*             value;
    NSString*             values;
    NSString*             setName;
    NSMutableDictionary*  newItem;
    
    if(error){ block(nil, error); return; };
    
  /*<SelectResponse>
    <SelectResult>
    <Item>
    <Name>Item_03</Name>
    <Attribute><Name>Category</Name><Value>Clothes</Value></Attribute>
    <Attribute><Name>Name</Name><Value>Sweatpants</Value></Attribute>
    <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    <Attribute><Name>Color</Name><Value>Yellow</Value></Attribute>
    </Item>
    <Item>
    <Name>Item_06</Name>
    <Attribute><Name>Category</Name><Value>Motorcycle Parts</Value></Attribute>
    <Attribute><Name>Name</Name><Value>Fender Eliminator</Value></Attribute>
    <Attribute><Name>Color</Name><Value>Blue</Value></Attribute>
    </Item>
    </SelectResult>
    </SelectResponse> */
    
    elements = [op.responseXML.rootElement elementsForName:@"SelectResult"];
    elements = [elements[0] elementsForName:@"Item"];
    items = [NSMutableDictionary dictionary];

    for(NSXMLElement* itemElement in elements) {
      newItem = [NSMutableDictionary dictionary];
      name = [[[itemElement elementsForName:@"Name"][0] childAtIndex:0] stringValue];
      items[name] = newItem;
      attributes = [itemElement elementsForName:@"Attribute"];

      for(NSXMLElement* attribute in attributes) {
        name = [[[attribute elementsForName:@"Name"][0] childAtIndex:0] stringValue];
        value = [[[attribute elementsForName:@"Value"][0] childAtIndex:0] stringValue];
        setName = [NSString stringWithFormat:@"%@Set", name];

        if(!newItem[setName]) newItem[setName] = [NSMutableArray array];
        [(NSMutableArray*)newItem[setName] addObject:value];
        values = [(NSArray*)newItem[setName] componentsJoinedByString:@", "];
        newItem[name] = values;
      }
    }
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

@synthesize action;
@synthesize error;
@synthesize parameters;
@synthesize sdb;
@synthesize timestamp;
@synthesize connection;
@synthesize response;
@synthesize responseData;
@synthesize responseXML;
@synthesize whenDone;

+ (SDBOp*)opWithSDB:(SDB*)inSDB action:(NSString*)inAction parameters:(NSDictionary*)inParameters
{
  return [[SDBOp alloc] initWithSDB:inSDB action:inAction parameters:inParameters];
}

- (id)initWithSDB:(SDB*)inSDB action:(NSString*)inAction parameters:(NSDictionary*)inParameters
{
  if(!(self = [super init])) return nil;
  
  self.sdb = inSDB;
  self.action = inAction;
  self.parameters = inParameters;
  self.responseData = [NSMutableData data];
  return self;
}

- (void)dealloc
{
  self.sdb = nil;
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

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)inError
{	
  // Wrap Up Connection
  self.connection = nil;
  self.response = nil;
  self.responseData = nil;
  
  // Record Error
  self.error = inError;
  
  // Tell SDB
  self.whenDone(self, error);
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
  NSError*  parseError;
  NSError*  responseError;
  NSArray*  errors;
  
  // Create responseXML
  self.responseXML = [[NSXMLDocument alloc] initWithData:self.responseData options:0 error:&parseError];
  if(parseError){ self.error = parseError; self.whenDone(self, parseError); return; }
  
  // Look for Errors in responseXML
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
  errors = [self.responseXML.rootElement elementsForName:@"Errors"];
  if(errors.count) errors = [errors[0] elementsForName:@"Error"];
  if(errors.count) {
    NSArray*      codeElements;
    NSArray*      messageElements;
    NSString*     errorCode;
    NSString*     errorMessage;
    NSDictionary* errorInfo;
    NSInteger     errorInteger;
    
    codeElements = [errors[0] elementsForName:@"Code"];
    messageElements = [errors[0] elementsForName:@"Message"];
    errorCode = [[codeElements[0] childAtIndex:0] stringValue];
    errorMessage = [[messageElements[0] childAtIndex:0] stringValue];
    errorInteger = SDBErrorStringToCode(errorCode);
    errorInfo = @{NSLocalizedDescriptionKey: errorMessage};
    responseError = [NSError errorWithDomain:SDBErrorDomain code:errorInteger userInfo:errorInfo];
    self.error = responseError;
    self.whenDone(self, responseError);
    return;
  }
  
  // Wrap Up Connection
  self.connection = nil;
  self.response = nil;
  self.responseData = nil;
	
  // Tell SDB
  self.whenDone(self, nil);
}

@end

@implementation SDBChangeSet

@synthesize changes;

+ (SDBChangeSet*)changeSet
{
  return [[SDBChangeSet alloc] init];
}

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
