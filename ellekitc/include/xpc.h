
#ifndef xpc_h
#define xpc_h

@import Foundation;

#if !TARGET_OS_OSX
typedef void * xpc_object_t;
typedef void * xpc_connection_t;

_Nullable xpc_connection_t xpc_connection_create_mach_service(const char * _Nonnull name,
    dispatch_queue_t _Nullable targetq, uint64_t flags);

void xpc_connection_resume(xpc_connection_t _Nullable connection);

typedef void (^xpc_handler_t)(xpc_object_t _Nullable object);

void xpc_connection_set_event_handler(xpc_connection_t _Nullable connection,
    xpc_handler_t _Nonnull handler);

xpc_object_t _Nonnull xpc_dictionary_create(const char * _Nonnull const * _Nullable keys,
    const xpc_object_t _Nullable * _Nullable values, size_t count);

void
xpc_dictionary_set_string(xpc_object_t _Nonnull xdict, const char * _Nullable key,
    const char * _Nullable string);

void
xpc_dictionary_set_uint64(xpc_object_t _Nonnull xdict, const char * _Nullable key, uint64_t value);

void
xpc_dictionary_set_int64(xpc_object_t _Nonnull xdict, const char * _Nullable key, int64_t value);

uint64_t
xpc_dictionary_get_uint64(xpc_object_t _Nonnull xdict, const char * _Nullable key);

int64_t
xpc_dictionary_get_int64(xpc_object_t _Nonnull xdict, const char * _Nullable key);

xpc_object_t _Nonnull
xpc_connection_send_message_with_reply_sync(xpc_connection_t _Nonnull connection,
    xpc_object_t _Nonnull message);

#endif /* xpc_h */
#endif
