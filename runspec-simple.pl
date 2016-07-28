#!/usr/bin/perl
# Note: UNIX only--the script uses 'cp'.

=head1 NAME
runspec-simple.pl - Run SPEC benchmarks under an external tool, e.g. QEMU

=head1 SYNOPSIS

 runspec-simple.pl [OPTIONS] <action=run,clean> <path_to_tool_binary> <path_to_spec> <benchmark(s)>
 Options: --config, --iterations, --size --tool-flags.
          --help for a brief help message.
 NOTES:
  <path_to_spec> points to the top SPEC directory.
  <benchmark> can be a specific benchmark, or int|all.
=cut

use warnings;
use strict;
use Cwd;
use Time::HiRes qw(gettimeofday tv_interval);
use File::Basename;
use File::Path qw(rmtree);
use Getopt::Long;
use Pod::Usage;
use Mean;

my %specint = (
    '400.perlbench' => {
	'flags' => '-I. -I./lib',
	'runs' => {
	    'test' => [qw/attrs.pl
                          gv.pl
                          makerand.pl
                          pack.pl
                          redef.pl
                          ref.pl
                          regmesg.pl
                          test.pl/],
	    'train' => ['diffmail.pl 2 550 15 24 23 100',
			'perfect.pl b 3',
			'scrabbl.pl scrabbl.in',
			'splitmail.pl 535 13 25 24 1091',
			'suns.pl'],
	    'ref' => ['checkspam.pl 2500 5 25 11 150 1 1 1 1',
		      'diffmail.pl 4 800 10 17 19 300',
		      'splitmail.pl 1600 12 26 16 4500'],
	},
    },
    '401.bzip2' => {
	'runs' => {
	    'test' => ['input.program 5',
		       'dryer.jpg 2'],
	    'train' => ['input.program 10',
			'byoudoin.jpg 5',
			'input.combined 80'],
	    'ref' => ['input.source 280',
		      'chicken.jpg 30',
		      'liberty.jpg 30',
		      'input.program 280',
		      'text.html 280',
		      'input.combined 200'],
	},
    },
    '403.gcc' => {
	'runs' => {
	    'test' => ['cccp.in -o cccp.s'],
	    'train' => ['integrate.in -o integrate.s'],
	    'ref' => ['166.in -o 166.s',
		       '200.in -o 200.s',
		       'c-typeck.in -o c-typeck.s',
		       'cp-decl.in -o cp-decl.s',
		       'expr.in -o expr.s',
		       'expr2.in -o expr2.s',
		       'g23.in -o g23.s',
		       's04.in -o s04.s',
		       'scilab.in -o scilab.s'],
	},
    },
    '429.mcf' => {
	'runs' => {
	    'test' => ['inp.in'],
	    'train' => ['inp.in'],
	    'ref' => ['inp.in'],
	},
    },
    '445.gobmk' => {
	'flags' => '--quiet --mode gtp --gtp-input',
	'runs' => {
	    'test' => [qw(capture.tst
                          connect.tst
                          connect_rot.tst
                          connection.tst
                          connection_rot.tst
                          cutstone.tst
                          dniwog.tst)],
	    'train' => [qw(arb.tst
                           arend.tst
                           arion.tst
                           atari_atari.tst
                           blunder.tst
                           buzco.tst
                           nicklas2.tst
                           nicklas4.tst)],
	    'ref' => [qw(13x13.tst
                         nngs.tst
                         score2.tst
                         trevorc.tst
                         trevord.tst)],
	},
    },
    '456.hmmer' => {
	'runs' => {
	    'test' => ['--fixed 0 --mean 325 --num 45000 --sd 200 --seed 0 bombesin.hmm'],
	    'train' => ['--fixed 0 --mean 425 --num 85000 --sd 300 --seed 0 leng100.hmm'],
	    'ref' => ['nph3.hmm swiss41',
		      '--fixed 0 --mean 500 --num 500000 --sd 350 --seed 0 retro.hmm'],
	},
    },
    '458.sjeng' => {
	'runs' => {
	    'test' => ['test.txt'],
	    'train' => ['train.txt'],
	    'ref' => ['ref.txt'],
	},
    },
    '462.libquantum' => {
	'runs' => {
	    'test' => ['33 5'],
	    'train' => ['143 25'],
	    'ref' => ['1397 8'],
	},
    },
    '464.h264ref' => {
	'runs' => {
	    'test' => ['-d foreman_test_encoder_baseline.cfg'],
	    'train' => ['-d foreman_train_encoder_baseline.cfg'],
	    'ref' => ['-d foreman_ref_encoder_baseline.cfg',
		      '-d foreman_ref_encoder_main.cfg',
		      '-d sss_encoder_main.cfg'],
	},
    },
    '471.omnetpp' => {
	'runs' => {
	    'test' => ['omnetpp.ini'],
	    'train' => ['omnetpp.ini'],
	    'ref' => ['omnetpp.ini'],
	},
    },
    '473.astar' => {
	'runs' => {
	    'test' => ['lake.cfg'],
	    'train' => ['BigLakes1024.cfg',
			'rivers1.cfg'],
	    'ref' => ['BigLakes2048.cfg',
		      'rivers.cfg'],
	},
    },
    '483.xalancbmk' => {
	'runs' => {
	    'test' => ['-v test.xml xalanc.xsl'],
	    'train' => ['-v allbooks.xml xalanc.xsl'],
	    'ref' => ['-v t5.xml xalanc.xsl'],
	},
	'exe_name' => 'Xalan',
    },
    '999.specrand' => {
	'runs' => {
	    'test' => ['324342 24239'],
	    'train' => ['1 3'],
	    'ref' => ['1255432124 234923'],
	},
    },
    );

my %grouped_benchmarks = (
    'int' => [qw(400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer
                 458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar
                 483.xalancbmk)],
    );

my $config = 'x86_64';
my $help;
my $iterations = 1;
my $size = 'test';
my $tune = 'base'; # could make this configurable, but bleh

GetOptions(
    'config=s' => \$config,
    'h|help|man' => \$help,
    'iterations=i' => \$iterations,
    'size=s' => \$size,
    ) or pod2usage(2);

pod2usage(0) if $help;

if (@ARGV < 4) {
    printf("Error: insufficient arguments.\n\n");
    pod2usage(1);
}
my $action = shift @ARGV;
my $tool = shift @ARGV;
my $toolname = basename($tool);
my $spec_path = shift @ARGV;
my @cli_benchmarks = @ARGV;

my %actions = (
    'run' => \&action_run,
    'clean' => \&action_clean,
    );
test_valid(\%actions, $action, 'action');

my %valid_size = (
    'test' => 1,
    'train' => 1,
    'ref' => 1,
    );
test_valid(\%valid_size, $size, 'size');

my $all;

# populate '$all'
for my $b (keys %specint) {
    die if $all->{$b};
    $all->{$b} = $specint{$b};
}

my @benchmarks = ();
foreach my $b (@cli_benchmarks) {
    if ($grouped_benchmarks{$b}) {
	push @benchmarks, @{ $grouped_benchmarks{$b} };
    } else {
	push @benchmarks, $b;
    }
}

# remove duplicates
my %bh;
foreach (@benchmarks) {
    $bh{$_} = 1;
}
@benchmarks = ();
foreach (sort keys %bh) {
    push @benchmarks, $_;
}

# sanity-check the requested benchmarks
for my $bench (@benchmarks) {
    if (!$all->{$bench}) {
	die "Invalid benchmark $bench";
    }
}

# ok, let's do it
$actions{$action}->();

sub test_valid {
    my ($href, $var, $name) = @_;

    return if $href->{$var};

    my @klist = sort keys %$href;
    my $plural = @klist > 1 ? "${name}s" : "$name";
    die "Invalid $name '$var'. Valid $plural: ", join(", ", @klist), ".\n";
}

sub action_run {
    my $results;
    for my $bench (@benchmarks) {
	my @res = ();
	for (my $i = 0; $i < $iterations; $i++) {
	    push @res, run_benchmark($bench);
	}
	$results->{$bench}->{mean} = Mean::arithmetic(\@res);
	$results->{$bench}->{stdev} = Mean::stdev(\@res);
    }
    pr_results($results);
}

sub action_clean {
    for my $bench (@benchmarks) {
	clean_dir($bench);
    }
}

sub pr_results {
    my ($results) = @_;
    my @titles = ('benchmark', 'mean', 'stdev');

    print "# ", join("\t", @titles), "\n";
    foreach my $b (sort keys %{ $results }) {
	my $r = $results->{$b};
	my @arr = ($b, $r->{mean}, $r->{stdev});

	print join("\t", @arr), "\n";
    }
}

# create the directory, and copy 'all/input' and '$size/input' to it
sub prepare_run_dir {
    my ($benchmark) = @_;
    my $path = "$spec_path/benchspec/CPU2006/$benchmark/run";
    my $num = 0;
    my $dirname;
    while (1) {
	$dirname = "$path/run_${tune}_${config}";
	$dirname .= sprintf(".%04d", $num);
	$dirname .= ".$toolname";
	if (!-d $dirname) {
	    last;
	}
	$num++;
    }
    mkdir($dirname, 0755) or die "Cannot create dir '$dirname': $!";
    if (-d "$path/../data/all/input") {
	sys("cp -r $path/../data/all/input/* $dirname");
    }
    sys("cp -r $path/../data/$size/input/* $dirname");
    return $dirname;
}

sub clean_dir {
    my ($benchmark) = @_;
    my $path = "$spec_path/benchspec/CPU2006/$benchmark/run";
    my $pr = 0;

    die if (!$spec_path); # paranoid: avoid deleting '/benchspec'

    opendir(my $dh, $path) or die "Can't open $path: $!";
    while (readdir $dh) {
	my $dir = $_;
	if (basename($dir) =~ m/run_${tune}_${config}\.[0-9]+\.$toolname/) {
	    if (!$pr) {
		print "$benchmark:\n";
		$pr = 1;
	    }
	    my $full = "$path/$dir";
	    print "cleaning $full\n";
	    rmtree($full);
	}
    }
    closedir $dh;
    if ($pr) {
	print "\n";
    }
}

sub run_timed {
    my ($dir, $arg) = @_;
    my $cmd = "$tool $arg 1>/dev/null 2>/dev/null";
    my $orig = getcwd;
    my $beaut_arg = $arg;
    $beaut_arg =~ s|\.\./\.\./exe/||;

    print STDERR basename($dir), ": ", $toolname, " $beaut_arg: ";
    chdir $dir or die "Cannot chdir to $dir: $!";

    my $t0 = [gettimeofday];
    sys($cmd);
    my $walltime = tv_interval($t0); # format: floating seconds

    chdir $orig or die "Cannot chdir to $orig: $!";
    print STDERR "\t${walltime}s\n";
    return $walltime;
};

sub sys {
    my $cmd = shift(@_);
    system("$cmd") == 0 or die "cannot run '$cmd': $?";
}

sub run_benchmark {
    my ($benchmark) = @_;
    my $path = "$spec_path/benchspec/CPU2006/$benchmark";
    my $flags = $all->{$benchmark}->{flags} || "";
    my $runs = $all->{$benchmark}->{runs}->{$size};
    my $exe = "$path/";
    my $beaut_exe = $all->{$benchmark}->{exe_name} || $benchmark;
    $beaut_exe =~ s/^[0-9]*\.//;
    my $dir;

    $dir = prepare_run_dir($benchmark);

    print STDERR "$benchmark\n";
    my $t = 0.0;
    foreach my $arg (@$runs) {
	$t += run_timed($dir, "../../exe/${beaut_exe}_${tune}.${config} $flags $arg");
    }
    print STDERR "\n";
    return $t;
};
