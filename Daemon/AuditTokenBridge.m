#import "AuditTokenBridge.h"

@interface NSXPCConnection (AuditToken)
@property (nonatomic, readonly) audit_token_t auditToken;
@end

audit_token_t SCGetAuditToken(NSXPCConnection *connection) {
    return connection.auditToken;
}
