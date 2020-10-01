package ScriptX_Util;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       detect_scriptx_script
               );

our %SPEC;

$SPEC{detect_scriptx_script} = {
    v => 1.1,
    summary => 'Detect whether a file is a ScriptX-based CLI script',
    description => <<'_',

The criteria are:

* the file must exist and readable;

* (optional, if `include_noexec` is false) file must have its executable mode
  bit set;

* content must start with a shebang C<#!>;

* either: must be perl script (shebang line contains 'perl') and must contain
  something like `use ScriptX`;

_
    args => {
        filename => {
            summary => 'Path to file to be checked',
            schema => 'str*',
            pos => 0,
            cmdline_aliases => {f=>{}},
        },
        string => {
            summary => 'String to be checked',
            schema => 'buf*',
        },
        include_noexec => {
            summary => 'Include scripts that do not have +x mode bit set',
            schema  => 'bool*',
            default => 1,
        },
    },
    args_rels => {
        'req_one' => ['filename', 'string'],
    },
};
sub detect_scriptx_script {
    my %args = @_;

    (defined($args{filename}) xor defined($args{string}))
        or return [400, "Please specify either filename or string"];
    my $include_noexec  = $args{include_noexec}  // 1;

    my $yesno = 0;
    my $reason = "";
    my %extrameta;

    my $str = $args{string};
  DETECT:
    {
        if (defined $args{filename}) {
            my $fn = $args{filename};
            unless (-f $fn) {
                $reason = "'$fn' is not a file";
                last;
            };
            if (!$include_noexec && !(-x _)) {
                $reason = "'$fn' is not an executable";
                last;
            }
            my $fh;
            unless (open $fh, "<", $fn) {
                $reason = "Can't be read";
                last;
            }
            # for efficiency, we read a bit only here
            read $fh, $str, 2;
            unless ($str eq '#!') {
                $reason = "Does not start with a shebang (#!) sequence";
                last;
            }
            my $shebang = <$fh>;
            unless ($shebang =~ /perl/) {
                $reason = "Does not have 'perl' in the shebang line";
                last;
            }
            seek $fh, 0, 0;
            {
                local $/;
                $str = <$fh>;
            }
            close $fh;
        }
        unless ($str =~ /\A#!/) {
            $reason = "Does not start with a shebang (#!) sequence";
            last;
        }
        unless ($str =~ /\A#!.*perl/) {
            $reason = "Does not have 'perl' in the shebang line";
            last;
        }

        # NOTE: the presence of \s* pattern after ^ causes massive slowdown of
        # the regex when we reach many thousands of lines, so we use split()

        #if ($str =~ /^\s*(use|require)\s+(Getopt::Long(?:::Complete)?)(\s|;)/m) {
        #    $yesno = 1;
        #    $extrameta{'func.module'} = $2;
        #    last DETECT;
        #}

        for (split /^/, $str) {
            if (/^\s*(use|require)\s+(ScriptX)(\s|;|$)/) {
                $yesno = 1;
                $extrameta{'func.module'} = $2;
                last DETECT;
            }
        }

        $reason = "Can't find any statement requiring ScriptX module";
    } # DETECT

    [200, "OK", $yesno, {"func.reason"=>$reason, %extrameta}];
}

1;
#ABSTRACT: Utilities for ScriptX

=head1 SEE ALSO

L<ScriptX>

=cut
