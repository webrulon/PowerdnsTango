package PowerdnsTango::Account;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::FlashMessage;
use Dancer::Session::Storable;
use Dancer::Template::TemplateToolkit;
use Dancer::Plugin::Ajax;
use Crypt::SaltedHash;
use Data::Validate::Domain qw(is_domain);
use PowerdnsTango::Acl qw(user_acl);

our $VERSION = '0.2';


get '/account' => sub
{
	my $user_id = session 'user_id';
	my $user = database->quick_select('users_tango', { id => $user_id });


	template 'account', { login => $user->{login}, name => $user->{name}, email => $user->{email} };
};


post '/account/reset/password' => sub
{
        my $user_id = session 'user_id';
        my $password1 = params->{password1};
        my $password2 = params->{password2};


        if (($password1 =~ m/(\w)+/ && $password2 =~ m/(\w)+/) && ($password1 eq $password2))
        {
                my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
                $csh->add($password1);
                my $new_password = $csh->generate;
                database->quick_update('users_tango', { id => $user_id }, { password => $new_password });


                flash message => 'Password reset';
        }
        else
        {
                flash error => 'Password mismatch, please try again';
        }


        return redirect "/account";
};


ajax '/account/get/user' => sub
{
        my $user_id = session 'user_id';
	my $user = database->quick_select('users_tango', { id => $user_id });

        return { stat => 'ok', login => $user->{login}, name => $user->{name}, email => $user->{email} };
};


ajax '/account/save/user' => sub
{
        my $user_id = session 'user_id';
        my $login = params->{login};
        my $name = params->{name};
        my $email = params->{email};
	my $user = database->quick_select('users_tango', { id => $user_id });
        my $sth = database->prepare('select count(login) as count from users_tango where login = ?');
        $sth->execute($login);
	my $check_login = $sth->fetchrow_hashref;

	$sth = database->prepare('select count(email) as count from users_tango where email = ?');
	$sth->execute($email);
	my $check_email = $sth->fetchrow_hashref;

	
	if ($check_login->{count} != 0 && $login ne $user->{login})
	{
		return { stat => 'fail', message => "Account update failed, username $login already exists" };
	}


        if ($check_email->{count} != 0 && $email ne $user->{email})
        {
                return { stat => 'fail', message => "Account update failed, email $email already exists" };
        }


        if ($login =~ m/(\w)+/ && $name =~ m/(\w)+/ && (Email::Valid->address($email)))
        {
                database->quick_update('users_tango', { id => $user_id }, { login => $login, name => $name, email => $email });

                return { stat => 'ok', message => "Account updated", login => $login, name=> $name, email => $email };
        }
	elsif (! Email::Valid->address($email))
	{
		return { stat => 'fail', message => "Account update failed, $email is not a valid email address" };
	}
        else
        {
                return { stat => 'fail', message => 'Account update failed, ensure all fields have been filled out correctly' };
        }
};

