# 
# Misc.pm  -  a miscelleaneous perl library for the ORACLE_TOOLS
# 
# Description:
# 
#   This script contains a number of functions that
#   are generally used in (my) perl scripts.
# 
# ---------------------------------------------------------
# Copyright 2004-2017, roveda
#
# This file is part of the 'ULS Client for Oracle'.
#
# The 'ULS Client for Oracle' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The 'ULS Client for Oracle' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the 'ULS Client for Oracle'.  If not, see <http://www.gnu.org/licenses/>.
#
# 
# ---------------------------------------------------------
# Dependencies:
# 
#   perl v5.6.0
#   Time::Local
#   Config::IniFiles
# 
# ---------------------------------------------------------
# Installation:
# 
#   Copy this file to a directory in @INC, e.g.:
# 
#     Linux:   /usr/lib/perl5/site_perl
#     HP-UX:   /opt/perl/lib/site_perl
#     Windows: <LW>:\Perl\site\lib
# 
# ---------------------------------------------------------
# Versions:
# 
# 2004-04-15, 0.01, roveda:
# 2004-05-10, 0.02, roveda:
#   iso_datetime2secs() added, requires Time::Local.
# 
# 2004-05-12, 0.03, roveda:
#   Added datetimestamp().
# 
# 2004-05-13, 0.04, roveda:
#   Added informix_mode_text().
# 
# 2004-07-03, 0.05, roveda:
# 
# 2004-07-28, 0.06, roveda:
#   Added \Q in search expression in get_value(), special
#   characters are not evaluated (like '(', ')', ...).
# 
# 2004-08-23, 0.07, roveda:
#   Added config2hash().
# 
# 2004-08-25, 0.08, roveda:
#   Added doc2hash() and has_elapsed().
# 
# 2005-07-29, 0.10, roveda:
#   More than 5 logfiles can be versioned now.
#   Added sub_name(), Generalized the look of output messages.
# 
# 2005-09-06, 0.11, roveda:
#   Gives warning, when split fails in get_value_list()
#   and make_value_file(). Removed the "Info:" output.
# 
# 2005-11-25, 0.12, roveda:
#   Added scheduled().
# 
# 2006-02-16, 0.13, roveda:
#   Changed config2hash(), now allowing multiple lines for
#   parameters when enclosing text in "___".
# 
# 2006-02-24, 0.14, roveda:
#   Added hash2config().
# 
# 2006-04-20, 0.15, roveda:
#   Added get_config() which reads a configuration file and
#   applies any "%include" and resolves any environment variables.
# 
# 2006-05-10, 0.16, roveda:
#   config2hash() now interpretes only lines with leading '#' as
#   remarks and ignores them. '#' at any other place will be part
#   of the respective expression. Added function to_seconds().
# 
# 2006-08-31, 0.17, roveda:
#   Added pround() function.
# 
# 2007-03-13, 0.18, roveda:
#   Added docfile2hash(), changed doc2hash() to accept other title
#   indicators. show_hash() now has a bit more beautified output.
#   Added args2hash().
# 
# 2007-03-20, 0.19, roveda:
#   Added documentation. title() can now return the title to calling context.
#   Changed determination of default value iso_datetime, iso_datetime2secs.
#   datetimestamp may now have an optional parameter. args2hash can now
#   handle -option without any values.
# 
# 2007-05-21, 0.20, roveda:
#   make_value_file returns now 1, if a file with zeroed values
#   has been built.
# 
# 2007-06-18, 0.21, roveda:
#   More than one file may be specified for the %include parameter.
#   They are parsed in order of their appearance.
#
# 2007-06-27, 0.22, roveda:
#   The documentation of this module has been made pod like, except
#   the remarks in the sub headers. The complete documentation for
#   a perl script or module can now be produced with the help of the
#   docpl.pl script.
# 
# 2007-12-13, 0.23, roveda:
#   Reverted to old style documentation.
#
# 2008-02-08, 0.24, roveda:
#   Added changes to sub_name for usage in compiled scripts
#   (donated by staasst).
#
# 2008-11-06, 0.25, roveda:
#   Added random_expression().
#   Removed "use 5.6.0", because it throws warnings.
#   Added get_values_lines().
#
# 2010-01-05, 0.26, roveda:
#   Added min(), max(). Removed "delim" from get_value_lines()
#   and added the optional max number of lines to read in.
#   Added rtrim() and make_text_report().
#
# 2010-03-17, 0.27, roveda:
#   Added random_number()
#
# 2010-05-21, 0.28, roveda:
#   Changed pround(), multiplying by 1 on return, converts
#   the return value from string to number ('-0' problem).
#
# 2010-07-09, 0.29, roveda:
#   Added mintxt(), maxtxt() and sum().
# 
# 2012-09-24, 0.31, roveda:
#   Added fif() return matching line(s) from a file.
#
# 2013-08-18, 0.32, roveda:
#   Added get_config2()
#
# 2013-09-08, 0.33, roveda:
#   Added the replacement of §§expression§§ in get_config2()
#
# 2013-09-21, 0.34, roveda:
#   Added the replacement of [[expression]] in get_config2().
#   §§expression§§ still works but is deprecated, because 
#   it is a unicode character, which can sometimes be annoying.
#   Iteration of recursive replacements limited to 100.
#   Recursion of replacements in replacements in replacements... added.
#   §§expr§§ finally cancelled.
#
# 2014-11-23, 0.35, roveda:
#   Setting the hash keys of the doc to lowercase.
#
# 2016-02-23, 0.36, roveda:
#   Added exec_os_command().
#
# 2016-03-22, 0.37, roveda:
#   Made get_config2() ignore empty files (has no sections).
#
# 2016-03-23, 0.38, roveda:
#   Added optional parameter max_elapsed_hours to scheduled() 
#
# 2016-05-31, 0.39, roveda:
#   Added log10() and bytes2gb().
#
# 2016-07-06, 0.40, roveda:
#   Made bytes2gb() safe for negative or zero value arguments.
#
# 2017-06-25, 0.41, roveda:
#   And local_tz_offset() that returns the number of seconds between local 
#   time of current script envirionment and GMT.
#   Added tz() that returns the timezone as {+|-}hh:mm for a number of seconds.
#   Removed log10() as it is contained in POSIX.
#
# ============================================================

use strict;
use warnings;

# Yes, I am
package Misc;

# use 5.6.0;
use Time::Local;
use Config::IniFiles;
use POSIX;


our(@ISA, @EXPORT, $VERSION);
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(args2hash bytes2gb config2hash datetimestamp delta_value doc2hash docfile2hash exec_os_command fif get_config get_config2 get_value get_value_lines get_value_list has_elapsed hash2config informix_mode_text iso_datetime iso_datetime2secs local_tz_offset lockfile_build make_text_report make_value_file max maxtxt min mintxt move_logfile pround random_expression random_number rtrim scheduled show_hash sub_name sum title trim tz);

$VERSION = 0.41;

# This one is used as timestamp marker in work files.
my $TIMESTAMP_TXT = "T_I_M_E_S_T_A_M_P";

# Indicates multiple lines for configuration files.
# This is used in several functions
my $TEXT_BLOCK = "___";   # start/stop chars for multiple lines

# Special parameter/key in configuration files 
# to allow recursive parsing of configuration files.
my $INCLUDE = "%include";
my $INCLUDE_SEP = "%include_separator";

srand(time);

# ------------------------------------------------------------
sub trim {
  #
  #   trim(<expression>);
  #
  # Removes leading and trailing white spaces from the <expression>.

  my $s = $_[0];

  $s =~ s/^\s+//;
  $s =~ s/\s+$//;

  return($s);
} # trim


# ------------------------------------------------------------
sub rtrim {
  #
  #   rtrim(<expression>);
  #
  # Removes trailing white spaces from the <expression>.

  my $s = $_[0];

  $s =~ s/\s+$//;

  return($s);
} # rtrim


# ------------------------------------------------------------
sub max {
  # max(<list_of_numeric>);
  # returns the maximum value of a list.

  my $max = $_[0];
  ($max = ($max > $_ ? $max : $_)) for @_;

  return($max);
} # max


# ------------------------------------------------------------
sub min {
  # min(<list_of_numeric>);
  # returns the minimum value of a list.

  my $min = $_[0];
  ($min = ($min < $_ ? $min : $_)) for @_;

  return($min);
} # min


# ---------------------------------------------------------
sub sum {
  # sum(<list_of_numeric>);
  # returns the sum of all elements of the list.

  my $sum = 0;
  ($sum+=$_) for @_;

  return($sum);

} # sum


# ---------------------------------------------------------
sub mintxt {
  # mintxt(<list_of_text>);
  # returns the minimum value of a list containing text expressions

  # my $rA = $_[0];

  my $min = $_[0];
  ($min = ($min lt $_ ? $min : $_)) for @_;

  return($min);

} # mintxt


# ---------------------------------------------------------
sub maxtxt {
  # maxtxt(<list_of_text>);
  # returns the maximum value of a list containing text expressions

  my $max = $_[0];
  ($max = ($max gt $_ ? $max : $_)) for @_;

  return($max);

} # maxtxt


# ------------------------------------------------------------
sub pround {
  #
  #   pround(<value>, <power>);
  #
  #   pround(1234.5678, -2);
  #   =>  1234.57
  #   pround(123456789,  3);
  #   => 123457000
  #
  # Rounds the <value> to the number of significant
  # digits before or after the decimal point as given 
  # by <power>.
  #
  # It may still be necessary to format the number to your needs.

  my ($value, $power) = @_;
  # if (! $value) {return(undef)}

  my $result = $value;

  if ($power < -300 || $power > 300) {
    print STDERR sub_name() . ": Error: Cannot pround($value, $power): $power is too extreme!\n";
    # $result = undef;
  } else {
    my $f = 10 ** $power;

    if ($f > 0.0) {
      $result = sprintf("%0.0f", $value / $f) * $f;
    } else {
      print STDERR sub_name() . ": Error: Cannot pround($value, $power): division by zero!\n";
      # $result = undef;
    }
  }

  return($result * 1);

} # pround


# ------------------------------------------------------------
sub bytes2gb {

  my $x = shift;

  # Checking for small numbers. log10 does not work for zero or negative numbers.
  if ($x < 1E-3) { return(0) }
  # Remember: we are calculating GB, so anything less than 10 Bytes does not make sense anyway.

  my $l = sprintf("%0.3f", log10($x));
  # print "log10($x)=$l, int($l)=", int($l), "\n";

  my $fmt = "%0.0f";

  if ( $l < 12 ) {
    $fmt = "%0." . sprintf("%1d", 12-$l) . "f";
  }
  # print "fmt=$fmt\n";

  my $b = sprintf($fmt, $x / (1024 * 1024 * 1024));

  return($b);

} # bytes2gb



# ------------------------------------------------------------
sub random_expression {
  #
  # random_expression(<number of characters> [, <additional_chars>]);
  #
  # Generates an expression which contains <number of characters>
  # characters, randomly chosen from the upper case, lowercase and
  # number classes.
  # You may add <additional_chars> as a list of characters which
  # will be added to the choice to build the expression from.
  # NOTE: you must escape the dollar sign like '\$'!

  my $n = $_[0] || 0;
  my $ae = $_[1] || "";

  my $upper_c = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  my $lower_c = "Abcdefghijklmnopqrstuvwxyz";
  my $special = "_";
  my $numbers = "0123456789";

  my $all_c = "$upper_c$lower_c$special$numbers$ae";

  my $L = length($all_c);

  my $ret = "";

  foreach my $i (1..$n) {
    my $d = int(rand($L));
    my $c = substr($all_c, $d, 1);
    $ret .= $c;
  }

  return($ret);

} # random_expression


# ------------------------------------------------------------
sub random_number {
  # random_number([<multiplier>], [<offset>]);
  #
  # Remember: the base random number is [0 .. 0.99999]
  #           which is less than 1! So you will never
  #           get the <multiplier> as result (without
  #           regarding a possible <offset>).

  my $multiplier = 1;
  my $offset     = 0;

  if ($_[0]) {$multiplier = $_[0]}
  if ($_[1]) {$offset = $_[1]}

  return($offset + $multiplier * rand(1));

} # random_number




# ------------------------------------------------------------
sub iso_datetime {
  #
  #   iso_datetime([<secs_since_unix_big_bang>])
  #
  # Converts <secs_since_unix_big_bang> to an ISO 8601 like
  # expression in the format: YYYY-MM-DD hh:mm:ss
  # (The ISO separates the date from the time with a 'T', though)
  # If <secs_since_unix_big_bang> is not given, it will use 
  # the current date and time.

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

  my $ts = $_[0] || time;

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ts);
  # ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($ts);

  my $res = sprintf("%04d", $year + 1900) . "-";
  $res = $res . sprintf("%02d", $mon + 1) . "-";   # why must I add one?
  $res = $res . sprintf("%02d", $mday) . " ";
  $res = $res . sprintf("%02d", $hour) . ":";
  $res = $res . sprintf("%02d", $min) . ":";
  $res = $res . sprintf("%02d", $sec);

  # print "$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)\n";

  # 2004-03-15 10:45:32
  return($res);
} # iso_datetime


# ------------------------------------------------------------
sub iso_datetime2secs {
  #
  #   iso_datetime2secs(<timestamp>)
  #
  #   iso_datetime2secs("2004-05-13 10:03:42")
  #
  # Convert an ISO datetime expression (like "2004-05-13 10:03:42")
  # to the number of seconds since Jan 1, 1970.
  # This is helpful for calculations of timing deltas.

  my $p = $_[0] || iso_datetime();   # current timestamp is default

  $p =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/;

  # print "$1, $2, $3, $4, $5, $6\n";

  # timelocal requires Time::Local.
  my $secs = timelocal(int($6), int($5), int($4), int($3), int($2)-1, int($1)-1900);
  return($secs);
} # iso_datetime2secs


# ------------------------------------------------------------
sub datetimestamp {
  #
  #   datetimestamp([<secs_since_unix_big_bang>]);
  #
  # Returns a compact representation of the current
  # date and time like "20040512_143822".
  # That can be used e.g. in filenames.

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

  my $ts = $_[0] || time;

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ts);
  # ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($ts);

  my $res = sprintf("%04d", $year + 1900);
  $res = $res . sprintf("%02d", $mon + 1);
  $res = $res . sprintf("%02d", $mday) . "_";
  $res = $res . sprintf("%02d", $hour);
  $res = $res . sprintf("%02d", $min) ;
  $res = $res . sprintf("%02d", $sec);

  # print "$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)\n";

  # 20040512_143822
  return($res);
} # datetimestamp


# -----------------------------------------------
sub to_seconds {
  #
  #   to_seconds(<number with time unit>);
  # 
  # Returns the number of seconds for that expression.
  # "30s", "30secs", "30 seconds" mean 30 seconds => returns 30
  # "5m", "5 min", "5 Minutes" mean 5 minutes => returns 300 (5 * 60)
  #
  # time unit expressions: only the first char is evaluated, the rest 
  # is ignored.
  #
  #   's' for seconds,
  #   'm' for minutes,
  #   'h' for hours,
  #   'd' for days.

  my $expr = trim($_[0]);
  # a group of digits followed by a decimal point and followed by a group of digits, 
  # zero or many whitespaces
  # zero or many non-whitespace characters
  $expr  =~ /(\d*\.?\d*)\s*(\S*)/;
  
  my $figure    = $1;
  my $time_unit = uc(substr($2, 0, 1));

  my $result = 0;
  if    ($time_unit eq "S") {$result = $figure}
  elsif ($time_unit eq "M") {$result = $figure * 60}
  elsif ($time_unit eq "H") {$result = $figure * 60 * 60}
  elsif ($time_unit eq "D") {$result = $figure * 60 * 60 * 24}
  else {
    print STDERR sub_name() . "Error: cannot convert '$expr' to seconds.\n";
    $result = undef();
  }
  # print "result $expr = $result\n";

  return($result);

} # to_seconds


# ------------------------------------------------------------
sub sub_name {
  #
  #   sub_name()
  #
  # Returns the package name, and the complete path of the calling 
  # function names, except the name of this function (sub_name) itself.

  my $i = 1;    # if 0, then "sub_name" would appear also.
  my $t = "";

  while ( 1 ) {
    my $x = (caller($i))[3];
    last if not $x;

    my @context = split(/:/, $x);
    last if $#context < 2; # compiled scripts have '(eval)' as top level context
    $x = $context[2];

    if ($t) {$t = ".." . $t}
    $t = $x . $t;

    $i++;
  }

  return($t);
} # sub_name


# ------------------------------------------------------------
sub add_includes {
  #
  #   add_includes(<ref to hash>, <pipe separated include file list>, <file separator>);
  #
  # Parses the list of configuration files one after
  # another as given in the <pipe separated include file list>.
  # If another "%include" directive is found in a configuration
  # file, the function will continue to process those 
  # <pipe separated include file list> by calling itself recursively 
  # until all "%include" directives have been exhausted.

  my ($href, $include_list, $include_sep) = @_;

  my @files = split($include_sep, $include_list);
  @files = map(trim($_), @files);
  # print join(";", @files), "\n";

  foreach my $f (@files) {

    # my $f = $$href{$INCLUDE};
    # Get the additional configuration file contents into temp hash
    print "Read include configuration file '$f'.\n";
    my %H = %{config2hash($f)};
    if (! %H) {return(0)}

    # Remove existing %include
    # (the list of file to be included is saved in array @files)
    delete($$href{$INCLUDE});

    # Add the new entries or replace existing ones.
    # (There may also be a new %include)
    foreach my $k (keys(%H)) {
      $$href{$k} = $H{$k};
    } # foreach

    # Is an include parameter/key defined?
    if (exists($$href{$INCLUDE})) {
      my $inc_sep = $$href{$INCLUDE_SEP} || '\|';
      add_includes($href, $$href{$INCLUDE}, $inc_sep);
    }

  } # foreach

} # add_includes


# ------------------------------------------------------------
sub get_config {
  #
  #   get_config(<configfile>, <ref to hash>);
  #
  # Read a configuration file using the config2hash() function.
  # Then checks for an "%include" entry:
  #
  #   %include = <conf file>[[ | <conf file>] | <conf file>]...
  #
  # This has the special meaning to read the defined <conf file(s)>
  # on top of the current hash, replacing entries having the same 
  # keys by the new value. If the <conf file(s)> contains again an 
  # "%include" entry, that will be read on top of the current 
  # hash, replacing entries having the same ... and so on, 
  # recursively, without any depth restriction.
  # 
  # When the final hash is complete after having read all <conf file(s)>
  # and the possible "%include" files, placeholders are searched and 
  # replaced by homonymous environment variables. The placeholders 
  # must be enclosed in "%%", e.g.
  #
  #   key1 = my username is %%USER%%, on server %%HOSTNAME%%
  #
  # %%USER%% is replaced by the value of the environment variable $USER/%USER
  # %%HOSTNAME%% is replaced by the value of the environment variable $HOSTNAME
  # 
  # The final configuration entries are placed in the hash of the 
  # given reference when the function is called.

  my ($filename, $href) = @_;

  # -----
  # Get first conf file
  print "Read configuration file '$filename'.\n";
  %$href = %{config2hash($filename)};
  # Return, if hash is empty (normally: file not found).
  if (! %$href) {return(0)}

  # -----
  # Check for more conf files to be included
  if (exists($$href{$INCLUDE})) {
    my $inc_sep = $$href{$INCLUDE_SEP} || '\|';
    add_includes($href, $$href{$INCLUDE}, $inc_sep);
  }

  # -----
  # Replace placeholders with environment values
  # %%ANY%% will be replaced by the value of the environment
  # variable ANY, if it exists, else "__not_found__"

  my $C = "%%";
  my $NOT_FOUND = "__not_found__";

  foreach my $k (keys(%$href)) {
    my $v = $$href{$k};
    my $replaced = 0;

    if ($v) {
      while ($v =~ /$C(\w+)$C/) {

        $replaced = 1;
        my $e = $1;

        if (exists($ENV{$e})) {
          print "Replacing: '$C$e$C' with '" . $ENV{$e} . "' in '$k'.\n";
          $v =~ s/$C$e$C/$ENV{$e}/;
        } else {
          print "Replacing: '$C$e$C' with '$NOT_FOUND' in '$k'.\n";
          $v =~ s/$C$e$C/$NOT_FOUND/;
        }

      } # while
    }
    if ($replaced) {$$href{$k} = $v}
  } # foreach

  # Success
  return(1);

} # get_config


# ------------------------------------------------------------
sub get_config2 {
  #
  #   get_config2(<configfile>, <ref to hash>, <section1> [, <section2> [, <section3>...]]);
  #
  # New style configuration file in INI format.
  # Read in all parameters from all given <sections> and place it in 
  # the <ref to hash> as: $H{"section.parameter"} = value

  my $inifile = shift(@_);
  my $href = shift(@_);

  # Return value of this function, assume success.
  my $retval = 1;

  # my $ini = Config::IniFiles->new( -file => $inifile, -allowempty => 1 );
  # -allowempty is not available in my version of Config::IniFiles

  # Check if file is empty (better: has no sections)
  if (! fif($inifile, '^\[\S+\]') ) {
    print sub_name(), ": Info: '$inifile' does not contain any section => nothing read!\n";
    return($retval);
  }

  my $ini = Config::IniFiles->new( -file => $inifile );

  if (! $ini) {
    print STDERR sub_name(), ": Error: cannot open file '$inifile' for reading: $!\n";
    return(0) 
  }

  # Walk over all remaining parameters (=sections)
  foreach my $s (@_) {

    if ( $ini->SectionExists($s) ) {
      # Add all parameters from ini file to given hash ref
      foreach my $p ($ini->Parameters($s)) {

        my $made_replacements = 1;
        my $too_many_its = 1;

        # The value of the parameter in the current section.
        # Contains the resulting value after all replacements.
        my $v = $ini->val($s, $p);

        while ( $made_replacements ) {

          $made_replacements = 0;
          $too_many_its = 0;

          # Counter to restrict max iterations to 100.
          # There can be endless recursive replacements.
          my $i = 0;
          my $max_i = 100;
          # my $max_i = 10;

          # -----
          $i = 0;
          # replace %%xxxxxxxxx%% with ENV{xxxxxxxxx}
          # while ( $v =~ /(%%(.*?)%%)/ ) {
          while ( $v =~ /(%%\b(.*?)%%)/ ) {
            # $& the string that matched
            # $+ the substring that matched
            # print "Matched string: $&, matched substring: $+ \n";

            $i++;
            if ( $i > $max_i ) {
              $too_many_its = 1;
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Warning: max iterations of $max_i replacements reached for $& => aborted.\n";
              last;
            }

            my $o = $ENV{$+};
            if ($o) {
              chomp($o);
              # replace the %%expression%%
              print sub_name() . ": Replacing '$&' with '$o' in $s.$p.\n";
              # $v =~ s/(%%.*?%%)/$o/;
              $v =~ s/\Q$&/$o/;
              $made_replacements = 1;
            } else {
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Warning: Could not find environment variable '$+' => no replacement.\n";
              last;
            }
          } # while 

          # -----
          $i = 0;
          # eval expressions like `hostname` and replace that with its output
          while ( $v =~ /(`\b(.*?)`)/ ) {
            # $& the string that matched
            # $+ the substring that matched

            $i++;
            if ( $i > $max_i ) {
              $too_many_its = 1;
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Warning: max iterations of $max_i replacements reached for $& => aborted.\n";
              last;
            }

            my $o = `$+`;
            my $ret = ($? >> 8);
            if ($ret != 0) {
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Error: Could not execute os command '$+' successfully: $! \n";
              last;
            } else {
              chomp($o);
              # replace the `expression`
              print sub_name() . ": Replacing '$&' with '$o' in $s.$p.\n";
              # $v =~ s/(`.*?`)/$o/;
              $v =~ s/\Q$&/$o/;
              $made_replacements = 1;
            }
          } # while 

          # -----
          $i = 0;
          # replace references to other parameter values in same section
          # [[FIREINTHEHOLE]] will be replaced by the value of the
          # parameter FIREINTHEHOLE in the same(!) section.

          while ( $v =~ /(\[\[\b(.*?)\]\])/ ) {
            # $& the string that matched
            # $+ the substring that matched

            $i++;
            if ( $i > $max_i ) {
              $too_many_its = 1;
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Warning: max iterations of $max_i replacements reached for $& => aborted.\n";
              last;
            }
  
            my $o = $ini->val($s, $+);
            if ($o) {
              print sub_name() . ": Replacing '$&' with '$o' in $s.$p.\n";
              # replace the [[expression]]
              # $v =~ s/(\[\[\b.*?\]\])/$o/;
              # That does not work because of the [[]]!
              # $v =~ s/$&/$o/;
              # But that works
              $v =~ s/\Q$&/$o/;
              $made_replacements = 1;
            } else {
              $retval = 0;  # failure of this function
              print STDERR sub_name() . ": Warning: Could not find parameter '$+' in section '$s' of configuration file => no replacement.\n";
              last;
            }
          } # while 

          # If any of the replacements are found to be probably recursive, then exit!
          if ($too_many_its) {last}
        } # while replacements

        # Add the resulting value to the hash, 
        # $myhash{"section.parameter"} = value
        $$href{"$s.$p"} = $v;

      } # foreach p[arameter]
    # } else {
    #   print sub_name() . ": Info: section '$s' does not exist!\n";
    } # if section exists
  } # foreach s[ection]

  # Success if 1
  return($retval);

} # get_config2


# ------------------------------------------------------------
sub config2hash {
  #
  #   my %cfg = %{config2hash(<configfile>)};
  #
  # Reads the contents of a configuration file and puts
  # its value pairs into a hash and returns a reference
  # to that.
  #
  # Examples of what can be used within the conf file:
  #
  #   VARIABLE = VALUE
  #   VARIABLE=VALUE
  #   VARIABLE=VALUE1,value2,value3
  # 
  # May have text spanning several lines, when a trailing '>' is found.
  # 
  #   VARIABLE = text text text text text text text text>
  #   text text text text text text text text>
  #   text text text text text text text text
  #
  # May have text spanning several lines, when starting and ending 
  # with "___" (that are 3 underscores '_').
  #
  #   VAR = ___
  #   kajfkjfhb vkjhf kkhf vkh kfkvh
  #   alkejvnphkn ajbfkls fgbdlkh n
  #   ___
  # 

  my $CONT_CHAR  = ">";     # continuation char at the end of each line

  my $cfgfile = $_[0];
  my %cfg;

  my $Line;
  my $CompleteLine = "";

  my $continue = 0;   # is 1, if line should be continued.
  my $in_text_block = 0;  # is 1, if currently within text block.

  my ($var, $value);

  if (open(CFG, $cfgfile)) {
    while($Line = <CFG>) {
      chomp($Line);         # no newline
      $Line =~ s/^\s*#.*//;     # no comments

      $continue = 0;

      # Test for continuation char '>'
      # my $last_c = substr($Line, 0, -1);
      # if ($last_c eq $CONT_CHAR) {
      if ($Line =~ /$CONT_CHAR$/) {
        $continue = 1;
        substr($Line, length($Line)-1, 1, "");
      }

      # Test for TEXT_BLOCK
      # If the last characters equates to TEXT_BLOCK_START
      if ($Line =~ /^\s*$TEXT_BLOCK\s*$/) {
        # Only TEXT_BLOCK in the line, ignoring white spaces.
        # TEXT_BLOCK is terminated.
        $in_text_block = 0;
        $Line = "";
      } elsif ($Line =~ /.+=\s*$TEXT_BLOCK\s*$/) {
        # any char, a '=', white spaces, at the end of the line, 
        $in_text_block = 1;
        # Remove all chars following the '='.
        $Line =~ s/=.*/=/;
      }
      # Keep $continue activated until TEXT_BLOCK has ended.
      if ($in_text_block) {$continue = 1}

      # print "'$last_c', $continue\n";
      $CompleteLine .= $Line;
      if ($continue) {if ($CompleteLine) {$CompleteLine .= "$/"}}

      if (! $continue) {
        $CompleteLine =~ s/^\s+//;    # no leading white
        $CompleteLine =~ s/\s+$//;    # no trailing white
        next unless length($CompleteLine);
        ($var, $value) = split(/\s*=\s*/, $CompleteLine, 2);
        $cfg{$var} = $value;
        $CompleteLine = "";
      }
    } # while
    close(CFG);
  } else {
    print STDERR sub_name() . "Error: Cannot open file '$cfgfile'.\n";
    # return(undef());
  }

  return(\%cfg);

} # config2hash


# ------------------------------------------------------------
sub hash2config {
  #
  #   hash2config(<filename>, <ref to hash>);
  #
  # Writes the contents of the hash to a file, 
  # in the same structure as the config2hash reads it, 

  my ($filename, $href) = @_;

  if (! open(CFG, ">", $filename)) {
    print STDERR sub_name() . "Error: Cannot open file '$filename' for writing. $!\n";
    return(undef());
  }
  print "Opened file '$filename' for writing.\n";

  print CFG "# filename   : ", $filename, "\n";
  print CFG "# last change: ", iso_datetime(), "\n";
  print CFG "# changed by : ", sub_name(), "\n";
  print CFG "\n";
  print CFG "\n";
  foreach my $k (sort(keys(%$href))) {
    if ($$href{$k} =~ /\r|\n/) {
      # If the value contains new lines then use multiple line syntax.
      print CFG "$k = $TEXT_BLOCK\n";
      print CFG $$href{$k}, "\n";
      print CFG "$TEXT_BLOCK\n";
    } else {
      print CFG "$k = ", $$href{$k}, "\n";
    }
    print CFG "\n";
  } # foreach

  if (! close(CFG)) {
    print STDERR sub_name() . "Error: Cannot close filehandle for file '$filename'. $!\n";
    return(undef());
  }
  print "Closed filehandle for file '$filename'.\n";

  return(1);

} # hash2config


# ------------------------------------------------------------
sub args2hash {
  #
  #   args2hash(<ref to hash>, <array or list>);
  # 
  # Takes the array or list and adds elements to the hash
  # <ref to hash> is pointing to. The following rules apply
  # (by example):
  #
  #   perl program.pl arg1 -v=123.4567 -5="Hello Dolly" --verbose=true ----help
  #
  # Will build a hash that looks like:
  #
  #   "1" => arg1
  #   "v" => 123.4567
  #   "5" => Hello Dolly
  #   "verbose" => true
  #   "help" => 1
  #
  # The number of leading '-' is ignored, all are removed before it becomes the hash key.
  # The expression following the '=' becomes the value of the corresponding hash key.
  # If neither a '-' nor a '=' is found in an argument, it becomes the value of the
  # hash key with the position number of the argument.
  # If only leading '-' are found, but no '=', the hash key is set, but without 
  # any value.

  my $href = shift(@_);

  # Counter for not qualified parameters (without -xyz=)
  # Note: This could conflict with a parameter at another position, e.g. -4=xxxx

  my $i = 1;

  foreach my $p (@_) {
    if ($p =~ /=/) {
      # split into max 2 expressions (= at first '=')
      my ($opt, $value) = split(/=/, $p, 2);
      # remove the leftmost minus signs
      $opt =~ s/^-+//;
      $$href{$opt} = $value;

    } else {

      if ($p =~ /^-/) {
        # -option without any value
        my $opt = $p;
        $opt =~ s/^-+//;
        $$href{$opt} = 1;

      } else {
        # Use a number
        $$href{$i} = $p;
      }
    }

    $i++;
  }

} # args2hash


# ------------------------------------------------------------
sub doc2hash {
  #
  #   doc2hash(<reference to filehandle> [, <title indicator>])
  #
  # Example of how to use this function with the internal filehandle
  # that starts at __END__ in the main script:
  #
  #   %DOC = %{doc2hash(\*DATA)};
  #
  # Reads all lines from the <filehandle> (often <DATA> in main script)
  # and puts this documentation into a hash, the title is the key,
  # the text is the value of the hash element.
  #
  # <reference to filehandle> references a hash, which will contain the 
  # the documentation.

  # <title indicator> is '*' by default and indicates the character
  # that identifies the line with the title. This line (except the 
  # <title indicator>, will become a hash key of %DOC. The following 
  # lines until the next <title indicator> or until the end of the file
  # will become the hash key's value.
  #
  # Format of the file contents:
  #
  #   *<title>
  #   blahblahblah
  #   any text any text any text any text any text any text any text any text
  #   any text any text any text any text any text any text any text any text
  #   any text any text any text any text any text any text any text any text
  #   ...
  #   #<remark within the documentation, this line is ignored>
  #   *<another title>
  #   any text any text any text any text any text any text any text any text
  #   any text any text any text any text any text any text any text any text
  #
  # $DOC{"<title>"} then contains the text "blahblahblah" and the following
  # lines. Newlines are kept.
  #
  # You may e.g. use uls_send_doc() to send this documentation to the 
  # appropriate teststep in the ULS if you provide a matching (to the 
  # used teststeps) documentation.

  my $FH = $_[0];
  my $ti = $_[1] || '*';

  my %doc;         # keeps the title/text pairs
  my $title = "";  # title
  my $txt   = "";  # documentation text
  my $L;           # line read in from <filehandle>

  while ($L = <$FH>) {
    my $T = $L;  # check for new title
    chomp($T);
    my $first = substr($T, 0, 1);  # It must really be the first character!

    if ($first eq $ti) {
      # This is a title!
      # Check for previous title and message.
      if ($title ne "" and $txt ne "") {
        # Put the pair into the hash
        $doc{lc($title)} = $txt;
      }

      # Start new title and message.
      $L = substr($L, 1);
      $T = substr($T, 1);
      $title = $T;
      $txt   = $L;

    } elsif ($first eq '#') {
      # A remark, skip this line
      next;

    } else {
      # Simple text, append it to the text
      $txt .= $L;
    }
  } # while

  # Don't forget the last piece of documentation
  if ($title ne "" and $txt ne "") {
    $doc{lc($title)} = $txt;
  }

  # return a reference
  print "Documentation loaded into hash.\n";
  return(\%doc);

} # doc2hash


# ------------------------------------------------------------
sub docfile2hash {
  #
  #   docfile2hash(<docfile>, <ref to hash> [, <title indicator>]);
  #
  #   docfile2hash(\*DATA, \%G, "+");
  #   docfile2hash("my_filename.txt", \%G, "+");
  #
  # <docfile> := the name of the file containing the documentation
  # 
  # <docfile> (as filehandle) := the filehandle pointing to the file
  # that contains the documentation
  #
  # <ref to hash> := reference to a hash, that is filled with the documentation
  # 
  # <title indicator> := first character on a line, that indicates the title
  # line of the documentation section. The rest of the lines becomes a key in the hash.
  #
  # see also doc2hash()
  # 
  # Example:
  #
  # Contents of file "my_filename.txt":
  #
  #   *title1
  #   more lines
  #   *title2
  #   even more lines
  #   much more lines
  #
  # Script:
  #
  #   docfile2hash("my_filename.txt", \%H, "*");
  # 
  # Hash contents:
  #
  #   $H{"title1"} => "more lines"
  #   $H{"title2"} => "even more lines\nmuch more lines"


  my $f    = $_[0];
  my $href = $_[1];
  my $ti   = $_[2];

  # print "f=$f,", ref($f), ", href=$href,", ref($href), "\n";

  # This is GLOB for filehandles if you call this function like:
  #   docfile2hash(\*DATA, \%G);
  # (which refers to the skript internal __DATA__ section

  # Distinguish filehandle and filename.
  my $is_filehandle = (ref($f) eq "GLOB" ? 1 : 0);

  # print ref($f), ", $is_filehandle\n";

  my $fh;

  if ($is_filehandle) {
    $fh = $f;
  } else {
    # ordinary filename
    if (! open(F, "<", $f)) {
      print STDERR sub_name() . ": Error: Cannot open file '$f':$!\n";
      return(0);
    }
    $fh = \*F;
  }

  %$href = %{doc2hash($fh, $ti)};

  if (! $is_filehandle) {
    if (! close(F)) {
      print STDERR sub_name() . ": Error: Cannot close file '$f':$!\n";
      return(0);
    }
  }

  # Return, if hash is empty (normally: file not found).
  if (! %$href) {return(0)}

  return(1);
} # docfile2hash



# ------------------------------------------------------------
sub exec_os_command {
  # exec_os_command(command);
  # 
  # Executes the os system command, without catching the output.
  # It returns 1 on success, undef in any error has occurred.
  # Error messages are printed to STDERR.

  my $cmd = shift;

  if ($cmd) {

    system($cmd);
    my $xval = $?;

    if ($xval == -1) {
      # <cmd> may not be available
      print STDERR sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!\n";
      return(undef);
    }
    elsif ($xval & 127) {
      print STDERR sub_name() . ": ERROR: child died with signal ', $xval & 127, ', coredump: ", ($? & 128) ? 'yes' : 'no', "\n";
      return(undef);
    }
    elsif ($xval != 0) {
      print STDERR sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!\n";
      return(undef);
    }
    else {
      # OK, proper execution
      # print "Command '$cmd' exited with value ", $xval >> 8, "\n";
      return(1);
    }
  } else {
    print STDERR sub_name() . ": ERROR: no command given as parameter!\n";
  }

  return(undef);

} # exec_os_command



# ------------------------------------------------------------
sub title {
  #
  #   title <expression list>
  #
  # Builds a head line that looks like:
  #
  #   -----[ Hello World ]----------- ... --[ 2004-03-15 10:45:32 ]-
  #
  # and prints it to stdout, or if it is used in an
  # assignment it returns the resulting expression.

  my $t;

  if (@_) {
    $t = "--[ " . trim(join(" ", @_));
    $t = sprintf("%.53s", $t);
    $t = $t . " ]";
  }

  $t = $t . "-" x 80;
  $t = sprintf("%.56s", $t);
  $t = $t . "[ " . iso_datetime() . " ]-";

  # -----[ Hello World ]------------------ ... --[ 2004-03-15 10:45:32 ]--

  if (defined(wantarray)) {
    # A return value is expected.
    return($t);
  } else {
    # wantarray is undef => print to STDOUT
    print "\n$t\n";
  }

} # title


# -------------------------------------------------------------------
sub move_logfile {
  #
  #   move_logfile(<logfile> [, <keep versions>])
  #
  # Move existing logfiles to next versions.
  # Files matching the <logfile>.I (where I is a 
  # number from 0 to <keep versions>-1) are moved
  # to <logfile>.J (with J = I + 1). The oldest version 
  # is overwritten.

  my $f = "$_[0]";
  my $versions = $_[1] || 5;

  title("Re-versioning file $f");

  my $c = 0;
  my $i = 0;

  for ($i = $versions-1; $i >= 1; $i--) {
    my $f1 = sprintf("%s.%d", $f, $i-1);
    my $f2 = sprintf("%s.%d", $f, $i);
    if (-e $f1) {
      print "Rename '$f1' to '$f2';\n";
      $c += rename("$f1", "$f2");
    }
  }
  if (-e $f) {
    print "Rename '$f' to '$f.0';\n";
    $c += rename("$f", "$f.0");
  }
  print "$c files renamed.\n";
} # move_logfile


# ----------------------------------------------------------------
sub has_elapsed {
  #
  #   has_elapsed(<filename>, <seconds>)
  #
  # If more than the number of seconds have elapsed since the
  # timestamp saved in the filename, it returns true and
  # updates the timestamp in the file.

  my $ret = 0;   # the requested number of second have not elapsed.
  my $last_timestamp;
  my $curr_timestamp = time;

  my ($timefile, $seconds) = @_;

  if (-e $timefile) {
    print "'$timefile' does exist.\n";
  } else {
    # file does not exist, build the file.
    print "'$timefile' does not exist. Create it.\n";
    if (open(TIMEFILE, "> $timefile")) {
      print TIMEFILE "0\n";
      close(TIMEFILE);
      print "'$timefile' created.\n";
    } else {
      print STDERR sub_name(), ": Error: cannot open new file '$timefile' for writing: $!\n";
      return($ret);
      # This is fatal, do not continue.
    }
  }

  print "Opening file '$timefile'.\n";

  if (open(TIMEFILE, $timefile)) {
    $last_timestamp = <TIMEFILE>;
    close(TIMEFILE);
    chomp($last_timestamp);
    $last_timestamp = int($last_timestamp);
    my $delta_secs = $curr_timestamp - $last_timestamp;
    if ($delta_secs >= $seconds) {
      # Yes, more than <seconds> have elapsed.
      print "More than $seconds seconds ($delta_secs) have elapsed since last timestamp change.\n";

      # Now write the current timestamp to the file.
      print "Write the current timestamp to '$timefile'.\n";
      if (open(TIMEFILE, "> $timefile")) {
        print TIMEFILE "$curr_timestamp\n";
        close(TIMEFILE);
        $ret = 1;
      } else {
        print STDERR sub_name(), ": Error: cannot open file '$timefile' for writing: $!\n";
      }
    } else {
      print "Less than $seconds seconds ($delta_secs) have elapsed since last timestamp change.\n";
    }
  } else {
    print STDERR sub_name(), ": Error: cannot open file '$timefile' for reading: $!\n";
  }

  return($ret);

} # has_elapsed


# ----------------------------------------------------------------
sub scheduled {
  #
  #   scheduled(<file>, <schedule time list> [, <compare time> [, <max_hours_elapsed>]])
  #
  # Example:
  # 
  #   scheduled("_my_project.last_hhmm", "08:00 09:00 10:00", "09:37", 18)
  #
  # If the hh:mm saved in the <file> is less than one of the <schedule time list> 
  # AND the <compare time> is greater than that one element of 
  # <schedule time list>, then this function returns 1, else it returns 0. 
  # OR: if more than <max_hours_elapsed> have elapsed since the last run, a 1 is returned.
  # undef() if any error occurrs concerning reading or writing to files.
  #
  # If <compare time> is not given, the current timestamp will be used.
  # The <compare time> is always written to the <file>.
  # Use different <file>s for different schedules within a script.

  title("Checking scheduling");

  my $ret = 0;   # the scheduled time has not been reached.

  my $filename  = $_[0];
  my @schedules = split(/\s+/, $_[1]);
  my $compare   = $_[2] || substr(iso_datetime(), 11, 5);
  my $compare_timestamp = iso_datetime();
  my $max_hours_elapsed = $_[3] || 24;

  print "Schedule times: ", join(",", @schedules), "\n";

  # Defaults (mainly for first run ever)
  my $last_hhmm = "00:00";
  my $last_timestamp = substr($compare_timestamp, 0, 10) . " 00:00:00";

  # --- Check for an existing file
  if (-e $filename) {
    # print "File '$filename' exists.\n";
  } else {
    print "File '$filename' does not exist. Create it.\n";
    if (open(FILE, ">", $filename)) {
      # print FILE "$last_hhmm\n";
      print FILE "$last_timestamp\n";
      close(FILE);
      # print "File '$filename' created with '$last_hhmm'.\n";
      print "File '$filename' created with '$last_timestamp'.\n";
    } else {
      print STDERR sub_name(), ": Error: cannot open new file '$filename' for writing: $!\n";
      return(undef());
      # This is fatal, do not continue.
    }
  }

  # --- Get the last checked hh:mm from file.
  if (open(FILE, "<", $filename)) {
    $last_timestamp = <FILE>;
    chomp($last_timestamp);
    if (length($last_timestamp) > 5) {
      # full timestamp
      $last_hhmm = substr($last_timestamp, 11, 5);
    } else {
      # only hh:mm
      print sub_name(), ": Info: Found old hh:mm timestamp in file, converting it to full timestamp.\n";
      $last_hhmm = $last_timestamp;
      $last_timestamp = substr(iso_datetime(), 0, 10) . " $last_hhmm:00";
    }
    close(FILE);
    # chomp($last_hhmm);
  } else {
    print STDERR sub_name(), ": Error: cannot open file '$filename' for reading: $!\n";
    return(undef());
    # This is fatal, do not continue.
  }
  print "Last timestamp from file is: '$last_timestamp'.\n";
  print "Last hh:mm from file is: '$last_hhmm'.\n";

  # --- Check the scheduled times
  print "Check if '$last_hhmm' < any scheduled hh:mm <= '$compare'.\n";

  foreach my $schedule (@schedules) {
    # print sub_name() . ": Info: checking against $schedule\n";
    if ($last_hhmm lt $schedule && $compare ge $schedule) {
      $ret = 1;
      print sub_name() . ": Info: Matching schedule: $last_hhmm < $schedule <= $compare.\n";
      last;
    }
  } # foreach

  if (! $ret) {print "No matching schedule found.\n"}

  # -----
  # Check if more than max_hours has elapsed

  # Convert both timestamps to seconds since big bang
  my $last_secs    = iso_datetime2secs($last_timestamp);
  my $compare_secs = iso_datetime2secs($compare_timestamp);

  # And check if the difference (in hours) is more than max_hours_elapsed.
  my $diff_h = pround(abs($compare_secs - $last_secs) / 60 / 60, -2);
  if ($diff_h > $max_hours_elapsed ) { 
    $ret = 1;
    print sub_name() . ": Info: Difference of $diff_h hours matches more than $max_hours_elapsed elapsed hours since last run.\n";
  } else {
    print sub_name() . ": Info: Only $diff_h hours have elapsed since last run. Not matching $max_hours_elapsed elapsed hours since last run.\n";
  }

  # --- Now write the current timestamp to the file.
  print "Writing '$compare_timestamp' to file '$filename'.\n";
  if (open(FILE, ">", $filename)) {
    print FILE "$compare_timestamp\n";
    close(FILE);
  } else {
    print STDERR sub_name(), ": Error: cannot open file '$filename' for writing: $!\n";
  }

  return($ret);
} # scheduled



# ----------------------------------------------------------------
sub lockfile_build {
  #
  #   lockfile_build(<filename>)
  #
  # It checks for an existing <filename>.
  # If it does NOT exist, it will build a new lockfile with the
  # current process id as contents and returns true.
  # 
  # If it DOES exist, it will read the process id from that file
  # and check whether there is still a process with that number.
  # If that process id is still running under the same user id,
  # it will return false.
  #
  # If that process is no longer running, it writes its
  # current process id into the <filename> and returns true.
  #
  # Use unlink(<filename>) to remove the lockfile after usage.

  my ($lockfile) = @_;

  if (-e $lockfile) {
    # lockfile exists, get pid
    print "Lockfile '$lockfile' exists.\n";

    my $pid = 0;
    if (open(LOCKFILE, "<", $lockfile)) {
      $pid = <LOCKFILE>;
      close(LOCKFILE);
    } else {
      print STDERR sub_name(), ": Error: cannot open file '$lockfile' for reading.\n";
      return(0);
    }
    # chomp($pid);
    $pid = trim($pid);

    # int() makes a zero out of <nothing>, 
    # but that is the master process of everything! 
    # So do not convert!
    # $pid = int($pid);
    print "Lockfile was created by process id '$pid'.\n";

    if ($pid =~ /\d+/) {
      if (kill(0, $pid)) {
        # Lockfile exists and process is still running, print message and return false.
        print "Process '$pid' is still running!\n";
        return(0);
  
      } else {
        print "Associated process '$pid' is no longer running!\n";
        print "Overwriting existing process id.\n";
      }
    } else {
      print "No valid pid found in '$lockfile' => no other process is running.\n";
    }
  } else {
    print "Lockfile '$lockfile' does not exist.\n";
  }

  if (open(LOCKFILE, ">", $lockfile)) {
    print LOCKFILE "$$\n";
    close(LOCKFILE);
    print "Process id '$$' written to '$lockfile'.\n";
  } else {
    print STDERR sub_name(), ": Error: cannot open file '$lockfile' for writing.\n";
    return(0);
  }

  return(1);

} # lockfile_build


# ----------------------------------------------------------------
sub get_value {
  #
  #   get_value <filename>, <delimiter>, <pattern> [, <column>]
  #
  # Assumes <filename> to contain tabular values, separated by
  # <delimiter> like:
  # 
  #   text expression!23.998!MHz
  #
  # It searches the <filename> for <pattern> in the leftmost 
  # column and returns the found value in <column> or in the 2nd.
  #
  # See also make_value_file().

  my ($filename, $delim, $pattern, $col, $line);

  # Check the parameter count.
  if (@_ == 4) {
    ($filename, $delim, $pattern, $col) = @_;
    $col--;   # perl's arrays start with zero!
  } else {
    ($filename, $delim, $pattern) = @_;
    $col = 1;   # the default column.
  }
  # print "$filename, $delim, $pattern, $col \n";

  # find the row in the file:
  if (! open(INFILE, $filename)) {
    print STDERR sub_name(), ": Error: Cannot open '$filename' for reading. $!\n";
    # Since any value could be expected, it is quite difficult to return
    # a usable "bad" value. So you might not be able to use it.
    return(0);
  }

  my ($ret, $y, @x);

  while ($line = <INFILE>){
    if ($line =~ /^\Q${pattern}${delim}/) {
      @x = split($delim, $line);
      if (scalar(@x)) {
        $ret = $x[$col];
      } else {
        print STDERR sub_name(), ": Warning: Cannot split line '$line' by delimiter '$delim'.\n";
      }
      last;
    }
  }
  if (! close(INFILE)) {
    print STDERR sub_name(), ": Error: Cannot close file handler for file '$filename'. $!\n";
    return(0);
  }

  # print "ret=$ret\n";

  return($ret);
} # get_value


# ----------------------------------------------------------------
sub delta_value {
  #
  #   delta_value <filename_old> <filename_new> <delimiter> <pattern> [<column>]
  # 
  # Assumes <filename_old> and <filename_new> to contain tabular 
  # values, separated by <delimiter> like:
  #
  #   frequency!23.998!MHz
  #
  # It searches the <filename_old> for <pattern> in the leftmost
  # column and takes the found value in <column> or in the 2nd.
  #
  # It searches the <filename_new> for <pattern> in the leftmost
  # column and takes the found value in <column> or in the 2nd.
  #
  # It returns then the calculated value. "new" minus "old".
  #
  # See also make_value_file().

  my ($filename_old, $filename_new, $delim, $pattern, $col);

  if (@_ == 5) {
    ($filename_old, $filename_new, $delim, $pattern, $col) = @_;
  } else {
    ($filename_old, $filename_new, $delim, $pattern) = @_;
    $col = 2;   # the default column.
  }
  my ($v1, $v2);

  $v1 = get_value($filename_old, $delim, $pattern, $col);
  $v2 = get_value($filename_new, $delim, $pattern, $col);

  return($v2 - $v1);
} # delta_value


# ----------------------------------------------------------------
sub get_value_list {
  #
  #   get_value_list(<filename>, <delimiter> [, <column>])
  #
  # Assumes <filename> to contain tabular 
  # values, separated by <delimiter> like:
  #
  #   adm!1.26!3.18!
  #   aio!143.21!324.97!
  #   cpu!5090.05!865.16!
  #   lio!0.4!1.8!
  #
  # Get a list of all values from a specific column of
  # the tabular data <filename> and returns it as array.

  my ($filename, $delim, $col, $line);

  # Check the parameter count.
  if (@_ == 3) {
    ($filename, $delim, $col) = @_;
    $col--;   # perl's arrays start with zero!
  } else {
    ($filename, $delim) = @_;
    $col = 0;   # the default column.
  }

  if (! open(INFILE, $filename)) {
    print STDERR sub_name(), ": Error: Cannot open '$filename' for reading. $!\n";
    return();
  }

  my (@ret, @x);

  while ($line = <INFILE>){
    @x = split($delim, $line);
    if (scalar(@x)) {
      push @ret, $x[$col];
    } else {
      print STDERR sub_name(), ": Warning: Cannot split '$line' by delimiter '$delim'.\n";
    }
  }
  if (! close(INFILE)) {
    print STDERR sub_name(), ": Error: Cannot close file handler for file '$filename'. $!\n";
    return();
  }

  return(@ret);
} # get_value_list


# ----------------------------------------------------------------
sub get_value_lines {
  #
  # get_value_lines(<ref_to_array>, <filename> [, <max_no_lines>] )
  #
  # Get all lines from a file <filename> and
  # put them onto an array, one element for each line.
  # Don't care about the contents.
  # Read only <max_no_lines> lines if given.

  my $rA       = $_[0];
  my $filename = $_[1];
  my $max_no_lines = $_[2] || -1;

  if (! open(INFILE, $filename)) {
    print STDERR sub_name(), ": Error: Cannot open '$filename' for reading. $!\n";
    return();
  }

  my $i = 0;

  while (my $line = <INFILE>) { 
    $i++;

    chomp($line);
    push(@$rA, $line);

    if ($max_no_lines != -1) {
      # if max_no_lines is given, then...
      if ($i >= $max_no_lines) {last}
    }
  } # while

  if (! close(INFILE)) {
    print STDERR sub_name(), ": Error: Cannot close file handler for file '$filename'. $!\n";
    return();
  }

  # Attention: $i may be zero!
  return($i);
} # get_value_lines



# ----------------------------------------------------------------
sub make_value_file {
  #
  #   make_value_file(<newfile>, <oldfile>, <timestamp>, <delimiter> [, <overwrite>]);
  #
  # Example:
  #
  #   make_value_file("xy23.tmp", "iw930.vp_status", "2004-04-20 08:01:00", "!");
  #
  # This function is used to build files that contain any type
  # of data, mostly tabular data output of sql statements that
  # need to be kept until the next run or longer. The function checks
  # whether there is any <oldfile>, if not, it will generate one
  # and take the <newfile> as pattern but zeroed values.
  #
  # If <oldfile> exists, it will check whether the <timestamp> has
  # changed (reboot, restart, statistics resetted, ...), if not,
  # nothing is done, if yes, it will generate an <oldfile> and
  # take <newfile> as pattern, but zeroed values.
  #
  # If <overwrite> is true, it will copy all contents from
  # <newfile> to <oldfile>.
  #
  # The return value is 1, if a new work file has been built or 
  # all values have been zeroed because the timestamp has changed.
  #
  # See any watch_*.pl scripts for how to use these functions.

  my ($zero, $newfile, $oldfile, $ts, $oldts, $delim, $overwrite);


  if (@_ == 5) {
    ($newfile, $oldfile, $ts, $delim, $overwrite) = @_;
  } else {
    ($newfile, $oldfile, $ts, $delim) = @_;
    $overwrite = 0;
  }

  $zero = 0;

  if (-e $oldfile) {
    print "File '$oldfile' does exist.\n";
    $oldts = get_value($oldfile, $delim, $TIMESTAMP_TXT);
    chomp $oldts;
    if ($oldts ne $ts) {
      print "Timestamp changed, was: '$oldts', now: '$ts'.\n";
      $zero = 1;
    } else {
      print "Timestamp has not changed, still: '$oldts'\n";
    }
  } else {
    print "File '$oldfile' does not exist.\n";
    $zero = 1;
  }

  print "Zero......: $zero\n";
  print "Overwrite.: $overwrite\n";

  if ($zero || $overwrite) {
    print "Build '$oldfile' from '$newfile' s values.\n";
    if ($zero) {print "With zeroed values.\n";}
    if (! open (OLDFILE, "> $oldfile")) {
      print STDERR sub_name(), ": Error: Cannot open '$oldfile' for writing. $! $?\n";
      return(0);
    }
    print OLDFILE "$TIMESTAMP_TXT$delim$ts\n";
    if (! open (NEWFILE, $newfile)) {
      print STDERR sub_name(), ": Error: Cannot open '$newfile' for reading. $! $?\n";
      close OLDFILE;
      return(0);
    }

    my ($line, @e);

    while ($line = <NEWFILE>) {
      chomp $line;
      # print $line, "\n";
      @e = split($delim, $line);
      if (scalar(@e)) {
        print OLDFILE $e[0], $delim;     # write expression to file
        shift @e;

        while (@e) {
          # print OLDFILE $e[0], $delim;
          if ($overwrite) {print OLDFILE $e[0], $delim;}
          else            {print OLDFILE 0, $delim;}     # write zero for each column to file
          shift @e;
        }
      } else {
        print STDERR sub_name(), ": Warning: Cannot split line '$line' at delimiters '$delim'.\n";
      }
      print OLDFILE "\n";              # this row is finished
    }
    close(NEWFILE);
    close(OLDFILE);
  }

  # -----
  # If 1 is returned, the ULS values should not be sent to 
  # the ULS server, because they are wrong.

  return($zero);
}  # make_value_file


# ----------------------------------------------------------------
sub informix_mode_text {
  #
  #   informix_mode_text(<onstat-return-value>)
  #
  # This is a special routine to find a verbose text
  # for the "onstat -" return values of an informix instance.
  # (Well, this *should* have been placed in an Informix.pm).
  #
  # onstat return codes:
  # 
  #   0   = Initialization
  #   1   = Quiescent
  #   2   = Fast Recovery
  #   3   = Archive Backup
  #   4   = Shutting Down
  #   5   = Online
  #   6   = System Aborting
  #   255 = shared memory not initialized

  my $ret = "$_[0] (unknown)";

  if    ($_[0] == 0) {$ret = "Initialization";}
  elsif ($_[0] == 1) {$ret = "Quiescent";}
  elsif ($_[0] == 2) {$ret = "Fast Recovery";}
  elsif ($_[0] == 3) {$ret = "Archive Backup";}
  elsif ($_[0] == 4) {$ret = "Shutting Down";}
  elsif ($_[0] == 5) {$ret = "Online";}
  elsif ($_[0] == 6) {$ret = "System Aborting";}
  elsif ($_[0] == 255) {$ret = "shared memory not initialized";}

  return($ret);
} # informix_mode_text


# ------------------------------------------------------------
sub show_hash {
  #
  #   show_hash(<ref to hash> [, separator])
  #
  # Displays a hash with sorted keys and their values (if present).

  my $href = $_[0];    # Reference to given hash
  my $sep = $_[1] || " := ";

  my @ks = sort(keys(%$href));

  foreach my $k (@ks) {
    # $t = $$href{$k} || " ";   # don't do this, it will output a blank when a zero is expected!

    my $t = " ";
    if (defined($$href{$k})) {$t = $$href{$k}}

    # if ($t) {$t = " "}   # But there may be no value, so set it to blank just for showing

    # print "-----\n";
    print "$k$sep$t\n";
  }
  # if(scalar(@ks)) {print "-" x 20, "\n"}
  # else {print "--- empty hash ---\n"}

} # show_hash


# ------------------------------------------------------------
sub make_text_report {
  # make_text_report(<ref_to_array>, <delimiter>, <col_align>, <title_rows>);

  # Generate a "report", where all column values are trimmed 
  # (perhaps truncated) and right or left aligned. Return the 
  # report as text.
  #
  # =====
  # Example:
  # Array @A contains these lines, each as one array element.
  # 
  # "    title 1   ! title 2    ! title 3   ! title 4"
  # " element 1.1   !  ele whatever is here 1.2   ! ele 1.3   ! ele 1.4"
  # "element 2.1   !  e 2.2   ! ele 2.3   !          ele 2.4"
  # "ele 3.1      !ele 3.2! absolutely elementary 3.3   ! ele 3.4"
  # 
  # make_text_report(\@A, "!", "LL10RL", 1);
  #
  # that would result in:
  # 
  # title 1     | title 2    |                   title 3 | title 4
  # ----------- | ---------- | ------------------------- | -------
  # element 1.1 | ele whatev |                   ele 1.3 | ele 1.4
  # element 2.1 | e 2.2      |                   ele 2.3 | ele 2.4
  # ele 3.1     | ele 3.2    | absolutely elementary 3.3 | ele 3.4
  #
  # =====
  # Parameters:
  #
  # <ref_to_array> := reference to an array containing the source lines.
  # <delimiter> := delimiter which is used to separate the elements within one line.
  # <col_align> := {L|R}[<width>][W:]{L|R}[<length>][W]...
  #                L := left align
  #                R := right align
  #                <width> := max width of column, expressions are truncated
  #                W := is reserved for later use
  #                : := only for L, will fill up to the right by using '.' and 
  #                     the following delimiter is a ':'.
  #                if <col_align> is empty, a default of "L" will be used 
  #                for every column found. if <col_align> is given, then there 
  #                will be only that number of columns in the result.
  # <title_rows> := the number of rows which should be used as column titles.

  # -----
  # My parameters

  my ($rA, $delim, $col_align, $title_rows) = @_;
  $col_align = uc($col_align);

  # -----
  # My definitions

  my $V = "|";
  my $H = "-";

  # -----
  # Find the max length of all expressions in all rows and cols.
  # Fill the MAXLEN array for each col.

  my @MAXLEN;

  foreach my $a (@$rA) {
    # print "$a\n";
    my @E = split($delim, $a);
    @E = map(trim($_), @E);

    for ( my $i = 0; $i <= $#E; $i++) {
      if (! $MAXLEN[$i]) { $MAXLEN[$i] = 0 }
      if (length($E[$i]) > $MAXLEN[$i]) { $MAXLEN[$i] = length($E[$i]) }
    }

  } # foreach

  # Set defaults, if col_align is not set.
  if (! $col_align) { $col_align = "L" x scalar(@MAXLEN) }

  # print join(",", @MAXLEN), "\n";

  # -----
  # Check the <col_align> definitions
  #

  # LR20L15WLLRL12 => ("L", "R20", "L15W", "L", "L", "R", "L12")
  my @COLS = ($col_align =~ /([LR]\d*W?)/g);

  # print join(",", @COLS), "\n";

  # Perhaps, the MAXLEN is overwritten by an explicit column width
  for (my $i = 0; $i <= $#COLS; $i++) {
    my ($colwidth) = ($COLS[$i] =~ /\w(\d*)/);

    if ($colwidth) { $MAXLEN[$i] = $colwidth }
    # print "$colwidth\n";
  }

  # print join(",", @MAXLEN), "\n";

  # -----
  # Insert the title separation

  my $i = 0;

  my @COPY;
  my $max_maxlen = max(@MAXLEN);

  foreach my $line (@$rA) {
    push(@COPY, $line);

    $i++;

    if ($i == $title_rows) {
      push(@COPY, join($delim, map($H x $max_maxlen, @COLS)));
    }

  } # foreach

  # -----
  # Prepare a resulting array

  my @R;

  foreach my $line (@COPY) {
    # walk over the lines

    # split the line into elements
    my @E = split($delim, $line);
    @E = map(trim($_), @E);

    for (my $i = 0; $i <= $#COLS; $i++) {
      # walk over the columns

      if ($COLS[$i] =~ /L/) {
        # left
        $E[$i] = substr($E[$i] . " " x $MAXLEN[$i], 0, $MAXLEN[$i]);
      } elsif ($COLS[$i] =~ /R/) {
        # right
        $E[$i] = substr(" " x $MAXLEN[$i] . $E[$i], - $MAXLEN[$i]);
      }

    } # for

    # Remove all elements, for which no column def is found.
    while (scalar(@E) > scalar(@COLS)) { delete($E[-1]) }

    push(@R, join(" $V ", @E) );

  } # foreach

  # -----
  # Return the result

  @R = map(rtrim($_), @R);

  # foreach my $r (@R) { print "[$r]\n" }

  return(join("\n", @R));

} # make_text_report


# -------------------------------------------------------------------
sub fif {
  # find in file
  #
  # fif(<filename>, <pattern>);
  #
  # Find the first line in a file, that matches <pattern>,
  # or all matches as array.
  # Returns undef() if no matching line is found.

  my ($filename, $patt) = @_;

  my @matches = ();

  if (open(IN, $filename)) {
    while(my $Line = <IN>) {
      chomp($Line);
      # no comments
      if ($Line =~ /^\s*#/) {next}

      if ($Line =~ /$patt/) {
        push(@matches, $Line);
        # last;
      }
    } # while

    if (! close(IN)) {
      print STDERR sub_name() . "Error: Cannot close filehandle for file '$filename'. $!\n";
    }

  } else {
    print STDERR sub_name() . "Error: Cannot open file '$filename'.\n";
  }


  if (wantarray() ) {
    return(@matches);
  } else {
    if (exists($matches[0]) ) {
      return($matches[0]);
    } else {
      return(undef());
    }
  }

}  # fif


# -------------------------------------------------------------------
sub local_tz_offset {
  # Returns the difference of the number of seconds between
  # local time and UTC (GMT/Zulu). For the current environment.
  # (needs POSIX)

  my $t = time();
  my $utc = mktime(gmtime($t));
  my @tmlocal = localtime($t);

  # force dst off, timezone specific
  $tmlocal[8] = 0;
  my $local = mktime(@tmlocal);

  return ($local - $utc);
} # local_tz_offset


# -------------------------------------------------------------------
sub tz {
  # Format a number of seconds to the timezone
  # {+|-}hh:mm
  # Always including plus or minus.

  my ($tzoffset) = @_;
  my $z = '+';
  if ($tzoffset < 0) { $z = '-' }
  $tzoffset = abs($tzoffset);
  my $hours = floor($tzoffset / 60 / 60);
  my $minutes = $tzoffset - $hours * 60 * 60;
  $z .= sprintf('%02d:%02d', $hours, $minutes);
  return $z;
} # tz





1;


