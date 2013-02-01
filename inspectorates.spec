Name:		inspectorates
Version:	0.0.4
Release:	1%{?dist}
Summary:	Internet connection bandwidth test tool

License:	GPLv2
URL:		https://github.com/bdperkin/%{name}
Source0:	https://github.com/bdperkin/%{name}/sources/%{name}-%{version}.tar.gz

BuildArch:	noarch
BuildRequires:	perl-devel
BuildRequires:	asciidoc
BuildRequires:	groff-base
BuildRequires:	rman
Requires:	perl
Requires:	perl-Pod-Perldoc
Requires:	less

%define NameUpper INSPECTORATES
%define NameMixed Inspectorates
%define DocFiles AUTHORS BUGS COPYING DESCRIPTION LICENSE NAME NOTES OPTIONS OUTPUT README.md RESOURCES SYNOPSIS
%define SubFiles %{name} %{name}.8.asciidoc %{DocFiles} man.asciidoc

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
a2x -d manpage -f manpage %{name}.8.asciidoc
groff -e -mandoc -Tutf8 %{name}.8 | rman -f POD >> %{name}

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir_p} %{buildroot}%{_bindir}
%{__mkdir_p} %{buildroot}%{_mandir}/man8
%{__install} %{name} %{buildroot}%{_bindir}
%{__gzip} -c %{name}.8 > %{buildroot}/%{_mandir}/man8/%{name}.8.gz

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%doc %{DocFiles}
%doc %{_mandir}/man8/%{name}.8.gz


%changelog
* Wed Jan 30 2013 Brandon Perkins <bperkins@redhat.com> 0.0.4-1
- Added man page and other docs. (bperkins@redhat.com)

* Wed Jan 30 2013 Brandon Perkins <bperkins@redhat.com> 0.0.3-1
- Automatic commit of package [inspectorates] release [0.0.2-1].
  (bperkins@redhat.com)

* Tue Jan 29 2013 Brandon Perkins <bperkins@redhat.com> 0.0.2-1
- new package built with tito

* Mon Jan 28 2013 Brandon Perkins <bperkins@redhat.com> 0.0.1-1
- new package built with tito

