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
use IO::Uncompress::Unzip qw(unzip $UnzipError);

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

			# Calculate the MD5 hash for the file.

			my $md5;
			if (open(FILE, $file)) {
				my $ctx = Digest::MD5->new;
				$ctx->addfile(*FILE);
				$md5 = $ctx->hexdigest;
				close(FILE);
			}

			# Exctract the control file, if we can. Try two filenames, to allow
			# for the fact tha Unzip seems to get confused by the RISC OS
			# filetypes.

			my $control;
			unzip $file => \$control, Name => "RiscPkg/Control\x00fff" or $control = undef;
			if (!defined($control)) {
				unzip $file => \$control, Name => "RiscPkg/Control" or $control = undef;
			}

			# If the file existed and could be understood, then process it and add it
			# to the package index.

			if (defined($md5) && defined($control)) {
				my $field = parse_control($control);

				chomp $control;

				print $control . "\n";
				print "Size: " . (-s $file) . "\n";
				print "MD5Sum: " . $md5 . "\n";
				print "URL: " . $relative . "\n";
				print "\n\n";

				print "<h2>" . ((defined($field->{'Package'})) ? $field->{'Package'} : "Untitled") . "</h2>\n\n";

				if (defined($field->{'Description'})) {
					my $description = $field->{'Description'};

					$description =~ s|\n|</p>\n\n<p>|g;

					print "<p>".$description."</p>\n\n";
				}

				print "\n\n";
			} else {
				print "Unzip failed: " . $UnzipError . "\n";
			}
		}
	}
}


# Break a control file up into a hash, with each token being held in a separate
# entry.
#
# Param $control	The control file contents.
# Return		A reference to the control hash.

sub parse_control {
	my ($control) = @_;

	my %field;
	my $last;
	my $first_extra_line = 0;

	foreach my $line (split('\n', $control)) {
		if (substr($line, 0, 1) ne " ") {
			my ($name, $value) = split(':', $line);
			$value =~ s/^\s+|\s+$//g;

			$field{$name} = $value;
			$last = $name;
			$first_extra_line = 1;
		} else {
			if (defined($last)) {
				$line =~ s/^\s+|\s+$//g;

				if ($line ne '.' && length($line) > 0) {
					if ($first_extra_line) {
						$field{$last} .= "\n";
					}
					$field{$last} .= $line;
				} else {
					$field{$last} .= "\n";
				}
					$first_extra_line = 0;
			}
		}
	}

	return \%field;
}
