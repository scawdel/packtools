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

# Requires libfile-find-rule-perl and libdatetime-perl packages.

use File::Find::Rule;
use File::Spec;
use Digest::MD5;
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use DateTime;

# The public URL of the repository; must end in /

my $url = "http://www.stevefryatt.org.uk/software/repo/";

# The root of the repository; must end in /

my $root = "/home/steve/Development/Packaging/Repo/software/repo/";

# The package index folder; must end in ;

my $indexes = "pkg/";

# Repository details; name, index, catalogue, introduction, folder [, folder... ]

my @repos = (
	# Stable Repository

	['Stable',	'stable',	'stable.html',

'<p>The &lsquo;stable&rsquo; repository contains release versions of software. If
you wish to test the latest &ldquo;cutting-edge&rdquo; developments, you should
make use of the packages in the <a href="unstable.html">unstable repository</a>.</p>',

	'stable'],

	# Unstable Repository

	['Unstable',	'unstable',	'unstable.html',

'<p>The &lsquo;unstable&rsquo; repository contains packages of software which
is currently under development. In contrast to the <a href="stable.html">stable
repository</a>, the packages here are development test builds of software which
can be found elsewhere. By their nature, these builds have had limited testing
and may contain bugs or even be unstable. While testing and feedback will be
welcomed, users uncomfortable with the potential risks may prefer to continue
using the stable releases of these applications &ndash; which can be found
elsewhere on this site.</p>

<p><strong>These builds may contain bugs, be unstable and have the potential to
cause data loss. Those using them are advised to maintain adequate backups of
important data and follow sensible precautions.</strong></p>

<p>Test builds can be easily identified from the version details in their
documentation and the info box on the iconbar menu. Whereas stable releases have
a version number of the form &ldquo;1.23&rdquo;, test builds carry the build date
and a revision number of the form &ldquo;r123&rdquo; which uniquely identifies the
version of source code used to create it. When reporting bugs, please always quote
the relevant version number or revision code.</p>',

	'unstable']);

foreach my $repo (@repos) {
	my $name = shift @$repo;
	my $index = shift @$repo;
	my $catalogue = shift @$repo;
	my $intro = shift @$repo;

	print "Generate repository " . $name . "\n";

	build_repo($name, $intro, $root, $url, $indexes, $index, $catalogue, @$repo);
}


# Build Repo
#
# Build a repository index file based on the packages found in one or more
# subdirectories of the root.
#
# Param $name		The name of the repository.
# Param $intro		The introductory text for the repository.
# Param $root		The repository root directory.
# Param $url		The base URL of the online repository.
# Param $indexes	The index folder for the repository.
# Param $index		The index file for the repository.
# Param $catalogue	The catalogue file for the repository.
# Param @folders	The folders to be scanned for the repository.

sub build_repo {
	my ($name, $intro, $root, $url, $indexes, $index, $catalogue, @folders) = @_;

	my %packages;

	# Scan the package folders in the repository and collect all of the
	# packages that we can find:
	#
	# %packages contains an entry for each unique Package tag found, containing
	# a reference to a new hash.
	#
	# The referenced hash contains an entry for each unique Version tag found,
	# containing a reference to another new hash.
	#
	# This referenced hash contains all of the tag data for the package version,
	# plus any other data required by the output.

	foreach my $folder (@folders) {
		my $rule = File::Find::Rule->new;
		$rule->file();
		my @files = $rule->in(($root.$folder));

		foreach my $file (@files) {
			print "Starting to process " . $file . "...\n";

			my $md5;
			my $size;
			my $date;

			# Collect the Size, Creation Date and MD5Sum for the file.

			if (open(FILE, $file)) {
				my $ctx = Digest::MD5->new;
				$ctx->addfile(*FILE);
				$md5 = $ctx->hexdigest;

				my @stat = stat(FILE);
				$size = $stat[7];
				$date = $stat[9];
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

			if (defined($md5) && defined($size) && defined($date) && defined($control)) {
				my $field = parse_control($control);

				if (!defined($field->{'Package'})) {
					$field->{'Package'} = "Untitled";
					print "Missing Package attribute in " . $file . "\n";
				}

				if (!defined($field->{'Version'})) {
					$field->{'Version'} = "Unknown";
					print "Missing Version attribute in " . $file . "\n";
				}

				$field->{'Size'} = $size;
				$field->{'MD5Sum'} = $md5;
				$field->{'URL'} = File::Spec->abs2rel($file, $root.$indexes);

				$field->{'Cat-Date'} = $date;
				$field->{'Cat-URL'} = File::Spec->abs2rel($file, $root);
				$field->{'Cat-Control'} = $control;

				if (!defined($packages{$field->{'Package'}})) {
					$packages{$field->{'Package'}} = {$field->{'Version'} => $field};
					print "Version " . $field->{'Version'} . " added to new package " . $field->{'Package'} . ".\n";
				} elsif (!defined($packages{$field->{'Package'}}->{$field->{'Version'}})) {
					$packages{$field->{'Package'}}->{$field->{'Version'}} = $field;
					print "Version " . $field->{'Version'} . " added to existing package " . $field->{'Package'} . ".\n";
				} else {
					print "Duplicate package.\n";
				}
			} else {
				print "Failed to process.\n";
			}
		}
	}

	# Output the human-friendly catalogue page.

	my @date_postfix = ("-", "st", "nd", "rd", "th", "th", "th", "th", "th",
			"th", "th", "th", "th", "th", "th", "th", "th", "th",
			"th", "th", "th", "st", "nd", "rd", "th", "th", "th",
			"th", "th", "th", "th", "st");

	open(CATALOGUE, ">".$root.$catalogue) || die "Can't open output file: $!\n";
	open(INDEX, ">".$root.$indexes.$index) || die "Can't open output file: $!\n";

	print CATALOGUE make_catalogue_header($name);
	print CATALOGUE $intro . "\n";
	print CATALOGUE make_catalogue_path_info($url.$indexes.$index);
	print "\n";

	my $newest_date = 0;

	foreach my $pkg_key (sort keys(%packages)) {
		print "Processing " . $pkg_key . "\n";

		my $versions = $packages{$pkg_key};

		print CATALOGUE "\n<!-- " . $pkg_key . " -->\n\n";
		print CATALOGUE "<img src=\"../images/zip.png\" alt=\"\" width=34 height=34 class=\"list-image\">\n\n";
		print CATALOGUE "<h3>" . $pkg_key . "</h3>\n\n";

		my $last_description = "";

		foreach my $vsn_key (sort {$b cmp $a} keys(%$versions)) {
			print "..Processing " . $vsn_key . "\n";

			my $fields = $versions->{$vsn_key};


			if (defined($fields->{'Description'}) && $fields->{'Description'} ne $last_description) {
				print CATALOGUE make_html_block($fields->{'Description'}) . "\n";
				$last_description = $fields->{'Description'};
			}

			print CATALOGUE "<p class=\"download\"><img src=\"../images/zip.png\" alt=\"\" width=34 height=34>\n";
			# print CATALOGUE "<img src=\"../images/iyonix.gif\" alt=\"Iyonix OK\" width=34 height=39 class=\"iyonix\">\n";
			print CATALOGUE "<b>Download:</b> <a href=\"".$fields->{'Cat-URL'}."\">".$fields->{'Package'}." ".$fields->{'Version'}."</a> ";
			print CATALOGUE "(MD5: <code>" . $fields->{'MD5Sum'} . "</code>)<br>\n";

			my $date = DateTime->from_epoch(epoch => $fields->{'Cat-Date'});
			my $size = $fields->{'Size'};
			my $size_unit = "bytes";

			if ($fields->{'Cat-Date'} > $newest_date) {
				$newest_date = $fields->{'Cat-Date'};
			}

			if ($size > 1048576) {
				$size = int(($size + 524288) / 1048576);
				$size_unit = "Mbytes";
			} elsif ($size > 1536) {
				$size = int(($size + 512) / 1024);
				$size_unit = "Kbytes";
			}

			print CATALOGUE $size . " " . $size_unit . " | ";
			print CATALOGUE $date->day().$date_postfix[$date->day()]. " " . $date->month_name() . ", " . $date->year();
			print CATALOGUE " | 26/32-bit neutral</p>\n\n";

			print INDEX $fields->{'Cat-Control'};
			print INDEX "Size: " . $fields->{'Size'} . "\n";
			print INDEX "MD5Sum: " . $fields->{'MD5Sum'} . "\n";
			print INDEX "URL: " . $fields->{'URL'} . "\n";
			print INDEX "\n\n";
		}
	}

	if (!%packages) {
		print CATALOGUE "<p><i>There are no packages in this repository.</i></p>\n\n";
	}

	my $date = ($newest_date != 0) ? DateTime->from_epoch(epoch => $newest_date) : DateTime->now();
	print CATALOGUE make_catalogue_footer($name, $date->day().$date_postfix[$date->day()]. " " . $date->month_name() . ", " . $date->year());

	close(CATALOGUE);
	close(INDEX);
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

sub make_html_block {
	my ($text) = @_;

	$text =~ s|\n|</p>\n\n<p>|g;
	return "<p>".$text."</p>\n";
}

sub make_catalogue_header {
	my ($name) = @_;

	return

"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">

<html>

<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">
<link rel=\"stylesheet\" type=\"text/css\" href=\"../../style/base.css\" media=\"screen\">
<title>RISC OS Software &ndash; Repositories &ndash; ".$name."</title>
</head>

<body bgcolor=\"#ffffff\" text=\"#000000\">
<div id=\"container\">
<div id=\"header\">
<h1>Repositories &ndash; ".$name."</h1>
</div>

<div id=\"content\">

<p class=\"breadcrumb\">[ <a href=\"../../\" class=\"breadcrumb\">Home</a>
| <a href=\"../\" class=\"breadcrumb\">RISC OS Software</a>
| <a href=\"index.html\" class=\"breadcrumb\">Repositories</a>
| <span class=\"breadcrumb-here\">".$name."</span> ]</p>

";
}

sub make_catalogue_path_info {
	my ($index) = @_;

	return

"<p>Although the software listed on this page can be manually downloaded in the
packages below, this is not recommended and the repository is better used by
including it into your package management software. To do this, add</p>

<blockquote><code>".$index."</code></blockquote>

<p>to the list of software sources.</p>

<p>If you would prefer to download and install your software manually &ndash;
and not via package management &ndash; then the better route is via the
stand-alone zip archives found via the <a href=\"../\">main software pages</a>.</p>

";
}

sub make_catalogue_footer {
	my ($name, $date) = @_;

	return

"<p class=\"breadcrumb\">[ <a href=\"../../\" class=\"breadcrumb\">Home</a>
| <a href=\"../\" class=\"breadcrumb\">RISC OS Software</a>
| <a href=\"index.html\" class=\"breadcrumb\">Repositories</a>
| <span class=\"breadcrumb-here\">".$name."</span> ]</p>

</div>

<div id=\"footer\">
<p><a href=\"http://validator.w3.org/check?uri=referer\"><img src=\"../../images/vh40.gif\" alt=\"Valid HTML 4.0!\" width=88 height=31 border=0></a>&nbsp;
<a href=\"http://www.riscos.com/\"><img src=\"../../images/roro4x.gif\" alt=\"RISC OS\" width=88 height=31 border=0></a>&nbsp;
<a href=\"http://www.anybrowser.org/campaign/\"><img src=\"../../images/any.gif\" alt=\"Best veiwed with Any Browser!\" width=81 height=31 border=0></a>&nbsp;
<a href=\"http://jigsaw.w3.org/css-validator/check/referer\"><img src=\"../../images/vcss.gif\" alt=\"Valid CSS!\" width=88 height=31 border=0></a></p>

<p>Page last updated ".$date." | Maintained by Steve Fryatt:
<a href=\"mailto:web\@stevefryatt.org.uk\">web\@stevefryatt.org.uk</a></p>
</div>
</div>
</body>
</html>
";
}
