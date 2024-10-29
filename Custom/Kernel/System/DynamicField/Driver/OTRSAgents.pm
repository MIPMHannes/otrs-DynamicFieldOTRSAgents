# --
# Kernel/System/DynamicField/Driver/OTRSAgents.pm - Delegate for DynamicField OTRSAgents Driver
# Copyright (C) 2016 - 2023 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::OTRSAgents;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Main',
    'Kernel::System::User',
    'Kernel::System::Group',
);

=head1 NAME

Kernel::System::DynamicField::Driver::OTRSAgents

=head1 SYNOPSIS

DynamicFields OTRSAgents Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 1,
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::OTRSAgents');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Kernel::System::Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more behabiors
        if ( IsHashRefWithData( $Extension->{Behaviors} ) ) {

            %{ $Self->{Behaviors} } = (
                %{ $Self->{Behaviors} },
                %{ $Extension->{Behaviors} }
            );
        }
    }

    $Self->{CacheType} = 'DynamicFieldValues';

    return $Self;
}

sub ValueSet {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ValueSet( %Param );
}

sub EditFieldValueValidate {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::EditFieldValueValidate( %Param );
}

sub DisplayValueRender {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::DisplayValueRender( %Param );
}

sub SearchFieldRender {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::SearchFieldRender( %Param );
}

sub SearchFieldParameterBuild {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::SearchFieldParameterBuild( %Param );
}

sub StatsFieldParameterBuild {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::StatsFieldParameterBuild( %Param );
}

sub ValueLookup {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ValueLookup( %Param );
}

sub ColumnFilterValuesGet {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ColumnFilterValuesGet( %Param );
}
sub PermissionRoleUserGet {
    my ( $Self, %Param ) = @_;
    my $go = $Kernel::OM->Get('Kernel::System::Group');
    # check needed stuff
    if ( !$Param{RoleID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need RoleID!",
        );
        return;
    }

    # get valid role list
    my %RoleList = $go->RoleList( Valid => 1 );

    return if !$RoleList{ $Param{RoleID} };

    # get permission data
    my %Permissions = $go->_DBRoleUserGet(
        Type => 'RoleUser',
    );

    return if !$Permissions{ $Param{RoleID} };
    return if ref $Permissions{ $Param{RoleID} } ne 'ARRAY';

    # extract users
    my $UsersRaw = $Permissions{ $Param{RoleID} } || [];

    # get valid user list
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type => 'Long',
        Valid => 1,
    );

    # calculate users
    my %Users;
    USERID:
    for my $UserID ( @{$UsersRaw} ) {

        next USERID if !$UserID;
        next USERID if !$UserList{$UserID};

        $Users{$UserID} = $UserList{$UserID};
    }

    return %Users;
}
sub PossibleValuesGet {
    my ($Self, %Param) = @_;
    my %List = ();

 
    my $Config = $Param{DynamicFieldConfig}->{Config} || {};
    if ($Config->{RoleFilter}){
            %List = $Self->PermissionRoleUserGet(
            RoleID => $Config->{RoleFilter},
        );
        }else{
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
     %List = $UserObject->UserList(
       Type          => 'Long',
        Valid         => $Config->{AgentValidity} || 1,
        NoOutOfOffice => 1,
    );}
    

    my $FieldPossibleNone;
    if ( defined $Param{OverridePossibleNone} ) {
        $FieldPossibleNone = $Param{OverridePossibleNone};
    }
    else {
        $FieldPossibleNone = $Config->{PossibleNone} || 0;
    }

    # set none value if defined on field config
    if ($FieldPossibleNone) {
        $List{''} = '-';
    }


    return  \%List;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
