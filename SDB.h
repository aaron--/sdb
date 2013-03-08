//
//  SDB
//
//  SDB is a simple block-based client that helps you make
//  requests to SimpleDB.
//

@class SDBChangeSet;

typedef void(^SDBCreateDomainDone)(NSError* error);
typedef void(^SDBDeleteDomainDone)(NSError* error);
typedef void(^SDBDomainMetadataDone)(NSDictionary* metadata, NSError* error);
typedef void(^SDBListDomainsDone)(NSArray* domains, NSError* error);
typedef void(^SDBGetAttributesDone)(NSDictionary* attributes, NSError* error);
typedef void(^SDBSelectDone)(NSDictionary* items, NSError* error);
typedef void(^SDBWriteChangesDone)(NSError* error);

@interface SDB : NSObject

+ (SDB*)sdbWithKey:(NSString*)key secret:(NSString*)secret;

// Properties
@property (readonly) NSString*  key;
@property (readonly) NSString*  secret;

// Domain Management
- (void)createDomain:(NSString*)domain whenDone:(SDBCreateDomainDone)block;
- (void)deleteDomain:(NSString*)domain whenDone:(SDBDeleteDomainDone)block;
- (void)domainMetadata:(NSString*)domain whenDone:(SDBDomainMetadataDone)block;
- (void)listDomains:(SDBListDomainsDone)block;

// Read
- (void)getAttributes:(NSString*)domain item:(NSString*)item whenDone:(SDBGetAttributesDone)block;
- (void)select:(NSString*)expression whenDone:(SDBSelectDone)block;

// Write
- (void)putAttributes:(NSString*)domain item:(NSString*)item
              changes:(SDBChangeSet*)changeSet
             whenDone:(SDBWriteChangesDone)block;
@end

@interface SDBChangeSet : NSObject

+ (SDBChangeSet*)changeSet;

- (void)setAttribute:(NSString*)attr value:(NSString*)value;
- (void)addAttribute:(NSString*)attr value:(NSString*)value;

@end

extern NSString* SDBErrorDomain;
enum {
  SDBAccessFailureError,
  SDBAttributeDoesNotExistError,
  SDBAuthFailureError,
  SDBAuthMissingFailureError,
  SDBConditionalCheckFailedError,
  SDBExistsAndExpectedValueError,
  SDBFeatureDeprecatedError,
  SDBIncompleteExpectedExpressionError,
  SDBInternalErrorError,
  SDBInvalidActionError,
  SDBInvalidHTTPAuthHeaderError,
  SDBInvalidHttpRequestError,
  SDBInvalidLiteralError,
  SDBInvalidNextTokenError,
  SDBInvalidNumberPredicatesError,
  SDBInvalidNumberValueTestsError,
  SDBInvalidParameterCombinationError,
  SDBInvalidParameterValueError,
  SDBInvalidQueryExpressionError,
  SDBInvalidResponseGroupsError,
  SDBInvalidServiceError,
  SDBInvalidSortExpressionError,
  SDBInvalidURIError,
  SDBInvalidWSAddressingPropertyError,
  SDBInvalidWSDLVersionError,
  SDBMissingActionError,
  SDBMissingParameterError,
  SDBMissingWSAddressingPropertyError,
  SDBMultipleExistsConditionsError,
  SDBMultipleExpectedNamesError,
  SDBMultipleExpectedValuesError,
  SDBMultiValuedAttributeError,
  SDBNoSuchDomainError,
  SDBNoSuchVersionError,
  SDBNotYetImplementedError,
  SDBNumberDomainsExceededError,
  SDBNumberDomainAttributesExceededError,
  SDBNumberDomainBytesExceededError,
  SDBNumberItemAttributesExceededError,
  SDBNumberSubmittedAttributesExceededError,
  SDBNumberSubmittedItemsExceededError,
  SDBRequestExpiredError,
  SDBQueryTimeoutError,
  SDBServiceUnavailableError,
  SDBTooManyRequestedAttributesError,
  SDBUnsupportedHttpVerbError,
  SDBUnsupportedNextTokenError,
  SDBURITooLongError
};
NSString* SDBErrorCodeToString(NSInteger errorCode);
