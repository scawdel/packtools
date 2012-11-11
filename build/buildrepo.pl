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

my $root = "/home/steve/Development/Packaging/Repo/software/repo/";

# The package index folder; must end in ;

my $indexes = "pkg/";

# Repository details; index, catalogue, folder [, folder... ]

my @repos = (
	['stable',	'stable.html',		'stable'],
	['unstable',	'unstable.html',	'unstable']);

foreach my $repo (@repos) {
	my $index = shift @$repo;
	my $catalogue = shift @$repo;

	print "Generate repository index " . $index . "\n";

	build_repo($root, $indexes, $index, $catalogue, @$repo);
}


# Build Repo
#
# Build a repository index file based on the packages found in one or more
# subdirectories of the root.
#
# Param $root		The repository root directory.
# Param $indexes	The index folder for the repository.
# Param $index		The index file for the repository.
# Param $catalogue	The catalogue file for the repository.
# Param @folders	The folders to be scanned for the repository.

sub build_repo {
	my ($root, $indexes, $index, $catalogue, @folders) = @_;

	open(CATALOGUE, ">".$root.$catalogue) || die "Can't open output file: $!\n";

	print CATALOGUE make_catalogue_header("Repo Name");

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


				print CATALOGUE "<img src=\"../images/module.png\" alt=\"\" width=34 height=34 class=\"list-image\">\n\n";

				print CATALOGUE "<h3>" . ((defined($field->{'Package'})) ? $field->{'Package'} : "Untitled") . "</h3>\n\n";

				if (defined($field->{'Description'})) {
					my $description = $field->{'Description'};

					$description =~ s|\n|</p>\n\n<p>|g;

					print CATALOGUE "<p>".$description."</p>\n\n";
				}

				print CATALOGUE "\n\n";
			} else {
				print "Unzip failed: " . $UnzipError . "\n";
			}
		}

	print CATALOGUE make_catalogue_footer();

	close(CATALOGUE);
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
			# If there's no space at the start of the line, this is a new
			# token. Break into token:value, then remove whitespace from
			# value.

			my ($name, $value) = split(':', $line);
			$value =~ s/^\s+|\s+$//g;

			$field{$name} = $value;
			$last = $name;
			$first_extra_line = 1;
		} else {
			# If there's whitespace at the start of the line, this is a
			# continuation of the previous line. Process this: lines are
			# joined with no newline, apart from before the first continuation
			# of a token value. A . on its own is a linebreak.

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

sub make_catalogue_header {
	my ($name) = @_;

	return

"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">

<html>

<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">
<link rel=\"stylesheet\" type=\"text/css\" href=\"../../style/base.css\" media=\"screen\">
<title>RISC OS Software &ndash; Repositories &ndash; Repo</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\">
<div id=\"container\">
<div id=\"header\">
<h1>Repositories &ndash; Repo</h1>
</div>

<div id=\"content\">

<p class=\"breadcrumb\">[ <a href=\"../../\" class=\"breadcrumb\">Home</a>
| <a href=\"../\" class=\"breadcrumb\">RISC OS Software</a>
| <a href=\"index.html\" class=\"breadcrumb\">Repositories</a>
| <span class=\"breadcrumb-here\">Repo</span> ]</p>

<p>The pieces of software on this page all falls under the heading of
&quot;desktop utilities&quot; - adding small extra features or
functionality to the desktop.  Many of them are relocatable modules that
can be added to the RISC OS boot sequence, though there are also some
small applications or even BASIC programs here too.</p>

<h2>Compatibility</h2>

<p>All the software on this page (apart from <cite>Find Icon Bar</cite>,
which isn't required with the &quot;Nested Wimp&quot;) is RISC OS 4
compatible and has been tested on RISC OS Select. If a minimum version of
RISC OS is required, this is indicated next to the download archive; all
software requires RISC OS 3.1 or better.</p>

<p>With the arrival of RISC OS 5, work is underway to ensure that all the
software (when applicable) will work on both 26-bit and 32-bit systems.
Most items are now marked &quot;26/32-bit neutral&quot;; anything tested
to Castle's requirements will also be marked with the &quot;Iyonix
OK&quot; logo.</p>


";
}

sub make_catalogue_footer {
	return

"<p class=\"breadcrumb\">[ <a href=\"../../\" class=\"breadcrumb\">Home</a>
| <a href=\"../\" class=\"breadcrumb\">RISC OS Software</a>
| <a href=\"index.html\" class=\"breadcrumb\">Repositories</a>
| <span class=\"breadcrumb-here\">Repositories</span> ]</p>

</div>

<div id=\"footer\">
<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;
<a href=\"http://www.riscos.com/\"><img src=\"../../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;
<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;
<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>

<p>Page last updated 5th August, 2007 | Maintained by Steve Fryatt:
<a href=\"mailto:web\@stevefryatt.org.uk\">web\@stevefryatt.org.uk</a></p>
</div>
</div>
</body>
</html>
";
}
