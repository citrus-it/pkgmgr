package PkgMgr::Config;

use strict;
use warnings;

use JSON::PP;
use FindBin;
use File::Basename qw(basename);
use PkgMgr::Utils;
use Data::Processor;

# constants
my $CONFILE = "$FindBin::RealBin/../etc/" . basename($0) . '.conf';

my $SCHEMA = sub {
    my $sv = PkgMgr::Utils->new();
    
    return {
    GENERAL => {
        optional => 1,
        members  => {
            certFile       => {
                description => 'path to certificate file',
                example     => '/omniosorg/ssl/certs/ooce_cert.pem',
                validator   => $sv->file('<', 'Cannot open file'),
            },              
            keyFile        => {
                description => 'path to certificate key file',
                example     => '/omniosorg/ssl/private/ooce_key.pem',
                validator   => $sv->file('<', 'Cannot open file'),
            },
            connectTimeout => {
                optional    => 1,
                description => 'Seconds to wait trying to connect during transport operations.',
                example     => 60,
                default     => 60,
                validator   => $sv->regexp(qr/^\d+$/, 'not a number'),
            },
            lowSpeedTimeout => {
                optional    => 1,
                description => 'Seconds below the lowspeed limit (1024 bytes/second) during '
                             . 'transport operations before the client aborts the operation.',
                example     => 30,
                default     => 30,
                validator   => $sv->regexp(qr/^\d+$/, 'not a number'),
            },
        },
    },
    REPOS   => {
        members  => {
            '\S+'   => {
                regex   => 1,
                members => {
                    signing     => {
                        description => 'sign packages (yes/no)',
                        example     => '"signing" : "yes"',
                        validator   => $sv->elemOf(qw(yes no)),
                    },
                    srcRepo     => {
                        description => 'source (local) repository',
                        example     => '"srcRepo" : "/omniosorg/_r22_repo"',
                        validator   => $sv->regexp(qr|^[-\w/.:_]+$|, 'not a valid repo path/URL'),
                    },     
                    dstRepo     => {
                        description => 'destination (remote) repository',
                        example     => '"dstRepo" : "https://pkg.omniosce.org/r151022/core"',
                        validator   => $sv->regexp(qr|^[-\w/.:_]+$|, 'not a valid repo path/URL'),
                    },
                    stagingRepo => {
                        optional    => 1,
                        description => 'staging repository',
                        example     => '"stagingRepo" : "https://pkg.omniosce.org/r151022/staging"',
                        validator   => $sv->regexp(qr|^[-\w/.:_]+$|, 'not a valid repo path/URL'),
                    },
                    publisher   => {
                        description => 'publisher name',
                        example     => '"publisher" : "omnios"',
                        validator   => $sv->regexp(qw/^[\w.]+$/, 'not a valid publisher name'),
                    },
                    release     => {
                        description => 'release',
                        example     => '"release" : "r151022"',
                        transformer => sub { return (shift =~ /^r?(.*)$/)[0]; }, # remove leading 'r' if given
                        validator   => $sv->regexp(qw/^1510\d{2}$/, 'not a valid release'),
                    },
                    on_hold     => {
                        optional    => 1,
                        array       => 1,
                        description => 'list of FMRI patterns (regexp) not to stage or publish',
                        example     => '"on_hold" : [ "binutils", "cherrypy" ]',
                        validator   => sub { return undef },
                    },
                },
            },
        },
    },
    }
};

# constructor
sub new {
    my $class = shift;
    my $self  = { @_ };

    $self->{cfg} = Data::Processor->new($SCHEMA->()); 

    return bless $self, $class;
}

sub loadConfig {
    my $self     = shift;
    my $repo     = shift;
    my $confFile = shift // $CONFILE;
    
    open my $fh, '<', $confFile or die "ERROR: opening config file '$confFile': $!\n";
    my $configJSON = do { local $/; <$fh>; };
    close $fh;
    
    my $config = JSON::PP->new->decode($configJSON);
    
    my $ec = $self->{cfg}->validate($config);
    $ec->count and die join ("\n", map { $_->stringify } @{$ec->{errors}}) . "\n";

    exists $config->{REPOS}->{$repo}
        or die "ERROR: repository '$repo' not defined in config file.\n";

    return $config;
}

1;
