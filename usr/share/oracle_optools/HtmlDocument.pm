#
# HtmlDocument.pm  -  build a html document
#
# Description:
#
#   Use this perl module to create a html document.
#   It will create an empty html when instantiated and you
#   may use methods to append more html to it.
#   Supported html elements are: paragraphs, headings, tables, anchors
#   breaks, horizontal rulers.
#
#     HtmlDocument->new([title]);
#       Create a new html document, give optionally a title (can also be set later).
#
#     get_html()
#       returns the complete html document.
#
#     add_anchor(<anchor>)
#     add_br()
#     set_charset(<mycharset>);
#     add_heading(<level>, <text> [, <anchor>])
#     add_hr()
#     add_html(<html>);
#     add_link(<link>, <text>)
#     add_local_anchor(<anchor>, <text>)
#     set_local_anchor_list()
#     add_paragraph(<type>, <text>)
#     add_remark(<remark>);
#     add_table(<ref_to_array>, <element_delimiter>, <col_align>, <title_rows> [, <caption>]);
#     set_title(<mytitle);
#
#     save2file(complete_path [, compress_command])
#                               { "xz" | "bzip2" | "gzip" }
#
#   The html document ist created as a string, containing an arbitrary
#   number of html elements that you append to the string. When you
#   request the html, the string is enclosed in html head and body and
#   returned.
#
#   This does NOT cover ANY html tags and is not a replacement for
#   html itself. The user still need to know about html and can add
#   arbitrary html using the add_html() method.
#
# ---------------------------------------------------------
# Copyright 2016, roveda
#
# HtmlDocument.pm is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# HtmlDocument.pm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with HtmlDocument.pm. If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Dependencies:
#
#   perl v5.6.0
#
# ---------------------------------------------------------
# Installation:
#
#   Copy this file to a directory in @INC, e.g.:
#
#     Linux:   /usr/lib/perl5/site_perl
#     HP-UX:   /opt/perl/lib/site_perl
#     Windows: <LW>:\Perl\site\lib
#     or in the local directory, if applicable.
#
# ---------------------------------------------------------
# Versions:
#
# 2016-02-14, 0.01, roveda
#   Created.
# 2016-06-19, 0.02, roveda
#   save2file() can now be called with "force", that will add a "--force" as
#   parameter to the optionally compress command (works for xz, bzip2 and gzip).
# 2016-07-13, 0.03, roveda
#   Removed the usage of Misc.pm
#   Added set_style().
# 2016-07-14, 0.04, roveda
#   Added exec_os_command() to get rid of the dependency to Misc.pm
#
# ============================================================

use strict;
use warnings;

# Yes, I am
package HtmlDocument;

# our(@ISA, @EXPORT, $VERSION);
# require Exporter;
# @ISA = qw(Exporter);

# @EXPORT = qw(html_embody html_h html_link html_place_anchor_list html_set_anchor html_table html_text);

my $VERSION = 0.04;


# ------------------------------------------------------------
# That is used for empty cells in tables:
my $NOTHING = "&nbsp;";

# ------------------------------------------------------------
# The default style definition
# That is embedded in <style>$DEFAULT_STYLE_DEFS</style>

my $DEFAULT_STYLE_DEFS="
  table {
      border-collapse: collapse;
      border: 1px solid black;
      margin-top: 5px;
  }

  th, td {
      border: 1px solid black;
      padding: 5px;
  }
";

# --------------------------------------------------------------------
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
sub new {
  # HtmlDocument->new([title]);

  # $_[0] contains the class name
  my $class = shift;
  my $title = shift || "";

  # the internal structure we'll use to represent
  # the data in our class is a hash reference
  my $self = {};

  # make $self an object of class $class
  bless( $self, $class );

  # That contains all the html.
  $self->{_doc} = "";

  # Add this as return anchor for all "up" links.
  $self->add_anchor("top_of_document");

  $self->{_charset} = "utf-8";

  # Title of html document.
  $self->{_title} = $title;

  # Style definition for the complete html document.
  $self->{_style_defs} = $DEFAULT_STYLE_DEFS;

  # Array of "local anchors" from which a simple table of content can be built
  $self->{_anchors} = [];

  # a constructor always returns an blessed() object
  return $self;

} # new


# ------------------------------------------------------------
sub get_html {
  # get_html();
  #
  # Return the complete html document as a string.

  my $self = shift;

  my $ret = "";

  $ret .= "<!doctype html>\n";
  $ret .="<html>\n";
  $ret .="  <head>\n";

  if ($self->{_charset}) {
    $ret .="    <meta charset=\"" . $self->{_charset} . "\">\n";
  }

  if ($self->{_title}) {
    $ret .="    <title>" . $self->{_title} . "</title>\n";
  }

  if ($self->{_style_defs}) {
    $ret .="    <style>\n";
    $ret .="    " . $self->{_style_defs} . "\n";
    $ret .="    </style>\n";
  }

  $ret .="  </head>\n";
  $ret .="<body>\n";

  $ret .= $self->{_doc} . "\n";

  $ret .="</body>\n";
  $ret .="</html>\n";


  # -----
  # anchors

  # Build a list (ul/li) of all anchors, but no bullets nor numbers
  # for all "local anchors" placed in the _anchors array.
  # (They have been added by add_local_anchor() or add_heading().

  my $got_anchors = 0;
  my $anchors = "<ul style=\"list-style-type:none\">\n";

  foreach my $a ( @{$self->{_anchors}} ) {

    my ($anchor_name, $anchor_text) = split(/\|\|/, $a);
    # print "anchor_name=$anchor_name, anchor_text=$anchor_text\n";

    $anchors .= "<li><a href=\"#$anchor_name\">$anchor_text</a></li>\n";
    $got_anchors = 1;
  } # foreach

  $anchors .= "</ul>\n";

  if ($got_anchors) {
    # Replace any occurrance of the special remark by the
    # list of anchors.
    $ret =~ s/<!-- __INSERT__MY__ANCHORS__ -->/$anchors/g;
  }

  return($ret);

} # get_html




# ------------------------------------------------------------
sub set_charset {
  # set_charset(mycharset);
  #
  # Will result in an:
  #   <meta charset="mycharset">

  my $self = shift;
  my $charset = shift;
  $self->{_charset} = $charset;
} # set_charset

# -----
sub get_charset {
  # get_charset();
  my $self = shift;
  return($self->{_charset});
} # get_char


# ------------------------------------------------------------
sub set_style {
  # set_style(<style_definitions>)
  #
  # Set the style definitions for this html document.
  # A default style definition is used at instantiation.
  # There is no syntax check or similar.

  my $self = shift;
  my $style_defs = shift;
  $self->{_style_defs} = $style_defs;
} # set_style

# -----
sub get_style {
  # get_style();
  my $self = shift;
  return($self->{_style_defs});
} # get_style


# ------------------------------------------------------------
sub set_title {
  # set_title(mytitle);
  #
  # Will result in an:
  #   <title>mytitle</title>

  my $self = shift;
  my $title = shift;
  $self->{_title} = $title;
} # set_title

# -----
sub get_title {
  # get_title();
  my $self = shift;
  return($self->{_title});
} # get_title


# ------------------------------------------------------------
sub add_heading {
  # add_heading(LEVEL, text [, anchor])
  #
  # Add a
  #   <hLEVEL>text</hLEVEL>
  # If anchor is given, it will insert an attribute
  # <hLEVEL id="anchor">text</hLEVEL>
  # If you use "_default_" as anchor, the anchor will be
  # automatically derived from the text, all lowercase, blanks replaced by underscores.

  my $self   = shift;
  my $level  = shift || "";
  my $text   = shift || "";
  my $anchor = shift || "";

  if ($anchor) {
    if ($anchor eq "_default_") {
      # Special anchor _default_
      my $a = lc($text);
      # Replace all characters except 0-9 and a-z by an underscore
      $a =~ s/[^0-9a-z]/_/g;
      $anchor = $a;
    }

    # Push it on the stack of local anchors as
    # element of a possible table of contents.
    push( @{$self->{_anchors}}, "$anchor||$text");

    $self->{_doc} .= "<h$level id=\"$anchor\">$text</h$level>\n";
  } else {
    $self->{_doc} .= "<h$level>$text</h$level>\n";
  }

} # add_heading


# ------------------------------------------------------------
sub add_link {
  # add_link(<link>, <text>)

  my $self = shift;
  my $link = shift;
  my $text = shift;

  $self->{_doc} .= "<a href=\"$link\">$text</a>\n";

} # add_link


# ------------------------------------------------------------
sub add_goto_top {
  # add_goto_top(<text>)

  my $self = shift;
  my $text = shift;

  $self->add_link("#top_of_document", $text);

} # add_link



# ------------------------------------------------------------
sub add_html {
  # add_html(<html>);
  #
  # Add any html expression.

  my $self = shift;
  my $html = shift;

  $self->{_doc} .= "$html\n";

} # add_html


# ------------------------------------------------------------
sub add_remark {
  # add_remark(<remark>);
  #
  # Add a remark.

  my $self = shift;
  my $remark = shift;

  if ( $remark =~ /\n/ ) {
    $self->{_doc} .= "<!-- \n$remark\n -->\n";
  } else {
    $self->{_doc} .= "<!-- $remark -->\n";
  }

} # add_remark


# ------------------------------------------------------------
sub add_anchor {
  # add_anchor(<anchor>)
  #
  # You must place a link somewhere to use this anchor,
  # remember to use "#anchor" as link destination.

  my $self = shift;
  my $anchor = shift;

  $self->{_doc} .= "<a name=\"$anchor\"></a>\n";

} # add_anchor

# ------------------------------------------------------------
sub add_local_anchor {
  # add_local_anchor(<anchor>, <text>)
  #
  # An anchor is set at the current position,
  # the text is filed in an array for later use.
  # It will be replaced during output of the html
  # at the position, where the local anchor list
  # is to be placed. See set_local_anchor_list().

  my $self = shift;
  my $anchor = shift;
  my $text = shift;

  push( @{$self->{_anchors}}, "$anchor||$text");

  $self->{_doc} .= "<a name=\"$anchor\"></a>\n";

} # add_local_anchor



# ------------------------------------------------------------
sub set_local_anchor_list {
  # set_local_anchor_list()
  #
  # Set an html remark, that will be replaced by
  # links to all filed local anchors.
  # You may use that e.g. for tables of contents.

  my $self = shift;

  $self->{_doc} .= "<!-- __INSERT__MY__ANCHORS__ -->\n";
  # That will be replaced during output by the list
  # of all local anchors. Somehow like a table of contents.

} # set_local_anchor_list


# ------------------------------------------------------------
sub add_paragraph {
  # add_paragraph(<type>, <text>)
  #
  # Add a paragraph of any type.
  # Use e.g. 'pre', 'p'

  my $self = shift;
  my $type = shift;
  my $text = shift || "";

  $self->{_doc} .= "<$type>$text</$type>\n";

} # add_paragraph


# ------------------------------------------------------------
sub add_br {
  # add_br()
  #
  # Add a break.

  my $self = shift;

  $self->{_doc} .= "<br>\n";

} # add_br


# ------------------------------------------------------------
sub add_hr {
  # add_hr()
  #
  # Add a horizontal ruler.

  my $self = shift;

  $self->{_doc} .= "<hr>\n";

} # add_hr

# ------------------------------------------------------------
sub add_ul {
  # add_ul(<ref_to_array>)
  #
  # Add an unordered list.
  # Use the array elements as list elements.

  my $self = shift;
  my $rA   = shift;

  my $ul = "";
  
  # <ul>
  #   <li>Coffee</li>
  #   <li>Tea</li>
  #   <li>Milk</li>
  # </ul> 

  if ( $#$rA >= 0 ) {
    $ul .= "<ul>\n";
    
    foreach my $a (@$rA) {
      $ul .= "  <li>";
      $ul .= $a;
      $ul .= "</li>\n";
    }
    $ul .= "</ul>\n";
    $self->{_doc} .= $ul;
  }

} # add_ul


# ------------------------------------------------------------
sub add_ol {
  # add_ol(<ref_to_array> [, <list_type> [, <start_value>])
  #
  # Add an ordered list.
  # Use the array elements as list elements.
  # Optionally specify the list type (1 Aa Ii) and/or
  # the start value.

  my $self   = shift;
  my $rA     = shift;
  my $ltype  = shift;
  if ( $ltype !~ /1|A|a|I|i/ ) { $ltype = "1" }
  
  my $startv = shift || 1;

  my $ol = "";
  
  # <ol type="A" start="1">
  #   <li>Coffee</li>
  #   <li>Tea</li>
  #   <li>Milk</li>
  # </ol> 

  if ( $#$rA >= 0 ) {
    $ol .= "<ol type=\"$ltype\" start=\"$startv\">\n";
    
    foreach my $a (@$rA) {
      $ol .= "  <li>";
      $ol .= $a;
      $ol .= "</li>\n";
    }
    $ol .= "</ol>\n";
    $self->{_doc} .= $ol;
  }

} # add_ol



# ------------------------------------------------------------
sub add_table {
  # add_table(<ref_to_array>, <element_delimiter>, <col_align>, <title_rows> [, <caption>]);
  #
  # Build a table out of the query output from an sql.
  # The array should e.g. look like ('!' as delimiter expected):
  #   value1          !   value in col 2  !  value in col 3 ! etc
  #   value2 in col 1 !                   !  xyz            ! even more
  #   3               !   4               !          5      ! what the heck...
  #
  # The col_align is a string containing one character ('L', 'C' or 'R') which defines
  # the alignment of the respective column.
  # The number of title rows define the number of rows, that are enclosed in th tags
  # instead of td tags.
  # The caption is optional.


  my $self       = shift;
  my $rA         = shift;
  my $delim      = shift;
  my $col_align  = shift || "";
  my $title_rows = shift || 0;
  my $caption    = shift || "";

  my $ret = "<table>\n";

  if ($caption) { $ret .= "  <caption>$caption</caption>\n" }

  # -----
  # Set up the array to keep the alignments for the columns.
  # L R or C may be used as alignment, in html tables you need
  # left, center and right.
  # "LRCLRC"
  my @ALIGN = (uc($col_align) =~ /([LRC])/g);
  foreach (@ALIGN) {
    s/L/left/;
    s/R/right/;
    s/C/center/;
  }

  # Line count (row count of table)
  my $i = 0;

  # For each array element (=line)
  foreach my $a (@$rA) {
    # print "$a\n";

    $i++;

    # Split up the line by delimiter
    my @E = split($delim, $a);

    # trim all elements
    for (@E) { s/^\s+|\s+$//g; }

    my $tdtag = "td";
    if ($i le $title_rows) { $tdtag = "th" }

    my $tr = "<tr>";


    # Column counter
    my $j = 0;

    # For each element of line
    foreach my $e (@E) {
      # That does not work, because '0' would be replaced by &nbsp; too
      # if ( ! "$e") { $e = $NOTHING }
      if ( "$e" eq "" ) { $e = $NOTHING }
      $tr .= "<$tdtag align=\"$ALIGN[$j]\">$e</$tdtag>";
      $j++;
    }

    $tr .= "</tr>\n";
    $ret .= $tr;

  } # foreach

  $ret .= "</table>\n";

  $self->{_doc} .= $ret;

} # add_table


# ------------------------------------------------------------
sub save2file {
  # save2file(complete_path [, compression_command [, force ]]);
  #
  # Save the resulting html document to a file,
  # compress it, if parameter is given.
  # (use: { "xz" | "gzip" | "bzip2" } ).
  # set force to anything to use --force as parameter to the compression command.
  #
  # The method returns the resulting filename
  # (complete path including [probably changed] extension)
  # or undef if anything did not work. Error messages are printed
  # to STDERR.

  my $self = shift;
  my $filename = shift;
  my $compression = shift || "";
  my $force = shift || "";
  if ($force) {$force = "--force "}

  if (! open(OUTFILE, ">", $filename)) {
    print STDERR sub_name() . ": ERROR: Cannot open '$filename' for writing: $!\n";
    return(undef);
  }

  print OUTFILE $self->get_html(), "\n";

  if (! close(OUTFILE)) {
    print STDERR sub_name() . ": ERROR: Cannot close file handler for file '$filename': $!\n";
    return(undef);
  }

  if      ($compression eq ""      ) {
    return($filename);
  } elsif ($compression =~ /xz/i    ) {
    if (exec_os_command("xz $force \"$filename\"")) { return("$filename.xz") }
  } elsif ($compression =~ /bzip2/i ) {
    if (exec_os_command("bzip2 $force \"$filename\"")) { return("$filename.bz2") }
  } elsif ($compression =~ /gzip/i  ) {
    if (exec_os_command("gzip $force \"$filename\"")) { return("$filename.gz") }
  } else {
    print STDERR sub_name() . ": WARNING: Compression '$compression' is not supported.\n";
    return($filename);
  }

  return(undef);

} # save2file


# ------------------------------------------------------------
1;

