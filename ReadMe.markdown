#FJBlockURL


###The Quick and Dirty

FJBlockURLRequest is a subclass of NSMutableURLRequest. 

Instead of creating a NSURLConnection and implementing the associated methods, you instead set the appropriate handler blocks of each individual request.

Requests are scheduled and processed by instances of FJBlockURLManager. Managers can be configured to process requests in stack or queue order. You can also set the number of concurrent requests.

###Slightly More
Additionally you can: 

- Upload files directly from disk
- Provide an object that sets headers (For uses like OAuth, example class included) 
- Provide a object that formats responses (Like JSON, example also included). These are chain-able.
- set an incremental upload progress handler
- set an incremental download handler
- and more… (i.e. things I am too lazy to document right now)



