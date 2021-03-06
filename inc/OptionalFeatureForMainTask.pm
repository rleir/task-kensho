use strict;
use warnings;
package inc::OptionalFeatureForMainTask;

use Moose;
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::BundleDeps',
    'MooseX::SimpleConfig';
use namespace::autoclean;

has configfile => (
    is => 'ro', isa => 'Str',
    lazy => 1,
    default => sub { shift->payload->{configfile} },
);

has _module_data => (
    isa => 'HashRef[HashRef[Str|HashRef[Str]]]',
    traits => ['Hash'],
    handles => {
        modules => 'keys',
        data_for => 'get',
    },
    lazy => 1,
    default => sub {
        my $self = shift;
        $self->get_config_from_file($self->configfile);
    },
);

sub configure
{
    my $self = shift;

    # skip the prompts when building
    $ENV{PERL_MM_USE_DEFAULT} = 1;

    my (@plugins,@dynamic_prompts);
    foreach my $module (sort $self->modules)
    {
        my $module_data = $self->data_for($module);
        my $task = (split('::', $module))[-1];

        push @plugins, [
            'OptionalFeature',
            "$task feature",
            {
                ':version' => '0.016',
                -name => $task,
                -description => $module_data->{description},
                -always_recommend => 1,
                -require_develop => 0,
                -default => 1,
                -prompt => 0,
                $module => 0,
            },
        ];

        push @dynamic_prompts, (
            qq!\$WriteMakefileArgs{PREREQ_PM}{'$module'} = \$FallbackPrereqs{'$module'} = \$WriteMakefileArgs{VERSION}!,
            qq!  if prompt("install $module ($module_data->{description})? [Y/n]", 'Y') =~ /^y/i;!,
        );
    }

    push @plugins, [ 'DynamicPrereqs', { ':version' => '0.006', '-raw' => \@dynamic_prompts } ];

    $self->add_plugins(@plugins);
}

__PACKAGE__->meta->make_immutable;
