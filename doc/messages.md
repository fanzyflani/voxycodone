# Proposed C-Lua API

## gotmail:b = mail.recv(f:function(other:MBoxRef, ...):())

Handle a message.

Returns true if a message came through.

Returns false if there wasn't a pulse.

It's done this way because it's easier to handle varargs.

## mail.send(other:MBoxRef, ...)

Send a message.

Returns a message ID for working out replies.

Arguments can be any of these types:

* int
* float
* string
* boolean
* nil

Anything else throws an error.

# Some messages that might be a thing

Note, `msgid` can be absolutely anything that can be passed.

* `("local_load", msgid, fname:str)`
  * `("*OK", msgid, data:str)`
  * `("*FAIL", msgid, reason:str)`
* `("local_save", msgid, fname:str, data:str)`
  * `("*OK", msgid)`
  * `("*FAIL", msgid, reason:str)`

[]: # ( vim: set syntax=markdown : )

