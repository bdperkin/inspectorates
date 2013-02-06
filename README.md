== Name ==

inspectorates — Internet connection bandwidth test tool

== Synopsis ==

'''inspectorates''' ['''-q'''|'''--quiet'''] ['''-v'''|'''--verbose'''] ['''-d'''|'''--debug'''] ['''-s''' ''servers''|'''--servers'''=''servers'']

'''inspectorates''' {'''--version'''|'''-V'''}

'''inspectorates''' {'''--help'''|'''-h'''}

'''inspectorates''' {'''--man'''|'''-m'''}

== DESCRIPTION ==

The inspectorates(8) command is a Perl script to test Internet connection bandwidth to locations around the world. Uses Speedtest.net - The Global Broadband Speed Test.

== OPTIONS ==



;  '''-d''', '''--debug''' 
: Debug output.
;  '''-h''', '''--help''' 
: Print or show help information and exit.
;  '''-m''', '''--man''' 
: Print the entire manual page and exit.
;  '''-q''', '''--quiet''' 
: Quiet output.
;  '''-s''' ''servers'', '''--server'''=''servers'' 
: Number of closest servers for ping test and test pool.
;  '''-v''', '''--verbose''' 
: Verbose output.
;  '''-V''', '''--version''' 
: Print or show the program version and release number and exit.

== EXIT STATUS ==



;  '''0''' 
: Success.
;  '''1''' 
: Failure (syntax or usage error; configuration error; unexpected error).

== BUGS ==

Report any issues at: [https://github.com/bdperkin/inspectorates/issues https://github.com/bdperkin/inspectorates/issues]

== AUTHORS ==

Brandon Perkins &lt;[mailto:bperkins@redhat.com bperkins@redhat.com]&gt;

== RESOURCES ==

GitHub: [https://github.com/bdperkin/inspectorates https://github.com/bdperkin/inspectorates]

== COPYING ==

Copyright (C) 2013-2013 Brandon Perkins &lt;[mailto:bperkins@redhat.com bperkins@redhat.com]&gt;

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
