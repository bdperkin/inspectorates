Name:		inspectorates
Version:	0.0.6
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
BuildRequires:	pandoc
BuildRequires:	rman
BuildRequires:	libxslt
Requires:	coreutils
Requires:	perl
%if 0%{?fedora} >= 17
Requires:	perl-Pod-Perldoc
%endif
Requires:	util-linux

%define NameUpper INSPECTORATES
%define NameMixed Inspectorates
%define Year %{expand:%%(date "+%Y")}
%define DocFiles AUTHORS BUGS COPYING DESCRIPTION LICENSE NAME NOTES OPTIONS OUTPUT README.md RESOURCES SYNOPSIS
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
%{__sed} -i -e s/%{VERSION}/%{version}/g %{SubFiles}
%{__sed} -i -e s/%{RELEASE}/%{release}/g %{SubFiles}
%{__sed} -i -e s/%{YEAR}/%{Year}/g %{SubFiles}
for f in %{DocFormats}; do %{__mkdir_p} $f; a2x -D $f -d manpage -f $f %{name}.8.asciidoc; done
groff -e -mandoc -Tascii manpage/%{name}.8 | rman -f POD >> %{name}
for i in $(%{__grep} '^=head1 ' %{name} | %{__awk} '{print $2,$3,$4}'); do echo -n "$i => "; j=$(echo $i | %{__sed} -e 's/B<//g' | %{__sed} -e 's/>//g' | tr [:lower:] [:upper:]); echo $j; %{__sed} -i -e "s/$i/$j/g" %{name}; done
pandoc -f html -t markdown -s -o README.md xhtml/%{name}.8.html

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
%doc %{DocFormats}
%doc %{_mandir}/man8/%{name}.8.gz


%changelog
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

