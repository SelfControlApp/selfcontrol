#import <Foundation/Foundation.h>

/// Exposes the private auditToken property on NSXPCConnection
/// so the daemon can validate the connecting client's code signature.
audit_token_t SCGetAuditToken(NSXPCConnection * _Nonnull connection);
