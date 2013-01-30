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
Requires:	perl

%description
Perl script to test Internet connection bandwidth to locations around the world. Uses Speedtest.net - The Global Broadband Speed Test.

%prep
%setup -q

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%build
a2x -d manpage -f manpage %{name}.8.asciidoc

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir_p} %{buildroot}%{_bindir}
%{__mkdir_p} %{buildroot}%{_mandir}/man8
%{__cat} %{name}.pl | %{__sed} -e s/%{NAME}/%{name}/g | %{__sed} -e s/%{VERSION}/%{version}/g | %{__sed} -e s/%{RELEASE}/%{release}/g > %{name}
%{__install} %{name} %{buildroot}%{_bindir}
%{__gzip} -c %{name}.8 > %{buildroot}/%{_mandir}/man8/%{name}.8.gz

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%doc AUTHORS  BUGS  COPYING  LICENSE  README.md
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

