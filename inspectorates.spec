Name:		inspectorates
Version:	0.0.3
Release:	1%{?dist}
Summary:	Internet connection bandwidth test tool

License:	GPLv2
URL:		https://github.com/bdperkin/inspectorates
Source0:	https://github.com/bdperkin/inspectorates/sources/inspectorates-%{version}.tar.gz

BuildArch:	noarch
BuildRequires:	perl-devel
Requires:	perl

%description
Perl script to test Internet connection bandwidth to locations around the world. Uses Speedtest.net - The Global Broadband Speed Test.

%prep
%setup -q

%clean
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/{bin,doc,man}
cat inspectorates.pl | sed -e s/%{NAME}/%{name}/g | sed -e s/%{VERSION}/%{version}/g | sed -e s/%{RELEASE}/%{release}/g > inspectorates
install inspectorates $RPM_BUILD_ROOT/usr/bin

%files
%defattr(-,root,root,-)
/usr/bin/inspectorates

%doc AUTHORS  COPYING  LICENSE  README.md



%changelog
* Wed Jan 30 2013 Brandon Perkins <bperkins@redhat.com> 0.0.3-1
- Automatic commit of package [inspectorates] release [0.0.2-1].
  (bperkins@redhat.com)

* Tue Jan 29 2013 Brandon Perkins <bperkins@redhat.com> 0.0.2-1
- new package built with tito

* Mon Jan 28 2013 Brandon Perkins <bperkins@redhat.com> 0.0.1-1
- new package built with tito

