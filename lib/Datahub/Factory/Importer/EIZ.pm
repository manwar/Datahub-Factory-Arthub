package Datahub::Factory::Importer::EIZ;

use strict;
use warnings;

use Catmandu::Importer::OAI;
use Moo;
use URI::Split qw(uri_join);
use File::Basename qw(fileparse);

with 'Datahub::Factory::Importer';

has endpoint           => (is => 'ro', required => 1);
has metadata_prefix    => (is => 'ro', default => sub {
    return 'oai_lido';
});
has handler                => (is => 'ro');
has set                    => (is => 'ro');
has from                   => (is => 'ro');
has until                  => (is => 'ro');
has username               => (is => 'ro');
has password               => (is => 'ro');
has pids_path              => (is => 'ro', required => 1);
has aat_path               => (is => 'ro', required => 1);
has creators_path          => (is => 'ro', required => 1);
# has pid_module             => (is => 'ro', default => 'rcf');
# has pid_username           => (is => 'ro');
# has pid_password           => (is => 'ro');
# has pid_lwp_realm          => (is => 'ro');
# has pid_lwp_base_url       => (is => 'ro');
# has pid_rcf_container_name => (is => 'ro');


sub _build_importer {
    my $self = shift;
    my $options = {
        url            => $self->endpoint,
        handler        => $self->handler,
        metadataPrefix => $self->metadata_prefix,
        from           => $self->from,
        until          => $self->until,
        set            => $self->set,
    };
    if (defined($self->username)) {
        $options->{'username'} = $self->username;
        $options->{'password'} = $self->password;
    }

    my $importer = Catmandu::Importer::OAI->new(
       $options
    );
    $self->prepare();
    return $importer;
}

sub prepare {
    my $self = shift;
    $self->logger->info('Creating "pids" temporary table.');
    $self->__pids();
    $self->logger->info('Creating "creators" temporary table.');
    $self->__creators();
    $self->logger->info('Creating "aat" temporary table.');
    $self->__aat();
}

sub __pids {
    my $self = shift;
    $self->temporary_table($self->pids_path);
    # my $pid = Datahub::Factory->module('PID')->new(
    #     pid_module             => $self->pid_module,
    #     pid_username           => $self->pid_username,
    #     pid_password           => $self->pid_password,
    #     pid_rcf_container_name => $self->pid_rcf_container_name,
    #     pid_rcf_object         => '/tmp/PIDS_MSK_UTF8.csv',
    #     pid_lwp_url            => uri_join($self->pid_lwp_base_url, 'PIDS_MSK_UTF8.csv'),
    #     pid_lwp_realm          => $self->pid_lwp_realm,
    # );
    # $pid->temporary_table($pid->path);
}

sub __creators {
    my $self = shift;
    $self->temporary_table($self->creators_path);
    # my $pid = Datahub::Factory->module('PID')->new(
    #     pid_module             => $self->pid_module,
    #     pid_username           => $self->pid_username,
    #     pid_password           => $self->pid_password,
    #     pid_rcf_container_name => $self->pid_rcf_container_name,
    #     pid_rcf_object         => '/tmp/CREATORS_MSK_UTF8.csv',
    #     pid_lwp_url            => uri_join($self->pid_lwp_base_url, 'CREATORS_MSK_UTF8.csv'),
    #     pid_lwp_realm          => $self->pid_lwp_realm,
    # );
    # $pid->temporary_table($pid->path);
}

sub __aat {
    my $self = shift;
    $self->temporary_table($self->aat_path);
    # my $pid = Datahub::Factory->module('PID')->new(
    #     pid_module             => $self->pid_module,
    #     pid_username           => $self->pid_username,
    #     pid_password           => $self->pid_password,
    #     pid_rcf_container_name => $self->pid_rcf_container_name,
    #     pid_rcf_object         => '/tmp/AAT_UTF8.csv',
    #     pid_lwp_url            => uri_join($self->pid_lwp_base_url, 'AAT_UTF8.csv'),
    #     pid_lwp_realm          => $self->pid_lwp_realm,
    # );
    # $pid->temporary_table($pid->path, 'record - object_name');
}

sub temporary_table {
    my ($self, $csv_location, $id_column) = @_;
    my $store_table = fileparse($csv_location, '.csv');

    unless (-e $csv_location) {
        Catmandu::BadArg->throw(
            message => sprintf('The CSV file %s is missing.', $store_table)
        );
    }

    my $importer = Catmandu->importer(
        'CSV',
        file => $csv_location
    );
    my $store = Catmandu->store(
        'DBI',
        data_source => sprintf('dbi:SQLite:/tmp/import.%s.sqlite', $store_table),
    );
    $importer->each(sub {
            my $item = shift;
            if (defined ($id_column)) {
                $item->{'_id'} = $item->{$id_column};
            }
            my $bag = $store->bag();
            # first $bag->get($item->{'_id'})
            $bag->add($item);
        });
}

1;
__END__

=encoding utf-8

=head1 NAME

Datahub::Factory::Importer::EIZ - Import data from the ErfgoedInzicht
L<OAI-PMH|https://www.openarchives.org/pmh/> endpoint

=head1 SYNOPSIS

    use Datahub::Factory::Importer::EIZ;
    use Data::Dumper qw(Dumper);

    my $oai = Datahub::Factory::Importer::EIZ->new(
        url                    => 'https://endpoint.eiz.be/oai',
        metadataPrefix         => 'oai_lido',
        set                    => '2011',
        pid_module             => 'rcf',
        pid_username           => 'datahub',
        pid_password           => 'datahub',
        pid_rcf_container_name => 'datahub',
    );

    $oai->importer->each(sub {
        my $item = shift;
        print Dumper($item);
    });

=head1 DESCRIPTION

Datahub::Factory::Importer::EIZ imports data from the ErfgoedInzicht OAI-PMH
endpoint. By default it uses the C<ListRecords> verb to return all records using
the I<oai_lido> format. It is possible to only return records from a single
I<Set> or those created, modified or deleted between two dates (I<from> and
I<until>).

It automatically deals with I<resumptionTokens>, so client code does not have to
implement paging.

To support PIDs, it uses Rackspace Cloud Files to fetch PID CSV's and convert
them to temporary sqlite tables.

Provide C<pid_username>, C<pid_password> and C<pid_rcf_container_name>.

=head1 PARAMETERS

The C<endpoint> parameter and some
L<PID module parameters|Datahub::Factory::Module::PID> are required.

To link PIDs (Persistent Identifiers) to MSK records, it is necessary to use the
PID module to fetch a CSV from either a Rackspace Cloud Files (protected by
username and password) instance or a public website. Depending on whether you
choose Rackspace or a Web site, different options must be set. If an option is
not applicable for your selected module, you can skip the parameter or set it
to C<undef>.

The CSV files are converted to sqlite tables inside C</tmp> and can be used in
your fixes. See L<msk.fix|https://github.com/VlaamseKunstcollectie/Datahub-Fixes/blob/master/msk.fix>
for an example.

=over

=item C<endpoint>

URL of the OAI endpoint.

=item handler( sub {} | $object | 'NAME' | '+NAME' )

Handler to transform each record from XML DOM (L<XML::LibXML::Element>) into
Perl hash.

Handlers can be provided as function reference, an instance of a Perl
package that implements 'parse', or by a package NAME. Package names should
be prepended by C<+> or prefixed with C<Catmandu::Importer::OAI::Parser>. E.g
C<foobar> will create a C<Catmandu::Importer::OAI::Parser::foobar> instance.
By default the handler L<Catmandu::Importer::OAI::Parser::oai_dc> is used for
metadataPrefix C<oai_dc>,  L<Catmandu::Importer::OAI::Parser::marcxml> for
C<marcxml>, L<Catmandu::Importer::OAI::Parser::mods> for
C<mods>, L<Catmandu::Importer::OAI::Parser::Lido> for
C<Lido> and L<Catmandu::Importer::OAI::Parser::struct> for other formats.
In addition there is L<Catmandu::Importer::OAI::Parser::raw> to return the XML
as it is.

=item C<metadata_prefix>

Any metadata prefix the endpoint supports. Defaults to C<oai_lido>.

=item C<set>

Optionally, a set to get records from.

=item C<from>

Optionally, a I<must_be_older_than> date.

=item C<until>

Optionally, a I<must_be_younger_than> date.

=item C<username>

=item C<password>

=back

=head2 PID options

=over

=item C<pid_module>

Choose the PID module you want to use. Set to I<rcf> to use Rackspace Cloud Files, or to
I<lwp> to use a public web site.

=item C<pid_username>

Provide your Rackspace Cloud Files username. If you selected I<lwp>, provide an optional
username (for HTTP Basic Authentication).

=item C<pid_password>

Provide your Rackspace Cloud Files api key. For I<lwp>, an optional password.

=item C<pid_rcf_container_name>

Provide the container name that holds the PID CSV's for I<rcf>.

=item C<pid_lwp_realm>

For I<lwp>, provide (optionally) the HTTP Basic Authentication Realm.

=item C<pid_lwp_base_url>

For I<lwp>, provide the URL where the CSV's are stored. This URL is used in addition
to the name of the CSV file to create the URL where the file can be fetched from (i.e
C<my $url = $pid_lwp_base_url + $csv_file_name>).

=back

=head1 ATTRIBUTES

=over

=item C<importer>

A L<Importer|Catmandu::Importer> that can be used in your script.

=back

=head1 AUTHOR

Pieter De Praetere E<lt>pieter at packed.be E<gt>
Matthias Vandermaesen E<lt>matthias dot vandermaesen at vlaamsekunstcollectie.be E<gt>

=head1 COPYRIGHT

Copyright 2017- PACKED vzw, Vlaamse Kunstcollectie vzw

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Datahub::Factory>
L<Catmandu>

=cut
