#
# Uls2.pm  -  a perl module to generate value files to be processed by the ULS server
#
# ---------------------------------------------------------
# Copyright 2004-2021, roveda
#
# This file is part of the 'Oracle OpTools'.
#
# The 'Oracle OpTools' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The 'Oracle OpTools' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the 'Oracle OpTools'.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Description:
#
#   This script contains a number of functions that
#   are generally used in perl scripts to collect data
#   and generate one or more files in a directory which 
#   have the necessary format and location for further
#   processing by the ULS server.
#
#   The transmission of the directory contents is done by 
#   the external program 'flush_test_values'.
#   This module does not get or put any HTTP[S] requests.
#
# ---------------------------------------------------------
# Usage:
#
#   Create a Perl script which does your work. Use the Uls2.pm 
#   and its functions to set up and use ULS functionality in that
#   script.
#
#   Initialize the ULS module.
#
#   Use the supplied ULS functions with a simple parameter structure
#   or with a sophisticated hash as parameter (that allows a deeper 
#   control of the data contents).
#
#   Flush the data when finished (data is written in a specific format 
#   to a file). You must supply a temporary directory name, which is 
#   used to create a unique temporary directory where the file 
#   is placed.
#
#   If files (BLOBs, images) are to be transferred to the ULS, then 
#   these files are copied into the temporary directory.
#
#   Call the external program "flush_test_values" to pack the complete 
#   directory and transmit that data package to the ULS server.
#   The temporary directory is removed.
#
# ---------------------------------------------------------
# User Configuration:
#
#   The default ULS settings are read from the system's uls.conf
#   in /etc/uls/. Set environment variables or use parameters 
#   in the script's configuration file to overwrite these defaults.
#
#     # Location, where to find the uls.conf (/etc/uls/)
#     ULS_CONF=
#     
#     # ULS_FAKE = 0: generate value file and blob files in directory, transfer to ULS-Server
#     # ULS_FAKE = 1: generate value file and blob files in directory, no transfer
#     ULS_FAKE=0
#     # You must use $ULS_FAKE in uls_flush().
#     
#     # default ist: 
#     #   $TEMP/uls or $TMP/uls or LOKALER_TEST_PFAD from /etc/uls/uls.conf
#     ULS_DATA_CACHE=
#     
#     # default is ULSHOSTNAME from /etc/uls/uls.conf
#     ULS_HOSTNAME=
#     
#     # e.g. ULS_SECTION = Oracle DB [%%ORACLE_SID%%]
#     # default is "unknown"
#     ULS_SECTION=
#
#     # e.g. ULS_OUTPUT_ENCODING = latin1
#     # default is "latin1"
#     # the future will be "utf8"
#     ULS_OUTPUT_ENCODING=
#
#
# ---------------------------------------------------------
# Dependencies:
#
#   perl v5.8.0
#
#   Misc (self developped)
#
# ---------------------------------------------------------
# Installation:
#
#   Copy this file to a directory in @INC, e.g.:
#
#     Linux:   /usr/lib/perl5/site_perl[/<version>]
#     HP-UX:   /opt/perl/lib/site_perl
#     Windows: <LW>:\Perl\site\lib
#
#   or leave it in the installation directory of the the 'Oracle OpTools'.
#
# ---------------------------------------------------------
# Versions:
#
# 2008-11-03, 1.00, roveda:
#   Deriverd from Uls.pm 0.23
#   Most functions are kept as before, _init() and _flush() 
#   do only support the new hash-based parameter.
#
# 2008-11-13, 1.01, roveda:
#   Added "rename_to" for functions uls_image and uls_file.
#   Removed "use 5.8.0", because it throws warnings.
#
# 2009-02-02, 1.02, roveda:
#   Changed behavior in uls_settings() to 
#   default -> /etc/uls/uls.conf -> environment variables -> configuration file
#
# 2009-03-16, 1.03, roveda:
#   'source' does not work in all shells, now using '.'.
#   Make the call to "flush_test_values" configurable in the conf file.
#
# 2009-03-20, 1.04, roveda:
#   Minor changes concerning the determination of flush_test_values.
#
# 2010-01-22, 1.05, roveda:
#   Debugged "nodup with elapsed".
#
# 2011-11-11, 1.06, roveda:
#   Added the GPL.
#
# 2013-06-23, 1.10, roveda:
#   Added the encoding
#
# 2013-08-17, 1.11, roveda
#   Added support for the single configuration file in uls_settings()
#
# 2013-09-08, 1.12, roveda
#   Added 'keep_for' retention time in sub uls_server_doc().
#   Added current directory to look for own perl modules.
#
# 2014-01-14, 1.13, roveda
#   Changed uls_settings() to evaluate the new ULS configuration file 
#   entry ULS_TMP_PATH (previously: LOKALER_TEST_PFAD) correctly.
#
# 2014-05-06, 1.14, roveda
#   Now deriving the standard encoding for output files from environment variable LANG.
#
# 2016-02-11, 1.15, roveda
#   Checking first, if environment variable LANG exist before using it.
#   Reference to latest Misc.pm version updated.
#
# 2017-02-26, 1.16, roveda
#   Added more verbose output to copy_files() for better debugging.
#   Reference to Misc.pm version 0.40 updated.
#
# 2021-11-27, 1.17, roveda
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
#
#
# Change $VERSION later in the script!
#
# ================================================================

use strict;
use warnings;

# -----------------------------------------------------------------------------
# boilerplate from
# https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129

use warnings    qw< FATAL  utf8     >;
use open        qw< :std  :utf8     >;
use charnames   qw< :full >;
use feature     qw< unicode_strings >;

# use File::Basename      qw< basename >;
# use Carp                qw< carp croak confess cluck >;
use Encode              qw< encode decode >;
use Unicode::Normalize  qw< NFD NFC >;
# -----------------------------------------------------------------------------

# Yes, I am
package Uls2;

# This always throws a warning and clutters the mail
# use 5.8.0;

our(@ISA, @EXPORT, $VERSION);
require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(set_uls_hostname set_uls_section set_uls_timestamp uls_counter uls_doc uls_file uls_flush uls_get_last_values uls_image uls_init uls_nvalues uls_nvalues_nodup uls_nvalues_unique uls_send_file_contents uls_server_doc uls_show uls_settings uls_teststep_doc uls_timing uls_value uls_value_nodup uls_value_unique);

$VERSION = 1.17;

# ----------------------------------------------------------------
# Perl modules
use File::Basename;
use File::Copy;

# ----------------------------------------------------------------
# Miscellaneous module (self developped)
use lib ".";
use Misc 0.44;

# ----------------------------------------------------------------
# Path where the operating system uls settings are found

my $ETC_ULS_ULS_CONF = "/etc/uls/uls.conf";


# ----------------------------------------------------------------

my ($ULS_HOSTNAME, $ULS_SECTION, $ULS_DATE, $ULS_TIME, $ULS_OUTPUT_ENCODING);

# -----
# An array keeps all values, already in the uls_send_format.

my @VALUES;

# An array that keeps the complete pathnames of any additional 
# files that must be transferred to the uls server.

my @FILES;

# Contains the unique filenames for @FILES in the destination 
# directory. You know, files may have the same basename and they
# would overwrite each other. Giving each file a (temporary) 
# unique name will prevent that.
my @FILES2;

# Max length of values (7500 have been successfully sent) that
# can be sent to the ULS webserver. This specifies the raw length.
# Expressions are encoded AFTER the length check!
my $MAX_VALUE_LENGTH = 6500;
# my $MAX_VALUE_LENGTH = 32000;

# Print much output. You may reduce output with set_uls_verbose(0)
my $VERBOSE = 1;


# ------------------------------------------------------------
sub qu {
  #
  # qu(<expression>);
  #
  # escape all double quotes " => \"
  # wrap the <expression> in double quotes.

  my $expr = $_[0];

  if ($expr) {
    $expr =~ s/"/\\"/g;
  }

  return("\"$expr\"");

} # qu


# ------------------------------------------------------------
sub make_line {
  #
  # make_line(<expr1>, <expr2>, <expr3>, ...);
  #
  # Builds one string, each <expri> with escaped double quotes and 
  # enclosed in double quotes. Each expression is separated by a ';'.
  # The resulting string is returned.

  # Do not enclose the first two elements (shift shift).
  my $ret = shift;
  $ret .= ";" . shift;

  foreach my $e (@_) {
    $ret .= ";";

    my $E = qu($e);
    $ret .= $E;
  }

  return($ret);

} # make_line


# ------------------------------------------------------------
sub uls_settings {
  #   uls_settings(<ref to uls hash> [, <ref to config hash>]);
  #
  # Checks the contents of the optional <config hash> and the
  # current environment and builds entries in the <uls hash>.
  # The <uls hash> can be used as easy parameter for several
  # functions.
  #
  # #### default -> /etc/uls/uls.conf -> configuration file -> environment variables
  # Changed!
  # default -> /etc/uls/uls.conf -> environment variables -> configuration file

  my %Dummy;
  my ($cfg, $uls);

  if (ref($_[0]) eq "HASH") {
    $uls = $_[0];
  } else {
    print STDERR sub_name() . ": Error: You must supply a referenz to a hash as parameter!\n";
    return();
  }

  if ($_[1]) {
    if (ref($_[1]) eq "HASH") { 
      $cfg = $_[1] 
    } else {
      # Just to have a reference to an unused hash.
      $cfg = \%Dummy;
    }
  }

  # -----
  # ULS standard

  $$uls{timestamp} = iso_datetime();

  # -----
  # location of uls.conf (/etc/uls/uls.conf)

  $$uls{uls_conf} = $ETC_ULS_ULS_CONF;
  if (exists($ENV{"ULS_CONF"})) {$$uls{uls_conf} = $ENV{"ULS_CONF"}}
  if (exists($$cfg{"ULS_CONF"})) {$$uls{uls_conf} = $$cfg{"ULS_CONF"}}
  if (exists($$cfg{"ULS.ULS_CONF"})) {$$uls{uls_conf} = $$cfg{"ULS.ULS_CONF"}}
  $ETC_ULS_ULS_CONF = $$uls{uls_conf};

  # -----
  # fake
  #
  # fake = 0: call and execute the further processing of the generated files
  # fake = 1: just log the call of further processing to the script's log file.

  my $fake = 0;
  if (exists($ENV{"ULS_FAKE"})) {$fake = $ENV{"ULS_FAKE"}}
  if (exists($$cfg{"ULS_FAKE"})) {$fake = $$cfg{"ULS_FAKE"}}
  if (exists($$cfg{"ULS.ULS_FAKE"})) {$fake = $$cfg{"ULS.ULS_FAKE"}}
  $$uls{fake} = 0;
  if ($fake =~ /\d{1}/) { $$uls{fake} = $fake }

  # -----
  # data cache
  #
  # directory where to place the value and blob files.

  $$uls{data_cache} = ".";
  if (exists($ENV{TEMP})) {$$uls{data_cache} = $ENV{TEMP} . "/uls"}
  if (exists($ENV{TMP})) {$$uls{data_cache} = $ENV{TMP} . "/uls"}

  if (-r $ETC_ULS_ULS_CONF) {
    # LOKALER_TEST_PFAD=/tmp/uls
    my $c = ". $ETC_ULS_ULS_CONF; echo \$LOKALER_TEST_PFAD";
    my $ltp = `$c`;
    chomp($ltp);
    if ($ltp) {$$uls{data_cache} = $ltp}
  }

  if (-r $ETC_ULS_ULS_CONF) {
    # ULS_TMP_PATH=/var/tmp/uls
    my $c = ". $ETC_ULS_ULS_CONF; echo \$ULS_TMP_PATH";
    my $utp = `$c`;
    chomp($utp);
    if ($utp) {$$uls{data_cache} = $utp}
  }

  if (exists($ENV{"ULS_DATA_CACHE"})) {$$uls{data_cache} = $ENV{"ULS_DATA_CACHE"}}
  if (exists($$cfg{"ULS_DATA_CACHE"})) {$$uls{data_cache} = $$cfg{"ULS_DATA_CACHE"}}
  if (exists($$cfg{"ULS.ULS_DATA_CACHE"})) {$$uls{data_cache} = $$cfg{"ULS.ULS_DATA_CACHE"}}

  # -----
  # hostname
  #
  # hostname which is used in the ULS hierarchy. This may not 
  # necessarily be the actual name of the host, though.

  $$uls{hostname} = $ENV{"COMPUTERNAME"} || $ENV{"HOSTNAME"};
  if (-r $ETC_ULS_ULS_CONF) {
    # ULSHOSTNAME=`hostname`
    my $c = ". $ETC_ULS_ULS_CONF; echo \$ULSHOSTNAME";
    my $h = `$c`;
    chomp($h);
    if ($h) {$$uls{hostname} = $h}
  }
  if (exists($ENV{"ULS_HOSTNAME"})) {$$uls{hostname} = $ENV{"ULS_HOSTNAME"}}
  if (exists($$cfg{"ULS_HOSTNAME"})) {$$uls{hostname} = $$cfg{"ULS_HOSTNAME"}}
  if (exists($$cfg{"ULS.ULS_HOSTNAME"})) {$$uls{hostname} = $$cfg{"ULS.ULS_HOSTNAME"}}

  # -----
  # section
  #
  # section which is used in the ULS hierarchy.
  # This is mostly set in the configuration file for the calling script.

  $$uls{section} = "unknown";
  if (exists($ENV{"ULS_SECTION"})) {$$uls{section} = $ENV{"ULS_SECTION"}}
  if (exists($$cfg{"ULS_SECTION"})) {$$uls{section} = $$cfg{"ULS_SECTION"}}
  if (exists($$cfg{"ULS.ULS_SECTION"})) {$$uls{section} = $$cfg{"ULS.ULS_SECTION"}}

  # -----
  # output encoding
  # 
  # Encoding of the uls value file

  # default
  $$uls{output_encoding} = "latin1";

  # derived from current environment variable LANG
  if ( $ENV{LANG} ) {
    if ( $ENV{LANG} =~ /utf.*8/i) {
      $$uls{output_encoding} = "utf8";
    }
  }

  # special variable set in current environment
  if (exists($ENV{"ULS_OUTPUT_ENCODING"})) {$$uls{output_encoding} = $ENV{"ULS_OUTPUT_ENCODING"}}
  # special variable set in configuration file (old style)
  if (exists($$cfg{"ULS_OUTPUT_ENCODING"})) {$$uls{output_encoding} = $$cfg{"ULS_OUTPUT_ENCODING"}}
  # special variable set in configuration file (new style)
  if (exists($$cfg{"ULS.ULS_OUTPUT_ENCODING"})) {$$uls{output_encoding} = $$cfg{"ULS.ULS_OUTPUT_ENCODING"}}

  # -----
  # flush_test_values
  #

  # $$uls{"flush_test_values"} = "/usr/local/bin/flush_test_values __DIRECTORY__";
  # 2013-07-21, roveda: the path has changed. Assume by default that the PATH has been correctly set.
  $$uls{"flush_test_values"} = "flush_test_values __DIRECTORY__";
  if (exists($ENV{"ULS_FLUSH_TEST_VALUES"})) {$$uls{"flush_test_values"} = $ENV{"ULS_FLUSH_TEST_VALUES"}}
  if (exists($$cfg{"ULS_FLUSH_TEST_VALUES"})) {$$uls{"flush_test_values"} = $$cfg{"ULS_FLUSH_TEST_VALUES"}}
  if (exists($$cfg{"ULS.ULS_FLUSH_TEST_VALUES"})) {$$uls{"flush_test_values"} = $$cfg{"ULS.ULS_FLUSH_TEST_VALUES"}}


} # uls_settings



# ----------------------------------------------------------------
sub uls_init {
  #   uls_init(<hostname>, <section> [, <timestamp> [, <set_secs_to_zero>]]);
  #   uls_init("wscdbp22", "Informix", "2005-07-28 16:22:53", 1);
  # or
  #   uls_init({
  #      hostname  => "MyHostname"
  #    , section   => "MySection"
  #   [, timestamp => "2005-12-28 08:43:22" ]
  #   [, zero_secs => { 0 | 1 } ]
  #   [, output_encoding => { "latin1" | "utf8" } ]
  #   });
  #
  # or
  #
  #   uls_init(<ref to uls hash>);
  #
  # Initializes hostname, section and timestamp if given as
  # parameters. If no <timestamp> is given, it will use the
  # current date and time as the default timestamp for all values.
  #
  # zero_secs := set the seconds of the timestamp to zero ":00". 
  # That may sync the timestamps from different sources.
  #
  # output_encoding := the encoding of the output to the uls value file.
  #
  # NOTE: These settings are obviously NOT done in the 
  #       %ULS hash of the calling script.

  my ($h, $s, $t, $zs, $enc);

  $t = iso_datetime();
  $zs = 0;
  $enc = "latin1";

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $h = $$rH{hostname};
    $s = $$rH{section};
    if ($$rH{timestamp})       { $t = $$rH{timestamp} }
    if ($$rH{zero_secs})       { $zs = 1 }
    if ($$rH{output_encoding}) { $enc = $$rH{output_encoding} }
  } else {
    $h = $_[0];
    $s = $_[1];
    $t = $_[2] || iso_datetime();
    if ($_[3]) { $zs = 1 }
  }

  set_uls_hostname($h);
  set_uls_section($s);
  set_uls_timestamp($t, $zs);
  set_uls_output_encoding($enc);

  # Reset the arrays
  @VALUES = ();
  @FILES = ();
  @FILES2 = ();

} # uls_init


# ----------------------------------------------------------------
sub set_uls_hostname {
  #   set_uls_hostname(<hostname>)
  #
  # Sets the hostname (source of the data) that
  # will be used for the following data.
  #
  # NOTE: These settings are obviously NOT done in the
  #       %ULS hash of the calling script.


  $ULS_HOSTNAME = $_[0];
  return($ULS_HOSTNAME);
}

# ----------------------------------------------------------------
sub set_uls_section {
  #   set_uls_section(<section>)
  #
  # Sets the section to which the following data belongs.
  #
  # NOTE: These settings are obviously NOT done in the
  #       %ULS hash of the calling script.


  $ULS_SECTION = $_[0];
  return($ULS_SECTION);
}

# ----------------------------------------------------------------
sub set_uls_timestamp {
  #   set_uls_timestamp([<timestamp> [, <zero_secs>]]);
  #   set_uls_timestamp();
  #   set_uls_timestamp("2005-07-28 16:22:53", 1);
  #
  # This sets the default timestamp for the following data.
  # You may overwrite the timestamp for each call to the uls_*
  # functions.
  #
  # NOTE: These settings are obviously NOT done in the
  #       %ULS hash of the calling script.

  my $ts = $_[0] || iso_datetime();

  my $zs = 0;
  if ($_[1]) {$zs = 1}

  # Set the last two digits to zero
  if ($zs) { $ts =~ s/\d{2}$/00/ }

  ($ULS_DATE, $ULS_TIME) = split(/ /, $ts);

  return($ts);
}

# ----------------------------------------------------------------
sub set_uls_output_encoding {
  #   set_uls_timestamp(<encoding>);
  #
  # This sets the encoding for the resulting uls value file.
  # "latin1" or "utf8" are supported.

  my $enc = lc($_[0]);

  $ULS_OUTPUT_ENCODING = "latin1";

  if ($enc =~ /utf8|latin1/) {
    $ULS_OUTPUT_ENCODING = $enc;
  }

  return($ULS_OUTPUT_ENCODING);
} # set_uls_output_encoding


# ----------------------------------------------------------------
sub set_uls_verbose {
  #   set_uls_verbose({ 0 | 1});
  #
  # This sets the verbose mode on or off.

  my $v = $_[0];

  $VERBOSE = 1;
  if ($v == 0) {$VERBOSE = 0}

  return($VERBOSE);
} # set_uls_verbose


# ----------------------------------------------------------------
sub uls_value_nodup {
  #   uls_value_nodup(<teststep>, <detail>, <value> [, <unit> [, <timestamp>]]);
  # or
  #   uls_value_nodup({
  #     [  hostname  => "MyHostname" ]
  #     [, section   => "MySection" ]
  #     [, timestamp => "2005-12-28 08:43:22"]
  #        teststep  => "MyTeststep"
  #      , detail    => "MyDetail"
  #      , value     => "45.778"
  #     [, unit      => "MB"]
  #     [, elapsed   => "hhh:mm" ]
  #   });
  #
  # The current <value> is only saved to the ULS database, if the
  # previous <value> in the database is different, or <elapsed> has elapsed
  # since the entry of the last value.
  #

  my ($H, $S, $T, $D, $V, $U, $ts, $E);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"detail"};
    $V  = $$rH{"value"};
    $U  = $$rH{"unit"} || " ";
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

    $E = "";
    if ($$rH{"elapsed"}) { $E = $$rH{"elapsed"} }

  } else {

    $H  = $ULS_HOSTNAME;
    $S  = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
    $V = $_[2];
    $U = $_[3] || " ";
    $ts = $_[4] || "$ULS_DATE $ULS_TIME";
  }

  my %hV = (
      hostname   => $H
    , section    => $S
    , teststep   => $T
    , detail     => $D
    , value      => $V
    , unit       => $U
    , timestamp  => $ts
    , save_mode  => "nodup"
  );
  if ($E) {$hV{elapsed} = $E}

  uls_value(\%hV);

} # uls_value_nodup


# ----------------------------------------------------------------
sub uls_value_unique {
  #   uls_value_unique(<teststep>, <detail>, <value> [, <unit> [, <timestamp>]]);
  # or
  #   uls_value_unique({
  #     [  hostname  => "MyHostname" ]
  #     [, section   => "MySection" ]
  #     [, timestamp => "2005-12-28 08:43:22"]
  #        teststep  => "MyTeststep"
  #      , detail    => "MyDetail"
  #      , value     => "45.778"
  #     [, unit      => "MB"]
  #   });
  #
  # The <value> is only saved to the ULS database, if the <value> does not
  # already exist in the database for exactly the same timestamp.
  # This might be useful e.g.: list of all ip addresses that have
  # successfully connected to my server today, so the timestamp would be
  # YYYY-MM-DD 12:00:00 for all values that you send over the day.

  my ($H, $S, $T, $D, $V, $U, $ts);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"detail"};
    $V  = $$rH{"value"};
    $U  = $$rH{"unit"} || " ";
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

  } else {

    $H  = $ULS_HOSTNAME;
    $S  = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
    $V = $_[2];
    $U = $_[3] || " ";
    $ts = $_[4] || "$ULS_DATE $ULS_TIME";
  }

  my %hV = (
      hostname   => $H
    , section    => $S
    , teststep   => $T
    , detail     => $D
    , value      => $V
    , unit       => $U
    , timestamp  => $ts
    , save_mode  => "unique"
  );

  uls_value(\%hV);

} # uls_value_unique


# ----------------------------------------------------------------
sub uls_value {
  #   uls_value(<teststep>, <detail>, <value> [, <unit> [, <timestamp>]]);
  #
  #   this assumes the currently set values for hostname and section.
  #
  # or
  #   uls_value(<ref to hash>);
  #
  # where the hash may look like:
  #
  #   uls_value({
  #     [  hostname        => "MyHostname" ]
  #     [, section         => "MySection" ]
  #     [, timestamp       => "2008-10-28 08:43:22"]
  #      , teststep        => "MyTeststep"
  #      , detail          => "MyDetail"
  #      , value           => "AnyValue"
  #     [, unit            => "AnyUnit"]
  #     [, only_if_changed => { "Y[es]" | "N[o]" } ]
  #     [, save_mode       => {"NORMAL" | "NODUP" | "UNIQUE"}]
  #     [, elapsed         => "hhh:mm"]
  #   });
  #
  # Save a value to the ULS database.
  #
  #   |    Zeitstempel      | <detail> |
  #   |                     |  <unit>  |
  #   |---------------------|----------|
  #   |    <timestamp>      |  <value> |
  #
  # (Not all of the above combinations will make sense)
  #
  # The optional parameter <timestamp> can be used to overwrite the
  # iso_datetime that is set thru uls_init() or set_uls_timestamp().
  #
  # only_if_changed := If only_if_changed is set to "Y", then this value is only
  # saved to the ULS database, if the value has changed compared
  # to the last value found in the database. It is always saved,
  # if no previous value exists. (This is equivalent to NODUP).
  #
  # save_mode
  # NORMAL := save value always in database
  #
  # NODUP := no duplicates are saved to the database, if the
  # last value is equal to the current value. But if
  # <elapsed> has gone since the last and equal value,
  # the value is saved to the database nevertheless.
  #
  # UNIQUE := The current value is saved to the database, if there
  # is not already an equal value FOR THE SAME TIMESTAMP.
  #
  # elapsed := only used in conjunction with "save_mode = NODUP".
  # The value is saved to the database, if more than
  # <elapsed> has gone since the last saved value.
  # Format:  ...[h[h]]hh:mm


  # teststep, detail, value, unit, timestamp, save_mode, elapsed
  my ($H, $S, $T, $D, $V, $U, $ts, $SM, $E);

  $SM = "V";   # save_mode: normal Value | No duplicates | no duplicate value with Elapsed | Unique value
  $E = "";

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H          = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S          = $$rH{"section"} || $ULS_SECTION;
    $T          = $$rH{"teststep"};
    $D          = $$rH{"detail"};
    $V          = $$rH{"value"};
    $U          = $$rH{"unit"} || " ";
    $ts         = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

    if (exists($$rH{"only_if_changed"})) {
      if(uc(substr($$rH{"only_if_changed"}, 0, 1)) eq "Y") {$SM = "N"}
    }

    if (exists($$rH{"save_mode"})) {
      $SM = "V";
      if (uc($$rH{"save_mode"}) eq "NODUP") {$SM = "N"}
      if (uc($$rH{"save_mode"}) eq "UNIQUE") {$SM = "U"}
    }

    if ($SM eq "N") {
      # "elapsed" only in conjunction with "no duplicates"
      if ($$rH{"elapsed"}) {
        if ($$rH{"elapsed"} =~ /\d{1,4}:\d{2}/) {
          $E = $$rH{"elapsed"};
          $SM = "E";
        } else {
          print STDERR sub_name() . ": Error: Improper format for elapsed: '", $$rH{"elapsed"}, "', must be '[h[h]]hh:mm'.\n";
        }
      }
    }

  } else {

    $H = $ULS_HOSTNAME;
    $S = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
    $V = $_[2];
    $U = $_[3] || " ";
    $ts = $_[4] || "$ULS_DATE $ULS_TIME";
  }

  if (length($V) > $MAX_VALUE_LENGTH) {
    print sub_name() . ": Warning: length of value expression exceeds maximum => truncated!\n";
    $V = substr($V, 0, $MAX_VALUE_LENGTH - 1);
  }

  # The elapsed period follows directly the 'E', no ';'
  if ($SM eq "E") { $SM = "$SM$E" }

  # Build the line for the output to the destination file
  my $L = make_line($SM, $ts, $H, $S, $T, $D, $V, $U);
  if ($VERBOSE) {print "$L\n";}
  push(@VALUES, $L);

} # uls_value


# ----------------------------------------------------------------
sub uls_nvalues {
  #   uls_nvalues(<teststep>, <ref to array of detail:value:unit> [, <timestamp>]);
  #   uls_nvalues("Teststep", ["hangovers:4:#", "good friends:22:#", "money:0:Euro"]);
  #   uls_nvalues("Teststep", \@dvu_array, "2005-12-06 06:06:06");
  #
  #   uls_nvalues(<teststep>, [
  #       "detail1:value1:unit1"
  #     , "detail2:value2:unit2"
  #     , "detail3:value3:unit3"
  #   ]);
  # or
  #   uls_nvalues({
  #     [  hostname          => <hostname> ]
  #     [, section           => <section> ]
  #     [, timestamp         => <timestamp>]
  #      , teststep          => <teststep>
  #      , detail_value_unit => <ref to array of detail:value:unit>
  #     [, save_mode         => { "NORMAL" | "NODUP" | "UNIQUE" }]
  #     [, elapsed           => <elapsed>]
  #   });
  #
  # Several detail:value:unit tuples for the *same* teststep can be sent
  # in one call to the uls database server.
  # (see uls_value for a description of save_mode and elapsed)
  #
  # Remember NOT to use the ':' in any detail, value or unit except
  # for the field separation.
  # ':' is often found in timestamps!!!
  #
  # The optional parameter <timestamp> can be used to overwrite the
  # iso_datetime that is set thru uls_init() or set_uls_timestamp().
  #
  #   |    Zeitstempel      | <detail1> | <detail2> | <detail3> |
  #   |                     |  <unit1>  |  <unit2>  |  <unit3>  |
  #   |---------------------|-----------|-----------|-----------|
  #   |    <timestamp>      |  <value1> |  <value2> |  <value3> |

  my ($H, $S, $T, $W, $ts, $SM, $E);

  # save_mode: normal Value | No duplicates | no duplicate value with Elapsed | Unique value
  # normal | nodup | unique
  $SM = "normal";

  $E = "";

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H   = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S   = $$rH{"section"} || $ULS_SECTION;
    $T   = $$rH{"teststep"};
    $W   = $$rH{"detail_value_unit"};
    $ts  = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

    if (exists($$rH{"only_if_changed"})) {
      if(uc(substr($$rH{"only_if_changed"}, 0, 1)) eq "Y") {$SM = "nodup"}
    }

    $SM = $$rH{"save_mode"} || $SM;

    if ($SM eq "nodup") {
      # "elapsed" only in conjunction with "no duplicates"
      if ($$rH{"elapsed"}) {
        if ($$rH{"elapsed"} =~ /\d{1,4}:\d{2}/) {
          $E = $$rH{"elapsed"};
        } else {
          print STDERR sub_name() . ": Error: Improper format for elapsed: '", $$rH{"elapsed"}, "', must be '[h[h]]hh:mm'.\n";
        }
      }
    }

  } else {

    $H = $ULS_HOSTNAME;
    $S = $ULS_SECTION;
    $T = $_[0];
    $W = $_[1];
    $ts = $_[2] || "$ULS_DATE $ULS_TIME";
  }

  # Pattern for uls_value, rest is filled in foreach loop
  my %hV = (
      hostname   => $H
    , section    => $S
    , teststep   => $T
    , timestamp  => $ts
    , save_mode  => $SM
  );

  if ($E) {$hV{elapsed} = $E}

  # run over referenced array with detail:value:unit

  foreach my $w (@$W) {
    # Check number of elements
    my $c = 1 + ($w =~ s/:/:/g);   # replace ':' with ':', but returns the count of replacements.

    if ($c != 3) {
      print STDERR sub_name() . ": Error: '$w' must contain 3 expressions separated by ':', not $c.\n"
    } else {

      my ($d, $v, $u) = split(":", $w);

      # fill missing entries in value hash
      $hV{detail} = $d;
      $hV{value}  = $v;
      $hV{unit}   = $u;

      uls_value(\%hV);
    }

  } # foreach

} # uls_nvalues


# ----------------------------------------------------------------
sub uls_nvalues_nodup {
  #   uls_nvalues_nodup(<teststep>, <ref to array of detail:value:unit> [, <elapsed> [, <timestamp>]]);
  # or
  #   uls_nvalues({
  #        teststep          => <teststep>
  #      , detail_value_unit => <ref to array of detail:value:unit>
  #      , save_mode         => "NODUP"
  #     [, timestamp         => <timestamp>]
  #     [, elapsed           => <elapsed>]
  #   });
  #
  # Save all detail-value-unit combinations as nodup in the database.
  # See uls_value_nodup() for further information about the nodup feature.


  my %H;
  $H{teststep} = $_[0];
  $H{detail_value_unit} = $_[1];
  if ($_[2]) {$H{elapsed} = $_[2]}
  $H{timestamp} = $_[3] || "$ULS_DATE $ULS_TIME";
  $H{save_mode} = "NODUP";

  uls_nvalues(\%H);

} # uls_nvalues_nodup


# ----------------------------------------------------------------
sub uls_nvalues_unique {
  #   uls_nvalues_unique(<teststep>, <ref to array of detail:value:unit> [, <timestamp>]);
  # or
  # uls_nvalues({
  #        teststep          => "MyTeststep"
  #      , detail_value_unit => <ref to array of detail:value:unit>
  #      , save_mode         => "UNIQUE"
  #     [, timestamp         => "2005-12-28 08:43:22"]
  #   });
  #
  #
  # Save all detail-value-unit combinations as uniques in the database.
  # See uls_value_unique() for more information about the unique feature.

  my %H;
  $H{teststep}   = $_[0];
  $H{detail_value_unit} = $_[1];
  $H{timestamp} = $_[2] || "$ULS_DATE $ULS_TIME";
  $H{save_mode} = "UNIQUE";

  uls_nvalues(\%H);

} # uls_nvalues_unique



# ----------------------------------------------------------------
sub uls_counter {
  #   uls_counter(<teststep>, <detail>, <mode> [, <value> [, <timestamp>]]);
  # or
  #   uls_counter({
  #     [  hostname  => <hostname> ]
  #     [, section   => <section> ]
  #      , teststep  => <teststep>
  #      , detail    => <detail>
  #     [, mode      => { "inc" | "add" | "sub" | "dec" | "set" | "reset" }]
  #     [, value     => <value>]
  #     [, timestamp => <timestamp>]
  #   });
  #
  # The optional parameter <timestamp> can be used to overwrite the
  # iso_datetime that is set thru uls_init() or set_uls_timestamp().
  # <value> is set to 1 for "inc" and "dec".

  # teststep, detail, value, unit, timestamp
  my ($H, $S, $T, $D, $V, $M, $ts);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"detail"};
    $V  = 0;
    if ($$rH{"value"}) {$V  = pround($$rH{"value"}, 0)}
    $M  = $$rH{"mode"} || "inc";
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

  } else {

    $H = $ULS_HOSTNAME;
    $S = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
    $M = $_[2] || "inc";
    $V  = 0;
    if ($_[3]) {$V = pround($_[3], 0)}
    $ts = $_[4] || "$ULS_DATE $ULS_TIME";
  }

  $M = lc($M);

  # Check for allowed counting modes.
  my $MODE_LIST = "add,inc,sub,dec,set,reset";

  if ($MODE_LIST !~ /$M/) {
    print STDERR sub_name() . ": Error: Wrong mode '$M', must be one of '$MODE_LIST'.\n";
    return(0);
  }

  # Set value explicitly for the two modes
  if ("inc,dec," =~ /$M/) { $V = 1 }

  if (length($V) > $MAX_VALUE_LENGTH) {
    print sub_name() . ": Warning: length of value expression exceeds maximum => truncated!\n";
    $V = substr($V, 0, $MAX_VALUE_LENGTH - 1);
  }

  # Build the line for the output to the destination file
  # C;<datetime>;<hostname>;<section>;<teststep>;<detail>;[<mode>];[<value>][;<access>]

  my $L = make_line("C", $ts, $H, $S, $T, $D, $M, $V);
  if ($VERBOSE) {print "$L\n"}
  push(@VALUES, $L);

} # uls_counter



# ----------------------------------------------------------------
sub uls_teststep_doc {
  #
  # uls_teststep_doc(<teststep> <documentation string>);
  #
  # or 
  #
  # uls_teststep_doc({
  #      hostname      => <hostname>
  #    , section       => <section>
  #    , teststep      => <teststep>
  #    , documentation => <documentation string>
  #   });

  #
  # This is just an alias for the uls_doc() function.

  uls_doc(@_);

} # uls_teststep_doc



# ----------------------------------------------------------------
sub uls_doc {
  #
  # uls_doc(<teststep> <documentation string>);
  #
  # or
  #
  # uls_doc({
  #   [  hostname      => <hostname> ]
  #   [, section       => <section> ]
  #    , teststep      => <teststep>
  #    , documentation => <documentation string>
  #   });
  #
  # This saves a <documentation string> to an existing <teststep>.


  my ($H, $S, $T, $D);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"documentation"} || " ";

  } else {

    $H  = $ULS_HOSTNAME;
    $S  = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
  }

  # Documentation string may be around 8000 characters long,
  # apply the default max length.

  my $LEN = length($D);
  if ($LEN > $MAX_VALUE_LENGTH) {
    print sub_name() . ": Warning: length of documentation string ($LEN) exceeds maximum ($MAX_VALUE_LENGTH) => truncated!\n";
    $D = substr($D, 0, $MAX_VALUE_LENGTH - 1);
  }

  my $L = make_line("T", " ", $H, $S, $T, " ", $D);
  if ($VERBOSE) {print "$L\n"}

  push(@VALUES, $L);

} # uls_doc


# ----------------------------------------------------------------
sub uls_timing {
  #
  #   uls_timing(<teststep>, <detail>, {"START" | "STOP"} [, <timestamp>]);
  # or
  #   uls_timing({
  #     [  hostname  => <hostname> ]
  #     [, section   => <section> ]
  #     [, timestamp => <timestamp>]
  #      , teststep  => <teststep>
  #      , detail    => <detail>
  #      , {start    => <start_iso_datetime> | stop => <stop_iso_datetime>}
  #   });
  #
  # Send a member of "start-stop" time pairs to the ULS database. This may
  # enclose the execution of scripts or the duration of other actions.
  #
  # You must call this function once for the START and a second time
  # (with the same! <timestamp>) with STOP. By default, the current
  # datetime is used for <start_iso_datetime> or <stop_iso_datetime>
  # respectively.
  #
  #   |    Zeitstempel      |       <detail>       |
  #   |---------------------|----------------------|
  #   |    <timestamp>      | <start_iso_datetime> |
  #   |                     | <stop_iso_datetime>  |
  #
  #   |    Zeitstempel      |       start-stop     |
  #   |---------------------|----------------------|
  #   | 2006-11-27 09:23:12 |  2006-11-27 09:25:37 |
  #   |                     |  2006-11-27 10:44:51 |
  #
  # The optional parameter <timestamp> can be used to overwrite the
  # timestamp that is set thru uls_init() or set_uls_timestamp().
  #
  # If you want to use another start-stop time than the actual
  # date and time, then you must use the hash for all parameters.

  my ($H, $S, $T, $D,  $V, $ts, $start_stop);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H   = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S   = $$rH{"section"} || $ULS_SECTION;
    $T   = $$rH{"teststep"};
    $D   = $$rH{"detail"};
    $ts  = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";

    if (exists($$rH{"start"})) {
      $V          = "Start";
      $start_stop = $$rH{"start"} || iso_datetime();
    }
    if (exists($$rH{"stop"})) {
      $V          = "Stop";
      $start_stop = $$rH{"stop"} || iso_datetime();
    }

  } else {

    $H   = $ULS_HOSTNAME;
    $S   = $ULS_SECTION;
    $T = $_[0];
    $D = $_[1];
    $V = ucfirst(lc($_[2]));  # First letter uppercase, rest lowercase
    $ts = $_[3] || "$ULS_DATE $ULS_TIME";
    $start_stop = iso_datetime();
  }

  if ($V ne "Start" && $V ne "Stop") {
    print STDERR "uls_timing(): Wrong parameter '$V'. Usage: uls_timing(<teststep> <detail> {START | STOP} [, <timestamp>])\n";
    return(0);
  }

  my %hV = (
     hostname   => $H
    ,section    => $S
    ,teststep   => $T
    ,detail     => $D
    ,value      => $V . " $start_stop"
    ,unit       => "{T}"
    ,timestamp  => $ts
  );

  uls_value(\%hV);

} # uls_timing


# ------------------------------------------------------------
sub uls_send_file_contents  {
  #   uls_send_file_contents(<teststep>, <detail>, <filename> [, <timestamp>])
  # or
  #   uls_send_file_contents({
  #     [  hostname   => <hostname> ]
  #     [, section    => <section> ]
  #     [, timestamp  => <timestamp>]
  #      , teststep   => <teststep>
  #      , detail     => <detail>
  #      , filename   => <filename>
  #     [, start_line => <start_line>]
  #     [, stop_line  => <stop_line>]
  #     [, unit       => <unit>]
  #   });
  #
  # Sends the ascii contents of the given file as the value
  # for the <teststep> and <detail> and optional to <timestamp> to the uls.
  # You can send a part of the file if you specify <start_line> and/or
  # <stop_line>.

  my ($H, $S, $T, $D, $U, $filename, $ts);
  my $start_line = 0;
  my $stop_line  = 0;

  $U = " ";

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H          = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S          = $$rH{"section"} || $ULS_SECTION;
    $T          = $$rH{"teststep"};
    $D          = $$rH{"detail"};
    $filename   = $$rH{"filename"};
    $ts         = $$rH{"timestamp"}   || "$ULS_DATE $ULS_TIME";
    $start_line = $$rH{"start_line"}  || "0";
    $stop_line  = $$rH{"stop_line"}   || "0";
    $U          = $$rH{"unit"}        || " ";

    $start_line = int($start_line);
    $stop_line  = int($stop_line);

  } else {

    $H        = $ULS_HOSTNAME;
    $S        = $ULS_SECTION;
    $T        = $_[0];
    $D        = $_[1];
    $filename = $_[2];
    $ts = $_[3] || "$ULS_DATE $ULS_TIME";
  }

  if ($start_line) { print "Starting output at line: $start_line.\n" }
  else             { print "Starting output at beginning of file.\n" }

  if ($stop_line) { print "Stopping output at line: $stop_line.\n" }
  else            { print "Stopping output at end of file.\n" }

  if (! open(F, "<", $filename)) {
    print STDERR sub_name() . ": Error: Cannot open $filename for reading. $!\n";
    return(0);
  }

  my $txt = "----- $filename -----";
  if ($start_line != 0 and $stop_line != 0) {$txt = "----- $filename ($start_line-$stop_line) -----"}
  elsif ($start_line != 0)                  {$txt = "----- $filename ($start_line-) -----"}
  elsif ($stop_line != 0)                   {$txt = "----- $filename (-$stop_line) -----"}
  $txt .= "\n";

  my %hV = (
     hostname   => $H
    ,section    => $S
    ,teststep   => $T
    ,detail     => $D
    ,value      => ""
    ,unit       => $U
    ,timestamp  => $ts
  );

  my $L;       # line contents
  my $LC = 0;  # line count

  while($L = <F>) {
    $LC ++;
    if (($LC >= $start_line) and ($LC <= $stop_line or $stop_line == 0)) {
      chomp($L);

      if (length($txt . $L) > $MAX_VALUE_LENGTH) {
        print sub_name() . ": Length of file contents exceeds maximum => send in chunks!\n";
        $hV{value} = $txt;
        uls_value(\%hV);
        # print "length of text:", length($txt), " ", substr($txt, 1, 30), "\n";
        $txt = "";
      }

      $txt .= $L . "\n";
    }
  } # while

  $hV{value} = $txt . "----------";
  uls_value(\%hV);

  if (! close(F)) {
    print STDERR "uls_send_file_contents(): Error: Cannot close file handler for file $filename. $!\n";
    return(0);
  }

} # uls_send_file_contents


# ----------------------------------------------------------------
sub uls_server_doc {
  #   uls_server_doc(<filename>, <name>, <description>, [<iso_timestamp>])
  # or
  #   uls_server_doc({
  #    [  hostname    => <hostname> ]
  #       filename    => "/tmp/MySpecialFile.png"
  #    [, rename_to   => "my_other_name.png"]
  #     , name        => "MyName"
  #     , description => "This is my special server documentation"
  #     , timestamp   => "2006-01-11 10:16:22"
  #    [, keep_for    => 14 ]
  #   });
  #
  # Saves a file as server documentation for the currently defined ULS_HOSTNAME
  # or <hostname>. This can be found at:
  #
  # Hauptmenue -- Verwalten -- Dokumentation -- Serverdokumentation -- <verfahren> -- <server>
  #
  #   | Name   |    Datum    |     Beschreibung     |     Download      |
  #   |--------|-------------|----------------------|-------------------|
  #   | MyName |  2006-01-11 | This is my special   | MySpecialFile.png |
  #   |        |    10:16:22 | server documentation |                   |
  #   |--------|-------------|----------------------|-------------------|
  #   | <name> | <timestamp> |     <description>    |     <filename>    |
  #
  # NOTE: The file is transferred when uls_flush() is executed. It must still exist
  # then. A reference to the file is kept until it is really transferred.
  #
  # Use <rename_to> to rename the <filename> to something else. The basename 
  # of <filename> is the default:
  #
  #   | Name   |    Datum    |     Beschreibung     |     Download      |
  #   |--------|-------------|----------------------|-------------------|
  #   | MyName |  2006-01-11 | This is my special   | my_other_name.png |
  #   |        |    10:16:22 | server documentation |                   |
  #   |--------|-------------|----------------------|-------------------|
  #   | <name> | <timestamp> |     <description>    |    <rename_to>    |
  #
  # <keep_for> defines the number of days that this documentation shall be kept.
  # The ULS default retention time is 180 days.


  # filename, name, description, timestamp, hostname, rename_to, keep_for
  my ($F, $N, $D, $ts, $H, $rt, $k4);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"}   || $ULS_HOSTNAME;
    $F  = $$rH{"filename"};
    $N  = $$rH{"name"};
    $D  = $$rH{"description"};
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";
    $rt = $$rH{"rename_to"}  || $F;
    $k4 = $$rH{"keep_for"}   || " ";

  } else {

    $H  = $ULS_HOSTNAME;
    $F  = $_[0];
    $N  = $_[1];
    $D  = $_[2] || "";
    $ts = $_[3] || "$ULS_DATE $ULS_TIME";
    $rt = $F;
    $k4 = " ";
  }

  my $f = basename($F);
  if ($rt) {$f = basename($rt)}

  if (! $f) {
    print STDERR sub_name() . ": Error: '$F' is not a valid filename!\n";
    return(0);
  }

  my $pid = sprintf("%06d", $$);
  my $unique_f = $f . "_${pid}_" . random_expression(10);

  # S;<datetime>;<source>;<name>;<description>;<keep_for_no_of_days>;<local filename>;[<download>]

  my $L = make_line("S", $ts, $H, $N, $D, $k4, $unique_f, $f);
  if ($VERBOSE) {print "$L\n"}


  push(@VALUES, $L);
  push(@FILES, $F);
  push(@FILES2, $unique_f);

} # uls_server_doc


# ----------------------------------------------------------------
sub uls_image {
  #   uls_image(<teststep>, <detail>, <filename> [, <timestamp>]);
  # or
  #   uls_image({
  #     [  hostname   => <hostname> ]
  #     [  section    => <section> ]
  #     [, timestamp => "2007-02-14 13:16:45"]
  #        teststep  => "MyTeststep"
  #      , detail    => "MyDetail"
  #      , filename  => "/tmp/hello_world.jpg"
  #     [, rename_to => "my_other_name.jpg"]
  #   });
  #
  # Saves an image (as blob) as a value to a timestamp.
  # The image is directly shown as value in the detail table.
  #
  # NOTE: The file is transferred when uls_flush() is executed. It must still exist
  # then. A reference to the file is kept until it is really transferred.
  #
  # The <filename> is reduced to the basename of the file, leading
  # path information is removed.

  my ($H, $S, $T, $D, $F, $ts, $rt);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"detail"};
    $F  = $$rH{"filename"};
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";
    $rt = $$rH{"rename_to"} || $F;

  } else {

    $H = $ULS_HOSTNAME;
    $S = $ULS_SECTION;
    $T  = $_[0];
    $D  = $_[1];
    $F  = $_[2] || "";
    $ts = $_[3] || "$ULS_DATE $ULS_TIME";
    $rt = $F;
  }

  my $f = basename($F);
  if ($rt) {$f = basename($rt)}

  if (! $f) {
    print STDERR sub_name() . ": Error: '$F' is not a valid filename!\n";
    return(0);
  }

  my $pid = sprintf("%06d", $$);
  my $unique_f = $f . "_${pid}_" . random_expression(10);

  my $L = make_line("I", $ts, $H, $S, $T, $D, $unique_f, $f);
  if ($VERBOSE) {print "$L\n"}


  push(@VALUES, $L);
  push(@FILES, $F);
  push(@FILES2, $unique_f);

} # uls_image


# ----------------------------------------------------------------
sub uls_file {
  #   uls_file(<teststep>, <detail>, <filename> [, <timestamp>]);
  # or
  #   uls_file({
  #     [  hostname   => <hostname> ]
  #     [, section    => <section> ]
  #     [, timestamp => "2007-02-14 13:16:45"]
  #        teststep  => "MyTeststep"
  #      , detail    => "MyDetail"
  #      , filename  => "/tmp/RDA.zip"
  #     [, rename_to => "my_other_name.zip"]
  #   });
  #
  # Saves a file (as blob) as a value to a timestamp.
  # The file is shown as download link in the detail table.
  #
  # NOTE: The file is transferred when uls_flush() is executed. It must still exist
  # then. A reference to the file is kept until it is really transferred.
  #
  # The <filename> is reduced to the basename of the file, leading
  # path information is removed. If you specify "rename_to", then the 
  # file is renamed to that expression when transferred to the ULS.

  my ($H, $S, $T, $D, $F, $ts, $rt);

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $H  = $$rH{"hostname"} || $ULS_HOSTNAME;
    $S  = $$rH{"section"} || $ULS_SECTION;
    $T  = $$rH{"teststep"};
    $D  = $$rH{"detail"};
    $F  = $$rH{"filename"};
    $ts = $$rH{"timestamp"}  || "$ULS_DATE $ULS_TIME";
    $rt = $$rH{"rename_to"} || $F;

  } else {

    $H = $ULS_HOSTNAME;
    $S = $ULS_SECTION;
    $T  = $_[0];
    $D  = $_[1];
    $F  = $_[2] || "";
    $ts = $_[3] || "$ULS_DATE $ULS_TIME";
    $rt = $F;
  }

  my $f = basename($F);
  if ($rt) {$f = basename($rt)}

  if (! $f) {
    print STDERR sub_name() . ": Error: '$F' is not a valid filename!\n";
    return(0);
  }

  my $pid = sprintf("%06d", $$);
  my $unique_f = $f . "_${pid}_" . random_expression(10);

  my $L = make_line("F", $ts, $H, $S, $T, $D, $unique_f, $f);
  if ($VERBOSE) {print "$L\n"}


  push(@VALUES, $L);
  push(@FILES, $F);
  push(@FILES2, $unique_f);

} # uls_file


# ----------------------------------------------------------------
sub write_value_file {
  #
  # write_value_file(<directory>, <enc>);
  #
  # Walk over all value lines and write them to a '.uls' file in the directory.

  title(sub_name());

  my $directory = $_[0];
  my $enc = lc($_[1]);

  my $filename = "$directory/" . datetimestamp() . ".uls";

  # Note the reversed order in comparison for equalness! 
  # \Q just escapes any characters that would otherwise be treated as regular expression.

  if ("latin1" =~ /^\Q$enc/ ) {
    # LATIN1
    if (! open(OUT, ">", $filename)) {
      print STDERR sub_name() . ": Error: Cannot open '$filename' for writing!\n";
      return(0);
    }

  } elsif ("utf8" =~ /^\Q$enc/) {
    # UTF8
    if (! open(OUT, ">:utf8", $filename)) {
      print STDERR sub_name() . ": Error: Cannot open '$filename' for writing!\n";
      return(0);
    }

  } else {
     # not supported
     print STDERR sub_name() . ": Error: Encoding '$enc' is not supported!\n";
     return(0);
  }

  # Prepend the encoding to the array of value lines
  my $L = make_line("L", "", "", "", "", "", $enc, "", "");
  unshift(@VALUES, $L);

  # Walk over all value elements
  foreach my $V (@VALUES) { print OUT "$V\n" }

  # Close file
  if (! close(OUT)) {
    print STDERR sub_name() . ": Error: Cannot close '$filename'!\n";
    return(0);
  }

  print "Data has been written to file '$filename'.\n";

} # write_value_file


# ----------------------------------------------------------------
sub copy_files {
  #
  # copy_files(<directory>);
  #
  # Copy all referenced files to the <directory>.

  title(sub_name());

  my $directory = $_[0];

  # Remember: the full pathname of the file is in @FILES, 
  #           the temporary unique filename is in @FILES2

  foreach my $F (@FILES) {
    # my $bn = basename($F);
    my $bn = shift(@FILES2);
    my $f = "$directory/$bn";

    print "Copy file '$F' to '$f'.\n";

    # copy() from File::Copy
    my $success = copy($F, $f);
    if ($success) {
      print "File copy was successful.\n";
    } else {
      print STDERR sub_name() . ": Error: File copy was NOT successful: $!\n";
    }

    # Test, if file exists in destination directory
    if (! -e $f) {
      print STDERR sub_name() . ": Error: File '$F' was not copied to '$f' => file is lost.";
    }
  } # foreach

} # copy_files


# ----------------------------------------------------------------
sub process_all {
  #
  # process_all(<directory>, <do_transmit>, <flush_test_values>);
  #

  title(sub_name());

  my $directory = $_[0];
  my $do_transmit = $_[1];
  my $ftv = $_[2];

  my $command = "$ftv";
  $command =~ s/__DIRECTORY__/\"$directory\"/g;
  print "$command\n";

  if ($do_transmit) {
    my $t0 = time;

    system($command);
    my $ret = ($? >> 8);
    print "Done.\n";

    if ($ret != 0) {
      print STDERR sub_name() . ": Error: '$command' not successfully terminated: $! \n";
    }

    print "Transmission duration: ", time - $t0, "s\n";

  } else {
    print "Command '$command' was NOT executed.\n";
  }

} # process_all


# ----------------------------------------------------------------
sub uls_flush {
  #   uls_flush(<directory> [, <do_not_transmit>])
  # or
  #   uls_flush(<ref_to_uls_hash> [, <do_not_transmit>]);
  #
  # Flushes all data from the internal uls data array to a file in the <directory>
  # (or $uls{data_cache}) and copies all additional files to that <directory>.

  my ($directory, $do_transmit, $ftv, $enc);

  title(sub_name());

  $do_transmit = 1;

  # The command to transfer all data to the ULS-server
  # $ftv = "/usr/local/bin/flush_test_values __DIRECTORY__";
  # 2013-07-21, roveda: The path to the uls-client binaries has changed.
  $ftv = "flush_test_values __DIRECTORY__";

  if (ref($_[0]) eq "HASH") {
    my $rH = $_[0];
    $directory = $$rH{data_cache};
    if ($$rH{fake})              { $do_transmit = 0 }
    if ($$rH{flush_test_values}) { $ftv = $$rH{flush_test_values} }
    if ($$rH{output_encoding})   { $enc = $$rH{output_encoding}   }
  } else {
    $directory = $_[0];
  }

  if ($_[1]) {$do_transmit = 0}

  # Generate a unique directory, based on $directory
  # Write the VALUES to a file in that directory
  # Copy all referenced files into that directory
  # Initiate further processing of that directoy

  # -----
  # create directory

  my $pid = sprintf("%06d", $$);
  $directory = "$directory.$pid";

  print "Creating directory '$directory'.\n";
  mkdir($directory);
  if (! -d $directory) {
    print STDERR sub_name() . ": Error: Directory '$directory' could not be created correctly => all data is lost!\n";
    return(0);
  }

  write_value_file($directory, $enc);

  copy_files($directory);

  process_all($directory, $do_transmit, $ftv);

  # Reset the arrays
  @VALUES = ();
  @FILES = ();
  @FILES2 = ();

  return(1);

} # uls_flush


# ----------------------------------------------------------
sub uls_get_last_values {
  #   uls_get_last_values({
  #       uls           => { <http[s]>://<uls_server>:<port> | <ref to ULS hash> }
  #    [, application   => <application_pattern>]
  #    [, server        => <server_pattern>]
  #    [, section       => <section_pattern>]
  #    [, teststep      => <teststep_pattern>]
  #    [, detail        => <detail_pattern>]
  #    [, { time_period => <tp> | from_timestamp => <ti>, to_timestamp => <ti> } ]
  #   });
  #
  # Get the last values for a number of given pattern, optionally for a time range.
  # The IP of the requesting machine must be configured in the administration of
  # the ULS server.
  #
  # The function will return the response from the ULS server as string expression
  # or an undef if there is no response available.
  #
  # <time_period> has higher priority than <from/to_timestamp>
  #
  # <tp> := { 2std | heute | gestern | abgestern | woche | 7tage | letztewoche | abwoche | monat | letztermonat | jahr }
  #
  # <ti> := <iso_timestamp>
  #
  # A HTTP request may look like this:
  #    http://10.2.150.21:11975/get_last_values.s2w?verfahren=Aureg*&server=*
  #       &section=ProdS&teststep=status&details=Register-Server
  #       &dat=heute
  #       &von=2006-06-29%2000:00:00&bis=2006-06-30%2010:00:00
  #

#  title(sub_name());
#
#  my $GLV;
#
#  if (ref($_[0]) eq "HASH") {
#    $GLV = $_[0];
#  } else {
#    print STDERR sub_name() . ": Error: You must supply a hash as parameter!\n";
#    return(undef());
#  }
#
#  # -----
#  # Find the requested ULS server
#  my $uls = "";
#
#  if (ref($$GLV{uls}) eq "HASH") {
#    print "ULS specifications found in hash.\n";
#    my $rULS = $$GLV{uls};
#    $uls = "$$rULS{http_mode}://$$rULS{server}:$$rULS{port}";
#
#  } else {
#    print "Assuming directly given ULS specifications.\n";
#    $uls = $$GLV{uls};
#  }
#
#  # -----
#  # Build the url

#  my $p = "get_last_values.s2w";
#  $p .= "?verfahren=" . uri_escape($$GLV{application} || "*");
#  $p .= "&server="    . uri_escape($$GLV{server}      || "*");
#  $p .= "&section="   . uri_escape($$GLV{section}     || "*");
#  $p .= "&teststep="  . uri_escape($$GLV{teststep}    || "*");
#  $p .= "&details="   . uri_escape($$GLV{detail}      || "*");
#
#  if (exists($$GLV{time_period})) {
#    $p .= "&dat=" . uri_escape($$GLV{time_period});
#
#  } else {
#    if (exists($$GLV{from_timestamp}) && exists($$GLV{to_timestamp})) {
#      $p .= "&von=" . uri_escape($$GLV{from_timestamp});
#      $p .= "&bis=" . uri_escape($$GLV{to_timestamp});
#    }
#  }
#
#  my $url = "$uls/$p";
#
#  print "$url\n";
#
#  my $ua = LWP::UserAgent->new;
#  $ua->timeout(30);
#
#  # my $response = $ua->get($url, ':content_file' => '/tmp/get_last_values.txt');
#  my $response = $ua->get($url);
#
#  # print "Content:\n";
#  # print $response->content, "\n\n";
#
#  # print "as_string:\n";
#  # print $response->as_string, "\n\n";
#
#  print "Execution:\n";
#  if ($response->is_success) {
#    print "Successful\n";
#    return(1, $response->as_string);
#  }
#
#  print "Failed\n";
#  print STDERR $response->status_line, "\n";
#  return(0, $response->as_string);

} # uls_get_last_values


# -----
# True, if I get here when use'ed

1;

