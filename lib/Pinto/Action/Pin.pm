# ABSTRACT: Force a package into the index

package Pinto::Action::Pin;

use Moose;

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw( Pinto::Action );

#------------------------------------------------------------------------------

with qw( Pinto::Role::Interface::Action::Pin );

#------------------------------------------------------------------------------

sub execute {
    my ($self) = @_;

    my $pkg = $self->_get_package() or return 0;

    $self->warning("Package $pkg is already pinned")
        and return 0 if $pkg->is_pinned();

    $self->error("This repository does not permit pinning developer packages")
        and return 0 if $pkg->distribution->is_devel() and not $self->config->devel();

    $self->_do_pin($pkg);

    return 1;
}

#------------------------------------------------------------------------------

sub _get_package {
    my ($self) = @_;

    my $where           = { name => $self->package() };
    $where->{version}   = $self->version() if defined $self->version();
    $where->{is_latest} = 1 if not $self->has_version();

    my $pkg_rs = $self->repos->select_packages($where);
    my $pkg_count = $pkg_rs->count();

    my $vname_suffix = $self->has_version() ? '-' . $self->version() : '';
    my $pkg_vname = $self->package() . $vname_suffix;

    if (not $pkg_count) {
        $self->error("Package $pkg_vname does not exist in the repository");
        return;
    }
    elsif ( $pkg_count > 1) {
        # TODO: Need to handle this better.  Maybe specify precise distribution?
        $self->error("Repository has multiple copies of package $pkg_vname");
        return;
    }

    # At this point, we know there is only one record
    my $pkg = $pkg_rs->first();

    return $pkg;
}

#------------------------------------------------------------------------------

sub _do_pin {
    my ($self, $pkg) = @_;

    $self->notice("Pinning package $pkg");

    # Only one version of a package can be pinned at a time.
    # So first, we unpin all the packages with that name...
    my $where   = { name => $pkg->name() };
    my @sisters = $self->repos->select_packages( $where )->all();
    $_->is_pinned(undef) for @sisters;
    $_->update() for @sisters;

    # Then pin the particular package we want...
    $pkg->is_pinned(1);
    $pkg->update();

    # Finally, remark the latest version of the package
    $self->repos->db->mark_latest($pkg);

    my $name = $pkg->name();
    $self->add_message("Pinned package $name. Latest is now $pkg");

    return 1;
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable();

#------------------------------------------------------------------------------

1;

__END__
