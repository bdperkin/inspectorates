Name:		inspectorates
Version:	0.0.1
Release:	1%{?dist}
Summary:	Internet connection bandwidth test tool

License:	GPLv2
URL:		https://github.com/bdperkin/inspectorates
Source0:	https://github.com/bdperkin/inspectorates/sources/inspectorates-%{version}.tar.gz

BuildRequires:	perl-devel
Requires:	perl

%description
Perl script to test Internet connection bandwidth to locations around the world. Uses Speedtest.net - The Global Broadband Speed Test.

%prep
%setup -q


%build
%configure
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
%make_install


%files
%doc



%changelog
* Mon Jan 28 2013 Brandon Perkins <bperkins@redhat.com> 0.0.1-1
- new package built with tito

