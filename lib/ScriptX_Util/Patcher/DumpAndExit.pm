package ScriptX_Util::Patcher::DumpAndExit;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Data::Dmp;
use Module::Patch qw(patch_package);

BEGIN {
    if ($INC{"ScriptX.pm"}) {
        warn "ScriptX has been loaded, we might not be able to patch it";
    }
    require ScriptX;
}

sub _dump {
    print "# BEGIN DUMP ScriptX\n";
    local $Data::Dmp::OPT_DEPARSE = 0;
    say dmp($_[0]);
    print "# END DUMP ScriptX\n";
}

patch_package('ScriptX', [
    {
        action => 'replace',
        sub_name => 'import',
        code => sub {
            my $class = shift;
            _dump(\@_);
            exit 0;
        },
    },
]);

1;
# ABSTRACT: Patch ScriptX to dump import arguments and exit

=for Pod::Coverage ^(patch_data)$

=head1 DESCRIPTION

This patch can be used to extract ScriptX list of loaded plugins
