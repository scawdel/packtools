#!/usr/bin/perl -w
#
# Copyright 2002-2012, Stephen Fryatt
#
# This file is part of PackTools:
#
#   http://www.stevefryatt.org.uk/software/
#
# Licensed under the EUPL, Version 1.1 only (the "Licence");
# You may not use this work except in compliance with the
# Licence.
#
# You may obtain a copy of the Licence at:
#
#   http://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

# BuildRepo -- Build repository catalogues and index files based on the
#              packages containd in them.
#
# Usage: BuildRepo

use strict;

# Requires libfile-find-rule-perl and libdatetime-perl packages.

#use File::Find::Rule;
#use File::Spec;
#use Digest::MD5;
#use IO::Uncompress::Unzip qw(unzip $UnzipError);
#use DateTime;
#use HTML::Entities;
use LWP::UserAgent;

my $package = "CashBook";
my $revision = "1.31";

# The public URL of the repository; must end in /

my $url = "http://latrigg/~steve/steve/software/repo/pkg/";

my $index = "stable";

# Fetch the index file from the server.

my $ua = LWP::UserAgent->new;
$ua->agent("$0/0.1 " . $ua->agent);

my $req = HTTP::Request->new(GET => $url.$index);
$req->header('Accept' => 'text/html');

# send request
my $res = $ua->request($req);

# check the outcome
if (!$res->is_success) {
	die "Failed to fetch repository index: ".$res->status_line."\n";
}

my $last_package;
my %version;

foreach my $line (split('\n', $res->decoded_content)) {
	if (length($line) > 0 && substr($line, 0, 1) ne " ") {
		# If there's no space at the start of the line, this is a new
		# token. Break into token:value, then remove whitespace from
		# value.

		my ($name, $value) = split(':', $line);
		if (defined($name) && defined($value)) {
			$value =~ s/^\s+|\s+$//g;

			if ($name eq 'Package' && $value eq $package) {
				$last_package = $value;
			} elsif (defined($last_package) && ($name eq 'Version') && index($value, "-") > -1) {
				my ($main_rev, $pkg_rev) = split('-', $value);

				if (defined($version{$main_rev})) {
					if ($pkg_rev > $version{$main_rev}) {
						$version{$main_rev} = $pkg_rev;
					}
				} else {
					$version{$main_rev} = $pkg_rev;
				}

				undef($last_package);
			}
		}
	}
}

foreach my $key (keys(%version)) {
	print $key, " at revision ", $version{$key}, "\n";
}

if (defined($version{$revision})) {
	print "New revision: ".$revision."-".($version{$revision} + 1)."\n";
} else {
	print "New revision: ".$revision."-1\n";
}
