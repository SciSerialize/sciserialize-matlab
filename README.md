SciSerialize
============
A format for serializing scientific data.
Initial MATLAB implementation -- in alpha status.
The Definition of SciSerialize can be found [here](https://github.com/SciSerialize/Definition).

This package provides type encode- and decode-functions combined with
`json` to serialize data-types often used in scientific
computations or engineering. It can be used to serialize data to
JSON files for example.
All supported types can be serialized and can be deserialized back to the
original types in MATLAB.

This modul containing four functions:
- dumpjson
- parsejson
- serialize_data
- deserialize_data

<!-- The main goals of this module are to provide easy extensability, to be
verbose and to be elegant as possible. -->


Example of the serialization of a propper datetime
with timezone:
```matlab
date_time = datetime('now','TimeZone','local');
date_time_serialized = serialize_data(date_time);
```

The encoded output is:

```
{"__type__":"datetime","isostr":"2015-12-01T12:04:08.4730+01:00"}
```

Installation
----------------




+ Clone this repo
+ copy it to your working directory and use it like any other function.

Tested with MATLAB 2015a
 <!-- Example -->
-------
<!--```matlab

```
-->

Notes
-----
Be aware of floating point precision in JSON, if you need exactly the same bytes
as jour original object, this could be a problem!

TODO:
Check out further data types to be implemented.
