
Name
----

inspectorates — Internet connection bandwidth test tool

Synopsis
--------

*inspectorates* [ *-q* | *--quiet* ] [ *-v* | *--verbose* ]
[ *-d* | *--debug* ] [ *-C* | *--curlvrbs* ] [ *-u*
*url* | *--url* = *url* ] [ *-s* *servers* | *--servers* = *servers* ]
[ *-p* *pings* | *--pings* = *pings* ] [ *-c*
*count* | *--count* = *count* ]

*inspectorates* { *--version* | *-V* }

*inspectorates* { *--help* | *-h* }

*inspectorates* { *--man* | *-m* }

DESCRIPTION
-----------

The inspectorates(8) command is a Perl script to test Internet
connection bandwidth to locations around the world. Uses Speedtest.net -
The Global Broadband Speed Test.

OPTIONS
-------

Command line options are used to specify various startup options for
inspectorates:


 *-c* *count*, *--count* = *count* 
:   Count of latency tests to perform against selected server.

 *-C*, *--curlvrbs* 
:   Set CURLOPT\_VERBOSE option to make the fetching more
    verbose/talkative.

 *-d*, *--debug* 
:   Debug output.

 *-h*, *--help* 
:   Print or show help information and exit.

 *-m*, *--man* 
:   Print the entire manual page and exit.

 *-p* *pings*, *--pings* = *pings* 
:   Number of ping tests to perform against candidate servers.

 *-q*, *--quiet* 
:   Quiet output.

 *-s* *servers*, *--servers* = *servers* 
:   Number of closest servers for ping test and test pool.

 *-u* *url*, *--url* = *url* 
:   Specify a specific Ookla Speedtest® connection testing server.

 *-v*, *--verbose* 
:   Verbose output.

 *-V*, *--version* 
:   Print or show the program version and release number and exit.

EXIT STATUS
-----------

The inspectorates return code to the parent process (or caller) when it
has finished executing may be one of:


 *0* 
:   Success.

 *1* 
:   Failure (syntax or usage error; configuration error; unexpected
    error).

BUGS
----

Report any issues at:
[https://github.com/bdperkin/inspectorates/issues](https://github.com/bdperkin/inspectorates/issues)

AUTHORS
-------

Brandon Perkins \<[bperkins@redhat.com](mailto:bperkins@redhat.com)\>

RESOURCES
---------

GitHub:
[https://github.com/bdperkin/inspectorates](https://github.com/bdperkin/inspectorates)

COPYING
-------

Copyright (C) 2013-2013 Brandon Perkins
\<[bperkins@redhat.com](mailto:bperkins@redhat.com)\>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
