package ScriptX_Util::Dump;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(dump_scriptx_script);

our %SPEC;

$SPEC{dump_scriptx_script} = {
    v => 1.1,
    summary => 'Run a ScriptX-based script but only to '.
        'dump the import arguments',
    description => <<'_',

This function runs a CLI script that uses `ScriptX` but monkey-patches
beforehand so that `import()` will dump the import arguments and then exit. The
goal is to get the import arguments without actually running the script.

This can be used to gather information about the script and then generate
documentation about it or do other things (e.g. `App::shcompgen` to generate a
completion script for the original script).

CLI script needs to use `ScriptX`. This is detected currently by a simple regex.
If script is not detected as using `ScriptX`, status 412 is returned.

_
    args => {
        filename => {
            summary => 'Path to the script',
            req => 1,
            pos => 0,
            schema => 'str*',
            cmdline_aliases => {f=>{}},
        },
        libs => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'lib',
            summary => 'Libraries to unshift to @INC when running script',
            schema  => ['array*' => of => 'str*'],
            cmdline_aliases => {I=>{}},
        },
        skip_detect => {
            schema => ['bool', is=>1],
            cmdline_aliases => {D=>{}},
        },
    },
};
sub dump_scriptx_script {
    require Capture::Tiny;

    my %args = @_;

    my $filename = $args{filename} or return [400, "Please specify filename"];
    my $detres;
    if ($args{skip_detect}) {
        $detres = [200, "OK (skip_detect)", 1, {"func.module"=>"ScriptX", "func.reason"=>"skip detect, forced"}];
    } else {
        require ScriptX_Util;
        $detres = ScriptX_Util::detect_scriptx_script(
            filename => $filename);
        return $detres if $detres->[0] != 200;
        return [412, "File '$filename' is not script using ScriptX (".
                    $detres->[3]{'func.reason'}.")"] unless $detres->[2];
    }

    my $libs = $args{libs} // [];

    my @cmd = (
        $^X, (map {"-I$_"} @$libs),
        "-MScriptX_Util::Patcher::DumpAndExit",
        $filename,
    );
    my ($stdout, $stderr, $exit) = Capture::Tiny::capture(
        sub {
            local $ENV{SCRIPTX_DUMP} = 1;
            system @cmd;
        },
    );

    my $spec;
    if ($stdout =~ /^# BEGIN DUMP ScriptX\s+(.*)^# END DUMP ScriptX/ms) {
        $spec = eval $1;
        if ($@) {
            return [500, "Script '$filename' looks like using ".
                        "ScriptX, but I got an error in eval-ing ".
                            "captured option spec: $@, raw capture: <<<$1>>>"];
        }
    } else {
        return [500, "Script '$filename' looks like using ScriptX, ".
                    "but I couldn't find capture markers (# BEGIN DUMP ScriptX .. # END DUMP ScriptX), raw capture: ".
                        "stdout=<<$stdout>>, stderr=<<$stderr>>"];
    }

    [200, "OK", $spec, {
        'func.detect_res' => $detres,
    }];
}

1;
# ABSTRACT:

=head1 ENVIRONMENT

=head2 SCRIPTX_DUMP

Bool. Will be set to 1 when executing the script to be dumped.
