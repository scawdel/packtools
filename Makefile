# Copyright 2010-2012, Stephen Fryatt
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

# This file really needs to be run by GNUMake.
# It is intended for native compilation on Linux (for use in a GCCSDK
# environment) or cross-compilation under the GCCSDK.

.PHONY: all clean documentation release install


# The build date.

BUILD_DATE := $(shell date "+%d %b %Y")
HELP_DATE := $(shell date "+%-d %B %Y")

# Construct version or revision information.

ifeq ($(VERSION),)
  RELEASE := $(shell svnversion --no-newline)
  VERSION := r$(RELEASE)
  RELEASE := $(subst :,-,$(RELEASE))
  HELP_VERSION := ----
else
  RELEASE := $(subst .,,$(VERSION))
  HELP_VERSION := $(VERSION)
endif

$(info Building with version $(VERSION) ($(RELEASE)) on date $(BUILD_DATE))

# The archive to assemble the release files in.  If $(RELEASE) is set, then the file can be given
# a standard version number suffix.

ZIPFILE := packtools$(RELEASE).zip
SRCZIPFILE := packtools$(RELEASE)src.zip
BUZIPFILE := packtools$(shell date "+%Y%m%d").zip


# Build Tools

MKDIR := mkdir
RM := rm -rf
CP := cp

ZIP := /home/steve/GCCSDK/env/bin/zip

SFBIN := /home/steve/GCCSDK/sfbin

TEXTMAN := $(SFBIN)/textman
STRONGMAN := $(SFBIN)/strongman
HTMLMAN := $(SFBIN)/htmlman
DDFMAN := $(SFBIN)/ddfman
BINDHELP := $(SFBIN)/bindhelp
TEXTMERGE := $(SFBIN)/textmerge
MENUGEN := $(SFBIN)/menugen


# Build Flags

ZIPFLAGS := -x "*/.svn/*" -r -, -9
SRCZIPFLAGS := -x "*/.svn/*" -r -9
BUZIPFLAGS := -x "*/.svn/*" -r -9
BINDHELPFLAGS := -f -r -v
MENUGENFLAGS := -d


# Set up the various build directories.

MANUAL := manual
OUTDIR := build
LICENCE := Licence,fff


# Set up the named target files.

README := ReadMe,fff
EXECUTABLES := buildrepo.pl,102, getpackagerev.pl,102
SUFFIX := .pl,102


# Set up the source files.

MANSRC := Source
MANSPR := ManSprite


# Build everything, but don't package it for release.

all: documentation


# Build the documentation

documentation: $(OUTDIR)/$(README)

$(OUTDIR)/$(README): $(MANUAL)/$(MANSRC)
	$(TEXTMAN) -I$(MANUAL)/$(MANSRC) -O$(OUTDIR)/$(README) -D'version=$(HELP_VERSION)' -D'date=$(HELP_DATE)'


# Build the release Zip file.

release: clean all
	$(RM) ../$(ZIPFILE)
	(cd $(OUTDIR) ; $(ZIP) $(ZIPFLAGS) ../../$(ZIPFILE) $(README) $(LICENCE) $(EXECUTABLES))
	$(RM) ../$(SRCZIPFILE)
	$(ZIP) $(SRCZIPFLAGS) ../$(SRCZIPFILE) $(OUTDIR) $(MANUAL) Makefile


# Build a backup Zip file

backup:
	$(RM) ../$(BUZIPFILE)
	$(ZIP) $(BUZIPFLAGS) ../$(BUZIPFILE) *


# Install the finished version in the GCCSDK, ready for use.  It's not a striaghtforward
# copy, as we need to strip the file extensions that are in build/ for the benefit
# of the RISC OS target.

install: clean all
	for f in $(EXECUTABLES); do $(CP) $(OUTDIR)/$$f $(SFBIN)/$${f%$(SUFFIX)}; done


# Clean targets

clean:
	$(RM) $(OUTDIR)/$(README)

