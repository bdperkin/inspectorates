Name:		inspectorates
Version:	0.0.10
Release:	1%{?dist}
Summary:	Internet connection bandwidth test tool

Group:		Applications/Internet
License:	GPLv2
URL:		https://github.com/bdperkin/%{name}
Source0:	https://github.com/bdperkin/%{name}/sources/%{name}-%{version}.tar.gz

BuildArch:	noarch
BuildRequires:	asciidoc
BuildRequires:	docbook-style-xsl
BuildRequires:	/usr/bin/groff
BuildRequires:	libxslt
BuildRequires:	pandoc
BuildRequires:	/usr/bin/perltidy
BuildRequires:	/usr/bin/podchecker
BuildRequires:	w3m
Requires:	/usr/bin/perl
Requires:	/usr/bin/perldoc
Requires:	perl(Data::Dumper::Names)
Requires:	perl(Data::Random)
Requires:	perl(File::Basename)
Requires:	perl(GD)
Requires:	perl(Getopt::Long)
Requires:	perl(Math::Trig)
Requires:	perl(Pod::Usage)
Requires:	perl(Time::HiRes)
Requires:	perl(URI::Split)
Requires:	perl(WWW::Curl::Easy)
Requires:	perl(XML::XPath)
Requires:	perl(strict)
Requires:	perl(warnings)

%define NameUpper %{expand:%%(echo %{name} | tr [:lower:] [:upper:])}
%define NameMixed %{expand:%%(echo %{name} | %{__sed} -e "s/\\([a-z]\\)\\([a-zA-Z0-9]*\\)/\\u\\1\\2/g")}
%define NameLower %{expand:%%(echo %{name} | tr [:upper:] [:lower:])}
%define Year %{expand:%%(date "+%Y")}
%define DocFiles ACKNOWLEDGEMENTS AUTHOR AUTHORS AVAILABILITY BUGS CAVEATS COPYING COPYRIGHT DESCRIPTION LICENSE NAME NOTES OPTIONS OUTPUT README.md RESOURCES SYNOPSIS
%define SubFiles %{name} %{name}.8.asciidoc %{DocFiles} man.asciidoc
%define DocFormats chunked htmlhelp manpage text xhtml

%description
Perl script to test Internet connection bandwidth to locations around the world. Uses Speedtest.net - The Global Broadband Speed Test.

%prep
%setup -q

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%build
%{__cp} %{name}.pl %{name}
%{__sed} -i -e s/%{NAME}/%{name}/g %{SubFiles}
%{__sed} -i -e s/%{NAMEUPPER}/%{NameUpper}/g %{SubFiles}
%{__sed} -i -e s/%{NAMEMIXED}/%{NameMixed}/g %{SubFiles}
%{__sed} -i -e s/%{NAMELOWER}/%{NameLower}/g %{SubFiles}
%{__sed} -i -e s/%{VERSION}/%{version}/g %{SubFiles}
%{__sed} -i -e s/%{RELEASE}/%{release}/g %{SubFiles}
%{__sed} -i -e s/%{YEAR}/%{Year}/g %{SubFiles}
for f in %{DocFormats}; do %{__mkdir_p} $f; a2x -D $f -d manpage -f $f %{name}.8.asciidoc; done
groff -e -mandoc -Tascii manpage/%{name}.8 > manpage/%{name}.8.groff
%{__mkdir_p} pod
./groff2pod.pl manpage/%{name}.8.groff pod/%{name}.8.pod
podchecker pod/%{name}.8.pod
cat pod/%{name}.8.pod >> %{name}
perltidy -b %{name}
podchecker %{name}
pandoc -f html -t markdown -s -o README.md.pandoc xhtml/%{name}.8.html
cat README.md.pandoc | %{__grep} -v ^% | %{__sed} -e 's/\*\*/\*/g' | %{__sed} -e 's/^\ \*/\n\ \*/g' | %{__sed} -e 's/\[\*/\[\ \*/g' | %{__sed} -e 's/\*\]/\*\ \]/g' | %{__sed} -e 's/{\*/{\ \*/g' | %{__sed} -e 's/\*}/\*\ }/g' | %{__sed} -e 's/|\*/|\ \*/g' | %{__sed} -e 's/\*|/\*\ |/g' | %{__sed} -e 's/=\*/=\ \*/g' | %{__sed} -e 's/\*=/\*\ =/g' > README.md 

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir_p} %{buildroot}%{_bindir}
%{__mkdir_p} %{buildroot}%{_mandir}/man8
%{__install} %{name} %{buildroot}%{_bindir}
%{__gzip} -c manpage/%{name}.8 > %{buildroot}/%{_mandir}/man8/%{name}.8.gz

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%doc %{DocFiles}
%doc %{DocFormats} pod
%doc %{_mandir}/man8/%{name}.8.gz


%changelog
* Mon Mar 25 2013 Brandon Perkins <bperkins@redhat.com> 0.0.10-1
- Commit build artifacts and include basic debian and lsb configurations.
  (bperkins@redhat.com)
- Return to current branch, not master. (bperkins@redhat.com)
- rpm2alien (bperkins@redhat.com)
- Ignore http-client-tests in tar export. (bperkins@redhat.com)
- first commit with submodule debhelper (bperkins@redhat.com)
- first commit with submodule alien (bperkins@redhat.com)
- Merge branch 'master' of github.com:bdperkin/inspectorates
  (bperkins@redhat.com)
- Print a list of candidate servers. (bperkins@redhat.com)

* Thu Mar 21 2013 Brandon Perkins <bperkins@redhat.com> 0.0.9-1
- Perl Tidy the final executable, add additional standard doc files, clean-up
  %%doc dirs. (bperkins@redhat.com)
- Fix headers so pod2usage will work again. (bperkins@redhat.com)
- make spec happy (bperkins@redhat.com)
- Homespun man2pod. (bperkins@redhat.com)
- groff2pod in attempt to drop troublesome rman (bperkins@redhat.com)
- remove debugging (bperkins@redhat.com)
- Updated README markdown file. (bperkins@redhat.com)
- spec and pod fixes (bperkins@redhat.com)
- Ignore scratch directory. (bperkins@redhat.com)
- Revert pod modifications. (bperkins@redhat.com)
- Updated README markdown file. (bperkins@redhat.com)
- Finish custom server/url code. (bperkins@redhat.com)
- Respect server latency waittime. (bperkins@redhat.com)
- Add Data::Dumper::Names module to get hash names. Remove unused MIME::Base64
  module. Document the debug variable. Make debugging output more dynamic so
  dev needs to do less text formatting. Document what numpingcount is to make
  it clearer how server or command-line args are used. Document what
  curloptverbose is and what it's settings are. Make it so custom server URL
  configuration passed overrides global speedtest settings.
  (bperkins@redhat.com)
- Initial pass at custom URL. (bperkins@redhat.com)
- Document CURLOPT_VERBOSE option. (bperkins@redhat.com)
- More text formatting clean-up. (bperkins@redhat.com)
- Significant improvement in upload tests and some text formatting.
  (bperkins@redhat.com)
- Remove url2 as it has been dropped from the server xml. (bperkins@redhat.com)
- Add option to turn on CURLOPT_VERBOSE Remove CURLOPT_TCP_KEEPALIVE,
  CURLOPT_TCP_KEEPIDLE, and CURLOPT_TCP_KEEPINTVL Print cURL versions (libcurl,
  zlib, libssh2, libidn, NSS, etc.) in debug mode (bperkins@redhat.com)
- Slim the module imports Enable cURL TCP Keep Idle and Interval First pass at
  upload code. Added perl modules: Data-Random, GD, and WWW-Curl to spec
  requires. (bperkins@redhat.com)
- Add TCP_KEEPALIVE and TCP_NODELAY options to the browser. Make ms since epoch
  a global variable and define it at conf retrieval time. Go ahead and force
  ever XPath retrieved value into a string value. Define the server 2 URL for
  the selected server. Add two download tests of largest download size against
  the server 2 URL. Smarter about which download sizes to get based on running
  speed average. (bperkins@redhat.com)
- Changed HTTP Client Module from LWP::UserAgent to WWW::Curl::Easy after
  reviewing results from http-client-tests.  Curl is really the only choice,
  fuzzy results could be obtained from HTTP-Tiny, HTTP-Lite, Net-HTTP, and LWP-
  UserAgent would be the fall-backs if cURL is NOT available.
  (bperkins@redhat.com)
- http-client-tests so the best HTTP client can be chosen (bperkins@redhat.com)
- First pass at download code. (bperkins@redhat.com)
- Changed HTTP Client Module from LWP::UserAgent to WWW::Curl::Easy after
  reviewing results from http-client-tests.  Curl is really the only choice,
  fuzzy results could be obtained from HTTP-Tiny, HTTP-Lite, Net-HTTP, and LWP-
  UserAgent would be the fall-backs if cURL is NOT available.
  (bperkins@redhat.com)
- Break out the request from the response to be consistent with other tests.
  (bperkins@redhat.com)
- tidy (bperkins@redhat.com)
- Remove URI-Fetch as it does not support POST. (bperkins@redhat.com)
- Remove LWP-Simple as it does not support POST. (bperkins@redhat.com)
- Remove Mojo-UserAgent as it seems it can't get a large enough buffer for the
  tests. (bperkins@redhat.com)
- Remove template. (bperkins@redhat.com)
- Add URI::Fetch - Smart URI fetching/caching. (bperkins@redhat.com)
- Add Mojo::UserAgent - Non-blocking I/O HTTP and WebSocket user agent.
  (bperkins@redhat.com)
- Add WWW::Curl - Perl extension interface for libcurl. (bperkins@redhat.com)
- Add HTTP::Lite - Lightweight HTTP implementation. (bperkins@redhat.com)
- Add HTTP::Tiny - A small, simple, correct HTTP/1.1 client.
  (bperkins@redhat.com)
- Add Net::HTTP - Low-level HTTP connection (client). (bperkins@redhat.com)
- Add LWP::Simple - simple procedural interface to LWP. (bperkins@redhat.com)
- Add LWP::UserAgent - Web user agent class. (bperkins@redhat.com)
- Add LWP - The World-Wide Web library for Perl test and enhance template.
  (bperkins@redhat.com)
- http-client-tests so the best HTTP client can be chosen (bperkins@redhat.com)
- Improve dubugging output to be cleaner and more readable.
  (bperkins@redhat.com)

* Tue Feb 19 2013 Brandon Perkins <bperkins@redhat.com> 0.0.8-1
- Implemented Ping/Latency functionality. (bperkins@redhat.com)
- Only Require perl-Time-HiRes on RHEL 6. (bperkins@redhat.com)
- Best server selection complete. (bperkins@redhat.com)
- Add normal output level messages. (bperkins@redhat.com)
- Force UTF-8 output, remove unneeded hash sorts, remove serverdistance hash
  and include distance data within the server hash within the servers hash.
  (bperkins@redhat.com)
- Collect all server attributes in hash.  More details on selected servers.
  (bperkins@redhat.com)
- Add w3m Build Requires. (bperkins@redhat.com)
- Updated README markdown file. (bperkins@redhat.com)

* Wed Feb 06 2013 Brandon Perkins <bperkins@redhat.com> 0.0.7-1
- Auto README markdown commit. (bperkins@redhat.com)
- Python libraries for new builder. (bperkins@redhat.com)
- Multiple format documentation. (bperkins@redhat.com)
- Comments, Docs, and Clean-up. (bperkins@redhat.com)
- Remove "5" as a magic number and make it a default · Issue #1 ·
  bdperkin/inspectorates · GitHub Added -s/--server option with value error
  checking. Code clean-up. (bperkins@redhat.com)
- Add comment WRT mean radius of the Earth. (bperkins@redhat.com)

* Tue Feb 05 2013 Brandon Perkins <bperkins@redhat.com> 0.0.6-1
- Merge in original offline work. (bperkins@redhat.com)
- Add /bin to PATH for older OS versions.  Require coreutils.  Replace less
  with more.  Only Require perl-Pod-Perldoc on newer OS versions.
  (bperkins@redhat.com)
- The build requires docbook-style-xsl and libxslt. (bperkins@redhat.com)
- Add to Applications/Internet Group, remove perl-devel BuildRequires, require
  groff command instead of package. (bperkins@redhat.com)

* Mon Feb 04 2013 Brandon Perkins <bperkins@redhat.com> 0.0.5-1
- Dynamic copyright. (bperkins@redhat.com)
- Make help/man better by using POD. (bperkins@redhat.com)
- Add verbosity and comments. (bperkins@redhat.com)
- Print or show help information and exit. (bperkins@redhat.com)
- Print or show the program version number and exit. (bperkins@redhat.com)
* Wed Jan 30 2013 Brandon Perkins <bperkins@redhat.com> 0.0.4-1
- Added man page and other docs. (bperkins@redhat.com)

* Wed Jan 30 2013 Brandon Perkins <bperkins@redhat.com> 0.0.3-1
- Automatic commit of package [inspectorates] release [0.0.2-1].
  (bperkins@redhat.com)

* Tue Jan 29 2013 Brandon Perkins <bperkins@redhat.com> 0.0.2-1
- new package built with tito

* Mon Jan 28 2013 Brandon Perkins <bperkins@redhat.com> 0.0.1-1
- new package built with tito

