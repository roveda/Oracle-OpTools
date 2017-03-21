#!/usr/bin/perl
#
# create_documentation.pl - create the documentation for these oracle-optools
#
# ---------------------------------------------------------
# Copyright 2017, roveda
#
# This file is part of Oracle OpTools.
#
# Oracle OpTools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Oracle OpTools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Oracle OpTools.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   perl create_documentation.pl  [output_file]
#
# ---------------------------------------------------------
# Description:
#   This script creates an html file that conatins the documentation 
#   for these oracle-optools. 
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Restrictions:
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   HtmlDocument.pm
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts on a test instance initially.
#
# ---------------------------------------------------------
# Versions:
#
# date            name        version
# ----------      ----------  -------
# 2017-02-10      roveda      0.01
#    THIS IS WORK IN PROGRESS
#
#    Change also $VERSION later in this script!
#
# ===================================================================


use strict;
use warnings;

# These are my modules:
use lib ".";
use Misc 0.40;
use HtmlDocument;

my $VERSION = 0.01;


# ===================================================================
# This keeps the complete report (as html)
my $OptoolsDoc = HtmlDocument->new();

$OptoolsDoc->set_style("
  table {
      border-collapse: collapse;
      border: 1px solid darkgrey;
      margin-top: 5px;
  }
  th, td {
      border: 1px solid darkgrey;
      padding: 5px;
  }
  th { background-color: #dbe4f0; }
  pre  {background-color: whitesmoke; }
");



# ===================================================================
# The subroutines
# ===================================================================



# -------------------------------------------------------------------
sub create_document {

  my $dt = iso_datetime();

  $OptoolsDoc->add_heading(1, "Oracle OpTools");
  $OptoolsDoc->add_paragraph('p', "Generated: $dt");

  $OptoolsDoc->set_local_anchor_list();

  $OptoolsDoc->add_paragraph('p', qq{
The Oracle OpTools are a GPLv3-based script collection for executing regular 
administrative jobs on Oracle database instances running on Unix-like operating systems.
} ) ;


# }) =~ s/^ {4}//mg;










  # my $aref = [
  #   "Instance name        ! $my_instance"
  # , "Oracle Version       ! $ORACLE_VERSION"
  # , "Database name        ! $my_database_name"
  # , "Database unique name ! " . trim(get_value($TMPOUT1, $DELIM, "DB_UNIQUE_NAME"))
  # , "DBID                 ! $dbid"
  # , "Database role        ! " . trim(get_value($TMPOUT1, $DELIM, "DATABASE_ROLE"))
  # , "Archive log mode     ! " . trim(get_value($TMPOUT1, $DELIM, "LOG_MODE"))
  # , "Flashback            ! " . trim(get_value($TMPOUT1, $DELIM, "FLASHBACK_ON"))
  # , "Dataguard status     ! " . trim(get_value($TMPOUT1, $DELIM, "GUARD_STATUS"))
  # , "Database created     ! $database_created"
  # , "Instance startup at  ! " . trim(get_value($TMPOUT1, $DELIM, "instance startup at"))
  # , "Running on host      ! $MY_HOST"
  # , "Listening on IP      ! $my_instance_ip"
 #  , "Host platform        ! " . trim(get_value($TMPOUT1, $DELIM, "platform"))
 #  ];

  # $OptoolsDoc->add_table($aref, "!", "LL", 0);

  # $OptoolsDoc->add_paragraph('p', "(*) NLS_LANG does not reflect the database settings! Just the setting of oracle's environment variable!");




  # $OptoolsDoc->add_heading(2, $title, "_default_");
  # $OptoolsDoc->add_paragraph('p', "Filename: $filename (This may be a temporary file name)");
  # $OptoolsDoc->add_paragraph('pre', $txt);
  # $OptoolsDoc->add_goto_top("top");
# 
} # create_document



# ===================================================================
# main
# ===================================================================

create_document();

print $OptoolsDoc->get_html(), "\n";


exit(0);

