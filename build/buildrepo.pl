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

# TextMan -- Convert help-markup into plain text files.
#
# Usage: TextMan -I<infile> -O<outfile> [-D<var>=<val> ...]

use strict;

# Requires libfile-find-rule-perl package.

use File::Find::Rule;
use File::Spec;
use Digest::MD5;

# The root of the repository; must end in /

my $root = "/home/steve/Development/Packaging/Repo/";

# The package index folder; must end in ;

my $indexes = "pkg/";

# Repository details; index, folder [, folder... ]

my @repos = (
	['stable',	'stable'],
	['unstable',	'unstable']);

foreach my $repo (@repos) {
	my $index = shift @$repo;

	print "Generate repository index " . $index . "\n";

	build_repo($root, $indexes, $index, @$repo);
}


# Build Repo
#
# Build a repository index file based on the packages found in one or more
# subdirectories of the root.
#
# Param $root		The repository root directory.
# Param $indexes	The index folder for the repository.
# Param $index		The index file for the repository.
# Param @folders	The folders to be scanned for the repository.

sub build_repo {
	my ($root, $indexes, $index, @folders) = @_;

	foreach my $folder (@folders) {
		my $rule = File::Find::Rule->new;
		$rule->file();
		my @files = $rule->in(($root.$folder));

		foreach my $file (@files) {
			my $relative = File::Spec->abs2rel($file, $root.$indexes);

			open(FILE, $file) or die "Can't find file $file\n";
			my $ctx = Digest::MD5->new;
			$ctx->addfile(*FILE);
			my $digest = $ctx->hexdigest;
			close(FILE);

			print "** " . $file . "\n";
			print "Size: " . (-s $file) . "\n";
			print "MD5Sum: " . $digest . "\n";
			print "URL: " . $relative . "\n";
			print "\n\n";
		}
	}
}

